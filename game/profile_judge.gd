## How a listener with a given profile would weigh a case put to the town (Michael, Nov 19,
## juror fix (a), option (i); Lantern builds it, Quill wires the Test juror, its badge and
## the Workshop town note onto it). The full listener path, as a real NPC hears a public
## presentation (WorkshopPresentation._present): Bridge.capture, the case as a stored case,
## Shared.prepare (its per-card hearing weights, route trust and the case's chain weight on
## the filing day), then the belief refresh's own evaluation (Shared.evaluate, the
## connections model). The listener is synthetic: nothing first-hand (no readings, no
## sightings of its own, no ledger of private talk), the public record, and the player's
## earlier public cases as stored cases. No full-weight figure: every card is weighed as
## this listener would hear it. Reads only; changes nothing in the game.
## Connections.judge_for_profile is the entry point.
extends RefCounted

const Bridge = preload("res://game/workshop_bridge.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")

## The average listener (Michael, Nov 19): credibility 0.5 in the player, trust 0.5 in
## everyone, middling traits, nothing first-hand.
const AVERAGE = {"credibility": 0.5, "npc_trust": 0.5, "confidence": 0.5, "insight": 0.5}

## {"ready", "issues", "target", "before", "after", "shift", "posterior_before",
## "posterior_after", "case"}: the target's chance of being evil without and with the case,
## each person's chance both ways, and the case's own entry among the stored cases (its
## weight on the filing day and its lean). `profile` overrides AVERAGE's fields; npc_trust
## may be one number for everyone or a map.
static func judge(g, value: Dictionary, profile: Dictionary = {}) -> Dictionary:
	var Canvas = preload("res://game/workshop_canvas.gd")
	var p: Dictionary = AVERAGE.duplicate()
	p.merge(profile, true)
	var fail = func(issues: Array) -> Dictionary: return {"ready": false, "issues": issues}
	if value.get("cards", []).is_empty():
		return fail.call(["Connect evidence to the selected premise before judging it."])
	var target: String = str(value.get("conclusion", {}).get("target", ""))
	var day: int = int(g.w.day)
	var listener: Dictionary = _listener(g, p, day)
	# The case as the town hears it at a meeting, presented today.
	var draft: Dictionary = _as_heard(Canvas.snapshot(g, value, "", "meeting"), listener)
	var checked = Assess.prepare(draft)
	if not checked.ready:
		return fail.call(checked.issues.duplicate())
	# The player's earlier public cases, as stored cases with the day each was put (oldest
	# first). A version this case revises is replaced by it, as a listener's would be.
	var replaced: Dictionary = {}
	var ancestor: int = int(value.get("revises", 0))
	while ancestor > 0 and ancestor <= g.board.size() and not replaced.has(ancestor):
		replaced[ancestor] = true
		ancestor = int(g.board[ancestor - 1].get("revises", 0))
	var numbers: Array = g.public_presentations.keys().map(func(x): return int(x))
	numbers.sort_custom(func(a, b): return _put_day(g, a) < _put_day(g, b) or (_put_day(g, a) == _put_day(g, b) and a < b))
	var earlier: Dictionary = {}
	var same_key: String = ""
	for number in numbers:
		if number < 1 or number > g.board.size():
			continue
		var filed: Dictionary = g.board[number - 1]
		if filed.get("kind", "") != "deduction" or not filed.has("workshop_case") or filed.get("withdrawn", false) or int(filed.get("superseded_by", 0)) > 0 or replaced.has(number):
			continue
		if filed.workshop_case == value:
			same_key = str(number)  # the same case put again: it takes its own place, renewed
		var snap: Dictionary = _as_heard(Canvas.snapshot(g, filed.workshop_case, "", "meeting"), listener)
		if not Assess.prepare(snap).ready:
			continue
		snap.now = {"day": _put_day(g, number), "phase": snap.now.get("phase", "")}
		earlier[str(number)] = snap
	var with_case: Dictionary = earlier.duplicate()
	with_case[same_key if same_key != "" else "draft"] = draft
	var current: Dictionary = Bridge.capture(g, [], "", "meeting")
	current.listener = listener.duplicate(true)
	var ledger: Dictionary = _public_hearing(g, value)
	var before: Dictionary = _evaluate(current, earlier, ledger, [])
	var after: Dictionary = _evaluate(current, with_case, ledger, draft.selected)
	if not after.ready:
		return fail.call(after.issues)
	if not before.ready:
		return fail.call(before.issues)
	var entry: Dictionary = {}
	for e in after.cases.get("entries", []):
		if str(e.get("key", "")).ends_with(same_key if same_key != "" else "draft"):
			entry = e
	# With nothing held before the case, the model reports no posterior: the prior stands.
	var b: float = float(before.posterior.get(target, after.prior.get(target, -1.0)))
	var a: float = float(after.posterior.get(target, after.prior.get(target, -1.0)))
	return {"ready": true, "issues": [], "target": target, "before": b, "after": a,
		"shift": a - b if a >= 0.0 and b >= 0.0 else 0.0,
		"posterior_before": before.posterior, "posterior_after": after.posterior, "case": entry}


## A presentation snapshot as this listener hears it: nothing private of its own.
static func _as_heard(snap: Dictionary, listener: Dictionary) -> Dictionary:
	snap.private_evidence = []
	snap.listener = listener.duplicate(true)
	return snap


## The day case `number` was put to the town (public_presentations once held `true`).
static func _put_day(g, number: int) -> int:
	var v = g.public_presentations.get(number, g.public_presentations.get(str(number), g.w.day))
	return int(v) if v is int else int(g.w.day)


## The listener Bridge._listener would give a mind with this profile and nothing of its own.
static func _listener(g, p: Dictionary, day: int) -> Dictionary:
	var trust: Dictionary = {}
	for n in g.w.npcs:
		trust[n.id] = float(p.npc_trust.get(n.id, 0.5)) if p.npc_trust is Dictionary else float(p.npc_trust)
	return {"id": "average", "name": "An average listener", "trust": float(p.credibility), "rapport": 0.5,
		"lean": {}, "committed_requested": {}, "own_gift": "", "suspicion": {}, "npc_trust": trust,
		"confidence": float(p.confidence), "insight": float(p.insight), "reasoning_mode": "full",
		"confidence_mode": "scale", "theories": {}, "source_doubt": {}, "known_claims": {},
		"own_outings": {}, "role_beliefs": {}, "legacy_evidence": [], "disowned_reports": [],
		"connections": {"day": day, "core": {}, "nominations": []}}


## What everyone heard in public, from its teller: each card the case cites that is already
## public, and the public claims about the people it names (WorkshopCanvas.public_claims_for,
## as the Test juror hears them), as the heard-card entries Mind.ledger_hear gives. A card
## the case brings to the town for the first time is heard only through the case.
static func _public_hearing(g, value: Dictionary) -> Dictionary:
	var Canvas = preload("res://game/workshop_canvas.gd")
	var Meeting = preload("res://game/game_meeting.gd")
	var ledger: Dictionary = {}
	var numbers: Array = Canvas.supports(g, value).numbers.duplicate()
	for x in Canvas.public_claims_for(g, value):
		if not (x in numbers):
			numbers.append(x)
	for number in numbers:
		var card: Dictionary = g.receipt_by_number(int(number))
		if card.is_empty() or card.get("kind", "") == "deduction" or not Meeting.already_public(g, card):
			continue
		var receipt: Dictionary = Evidence.normalize_card(card)
		var teller: String = str(receipt.get("source", ""))
		if teller == "" or teller == "player":
			continue  # the player's own word reaches it through the case, at its credibility
		var eid: String = "tell:public:%s" % str(receipt.id)
		ledger[eid] = {"eid": eid, "effects": [], "weight": 1.0, "rel": [teller, int(card.get("day", g.w.day)), "tell"],
			"day": int(card.get("day", g.w.day)), "times": 1, "justs": [],
			"meta": {"kind": "tell", "workshop_card": receipt, "workshop_teller": teller, "text": str(receipt.get("text", ""))}}
	return ledger


static func _evaluate(current: Dictionary, presentations: Dictionary, ledger: Dictionary, focus: Array) -> Dictionary:
	var plan: Dictionary = Shared.prepare(current, presentations, ledger, {}, focus)
	if not plan.get("ready", false):
		return {"ready": false, "issues": plan.get("issues", []).duplicate(), "prior": {}}
	var proposal: Dictionary = Shared.evaluate(plan, {}, {}, {}, {})
	var cx: Dictionary = proposal.get("connections", {})
	# A person nothing held touches keeps the prior (the model reports no posterior for them).
	var post: Dictionary = cx.get("prior", {}).duplicate()
	post.merge(cx.get("posterior", {}), true)
	return {"ready": true, "issues": [], "posterior": post, "prior": cx.get("prior", {}), "cases": cx.get("cases", {})}
