## Test suite for the RoleDef / RoleRegistry system (Seer, Warden, ROLE_IN_GROUP: Clerk/Archivist/Gravedigger, ROLE_AT_SITE: Dowser/Hearthwitch/Medium, and Count/Route: Surveyor/Lamplighter/Night Watch).
##   godot --headless --path . --script res://tools/test_role_def_poc.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Gifts = preload("res://sim/gifts.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Solver = preload("res://workshop/solver.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Live = preload("res://game/workshop_canvas.gd")

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
	_test_role_at_site_hooks()
	_test_count_and_route_hooks()
	print("RoleDef PoC: %d checks; failures: %d" % [checks, fails])
	quit(1 if fails else 0)


func _test_registry_and_metadata() -> void:
	var seer_def = C.role_def("seer")
	var warden_def = C.role_def("warden")
	var clerk_def = C.role_def("clerk")
	var arch_def = C.role_def("archivist")
	var grave_def = C.role_def("gravedigger")
	var dowser_def = C.role_def("dowser")
	var hearth_def = C.role_def("hearthwitch")
	var medium_def = C.role_def("medium")
	var surv_def = C.role_def("surveyor")
	var lamp_def = C.role_def("lamplighter")
	var watch_def = C.role_def("nightwatch")
	_check(seer_def != null and seer_def.shape == "PING" and seer_def.marked_registers and seer_def.red_herring_registers, "Seer RoleDef registered with PING shape and registration flags")
	_check(warden_def != null and warden_def.shape == "NIGHT_EVENT" and warden_def.night_walk and warden_def.can_cause_quiet_night, "Warden RoleDef registered with NIGHT_EVENT shape and protection flags")
	_check(clerk_def != null and clerk_def.shape == "ROLE_IN_GROUP" and clerk_def.role_group_key == "pair" and clerk_def.role_target_pool == "good" and clerk_def.first_night, "Clerk RoleDef registered with ROLE_IN_GROUP shape and good pair metadata")
	_check(arch_def != null and arch_def.shape == "ROLE_IN_GROUP" and arch_def.role_group_key == "pair" and arch_def.role_target_pool == "minion" and arch_def.first_night, "Archivist RoleDef registered with ROLE_IN_GROUP shape and minion pair metadata")
	_check(grave_def != null and grave_def.shape == "ROLE_IN_GROUP" and grave_def.role_group_key == "executed" and grave_def.role_target_pool == "any" and grave_def.marked_registers and grave_def.requires_execution, "Gravedigger RoleDef registered with ROLE_IN_GROUP shape and executed metadata")
	_check(dowser_def != null and dowser_def.shape == "ROLE_AT_SITE" and dowser_def.site_mode == "group_count" and dowser_def.site_group_key == "group" and dowser_def.day and dowser_def.marked_registers, "Dowser RoleDef registered with ROLE_AT_SITE group_count metadata")
	_check(hearth_def != null and hearth_def.shape == "ROLE_AT_SITE" and hearth_def.site_mode == "group_count" and hearth_def.site_group_key == "nbrs" and hearth_def.marked_registers, "Hearthwitch RoleDef registered with ROLE_AT_SITE group_count metadata")
	_check(medium_def != null and medium_def.shape == "ROLE_AT_SITE" and medium_def.site_mode == "hearth_relay" and medium_def.night_walk, "Medium RoleDef registered with ROLE_AT_SITE hearth_relay metadata")
	_check(surv_def != null and surv_def.shape == "GROUP_COUNT" and surv_def.count_mode == "blocks" and surv_def.first_night and surv_def.marked_registers, "Surveyor RoleDef registered with GROUP_COUNT blocks metadata")
	_check(lamp_def != null and lamp_def.shape == "GROUP_COUNT" and lamp_def.count_mode == "walkers" and lamp_def.night_walk, "Lamplighter RoleDef registered with GROUP_COUNT walkers metadata")
	_check(watch_def != null and watch_def.shape == "NIGHT_ROUTE" and watch_def.night_walk, "Night Watch RoleDef registered with NIGHT_ROUTE metadata")
	for rid in ["seer", "warden", "clerk", "archivist", "gravedigger", "dowser", "hearthwitch", "medium", "surveyor", "lamplighter", "nightwatch"]:
		_check(C.role_def(rid).to_role_dict() == C.ROLES[rid], "%s RoleDef.to_role_dict() matches C.ROLES['%s'] exactly" % [rid, rid])
	_check(C.role_def("rumormonger") == null, "Unmigrated role returns null from C.role_def() for incremental fallback")


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
	var c_card = g.add_card({"kind": "info", "source": clerk.id, "role": "clerk", "day": 0, "data": clerk_r["data"], "subject": [], "text": clerk_r["text"]})
	var a_card = g.add_card({"kind": "info", "source": arch.id, "role": "archivist", "day": 0, "data": arch_r["data"], "subject": [], "text": arch_r["text"]})
	var snap = g.workshop_snapshot([c_card, a_card], clerk.id)
	var prep = Assess.prepare(snap)
	var solved = Solver.solve(prep.view, prep.view.cards).worlds
	_check(not solved.is_empty(), "Workshop solver/assessment validates Clerk and Archivist ROLE_IN_GROUP readings")


func _test_role_at_site_hooks() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.log_dir = "user://test_logs"
	g.new_case(9104, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var dowser = goods[0]
	var medium = goods[1]
	var victim = goods[2]
	var other = goods[3]
	_give(w, dowser, "dowser")
	_give(w, medium, "medium")

	# 1. Dowser ROLE_AT_SITE group_count reading
	dowser.loc = ""
	victim.loc = ""
	other.loc = ""
	victim.home_block = dowser.home_block
	other.home_block = dowser.home_block
	w.day = 1
	var dw_r: Dictionary = C.role_def("dowser").generate_reading(w, dowser, {"day_phase": true}, Mind)
	_check(dw_r.get("data", {}).get("group", []).size() >= 2 and dw_r.get("data", {}).get("block", "") == dowser.home_block, "Dowser generate_reading reads crowd on block during day phase")
	_check(C.role_def("dowser").generate_reading(w, dowser, {}, Mind).is_empty(), "Dowser generate_reading is a no-op during night _receive_info")
	var dw_zero = {"role": "dowser", "day": 1, "data": {"group": [victim.id, other.id], "count": 0, "block": dowser.home_block}}
	var dw_one = {"role": "dowser", "day": 1, "data": {"group": [victim.id, other.id], "count": 1, "block": dowser.home_block}}
	_check(Gifts.implicated(dw_zero).is_empty() and Gifts.clears(dw_zero) == [victim.id, other.id], "Dowser count 0 clears group via ROLE_AT_SITE shape")
	_check(Gifts.implicated(dw_one) == [victim.id, other.id] and Gifts.clears(dw_one).is_empty(), "Dowser count > 0 implicates group via ROLE_AT_SITE shape")

	var dw_card = g.add_card({"kind": "info", "source": dowser.id, "role": "dowser", "day": 1, "phase": C.MORNING, "data": dw_zero["data"], "subject": [victim.id, other.id], "text": "on %s I sensed 0 evil" % C.block_name(dowser.home_block)})
	var dw_snap = g.workshop_snapshot([dw_card], dowser.id)
	var dw_prep = Assess.prepare(dw_snap)
	_check(not Solver.solve(dw_prep.view, dw_prep.view.cards).worlds.is_empty(), "Workshop solver/assessment validates Dowser ROLE_AT_SITE group_count reading")

	# 2. Medium ROLE_AT_SITE hearth_relay reading
	victim.alive = false
	victim.death_cause = "demon"
	victim.death_day = 1
	victim.info_log = [{"role": "seer", "day": 0, "shared": false, "fake": false, "data": {"pair": [dowser.id, other.id], "yes": false}, "text": "I looked at %s and %s: neither is the demon" % [dowser.name, other.name]}]
	var picked_dead: String = w._medium_choice(medium)
	_check(picked_dead == victim.id, "Medium pick_targets selects unvisited demon victim")
	var med_r: Dictionary = C.role_def("medium").generate_reading(w, medium, {"medium_t": picked_dead}, Mind)
	_check(med_r.get("data", {}).get("dead", "") == victim.id and med_r.get("data", {}).get("item", {}).get("type", "") == "reading", "Medium generate_reading relays unshared reading from dead victim")
	var med_entry = {"role": "medium", "day": 1, "data": med_r["data"], "text": med_r["text"]}
	_check(Gifts.clears(med_entry) == [dowser.id, other.id] and Gifts.implicated(med_entry).is_empty(), "Medium implicated/clears delegates to relayed reading")
	var med_effs: Array = C.role_def("medium").info_effects(w, medium, medium, med_entry, 1.0, true, Mind)
	_check(med_effs.size() == 2 and is_equal_approx(med_effs[0][1], -0.3 * 0.6), "Medium info_effects scales relayed reading effects by 0.6")

	medium.info_log.append(med_entry)
	medium.claimed_role = "medium"
	medium.claim_public = true
	medium.history[w.time_key(1, C.NIGHT)] = "night:" + victim.home_block
	w.day = 2
	var med_night: Dictionary = Mind.answer_night(w, medium, 1)
	_check(med_night["facts"].size() >= 1 and med_night["facts"][0].get("duty", "") == "medium", "Medium night_duty_alibi reports visiting victim's hearth")


func _test_count_and_route_hooks() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.log_dir = "user://test_logs"
	g.new_case(9105, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var surv = goods[0]
	var lamp = goods[1]
	var watch = goods[2]
	var walker = goods[3]
	_give(w, surv, "surveyor")
	_give(w, lamp, "lamplighter")
	_give(w, watch, "nightwatch")
	var name_fn = func(id): return w.by_id[id].name

	# 1. Surveyor (GROUP_COUNT blocks)
	var surv_r: Dictionary = C.role_def("surveyor").generate_reading(w, surv, {}, Mind)
	_check(surv_r.get("data", {}).get("count", -1) >= 1 and surv_r.get("data", {}).get("count", -1) <= 4, "Surveyor generate_reading counts blocks with evil residents")
	var surv_entry = {"role": "surveyor", "day": 0, "data": surv_r["data"], "text": surv_r["text"]}
	_check(Gifts.implicated(surv_entry).is_empty() and Gifts.clears(surv_entry).is_empty(), "Surveyor reading implicates and clears nobody directly")
	_check("Surveyor:" in Gifts.short_text("surveyor", surv_r["data"], surv.name, name_fn), "Surveyor short_text formats block count")

	# 2. Lamplighter (GROUP_COUNT walkers)
	w.night_walkers = [{"id": lamp.id, "block": lamp.home_block, "path": [lamp.home_block]}, {"id": walker.id, "block": walker.home_block, "path": [walker.home_block]}]
	var lamp_r: Dictionary = C.role_def("lamplighter").generate_reading(w, lamp, {"lamp": lamp}, Mind)
	_check(lamp_r.get("data", {}).get("count", -1) == 1, "Lamplighter generate_reading counts other night walkers")
	lamp.claimed_role = "lamplighter"
	lamp.claim_public = true
	lamp.history[w.time_key(1, C.NIGHT)] = "night:" + lamp.home_block
	w.day = 2
	var lamp_night: Dictionary = Mind.answer_night(w, lamp, 1)
	_check(lamp_night["facts"].size() >= 1 and lamp_night["facts"][0].get("duty", "") == "lamplighter", "Lamplighter night_duty_alibi reports walking the lamp route")

	# 3. Night Watch (NIGHT_ROUTE)
	w.day = 1
	watch.trust = 0.95
	var target_block: String = walker.home_block
	var req = Mind.consider_gift_request(w, watch, "nightwatch", [target_block])
	_check(req.get("agreed", false) and Mind.watch_block(w, watch) == target_block, "Night Watch RoleDef agrees to watch requested block and picks it")
	var watch_r: Dictionary = C.role_def("nightwatch").generate_reading(w, watch, {"watch_block": target_block}, Mind)
	_check(watch_r.get("data", {}).get("block", "") == target_block and walker.id in watch_r.get("data", {}).get("seen", []), "Night Watch generate_reading records walkers on watched block")
	var watch_entry = {"role": "nightwatch", "day": 1, "data": watch_r["data"], "text": watch_r["text"]}
	_check(Gifts.implicated(watch_entry) == [walker.id] and Gifts.clears(watch_entry).is_empty(), "Night Watch NIGHT_ROUTE shape implicates seen walkers")

	# 4. Workshop solver & live assessment for Surveyor, Lamplighter, Night Watch
	var s_card = g.add_card({"kind": "info", "source": surv.id, "role": "surveyor", "day": 0, "data": surv_r["data"], "subject": [], "text": surv_r["text"]})
	var l_card = g.add_card({"kind": "info", "source": lamp.id, "role": "lamplighter", "day": 1, "data": lamp_r["data"], "subject": [], "text": lamp_r["text"]})
	var w_card = g.add_card({"kind": "info", "source": watch.id, "role": "nightwatch", "day": 1, "data": watch_r["data"], "subject": [walker.id], "text": watch_r["text"]})
	var snap = g.workshop_snapshot([s_card, l_card, w_card], surv.id)
	var prep = Assess.prepare(snap)
	_check(not Solver.solve(prep.view, prep.view.cards).worlds.is_empty(), "Workshop solver/assessment validates Surveyor, Lamplighter, and Night Watch readings")
