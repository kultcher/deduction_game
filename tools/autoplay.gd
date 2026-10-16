## Headless test harness: a simple bot plays cases through the same command interface
## a human uses, then reports results and writes dev logs.
##
##   godot --headless --path . --script res://tools/autoplay.gd -- [--seed N] [--games G]
##         [--npcs 7] [--log-dir DIR] [--transcript] [--echo-log]
##
## --transcript prints everything the player would see. Logs go to <log-dir>/case_<seed>.*
## The bot only uses information a player could see, except that it knows which idle NPCs
## are at which exact location within a block (to keep it from wasting moves).
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
	var keys = ["days", "exec_evil", "exec_good", "kills", "lies", "nominations", "clemency", "reveals", "max_tier4", "pairs", "guards",
		"shares", "evil_shares", "approaches", "kill_on_threat"]
	var stats = {"good": 0, "evil": 0}
	for k in keys:
		stats[k] = 0
	for i in range(games):
		var seed_v = first + i
		var r = _play(seed_v, int(args.get("npcs", "7")), log_dir, args.has("echo-log"))
		stats[r["winner"]] += 1
		for k in keys:
			stats[k] += r[k]
		print("case %d: %s wins on day %d | exec good=%d evil=%d | kills=%d | lies=%d | noms=%d | pairs=%d | %s" %
			[seed_v, r["winner"], r["days"], r["exec_good"], r["exec_evil"], r["kills"], r["lies"], r["nominations"], r["pairs"], r["reason"]])
	if games > 1:
		var gf = float(games)
		print("\nSUMMARY over %d cases: good %d / evil %d (%.0f%%), avg days %.1f, wrongful executions %.2f/case, evil executed %.2f/case," %
			[games, stats["good"], stats["evil"], 100.0 * stats["good"] / gf, stats["days"] / gf, stats["exec_good"] / gf, stats["exec_evil"] / gf])
		print("  nominations %.1f/case, trait reveals %.1f/case, NPCs reaching tier 4 %.1f/case, NPC conversations %.1f/case, lies %.1f/case, stuck games %d" %
			[stats["nominations"] / gf, stats["reveals"] / gf, stats["max_tier4"] / gf, stats["pairs"] / gf, stats["lies"] / gf, stats["guards"]])
		print("  NPC shares %.1f/case, evil intel pools %.1f/case, approaches %.1f/case" %
			[stats["shares"] / gf, stats["evil_shares"] / gf, stats["approaches"] / gf])
	quit()

func _play(seed_v: int, npc_count: int, log_dir: String, echo: bool) -> Dictionary:
	g = Game.new()
	g.log_dir = log_dir
	rng.seed = seed_v * 7919
	talked = {}
	_out(g.new_case(seed_v, npc_count))
	if echo:
		g.w.dlog.echo = true
	var guard = 0
	while g.state != "over" and guard < 600:
		guard += 1
		var cmd = _decide()
		_out("\n> " + cmd)
		_out(g.command(cmd))
	var w = g.w
	var r = {"winner": w.winner if w.winner != "" else "evil", "days": w.day, "reason": w.end_reason,
		"exec_good": 0, "exec_evil": 0, "kills": 0, "lies": 0, "nominations": 0, "clemency": 0, "reveals": 0,
		"max_tier4": 0, "pairs": 0, "guards": 1 if guard >= 600 else 0, "shares": 0, "evil_shares": 0, "approaches": 0, "kill_on_threat": 0}
	for e in w.executions:
		if w.by_id[e["id"]].is_evil():
			r["exec_evil"] += 1
		else:
			r["exec_good"] += 1
	for e in w.dlog.entries:
		match e["type"]:
			"kill":
				r["kills"] += 1
			"nomination":
				r["nominations"] += 1
			"trait_reveal":
				r["reveals"] += 1
			"npc_conversation":
				r["pairs"] += 1
			"npc_share":
				r["shares"] += 1
			"evil_share":
				r["evil_shares"] += 1
			"approach":
				r["approaches"] += 1
			"think":
				if e["data"].get("topic", "") == "lie":
					r["lies"] += 1
	for n in w.npcs:
		if n.max_tier >= 4:
			r["max_tier4"] += 1
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
				"sighting":
					if c.get("phase", -1) == C.NIGHT:
						add = 0.6 if src == "player" else 0.3
				"refusal":
					add = 0.15
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
		"approach":
			return "accept" if rng.randf() < 0.7 else "decline"
		"day":
			if not g.moved:
				return "go " + _pick_location()
			var here: Array = w.npcs_at(g.loc)
			if w.scenes.has(g.loc) and not w.scenes[g.loc]["searched"]:
				return "search"
			var fresh: Array = here.filter(func(n): return n.busy_with == "" and talked.get(n.id, -1) != w.day)
			if fresh.is_empty() and not g.free_move_used:
				for l in w.locations_on(w.loc_block(g.loc)):
					if l != g.loc and not w.npcs_at(l).filter(func(n): return n.busy_with == "").is_empty():
						return "go " + l
			if w.phase == C.EVENING and g.loc == "tavern" and rng.randf() < 0.4:
				return "gossip"
			if not fresh.is_empty():
				var n = fresh[rng.randi_range(0, fresh.size() - 1)]
				talked[n.id] = w.day
				return "talk " + n.id
			if g.loc == "tavern":
				return "gossip"
			return "wait"
		"talk":
			var n = g.talk_with
			var asked: int = 3 - g.questions_left
			if asked == 0:
				return "ask gift"
			if asked == 1:
				return "ask night" if rng.randf() < 0.5 else "ask today"
			var ts = _top_suspect()
			if ts[0] != null and ts[1] >= 0.8 and ts[0] != n:
				for c in g.board:
					if ts[0].id in c.get("subject", []) and c.get("source", "") != ts[0].id and c["kind"] != "vote" and c["kind"] != "secret":
						return "tell %s %d" % [ts[0].id, c["n"]]
			if rng.randf() < 0.25:
				return "ask about " + ["seer", "gravedigger", "archivist", "night watch", "hearthwitch"][rng.randi_range(0, 4)]
			var others: Array = w.living().filter(func(m): return m != n)
			return "ask about " + others[rng.randi_range(0, others.size() - 1)].id
		"meeting":
			var ts = _top_suspect()
			if ts[0] != null and ts[1] >= 1.0 and w.day >= 2 and w.can_nominate("player", ts[0].id) == "":
				if w.meeting["block"] != ts[0].id:
					return "nominate " + ts[0].id
			return "done" if g.town_quiet else "wait"
		"nomination":
			var sc = _scores()
			var nm: Dictionary = w.meeting["pending"]
			var s: float = sc.get(nm["nominee"], 0.0)
			if not g.statement_used and nm["by"] != "player":
				var best_card = 0
				for c in g.board:
					if nm["nominee"] in c.get("subject", []) and c.get("source", "") != nm["nominee"] and c["kind"] in ["info", "sighting", "trace"]:
						best_card = c["n"]
				if s <= -0.3:
					return "defend"
				if s >= 1.0:
					return "accuse %d" % best_card if best_card > 0 else "accuse"
			if w.tools["clemency"] > 0 and nm["by"] != "player" and s <= -0.8 and rng.randf() < 0.5:
				return "clemency"
			return "vote yes" if s >= 0.5 else "vote no"
		"night":
			var sc = _scores()
			if w.tools["ward"] > 0 and w.day >= 2 and rng.randf() < 0.5:
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
	if w.phase == C.EVENING and rng.randf() < 0.5:
		return "tavern"
	var best = "tavern"
	var best_n = -1
	for l in C.LOCATIONS:
		var n: int = w.npcs_at(l).filter(func(m): return m.busy_with == "" and talked.get(m.id, -1) != w.day).size()
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
