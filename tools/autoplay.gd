## Headless test harness: a simple bot plays cases through the same command interface
## a human uses, then reports results and writes dev logs.
##
##   godot --headless --path . --script res://tools/autoplay.gd -- [--seed N] [--games G]
##         [--npcs 7] [--log-dir DIR] [--transcript] [--echo-log]
##
## --transcript prints everything the player would see. Logs go to <log-dir>/case_<seed>.*
## The bot cheats slightly (it reads NPC positions to pick busy locations) because its job
## is to exercise systems, not to play fairly.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")

var g
var transcript = false
var talked = {}
var rng = RandomNumberGenerator.new()

func _init() -> void:
	var args = _parse(OS.get_cmdline_user_args())
	var first: int = int(args.get("seed", "1"))
	var games: int = int(args.get("games", "1"))
	transcript = args.has("transcript")
	var log_dir: String = ProjectSettings.globalize_path(args.get("log-dir", "res://logs"))
	var stats = {"good": 0, "evil": 0, "days": 0, "exec_evil": 0, "exec_good": 0, "kills": 0, "lies": 0, "errors": 0}
	for i in range(games):
		var seed_v = first + i
		var r = _play(seed_v, int(args.get("npcs", "7")), log_dir, args.has("echo-log"))
		stats[r["winner"]] += 1
		stats["days"] += r["days"]
		stats["exec_evil"] += r["exec_evil"]
		stats["exec_good"] += r["exec_good"]
		stats["kills"] += r["kills"]
		stats["lies"] += r["lies"]
		print("case %d: %s wins on day %d | executions good=%d evil=%d | demon kills=%d | logged lies=%d | %s" %
			[seed_v, r["winner"], r["days"], r["exec_good"], r["exec_evil"], r["kills"], r["lies"], r["reason"]])
	if games > 1:
		print("\nSUMMARY over %d cases: good %d / evil %d, avg days %.1f, wrongful executions %d, evil executed %d, avg lies %.1f" %
			[games, stats["good"], stats["evil"], float(stats["days"]) / games, stats["exec_good"], stats["exec_evil"], float(stats["lies"]) / games])
	quit()

func _play(seed_v: int, npc_count: int, log_dir: String, echo: bool) -> Dictionary:
	g = Game.new()
	g.log_dir = log_dir
	rng.seed = seed_v * 7919
	talked = {}
	if echo:
		pass
	_out(g.new_case(seed_v, npc_count))
	if echo:
		g.w.dlog.echo = true
	var guard = 0
	while g.state != "over" and guard < 400:
		guard += 1
		var cmd = _decide()
		_out("\n> " + cmd)
		_out(g.command(cmd))
	var w = g.w
	var r = {"winner": w.winner if w.winner != "" else "evil", "days": w.day, "reason": w.end_reason,
		"exec_good": 0, "exec_evil": 0, "kills": 0, "lies": 0}
	for e in w.executions:
		if w.by_id[e["id"]].is_evil():
			r["exec_evil"] += 1
		else:
			r["exec_good"] += 1
	for e in w.dlog.entries:
		if e["type"] == "kill":
			r["kills"] += 1
		if e["type"] == "think" and e["data"].get("topic", "") == "lie":
			r["lies"] += 1
	if g.log_paths.is_empty():
		g.command("log")
	return r

func _out(s: String) -> void:
	if transcript:
		print(s)

# ---------------------------------------------------------------- bot brain

func _scores() -> Dictionary:
	var w = g.w
	var sc = {}
	for n in w.npcs:
		sc[n.id] = 0.0
	for pass_i in range(2):
		var nsc = {}
		for n in w.npcs:
			nsc[n.id] = 0.0
		var claims = {}
		for c in g.board:
			var src: String = c.get("source", "")
			var cred = 1.0
			if sc.has(src):
				cred = clampf(1.0 - sc[src] / 2.0, 0.1, 1.0)
			var subj: Array = c.get("subject", [])
			var add = 0.0
			match c["kind"]:
				"info":
					var d: Dictionary = c.get("data", {})
					match c.get("role", ""):
						"seer":
							add = 1.0 if d.get("yes", false) else -0.4
						"hearthwitch":
							add = 0.5 * d.get("count", 0) if d.get("count", 0) > 0 else -0.3
						"archivist":
							add = 0.7
						"nightwatch":
							add = 0.4
						"clerk":
							add = -0.3
				"trace":
					add = 0.3
				"sighting":
					if c.get("phase", -1) == C.NIGHT:
						add = 0.6 if src == "player" else 0.3
				"accusation", "opinion":
					add = 0.15
				"claim":
					var role: String = c.get("role", "")
					if role != "none" and not c.get("private", false):
						if not claims.has(role):
							claims[role] = []
						if not (subj[0] in claims[role]):
							claims[role].append(subj[0])
			for i in subj:
				if i != src and nsc.has(i):
					nsc[i] += add * cred
		for role in claims:
			if claims[role].size() > 1:
				for i in claims[role]:
					nsc[i] += 1.0
		sc = nsc
	for n in w.npcs:
		if not n.alive and n.death_cause == "demon":
			sc[n.id] = -9.0
	return sc

func _top_suspect():
	var sc = _scores()
	var best = null
	var best_s = -99.0
	for n in g.w.living():
		if sc[n.id] > best_s:
			best_s = sc[n.id]
			best = n
	return [best, best_s]

func _decide() -> String:
	var w = g.w
	match g.state:
		"day":
			if not g.moved:
				return "go " + _pick_location()
			var here: Array = w.npcs_at(w.player_loc)
			if w.scenes.has(w.player_loc) and not w.scenes[w.player_loc]["searched"]:
				return "search"
			if w.player_loc == "tavern" and w.phase == C.EVENING and rng.randf() < 0.5:
				return "gossip"
			var fresh: Array = here.filter(func(n): return talked.get(n.id, -1) != w.day)
			if not fresh.is_empty():
				var n = fresh[rng.randi_range(0, fresh.size() - 1)]
				talked[n.id] = w.day
				return "talk " + n.id
			if w.player_loc == "tavern":
				return "gossip"
			return "wait"
		"talk":
			var n = g.talk_with
			var asked: int = 3 - g.questions_left
			if asked == 0:
				return "ask gift"
			if asked == 1:
				return "ask info" if rng.randf() < 0.6 else "ask night"
			var ts = _top_suspect()
			if ts[0] != null and ts[1] >= 0.8 and ts[0] != n:
				for c in g.board:
					if ts[0].id in c.get("subject", []) and c.get("source", "") != ts[0].id and c["kind"] != "vote":
						return "tell %s %d" % [ts[0].id, c["n"]]
			var others: Array = w.living().filter(func(m): return m != n)
			return "ask about " + others[rng.randi_range(0, others.size() - 1)].id
		"meeting":
			var ts = _top_suspect()
			var sc = _scores()
			if not g.player_nominated and ts[0] != null and ts[1] >= 1.0 and w.day >= 2:
				var already = false
				for nm in g.meeting_noms:
					if nm["nominee"] == ts[0].id:
						already = true
				if not already:
					return "nominate " + ts[0].id
			if g.player_vote == "" and not g.meeting_noms.is_empty():
				var best = ""
				var best_s = 0.4
				for nm in g.meeting_noms:
					if sc[nm["nominee"]] > best_s:
						best_s = sc[nm["nominee"]]
						best = nm["nominee"]
				if best != "":
					return "vote " + best
			return "done"
		"night":
			var sc = _scores()
			if rng.randf() < 0.5:
				var cands: Array = w.living().filter(func(n): return n.claim_public and n.claimed_role in C.INFO_ROLES)
				if not cands.is_empty():
					cands.sort_custom(func(a, b): return sc[a.id] < sc[b.id])
					return "ward " + cands[0].id
			var ts = _top_suspect()
			if ts[0] != null:
				return "vigil " + ts[0].home_block
			return "sleep"
	return "look"

func _pick_location() -> String:
	var w = g.w
	for sid in w.scenes:
		if not w.scenes[sid]["searched"] and w.phase == C.MORNING:
			return sid
	if w.phase == C.EVENING:
		return "tavern"
	var best = "tavern"
	var best_n = -1
	for l in C.LOCATIONS:
		var n: int = w.npcs_at(l).filter(func(m): return talked.get(m.id, -1) != w.day).size()
		if n > best_n:
			best_n = n
			best = l
	return best

static func _parse(argv: PackedStringArray) -> Dictionary:
	var out = {}
	var i = 0
	while i < argv.size():
		var a = argv[i]
		if a.begins_with("--"):
			var k = a.substr(2)
			if i + 1 < argv.size() and not argv[i + 1].begins_with("--"):
				out[k] = argv[i + 1]
				i += 1
			else:
				out[k] = "true"
		i += 1
	return out
