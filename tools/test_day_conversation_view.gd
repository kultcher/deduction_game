extends SceneTree
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")

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
		assert(texture != null and texture.get_size() == Vector2(1024, 1536))
		assert(texture == scene.conversation_view._expression_texture(id, "neutral"))
		for expression in ["warm", "harsh", "concerned", "sorrowful"]:
			var variant: Texture2D = scene.conversation_view._expression_texture(id, expression)
			assert(variant != null and variant != texture)
			assert(variant.get_size() == Vector2(1024, 1536))
		assert(scene.conversation_view._expression_texture(id, "invalid") == texture)
	var g = scene.g
	var n = g.w.living_good()[0]
	n.loc = "chapel"
	n.working = true
	n.busy_with = ""
	g.moved = false
	scene._talk_to_person(n.id)
	assert(g.state == "talk")
	assert(scene.conversation_view.visible)
	assert(scene.conversation_view.person_id == n.id)
	assert(scene.conversation_view.portrait.texture != null)
	var view = scene.conversation_view
	var neutral: Texture2D = view.portrait.texture
	view.set_expression("warm")
	assert(view.portrait.texture != neutral and view.previous_portrait.texture == neutral)
	assert(view.previous_portrait.visible)
	view.set_expression("harsh")
	assert(view.previous_portrait.visible)
	view.portrait_tween.custom_step(1.0)
	assert(not view.previous_portrait.visible)
	view.begin(n.id, n.name)
	assert(view.portrait.texture == neutral and not view.previous_portrait.visible)
	assert(view.speech.visible_characters == -1 and not view.reveal_hint.visible)
	# A fresh response reveals at the lab pace, pauses over the map, and can be skipped.
	view.consume([{"k": "speech", "speaker": n.id, "text": "A long enough response for the reveal to be observed clearly."}])
	assert(view.speech.visible_characters == 0 and view.reveal_hint.visible)
	view._process(0.1)
	assert(view.speech.visible_characters == 9)
	view.hide()
	view._process(1.0)
	assert(view.speech.visible_characters == 9)
	view.show()
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	view._on_dialogue_input(click)
	assert(view.speech.visible_characters == -1 and not view.reveal_hint.visible)
	view.consume([{"k": "speech", "speaker": n.id, "text": "A different answer arrives."}])
	assert(view.speech.visible_characters == 0 and view.reveal_hint.visible)
	view._process(10.0)
	assert(view.speech.visible_characters == view.reveal_total and not view.reveal_hint.visible)
	view.begin(n.id, n.name)
	# Curated cues follow spoken delivery, including through the real event boundary.
	var speaker_data = {"id": "isolde", "name": "Isolde"}
	var fearful: Dictionary = Mind.say_voiced(speaker_data, "fear_gift_refusal", "fallback")
	var practical: Dictionary = Mind.say_voiced({"id": "hollis", "name": "Hollis"}, "fear_gift_refusal", "fallback")
	assert(fearful.get("expression") == "concerned")
	var same_words_other_alignment: Dictionary = Mind.say_voiced({"id": "isolde", "name": "Isolde", "alignment": "evil"}, "fear_gift_refusal", "fallback")
	assert(same_words_other_alignment.text == fearful.text and same_words_other_alignment.expression == fearful.expression)
	assert(not practical.has("expression"))
	assert(not Mind.say_voiced(speaker_data, "request_confidence", "fallback").has("expression"))
	var before_events: Array = g.events.duplicate()
	g.events.clear()
	g._line(fearful)
	assert(g.events.size() == 1 and g.events[0].get("expression") == "concerned")
	view.begin("isolde", "Isolde")
	view.consume(g.events)
	assert(view.portrait.texture == view._expression_texture("isolde", "concerned"))
	view.consume([{"k": "speech", "speaker": "isolde", "text": "Thank you.", "expression": "warm", "expression_strength": 1},
		{"k": "speech", "speaker": "isolde", "text": "I'm frightened.", "expression": "concerned", "expression_strength": 2},
		{"k": "speech", "speaker": "bart", "text": "Other speaker", "expression": "harsh", "expression_strength": 9}])
	assert(view.portrait.texture == view._expression_texture("isolde", "concerned"))
	view.consume([{"k": "speech", "speaker": "isolde", "text": "I was afraid.", "expression": "concerned", "expression_strength": 2},
		{"k": "speech", "speaker": "isolde", "text": "I won't stand for it.", "expression": "harsh", "expression_strength": 2}])
	assert(view.portrait.texture == view._expression_texture("isolde", "harsh"))
	view.consume([{"k": "narration", "text": "No speech"}])
	assert(view.portrait.texture == view._expression_texture("isolde", "harsh"))
	view.consume([{"k": "speech", "speaker": "isolde", "text": "That's not for me to say."}])
	assert(view.portrait.texture == view._expression_texture("isolde", "neutral"))
	g.events = before_events
	view.begin(n.id, n.name)
	assert(scene.conversation_view.controls.get_children().any(func(c): return c is Button and c.text == "Leave"))
	var buttons = scene.actions.get_children().filter(func(c): return c is Button and c.text == "Look at the map")
	assert(buttons.size() == 1)
	buttons[0].pressed.emit()
	assert(not scene.conversation_view.visible and g.state == "talk")
	assert(scene.actions.get_children().any(func(c): return c is Button and c.text == "Look at conversation"))
	assert(scene.actions.get_children().any(func(c): return c is Button and c.text == "Leave"))
	scene.actions.get_children().filter(func(c): return c is Button and c.text == "Look at conversation")[0].pressed.emit()
	assert(scene.conversation_view.visible)
	scene._run("ask gift")
	var said: Array = g.last_events.filter(func(e): return e.get("k") == "speech" and e.get("speaker") == n.id)
	if not said.is_empty() and g.state == "talk":
		assert(scene.conversation_view.lines == said.map(func(e): return e.text))
	var before = scene.conversation_view.lines.duplicate()
	scene._run("help")
	if g.state == "talk":
		assert(scene.conversation_view.lines == before)
		scene._run("bye")
	assert(not scene.conversation_view.visible)
	# An automatically exhausted conversation keeps its last response on screen.
	scene._new_case()
	n = scene.g.w.living_good()[0]
	n.loc = "chapel"
	n.working = true
	n.busy_with = ""
	scene.g.moved = false
	scene._talk_to_person(n.id)
	scene.g.questions_left = 1
	scene._run("ask night")
	assert(scene.g.state != "talk")
	assert(scene.conversation_finished and scene.conversation_view.visible)
	var final_speech: Array = scene.g.last_events.filter(func(e): return e.get("k") == "speech" and e.get("speaker") == n.id)
	assert(not final_speech.is_empty())
	assert(scene.conversation_view.lines == final_speech.map(func(e): return e.text))
	var final_buttons: Array = scene.conversation_view.controls.get_children().filter(func(c): return c is Button)
	assert(final_buttons.size() == 1 and final_buttons[0].text == "Leave conversation")
	assert(scene.actions.get_child_count() == 0 and not scene.input.editable)
	var phase_before = scene.g.w.phase
	scene._run("wait")
	assert(scene.g.w.phase == phase_before and scene.conversation_finished)
	final_buttons[0].pressed.emit()
	assert(not scene.conversation_finished and not scene.conversation_view.visible and scene.input.editable)
	# Evening can start a streamed meeting; its speakers wait until dismissal.
	scene._new_case()
	n = scene.g.w.living_good()[0]
	n.loc = "chapel"
	n.working = true
	n.busy_with = ""
	scene.g.moved = false
	scene._talk_to_person(n.id)
	scene.g.w.phase = C.EVENING
	scene.g.questions_left = 1
	scene._run("ask night")
	assert(scene.conversation_finished and scene.conversation_view.visible)
	assert(scene.g.state == "meeting" and scene.g.meeting_streaming())
	assert(not scene.meeting_view.visible)
	var progress_before: int = scene.g._testimony.get("i", 0)
	await process_frame
	assert(scene.g._testimony.get("i", 0) == progress_before)
	scene.conversation_view.controls.get_children().filter(func(c): return c is Button)[0].pressed.emit()
	assert(not scene.conversation_finished and scene.meeting_view.visible)
	scene.finish_streaming()
	await process_frame
	print("Day conversation view checks passed")
	scene.queue_free()
	await process_frame
	quit()
