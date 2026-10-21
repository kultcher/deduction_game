## UI-independent controlled experiment, version history and reproducible export.
extends RefCounted

const Scenario = preload("res://workshop/scenario.gd")
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")

var scenario: Dictionary
var case_data: Dictionary
var baseline: Array = []
var listeners: Array = []
var history: Array = []
var last_results: Array = []

func _init(seed_value: int = 692) -> void:
	generate(seed_value)

func generate(seed_value: int) -> void:
	scenario = Scenario.generate(seed_value)
	case_data = Solver.empty_case()
	case_data.conclusion.target = scenario.slots.demon
	baseline = scenario.jury.duplicate(true)
	reset_discussion()

func reset_discussion() -> void:
	listeners = baseline.duplicate(true)
	history = []
	last_results = []

func revise() -> void:
	case_data.version += 1

func present(remember: bool = false, venue: String = "private") -> Array:
	if not remember:
		listeners = baseline.duplicate(true)
	last_results = []
	for listener in listeners:
		last_results.append(Jury.evaluate(scenario.public_view, case_data, listener, {"venue": venue}))
	history.append({"case": case_data.duplicate(true), "remember": remember, "venue": venue, "jury_settings": baseline.duplicate(true), "results": last_results.duplicate(true)})
	return last_results

func compare_reasoning(index: int) -> Array:
	# Independent clones hold identity, private knowledge and every social input fixed.
	# Comparisons never become presentations or alter remembered theories.
	var result: Array = []
	for spec in [["full", 0.9], ["bounded", 0.1], ["bounded", 0.5], ["bounded", 0.9]]:
		var clone: Dictionary = baseline[index].duplicate(true)
		clone.reasoning_mode = spec[0]
		clone.insight = spec[1]
		clone.confidence_mode = "scale"
		result.append(Jury.evaluate(scenario.public_view, case_data, clone))
	return result

func export_data(include_truth: bool = false) -> Dictionary:
	var result = {"format": "demonologist-case-workshop-3", "seed": scenario.public_view.seed,
		"public_view": scenario.public_view.duplicate(true), "case": case_data.duplicate(true),
		"jury_settings": baseline.duplicate(true), "history": history.duplicate(true)}
	if include_truth:
		result["developer_truth"] = {"people": scenario.truth, "timeline": scenario.timeline}
	return result

func restore(data: Dictionary) -> String:
	# Load only this fixture format. Validate the complete experiment before mutating
	# the session, then replay its presentations instead of trusting stored outcomes.
	if data.get("format", "") != "demonologist-case-workshop-3" or not data.get("seed") is float and not data.get("seed") is int:
		return "This experiment uses a different Workshop model. Version 3 is required for reliable replay."
	if not is_finite(float(data.seed)) or data.seed < 1 or data.seed > 2147483647 or float(int(data.seed)) != float(data.seed):
		return "Invalid scenario seed."
	var candidate = get_script().new(int(data.seed))
	if data.get("public_view") != JSON.parse_string(JSON.stringify(candidate.scenario.public_view)):
		return "The scenario differs from this Workshop version; it cannot be replayed reliably."
	var error = candidate.validate_case(data.get("case"))
	if error != "":
		return error
	error = candidate.validate_jury(data.get("jury_settings"))
	if error != "":
		return error
	if not data.get("history") is Array or data.history.size() > 200:
		return "Invalid or oversized presentation history (maximum 200)."
	for entry in data.history:
		if not entry is Dictionary or not entry.get("remember") is bool or entry.get("venue", "") not in ["private", "meeting", "nomination"]:
			return "Invalid presentation history."
		error = candidate.validate_case(entry.get("case"))
		if error == "":
			error = candidate.validate_jury(entry.get("jury_settings"))
		if error != "":
			return error
		candidate.case_data = entry.case.duplicate(true)
		candidate.case_data.version = int(candidate.case_data.version)
		candidate.baseline = entry.jury_settings.duplicate(true)
		# Settings may have been changed during remembered discussion.
		for i in range(candidate.listeners.size()):
			var listener: Dictionary = candidate.listeners[i]
			listener.trust = candidate.baseline[i].trust
			listener.confidence = candidate.baseline[i].confidence
			for field in ["insight", "reasoning_mode", "confidence_mode"]:
				listener[field] = candidate.baseline[i][field]
			listener.npc_trust = candidate.baseline[i].npc_trust.duplicate(true)
			listener.reading_reliability = candidate.baseline[i].reading_reliability.duplicate(true)
			for person in candidate.scenario.public_view.people:
				var applied = 0.0
				for effect in listener.ledger.values():
					if effect.target == person.id:
						applied += effect.applied
				listener.suspicion[person.id] = snappedf(candidate.baseline[i].suspicion[person.id] + applied, 0.000000001)
		candidate.present(entry.remember, entry.venue)
	scenario = candidate.scenario
	case_data = data.case.duplicate(true)
	case_data.version = int(case_data.version)
	baseline = data.jury_settings.duplicate(true)
	listeners = candidate.listeners
	history = candidate.history
	last_results = candidate.last_results
	# Also restore settings edited after the final recorded presentation.
	for i in range(listeners.size()):
		listeners[i].trust = baseline[i].trust
		listeners[i].confidence = baseline[i].confidence
		for field in ["insight", "reasoning_mode", "confidence_mode"]:
			listeners[i][field] = baseline[i][field]
		listeners[i].npc_trust = baseline[i].npc_trust.duplicate(true)
		listeners[i].reading_reliability = baseline[i].reading_reliability.duplicate(true)
		for person in scenario.public_view.people:
			var applied = 0.0
			for effect in listeners[i].ledger.values():
				if effect.target == person.id:
					applied += effect.applied
			listeners[i].suspicion[person.id] = snappedf(baseline[i].suspicion[person.id] + applied, 0.000000001)
	return ""

func validate_case(value) -> String:
	if not value is Dictionary:
		return "Missing case."
	if value.get("id") != "case-1" or not value.get("version") is float and not value.get("version") is int:
		return "Invalid case identity or version."
	if not is_finite(float(value.version)) or value.version < 1 or float(int(value.version)) != float(value.version):
		return "Invalid case version."
	if not value.get("cards") is Array or not value.get("positions") is Dictionary or not value.get("answers") is Dictionary or not value.get("reasons") is Dictionary:
		return "Invalid case choices."
	var ids: Array = scenario.public_view.people.map(func(p): return p.id)
	var card_ids: Array = scenario.public_view.cards.map(func(c): return c.id)
	if not value.get("derived", []) is Array or value.get("derived", []).size() > 8:
		return "Invalid derived questions (maximum eight)."
	for question in value.get("derived", []):
		if not question is Dictionary or not question.get("id") is String or question.id in card_ids or not question.get("text") is String or question.text.length() > 240 or not question.get("supports") is Array or question.supports.is_empty() or question.supports.size() > scenario.public_view.cards.size() or not question.supports.all(func(id): return id in scenario.public_view.cards.map(func(c): return c.id)):
			return "Invalid derived question provenance."
		card_ids.append(question.id)
	if not value.cards.all(func(id): return id in card_ids) or value.cards.size() > card_ids.size():
		return "Unknown evidence card."
	var conclusion = value.get("conclusion")
	if not conclusion is Dictionary or conclusion.get("type") not in ["evil", "good", "marked", "suspicious", "conflict"] or conclusion.get("target") not in ids or conclusion.get("at") != scenario.public_view.alignment_epoch:
		return "Invalid conclusion or time."
	for id in value.positions:
		if id not in ids or value.positions[id] not in ["good", "evil", "marked"]:
			return "Invalid alignment choice."
	for id in value.answers:
		var answer = value.answers[id]
		if id not in card_ids or not answer is Dictionary or not answer.get("positive") is Array:
			return "Invalid card answer."
		if not answer.positive.all(func(p): return p in ids) or answer.positive.size() > ids.size():
			return "Unknown person in a card answer."
		if answer.has("slots") and (not answer.slots is Array or answer.slots.size() > ids.size() or not answer.slots.all(func(p): return p == null or p == "" or p in ids)):
			return "Invalid answer slots."
		if answer.has("slots") and answer.slots.filter(func(p): return p is String and p != "") != answer.positive:
			return "The displayed slots and recorded answers disagree."
	for key in value.reasons:
		var valid_keys: Array = []
		for id in ids:
			valid_keys.append(id + ":1")
			valid_keys.append(id + ":2")
		if key not in valid_keys or value.reasons[key] not in ["unexplained", "gift", "evil"]:
			return "Invalid outing explanation."
	if not value.get("citations", {}) is Dictionary or not value.get("conflict_scope", []) is Array or not value.get("challenges", {}) is Dictionary:
		return "Invalid citations or conflict scope."
	for key in value.get("citations", {}):
		if key not in ids.map(func(id): return id + ":1") + ids.map(func(id): return id + ":2") or value.citations[key] not in scenario.public_view.cards.filter(func(c): return c.kind == "claim").map(func(c): return c.id):
			return "Invalid claim citation."
	if not value.get("conflict_scope", []).all(func(id): return id in card_ids):
		return "Unknown report in conflict scope."
	for id in value.get("challenges", {}):
		if id not in scenario.public_view.cards.map(func(c): return c.id) or not value.challenges[id] is Array or not value.challenges[id].all(func(root): return root in card_ids):
			return "Invalid challenged report or grounds."
	if not value.get("lines", []) is Array or value.get("lines", []).size() > 6:
		return "Invalid reasoning lines (maximum six)."
	var line_ids: Array = []
	for line in value.get("lines", []):
		if not line is Dictionary or not line.get("id") is String or line.id in line_ids or not line.get("label") is String or line.label.length() > 120 or line.get("relation") not in ["supports", "alternative"] or not line.get("cards") is Array or line.cards.size() > card_ids.size() or not line.cards.all(func(id): return id in value.cards):
			return "Invalid reasoning line or evidence reference."
		line_ids.append(line.id)
		var choices = Solver.empty_case()
		choices.cards = line.cards
		choices.derived = value.get("derived", [])
		choices.positions = line.get("positions", {})
		choices.answers = line.get("answers", {})
		choices.reasons = line.get("reasons", {})
		choices.citations = line.get("citations", {})
		choices.conclusion = line.get("conclusion", value.conclusion)
		var error = validate_case(choices)
		if error != "":
			return "Invalid line choices: " + error
		if line.has("test_factor"):
			var factor = line.test_factor
			if not factor is Dictionary or factor.get("target") not in ids or not factor.get("log2_ratio") is float and not factor.get("log2_ratio") is int:
				return "Invalid test factor."
			if not is_finite(float(factor.log2_ratio)) or absf(float(factor.log2_ratio)) > 4.0 or line.cards.is_empty():
				return "Test factor must cite evidence and stay between 1/16 and 16."
	return ""

func validate_jury(value) -> String:
	if not value is Array or value.size() != scenario.jury.size():
		return "Invalid jury settings."
	for i in range(value.size()):
		var juror = value[i]
		if not juror is Dictionary or juror.get("id") != scenario.jury[i].id or juror.get("knowledge") != scenario.jury[i].knowledge:
			return "Jury identity or personal knowledge differs from the fixture."
		if juror.get("name") != scenario.jury[i].name or juror.get("preset") != scenario.jury[i].preset or juror.get("ledger") != {} or juror.get("case_memory") != {} or juror.get("theories") != {}:
			return "Invalid baseline jury identity or memory."
		for field in ["trust", "confidence", "insight"]:
			if not _unit_number(juror.get(field)):
				return "Invalid jury trait."
		if juror.get("reasoning_mode") not in ["full", "bounded"] or juror.get("confidence_mode") not in ["scale", "persistence"]:
			return "Invalid reasoning or confidence mode."
		for field in ["npc_trust", "suspicion"]:
			if not juror.get(field) is Dictionary:
				return "Invalid jury relationship settings."
			for person in scenario.public_view.people:
				if not _unit_number(juror[field].get(person.id)):
					return "Invalid jury relationship value."
		if not juror.get("reading_reliability") is Dictionary or juror.reading_reliability.size() != scenario.jury[i].reading_reliability.size():
			return "Invalid reading reliability settings."
		for key in scenario.jury[i].reading_reliability:
			if not _unit_number(juror.reading_reliability.get(key)):
				return "Invalid reading reliability value."
	return ""

func _unit_number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= 0.0 and value <= 1.0
