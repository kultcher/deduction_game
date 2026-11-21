## Line boil (ui/line_boil.gdshader): the drawn ink on a portrait redrawn a few times a
## second, rotoscope style, over a still colour layer. This owns which portraits have
## layers, the boil level (resting low, flaring on an expression change, settling back)
## and a steady redraw clock that two crossfading portraits share.
## Presentation only: it reads no game state and never touches the simulation's RNG.
## Off unless `enabled` is set; until then portraits draw exactly as before.
extends RefCounted

const SHADER = preload("res://ui/line_boil.gdshader")
const LAYERS = "res://assets/art/line_boil/%s/%s-%s.png"   # id, expression, base|ink

## Looks to choose between. "original" is the Nov 3 test (e965cd3) as it last stood.
## rest: boil while nothing happens; flare: boil an expression change jumps to (by
## expression, "*" for the rest); decay: seconds for most of a flare to settle;
## fps: redraws a second at boil 0 and 1; warp: how far lines wander at boil 0 and 1,
## in source pixels.
const PRESETS = {
	"subtle": {"rest": 0.15, "flare": {"harsh": 0.8, "neutral": 0.35, "*": 0.5}, "decay": 0.6,
		"fps": [6.0, 10.0], "warp": [0.5, 2.0], "hatch_drop": 0.15},
	"original": {"rest": 0.3, "flare": {"harsh": 1.0, "neutral": 0.45, "*": 0.65}, "decay": 1.0,
		"fps": [8.0, 14.0], "warp": [0.8, 3.0], "hatch_drop": 0.25},
	"lively": {"rest": 0.5, "flare": {"harsh": 1.0, "neutral": 0.7, "*": 0.85}, "decay": 1.4,
		"fps": [10.0, 16.0], "warp": [1.2, 4.0], "hatch_drop": 0.35},
}
const DEFAULT_PRESET = "original"

## Session-wide switch, shared by every view (the B key in a conversation flips it).
static var enabled = false
static var preset_name = DEFAULT_PRESET
static var _warp: NoiseTexture2D

var boil = 0.0
var phase = 0.0          # redraws so far; integrated, so a change of speed never jumps
var materials = {}       # base texture path -> ShaderMaterial

func _init() -> void:
	boil = preset().rest

static func preset() -> Dictionary:
	return PRESETS.get(preset_name, PRESETS[DEFAULT_PRESET])

static func has_layers(id: String, expression: String) -> bool:
	return ResourceLoader.exists(LAYERS % [id, expression, "base"]) \
		and ResourceLoader.exists(LAYERS % [id, expression, "ink"])

## The colour layer to show for this portrait, or null to show the plain portrait.
static func base_texture(id: String, expression: String) -> Texture2D:
	if not enabled or not has_layers(id, expression):
		return null
	return load(LAYERS % [id, expression, "base"])

static func warp_texture() -> NoiseTexture2D:
	if _warp == null:
		var noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 2
		noise.seed = 1
		_warp = NoiseTexture2D.new()
		_warp.width = 512
		_warp.height = 512
		_warp.seamless = true
		_warp.noise = noise
	return _warp

## The material for a texture from base_texture(), null for anything else.
func material_for(texture: Texture2D) -> ShaderMaterial:
	if texture == null or not texture.resource_path.ends_with("-base.png") or "/line_boil/" not in texture.resource_path:
		return null
	var key = texture.resource_path
	if not materials.has(key):
		var m = ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("ink", load(key.trim_suffix("-base.png") + "-ink.png"))
		m.set_shader_parameter("warp_tex", warp_texture())
		materials[key] = m
		_sync_one(m)
	return materials[key]

## Give each rect the material its texture needs (none for a plain portrait).
func apply(rects: Array) -> void:
	for r in rects:
		if r != null:
			r.material = material_for(r.texture)

func rest() -> void:
	boil = preset().rest
	_sync()

## An expression change: jump the boil up (harsh hardest) and let it settle.
func flare(expression: String = "*") -> void:
	var f: Dictionary = preset().flare
	boil = maxf(boil, f.get(expression, f["*"]))
	_sync()

func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	var p = preset()
	var old_step = int(phase)
	phase += delta * lerpf(p.fps[0], p.fps[1], boil)
	var settled = boil <= p.rest
	if not settled:
		boil = p.rest + (boil - p.rest) * exp(-delta / p.decay)
	if int(phase) != old_step or not settled:
		_sync()

func _sync() -> void:
	for m in materials.values():
		_sync_one(m)

func _sync_one(m: ShaderMaterial) -> void:
	var p = preset()
	# Bounded so the GPU's float hash stays sharp however long a conversation runs.
	m.set_shader_parameter("redraw_step", float(int(phase) % 4096))
	m.set_shader_parameter("boil", boil)
	m.set_shader_parameter("warp_rest_px", p.warp[0])
	m.set_shader_parameter("warp_px", p.warp[1])
	m.set_shader_parameter("hatch_drop", p.hatch_drop)
