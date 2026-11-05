## One local clock shared by both portraits during expression crossfades.
## Settings and seed are presentation data; never touch the simulation RNG.
extends RefCounted

const Assets = preload("res://ui/portrait_ink_assets.gd")
const SHADER = preload("res://ui/portrait_ink.gdshader")
const DEFAULTS = {
	"rate": 6.0, "displacement": 1.2, "amount": 0.6,
	"protect_face": true, "protect_edge": true, "show_protection": false,
	"warp": true, "variants": false, "pressure": false,
}

var settings = DEFAULTS.duplicate()
var mode = "animated" # original / still / animated
var paused = false
var phase = 0.0
var step_index = 0
var pulse_left = 0.0
var materials: Dictionary = {}

func configure(values: Dictionary) -> void:
	for key in values:
		if settings.has(key):
			settings[key] = values[key]
	settings.rate = clampf(float(settings.rate), 1.0, 12.0)
	settings.displacement = clampf(float(settings.displacement), 0.0, 4.0)
	settings.amount = clampf(float(settings.amount), 0.0, 1.0)
	_sync()

func advance(delta: float, showing: bool = true) -> void:
	if not showing or paused or mode != "animated" or delta <= 0.0:
		return
	# Integrate the rate instead of multiplying all elapsed time by a new rate.
	var old_step = step_index
	var pulsing = pulse_left > 0.0
	phase += delta * float(settings.rate)
	step_index = int(floor(phase))
	pulse_left = maxf(0.0, pulse_left - delta)
	if old_step != step_index or pulsing:
		_sync()

func pulse() -> void:
	pulse_left = 0.45
	_sync()

func reset_clock() -> void:
	phase = 0.0
	step_index = 0
	pulse_left = 0.0
	_sync()

func material_for(texture: Texture2D) -> ShaderMaterial:
	if mode == "original":
		return null
	var data = Assets.for_texture(texture)
	if data.is_empty():
		return null
	var key: String = texture.resource_path
	if not materials.has(key):
		var mat = ShaderMaterial.new()
		mat.shader = SHADER
		for v in ["a", "b", "c"]:
			mat.set_shader_parameter("lines_" + v, load(data.lines % v))
		mat.set_shader_parameter("protected_face", data.face)
		mat.set_shader_parameter("seed", data.seed)
		materials[key] = mat
		_sync()
	return materials[key]

func apply(current: TextureRect, previous: TextureRect = null) -> void:
	current.material = material_for(current.texture)
	if previous != null:
		previous.material = material_for(previous.texture)
	_sync()

func _sync() -> void:
	for mat in materials.values():
		# Keep GPU float hashes bounded while the CPU phase remains monotonic.
		mat.set_shader_parameter("redraw_step", float(step_index % 4096))
		mat.set_shader_parameter("displacement_px", float(settings.displacement) * (1.0 + pulse_left * 0.8))
		mat.set_shader_parameter("ink_amount", float(settings.amount))
		mat.set_shader_parameter("protect_face", bool(settings.protect_face))
		mat.set_shader_parameter("protect_edge", bool(settings.protect_edge))
		mat.set_shader_parameter("show_protection", bool(settings.show_protection))
		mat.set_shader_parameter("warp_enabled", bool(settings.warp))
		mat.set_shader_parameter("variant_count", 3 if settings.variants else 1)
		mat.set_shader_parameter("pressure_variation", 0.08 if settings.pressure else 0.0)
