## A circular face crop for the townsfolk list. Framing is independent of the full
## portrait used by profiles; the original art is preserved.
extends Control

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
## Normalized face center (x, y), then square crop width in source-image widths.
const FACE_FRAMES = {
	"hollis": Vector3(0.46, 0.35, 1.12),
	"odette": Vector3(0.52, 0.43, 1.15),
	"constance": Vector3(0.5, 0.35, 1.12),
}

var _id = ""
var _alive = true
var photo: TextureRect
var ring: TextureRect

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo = TextureRect.new()
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_SCALE
	var shader = Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 crop = vec4(0.0, 0.0, 1.0, 1.0);
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec2 source_uv = crop.xy + UV * crop.zw;
	vec4 face = texture(TEXTURE, source_uv);
	float circle = 1.0 - smoothstep(0.48, 0.5, length(UV - vec2(0.5)));
	if (source_uv.x < 0.0 || source_uv.y < 0.0 || source_uv.x > 1.0 || source_uv.y > 1.0) {
		face.a = 0.0;
	}
	float luma = dot(face.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(face.rgb, vec3(luma), desaturate);
	COLOR = tint * vec4(rgb, face.a * circle);
}"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	photo.material = mat
	add_child(photo)
	ring = TextureRect.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_SCALE
	ring.texture = UITheme.tex("ui/ring_gold", 0.3)
	add_child(ring)
	resized.connect(_layout)

func show_person(id: String, alive: bool) -> void:
	if id == _id and alive == _alive:
		return
	_id = id
	_alive = alive
	photo.texture = UITheme.tex("art/portraits/" + id, 0.5)
	if photo.texture != null:
		var dimensions = photo.texture.get_size()
		var frame: Vector3 = FACE_FRAMES.get(id, Vector3(0.5, dimensions.x * 0.58 / dimensions.y, 1.08))
		var span = Vector2(dimensions.x, dimensions.x) * frame.z / dimensions
		var origin = Vector2(frame.x, frame.y) - span / 2
		photo.material.set_shader_parameter("crop", Vector4(origin.x, origin.y, span.x, span.y))
	photo.modulate = Color.WHITE if alive else Color(0.5, 0.48, 0.48)
	queue_redraw()

func _layout() -> void:
	photo.position = Vector2(3, 3)
	photo.size = (size - Vector2(6, 6)).max(Vector2.ZERO)
	ring.position = Vector2.ZERO
	ring.size = size
	queue_redraw()

var _grayscale: float = 0.0

func set_grayscale(amount: float) -> void:
	var clamped: float = clampf(amount, 0.0, 1.0)
	if is_equal_approx(_grayscale, clamped):
		return
	_grayscale = clamped
	if photo != null and photo.material is ShaderMaterial:
		photo.material.set_shader_parameter("desaturate", _grayscale)
	queue_redraw()

func get_grayscale() -> float:
	return _grayscale

func _draw() -> void:
	var base_col: Color = C.npc_color(_id).darkened(0.35)
	if _grayscale > 0.0:
		var g_lum: float = base_col.r * 0.299 + base_col.g * 0.587 + base_col.b * 0.114
		base_col = base_col.lerp(Color(g_lum, g_lum, g_lum, base_col.a), _grayscale)
	draw_circle(size / 2, minf(size.x, size.y) / 2, base_col)
	if ring.texture == null:
		draw_arc(size / 2, minf(size.x, size.y) / 2 - 1, 0, TAU, 48, UITheme.color("border"), 2)
