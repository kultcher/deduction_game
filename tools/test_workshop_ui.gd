## Exercises actual UI signals, slot persistence, file replay and the main-menu entry.
extends SceneTree
const Workshop = preload("res://ui/case_workshop_lab.tscn")
var fails = 0
var checks = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = Workshop.instantiate()
	root.add_child(scene)
	await process_frame
	scene._load_example(3)
	scene.focus_card = "survey"
	scene._refresh_case()
	var block_slot = scene.find_child("Answer_survey_0", true, false)
	check(block_slot != null and block_slot.get_item_text(1).begins_with("Someone on "), "Surveyor controls offer a block without naming a resident")
	block_slot.select(1)
	block_slot.item_selected.emit(1)
	await process_frame
	check(scene.session.case_data.answers.survey.blocks.size() == 1 and scene.session.case_data.answers.survey.positive.is_empty(), "selecting a block preserves an unresolved resident")
	check(scene.find_child("Answer_survey_0", true, false).selected == 1, "the block answer survives the UI rebuild")
	scene._load_example(3)
	var slot = scene.find_child("Answer_dowse_1", true, false)
	slot.select(4)
	slot.item_selected.emit(4)
	await process_frame
	check(scene.session.case_data.answers.dowse.slots[1] == "lian", "an actual answer signal records the chosen slot")
	check(scene.find_child("Answer_dowse_0", true, false).selected == 0, "earlier unanswered slot stays unknown")
	check(scene.find_child("Answer_dowse_1", true, false).selected == 4, "chosen slot survives the UI rebuild")
	# Prevent a duplicate slot while preserving the earlier unknown answer.
	slot = scene.find_child("Answer_dowse_0", true, false)
	slot.select(4)
	slot.item_selected.emit(4)
	await process_frame
	check(scene.find_child("Answer_dowse_0", true, false).selected == 0 and scene.status.text.contains("already fills a slot"), "duplicate slot is blocked with specific feedback and remains unknown")
	scene._load_example(3)
	scene._present()
	scene.remember.button_pressed = true
	scene.venue.select(1)
	scene._present()
	check(scene.session.last_results.all(func(r): return is_zero_approx(r.suspicion_delta)), "UI remembered-mode repetition adds no suspicion")
	var path = "user://workshop-ui-test.json"
	scene._save(path)
	var expected = scene.session.last_results.duplicate(true)
	scene.session.generate(101)
	scene._open(path)
	check(scene.session.last_results == expected, "save/open controls restore the actual experiment")
	check(scene.remember.button_pressed and scene.venue.selected == 1, "open restores discussion mode and venue")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Claim citations are actual controls; choosing a claim does not accept its read.
	scene._load_example(4)
	scene.focus_card = "watch1"
	scene.session.case_data.reasons["agnes:1"] = "gift"
	scene._refresh_case()
	var citation = scene.find_child("Citation_agnes_1", true, false)
	citation.select(1)
	citation.item_selected.emit(1)
	check(scene.session.case_data.citations["agnes:1"] == "claim_lamplighter" and "lamp1" not in scene.session.case_data.cards, "gift citation picker cites Agnes's implicit role claim without accepting her read")
	scene._load_example(5)
	check(not scene.find_child("ConclusionTarget", true, false).visible, "conflict argument hides the irrelevant accused-person picker")
	var scope = scene.find_child("ConflictScope_alibi1", true, false)
	scope.button_pressed = false
	check(scene.analysis.entailment == "unsupported", "removing the alibi from conflict scope changes the actual argument")
	scene._load_example(3)
	scene.find_child("AddReasoningLine", true, false).pressed.emit()
	check(scene.session.case_data.lines.size() == 1 and scene.active_line != "", "adding a line opens its own editable assumptions and evidence")
	scene.find_child("LineEvidence_survey", true, false).button_pressed = true
	check(scene.session.case_data.lines[0].cards == ["survey"], "line evidence selector stores a reference to the existing card")
	scene._load_example(6)
	scene.remember.button_pressed = false
	scene._present()
	var converged: float = scene.session.last_results[3].strength
	var factor = scene.find_child("TestFactorRatio", true, false)
	factor.value = 1.0
	scene._present()
	check(scene.session.last_results[3].strength < converged and scene.analysis.compatible == 2, "the actual test-factor control changes conviction while logical alternatives stay intact")
	scene._save(path)
	var grouped = scene.session.case_data.duplicate(true)
	scene.session.generate(101)
	scene._open(path)
	check(scene.session.case_data == grouped and scene.active_line == "movement", "save/open preserves grouped evidence and supplied factor")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	scene._load_example(3)
	scene._refresh_jury()
	var before_compare = JSON.stringify(scene.session.export_data())
	scene.find_child("CompareInsight_3", true, false).pressed.emit()
	check(scene.reasoning_comparisons[3].size() == 4 and JSON.stringify(scene.session.export_data()) == before_compare, "Compare Insight control evaluates identical jurors without mutating the experiment")
	var mode = scene.find_child("ReasoningMode_3", true, false)
	mode.select(1)
	mode.item_selected.emit(1)
	var confidence_mode = scene.find_child("ConfidenceMode_3", true, false)
	confidence_mode.select(1)
	confidence_mode.item_selected.emit(1)
	scene._present()
	check(scene.session.last_results[3].reasoning.profile != "Full" and scene.session.last_results[3].calculation.confidence_factor == 1.0, "reasoning and confidence controls select bounded search and independent persistence mode")
	scene.remember.button_pressed = true
	scene._present()
	check(scene.session.last_results[3].repeated and is_zero_approx(scene.session.last_results[3].suspicion_delta), "remembered persistence mode does not compound through the Present control")
	scene._save(path)
	var persistent_results = scene.session.last_results.duplicate(true)
	scene.session.generate(101)
	scene._open(path)
	check(scene.session.last_results == persistent_results and scene.session.listeners[3].theories.size() > 0, "Open reconstructs reasoning mode and persistent theories from presentation history")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	scene.queue_free()
	await process_frame
	var main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var original_world = main.g.w
	var original_day: int = main.g.w.day
	main._on_more(4)
	await process_frame
	check(main.case_view.visible and not main.case_view.workshop.is_collapsed(), "More > Case Workshop opens the case board with the Workshop sheet out")
	check(main.g.w == original_world and main.g.w.day == original_day, "opening Workshop preserves the running game's world")
	var editor = main.case_view.workshop.editor
	main.case_view.workshop.collapse()
	main._on_more(4)
	check(main.case_view.workshop.editor == editor, "reopening reuses the Workshop and preserves its draft")
	main.queue_free()
	await process_frame
	print("Workshop UI: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(okay: bool, label: String) -> void:
	checks += 1
	if okay:
		print("PASS: " + label)
	else:
		fails += 1
		push_error("FAIL: " + label)
