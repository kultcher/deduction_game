## Proof-of-concept test suite for the RoleDef / RoleRegistry system (Seer and Warden).
##   godot --headless --path . --script res://tools/test_role_def_poc.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Gifts = preload("res://sim/gifts.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")

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
	print("RoleDef PoC: %d checks; failures: %d" % [checks, fails])
	quit(1 if fails else 0)


func _test_registry_and_metadata() -> void:
	var seer_def = C.role_def("seer")
	var warden_def = C.role_def("warden")
	_check(seer_def != null and seer_def.shape == "PING" and seer_def.marked_registers and seer_def.red_herring_registers, "Seer RoleDef registered with PING shape and registration flags")
	_check(warden_def != null and warden_def.shape == "NIGHT_EVENT" and warden_def.night_walk and warden_def.can_cause_quiet_night, "Warden RoleDef registered with NIGHT_EVENT shape and protection flags")
	_check(seer_def.to_role_dict() == C.ROLES["seer"], "Seer RoleDef.to_role_dict() matches C.ROLES['seer'] exactly")
	_check(warden_def.to_role_dict() == C.ROLES["warden"], "Warden RoleDef.to_role_dict() matches C.ROLES['warden'] exactly")
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
