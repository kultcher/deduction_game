## The read-everything gap (docs: Project claude/belief-model-direction-2026-11-10.md, Phase 0).
## For real listener states, compares each good mind's P(evil) and P(Demon) under its
## bounded view against the same mind reading every held card (Reasoner.unlimited_cards),
## and attributes the largest gap to card kinds: each kind the bounded view left unread is
## added back alone (Reasoner.always_keep_kinds) and the share of the gap it closes recorded.
##
## godot --headless --path . --script res://tools/read_everything_gap.gd -- --log logs/case_12926.jsonl --days 2,3,4 [--out f.jsonl]
## godot --headless --path . --script res://tools/read_everything_gap.gd -- --seed 900 --size 7 --days 3,4 [--out f.jsonl]
##
## States are taken at the first command of each listed day (morning). Taking a view re-runs
## the mind's ordinary refresh; the bounded view is re-taken last, so the replay continues
## from the same beliefs.
extends SceneTree
const Game = preload("res://game/game.gd")
const Replay = preload("res://tools/log_replay.gd")
const Views = preload("res://tools/belief_views.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Caches = preload("res://workshop/caches.gd")

var rows: Array = []
var out_file: FileAccess = null
var days_wanted: Array = []
var done_days: Dictionary = {}
var label: String = ""

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var log_path: String = ""
	var seed_v: int = -1
	var size: int = 7
	var out_path: String = ""
	var i: int = 0
	while i < args.size():
		match args[i]:
			"--log": log_path = args[i + 1]; i += 1
			"--seed": seed_v = int(args[i + 1]); i += 1
			"--size": size = int(args[i + 1]); i += 1
			"--days":
				for d in str(args[i + 1]).split(","):
					days_wanted.append(int(d))
				i += 1
			"--out": out_path = args[i + 1]; i += 1
		i += 1
	if out_path != "":
		out_file = FileAccess.open(out_path, FileAccess.WRITE)
	if log_path != "":
		label = log_path.get_file().get_basename()
		var events: Array = Replay.load_events(log_path)
		var res: Dictionary = Replay.replay(events, 1 << 30, {"before_command": func(g, e): _maybe_measure(g)})
		var votes: Array = Replay.votes(events, res.g)
		print("REPLAY diverged=%s votes_match=%s" % [res.diverged, votes[0] == votes[1]])
	else:
		label = "seed_%d_%d" % [seed_v, size]
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(seed_v, size)
		var guard: int = 0
		while g.state != "over" and guard < 400 and done_days.size() < days_wanted.size():
			guard += 1
			_maybe_measure(g)
			match g.state:
				"approach": g.command("decline")
				"day": g.command("wait")
				"meeting": g.command("done" if g.town_quiet else "wait")
				"talk": g.command("bye")
				"nomination": g.command("vote no")
				"night": g.command("sleep")
				_: break
	if out_file != null:
		out_file.close()
	quit()

func _maybe_measure(g) -> void:
	var d: int = g.w.day
	if d in days_wanted and not done_days.has(d) and g.state == "day":
		done_days[d] = true
		for n in g.w.living_good():
			var r: Dictionary = _measure(g, n)
			if not r.is_empty():
				rows.append(r)
				if out_file != null:
					out_file.store_line(JSON.stringify(r))
				print("GAP %s day %d %s insight %.2f read %d/%d  evil mean %.3f max %.3f (%s)  demon mean %.3f max %.3f (%s)  closes: %s" % [label, d, n.id,
					float(n.traits.insight), r.read, r.held, r.evil_mean, r.evil_max, r.evil_max_who, r.demon_mean, r.demon_max, r.demon_max_who, r.closes])

func _view(g, n, unlimited: bool, keep_kinds: Array = []) -> Dictionary:
	Reasoner.unlimited_cards = unlimited
	Reasoner.always_keep_kinds = keep_kinds
	Reasoner.capture_attention = true
	Reasoner.captured = []
	Caches.clear_all()
	var v: Dictionary = Views.mind(g, n, 1)
	var cap: Array = Reasoner.captured.filter(func(c): return c.listener == n.id)
	Reasoner.capture_attention = false
	Reasoner.captured = []
	Reasoner.unlimited_cards = false
	Reasoner.always_keep_kinds = []
	# A refresh prepares several conclusions; the belief view is the widest one.
	var widest: Dictionary = {}
	for c in cap:
		if widest.is_empty() or int(c.pool) > int(widest.pool):
			widest = c
	v["considered"] = widest.get("considered", [])
	v["pool"] = int(widest.get("pool", 0))
	return v

func _gaps(a: Dictionary, b: Dictionary, key: String, me: String) -> Dictionary:
	var sum: float = 0.0
	var n: int = 0
	var mx: float = 0.0
	var who: String = ""
	for id in b.get(key, {}):
		if id == me or not a.get(key, {}).has(id):
			continue
		var gap: float = absf(float(a[key][id]) - float(b[key][id]))
		sum += gap
		n += 1
		if gap > mx:
			mx = gap
			who = id
	return {"mean": sum / maxi(1, n), "max": mx, "who": who}

func _measure(g, n) -> Dictionary:
	var bounded: Dictionary = _view(g, n, false)
	var full: Dictionary = _view(g, n, true)
	if bounded.get("p_evil", {}).is_empty() or full.get("p_evil", {}).is_empty():
		_view(g, n, false)
		return {}
	var ev: Dictionary = _gaps(bounded, full, "p_evil", n.id)
	var dm: Dictionary = _gaps(bounded, full, "demon", n.id)
	# Which kinds did the bounded view leave unread, and how much of the largest P(evil)
	# gap does reading each kind alone close?
	var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
	var view: Dictionary = plan.get("prepared", {}).get("view", {})
	var kinds: Dictionary = {}
	for c in view.get("cards", []):
		if c.id not in bounded.considered:
			var k: String = str(c.get("kind", ""))
			kinds[k] = int(kinds.get(k, 0)) + 1
			if k == "report":
				var kr: String = "report:" + str(c.get("role", ""))
				kinds[kr] = int(kinds.get(kr, 0)) + 1
	var closes: Dictionary = {}
	if ev.who != "" and ev.max > 0.01:
		var base_gap: float = ev.max
		for k in kinds:
			var with_k: Dictionary = _view(g, n, false, [k])
			var gap_k: float = absf(float(with_k.p_evil.get(ev.who, 0.0)) - float(full.p_evil[ev.who]))
			closes[k] = snappedf((base_gap - gap_k) / base_gap, 0.01)
	_view(g, n, false) # leave the mind on its ordinary bounded beliefs
	return {"label": label, "day": g.w.day, "listener": n.id, "insight": float(n.traits.insight), "read": bounded.considered.size(), "held": bounded.pool,
		"evil_mean": ev.mean, "evil_max": ev.max, "evil_max_who": ev.who, "evil_max_is_evil": g.w.by_id[ev.who].is_evil() if ev.who != "" else false,
		"demon_mean": dm.mean, "demon_max": dm.max, "demon_max_who": dm.who,
		"bounded_p": bounded.p_evil.get(ev.who, 0.0) if ev.who != "" else 0.0, "full_p": full.p_evil.get(ev.who, 0.0) if ev.who != "" else 0.0,
		"unread_kinds": kinds, "closes": closes,
		"bounded_correct": _team_score(g, bounded, n.id), "full_correct": _team_score(g, full, n.id)}

## Mean P(evil) on the truly evil minus on the truly good: who reads the town better.
func _team_score(g, v: Dictionary, me: String) -> float:
	var e: Array = []
	var gd: Array = []
	for id in v.get("p_evil", {}):
		if id == me or not g.w.by_id.has(id) or not g.w.by_id[id].alive:
			continue
		(e if g.w.by_id[id].is_evil() else gd).append(float(v.p_evil[id]))
	var me_e: float = 0.0
	for x in e: me_e += x
	var me_g: float = 0.0
	for x in gd: me_g += x
	return me_e / maxi(1, e.size()) - me_g / maxi(1, gd.size())
