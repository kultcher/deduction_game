## Slice 1 tests: hidden profile receipts, board cleanup, immutable filing snapshots,
## bereavement dated trait preservation, and Workshop Townsfolk Profile Info nodes.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Session = preload("res://workshop/session.gd")
const LiveEditor = preload("res://ui/live_case_workshop.gd")

var checks = 0
var fails = 0

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)

func _game(sd: int = 692, count: int = 7):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, count)
	return g

func _run() -> void:
	_test_setup_receipts_and_board_cleanup()
	_test_immutable_filing_on_new_haunt()
	_test_bereavement_dated_traits()
	_test_profile_node_person_swap_and_restore()
	await _test_live_editor_dropdown_and_shortcuts()
	print("Profile receipts: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _test_setup_receipts_and_board_cleanup() -> void:
	var g = _game(692, 10)
	_check(not g.board.any(func(c): return c.kind in ["home", "work", "haunt"]), "main board has no home, work, or haunt cards")
	_check(g.profile_receipts.size() == 20, "10-person setup mints 10 home and 10 work hidden receipts")
	_check(g.profile_receipts.all(func(c): return c.n <= -10001 and g.receipt_by_number(c.n) == c), "negative receipt numbers (-10001..) avoid synthetic draft root -1 and resolve via receipt_by_number")

func _test_immutable_filing_on_new_haunt() -> void:
	var g = _game(692, 7)
	var speaker = g.w.living_good()[0]
	var target = g.w.npcs.filter(func(p): return p != speaker)[0]
	var loc0: String = target.haunts[0]
	var loc1: String = target.haunts[1]
	g.known_haunts[target.id] = [loc0]
	g.add_profile_receipt({"kind": "haunt", "subject": [target.id], "source": speaker.id, "loc": loc0, "locs": [loc0],
		"block": g.w.loc_block(loc0), "day": 1, "phase": 0, "class": "circumstantial",
		"text": "%s says %s often goes to %s when not working." % [speaker.name, target.name, g.w.loc_name(loc0)]})
	var v1: Dictionary = WorkshopCanvas.view(g)
	var model = CanvasModel.new(v1)
	var prem: String = model.selected
	model.nodes[prem].conclusion = {"type": "suspicious", "target": target.id, "at": v1.alignment_epoch}
	var pnode: String = model.add_profile_info(target.id, ["home_work", "haunts"])
	model.connect_cards(pnode, prem)
	var compiled1: Dictionary = model.compile(prem)
	_check(compiled1.cards.size() == 3, "compiled profile node cites home, work, and the single known haunt")
	var filed_num: int = WorkshopCanvas.file(g, compiled1)
	_check(filed_num > 0, "Workshop case with hidden profile receipts files onto board")
	var frozen_cards: Array = g.board[filed_num - 1].workshop_case.cards.duplicate()
	# Now discover the second haunt later: the already-filed case must NOT mutate.
	g.known_haunts[target.id].append(loc1)
	g.add_profile_receipt({"kind": "haunt", "subject": [target.id], "source": speaker.id, "loc": loc1, "locs": [loc1],
		"block": g.w.loc_block(loc1), "day": 2, "phase": 1, "class": "circumstantial",
		"text": "%s says %s often goes to %s when not working." % [speaker.name, target.name, g.w.loc_name(loc1)]})
	_check(g.board[filed_num - 1].workshop_case.cards == frozen_cards, "learning a second haunt does not mutate an already-filed case")
	model.view = WorkshopCanvas.view(g)
	_check(model.nodes[pnode].receipt_ids.size() == 3, "existing canvas draft keeps its cited receipts until explicitly synced")
	model.sync_profile_node(pnode)
	var compiled2: Dictionary = model.compile(prem)
	_check(compiled2.cards.size() == 4, "syncing the draft pulls in the newly learned second haunt receipt")
	var rev_num: int = WorkshopCanvas.file(g, compiled2, filed_num)
	_check(rev_num > filed_num and g.board[rev_num - 1].get("revises", 0) == filed_num, "re-filing with newly synced profile fact creates a clean revision")
	var snap2: Dictionary = WorkshopCanvas.snapshot(g, compiled2, speaker.id)
	var prepared: Dictionary = Assess.prepare(snap2)
	_check(prepared.ready, "shared evaluator prepares all profile receipt kinds without fallback")
	_check(Shared.endorsed_facts(snap2, snap2.root).size() == 4, "synthetic draft root -1 never collides with profile receipt board_map")
	_check(WorkshopCanvas.status(g, compiled2).ready, "WorkshopCanvas.status succeeds across audience with first profile receipt included")

func _test_bereavement_dated_traits() -> void:
	var g = _game(692, 7)
	var a = g.w.npcs[0]
	var b = g.w.npcs[1]
	a.secret_mod = "lovers"
	b.secret_mod = "lovers"
	a.lover = b.id
	b.lover = a.id
	a.traits["privacy"] = 0.2
	a.revealed_traits["privacy"] = "low"
	var r1: int = g._record_trait_receipt(a, "privacy", "low", "player")
	b.alive = false
	g.w.day = 2
	g.w._bereave(b)
	g.sync_bereaved_traits(a, "player")
	var traits_for_a: Array = g.profile_receipts_for(a.id, "personality")
	_check(r1 < 0 and traits_for_a.size() == 2, "bereavement adds a new dated trait receipt rather than overwriting the historical one")
	_check(traits_for_a[0].tier == "low" and not traits_for_a[0].withdrawn and traits_for_a[1].tier == "high" and traits_for_a[1].withdrawn, "both pre-bereavement and post-bereavement trait tiers are preserved with dates")

func _test_profile_node_person_swap_and_restore() -> void:
	var g = _game(692, 7)
	var a = g.w.npcs[0]
	var b = g.w.npcs[1]
	g.known_haunts[a.id] = [a.haunts[0]]
	g.add_profile_receipt({"kind": "haunt", "subject": [a.id], "source": b.id, "loc": a.haunts[0], "locs": [a.haunts[0]],
		"block": g.w.loc_block(a.haunts[0]), "day": 1, "phase": 0, "text": "Haunt A"})
	var view: Dictionary = WorkshopCanvas.view(g)
	var model = CanvasModel.new(view)
	var pid: String = model.add_profile_info(a.id, ["home_work", "haunts"])
	_check("haunts" in model.nodes[pid].facets, "unlocked haunts facet is selected for person A")
	model.set_profile_person(pid, b.id)
	_check(model.nodes[pid].person == b.id and model.nodes[pid].facets == ["home_work"], "swapping person drops facets that are still locked for person B")
	var sess = Session.new()
	sess.scenario = {"public_view": view}
	var copy = CanvasModel.new(view)
	var err: String = copy.restore(model.export_data(), sess)
	_check(err == "" and copy.nodes.has(pid), "canvas export/restore validates profile_info nodes cleanly")

func _test_live_editor_dropdown_and_shortcuts() -> void:
	var g = _game(692, 7)
	var editor = LiveEditor.new()
	editor.g = g
	root.add_child(editor)
	await process_frame
	var labels: Array = []
	for i in range(editor.premise_type.item_count):
		labels.append(editor.premise_type.get_item_text(i))
	_check("is suspicious" in labels and not ("Supporting evidence (no claim)" in labels), "Premise dropdown retains 'is suspicious' and removes 'Supporting evidence (no claim)'")
	var added_id: String = editor.add_profile_info(g.w.npcs[0].id, "home_work")
	_check(added_id != "" and editor.board.nodes[added_id].kind == "profile_info", "LiveCaseWorkshop adds and selects a Townsfolk Profile Info node")
	editor.queue_free()
	await process_frame
