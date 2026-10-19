## A non-modal case-board overlay. Its parent owns the full canvas; moving, resizing,
## or hiding this panel never changes the board's size or its pan/zoom coordinates.
extends PanelContainer

const UITheme = preload("res://ui/theme.gd")

var content: VBoxContainer
var minimum_panel_size = Vector2(340, 240)
var _dragging = false
var _resizing = false

func build(title: String) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UITheme.flat(UITheme.color("panel"), UITheme.color("border"), 2, 6, 10))
	var box = VBoxContainer.new()
	add_child(box)
	var header = HBoxContainer.new()
	box.add_child(header)
	var handle = Label.new()
	handle.text = title
	handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	handle.tooltip_text = "Drag to move this panel. Resize with the bottom-right corner."
	handle.add_theme_color_override("font_color", UITheme.color("accent"))
	handle.gui_input.connect(func(ev): _handle_input(ev, false))
	header.add_child(handle)
	var close = Button.new()
	close.text = "Minimize"
	close.pressed.connect(hide)
	header.add_child(close)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var footer = HBoxContainer.new()
	box.add_child(footer)
	var space = Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(space)
	var grip = Label.new()
	grip.text = "◢"
	grip.custom_minimum_size = Vector2(22, 22)
	grip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.tooltip_text = "Drag to resize"
	grip.gui_input.connect(func(ev): _handle_input(ev, true))
	footer.add_child(grip)
	custom_minimum_size = minimum_panel_size
	hide()

func _handle_input(ev: InputEvent, resize_handle: bool) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_dragging = ev.pressed and not resize_handle
		_resizing = ev.pressed and resize_handle
		if ev.pressed:
			move_to_front()
		accept_event()
	elif ev is InputEventMouseMotion and (_dragging or _resizing):
		if _resizing:
			resize_to(size + ev.relative)
		else:
			move_to(position + ev.relative)
		accept_event()

func move_to(at: Vector2) -> void:
	var limit = (get_parent_control().size - size).max(Vector2.ZERO)
	position = at.clamp(Vector2.ZERO, limit)

func resize_to(wanted: Vector2) -> void:
	var bounds = get_parent_control().size
	custom_minimum_size = minimum_panel_size.min(bounds)
	size = wanted.clamp(custom_minimum_size, (bounds - position).max(custom_minimum_size))
	move_to(position)

func fit_inside() -> void:
	var bounds = get_parent_control().size
	custom_minimum_size = minimum_panel_size.min(bounds)
	size = size.clamp(custom_minimum_size, bounds.max(custom_minimum_size))
	move_to(position)
