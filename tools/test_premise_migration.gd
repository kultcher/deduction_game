## A board saved before the premise trim (#416, Nov 20) still opens cleanly:
## "is a Minion" reads as "is evil", "holds their claimed gift" as "is good", and "these
## reports conflict" becomes an unclaimed premise that keeps its cards and links
## (CanvasModel.migrate_retired_premises).
##   godot --headless --path . --script res://tools/test_premise_migration.gd
extends SceneTree

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

## Writes an old-style premise of `type` about `target` straight into the board, as a
## saved board from before the trim holds it.
func _old_premise(board, target: String, type: String, at: Vector2, extra: Dictionary = {}) -> String:
	var id: String = board.add_premise(target, "evil", at)
	board.nodes[id].conclusion = {"type": type, "target": target, "at": board.view.alignment_epoch}.merged(extra)
	return id

func _run() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	scene.show_script_at_start = false
	scene.seed_box.value = 692
	scene.size_opt.select(1)
	scene._new_case()
	scene.roles_win.hide()
	scene.case_view.open_workshop()
	await process_frame
	await process_frame
	var ed = scene.case_view.workshop.editor
	var g = scene.g
	var who = g.w.npcs[0]
	var other = g.w.npcs[1]

	# The model: each retired type is brought up to date, and nothing else changes.
	var board = ed.board
	var minion: String = _old_premise(board, who.id, "minion", Vector2(0, 0))
	var gift: String = _old_premise(board, other.id, "role", Vector2(400, 0), {"role": "seer"})
	var conflict: String = _old_premise(board, "", "conflict", Vector2(800, 0))
	var kept: String = board.add_premise(who.id, "suspicious", Vector2(1200, 0))
	var number: int = 0
	for c in g.board:
		if c.get("kind", "") in ["sighting", "info", "claim", "alibi"] and ed._usable(int(c.n)):
			number = int(c.n)
			break
	var first_card: String = ed.add_evidence(number, false) if number > 0 else ""
	if first_card != "":
		board.connect_cards(first_card, conflict)
	var links_before: int = board.links.size()
	check(links_before > 0, "(fixture) the conflict premise has a linked card (%d links)" % links_before)
	var changed: int = board.migrate_retired_premises()
	check(changed == 3, "three retired premises are updated (%d)" % changed)
	check(board.nodes[minion].conclusion.type == "evil" and board.nodes[minion].conclusion.target == who.id, "\"is a Minion\" becomes \"is evil\" about the same person")
	check(board.nodes[gift].conclusion.type == "good" and not board.nodes[gift].conclusion.has("role") and board.nodes[gift].conclusion.target == other.id, "\"holds their claimed gift\" becomes \"is good\", its gift field dropped")
	check(board.nodes[conflict].conclusion.is_empty() and board.nodes[conflict].get("draft", false), "\"these reports conflict\" becomes an unclaimed premise")
	check(board.links.size() == links_before, "its cards and links are kept (%d links)" % board.links.size())
	check(board.nodes[kept].conclusion.type == "suspicious", "a current premise type is left alone")
	check(board.migrate_retired_premises() == 0, "running it again changes nothing")
	check(not ("is minion" in board.title(minion)) and board.title(minion) == "%s is evil" % who.name, "the premise reads as its new claim (%s)" % board.title(minion))

	# A saved draft from before the trim opens with the new types.
	var saved: Dictionary = board.export_data()
	saved.nodes[minion].conclusion = {"type": "minion", "target": who.id, "at": board.view.alignment_epoch}
	saved.nodes[conflict].conclusion = {"type": "conflict", "target": "", "at": board.view.alignment_epoch}
	saved.nodes[conflict].erase("draft")
	g.workshop_draft = {"canvas": saved, "files": {}, "filed_answers": {}, "root": minion}
	ed.case_world = null
	ed.refresh()
	await process_frame
	check(ed.board.nodes.has(minion) and ed.board.nodes[minion].conclusion.type == "evil", "a saved board's Minion premise opens as \"is evil\"")
	check(ed.board.nodes.has(conflict) and ed.board.nodes[conflict].conclusion.is_empty(), "and its conflict premise opens unclaimed")

	# Undo restores a snapshot the same way.
	ed._undo = {"canvas": saved.duplicate(true), "root": minion, "files": {}}
	ed._undo_remove()
	check(ed.board.nodes[minion].conclusion.type == "evil" and ed.board.nodes[conflict].conclusion.is_empty(), "an undo snapshot from before the trim is brought up to date too")
	print("Premise migration: %d checks, %d failures" % [checks, fails])
	scene.queue_free()
	quit(1 if fails else 0)
