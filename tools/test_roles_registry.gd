## Role registry and definitions: RoleDef hooks, pools and hint packages, the deal (setup sizes, homes, bluffs) and the C# report tables every role compiles to.
## Merged from: test_chunk2_world_mask_roles, test_chunk3_executor_registrar, test_chunk5_cs_tables, test_role_def_poc, test_roster.
extends SceneTree

const Gifts = preload("res://sim/gifts.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const Evil = preload("res://sim/evil.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Solver = preload("res://workshop/solver.gd")
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const World = preload("res://sim/world.gd")
const Live = preload("res://game/workshop_canvas.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_role_def_poc()
	_run_chunk2_world_mask_roles()
	_run_chunk3_executor_registra()
	_run_roster()
	_run_chunk5_cs_tables()
	print("Roles: registry: %d checks, %d failures" % [checks, fails])
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


# ---------------------------------------------------------------- from test_role_def_poc

func _run_role_def_poc() -> void:
	_test_registry_and_metadata()
	_test_seer_hooks()
	_test_warden_hooks()
	_test_role_in_group_hooks()
	_test_role_at_site_hooks()
	_test_count_and_route_hooks()
	_test_final_roles_hooks()


# ---------------------------------------------------------------- from test_chunk2_world_mask_roles

func _run_chunk2_world_mask_roles() -> void:
	_test_pools_hints_and_seer_solo_bluff()


# ---------------------------------------------------------------- from test_chunk3_executor_registrar

func _run_chunk3_executor_registra() -> void:
	_test_pools_hints_and_scripts()


# ---------------------------------------------------------------- from test_roster

func _run_roster() -> void:
	_test_setup(7)
	_test_setup(10)
	_test_homes_and_bluffs()


# ---------------------------------------------------------------- from test_chunk5_cs_tables

func _run_chunk5_cs_tables() -> void:
	var g = Game.new()
	g.new_case(692, 10)
	g.w.dlog.detailed = false
	g.w.day = 3
	var obs = g.w.living_good()[0]
	var prepared = Live.Assess.prepare(g.workshop_snapshot([], obs.id))
	var view: Dictionary = prepared.view
	var ids: Array = view.people.map(func(p): return p.id)
	var src: String = ids[1]
	var cards: Array = []
	for blk in ["square", "docks", "nowhere"]:
		for walked in [false, true]:
			for r in ["", "poisoner", "demon", "seer"]:
				var d = {"block": blk, "walked": walked}
				if r != "": d["role"] = r
				cards.append({"role": "monitor", "data": d})
	for t in ids:
		cards.append({"role": "confessor", "data": {"target": t, "good": true}})
	cards.append({"role": "confessor", "data": {"forgot": true}})
	cards.append({"role": "confessor", "data": {}})
	var answers: Array = [[]]
	for p in ids.slice(0, 5): answers.append([p])
	answers.append([ids[2], ids[5]])
	answers.append(["nobody"])
	var universe: Array = Solver.universe(view)
	var checked = 0
	var bad = 0
	for k in range(cards.size()):
		for testimony in [false, true]:
			var card: Dictionary = {"kind": "report", "quoted": false}
			card["id"] = "mc:%d:%s" % [k, testimony]
			card["role"] = cards[k].role
			card["data"] = cards[k].data
			card["source"] = src
			card["observed_at"] = {"day": 2, "phase": "night"}
			card["night"] = 2
			if testimony:
				card["testimony_only"] = true
				card["reported_at"] = {"day": 3, "phase": "evening"}
			for ans in (answers if not testimony else [[]]):
				var table: PackedByteArray = Solver.report_table(view, card, ans)
				var valid: PackedByteArray = Solver.valid_table(view, card)
				for i in range(0, universe.size(), 37):
					var want: bool
					if testimony:
						want = Solver.source_valid(view, universe[i], card) and Solver._testimony_content(view, universe[i], card)
					else:
						want = valid[i] != 0 and Solver._report_content(view, universe[i], card, {"positive": ans})
					checked += 1
					if (table[i] != 0) != want:
						bad += 1
						if bad <= 5:
							print("MISMATCH card=", JSON.stringify(card.data), " role=", card.role, " testimony=", testimony, " ans=", ans, " world=", JSON.stringify(universe[i]), " cs=", table[i], " gd=", want)
	print("C# Monitor/Confessor tables: %d worlds checked, %d mismatches" % [checked, bad])
	check(checked > 0 and bad == 0, "C# Monitor/Confessor report tables agree with the content rule")


# ---- test_role_def_poc


func _give(w, n, role: String) -> void:
	var holder = w.npc_with_role(role)
	if holder != null and holder != n:
		holder.role = n.role
		holder.poisoned = false
		holder.info_log.clear()
		holder.known_claims.clear()
		holder.believed_roles.clear()
		holder.ledger.clear()
		holder.history.clear()
	n.role = role
	n.poisoned = false
	n.info_log.clear()
	n.known_claims.clear()
	n.believed_roles.clear()
	n.ledger.clear()
	n.history.clear()


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
	_check(C.role_def("psychologist").shape == "PSYCH_STATEMENTS" and C.role_def("psychologist").min_gift_day == 1, "Psychologist RoleDef registered with PSYCH_STATEMENTS and Night-1+ metadata")
	_check(C.role_def("veteran").shape == "NIGHT_EVENT" and C.role_def("veteran").can_cause_quiet_night and is_equal_approx(C.role_def("veteran").quiet_night_effect, -0.06), "Veteran RoleDef registered with NIGHT_EVENT quiet night metadata")
	_check(C.role_def("martyr").shape == "NIGHT_EVENT" and C.role_def("martyr").marked_registers, "Martyr RoleDef registered with NIGHT_EVENT metadata")
	_check(C.role_def("sexton").shape == "NIGHT_EVENT", "Sexton RoleDef registered with NIGHT_EVENT metadata")
	_check(C.role_def("chronicler").shape == "CHRONICLER_TRIO" and C.role_def("chronicler").cannot_hold_solo_secret and C.role_def("chronicler").min_gift_day == 3, "Chronicler RoleDef registered with CHRONICLER_TRIO and Night-3 metadata")
	_check(C.role_def("augur").shape == "AUGUR_CROSSING" and C.role_def("augur").day and C.role_def("augur").marked_registers, "Augur RoleDef registered with AUGUR_CROSSING and Marked metadata")
	_check(C.role_def("magistrate").shape == "MAGISTRATE_NOM" and C.role_def("magistrate").marked_registers and C.role_def("magistrate").min_gift_day == 1, "Magistrate RoleDef registered with MAGISTRATE_NOM metadata")
	for rid in C.ROLES.keys():
		_check(C.role_def(rid) != null and C.role_def(rid).to_role_dict() == C.ROLES[rid], "%s RoleDef.to_role_dict() matches C.ROLES['%s'] exactly" % [rid, rid])


func _test_seer_hooks() -> void:
	var g = Game.new()
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

	C.role_def("seer").on_reading_heard(seer, seer, no_entry, true)
	_check(not C.role_def("seer").has_method("info_effects") and seer.cleared.has(a.id) and seer.cleared.has(b.id), "Seer on_reading_heard clears both subjects on own fresh NO reading without legacy info_effects")

	w.day = 1
	seer.trust = 0.9
	# Agreeing is a roll (likely at this trust): ask again if the first draw says no, so the
	# check doesn't hang on the random stream's position.
	var req: Dictionary = {}
	for attempt in range(6):
		req = Mind.consider_gift_request(w, seer, "seer", [a.id, b.id])
		if req.get("agreed", false):
			break
	_check(req.get("agreed", false) and Mind.seer_picks(w, seer) == [a.id, b.id], "Seer RoleDef agrees to trusted player gift request and picks requested pair")
	var reading: Dictionary = C.role_def("seer").generate_reading(w, seer, {}, Mind)
	_check(reading.get("data", {}).get("pair", []) == [a.id, b.id] and reading.has("text"), "Seer RoleDef.generate_reading produces reading for picked pair")


func _test_warden_hooks() -> void:
	var g = Game.new()
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
	g.log_dir = "user://test_logs"
	g.new_case(9103, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var evils: Array = w.living().filter(func(person): return person.is_evil())
	var clerk = goods[0]
	var arch = goods[1]
	var grave = goods[2]
	var subject_good = goods[3]
	var subject_other = goods[4]
	var minion = evils.filter(func(m): return m.role != "demon")[0]

	_give(w, clerk, "clerk")
	_give(w, arch, "archivist")
	_give(w, grave, "gravedigger")
	for healthy_npc in [clerk, arch, grave]:
		if healthy_npc.secret_mod == "delusional":
			healthy_npc.secret_mod = ""
	if subject_good.secret_mod == "marked":
		subject_good.secret_mod = ""

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

	# 1. Dowser ROLE_AT_SITE group_count reading (requires public locations, not at home)
	w.day = 1
	dowser.loc = "home"
	victim.loc = "home"
	other.loc = "home"
	_check(C.role_def("dowser").generate_reading(w, dowser, {"day_phase": true}, Mind).is_empty(), "Dowser generate_reading does not trigger while at home")
	dowser.loc = "tavern"
	victim.loc = "well"
	other.loc = "tavern"
	var dw_r: Dictionary = C.role_def("dowser").generate_reading(w, dowser, {"day_phase": true}, Mind)
	_check(dw_r.get("data", {}).get("group", []).size() >= 2 and dw_r.get("data", {}).get("block", "") == w.loc_block("tavern"), "Dowser generate_reading reads public crowd on block during day phase")
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
	_check(not C.role_def("medium").has_method("info_effects") and dowser.id in C.role_def("medium").clears(med_entry["data"]), "Medium delegates clears/defence without legacy info_effects")

	medium.info_log.append(med_entry)
	medium.claimed_role = "medium"
	medium.claim_public = true
	medium.history[w.time_key(1, C.NIGHT)] = "night:" + victim.home_block
	w.day = 2
	var med_night: Dictionary = Mind.answer_night(w, medium, 1)
	_check(med_night["facts"].size() >= 1 and med_night["facts"][0].get("duty", "") == "medium", "Medium night_duty_alibi reports visiting victim's hearth")


func _test_count_and_route_hooks() -> void:
	var g = Game.new()
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

	# 1. Surveyor (block alignment parity on random non-own >=2 resident block)
	var surv_r: Dictionary = C.role_def("surveyor").generate_reading(w, surv, {}, Mind)
	var surv_blk: String = str(surv_r.get("data", {}).get("block", ""))
	_check(surv_blk in C.BLOCKS and surv_blk != surv.home_block and w.npcs.filter(func(m): return m.home_block == surv_blk).size() >= 2 and surv_r.get("data", {}).get("same") is bool, "Surveyor generate_reading reads alignment parity on a non-own >=2 resident block")
	var surv_entry = {"role": "surveyor", "day": 0, "data": surv_r["data"], "text": surv_r["text"]}
	_check(Gifts.implicated(surv_entry).is_empty() and Gifts.clears(surv_entry).is_empty(), "Surveyor reading implicates and clears nobody directly")
	_check("Surveyor:" in Gifts.short_text("surveyor", surv_r["data"], surv.name, name_fn), "Surveyor short_text formats block alignment parity")

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

	# 2. Psychologist (PSYCH_STATEMENTS)
	w.day = 0
	_check(C.role_def("psychologist").generate_reading(w, psych, {}, Mind).is_empty(), "Psychologist generate_reading never triggers on Night 0")
	w.day = 1
	var PR = preload("res://sim/roles/psychologist.gd")
	PR.record_heard(w, psych, vet.id, {"kind": "alibi", "source": vet.id, "subject": [vet.id], "home": true, "block": vet.home_block, "day": 0, "phase": C.NIGHT, "text": "home"}, false)
	var psych_nf: Dictionary = C.role_def("psychologist").generate_reading(w, psych, {}, Mind)
	_check(psych_nf.get("data", {}).get("mode", "") == "none_false" and int(psych_nf.get("data", {}).get("day_heard", -1)) == 1, "Psychologist generate_reading reports none_false when all heard statements are true")
	PR.record_heard(w, psych, martyr.id, {"kind": "sighting", "source": martyr.id, "subject": [rumor.id], "block": rumor.home_block, "day": 0, "phase": C.NIGHT, "text": "saw"}, true, "lying")
	var psych_pair: Dictionary = C.role_def("psychologist").generate_reading(w, psych, {}, Mind)
	_check(psych_pair.get("data", {}).get("mode", "") == "pair" and psych_pair.get("data", {}).get("statements", []).size() == 2, "Psychologist generate_reading reports statement pair when at least one heard statement is false")

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
	_check(is_equal_approx(seer_claim_parts.get("gift_keeps_giving", 0.0), Tuning.Roles.ONGOING_INFO_EARLY_CLAIM), "Ongoing info RoleDef sets gift_keeps_giving = -0.45 on Day 1")
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
	_check(Domain.gift_time({"role": "chronicler", "observed_at": {"day": 3, "phase": "night"}}) and not Domain.gift_time({"role": "chronicler", "observed_at": {"day": 2, "phase": "night"}}) and not Domain.gift_time({"role": "chronicler", "observed_at": {"day": 4, "phase": "night"}}), "Domain.gift_time restricts Chronicler to Night 3")
	_check(Domain.gift_time({"role": "augur", "observed_at": {"day": 1, "phase": "evening"}}) and not Domain.gift_time({"role": "augur", "observed_at": {"day": 1, "phase": "morning"}}) and not Domain.gift_time({"role": "augur", "observed_at": {"day": 1, "phase": "night"}}), "Domain.gift_time restricts Augur to Evening day>=1")
	_check(Domain.gift_time({"role": "magistrate", "observed_at": {"day": 1, "phase": "night"}}) and not Domain.gift_time({"role": "magistrate", "observed_at": {"day": 0, "phase": "night"}}), "Domain.gift_time restricts Magistrate to Night day>=1")

	# 6. MindMeeting & MindDialogue module extraction checks
	_check(Mind.MindMeeting != null and Mind.MindDialogue != null, "Mind preloads MindMeeting and MindDialogue modules")
	_check(Mind.reveal_cost(w, rumor) == Mind.MindMeeting.reveal_cost(w, rumor), "Mind.reveal_cost forwards identically to MindMeeting.reveal_cost")
	_check(Mind.fear_chance(w, rumor) == Mind.MindDialogue.fear_chance(w, rumor), "Mind.fear_chance forwards identically to MindDialogue.fear_chance")
	_check(Mind.protection_kind(w, rumor) == Mind.MindDialogue.protection_kind(w, rumor), "Mind.protection_kind forwards identically to MindDialogue.protection_kind")

	# 7. GameBoard & GamePresentation module extraction checks
	_check(g.GameBoard != null and g.GamePresentation != null, "Game preloads GameBoard and GamePresentation modules")
	_check(g.filter_cards("") == g.GameBoard.filter_cards(g, ""), "Game.filter_cards forwards identically to GameBoard.filter_cards")
	_check(g.timeline_data() == g.GameBoard.timeline_data(g), "Game.timeline_data forwards identically to GameBoard.timeline_data")

	# 8. Codex review regressions: raw-data implicated/clears & single Martyr registration roll
	_check(vet.id in C.role_def("dowser").implicated({"group": [vet.id, sexton.id], "count": 1, "block": vet.home_block}), "Dowser implicated() accepts a raw data dict and names the group member")
	_check(vet.id in C.role_def("martyr").implicated({"target": vet.id, "evil": true}), "Martyr evil outcome implicates its target from a raw data dict")
	_check(vet.id in C.role_def("gravedigger").clears({"executed": vet.id, "role": "warden"}), "Gravedigger good-role reading clears the executed from a raw data dict")
	_check(vet.id in C.role_def("rumormonger").clears({"pair": [vet.id, sexton.id], "secret": "marked"}), "Rumormonger reading clears from a raw data dict")
	_check(not (vet.id in C.role_def("archivist").clears({"pair": [vet.id, sexton.id], "role": "poisoner"})), "a non-clearing reading clears nobody")

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
	_check(is_equal_approx(Mind.SERIOUS_GRIEVANCE, Tuning.Trust.SERIOUS_GRIEVANCE), "Mind constants alias Tuning.Trust")
	_check(is_equal_approx(Mind.CONSENSUS_BASE, Tuning.Meeting.CONSENSUS_BASE) and is_equal_approx(C.DEFENCE_ROPE, Tuning.Meeting.DEFENCE_ROPE), "Meeting constants alias Tuning.Meeting")
	_check(is_equal_approx(C.EVIL_CAUTION_DEMON, Tuning.Evil.EVIL_CAUTION_DEMON) and is_equal_approx(Evil.HEAT_FADE, Tuning.Evil.HEAT_FADE), "Evil constants alias Tuning.Evil")
	_check(is_equal_approx(C.role_def("seer").public_threat_bonus, Tuning.Roles.SEER.public_threat_bonus) and is_equal_approx(C.role_def("warden").quiet_night_effect, Tuning.Roles.WARDEN.quiet_night_effect), "RoleDefs read per-role tuning from Tuning.Roles")
	_check(Reasoner.profile(0.2).cards == Tuning.Workshop.PROFILE_LOW.cards and Reasoner.profile(0.5).rivals == Tuning.Workshop.PROFILE_MEDIUM.rivals and Reasoner.profile(0.8).support == Tuning.Workshop.PROFILE_HIGH.support, "Reasoner.profile reads Low/Medium/High profiles from Tuning.Workshop")


# ---- test_chunk2_world_mask_roles


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


# ---- test_chunk3_executor_registrar


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


# ---- test_roster


## Give a good NPC a role (swapping with whoever holds it, so roles stay unique).
func _world(sd: int, size: int = 7):
	var w = World.new()
	w.setup(sd, size)
	return w


func _test_setup(size: int) -> void:
	var bad: Array = []
	var mods = {}
	# At least 20 deals, then until all four secrets have turned up (at most 60, as before).
	for sd in range(9000, 9060):
		if sd >= 9020 and mods.size() == 4:
			break
		var w = _world(sd, size)
		var cfg: Dictionary = C.SETUPS[size]
		var roles: Array = w.npcs.map(func(n): return n.role)
		var town: Array = roles.filter(func(r): return r in C.GOOD_ROLES)
		var mins: Array = roles.filter(func(r): return C.is_minion(r))
		var uniq = {}
		for r in roles:
			uniq[r] = true
		var holders: Array = w.npcs.filter(func(n): return n.secret_mod != "")
		var kinds = {}
		for h in holders:
			kinds[h.secret_mod] = true
		var ok = w.npcs.size() == size and town.size() == cfg["town"] and mins.size() == cfg["minions"] \
			and roles.count("demon") == 1 and uniq.size() == size \
			and town.filter(func(r): return r in C.START_ROLES).size() >= 2 \
			and town.filter(func(r): return r in C.IDENTIFIER_ROLES).size() >= 1 \
			and kinds.size() == 1 and holders.all(func(h): return not h.is_evil()) \
			and holders.size() == (2 if kinds.has("lovers") else 1)
		for k in kinds:
			mods[k] = true
		if not ok:
			bad.append(sd)
	print("%d-player setups: bad seeds %s; secrets seen %s" % [size, str(bad), str(mods.keys())])
	_check(bad.is_empty(), "%d-player setup: right counts, unique roles, 2+ start gifts, an identifier, one secret on the good" % size)
	_check(mods.size() == 4, "%d-player: all four secrets turn up" % size)


func _test_homes_and_bluffs() -> void:
	var bad = 0
	for sd in range(9500, 9520):
		for size in [7, 10]:
			var w = _world(sd, size)
			var counts = {}
			for n in w.npcs:
				counts[n.home_block] = counts.get(n.home_block, 0) + 1
			var vals: Array = counts.values()
			if vals.size() < 4 or vals.max() - vals.min() > 1:
				bad += 1
	_check(bad == 0, "homes are spread evenly across the blocks")
	var invalid_fake = 0
	var total = 0
	# Enough fake Surveyor readings to judge them: at least 40 deals and 30 readings, at
	# most the 380 deals this used to walk every time.
	for sd in range(9520, 9900):
		if sd >= 9560 and total >= 30:
			break
		var w2 = _world(sd, 10)
		for m in w2.evil_team():
			for e in m.info_log:
				if e.get("fake", false) and e["role"] == "surveyor":
					total += 1
					var fblk: String = str(e["data"].get("block", ""))
					var fres: int = w2.npcs.filter(func(x): return x.home_block == fblk).size()
					if fblk not in C.BLOCKS or fblk == m.home_block or fres < 2 or not (e["data"].get("same") is bool):
						invalid_fake += 1
	print("fake Surveyor invalid block/parity readings: %d/%d" % [invalid_fake, total])
	_check(total > 0 and invalid_fake == 0, "fake Surveyor bluffs always pick an eligible non-own >=2 resident block")
