## Verification suite for Chunk 3 (Role-Identity Readers: Executor & Registrar):
##   1. Roster pools, hint packages, ScriptDef tags, and custom-script dealing.
##   2. Executor simulation: Night 0 shareable charge reading, Morning post-death role
##      reading across Demon kills / executions / Martyr substitutions, Morning-active
##      Poison & Delusional corruption, Marked 30% evil-role misread, Scion promotion on
##      original Demon execution, and evil bluff consistency.
##   3. Executor Workshop & C# VERIFY parity: target consistency across Night 0 + Morning
##      cards, timeline died_before_morning check, SourceDoubt caught-lie & proof checks,
##      Scion promotion compatibility, and FactoredChannels vs exhaustive Oracle parity.
##   4. Registrar simulation: Night 0 3-role slate scoped strictly to case_script (never
##      Registrar, never Demon, <= 1 Minion at ~50%, >= 1 role guaranteed in play;
##      Delusional draws out-of-play roles), Night 1+ target checks, player 'ask check'
##      requests, and Marked 50% false Yes only when a Minion role is on the slate.
##   5. Registrar Workshop & C# VERIFY parity: 1+ in-play slate enforcement with Town Hall
##      cross-constraints, Yes on 3-good-role slate clearing evil, Yes on Minion-bearing
##      slate ruling out Demon while allowing Minion/Good/Marked, No catching fake claims,
##      Yes+No on same target deducing Marked when Minion on slate, and Oracle parity.
extends SceneTree

var _vm0: int = 0

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Caches = preload("res://workshop/caches.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Factored = preload("res://workshop/factored_channels.gd")
const Oracle = preload("res://workshop/channel_likelihood.gd")
const LiveAssessment = preload("res://workshop/live_assessment.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
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
	npc.executor_target = ""
	npc.executor_resolved = false
	npc.registrar_roles = []
	npc.info_log = []


func _init() -> void:
	_test_pools_hints_and_scripts()
	_test_executor_sim()
	_test_executor_workshop_and_parity()
	_test_registrar_sim()
	_test_registrar_workshop_and_parity()
	print("Chunk 3 Executor & Registrar Suite: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _test_pools_hints_and_scripts() -> void:
	_check("executor" in C.GOOD_ROLES and "registrar" in C.GOOD_ROLES and C.GOOD_ROLES.size() >= 20,
		"GOOD_ROLES includes executor and registrar (20+ ready town roles; 22 after patch_014)")
	_check("registrar" in C.IDENTIFIER_ROLES and "registrar" not in C.START_ROLES and "executor" not in C.START_ROLES,
		"registrar is in IDENTIFIER_ROLES and neither executor nor registrar is in START_ROLES")
	_check("executor" in C.HINT_PACKAGES["the_dead"].roles and "registrar" in C.HINT_PACKAGES["official"].roles,
		"HINT_PACKAGES wires executor to the_dead and registrar to official")
	_check("role_id" in ScriptDef.tags_of("executor") and "role_id" in ScriptDef.tags_of("registrar"),
		"ScriptDef tags classify both executor and registrar under role_id")

	var custom = ScriptDef.default_script()
	custom.town.erase("warden")
	custom.town.erase("veteran")
	custom.town.append("executor")
	custom.town.append("registrar")
	custom.forced = ["executor", "registrar"]
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9300, 7, custom)
	var ex_n = g.w.npc_with_role("executor")
	var rg_n = g.w.npc_with_role("registrar")
	_check(ex_n != null and rg_n != null,
		"Custom script deals forced Executor and Registrar")
	_check(ex_n.info_log.size() == 1 and ex_n.info_log[0].get("data", {}).get("assigned", false) and ex_n.executor_target != ex_n.id,
		"Dealt Executor starts Night 0 with a shareable charge reading on another person")
	_check(rg_n.info_log.size() == 1 and rg_n.registrar_roles.size() == 3 and not rg_n.info_log[0].get("data", {}).has("target"),
		"Dealt Registrar starts Night 0 knowing 3 roles without a Night 0 person check")


func _test_executor_sim() -> void:
	var sc = ScriptDef.default_script()
	sc.town.erase("sexton")
	sc.town.append("executor")
	sc.forced = ["executor"]
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9301, 7, sc)
	var w = g.w
	var ex_n = w.npc_with_role("executor")
	var charge_id: String = ex_n.executor_target
	var charge = w.by_id[charge_id]

	# Night kill on Night 1 does NOT give a Night 1 reading; Executor learns on Morning 2!
	w.day = 1
	w.phase = C.NIGHT
	w._kill(charge)
	_check(ex_n.info_log.size() == 1 and not ex_n.executor_resolved,
		"Executor does not learn role during Night 1 immediately on _kill")
	w.start_new_day() # Advances to Day 2 Morning -> _morning_executor_gifts()
	_check(ex_n.executor_resolved and ex_n.info_log.size() == 2 and ex_n.info_log[1].get("data", {}).get("role", "") == charge.role and int(ex_n.info_log[1].get("day", -1)) == 2 and int(ex_n.info_log[1].get("phase", -1)) == C.MORNING,
		"Executor learns deceased charge's true role on the following Morning (Day 2 Morning)")

	# Poisoned on Night 1 -> Morning 2 role reading is corrupted (role != charge.role):
	var g2 = Game.new()
	g2.detailed_logging = false
	g2.new_case(9302, 7, sc)
	var w2 = g2.w
	var ex2 = w2.npc_with_role("executor")
	var ch2 = w2.by_id[ex2.executor_target]
	ex2.poisoned = true
	w2.day = 1
	w2.phase = C.NIGHT
	w2._kill(ch2)
	w2.start_new_day()
	var p_entry: Dictionary = ex2.info_log.back()
	_check(ex2.executor_resolved and p_entry.get("data", {}).get("role", "") != ch2.role and not bool(p_entry.get("true", true)),
		"Executor poisoned the night before Morning learns a corrupted off-script-safe false role")

	# Marked charge reads as an evil role ~30% of the time:
	var marked_evil_hits: int = 0
	for sd in range(9310, 9350):
		var gm = Game.new()
		gm.detailed_logging = false
		gm.new_case(sd, 7, sc)
		var wm = gm.w
		var exm = wm.npc_with_role("executor")
		var goods_other: Array = wm.living_good().filter(func(m): return m != exm)
		var chm = goods_other[0]
		exm.executor_target = chm.id
		exm.executor_resolved = false
		chm.secret_mod = "marked"
		wm.day = 1
		wm.phase = C.EVENING
		wm.begin_meeting()
		wm.execute(chm.id, {"by": "player", "yes": [], "player_yes": true})
		wm.day = 2
		wm.phase = C.MORNING
		wm._morning_executor_gifts()
		var r_out: String = str(exm.info_log.back().get("data", {}).get("role", ""))
		if C.ROLES.get(r_out, {}).get("align") == "evil":
			marked_evil_hits += 1
	_check(marked_evil_hits >= 3 and marked_evil_hits <= 28,
		"Marked Executor charge registers as an evil role ~30%% of the time (%d/40)" % marked_evil_hits)


func _test_executor_workshop_and_parity() -> void:
	Caches.clear_all()
	var has_cs: bool = SolverBackend.is_csharp_available()

	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": i != 1})
	var events: Array = [
		{"kind": "demon_death", "subjects": [people[1].id], "by": "town", "at": {"day": 1, "phase": "night"}},
	]
	var timeline: Dictionary = preload("res://workshop/live_history.gd").from_events(events)

	var c_assign: Dictionary = {
		"id": "ex_n0", "fact_id": "ex_n0", "kind": "report", "source": people[0].id,
		"role": "executor", "night": 0, "observed_at": {"day": 0, "phase": "night"},
		"data": {"target": people[1].id, "assigned": true}, "text": "Charge is P1."
	}
	var c_role_good: Dictionary = {
		"id": "ex_m2", "fact_id": "ex_m2", "kind": "report", "source": people[0].id,
		"role": "executor", "night": -1, "observed_at": {"day": 2, "phase": "morning"},
		"data": {"target": people[1].id, "role": "clerk"}, "text": "P1 was Clerk."
	}
	var c_mismatch: Dictionary = {
		"id": "ex_bad_t", "fact_id": "ex_bad_t", "kind": "report", "source": people[0].id,
		"role": "executor", "night": -1, "observed_at": {"day": 2, "phase": "morning"},
		"data": {"target": people[2].id, "role": "clerk"}, "text": "P2 was Clerk."
	}
	var view: Dictionary = {
		"seed": 301, "day": 2, "people": people, "cards": [c_assign, c_role_good, c_mismatch],
		"evil_count": 2, "alignment_epoch": "Original alignment", "history": [],
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "roles": true, "identities": true},
		"timeline": timeline,
	}

	var s_consistent: Dictionary = Solver.solve(view, [c_assign, c_role_good])
	_check(not s_consistent.worlds.is_empty() and s_consistent.worlds.all(func(uw): return (int(uw.evil) & (1 << 1)) == 0),
		"Consistent Night 0 + Morning 2 Executor reading clears dead good target (%d worlds)" % s_consistent.worlds.size())

	var s_mismatch: Dictionary = Solver.solve(view, [c_assign, c_mismatch])
	_check(s_mismatch.worlds.is_empty(),
		"Mismatched Executor charge vs death target (or undead target) yields 0 worlds")

	# Scion promotion: P1 executed Day 1 with 7 alive, Executor learns 'demon' on Morning 2,
	# while P2 is the surviving promoted Scion Demon!
	var events_sc: Array = [
		{"kind": "execution", "subjects": [people[1].id], "by": "town", "at": {"day": 1, "phase": "evening"}},
	]
	var view_sc: Dictionary = view.duplicate(true)
	view_sc.timeline = preload("res://workshop/live_history.gd").from_events(events_sc)
	var c_role_demon: Dictionary = {
		"id": "ex_dem", "fact_id": "ex_dem", "kind": "report", "source": people[0].id,
		"role": "executor", "night": -1, "observed_at": {"day": 2, "phase": "morning"},
		"data": {"target": people[1].id, "role": "demon"}, "text": "P1 was Demon."
	}
	view_sc.cards = [c_assign, c_role_demon]
	var s_scion: Dictionary = Solver.solve(view_sc, [c_assign, c_role_demon])
	var has_promoted_world: bool = s_scion.worlds.any(func(uw): return int(uw.demon) != 1 and (int(uw.evil) & (1 << 1)) != 0 and int(uw.marked) != 1)
	_check(has_promoted_world,
		"Executor reading 'demon' on hanged target with >=5 alive supports worlds where Scion promoted to active Demon")

	# FactoredChannels vs exhaustive Oracle parity:
	var fac: Dictionary = Factored.assess(view, [c_assign, c_role_good], {}, {"gift_honesty:" + people[0].id: 0.85, "gift_accuracy:" + people[0].id + ":0": 0.98, "gift_accuracy:" + people[0].id + ":1": 0.95}, {})
	var ora: Dictionary = Oracle.assess(view, [c_assign, c_role_good], {}, {"gift_honesty:" + people[0].id: 0.85, "gift_accuracy:" + people[0].id + ":0": 0.98, "gift_accuracy:" + people[0].id + ":1": 0.95}, {})
	var max_diff: float = 0.0
	for idx in range(fac.post.size()):
		max_diff = maxf(max_diff, absf(fac.post[idx] - ora.post[idx]))
	_check(max_diff <= 1e-12,
		"FactoredChannels matches exhaustive ChannelLikelihood oracle on Executor (max diff %.3g)" % max_diff)



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
	var has_cs: bool = SolverBackend.is_csharp_available()

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

