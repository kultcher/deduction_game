## "Travel to <block>" (Michael, Nov 28, item 6): a button at the foot of a block's close-up,
## before you've chosen where to spend the phase, asks first. The question shows only what the
## player could know: people you can make out by name ("(busy)" if talking), the rest as a
## count, the Town Hall's reads left, and who lives there. "Don't ask again" sticks.
##   godot --headless --path . --script res://tools/test_travel_confirm.gd
extends SceneTree

const Travel = preload("res://ui/travel_confirm.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _frames(n: int = 4) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	var had_skip: bool = Travel.skip_confirm()
	Travel.set_skip_confirm(false)
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	scene.pacing_enabled = false
	root.add_child(scene)
	await _frames()
	var g = scene.g
	if g.state == "approach":
		scene._run("decline")
	scene._refresh_all()
	await _frames()
	check(not scene.travel_button.visible, "no Travel button on the whole-town map")
	scene.map.zoom_to("square")
	await _frames()
	check(scene.travel_button.visible and scene.travel_button.text == "Travel to %s" % C.block_name("square"), "a block's close-up offers 'Travel to the Square' (%s)" % scene.travel_button.text)

	# The question: only what the player could know.
	var info: Dictionary = Travel.summary(g, "square")
	check(str(info.title) == "Visit %s this %s?" % [C.block_name("square"), g.w.phase_name().to_lower()], "it asks '%s'" % info.title)
	var text: String = "\n".join(PackedStringArray(info.lines))
	var leaks: Array = []
	var named_ok: bool = true
	for l in g.w.locations_on("square"):
		for n in g.w.npcs_at(l):
			if n.at_home():
				continue
			var seen: bool = g.can_see_ui(n)
			if not seen and (n.name + ",") in (text + ","):
				leaks.append(n.name)
			if seen and not n.name in text:
				named_ok = false
	check(leaks.is_empty(), "nobody out of sight is named (%s)" % ", ".join(PackedStringArray(leaks)))
	check(named_ok, "everyone in sight there is named")
	var unseen: int = 0
	for l in g.w.locations_on("square"):
		unseen += preload("res://game/game_day_night.gd").unseen_at_ui(g, l)
	check(unseen == 0 or "other" in text, "the rest are a count (%d out of sight)" % unseen)
	check(info.lines.any(func(x): return str(x) == "Town Hall: %d/3 Check Records uses remaining" % g.w.town_hall_uses_left), "the Town Hall's reads left are shown")
	var residents: Array = g.w.npcs.filter(func(n): return n.home_block == "square")
	check(residents.is_empty() or info.lines.any(func(x): return str(x).begins_with("Living here: ") and residents.all(func(n): return n.name in str(x))), "and who lives there")
	var victim = residents[0] if not residents.is_empty() else null
	if victim != null:
		victim.alive = false
		check(Travel.summary(g, "square").lines.any(func(x): return ("%s (dead)" % victim.name) in str(x)), "the dead are marked (dead)")
		victim.alive = true

	# Asking, travelling, and "don't ask again".
	scene._on_travel_pressed()
	await _frames()
	var popup = scene.get_node_or_null("TravelConfirm")
	check(popup != null and popup.visible and not g.moved, "pressing it asks first, and nothing moves yet")
	var boxes: Array = popup.find_children("*", "CheckBox", true, false) if popup != null else []
	var travel_btn: Array = popup.find_children("*", "Button", true, false).filter(func(b): return b.text == "Travel") if popup != null else []
	if not boxes.is_empty() and not travel_btn.is_empty():
		boxes[0].button_pressed = true
		travel_btn[0].pressed.emit()
		await _frames()
	check(g.moved and g.w.loc_block(g.loc) == "square", "Travel goes there (%s)" % g.loc)
	check(Travel.skip_confirm(), "'Don't ask again' is kept in this viewer's settings")
	check(not scene.travel_button.visible, "once you've chosen, the button goes")
	var went: Array = [false]
	Travel.request(scene, g, "docks", func(): went[0] = true)
	await _frames()
	check(went[0] and scene.get_node_or_null("TravelConfirm") == null, "with it ticked, travel goes without asking")

	Travel.set_skip_confirm(had_skip)
	scene.queue_free()
	print("Travel confirm: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
