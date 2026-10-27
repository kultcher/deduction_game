## A bounded, observational debug view. Never issues game commands.
extends Window
const Feed = preload("res://sim/decision_feed.gd")
var feed
var people: OptionButton
var kinds: OptionButton
var shadows: CheckBox
var pause: CheckBox
var mirror: CheckBox
var tree: Tree
var detail: TextEdit
var _version = -1
var _elapsed = 0.0
var _shown: Array = []
var _frozen: Array = []
var _dirty = true

func _init() -> void:
	title = "NPC decision rolls"
	size = Vector2i(1100, 700)
	min_size = Vector2i(700, 420)
	visible = false
	close_requested.connect(hide)
	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(box)
	var controls = HFlowContainer.new()
	box.add_child(controls)
	people = OptionButton.new()
	people.add_item("All NPCs")
	controls.add_child(people)
	kinds = OptionButton.new()
	kinds.add_item("All decisions")
	controls.add_child(kinds)
	for picker in [people, kinds]: picker.item_selected.connect(func(_i): _dirty = true)
	shadows = CheckBox.new()
	shadows.text = "Include good-self simulations"
	shadows.toggled.connect(func(on):
		if feed != null: feed.console_shadow = on
		_dirty = true)
	controls.add_child(shadows)
	pause = CheckBox.new()
	pause.text = "Pause scrolling"
	pause.toggled.connect(func(on):
		_frozen = feed.records.duplicate() if on and feed != null else []
		_dirty = true)
	controls.add_child(pause)
	mirror = CheckBox.new()
	mirror.text = "Console mirror"
	mirror.toggled.connect(func(on):
		if feed != null: feed.console = on)
	controls.add_child(mirror)
	var clear = Button.new()
	clear.text = "Clear"
	clear.pressed.connect(func():
		if feed != null: feed.clear()
		_frozen = []
		_dirty = true)
	controls.add_child(clear)
	var copy = Button.new()
	copy.text = "Copy visible"
	copy.pressed.connect(func(): DisplayServer.clipboard_set(visible_text()))
	controls.add_child(copy)
	var hint = Label.new()
	hint.text = "Latest 1,000 checks. Select a row for inputs, calculations, actual draws and cutoffs. Chances are conditional on earlier gates."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var split = VSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	tree = Tree.new()
	tree.columns = 5
	tree.hide_root = true
	tree.column_titles_visible = true
	for i in range(5): tree.set_column_title(i, ["Time", "NPC", "Decision / trigger", "Success chance", "Result"][i])
	tree.set_column_expand_ratio(2, 3)
	tree.set_column_expand_ratio(3, 2)
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_selected.connect(_show_detail)
	tree.custom_minimum_size.y = 100
	split.add_child(tree)
	detail = TextEdit.new()
	detail.editable = false
	detail.custom_minimum_size.y = 120
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_color_override("font_readonly_color", Color(0.94, 0.94, 0.94))
	detail.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	split.add_child(detail)

func set_feed(value) -> void:
	feed = value
	_version = -1
	_frozen = []
	pause.set_pressed_no_signal(false)
	mirror.set_pressed_no_signal(feed.console)
	shadows.set_pressed_no_signal(false)
	feed.console_shadow = false
	people.clear()
	people.add_item("All NPCs")
	kinds.clear()
	kinds.add_item("All decisions")
	_dirty = true
	_refresh()

func _process(delta: float) -> void:
	if not visible or feed == null: return
	_elapsed += delta
	if _elapsed < 0.1: return
	_elapsed = 0.0
	if _dirty or (not pause.button_pressed and _version != feed.version): _refresh()

func _chosen(picker: OptionButton) -> String:
	return str(picker.get_selected_metadata()) if picker.selected > 0 else ""

func _options(picker: OptionButton, values: Dictionary, all_text: String) -> void:
	var chosen = _chosen(picker)
	picker.clear()
	picker.add_item(all_text)
	var keys: Array = values.keys()
	keys.sort()
	for key in keys:
		picker.add_item(str(values[key]))
		picker.set_item_metadata(picker.item_count - 1, key)
		if str(key) == chosen: picker.select(picker.item_count - 1)

func _refresh() -> void:
	if feed == null: return
	var data: Array = _frozen if pause.button_pressed else feed.records
	var names = {}
	var categories = {}
	for event in data:
		names[event.actor] = event.name
		categories[event.kind] = event.kind.replace("_", " ")
	_options(people, names, "All NPCs")
	_options(kinds, categories, "All decisions")
	var actor = _chosen(people)
	var kind = _chosen(kinds)
	var selected_seq: int = tree.get_selected().get_metadata(0) if tree.get_selected() != null else -1
	var follow_latest: bool = not pause.button_pressed and (selected_seq == -1 or (not _shown.is_empty() and selected_seq == _shown[-1].seq))
	_shown = data.filter(func(e): return (actor == "" or actor == e.actor) and (kind == "" or kind == e.kind) and (shadows.button_pressed or e.stream != "shadow"))
	tree.clear()
	var root = tree.create_item()
	var selected = null
	for event in _shown:
		var row = tree.create_item(root)
		row.set_metadata(0, event.seq)
		row.set_text(0, "D%d %s" % [event.day, event.phase])
		row.set_text(1, str(event.name) + (" [good self]" if event.stream == "shadow" else ""))
		row.set_text(2, event.kind.replace("_", " ") + " / " + event.stage + " · " + event.trigger)
		row.set_text(3, Feed.chance_text(event))
		row.set_text(4, str(event.result))
		row.set_tooltip_text(2, "Select for stat values, actual draws, calculations and thresholds.")
		if event.seq == selected_seq: selected = row
	if (selected == null or follow_latest) and root.get_child_count() > 0: selected = root.get_child(root.get_child_count() - 1)
	if selected != null:
		selected.select(0)
		if not pause.button_pressed: tree.scroll_to_item(selected)
	else: detail.text = "No matching checks. Capture starts when Debug is enabled."
	_show_detail()
	_version = feed.version
	_dirty = false

func _show_detail() -> void:
	if tree.get_selected() == null: return
	var seq = tree.get_selected().get_metadata(0)
	for event in _shown:
		if event.seq == seq:
			detail.text = Feed.format_record(event)
			return

func visible_text() -> String:
	return "\n\n".join(PackedStringArray(_shown.map(func(e): return Feed.format_record(e))))
