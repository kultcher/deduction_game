## On-card answers: the click rules (CanvasModel.apply_answer) and the "registered as
## Marked" answer for Dowser and Surveyor readings.
##   godot --headless --path . --script res://tools/test_workshop_card_answers.gd
extends SceneTree
const Solver = preload("res://workshop/solver.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/workshop_checkpoint_v5.json"))
	var core: Dictionary = data.examples.filter(func(e): return e.name == "core")[0]
	var view: Dictionary = core.view
	var model = CanvasModel.new(view)
	var dowser: Dictionary = view.cards.filter(func(c): return c.get("role", "") == "dowser")[0].duplicate(true)
	dowser.data.count = 1
	var p: String = dowser.data.group[0]
	var q: String = dowser.data.group[1] if dowser.data.group.size() > 1 else ""
	# Dowser: ? -> registered -> registered as Marked -> ?
	var a: Dictionary = model.apply_answer(dowser, {}, "pick", p)
	check(a.positive == [p] and not a.has("marked"), "first click marks a Dowser face as registering")
	a = model.apply_answer(dowser, a, "pick", p)
	check(a.positive == [p] and a.marked == [p], "second click says they registered because Marked")
	if q != "":
		var full: Dictionary = model.apply_answer(dowser, a, "pick", q)
		check(full.positive == [p], "a Dowser answer never names more people than the count")
	a = model.apply_answer(dowser, a, "pick", p)
	check(a.positive.is_empty() and not a.has("marked"), "third click clears the face")
	# Evaluator: registered as Marked keeps only worlds where that person is Marked.
	var universe: Array = Solver.universe(view)
	var any_reason: PackedByteArray = Solver.report_table(view, dowser, [p])
	var as_marked: PackedByteArray = Solver.report_table(view, dowser, [p], [], [p])
	var index: int = Solver.person_index(view, p)
	var only_marked = true
	var narrower = false
	for i in range(universe.size()):
		if as_marked[i] == 1 and universe[i].marked != index:
			only_marked = false
		if as_marked[i] == 1 and any_reason[i] == 0:
			narrower = false
			only_marked = false
		if any_reason[i] == 1 and as_marked[i] == 0:
			narrower = true
	check(only_marked, "\"registered as Marked\" only fits worlds where that person is the Marked one")
	check(narrower, "and is a narrower answer than \"registered\"")
	# Seer: pick one of the pair, then the registration.
	var seers: Array = view.cards.filter(func(c): return c.get("role", "") == "seer" and c.data.get("yes", false))
	if not seers.is_empty():
		var seer: Dictionary = seers[0]
		var s: Dictionary = model.apply_answer(seer, {}, "pick", seer.data.pair[0])
		s = model.apply_answer(seer, s, "pick", seer.data.pair[1])
		check(s.positive == [seer.data.pair[1]], "a Seer yes answer picks one person; picking the other switches")
		s = model.apply_answer(seer, s, "reg", "red_herring")
		check(s.registration == "red_herring", "the registration chip sets the explanation")
	# Surveyor: a block tile, then a resident on it, cycling to Marked.
	var surveyor: Dictionary = view.cards.filter(func(c): return c.get("role", "") == "surveyor")[0].duplicate(true)
	surveyor.data.count = 2
	var resident: Dictionary = view.people[0]
	var b: String = resident.home
	var sv: Dictionary = model.apply_answer(surveyor, {}, "block", b)
	check(sv.blocks == [b] and sv.positive.is_empty(), "a block tile marks that block")
	sv = model.apply_answer(surveyor, sv, "resident", resident.id)
	check(sv.blocks.is_empty() and sv.positive == [resident.id], "a resident face replaces their block with that resident")
	sv = model.apply_answer(surveyor, sv, "resident", resident.id)
	check(sv.marked == [resident.id], "clicking the resident again says they registered as Marked")
	sv = model.apply_answer(surveyor, sv, "block", b)
	check(sv.blocks.is_empty() and sv.positive.is_empty() and not sv.has("marked"), "clicking the tile again clears the block")
	print("Workshop card answers: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)
