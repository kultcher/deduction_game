## Portable input/output specimens for a future inference implementation.
## -- --record rewrites the reference intentionally; ordinary execution only verifies.
extends SceneTree
const Scenario = preload("res://workshop/scenario.gd")
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const PATH = "res://tests/fixtures/workshop_checkpoint_v5.json"
var failures = 0

func _init() -> void:
	# The reference is model v5's output: verify the legacy engine, kept for comparison.
	# tools/test_case_eval.gd compares CaseEval against the same specimens.
	Jury.engine = "legacy"
	if "--record" in OS.get_cmdline_user_args():
		_record()
		return
	var file = FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Missing Workshop checkpoint reference.")
		quit(1)
		return
	var data = JSON.parse_string(file.get_as_text())
	var checks = 0
	for example in data.examples:
		var actual = _summary(Jury.evaluate(example.view, example.case, example.listener.duplicate(true)))
		for key in ["stance", "reasoning", "compatible", "effects", "claims", "agreement"]:
			checks += 1
			if not _equal(actual[key], example.expected[key]):
				failures += 1
				push_error("Checkpoint mismatch: %s / %s" % [example.name, key])
	print("Workshop checkpoint: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _record() -> void:
	var examples: Array = []
	for kind in ["core", "movement", "poison", "revenant"]:
		var scenario = Scenario.generate(692, kind)
		var value = Solver.empty_case()
		value.conclusion = {"type": "evil", "target": scenario.slots.demon, "at": scenario.public_view.alignment_epoch}
		value.cards = ["survey", "rumor", "dowse"]
		if kind == "movement":
			value.cards.append_array(["vigil3", "soot2", "evening2", "soot3", "evening3"])
		elif kind == "poison":
			value.conclusion.target = scenario.slots.scion
			value.cards.append_array(["dowse_recovered", "vial1"])
			value.faults = {"night1": {"type": "poisoned", "window": "night1", "basis": "vial1"}}
		elif kind == "revenant":
			value.cards.append_array(["curse_warning", "totem_found"])
			value.conclusion.target = scenario.slots.rumormonger
			value.conclusion.at = "during curse"
		var listener: Dictionary = scenario.jury[3].duplicate(true)
		examples.append({"name": kind, "view": scenario.public_view, "case": value, "listener": listener.duplicate(true),
			"expected": _summary(Jury.evaluate(scenario.public_view, value, listener))})
	var core: Dictionary = examples[0]
	var canvas = Canvas.new(core.view)
	canvas.mockup()
	var converging = canvas.compile(canvas.selected)
	examples.append({"name": "converging_intermediates", "view": core.view, "case": converging,
		"listener": core.listener.duplicate(true), "expected": _summary(Jury.evaluate(core.view, converging, core.listener.duplicate(true)))})
	var marked_bart = Solver.empty_case()
	marked_bart.cards = ["survey"]
	marked_bart.conclusion = core.case.conclusion.duplicate(true)
	marked_bart.positions = {"bart": "marked"}
	examples.append({"name": "surveyor_could_be_marked", "view": core.view, "case": marked_bart,
		"listener": core.listener.duplicate(true), "expected": _summary(Jury.evaluate(core.view, marked_bart, core.listener.duplicate(true)))})
	DirAccess.make_dir_recursive_absolute("res://tests/fixtures")
	var file = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write checkpoint reference.")
		quit(1)
		return
	file.store_string(JSON.stringify({"format": "demonologist-workshop-reference-1", "reference_commit": "5d30513",
		"meaning": "Specimen inputs contain permitted evidence and juror state, never generator truth. Numerical values document experimental model v5, not permanent design requirements.",
		"examples": examples}, "\t") + "\n")
	print("Recorded %d portable Workshop examples." % examples.size())
	quit()

func _summary(result: Dictionary) -> Dictionary:
	var effects = {}
	for person in result.effects:
		effects[person] = result.effects[person].requested
	var claims: Array = []
	for claim in result.claims:
		claims.append({"conclusion": claim.conclusion, "stance": claim.stance, "status": claim.status})
	return {"stance": result.stance, "reasoning": result.reasoning.status, "compatible": result.assessment.compatible,
		"agreement": result.support_model.agreement, "effects": effects, "claims": claims}

func _equal(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < 0.000001
	if a is Dictionary and b is Dictionary:
		return a.size() == b.size() and a.keys().all(func(key): return b.has(key) and _equal(a[key], b[key]))
	if a is Array and b is Array:
		return a.size() == b.size() and range(a.size()).all(func(i): return _equal(a[i], b[i]))
	return a == b
