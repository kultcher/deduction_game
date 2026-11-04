## After a hanging: Gravedigger readings move the player's rapport once, the Revenant's
## curse pins the hanged Revenant without touching the outside layer, mourners resent
## those who hanged a trusted friend (fading, citable, cleared once shown evil), and a
## soul freed from the curse is restored from before it turned.
## Gathered from the Legacy Purge phase 2b suite on 2026-11-04.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_test_gravedigger_rapport()
	_test_revenant_curse()
	_test_grief_resentments()
	_test_freed_soul()
	print("Execution aftermath: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _clean_game(seed_val: int, size: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_val, size)
	for p in g.w.npcs:
		for m in [p, p.shadow]:
			if m == null:
				continue
			m.info_log = []
			m.applied_info = 0
			m.known_claims = {}
			m.beliefs = []
			m.hearsay = []
			m.ledger = {}
			m.resentments = []
			m.settled_execution_rapport = {}
			m.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
			for id in m.suspicion:
				m.suspicion[id] = 0.1
			if not m.is_evil():
				Mind.refresh_beliefs(g.w, m, " (clean)")
	return g


func _test_gravedigger_rapport() -> void:
	var g = _clean_game(97930, 10)
	var w = g.w
	w.day = 2
	var goods: Array = w.living_good()
	var listener = goods[0]
	var gd_npc = goods[1]
	var ex_friend = goods[2]
	var ex_minion = w.evil_team()[0]

	ex_friend.alive = false
	ex_friend.death_day = 1
	ex_friend.death_cause = "executed"
	w.day = 1
	w.public_event("execution", [ex_friend.id], "town")
	w.executions.append({"day": 1, "id": ex_friend.id, "nominator": "player", "yes": [gd_npc.id], "no": [listener.id], "player_yes": true, "player_nominated": true})
	w.day = 2

	listener.friends = [ex_friend.id]
	listener.npc_trust[gd_npc.id] = 0.75
	var t0: float = listener.trust
	var gd_good_entry: Dictionary = {"day": 1, "phase": C.NIGHT, "role": "gravedigger", "data": {"executed": ex_friend.id, "role": "surveyor"}, "true": true, "shared": true, "text": "Was Surveyor"}

	# 2. Hearing the reading via Mind.apply_info updates shared beliefs first, then docks -0.06 rapport once.
	Mind.apply_info(w, listener, gd_npc, gd_good_entry, 0.8)
	_check(is_equal_approx(listener.trust, t0 - 0.06), "post-refresh execution handler docks -0.06 rapport when hanged friend is shown innocent (%.3f -> %.3f)" % [t0, listener.trust])
	# Re-hearing never double-docks.
	w.on_execution_reading_heard(listener, gd_npc, gd_good_entry, 1.0)
	_check(is_equal_approx(listener.trust, t0 - 0.06), "settled_execution_rapport prevents duplicate rapport adjustments for the same execution")

	# 3. Evil execution vindication boosts rapport based on listener Insight.
	ex_minion.alive = false
	ex_minion.death_day = 2
	ex_minion.death_cause = "executed"
	w.public_event("execution", [ex_minion.id], "town")
	w.executions.append({"day": 2, "id": ex_minion.id, "nominator": "player", "yes": [gd_npc.id], "no": [], "player_yes": true, "player_nominated": true})
	w.day = 3
	var t1: float = listener.trust
	var gd_evil_entry: Dictionary = {"day": 2, "phase": C.NIGHT, "role": "gravedigger", "data": {"executed": ex_minion.id, "role": ex_minion.role if C.ROLES[ex_minion.role]["align"] == "evil" else "poisoner"}, "true": true, "shared": true, "text": "Was Poisoner"}
	Mind.apply_info(w, listener, gd_npc, gd_evil_entry, 0.8)
	var expected_boost: float = 0.08 + 0.06 * Mind.trait_of(listener, "insight")
	_check(is_equal_approx(listener.trust, minf(listener.trust_cap, t1 + expected_boost)),
		"post-refresh execution handler rewards player rapport when hanged suspect is shown evil")


func _test_revenant_curse() -> void:
	var g = _clean_game(54875, 10)
	var w = g.w
	var rv = w.evil_team()[0]
	rv.role = "revenant"
	rv.alignment = "evil"
	var goods: Array = w.living_good()
	var voters: Array = [goods[0].id, goods[1].id, goods[2].id]
	var observer = goods[3]
	w.day = 2
	w.phase = C.EVENING
	w.totem = {"loc": "well", "day": 2, "owner": rv.id, "material": rv.home_block}
	w.open_meeting()
	w.public_event("vote", [rv.id], "town", {"nominee": rv.id, "nominator": "player", "yes": voters, "no": [observer.id], "player_yes": true, "count": 4, "threshold": 4, "outcome": "on_block"})
	w.execute(rv.id, {"by": "player", "yes": voters, "no": [observer.id], "player_yes": true})
	w.public_event("execution", [rv.id], "town")
	# open_meeting defers belief refreshes until a speaker's turn; release them so the
	# refresh below sees the vote, curse and execution on the public record.
	w.defer_beliefs = false
	Mind.flush_beliefs(w)
	Mind.refresh_beliefs(w, observer, " (post-curse chronology refresh)")

	_check(is_equal_approx(float(observer.workshop_state.outside.get(rv.id, -1.0)), 0.1),
		"Revenant curse leaves outside baseline untouched at 0.1 (got %.4f)" % float(observer.workshop_state.outside.get(rv.id, -1.0)))
	_check(Mind.susp(observer, rv.id) > 0.45 and is_equal_approx(float(observer.workshop_state.get("source_doubt", {}).get(rv.id + ":*", 0.0)), 1.0),
		"shared chronology pins executed Revenant as evil and sets source_doubt[rv:*] = 1.0")


func _test_grief_resentments() -> void:
	var g = _clean_game(61204, 10)
	var w = g.w
	w.detailed_logging = true
	w.dlog.configure_trace(true)
	w.day = 2
	w.phase = C.EVENING
	var goods: Array = w.living_good()
	var ex = goods[0]
	var mourner_no = goods[1]
	var mourner_yes = goods[2]
	var nominator = goods[3]
	var yes_voter = goods[4]
	var gd_reader = goods[5]

	mourner_no.npc_trust[ex.id] = 0.90
	mourner_yes.npc_trust[ex.id] = 0.90
	w.open_meeting()
	w.execute(ex.id, {"by": nominator.id, "yes": [nominator.id, yes_voter.id, mourner_yes.id], "no": [mourner_no.id], "player_yes": false})
	w.public_event("execution", [ex.id], "town")
	# Release the meeting's deferred refreshes so later hearings apply immediately.
	w.defer_beliefs = false
	Mind.flush_beliefs(w)

	# 1. No grief if the mourner voted yes!
	_check(mourner_yes.resentments.is_empty(), "mourner who voted YES to hang trusted friend records zero grief resentment")

	# 2. Mourner who voted NO gets private resentment records, with zero suspicion/outside mutation!
	var res_targets: Array = mourner_no.resentments.map(func(r): return str(r.get("target", "")))
	res_targets.sort()
	var want_targets: Array = [nominator.id, yes_voter.id, mourner_yes.id]
	want_targets.sort()
	_check(res_targets == want_targets,
		"mourner who opposed execution resents the nominator and every yes-voter (%s)" % str(res_targets))
	_check(is_equal_approx(Mind.susp(mourner_no, nominator.id), 0.1) and is_equal_approx(float(mourner_no.workshop_state.outside.get(nominator.id, -1.0)), 0.1),
		"grief resentment never alters shared suspicion or outside baseline")

	var res_nom_day2: float = Mind.resentment_toward(w, mourner_no, nominator.id)
	var res_vot_day2: float = Mind.resentment_toward(w, mourner_no, yes_voter.id)
	_check(res_nom_day2 > res_vot_day2 and res_vot_day2 > 0.05,
		"nominator resentment (%.3f) exceeds yes-voter resentment (%.3f)" % [res_nom_day2, res_vot_day2])

	# 3. Citable reason in reason_status and case_against.
	var rs_nom: Dictionary = Mind.reason_status(w, mourner_no, nominator.id)
	var rs_vot: Dictionary = Mind.reason_status(w, mourner_no, yes_voter.id)
	_check(rs_nom["kind"] == "public" and rs_nom.get("channel", "") == "resentment" and rs_nom["why"] == "they pushed to hang %s" % ex.name,
		"reason_status cites nominator resentment publicly (%s)" % rs_nom["why"])
	_check(rs_vot["kind"] == "public" and rs_vot["why"] == "they voted to hang %s" % ex.name,
		"reason_status cites voter resentment publicly (%s)" % rs_vot["why"])

	# 4. Action-only contribution in nomination score and vote score (exact sum parity).
	var nom_score_nominator: float = MindMeeting._nomination_action_score(w, mourner_no, nominator.id)
	var nom_score_bystander: float = MindMeeting._nomination_action_score(w, mourner_no, gd_reader.id)
	_check(is_equal_approx(nom_score_nominator - nom_score_bystander, res_nom_day2),
		"resentment adds directly to mourner's own nomination action score (+%.3f)" % (nom_score_nominator - nom_score_bystander))

	w.meeting["block"] = ""
	MindMeeting.vote(w, mourner_no, nominator.id, gd_reader.id, false, "", 0)
	var eval_entries: Array = w.dlog.trace_events().filter(func(en): return en.get("type", "") == "decision" and en.get("actor", "") == mourner_no.id and en.get("data", {}).get("kind", "") == "vote" and en.get("data", {}).get("stage", "") == "evaluation")
	var last_vote_data: Dictionary = eval_entries[-1]["data"]["details"]
	var parts_sum: float = 0.0
	for k in last_vote_data["parts"]:
		parts_sum += float(last_vote_data["parts"][k])
	_check(last_vote_data["parts"].has("resentment") and absf(parts_sum - float(last_vote_data["score"])) < 1e-9,
		"vote evaluation includes resentment part and maintains exact parts sum == score")

	# 5. Nightly fading in end_of_day_trust.
	Mind.end_of_day_trust(w)
	var res_nom_after_fade: float = Mind.resentment_toward(w, mourner_no, nominator.id)
	_check(is_equal_approx(res_nom_after_fade, res_nom_day2 * (1.0 - Tuning.Trust.RESENTMENT_FADE)),
		"resentment fades nightly by RESENTMENT_FADE (%.3f -> %.3f)" % [res_nom_day2, res_nom_after_fade])

	# 6. Auto-clear when the hanged friend is later shown evil (e.g. trusted Gravedigger reading).
	mourner_no.npc_trust[gd_reader.id] = 0.90
	var gd_evil: Dictionary = {"day": 2, "phase": C.NIGHT, "role": "gravedigger", "data": {"executed": ex.id, "role": "poisoner"}, "true": true, "shared": true, "text": "Was Poisoner"}
	Mind.apply_info(w, mourner_no, gd_reader, gd_evil, 1.0)
	_check(Mind.susp(mourner_no, ex.id) >= Tuning.Trust.GRIEF_BELIEVED_EVIL or mourner_no.workshop_state.get("source_doubt", {}).get(ex.id + ":*", 0.0) >= 0.7,
		"trusted Gravedigger reading establishes hanged friend was evil")
	# Ensure susp crosses GRIEF_BELIEVED_EVIL or test direct belief threshold clear:
	if Mind.susp(mourner_no, ex.id) < Tuning.Trust.GRIEF_BELIEVED_EVIL:
		mourner_no.believed_roles[ex.id] = "poisoner"
		Mind.prune_resentments(w, mourner_no)
	_check(mourner_no.resentments.is_empty() and is_zero_approx(Mind.resentment_toward(w, mourner_no, nominator.id)),
		"grudge clears automatically once hanged friend is believed/shown evil")


func _test_freed_soul() -> void:
	var g = _clean_game(77412, 10)
	var w = g.w
	w.day = 2
	w.phase = C.EVENING
	var goods: Array = w.living_good()
	var victim = goods[0]
	var suspect = w.evil_team()[0]
	var pub_ally = goods[1]
	var priv_whisperer = goods[2]

	# Give `victim` strong pre-turn own evidence against `suspect` (> 0.25 old cap!).
	victim.role = "seer"
	var own_seer: Dictionary = {"day": 1, "phase": C.NIGHT, "role": "seer", "data": {"pair": [suspect.id, w.demon_id], "yes": true}, "true": true, "shared": false, "text": "Demon among pair"}
	var own_seer0: Dictionary = {"day": 0, "phase": C.NIGHT, "role": "seer", "data": {"pair": [suspect.id, pub_ally.id], "yes": true}, "true": true, "shared": false, "text": "Demon among pair"}
	victim.info_log = [own_seer0, own_seer]
	victim.applied_info = 0
	Mind.hear_claim(w, victim, victim.id, "seer", 1.5, "own")
	Mind.update_from_own_info(w)
	var pre_turn_susp: float = Mind.susp(victim, suspect.id)
	_check(pre_turn_susp > 0.26, "precondition: pre-turn suspicion of suspect exceeds old 0.25 cap (%.3f)" % pre_turn_susp)

	# Turn `victim` evil via Revenant curse.
	var rv = w.evil_team()[1] if w.evil_team().size() > 1 else suspect
	w.public_event("vote", [rv.id], "town", {"nominee": rv.id, "nominator": "player", "yes": [victim.id, pub_ally.id], "no": [], "player_yes": true, "count": 3, "threshold": 3, "outcome": "on_block"})
	w.public_event("execution", [rv.id], "town")
	w.public_event("curse", [rv.id], rv.id)
	w.turn_evil(victim, "the Revenant's curse")
	w.curse = {"victim": victim.id, "day": 2, "totem": {"loc": "well"}}

	# While turned: private whisper + fake own reading + public claim/reading by `pub_ally`.
	Mind.ledger_hear(w, victim, "priv:while_turned", [[priv_whisperer.id, 0.35, false, "private whisper", ""]], 1.0)
	var fake_seer: Dictionary = {"day": 2, "phase": C.NIGHT, "role": "seer", "data": {"pair": [pub_ally.id, priv_whisperer.id], "yes": true}, "true": false, "fake": true, "shared": false, "text": "Fake reading"}
	victim.info_log.append(fake_seer)
	Mind.update_from_own_info(w)

	w.day = 3
	w.phase = C.MORNING
	pub_ally.role = "dowser"
	pub_ally.claimed_role = "dowser"
	pub_ally.claim_public = true
	w.public_claims.append({"day": 3, "who": pub_ally.id, "role": "dowser"})
	var pub_dowser: Dictionary = {"day": 2, "phase": C.NIGHT, "role": "dowser", "data": {"group": [suspect.id, pub_ally.id, priv_whisperer.id], "count": 1}, "true": true, "shared": true, "text": "Public Dowser"}
	pub_ally.info_log = [pub_dowser]

	# Free `victim`!
	var freed_id: String = w.free_turned()
	_check(freed_id == victim.id and not victim.is_evil() and victim.shadow == null and victim.intel.is_empty(),
		"free_turned restores good alignment and clears shadow and evil intel")
	_check(not victim.ledger.has("priv:while_turned"),
		"private hearings from the turned period are forgotten on restoration")
	_check(victim.ledger.has(Mind.claim_eid(pub_ally.id, "dowser")) and victim.ledger.has(Mind.info_eid(pub_ally.id, pub_dowser)),
		"public claims and shared readings from the turned period carry forward cleanly")
	_check(victim.info_log[2].get("disowned", false) and not victim.info_log[0].get("disowned", false) and not victim.info_log[1].get("disowned", false),
		"fake turned readings are disowned while true pre-turn readings stay intact")
	_check(Mind.susp(victim, suspect.id) > 0.26,
		"freed soul keeps genuine pre-turn + public suspicion without the old 0.25 cap (%.3f)" % Mind.susp(victim, suspect.id))
	_check(victim.workshop_state.outside.values().all(func(v): return is_equal_approx(float(v), 0.1)),
		"freed soul outside layer remains strictly flat at 0.1")
