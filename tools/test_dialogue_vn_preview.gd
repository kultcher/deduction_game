extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _normalized(value: String) -> String:
	var whitespace = RegEx.new()
	whitespace.compile("\\s+")
	return whitespace.sub(value.replace("\u00a0", " "), " ", true).strip_edges()

func _run() -> void:
	var lab = load("res://ui/dialogue_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	var before: Dictionary = lab.memories.duplicate(true)
	lab._open_vn_preview()
	assert(lab.vn_preview.visible)
	assert(lab.vn_preview.speaker.text == "Agnes")
	assert(_normalized(lab.vn_preview.speech.get_parsed_text()) == _normalized(lab.last_results.agnes.text))
	assert(lab.memories == before)
	lab.vn_preview.choices.select(1)
	lab.vn_preview.choices.item_selected.emit(1)
	assert(lab.vn_preview.speaker.text == "Bartholomew")
	assert(_normalized(lab.vn_preview.speech.get_parsed_text()) == _normalized(lab.last_results.bart.text))
	lab.vn_preview.speak_requested.emit()
	assert(_normalized(lab.vn_preview.speech.get_parsed_text()) == _normalized(lab.last_results.bart.text))
	var sample = {"bart": {"text": "Agnes says the Seer saw Constance.", "cue": ""}}
	lab.vn_preview.show_results(sample)
	var spans: Array = lab.vn_preview.formatter.format_text(sample.bart.text, {"surface": "paper", "speaker_id": "bart", "font_size": 26, "icon_size": 26})
	assert(spans.any(func(span): return span.entity_id == "person:agnes"))
	assert(spans.any(func(span): return span.entity_id == "role:seer" and not span.icon_path.is_empty()))
	assert(_normalized(lab.vn_preview.speech.get_parsed_text()) == _normalized(sample.bart.text))
	lab.vn_preview.hide()
	assert(not lab.vn_preview.visible)
	print("Dialogue VN preview checks passed")
	lab.queue_free()
	quit()
