## A fixed reference audience, without a town identity or private knowledge.
extends RefCounted
const Jury = preload("res://workshop/jury.gd")
const Assess = preload("res://workshop/live_assessment.gd")

static func profile(people: Array) -> Dictionary:
	var suspicion = {}
	var trust = {}
	for person in people:
		suspicion[person.id] = 0.1
		trust[person.id] = 0.5
	return {"id": "ghost", "name": "Neutral ghost juror", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "reasoning_mode": "full", "confidence_mode": "scale", "theories": {},
		"npc_trust": trust, "suspicion": suspicion, "reading_reliability": {},
		"knowledge": {"self": "", "good": [], "own_role": "", "own_reports": [], "own_outings": {}},
		"ledger": {}, "case_memory": {}}

static func evaluate(view: Dictionary, value: Dictionary) -> Dictionary:
	return evaluate_with_profile(view, value, profile(view.people))

static func live(snapshot: Dictionary) -> Dictionary:
	var input = snapshot.duplicate(true)
	input.private_evidence = []
	input.evidence = input.evidence.filter(func(e): return e.id in input.selected)
	var ghost = profile(input.people)
	input.listener = {"id": ghost.id, "name": ghost.name, "trust": ghost.trust, "confidence": ghost.confidence,
		"insight": ghost.insight, "npc_trust": ghost.npc_trust, "suspicion": ghost.suspicion,
		"discounted": {}, "honesty": {}, "own_gift": "", "legacy_evidence": []}
	var prepared = Assess.prepare(input)
	if not prepared.ready:
		return {"ready": false, "issues": prepared.issues, "proposal": {}, "elapsed_ms": 0, "scope": "Player-held evidence only; unsupported mechanics need an adapter."}
	var listener = profile(input.people)
	listener.knowledge.good = prepared.listener.knowledge.good.filter(func(id): return id != ghost.id)
	return evaluate_with_profile(prepared.view, prepared.case, listener)

static func evaluate_with_profile(view: Dictionary, value: Dictionary, listener: Dictionary) -> Dictionary:
	var started = Time.get_ticks_msec()
	var proposal = Jury.evaluate(view, value, listener)
	return {"ready": true, "issues": [], "proposal": proposal, "elapsed_ms": Time.get_ticks_msec() - started,
		"scope": "Neutral reference: player trust 0.5, witness trust 0.5, suspicion 0.1, confidence 0.5; full reasoning and public process knowledge only. Experimental strength, not an NPC or vote prediction. Narrowing worlds is not a probability of guilt."}
