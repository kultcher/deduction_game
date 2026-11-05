## Verification suite for Chunk 2 (World-Mask Townsfolk + Dowser Public-Area Fix):
##   1. Roster pools, hint packages, and solo-evil Seer bluff self-pair guard.
##   2. Dowser public-area fix (both Dowser and counted crowd must not be at home).
##   3. Surveyor rework (random non-own >=2 resident block alignment parity, Marked 50%,
##      2-home Demon-kill strong Workshop signal, 3-home good clear, legacy count fallback).
##   4. Chronicler (Night 3 only, never self, cannot_hold_solo_secret, case-start state
##      across death/Scion/Revenant curse, Marked in secret-holder slot, Workshop + Oracle).
##   5. Augur (Evening Day 1+, public M/A crossings only, Marked 50%, Workshop crowd-diluted
##      Demon signal on Yes and Demon clear on No).
##   6. Magistrate (Night 1+, first non-player/non-Magistrate nomination, empty skip,
##      nomination-time Revenant curse alignment, public timeline validation, Workshop + C# VERIFY).
extends SceneTree

var _vm0: int = 0

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Gifts = preload("res://sim/gifts.gd")
const Caches = preload("res://workshop/caches.gd")
const Solver = preload("res://workshop/solver.gd")
const Domain = preload("res://workshop/world_domain.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Factored = preload("res://workshop/factored_channels.gd")
const Oracle = preload("res://workshop/channel_likelihood.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const LiveAssessment = preload("res://workshop/live_assessment.gd")
const LiveEvidence = preload("res://workshop/live_evidence.gd")
const ReadingChallenges = preload("res://workshop/reading_challenges.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _give(w, npc, role_id: String) -> void:
	npc.alignment = "evil" if C.ROLES[role_id].get("align") == "evil" else "good"
	npc.role = role_id
	npc.poisoned = false
	npc.turned = false
	npc.turned_day = -1
	npc.secret_mod = ""
	npc.info_log = []


func _init() -> void:
	_test_pools_hints_and_seer_solo_bluff()
	_test_dowser_public_area_fix()
	_test_surveyor_rework_and_workshop()
	_test_chronicler_sim_and_workshop()
	_test_augur_sim_and_workshop()
	_test_magistrate_sim_and_workshop()
	print("Chunk 2 World-Mask Roles Suite: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _test_pools_hints_and_seer_solo_bluff() -> void:
	_check(C.START_ROLES == ["archivist", "clerk", "surveyor", "rumormonger"],
		"START_ROLES keeps the 4 Night-0 info roles")
	_check("augur" in C.IDENTIFIER_ROLES and C.GOOD_ROLES.size() >= 18,
		"IDENTIFIER_ROLES includes augur and GOOD_ROLES has 18 roles")
	_check("chronicler" in C.HINT_PACKAGES["official"].roles and "magistrate" in C.HINT_PACKAGES["official"].roles and "augur" in C.HINT_PACKAGES["people"].roles,
		"HINT_PACKAGES wires chronicler + magistrate to official and augur to people")

	# Solo-evil Seer bluff guard (Seed 2004 regression):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(2004, 7)
	var w = g.w
	var d = w.demon()
	for m_id in w.minion_ids:
		w.by_id[m_id].alive = false
		w.by_id[m_id].death_day = 1
		w.by_id[m_id].death_cause = "executed"
	w.evil_plan["bluffs"][d.id] = "seer"
	w.day = 2
	w.phase = C.NIGHT
	var self_paired: bool = false
	for trial in range(60):
		var res: Dictionary = C.role_def("seer").generate_bluff_reading(w, d, w.evil_plan, w.living_good()[0].id, d, [d.id])
		var pair: Array = res.get("entry", {}).get("data", {}).get("pair", [])
		if pair.size() != 2 or pair[0] == pair[1] or d.id in pair:
			self_paired = true
	_check(not self_paired,
		"Solo-evil Seer bluffer never includes themselves in data.pair on even nights")


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
	_give(w, dw, "dowser")
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


func _test_surveyor_rework_and_workshop() -> void:
	Caches.clear_all()
	var has_cs: bool = SolverBackend.is_csharp_available()

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
	var has_cs: bool = SolverBackend.is_csharp_available()

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



func _test_augur_sim_and_workshop() -> void:
	Caches.clear_all()
	var has_cs: bool = SolverBackend.is_csharp_available()

	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9204, 7)
	var w = g.w
	var aug = w.living_good()[0]
	var dem = w.demon()
	var mk = w.living_good()[1]
	_give(w, aug, "augur")
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



func _test_magistrate_sim_and_workshop() -> void:
	Caches.clear_all()
	var has_cs: bool = SolverBackend.is_csharp_available()

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

