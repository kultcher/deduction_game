extends SceneTree
const MainActions = preload("res://ui/main_actions.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")

## Counted checks, not bare assert(): a failure prints a FAIL line instead of hanging the
## run (Steward, Nov 19).
var _checks = 0
var _fails = 0

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	scene.show_script_at_start = false
	scene.seed_box.value = 25923
	scene._new_case()
	scene.roles_win.hide()
	await process_frame
	# Every playable townsperson resolves to their own large portrait.
	for cast_member in C.CAST:
		var id: String = cast_member.id
		scene.conversation_view.begin(id, cast_member.name)
		var texture: Texture2D = scene.conversation_view.portrait.texture
		_check(texture != null and texture.get_size() == Vector2(1024, 1536), "line 21")
		_check(texture == scene.conversation_view._expression_texture(id, "neutral"), "line 22")
		for expression in ["warm", "harsh", "concerned", "sorrowful"]:
			var variant: Texture2D = scene.conversation_view._expression_texture(id, expression)
			_check(variant != null and variant != texture, "line 25")
			_check(variant.get_size() == Vector2(1024, 1536), "line 26")
		_check(scene.conversation_view._expression_texture(id, "invalid") == texture, "line 27")
	var g = scene.g
	var n = g.w.living_good()[0]
	n.loc = "chapel"
	n.working = true
	n.busy_with = ""
	g.moved = false
	MainActions.talk_to_person(scene, n.id)
	_check(g.state == "talk", "line 35")
	_check(scene.conversation_view.visible, "line 36")
	_check(scene.conversation_view.person_id == n.id, "line 37")
	_check(scene.conversation_view.portrait.texture != null, "line 38")
	# Pending requests must not place a wrapping hint in a row of choice buttons.
	g.pending_request = {"kind": "confidence"}
	MainActions.refresh(scene)
	await process_frame
	await process_frame
	var choice_view = scene.conversation_view
	_check(choice_view.action_hint.visible and choice_view.action_hint.text == "Anything else you do counts as no.", "line 45")
	_check(choice_view.action_hint.get_parent() != choice_view.controls, "line 46")
	_check(choice_view.action_hint.size.x > 150, "line 47")
	var choice_buttons = choice_view.controls.get_children().filter(func(c): return c is Button)
	_check(choice_buttons.size() >= 2, "line 49")
	for button in choice_buttons:
		_check(button.size.y < 100, "line 51")
	g.pending_request = {}
	MainActions.refresh(scene)
	_check(not choice_view.action_hint.visible, "line 54")
	var view = scene.conversation_view
	var neutral: Texture2D = view.portrait.texture
	view.set_expression("warm")
	_check(view.portrait.texture != neutral and view.previous_portrait.texture == neutral, "line 58")
	_check(view.previous_portrait.visible, "line 59")
	view.set_expression("harsh")
	_check(view.previous_portrait.visible, "line 61")
	view.portrait_tween.custom_step(1.0)
	_check(not view.previous_portrait.visible, "line 63")
	view.begin(n.id, n.name)
	_check(view.portrait.texture == neutral and not view.previous_portrait.visible, "line 65")
	_check(view.speech.visible_characters == -1 and not view.reveal_hint.visible, "line 66")
	# A fresh response reveals at the lab pace, pauses over the map, and can be skipped.
	view.consume([{"k": "speech", "speaker": n.id, "text": "A long enough response for the reveal to be observed clearly."}])
	_check(view.speech.visible_characters == 0 and view.reveal_hint.visible, "line 69")
	view._process(0.1)
	_check(view.speech.visible_characters == 9, "line 71")
	view.hide()
	view._process(1.0)
	_check(view.speech.visible_characters == 9, "line 74")
	view.show()
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	view._on_dialogue_input(click)
	_check(view.speech.visible_characters == -1 and not view.reveal_hint.visible, "line 80")
	view.consume([{"k": "speech", "speaker": n.id, "text": "A different answer arrives."}])
	_check(view.speech.visible_characters == 0 and view.reveal_hint.visible, "line 82")
	view._process(10.0)
	_check(view.speech.visible_characters == view.reveal_total and not view.reveal_hint.visible, "line 84")
	view.begin(n.id, n.name)
	# Curated cues follow spoken delivery, including through the real event boundary.
	var speaker_data = {"id": "isolde", "name": "Isolde"}
	var fearful: Dictionary = Mind.say_voiced(speaker_data, "fear_gift_refusal", "fallback")
	var practical: Dictionary = Mind.say_voiced({"id": "hollis", "name": "Hollis"}, "fear_gift_refusal", "fallback")
	_check(fearful.get("expression") == "concerned", "line 90")
	var same_words_other_alignment: Dictionary = Mind.say_voiced({"id": "isolde", "name": "Isolde", "alignment": "evil"}, "fear_gift_refusal", "fallback")
	_check(same_words_other_alignment.text == fearful.text and same_words_other_alignment.expression == fearful.expression, "line 92")
	_check(not practical.has("expression"), "line 93")
	_check(not Mind.say_voiced(speaker_data, "request_confidence", "fallback").has("expression"), "line 94")
	var before_events: Array = g.events.duplicate()
	g.events.clear()
	g._line(fearful)
	_check(g.events.size() == 1 and g.events[0].get("expression") == "concerned", "line 98")
	view.begin("isolde", "Isolde")
	view.consume(g.events)
	_check(view.portrait.texture == view._expression_texture("isolde", "concerned"), "line 101")
	view.consume([{"k": "speech", "speaker": "isolde", "text": "Thank you.", "expression": "warm", "expression_strength": 1},
		{"k": "speech", "speaker": "isolde", "text": "I'm frightened.", "expression": "concerned", "expression_strength": 2},
		{"k": "speech", "speaker": "bart", "text": "Other speaker", "expression": "harsh", "expression_strength": 9}])
	_check(view.portrait.texture == view._expression_texture("isolde", "concerned"), "line 105")
	view.consume([{"k": "speech", "speaker": "isolde", "text": "I was afraid.", "expression": "concerned", "expression_strength": 2},
		{"k": "speech", "speaker": "isolde", "text": "I won't stand for it.", "expression": "harsh", "expression_strength": 2}])
	_check(view.portrait.texture == view._expression_texture("isolde", "harsh"), "line 108")
	view.consume([{"k": "narration", "text": "No speech"}])
	_check(view.portrait.texture == view._expression_texture("isolde", "harsh"), "line 110")
	view.consume([{"k": "speech", "speaker": "isolde", "text": "That's not for me to say."}])
	_check(view.portrait.texture == view._expression_texture("isolde", "neutral"), "line 112")
	g.events = before_events
	view.begin(n.id, n.name)
	_check(scene.conversation_view.controls.get_children().any(func(c): return c is Button and c.text == "Leave"), "line 115")
	# The breadcrumb row moves between the map and the conversation (Michael, Nov 28).
	var Crumbs = preload("res://ui/nav_crumbs.gd")
	var town: Array = Crumbs.crumbs(scene).filter(func(c): return c.label == "Town")
	_check(town.size() == 1 and town[0].go.is_valid(), "line 117")
	town[0].go.call()
	_check(not scene.conversation_view.visible and g.state == "talk", "line 119")
	_check(Crumbs.crumbs(scene).back().label == n.name, "line 120")
	# The conversation's options wait while the map is up (Michael, Nov 17).
	_check(not scene.actions.get_children().any(func(c): return c is Button and c.text == "Leave"), "line 122")
	_check(not scene.actions.get_children().any(func(c): return c is Button and c.text in ["Look at the map", "Look at conversation"]), "line 123")
	Crumbs.crumbs(scene).back().go.call()
	_check(scene.conversation_view.visible, "line 125")
	scene._run("ask gift")
	var said: Array = g.last_events.filter(func(e): return e.get("k") == "speech" and e.get("speaker") == n.id)
	if not said.is_empty() and g.state == "talk":
		_check(scene.conversation_view.lines == said.map(func(e): return e.text), "line 129")
	var before = scene.conversation_view.lines.duplicate()
	scene._run("help")
	if g.state == "talk":
		_check(scene.conversation_view.lines == before, "line 133")
		scene._run("bye")
	# Leaving closes the view, unless someone steps up to the player as the next phase
	# begins: the approach plays in the same view (triage 2.8).
	_check(not scene.conversation_view.visible or (g.state == "approach" and scene.approach_stage != ""), "line 137")
	# An automatically exhausted conversation keeps its last response on screen.
	scene._new_case()
	n = scene.g.w.living_good()[0]
	n.loc = "chapel"
	n.working = true
	n.busy_with = ""
	scene.g.moved = false
	MainActions.talk_to_person(scene, n.id)
	scene.g.questions_left = 1
	scene._run("ask night")
	_check(scene.g.state != "talk", "line 148")
	_check(scene.conversation_finished and scene.conversation_view.visible, "line 149")
	var final_speech: Array = scene.g.last_events.filter(func(e): return e.get("k") == "speech" and e.get("speaker") == n.id)
	_check(not final_speech.is_empty(), "line 151")
	_check(scene.conversation_view.lines == final_speech.map(func(e): return e.text), "line 152")
	var final_buttons: Array = scene.conversation_view.controls.get_children().filter(func(c): return c is Button)
	_check(final_buttons.size() == 1 and final_buttons[0].text == "Leave conversation", "line 154")
	_check(scene.actions.get_child_count() == 0 and not scene.input.editable, "line 155")
	var phase_before = scene.g.w.phase
	scene._run("wait")
	_check(scene.g.w.phase == phase_before and scene.conversation_finished, "line 158")
	final_buttons[0].pressed.emit()
	_check(not scene.conversation_finished and scene.input.editable, "line 160")
	_check(not scene.conversation_view.visible or (scene.g.state == "approach" and scene.approach_stage != ""), "line 161")
	# Evening can start a streamed meeting; its speakers wait until dismissal.
	scene._new_case()
	n = scene.g.w.living_good()[0]
	n.loc = "chapel"
	n.working = true
	n.busy_with = ""
	scene.g.moved = false
	MainActions.talk_to_person(scene, n.id)
	scene.g.w.phase = C.EVENING
	scene.g.questions_left = 1
	scene._run("ask night")
	_check(scene.conversation_finished and scene.conversation_view.visible, "line 173")
	_check(scene.g.state == "meeting" and scene.g.meeting_streaming(), "line 174")
	_check(not scene.meeting_view.visible, "line 175")
	var progress_before: int = scene.g._testimony.get("i", 0)
	await process_frame
	_check(scene.g._testimony.get("i", 0) == progress_before, "line 178")
	scene.conversation_view.controls.get_children().filter(func(c): return c is Button)[0].pressed.emit()
	_check(not scene.conversation_finished and scene.meeting_view.visible, "line 180")
	scene.finish_streaming()
	await process_frame
	print("Day conversation view: %d checks, %d failures" % [_checks, _fails])
	scene.queue_free()
	await process_frame
	quit(1 if _fails else 0)
