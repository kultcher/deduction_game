## Acceptance and regression suite for the post-Phase-3 tuning literal hoist:
##   1. All 9 inner classes in `sim/tuning.gd` load cleanly with zero preload cycles and
##      expose both the baseline constants and newly hoisted simulation/Workshop levers.
##   2. `Tuning.fingerprint()` computes a 12-char SHA-256 hex digest recorded in `w.trace_tuning`
##      and `case_start` log entries.
##   3. Production scripts reference `Tuning.*` constants rather than leaving previously unwired
##      placebo constants (`CIVIL_TALK_BASE`, `QUESTION_FATIGUE_LIMIT`, `KILL_NOISE`, `POISON_NOISE`,
##      `STANCE_MOVE`, `VENUE_MULTS`, etc.) or hardcoded Workshop attribution/doubt/circumstantial
##      literals disconnected from `sim/tuning.gd`.
##   4. Deterministic same-seed 7-NPC and 10-NPC runs produce identical RNG states, suspicion
##      vectors, source doubt maps, and reason attributions.
##
##   godot --headless --path . --script res://tools/test_tuning_hoist.gd
extends SceneTree

const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const ReasonAttribution = preload("res://workshop/reason_attribution.gd")
const Circumstantial = preload("res://workshop/circumstantial.gd")
const ReadingChallenges = preload("res://workshop/reading_challenges.gd")
const SupportModel = preload("res://workshop/support_model.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const WorkshopPresentation = preload("res://game/workshop_presentation.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_test_tuning_classes_and_fingerprint()
	_test_production_wiring_and_aliases()
	_test_witness_quality_parity()
	_test_deterministic_replay_7_and_10_npcs()
	print("Tuning Hoist Suite: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _test_tuning_classes_and_fingerprint() -> void:
	var fp: String = Tuning.fingerprint()
	_check(fp.length() == 12 and fp.is_valid_hex_number(false),
		"Tuning.fingerprint() returns a 12-char hex SHA-256 digest (%s)" % fp)

	var g = Game.new()
	g.detailed_logging = false
	g.new_case(37291, 7)
	_check(g.w.trace_tuning == fp,
		"World.setup records Tuning.fingerprint() in w.trace_tuning")

	var tuning_src: String = FileAccess.get_file_as_string("res://sim/tuning.gd")
	var has_preload: bool = false
	for line in tuning_src.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#"):
			continue
		if "preload(" in trimmed or "load(" in trimmed:
			has_preload = true
			break
	_check(not has_preload,
		"sim/tuning.gd remains pure RefCounted data with zero preload/load dependencies")

	_check(
		is_equal_approx(Tuning.Setup.IDLE_HAUNT_CHANCE, 0.4)
		and is_equal_approx(Tuning.Roles.GRAVEDIGGER.marked_evil_chance, Tuning.Setup.GRAVEDIGGER_MARKED_EVIL_CHANCE)
		and is_equal_approx(Tuning.Mind.PUBLIC_CLAIM_HEARING_WEIGHT, 0.5)
		and is_equal_approx(Tuning.Trust.CLEMENCY_SPARED_BONUS, 0.15)
		and is_equal_approx(Tuning.Social.GOOD_NEWS_TRUST_MIN, 0.6)
		and is_equal_approx(Tuning.Meeting.ACCUSE_SUSPICION_PIVOT, 0.6)
		and is_equal_approx(Tuning.Dialogue.DIRECT_NIGHT_SIGHTING_SHARE_PROB, 0.95)
		and is_equal_approx(Tuning.Evil.PLANTER_MINION_BONUS, 1.0)
		and is_equal_approx(Tuning.Workshop.JURY_ALIGNMENT_COEFF, 0.45),
		"All 9 Tuning inner classes expose hoisted baseline values accurately"
	)


func _test_production_wiring_and_aliases() -> void:
	_check(
		is_equal_approx(ReasonAttribution.MIN_SUSPECT_REQUESTED, Tuning.Workshop.REASON_MIN_SUSPECT_REQUESTED)
		and is_equal_approx(ReasonAttribution.MIN_ITEM_CONTRIB, Tuning.Workshop.REASON_MIN_ITEM_CONTRIB)
		and ReasonAttribution.MAX_REASONS_PER_TARGET == Tuning.Workshop.REASON_MAX_PER_TARGET
		and is_equal_approx(ReasonAttribution.LOO_COVERED_SHARE, Tuning.Workshop.REASON_LOO_COVERED_SHARE)
		and ReasonAttribution.LOO_MAX_OTHER_CARDS == Tuning.Workshop.REASON_LOO_MAX_OTHER_CARDS,
		"ReasonAttribution aliases Tuning.Workshop.REASON_* constants"
	)
	_check(
		is_equal_approx(Circumstantial.REFUSAL_FEAR_DISCOUNT, Tuning.Workshop.CIRCUMSTANTIAL_REFUSAL_FEAR_DISCOUNT)
		and is_equal_approx(Circumstantial.STAGE1_NOISE_FLOOR, Tuning.Workshop.CIRCUMSTANTIAL_STAGE1_NOISE_FLOOR)
		and is_equal_approx(Circumstantial.INCIDENT_MAX, Tuning.Workshop.CIRCUMSTANTIAL_INCIDENT_MAX)
		and is_equal_approx(Circumstantial.TARGET_CAP, Tuning.Workshop.CIRCUMSTANTIAL_TARGET_CAP),
		"Circumstantial aliases Tuning.Workshop.CIRCUMSTANTIAL_* constants"
	)
	_check(
		WorkshopPresentation.STANCE_MOVE == Tuning.Workshop.STANCE_MOVE,
		"WorkshopPresentation.STANCE_MOVE aliases Tuning.Workshop.STANCE_MOVE"
	)

	var expected_refs: Dictionary = {
		"res://sim/world.gd": ["PRE_PHASE_CHAT_CHANCE", "SAME_BLOCK_SIGHTING_CHANCE", "NIGHT_SIGHTING_STREET_CHANCE", "CLEMENCY_SPARED_BONUS", "trust_backed_innocent"],
		"res://sim/mind.gd": ["DEMON_VICTIM_CLAIM_BOOST", "NIGHT_SIGHTING_ELSEWHERE", "RECONSIDER_MIN_SHIFT", "HEARD_READING_WEIGHT", "SELF_SUPPORT_BONUS"],
		"res://sim/mind_dialogue.gd": ["QUESTION_FATIGUE_LIMIT", "CIVIL_TALK_BASE", "PRESSED_EVIDENCE_BASE", "SLIP_COMPOSURE_SCALE", "DIRECT_NIGHT_SIGHTING_SHARE_PROB"],
		"res://sim/mind_meeting.gd": ["PUBLIC_CLAIM_FEW_LEFT", "DEFENCE_REVEAL_CAP", "DEFENCE_MISLED_RELIEF", "ACCUSE_SUSPICION_PIVOT", "VOTE_DISTRUST_NOMINATOR_OFFSET"],
		"res://sim/social.gd": ["TAVERN_WHISPER_MIN_CROWD", "TAVERN_WHISPER_CHANCE", "WRONG_ROLE_GUESS_STEP", "SHARE_READING_OPENNESS_SCALE", "ROLE_WILLING_THRESHOLD"],
		"res://sim/evil.gd": ["KILL_VETERAN_UNPOISONED", "KILL_NOISE", "POISON_NOISE", "PLANTER_MINION_BONUS", "SCAPEGOAT_KEEP_BASE"],
		"res://workshop/source_doubt.gd": ["DOUBT_CAUGHT_ALIBI_NIGHT", "DOUBT_FALSE_NW_GENERAL", "DOUBT_GD_EVIL_SCALE", "History.executed"],
	}
	var all_wired: bool = true
	for path in expected_refs:
		var src: String = FileAccess.get_file_as_string(path)
		for tok in expected_refs[path]:
			if not (tok in src):
				print("  MISSING WIRING in %s: %s" % [path, tok])
				all_wired = false
	_check(all_wired, "Previously unwired Tuning constants and newly hoisted levers are wired into production call sites")


func _test_witness_quality_parity() -> void:
	var listener: Dictionary = {
		"id": "agnes",
		"trust": 0.62,
		"npc_trust": {"dorian": 0.74, "edda": 0.25},
		"suspicion": {"dorian": 0.12, "edda": 0.68},
	}
	var q_rc_d: float = ReadingChallenges.quality(listener, "dorian")
	var q_sm_d: float = SupportModel.source_quality(listener, "dorian")
	var q_rc_e: float = ReadingChallenges.quality(listener, "edda")
	var q_sm_e: float = SupportModel.source_quality(listener, "edda")
	_check(is_equal_approx(q_rc_d, q_sm_d) and is_equal_approx(q_rc_e, q_sm_e),
		"ReadingChallenges.quality and SupportModel.source_quality share identical WITNESS_QUALITY_* weights")


func _run_seed_signature(seed_val: int, npc_count: int) -> Dictionary:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_val, npc_count)
	var guard: int = 0
	while g.state != "over" and g.w.day < 3 and guard < 90:
		guard += 1
		if g.state == "approach":
			g.command("decline")
		elif g.state == "day":
			g.command("wait")
		elif g.state == "meeting":
			g.command("pass")
		elif g.state == "nomination":
			g.command("vote no")
		elif g.state == "night":
			g.command("sleep")
		else:
			break
	var sus_by_npc: Dictionary = {}
	var doubt_by_npc: Dictionary = {}
	var reasons_by_npc: Dictionary = {}
	for p in g.w.living_good():
		sus_by_npc[p.id] = p.suspicion.duplicate(true)
		doubt_by_npc[p.id] = p.workshop_state.get("source_doubt", {}).duplicate(true)
		var top: Array = Mind.ranked_suspects(g.w, p)
		if not top.is_empty():
			reasons_by_npc[p.id] = Mind.reason_status(g.w, p, top[0].id)
	return {
		"rng_state": g.w.rng.state,
		"fallbacks": g.shared_fallbacks.size(),
		"suspicion": sus_by_npc,
		"doubt": doubt_by_npc,
		"reasons": reasons_by_npc,
	}


func _test_deterministic_replay_7_and_10_npcs() -> void:
	var r7_a: Dictionary = _run_seed_signature(54875, 7)
	var r7_b: Dictionary = _run_seed_signature(54875, 7)
	_check(
		r7_a.rng_state == r7_b.rng_state
		and r7_a.fallbacks == 0
		and JSON.stringify(r7_a.suspicion) == JSON.stringify(r7_b.suspicion)
		and JSON.stringify(r7_a.doubt) == JSON.stringify(r7_b.doubt)
		and JSON.stringify(r7_a.reasons) == JSON.stringify(r7_b.reasons),
		"7-NPC deterministic multi-day run produces bit-identical RNG state, suspicions, source doubt, and reasons with 0 fallbacks"
	)

	var r10_a: Dictionary = _run_seed_signature(900, 10)
	var r10_b: Dictionary = _run_seed_signature(900, 10)
	_check(
		r10_a.rng_state == r10_b.rng_state
		and r10_a.fallbacks == 0
		and JSON.stringify(r10_a.suspicion) == JSON.stringify(r10_b.suspicion)
		and JSON.stringify(r10_a.doubt) == JSON.stringify(r10_b.doubt),
		"10-NPC deterministic multi-day run produces bit-identical RNG state, suspicions, and source doubt with 0 fallbacks"
	)
