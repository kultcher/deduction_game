## The Case Workshop as a pull-out sheet over the case board. The sheet slides in from
## the right edge; the uncovered part of the board stays live (pan, zoom, drag cards
## onto the sheet). Free drag with gentle snaps at collapsed, half and full width.
extends Control

signal filed
signal changed

const UITheme = preload("res://ui/theme.gd")
const Editor = preload("res://ui/live_case_workshop.gd")

const COLLAPSED = 0.05
const SNAPS = [COLLAPSED, 0.5, 1.0]
const SNAP_RANGE = 0.04
const HANDLE_W = 30.0
const MIN_COLLAPSED_PX = 56.0

var g
var execute: Callable
var editor          # ui/live_case_workshop.gd
var sheet: Control
var handle: Control
var collapsed_label: Label
var fraction: float = COLLAPSED
var _collapsed = true   # collapsed stays collapsed (a handle) whatever the board's width
var _dragging = false
var _drag_moved = false
var _restore_fraction: float = 0.5
var _flash = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UITheme.flat(UITheme.color("bg"), UITheme.color("border"), 2, 0, 0))
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.clip_contents = true
	sheet.set_drag_forwarding(Callable(), _can_drop, _drop)
	add_child(sheet)
	collapsed_label = Label.new()
	collapsed_label.text = "C\na\ns\ne\n\nW\no\nr\nk\ns\nh\no\np"
	collapsed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collapsed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	collapsed_label.add_theme_color_override("font_color", UITheme.color("accent"))
	collapsed_label.add_theme_font_size_override("font_size", 15)
	collapsed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(collapsed_label)
	handle = Control.new()
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	handle.tooltip_text = "Case Workshop: drag to open or resize; click to open or collapse. Drop cards here to add them."
	handle.gui_input.connect(_handle_input)
	handle.draw.connect(_draw_handle)
	handle.set_drag_forwarding(Callable(), _can_drop, _drop)
	add_child(handle)
	resized.connect(_layout)
	_layout()

func set_game(game) -> void:
	g = game
	if editor == null:
		# The editor reads the live case as it starts, so it waits for a game.
		editor = Editor.new()
		editor.g = g
		editor.execute = execute
		editor.filed.connect(func(): filed.emit())
		editor.cards_dropped.connect(_drop_cards)
		editor.contents_changed.connect(func(): changed.emit())
		sheet.add_child(editor)
		sheet.move_child(editor, 0)
	else:
		editor.g = g
		editor.refresh()
	_layout()

## Re-read the live case (new cards, state changes) while the sheet is open.
func refresh() -> void:
	if editor != null and not is_collapsed():
		editor.refresh()

func set_fraction(value: float, snap: bool = false) -> void:
	var minimum: float = _min_fraction()
	fraction = clampf(value, minimum, 1.0)
	if snap:
		for point in SNAPS:
			var p: float = maxf(point, minimum)
			if absf(fraction - p) <= SNAP_RANGE:
				fraction = p
	_collapsed = fraction <= minimum + 0.001
	_layout()
	changed.emit()

func is_collapsed() -> bool:
	return _collapsed

func open(value: float = 0.5) -> void:
	if fraction < value:
		set_fraction(value)

func collapse() -> void:
	set_fraction(COLLAPSED)

## Screen-space width the sheet covers (the board stays usable to its left).
func covered_width() -> float:
	return size.x * fraction

## Add a board card to the Workshop. The sheet stays as it is; a collapsed handle
## flashes so the player sees the card arrived.
func add_card(number: int) -> void:
	if g == null or number < 1 or number > g.board.size():
		return
	if g.board[number - 1].kind == "deduction" or editor == null:
		return
	editor.add_evidence(number)
	_flash = 1.0
	handle.queue_redraw()
	if is_collapsed():
		_pulse()

func _pulse() -> void:
	var tween = create_tween()
	tween.tween_method(func(v): _flash = v; handle.queue_redraw(), 1.0, 0.0, 0.9)

func _min_fraction() -> float:
	if size.x <= 0.0:
		return COLLAPSED
	return maxf(COLLAPSED, MIN_COLLAPSED_PX / size.x)

func _layout() -> void:
	if sheet == null or size.x <= 0.0:
		return
	fraction = _min_fraction() if _collapsed else clampf(fraction, _min_fraction(), 1.0)
	var width: float = size.x * fraction
	var left: float = size.x - width
	handle.position = Vector2(left, 0)
	handle.size = Vector2(HANDLE_W, size.y)
	sheet.position = Vector2(left + HANDLE_W, 0)
	sheet.size = Vector2(maxf(width - HANDLE_W, 0.0), size.y)
	var collapsed: bool = is_collapsed()
	if editor != null:
		var was_hidden: bool = not editor.visible
		editor.visible = not collapsed
		if was_hidden and editor.visible:
			editor.refresh()
	collapsed_label.visible = collapsed
	handle.queue_redraw()

func _handle_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_dragging = true
			_drag_moved = false
		else:
			_dragging = false
			if _drag_moved:
				set_fraction(fraction, true)
			elif is_collapsed():
				set_fraction(_restore_fraction)
			else:
				_restore_fraction = fraction
				collapse()
		handle.accept_event()
	elif ev is InputEventMouseMotion and _dragging:
		_drag_moved = true
		var x: float = handle.position.x + ev.position.x
		set_fraction(1.0 - x / size.x)
		handle.accept_event()

func _draw_handle() -> void:
	var r = Rect2(Vector2.ZERO, handle.size)
	var base: Color = UITheme.color("panel").lerp(UITheme.color("accent"), 0.25 + 0.5 * _flash)
	handle.draw_rect(r, base)
	handle.draw_line(Vector2(0, 0), Vector2(0, r.size.y), UITheme.color("accent"), 2.0)
	var mid: float = r.size.y / 2.0
	# Grip: three bars, plus an arrow pointing the way the sheet will go on click.
	for i in range(3):
		var x: float = 10.0 + i * 5.0
		handle.draw_line(Vector2(x, mid - 34), Vector2(x, mid + 34), UITheme.color("muted"), 2.0)
	var arrow = PackedVector2Array()
	var cx: float = r.size.x / 2.0
	if is_collapsed():
		arrow = PackedVector2Array([Vector2(cx + 6, mid - 58), Vector2(cx - 6, mid - 50), Vector2(cx + 6, mid - 42)])
	else:
		arrow = PackedVector2Array([Vector2(cx - 6, mid - 58), Vector2(cx + 6, mid - 50), Vector2(cx - 6, mid - 42)])
	handle.draw_colored_polygon(arrow, UITheme.color("accent"))

func _can_drop(_at: Vector2, data) -> bool:
	return data is Dictionary and data.has("cards") and g != null

func _drop(_at: Vector2, data) -> void:
	_drop_cards(data["cards"])

func _drop_cards(numbers: Array) -> void:
	for n in numbers:
		if n is int:
			add_card(n)
