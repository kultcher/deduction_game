## Test suite for the complete RoleDef / RoleRegistry system (all 21 roles in C.ROLES).
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
const Reasoner = preload("res://workshop/reasoner.gd")
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
		holder.info_log.clear()
		holder.ledger.clear()
		holder.history.clear()
	n.role = role
	n.info_log.clear()
	n.ledger.clear()
	n.history.clear()


func _init() -> void:
	_test_registry_and_metadata()
	_test_seer_hooks()
	_test_warden_hooks()
	_test_role_in_group_hooks()
	_test_role_at_site_hooks()
	_test_count_and_route_hooks()
	_test_final_roles_hooks()
	print("RoleDef PoC: %d checks; failures: %d" % [checks, fails])
	quit(1 if fails else 0)


func _test_registry_and_metadata() -> void:
	_check(C.role_def("seer").shape == "PING" and C.role_def("seer").marked_registers and C.role_def("seer").red_herring_registers, "Seer RoleDef registered with PING shape and registration flags")
	_check(C.role_def("warden").shape == "NIGHT_EVENT" and C.role_def("warden").night_walk and C.role_def("warden").can_cause_quiet_night, "Warden RoleDef registered with NIGHT_EVENT shape and protection flags")
	_check(C.role_def("clerk").shape == "ROLE_IN_GROUP" and C.role_def("clerk").role_group_key == "pair" and C.role_def("clerk").role_target_pool == "good" and C.role_def("clerk").first_night, "Clerk RoleDef registered with ROLE_IN_GROUP shape and good pair metadata")
	_check(C.role_def("archivist").shape == "ROLE_IN_GROUP" and C.role_def("archivist").role_group_key == "pair" and C.role_def("archivist").role_target_pool == "minion" and C.role_def("archivist").first_night, "Archivist RoleDef registered with ROLE_IN_GROUP shape and minion pair metadata")
	_check(C.role_def("gravedigger").shape == "ROLE_IN_GROUP" and C.role_def("gravedigger").role_group_key == "executed" and C.role_def("gravedigger").role_target_pool == "any" and C.role_def("gravedigger").marked_registers and C.role_def("gravedigger").requires_execution, "Gravedigger RoleDef registered with ROLE_IN_GROUP shape and executed metadata")
	_check(C.role_def("dowser").shape == "ROLE_AT_SITE" and C.role_def("dowser").site_mode == "group_count" and C.role_def("dowser").site_group_key == "group" and C.role_def("dowser").day and C.role_def("dowser").marked_registers, "Dowser RoleDef registered with ROLE_AT_SITE group_count metadata")
	_check(C.role_def("hearthwitch").shape == "ROLE_AT_SITE" and C.role_def("hearthwitch").site_mode == "group_count" and C.role_def("hearthwitch").site_group_key == "nbrs" and C.role_def("hearthwitch").marked_registers, "Hearthwitch RoleDef registered with ROLE_AT_SITE group_count metadata")
	_check(C.role_def("medium").shape == "ROLE_AT_SITE" and C.role_def("medium").site_mode == "hearth_relay" and C.role_def("medium").night_walk, "Medium RoleDef registered with ROLE_AT_SITE hearth_relay metadata")
	_check(C.role_def("surveyor").shape == "GROUP_COUNT" and C.role_def("surveyor").count_mode == "blocks" and C.role_def("surveyor").first_night and C.role_def("surveyor").marked_registers, "Surveyor RoleDef registered with GROUP_COUNT blocks metadata")
	_check(C.role_def("lamplighter").shape == "GROUP_COUNT" and C.role_def("lamplighter").count_mode == "walkers" and C.role_def("lamplighter").night_walk, "Lamplighter RoleDef registered with GROUP_COUNT walkers metadata")
	_check(C.role_def("nightwatch").shape == "NIGHT_ROUTE" and C.role_def("nightwatch").night_walk, "Night Watch RoleDef registered with NIGHT_ROUTE metadata")
	_check(C.role_def("rumormonger").shape == "SECRET_PAIR" and C.role_def("rumormonger").first_night, "Rumormonger RoleDef registered with SECRET_PAIR metadata")
	_check(C.role_def("psychologist").shape == "SOCIAL_PAIR", "Psychologist RoleDef registered with SOCIAL_PAIR metadata")
	_check(C.role_def("veteran").shape == "NIGHT_EVENT" and C.role_def("veteran").can_cause_quiet_night and is_equal_approx(C.role_def("veteran").quiet_night_effect, -0.06), "Veteran RoleDef registered with NIGHT_EVENT quiet night metadata")
	_check(C.role_def("martyr").shape == "NIGHT_EVENT" and C.role_def("martyr").marked_registers, "Martyr RoleDef registered with NIGHT_EVENT metadata")
	_check(C.role_def("sexton").shape == "NIGHT_EVENT", "Sexton RoleDef registered with NIGHT_EVENT metadata")
	for rid in C.ROLES.keys():
		_check(C.role_def(rid) != null and C.role_def(rid).to_role_dict() == C.ROLES[rid], "%s RoleDef.to_role_dict() matches C.ROLES['%s'] exactly" % [rid, rid])


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
	var evils: Array = w.evil_team()
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
	_check(arch_r.get("data", {}).get("pair", []).size() == 2 and C.ROLES.get(arch_r["data"].get("role", ""), {}).get("minion", false), "Archivist generate_reading produces valid minion role pair")

	grave.claim_public = true
	grave.claimed_role = "gravedigger"
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
	dowser.loc = "home"
	victim.loc = "home"
	other.loc = "home"
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
	var l_card = g.add_card({"kind": "info", "source": lamp.id, "role": "lamplighter", "day": 0, "data": lamp_r["data"], "subject": [], "text": lamp_r["text"]})
	var w_card = g.add_card({"kind": "info", "source": watch.id, "role": "nightwatch", "day": 1, "data": watch_r["data"], "subject": [walker.id], "text": watch_r["text"]})
	var snap = g.workshop_snapshot([s_card, l_card, w_card], surv.id)
	var prep = Assess.prepare(snap)
	_check(not Solver.solve(prep.view, prep.view.cards).worlds.is_empty(), "Workshop solver/assessment validates Surveyor, Lamplighter, and Night Watch readings")


func _test_final_roles_hooks() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.log_dir = "user://test_logs"
	g.new_case(9106, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var rumor = goods[0]
	var psych = goods[1]
	var vet = goods[2]
	var martyr = goods[3]
	var sexton = goods[4]
	_give(w, rumor, "rumormonger")
	_give(w, psych, "psychologist")
	_give(w, vet, "veteran")
	_give(w, martyr, "martyr")
	_give(w, sexton, "sexton")

	# 1. Rumormonger (SECRET_PAIR)
	var rumor_r: Dictionary = C.role_def("rumormonger").generate_reading(w, rumor, {}, Mind)
	_check(rumor_r.get("data", {}).get("pair", []).size() == 2 and rumor_r.get("data", {}).get("secret", "") in C.SECRET_MOD_LIST, "Rumormonger generate_reading produces valid secret pair")
	var rumor_entry = {"role": "rumormonger", "day": 0, "data": rumor_r["data"], "text": rumor_r["text"]}
	_check(Gifts.clears(rumor_entry) == rumor_r["data"]["pair"] and Gifts.implicated(rumor_entry).is_empty(), "Rumormonger SECRET_PAIR clears both members of the pair")

	# 2. Psychologist (SOCIAL_PAIR)
	psych.talked_today = [vet.id]
	var psych_r: Dictionary = C.role_def("psychologist").generate_reading(w, psych, {}, Mind)
	_check(psych_r.get("data", {}).get("subject", "") == vet.id and psych_r.get("data", {}).has("trusts") and psych_r.get("data", {}).has("suspects"), "Psychologist generate_reading reads talked subject's trust and suspicion")

	# 3. Veteran, Martyr, Sexton (NIGHT_EVENT)
	w.day = 1
	w.demon().night_path = [w.demon().home_block, vet.home_block]
	w._veteran_survives(vet)
	_check(vet.vet_used and not vet.info_log.is_empty() and vet.info_log[-1]["data"].get("block", "") == w.demon().home_block, "Veteran on_survive_attack logs attacker approach block")

	martyr.npc_trust[vet.id] = 0.9
	martyr.suspicion[vet.id] = 0.0
	w._martyr_choice(martyr)
	_check(martyr.martyr_target == vet.id and not martyr.info_log.is_empty() and Gifts.clears(martyr.info_log[-1]) == [vet.id], "Martyr pick_targets chooses trusted townsperson and clears them")

	sexton.claim_public = true
	sexton.claimed_role = "sexton"
	vet.claim_public = true
	vet.claimed_role = "veteran"
	martyr.claim_public = true
	martyr.claimed_role = "martyr"
	_check(not Evil.gift_live_tonight(w, sexton) and not Evil.gift_live_tonight(w, vet) and Evil.gift_live_tonight(w, martyr), "gift_live_tonight matches Veteran/Sexton (false) and Martyr on day >= 1 (true)")

	# 4. World, Evil & Content RoleDef hooks (Item 5)
	for rid in C.ROLES.keys():
		_check(C.has_readings(rid) == (rid in C.INFO_ROLES or rid in ["veteran", "martyr"]), "C.has_readings('%s') matches RoleDef.has_readings()" % rid)
		_check(C.is_minion(rid) == C.ROLES[rid].get("minion", false), "C.is_minion('%s') matches RoleDef.minion" % rid)
	_check(C.role_def("rumormonger").cannot_hold_solo_secret, "Rumormonger RoleDef marks cannot_hold_solo_secret")
	_check(is_equal_approx(C.role_def("psychologist").conversation_nudge, 0.5), "Psychologist RoleDef sets conversation_nudge = 0.5")
	_check(C.role_def("warden").hard_to_kill and C.role_def("veteran").hard_to_kill, "Warden and Veteran RoleDefs set hard_to_kill")
	_check(C.role_def("seer").public_threat_key == "seer" and is_equal_approx(C.role_def("seer").public_threat_bonus, 1.0), "Seer RoleDef sets public_threat_bonus")
	_check(C.role_def("martyr").can_substitute_execution(w, martyr, vet.id), "Martyr RoleDef can_substitute_execution validates good chosen target")

	# 5. Mind disclosure, alibis, press, defence & Domain.gift_time hooks (Parts 1-3)
	w.day = 1
	var seer_claim_parts: Dictionary = {}
	C.role_def("seer").score_public_claim(w, rumor, seer_claim_parts)
	_check(is_equal_approx(seer_claim_parts.get("gift_keeps_giving", 0.0), -0.4), "Ongoing info RoleDef sets gift_keeps_giving = -0.4 on early days")
	var clerk_claim_parts: Dictionary = {}
	C.role_def("clerk").score_public_claim(w, rumor, clerk_claim_parts)
	_check(is_equal_approx(clerk_claim_parts.get("one_shot_gift", 0.0), 0.3), "First-night RoleDef sets one_shot_gift = 0.3")
	var martyr_claim_parts: Dictionary = {}
	C.role_def("martyr").score_public_claim(w, martyr, martyr_claim_parts)
	_check(is_equal_approx(martyr_claim_parts.get("hides_from_demon", 0.0), -0.5) and is_equal_approx(martyr_claim_parts.get("martyr_chosen", 0.0), 0.4), "Martyr RoleDef sets hides_from_demon and martyr_chosen when target is chosen")
	var vote_parts: Dictionary = {}
	martyr.pressure = 0.0
	C.role_def("martyr").score_vote_reluctance(w, martyr, vet.id, 0.5, 0.0, vote_parts)
	_check(vote_parts.get("martyr_reluctance", 0.0) < 0.0, "Martyr RoleDef score_vote_reluctance adds negative vote reluctance on chosen target")
	_check(C.role_def("clerk").names_good_role_in_pair() and not C.role_def("archivist").names_good_role_in_pair(), "Clerk RoleDef names_good_role_in_pair is true only for good pair ROLE_IN_GROUP")
	_check("keeping watch" in C.role_def("nightwatch").pressed_night_line(w, rumor, {"block": rumor.home_block}, 1, "on night 1", true, C.block_name), "Night Watch RoleDef formats pressed_night_line")
	_check(Domain.gift_time({"role": "dowser", "observed_at": {"day": 1, "phase": "morning"}}) and not Domain.gift_time({"role": "dowser", "observed_at": {"day": 1, "phase": "night"}}), "Domain.gift_time delegates Dowser day-only timing to RoleDef")
	_check(Domain.gift_time({"role": "surveyor", "observed_at": {"day": 0, "phase": "night"}}) and not Domain.gift_time({"role": "surveyor", "observed_at": {"day": 1, "phase": "night"}}), "Domain.gift_time delegates Surveyor first-night timing to RoleDef")
	_check(Domain.gift_time({"role": "martyr", "observed_at": {"day": 1, "phase": "evening"}}) and not Domain.gift_time({"role": "martyr", "observed_at": {"day": 0, "phase": "night"}}), "Domain.gift_time delegates Martyr evening/night day>=1 timing to RoleDef")

	# 6. MindMeeting & MindDialogue module extraction checks
	_check(Mind.MindMeeting != null and Mind.MindDialogue != null, "Mind preloads MindMeeting and MindDialogue modules")
	_check(Mind.reveal_cost(w, rumor) == Mind.MindMeeting.reveal_cost(w, rumor), "Mind.reveal_cost forwards identically to MindMeeting.reveal_cost")
	_check(Mind.fear_chance(w, rumor) == Mind.MindDialogue.fear_chance(w, rumor), "Mind.fear_chance forwards identically to MindDialogue.fear_chance")
	_check(Mind.protection_kind(w, rumor) == Mind.MindDialogue.protection_kind(w, rumor), "Mind.protection_kind forwards identically to MindDialogue.protection_kind")

	# 7. GameBoard & GamePresentation module extraction checks
	_check(g.GameBoard != null and g.GamePresentation != null, "Game preloads GameBoard and GamePresentation modules")
	_check(g.filter_cards("") == g.GameBoard.filter_cards(g, ""), "Game.filter_cards forwards identically to GameBoard.filter_cards")
	_check(g.timeline_data() == g.GameBoard.timeline_data(g), "Game.timeline_data forwards identically to GameBoard.timeline_data")

	# 8. Codex review regressions: raw-data card/defend strength & single Martyr registration roll
	_check(is_equal_approx(C.role_def("dowser").card_strength({"group": [vet.id, sexton.id], "count": 1, "block": vet.home_block}, vet.id), 0.6), "Dowser card_strength accepts raw data dict and returns 0.6 for implicated member")
	_check(is_equal_approx(C.role_def("martyr").card_strength({"target": vet.id, "evil": true}, vet.id), 0.6), "Martyr evil-outcome card_strength accepts raw data dict and returns 0.6")
	_check(is_equal_approx(C.role_def("gravedigger").defend_strength({"executed": vet.id, "role": "warden"}, vet.id), 0.5), "Gravedigger good-role defend_strength accepts raw data dict and returns 0.5")
	_check(is_equal_approx(C.role_def("rumormonger").defend_strength({"pair": [vet.id, sexton.id], "secret": "marked"}, vet.id), 0.5), "Rumormonger defend_strength accepts raw data dict and returns 0.5")
	_check(is_equal_approx(C.role_def("archivist").defend_strength({"pair": [vet.id, sexton.id], "role": "poisoner"}, vet.id), 0.15), "Non-clearing RoleDef.defend_strength preserves 0.15 fallback")

	var m_def = C.role_def("martyr")
	vet.secret_mod = "marked"
	martyr.martyr_target = vet.id
	martyr.poisoned = false
	var probe_rng = RandomNumberGenerator.new()
	probe_rng.seed = 3
	w.rng.state = probe_rng.state
	var expected_one_draw = RandomNumberGenerator.new()
	expected_one_draw.state = probe_rng.state
	var first_draw_evil: bool = expected_one_draw.randf() < 0.5
	var before_logs: int = martyr.info_log.size()
	var sub_ok: bool = m_def.can_substitute_execution(w, martyr, vet.id)
	if not sub_ok:
		m_def.on_chosen_executed(w, martyr, vet)
	_check(w.rng.state == expected_one_draw.state, "Martyr execution consumes exactly one RNG draw for a Marked target across substitution + post-execution hooks")
	_check(sub_ok == (not first_draw_evil) and (sub_ok or martyr.info_log.size() == before_logs + 1), "Martyr non-substitution on Marked target reuses first draw and records confirmation reading")

	# 9. Centralized Tuning (sim/tuning.gd) checks
	var Tuning = C.Tuning
	_check(Tuning != null, "C.Tuning preloads sim/tuning.gd")
	_check(C.SETUPS == Tuning.Setup.SETUPS and C.SHADOW_SELF == Tuning.Setup.SHADOW_SELF, "C.SETUPS and C.SHADOW_SELF alias Tuning.Setup")
	_check(is_equal_approx(Mind.SERIOUS_GRIEVANCE, Tuning.Trust.SERIOUS_GRIEVANCE) and is_equal_approx(Mind.HONESTY_K, Tuning.Mind.HONESTY_K), "Mind constants alias Tuning.Trust and Tuning.Mind")
	_check(is_equal_approx(Mind.CONSENSUS_BASE, Tuning.Meeting.CONSENSUS_BASE) and is_equal_approx(C.DEFENCE_ROPE, Tuning.Meeting.DEFENCE_ROPE), "Meeting constants alias Tuning.Meeting")
	_check(is_equal_approx(C.EVIL_CAUTION_DEMON, Tuning.Evil.EVIL_CAUTION_DEMON) and is_equal_approx(Evil.HEAT_FADE, Tuning.Evil.HEAT_FADE), "Evil constants alias Tuning.Evil")
	_check(is_equal_approx(C.role_def("seer").public_threat_bonus, Tuning.Roles.SEER.public_threat_bonus) and is_equal_approx(C.role_def("warden").quiet_night_effect, Tuning.Roles.WARDEN.quiet_night_effect), "RoleDefs read per-role tuning from Tuning.Roles")
	_check(Reasoner.profile(0.2).cards == Tuning.Workshop.PROFILE_LOW.cards and Reasoner.profile(0.5).rivals == Tuning.Workshop.PROFILE_MEDIUM.rivals and Reasoner.profile(0.8).support == Tuning.Workshop.PROFILE_HIGH.support, "Reasoner.profile reads Low/Medium/High profiles from Tuning.Workshop")
