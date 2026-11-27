## Manages the town map's phase-of-day lighting overlay and curved wave transitions
## (ui/map_lighting.gdshader). Attached inside MapView between the world layer and the
## crisp UI overlay so buildings, terrain and standees shift from dawn gold to daylight,
## cool evening twilight and moonlit night while plaques, labels and tooltips stay sharp.
extends RefCounted

const C = preload("res://sim/content.gd")
const SHADER_PATH := "res://ui/map_lighting.gdshader"

# Transition durations (seconds) by target phase transition.
const DAWN_DURATION := 5.55   # Night -> Morning (violet -> rose -> gold wave)
const DUSK_DURATION := 4.95   # Afternoon -> Evening (sunset edge -> cool blue wave)
const STEP_DURATION := 3.60   # Morning -> Afternoon, Evening -> Night, or fallback

var _owner: Control
var _back_buffer: BackBufferCopy
var _overlay: ColorRect
var _material: ShaderMaterial
var _tween: Tween

var current_phase: int = -1
var from_phase: int = C.MORNING
var to_phase: int = C.MORNING
var progress: float = 1.0
var pending_phase: int = -1
var deferred: bool = false
## Called whenever the grade changes (the map redraws its standees' tint with it).
var on_change: Callable = Callable()

## The townspeople standees are drawn above the grade with a milder tint of their own, so
## faces stay readable at night (Michael, Nov 27). Morning, afternoon, evening, night.
const STANDEE_TINTS = [Color(1.0, 0.97, 0.9), Color(1, 1, 1), Color(0.88, 0.91, 1.0), Color(0.74, 0.8, 0.96)]


func attach(owner: Control) -> void:
	_owner = owner
	_back_buffer = BackBufferCopy.new()
	_back_buffer.name = "MapLightingBackBuffer"
	# COPY_MODE_VIEWPORT avoids any rect-clipping seam at the bottom/right under DPI scaling;
	# MapLightingOverlay is clipped to MapView by clip_contents = true.
	_back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	owner.add_child(_back_buffer)

	_overlay = ColorRect.new()
	_overlay.name = "MapLightingOverlay"
	_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_overlay.position = Vector2.ZERO
	_overlay.size = owner.size
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color.WHITE

	var shader: Shader = load(SHADER_PATH)
	if shader != null:
		_material = ShaderMaterial.new()
		_material.shader = shader
		_overlay.material = _material
	owner.add_child(_overlay)
	_sync_shader()


func update_bounds(control_size: Vector2, map_rect: Rect2) -> void:
	if _overlay != null:
		_overlay.position = Vector2.ZERO
		_overlay.size = control_size
	if _material != null:
		_material.set_shader_parameter("control_size", control_size)
		_material.set_shader_parameter("map_rect", Vector4(map_rect.position.x, map_rect.position.y, map_rect.size.x, map_rect.size.y))


func set_hold(hold: bool, animate: bool = true) -> void:
	deferred = hold
	if not deferred and pending_phase >= 0:
		var target: int = pending_phase
		pending_phase = -1
		set_phase(target, animate)


func set_phase(phase: int, animate: bool = true) -> void:
	var target: int = clampi(phase, C.MORNING, C.NIGHT)
	if not animate or _owner == null or not _owner.is_inside_tree():
		current_phase = target
		pending_phase = -1
		if _tween != null and _tween.is_valid():
			_tween.kill()
			_tween = null
		from_phase = target
		to_phase = target
		progress = 1.0
		_sync_shader()
		return
	if current_phase == target:
		pending_phase = -1
		return
	if deferred and current_phase >= 0:
		pending_phase = target
		return
	var previous: int = current_phase
	current_phase = target
	pending_phase = -1
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_tween = null
	if previous < 0:
		from_phase = target
		to_phase = target
		progress = 1.0
		_sync_shader()
		return
	from_phase = previous
	to_phase = target
	progress = 0.0
	_sync_shader()
	var dur: float = transition_duration(previous, target)
	_tween = _owner.create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_progress, 0.0, 1.0, dur)
	_tween.finished.connect(func():
		from_phase = target
		progress = 1.0
		_sync_shader()
	)


static func transition_duration(from_p: int, to_p: int) -> float:
	if from_p == C.NIGHT and to_p == C.MORNING:
		return DAWN_DURATION
	if from_p == C.AFTERNOON and to_p == C.EVENING:
		return DUSK_DURATION
	return STEP_DURATION


static func phase_for_game(g) -> int:
	if g == null or g.w == null:
		return C.MORNING
	if g.state == "night":
		return C.NIGHT
	return clampi(int(g.w.phase), C.MORNING, C.NIGHT)


func _set_progress(v: float) -> void:
	progress = v
	if _material != null:
		_material.set_shader_parameter("progress", v)
	_update_idle()
	if on_change.is_valid():
		on_change.call()


## The standees' tint now: the phase's, eased across a transition as the grade is.
func standee_tint() -> Color:
	var a: Color = STANDEE_TINTS[clampi(from_phase, 0, 3)]
	var b: Color = STANDEE_TINTS[clampi(to_phase, 0, 3)]
	return a.lerp(b, clampf(progress, 0.0, 1.0)) if from_phase != to_phase else b


## Afternoon's grade is the painted map as it is, so while it's settled the overlay and its
## whole-viewport copy are switched off (Michael, Nov 27: free for a quarter of the day).
func is_idle() -> bool:
	var settled: bool = from_phase == to_phase or progress >= 0.999
	return settled and to_phase == C.AFTERNOON


func _update_idle() -> void:
	var on: bool = not is_idle()
	if _overlay != null:
		_overlay.visible = on
	if _back_buffer != null:
		_back_buffer.visible = on


func _sync_shader() -> void:
	_update_idle()
	if on_change.is_valid():
		on_change.call()
	if _material == null:
		return
	_material.set_shader_parameter("from_phase", from_phase)
	_material.set_shader_parameter("to_phase", to_phase)
	_material.set_shader_parameter("progress", progress)
