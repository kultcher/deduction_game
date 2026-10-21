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

func export_data(include_truth: bool = false) -> Dictionary:
	var result = {"format": "demonologist-case-workshop-1", "seed": scenario.public_view.seed,
		"public_view": scenario.public_view.duplicate(true), "case": case_data.duplicate(true),
		"jury_settings": baseline.duplicate(true), "history": history.duplicate(true)}
	if include_truth:
		result["developer_truth"] = {"people": scenario.truth, "timeline": scenario.timeline}
	return result

func restore(data: Dictionary) -> String:
	# Load only this fixture format. Validate the complete experiment before mutating
	# the session, then replay its presentations instead of trusting stored outcomes.
	if data.get("format", "") != "demonologist-case-workshop-1" or not data.get("seed") is float and not data.get("seed") is int:
		return "Invalid experiment header."
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
			listener.npc_trust = candidate.baseline[i].npc_trust.duplicate(true)
			for person in candidate.scenario.public_view.people:
				var applied = 0.0
				for effect in listener.ledger.values():
					if effect.target == person.id:
						applied += effect.applied
				listener.suspicion[person.id] = candidate.baseline[i].suspicion[person.id] + applied
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
		listeners[i].npc_trust = baseline[i].npc_trust.duplicate(true)
		for person in scenario.public_view.people:
			var applied = 0.0
			for effect in listeners[i].ledger.values():
				if effect.target == person.id:
					applied += effect.applied
			listeners[i].suspicion[person.id] = baseline[i].suspicion[person.id] + applied
	return ""

func validate_case(value) -> String:
	if not value is Dictionary:
		return "Missing case."
	if value.get("id") != "case-1" or not value.get("version") is float and not value.get("version") is int:
		return "Invalid case identity or version."
	if not value.get("cards") is Array or not value.get("positions") is Dictionary or not value.get("answers") is Dictionary or not value.get("reasons") is Dictionary:
		return "Invalid case choices."
	var ids: Array = scenario.public_view.people.map(func(p): return p.id)
	var card_ids: Array = scenario.public_view.cards.map(func(c): return c.id)
	if not value.cards.all(func(id): return id in card_ids) or value.cards.size() > card_ids.size():
		return "Unknown evidence card."
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
	for key in value.reasons:
		var valid_keys: Array = []
		for id in ids:
			valid_keys.append(id + ":1")
			valid_keys.append(id + ":2")
		if key not in valid_keys or value.reasons[key] not in ["unexplained", "gift", "evil"]:
			return "Invalid outing explanation."
	var conclusion = value.get("conclusion")
	if not conclusion is Dictionary or conclusion.get("type") not in ["evil", "good", "marked", "suspicious", "conflict"] or conclusion.get("target") not in ids or conclusion.get("at") != scenario.public_view.alignment_epoch:
		return "Invalid conclusion or time."
	return ""

func validate_jury(value) -> String:
	if not value is Array or value.size() != scenario.jury.size():
		return "Invalid jury settings."
	for i in range(value.size()):
		var juror = value[i]
		if not juror is Dictionary or juror.get("id") != scenario.jury[i].id or juror.get("knowledge") != scenario.jury[i].knowledge:
			return "Jury identity or personal knowledge differs from the fixture."
		if juror.get("name") != scenario.jury[i].name or juror.get("preset") != scenario.jury[i].preset or juror.get("ledger") != {} or juror.get("case_memory") != {}:
			return "Invalid baseline jury identity or memory."
		for field in ["trust", "confidence"]:
			if not _unit_number(juror.get(field)):
				return "Invalid jury trait."
		for field in ["npc_trust", "suspicion"]:
			if not juror.get(field) is Dictionary:
				return "Invalid jury relationship settings."
			for person in scenario.public_view.people:
				if not _unit_number(juror[field].get(person.id)):
					return "Invalid jury relationship value."
	return ""

func _unit_number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= 0.0 and value <= 1.0
