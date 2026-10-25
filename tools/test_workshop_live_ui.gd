extends SceneTree
const Game = preload("res://game/game.gd")
const Inspector = preload("res://ui/workshop_comparison.gd")
const UITheme = preload("res://ui/theme.gd")
var fails = 0
var checks = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1200, 850)
	root.content_scale_size = root.size
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	var n = g.w.living_good()[0]
	n.info_log = []
	n.beliefs = []
	n.known_claims = {}
	var src = g.w.npcs.filter(func(p): return p != n)[0]
	var card = g.add_card({"kind": "info", "source": src.id, "role": "surveyor", "day": 0, "data": {"count": 2}, "text": "A Surveyor reported evil on two blocks."})
	g.file_deduction({"type": "evil", "a": g.w.npcs[2].id}, [card])
	var panel = Inspector.new()
	panel.g = g
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "DejaVu Sans"])
	panel.theme = UITheme.make(font)
	root.add_child(panel)
	await process_frame
	check(panel.inspect_button.disabled and "Enable Debug" in panel.output.text, "live private inspection requires explicit Debug mode")
	var safe_before = JSON.stringify([g.w.rng.state, n.suspicion, n.ledger, g.prediction_spoiled])
	await panel._preview()
	check("neutral ghost" in panel.output.text and "Conditional worlds" in panel.output.text, "effectiveness preview works before enabling Debug")
	check(safe_before == JSON.stringify([g.w.rng.state, n.suspicion, n.ledger, g.prediction_spoiled]), "neutral UI preview neither spoils scoring nor changes private beliefs")
	g.set_debug_overlay(true)
	panel.refresh()
	check(g.prediction_spoiled and not panel.inspect_button.disabled, "debug inspection is labelled and follows existing scoring rules")
	panel.effects_toggle.button_pressed = true
	check(g.workshop_effects, "experimental ownership switch enables restricted effects explicitly")
	g.workshop_compare = true
	g._evaluate_deduction(n, g.board[-1], 0.6, true, "meeting")
	panel._records()
	check("Applied shared assessment" in panel.output.text and not g.workshop_comparisons[-1].has("legacy"), "recorded applied assessments name the actual model without inventing a legacy comparison")
	panel.effects_toggle.button_pressed = false
	check(not g.workshop_effects, "experimental switch can restore legacy ownership")
	for i in range(panel.listeners.item_count):
		if panel.listeners.get_item_metadata(i) == n.id:
			panel.listeners.select(i)
	var rng_state = g.w.rng.state
	await panel._inspect()
	check("not applied" in panel.output.text and "New model" in panel.output.text, "inspector displays a conditional proposal with explicit effect status")
	check(g.w.rng.state == rng_state, "manual UI preview does not consume game randomness")
	panel.automatic.button_pressed = true
	check(g.workshop_compare, "recording control enables the shared venue comparator")
	g._evaluate_deduction(n, g.board[-1], 0.6, false, "meeting")
	panel._records()
	check("Original agreement" in panel.output.text and "meeting" in panel.output.text, "recorded original and new responses appear together")
	panel.refresh()
	await panel._inspect()
	for i in range(2):
		await process_frame
	var args = OS.get_cmdline_user_args()
	if "--screenshot" in args:
		var index = args.find("--screenshot")
		if index + 1 < args.size():
			await panel._preview()
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png(args[index + 1])
	panel.queue_free()
	await process_frame
	var main = load("res://ui/main.tscn").instantiate()
	main.show_script_at_start = false
	root.add_child(main)
	await process_frame
	main.roles_win.hide()
	var more_items: Array = []
	for button in main.find_children("*", "MenuButton", true, false):
		if button.text.begins_with("More"):
			var popup: PopupMenu = button.get_popup()
			for i in range(popup.item_count):
				more_items.append(popup.get_item_text(i))
	check(not more_items.any(func(t): return "comparison" in t.to_lower()) and "New case…" in more_items, "the More menu has New case and no Live Workshop comparison")
	main.queue_free()
	await process_frame
	print("Live Workshop UI: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		fails += 1
		push_error("FAIL: " + label)
