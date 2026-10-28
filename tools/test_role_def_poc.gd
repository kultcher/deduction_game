## Test suite for the RoleDef / RoleRegistry system (Seer, Warden, and ROLE_IN_GROUP: Clerk, Archivist, Gravedigger).
##   godot --headless --path . --script res://tools/test_role_def_poc.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Gifts = preload("res://sim/gifts.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Live = preload("res://workshop/live_integration.gd")

var checks = 0
var fails = 0


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", msg)
	else:
		print("PASS: ", msg)


func _give(w, n, role: String) -> void:
	var holder = w.npc_with_role(role)
	if holder != null and holder != n:
		holder.role = n.role
	n.role = role


func _init() -> void:
	_test_registry_and_metadata()
	_test_seer_hooks()
	_test_warden_hooks()
	_test_role_in_group_hooks()
	print("RoleDef PoC: %d checks; failures: %d" % [checks, fails])
	quit(1 if fails else 0)


func _test_registry_and_metadata() -> void:
	var seer_def = C.role_def("seer")
	var warden_def = C.role_def("warden")
	var clerk_def = C.role_def("clerk")
	var arch_def = C.role_def("archivist")
	var grave_def = C.role_def("gravedigger")
	_check(seer_def != null and seer_def.shape == "PING" and seer_def.marked_registers and seer_def.red_herring_registers, "Seer RoleDef registered with PING shape and registration flags")
	_check(warden_def != null and warden_def.shape == "NIGHT_EVENT" and warden_def.night_walk and warden_def.can_cause_quiet_night, "Warden RoleDef registered with NIGHT_EVENT shape and protection flags")
	_check(clerk_def != null and clerk_def.shape == "ROLE_IN_GROUP" and clerk_def.role_group_key == "pair" and clerk_def.role_target_pool == "good" and clerk_def.first_night, "Clerk RoleDef registered with ROLE_IN_GROUP shape and good pair metadata")
	_check(arch_def != null and arch_def.shape == "ROLE_IN_GROUP" and arch_def.role_group_key == "pair" and arch_def.role_target_pool == "minion" and arch_def.first_night, "Archivist RoleDef registered with ROLE_IN_GROUP shape and minion pair metadata")
	_check(grave_def != null and grave_def.shape == "ROLE_IN_GROUP" and grave_def.role_group_key == "executed" and grave_def.role_target_pool == "any" and grave_def.marked_registers and grave_def.requires_execution, "Gravedigger RoleDef registered with ROLE_IN_GROUP shape and executed metadata")
	for rid in ["seer", "warden", "clerk", "archivist", "gravedigger"]:
		_check(C.role_def(rid).to_role_dict() == C.ROLES[rid], "%s RoleDef.to_role_dict() matches C.ROLES['%s'] exactly" % [rid, rid])
	_check(C.role_def("dowser") == null, "Unmigrated role returns null from C.role_def() for incremental fallback")


func _test_seer_hooks() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.log_dir = "user://test_logs"
	g.new_case(9101, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var seer = goods[0]
	var a = goods[1]
	var b = goods[2]
	_give(w, seer, "seer")
	C.role_def("seer").setup_world(w, seer)
	_check(seer.red_herring != "" and seer.red_herring != seer.id and not w.by_id[seer.red_herring].is_evil(), "Seer setup_world assigns a valid good red herring")

	var yes_entry = {"role": "seer", "day": 1, "data": {"pair": [a.id, b.id], "yes": true}}
	var no_entry = {"role": "seer", "day": 1, "data": {"pair": [a.id, b.id], "yes": false}}
	_check(Gifts.implicated(yes_entry) == [a.id, b.id] and Gifts.clears(yes_entry).is_empty(), "Gifts.implicated/clears delegates Seer YES reading via PING shape")
	_check(Gifts.implicated(no_entry).is_empty() and Gifts.clears(no_entry) == [a.id, b.id], "Gifts.implicated/clears delegates Seer NO reading via PING shape")
	_check("YES" in Gifts.short_text("seer", yes_entry["data"], seer.name, func(id): return w.by_id[id].name), "Gifts.short_text formats Seer reading via RoleDef")

	var effs_no: Array = C.role_def("seer").info_effects(w, seer, seer, no_entry, 1.0, true, Mind)
	_check(effs_no.size() == 2 and seer.cleared.has(a.id) and seer.cleared.has(b.id), "Seer info_effects clears both subjects on own fresh NO reading")

	w.day = 1
	seer.trust = 0.9
	var req = Mind.consider_gift_request(w, seer, "seer", [a.id, b.id])
	_check(req.get("agreed", false) and Mind.seer_picks(w, seer) == [a.id, b.id], "Seer RoleDef agrees to trusted player gift request and picks requested pair")
	var reading: Dictionary = C.role_def("seer").generate_reading(w, seer, {}, Mind)
	_check(reading.get("data", {}).get("pair", []) == [a.id, b.id] and reading.has("text"), "Seer RoleDef.generate_reading produces reading for picked pair")


func _test_warden_hooks() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.log_dir = "user://test_logs"
	g.new_case(9102, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var warden = goods[0]
	var guarded = goods[1]
	_give(w, warden, "warden")
	warden.claimed_role = "warden"
	warden.claim_public = true
	w.day = 1
	warden.trust = 0.95
	warden.npc_trust[guarded.id] = 0.85
	warden.suspicion[guarded.id] = 0.05
	var req = Mind.consider_gift_request(w, warden, "warden", [guarded.id])
	_check(req.get("agreed", false) and Mind.warden_target(w, warden) == guarded.id, "Warden RoleDef agrees to guard trusted target and selects them at night")

	warden.warden_log["1"] = guarded.id
	warden.history[w.time_key(1, C.NIGHT)] = "night:" + guarded.home_block
	w.day = 2
	var night_ans: Dictionary = Mind.answer_night(w, warden, 1)
	_check(night_ans["facts"].size() >= 1 and night_ans["facts"][0].get("guard_claim", "") == guarded.id, "Warden RoleDef night_duty_alibi emits guard_claim sighting fact")

	var gift_ans: Dictionary = Mind.answer_gift(w, warden, 4)
	_check(gift_ans["facts"].any(func(f): return f.get("guard_claim", "") == guarded.id), "Warden RoleDef answer_gift_custom reports guarded doors")


func _test_role_in_group_hooks() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.log_dir = "user://test_logs"
	g.new_case(9103, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var evils: Array = w.living_evil()
	var clerk = goods[0]
	var arch = goods[1]
	var grave = goods[2]
	var subject_good = goods[3]
	var subject_other = goods[4]
	var minion = evils.filter(func(m): return m.role != "demon")[0]

	_give(w, clerk, "clerk")
	_give(w, arch, "archivist")
	_give(w, grave, "gravedigger")

	# 1. Gifts.implicated / Gifts.clears / Gifts.short_text via ROLE_IN_GROUP shape
	var clerk_entry = {"role": "clerk", "day": 0, "data": {"pair": [subject_good.id, subject_other.id], "role": subject_good.role}}
	var arch_entry = {"role": "archivist", "day": 0, "data": {"pair": [minion.id, subject_other.id], "role": minion.role}}
	var grave_good_entry = {"role": "gravedigger", "day": 1, "data": {"executed": subject_good.id, "role": subject_good.role}}
	var grave_evil_entry = {"role": "gravedigger", "day": 1, "data": {"executed": minion.id, "role": minion.role}}

	_check(Gifts.implicated(clerk_entry).is_empty() and Gifts.clears(clerk_entry) == [subject_good.id, subject_other.id], "ROLE_IN_GROUP Clerk reading clears pair and implicates nobody")
	_check(Gifts.implicated(arch_entry) == [minion.id, subject_other.id] and Gifts.clears(arch_entry).is_empty(), "ROLE_IN_GROUP Archivist reading implicates pair and clears nobody")
	_check(Gifts.implicated(grave_good_entry).is_empty() and Gifts.clears(grave_good_entry) == [subject_good.id], "ROLE_IN_GROUP Gravedigger good role reading clears executed")
	_check(Gifts.implicated(grave_evil_entry) == [minion.id] and Gifts.clears(grave_evil_entry).is_empty(), "ROLE_IN_GROUP Gravedigger evil role reading implicates executed")

	var name_fn = func(id): return w.by_id[id].name
	_check(C.role_name(subject_good.role) in Gifts.short_text("clerk", clerk_entry["data"], clerk.name, name_fn), "Clerk short_text includes good role name")
	_check(C.role_name(minion.role) in Gifts.short_text("archivist", arch_entry["data"], arch.name, name_fn), "Archivist short_text includes minion role name")
	_check(C.role_name(minion.role) in Gifts.short_text("gravedigger", grave_evil_entry["data"], grave.name, name_fn), "Gravedigger short_text includes executed role name")

	# 2. generate_reading & gift_live_tonight
	var clerk_r: Dictionary = C.role_def("clerk").generate_reading(w, clerk, {"poisoned": false}, Mind)
	_check(clerk_r.get("data", {}).get("pair", []).size() == 2 and C.ROLES.get(clerk_r["data"].get("role", ""), {}).get("align") == "good", "Clerk generate_reading produces valid good role pair")

	var arch_r: Dictionary = C.role_def("archivist").generate_reading(w, arch, {"poisoned": false}, Mind)
	_check(arch_r.get("data", {}).get("pair", []).size() == 2 and C.ROLES.get(arch_r["data"].get("role", ""), {}).get("kind") == "minion", "Archivist generate_reading produces valid minion role pair")

	w.executed_today = ""
	_check(not Evil.gift_live_tonight(w, grave) and C.role_def("gravedigger").generate_reading(w, grave, {}, Mind).is_empty(), "Gravedigger is inactive when no one was executed today")
	w.executed_today = subject_good.id
	_check(Evil.gift_live_tonight(w, grave), "Gravedigger is live tonight when someone was executed today")
	var grave_r: Dictionary = C.role_def("gravedigger").generate_reading(w, grave, {"poisoned": false}, Mind)
	_check(grave_r.get("data", {}).get("executed", "") == subject_good.id and grave_r.get("data", {}).get("role", "") == subject_good.role, "Gravedigger generate_reading reports true role of executed person")

	# 3. Workshop solver & live assessment integration for ROLE_IN_GROUP
	clerk.info_log.append({"role": "clerk", "day": 0, "data": clerk_r["data"], "text": clerk_r["text"]})
	arch.info_log.append({"role": "archivist", "day": 0, "data": arch_r["data"], "text": arch_r["text"]})
	grave.info_log.append({"role": "gravedigger", "day": 1, "data": grave_r["data"], "text": grave_r["text"]})
	for holder in [clerk, arch, grave]:
		var prep = Live.Assess.prepare(w, holder)
		var fits = Live.Solver.Roles.fits_table(prep["problem"], prep["domains"], [holder.id])
		_check(fits.get(holder.id, {}).get(holder.role, false), "Workshop solver/assessment validates %s ROLE_IN_GROUP reading" % holder.role)
