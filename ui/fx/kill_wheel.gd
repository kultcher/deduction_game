## The night's kill as a wheel of fortune (Michael, Nov 22).
##   - The wheel: a red rim with spokes and a hub, and a slice for each living person, in
##     their colour, with their portrait. A small dagger sits on the right rim, pointing in.
##   - The spin: the wheel spins and slows until the victim's slice stops under the dagger.
##   - Isolating: everything else fades, and the victim's slice and the dagger glide to the
##     centre, a little larger.
##   - A kill: after a beat the dagger stabs in, the wheel shakes, the screen flashes red, and a red
##     X is left over the portrait.
##   - No kill (the fakeout): the wheel lands on someone harmless; the dagger bumps them,
##     bounces off and tumbles off screen.
##   - Reduced motion: no spin and no shake. The slice and dagger fade in at the centre,
##     then the X fades in (or the dagger fades away).
## Every frame is a pure function of one clock (`t`), so a skip, a test or a capture can
## jump to any moment. Herald places it and owns the flow around it; it shakes only its own
## stage, and `struck` is the hook for a sound or a wider shake.
## Presentation only. Cost: ~3 small Controls a person drawn with draw_* calls, one circle
## shader a portrait; nothing per frame beyond transforms and a redraw of the frame.
extends Control

const PortraitFx = preload("res://ui/portrait_fx.gd")
const CrossMark = preload("res://ui/fx/cross_mark.gd")
const UITheme = preload("res://ui/theme.gd")

## The wheel has stopped on its slice.
signal landed
## The dagger has struck (the stab, or the harmless bump).
signal struck
## The whole beat is over; the final picture holds.
signal finished

const RIM = Color(0.55, 0.08, 0.07)
const RIM_DARK = Color(0.30, 0.04, 0.04)
const GOLD = Color(0.82, 0.59, 0.24)
const INK = Color(0.05, 0.08, 0.12)
const BLOOD = Color(0.80, 0.07, 0.06)
const STEEL = Color(0.86, 0.88, 0.91)

## The wheel's radius as a share of the smaller side of the rect.
const RADIUS = 0.38
## How far the wheel sits left of centre, so the dagger's grip fits on the right.
const SHIFT = 0.07
## Where a portrait sits along its slice, as a share of the radius.
const PORTRAIT_AT = 0.6
## How much larger the isolated slice grows.
const FOCUS_SCALE = 1.5
const TURNS = 3

var reduced_motion: bool = false
var playing: bool = false
var t: float = 0.0
var kill: bool = true
var people: Array = []
var victim_index: int = 0

var stage: Control
var frame: Control
var slices: Array = []
var dagger: Control
var mark: Control
var flash: ColorRect

var _plan: Dictionary = {}
var _emitted: Dictionary = {}
var _geo: Dictionary = {}


func _init() -> void:
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = Control.new()
	stage.name = "Stage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	frame = WheelFrame.new()
	frame.name = "Frame"
	dagger = Dagger.new()
	dagger.name = "Dagger"
	mark = CrossMark.new()
	mark.name = "Mark"
	mark.color = BLOOD
	flash = ColorRect.new()
	flash.name = "Flash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(BLOOD, 0.0)
	flash.top_level = true   # the flash covers the whole screen, not just the wheel's rect


## Plays the night's beat. `step`: `people` (an array of {id, name, color, portrait}, the
## living in wheel order; portrait and color are optional), `victim` (an id) and `kill`
## (false for the no-kill fakeout, which lands on `victim` harmlessly).
func play(step: Dictionary) -> void:
	people = step.get("people", [])
	kill = bool(step.get("kill", true))
	victim_index = maxi(0, people.map(func(p): return str(p.get("id", ""))).find(str(step.get("victim", ""))))
	_build()
	_plan = _make_plan()
	_emitted = {}
	t = 0.0
	playing = true
	_apply()


func landed_at() -> float:
	return _plan.get("landed", 0.0)

func struck_at() -> float:
	return _plan.get("strike", 0.0)

func ends_at() -> float:
	return _plan.get("end", 0.0)


## Jumps to the end: the final picture, and any signals not yet sent, once each and in order.
func skip_to_end() -> void:
	if _plan.is_empty():
		return
	t = _plan.end
	_apply()
	_emit_due()
	playing = false


func advance(delta: float) -> void:
	if not playing:
		return
	t = minf(t + delta, _plan.end)
	_apply()
	_emit_due()
	if t >= _plan.end:
		playing = false


func _process(delta: float) -> void:
	advance(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _plan.is_empty():
		_layout()
		_apply()


func _emit_due() -> void:
	for k in ["landed", "strike", "end"]:
		if t >= _plan[k] and not _emitted.has(k):
			_emitted[k] = true
			match k:
				"landed": landed.emit()
				"strike": struck.emit()
				"end": finished.emit()


# --- Building ---------------------------------------------------------------------------

func _build() -> void:
	for c in stage.get_children():
		stage.remove_child(c)
		if not c in [frame, dagger, mark, flash]:
			c.queue_free()
	slices = []
	var n: int = maxi(1, people.size())
	for i in range(people.size()):
		var p: Dictionary = people[i]
		var s = Slice.new()
		s.name = "Slice_" + str(p.get("id", i))
		s.color = p.get("color", Color(0.85, 0.85, 0.85))
		s.half = PI / n
		var face = TextureRect.new()
		face.name = "Face"
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex = p.get("portrait", null)
		if tex == null:
			tex = UITheme.tex("art/portraits/" + str(p.get("id", "")), 0.25)
		face.texture = PortraitFx.square(tex)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.material = PortraitFx.material(true)
		PortraitFx.set_ring(face, true, GOLD)
		s.add_child(face)
		s.face = face
		stage.add_child(s)
		slices.append(s)
	stage.add_child(frame)
	# The victim's slice draws above the frame, so it can leave the wheel cleanly.
	if not slices.is_empty():
		stage.move_child(slices[victim_index], -1)
	stage.add_child(dagger)
	stage.add_child(mark)
	stage.add_child(flash)
	frame.count = n
	_layout()


func _layout() -> void:
	var d: float = minf(size.x, size.y)
	var r: float = d * RADIUS
	_geo = {"d": d, "r": r, "centre": size / 2.0 - Vector2(d * SHIFT, 0.0), "mid": size / 2.0}
	stage.size = size
	if is_inside_tree():
		flash.position = Vector2.ZERO
		flash.size = get_viewport_rect().size
	frame.radius = r
	frame.queue_redraw()
	var n: int = maxi(1, people.size())
	var pr: float = minf(r * PORTRAIT_AT * sin(PI / n) * 0.86, r * 0.24)
	_geo["pr"] = pr
	for s in slices:
		s.radius = r
		s.face.size = Vector2.ONE * pr * 2.0
		s.face.pivot_offset = s.face.size / 2.0
		s.face.position = Vector2(r * PORTRAIT_AT, 0.0) - s.face.size / 2.0
		s.queue_redraw()
	dagger.length = r * 0.46
	dagger.queue_redraw()
	mark.size = Vector2.ONE * pr * 2.0 * FOCUS_SCALE * 1.15
	mark.pivot_offset = mark.size / 2.0
	mark.queue_redraw()


# --- The timeline -----------------------------------------------------------------------

func _make_plan() -> Dictionary:
	if reduced_motion:
		return {"appear": [0.0, 0.4], "landed": 0.4, "strike": 1.1, "mark": [1.1, 1.4], "end": 2.0}
	var p = {"appear": [0.0, 0.3], "spin": [0.3, 2.5], "landed": 2.5, "isolate": [2.75, 3.3],
		"windup": [3.55, 3.8]}
	if kill:
		p["stab"] = [3.8, 3.92]
		p["strike"] = 3.92
		p["mark"] = [3.95, 4.25]
		p["shake"] = [3.92, 4.3]
		p["end"] = 4.9
	else:
		p["bump"] = [3.8, 4.08]
		p["strike"] = 4.08
		p["bounce"] = [4.08, 4.3]
		p["fall"] = [4.3, 5.1]
		p["end"] = 5.3
	return p


static func _u(t: float, span: Array) -> float:
	return clampf((t - span[0]) / maxf(span[1] - span[0], 0.0001), 0.0, 1.0)

static func _smooth(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## The wheel's rotation at time `tt`: several turns, slowing to a stop with the victim's
## slice (its middle) under the dagger, on the right.
func wheel_rotation(tt: float) -> float:
	var n: int = maxi(1, people.size())
	var step: float = TAU / n
	var rest: float = -victim_index * step
	if reduced_motion or not _plan.has("spin"):
		return rest
	var u: float = _u(tt, _plan.spin)
	var e: float = 1.0 - pow(1.0 - u, 4.0)
	var total: float = TAU * TURNS + step * 0.5 + 0.7
	return rest - (1.0 - e) * total


func _apply() -> void:
	if _plan.is_empty():
		return
	var r: float = _geo.r
	var c: Vector2 = _geo.centre
	var mid: Vector2 = _geo.mid
	var pr: float = _geo.pr
	var rot: float = wheel_rotation(t)
	var n: int = maxi(1, people.size())
	var step: float = TAU / n
	var appear: float = _smooth(_u(t, _plan.appear))
	var iso: float = 1.0 if reduced_motion else _smooth(_u(t, _plan.isolate))

	# The wheel and the other slices.
	frame.position = c
	frame.rotation = rot
	frame.scale = Vector2.ONE * lerpf(0.92, 1.0, appear)
	frame.modulate.a = 0.0 if reduced_motion else appear * (1.0 - iso)
	for i in range(slices.size()):
		var s = slices[i]
		if i == victim_index:
			continue
		s.position = c
		s.rotation = rot + i * step
		s.scale = frame.scale
		s.face.rotation = -s.rotation
		s.modulate.a = frame.modulate.a

	# The victim's slice: on the wheel, then gliding to the middle, upright, larger.
	var v = slices[victim_index] if not slices.is_empty() else null
	var focus_scale: float = lerpf(1.0, FOCUS_SCALE, iso)
	var on_wheel_pos: Vector2 = c
	var focus_pos: Vector2 = mid - Vector2(r * PORTRAIT_AT * FOCUS_SCALE, 0.0)
	if v != null:
		v.position = on_wheel_pos.lerp(focus_pos, iso)
		v.rotation = (rot + victim_index * step) * (1.0 - iso)
		v.scale = Vector2.ONE * focus_scale * (frame.scale.x if iso < 1.0 else 1.0)
		v.face.rotation = -v.rotation
		v.modulate.a = appear
	# Where the portrait's centre is, on screen, and its radius there.
	var face_c: Vector2 = (v.position + Vector2(r * PORTRAIT_AT, 0.0).rotated(v.rotation) * v.scale.x) if v != null else mid
	var face_r: float = pr * (v.scale.x if v != null else 1.0)

	# The dagger: resting on the rim, pointing in, then following the slice.
	var rest_tip: Vector2 = v.position + Vector2(r * 0.93, 0.0) * v.scale.x if v != null else c + Vector2(r * 0.93, 0)
	if reduced_motion:
		rest_tip = face_c + Vector2(face_r * 1.25, 0.0)
	var tip: Vector2 = rest_tip
	var d_rot: float = 0.0
	var d_alpha: float = appear
	var d_scale: float = v.scale.x if v != null else 1.0
	if not reduced_motion:
		var wind: float = _smooth(_u(t, _plan.windup))
		tip += Vector2(r * 0.08 * wind, 0.0)
		if kill:
			var stab: float = _u(t, _plan.stab)
			var into: Vector2 = face_c + Vector2(face_r * 0.15, 0.0)
			tip = tip.lerp(into, stab * stab)
		else:
			var bump: float = _smooth(_u(t, _plan.bump))
			var touch: Vector2 = face_c + Vector2(face_r * 1.02, 0.0)
			tip = tip.lerp(touch, bump)
			var b: float = _u(t, _plan.bounce)
			if b > 0.0:
				var back: Vector2 = touch + Vector2(r * 0.42 * _smooth(b), -r * 0.32 * sin(PI * 0.5 * b))
				tip = back
				d_rot = -0.9 * b
			var f: float = t - _plan.fall[0]
			if f > 0.0:
				var start: Vector2 = touch + Vector2(r * 0.42, -r * 0.32)
				var vel: Vector2 = Vector2(r * 0.55, -r * 0.5)
				var grav: float = r * 5.0
				tip = start + vel * f + Vector2(0.0, 0.5 * grav * f * f)
				d_rot = -0.9 - 7.0 * f
	else:
		if not kill:
			d_alpha *= 1.0 - _smooth(_u(t, [_plan.strike, _plan.strike + 0.4]))
	dagger.position = tip
	dagger.rotation = d_rot
	dagger.scale = Vector2.ONE * d_scale
	dagger.modulate.a = d_alpha
	dagger.visible = d_alpha > 0.001

	# The portrait's own jolt when the dagger bumps it.
	if v != null and not reduced_motion and not kill:
		var jolt: float = _u(t, [_plan.strike, _plan.strike + 0.2])
		if jolt > 0.0 and jolt < 1.0:
			v.position += Vector2(-r * 0.05 * sin(PI * jolt), 0.0)

	# The X, the flash and the shake.
	if kill:
		var m: float = _u(t, _plan.mark)
		mark.visible = m > 0.0
		mark.position = face_c - mark.size / 2.0
		if reduced_motion:
			mark.set_progress(1.0, 1.0)
			mark.modulate.a = _smooth(m)
		else:
			mark.set_progress(clampf(m * 2.0, 0.0, 1.0), clampf(m * 2.0 - 1.0, 0.0, 1.0))
			mark.modulate.a = 1.0
		var fl: float = _u(t, [_plan.strike, _plan.strike + (0.3 if reduced_motion else 0.35)])
		flash.color.a = (0.18 if reduced_motion else 0.45) * (1.0 - fl) if t >= _plan.strike else 0.0
		if v != null:
			PortraitFx.set_grey_amount(v.face, 0.6 * _u(t, _plan.mark))
	else:
		mark.visible = false
		flash.color.a = 0.0
	var shake: Vector2 = Vector2.ZERO
	if kill and not reduced_motion:
		var sh: float = _u(t, _plan.shake)
		if sh > 0.0 and sh < 1.0:
			var amp: float = _geo.d * 0.022 * (1.0 - sh)
			shake = Vector2(sin(t * 97.0), cos(t * 83.0)) * amp
	stage.position = shake


## The current isolated portrait's centre on screen (for Herald's captions).
func focus_centre() -> Vector2:
	if slices.is_empty():
		return size / 2.0
	var v = slices[victim_index]
	return stage.position + v.position + Vector2(_geo.r * PORTRAIT_AT, 0.0).rotated(v.rotation) * v.scale.x


# --- The pieces -------------------------------------------------------------------------

## One person's slice: a wedge in their colour (drawn about the wheel's centre, pointing
## right), with their portrait part-way out.
class Slice extends Control:
	var color: Color = Color.WHITE
	var half: float = 0.3
	var radius: float = 100.0
	var face: TextureRect

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r_in: float = radius * 0.9
		var r_hub: float = radius * 0.17
		var pts = PackedVector2Array()
		var steps: int = 18
		for k in range(steps + 1):
			var a: float = -half + 2.0 * half * k / steps
			pts.append(Vector2(cos(a), sin(a)) * r_in)
		for k in range(steps, -1, -1):
			var a: float = -half + 2.0 * half * k / steps
			pts.append(Vector2(cos(a), sin(a)) * r_hub)
		var fill: Color = color.lerp(Color(0.55, 0.08, 0.07), 0.18)
		draw_colored_polygon(pts, fill)
		# A soft darker band at the outer edge, so each slice has some depth.
		var band = PackedVector2Array()
		for k in range(steps + 1):
			var a: float = -half + 2.0 * half * k / steps
			band.append(Vector2(cos(a), sin(a)) * r_in)
		for k in range(steps, -1, -1):
			var a: float = -half + 2.0 * half * k / steps
			band.append(Vector2(cos(a), sin(a)) * r_in * 0.9)
		draw_colored_polygon(band, Color(fill.darkened(0.25), 0.9))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.05, 0.08, 0.12, 0.85), 2.0, true)


## The wheel's rim, spokes and hub, drawn about its centre.
class WheelFrame extends Control:
	var radius: float = 100.0
	var count: int = 10

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: float = radius
		var rim_w: float = r * 0.1
		var gold := Color(0.82, 0.59, 0.24)
		var rim := Color(0.55, 0.08, 0.07)
		var ink := Color(0.05, 0.08, 0.12)
		# A shadow, offset down and right whatever the wheel's turn.
		var off: Vector2 = Vector2(r * 0.025, r * 0.04).rotated(-rotation)
		draw_arc(off, r - rim_w / 2.0, 0.0, TAU, 96, Color(0, 0, 0, 0.35), rim_w * 1.3, true)
		draw_arc(Vector2.ZERO, r - rim_w / 2.0, 0.0, TAU, 96, rim, rim_w, true)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, gold, maxf(2.0, r * 0.012), true)
		draw_arc(Vector2.ZERO, r - rim_w, 0.0, TAU, 96, gold, maxf(2.0, r * 0.012), true)
		var step: float = TAU / maxi(1, count)
		for k in range(count):
			var a: float = step * (k + 0.5)
			var dir := Vector2(cos(a), sin(a))
			draw_line(dir * r * 0.17, dir * (r - rim_w), ink, maxf(3.0, r * 0.022), true)
			draw_line(dir * r * 0.17, dir * (r - rim_w), gold, maxf(1.5, r * 0.009), true)
			draw_circle(dir * (r - rim_w / 2.0), r * 0.022, gold)
			draw_circle(dir * (r - rim_w / 2.0), r * 0.011, rim.darkened(0.4))
		# The hub.
		draw_circle(Vector2.ZERO, r * 0.17, ink)
		draw_circle(Vector2.ZERO, r * 0.15, rim)
		draw_arc(Vector2.ZERO, r * 0.15, 0.0, TAU, 48, gold, maxf(2.0, r * 0.014), true)
		draw_circle(Vector2.ZERO, r * 0.06, gold)
		draw_circle(Vector2.ZERO, r * 0.03, rim.darkened(0.3))


## A small dagger, its tip at the origin, pointing left (into the wheel).
class Dagger extends Control:
	var length: float = 60.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var L: float = length
		var w: float = L * 0.09
		var steel := Color(0.86, 0.88, 0.91)
		var gold := Color(0.82, 0.59, 0.24)
		var ink := Color(0.05, 0.08, 0.12)
		var shadow := Vector2(L * 0.03, L * 0.05)
		var blade = PackedVector2Array([Vector2(0, 0), Vector2(L * 0.56, -w), Vector2(L * 0.56, w)])
		var shade = PackedVector2Array()
		for p in blade:
			shade.append(p + shadow)
		draw_colored_polygon(shade, Color(0, 0, 0, 0.3))
		draw_colored_polygon(blade, steel)
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(L * 0.56, 0), Vector2(L * 0.56, w)]), steel.darkened(0.22))
		var outline = blade.duplicate()
		outline.append(blade[0])
		draw_polyline(outline, ink, maxf(1.5, L * 0.02), true)
		# The guard, the grip and the pommel.
		draw_rect(Rect2(L * 0.56, -L * 0.17, L * 0.06, L * 0.34), gold)
		draw_rect(Rect2(L * 0.56, -L * 0.17, L * 0.06, L * 0.34), ink, false, maxf(1.0, L * 0.015))
		draw_rect(Rect2(L * 0.62, -w * 0.75, L * 0.27, w * 1.5), Color(0.36, 0.13, 0.08))
		for k in range(4):
			var x: float = L * (0.65 + 0.06 * k)
			draw_line(Vector2(x, -w * 0.75), Vector2(x + L * 0.03, w * 0.75), Color(0.2, 0.07, 0.05), maxf(1.0, L * 0.012))
		draw_circle(Vector2(L * 0.93, 0), L * 0.065, gold)
		draw_arc(Vector2(L * 0.93, 0), L * 0.065, 0.0, TAU, 24, ink, maxf(1.0, L * 0.015), true)
