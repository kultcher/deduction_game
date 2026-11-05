## Clock, fallback and conversation lifecycle checks; visual checks use the real renderer.
extends SceneTree

const Player = preload("res://ui/portrait_ink_player.gd")
const Assets = preload("res://ui/portrait_ink_assets.gd")
const View = preload("res://ui/day_conversation_view.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = Player.new()
	player.advance(60.0)
	assert(player.step_index == 360)
	player.configure({"rate": 12.0})
	player.advance(0.25)
	assert(player.step_index == 363) # Rate changes cannot reinterpret the preceding minute.
	player.configure({"rate": 2.0, "displacement": 3.0})
	player.pulse()
	player.advance(0.5)
	assert(player.step_index == 364)
	var phase: float = player.phase
	player.advance(20.0, false)
	assert(player.phase == phase)
	player.paused = true
	player.advance(20.0)
	assert(player.phase == phase)
	player.paused = false
	player.mode = "still"
	player.advance(20.0)
	assert(player.phase == phase)
	player.mode = "original"
	assert(player.material_for(load(Assets.entry("edda", "neutral").source)) == null)
	assert(Assets.entry("edda", "harsh").is_empty())
	var v = View.new()
	root.add_child(v)
	await process_frame
	v.begin("edda", "Edda")
	var source: Texture2D = v.portrait.texture
	assert(source.resource_path == Assets.entry("edda", "neutral").source)
	v.set_portrait_ink_mode("animated")
	assert(v.portrait.texture == source and v.portrait.material != null)
	v._process(0.5)
	var tick: int = v.ink_player.step_index
	v.set_expression("harsh")
	assert(v.portrait.material == null) # No neutral overlay is pasted onto another pose.
	assert(v.previous_portrait.texture == source and v.previous_portrait.material != null)
	assert(v.ink_player.step_index == tick) # Expression changes preserve the shared phase.
	v.set_expression("neutral")
	assert(v.portrait.texture == source and v.portrait.material != null)
	v.hide()
	v._process(10.0)
	assert(v.ink_player.step_index == tick)
	v.show()
	v.show_item("Evidence", null, "A clue.")
	v._process(10.0)
	assert(v.portrait.material == null and v.ink_player.step_index == tick)
	v.queue_free()
	var lab = load("res://ui/line_boil_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	assert(lab.portraits.size() == 3)
	assert(lab.portraits[0].texture == lab.portraits[1].texture)
	assert(lab.portraits[1].texture == lab.portraits[2].texture)
	assert(lab.portraits[0].material == null and lab.portraits[1].material != null)
	lab.set_process(false)
	lab.reset_clock()
	lab._process(0.5)
	assert(lab.player.step_index == 3 and lab.still_player.step_index == 0)
	lab.hide()
	lab._process(10.0)
	assert(lab.player.step_index == 3)
	lab.show()
	lab.controls.protect_face.button_pressed = false
	assert(not lab.player.settings.protect_face and lab.player.settings.protect_edge)
	lab.controls.protect_face.button_pressed = true
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	assert(lab.compare.get_global_rect().position.y < 300, "Toolbar labels must not wrap into tall one-letter columns")
	lab.set_reading(true)
	lab._process(0.5)
	assert(lab.conversation.ink_player.step_index >= 3)
	assert(lab.conversation.speech.visible_characters > 0)
	lab.reading_mode_opt.select(2)
	lab.reading_mode_opt.item_selected.emit(2)
	assert(lab.conversation.portrait.material == null)
	lab.reading_mode_opt.select(0)
	lab.reading_mode_opt.item_selected.emit(0)
	assert(lab.conversation.portrait.material != null)
	lab.set_expression("harsh")
	assert(lab.portraits.all(func(p): return p.material == null))
	lab.queue_free()
	await process_frame
	print("Portrait ink checks passed")
	quit()
