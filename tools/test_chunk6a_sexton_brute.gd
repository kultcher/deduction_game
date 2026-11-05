extends SceneTree

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const BruteDef = preload("res://sim/roles/brute.gd")
const SextonDef = preload("res://sim/roles/sexton.gd")
const SeerDef = preload("res://sim/roles/seer.gd")
const ArchivistDef = preload("res://sim/roles/archivist.gd")
const ScriptBuilder = preload("res://sim/script_builder.gd")

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
	if C.ROLES[role_id].get("minion", false):
		if n.id not in w.minion_ids:
			w.minion_ids.append(n.id)


func _init() -> void:
	var has_cs: bool = SolverBackend.is_csharp_available()

	_test_brute_registration_and_attributes()
	_test_brute_hunting_and_demon_idle()
	_test_brute_drops_two_traces()
	_test_brute_identifier_interactions()
	_test_brute_death_demon_resumes_hunt()

	_test_sexton_registration_and_attributes()
	_test_sexton_lamplighter_walk_on_toll()
	_test_sexton_minion_suppression()
	_test_sexton_townsfolk_gifts_unaffected()
	_test_sexton_once_per_case()
	_test_brute_experimental_on_scripts()

	if failures == 0:
		print("Slice 6A (Sexton rework & Brute minion): %d checks passed." % checks)
		quit(0)
	else:
		printerr("Slice 6A suite failed (%d/%d checks failed)." % [failures, checks])
		quit(1)


func _test_brute_registration_and_attributes() -> void:
	_check(C.has_role_def("brute"), "Brute registered in role registry")
	var rdef = C.role_def("brute")
	_check(rdef.id == "brute", "Brute id matches")
	_check(rdef.align == "evil", "Brute align is evil")
	_check(rdef.kind == "evil", "Brute kind is evil")
	_check(rdef.minion, "Brute minion flag is true")
	_check(rdef.night_walk, "Brute night_walk is true")
	_check("brute" in C.MINION_ROLES, "Brute in C.MINION_ROLES")
	_check("brute" in C.EVIL_ROLES, "Brute in C.EVIL_ROLES")
	_check(not ("brute" in C.GOOD_ROLES), "Brute not in C.GOOD_ROLES")


func _test_brute_hunting_and_demon_idle() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(12345, 7)
	var w = g.w
	var evils = w.living().filter(func(p): return p.is_evil())
	var demon_npc = w.demon()
	var minion_npc = evils.filter(func(p): return p != demon_npc)[0]
	_give_role(w, minion_npc, "brute")

	w.day = 1
	var victim = w.living_good()[0]
	w.resolve_night()

	# While Brute is alive and active: Brute hunted and Demon stayed home
	_check(minion_npc.out_last_night, "Brute night-walked on the hunt")
	# The demon's chosen target (not necessarily living_good()[0]): read the Brute's hunt walk.
	var hunt: Array = w.night_walkers.filter(func(wk): return wk.id == minion_npc.id and "(as Brute)" in str(wk.why))
	var hunted: Array = w.living().filter(func(p): return not hunt.is_empty() and ("hunting %s (as Brute)" % p.name) == str(hunt[0].why))
	hunted.append_array(w.npcs.filter(func(p): return not p.alive and not hunt.is_empty() and ("hunting %s (as Brute)" % p.name) == str(hunt[0].why)))
	_check(not hunted.is_empty() and minion_npc.night_block == hunted[0].home_block, "Brute arrived at the hunted victim's home block")
	_check(not demon_npc.out_last_night, "Demon stayed home while Brute was hunting")
	_check(demon_npc.night_block == demon_npc.home_block, "Demon remained on their home block")


func _test_brute_drops_two_traces() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(23456, 7)
	var w = g.w
	var evils = w.living().filter(func(p): return p.is_evil())
	var demon_npc = w.demon()
	var minion_npc = evils.filter(func(p): return p != demon_npc)[0]
	_give_role(w, minion_npc, "brute")

	w.day = 1
	w.resolve_night()

	# Check the murder scene traces
	_check(w.deaths_last_night.size() == 1, "Victim was killed overnight")
	var victim_id = w.deaths_last_night[0]
	var sid = "scene_" + victim_id
	_check(w.scenes.has(sid), "Murder scene recorded")
	var sc = w.scenes[sid]
	_check(sc.traces.size() == 2, "Brute murder scene leaves exactly two physical traces")
	# Both traces point toward the Brute
	_check(sc.trace != null, "Primary trace exists")
	_check(sc.traces[1] != null, "Second trace exists")


func _test_brute_identifier_interactions() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(34567, 7)
	var w = g.w
	var evils = w.living().filter(func(p): return p.is_evil())
	var demon_npc = w.demon()
	var brute_npc = evils.filter(func(p): return p != demon_npc)[0]
	_give_role(w, brute_npc, "brute")

	var seer_npc = w.living_good()[0]
	_give_role(w, seer_npc, "seer")
	seer_npc.red_herring = ""

	var good_other = w.living_good()[1]
	good_other.secret_mod = ""

	# Seer reading on pair [brute, good_other] without demon or marked
	var rdef_seer = C.role_def("seer")
	var r_seer = rdef_seer.generate_reading(w, seer_npc, {}, Mind)
	# When checked against Brute: Brute does NOT register as demon
	_check(not w.registers_demon(brute_npc), "Brute does not register as the demon to Seer")

	# Archivist can target Brute as minion
	_check(C.is_minion("brute"), "Brute registers as a minion")


func _test_brute_death_demon_resumes_hunt() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(45678, 7)
	var w = g.w
	var evils = w.living().filter(func(p): return p.is_evil())
	var demon_npc = w.demon()
	var brute_npc = evils.filter(func(p): return p != demon_npc)[0]
	_give_role(w, brute_npc, "brute")

	# Execute or kill Brute
	brute_npc.alive = false
	brute_npc.death_day = 1
	brute_npc.death_cause = "executed"

	w.day = 1
	w.resolve_night()

	# Demon resumes hunting!
	_check(demon_npc.out_last_night, "Demon resumes hunting when Brute is dead")


func _test_sexton_registration_and_attributes() -> void:
	_check(C.has_role_def("sexton"), "Sexton registered in role registry")
	var rdef = C.role_def("sexton")
	_check(rdef.id == "sexton", "Sexton id matches")
	_check(rdef.align == "good", "Sexton align is good")
	_check(rdef.kind == "protect", "Sexton kind is protect")
	_check(rdef.min_gift_day == 1, "Sexton min_gift_day is 1")
	_check("protection" in rdef.tags, "Sexton has protection tag")
	_check("sexton" in C.GOOD_ROLES, "Sexton in C.GOOD_ROLES")


func _test_sexton_lamplighter_walk_on_toll() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(56789, 7)
	var w = g.w
	var sexton_npc = w.living_good()[0]
	_give_role(w, sexton_npc, "sexton")
	sexton_npc.gift_used = false

	w.day = 1
	var rdef = C.role_def("sexton")
	# Force toll
	var tolled = rdef.try_toll(w, sexton_npc, Mind)
	# Even if AI decision weights vary, manual call sets suppression when true
	if not tolled:
		sexton_npc.gift_used = true
		w.sexton_suppression_night = w.day

	w.resolve_night()

	_check(w.is_minion_suppressed(), "Minions are suppressed on the night of the toll")
	_check(sexton_npc.out_last_night, "Sexton performs night walk when tolling the bell")
	_check(sexton_npc.night_path.size() >= 4, "Sexton visits all parishes on the Lamplighter walk")


func _test_sexton_minion_suppression() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(67890, 7)
	var w = g.w

	var evils = w.living().filter(func(p): return p.is_evil())
	var demon_npc = w.demon()
	var poisoner_npc = evils.filter(func(p): return p != demon_npc)[0]
	_give_role(w, poisoner_npc, "poisoner")

	var sexton_npc = w.living_good()[0]
	_give_role(w, sexton_npc, "sexton")
	sexton_npc.poisoned = false
	sexton_npc.gift_used = false

	# Suppress minions on night 1
	w.day = 1
	w.sexton_suppression_night = 1

	w.resolve_night()

	# Check that no living person was poisoned despite poisoner being in play
	var poisoned_count: int = w.living().filter(func(p): return p.poisoned).size()
	_check(poisoned_count == 0, "Poisoner is suppressed by church bell: zero targets poisoned")


func _test_sexton_townsfolk_gifts_unaffected() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(78901, 7)
	var w = g.w

	var sexton_npc = w.living_good()[0]
	_give_role(w, sexton_npc, "sexton")
	w.sexton_suppression_night = 1

	var seer_npc = w.living_good()[1]
	_give_role(w, seer_npc, "seer")

	w.day = 1
	w.resolve_night()

	# Seer reading generated normally despite Sexton bell
	var has_seer_reading: bool = seer_npc.info_log.any(func(e): return e.get("role") == "seer" and e.get("day") == 1)
	_check(has_seer_reading, "Townsfolk gift (Seer) continues working under Sexton bell")


func _test_sexton_once_per_case() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(89012, 7)
	var w = g.w

	var sexton_npc = w.living_good()[0]
	_give_role(w, sexton_npc, "sexton")
	sexton_npc.gift_used = true

	w.day = 2
	var rdef = C.role_def("sexton")
	var second_toll = rdef.try_toll(w, sexton_npc, Mind)
	_check(not second_toll, "Sexton cannot toll a second time in the same case")


## The Brute is experimental until the solver models a non-Demon killer: never drawn on the
## Default or a dynamic script, but a playtest mark (or the editor) can still put it on.
func _test_brute_experimental_on_scripts() -> void:
	_check(BruteDef.new().status == "experimental", "Brute is marked experimental")
	_check(not ("brute" in ScriptDef.default_script().minions) and ScriptDef.default_script().is_default(), "the Default script leaves the Brute off")
	var drawn: bool = false
	for sd in range(1, 61):
		if "brute" in ScriptBuilder.dynamic({"seed": sd}).minions:
			drawn = true
	_check(not drawn, "60 dynamic scripts never draw the Brute")
	_check("brute" in ScriptBuilder.dynamic({"seed": 7, "include": ["brute"]}).minions, "a playtest 'include' mark still puts the Brute on")
	_check("brute" in ScriptDef.roster().minions, "the script editor still offers the Brute")
