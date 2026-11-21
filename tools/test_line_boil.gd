## Line boil (ui/line_boil.gd, Limner Nov 18): redrawn-ink portraits, opt-in.
##   - off by default, and while off a conversation shows exactly the plain portrait;
##   - on, a portrait with ink layers shows its colour layer with the boil material, and one
##     without layers stays plain; an item (a crime-scene trace) never gets the material;
##   - the boil rests, flares on an expression change (harsh hardest) and settles back;
##   - the redraw clock is integrated, so a flare speeds it up without jumping it.
## Headless: checks wiring, not pixels (tools/line_boil_capture.gd records the look).
##   godot --headless --path . --script res://tools/test_line_boil.gd
extends SceneTree

const LineBoil = preload("res://ui/line_boil.gd")
const ConversationView = preload("res://ui/day_conversation_view.gd")
const VNPortraits = preload("res://ui/vn_portraits.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	call_deferred("_run")


func _key_b(shift: bool) -> InputEventKey:
	var e = InputEventKey.new()
	e.keycode = KEY_B
	e.pressed = true
	e.shift_pressed = shift
	return e


func _run() -> void:
	_check(not LineBoil.enabled, "line boil is off by default")
	_check(LineBoil.has_layers("edda", "neutral"), "Edda's neutral portrait has ink layers")
	_check(not LineBoil.has_layers("edda", "harsh"), "Edda's harsh portrait has none yet")
	_check(LineBoil.base_texture("edda", "neutral") == null, "while off, no colour layer is handed out")

	# Off: the conversation is exactly as before.
	var view = ConversationView.new()
	root.add_child(view)
	await process_frame
	view.begin("edda", "Edda")
	_check(view.portrait.texture == VNPortraits.texture("edda", "neutral"), "off: Edda shows her plain portrait")
	_check(view.portrait.material == null, "off: no shader on the portrait")

	# B in a talk with Edda turns it on; the colour layer and the material go up.
	view._unhandled_key_input(_key_b(false))
	_check(LineBoil.enabled, "B turns line boil on")
	_check(view.portrait.texture.resource_path.ends_with("line_boil/edda/neutral-base.png"), "on: Edda shows her colour layer")
	_check(view.portrait.material is ShaderMaterial, "on: the portrait has the boil material")
	var m: ShaderMaterial = view.portrait.material
	_check(m.get_shader_parameter("ink") != null, "the material has its ink layer")

	# Expression change to one without layers: plain portrait, the old one fades out boiling.
	view.set_expression("harsh")
	_check(view.portrait.material == null, "an expression without ink layers shows plain")
	_check(view.portrait.texture == VNPortraits.texture("edda", "harsh"), "...and is Edda's own harsh portrait")
	view.set_expression("neutral")
	_check(view.portrait.material == m, "back to neutral reuses the same material")

	# Rest, flare, settle.
	var p = LineBoil.preset()
	view.line_boil.rest()
	_check(is_equal_approx(view.line_boil.boil, p.rest), "the boil rests at the preset's level")
	view.line_boil.flare("harsh")
	_check(is_equal_approx(view.line_boil.boil, p.flare["harsh"]), "a harsh change flares hardest")
	view.line_boil.flare("neutral")
	_check(is_equal_approx(view.line_boil.boil, p.flare["harsh"]), "a weaker flare doesn't cut a stronger one short")
	for _i in range(300):
		view.line_boil.advance(1.0 / 60.0)
	_check(view.line_boil.boil - p.rest < 0.02, "five seconds on, the flare has settled")
	_check(is_equal_approx(m.get_shader_parameter("boil"), view.line_boil.boil), "the shader gets the boil level")

	# The clock: integrated, so changing speed never jumps it back or far forward.
	var lb = LineBoil.new()
	lb.advance(1.0)
	var at_rest: float = lb.phase
	_check(is_equal_approx(at_rest, lerpf(p.fps[0], p.fps[1], p.rest)), "a second at rest is that many redraws")
	lb.flare("harsh")
	lb.advance(0.0)
	_check(lb.phase == at_rest, "a flare doesn't move the clock by itself")
	lb.advance(0.1)
	_check(lb.phase > at_rest and lb.phase < at_rest + p.fps[1] * 0.1 + 0.001, "a flare speeds the redraws up, no jump")

	# Shift+B flares without toggling.
	view.line_boil.rest()
	view._unhandled_key_input(_key_b(true))
	_check(LineBoil.enabled and view.line_boil.boil > p.rest, "Shift+B fires a flare and leaves it on")

	# Items never boil.
	view.show_item("A trace", VNPortraits.texture("agnes", "neutral"), "Something left behind.")
	_check(view.portrait.material == null, "an item shows without the shader")

	# Someone without layers: B does nothing, plain portrait even while on.
	view.begin("agnes", "Agnes")
	_check(view.portrait.material == null and view.portrait.texture == VNPortraits.texture("agnes", "neutral"), "on: someone without ink stays plain")
	view._unhandled_key_input(_key_b(false))
	_check(LineBoil.enabled, "B does nothing in a talk with someone without ink")

	# And off again.
	view.begin("edda", "Edda")
	view._unhandled_key_input(_key_b(false))
	_check(not LineBoil.enabled and view.portrait.material == null, "B again turns it off")
	_check(view.portrait.texture == VNPortraits.texture("edda", "neutral"), "...back to the plain portrait")

	view.queue_free()
	await process_frame
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
