## Restricted live comparison. Pure inputs/outputs; no simulation objects or effects.
extends RefCounted
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")
const Domain = preload("res://workshop/world_domain.gd")
const LedgerAudit = preload("res://workshop/ledger_audit.gd")
const ROLES = ["surveyor", "rumormonger", "dowser"]
const CONCLUSIONS = ["evil", "good", "marked", "suspicious", "conflict"]

static func prepare(snapshot: Dictionary) -> Dictionary:
	var result = {"ready": false, "issues": [], "view": {}, "case": {}, "listener": {},
		"scope": "Conditional reading comparison with legal original alignment/modifier worlds. Accepting a report assumes a good, correctly claimed, healthy source. No live movement likelihood or alignment-transition history is inferred. Venue is recorded; proposed effects use the unscaled Workshop response."}
	if snapshot.get("format") != "demonologist-live-evidence-1":
		result.issues.append("Unknown live evidence format.")
		return result
	if snapshot.listener.is_empty():
		result.issues.append("Select a listener with an available good or cover mind.")
	if snapshot.people.size() not in [7, 10]:
		result.issues.append("Only seven- and ten-person live setups are profiled.")
	for issue in snapshot.issues:
		if issue.code in ["missing_card", "cyclic_argument", "argument_depth", "unknown_listener", "cover_unavailable", "invalid_venue"]:
			result.issues.append(issue.code + ": " + issue.detail)
	if snapshot.public_events.any(func(e): return e.kind in ["curse", "curse_lifted"]):
		result.issues.append("This live case has alignment-transition history that needs a temporal adapter.")
	var needed: Array = snapshot.selected.duplicate()
	for id in snapshot.private_evidence:
		if id not in needed:
			needed.append(id)
	var cards: Array = []
	for e in snapshot.evidence:
		if e.id not in needed:
			continue
		if e.kind in ["claim", "home"]:
			continue # Role assertions are not healthy readings; homes are in the public roster.
		if e.id not in snapshot.selected and e.kind == "sighting":
			continue # This comparison makes no movement claim or movement effect.
		if e.id not in snapshot.selected and e.kind == "info" and e.content.get("role", "") not in ROLES:
			continue # Independent unsupported readings keep their native baseline owner.
		if e.kind != "info" or e.content.get("role", "") not in ROLES:
			result.issues.append("Not yet supported: %s %s." % [e.kind, e.content.get("role", "")])
			continue
		var data: Dictionary = e.content.data
		var ids: Array = snapshot.people.map(func(p): return p.id)
		var role: String = e.content.role
		var valid: bool = e.source in ids and e.observed_at.day >= 0 and e.observed_at.phase != "unknown"
		if role == "surveyor":
			valid = valid and _count_valid(data.get("count"), 4)
		elif role == "dowser":
			valid = valid and _group_valid(data.get("group"), ids) and _count_valid(data.get("count"), data.get("group", []).size())
		else:
			valid = valid and _group_valid(data.get("pair"), ids) and data.get("pair", []).size() == 2 and data.get("secret") in snapshot.rules.modifier_options
		if not valid:
			result.issues.append("Incomplete or invalid reading payload: " + e.id)
			continue
		cards.append({"id": e.id, "fact_id": e.fact_id, "kind": "report", "source": e.source, "role": role,
			"data": data.duplicate(true), "night": e.observed_at.day if e.observed_at.phase == "night" else -1,
			"observed_at": e.observed_at, "reported_at": e.reported_at, "learned_at": e.learned_at,
			"acquired_day": e.learned_at.day if e.learned_at != null else e.observed_at.day,
			"provenance": e.provenance, "text": e.text})
	if not cards.any(func(c): return c.id in snapshot.selected):
		result.issues.append("No supported reading is presented.")
	if cards.size() > 8 or snapshot.arguments.size() > 6:
		result.issues.append("This comparison exceeds the initial eight-reading / six-claim workload budget.")
	var epoch: String = "live through day %d" % snapshot.now.day
	var view = {"seed": 0, "day": snapshot.now.day, "people": snapshot.people.duplicate(true), "cards": cards,
		"evil_count": snapshot.rules.initial_evil_count, "alignment_epoch": epoch, "history": [],
		"world_options": {"modifiers": snapshot.rules.modifier_options.duplicate()}, "scope": result.scope}
	var root: Dictionary = snapshot.arguments.filter(func(a): return a.board_number == snapshot.root)[0] if snapshot.arguments.any(func(a): return a.board_number == snapshot.root) else {}
	if root.is_empty():
		result.issues.append("Select a filed deduction as the comparison's headline claim.")
	else:
		var value = _case(snapshot, root, epoch, [])
		value["arguments"] = []
		for argument in snapshot.arguments:
			var scoped = _case(snapshot, argument, epoch, [])
			var inputs: Array = []
			var direct: Array = argument.supports.filter(func(number): return snapshot.board_map.has(str(number))).map(func(number): return snapshot.board_map[str(number)])
			if not direct.is_empty():
				inputs.append({"id": "direct:%d" % argument.board_number, "cards": direct})
			for child in snapshot.arguments.filter(func(a): return a.board_number in argument.supports):
				inputs.append({"id": "argument:%d" % child.board_number, "cards": _case(snapshot, child, epoch, []).cards})
			value.arguments.append({"id": "argument:%d" % argument.board_number, "label": "Filed claim #%d" % argument.board_number,
				"case": scoped, "inputs": inputs, "parents": snapshot.arguments.filter(func(a): return argument.board_number in a.supports).map(func(a): return "argument:%d" % a.board_number)})
		result.case = value
		for argument in snapshot.arguments:
			var conclusion = argument.conclusion
			if conclusion.get("type") not in CONCLUSIONS or _target(conclusion) not in snapshot.people.map(func(p): return p.id):
				result.issues.append("Unsupported claim: " + str(conclusion.get("type", "unknown")))
		if not snapshot.listener.is_empty():
			result.listener = _listener(snapshot, cards)
			var uncertain = cards.filter(func(c): return c.source != snapshot.listener.id).map(func(c): return c.source)
			var sources = {}
			for source in uncertain:
				sources[source] = true
			var discounts: int = result.listener.reading_reliability.values().filter(func(v): return v > 0 and v < 1).size()
			if sources.size() + discounts > 6:
				result.issues.append("This comparison exceeds the initial 64-state credibility budget.")
	result.view = view
	result.ready = result.issues.is_empty()
	return result

static func evaluate(snapshot: Dictionary) -> Dictionary:
	var started = Time.get_ticks_msec()
	var prepared = prepare(snapshot)
	var result = {"ready": prepared.ready, "issues": prepared.issues, "scope": prepared.scope,
		"format": "demonologist-live-comparison-1", "listener": snapshot.get("listener", {}).get("id", ""),
		"proposal": {}, "elapsed_ms": 0}
	result["ledger_audit"] = LedgerAudit.inspect(snapshot)
	if not result.ledger_audit.aliases.is_empty():
		result.ready = false
		result.issues.append("Several statements share an unresolved original reading identity; numeric comparison is deferred.")
	if result.ready:
		result.proposal = Jury.evaluate(prepared.view, prepared.case, prepared.listener, {"venue": snapshot.venue})
		result["world_count"] = Domain.worlds(prepared.view).size()
	result.elapsed_ms = Time.get_ticks_msec() - started
	return result

static func _case(snapshot: Dictionary, argument: Dictionary, epoch: String, path: Array) -> Dictionary:
	var result = Solver.empty_case()
	result.id = "live:" + snapshot.case_id
	result.conclusion = {"type": argument.conclusion.get("type", "unsupported"), "target": _target(argument.conclusion), "at": epoch}
	if argument.board_number in path:
		return result
	var direct: Array = []
	for number in argument.supports:
		if snapshot.board_map.has(str(number)):
			var id: String = snapshot.board_map[str(number)]
			if snapshot.evidence.any(func(e): return e.id == id and e.kind == "info"):
				result.cards.append(id)
				direct.append(id)
		else:
			var child: Array = snapshot.arguments.filter(func(a): return a.board_number == number)
			if child.is_empty():
				continue
			var sub = _case(snapshot, child[0], epoch, path + [argument.board_number])
			result.cards.append_array(sub.cards.filter(func(id): return id not in result.cards))
			result.lines.append({"id": "argument:%d" % number, "label": "Supporting claim", "relation": "supports",
				"conclusion": sub.conclusion, "cards": sub.cards, "answers": {}, "positions": {}, "reasons": {}})
			if sub.conclusion.type == "conflict":
				result.lines[-1].relation = "quotes"
	if not direct.is_empty():
		# A quoted child may contain the same report as a direct endorsed path.
		# Preserve both routes so quoting cannot erase that independent endorsement.
		result.lines.append({"id": "direct:%d" % argument.board_number, "label": "Direct reports", "relation": "supports",
			"cards": direct, "answers": {}, "positions": {}, "reasons": {}})
	if result.conclusion.type == "conflict":
		result.conflict_scope = result.cards.duplicate()
	return result

static func _listener(snapshot: Dictionary, cards: Array) -> Dictionary:
	var src: Dictionary = snapshot.listener
	var reliability = {}
	var good: Array = [src.id]
	for event in snapshot.public_events:
		if event.kind in ["demon_death", "martyr"]:
			for person in event.subjects:
				if person not in good and person in snapshot.people.map(func(p): return p.id):
					good.append(person)
	for card in cards:
		reliability[card.id] = 1.0 - maxf(src.discounted.get("%s:%d" % [card.source, card.observed_at.day], 0.0), src.discounted.get(card.source + ":*", 0.0))
	return {"id": src.id, "name": src.name, "trust": src.trust, "confidence": src.confidence,
		"insight": src.insight, "reasoning_mode": "full", "confidence_mode": "scale", "theories": {},
		"npc_trust": src.npc_trust.duplicate(true), "suspicion": src.suspicion.duplicate(true),
		"reading_reliability": reliability, "knowledge": {"self": src.id, "good": good, "own_role": src.own_gift,
			"own_reports": cards.filter(func(c): return c.id in snapshot.private_evidence).map(func(c): return c.id), "own_outings": {}},
		"ledger": {}, "case_memory": {}}

static func _target(conclusion: Dictionary) -> String:
	return conclusion.get("a", "") if conclusion.get("a", "") != "" else str(conclusion.get("group", [""])[0]) if not conclusion.get("group", []).is_empty() else ""

static func _count_valid(value, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= maximum and int(value) == value

static func _group_valid(value, ids: Array) -> bool:
	if not value is Array or value.is_empty():
		return false
	var unique = {}
	for id in value:
		if id not in ids or unique.has(id):
			return false
		unique[id] = true
	return true
