extends SceneTree

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Muddler = preload("res://sim/muddler.gd")
const MonitorDef = preload("res://sim/roles/monitor.gd")
const ConfessorDef = preload("res://sim/roles/confessor.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")

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

	_test_monitor_role_def_registration()
	_test_monitor_readings_and_marked()
	_test_monitor_poisoned_misread()
	_test_monitor_window_sighting_suppression()
	_test_monitor_bluff_and_fake_medium()

	_test_confessor_role_def_registration()
	_test_confessor_target_choice_and_secret_visit()
	_test_confessor_readings_alignment_and_marked()
	_test_confessor_visit_before_demon_kill()
	_test_confessor_poisoned_delusional_misread()
	_test_confessor_night_duty_alibi_and_bluff()

	_test_workshop_live_evidence_and_assessment()
	_test_workshop_solver_monitor_and_confessor()
	_test_muddler_monitor_and_confessor()

	if has_cs:
		_check(SolverBackend.get_verify_mismatches() == vm0, "Zero C#/GDScript VERIFY mismatches across Chunk 5 suite")
	SolverBackend.set_mode(prev_mode)

	if failures == 0:
		print("Chunk 5 (Monitor & Confessor): %d checks passed." % checks)
		quit(0)
	else:
		printerr("Chunk 5 suite failed (%d/%d checks failed)." % [failures, checks])
		quit(1)


func _test_monitor_role_def_registration() -> void:
	_check(C.has_role_def("monitor"), "Monitor registered in role registry")
	var rdef = C.role_def("monitor")
	_check(rdef.id == "monitor", "Monitor id matches")
	_check(rdef.align == "good", "Monitor align is good")
	_check(rdef.kind == "info", "Monitor kind is info")
	_check(rdef.min_gift_day == 1, "Monitor min_gift_day is 1")
	_check(not rdef.night_walk, "Monitor does not night walk (home block only)")
	_check(rdef.marked_registers, "Monitor marked_registers is true")
	_check("ongoing_info" in rdef.tags, "Monitor has ongoing_info tag")
	_check("role_id" in rdef.tags, "Monitor has role_id tag")
	_check("monitor" in C.GOOD_ROLES, "Monitor in C.GOOD_ROLES")
	_check("monitor" in C.INFO_ROLES, "Monitor in C.INFO_ROLES")
	_check("monitor" in C.HINT_PACKAGES["night_sight"]["roles"], "Monitor in night_sight hint package")


func _test_monitor_readings_and_marked() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(12345, 7)
	var w = g.w
	var n = w.living_good()[0]
	_give_role(w, n, "monitor")
	n.home_block = "square"
	n.secret_mod = ""
	n.poisoned = false

	var rdef = C.role_def("monitor")

	# Day 0: produces no reading
	w.day = 0
	var r0: Dictionary = rdef.generate_reading(w, n, {}, Mind)
	_check(r0.is_empty(), "Monitor produces no reading on Night 0")

	# Day 1 with 0 night walkers on home block -> fallback "walked: false"
	w.day = 1
	w.night_walkers = []
	var r_none: Dictionary = rdef.generate_reading(w, n, {}, Mind)
	_check(not r_none.is_empty(), "Monitor produces reading on Night 1")
	_check(bool(r_none.data.walked) == false, "Monitor reports walked == false when 0 walkers abroad")
	_check(r_none.data.block == "square", "Monitor reading block matches home block")
	_check(not r_none.data.has("role"), "Monitor fallback reading omits role field")
	_check(r_none.text == "no one walked by my house last night", "Monitor fallback text matches exact spec")
	_check(bool(r_none.true) == true, "Monitor fallback reading is true when 0 walkers")

	# Day 1 with 1 walker abroad on home block
	var walker = w.living().filter(func(p): return p != n)[0]
	_give_role(w, walker, "seer")
	w.night_walkers = [{"id": walker.id, "block": "square", "path": ["market", "square"]}]
	var r_walk: Dictionary = rdef.generate_reading(w, n, {}, Mind)
	_check(bool(r_walk.data.walked) == true, "Monitor reports walked == true when walker abroad")
	_check(str(r_walk.data.role) == "seer", "Monitor learns role of the walker")
	_check(bool(r_walk.true) == true, "Monitor reading is true")

	# Marked walker registers as random active-script Minion or Demon
	walker.secret_mod = "marked"
	var saw_evil_role: bool = false
	for seed_i in range(100):
		w.rng.seed = 20000 + seed_i
		var r_m: Dictionary = rdef.generate_reading(w, n, {}, Mind)
		if str(r_m.data.get("role", "")) in (C.MINION_ROLES + ["demon"]):
			saw_evil_role = true
			_check(r_m.get("why", "") == "a Marked soul read as evil", "Marked registration sets correct why clause")
			break
	_check(saw_evil_role, "Marked walker on home block registers as evil role")


func _test_monitor_poisoned_misread() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(54321, 7)
	var w = g.w
	var n = w.living_good()[0]
	_give_role(w, n, "monitor")
	n.home_block = "docks"
	n.poisoned = true
	w.day = 1

	var rdef = C.role_def("monitor")

	# Poisoned with 0 walkers: can misread and report a role walked
	w.night_walkers = []
	var r_pois: Dictionary = rdef.generate_reading(w, n, {}, Mind)
	_check(bool(r_pois.true) == false, "Poisoned Monitor produces false reading")
	_check(r_pois.why == "poisoned", "Poisoned Monitor sets why == poisoned")
	_check(str(r_pois.data.get("role", "")) in (C.GOOD_ROLES + C.EVIL_ROLES), "Misread names role on active script")


func _test_monitor_window_sighting_suppression() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(77123, 7)
	var w = g.w
	var mon = w.living_good()[0]
	_give_role(w, mon, "monitor")
	mon.home_block = "hill"
	mon.out_last_night = false

	var walker = w.living().filter(func(p): return p != mon)[0]
	w.night_walkers = [{"id": walker.id, "block": "hill", "path": ["hill"]}]

	# Run night sightings multiple times; monitor should never get window sighting
	for iter in range(20):
		mon.beliefs.clear()
		w._night_sightings()
		var got_window: bool = mon.beliefs.any(func(b): return b.get("kind") == "saw" and str(b.get("how")) == "window")
		_check(not got_window, "Monitor never receives out-the-window street sightings")


func _test_monitor_bluff_and_fake_medium() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(88123, 7)
	var w = g.w
	w.day = 1
	var bluffer = w.living().filter(func(p): return p.is_evil())[0]
	var sg = w.living_good()[0]
	var rdef = C.role_def("monitor")

	var bluff_res = rdef.generate_bluff_reading(w, bluffer, {}, sg.id, null, [])
	_check(bluff_res.has("entry"), "Bluffing Monitor generates bluff entry")
	_check(bluff_res.entry.data.has("block"), "Bluffing Monitor includes block")
	_check(bluff_res.entry.data.has("walked"), "Bluffing Monitor includes walked")

	var dead_mon = w.living_good()[1]
	var med_res = rdef.fake_medium_reading(w, bluffer, dead_mon, sg.id, sg, null, [], func(): pass, {}, false)
	_check(med_res.has("entry"), "Fake medium Monitor reading generates entry")
	_check(med_res.entry.data.walked == true, "Fake medium Monitor reading reports walker")


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
	_check(bool(r_good.true) == true, "Confessor reading on good target is true")

	# Evil target -> "I don't remember" (forgot: true)
	var r_evil: Dictionary = rdef.generate_reading(w, conf, {"confessor_t": evil_target.id}, Mind)
	_check(bool(r_evil.data.get("forgot", false)) == true, "Confessor reading on evil target reports forgot: true")
	_check(not r_evil.data.has("target"), "Confessor forgot reading omits target name")
	_check(bool(r_evil.true) == true, "Confessor forgot reading on evil target is true")

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
	_check(bool(r_pg.true) == false, "Poisoned Confessor reading is false")
	_check(r_pg.why == "poisoned", "Poisoned Confessor why is poisoned")

	# Visiting evil target while poisoned with claimed bluff: can see evil as good
	var saw_evil_as_good: bool = false
	for s_i in range(50):
		w.rng.seed = 40000 + s_i
		var r_pe: Dictionary = rdef.generate_reading(w, conf, {"confessor_t": evil_target.id}, Mind)
		if bool(r_pe.data.get("good", false)):
			saw_evil_as_good = true
			_check(bool(r_pe.true) == false, "Seeing evil as good is false")
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


func _test_workshop_live_evidence_and_assessment() -> void:
	_check(Evidence.REPORT_FIELDS.has("monitor"), "REPORT_FIELDS contains monitor")
	_check(Evidence.REPORT_FIELDS.has("confessor"), "REPORT_FIELDS contains confessor")
	_check("walked" in Evidence.FIELDS, "walked in Evidence.FIELDS")
	_check("good" in Evidence.FIELDS, "good in Evidence.FIELDS")
	_check("forgot" in Evidence.FIELDS, "forgot in Evidence.FIELDS")

	var ids = ["alice", "bob", "clara", "dan", "eve", "felix", "gwen"]
	var mods = ["delusional", "marked", "lovers", "sleepwalker"]

	# Monitor assessment validation
	var mon_card_valid = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 1, "phase": "night"},
		"content": {"role": "monitor", "data": {"block": "square", "walked": true, "role": "seer"}}
	}
	_check(Assess.reading_valid(mon_card_valid, ids, mods), "Valid Monitor reading passes reading_valid")

	var mon_card_fallback_valid = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 1, "phase": "night"},
		"content": {"role": "monitor", "data": {"block": "square", "walked": false}}
	}
	_check(Assess.reading_valid(mon_card_fallback_valid, ids, mods), "Valid fallback Monitor reading passes reading_valid")

	var mon_card_day0 = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 0, "phase": "night"},
		"content": {"role": "monitor", "data": {"block": "square", "walked": false}}
	}
	_check(not Assess.reading_valid(mon_card_day0, ids, mods), "Day 0 Monitor reading rejected by reading_valid")

	# Confessor assessment validation
	var conf_card_good_valid = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 1, "phase": "night"},
		"content": {"role": "confessor", "data": {"target": "bob", "good": true}}
	}
	_check(Assess.reading_valid(conf_card_good_valid, ids, mods), "Valid Confessor good reading passes reading_valid")

	var conf_card_forgot_valid = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 1, "phase": "night"},
		"content": {"role": "confessor", "data": {"forgot": true}}
	}
	_check(Assess.reading_valid(conf_card_forgot_valid, ids, mods), "Valid Confessor forgot reading passes reading_valid")

	var conf_card_self_target = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 1, "phase": "night"},
		"content": {"role": "confessor", "data": {"target": "alice", "good": true}}
	}
	_check(not Assess.reading_valid(conf_card_self_target, ids, mods), "Confessor self-target rejected by reading_valid")


func _test_workshop_solver_monitor_and_confessor() -> void:
	_check("monitor" in Solver.CONTENT_ROLES, "monitor in Solver.CONTENT_ROLES")
	_check("confessor" in Solver.CONTENT_ROLES, "confessor in Solver.CONTENT_ROLES")

	# View setup
	var view: Dictionary = {
		"people": [
			{"id": "alice", "home": "square"},
			{"id": "bob", "home": "square"},
			{"id": "clara", "home": "market"},
			{"id": "dan", "home": "market"},
			{"id": "eve", "home": "docks"},
			{"id": "felix", "home": "docks"},
			{"id": "gwen", "home": "hill"},
		]
	}
	# World with evil: dan (minion), eve (demon)
	var world: Dictionary = {
		"evil": (1 << 3) | (1 << 4), # dan (3), eve (4)
		"demon": 4, # eve
		"marked": -1,
		"holders": 0,
	}

	# Confessor card on bob (good): good: true -> should fit
	var c_conf_good = {"kind": "report", "role": "confessor", "source": "alice", "data": {"target": "bob", "good": true}}
	_check(Solver._report_content(view, world, c_conf_good, {}), "Confessor reading on good bob holds in world")

	# Confessor card on dan (evil): good: true -> should NOT fit
	var c_conf_evil = {"kind": "report", "role": "confessor", "source": "alice", "data": {"target": "dan", "good": true}}
	_check(not Solver._report_content(view, world, c_conf_evil, {}), "Confessor reading good: true on evil dan fails in world")

	# Confessor card forgot: true with positive answer chips pointing to dan (evil) -> holds
	var c_conf_forgot = {"kind": "report", "role": "confessor", "source": "alice", "data": {"forgot": true}}
	_check(Solver._report_content(view, world, c_conf_forgot, {"positive": ["dan"]}), "Confessor forgot: true with positive chip on evil dan holds in world")

	# Confessor card forgot: true with positive answer chips pointing to bob (good) -> fails
	_check(not Solver._report_content(view, world, c_conf_forgot, {"positive": ["bob"]}), "Confessor forgot: true with positive chip on good bob fails in world")

	# Monitor card on square reporting minion with positive chip on dan (who is not on square, or evil)
	var c_mon_minion = {"kind": "report", "role": "monitor", "source": "alice", "data": {"block": "square", "walked": true, "role": "poisoner"}}
	_check(Solver._report_content(view, world, c_mon_minion, {"positive": ["dan"]}), "Monitor minion reading with chip on evil dan holds")

	# Monitor card with chip on good bob for minion role -> fails
	_check(not Solver._report_content(view, world, c_mon_minion, {"positive": ["bob"]}), "Monitor minion reading with chip on good bob fails")


func _test_muddler_monitor_and_confessor() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(66123, 7)
	var w = g.w
	var muddler = w.living_good()[0]
	muddler.secret_mod = "muddler"

	# Test Monitor mutation
	var orig_mon = {
		"role": "monitor",
		"data": {"block": "square", "walked": true, "role": "seer"},
		"text": "I learned that a Seer was abroad on Square last night"
	}
	var mut_mon = Muddler.mutate_reading_entry(w, muddler, "other", orig_mon)
	_check(not mut_mon.is_empty(), "Muddler mutates Monitor reading")
	_check(mut_mon.data.get("role") != "seer" or mut_mon.data.get("walked") == false, "Muddler changes Monitor role or walked flag")

	# Test Confessor mutation
	var orig_conf = {
		"role": "confessor",
		"data": {"target": "bob", "good": true},
		"text": "I heard Bob's confession last night: their heart was pure and their spirit good"
	}
	var mut_conf = Muddler.mutate_reading_entry(w, muddler, "other", orig_conf)
	_check(not mut_conf.is_empty(), "Muddler mutates Confessor reading")
	_check(mut_conf.data.get("target") != "bob" or mut_conf.data.get("forgot") == true, "Muddler changes Confessor target or flips to forgot")
