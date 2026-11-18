@tool
## Paper puppet (Limner test, Nov 18): a portrait cut from paper pieces that breathes,
## sways, blinks and moves its mouth, each piece casting its own soft shadow.
##
## The scene is the rig (ui/paper_puppet/edda_puppet.tscn). Every piece is a Sprite2D:
##   - its position is its pivot (what it sways or turns around). Move the pivot with the
##     editor's pivot tool (V), which shifts Offset so the art stays where it is;
##   - Z Index sets the stacking (higher is in front), across the Body and Head groups;
##   - metadata (Inspector, bottom): `depth` (how far it stands off what's beneath: its
##     shadow's offset and softness, 0 for none), `sway` (degrees it sways, 0 for none),
##     `phase` (where in the sway it starts), and for eyes `shut` (the closed-eye texture),
##     for the mouth `frames` (its shapes while talking, the first at rest).
## Pieces under Head turn with the head around Head's position; everything under Body
## breathes with the body around Body's position.
## Shadows show in the editor too; the motion only runs in the game (F6 runs this scene:
## T talks, S switches stepped/smooth, R shows the reference).
## Presentation only: its own seeded RNG, no game state.
extends Node2D

const SHADOW_SHADER = """shader_type canvas_item;
uniform float radius = 4.0;
uniform float strength = 0.35;
uniform vec3 tint = vec3(0.16, 0.09, 0.04);
void fragment() {
	vec2 r = TEXTURE_PIXEL_SIZE * radius;
	float a = texture(TEXTURE, UV).a * 0.2;
	a += (texture(TEXTURE, UV + vec2(r.x, 0.0)).a + texture(TEXTURE, UV - vec2(r.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, r.y)).a + texture(TEXTURE, UV - vec2(0.0, r.y)).a) * 0.125;
	a += (texture(TEXTURE, UV + r * 0.7).a + texture(TEXTURE, UV - r * 0.7).a
		+ texture(TEXTURE, UV + vec2(r.x, -r.y) * 0.7).a + texture(TEXTURE, UV + vec2(-r.x, r.y) * 0.7).a) * 0.075;
	COLOR = vec4(tint, a * strength);
}"""

## Stop-motion: move in steps, a few a second, with a small nudge to each piece every step.
@export var stepped = true
@export var step_fps = 10.0
## Shadow offset per unit of depth, in canvas pixels (where the light comes from).
@export var light = Vector2(3.0, 5.0)
## Candle flicker on the shadows (0 = steady).
@export var flicker = 1.0
@export var talking = false
@export var seed_value = 7
@export_group("Motion")
@export var breath = 0.006          ## how much the body swells (fraction of its height)
@export var body_sway = 0.35        ## degrees
@export var head_sway = 1.6         ## degrees
@export var talk_nod = 0.8          ## extra head movement while talking, degrees
@export var nudge_px = 0.8          ## stop-motion nudge, canvas pixels
@export var blink_every = Vector2(2.2, 5.5)   ## seconds between blinks, from..to

var pieces: Array = []              # {sprite, shadow, rest_pos, rest_rot, index}
var t = 0.0
var rng = RandomNumberGenerator.new()
var next_blink = 2.0
var blink_until = -1.0
var mouth_frame = 0
var mouth_step = -1
var _shadow_shader: Shader
var _body: Node2D
var _head: Node2D
var _rest = {}

func _ready() -> void:
	rng.seed = seed_value
	_shadow_shader = Shader.new()
	_shadow_shader.code = SHADOW_SHADER
	_body = get_node_or_null("Body")
	_head = get_node_or_null("Body/Head")
	for n in [_body, _head]:
		if n != null:
			_rest[n] = [n.position, n.rotation, n.scale]
	_collect(self)
	_place_shadows()
	if not Engine.is_editor_hint() and get_parent() == get_tree().root:
		_preview_setup()

func _collect(node: Node) -> void:
	for c in node.get_children():
		if c is Sprite2D:
			if c.name == "Reference":
				continue
			var shadow = Sprite2D.new()
			var m = ShaderMaterial.new()
			m.shader = _shadow_shader
			shadow.material = m
			shadow.show_behind_parent = true
			# Internal: never saved into the scene, so the rig stays just the pieces.
			c.add_child(shadow, false, Node.INTERNAL_MODE_FRONT)
			pieces.append({"sprite": c, "shadow": shadow, "rest_pos": c.position,
				"rest_rot": c.rotation, "index": pieces.size() + 1})
		_collect(c)

func _depth(s: Sprite2D) -> float:
	return float(s.get_meta("depth", 2))

func _place_shadows(lit: float = 1.0) -> void:
	for p in pieces:
		var s: Sprite2D = p.sprite
		var d = _depth(s)
		var sh: Sprite2D = p.shadow
		sh.visible = d > 0.0
		sh.texture = s.texture
		sh.centered = s.centered
		sh.flip_h = s.flip_h
		sh.flip_v = s.flip_v
		sh.offset = s.offset
		# The shadow is a child of the piece: undo the piece's turn and scale so the light
		# keeps coming from one direction whatever the piece does.
		var gs: Vector2 = s.global_scale
		sh.position = (light * d * lit).rotated(-s.global_rotation) / gs
		sh.material.set_shader_parameter("radius", 2.0 + d * 1.5)
		sh.material.set_shader_parameter("strength", 0.32 * (2.0 - lit))

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_place_shadows()
		return
	advance(delta)

func advance(delta: float) -> void:
	t += delta
	_pose(floor(t * step_fps) / step_fps if stepped else t)

func _hash(n: float) -> float:
	return fposmod(sin(n * 127.1 + 311.7) * 43758.5453, 1.0)

func _pose(ts: float) -> void:
	var step_n = floor(t * step_fps)
	if _body != null:
		_body.rotation = _rest[_body][1] + deg_to_rad(body_sway * sin(TAU * ts / 6.3))
		_body.scale = _rest[_body][2] * Vector2(1.0, 1.0 + breath * sin(TAU * ts / 4.2))
	if _head != null:
		var nod = talk_nod * sin(TAU * ts * 1.7) if talking else 0.0
		_head.rotation = _rest[_head][1] + deg_to_rad(head_sway * sin(TAU * ts / 5.1 + 1.0) + nod)
	for p in pieces:
		var s: Sprite2D = p.sprite
		var rot = float(s.get_meta("sway", 0.0)) * sin(TAU * ts / 2.9 + float(s.get_meta("phase", 0.0)))
		var nudge = Vector2.ZERO
		if stepped and _depth(s) >= 2.0:
			var k = step_n * 13.0 + p.index * 7.0
			nudge = Vector2(_hash(k) - 0.5, _hash(k + 3.0) - 0.5) * 2.0 * nudge_px
			rot += (_hash(k + 5.0) - 0.5) * 0.5
		s.rotation = p.rest_rot + deg_to_rad(rot)
		s.position = p.rest_pos + nudge
	_blink()
	_mouth()
	_place_shadows(1.0 + flicker * 0.12 * (sin(ts * 7.3) * 0.6 + sin(ts * 11.9 + 1.0) * 0.4))

func _blink() -> void:
	if t >= next_blink:
		blink_until = t + 0.13
		next_blink = t + rng.randf_range(blink_every.x, blink_every.y)
	var shut = t < blink_until
	for p in pieces:
		var s: Sprite2D = p.sprite
		if s.has_meta("shut"):
			if not p.has("open"):
				p.open = s.texture
			s.texture = s.get_meta("shut") if shut else p.open

func _mouth() -> void:
	for p in pieces:
		var s: Sprite2D = p.sprite
		if not s.has_meta("frames"):
			continue
		var frames: Array = s.get_meta("frames")
		var ms = int(floor(t * 8.0))
		if talking:
			if ms != mouth_step:
				mouth_step = ms
				var f = rng.randi_range(0, frames.size() - 1)
				mouth_frame = (f + 1) % frames.size() if f == mouth_frame else f
		else:
			mouth_frame = 0
		s.texture = frames[mouth_frame]

# --- Running the scene by itself (F6) ---------------------------------------------------

var _label: Label

func _preview_setup() -> void:
	var win = get_viewport().get_visible_rect().size
	var canvas = Vector2(1024, 1536)
	var k = minf(win.x / canvas.x, win.y / canvas.y) * 0.95
	scale = Vector2.ONE * k
	position = (win - canvas * k) / 2.0
	RenderingServer.set_default_clear_color(Color(0.42, 0.33, 0.26))
	var layer = CanvasLayer.new()
	add_child(layer, false, Node.INTERNAL_MODE_BACK)
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_label)
	_update_label()

func _update_label() -> void:
	if _label != null:
		_label.text = "T talk (%s)   S %s   R reference" % ["on" if talking else "off", "stepped" if stepped else "smooth"]

func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _label == null or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_T: talking = not talking
		KEY_S: stepped = not stepped
		KEY_R:
			var r = get_node_or_null("Reference")
			if r != null:
				r.visible = not r.visible
	_update_label()
