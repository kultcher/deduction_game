## Phase 3: real log/profile rendering and mouse interaction through nested role hints.
## godot --headless --path . --script res://tools/test_text_ui.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const LogText = preload("res://ui/log_text.gd")
var fails = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	# Headless windows start at 64x64; use the real UI's layout before hit testing.
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	await _log()
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	scene.show_script_at_start = false
	scene.seed_box.value = 4242
	scene._new_case()
	scene.roles_win.hide()
	await _settle()
	var g = scene.g
	var person = g.w.npcs[0]
	var other = g.w.npcs[1]
	var card_text = "%s says %s could be the Seer, not the Poisoner. [b]literal[/b]" % [person.name, other.name]
	var number = g.add_card({"kind": "opinion", "source": person.id, "subject": [other.id], "text": card_text})
	var original = JSON.stringify(g.board)
	var rng_state = g.w.rng.state
	person.claim_public = false
	person.max_tier = 0
	person.claimed_role = "seer"
	scene._select_person(person.id)
	var profile = scene.profile
	_check(profile.claim_label.get_parsed_text() == "No claim yet." and profile.claim_icon.texture == null, "formatting does not expose an undisclosed role claim")
	person.max_tier = 3
	profile.refresh()
	await _settle()
	_check(profile.claim_label.get_parsed_text() == "Claims: Seer (told you privately)", "a disclosed claim keeps its private provenance and readable role name")
	_check(_hint_point(profile.claim_label, C.ROLES["seer"]["desc"]).x >= 0, "the disclosed claim's role name has the public role tooltip")
	profile.tab = 1
	profile.refresh()
	await _settle()
	var shown = profile.body.get_parsed_text()
	_check("#%d" % number in shown and "[b]literal[/b]" in shown, "Their claims shows the card while treating bracketed content literally")
	_check("private" in shown and "D1M" in shown, "card entries retain original time and disclosure information")
	var seer_at = _hint_point(profile.body, C.ROLES["seer"]["desc"])
	var evil_at = _hint_point(profile.body, C.ROLES["poisoner"]["desc"])
	_check(seer_at.x >= 0 and evil_at.x >= 0, "good and evil role words inside a card link both expose their own tooltips")
	if seer_at.x >= 0:
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(profile.body.global_position + seer_at), "the role interaction point lies inside the actual viewport")
		await _move(profile.body.global_position + seer_at)
		_check(profile.body.get_local_mouse_position().distance_to(seer_at) < 1.0, "synthetic motion updates the pointer used by rich-text hover")
		_check(profile._hovered_card == number, "hovering a role hint retains the enclosing card target")
		await _click(profile.body.global_position + seer_at, MOUSE_BUTTON_RIGHT)
		_check(scene.case_view.card_menu.visible and scene.case_view._context_card == number, "right-clicking the role text opens the enclosing card's actions")
		scene.case_view.card_menu.hide()
		await _click(profile.body.global_position + seer_at, MOUSE_BUTTON_LEFT)
		_check(scene.case_view.visible and scene.case_state.selected_card == number, "left-clicking role text still follows the enclosing card link")
	var cv = scene.case_view
	cv.visible = true
	cv.set_panel_open("profile", true)
	cv.profile.show_person(person.id)
	cv.profile.tab = 1
	cv.profile.refresh()
	await _settle()
	_check("[b]literal[/b]" in cv.profile.body.get_parsed_text() and _hint_point(cv.profile.body, C.ROLES["seer"]["desc"]).x >= 0, "the case-board profile uses the same formatted card content and role hints")
	cv.profile.show_person(other.id)
	cv.profile.tab = 2
	cv.profile.refresh()
	await _settle()
	_check("#%d" % number in cv.profile.body.get_parsed_text() and _hint_point(cv.profile.body, C.ROLES["poisoner"]["desc"]).x >= 0, "About them also formats names and roles in relevant card entries")
	_check(JSON.stringify(g.board) == original and g.w.rng.state == rng_state, "rendering and profile interactions do not modify evidence or simulation randomness")
	scene.free()
	print("TEXT UI FAILURES: %d" % fails)
	quit(1 if fails else 0)

func _log() -> void:
	var label = RichTextLabel.new()
	label.size = Vector2(1000, 240)
	UITheme.rich_text_fonts(label, UITheme.serif())
	root.add_child(label)
	var log_text = LogText.new()
	log_text.append_to(label, 'Bartholomew: "Fenwick could be the Seer, not the Poisoner."  [case board: #12, #13]')
	await _settle()
	var plain = label.get_parsed_text()
	_check('Bartholomew: "Fenwick could be the ' in plain and "#12, #13" in plain, "the log retains speaker, spoken words and card references")
	_check(_hint_point(label, C.ROLES["seer"]["desc"]).x >= 0 and _hint_point(label, C.ROLES["poisoner"]["desc"]).x >= 0, "speech exposes public tooltips for each mentioned role")
	var count = label.get_total_character_count()
	log_text.append_to(label, "=== Day 2, Morning ===\nDawn breaks. [color=red]literal[/color]")
	_check(label.get_total_character_count() > count and "#12" in label.get_parsed_text() and "[color=red]literal[/color]" in label.get_parsed_text(), "new log entries append without rebuilding old content or parsing source markup")
	label.clear()
	log_text.append_to(label, "> ask about Seer [case board: #999]")
	await _settle()
	_check("> ask about Seer [case board: #999]" in label.get_parsed_text() and _hint_point(label, C.ROLES["seer"]["desc"]).x < 0, "typed commands remain literal and do not acquire role hints or generated card links")
	var normal = label.get_theme_font("normal_font") as SystemFont
	var bold = label.get_theme_font("bold_font") as SystemFont
	_check(normal != null and bold != null and normal.font_names == bold.font_names and bold.font_weight == 700, "bold rich-text faces keep the normal font family")
	label.free()

func _hint_point(label: RichTextLabel, description: String) -> Vector2:
	for y in range(4, int(label.size.y), 5):
		for x in range(2, int(label.size.x), 5):
			var at = Vector2(x, y)
			if description in label.get_tooltip(at):
				return at
	return Vector2(-1, -1)

func _settle() -> void:
	for i in range(5):
		await process_frame

func _move(at: Vector2) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await _settle()

func _click(at: Vector2, button: int) -> void:
	await _move(at)
	var event = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1
