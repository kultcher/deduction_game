## Whereabouts panel (workshop/location_solver.gd): choose a question (a death, a silencing, or
## a place on a day), see each person's known whereabouts across the day's three phases and
## whether they fit, and commit a Whereabouts node to the Case Workshop. The node cites the
## day's log in one piece, so listeners hear your watches as a single card.
extends VBoxContainer

signal commit_requested(question: Dictionary)
signal person_clicked(person_id: String)

const UITheme = preload("res://ui/theme.gd")
const LocationSolver = preload("res://workshop/location_solver.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const C = preload("res://sim/content.gd")

const NAME_W = 100.0
const CELL_W = 150.0
const VERDICT_W = 230.0

var g
var question: Dictionary = {}
var last_result: Dictionary = {}
var _case_world = null

var intro_label: Label
var question_pick: OptionButton
var place_pick: OptionButton
var day_pick: SpinBox
var empty_label: Label
var grid: GridContainer
var grid_scroll: ScrollContainer
var places_label: Label
var summary_label: Label
var commit_btn: Button
var _questions: Array = []


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	intro_label = Label.new()
	intro_label.text = "Cross-reference who was where. Pick a death, a silencing or a place, and see what you know of everyone's day: what you saw, what others told you, and work hours. Committing adds one Whereabouts card that hands the town your record of that day."
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_label.add_theme_font_size_override("font_size", 14)
	intro_label.add_theme_color_override("font_color", UITheme.color("muted"))
	add_child(intro_label)

	var pick_row = HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 8)
	add_child(pick_row)
	question_pick = OptionButton.new()
	question_pick.name = "QuestionPick"
	question_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_pick.item_selected.connect(_on_question_picked)
	pick_row.add_child(question_pick)
	place_pick = OptionButton.new()
	place_pick.name = "PlacePick"
	for l in LocationSolver.DayPresence.PLACES:
		place_pick.add_item(C.loc_name(l))
		place_pick.set_item_metadata(place_pick.item_count - 1, l)
	place_pick.item_selected.connect(func(_i): _on_place_changed())
	pick_row.add_child(place_pick)
	day_pick = SpinBox.new()
	day_pick.name = "DayPick"
	day_pick.prefix = "Day"
	day_pick.min_value = 1
	day_pick.max_value = 1
	day_pick.value_changed.connect(func(_v): _on_place_changed())
	pick_row.add_child(day_pick)

	empty_label = Label.new()
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.add_theme_font_size_override("font_size", 15)
	empty_label.add_theme_color_override("font_color", UITheme.color("muted"))
	add_child(empty_label)

	places_label = Label.new()
	places_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	places_label.add_theme_font_size_override("font_size", 13)
	places_label.add_theme_color_override("font_color", UITheme.color("accent"))
	add_child(places_label)

	grid_scroll = ScrollContainer.new()
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.custom_minimum_size = Vector2(0, 240)
	add_child(grid_scroll)
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid_scroll.add_child(grid)

	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	add_child(footer)
	summary_label = Label.new()
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 14)
	summary_label.add_theme_color_override("font_color", UITheme.color("accent"))
	footer.add_child(summary_label)
	commit_btn = Button.new()
	commit_btn.name = "CommitWhereabouts"
	commit_btn.text = "Commit to Workshop"
	commit_btn.tooltip_text = "Adds (or updates) a Whereabouts card on the Case Workshop canvas, citing your record of that day and the sightings others told you."
	commit_btn.pressed.connect(func():
		if not question.is_empty():
			commit_requested.emit(question.duplicate(true)))
	footer.add_child(commit_btn)


func set_game(game) -> void:
	if _case_world != (game.w if game != null else null):
		_case_world = game.w if game != null else null
		question = {}
	g = game
	refresh()


func set_question(q: Dictionary) -> void:
	question = q.duplicate(true)
	refresh()


func refresh() -> void:
	if g == null:
		return
	var view: Dictionary = WorkshopCanvas.view(g)
	day_pick.max_value = maxi(1, g.w.day)
	_questions = LocationSolver.questions(view)
	question_pick.clear()
	for q in _questions:
		question_pick.add_item(LocationSolver.label(view, q))
	question_pick.add_item("A place on a day…")
	if question.is_empty():
		question = _questions[0].duplicate(true) if not _questions.is_empty() else {"kind": "place", "day": maxi(1, g.w.day), "loc": LocationSolver.DayPresence.PLACES[0]}
	var qi: int = _questions.map(func(q): return LocationSolver.key(q)).find(LocationSolver.key(question))
	question_pick.select(qi if qi >= 0 else _questions.size())
	var is_place: bool = str(question.get("kind", "")) == "place"
	place_pick.visible = is_place
	day_pick.visible = is_place
	if is_place:
		place_pick.select(maxi(0, LocationSolver.DayPresence.PLACES.find(str(question.get("loc", "")))))
		day_pick.set_value_no_signal(int(question.get("day", 1)))
	last_result = LocationSolver.evaluate(view, question)
	_rebuild(view, last_result)


func _on_question_picked(i: int) -> void:
	if i < _questions.size():
		question = _questions[i].duplicate(true)
	else:
		question = {"kind": "place", "day": int(day_pick.value) if day_pick.value >= 1 else maxi(1, g.w.day), "loc": str(place_pick.get_item_metadata(maxi(0, place_pick.selected)))}
	refresh()


func _on_place_changed() -> void:
	if str(question.get("kind", "")) != "place":
		return
	question = {"kind": "place", "day": int(day_pick.value), "loc": str(place_pick.get_item_metadata(maxi(0, place_pick.selected)))}
	refresh()


func _rebuild(view: Dictionary, res: Dictionary) -> void:
	for ch in grid.get_children():
		ch.queue_free()
	var day: int = int(res.get("day", 1))
	var watched: Array = res.get("watched_phases", [])
	var has_record: bool = not watched.is_empty() or not res.get("report_ids", []).is_empty()
	empty_label.visible = not has_record
	empty_label.text = "You didn't watch anywhere on day %d and nobody's told you where anyone was, so there's nothing to cross-reference yet beyond work hours." % day
	var kind: String = str(res.question.get("kind", ""))
	if kind == "silence":
		places_label.text = "Who was out on the same block as %s, phase by phase." % LocationSolver._name(view, str(res.question.get("victim", "")))
	else:
		var names: Array = res.get("places", []).map(func(l): return C.loc_name(l))
		var tail: String = ""
		if int(res.get("unknown_haunts", 0)) > 0:
			tail = "  ·  %d of their haunts unknown" % int(res.unknown_haunts)
		places_label.text = ("Places: " + ", ".join(PackedStringArray(names)) if not names.is_empty() else "No known places") + tail
	for h in ["", "Morning", "Afternoon", "Evening", "Verdict"]:
		var hl = Label.new()
		hl.text = h + (" (watched)" if h.to_lower() in watched else "")
		hl.add_theme_font_size_override("font_size", 13)
		hl.add_theme_color_override("font_color", UITheme.color("accent"))
		hl.custom_minimum_size = Vector2(NAME_W if h == "" else (VERDICT_W if h == "Verdict" else CELL_W), 0)
		grid.add_child(hl)
	for row in res.get("rows", []):
		var nb = Button.new()
		nb.text = str(row.name)
		nb.flat = true
		nb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nb.custom_minimum_size = Vector2(NAME_W, 0)
		var pid: String = str(row.id)
		nb.pressed.connect(func(): person_clicked.emit(pid))
		grid.add_child(nb)
		for cell in row.cells:
			var cl = Label.new()
			cl.text = str(cell.text)
			cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cl.custom_minimum_size = Vector2(CELL_W, 0)
			cl.add_theme_font_size_override("font_size", 12)
			var col: Color = UITheme.color("muted")
			if float(cell.get("p", 0.0)) >= LocationSolver.CERTAIN:
				col = Color("7cc48e")
			elif cell.state in ["seen", "work", "absent"] and float(cell.get("p", 0.0)) <= 0.0:
				col = Color("c98a7e")
			elif cell.state == "reported":
				col = Color("d9be7a")
			cl.add_theme_color_override("font_color", col)
			cl.tooltip_text = "%s · chance at the places this phase: %d%%" % [str(cell.text), int(round(float(cell.get("p", 0.0)) * 100.0))]
			cl.mouse_filter = Control.MOUSE_FILTER_PASS
			grid.add_child(cl)
		var vl = Label.new()
		var glyph: String = {"fits": "✓ ", "unknown": "? ", "ruled_out": "✕ "}.get(str(row.verdict), "")
		vl.text = glyph + str(row.reason)
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vl.custom_minimum_size = Vector2(VERDICT_W, 0)
		vl.add_theme_font_size_override("font_size", 12)
		vl.add_theme_color_override("font_color", {"fits": Color("7cc48e"), "unknown": Color("d9a95a"), "ruled_out": Color("c98a7e")}.get(str(row.verdict), UITheme.color("text")))
		grid.add_child(vl)
	summary_label.text = "%d ✓ fit  ·  %d ? unknown  ·  %d ✕ ruled out" % [res.get("fits", []).size(), res.get("unknown", []).size(), res.get("ruled_out", []).size()]
	commit_btn.disabled = not has_record
