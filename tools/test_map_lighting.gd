## Phase-of-day town map lighting and sweeping wave transitions (ui/map_lighting.gd,
## ui/map_lighting.gdshader, ui/map_view.gd).
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const MapView = preload("res://ui/map_view.gd")
const MapLighting = preload("res://ui/map_lighting.gd")

var _checks := 0
var _fails := 0

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: " + msg)

func _init() -> void:
	# 1. Shader resource loads and compiles cleanly.
	var shader: Shader = load(MapLighting.SHADER_PATH)
	_check(shader != null, "map_lighting.gdshader loads cleanly")
	_check(shader != null and not shader.code.is_empty(), "map_lighting.gdshader has shader code")

	# 2. Transition durations match dawn / dusk / step hierarchy.
	_check(MapLighting.transition_duration(C.NIGHT, C.MORNING) > MapLighting.transition_duration(C.MORNING, C.AFTERNOON),
		"dawn wave lasts longer than morning->afternoon")
	_check(MapLighting.transition_duration(C.AFTERNOON, C.EVENING) > MapLighting.transition_duration(C.MORNING, C.AFTERNOON),
		"dusk wave lasts longer than morning->afternoon")

	# 3. MapView attaches BackBufferCopy -> LightingOverlay -> UIOverlay in order.
	var host := Control.new()
	host.size = Vector2(1000, 700)
	root.add_child(host)
	var mv := MapView.new()
	mv.size = Vector2(1000, 700)
	host.add_child(mv)
	await process_frame

	_check(mv.get_child_count() == 3, "MapView has 3 overlay children (backbuffer, lighting, ui)")
	_check(mv.get_child(0) is BackBufferCopy, "child 0 is BackBufferCopy")
	_check(mv.get_child(1) is ColorRect and mv.get_child(1).material is ShaderMaterial,
		"child 1 is ColorRect with ShaderMaterial")
	_check(mv.get_child(2) is Control and mv.get_child(2).name == "MapUIOverlay",
		"child 2 is MapUIOverlay above the lighting pass")
	_check(mv.get_child(1).mouse_filter == Control.MOUSE_FILTER_IGNORE and mv.get_child(2).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"lighting and UI overlays ignore mouse input so MapView hits still work")

	# 4. Game phase mapping & initial snap (no animation on set_game).
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(42, 7)
	mv.set_game(g)
	_check(mv._lighting.current_phase == C.MORNING and is_equal_approx(mv._lighting.progress, 1.0),
		"set_game snaps directly to morning lighting without animating")

	# 5. Advancing phase starts an animated sweep when reduced_motion is false.
	g.w.phase = C.AFTERNOON
	mv.reduced_motion = false
	mv.refresh()
	_check(mv._lighting.from_phase == C.MORNING and mv._lighting.to_phase == C.AFTERNOON and mv._lighting.progress < 1.0,
		"morning -> afternoon starts sweeping transition (from=%d to=%d progress=%.2f)" % [mv._lighting.from_phase, mv._lighting.to_phase, mv._lighting.progress])

	# 6. Night state maps to C.NIGHT even if w.phase is still evening.
	g.state = "night"
	mv.refresh()
	_check(mv._lighting.to_phase == C.NIGHT, "night game state maps to C.NIGHT lighting")

	# 7. Deferred transitions hold behind cutscenes/meetings until revealed.
	mv.reduced_motion = false
	mv.set_lighting_deferred(true)
	g.state = "day"
	g.w.phase = C.MORNING
	mv.refresh()
	_check(mv._lighting.current_phase == C.NIGHT and mv._lighting.pending_phase == C.MORNING,
		"deferred transition holds night lighting while cutscene is open (cur=%d pending=%d)" % [mv._lighting.current_phase, mv._lighting.pending_phase])
	mv.set_lighting_deferred(false)
	_check(mv._lighting.from_phase == C.NIGHT and mv._lighting.to_phase == C.MORNING and mv._lighting.progress < 1.0,
		"releasing defer starts dawn transition from night to morning")

	# 8. Enabling reduced_motion mid-transition immediately cancels active lighting and zoom tweens.
	mv.zoom_to("square", true)
	_check(mv._zoom_tween != null and mv._zoom_tween.is_valid(),
		"zoom_to starts an animated zoom tween when reduced_motion is false")
	mv.reduced_motion = true
	_check(mv._lighting.from_phase == C.MORNING and mv._lighting.to_phase == C.MORNING and is_equal_approx(mv._lighting.progress, 1.0) and mv._lighting._tween == null,
		"setting reduced_motion=true mid-wave cancels lighting tween and snaps immediately")
	_check(mv._zoom_tween == null and mv._current_view.is_equal_approx(mv._view_rect()),
		"setting reduced_motion=true mid-zoom cancels zoom tween and snaps immediately")
	mv.zoom_to("", false)

	# 9. Non-animated refresh to the SAME target phase cancels an active wave and snaps.
	mv.reduced_motion = false
	g.w.phase = C.AFTERNOON
	mv.refresh()
	_check(mv._lighting.from_phase == C.MORNING and mv._lighting.to_phase == C.AFTERNOON and mv._lighting.progress < 1.0,
		"re-entering animated transition before set_game reset")
	mv.set_game(g)
	_check(mv._lighting.from_phase == C.AFTERNOON and mv._lighting.to_phase == C.AFTERNOON and is_equal_approx(mv._lighting.progress, 1.0) and mv._lighting._tween == null,
		"set_game during active transition to same phase cancels tween and snaps")

	# 10. reduced_motion snaps immediately to a new phase without tweening.
	mv.reduced_motion = true
	g.state = "day"
	g.w.phase = C.EVENING
	mv.refresh()
	_check(mv._lighting.from_phase == C.EVENING and mv._lighting.to_phase == C.EVENING and is_equal_approx(mv._lighting.progress, 1.0),
		"reduced_motion snaps directly to target phase")

	host.free()
	print("Map lighting: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
