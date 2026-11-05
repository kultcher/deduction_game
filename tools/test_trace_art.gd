## Trace artwork lookup and the conversation view's item mode.
extends SceneTree

const TraceArt = preload("res://ui/trace_art.gd")
const C = preload("res://sim/content.gd")

func _init() -> void:
	var fails = 0
	var checks = 0
	var check = func(ok: bool, msg: String):
		checks += 1
		if not ok:
			push_error("FAIL: " + msg)
		return ok
	var all_locs: Array = C.LOCATIONS.keys().filter(func(l): return not str(l).begins_with("home"))
	var missing: Array = []
	for key in C.TRACE_TOKENS.keys() + C.TRACE_SCENTS.keys():
		var locs: Array = Array(key.split(":"))
		for size in ["small", "large"]:
			if TraceArt.icon({"locs": locs}, size) == null:
				missing.append("%s/%s" % [size, key])
	if not check.call(missing.is_empty(), "every token and scent has both icon sizes; missing: %s" % [missing]): fails += 1
	if not check.call(TraceArt.icon({"locs": ["mill", "bakery"]}) == TraceArt.icon({"trace_key": "locations:bakery:mill"}), "lookup is order-free and accepts trace_key"): fails += 1
	if not check.call(TraceArt.icon({"trace_key": "quarter:square:docks:2"}) == null and TraceArt.icon({}) == null, "traces without art return null"): fails += 1
	var View = load("res://ui/day_conversation_view.gd")
	var v = View.new()
	root.add_child(v)
	await process_frame
	var tex = TraceArt.icon({"locs": ["bakery", "mill"]}, "large")
	v.show_item("Edda's cottage", tex, "Near the body lies a brass grain-measure token.")
	if not check.call(v.person_id == "" and v.portrait.texture == tex and v.speaker.text == "Edda's cottage" and v.lines.size() == 1, "show_item puts the item in the portrait slot and its text in the bubble"): fails += 1
	if not check.call(is_equal_approx(v.portrait.anchor_right, View.ITEM_FRAME[2]), "item uses the item frame"): fails += 1
	v.begin("edda", "Edda")
	v.set_portrait_ink_mode("animated")
	if not check.call(v.portrait.material != null, "registered neutral ink is available for the Edda prototype"): fails += 1
	if not check.call(is_equal_approx(v.portrait.anchor_right, View.PORTRAIT_FRAME[2]) and v.person_id == "edda", "begin restores the portrait frame"): fails += 1
	# An Edda conversation leaves a line-boil material on the shared portrait slot.
	# Searching a scene must clear it before that slot displays an evidence item.
	v.show_item("Edda's cottage", tex, "Near the body lies a brass grain-measure token.")
	if not check.call(v.portrait.material == null, "item mode clears the preceding portrait's shader"): fails += 1
	var toggle = InputEventKey.new()
	toggle.keycode = KEY_B
	toggle.pressed = true
	v._unhandled_key_input(toggle)
	if not check.call(v.portrait.texture == tex and v.portrait.material == null, "line-boil shortcut leaves item mode intact"): fails += 1
	if fails == 0:
		print("test_trace_art: ALL %d CHECKS PASSED" % checks)
		quit(0)
	else:
		printerr("test_trace_art: %d/%d FAILED" % [fails, checks])
		quit(1)
