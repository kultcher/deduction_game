## Regression suite for Nov 4 playtest fixes (cases 95955 and 40741).
## Covers:
##   1. Rumormonger & Chronicler chance_content calibration (no false self-incrimination).
##   2. Presentation voice routing (scoped attended inconsistency only; snapshot.selected attention check).
##   3. Evil awareness of promised player vigils & wards (via Evil.note_player_offer + share_intel).
##   4. Scion-active cover voting/nomination & doomed-Demon rescue follow-through.
##   5. Night phrasing via C.spoken_when ("last night" / "on the first night", never "on night 1").
##   6. Night Watch & accusation-sighting deduplication (no duplicate lines or double cards).
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Social = preload("res://sim/social.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const ReasonAttribution = preload("res://workshop/reason_attribution.gd")
const SolverBackend = preload("res://workshop/solver_backend.gd")
const Presentations = preload("res://sim/dialogue_presentations.gd")
const Voices = preload("res://sim/dialogue_voices.gd")

var fails: int = 0
var checks: int = 0


func _check(cond: bool, label: String) -> void:
	checks += 1
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _init() -> void:
	_test_rumormonger_and_chronicler_chance_content()
	_test_presentation_reply_routing()
	_test_evil_promised_vigil_and_ward_avoidance()
	_test_scion_cover_and_doomed_demon_votes()
	_test_spoken_when_and_sighting_dedup()
	print("PLAYTEST NOV4 FIXES: %d/%d passed (%d failed)" % [checks - fails, checks, fails])
	quit(1 if fails > 0 else 0)


func _test_rumormonger_and_chronicler_chance_content() -> void:
	var g = Game.new()
	g.new_case(95955, 10)
	var w = g.w
	w.day = 1
	w.phase = C.EVENING
	var goods: Array = w.living_good()
	var speaker = goods[0]
	var pair_a = goods[1]
	var pair_b = goods[2]
	var listener = goods[3]
	speaker.role = "rumormonger"
	speaker.claimed_role = ""
	speaker.claim_public = false
	var entry: Dictionary = {
		"day": 0,
		"role": "rumormonger",
		"data": {"pair": [pair_a.id, pair_b.id], "secret": "delusional"},
		"text": "The night before you arrived, I heard that one of %s and %s carries a Delusional secret." % [pair_a.name, pair_b.name],
		"true": true,
		"shared": false,
	}
	speaker.info_log = [entry]
	Mind.refresh_beliefs(w, listener, "baseline before rumormonger reveal")
	var susp_before: float = Mind.susp(listener, speaker.id)
	var pub_lines: Array = []
	var pub_facts: Array = []
	Mind.MindMeeting._go_public(w, speaker, pub_lines, pub_facts)
	g._facts(pub_facts)
	Mind.refresh_beliefs(w, listener, "after truthful rumormonger reveal")
	var susp_after: float = Mind.susp(listener, speaker.id)
	_check(susp_after <= susp_before + 0.03,
		"Uncorroborated Rumormonger report does not spike speaker suspicion (%.3f -> %.3f)" % [susp_before, susp_after])
	var reasons: Array = Mind.MindMeeting.case_against(w, listener, speaker.id)
	_check(not reasons.any(func(r): return "Rumormonger report doesn't fit" in str(r.get("why", ""))),
		"Uncontradicted Rumormonger reading never emits false 'doesn't fit what we know' reason (%s)" % str(reasons))

	var view: Dictionary = ReasonAttribution.public_view_from_world(w)
	var rm_card: Dictionary = {
		"id": "probe_rm", "kind": "report", "source": speaker.id, "role": "rumormonger",
		"night": 0, "observed_at": {"day": 0, "phase": "night"},
		"data": {"pair": [pair_a.id, pair_b.id], "secret": "marked"},
	}
	var q_rm: float = CaseEval.chance_content(view, rm_card)
	_check(q_rm > 0.02 and q_rm < 0.08,
		"10-NPC live Marked Rumormonger chance_content matches ~0.0325 prior hold rate (got %.4f)" % q_rm)
	var chr_card: Dictionary = {
		"id": "probe_chr", "kind": "report", "source": speaker.id, "role": "chronicler",
		"night": 3, "observed_at": {"day": 3, "phase": "night"},
		"data": {"trio": [pair_a.id, pair_b.id, goods[4].id]},
	}
	var q_chr: float = CaseEval.chance_content(view, chr_card)
	_check(q_chr > 0.10 and q_chr < 0.18,
		"10-NPC live Chronicler chance_content matches ~0.1394 prior hold rate (got %.4f)" % q_chr)


func _test_presentation_reply_routing() -> void:
	var g = Game.new()
	g.new_case(40741, 10)
	var w = g.w
	var listener = w.living_good()[0]
	var target = w.demon()
	# Simulate background town conflict (assessment.status == 'conflicting') while attended case is coherent & accepted.
	var fake_assessment: Dictionary = {
		"agreement": 0.78,
		"stance": "accept",
		"path_kind": "reading",
		"assessment": {"status": "conflicting"},
		"case_eval": {"consistent": false, "impossible": false, "posterior": 0.88, "movement": [], "rivals": []},
		"reasoning": {
			"status": "provisional",
			"rivals_tested": 4,
			"considered": ["c1", "c2", "c3"],
			"ignored": ["bg_1", "bg_2", "bg_3"],
			"ignored_lines": [],
			"private_checks": {"fatal": false, "objections": [], "rejected": []},
		},
	}
	var fake_view: Dictionary = {"people": [], "listener": {}}
	var fake_snap: Dictionary = {"selected": ["c1", "c2", "c3"]}
	var reply: Dictionary = Presentations.render_workshop_reply(
		w, listener, {"type": "demon", "a": target.id, "at": "Original alignment"},
		[target.id], fake_assessment, fake_view, fake_snap, "accept", false, false,
		"Your explanation fits what I considered.", {}
	)
	var expected_solid: String = Dialogue.apply_tics(listener.id, Voices.VOICES[listener.id]["present_accept_solid"], {})
	_check(reply.text == expected_solid,
		"Accepted coherent presentation voices present_accept_solid with zero conflict or attention-drop complaints (%s)" % reply.text)

	# Conversely, an actual attended inconsistency with dropped supporting lines voices conflict + partial attention.
	var inc_assessment: Dictionary = fake_assessment.duplicate(true)
	inc_assessment.reasoning.status = "inconsistent"
	inc_assessment.reasoning.ignored_lines = ["sub_branch_3"]
	var inc_reply: Dictionary = Presentations.render_workshop_reply(
		w, listener, {"type": "demon", "a": target.id, "at": "Original alignment"},
		[target.id], inc_assessment, fake_view, fake_snap, "reject", false, false,
		"The accounts I considered conflict with each other.", {}
	)
	var expected_inc: String = Dialogue.apply_tics(
		listener.id,
		Voices.VOICES[listener.id]["present_conflict_weighing"] + " " + Voices.VOICES[listener.id]["present_partial_attention"],
		{}
	)
	_check(inc_reply.text == expected_inc,
		"Genuinely inconsistent attended case with dropped lines still voices conflict + partial attention")


func _test_evil_promised_vigil_and_ward_avoidance() -> void:
	var g = Game.new()
	g.new_case(95955, 10)
	var w = g.w
	w.day = 1
	w.phase = C.AFTERNOON
	var d = w.demon()
	var goods: Array = w.living_good()
	var same_block_good = goods[0]
	same_block_good.home_block = d.home_block
	var alt_blk: String = "square" if d.home_block != "square" else "docks"
	for idx in range(1, goods.size()):
		goods[idx].home_block = alt_blk
	same_block_good.claim_public = true
	same_block_good.claimed_role = "seer"
	w.public_claims.append({"day": 1, "who": same_block_good.id, "role": "seer"})
	# Demon receives a vigil promise on their own home block (like Jory in 95955).
	g._offer_command(d, "vigil", true)
	_check(Evil._knows_promised_vigil_tonight(d, d.home_block, w.day),
		"GameConversation._offer_command records promised vigil block in evil recipient's intel")
	var kt: String = Evil.choose_kill_target(w)
	_check(kt != "" and w.by_id[kt].home_block != d.home_block,
		"Demon avoids killing on a block where it asked for / received a player vigil (%s on %s vs vigil %s)" % [kt, w.by_id[kt].home_block if kt != "" else "?", d.home_block])

	# Minion receives vigil promise and passes it to Demon via share_intel (no telepathy before meeting).
	var m = w.minion()
	w.day = 2
	m.home_block = alt_blk
	g.offer = {}
	g._offer_command(m, "vigil", false)
	_check(Evil._knows_promised_vigil_tonight(m, alt_blk, 2) and not Evil._knows_promised_vigil_tonight(d, alt_blk, 2),
		"Minion vigil promise is not telepathically known to Demon before conversing")
	Social.converse(w, d, m, "afternoon")
	_check(Evil._knows_promised_vigil_tonight(d, alt_blk, 2),
		"Demon learns Minion's promised vigil block once teammates pool intel via Social.converse")


func _test_scion_cover_and_doomed_demon_votes() -> void:
	var g = Game.new()
	g.new_case(40741, 10)
	var w = g.w
	w.day = 2
	w.begin_meeting()
	var d = w.demon()
	var sc = w.living_with_role("scion")
	if sc == null:
		sc = w.minion()
		sc.role = "scion"
	sc.poisoned = false
	_check(Evil.scion_fallback_active(w),
		"scion_fallback_active is true with unbroken Scion and >= 5 living NPCs")
	_check(Evil.teammate_value(w, sc.id) > Evil.teammate_value(w, d.id),
		"Active Scion carries higher teammate_value than replaceable Demon (%.2f vs %.2f)" % [Evil.teammate_value(w, sc.id), Evil.teammate_value(w, d.id)])

	# Landslide Demon vote with active Scion: exposed Scion whose good shadow votes YES keeps cover.
	sc.pressure = 1.2
	w.meeting["nominated"].append(d.id)
	Mind.shadow_run(w, sc, func(sh):
		sh.suspicion[d.id] = 0.95
		sh.workshop_state["outside"][d.id] = 0.95)
	var sh_yes = Mind.shadow_eval(w, sc, func(sh): return Mind.vote(w, sh, d.id, "player", true, "accuse", 6))
	_check(sh_yes == true, "Scion's good shadow wants to vote YES on heavily implicated Demon")
	var sc_vote: bool = Mind.vote(w, sc, d.id, "player", true, "accuse", 6)
	_check(sc_vote == true,
		"Exposed Scion votes YES with town landslide on Demon to preserve cover for succession")

	# Without active Scion (< 5 alive), even an exposed minion still votes NO on the Demon, and a Demon on the block backs a live rescue nomination.
	var kept: int = 0
	for p in w.npcs:
		if p == d or p == sc:
			p.alive = true
		elif kept < 2:
			p.alive = true
			kept += 1
		else:
			p.alive = false
	_check(not Evil.scion_fallback_active(w),
		"scion_fallback_active is false once fewer than 5 NPCs remain alive")
	_check(not Mind.vote(w, sc, d.id, "player", false, "", 0),
		"Without active Scion fallback, evil teammate still refuses to vote YES on the Demon")
	var villager = w.living_good()[0]
	w.meeting["block"] = d.id
	w.meeting["block_count"] = 2
	d.pressure = 3.0
	var rescue_vote: bool = Mind.vote(w, d, villager.id, sc.id, false, "", 1)
	_check(rescue_vote == true,
		"Doomed Demon on the block without Scion fallback backs mathematically live rescue counter-nomination")


func _test_spoken_when_and_sighting_dedup() -> void:
	var g = Game.new()
	g.new_case(40741, 10)
	var w = g.w
	w.day = 3
	w.phase = C.EVENING
	w.begin_meeting()
	var n = w.minion()
	var sg = w.living_good()[0]
	w.evil_plan["scapegoat"] = sg.id
	w.evil_plan["bluffs"][n.id] = "nightwatch"
	n.claimed_role = "nightwatch"
	n.claim_public = true
	w.public_claims.append({"day": 2, "who": n.id, "role": "nightwatch"})
	n.traits["gossip"] = 1.0
	n.traits["confidence"] = 1.0
	n.traits["insight"] = 1.0
	n.pressure = 2.0
	n.told_to = {}
	n.info_log = [{
		"day": 2,
		"role": "nightwatch",
		"data": {"block": "market", "seen": [sg.id]},
		"text": "Last night, I watched the Market: I saw %s pass by." % sg.name,
		"true": false,
		"fake": true,
		"shared": false,
	}]
	var fs: Dictionary = {"kind": "saw", "who": sg.id, "loc": "", "block": "market", "day": 2, "phase": C.NIGHT, "how": "street", "detail": "street"}
	w.evil_plan["fake_sightings"][n.id + ":2"] = fs
	n.beliefs = [fs.duplicate(true)]

	var reason_d3_n2: String = Evil.bluff_reason(w, n, sg)
	_check(not ("on night " in reason_d3_n2),
		"Evil.bluff_reason uses natural spoken_when phrasing rather than 'on night N' (%s)" % reason_d3_n2)

	var st: Dictionary = {"speakers": [n], "i": 0, "done": false}
	var turn: Dictionary = Mind.testimony_step(w, st)
	var sighting_facts: Array = turn.get("facts", []).filter(func(f): return f.get("kind", "") == "sighting")
	var info_facts: Array = turn.get("facts", []).filter(func(f): return f.get("kind", "") == "info")
	_check(info_facts.size() == 1 and sighting_facts.is_empty(),
		"Sharing Night Watch reading suppresses duplicate volunteered/accusation sighting cards (info=%d, sighting=%d)" % [info_facts.size(), sighting_facts.size()])
	var texts: Array = turn.get("lines", []).map(func(l): return str(l.get("text", "")))
	_check(not texts.any(func(t): return "on night 2" in t.to_lower() or "on night 1" in t.to_lower()),
		"Testimony lines contain zero raw 'on night N' strings (%s)" % str(texts))
