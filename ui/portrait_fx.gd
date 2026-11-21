## Small portrait treatments shared by pickers and the reveal (Limner, Nov 21):
##   - `material(circle)`: a portrait material that can crop to a circle, grey the portrait out
##     (the dead) and draw a ring round a circle; `set_grey` and `set_ring` drive it;
##   - `hover_lift(control)`: the control rises a little under the mouse, in front of its row;
##   - `glow(button, color)`: a soft coloured glow round a button (the one already chosen).
## Presentation only. Cost: one small shader, 1 texture read a pixel, on portrait rects only.
extends RefCounted

const LIFT = 1.07
const LIFT_SECONDS = 0.08

static var _shader: Shader

static func material(circle: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """shader_type canvas_item;
uniform bool circle = false;
uniform float grey = 0.0;
uniform vec4 ring_color : source_color = vec4(0.62, 0.2, 0.17, 1.0);
uniform float ring = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(l) * 0.85, grey);
	if (circle) {
		float d = distance(UV, vec2(0.5));
		c.a *= 1.0 - smoothstep(0.48, 0.5, d);
		float band = smoothstep(0.43, 0.445, d) * (1.0 - smoothstep(0.485, 0.5, d)) * ring;
		c = mix(c, vec4(ring_color.rgb, 1.0), band);
	}
	COLOR = c;
}"""
	var m = ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("circle", circle)
	return m

static func set_grey(item: CanvasItem, grey: bool) -> void:
	if item.material is ShaderMaterial:
		item.material.set_shader_parameter("grey", 1.0 if grey else 0.0)

static func set_ring(item: CanvasItem, on: bool, color: Color = Color(0.62, 0.2, 0.17)) -> void:
	if item.material is ShaderMaterial:
		item.material.set_shader_parameter("ring", 1.0 if on else 0.0)
		item.material.set_shader_parameter("ring_color", color)

## Lifts the control under the mouse: it scales up from its centre and draws over its row.
## Disabled buttons stay put.
static func hover_lift(c: Control) -> void:
	var tw = [null]
	var to = func(s: float, z: int):
		if tw[0] != null and tw[0].is_valid():
			tw[0].kill()
		c.pivot_offset = c.size / 2.0
		c.z_index = z
		if c.is_inside_tree():
			tw[0] = c.create_tween()
			tw[0].tween_property(c, "scale", Vector2.ONE * s, LIFT_SECONDS)
		else:
			c.scale = Vector2.ONE * s
	c.mouse_entered.connect(func():
		if c is BaseButton and c.disabled:
			return
		to.call(LIFT, 1))
	c.mouse_exited.connect(func(): to.call(1.0, 0))

## A soft glow round a button, for the one already chosen. Drawn as its own layer behind the
## button, so the button keeps its own frame and text.
static func glow(b: Control, color: Color) -> void:
	var halo = Panel.new()
	halo.name = "Glow"
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.show_behind_parent = true
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		halo.set_offset(side, -3)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		halo.set_offset(side, 3)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.0)
	sb.draw_center = false
	sb.border_color = color
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(color, 0.6)
	sb.shadow_size = 12
	halo.add_theme_stylebox_override("panel", sb)
	b.add_child(halo)
	b.set_meta("glow", true)
