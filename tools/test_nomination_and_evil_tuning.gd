extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")

var checks: int = 0
var fails: int = 0

func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		push_error("FAIL: " + msg)

func _game(seed_val: int = 2601, size: int = 7):
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = true
	g.new_case(seed_val, size)
	for p in g.w.npcs:
		p.cleared = {}
		p.consensus_pressure = {}
		for id in p.suspicion:
			p.suspicion[id] = 0.1
	return g

func _init() -> void:
	_test_baseline_slope_and_confidence_scaling()
	_test_failed_vote_cooloff_pivot_and_endgame_taper()
	_test_evil_scapegoat_readiness_and_cooloff()
	if fails == 0:
		print("test_nomination_and_evil_tuning: ALL %d CHECKS PASSED" % checks)
		quit(0)
	else:
		printerr("test_nomination_and_evil_tuning: %d/%d FAILED" % [fails, checks])
		quit(1)

func _test_baseline_slope_and_confidence_scaling() -> void:
	var g = _game(2601, 7)
	var w = g.w
	var n = w.living_good()[0]
	var target = w.living_good()[1]
	w.day = 1
	w.meeting = {"block": "", "nominated": []}
	n.traits["confidence"] = 0.5
	# Day 1 at 0.5 confidence and 0 dead -> threshold = 0.65 - 0.05 = 0.60
	n.suspicion[target.id] = 0.58
	_check(Mind._good_nomination(w, n, w.meeting, "") == null, "Day 1 mid-confidence NPC holds fire at 0.58 (< 0.60 threshold)")
	# Raising confidence to 0.90 lowers threshold by 0.20 * (0.4 * 2.0) = 0.16 -> 0.44!
	n.traits["confidence"] = 0.90
	var bold_nom = Mind._good_nomination(w, n, w.meeting, "")
	_check(bold_nom != null and bold_nom["nominee"] == target.id, "Day 1 high-confidence (0.90) NPC nominates at 0.58 (threshold 0.44)")

	# Verify threshold_parts sum matches threshold exactly across days
	n.traits["confidence"] = 0.65
	w.day = 4
	Mind._good_nomination(w, n, w.meeting, "")
	var evs: Array = w.dlog.trace_events().filter(func(e): return e.type == "decision" and e.data.kind == "nomination" and e.data.stage == "evaluation" and e.actor == n.id)
	_check(not evs.is_empty(), "nomination evaluation trace emitted")
	if not evs.is_empty():
		var det: Dictionary = evs[-1].data.details
		var psum: float = 0.0
		for v in det.threshold_parts.values():
			psum += float(v)
		_check(is_equal_approx(psum, float(det.threshold)), "nomination threshold_parts sum reproduces exact threshold")

func _test_failed_vote_cooloff_pivot_and_endgame_taper() -> void:
	var g = _game(2602, 8)
	var w = g.w
	var nominator = w.living_good()[0]
	var bystander = w.living_good()[1]
	var target_a = w.living_good()[2]
	var target_b = w.living_good()[3]
	nominator.traits["confidence"] = 0.5
	bystander.traits["confidence"] = 0.5
	w.day = 1
	# Record a 1/5 belly-flop vote on target_a yesterday (Day 1) nominated by `nominator`
	w.public_event("vote", [target_a.id], "town", {
		"nominee": target_a.id, "nominator": nominator.id,
		"yes": [nominator.id], "no": [bystander.id], "player_yes": false,
		"count": 1, "threshold": 5, "outcome": "fails",
	})
	w.day = 2
	w.meeting = {"block": "", "nominated": []}
	var self_cool: float = Mind.nomination_cooloff(w, nominator.id, target_a.id)
	var room_cool: float = Mind.nomination_cooloff(w, bystander.id, target_a.id)
	_check(is_equal_approx(self_cool, Tuning.Meeting.NOMINATION_COOLOFF_SELF * 0.8), "self-nominator cooloff scales by vote shortfall (0.28 * 0.8 = 0.224)")
	_check(is_equal_approx(room_cool, Tuning.Meeting.NOMINATION_COOLOFF_ROOM * 0.8) and room_cool < self_cool, "bystander room-read cooloff is lighter than self-nominator cooloff")

	# Underlying suspicion and voting are completely untouched by nomination cooloff
	nominator.suspicion[target_a.id] = 0.62
	_check(is_equal_approx(Mind.susp(nominator, target_a.id), 0.62), "nomination cooloff never alters underlying suspicion")
	_check(Mind.vote(w, nominator, target_a.id, "player", false, "", 0) == true, "nominator still votes YES on target_a if someone else nominates them")
	# On Day 2, threshold is 0.55; 0.62 - 0.224 = 0.396 < 0.55 -> nominator holds back on target_a alone!
	_check(Mind._good_nomination(w, nominator, w.meeting, "") == null, "after a 1/5 flop, nominator bides their time at 0.62 suspicion instead of re-pushing target_a")

	# If nominator ALSO suspects target_b at 0.57 (>= 0.55), nominator pivots to target_b!
	nominator.suspicion[target_b.id] = 0.57
	var pivot_nom = Mind._good_nomination(w, nominator, w.meeting, "")
	_check(pivot_nom != null and pivot_nom["nominee"] == target_b.id, "nominator on cooloff for #1 suspect pivots cleanly to viable #2 suspect")

	# Cooloff expires after 1 day: on Day 3 (with no Day 2 vote), Day 1's flop returns 0.0.
	w.day = 3
	_check(is_zero_approx(Mind.nomination_cooloff(w, nominator.id, target_a.id)), "failed-vote cooloff applies only to the next day's meeting")

	# Record a close 4/5 near-miss on Day 3, then advance to Day 4 (yesterday == 3):
	# minimal cooloff (0.28 * 0.2 = 0.056) allows re-push at 0.53 (>= 0.45 + 0.056).
	w.public_event("vote", [target_a.id], "town", {
		"nominee": target_a.id, "nominator": nominator.id,
		"yes": [nominator.id], "no": [], "player_yes": false,
		"count": 4, "threshold": 5, "outcome": "fails",
	})
	w.day = 4
	w.meeting = {"block": "", "nominated": []}
	nominator.suspicion[target_b.id] = 0.1
	nominator.suspicion[target_a.id] = 0.53
	var retry_nom = Mind._good_nomination(w, nominator, w.meeting, "")
	_check(retry_nom != null and retry_nom["nominee"] == target_a.id, "after a close 4/5 near-miss yesterday, nominator is willing to try again today")

	# Endgame (<= 4 living) disables nomination cooloff completely even on the very next day.
	var alive_list: Array = w.living()
	for i in range(4, alive_list.size()):
		alive_list[i].alive = false
	_check(is_zero_approx(Mind.nomination_cooloff(w, nominator.id, target_a.id)), "endgame (<= 4 living) disables nomination cooloff completely")

func _test_evil_scapegoat_readiness_and_cooloff() -> void:
	var g = _game(2603, 7)
	var w = g.w
	var demon = w.demon()
	var minions: Array = w.npcs.filter(func(p): return p.is_evil() and p != demon)
	var minion = minions[0]
	var sg = w.living_good()[0]
	w.evil_plan["scapegoat"] = sg.id
	w.evil_plan["bluffs"][minion.id] = "seer"
	w.day = 2
	w.meeting = {"block": "", "nominated": [], "nominators": []}
	minion.traits["confidence"] = 0.6
	# Minion has an unshared fake Seer reading implicating sg AND made one public accusation:
	# Organic good-only Evil.public_heat stays 0.15, while Evil.scapegoat_readiness counts both!
	minion.info_log = [{"day": 1, "role": "seer", "data": {"pair": [sg.id, demon.id], "yes": true}, "text": "Fake reading", "true": false, "fake": true, "shared": false}]
	w.public_event("accusation", [sg.id], minion.id)
	_check(is_equal_approx(Evil.public_heat(w, sg), 0.15), "Evil.public_heat still excludes Evil's own talk for organic momentum checks")
	var ready: Dictionary = Evil.scapegoat_readiness(w, minion, sg)
	_check(ready["score"] > 0.35 and ready["pocket_ammo"] > 0.0, "Evil.scapegoat_readiness counts Evil's public setup and unshared pocket frame")
	var ev_nom = Mind._evil_nomination(w, minion, w.meeting, "")
	_check(ev_nom != null and ev_nom["nominee"] == sg.id, "Minion proactively nominates scapegoat on Day 2 using its own frame setup")

	# If Evil's scapegoat nomination belly-flopped 0/4 on Day 2, Day 3 readiness drops on cooloff!
	w.public_event("vote", [sg.id], "town", {
		"nominee": sg.id, "nominator": minion.id,
		"yes": [], "no": [sg.id], "player_yes": false,
		"count": 0, "threshold": 4, "outcome": "fails",
	})
	w.day = 3
	var cooled: Dictionary = Evil.scapegoat_readiness(w, minion, sg)
	_check(cooled["cooloff"] > 0.20 and cooled["score"] < ready["score"], "Evil.scapegoat_readiness applies cooloff after a flopped scapegoat vote")
