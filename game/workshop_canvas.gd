## Live canvas boundary. Only player board receipts cross into the editor.
extends RefCounted
const Bridge = preload("res://game/workshop_bridge.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Assess = preload("res://workshop/live_assessment.gd")

static func view(g) -> Dictionary:
	var numbers: Array = g.board.filter(func(c): return not c.get("deleted", false) and c.kind != "deduction").map(func(c): return c.n)
	var snapshot = Bridge.capture(g, numbers)
	var cards: Array = []
	for receipt in snapshot.evidence:
		var content: Dictionary = receipt.content
		var note = "FALLBACK: this evidence has no live Workshop evaluator"
		if (receipt.kind == "claim" and content.get("role") in Assess.C.GOOD_ROLES) or (receipt.kind in ["sighting", "alibi"] and receipt.observed_at.phase == "night"):
			note = "Adapter available · testimony and circumstances, not proof of evil"
		var activity = Assess.activity_card(receipt, snapshot)
		if not activity.is_empty():
			note = "Adapter available · experimental joint activity/trace comparison"
		if receipt.kind == "info" and content.get("role") in Assess.ROLES:
			note = "Reading adapter available · check whole-case support"
			if not Assess.Domain.gift_time({"role": content.role, "observed_at": receipt.observed_at}):
				note = "FALLBACK: this reading time is outside the live adapter"
			var ids: Array = snapshot.people.map(func(p): return p.id)
			if not Assess.reading_valid(receipt, ids, snapshot.rules.modifier_options):
				note = "FALLBACK: reading payload is incomplete or invalid"
		cards.append({"id": receipt.id, "fact_id": receipt.id, "kind": "report" if receipt.kind == "info" else receipt.kind,
			"source": receipt.source, "subject": receipt.subjects[0] if not receipt.subjects.is_empty() else "", "subjects": receipt.subjects.duplicate(),
			"role": content.get("role", ""), "data": content.get("data", {}).duplicate(true),
			"night": receipt.observed_at.day if receipt.observed_at.phase == "night" else -1,
			"block": content.get("block", ""), "observed_at": receipt.observed_at,
			"reported_at": receipt.reported_at if receipt.reported_at != null else {"day": "?"},
			"learned_at": receipt.learned_at if receipt.learned_at != null else {"day": "?"},
			"acquired_day": receipt.learned_at.day if receipt.learned_at != null else snapshot.now.day,
			"text": receipt.text, "support_note": note})
		if not activity.is_empty():
			cards[-1].merge(activity, true)
	return {"seed": g.w.seed_value, "day": snapshot.now.day, "people": snapshot.people, "cards": cards,
		"evil_count": snapshot.rules.initial_evil_count, "alignment_epoch": "Original alignment",
		"world_options": {"modifiers": snapshot.rules.modifier_options}, "live": true, "live_activity": true,
		"timeline": Assess.History.from_events(snapshot.public_events)}

## Resolve exact original facts afresh. Missing/deleted evidence is a blocker, never
## permission to file a weaker argument with fewer roots.
static func supports(g, value: Dictionary) -> Dictionary:
	var numbers: Array = []
	var missing: Array = []
	for id in value.cards:
		var matches: Array = g.board.filter(func(c): return c.kind != "deduction" and not c.get("deleted", false) and Evidence.normalize_card(c).id == id)
		if matches.is_empty():
			missing.append("Missing or changed original evidence: " + id)
		else:
			numbers.append(matches[0].n)
	return {"numbers": numbers, "issues": missing}

static func snapshot(g, value: Dictionary, listener: String = "", venue: String = "private") -> Dictionary:
	var roots = supports(g, value)
	var input = Bridge.capture(g, roots.numbers, listener, venue)
	input.root = -1
	input.arguments = [{"board_number": -1, "supports": roots.numbers,
		"conclusion": {"type": value.conclusion.type, "a": value.conclusion.target}, "workshop_case": value.duplicate(true)}]
	for issue in roots.issues:
		input.issues.append({"code": "missing_card", "detail": issue})
	return input

static func status(g, value: Dictionary) -> Dictionary:
	var input = snapshot(g, value)
	# Use a synthetic profile for capability checks, without running the expensive
	# numerical preview or looking at any real listener's private knowledge.
	input.listener = {"id": "ghost", "name": "Neutral reference", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "discounted": {}, "own_gift": ""}
	var prepared = Assess.prepare(input)
	var issues: Array = prepared.issues.duplicate()
	var blocked = not supports(g, value).issues.is_empty() or value.cards.is_empty()
	if value.cards.is_empty():
		issues.append("Connect evidence to the selected premise before filing.")
	return {"ready": prepared.ready and not blocked, "blocked": blocked, "issues": issues,
		"mode": "shared" if prepared.ready and g.workshop_effects else "legacy",
		"warning": "Fallback evaluates the headline and original cards using the existing argument system. Canvas answers, assumptions, intermediate claims and link meanings are NOT interpreted by that system."}

static func file(g, value: Dictionary, previous: int = 0) -> int:
	if g.workshop_presenting:
		g.last_error = "Wait for the current presentation to finish before changing a filed case."
		return -1
	if previous > 0 and previous <= g.board.size() and g.board[previous - 1].get("deleted", false):
		previous = 0
	var check = status(g, value)
	if check.blocked:
		g.last_error = "\n".join(PackedStringArray(check.issues))
		return -1
	var roots = supports(g, value)
	var conclusion = {"type": value.conclusion.type, "a": value.conclusion.target}
	if previous > 0 and previous <= g.board.size() and g.board[previous - 1].get("workshop_case", {}) == value:
		return previous
	# Build native fallback footing through the ordinary filer, then retain the
	# entire graph. A unique label prevents text-based card merging across drafts.
	var old_size: int = g.board.size()
	var number = g.file_deduction(conclusion, roots.numbers, {}, 0, true)
	if number < 1:
		return number
	var card: Dictionary = g.board[number - 1].duplicate(true)
	card["workshop_case"] = value.duplicate(true)
	card["text"] = "Case: %s (%d original reports)." % [g.Argue.conclusion_text(g.w, conclusion), roots.numbers.size()]
	# Stable board number for revisions; listeners keep their old receipt until the
	# next presentation. Editing a draft never changes anyone's beliefs.
	if previous > 0 and previous <= g.board.size() and g.board[previous - 1].has("workshop_case"):
		if g.board[previous - 1].workshop_case == value:
			return previous
		card.n = previous
		g.board[previous - 1] = card
		if number != previous and number > old_size:
			g.board[number - 1]["deleted"] = true
		g.w.dlog.add("workshop_canvas_filed", "player", conclusion.get("a", ""), {"card": previous, "revision": true, "case": value, "supports": roots.numbers})
		return previous
	# The native filer may have returned a pre-existing flat deduction. Never
	# overwrite that card or turn another draft into this graph.
	if number > old_size:
		g.board[number - 1] = card
		g.w.dlog.add("workshop_canvas_filed", "player", conclusion.get("a", ""), {"card": number, "revision": false, "case": value, "supports": roots.numbers})
		return number
	return g.add_card(card)
