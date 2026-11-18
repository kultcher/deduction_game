## Paper puppet (Limner test, Nov 18): a portrait cut from paper pieces that breathes,
## sways, blinks and moves its mouth, each piece casting its own soft shadow.
## Built from a rig file (assets/art/paper_puppet_poc/<id>/rig.json): each piece's centre,
## scale and rotation on the portrait canvas, its group (body or head), its pivot and how far
## it stands off what's beneath it (its shadow's offset and softness).
## `stepped` moves the pieces in steps, a few a second, with a small nudge each step, like
## stop-motion; off, they move smoothly. Presentation only: its own seeded RNG, no game state.
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

var stepped = true
var step_fps = 10.0
var talking = false
var light = Vector2(3.0, 5.0)       # shadow offset per unit of depth, in canvas pixels
var flicker = 1.0                   # candle flicker on the shadows (0 = steady)

var groups = {}                     # body / head -> Node2D
var pieces = {}                     # name -> {holder, sprite, shadow, data, rest_rot, rest_pos}
var textures = {}
var t = 0.0
var rng = RandomNumberGenerator.new()
var next_blink = 2.0
var blink_until = -1.0
var mouth_frame = 0
var mouth_step = -1
var _shadow_shader: Shader

func build(dir: String, seed_value: int = 7) -> void:
	rng.seed = seed_value
	_shadow_shader = Shader.new()
	_shadow_shader.code = SHADOW_SHADER
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/rig.json"))
	var body = Node2D.new()
	body.position = _v(rig.pivots.body)
	add_child(body)
	var head = Node2D.new()
	head.position = _v(rig.pivots.head) - body.position
	body.add_child(head)
	groups = {"body": body, "head": head}
	var origin = {"body": body.position, "head": _v(rig.pivots.head)}
	var i = 0
	for d in rig.pieces:
		i += 1
		var holder = Node2D.new()
		var pivot: Vector2 = _v(d.get("pivot", d.centre))
		holder.position = pivot - origin[d.parent]
		holder.z_index = i * 2
		groups[d.parent].add_child(holder)
		var tex = _tex(dir, d.name)
		var shadow = Sprite2D.new()
		shadow.texture = tex
		shadow.z_index = -1
		var m = ShaderMaterial.new()
		m.shader = _shadow_shader
		m.set_shader_parameter("radius", 2.0 + float(d.depth) * 1.5)
		shadow.material = m
		holder.add_child(shadow)
		var sprite = Sprite2D.new()
		sprite.texture = tex
		holder.add_child(sprite)
		for s in [shadow, sprite]:
			s.position = _v(d.centre) - pivot
			s.scale = Vector2.ONE * float(d.scale)
			s.rotation_degrees = -float(d.rot)   # the rig uses the image convention: positive turns anticlockwise
		for extra in [d.get("shut", "")] + Array(d.get("frames", [])):
			if extra != "":
				_tex(dir, extra)
		pieces[d.name] = {"holder": holder, "sprite": sprite, "shadow": shadow, "data": d,
			"rest": sprite.position, "index": i}
	_pose(0.0)

func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

func _tex(dir: String, name: String) -> Texture2D:
	if not textures.has(name):
		textures[name] = load("%s/%s.png" % [dir, name])
	return textures[name]

func advance(delta: float) -> void:
	t += delta
	_pose(floor(t * step_fps) / step_fps if stepped else t)

func _hash(n: float) -> float:
	return fposmod(sin(n * 127.1 + 311.7) * 43758.5453, 1.0)

func _pose(ts: float) -> void:
	var tau = TAU
	var step_n = floor(t * step_fps)
	groups.body.rotation_degrees = 0.35 * sin(tau * ts / 6.3)
	groups.body.scale = Vector2(1.0, 1.0 + 0.006 * sin(tau * ts / 4.2))
	groups.head.rotation_degrees = 1.6 * sin(tau * ts / 5.1 + 1.0) + (0.8 * sin(tau * ts * 1.7) if talking else 0.0)
	var sway = {"lock_top": [2.0, 0.0], "lock_right": [3.0, 1.3], "lock_left": [3.0, 2.4],
		"hair_back": [0.8, 0.6], "lapel_b": [1.2, 2.0], "ear": [0.0, 0.0]}
	for name in pieces:
		var p = pieces[name]
		var rot = 0.0
		if sway.has(name):
			rot = sway[name][0] * sin(tau * ts / 2.9 + sway[name][1])
		var nudge = Vector2.ZERO
		if stepped and int(p.data.depth) >= 2:
			var k = step_n * 13.0 + p.index * 7.0
			nudge = Vector2(_hash(k) - 0.5, _hash(k + 3.0) - 0.5) * 1.6
			rot += (_hash(k + 5.0) - 0.5) * 0.5
		p.holder.rotation_degrees = rot
		p.sprite.position = p.rest + nudge
		var lit = 1.0 + flicker * 0.12 * (sin(ts * 7.3) * 0.6 + sin(ts * 11.9 + 1.0) * 0.4)
		p.shadow.position = p.rest + nudge + light * float(p.data.depth) * lit
		p.shadow.material.set_shader_parameter("strength", 0.32 * (2.0 - lit))
	# Blinks: now and then, a little more than a tenth of a second.
	if t >= next_blink:
		blink_until = t + 0.13
		next_blink = t + rng.randf_range(2.2, 5.5)
	var shut = t < blink_until
	for name in ["eye_far", "eye_near"]:
		if pieces.has(name):
			var tex = textures[name + "_shut"] if shut else textures[name]
			pieces[name].sprite.texture = tex
			pieces[name].shadow.texture = tex
			pieces[name].sprite.position.y = pieces[name].rest.y + (10.0 if shut else 0.0)
	# Mouth: flaps through its shapes on its own stepped clock while talking, else rests shut.
	if pieces.has("mouth_0"):
		var frames: Array = pieces.mouth_0.data.frames
		var ms = int(floor(t * 8.0))
		if talking:
			if ms != mouth_step:
				mouth_step = ms
				var f = rng.randi_range(0, frames.size() - 1)
				mouth_frame = (f + 1) % frames.size() if f == mouth_frame else f
		else:
			mouth_frame = 0
		var mt = textures[frames[mouth_frame]]
		pieces.mouth_0.sprite.texture = mt
		pieces.mouth_0.shadow.texture = mt
