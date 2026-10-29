extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const Circumstantial = preload("res://workshop/circumstantial.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const LiveCaseWorkshop = preload("res://ui/live_case_workshop.gd")

var checks: int = 0
var fails: int = 0

func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		push_error("FAIL: " + msg)

func _game(seed_val: int = 2404, size: int = 7):
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = false
	g.new_case(seed_val, size)
	for p in g.w.npcs:
		for m in [p, p.shadow]:
			if m == null:
				continue
			m.info_log = []
			m.known_claims = {}
			m.beliefs = []
			m.ledger = {}
			m.workshop_state = {"enabled": false, "reasoning_mode": "full", "confidence_mode": "scale"}
			for id in m.suspicion:
				m.suspicion[id] = 0.1
	g.set_workshop_effects(true)
	return g

func _init() -> void:
	_test_canvas_hub_orphan_and_restore()
	_test_stage1_preserved_through_hub_and_stage2_gated()
	_test_union_dedup_cap_and_retraction()
	_test_native_adjust_preserves_stage2_layer()
	_test_smear_backlash()
	await _test_live_workshop_ui_hub()
	if fails == 0:
		print("test_workshop_circumstantial_hub: ALL %d CHECKS PASSED" % checks)
		quit(0)
	else:
		printerr("test_workshop_circumstantial_hub: %d/%d FAILED" % [fails, checks])
		quit(1)

func _test_canvas_hub_orphan_and_restore() -> void:
	var g = _game(2401, 7)
	var view: Dictionary = WorkshopCanvas.view(g)
	var model = CanvasModel.new(view)
	var hub_id: String = model.add_circumstantial_hub(Vector2(300, 260))
	_check(model.nodes.has(hub_id) and model.nodes[hub_id].kind == "circumstantial", "CanvasModel adds circumstantial hub node")
	_check(model.hub_premise_targets(hub_id).is_empty(), "unlinked circumstantial hub reports empty premise targets (Needs a premise)")
	var prem_id: String = model.nodes.keys().filter(func(k): return model.nodes[k].kind == "premise")[0]
	var target_id: String = g.w.npcs[0].id
	model.nodes[prem_id].conclusion = {"type": "evil", "target": target_id, "at": view.alignment_epoch}
	var pnode: String = model.add_profile_info(target_id, ["home_work"])
	# Clicking Link from hub -> profile_info auto-orients profile_info -> hub!
	var err_auto: String = model.connect_cards(hub_id, pnode)
	_check(err_auto == "" and model.links.any(func(e): return e.from == pnode and e.to == hub_id), "connect_cards auto-orients supporting cards into circumstantial hub")
	var err_prem: String = model.connect_cards(hub_id, prem_id)
	_check(err_prem == "" and prem_id in model.hub_premise_targets(hub_id), "linked circumstantial hub resolves its target premise")
	var compiled: Dictionary = model.compile(prem_id)
	_check(compiled.has("circumstantial") and compiled.circumstantial.size() == 1 and not compiled.cards.is_empty(), "compiled premise retains both Stage 1 cards and Stage 2 circumstantial hub descriptor")
	# Export & restore
	var session = preload("res://workshop/session.gd").new()
	session.scenario = {"public_view": view}
	var copy = CanvasModel.new(view)
	var r_err: String = copy.restore(model.export_data(), session)
	_check(r_err == "" and copy.nodes.has(hub_id), "CanvasModel.restore validates circumstantial hub nodes cleanly")
	# Removing hub clears active and contradiction prior_links
	model.remove_circumstantial(hub_id)
	_check(not model.nodes.has(hub_id) and not model.links.any(func(e): return e.from == hub_id or e.to == hub_id), "remove_circumstantial removes hub and cleans links")

func _test_stage1_preserved_through_hub_and_stage2_gated() -> void:
	var g = _game(2402, 7)
	var listener = g.w.living_good()[0]
	var target = g.w.living_good()[1]
	var silenced_p = g.w.living_good()[2]
	var victim = g.w.living_good()[3]
	g.w.day = 1
	g.w.phase = C.EVENING
	target.work = "bakery"
	target.haunts = ["tavern", "mill"]
	# Public murder + Breathstealer silence on Day 1
	g.w.public_event("demon_death", [victim.id], "town")
	g.w.public_event("silenced", [silenced_p.id], "town")
	var death_num: int = g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1, "block": victim.home_block, "text": "Public death"})
	var sil_num: int = g.add_card({"kind": "silenced", "source": "player", "subject": [silenced_p.id], "day": 1, "phase": C.EVENING, "text": "Silenced at meeting"})
	var conv_num: int = g.add_card({"kind": "conversation", "source": "player", "subject": [target.id, silenced_p.id], "block": "market", "loc": "bakery", "day": 1, "phase": C.MORNING, "text": "Talking before silence"})
	var trace_num: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": victim.id, "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a grease-darkened brass farthing",
		"text": "Scene trace: farthing (the Bakery or the Tavern).",
	})
	var view: Dictionary = WorkshopCanvas.view(g)
	# 1) Pure vibes without Stage 1 grounding: gate == 0 -> zero Stage 2 suspicion!
	var vibes_only = CanvasModel.new(view)
	var root_v: String = vibes_only.selected
	vibes_only.nodes[root_v].conclusion = {"type": "evil", "target": target.id, "at": view.alignment_epoch}
	var hub_v: String = vibes_only.add_circumstantial_hub()
	for num in [sil_num, conv_num]:
		var cid: String = WorkshopCanvas.Evidence.normalize_card(g.board[num - 1]).id
		vibes_only.connect_cards("e:" + cid, hub_v)
	vibes_only.connect_cards(hub_v, root_v)
	var filed_v: int = WorkshopCanvas.file(g, vibes_only.compile(root_v))
	_check(filed_v > 0, "vibes-only hub case files cleanly")
	g._evaluate_deduction(listener, g.board[filed_v - 1], 1.0, false)
	_check(is_zero_approx(float(listener.workshop_state.get("circumstantial_applied", {}).get(target.id, 0.0))), "Stage 2 vibes alone cannot carry a case without Stage 1 grounding")
	g.workshop_retract(filed_v, listener.id)

	# 2) Stage 1 trace + profile wired alongside Stage 2 Breathstealer proximity hub:
	# Compare Stage 1 only vs Stage 1 + Hub (and verify Stage 1 trace routed THROUGH the hub keeps full Stage 1 weight!)
	var s1_board = CanvasModel.new(view)
	var root_s1: String = s1_board.selected
	s1_board.nodes[root_s1].conclusion = {"type": "evil", "target": target.id, "at": view.alignment_epoch}
	var tr_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[trace_num - 1]).id
	var dt_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[death_num - 1]).id
	s1_board.connect_cards("e:" + tr_id, root_s1)
	s1_board.connect_cards("e:" + dt_id, root_s1)
	var p_s1: String = s1_board.add_profile_info(target.id, ["home_work"])
	s1_board.connect_cards(p_s1, root_s1)
	var filed_s1: int = WorkshopCanvas.file(g, s1_board.compile(root_s1))
	g._evaluate_deduction(listener, g.board[filed_s1 - 1], 1.0, false)
	var s1_susp: float = listener.suspicion[target.id]
	var s1_req: float = float(listener.workshop_state.requested.get(target.id, 0.0))
	g.workshop_retract(filed_s1, listener.id)

	var s2_board = CanvasModel.new(view)
	var root_s2: String = s2_board.selected
	s2_board.nodes[root_s2].conclusion = {"type": "evil", "target": target.id, "at": view.alignment_epoch}
	var hub_s2: String = s2_board.add_circumstantial_hub()
	# Wire trace + profile + Breathstealer proximity ALL through the hub to test Sol's channel-routing rule!
	s2_board.connect_cards("e:" + tr_id, hub_s2)
	s2_board.connect_cards("e:" + dt_id, hub_s2)
	var p_s2: String = s2_board.add_profile_info(target.id, ["home_work"])
	s2_board.connect_cards(p_s2, hub_s2)
	for num in [sil_num, conv_num]:
		var cid2: String = WorkshopCanvas.Evidence.normalize_card(g.board[num - 1]).id
		s2_board.connect_cards("e:" + cid2, hub_s2)
	s2_board.connect_cards(hub_s2, root_s2)
	var filed_s2: int = WorkshopCanvas.file(g, s2_board.compile(root_s2))
	g._evaluate_deduction(listener, g.board[filed_s2 - 1], 1.0, false)
	var hub_s1_req: float = float(listener.workshop_state.requested.get(target.id, 0.0))
	var hub_s2_app: float = float(listener.workshop_state.get("circumstantial_applied", {}).get(target.id, 0.0))
	_check(is_equal_approx(hub_s1_req, s1_req), "routing Stage 1 trace/profile evidence through a Circumstantial Hub preserves exact Stage 1 weight")
	_check(hub_s2_app > 0.0 and hub_s2_app <= Tuning.Workshop.CIRCUMSTANTIAL_INCIDENT_MAX + 1e-6 and listener.suspicion[target.id] > s1_susp, "qualifying Breathstealer proximity adds bounded Stage 2 suspicion (<= +0.015) on top of Stage 1")

func _test_union_dedup_cap_and_retraction() -> void:
	var g = _game(2403, 7)
	var listener = g.w.living_good()[0]
	var target = g.w.living_good()[1]
	var accomplice = g.w.living_good()[2]
	var trusted_ally = g.w.living_good()[3]
	var victim = g.w.living_good()[4]
	g.w.day = 2
	g.w.phase = C.EVENING
	target.work = "bakery"
	# Give listener high suspicion on accomplice and high trust / low suspicion on trusted_ally
	listener.suspicion[accomplice.id] = 0.65
	listener.npc_trust[trusted_ally.id] = 0.85
	listener.suspicion[trusted_ally.id] = 0.08
	# Seed 4 distinct qualifying incidents (Breathstealer prox, accomplice conversation, hostile vote against trusted_ally, rivalry with murder victim + refusal)
	g.w.public_event("demon_death", [victim.id], "town")
	g.w.public_event("silenced", [trusted_ally.id], "town")
	g.w.public_event("vote", [trusted_ally.id], "town", {"nominee": trusted_ally.id, "nominator": target.id, "yes": [target.id, accomplice.id], "no": [listener.id], "player_yes": false, "count": 2, "threshold": 4, "outcome": "fails"})
	var death_num: int = g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1, "block": victim.home_block, "text": "Public death"})
	var trace_num: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": victim.id, "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a grease-darkened brass farthing",
		"text": "Scene trace: farthing (the Bakery or the Tavern).",
	})
	var sil_num: int = g.add_card({"kind": "silenced", "source": "player", "subject": [trusted_ally.id], "day": 2, "phase": C.EVENING, "text": "Silenced"})
	var prox_num: int = g.add_card({"kind": "conversation", "source": "player", "subject": [target.id, trusted_ally.id], "block": "market", "loc": "bakery", "day": 2, "phase": C.MORNING, "text": "With ally before silence"})
	var assoc_num: int = g.add_card({"kind": "conversation", "source": "player", "subject": [target.id, accomplice.id], "block": "market", "loc": "bakery", "day": 2, "phase": C.AFTERNOON, "text": "With suspected accomplice"})
	var vote_num: int = g.add_card({"kind": "vote", "source": "player", "subject": [target.id, accomplice.id, trusted_ally.id], "day": 2, "phase": C.EVENING, "nominee": trusted_ally.id, "by": target.id, "yes": [target.id, accomplice.id], "no": [listener.id], "player_yes": false, "count": 2, "threshold": 4, "outcome": "fails", "text": "Vote tally"})
	var ref_num: int = g.add_card({"kind": "refusal", "source": target.id, "subject": [target.id], "day": 1, "phase": C.NIGHT, "fear": false, "withheld": true, "text": "Refused night account"})
	g.add_profile_receipt({"kind": "bond", "subject": [target.id, victim.id], "bond_kind": "rival", "source": listener.id, "day": 1, "phase": 0, "text": "At odds with victim"})

	var view: Dictionary = WorkshopCanvas.view(g)
	var baseline_before: float = listener.suspicion[target.id]
	var board = CanvasModel.new(view)
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "evil", "target": target.id, "at": view.alignment_epoch}
	var hub: String = board.add_circumstantial_hub()
	for num in [death_num, trace_num, sil_num, prox_num, assoc_num, vote_num, ref_num]:
		var cid: String = WorkshopCanvas.Evidence.normalize_card(g.board[num - 1]).id
		board.connect_cards("e:" + cid, hub)
	var pnode: String = board.add_profile_info(target.id, ["home_work", "bonds"])
	board.connect_cards(pnode, hub)
	board.connect_cards(hub, root)
	var filed1: int = WorkshopCanvas.file(g, board.compile(root))
	g._evaluate_deduction(listener, g.board[filed1 - 1], 1.0, false)
	var applied_total: float = float(listener.workshop_state.get("circumstantial_applied", {}).get(target.id, 0.0))
	_check(applied_total > 0.03 and applied_total <= Tuning.Workshop.CIRCUMSTANTIAL_TARGET_CAP + 1e-6, "4+ qualifying incidents cap cleanly at +0.045 per (listener, target) (got %.4f)" % applied_total)

	# Presenting a second distinct case citing the same hub incidents cannot breach +0.045 or double-count!
	var board2 = CanvasModel.new(view)
	var root2: String = board2.selected
	board2.nodes[root2].conclusion = {"type": "suspicious", "target": target.id, "at": view.alignment_epoch}
	var hub2: String = board2.add_circumstantial_hub()
	for num in [sil_num, prox_num, assoc_num]:
		var cid2: String = WorkshopCanvas.Evidence.normalize_card(g.board[num - 1]).id
		board2.connect_cards("e:" + cid2, hub2)
	board2.connect_cards(hub2, root2)
	var filed2: int = WorkshopCanvas.file(g, board2.compile(root2))
	g._evaluate_deduction(listener, g.board[filed2 - 1], 1.0, false)
	var after_second: float = float(listener.workshop_state.get("circumstantial_applied", {}).get(target.id, 0.0))
	_check(after_second <= Tuning.Workshop.CIRCUMSTANTIAL_TARGET_CAP + 1e-6 and is_equal_approx(after_second, applied_total), "second overlapping hub presentation deduplicates incidents and respects +0.045 global cap")

	# Refresh idempotence: recomputing beliefs does NOT feed Stage 2 into Stage 1 priors!
	var susp_snapshot: float = listener.suspicion[target.id]
	Mind.recompute_beliefs(g.w, listener, "idempotence check")
	_check(is_equal_approx(listener.suspicion[target.id], susp_snapshot), "belief refresh retracts Stage 2 before Stage 1 so vibes never compound into priors")

	# Retracting both cases restores exact baseline suspicion!
	g.workshop_retract(filed1, listener.id)
	g.workshop_retract(filed2, listener.id)
	_check(is_zero_approx(float(listener.workshop_state.get("circumstantial_applied", {}).get(target.id, 0.0))) and is_equal_approx(listener.suspicion[target.id], baseline_before), "withdrawing cases fully retracts Stage 2 circumstantial suspicion")

func _test_native_adjust_preserves_stage2_layer() -> void:
	var g = _game(2406, 7)
	var listener = g.w.living_good()[0]
	var target = g.w.living_good()[1]
	var silenced_p = g.w.living_good()[2]
	var victim = g.w.living_good()[3]
	g.w.day = 1
	g.w.phase = C.EVENING
	target.work = "bakery"
	target.haunts = ["tavern", "mill"]
	g.w.public_event("demon_death", [victim.id], "town")
	g.w.public_event("silenced", [silenced_p.id], "town")
	var death_num: int = g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1, "block": victim.home_block, "text": "Public death"})
	var sil_num: int = g.add_card({"kind": "silenced", "source": "player", "subject": [silenced_p.id], "day": 1, "phase": C.EVENING, "text": "Silenced at meeting"})
	var conv_num: int = g.add_card({"kind": "conversation", "source": "player", "subject": [target.id, silenced_p.id], "block": "market", "loc": "bakery", "day": 1, "phase": C.MORNING, "text": "Talking before silence"})
	var trace_num: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": victim.id, "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a grease-darkened brass farthing",
		"text": "Scene trace: farthing (the Bakery or the Tavern).",
	})
	var view: Dictionary = WorkshopCanvas.view(g)
	var baseline_before: float = listener.suspicion[target.id]
	var board = CanvasModel.new(view)
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "evil", "target": target.id, "at": view.alignment_epoch}
	var hub: String = board.add_circumstantial_hub()
	for num in [death_num, trace_num, sil_num, conv_num]:
		var cid: String = WorkshopCanvas.Evidence.normalize_card(g.board[num - 1]).id
		board.connect_cards("e:" + cid, hub)
	var pnode: String = board.add_profile_info(target.id, ["home_work"])
	board.connect_cards(pnode, hub)
	board.connect_cards(hub, root)
	var filed: int = WorkshopCanvas.file(g, board.compile(root))
	g._evaluate_deduction(listener, g.board[filed - 1], 1.0, false)
	var s1_req: float = float(listener.workshop_state.requested.get(target.id, 0.0))
	var s2_req: float = float(listener.workshop_state.get("circumstantial_requested", {}).get(target.id, 0.0))
	_check(s2_req > 0.0, "precondition: listener holds nonzero Stage 2 circumstantial suspicion before native adjust")
	var pre_adjust_susp: float = listener.suspicion[target.id]
	var grief_delta: float = 0.12
	Mind.adjust(g.w, listener, target.id, grief_delta, "execution grief test", "", false)
	_check(is_equal_approx(listener.suspicion[target.id], pre_adjust_susp + grief_delta), "Mind.adjust preserves both Stage 1 and Stage 2 layers immediately")
	_check(is_equal_approx(float(listener.workshop_state.outside[target.id]), baseline_before + grief_delta), "Mind.adjust advances state.outside by exact native delta")
	Mind.recompute_beliefs(g.w, listener, "post-adjust refresh check")
	_check(is_equal_approx(float(listener.workshop_state.outside[target.id]), baseline_before + grief_delta) and is_equal_approx(listener.suspicion[target.id], baseline_before + grief_delta + s1_req + float(listener.workshop_state.get("circumstantial_requested", {}).get(target.id, 0.0))), "ownership refresh after Mind.adjust does not subtract Stage 2 contribution from outside baseline")
	g.workshop_retract(filed, listener.id)
	_check(is_equal_approx(listener.suspicion[target.id], baseline_before + grief_delta), "withdrawing case after Mind.adjust restores exact baseline plus native delta")

func _test_smear_backlash() -> void:
	var g = _game(2404, 7)
	var listener = g.w.living_good()[0]
	var target = g.w.living_good()[1]
	var bystander = g.w.living_good()[2]
	listener.trust = 0.6
	listener.npc_trust[target.id] = 0.75
	var benign_num: int = g.add_card({"kind": "sighting", "source": "player", "subject": [bystander.id], "block": "market", "day": 1, "phase": C.MORNING, "text": "Unrelated morning sighting"})
	var view: Dictionary = WorkshopCanvas.view(g)
	var board = CanvasModel.new(view)
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "evil", "target": target.id, "at": view.alignment_epoch}
	var hub: String = board.add_circumstantial_hub()
	board.connect_cards("e:" + WorkshopCanvas.Evidence.normalize_card(g.board[benign_num - 1]).id, hub)
	board.connect_cards(hub, root)
	var filed: int = WorkshopCanvas.file(g, board.compile(root))
	var trust_before: float = listener.trust
	g._evaluate_deduction(listener, g.board[filed - 1], 1.0, true)
	var drop: float = trust_before - listener.trust
	_check(drop >= Tuning.Workshop.CIRCUMSTANTIAL_SMEAR_MIN - 1e-5 and drop <= Tuning.Workshop.CIRCUMSTANTIAL_SMEAR_MAX + 1e-5, "ungrounded circumstantial smear triggers [-0.015, -0.005] trust backlash (drop=%.4f)" % drop)

func _test_live_workshop_ui_hub() -> void:
	var g = _game(2405, 7)
	var editor = LiveCaseWorkshop.new()
	editor.g = g
	root.add_child(editor)
	await process_frame
	var hub_id: String = editor.add_circumstantial_hub()
	_check(hub_id != "" and editor.board.nodes.has(hub_id) and editor.board.nodes[hub_id].kind == "circumstantial", "LiveCaseWorkshop adds and selects Circumstantial Evidence hub")
	editor.remove_node(hub_id)
	_check(not editor.board.nodes.has(hub_id), "LiveCaseWorkshop removes Circumstantial Evidence hub cleanly")
	editor._undo_remove()
	_check(editor.board.nodes.has(hub_id), "LiveCaseWorkshop undo restores removed Circumstantial Evidence hub")
	editor.queue_free()
	await process_frame
