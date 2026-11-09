## Demon types, step 1 (docs/demon_types_plan.md): the is_demon helper, the script's demon
## types in the solver's view, and the demon's movement likelihood mixed over them.
##   godot --headless --path . --script res://tools/test_demon_types.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const History = preload("res://workshop/live_history.gd")
const Game = preload("res://game/game.gd")
const WorkshopBridge = preload("res://game/workshop_bridge.gd")

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


func _view(demons: Array) -> Dictionary:
	var people: Array = []
	var homes = {"a": "hill", "b": "market", "c": "square", "d": "square", "e": "square", "f": "market", "g": "docks"}
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id.to_upper(), "home": homes[id], "alive": true})
	var events: Array = [
		{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1, "phase": "night"}, "by": ""},
		{"kind": "demon_death", "subjects": ["f"], "at": {"day": 2, "phase": "night"}, "by": ""},
	]
	return {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment",
		"live_activity": true, "timeline": History.from_events(events), "script_demons": demons,
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}


func _sighting(id: String, subject: String, night: int, block: String) -> Dictionary:
	return {"id": id, "fact_id": id, "kind": "sighting", "source": "player", "subject": subject, "subjects": [subject],
		"night": night, "block": block, "data": {}, "role": "", "observed_at": {"day": night, "phase": "night"}}


func _close(x: float, y: float) -> bool:
	return absf(x - y) <= 1e-12 * maxf(1.0, maxf(absf(x), absf(y)))


## A hand-built joint factor with one Scion split: person 0 is executed, person 1 rises.
## `day` puts the minion profile in the split's demon slot; `premix` mixes it in per profile
## (the wrong way) at that share.
func _split_factor(share: float, day: bool, premix: float = 0.0) -> Dictionary:
	var main: Array = []
	var pre: Array = []
	var post: Array = []
	var walk_pre: Array = [0.9, 0.2, 0.5, 0.6]
	var walk_post: Array = [0.3, 0.8, 0.4, 0.7]
	for i in range(4):
		main.append({"good": 0.5, "minion": 0.4, "demon": 0.3 + 0.1 * i})
		var dp: float = 0.25 if day else walk_pre[i]
		var dq: float = 0.15 if day else walk_post[i]
		if premix > 0.0:
			dp = LiveActivity.mix_demon(walk_pre[i], 0.25, premix)
			dq = LiveActivity.mix_demon(walk_post[i], 0.15, premix)
		pre.append({"good": 0.5, "minion": 0.25, "demon": dp})
		post.append({"good": 0.5, "minion": 0.15, "demon": dq})
	var f: Dictionary = {"profiles": main, "scene_tables": [], "scion_splits": [{"exec_day": 2, "executed_idx": 0,
		"alive_demon_mask": 0b1110, "pre_profiles": pre, "post_profiles": post, "pre_scenes": [], "post_scenes": []}]}
	if share > 0.0:
		f["day_demon_share"] = share
	return f


func _run() -> void:
	# The helper.
	_check(C.is_demon("demon") and C.is_demon("daykiller"), "is_demon covers the Demon and the reserved day-killer")
	_check(not C.is_demon("scion") and not C.is_demon("seer"), "is_demon doesn't cover a Scion before it rises, or a town role")
	_check(C.is_day_demon("daykiller") and not C.is_day_demon("demon"), "only the day-killer is a day demon")
	_check(C.ROLES.has("daykiller") and not "daykiller" in C.DEMON_ROLES, "the day-killer (the Hexer) is a role, apart from the walking Demon")

	# The share comes from the script's demons.
	_check(LiveActivity.day_demon_share(_view(["demon"])) == 0.0, "a script with only the Demon has no day-killer share")
	_check(LiveActivity.day_demon_share({}) == 0.0, "a view without script demons has no day-killer share")
	_check(LiveActivity.day_demon_share(_view(["demon", "daykiller"])) == 0.5, "two possible demons: half and half")

	# A seen on both victims' blocks on both kill nights: walker evidence.
	var cards: Array = [_sighting("s1", "a", 1, "docks"), _sighting("s2", "a", 2, "market")]
	var a: Dictionary = _view(["demon"]).people[0]
	var walk: float = LiveActivity._likelihood(_view(["demon"]), cards, a, "demon")
	var still: float = LiveActivity._likelihood(_view(["demon"]), cards, a, "minion")
	var half: float = LiveActivity._likelihood(_view(["demon", "daykiller"]), cards, a, "demon")
	var day_only: float = LiveActivity._likelihood(_view(["daykiller"]), cards, a, "demon")
	_check(walk > 0.0 and still > 0.0, "both likelihoods are positive (walk %.5f, still %.5f)" % [walk, still])
	_check(_close(half, 0.5 * walk + 0.5 * still), "the demon likelihood is the whole-case mixture of walking and staying (%.5f)" % half)
	_check(_close(day_only, still), "with only the day-killer possible, the demon moves like a minion")
	_check(walk > half and half > still, "being seen on the victims' blocks counts for less once the demon might not walk")
	_check(LiveActivity._likelihood(_view(["demon", "daykiller"]), cards, a, "minion") == still, "other alignments don't change")
	_check(LiveActivity._likelihood(_view(["demon", "daykiller"]), cards, a, "good") == LiveActivity._likelihood(_view(["demon"]), cards, a, "good"), "good likelihoods don't change")

	# The joint factor carries the same mixture in its per-person profiles.
	var f0: Array = LiveActivity.factors(_view(["demon"]), cards, {})
	var f_half: Array = LiveActivity.factors(_view(["demon", "daykiller"]), cards, {})
	_check(not f0.is_empty() and not f_half.is_empty(), "both views produce a movement factor")
	if not f0.is_empty() and not f_half.is_empty():
		var ok: bool = true
		for i in range(f0[0].profiles.size()):
			var p0: Dictionary = f0[0].profiles[i]
			var ph: Dictionary = f_half[0].profiles[i]
			ok = ok and ph.good == p0.good and ph.minion == p0.minion and ph.demon == p0.demon
		_check(ok, "factor profiles stay walking with a Hexer possible: C# mixes whole-world scores (step 3)")
		_check(f_half[0].has("hex_kills") and f_half[0].hex_kills.size() == 2 and not f0[0].has("hex_kills"), "with a Hexer possible the factor carries the two kills' hex data")
		_check(f0[0].scene_tables == f_half[0].scene_tables, "trace and scene tables don't change: either demon is at the victim's house")
	var again: Array = LiveActivity.factors(_view(["demon"]), cards, {})
	_check(not again.is_empty() and again[0].profiles == f0[0].profiles, "the factor cache keeps the two views apart")

	# A Scion succession split mixes over one shared type: (1-s)*Wpre*Wpost + s*Dpre*Dpost,
	# with no cross terms from mixing the before and after profiles separately.
	var world: Dictionary = {"evil": 0b0011, "demon": 1}  # 0 = the executed demon, 1 = the Scion who rose
	var f_walk: Dictionary = _split_factor(0.0, false)
	var f_day: Dictionary = _split_factor(0.0, true)
	var f_mix: Dictionary = _split_factor(0.5, false)
	var s_walk: float = LiveActivity.score(world, f_walk)
	var s_day: float = LiveActivity.score(world, f_day)
	var s_mix: float = LiveActivity.score(world, f_mix)
	_check(s_walk > 0.0 and s_day > 0.0 and not _close(s_walk, s_day), "the split scores differ by type (walk %.5f, day %.5f)" % [s_walk, s_day])
	_check(_close(s_mix, 0.5 * s_walk + 0.5 * s_day), "a Scion split mixes after multiplying before and after (%.5f)" % s_mix)
	var f_cross: Dictionary = _split_factor(0.0, false, 0.5)
	_check(not _close(s_mix, LiveActivity.score(world, f_cross)), "pre-mixing the before and after profiles would give a different score")
	_check(LiveActivity.score(world, _split_factor(0.0, false)) == s_walk, "the factor cache keeps shared and walking-only splits apart")

	# The Hexer factor (step 3): one kill, the victim (person 3) a regular of two places.
	# Place 0's regulars are 1 and 3, place 1's are 2 and 3. Person 0 hexed place 0 with 0.8.
	var hk: Array = [{"night": 1, "victim": "d", "places": ["smithy", "tavern"], "alive_mask": 0b1111,
		"reg_masks": [0b1010, 0b1100], "shares": [[0.8, 0.1, 0.0, 0.0], [0.1, 0.0, 0.6, 0.0]]}]
	var base_main: Array = []
	var day_main: Array = []
	for i in range(4):
		base_main.append({"good": 0.5, "minion": 0.4, "demon": 0.3 + 0.1 * i})
		day_main.append({"good": 0.5, "minion": 0.4, "demon": 0.4})
	var fw: Dictionary = {"profiles": base_main, "scene_tables": [], "scion_splits": []}
	var fd: Dictionary = {"profiles": day_main, "scene_tables": [], "scion_splits": []}
	var fm: Dictionary = {"profiles": base_main, "scene_tables": [], "scion_splits": [], "day_demon_share": 0.5, "hex_kills": hk, "hex_floor": 0.15}
	var w0: Dictionary = {"evil": 0b0011, "demon": 0}   # 0 the Hexer, 1 a minion
	var w2: Dictionary = {"evil": 0b0101, "demon": 2}   # 2 the Hexer
	for pair in [[w0, 0], [w2, 2]]:
		var hw: Dictionary = pair[0]
		var d: int = pair[1]
		var evil: int = int(hw.evil)
		var good_alive: int = 0
		for j in range(4):
			if not (evil >> j) & 1:
				good_alive += 1
		var m: float = 0.15
		for p in range(2):
			var regs: int = 0
			for j in range(4):
				if (int(hk[0].reg_masks[p]) >> j) & 1 and not (evil >> j) & 1:
					regs += 1
			if regs > 0:
				m += float(hk[0].shares[p][d]) * good_alive / regs
		var expect: float = 0.5 * LiveActivity.score(hw, fw) + 0.5 * LiveActivity.score(hw, fd) * m
		_check(_close(LiveActivity.score(hw, fm), expect), "the Hexer factor: (1-s)*walk + s*day*hex for demon %d (hex %.3f)" % [d, m])
	var fm_far: Dictionary = fm.duplicate(true)
	fm_far.hex_kills[0].shares = [[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0]]
	_check(LiveActivity.score(w0, fm_far) < LiveActivity.score(w0, fm), "a demon nowhere near the victim's places is a weaker Hexer world")

	# The bridge hands the script's demons to the solver.
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 7)
	var snap: Dictionary = WorkshopBridge.capture(g, [])
	_check(snap.rules.get("demons", []) == ["demon"], "a dealt case's snapshot lists its script's demons")

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
