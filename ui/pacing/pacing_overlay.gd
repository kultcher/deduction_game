## Plays the execution and the night's reveal as a short sequence of beats over the town
## (Michael, Nov 22; the beats are built by ui/pacing/pacing_plans.gd). Presentation only.
##
## A click lands whatever is moving or ends the pause; a click on a "Continue" goes on. Esc,
## or "Skip", ends the whole sequence: the log already holds every line. Reduced motion has
## no shake, flash or spin, and halves the pauses (a small call on Michael's behalf).
##
## The art and motion are Limner's: KillWheel and ExecutionMark (ui/fx/). Without them this
## falls back to a plain portrait, a drawn X and a named slice, so the flow works either way.
extends Control

signal done

const UITheme = preload("res://ui/theme.gd")
const C = preload("res://sim/content.gd")

const CONTINUE = "Continue"
const SKIP = "Skip"
const FADE_SECS = 0.6
const SHAKE_SECS = 0.35
const SHAKE_PX = 14.0

var beats: Array = []
var index: int = -1
var reduced_motion: bool = false
var w

var _shade: ColorRect
var _stage: Control
var _above: RichTextLabel
var _below: RichTextLabel
var _centre: Control           # the portrait or the wheel
var _continue: Button
var _skip: Button
var _left: float = 0.0          # seconds left in a timed beat
var _busy = null                # a component still playing (wheel, mark)
var _waiting: bool = false      # waiting on Continue
var _tweens: Array = []
var _shake_left: float = 0.0
var _last_angle: float = NAN    # where the last wheel stopped, for the next spin

## Opens over `parent` and plays `beats`. Calls `then` when it ends, however it ends.
static func open(parent: Control, world, beat_list: Array, reduced: bool = false, then: Callable = Callable()) -> Control:
	var o = load("res://ui/pacing/pacing_overlay.gd").new()
	o.name = "Pacing"
	o.w = world
	o.beats = beat_list
	o.reduced_motion = reduced
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(o)
	if then.is_valid():
		o.done.connect(then, CONNECT_ONE_SHOT)
	o._build()
	o._next()
	return o

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	_above = _headline("Above", 0.06, 0.16)
	_below = _headline("Below", 0.84, 0.94)
	_continue = Button.new()
	_continue.name = "Continue"
	_continue.text = CONTINUE
	_continue.visible = false
	_continue.anchor_left = 0.45
	_continue.anchor_right = 0.55
	_continue.anchor_top = 0.95
	_continue.anchor_bottom = 0.99
	_continue.pressed.connect(func(): _go_on())
	add_child(_continue)
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.text = SKIP
	_skip.flat = true
	_skip.add_theme_color_override("font_color", UITheme.color("muted"))
	_skip.anchor_left = 0.9
	_skip.anchor_right = 0.99
	_skip.anchor_top = 0.01
	_skip.anchor_bottom = 0.05
	_skip.pressed.connect(finish)
	add_child(_skip)
	grab_focus()

func _headline(node_name: String, top: float, bottom: float) -> RichTextLabel:
	var l = RichTextLabel.new()
	l.name = node_name
	l.bbcode_enabled = true
	l.fit_content = false
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.anchor_left = 0.05
	l.anchor_right = 0.95
	l.anchor_top = top
	l.anchor_bottom = bottom
	l.add_theme_font_size_override("normal_font_size", 34)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	add_child(l)
	return l

# ------------------------------------------------------------------ running the beats

func _next() -> void:
	index += 1
	_left = 0.0
	_busy = null
	_waiting = false
	_continue.visible = false
	if index >= beats.size():
		finish()
		return
	var b: Dictionary = beats[index]
	match str(b.get("type", "")):
		"fade":
			_tween(_shade, "color:a", float(b.get("to", 1.0)), FADE_SECS)
			_left = _secs(FADE_SECS)
		"portrait":
			_show_portrait(str(b.id))
			_left = _secs(0.5)
		"headline":
			var l: RichTextLabel = _above if str(b.get("pos", "above")) == "above" else _below
			var col: Color = b.get("colour", Color.WHITE)
			l.text = "[center][color=#%s]%s[/color][/center]" % [col.to_html(false), str(b.text)]
			l.modulate.a = 0.0
			_tween(l, "modulate:a", 1.0, 0.4)
			_left = _secs(0.6)
		"beat":
			_left = _secs(float(b.get("secs", 0.8)))
		"mark":
			_mark()
		"wheel":
			_wheel(b)
		"panel":
			_show_panel(str(b.text))
			_left = _secs(0.4)
		"continue":
			_waiting = true
			_continue.visible = true
			_continue.grab_focus()
		"clear":
			_clear_stage()
			_left = _secs(0.3)
		_:
			_left = 0.0

func _process(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left -= delta
		var k: float = maxf(0.0, _shake_left / SHAKE_SECS)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * SHAKE_PX * k
		if _shake_left <= 0.0:
			position = Vector2.ZERO
	if index < 0 or index >= beats.size() or _waiting:
		return
	if _busy != null:
		if is_instance_valid(_busy) and bool(_busy.get("playing")):
			return
		_busy = null
	_left -= delta
	if _left <= 0.0:
		_next()

## A click lands what's moving, or ends the pause; on a Continue, goes on.
func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		click()
		accept_event()

func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed):
		return
	if ev.keycode == KEY_ESCAPE:
		finish()
		get_viewport().set_input_as_handled()
	elif ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		click()
		get_viewport().set_input_as_handled()

func click() -> void:
	if _waiting:
		_go_on()
		return
	if _busy != null and is_instance_valid(_busy) and _busy.has_method("skip_to_end"):
		_busy.skip_to_end()
		_busy = null
		return
	for t in _tweens:
		if t.is_valid() and t.is_running():
			t.custom_step(60.0)
	_tweens.clear()
	_left = 0.0

func _go_on() -> void:
	_waiting = false
	_continue.visible = false
	_next()

## Ends the sequence now, however far it got.
func finish() -> void:
	if is_queued_for_deletion():
		return
	set_process(false)
	position = Vector2.ZERO
	done.emit()
	queue_free()

# ------------------------------------------------------------------ the pieces

func _secs(s: float) -> float:
	return s * (0.5 if reduced_motion else 1.0)

func _tween(obj: Object, prop: String, to, secs: float) -> void:
	var t = create_tween()
	t.tween_property(obj, prop, to, _secs(secs))
	_tweens.append(t)

func _clear_stage() -> void:
	for ch in _stage.get_children():
		_stage.remove_child(ch)
		ch.queue_free()
	_centre = null
	_above.text = ""
	_below.text = ""

func _show_portrait(id: String) -> void:
	_clear_stage_keep_text()
	var p = TextureRect.new()
	p.name = "Portrait"
	p.texture = UITheme.tex("art/portraits/" + id, 0.5)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.anchor_left = 0.35
	p.anchor_right = 0.65
	p.anchor_top = 0.18
	p.anchor_bottom = 0.82
	p.modulate.a = 0.0
	_stage.add_child(p)
	_centre = p
	_tween(p, "modulate:a", 1.0, 0.4)

func _clear_stage_keep_text() -> void:
	for ch in _stage.get_children():
		_stage.remove_child(ch)
		ch.queue_free()
	_centre = null

func _show_panel(text: String) -> void:
	_clear_stage_keep_text()
	var panel = PanelContainer.new()
	panel.name = "NightResult"
	panel.add_theme_stylebox_override("panel", UITheme.flat(UITheme.color("panel"), UITheme.color("border"), 2, 8, 18))
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.35
	panel.anchor_bottom = 0.65
	var l = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", UITheme.color("text"))
	panel.add_child(l)
	_stage.add_child(panel)

## Greys the condemned's portrait and smashes a blue X down (Limner's ExecutionMark).
func _mark() -> void:
	if _centre == null:
		_left = 0.0
		return
	if ResourceLoader.exists("res://ui/fx/execution_mark.gd"):
		var m = load("res://ui/fx/execution_mark.gd").play(_centre, reduced_motion)
		_busy = m
		if not reduced_motion:
			_shake(0.5)
		return
	# Fallback: grey it and draw the X.
	_centre.modulate = Color(0.5, 0.5, 0.5)
	var x = _CrossX.new()
	x.colour = BLUE_X
	x.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_centre.add_child(x)
	_left = _secs(0.6)

const BLUE_X = Color("5d8fe0")
const RED_X = Color("d0322e")

## One spin of Limner's KillWheel, then the screen shakes on the strike.
func _wheel(b: Dictionary) -> void:
	_clear_stage_keep_text()
	var people: Array = b.get("people", []).duplicate(true)
	for p in people:
		p["portrait"] = UITheme.tex("art/portraits/" + str(p.id), 0.5)
	var holder = Control.new()
	holder.name = "WheelHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.anchor_left = 0.5
	holder.anchor_right = 0.5
	holder.anchor_top = 0.5
	holder.anchor_bottom = 0.5
	var side: float = get_viewport_rect().size.y * 0.66 if get_viewport_rect().size.y > 0 else 600.0
	holder.offset_left = -side / 2.0
	holder.offset_right = side / 2.0
	holder.offset_top = -side / 2.0
	holder.offset_bottom = side / 2.0
	_stage.add_child(holder)
	_centre = holder
	if ResourceLoader.exists("res://ui/fx/kill_wheel.gd"):
		var wheel = load("res://ui/fx/kill_wheel.gd").new()
		wheel.name = "KillWheel"
		wheel.reduced_motion = reduced_motion
		wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(wheel)
		if bool(b.get("kill", true)) and not reduced_motion:
			wheel.struck.connect(func(): _shake(1.0))
		var step: Dictionary = {"people": people, "victim": str(b.get("victim", "")), "kill": bool(b.get("kill", true))}
		if not is_nan(_last_angle):
			step["start_angle"] = _last_angle   # a second kill spins on from where the first stopped
		wheel.play(step)
		wheel.finished.connect(func():
			if wheel.has_method("end_angle"):
				_last_angle = wheel.end_angle())
		_busy = wheel
		return
	# Fallback: the victim's portrait, marked red for a kill.
	var p = TextureRect.new()
	p.texture = UITheme.tex("art/portraits/" + str(b.get("victim", "")), 0.5)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(p)
	if bool(b.get("kill", true)):
		var x = _CrossX.new()
		x.colour = RED_X
		x.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.add_child(x)
	_left = _secs(1.0)

func _shake(strength: float) -> void:
	if reduced_motion:
		return
	_shake_left = SHAKE_SECS * strength

## A plain X for the fallback, when Limner's components aren't there.
class _CrossX extends Control:
	var colour: Color = Color.WHITE
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var s: Vector2 = size
		var m: float = minf(s.x, s.y) * 0.2
		var wdt: float = maxf(4.0, minf(s.x, s.y) * 0.08)
		draw_line(Vector2(m, m), s - Vector2(m, m), colour, wdt, true)
		draw_line(Vector2(s.x - m, m), Vector2(m, s.y - m), colour, wdt, true)
