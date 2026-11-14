## Demon types, step 2 (docs/demon_types_plan.md): daytime presence and Breathstealer by
## presence.
##   godot --headless --path . --script res://tools/test_day_presence.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const DayPresence = preload("res://workshop/day_presence.gd")
const History = preload("res://workshop/live_history.gd")
const Game = preload("res://game/game.gd")
const WorkshopBridge = preload("res://game/workshop_bridge.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Assess = preload("res://workshop/live_assessment.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	call_deferred("_run")


func _ctx(kind: String, subject: String, data: Dictionary) -> Dictionary:
	return {"id": "%s_%s" % [kind, subject], "kind": "context", "context_kind": kind, "subject": subject, "data": data}


func _view(ids: Array, day: int, events: Array = [], watched: Array = []) -> Dictionary:
	var people: Array = []
	for id in ids:
		people.append({"id": id, "name": id.to_upper(), "home": "hill", "alive": true})
	return {"people": people, "day": day, "cards": [], "timeline": History.from_events(events), "watched": watched,
		"script_minions": ["breathstealer"]}


func _run() -> void:
	_test_prior_matches_sim()
	_test_evidence()
	_test_breath_factor()
	_test_hunt_block()
	_test_case_eval_kernel()
	_test_game_records_watch()
	_test_known_haunts()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The idle prior is the sim's own: sample World._choose_idle_location and compare.
func _test_prior_matches_sim() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(4242, 7)
	var n = g.w.npcs[0]
	n.friends = []
	var cards: Array = [_ctx("work", n.id, {"loc": n.work, "work_phases": [] }), _ctx("haunt", n.id, {"locs": n.haunts.duplicate()})]
	var table: Dictionary = DayPresence.build(_view([n.id], 1), cards)
	var worst: float = 0.0
	var draws: int = 20000
	for p in range(3):
		g.w.phase = p
		var counts: Dictionary = {}
		for i in range(draws):
			var l: String = g.w._choose_idle_location(n)
			counts[l] = counts.get(l, 0) + 1
		for l in DayPresence.PLACES + ["home"]:
			var model: float = DayPresence.at(table, n.id, 1, p, l)
			worst = maxf(worst, absf(model - float(counts.get(l, 0)) / draws))
	_check(worst < 0.015, "the idle prior matches the sim's choices with known haunts (worst gap %.4f)" % worst)
	# Unknown haunts: the 0.4 haunt share spreads over the places they could be.
	var t2: Dictionary = DayPresence.build(_view([n.id], 1), [_ctx("work", n.id, {"loc": n.work, "work_phases": []})])
	var s: float = 0.0
	for l in DayPresence.PLACES + ["home"]:
		s += DayPresence.at(t2, n.id, 1, 0, l)
	_check(absf(s - 1.0) < 1e-9 and DayPresence.at(t2, n.id, 1, 0, n.work) < DayPresence.at(t2, n.id, 1, 0, DayPresence.PLACES.filter(func(l): return l != n.work)[0]),
		"with haunts unknown the slot still sums to 1, and the workplace isn't a haunt")


func _test_evidence() -> void:
	var ids: Array = ["a", "b", "c"]
	var cards: Array = [_ctx("work", "a", {"loc": "smithy", "work_phases": [0]}), _ctx("haunt", "b", {"locs": ["tavern", "chapel"]})]
	var t: Dictionary = DayPresence.build(_view(ids, 2), cards)
	_check(DayPresence.at(t, "a", 1, 0, "smithy") == 1.0, "a working phase puts someone at their workplace")
	# The player watched the market on day 1 afternoon and saw only c at the bakery.
	var watched: Array = [{"day": 1, "phase": "afternoon", "block": "market", "at": {"smithy": [], "bakery": ["c"]}}]
	var tw: Dictionary = DayPresence.build(_view(ids, 2, [], watched), cards)
	_check(DayPresence.at(tw, "c", 1, 1, "bakery") == 1.0, "listed on the watched block: certain")
	_check(DayPresence.on_block(tw, "a", 1, 1, "market") == 0.0 and DayPresence.on_block(t, "a", 1, 1, "market") > 0.0,
		"not listed on the watched block: that block is ruled out")
	_check(absf(DayPresence.on_block(tw, "a", 1, 1, "square") - DayPresence.on_block(t, "a", 1, 1, "square") / (1.0 - DayPresence.on_block(t, "a", 1, 1, "market"))) < 1e-9,
		"the rest is renormalized")
	_check(DayPresence.on_block(tw, "a", 1, 2, "market") == DayPresence.on_block(t, "a", 1, 2, "market"), "other phases are untouched")
	# An NPC says b was at the well in the morning of day 2.
	var told: Array = cards + [{"id": "t1", "kind": "location", "source": "c", "subjects": ["b"], "day": 2, "block": "square", "loc": "well", "observed_at": {"day": 2, "phase": "morning"}}]
	var tt: Dictionary = DayPresence.build(_view(ids, 2), told)
	var before: float = DayPresence.at(t, "b", 2, 0, "well")
	var after: float = DayPresence.at(tt, "b", 2, 0, "well")
	_check(after > before and after < 1.0, "an NPC's sighting raises the chance without settling it (%.3f to %.3f)" % [before, after])
	var mine: Array = cards + [{"id": "t2", "kind": "location", "source": "player", "subjects": ["b"], "day": 2, "block": "square", "loc": "well", "observed_at": {"day": 2, "phase": "morning"}}]
	_check(DayPresence.at(DayPresence.build(_view(ids, 2), mine), "b", 2, 0, "well") == 1.0, "the player's own sighting settles it")
	# Seen at home (a visit to their house), not out in public (#118 review).
	var at_home: Array = cards + [{"id": "t3", "kind": "location", "source": "player", "subjects": ["b"], "day": 2, "block": "hill", "at_home": true, "observed_at": {"day": 2, "phase": "morning"}}]
	var th: Dictionary = DayPresence.build(_view(ids, 2), at_home)
	_check(DayPresence.at(th, "b", 2, 0, "home") == 1.0 and DayPresence.on_block(th, "b", 2, 0, "hill") == 0.0, "the player seeing someone at home puts them home, not out on their block")
	var told_home: Array = cards + [{"id": "t4", "kind": "location", "source": "c", "subjects": ["b"], "day": 2, "block": "hill", "at_home": true, "observed_at": {"day": 2, "phase": "morning"}}]
	_check(DayPresence.at(DayPresence.build(_view(ids, 2), told_home), "b", 2, 0, "home") > DayPresence.at(t, "b", 2, 0, "home"), "an NPC's word that they were home raises the home chance")
	# Who a watch ruled off the block.
	var ex: Dictionary = DayPresence.exclusions(_view(ids, 2, [], watched), cards)
	_check(ex.has("a:1:1:market") and ex.has("b:1:1:market") and not ex.has("c:1:1:market"), "exclusions: everyone not listed on the watched block")
	# The Hexer's seek share never goes to a place a watch ruled them off (#125 review).
	var LA = load("res://workshop/live_activity.gd")
	var hv: Dictionary = _view(["v", "s", "x"], 2, [{"kind": "demon_death", "subjects": ["v"], "at": {"day": 1, "phase": "night"}, "by": ""}])
	hv.people[0]["work"] = "smithy"
	hv.people[0]["work_phases"] = [0]
	hv["script_demons"] = ["demon", "daykiller"]
	var hk_free: Array = LA.hex_kills(hv, [], ["v", "s", "x"])
	var hv_w: Dictionary = hv.duplicate(true)
	hv_w["watched"] = [{"day": 1, "phase": "morning", "block": C.loc_block("smithy"), "at": {"smithy": ["v"]}}]
	var hk_watched: Array = LA.hex_kills(hv_w, [], ["v", "s", "x"])
	var share_free: float = float(hk_free[0].shares[0][1]) if not hk_free.is_empty() else -1.0
	var share_watched: float = float(hk_watched[0].shares[0][1]) if not hk_watched.is_empty() else -1.0
	_check(share_free > 0.0 and share_watched >= 0.0 and share_watched < 0.5 * share_free, "a suspect watched off the victim's work block that morning gets no seek share there (%.3f to %.3f)" % [share_free, share_watched])
	var hv_h: Dictionary = hv.duplicate(true)
	var seen_home: Array = [{"id": "h1", "kind": "location", "source": "player", "subjects": ["s"], "day": 1, "block": "hill", "at_home": true, "observed_at": {"day": 1, "phase": "morning"}}]
	var hk_home: Array = LA.hex_kills(hv_h, seen_home, ["v", "s", "x"])
	var share_home: float = float(hk_home[0].shares[0][1]) if not hk_home.is_empty() else -1.0
	_check(share_home >= 0.0 and share_home < 0.5 * share_free, "a suspect the player saw at home that morning gets no seek share either (%.3f)" % share_home)
	# The dead are nowhere.
	var dead_view: Dictionary = _view(ids, 2, [{"kind": "demon_death", "subjects": ["c"], "at": {"day": 1, "phase": "night"}, "by": ""}])
	_check(DayPresence.on_block(DayPresence.build(dead_view, cards), "c", 2, 0, "square") == 0.0, "someone killed in the night is nowhere the next day")


func _test_breath_factor() -> void:
	# v1, v2, v3 silenced on days 1-3. The player watched the victims' block in the evening
	# each day and saw the victim with m; x was never there.
	var ids: Array = ["m", "x", "y", "v1", "v2", "v3"]
	var events: Array = []
	var watched: Array = []
	var cards: Array = []
	for d in range(1, 4):
		var v: String = "v%d" % d
		events.append({"kind": "silenced", "subjects": [v], "at": {"day": d, "phase": "evening"}, "by": "town"})
		watched.append({"day": d, "phase": "evening", "block": "docks", "at": {"wharf": [v, "m"], "mill": []}})
	var f: Dictionary = DayPresence.breath_factor(_view(ids, 3, events, watched), cards)
	_check(not f.is_empty() and f.silencings.size() == 3, "three silencings make a factor")
	var w: PackedFloat64Array = f.get("weights", PackedFloat64Array())
	_check(w.size() == 6 and w[0] > w[1] and w[0] > w[2], "the one person near every silencing weighs most (m %.3f, x %.3f, y %.3f)" % [w[0], w[1], w[2]])
	_check(w[3] == 0.0 and w[4] == 0.0 and w[5] == 0.0, "a victim can't be the silencer of their own silencing")
	var f1: Dictionary = DayPresence.breath_factor(_view(ids, 3, events.slice(0, 1), watched), cards)
	var one: float = f1.weights[0] / maxf(f1.weights[1], 1e-12)
	var three: float = w[0] / maxf(w[1], 1e-12)
	_check(three > one * 1.5, "the evidence builds up across silencings (m:x %.2f after one, %.2f after three)" % [one, three])
	# Per world: the mean over the world's minions, mixed with err.
	var err: float = Tuning.Workshop.DEFAULT_ERR
	var with_m: float = DayPresence.breath_score({"evil": 0b011, "demon": 1}, f, err)  # m the minion, x the Demon
	var with_x: float = DayPresence.breath_score({"evil": 0b011, "demon": 0}, f, err)  # x the minion, m the Demon
	_check(absf(with_m - ((1.0 - err) * w[0] + err)) < 1e-12 and with_m > with_x, "a world where m is the minion scores higher")
	var two: float = DayPresence.breath_score({"evil": 0b111, "demon": 2}, f, err)
	_check(absf(two - ((1.0 - err) * 0.5 * (w[0] + w[1]) + err)) < 1e-12, "two minions: either could be the Breathstealer")
	var off: Dictionary = _view(ids, 3, events, watched)
	off["script_minions"] = ["poisoner"]
	_check(DayPresence.breath_factor(off, cards).is_empty(), "no factor when the script has no Breathstealer")
	_check(DayPresence.breath_factor(_view(ids, 3, [], watched), cards).is_empty(), "no factor without a silencing")


## The hunting Breathstealer (Nov 14): tied to a place, it is there; free, it can reach any
## block its record doesn't rule out, with HUNT_REACH.
func _test_hunt_block() -> void:
	var at := func(loc: String) -> PackedFloat64Array:
		var d := PackedFloat64Array()
		d.resize(DayPresence.SLOTS)
		d[DayPresence.PLACES.find(loc)] = 1.0
		return d
	var spread := PackedFloat64Array()
	spread.resize(DayPresence.SLOTS)
	for i in DayPresence.SLOTS:
		spread[i] = 1.0 / float(DayPresence.SLOTS)
	var off_market: PackedFloat64Array = spread.duplicate()
	for loc in ["smithy", "bakery"]:
		off_market[DayPresence.PLACES.find(loc)] = 0.0
	var table: Dictionary = {"v": {"1:0": at.call("bakery")}, "co": {"1:0": at.call("smithy")}, "away": {"1:0": at.call("wharf")},
		"free": {"1:0": spread}, "seen_off": {"1:0": off_market}}
	_check(is_equal_approx(DayPresence.hunt_block(table, "co", "v", 1, 0), 1.0), "working on the victim's block: there")
	_check(is_zero_approx(DayPresence.hunt_block(table, "away", "v", 1, 0)), "working on another block: an alibi")
	_check(is_equal_approx(DayPresence.hunt_block(table, "free", "v", 1, 0), DayPresence.HUNT_REACH), "free: could have hunted the victim down (%.2f)" % DayPresence.hunt_block(table, "free", "v", 1, 0))
	_check(is_zero_approx(DayPresence.hunt_block(table, "seen_off", "v", 1, 0)), "free but ruled off the victim's block: an alibi")
	_check(DayPresence.hunt_block(table, "free", "v", 1, 0) > DayPresence.same_block(table, "free", "v", 1, 0), "a free person counts for more than an ordinary wander would give")
	# An NPC's (soft) report moves a free person's reach (Codex on #157): seen at the bakery,
	# up; seen at the wharf, down. The prior is the spread; the report reweights it.
	var soft := func(loc: String) -> PackedFloat64Array:
		var d: PackedFloat64Array = spread.duplicate()
		for i in DayPresence.SLOTS:
			var fits: bool = i < DayPresence.HOME and DayPresence.place_block(i) == DayPresence.place_block(DayPresence.PLACES.find(loc))
			d[i] *= DayPresence.TRUST if fits else (1.0 - DayPresence.TRUST)
		var t: float = 0.0
		for x in d:
			t += x
		for i in d.size():
			d[i] /= t
		return d
	var told: Dictionary = {"v": {"1:0": at.call("bakery")}, "near": {"1:0": soft.call("smithy")}, "far": {"1:0": soft.call("wharf")}, "free": {"1:0": spread}}
	var prior: Dictionary = {"near": {"1:0": spread}, "far": {"1:0": spread}, "free": {"1:0": spread}}
	var r_near: float = DayPresence.hunt_block(told, "near", "v", 1, 0, prior)
	var r_far: float = DayPresence.hunt_block(told, "far", "v", 1, 0, prior)
	var r_free: float = DayPresence.hunt_block(told, "free", "v", 1, 0, prior)
	_check(is_equal_approx(r_free, DayPresence.HUNT_REACH) and r_near > r_free and r_far < r_free, "a reported sighting near the victim raises a free person's reach, one elsewhere lowers it (%.2f / %.2f / %.2f)" % [r_near, r_free, r_far])


## The C# kernel (CaseEval move kind 3) agrees with the GDScript reference, and the solver
## carries the watch record and builds the factor.
func _test_case_eval_kernel() -> void:
	var SolverBackend = load("res://workshop/solver_backend.gd")
	var b = SolverBackend._bridge()
	var weights := PackedFloat64Array([2.5, 0.25, 1.0, 0.0, 0.75])
	var err: float = Tuning.Workshop.DEFAULT_ERR
	var h: int = int(b.CaseEvalRegisterPresenceWeights(weights))
	var ok: bool = true
	for world in [{"evil": 0b00011, "demon": 1}, {"evil": 0b00011, "demon": 0}, {"evil": 0b10101, "demon": 2}, {"evil": 0b01000, "demon": 3}, {"evil": 0b00110}]:
		var gd: float = DayPresence.breath_score(world, {"weights": weights}, err)
		var cs: float = float(b.CaseEvalPresenceScore(SolverBackend.pack_world(world), h, err))
		ok = ok and absf(gd - cs) < 1e-12
	_check(ok, "the C# presence score matches the GDScript reference")

	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 7)
	var victim = g.w.living_good()[0]
	g.w.public_event("silenced", [victim.id], "town")
	g.watched = [{"day": 1, "phase": "evening", "block": "square", "at": {"tavern": [victim.id, g.w.npcs[1].id], "well": []}}]
	var snap: Dictionary = WorkshopBridge.capture(g, [])
	_check(snap.get("watched", []) == g.watched, "the snapshot carries the watch record")
	var view: Dictionary = Assess.prepare(snap).get("view", {})
	_check(view.get("watched", []) == g.watched, "the solver's view carries the watch record")
	if not view.is_empty():
		_check(not DayPresence.breath_factor(view, view.get("cards", [])).is_empty(), "a dealt case with a silencing builds the factor")


## Regulars know regulars: an NPC's reasoning holds its own haunts and anyone's haunt that is
## its workplace or one of its haunts, and no other haunt.
func _test_known_haunts() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 7)
	var n = g.w.living_good()[0]
	var spots: Array = [n.work] + n.haunts
	var expect: Dictionary = {}
	for o in g.w.npcs:
		for h in o.haunts:
			if o.id == n.id or h in spots:
				expect["%s:%s" % [o.id, h]] = true
	var view: Dictionary = Assess.prepare(WorkshopBridge.capture(g, [], n.id)).get("view", {})
	var got: Dictionary = {}
	var regular: Dictionary = view.get("regular_haunts", {})
	for pid in regular:
		for h in regular[pid]:
			got["%s:%s" % [pid, h]] = true
	_check(expect.size() > n.haunts.size(), "the listener shares a spot with someone's haunt (%d known)" % expect.size())
	_check(got == expect, "the listener's view holds exactly the haunts a regular would know (%d vs %d)" % [got.size(), expect.size()])
	var player_view: Dictionary = Assess.prepare(WorkshopBridge.capture(g, [])).get("view", {})
	_check(player_view.get("regular_haunts", {}).is_empty(), "the Demonologist's own view gets no haunts for free")
	_check(not view.get("cards", []).any(func(c): return c.get("context_kind", "") == "haunt"), "regular knowledge isn't evidence: no haunt cards in the listener's view")
	# The trace model counts them as discovered.
	var TraceSolver = load("res://workshop/trace_solver.gd")
	var profs: Dictionary = TraceSolver.discovered_profiles(view)
	var other: String = ""
	for pid in regular:
		if pid != n.id:
			other = pid
	_check(other != "" and profs[other].known_haunts == regular[other].slice(0, 2), "the trace model knows a fellow regular's haunt")


func _test_game_records_watch() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 7)
	g.start_day() if g.has_method("start_day") else null
	var before: int = g.watched.size()
	g.command("go smithy")
	_check(g.watched.size() == before + 1, "going somewhere in a day phase records a watch")
	if g.watched.size() > before:
		var e: Dictionary = g.watched[-1]
		var listed: Array = []
		for l in e.at:
			listed.append_array(e.at[l])
		var truth: Array = []
		for l in C.LOCATIONS:
			if C.LOCATIONS[l].block == e.block:
				truth.append_array(g.w.npcs_at(l).map(func(x): return x.id))
		listed.sort()
		truth.sort()
		_check(e.block == "market" and listed == truth, "the watch lists everyone at the block's public places")
