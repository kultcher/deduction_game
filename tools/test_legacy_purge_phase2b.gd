## Regression suite for Legacy Purge Phase 2b:
##   1. `workshop_state.source_doubt` replacing `n.discounted` and `n.honesty` in shared mode
##   2. Post-refresh Gravedigger execution rapport (`World.on_execution_reading_heard`)
##   3. Revenant curse cleanup (no direct `Mind.adjust(+1.0)`)
##   4. Grief -> private, nightly-fading, citable `resentments` (skipping yes-voters, clearing when shown evil)
##   5. Freed souls -> pre-turn snapshot restoration + public receipt carry-forward (no `shadow_adopt`, no `0.25` cap)
##   6. Two-way player-presented vote circumstantial evidence (`shielding` + `no` votes)
##   7. Flat `0.1` `outside` baseline invariance across multi-day play
##
## Run headless:
##   godot --headless --path . --script res://tools/test_legacy_purge_phase2b.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Social = preload("res://sim/social.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Credibility = preload("res://game/credibility.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_test_source_doubt_replaces_discounted_and_honesty()
	_test_gravedigger_rapport_moved_out_of_info_effects()
	_test_revenant_curse_no_direct_outside_adjust()
	_test_grief_resentments_fading_citable_and_exonerated()
	_test_freed_soul_pre_turn_snapshot_and_public_carry_forward()
	_test_two_way_vote_circumstantial_shielding_player_presented_only()
	_test_multi_day_outside_layer_invariance()
	print("Legacy Purge Phase 2b: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _clean_game(seed_val: int, size: int = 10):
	var g = Game.new()
	g.workshop_effects = false
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
			m.workshop_state = {"enabled": false, "reasoning_mode": "full", "confidence_mode": "scale"}
			for id in m.suspicion:
				m.suspicion[id] = 0.1
	g.set_workshop_effects(true)
	return g


func _test_source_doubt_replaces_discounted_and_honesty() -> void:
	var g = _clean_game(98933, 10)
	var w = g.w
	w.day = 2
	var goods: Array = w.living_good()
	var listener = goods[0]
	var liar = w.evil_team()[0]
	var relayer = goods[1]
	var scapegoat = goods[2]
	var honest_reader = goods[3]

	listener.role = "seer"
	Mind.hear_claim(w, listener, listener.id, "seer", 1.5, "own")
	# Relay a Night 1 sighting originally planted by `liar` via `relayer`.
	listener.npc_trust[relayer.id] = 0.85
	listener.npc_trust[liar.id] = 0.55
	var direct_sight = {"kind": "sighting", "about": scapegoat.id, "block": "market", "day": 1, "from": liar.id, "key": "sighting:%s:1" % scapegoat.id, "lie": true}
	Social._deliver(w, liar, relayer, direct_sight)
	var relay_sight = direct_sight.duplicate(true)
	relay_sight["relay"] = true
	relay_sight["key"] = "relay:" + direct_sight["key"]
	Social._deliver(w, relayer, listener, relay_sight)

	var sight_eid: String = listener.ledger.keys().filter(func(k): return str(k).begins_with("heard:"))[0]
	var sight_cid: String = listener.ledger[sight_eid].meta.workshop_card.id

	# Poison legacy `discounted` and `honesty` on `listener` and verify shared mode ignores them!
	listener.discounted[honest_reader.id + ":1"] = 0.90
	listener.discounted[liar.id + ":*"] = 0.0
	listener.honesty[honest_reader.id] = 0.10
	Mind.apply_info(w, listener, honest_reader, {"day": 1, "role": "dowser", "data": {"group": [liar.id, scapegoat.id], "count": 1}, "text": "One evil"}, 0.6)
	var snap: Dictionary = Bridge.capture(g, [], listener.id, "private", listener)
	_check(snap.listener.has("source_doubt") and not snap.listener.has("discounted") and not snap.listener.has("honesty"),
		"WorkshopBridge listener snapshot carries source_doubt and omits legacy discounted/honesty")
	_check(is_equal_approx(Mind.reliability(listener, honest_reader.id, 1, "reading"), 1.0),
		"Mind.reliability in shared mode ignores poisoned legacy discounted/honesty")

	# Now `liar` publicly claims `listener`'s own unique gift ("seer") -> caught lie sets source_doubt[liar:*] == 1.0
	# and automatically collapses the relayed sighting's hearing_weight!
	Mind.hear_claim(w, listener, liar.id, "seer", 0.8, "public")
	var sd: Dictionary = listener.workshop_state.get("source_doubt", {})
	_check(is_equal_approx(float(sd.get(liar.id + ":*", 0.0)), 1.0),
		"claiming listener's own unique gift sets workshop_state.source_doubt[liar:*] = 1.0")
	_check(is_zero_approx(Mind.reliability(listener, liar.id, 1, "reading")),
		"Mind.reliability drops to 0.0 when source_doubt[liar:*] == 1.0")
	var plan_after = Shared.prepare(g.workshop_snapshot([], listener.id), {}, listener.ledger)
	var sight_card_after: Dictionary = plan_after.prepared.view.cards.filter(func(c): return c.id == sight_cid)[0]
	_check(is_zero_approx(float(sight_card_after.get("hearing_weight", 1.0))),
		"caught lie in source_doubt collapses relayed sighting hearing_weight to 0.0 without touching legacy discounted")

	# Demon victim sincerity clears `source:*` dishonesty doubt while preserving `source:night` impairment doubt.
	honest_reader.alive = false
	honest_reader.death_day = 2
	honest_reader.death_cause = "demon"
	w.public_event("demon_death", [honest_reader.id], "town")
	Mind.ledger_hear(w, listener, "arg:impair", [], 1.0, [], {"kind": "arg", "conclusion": {"type": "misled", "a": honest_reader.id, "night": 1}})
	var sd_victim: Dictionary = listener.workshop_state.get("source_doubt", {})
	_check(float(sd_victim.get(honest_reader.id + ":1", 0.0)) > 0.7 and not sd_victim.has(honest_reader.id + ":*"),
		"Demon victim keeps night-specific impairment doubt (%.2f) with zero dishonesty doubt" % float(sd_victim.get(honest_reader.id + ":1", 0.0)))

	# Credibility.dawn and debug_npc_text run cleanly on source_doubt.
	Credibility.record(listener, "evil", liar.id, 2, 1.0)
	var cred_before: float = listener.credibility
	Credibility.dawn(g)
	_check(listener.credibility > cred_before, "Credibility.dawn evaluates agreement via source_doubt without n.discounted")
	var dbg_txt: String = g.debug_npc_text(liar.id)
	_check("Credited by others:" in dbg_txt, "game.gd debug_npc_text formats source credence without reading legacy honesty")


func _test_gravedigger_rapport_moved_out_of_info_effects() -> void:
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

	# 1. Calling legacy info_effects directly must NOT mutate listener.trust anymore.
	C.role_def("gravedigger").info_effects(w, listener, gd_npc, gd_good_entry, 1.0, true, Mind)
	_check(is_equal_approx(listener.trust, t0), "Gravedigger info_effects no longer mutates listener rapport directly")

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


func _test_revenant_curse_no_direct_outside_adjust() -> void:
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
	Mind.recompute_beliefs(w, observer, " (post-curse chronology refresh)")

	_check(is_equal_approx(float(observer.workshop_state.outside.get(rv.id, -1.0)), 0.1),
		"Revenant curse leaves outside baseline untouched at 0.1 (got %.4f)" % float(observer.workshop_state.outside.get(rv.id, -1.0)))
	_check(Mind.susp(observer, rv.id) > 0.45 and is_equal_approx(float(observer.workshop_state.get("source_doubt", {}).get(rv.id + ":*", 0.0)), 1.0),
		"shared chronology pins executed Revenant as evil and sets source_doubt[rv:*] = 1.0")


func _test_grief_resentments_fading_citable_and_exonerated() -> void:
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

	# 1. No grief if the mourner voted yes!
	_check(mourner_yes.resentments.is_empty(), "mourner who voted YES to hang trusted friend records zero grief resentment")

	# 2. Mourner who voted NO gets private resentment records, with zero suspicion/outside mutation!
	_check(mourner_no.resentments.size() == 2, "mourner who opposed execution records resentment against nominator and yes-voter")
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


func _test_freed_soul_pre_turn_snapshot_and_public_carry_forward() -> void:
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
	victim.info_log = [own_seer]
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
	_check(victim.info_log[1].get("disowned", false) and not victim.info_log[0].get("disowned", false),
		"fake turned readings are disowned while true pre-turn readings stay intact")
	_check(Mind.susp(victim, suspect.id) > 0.26,
		"freed soul keeps genuine pre-turn + public suspicion without the old 0.25 cap (%.3f)" % Mind.susp(victim, suspect.id))
	_check(victim.workshop_state.outside.values().all(func(v): return is_equal_approx(float(v), 0.1)),
		"freed soul outside layer remains strictly flat at 0.1")


func _test_two_way_vote_circumstantial_shielding_player_presented_only() -> void:
	var g = _clean_game(88310, 10)
	var w = g.w
	w.day = 2
	w.phase = C.EVENING
	var goods: Array = w.living_good()
	var listener = goods[0]
	var nominator = goods[1]
	var shielder = w.evil_team()[0]
	var nom_evil = w.demon()
	if shielder == nom_evil:
		shielder = w.minions()[0]

	# Give `listener` Stage 1 grounds on both `nom_evil` (believed evil >= 0.48) and `shielder` (passes Stage 1 gate).
	var foil_a = goods[2]
	var foil_b = goods[3]
	listener.role = "seer"
	var s1: Dictionary = {"day": 0, "phase": C.NIGHT, "role": "seer", "data": {"pair": [nom_evil.id, foil_a.id], "yes": true}, "true": true, "shared": false, "text": "Demon among pair 1"}
	var s2: Dictionary = {"day": 1, "phase": C.NIGHT, "role": "seer", "data": {"pair": [nom_evil.id, foil_b.id], "yes": true}, "true": true, "shared": false, "text": "Demon among pair 2"}
	var d1: Dictionary = {"day": 1, "phase": C.NIGHT, "role": "dowser", "data": {"group": [shielder.id, nominator.id], "count": 1}, "true": true, "shared": true, "text": "One evil"}
	listener.info_log = [s1, s2]
	listener.applied_info = 0
	Mind.hear_claim(w, listener, listener.id, "seer", 1.5, "own")
	Mind.update_from_own_info(w)
	Mind.apply_info(w, listener, nominator, d1, 0.8)
	_check(Mind.susp(listener, nom_evil.id) >= 0.48, "precondition: listener believes nominee is evil (%.3f)" % Mind.susp(listener, nom_evil.id))

	# Hold a public vote where `shielder` votes NO on `nom_evil`.
	w.meeting = {"block": "", "block_count": 0, "nominated": [], "nominators": [], "results": [], "pending": {}}
	w.open_nomination(nominator.id, nom_evil.id)
	var tally: Dictionary = w.vote_pending(true)
	_check(shielder.id in tally["no"], "vote_pending records evil teammate in no voters")

	var susp_before_hub: float = Mind.susp(listener, shielder.id)
	Mind.recompute_beliefs(w, listener, " (ambient refresh after public vote)")
	_check(is_equal_approx(Mind.susp(listener, shielder.id), susp_before_hub) and listener.workshop_state.get("circumstantial_incidents", {}).is_empty(),
		"ambient refresh does NOT auto-compute vote shielding without a player-presented Circumstantial hub")

	# Add the vote card and present a Circumstantial hub targeting `shielder`!
	var vote_card_num: int = g.add_card({
		"kind": "vote", "source": "player", "subject": tally["yes"] + [nom_evil.id],
		"day": 2, "phase": C.EVENING, "nominee": nom_evil.id, "by": nominator.id,
		"yes": tally["yes"].duplicate(), "no": tally["no"].duplicate(),
		"player_yes": tally["player_yes"], "count": tally["count"],
		"threshold": tally["threshold"], "outcome": tally["outcome"],
		"text": "Day 2 vote on %s" % nom_evil.name,
	})
	var dowser_card_num: int = g.add_card({
		"kind": "info", "source": nominator.id, "subject": [shielder.id, nominator.id],
		"day": 1, "phase": C.NIGHT, "role": "dowser",
		"data": {"group": [shielder.id, nominator.id], "count": 1},
		"text": "Dowser count 1",
	})
	var vote_cid: String = WorkshopCanvas.Evidence.normalize_card(g.board[vote_card_num - 1]).id
	var dowser_cid: String = WorkshopCanvas.Evidence.normalize_card(g.board[dowser_card_num - 1]).id
	var view: Dictionary = WorkshopCanvas.view(g)
	var canvas = CanvasModel.new(view)
	var prem_id: String = canvas.nodes.keys().filter(func(k): return canvas.nodes[k].kind == "premise")[0]
	canvas.nodes[prem_id].conclusion = {"type": "suspicious", "target": shielder.id, "at": view.alignment_epoch}
	canvas.connect_cards("e:" + dowser_cid, prem_id)
	var hub_id: String = canvas.add_circumstantial_hub(Vector2(280, 220))
	canvas.connect_cards("e:" + vote_cid, hub_id)
	canvas.connect_cards(hub_id, prem_id)
	var filed_num: int = WorkshopCanvas.file(g, canvas.compile(prem_id))
	_check(filed_num > 0, "WorkshopCanvas files case with vote card wired into Circumstantial hub")

	g._evaluate_deduction(listener, g.board[filed_num - 1], 1.0, false, "meeting")
	var incs: Array = listener.workshop_state.get("circumstantial_incidents", {}).get(shielder.id, [])
	_check(incs.any(func(inc): return str(inc.get("family", "")) == "shielding") and float(listener.workshop_state.get("circumstantial_applied", {}).get(shielder.id, 0.0)) > 0.0,
		"player-presented Circumstantial hub fires shielding incident against no-voter (%s)" % str(incs))
	var reasons: Array = MindMeeting.case_against(w, listener, shielder.id, 6)
	_check(reasons.any(func(r): return "voted against hanging %s" % nom_evil.name in str(r.get("why", ""))),
		"case_against surfaces citable shielding reason (%s)" % str(reasons))


func _test_multi_day_outside_layer_invariance() -> void:
	for cfg in [[900, 7], [54875, 10]]:
		var sd: int = int(cfg[0])
		var sz: int = int(cfg[1])
		var g = Game.new()
		g.detailed_logging = false
		g.log_dir = "user://phase2b_outside_check"
		g.new_case(sd, sz)
		var steps: int = 0
		while g.w.day < 4 and not g.w.game_over and steps < 250:
			steps += 1
			match g.state:
				"approach":
					g.command("decline")
				"talk":
					g.command("bye")
				"meeting":
					g.command("done" if g.town_quiet else "wait")
				"nomination":
					g.command("vote no")
				"night":
					g.command("sleep")
				_:
					g.command("wait")
		var all_flat: bool = true
		for n in g.w.living_good():
			var out_map: Dictionary = n.workshop_state.get("outside", {})
			for pid in out_map:
				if not is_equal_approx(float(out_map[pid]), 0.1):
					all_flat = false
		_check(all_flat and g.shared_fallbacks.is_empty(),
			"seed %d (%d NPCs) reaches Day %d with 0 fallbacks and strictly flat 0.1 outside layer" % [sd, sz, g.w.day])
