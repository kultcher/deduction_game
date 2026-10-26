extends SceneTree
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const Overlay = preload("res://ui/headline_overlay.gd")
var checks = 0
var fails = 0
func _init():
	call_deferred("run")
func check(ok: bool, text: String):
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", text)
func fresh(count: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch3_tests"
	g.new_case(4242, count)
	return g
func run():
	await headlines()
	await setup_counts()
	await ward_warnings()
	print("Batch 3: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
func headlines():
	var g = fresh()
	var rng = g.w.rng.state
	g._headline("dawn", "Day 1 Dawns")
	check(g.w.rng.state == rng, "headline emission does not advance RNG")
	var events = [{"k": "narration", "text": "Original line."}, {"k": "card", "n": 1}, {"k": "headline", "text": "Notice"}, {"k": "card", "n": 2}]
	check(Game.render(events) == "Original line.  [case board: #1, #2]", "headline side-channel preserves exact text/card-tag rendering")
	var victim = g.w.npcs[0]
	victim.alive = false
	g.w.deaths_last_night = [victim.id]
	g.w.day = 2
	for public_claim in [false, true]:
		victim.claimed_role = "seer"
		victim.max_tier = 3
		victim.claim_public = public_claim
		g.events = []
		g._morning_report()
		var notices = g.events.filter(func(e): return e.k == "headline" and e.kind == "death")
		check(notices.size() == 1 and ("claimed to be" if public_claim else "told you they were") in notices[0].text and "Seer" in notices[0].text, "death notice uses only the player's public/private claim knowledge")
		check(notices[0].subtitle == "A Demon hides among 9 remaining townsfolk", "death subtitle reports living count")
	victim.max_tier = 0
	victim.claim_public = false
	g.events = []
	g._morning_report()
	check(g.events.any(func(e): return e.k == "headline" and e.kind == "death" and e.text == victim.name), "unknown gift death reveals only the name")
	root.size = Vector2i(1200, 800)
	root.content_scale_size = root.size
	var button = Button.new()
	button.position = Vector2(10, 10)
	button.size = Vector2(100, 50)
	button.text = "Target"
	root.add_child(button)
	var clicks = [0]
	button.pressed.connect(func(): clicks[0] += 1)
	var overlay = Overlay.new()
	root.add_child(overlay)
	overlay.set_process(false)
	for i in range(5): overlay.enqueue({"kind": "dawn", "text": str(i)})
	check(overlay.current.text == "0" and overlay.pending.size() == 4, "notices play one at a time in order")
	var left = overlay.remaining
	overlay._process(0.25)
	check(is_equal_approx(left - overlay.remaining, 0.5), "more than two waiting notices shorten display time")
	var motion = InputEventMouseMotion.new()
	motion.position = Vector2(30, 30)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	for i in range(3): await process_frame
	var click = InputEventMouseButton.new()
	click.position = motion.position
	click.global_position = motion.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click.pressed = false
	Input.parse_input_event(click)
	await process_frame
	check(clicks[0] == 1 and overlay.current.text == "1", "a click skips a notice and still activates its ordinary target")
	check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.title.mouse_filter == Control.MOUSE_FILTER_IGNORE, "overlay and text cannot intercept input")
	var cfg = ConfigFile.new()
	cfg.set_value("headline.dawn", "size", 51)
	cfg.set_value("headline.dawn", "duration", 1.7)
	cfg.set_value("headline.dawn", "colour", "#123456")
	var path = "res://logs/batch3/headline-test.cfg"
	cfg.save(path)
	overlay.load_styles(path)
	check(overlay.styles.dawn.size == 51 and overlay.styles.dawn.duration == 1.7 and overlay.styles.dawn.colour == Color("123456"), "settings override each style field from the shared defaults table")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	overlay.clear()
	check(overlay.current.is_empty() and overlay.pending.is_empty() and not overlay.visible, "case reset clears every notice")
	overlay.free()
	button.free()

func setup_counts():
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var main = load("res://ui/main.tscn").instantiate()
	main.show_script_at_start = false
	root.add_child(main)
	var expected = {7: "Good: 5 gifted townsfolk / 1 secret · Evil: 1 minion / 1 demon", 10: "Good: 7 gifted townsfolk / 1 secret · Evil: 2 minions / 1 demon"}
	for count in [7, 10]:
		main.g = fresh(count)
		var board = JSON.stringify(main.g.board)
		var rng = main.g.w.rng.state
		# Even an inconsistent hidden assignment cannot influence the public count.
		main.g.w.minion_ids = []
		for n in main.g.w.npcs:
			n.secret_mod = "lovers"
		main._open_roles()
		await process_frame
		var summary = main.roles_box.get_node("SetupSummary")
		check(summary.text == expected[count], "script summary uses setup counts and one secret, including Lovers")
		check(JSON.stringify(main.g.board) == board and main.g.w.rng.state == rng, "script summary creates no card and consumes no RNG")
	main.free()

func ward_warnings():
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	root.add_child(scene)
	var g = scene.g
	var person = g.w.living_good()[0]
	g.events = []
	g._offer_command(person, "ward")
	check(g.w.tools.ward == 1 and g.offer.ward == person.id and Game.render(g.events).contains("Promising does not spend your ward; keeping the promise does"), "ward promises explain the limit and do not consume the tool")
	g.state = "night"
	scene._ward_target = person.id
	scene._refresh_actions()
	await process_frame
	var buttons: Array = scene.actions.get_children().filter(func(n): return n is Button and "ward" in n.text.to_lower())
	check(buttons.size() >= 3 and buttons.all(func(b): return "1 left, once per case" in b.text), "every direct-night Ward button displays the remaining limit")
	var dialog = scene._confirm_ward(person.id)
	check(dialog.dialog_text == "This spends your only ward. Ward %s?" % person.name and g.w.tools.ward == 1, "direct UI warding asks for confirmation before spending")
	dialog.canceled.emit()
	await process_frame
	check(g.w.tools.ward == 1 and g.state == "night", "canceling a ward confirmation spends nothing")
	var output = g.command("ward " + person.id)
	check(g.w.tools.ward == 0 and g.ward_log.has(1) and "You chalk a warding sigil" in output, "typed ward commands go straight through and consume exactly one use")
	scene.free()
