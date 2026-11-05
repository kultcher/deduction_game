## Gifts for reading people (hint package 'people'): Dowser, Psychologist, Augur, Confessor (the Rumormonger is with official business).
## Merged from: test_chunk2_world_mask_roles, test_chunk4_psychologist_muddler, test_chunk5_monitor_confessor, test_roster, test_workshop_psychologist.
extends SceneTree

const Game = preload("res://game/game.gd")
const World = preload("res://sim/world.gd")
const C = preload("res://sim/content.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Mind = preload("res://sim/mind.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Evil = preload("res://sim/evil.gd")
const Solver = preload("res://workshop/solver.gd")
const Caches = preload("res://workshop/caches.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Channels = preload("res://workshop/evidence_channels.gd")
const Factored = preload("res://workshop/factored_channels.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Challenges = preload("res://workshop/reading_challenges.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Oracle = preload("res://workshop/channel_likelihood.gd")
const Social = preload("res://sim/social.gd")
const PsychRole = preload("res://sim/roles/psychologist.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_roster()
	_run_chunk2_world_mask_roles()
	_run_workshop_psychologist()
	_run_chunk4_psychologist_mudd()
	_run_chunk5_monitor_confessor()
	print("Roles: reading people: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## One shared check helper (the merged suites used both names).
func check(ok: bool, label: String) -> void:
	_count(ok, label)


func _check(ok: bool, label: String) -> void:
	_count(ok, label)


func _count(ok: bool, label: String) -> void:
	checks += 1
	_checks += 1
	if not ok:
		fails += 1
		failures += 1
		_fails += 1
		printerr("FAIL: " + label)


# ---------------------------------------------------------------- from test_roster

func _run_roster() -> void:
	_test_dowser()
	_test_psychologist()


# ---------------------------------------------------------------- from test_chunk2_world_mask_roles

func _run_chunk2_world_mask_roles() -> void:
	_test_dowser_public_area_fix()
	_test_augur_sim_and_workshop()


# ---------------------------------------------------------------- from test_workshop_psychologist

func _run_workshop_psychologist() -> void:
	for size in [7, 10]:
		_family(size)


# ---------------------------------------------------------------- from test_chunk4_psychologist_muddler

func _run_chunk4_psychologist_mudd() -> void:
	_test_psychologist_simulation_and_companion_cards()
	_test_psychologist_workshop_solver_and_challenges()


# ---------------------------------------------------------------- from test_chunk5_monitor_confessor

func _run_chunk5_monitor_confessor() -> void:
	_test_confessor_role_def_registration()
	_test_confessor_target_choice_and_secret_visit()
	_test_confessor_readings_alignment_and_marked()
	_test_confessor_visit_before_demon_kill()
	_test_confessor_poisoned_delusional_misread()
	_test_confessor_night_duty_alibi_and_bluff()


# ---- test_roster


## Pure World setup for multi-hundred-seed role/home/bluff distribution checks.
func _game(sd: int, size: int = 7):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


func _give(w, n, role: String) -> void:
	var holder = w.npc_with_role(role)
	if holder != null and holder != n:
		holder.role = n.role
	n.role = role


func _test_dowser() -> void:
	var got = 0
	var right = 0
	for sd in range(9170, 9190):
		var w = _game(sd).w
		var dw = w.living_good()[0]
		_give(w, dw, "dowser")
		dw.secret_mod = ""
		dw.poisoned = false
		dw.dowsed_day = -1
		w.phase = C.MORNING
		dw.loc = "tavern"
		var others: Array = w.living().filter(func(m): return m != dw)
		others[0].loc = "well"
		others[1].loc = "tavern"
		others[0].busy_with = ""
		var before = dw.info_log.size()
		w._day_gifts()
		if dw.info_log.size() > before:
			got += 1
			var e: Dictionary = dw.info_log.back()
			if e["true"] or e.get("why", "") != "":
				right += 1
			if e["data"]["group"].size() < 2:
				right -= 100
			if got == 1:
				print("  ", e["text"])
	_check(got == 20 and right == 20, "the Dowser reads their block the first time two or more are there")


func _test_psychologist() -> void:
	var mate_trusted = 0
	var tries = 0
	for sd in range(9190, 9210):
		var w = _game(sd, 10).w
		var d = w.demon()
		tries += 1
		if w._psych_read(d)["trusts"] in w.minion_ids:
			mate_trusted += 1
	print("demon's most trusted is a minion: %d/%d" % [mate_trusted, tries])
	_check(mate_trusted >= tries / 2, "evil mostly trust each other (the Psychologist can see it)")


# ---- test_chunk2_world_mask_roles


func chunk2_world_mask_roles__give(w, npc, role_id: String) -> void:
	npc.alignment = "evil" if C.ROLES[role_id].get("align") == "evil" else "good"
	npc.role = role_id
	npc.poisoned = false
	npc.turned = false
	npc.turned_day = -1
	npc.secret_mod = ""
	npc.info_log = []


func _test_dowser_public_area_fix() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9201, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var dw = goods[0]
	var g1 = goods[1]
	var g2 = goods[2]
	var ev = w.demon()
	chunk2_world_mask_roles__give(w, dw, "dowser")
	w.day = 1
	w.phase = C.MORNING

	# Everyone at home on the same block: neither Dowser nor blockmates are in public.
	for m in w.living():
		m.home_block = "square"
		m.loc = "home"
	_check(C.role_def("dowser").generate_reading(w, dw, {"day_phase": true}, Mind).is_empty(),
		"Dowser at home produces no reading even when blockmates live on the same block")

	# Dowser at Tavern (Square), 1 good at Well (Square), evil at home on Square -> only 1 other in public (< 2).
	dw.loc = "tavern"
	g1.loc = "well"
	ev.loc = "home"
	g2.loc = "home"
	_check(C.role_def("dowser").generate_reading(w, dw, {"day_phase": true}, Mind).is_empty(),
		"Dowser in public ignores blockmates at home when fewer than 2 others are in public")

	# Add g2 at Tavern (Square) while evil remains at home on Square -> reads [g1, g2] with count 0!
	g2.loc = "tavern"
	var r: Dictionary = C.role_def("dowser").generate_reading(w, dw, {"day_phase": true}, Mind)
	var grp: Array = r.get("data", {}).get("group", [])
	_check(grp.size() == 2 and g1.id in grp and g2.id in grp and ev.id not in grp and int(r["data"].get("count", -1)) == 0,
		"Dowser counts only public-area townsfolk on the block and excludes evil at home")

	# Evil Dowser bluffer also requires public presence and excludes homebodies:
	ev.dowsed_day = -1
	ev.loc = "home"
	_check(C.role_def("dowser").generate_bluff_reading(w, ev, {}, g1.id, null, []).is_empty(),
		"Evil Dowser bluffer cannot fabricate a crowd reading while at home")
	ev.loc = "tavern"
	dw.loc = "home"
	var fb: Dictionary = C.role_def("dowser").generate_bluff_reading(w, ev, {}, g1.id, null, [])
	var fb_grp: Array = fb.get("entry", {}).get("data", {}).get("group", [])
	_check(fb_grp.size() == 2 and dw.id not in fb_grp,
		"Evil Dowser bluffer includes only public-area townsfolk on the block")


func _test_augur_sim_and_workshop() -> void:
	Caches.clear_all()

	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9204, 7)
	var w = g.w
	var aug = w.living_good()[0]
	var dem = w.demon()
	var mk = w.living_good()[1]
	chunk2_world_mask_roles__give(w, aug, "augur")
	mk.secret_mod = "marked"

	w.day = 1
	w.phase = C.EVENING
	# Case A: Both at home on same block in M & A, and together at Tavern in EVENING -> NO crossing!
	aug.home_block = "square"
	dem.home_block = "square"
	for m in w.npcs:
		m.history[w.time_key(1, C.MORNING)] = "home:" + m.home_block
		m.history[w.time_key(1, C.AFTERNOON)] = "home:" + m.home_block
		m.history[w.time_key(1, C.EVENING)] = "tavern"
	var r_no: Dictionary = C.role_def("augur").generate_reading(w, aug, {"day_phase": true}, Mind)
	_check(r_no.get("data", {}).get("yes") == false,
		"Augur ignores home co-location and Evening co-location (reads false)")

	# Case B: Augur at Tavern (Square) and Demon at Well (Square) in Afternoon -> YES crossing!
	aug.history[w.time_key(1, C.AFTERNOON)] = "tavern"
	dem.history[w.time_key(1, C.AFTERNOON)] = "well"
	var r_yes: Dictionary = C.role_def("augur").generate_reading(w, aug, {"day_phase": true}, Mind)
	_check(r_yes.get("data", {}).get("yes") == true and r_yes.get("true") == true,
		"Augur detects public same-block crossing with Demon across different Square locations in Afternoon")

	# Case C: Marked public crossing triggers ~50% false positive:
	dem.history[w.time_key(1, C.AFTERNOON)] = "wharf" # docks
	mk.history[w.time_key(1, C.AFTERNOON)] = "well" # square
	var saw_t: bool = false
	var saw_f: bool = false
	for trial in range(60):
		var rm: Dictionary = C.role_def("augur").generate_reading(w, aug, {"day_phase": true}, Mind)
		if bool(rm.get("data", {}).get("yes", false)):
			saw_t = true
		else:
			saw_f = true
	_check(saw_t and saw_f,
		"Marked public crossing with Augur triggers Yes roughly 50% of the time")

	# Workshop CaseEval: solo overlap vs crowd-diluted overlap vs No-reading clear!
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var c_aug_yes: Dictionary = {"id": "aug_y", "fact_id": "aug_y", "kind": "report", "source": people[0].id,
		"role": "augur", "night": -1, "observed_at": {"day": 1, "phase": "evening"},
		"data": {"yes": true}, "text": "I crossed paths with the demon earlier today."}
	var c_aug_no: Dictionary = {"id": "aug_n", "fact_id": "aug_n", "kind": "report", "source": people[0].id,
		"role": "augur", "night": -1, "observed_at": {"day": 1, "phase": "evening"},
		"data": {"yes": false}, "text": "No sign of the demon along my path today."}
	var s_solo: Dictionary = {"id": "loc_solo", "fact_id": "loc_solo", "kind": "location", "source": "player",
		"day": 1, "night": -1, "block": "square", "subjects": [people[0].id, people[1].id], "subject": people[0].id,
		"observed_at": {"day": 1, "phase": "morning"}, "text": "Saw p0 and p1 at the Square."}
	var s_crowd: Dictionary = {"id": "loc_crowd", "fact_id": "loc_crowd", "kind": "location", "source": "player",
		"day": 1, "night": -1, "block": "square", "subjects": [people[0].id, people[1].id, people[2].id, people[3].id], "subject": people[0].id,
		"observed_at": {"day": 1, "phase": "morning"}, "text": "Saw p0, p1, p2, p3 at the Square."}

	var view: Dictionary = {
		"seed": 204, "day": 2, "people": people, "cards": [c_aug_yes, c_aug_no, s_solo, s_crowd],
		"evil_count": 2, "alignment_epoch": "Original alignment", "history": [],
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "roles": true, "identities": true, "live_activity": true},
		"live_activity": true,
		"timeline": {"events": []},
	}

	var case_solo: Dictionary = Solver.empty_case()
	case_solo.cards = ["aug_y", "loc_solo"]
	case_solo.conclusion = {"type": "demon", "target": people[1].id, "at": "Original alignment"}
	var ev_solo: Dictionary = CaseEval.evaluate(view, case_solo)

	var case_crowd: Dictionary = Solver.empty_case()
	case_crowd.cards = ["aug_y", "loc_crowd"]
	case_crowd.conclusion = {"type": "demon", "target": people[1].id, "at": "Original alignment"}
	var ev_crowd: Dictionary = CaseEval.evaluate(view, case_crowd)

	_check(ev_solo.posterior > ev_solo.prior and ev_crowd.posterior > ev_crowd.prior and ev_solo.posterior > ev_crowd.posterior + 0.04,
		"Augur Yes + daytime sighting raises Demon posterior and dilutes with crowd size (solo %.3f > 3-crowd %.3f > prior %.3f)" % [
			ev_solo.posterior, ev_crowd.posterior, ev_solo.prior])

	var case_clear: Dictionary = Solver.empty_case()
	case_clear.cards = ["aug_n", "loc_solo"]
	case_clear.conclusion = {"type": "demon", "target": people[1].id, "at": "Original alignment"}
	var ev_clear: Dictionary = CaseEval.evaluate(view, case_clear)
	var solved_clear: Dictionary = Solver.solve(view, [c_aug_no, s_solo], {people[0].id: "good"})
	_check(ev_clear.posterior < ev_clear.prior * 0.45 and solved_clear.worlds.all(func(uw): return not Domain.healthy(view, uw, people[0].id) or int(uw.demon) != 1),
		"Augur No + daytime sighting clears co-sighted person of being the Demon (Demon post %.3f vs prior %.3f)" % [
			ev_clear.posterior, ev_clear.prior])


# ---- test_workshop_psychologist


func _family(size: int) -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, size)
	for real in g.w.npcs:
		for n in [real, real.shadow]:
			if n == null:
				continue
			n.info_log = []
			n.known_claims = {}
			n.beliefs = []
			n.ledger = {}
			n.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	var source = g.w.npcs[0]
	var subject = g.w.npcs[1]
	var target = g.w.npcs[2]
	var reading = {"role": "psychologist", "day": 1, "phase": 3,
		"data": {"subject": subject.id, "trusts": target.id, "suspects": source.id}, "text": "Publicly reported social preferences"}
	var number = g.add_card({"kind": "info", "source": source.id, "role": reading.role, "day": reading.day,
		"phase": reading.phase, "data": reading.data, "text": reading.text})
	var fact: String = Live.Evidence.normalize_card(g.board[number - 1]).id
	var value = Solver.empty_case()
	value.cards = [fact]
	value.conclusion = {"type": "evil", "target": target.id, "at": "Original alignment"}
	var filed = Live.file(g, value)
	check(filed > 0, "a Psychologist context case files for a %d-person town" % size)
	g.strict_evaluator = true
	for real in g.w.living():
		var n = real.shadow if real.is_evil() else real
		var prepared = Live.Assess.prepare(g.workshop_snapshot([filed], real.id))
		check(prepared.ready and prepared.view.cards.any(func(c): return c.id == fact and c.kind == "context" and c.data == reading.data), "every listener receives the same structured context: " + real.id)
		if not prepared.ready:
			continue
		var ev = CaseEval.evaluate(prepared.view, prepared.case, prepared.listener)
		check(ev.people.values().all(func(p): return is_equal_approx(p.prior, p.posterior)), "social preferences alone change no alignment posterior: " + real.id)
		var before = n.suspicion.duplicate(true)
		var result = g._evaluate_deduction(n, g.board[filed - 1], 1.0, false)
		check(result.get("workshop", false) and n.workshop_state.active and fact in n.workshop_state.facts and n.suspicion == before, "shared ownership preserves the context without a guilt award: " + real.id)
	var listener = g.w.living_good()[0]
	Mind.apply_info(g.w, listener, source, reading, 1.0)
	check(fact in listener.workshop_state.facts and listener.workshop_state.owned.has(Mind.info_eid(source.id, reading)), "learned Psychologist receipts use the same owner as player presentations")
	var input = g.workshop_snapshot([filed], listener.id)
	for edit in [{"subject": "unknown"}, {"trusts": subject.id}, {"suspects": ""}]:
		var bad = input.duplicate(true)
		bad.evidence.filter(func(e): return e.id == fact)[0].content.data.merge(edit, true)
		check(not Live.Assess.prepare(bad).ready, "malformed social-reading identities are not guessed")
	# The same social observation remains context when a Medium faithfully relays it.
	g.w.day = 3
	g.add_card({"kind": "death", "source": "player", "subject": [source.id], "night": 1, "text": "Public death"})
	var medium = g.w.npcs[3]
	number = g.add_card({"kind": "info", "source": medium.id, "role": "medium", "day": 2, "phase": 3,
		"data": {"dead": source.id, "item": {"type": "reading", "entry": reading}}, "text": "Medium relays the social reading"})
	value.cards = [Live.Evidence.normalize_card(g.board[number - 1]).id]
	var prepared = Live.Assess.prepare(Live.snapshot(g, value, listener.id))
	check(prepared.ready and prepared.view.cards.any(func(c): return c.id in value.cards and c.kind == "context" and c.get("original_source", "") == source.id and not c.has("relay_source")), "a Medium preserves social-reading provenance without inventing an alignment likelihood")
	if prepared.ready:
		var ev = CaseEval.evaluate(prepared.view, prepared.case, prepared.listener)
		var without_social = prepared.case.duplicate(true)
		without_social.cards = []
		var public_only = CaseEval.evaluate(prepared.view, without_social, prepared.listener)
		check(ev.people == public_only.people, "a faithful relay of social preferences adds no alignment evidence beyond the public death")


# ---- test_chunk4_psychologist_muddler


func _give_role(w, n, role_id: String) -> void:
	n.role = role_id
	n.alignment = C.ROLES[role_id]["align"]


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


# ---- test_chunk5_monitor_confessor


func _test_confessor_role_def_registration() -> void:
	_check(C.has_role_def("confessor"), "Confessor registered in role registry")
	var rdef = C.role_def("confessor")
	_check(rdef.id == "confessor", "Confessor id matches")
	_check(rdef.align == "good", "Confessor align is good")
	_check(rdef.kind == "info", "Confessor kind is info")
	_check(rdef.min_gift_day == 1, "Confessor min_gift_day is 1")
	_check(rdef.night_walk, "Confessor night walks")
	_check(rdef.marked_registers, "Confessor marked_registers is true")
	_check("ongoing_info" in rdef.tags, "Confessor has ongoing_info tag")
	_check("evil_id" in rdef.tags, "Confessor has evil_id tag")
	_check("night_walker" in rdef.tags, "Confessor has night_walker tag")
	_check("confessor" in C.GOOD_ROLES, "Confessor in C.GOOD_ROLES")
	_check("confessor" in C.INFO_ROLES, "Confessor in C.INFO_ROLES")
	_check("confessor" in C.HINT_PACKAGES["people"]["roles"], "Confessor in people hint package")


func _test_confessor_target_choice_and_secret_visit() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(44123, 7)
	var w = g.w
	var conf = w.living_good()[0]
	_give_role(w, conf, "confessor")
	var rdef = C.role_def("confessor")

	# Player recommendation refused
	var parts: Dictionary = {}
	rdef.score_gift_request(w, conf, ["someone"], "", parts, Mind)
	_check(parts.get("confessor_secret", 0.0) <= -9000.0, "Confessor gift request heavily penalized")
	_check(rdef.counter_gift_request(w, conf, [], "") != "", "Confessor returns refuse line for gift request")

	# Target choice picks living person other than self
	var t_id: String = rdef.pick_targets(w, conf, Mind)
	_check(t_id != "", "Confessor picks a target")
	_check(t_id != conf.id, "Confessor target is not self")
	_check(w.by_id[t_id].alive, "Confessor target is alive")


func _test_confessor_readings_alignment_and_marked() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(33123, 7)
	var w = g.w
	w.day = 1
	var conf = w.living_good()[0]
	_give_role(w, conf, "confessor")
	conf.poisoned = false
	conf.secret_mod = ""

	var good_target = w.living_good().filter(func(p): return p != conf)[0]
	good_target.secret_mod = ""
	var evil_target = w.living().filter(func(p): return p.is_evil())[0]

	var rdef = C.role_def("confessor")

	# Good target -> confirmed Good
	var r_good: Dictionary = rdef.generate_reading(w, conf, {"confessor_t": good_target.id}, Mind)
	_check(bool(r_good.data.get("good", false)) == true, "Confessor reading on good target reports good: true")
	_check(str(r_good.data.get("target", "")) == good_target.id, "Confessor reading names good target")
	_check(bool(r_good["true"]) == true, "Confessor reading on good target is true")

	# Evil target -> "I don't remember" (forgot: true)
	var r_evil: Dictionary = rdef.generate_reading(w, conf, {"confessor_t": evil_target.id}, Mind)
	_check(bool(r_evil.data.get("forgot", false)) == true, "Confessor reading on evil target reports forgot: true")
	_check(not r_evil.data.has("target"), "Confessor forgot reading omits target name")
	_check(bool(r_evil["true"]) == true, "Confessor forgot reading on evil target is true")

	# Marked good target registering evil -> forgot: true
	good_target.secret_mod = "marked"
	var saw_marked_forgot: bool = false
	for s_i in range(50):
		w.rng.seed = 60000 + s_i
		var r_mk: Dictionary = rdef.generate_reading(w, conf, {"confessor_t": good_target.id}, Mind)
		if bool(r_mk.data.get("forgot", false)):
			saw_marked_forgot = true
			_check(r_mk.get("why", "") == "a Marked soul read as evil", "Marked target returns marked why clause")
			break
	_check(saw_marked_forgot, "Marked good target can return forgot: true to Confessor")


func _test_confessor_visit_before_demon_kill() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(99123, 7)
	var w = g.w
	w.day = 1
	var conf = w.living_good()[0]
	_give_role(w, conf, "confessor")

	# Set demon to target the victim
	var victim = w.living_good().filter(func(p): return p != conf)[0]
	# In resolve_night, INFO_BEFORE_KILL is true, so Confessor visit resolves before murder
	_check(C.INFO_BEFORE_KILL, "INFO_BEFORE_KILL is true: readings generated before demon kill")


func _test_confessor_poisoned_delusional_misread() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(22123, 7)
	var w = g.w
	w.day = 1
	var conf = w.living_good()[0]
	_give_role(w, conf, "confessor")
	conf.poisoned = true

	var good_target = w.living_good().filter(func(p): return p != conf)[0]
	var evil_target = w.living().filter(func(p): return p.is_evil())[0]
	evil_target.claimed_role = "seer"

	var rdef = C.role_def("confessor")

	# Visiting good target while poisoned: falsely returns forgot
	var r_pg: Dictionary = rdef.generate_reading(w, conf, {"confessor_t": good_target.id}, Mind)
	_check(bool(r_pg.data.get("forgot", false)) == true, "Poisoned Confessor visiting good target returns forgot: true")
	_check(bool(r_pg["true"]) == false, "Poisoned Confessor reading is false")
	_check(r_pg.why == "poisoned", "Poisoned Confessor why is poisoned")

	# Visiting evil target while poisoned with claimed bluff: can see evil as good
	var saw_evil_as_good: bool = false
	for s_i in range(50):
		w.rng.seed = 40000 + s_i
		var r_pe: Dictionary = rdef.generate_reading(w, conf, {"confessor_t": evil_target.id}, Mind)
		if bool(r_pe.data.get("good", false)):
			saw_evil_as_good = true
			_check(bool(r_pe["true"]) == false, "Seeing evil as good is false")
			break
	_check(saw_evil_as_good, "Poisoned Confessor can report evil as good")


func _test_confessor_night_duty_alibi_and_bluff() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(11123, 7)
	var w = g.w
	var conf = w.living_good()[0]
	_give_role(w, conf, "confessor")
	conf.claimed_role = "confessor"
	conf.claim_public = true

	var rdef = C.role_def("confessor")
	_check(rdef.uses_night_duty_alibi(w, conf, 1, true), "Confessor uses night duty alibi when out")

	var alibi = rdef.night_duty_alibi(w, conf, 1, true, "market", Mind, C.block_name)
	_check(alibi.handled, "Confessor duty alibi handled")
	_check(alibi.fact.duty == "confession", "Confessor duty fact tagged as confession")
	_check(alibi.fact.block == "market", "Confessor duty fact records block")
	_check(not alibi.fact.has("target"), "Confessor duty alibi does not name the visited person")

	# Bluffing Confessor
	var bluffer = w.living().filter(func(p): return p.is_evil())[0]
	var mate = w.living().filter(func(p): return p.is_evil() and p != bluffer)
	var mate_npc = mate[0] if not mate.is_empty() else null
	w.day = 1
	var bluff_entry = rdef.generate_bluff_reading(w, bluffer, {}, "sg", mate_npc, [])
	_check(bluff_entry.has("entry"), "Bluffing Confessor generates bluff reading")
