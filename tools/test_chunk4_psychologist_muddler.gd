extends SceneTree

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const Muddler = preload("res://sim/muddler.gd")
const PsychRole = preload("res://sim/roles/psychologist.gd")
const CardList = preload("res://ui/card_list.gd")
const UITheme = preload("res://ui/theme.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const CanvasView = preload("res://ui/workshop_canvas_view.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Challenges = preload("res://workshop/reading_challenges.gd")
const Channels = preload("res://workshop/evidence_channels.gd")
const Factored = preload("res://workshop/factored_channels.gd")
const Oracle = preload("res://workshop/channel_likelihood.gd")
const Session = preload("res://workshop/session.gd")

var failures: int = 0
var checks: int = 0


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)


func _give_role(w, n, role_id: String) -> void:
	n.role = role_id
	n.alignment = C.ROLES[role_id]["align"]


func _init() -> void:
	var prev_mode: int = SolverBackend.get_mode()
	var has_cs: bool = SolverBackend.is_csharp_available()
	if has_cs:
		SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
	var vm0: int = SolverBackend.get_verify_mismatches()

	_test_revenant_retraction_regression()
	_test_psychologist_simulation_and_companion_cards()
	_test_psychologist_workshop_solver_and_challenges()
	_test_muddler_simulation_and_debunking()
	_test_muddler_domain_and_channel_parity()

	if has_cs:
		_check(SolverBackend.get_verify_mismatches() == vm0, "Zero C#/GDScript VERIFY mismatches across Chunk 4 suite")
	SolverBackend.set_mode(prev_mode)

	if failures == 0:
		print("Chunk 4 (Psychologist rework, Muddler secret & Revenant retraction fix): %d checks passed." % checks)
		quit(0)
	else:
		printerr("Chunk 4 suite failed (%d/%d checks failed)." % [failures, checks])
		quit(1)


func _test_revenant_retraction_regression() -> void:
	var revenant = Session.new(692, "revenant")
	var view: Dictionary = revenant.scenario.public_view
	# The same case as test_workshop_remaining's restoration check (the 012 regression).
	var c = revenant.case_data.duplicate(true)
	c.cards = ["survey", "rumor", "dowse", "curse_warning"]
	c.conclusion = {"type": "evil", "target": "merrin", "at": "during curse"}
	c.answers.curse_warning = {"positive": ["merrin"]}
	revenant.case_data = c
	revenant.present(false)
	revenant.case_data.conclusion.at = "after restoration"
	revenant.case_data.conclusion.type = "good"
	revenant.revise()
	var restored_results = revenant.present(true)
	_check(restored_results[3].effects.merrin.delta < 0.0, "Revenant fixture retraction reduces Merrin suspicion after restoration")


func _test_psychologist_simulation_and_companion_cards() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(9401, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var evils: Array = w.living().filter(func(p): return p.is_evil())
	var psych = goods[0]
	var speaker_a = goods[1]
	var speaker_b = goods[2]
	var speaker_c = goods[3]
	var liar = evils[0]
	_give_role(w, psych, "psychologist")
	psych.secret_mod = ""
	psych.poisoned = false
	psych.info_log.clear()
	psych.heard_statements.clear()

	# 1. Night 0: never produces a reading; Day 1 with 0 heard statements: returns {}
	w.day = 0
	_check(C.role_def("psychologist").min_gift_day == 1 and C.role_def("psychologist").generate_reading(w, psych, {}, Mind).is_empty(), "Psychologist never fires on Night 0")
	w.day = 1
	_check(C.role_def("psychologist").generate_reading(w, psych, {}, Mind).is_empty(), "Psychologist produces no reading when 0 eligible statements were heard")

	# 2. Role claims, hints, and opinions are excluded
	Social._deliver(w, speaker_a, psych, {"kind": "role_claim", "about": speaker_a.id, "from": speaker_a.id, "role": speaker_a.role, "key": "role_claim:" + speaker_a.id})
	Social._deliver(w, speaker_a, psych, {"kind": "opinion", "about": liar.id, "why": "", "from": speaker_a.id, "key": "opinion:" + liar.id})
	_check(psych.heard_statements.is_empty(), "Psychologist ignores bare role claims and opinions")

	# 3. Hearing >= 1 true eligible statements and 0 lies -> mode == "none_false"
	speaker_a.history[w.time_key(0, C.NIGHT)] = "home:" + speaker_a.home_block
	speaker_a.secret_mod = ""
	Social._deliver(w, speaker_a, psych, {"kind": "alibi", "about": speaker_a.id, "block": speaker_a.home_block, "day": 0, "from": speaker_a.id, "key": "alibi:%s:0" % speaker_a.id})
	var r_nf: Dictionary = C.role_def("psychologist").generate_reading(w, psych, {}, Mind)
	_check(r_nf.get("data", {}).get("mode", "") == "none_false" and int(r_nf.get("data", {}).get("day_heard", -1)) == 1 and bool(r_nf.get("true", false)), "Psychologist reports none_false when all heard eligible statements were true")

	# 4. Misled rules: Sleepwalker false home alibi + Seer Red Herring / Marked reading count as false/misread
	speaker_b.secret_mod = "sleepwalker"
	speaker_b.history[w.time_key(0, C.NIGHT)] = "night:" + speaker_c.home_block
	Social._deliver(w, speaker_b, psych, {"kind": "alibi", "about": speaker_b.id, "block": speaker_b.home_block, "day": 0, "from": speaker_b.id, "key": "alibi:%s:0" % speaker_b.id})
	var r_sw: Dictionary = C.role_def("psychologist").generate_reading(w, psych, {}, Mind)
	_check(r_sw.get("data", {}).get("mode", "") == "pair" and r_sw.get("data", {}).get("statements", []).size() == 2, "Sleepwalker false home alibi triggers Psychologist pair reading")

	# 5. Broken Psychologist can report two true statements or false none_false
	psych.heard_statements.clear()
	speaker_c.secret_mod = ""
	speaker_c.history[w.time_key(0, C.NIGHT)] = "home:" + speaker_c.home_block
	Social._deliver(w, speaker_a, psych, {"kind": "alibi", "about": speaker_a.id, "block": speaker_a.home_block, "day": 0, "from": speaker_a.id, "key": "alibi2:%s:0" % speaker_a.id})
	Social._deliver(w, speaker_c, psych, {"kind": "alibi", "about": speaker_c.id, "block": speaker_c.home_block, "day": 0, "from": speaker_c.id, "key": "alibi2:%s:0" % speaker_c.id})
	psych.poisoned = true
	var r_broken: Dictionary = C.role_def("psychologist").generate_reading(w, psych, {}, Mind)
	_check(r_broken.get("data", {}).get("mode", "") == "pair" and not bool(r_broken.get("true", true)), "Poisoned Psychologist can pair two true statements as a false reading")
	psych.poisoned = false

	# 6. Sharing a pair reading adds companion statement cards to g.board
	psych.heard_statements.clear()
	Social._deliver(w, speaker_a, psych, {"kind": "alibi", "about": speaker_a.id, "block": speaker_a.home_block, "day": 0, "from": speaker_a.id, "key": "alibi3:%s:0" % speaker_a.id})
	Social._deliver(w, liar, psych, {"kind": "sighting", "about": speaker_c.id, "block": speaker_a.home_block, "day": 0, "from": liar.id, "key": "sight3:%s:0" % speaker_c.id, "lie": true})
	var r_pair: Dictionary = C.role_def("psychologist").generate_reading(w, psych, {}, Mind)
	w._add_info(psych, r_pair)
	w.day = 2
	var before_board: int = g.board.size()
	var ans_gift: Dictionary = Mind.answer_gift(w, psych, 4)
	g._facts(ans_gift["facts"])
	_check(g.board.size() >= before_board + 3, "Psychologist sharing a pair reading adds companion cards for relayed statements onto g.board")


func _test_psychologist_workshop_solver_and_challenges() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(9402, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var evils: Array = w.living().filter(func(p): return p.is_evil())
	var psych = goods[0]
	var seer = goods[1]
	var other_g = goods[2]
	var liar = evils[0]
	_give_role(w, psych, "psychologist")
	_give_role(w, seer, "seer")
	psych.secret_mod = ""
	seer.secret_mod = ""
	w.day = 1

	var seer_e: Dictionary = {"day": 0, "role": "seer", "data": {"pair": [other_g.id, goods[3].id], "yes": false}, "true": true, "shared": false, "text": "I looked at %s and %s: neither is the demon" % [other_g.name, goods[3].name]}
	var liar_e: Dictionary = {"day": 0, "role": "clerk", "data": {"pair": [other_g.id, goods[3].id], "role": "warden"}, "true": false, "fake": true, "shared": false, "text": "I learned that either %s or %s is the Warden" % [other_g.name, goods[3].name]}
	Social._deliver(w, seer, psych, {"kind": "reading", "entry": seer_e, "about": "", "from": seer.id, "key": "reading:0:seer"})
	Social._deliver(w, liar, psych, {"kind": "reading", "entry": liar_e, "about": "", "from": liar.id, "key": "reading:0:clerk", "lie": true})
	var pr: Dictionary = C.role_def("psychologist").generate_reading(w, psych, {}, Mind)
	# The Psychologist's gift fires at night: a reading stamped with a daytime phase is
	# outside its gift time, so the Solver would reject every world for the wrong reason.
	var phase0 = w.phase
	w.phase = C.NIGHT
	w._add_info(psych, pr)
	w.phase = phase0
	w.day = 2
	var shared: Dictionary = Mind.answer_gift(w, psych, 4)
	g._facts(shared["facts"])

	var cview: Dictionary = WorkshopCanvas.view(g)
	var model = CanvasModel.new(cview)
	var p_card: Dictionary = {}
	for c in cview.cards:
		if c.kind == "report" and c.role == "psychologist":
			p_card = c
			break
	_check(not p_card.is_empty() and str(p_card.data.get("mode", "")) == "pair", "WorkshopCanvas prepares reworked Psychologist pair reading as a report card")

	var stmts: Array = p_card.data.statements
	var liar_slot: String = "0" if str(stmts[0].source) == liar.id else "1"
	var fid0: String = str(stmts[0].fact_id)
	var fid1: String = str(stmts[1].fact_id)

	var prem: String = model.selected
	model.nodes[prem].conclusion = {"type": "evil", "target": liar.id, "at": cview.alignment_epoch}
	# The canvas makes one evidence node per view card, keyed "e:<card id>".
	var ep: String = "e:" + p_card.id
	var e0: String = "e:" + fid0
	var e1: String = "e:" + fid1
	_check(model.nodes.has(ep) and model.nodes.has(e0) and model.nodes.has(e1), "the Psychologist reading and both cited statements are on the canvas")
	model.connect_cards(ep, prem)
	model.connect_cards(e0, prem)
	model.connect_cards(e1, prem)

	# Unanswered [P, s0, s1]: base worlds with all 3 true together conflict on a known-good Psychologist
	var compiled_open: Dictionary = model.compile(prem)
	var base_an: Dictionary = Solver.analyze(cview, compiled_open, {"good": [psych.id]})
	_check(base_an.entailment == "conflicting" and not base_an.conflicts.is_empty(), "Solver detects 3-way incompatibility across Psychologist pair and both cited statements")

	# Selecting liar's slot + Source lied resolves the conflict and raises posterior on liar
	model.nodes[ep].answers[p_card.id] = model.apply_answer(p_card, {}, "psych_pick", liar_slot)
	model.nodes[ep].answers[p_card.id] = model.apply_answer(p_card, model.nodes[ep].answers[p_card.id], "psych_why", "lying")
	var compiled_lied: Dictionary = model.compile(prem)
	var an_lied: Dictionary = Solver.analyze(cview, compiled_lied, {"good": [psych.id]})
	_check(an_lied.proposed > 0 and an_lied.errors.is_empty(), "Picking liar's statement + Source lied resolves conflict cleanly in Solver.analyze")
	var ev_lied: Dictionary = CaseEval.evaluate(cview, compiled_lied)
	_check(ev_lied.posterior > ev_lied.prior and ev_lied.lr > 1.2, "Picking liar's statement + Source lied boosts CaseEval likelihood ratio against liar")

	# FactoredChannels vs ChannelLikelihood oracle exact agreement on [P, s0, s1]
	var subset_cards: Array = [Solver.card_by_id(cview, p_card.id), Solver.card_by_id(cview, fid0), Solver.card_by_id(cview, fid1)]
	var rates: Dictionary = {}
	var q_map: Dictionary = {}
	# Rates keyed by the compiled plan's own channels (as test_workshop_channel_likelihood does).
	for channel in Channels.compile(cview, subset_cards).channels:
		rates[channel.key] = {"healthy": 0.95, "impaired": 0.25} if channel.kind == "gift_accuracy" else 0.8
	for sc in subset_cards:
		q_map[sc.id] = CaseEval.chance_content(cview, sc)
	var f_res: Dictionary = Factored.assess(cview, subset_cards, {}, rates, q_map)
	var o_res: Dictionary = Oracle.assess(cview, subset_cards, {}, rates, q_map)
	_check(f_res.consistent == o_res.consistent, "FactoredChannels and ChannelLikelihood agree on consistent flag for [P, s0, s1]")
	var max_diff: float = 0.0
	for wi in range(f_res.post.size()):
		max_diff = maxf(max_diff, absf(f_res.post[wi] - o_res.post[wi]))
	_check(max_diff < 1e-10, "FactoredChannels matches exhaustive ChannelLikelihood oracle on Psychologist pair gate")

	# Direct night sighting disables "misled" in apply_answer and validate_answers
	var sight_fact: Dictionary = {"kind": "sighting", "source": liar.id, "subject": [other_g.id], "block": other_g.home_block, "day": 0, "phase": C.NIGHT, "text": "saw"}
	var alibi_fact: Dictionary = {"kind": "alibi", "source": seer.id, "subject": [seer.id], "home": true, "block": seer.home_block, "day": 0, "phase": C.NIGHT, "text": "home"}
	psych.heard_statements.clear()
	w.day = 2
	PsychRole.record_heard(w, psych, liar.id, sight_fact, true, "lying")
	PsychRole.record_heard(w, psych, seer.id, alibi_fact, false, "")
	var pr_sight: Dictionary = C.role_def("psychologist").generate_reading(w, psych, {}, Mind)
	var s_slot: String = "0" if str(pr_sight.data.statements[0].kind) == "sighting" else "1"
	var p_sight_card: Dictionary = {"id": "p_sight", "kind": "report", "role": "psychologist", "source": psych.id, "observed_at": {"day": 2, "phase": "night"}, "data": Evidence.report_data("psychologist", pr_sight.data)}
	var ans_try: Dictionary = model.apply_answer(p_sight_card, {}, "psych_pick", s_slot)
	ans_try = model.apply_answer(p_sight_card, ans_try, "psych_why", "misled")
	_check(not ans_try.has("false_reason"), "CanvasModel.apply_answer blocks 'misled' on a raw night sighting")

	# "none_false" bolstering & right-click challenge when Day-1 statements contradict each other
	var g2 = Game.new()
	g2.log_dir = "user://test_logs"
	g2.new_case(9403, 7)
	var w2 = g2.w
	var g2_goods: Array = w2.living_good()
	var psych2 = g2_goods[0]
	var wit = g2_goods[1]
	var walker = w2.living().filter(func(p): return p.is_evil())[0]
	_give_role(w2, psych2, "psychologist")
	w2.day = 1
	var nf_entry: Dictionary = {"day": 1, "role": "psychologist", "data": {"mode": "none_false", "day_heard": 1}, "true": false, "fake": true, "shared": true, "text": "none of the information I heard on day 1 was a lie or misread"}
	var c_nf_num: int = g2.add_card({"kind": "info", "source": psych2.id, "role": "psychologist", "day": 1, "data": nf_entry.data, "subject": [], "text": "Psychologist none_false"})
	var c_sight_num: int = g2.add_card({"kind": "sighting", "source": wit.id, "subject": [walker.id], "block": wit.home_block, "day": 0, "phase": C.NIGHT, "text": "%s saw %s" % [wit.name, walker.name]})
	var c_alibi_num: int = g2.add_card({"kind": "alibi", "source": walker.id, "subject": [walker.id], "home": true, "block": walker.home_block, "day": 0, "phase": C.NIGHT, "text": "%s says home" % walker.name})
	var v2: Dictionary = WorkshopCanvas.view(g2)
	var id_nf: String = Evidence.normalize_card(g2.board[c_nf_num - 1]).id
	var id_sg: String = Evidence.normalize_card(g2.board[c_sight_num - 1]).id
	var id_al: String = Evidence.normalize_card(g2.board[c_alibi_num - 1]).id

	var solo_case = Solver.empty_case()
	solo_case.conclusion = {"type": "evil", "target": walker.id, "at": v2.alignment_epoch}
	solo_case.cards = [id_sg]
	var bolstered_case = solo_case.duplicate(true)
	bolstered_case.cards = [id_sg, id_nf]
	var ev_solo: Dictionary = CaseEval.evaluate(v2, solo_case)
	var ev_bolst: Dictionary = CaseEval.evaluate(v2, bolstered_case)
	_check(ev_bolst.lr > ev_solo.lr, "Linking Psychologist 'none_false' bolsters Day-1 sighting evidence in CaseEval")

	# Challenging the Psychologist's 'none_false' using contradictory Day-1 sighting + alibi
	var ch_val: Dictionary = {"reading_challenges": {id_nf: {"mode": "lying", "supports": [id_sg, id_al]}}}
	var listener_ref: Dictionary = {"id": wit.id, "trust": 0.7, "npc_trust": {wit.id: 1.0, walker.id: 0.6, psych2.id: 0.4}, "suspicion": {psych2.id: 0.35}, "knowledge": {"self": wit.id, "good": [wit.id], "own_role": wit.role}}
	var ch_res: Dictionary = Challenges.assess(v2, ch_val, listener_ref, [Solver.card_by_id(v2, id_nf), Solver.card_by_id(v2, id_sg), Solver.card_by_id(v2, id_al)])
	_check(not ch_res.results.is_empty() and bool(ch_res.results[0].supported), "Challenging Psychologist 'none_false' with contradictory Day-1 statements is supported")


func _test_muddler_simulation_and_debunking() -> void:
	# 1. Roster & default script separation
	_check("muddler" in C.SECRET_MOD_LIST and "muddler" in ScriptDef.roster().secrets, "Muddler is registered in C.SECRET_MOD_LIST and ScriptDef.roster().secrets")
	_check(ScriptDef.default_script().secrets.size() == 4 and ScriptDef.default_script().is_default(), "Default script keeps 4 starter secrets with zero warnings")

	var g = Game.new()
	g.log_dir = "user://test_logs"
	var sc = ScriptDef.default_script()
	sc.secrets = ["muddler", "marked", "delusional", "sleepwalker"]
	sc.forced = ["muddler"]
	g.new_case(9404, 7, sc)
	var w = g.w
	var muddlers: Array = w.living_good().filter(func(p): return p.secret_mod == "muddler")
	_check(muddlers.size() == 1 and muddlers[0].secret.get("kind", "") != "muddler", "Forced Muddler spawns on one good townsperson who remains unaware of being Muddler")
	var mud = muddlers[0]
	var others_g: Array = w.living_good().filter(func(p): return p != mud)
	var reader = others_g[0]
	var listener = others_g[1]
	var third = others_g[2]
	_give_role(w, reader, "seer")
	reader.info_log.clear()
	var orig_e: Dictionary = {"day": 0, "role": "seer", "data": {"pair": [listener.id, third.id], "yes": false}, "true": true, "shared": false, "text": "I looked at %s and %s: neither is the demon" % [listener.name, third.name]}
	reader.info_log.append(orig_e)

	# 2. Statistical ~65% muddle rate, single-fact mutation preserving source & role, role claims untouched
	var muddle_hits: int = 0
	var trials: int = 200
	for t in range(trials):
		mud.muddled_items.clear()
		var probe_e: Dictionary = orig_e.duplicate(true)
		probe_e["day"] = t
		var out_e: Dictionary = Muddler.maybe_muddle_reading(w, mud, reader.id, probe_e)
		if out_e.get("muddled", false):
			muddle_hits += 1
			_check(out_e.get("role", "") == "seer", "Muddler preserves reading role")
			var diff_pair: bool = out_e.data.pair != probe_e.data.pair
			var diff_yes: bool = bool(out_e.data.yes) != bool(probe_e.data.yes)
			_check(diff_pair != diff_yes, "Muddler mutates exactly one fact (either pair member OR yes/no, never both)")
	_check(muddle_hits >= 100 and muddle_hits <= 160, "Muddler 65%% roll lands within expected band (%d/%d)" % [muddle_hits, trials])

	var claim_item: Dictionary = {"kind": "role_claim", "about": reader.id, "from": reader.id, "role": "seer", "key": "role_claim:" + reader.id, "relay": true}
	_check(not Muddler.maybe_muddle_item(w, mud, claim_item).get("muddled", false), "Muddler leaves role claims untouched")

	# 3. Per-item consistency across relays + private disclaimer on `ask gift`
	mud.muddled_items.clear()
	var forced_m: Dictionary = Muddler.mutate_reading_entry(w, mud, reader.id, orig_e)
	var ckey: String = Muddler._reading_cache_key(reader.id, orig_e)
	mud.muddled_items[ckey] = forced_m.duplicate(true)
	mud.hearsay.append({"kind": "reading", "entry": orig_e.duplicate(true), "from": reader.id, "via": reader.id, "day_heard": 1, "key": "reading:0:seer", "public": false})
	var g_share: Dictionary = Social.gossip_item(w, mud)
	g._facts(g_share["facts"])
	var muddled_card: Dictionary = g.board[-1]
	_check(bool(muddled_card.get("muddled", false)) and muddled_card.get("data", {}) == forced_m.data, "Muddler gossip_item emits cached muddled Via card onto g.board")

	# Private `ask gift` with low trust (tier < 4): reader ALWAYS disclaims the muddled card while withholding real reading!
	reader.trust = 0.15
	reader.max_tier = 0
	reader.claim_public = false
	var low_reply: Dictionary = Mind.answer_gift(w, reader)
	Muddler.apply_private_disclaimers(g, reader, "gift", low_reply)
	g._facts(low_reply["facts"])
	_check(bool(muddled_card.get("deprecated", false)) and str(muddled_card.get("disclaimed_by", "")) == reader.id and not bool(muddled_card.get("workshop_usable", true)), "Reader privately disclaims and deprecates muddled Via card even when withholding their real gift")
	_check(not low_reply["facts"].any(func(f): return f.get("kind") == "info"), "Low-trust reader still withholds their real reading while disclaiming the muddle")
	_check("deprecated" in CardList.line_for(muddled_card) and UITheme.card_color(muddled_card).a < 1.0, "Deprecated card renders dimmed with disclaimed label on Case Board")
	_check("deprecated" in g._presentation_rejection(muddled_card), "Presenting a deprecated muddled card is rejected with a clear message")

	# High trust (tier 4): real reading is shared and links `superseded_by` on muddled cards
	var muddled_num2: int = g.add_card({"kind": "info", "source": reader.id, "via": mud.id, "role": "seer", "day": 0, "data": forced_m.data.duplicate(true), "muddled": true, "subject": forced_m.data.pair.duplicate(), "text": "Via Muddler 2"})
	reader.trust = 0.95
	var high_reply: Dictionary = Mind.answer_gift(w, reader, 4)
	Muddler.apply_private_disclaimers(g, reader, "gift", high_reply)
	g._facts(high_reply["facts"])
	_check(bool(g.board[muddled_num2 - 1].get("deprecated", false)) and int(g.board[muddled_num2 - 1].get("superseded_by", 0)) > muddled_num2, "Disclosing the real reading deprecates the muddled card and links superseded_by to the real card")

	# 4. Public meeting relay: high reveal_cost defers debunking to pending_muddle_debunks, then _go_public includes debunk!
	var g3 = Game.new()
	g3.log_dir = "user://test_logs"
	g3.new_case(9405, 7, sc)
	var w3 = g3.w
	var g3_goods: Array = w3.living_good()
	var mud3 = g3_goods[0]
	var src3 = g3_goods[1]
	mud3.secret_mod = "muddler"
	_give_role(w3, src3, "seer")
	src3.claim_public = false
	src3.traits["privacy"] = 0.98
	src3.traits["confidence"] = 0.05
	w3.day = 1
	var real3: Dictionary = {"day": 0, "role": "seer", "data": {"pair": [g3_goods[2].id, g3_goods[3].id], "yes": false}, "true": true, "shared": false, "text": "I looked at %s and %s: neither is the demon" % [g3_goods[2].name, g3_goods[3].name]}
	src3.info_log = [real3]
	var mud_e3: Dictionary = Muddler.mutate_reading_entry(w3, mud3, src3.id, real3)
	mud3.muddled_items[Muddler._reading_cache_key(src3.id, real3)] = mud_e3.duplicate(true)

	var m_lines: Array = []
	var m_facts: Array = []
	Mind.relay_reading(w3, mud3, src3, real3, m_lines, m_facts)
	if not src3.claim_public:
		_check(not src3.pending_muddle_debunks.is_empty(), "Unclaimed high-reveal-cost source defers muddle debunk into pending_muddle_debunks")
		var pub_lines: Array = []
		var pub_facts: Array = []
		Mind._go_public(w3, src3, pub_lines, pub_facts)
		_check(src3.pending_muddle_debunks.is_empty() and pub_facts.any(func(f): return f.get("kind") == "deprecate_muddle"), "Deferred muddle debunk fires when source later goes public")
	else:
		_check(m_facts.any(func(f): return f.get("kind") == "deprecate_muddle"), "Revealing source immediately debunks muddled public relay")


func _test_muddler_domain_and_channel_parity() -> void:
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var view: Dictionary = {
		"people": people,
		"evil_count": 2,
		"alignment_epoch": "Original alignment",
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "roles": true, "identities": true},
	}
	var worlds: Array = Domain.worlds(view)
	# 7 people, 2 evil (21 teams * 2 demons = 42): per team, over the 5 good people,
	# delusional 5 + marked 5 + lovers C(5,2)=10 + sleepwalker 5 + muddler 5 = 30 layouts -> 42 * 30 = 1260 worlds
	_check(worlds.size() == 1260, "WorldDomain enumerates exact 1,260 worlds with all 5 secrets including Muddler")
	var keys: Dictionary = {}
	for w in worlds:
		keys[Domain.key(view, w)] = true
	_check(keys.size() == worlds.size(), "WorldDomain * 5 radix produces collision-free 64-bit keys across all 5 secret modifiers")

	var rumor_muddler: Dictionary = {
		"id": "rm_mud", "fact_id": "rm_mud", "kind": "report", "role": "rumormonger", "source": people[0].id,
		"observed_at": {"day": 0, "phase": "night"},
		"data": {"pair": [people[1].id, people[2].id], "secret": "muddler"},
		"text": "Rumormonger muddler pair",
	}
	var c_mud = Solver.empty_case()
	c_mud.conclusion = {"type": "secret_mod", "target": people[1].id, "mod": "muddler", "at": "Original alignment"}
	c_mud.cards = ["rm_mud"]
	view["cards"] = [rumor_muddler]
	var ev_mud: Dictionary = CaseEval.evaluate(view, c_mud)
	_check(ev_mud.posterior > ev_mud.prior and ev_mud.lr > 3.0, "CaseEval evaluates secret_mod='muddler' premise from Rumormonger Muddler report with exact C#/GDScript parity")
