## Gifts of official business (hint package 'official'): Surveyor, Clerk, Archivist, Chronicler, Magistrate, Registrar; plus the Seer's pair reading, which the Clerk/Archivist suite shares.
## Merged from: test_chunk2_world_mask_roles, test_chunk3_executor_registrar, test_workshop_clerk_archivist_seer, test_workshop_surveyor_answers.
extends SceneTree

const Factored = preload("res://workshop/factored_channels.gd")
const ReadingChallenges = preload("res://workshop/reading_challenges.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const Game = preload("res://game/game.gd")
const Caches = preload("res://workshop/caches.gd")
const Oracle = preload("res://workshop/channel_likelihood.gd")
const C = preload("res://sim/content.gd")
const Graph = preload("res://workshop/case_graph.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Editor = preload("res://ui/live_case_workshop.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_chunk2_world_mask_roles()
	_run_workshop_surveyor_answer()
	_run_chunk3_executor_registra()
	await _run_workshop_clerk_archivist()
	print("Roles: official business: %d checks, %d failures" % [checks, fails])
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


# ---------------------------------------------------------------- from test_chunk2_world_mask_roles

func _run_chunk2_world_mask_roles() -> void:
	_test_surveyor_rework_and_workshop()
	_test_chronicler_sim_and_workshop()
	_test_magistrate_sim_and_workshop()


# ---------------------------------------------------------------- from test_workshop_surveyor_answers

func _run_workshop_surveyor_answer() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/workshop_checkpoint_v5.json"))
	var core: Dictionary = data.examples.filter(func(e): return e.name == "core")[0]
	var view: Dictionary = core.view
	var card: Dictionary = view.cards.filter(func(c): return c.get("role", "") == "surveyor")[0]
	card.data.count = 2
	var value: Dictionary = Solver.empty_case()
	value.cards = [card.id]
	value.conclusion = core.case.conclusion.duplicate(true)
	var block: String = view.people[0].home
	var plain = CaseEval.evaluate(view, value)
	value.answers[card.id] = {"positive": [], "blocks": [block]}
	check(Solver.validate_answers(view, value).is_empty(), "a known block can fill an unresolved Surveyor slot")
	var answered = CaseEval.evaluate(view, value)
	check(plain.people == answered.people and plain.posterior == answered.posterior, "a block answer never adds alignment evidence")
	check(answered.theory_fit > 0 and answered.theory_fit < 1, "a block answer tests the fit of the supplied hypothesis")
	var unconditioned = Solver.report_table(view, card)
	var conditioned = Solver.report_table(view, card, [], [block])
	check(conditioned != unconditioned, "report-table caching includes block answers")
	check(Solver.solve(view, [card], {}, value.answers).worlds.size() < Solver.solve(view, [card]).worlds.size(), "the conditional logical solve narrows the Surveyor explanation")
	for answer in [
		{"positive": [], "blocks": ["unknown"]},
		{"positive": [], "blocks": [block, block]},
		{"positive": [view.people[0].id], "blocks": [block]},
		{"positive": [], "blocks": ["square", "market", "docks", "hill", "square"]}]:
		value.answers[card.id] = answer
		check(not Solver.validate_answers(view, value).is_empty(), "invalid or overlapping block slots receive explicit feedback")
	var other: Dictionary = view.cards.filter(func(c): return c.get("role", "") == "dowser")[0]
	value.cards = [other.id]
	value.answers = {other.id: {"positive": [], "blocks": [block]}}
	check(not Solver.validate_answers(view, value).is_empty(), "non-Surveyor answers cannot introduce block slots")
	value.cards = [card.id]
	value.answers = {}
	value.lines = [
		{"id": "a", "label": "First", "cards": [card.id], "answers": {card.id: {"positive": [], "blocks": ["square"]}}},
		{"id": "b", "label": "Second", "cards": [card.id], "answers": {card.id: {"positive": [], "blocks": ["market"]}}}]
	check(not Graph.compile_case(view, value).graph_errors.is_empty(), "supporting lines cannot silently overwrite different block answers")


# ---------------------------------------------------------------- from test_chunk3_executor_registrar

func _run_chunk3_executor_registra() -> void:
	_test_registrar_sim()
	_test_registrar_workshop_and_parity()


# ---------------------------------------------------------------- from test_workshop_clerk_archivist_seer

func _run_workshop_clerk_archivist() -> void:
	await _run()


# ---- test_chunk2_world_mask_roles


func _give(w, npc, role_id: String) -> void:
	npc.alignment = "evil" if C.ROLES[role_id].get("align") == "evil" else "good"
	npc.role = role_id
	npc.poisoned = false
	npc.turned = false
	npc.turned_day = -1
	npc.secret_mod = ""
	npc.info_log = []


func _test_surveyor_rework_and_workshop() -> void:
	Caches.clear_all()

	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9202, 7)
	var w = g.w
	var surv = w.living_good()[0]
	_give(w, surv, "surveyor")
	w.day = 0
	w.phase = C.NIGHT

	for trial in range(30):
		var sr: Dictionary = C.role_def("surveyor").generate_reading(w, surv, {}, Mind)
		var blk: String = str(sr.get("data", {}).get("block", ""))
		var res_n: int = w.npcs.filter(func(m): return m.home_block == blk).size()
		if blk == "" or blk == surv.home_block or res_n < 2 or not (sr.get("data", {}).get("same") is bool):
			_check(false, "Surveyor reading violated block eligibility on trial %d" % trial)
			break
	_check(true, "Surveyor always picks a non-own block with at least 2 residents")

	# Build a deterministic 7-NPC live view:
	#   hill (2): p0 (Surveyor), p1
	#   docks (2): p2 (killed by Demon on N1!), p3 (target!)
	#   square (3): p4, p5, p6
	#   market (0)
	var homes: Array = ["hill", "hill", "docks", "docks", "square", "square", "square"]
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": homes[i], "alive": i != 2})

	var c_same: Dictionary = {"id": "sv_same", "fact_id": "sv_same", "kind": "report", "source": people[0].id,
		"role": "surveyor", "night": 0, "observed_at": {"day": 0, "phase": "night"},
		"data": {"block": "docks", "same": true}, "text": "All folk on the Docks share the same alignment."}
	var c_diff: Dictionary = {"id": "sv_diff", "fact_id": "sv_diff", "kind": "report", "source": people[0].id,
		"role": "surveyor", "night": 0, "observed_at": {"day": 0, "phase": "night"},
		"data": {"block": "docks", "same": false}, "text": "Not everyone on the Docks shares the same alignment."}
	var c_sq3: Dictionary = {"id": "sv_sq3", "fact_id": "sv_sq3", "kind": "report", "source": people[0].id,
		"role": "surveyor", "night": 0, "observed_at": {"day": 0, "phase": "night"},
		"data": {"block": "square", "same": true}, "text": "All folk on the Square share the same alignment."}

	var view: Dictionary = {
		"seed": 202, "day": 2, "people": people, "cards": [c_same, c_diff, c_sq3],
		"evil_count": 2, "alignment_epoch": "Original alignment", "history": [],
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "roles": true, "identities": true},
		"timeline": {"deaths": {people[2].id: 2}, "death_ticks": {people[2].id: 7}, "executions": {},
			"events": [{"kind": "demon_death", "subjects": [people[2].id], "at": {"day": 1, "phase": "night"}, "by": ""}]},
	}

	# 2-home block + Demon kill + Surveyor same=true -> strong good signal for p3!
	var case_good: Dictionary = Solver.empty_case()
	case_good.cards = ["sv_same"]
	case_good.conclusion = {"type": "good", "target": people[3].id, "at": "Original alignment"}
	var ev_good: Dictionary = CaseEval.evaluate(view, case_good)
	_check(ev_good.lr > Tuning.Workshop.LR_MODERATE and ev_good.people[people[3].id].posterior < 0.12,
		"2-home Docks same=true + Demon kill on roommate gives strong good support for survivor (LR=%.2f, P(evil)=%.3f)" % [ev_good.lr, ev_good.people[people[3].id].posterior])

	# 2-home block + Demon kill + Surveyor same=false -> strong evil signal for p3!
	var case_evil: Dictionary = Solver.empty_case()
	case_evil.cards = ["sv_diff"]
	case_evil.conclusion = {"type": "evil", "target": people[3].id, "at": "Original alignment"}
	var ev_evil: Dictionary = CaseEval.evaluate(view, case_evil)
	_check(ev_evil.lr > Tuning.Workshop.LR_MODERATE and ev_evil.posterior > 0.55,
		"2-home Docks same=false + Demon kill on roommate gives strong evil support for survivor (LR=%.2f, post=%.3f)" % [ev_evil.lr, ev_evil.posterior])

	# 3-home block same=true -> clears all 3 residents in non-Marked worlds and sharply drops evil posterior!
	var view_no_mark: Dictionary = view.duplicate(true)
	view_no_mark.world_options.modifiers = ["sleepwalker", "lovers"]
	var solved_sq3: Dictionary = Solver.solve(view_no_mark, [c_sq3])
	var sq_mask: int = (1 << 4) | (1 << 5) | (1 << 6)
	_check(not solved_sq3.worlds.is_empty() and solved_sq3.worlds.all(func(w): return (int(w.evil) & sq_mask) == 0),
		"3-home Square same=true clears all 3 residents in 2-evil non-Marked worlds (%d worlds)" % solved_sq3.worlds.size())

	# Challenge gate: 'unlikely' is disabled on new parity Surveyor and enabled only on legacy count Surveyor:
	var c_legacy: Dictionary = {"id": "sv_leg", "fact_id": "sv_leg", "kind": "report", "source": people[0].id,
		"role": "surveyor", "night": 0, "observed_at": {"day": 0, "phase": "night"}, "data": {"count": 2}, "text": "2 blocks."}
	view.cards.append(c_legacy)
	_check(not ReadingChallenges.valid(view, "sv_same", {"mode": "unlikely", "supports": []}) and ReadingChallenges.valid(view, "sv_leg", {"mode": "unlikely", "supports": []}),
		"ReadingChallenges restricts 'unlikely' mode to legacy count-based Surveyor cards")


func _test_chronicler_sim_and_workshop() -> void:
	Caches.clear_all()

	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9203, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var chr = goods[0]
	var mk = goods[1]
	var ord1 = goods[2]
	var ord2 = goods[3]
	var ord3 = goods[4]
	var orig_minion = w.by_id[w.minion_ids[0]]
	var orig_demon = w.demon()

	_give(w, chr, "chronicler")
	_give(w, mk, "warden")
	_give(w, ord1, "seer")
	_give(w, ord2, "clerk")
	_give(w, ord3, "dowser")
	mk.secret_mod = "marked"
	w.initial_minion_ids = [orig_minion.id]
	w.initial_evil_ids = [orig_demon.id, orig_minion.id]
	w.initial_secret_holders = [mk.id]

	# Night 1 and Night 2 produce nothing; Night 3 reads case-start state even after
	# orig_demon is executed, orig_minion promotes via Scion, mk dies, and ord1 turns evil!
	w.day = 2
	w.phase = C.NIGHT
	_check(C.role_def("chronicler").generate_reading(w, chr, {}, Mind).is_empty(),
		"Chronicler does not fire before Night 3")

	orig_demon.alive = false
	orig_demon.death_day = 2
	orig_demon.death_cause = "executed"
	orig_minion.role = "demon"
	w.demon_id = orig_minion.id
	w.minion_ids = []
	mk.alive = false
	mk.death_day = 2
	mk.death_cause = "demon"
	w.turn_evil(ord1, "test Revenant curse")

	w.day = 3
	var cr: Dictionary = C.role_def("chronicler").generate_reading(w, chr, {}, Mind)
	var trio: Array = cr.get("data", {}).get("trio", [])
	_check(trio.size() == 3 and chr.id not in trio and orig_minion.id in trio and mk.id in trio and trio.any(func(x): return x in [ord1.id, ord2.id, ord3.id]),
		"Chronicler Night-3 reading never names self, places Marked in secret slot, and reads case-start Minion/folk across death, Scion, and curse")

	# Workshop Solver + CaseEval + FactoredChannels vs Oracle parity:
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var c_chr: Dictionary = {"id": "chr_3", "fact_id": "chr_3", "kind": "report", "source": people[0].id,
		"role": "chronicler", "night": 3, "observed_at": {"day": 3, "phase": "night"},
		"data": {"trio": [people[1].id, people[2].id, people[3].id]},
		"text": "Chronicler trio."}
	var view: Dictionary = {
		"seed": 203, "day": 4, "people": people, "cards": [c_chr],
		"evil_count": 2, "alignment_epoch": "Original alignment", "history": [],
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "roles": true, "identities": true},
		"timeline": {"events": []},
	}
	var solved: Dictionary = Solver.solve(view, [c_chr])
	var t_mask: int = (1 << 1) | (1 << 2) | (1 << 3)
	var all_valid: bool = not solved.worlds.is_empty() and solved.worlds.all(func(uw):
		var d_bit: int = 1 << int(uw.demon)
		var min_m: int = int(uw.evil) & ~d_bit
		var sec_m: int = int(uw.holders) & ~int(uw.evil)
		var flk_m: int = ((1 << 7) - 1) & ~int(uw.evil) & ~sec_m
		return (int(uw.evil) & 1) == 0 and (int(uw.holders) & ~1) != 0 and (t_mask & min_m) != 0 and (t_mask & sec_m) != 0 and (t_mask & flk_m) != 0)
	_check(all_valid,
		"Solver.solve enforces Chronicler case-start Minion + secret-holder + ordinary folk partition (%d worlds)" % solved.worlds.size())

	# Optional positive Minion pick:
	var solved_pick: Dictionary = Solver.solve(view, [c_chr], {}, {"chr_3": {"positive": [people[2].id]}})
	_check(not solved_pick.worlds.is_empty() and solved_pick.worlds.all(func(uw): return (int(uw.evil) & (1 << 2)) != 0 and int(uw.demon) != 2),
		"Selecting a person on Chronicler card pins them as the case-start Minion")

	var fac: Dictionary = Factored.assess(view, [c_chr], {}, {"gift_honesty:" + people[0].id: 0.85, "gift_accuracy:" + people[0].id + ":3": 0.95}, {})
	var ora: Dictionary = Oracle.assess(view, [c_chr], {}, {"gift_honesty:" + people[0].id: 0.85, "gift_accuracy:" + people[0].id + ":3": 0.95}, {})
	var max_diff: float = 0.0
	for idx in range(fac.post.size()):
		max_diff = maxf(max_diff, absf(fac.post[idx] - ora.post[idx]))
	_check(max_diff <= 1e-12,
		"FactoredChannels matches exhaustive ChannelLikelihood oracle on Chronicler (max diff %.3g)" % max_diff)


func _test_magistrate_sim_and_workshop() -> void:
	Caches.clear_all()

	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9205, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var mag = goods[0]
	var g1 = goods[1]
	var g2 = goods[2]
	var rev = w.by_id[w.minion_ids[0]]
	_give(w, mag, "magistrate")
	_give(w, rev, "revenant")

	w.day = 1
	w.phase = C.NIGHT
	w.public_log = []
	# 1. Player nomination + Magistrate's own nomination only -> NO eligible nomination -> empty reading!
	w.public_log.append({"day": 1, "phase": C.EVENING, "kind": "nomination", "by": "player", "subjects": [g1.id]})
	w.public_log.append({"day": 1, "phase": C.EVENING, "kind": "nomination", "by": mag.id, "subjects": [g2.id]})
	var real_empty: bool = C.role_def("magistrate").generate_reading(w, mag, {}, Mind).is_empty()
	# A bluffer skips the player's and its own nominations (the real Magistrate's is fair game).
	var saved_log: Array = w.public_log.duplicate(true)
	w.public_log = [saved_log[0], {"day": 1, "phase": C.EVENING, "kind": "nomination", "by": rev.id, "subjects": [g2.id]}]
	var bluff_empty: bool = C.role_def("magistrate").generate_bluff_reading(w, rev, {}, g1.id, null, []).is_empty()
	w.public_log = saved_log
	_check(real_empty and bluff_empty,
		"Magistrate skips player and own nominations and produces no reading (real or bluff) if none left")

	# 2. Add g1 (good) nominating rev (evil Revenant), then simulate rev hanging & cursing g1 at end of Day 1:
	w.public_log.append({"day": 1, "phase": C.EVENING, "kind": "nomination", "by": g1.id, "subjects": [rev.id]})
	w.turn_evil(g1, "test Revenant curse at end of Day 1 meeting")
	var mr1: Dictionary = C.role_def("magistrate").generate_reading(w, mag, {}, Mind)
	_check(mr1.get("data", {}) == {"nominator": g1.id, "nominee": rev.id, "same": false} and mr1.get("true") == true,
		"Magistrate reads first non-player/non-Magistrate nomination and evaluates alignment at nomination time (before Day-1 curse)")

	# 3. On Day 2 while g1 is already cursed, g1 nominating good g2 reads same=false (cursed = evil)!
	w.day = 2
	w.public_log.append({"day": 2, "phase": C.EVENING, "kind": "nomination", "by": g1.id, "subjects": [g2.id]})
	var mr2: Dictionary = C.role_def("magistrate").generate_reading(w, mag, {}, Mind)
	_check(mr2.get("data", {}) == {"nominator": g1.id, "nominee": g2.id, "same": false} and mr2.get("true") == true,
		"Magistrate treats a previously Revenant-cursed nominator as evil on subsequent days")

	# 4. Workshop Solver + public nomination timeline check + Demon-kill inference:
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": i != 1})
	var c_mag_diff: Dictionary = {"id": "mag_1", "fact_id": "mag_1", "kind": "report", "source": people[0].id,
		"role": "magistrate", "night": 1, "observed_at": {"day": 1, "phase": "night"},
		"data": {"nominator": people[1].id, "nominee": people[2].id, "same": false},
		"text": "p1 and p2 did not share an alignment."}
	var c_mag_fake_pair: Dictionary = {"id": "mag_bad", "fact_id": "mag_bad", "kind": "report", "source": people[0].id,
		"role": "magistrate", "night": 1, "observed_at": {"day": 1, "phase": "night"},
		"data": {"nominator": people[3].id, "nominee": people[4].id, "same": true},
		"text": "Fabricated pair."}

	var events: Array = [
		{"kind": "nomination", "by": "player", "subjects": [people[5].id], "at": {"day": 1, "phase": "evening"}},
		{"kind": "nomination", "by": people[0].id, "subjects": [people[6].id], "at": {"day": 1, "phase": "evening"}},
		{"kind": "nomination", "by": people[1].id, "subjects": [people[2].id], "at": {"day": 1, "phase": "evening"}},
		{"kind": "meeting", "by": "town", "subjects": [], "at": {"day": 1, "phase": "evening"}},
		{"kind": "demon_death", "by": "", "subjects": [people[1].id], "at": {"day": 1, "phase": "night"}},
	]
	var view: Dictionary = {
		"seed": 205, "day": 2, "people": people, "cards": [c_mag_diff, c_mag_fake_pair],
		"evil_count": 2, "alignment_epoch": "Original alignment", "history": [],
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "roles": true, "identities": true},
		"timeline": {"deaths": {people[1].id: 2}, "death_ticks": {people[1].id: 7}, "executions": {}, "events": events},
	}

	# Fabricated nomination pair contradicts public timeline for a good healthy Magistrate:
	var solved_bad: Dictionary = Solver.solve(view, [c_mag_fake_pair])
	_check(solved_bad.worlds.is_empty(),
		"Solver rejects Magistrate reading whose (nominator, nominee) contradicts the public meeting log")

	# Valid (p1 -> p2, same=false) + p1 killed by Demon -> strong evil signal on p2!
	var case_m: Dictionary = Solver.empty_case()
	case_m.cards = ["mag_1"]
	case_m.conclusion = {"type": "evil", "target": people[2].id, "at": "Original alignment"}
	var ev_m: Dictionary = CaseEval.evaluate(view, case_m)
	_check(ev_m.lr > Tuning.Workshop.LR_MODERATE and ev_m.posterior > 0.55,
		"Magistrate same=false + Demon kill on nominator gives strong evil support on nominee (LR=%.2f, post=%.3f)" % [ev_m.lr, ev_m.posterior])


# ---- test_chunk3_executor_registrar


func _test_registrar_sim() -> void:
	# Custom script excluding several town & minion roles: Registrar slate must NEVER draw off-script!
	var sc = ScriptDef.default_script()
	sc.town = ["archivist", "clerk", "dowser", "gravedigger", "seer", "warden", "registrar"]
	sc.minions = ["poisoner", "scion"]
	sc.forced = ["registrar"]

	var min_slates: int = 0
	var all_on_script: bool = true
	var all_have_in_play: bool = true
	var never_self_or_demon: bool = true
	var max_one_minion: bool = true

	for sd in range(9360, 9420):
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(sd, 7, sc)
		var w = g.w
		var rg = w.npc_with_role("registrar")
		var slate: Array = rg.registrar_roles
		if rg.secret_mod == "delusional":
			continue
		if slate.size() != 3:
			all_on_script = false
			continue
		var m_cnt: int = 0
		var has_ip: bool = false
		for r in slate:
			if r == "registrar" or r == "demon":
				never_self_or_demon = false
			if r in sc.minions:
				m_cnt += 1
				if w.npcs.any(func(p): return p.role == r):
					has_ip = true
			elif r in sc.town:
				if r in w.initial_good_roles:
					has_ip = true
			else:
				all_on_script = false
		if m_cnt > 1:
			max_one_minion = false
		if m_cnt == 1:
			min_slates += 1
		if not has_ip:
			all_have_in_play = false

	_check(all_on_script and never_self_or_demon and max_one_minion and all_have_in_play,
		"Registrar Night 0 slate stays strictly on case_script, excludes registrar & demon, caps minions at 1, and guarantees >=1 role in play")
	_check(min_slates >= 15 and min_slates <= 45,
		"Registrar includes a minion role on ~50%% of slates (%d healthy trials)" % min_slates)

	# Regression (seeds 9397 & 9400): even when Poisoner hits Registrar on Night 0, the
	# permanent register keeps >=1 in-play role unless Delusional.
	for psd in [9397, 9400]:
		var g_p0 = Game.new()
		g_p0.detailed_logging = false
		g_p0.new_case(psd, 7, sc)
		var rg_p0 = g_p0.w.npc_with_role("registrar")
		if rg_p0.secret_mod != "delusional":
			var p0_ip: bool = rg_p0.registrar_roles.any(func(r): return (r in g_p0.w.initial_good_roles) or g_p0.w.npcs.any(func(p): return p.role == r))
			_check(p0_ip, "Registrar Night 0 slate keeps >=1 in-play role under Night 0 Poisoner (seed %d)" % psd)

	# Player 'ask check <name>' request + Marked registration check:
	var g_req = Game.new()
	g_req.detailed_logging = false
	g_req.new_case(9425, 7, sc)
	var w_req = g_req.w
	var rg_req = w_req.npc_with_role("registrar")
	rg_req.secret_mod = ""
	rg_req.trust = 0.95
	rg_req.claimed_role = "registrar"
	rg_req.claim_public = true
	var target_good = w_req.living_good().filter(func(m): return m != rg_req)[0]
	rg_req.registrar_roles = [target_good.role, "warden" if target_good.role != "warden" else "clerk", "poisoner"]
	g_req.talk_with = rg_req
	var req_res: Dictionary = g_req._gift_request(rg_req, "check", target_good.name)
	_check(bool(req_res.get("agreed", false)) and rg_req.gift_request.get("role", "") == "registrar" and rg_req.gift_request.get("targets", []) == [target_good.id],
		"Player 'ask check <name>' binds a tonight target request on a claimed Registrar")
	w_req.day = 1
	w_req.phase = C.NIGHT
	var n1_read: Dictionary = C.role_def("registrar").generate_reading(w_req, rg_req, {}, Mind)
	_check(str(n1_read.get("data", {}).get("target", "")) == target_good.id and bool(n1_read.get("data", {}).get("yes", false)) == true,
		"Registrar checks requested target on Night 1 and returns Yes when target holds a slate role")

	# Marked never triggers false Yes on a 3-good-role slate, and triggers ~50% on a Minion slate:
	target_good.secret_mod = "marked"
	var non_match_good: Array = ["archivist", "clerk", "dowser", "gravedigger", "seer", "warden"].filter(func(r): return r != target_good.role).slice(0, 3)
	rg_req.registrar_roles = non_match_good
	var false_yes_no_minion: int = 0
	for _i in range(30):
		rg_req.gift_request = {"night": 1, "role": "registrar", "targets": [target_good.id]}
		var rd_nm: Dictionary = C.role_def("registrar").generate_reading(w_req, rg_req, {}, Mind)
		if bool(rd_nm.get("data", {}).get("yes", false)):
			false_yes_no_minion += 1
	_check(false_yes_no_minion == 0,
		"Marked target never triggers false Yes when Registrar slate has only good roles")

	rg_req.registrar_roles = [non_match_good[0], non_match_good[1], "poisoner"]
	var false_yes_with_minion: int = 0
	for _i in range(40):
		rg_req.gift_request = {"night": 1, "role": "registrar", "targets": [target_good.id]}
		var rd_wm: Dictionary = C.role_def("registrar").generate_reading(w_req, rg_req, {}, Mind)
		if bool(rd_wm.get("data", {}).get("yes", false)):
			false_yes_with_minion += 1
	_check(false_yes_with_minion >= 8 and false_yes_with_minion <= 32,
		"Marked target triggers ~50%% false Yes when a Minion role is on the Registrar slate (%d/40)" % false_yes_with_minion)


func _test_registrar_workshop_and_parity() -> void:
	Caches.clear_all()

	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})

	# 1. 3-good-role slate Yes on P1 clears P1 of all evil roles:
	var c_slate_good: Dictionary = {
		"id": "rg_g1", "fact_id": "rg_g1", "kind": "report", "source": people[0].id,
		"role": "registrar", "night": 1, "observed_at": {"day": 1, "phase": "night"},
		"data": {"roles": ["clerk", "warden", "seer"], "target": people[1].id, "yes": true},
		"text": "Checked P1 against Clerk, Warden, Seer: yes."
	}
	# 2. Minion-bearing slate Yes on P2 rules out P2 as Demon, allows P2 as Minion or Good/Marked:
	var c_slate_min_yes: Dictionary = {
		"id": "rg_m1", "fact_id": "rg_m1", "kind": "report", "source": people[0].id,
		"role": "registrar", "night": 1, "observed_at": {"day": 1, "phase": "night"},
		"data": {"roles": ["clerk", "warden", "poisoner"], "target": people[2].id, "yes": true},
		"text": "Checked P2 against Clerk, Warden, Poisoner: yes."
	}
	# 3. Registrar No on P3 catches P3's Clerk claim:
	var c_claim_p3: Dictionary = {
		"id": "cl_p3", "fact_id": "cl_p3", "kind": "claim", "source": people[3].id,
		"role": "clerk", "observed_at": {"day": 1, "phase": "morning"}, "data": {}, "text": "I am Clerk."
	}
	var c_reg_no_p3: Dictionary = {
		"id": "rg_no3", "fact_id": "rg_no3", "kind": "report", "source": people[0].id,
		"role": "registrar", "night": 2, "observed_at": {"day": 2, "phase": "night"},
		"data": {"roles": ["clerk", "warden", "poisoner"], "target": people[3].id, "yes": false},
		"text": "Checked P3 against Clerk, Warden, Poisoner: no."
	}
	# 4. Registrar Yes + No on same P2 with Minion on slate forces P2 == Marked!
	var c_reg_no_p2: Dictionary = {
		"id": "rg_no2", "fact_id": "rg_no2", "kind": "report", "source": people[0].id,
		"role": "registrar", "night": 2, "observed_at": {"day": 2, "phase": "night"},
		"data": {"roles": ["clerk", "warden", "poisoner"], "target": people[2].id, "yes": false},
		"text": "Checked P2 against Clerk, Warden, Poisoner: no."
	}
	# 5. Town Hall ruling out Clerk & Warden while Registrar Night 0 slate is [Clerk, Warden, Dowser]
	#    forces Dowser to be in play (and if a 3rd Town Hall also rules out Dowser, 0 worlds!):
	var c_reg_n0: Dictionary = {
		"id": "rg_n0", "fact_id": "rg_n0", "kind": "report", "source": people[0].id,
		"role": "registrar", "night": 0, "observed_at": {"day": 0, "phase": "night"},
		"data": {"roles": ["clerk", "warden", "dowser"]}, "text": "Register: Clerk, Warden, Dowser."
	}
	var c_th1: Dictionary = {
		"id": "th_1", "fact_id": "th_1", "kind": "town_hall", "source": "player",
		"observed_at": {"day": 1, "phase": "morning"}, "data": {"roles": ["clerk", "seer"]}, "text": "TH1"
	}
	var c_th2: Dictionary = {
		"id": "th_2", "fact_id": "th_2", "kind": "town_hall", "source": "player",
		"observed_at": {"day": 1, "phase": "afternoon"}, "data": {"roles": ["warden", "archivist"]}, "text": "TH2"
	}
	var c_th3: Dictionary = {
		"id": "th_3", "fact_id": "th_3", "kind": "town_hall", "source": "player",
		"observed_at": {"day": 2, "phase": "morning"}, "data": {"roles": ["dowser", "medium"]}, "text": "TH3"
	}

	var view: Dictionary = {
		"seed": 305, "day": 3, "people": people,
		"cards": [c_slate_good, c_slate_min_yes, c_claim_p3, c_reg_no_p3, c_reg_no_p2, c_reg_n0, c_th1, c_th2, c_th3],
		"evil_count": 2, "alignment_epoch": "Original alignment", "history": [],
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "roles": true, "identities": true},
		"timeline": {"events": []},
	}

	var s_good_yes: Dictionary = Solver.solve(view, [c_slate_good])
	_check(not s_good_yes.worlds.is_empty() and s_good_yes.worlds.all(func(uw): return (int(uw.evil) & (1 << 1)) == 0),
		"Registrar Yes on a 3-good-role slate clears target of all evil roles (%d worlds)" % s_good_yes.worlds.size())

	var s_min_yes: Dictionary = Solver.solve(view, [c_slate_min_yes])
	var any_demon_p2: bool = s_min_yes.worlds.any(func(uw): return int(uw.demon) == 2)
	var any_min_p2: bool = s_min_yes.worlds.any(func(uw): return (int(uw.evil) & (1 << 2)) != 0 and int(uw.demon) != 2)
	var any_good_p2: bool = s_min_yes.worlds.any(func(uw): return (int(uw.evil) & (1 << 2)) == 0)
	_check(not s_min_yes.worlds.is_empty() and not any_demon_p2 and any_min_p2 and any_good_p2,
		"Registrar Yes on a Minion-bearing slate rules out Demon while allowing Minion and Good/Marked")

	var s_fake_claim: Dictionary = Solver.solve(view, [c_claim_p3, c_reg_no_p3])
	_check(s_fake_claim.worlds.is_empty(),
		"Solver catches contradiction between a true Clerk claim and Registrar No with Clerk on slate")
	var ev_fake_claim: Dictionary = CaseEval.evaluate(view, {
		"conclusion": {"type": "evil", "target": people[3].id},
		"cards": ["cl_p3", "rg_no3"],
		"lines": [], "positions": {}, "answers": {}, "reasons": {}, "citations": {},
	})
	_check(ev_fake_claim.lr > 2.0 and ev_fake_claim.posterior > ev_fake_claim.prior,
		"CaseEval strongly supports evil premise when Registrar No contradicts target's role claim (LR %.2f)" % ev_fake_claim.lr)

	var s_yes_and_no: Dictionary = Solver.solve(view, [c_slate_min_yes, c_reg_no_p2])
	_check(not s_yes_and_no.worlds.is_empty() and s_yes_and_no.worlds.all(func(uw): return int(uw.marked) == 2 and (int(uw.evil) & (1 << 2)) == 0),
		"Registrar Yes + No on same target with Minion on slate uniquely deduces target is Marked (%d worlds)" % s_yes_and_no.worlds.size())

	var s_th_two: Dictionary = Solver.solve(view, [c_reg_n0, c_th1, c_th2], {}, {
		"th_1": {"in_play_role": "seer"},
		"th_2": {"in_play_role": "archivist"},
	})
	var s_th_three: Dictionary = Solver.solve(view, [c_reg_n0, c_th1, c_th2, c_th3], {}, {
		"th_1": {"in_play_role": "seer"},
		"th_2": {"in_play_role": "archivist"},
		"th_3": {"in_play_role": "medium"},
	})
	_check(not s_th_two.worlds.is_empty() and s_th_three.worlds.is_empty(),
		"Registrar 1+ in-play slate constraint composes with Town Hall out-of-play exclusions")

	var fac: Dictionary = Factored.assess(view, [c_slate_min_yes, c_claim_p3, c_reg_no_p3], {}, {
		"gift_honesty:" + people[0].id: 0.85,
		"gift_honesty:" + people[3].id: 0.55,
		"gift_accuracy:" + people[0].id + ":1": 0.95,
		"gift_accuracy:" + people[0].id + ":2": 0.95,
		"gift_accuracy:" + people[0].id + ":3": 0.95,
	}, {})
	var ora: Dictionary = Oracle.assess(view, [c_slate_min_yes, c_claim_p3, c_reg_no_p3], {}, {
		"gift_honesty:" + people[0].id: 0.85,
		"gift_honesty:" + people[3].id: 0.55,
		"gift_accuracy:" + people[0].id + ":1": 0.95,
		"gift_accuracy:" + people[0].id + ":2": 0.95,
		"gift_accuracy:" + people[0].id + ":3": 0.95,
	}, {})
	var max_diff: float = 0.0
	for idx in range(fac.post.size()):
		max_diff = maxf(max_diff, absf(fac.post[idx] - ora.post[idx]))
	_check(max_diff <= 1e-12,
		"FactoredChannels matches exhaustive ChannelLikelihood oracle on Registrar + claim clash (max diff %.3g)" % max_diff)


# ---- test_workshop_clerk_archivist_seer


func report(id: String, source: String, role: String, data: Dictionary, night: int = 0) -> Dictionary:
	return {"id": id, "kind": "report", "source": source, "role": role, "data": data,
		"night": night, "observed_at": {"day": night, "phase": "night"}}


func _run() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id.to_upper(), "home": "square"})
	var view = {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment",
		"world_options": {"modifiers": ["marked", "delusional", "lovers", "sleepwalker"], "roles": true, "identities": true}}
	var world = {"evil": 96, "demon": 5, "marked": 4, "modifier": "marked", "holders": 16}
	var knowledge = {"self": "a", "good": ["a"], "own_role": "seer"}
	var clerk = report("clerk", "b", "clerk", {"pair": ["c", "d"], "role": "warden"})
	var matching = {"id": "claim", "kind": "claim", "source": "c", "role": "warden", "data": {}}
	check(Solver.Roles.fits(view, world, [clerk, matching], knowledge), "Clerk and matching claim admit a unique good-role completion")
	var outsider: Dictionary = matching.duplicate(true)
	outsider.source = "e"
	check(not Solver.Roles.fits(view, world, [clerk, outsider], knowledge), "outside unique-role claim conflicts with Clerk pair")
	var evil_claim: Dictionary = matching.duplicate(true)
	evil_claim.source = "g"
	check(not Solver.Roles.fits(view, world, [evil_claim], knowledge), "granting a good-role claim excludes an evil claimant")
	check(not Solver.Roles.fits(view, world, [clerk], knowledge, {"clerk": {"positive": ["f"]}}), "Clerk answer cannot designate someone outside its pair")
	var archivist = report("arch", "c", "archivist", {"pair": ["f", "d"], "role": "poisoner"})
	check(not Solver.Roles.fits(view, world, [archivist], knowledge), "Demon alone cannot satisfy a named-minion ping")
	archivist.data.pair = ["g", "d"]
	check(Solver.Roles.fits(view, world, [archivist], knowledge), "named minion plus good candidate fits Archivist")
	archivist.data.pair = ["d", "e"]
	check(not Solver.Roles.fits(view, world, [archivist], knowledge), "two good candidates cannot satisfy Archivist")
	var no = report("no", "a", "seer", {"pair": ["g", "b"], "yes": false})
	check(Solver.Roles.fits(view, world, [no], knowledge), "healthy Seer negative permits a minion")
	no.data.pair = ["f", "b"]
	check(not Solver.Roles.fits(view, world, [no], knowledge), "healthy negative excludes the Demon")
	var first = report("first", "a", "seer", {"pair": ["b", "c"], "yes": true})
	var second = report("second", "a", "seer", {"pair": ["d", "e"], "yes": true}, 1)
	var no_mark: Dictionary = world.duplicate(true)
	no_mark.marked = 0
	no_mark.holders = 1
	check(not Solver.Roles.fits(view, no_mark, [first, second], knowledge), "disjoint positives cannot use two different Red Herrings")
	check(Solver.Roles.fits(view, world, [first, second], knowledge), "one Red Herring and a different Marked ping explain disjoint positives")
	var negative = report("negative", "a", "seer", {"pair": ["b", "c"], "yes": false}, 1)
	check(not Solver.Roles.fits(view, no_mark, [first, negative], knowledge), "persistent Red Herring cannot switch off between readings")
	var marked: Dictionary = world.duplicate(true)
	marked.marked = 1
	marked.holders = 2
	check(Solver.Roles.fits(view, marked, [first, negative], knowledge), "Marked can explain same-pair no/yes without impairment")
	check(Solver.Roles.fits(view, marked, [first], knowledge, {"first": {"positive": ["b"], "registration": "red_herring"}}), "Red Herring may also be Marked")
	check(not Solver.Roles.fits(view, marked, [first, negative], knowledge, {"first": {"positive": ["b"], "registration": "red_herring"}}), "explicit Red Herring answer must fit later negatives")
	check(Assess.Domain.gift_time(first), "Night-zero Seer reading is supported")
	view.cards = [clerk]
	var solved = Solver.solve(view, [clerk], {"c": "evil"}, {}, knowledge)
	check(not solved.worlds.is_empty(), "Clerk survives another candidate being evil")
	check(solved.worlds.all(func(w): return not (w.evil & 8)), "Clerk plus candidate elimination forces remaining holder good")
	check(not Solver.position_holds(view, world, "g", "demon") and Solver.position_holds(view, world, "g", "minion"), "Demon/minion premise predicates distinguish identities")
	_challenges(view, knowledge, first, negative)
	var cached = Solver.solve(view, [clerk], {"c": "evil"}, {}, knowledge)
	Solver.Roles.reuse = false
	var uncached = Solver.solve(view, [clerk], {"c": "evil"}, {}, knowledge)
	Solver.Roles.reuse = true
	check(cached == uncached, "role completion caching preserves exact solver results")
	_live()
	_claim_routes()
	await _ui()
	print("Clerk/Archivist/Seer checks: %d; failures: %d" % [checks, fails])
	quit(1 if fails else 0)


func _challenges(view: Dictionary, knowledge: Dictionary, positive: Dictionary, negative: Dictionary) -> void:
	view.cards = [positive, negative]
	var listener = Ghost.profile(view.people)
	listener.knowledge = knowledge.duplicate(true)
	listener.npc_trust.a = 1.0
	var value = Solver.empty_case()
	value.conclusion.at = view.alignment_epoch
	value.cards = [positive.id, negative.id]
	value.reading_challenges = {positive.id: {"mode": "misled", "supports": [negative.id]}}
	var result = preload("res://workshop/reading_challenges.gd").assess(view, value, listener, [positive, negative])
	check(result.results[0].supported and result.results[0].multiplier == 1.0, "healthy Marked/Red Herring misdirection is recognized without discounting its registration")
	check(result.results[0].note.contains("without a broken gift"), "Misled feedback distinguishes registration from impairment")
	value.reading_challenges = {negative.id: {"mode": "misled", "supports": [positive.id]}}
	result = preload("res://workshop/reading_challenges.gd").assess(view, value, listener, [positive, negative])
	check(not result.results[0].supported and result.results[0].multiplier == 1.0, "same-pair flip supplies no automatic poisoning discount")
	var claimant = report("rival", "b", "seer", {"pair": ["c", "d"], "yes": false})
	view.cards = [claimant]
	value.cards = [claimant.id]
	value.reading_challenges = {claimant.id: {"mode": "lying", "supports": []}}
	result = preload("res://workshop/reading_challenges.gd").assess(view, value, listener, [claimant])
	check(result.results[0].agreement == 1.0 and not result.sources.has("b") and not result.reports.has(claimant.id), "firsthand unique-role contradiction supports dishonesty, and the lie keeps counting against the reader (no reliability discount)")
	value.reading_challenges[claimant.id].mode = "misled"
	var analysis = Solver.analyze(view, value, knowledge)
	check(analysis.proposed == 0, "Misled cannot excuse a duplicate unique role known firsthand")


func _live() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	var source = g.w.npcs[0]
	var targets: Array = g.w.npcs.filter(func(n): return n != source)
	var pair: Array = [targets[0].id, targets[1].id]
	for role in ["clerk", "archivist", "seer"]:
		var data: Dictionary = {"pair": pair, "role": "warden" if role == "clerk" else "poisoner"}
		if role == "seer":
			data = {"pair": pair, "yes": false}
		var number = g.add_card({"kind": "info", "role": role, "source": source.id, "subject": pair,
			"day": 0, "phase": 3, "data": data, "text": "Regression new role: " + role})
		var board = Canvas.new(Live.view(g))
		var root: String = board.selected
		board.nodes[root].conclusion.target = pair[0]
		var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
		board.connect_cards("e:" + id, root)
		var value = board.compile(root)
		check(Live.status(g, value).ready, role + " has complete live capability")
		var preview = Ghost.live(Live.snapshot(g, value))
		check(preview.ready and preview.proposal.assessment.compatible > 0, role + " neutral preview evaluates legal explanations")
		var filed = Live.file(g, value)
		check(filed > 0 and g.board[filed - 1].supports == [number], role + " filing preserves exact source receipt")
		var listener = g.w.living_good().filter(func(n): return n != source and n.id not in pair)[0]
		listener.info_log = []
		listener.known_claims = {}
		listener.ledger = {}
		listener.role = "warden"
		listener.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
		var response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.get("workshop", false), role + " reaches actual shared NPC presentation")
		var vector: Dictionary = listener.workshop_state.requested.duplicate(true)
		response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.repeated and listener.workshop_state.requested == vector, role + " presentation is repeat-stable")
		for type in ["demon", "minion"]:
			board.nodes[root].conclusion.type = type
			var identities = Ghost.live(Live.snapshot(g, board.compile(root)))
			check(identities.ready, role + " supports explicit " + type + " questions")
			check(Live.file(g, board.compile(root)) > 0, type + " premise files through the native board")


func _ui() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	var source = g.w.npcs[0]
	var pair: Array = g.w.npcs.filter(func(n): return n != source).slice(0, 2).map(func(n): return n.id)
	var number = g.add_card({"kind": "info", "role": "seer", "source": source.id, "subject": pair,
		"day": 0, "phase": 3, "data": {"pair": pair, "yes": true}, "text": "UI Seer registration regression."})
	var editor = Editor.new()
	editor.g = g
	root.add_child(editor)
	await process_frame

	editor.add_evidence(number)
	var evidence: String = editor.board.selected
	editor._open_answer(evidence)
	var selectors: Array = editor.case_box.find_children("*", "OptionButton", true, false)
	check(selectors.size() == 2, "live Seer answer offers person and registration-cause choices")
	selectors[0].item_selected.emit(1)
	selectors = editor.case_box.find_children("*", "OptionButton", true, false)
	selectors[1].item_selected.emit(2)
	var id: String = editor.board.nodes[evidence].card
	check(editor.board.nodes[evidence].answers[id].positive == [editor._report(id).data.pair[0]] and editor.board.nodes[evidence].answers[id].registration == "red_herring", "actual Seer UI retains chosen person and cause together")
	selectors = editor.case_box.find_children("*", "OptionButton", true, false)
	selectors[0].item_selected.emit(2)
	check(editor.board.nodes[evidence].answers[id].registration == "red_herring", "changing the selected person preserves the registration explanation")
	editor.answer_window.hide()
	check(str(editor.canvas.body(evidence)).contains("Red Herring"), "closed Seer card displays its registration explanation")
	editor._context(evidence)
	check(editor.context_menu.is_item_disabled(editor.context_menu.get_item_index(202)), "Unlikely stays visible but disabled for unsupported reading types")
	editor.context_menu.hide()
	editor.queue_free()
	await process_frame


func _claim_routes() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	var source = g.w.npcs[0]
	var pair: Array = g.w.npcs.filter(func(n): return n != source).slice(0, 2).map(func(n): return n.id)
	var reading = g.add_card({"kind": "info", "role": "clerk", "source": source.id, "subject": pair,
		"day": 0, "phase": 3, "data": {"pair": pair, "role": "warden"}, "text": "Claim-route Clerk regression."})
	var claim = g.add_card({"kind": "claim", "role": "warden", "source": pair[0], "subject": [pair[0]],
		"day": 1, "phase": 0, "text": "Claim-route Warden regression."})
	var board = Canvas.new(Live.view(g))
	var root_id: String = board.selected
	board.nodes[root_id].conclusion.target = pair[0]
	var reading_id: String = Live.Evidence.normalize_card(g.board[reading - 1]).id
	var claim_id: String = Live.Evidence.normalize_card(g.board[claim - 1]).id
	board.connect_cards("e:" + reading_id, root_id)
	var before = Ghost.live(Live.snapshot(g, board.compile(root_id)))
	board.connect_cards("e:" + claim_id, root_id)
	var after = Ghost.live(Live.snapshot(g, board.compile(root_id)))
	check(after.ready and after.proposal.effects[pair[0]].requested < before.proposal.effects[pair[0]].requested, "matching role claim adds conditional exoneration to Clerk evidence")
	var n = g.w.living_good().filter(func(p): return p != source and p.id not in pair)[0]
	n.info_log = []
	n.known_claims = {}
	n.ledger = {}
	n.role = "veteran"
	n.credibility = 0.0  # how far the player's word counts (credibility since Oct 30)
	var filed = Live.file(g, board.compile(root_id))
	var snapshot = g.workshop_snapshot([filed], n.id)
	snapshot.listener.source_doubt[pair[0] + ":*"] = 1.0
	var assessed = Assess.prepare(snapshot)
	check(assessed.ready and assessed.listener.reading_reliability[claim_id] == 1.0, "gift impairment cannot discount a role claim")
	var plan = preload("res://workshop/shared_ledger.gd").prepare(g.workshop_snapshot([], n.id), {str(filed): snapshot}, n.ledger)
	check(plan.ready and plan.prepared.listener.reading_reliability[claim_id] == 0.5, "player-only role-claim relay retains the player trust factor without a health assumption")
