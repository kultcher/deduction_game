## The execution mark (Michael, Nov 22): the condemned person's portrait greys out, then a
## blue X smashes down over it with a little shake.
##   ExecutionMark.play(portrait)  # any Control showing the portrait; returns the mark
## The mark is a child laid over the portrait, and it stays once it has landed. The portrait
## greys through PortraitFx's shader when it has that material (or none, in which case it
## gets one); otherwise its modulate is dimmed instead. The shake is a small rotation and
## scale jolt of the portrait, so it never fights a container's layout.
## Reduced motion: the portrait greys and the X fades in, with no smash or shake.
## Every frame is a pure function of `t`, as in KillWheel.
## Presentation only. Cost: one Control drawn with draw_* calls.
extends Control

const PortraitFx = preload("res://ui/portrait_fx.gd")
const CrossMark = preload("res://ui/fx/cross_mark.gd")

signal landed
signal finished

const BLUE = Color(0.18, 0.36, 0.78)
## The X's size as a share of the portrait's smaller side.
const SIZE = 0.9

var reduced_motion: bool = false
var playing: bool = false
var t: float = 0.0
var target: Control
var cross: Control
var _plan: Dictionary = {}
var _emitted: Dictionary = {}
var _uses_shader: bool = false
var _base_modulate: Color = Color(1, 1, 1)
var _base_scale: Vector2 = Vector2.ONE
var _base_rotation: float = 0.0
var _jolting: bool = false


## Marks `portrait`: adds the mark over it and starts. Replaces any mark already there.
static func play(portrait: Control, reduced: bool = false) -> Control:
	var old = portrait.get_node_or_null("ExecutionMark")
	if old != null:
		old.restore_transform()   # mid-jolt, the portrait gets its own scale and turn back first (Codex)
		portrait.remove_child(old)
		old.queue_free()
	var m = load("res://ui/fx/execution_mark.gd").new()
	m.name = "ExecutionMark"
	m.reduced_motion = reduced
	portrait.add_child(m)
	m.start(portrait)
	return m


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross = CrossMark.new()
	cross.name = "Cross"
	cross.color = BLUE
	cross.width_frac = 0.16
	add_child(cross)


func start(portrait: Control) -> void:
	target = portrait
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if target.material == null:
		target.material = PortraitFx.material(false)
	_uses_shader = target.material is ShaderMaterial and target.material.shader != null and "grey" in target.material.shader.code
	_base_modulate = target.modulate
	_base_scale = target.scale
	_base_rotation = target.rotation
	_plan = {"grey": [0.0, 0.3], "landed": 0.3, "fade": [0.3, 0.6], "end": 0.8} if reduced_motion else \
		{"grey": [0.0, 0.35], "smash": [0.35, 0.47], "landed": 0.47, "shake": [0.47, 0.8], "end": 0.95}
	_emitted = {}
	t = 0.0
	playing = true
	_apply()


## Puts back the portrait's own scale and rotation if the jolt has them changed.
func restore_transform() -> void:
	if _jolting and target != null:
		target.rotation = _base_rotation
		target.scale = _base_scale
		_jolting = false


func ends_at() -> float:
	return _plan.get("end", 0.0)

func landed_at() -> float:
	return _plan.get("landed", 0.0)


func skip_to_end() -> void:
	if _plan.is_empty():
		return
	t = _plan.end
	_apply()
	# Stopped before the signals go out: a `finished` handler may start the next one (Codex).
	playing = false
	_emit_due()


func advance(delta: float) -> void:
	if not playing:
		return
	t = minf(t + delta, _plan.end)
	_apply()
	if t >= _plan.end:
		playing = false
	_emit_due()


func _process(delta: float) -> void:
	advance(delta)


func _emit_due() -> void:
	var plan: Dictionary = _plan
	for k in ["landed", "end"]:
		if t >= _plan[k] and not _emitted.has(k):
			_emitted[k] = true
			if k == "landed":
				landed.emit()
			else:
				finished.emit()
			if not is_same(plan, _plan):
				return   # a handler started the next one; its signals are its own


static func _u(tt: float, span: Array) -> float:
	return clampf((tt - span[0]) / maxf(span[1] - span[0], 0.0001), 0.0, 1.0)


func _apply() -> void:
	if target == null or _plan.is_empty():
		return
	var g: float = _u(t, _plan.grey)
	g = g * g * (3.0 - 2.0 * g)
	if _uses_shader:
		PortraitFx.set_grey_amount(target, g)
	else:
		target.modulate = _base_modulate.lerp(Color(0.55, 0.55, 0.58, _base_modulate.a), g)
	var side: float = minf(target.size.x, target.size.y) * SIZE
	cross.size = Vector2.ONE * side
	cross.pivot_offset = cross.size / 2.0
	cross.position = target.size / 2.0 - cross.size / 2.0
	if reduced_motion:
		var f: float = _u(t, _plan.fade)
		cross.visible = f > 0.0
		cross.modulate.a = f
		cross.scale = Vector2.ONE
		return
	# The smash: the X drops in from large and faint to its size, hard, then the jolt.
	var s: float = _u(t, _plan.smash)
	cross.visible = s > 0.0
	cross.modulate.a = clampf(s * 2.5, 0.0, 1.0)
	cross.scale = Vector2.ONE * lerpf(2.2, 1.0, s * s)
	var sh: float = _u(t, _plan.shake)
	target.pivot_offset = target.size / 2.0
	if sh > 0.0 and sh < 1.0:
		var k: float = 1.0 - sh
		target.rotation = _base_rotation + deg_to_rad(3.0) * sin(sh * 38.0) * k
		target.scale = _base_scale * (1.0 + 0.06 * k * k)
		_jolting = true
	elif _jolting:
		# Only ever put back what the jolt changed, so a hover lift or the like survives.
		target.rotation = _base_rotation
		target.scale = _base_scale
		_jolting = false
