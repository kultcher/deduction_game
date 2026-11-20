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

const GameBoard = preload("res://game/game_board.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")

## The average listener (Michael, Nov 19): credibility 0.5 in the player, trust 0.5 in
## everyone, middling traits, nothing first-hand.
const AVERAGE = {"credibility": 0.5, "npc_trust": 0.5, "confidence": 0.5, "insight": 0.5}

## {"ready", "issues", "target", "before", "after", "shift", "posterior_before",
## "posterior_after", "case", "floors", "requested_before", "requested_after", "plan_before",
## "plan_after"}: the target's
## chance of being evil without and with the case, each person's chance both ways, and the
## case's own entry among the stored cases (its weight on the filing day and its lean).
## An accepted "lying" challenge doesn't move these chances (the clash is already in the
## worlds; ReadingChallenges.assess): it floors the teller's suspicion through the refresh's
## effects (Jury), returned as `floors` (the stored cases' accepted challenges, with their
## agreement and weight) and `requested_*` (each person's requested suspicion change, as the
## refresh would apply it). `plan_*` are the two Shared.prepare plans, for asking another
## question of the same hearing (SharedLedger.evaluate_question), and `counted_*` the stored
## cases the connections model counted from each (those above CASE_FLOOR, with their challenges). `profile` overrides AVERAGE's fields; npc_trust
## may be one number for everyone or a map. `profile.baseline`:
##   "marginal" (the default): `before` is the listener as it stands, having heard the case's
##     public cards from their tellers; what presenting it would change (the town note).
##   "without_cards": `before` leaves out the case's own cards entirely (their public hearing
##     as well as the case), keeping the public claims about the people it names; how strong
##     the case is to a listener who hears its cards as it would (the Test juror's badge;
##     Quill, Nov 19). `after` is the same either way.
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
	# The player's earlier public cases, as stored cases in the order the town heard them.
	# Earlier versions of a case put to the town in revised form: the town retracted them when
	# it heard the revision (GamePresentation.workshop_canvas_retire). A revision only filed,
	# not yet presented, retires nothing (Codex on #326), as WorkshopCanvas.town_note reads it.
	var replaced: Dictionary = {}
	var numbers: Array = _heard_order(g)
	for number in numbers:
		_ancestors(g, int(g.board[number - 1].get("revises", 0)), replaced)
	# What this case would replace if it were put now: the versions it revises. Its `revises`
	# lives on its filed board card, not in the Workshop value (Codex on #326). Left out of the
	# after-state only: until it is heard, the town still holds them.
	var draft_replaces: Dictionary = {}
	_ancestors(g, int(value.get("revises", 0)), draft_replaces)
	for card in g.board:
		if card.get("kind", "") == "deduction" and card.get("workshop_case", {}) == value:
			_ancestors(g, int(card.get("revises", 0)), draft_replaces)
	var earlier: Dictionary = {}
	var same_key: String = ""
	var kept: Dictionary = {}
	# A withdrawal in public takes back every version in the withdrawn case's line, heard or
	# not (GamePresentation.workshop_withdraw_public), keeping the cards each heard version
	# brought (Codex on #326).
	for i in range(g.board.size()):
		var w_card: Dictionary = g.board[i]
		if w_card.get("kind", "") != "deduction" or not w_card.get("withdrawn", false):
			continue
		var line: Dictionary = {}
		_ancestors(g, i + 1, line)
		for v in line:
			if v != i + 1 and g.public_presentations.has(v) and g.board[v - 1].has("workshop_case") and not replaced.has(v):
				_kept_receipts(g, v, listener, kept)
			replaced[v] = true
	for number in numbers:
		var filed: Dictionary = g.board[number - 1]
		if filed.get("kind", "") == "deduction" and filed.has("workshop_case") and filed.get("withdrawn", false):
			_kept_receipts(g, number, listener, kept)
		if filed.get("kind", "") != "deduction" or not filed.has("workshop_case") or filed.get("withdrawn", false) or replaced.has(number):
			continue
		if filed.workshop_case == value:
			same_key = str(number)  # the same case put again: it takes its own place, renewed
		var snap: Dictionary = _as_heard(Canvas.snapshot(g, filed.workshop_case, "", "meeting"), listener)
		if not Assess.prepare(snap).ready:
			continue
		snap.now = {"day": _put_day(g, number), "phase": snap.now.get("phase", "")}
		earlier[str(number)] = snap
	# Putting it moves it to the end, as a real listener's store does (WorkshopPresentation._present).
	var with_case: Dictionary = {}
	for key in earlier:
		if key != same_key and not draft_replaces.has(int(key)):
			with_case[key] = earlier[key]
	with_case[same_key if same_key != "" else "draft"] = draft
	var current: Dictionary = Bridge.capture(g, [], "", "meeting")
	current.listener = listener.duplicate(true)
	current["watched"] = []  # the player's own watch record: never heard by the town (Codex on #326)
	var ledger: Dictionary = _public_hearing(g, value)
	ledger.merge(kept)
	var before_ledger: Dictionary = ledger
	var before_cases: Dictionary = earlier
	if str(p.get("baseline", "marginal")) == "without_cards":
		# Without the case's cards at all: neither heard in public, nor kept from a withdrawn
		# case, nor through any stored case, this one included (Codex on #326).
		var own: Array = value.get("cards", []).map(func(x): return str(x))
		before_ledger = {}
		for eid in ledger:
			if not (str(ledger[eid].get("meta", {}).get("workshop_card", {}).get("id", "")) in own):
				before_ledger[eid] = ledger[eid]
		before_cases = {}
		for key in earlier:
			if key == same_key:
				continue
			var snap: Dictionary = earlier[key].duplicate(true)
			snap.selected = snap.selected.filter(func(id): return not (str(id) in own))
			before_cases[key] = snap
	var before: Dictionary = _evaluate(current, before_cases, before_ledger, [])
	var after: Dictionary = _evaluate(current, with_case, ledger, draft.selected)
	if not after.ready:
		return fail.call(after.issues)
	if not before.ready:
		return fail.call(before.issues)
	var entry: Dictionary = {}
	var want: String = "case:" + (same_key if same_key != "" else "draft")
	for e in after.cases.get("entries", []):
		if str(e.get("key", "")) == want:
			entry = e
	# With nothing held before the case, the model reports no posterior: the prior stands.
	var b: float = float(before.posterior.get(target, after.prior.get(target, -1.0)))
	var a: float = float(after.posterior.get(target, after.prior.get(target, -1.0)))
	return {"ready": true, "issues": [], "target": target, "before": b, "after": a,
		"shift": a - b if a >= 0.0 and b >= 0.0 else 0.0,
		"posterior_before": before.posterior, "posterior_after": after.posterior, "case": entry,
		"floors": after.cases.get("floors", []).duplicate(true),
		"requested_before": before.get("requested", {}), "requested_after": after.get("requested", {}),
		"plan_before": before.plan, "plan_after": after.plan,
		"counted_before": before.cases.get("entries", []), "counted_after": after.cases.get("entries", [])}


## A presentation snapshot as this listener hears it: nothing private of its own.
static func _as_heard(snap: Dictionary, listener: Dictionary) -> Dictionary:
	snap.private_evidence = []
	snap["watched"] = []
	snap.listener = listener.duplicate(true)
	return snap


## The cards a case withdrawn in public introduced stay with each listener as testimony the
## player passed on, though the argument is taken back (GamePresentation._keep_receipts,
## the same entries; Codex on #326).
static func _kept_receipts(g, number: int, listener: Dictionary, into: Dictionary) -> void:
	var Canvas = preload("res://game/workshop_canvas.gd")
	var snap: Dictionary = _as_heard(Canvas.snapshot(g, g.board[number - 1].workshop_case, "", "meeting"), listener)
	var endorsed: Array = Shared.endorsed_facts(snap, snap.root)
	var day: int = int(g.board[number - 1].get("withdrawn_day", g.w.day))
	for receipt in snap.get("evidence", []):
		if receipt.id in snap.get("selected", []) and receipt.id in endorsed:
			var eid: String = "tell:kept:%d:%s" % [number, str(receipt.id)]
			into[eid] = {"eid": eid, "effects": [], "weight": 0.0, "rel": ["player", day, "tell"], "day": day, "times": 1,
				"justs": [], "meta": {"kind": "tell", "workshop_card": receipt.duplicate(true),
				"text": str(receipt.get("text", "")), "kept_from_case": number}}


## Every earlier version `number` and its own ancestors revise, into `into`.
static func _ancestors(g, number: int, into: Dictionary) -> void:
	while number > 0 and number <= g.board.size() and not into.has(number):
		into[number] = true
		number = int(g.board[number - 1].get("revises", 0))


## The player's public cases in the order the town last heard them (Codex on #326): a real
## listener's store moves a case to the end each time it is put (WorkshopPresentation._present),
## and the connections model's replacement rule reads that order. Read from the living minds
## that hold them; a case none holds goes by the day it was put.
static func _heard_order(g) -> Array:
	var order: Array = []
	for real in g.w.living():
		var mind = real.shadow if real.is_evil() and real.shadow != null else real
		var held: Array = []
		for key in mind.workshop_state.get("presentations", {}):
			if str(key).is_valid_int() and g.public_presentations.has(int(key)) and not (int(key) in held):
				held.append(int(key))
		if held.size() > order.size():
			order = held
	var rest: Array = g.public_presentations.keys().map(func(x): return int(x)).filter(func(x): return x >= 1 and x <= g.board.size() and not (x in order))
	rest.sort_custom(func(a, b): return _put_day(g, a) < _put_day(g, b) or (_put_day(g, a) == _put_day(g, b) and a < b))
	return order.filter(func(x): return x >= 1 and x <= g.board.size()) + rest


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
		var card: Dictionary = GameBoard.receipt_by_number(g, int(number))
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
		return {"ready": false, "issues": plan.get("issues", []).duplicate(), "prior": {}, "cases": {}, "plan": {}}
	var proposal: Dictionary = Shared.evaluate(plan, {}, {}, {}, {})
	var cx: Dictionary = proposal.get("connections", {})
	# A person nothing held touches keeps the prior (the model reports no posterior for them).
	var post: Dictionary = cx.get("prior", {}).duplicate()
	post.merge(cx.get("posterior", {}), true)
	var requested: Dictionary = {}
	for id in proposal.get("effects", {}):
		requested[id] = float(proposal.effects[id].get("requested", 0.0))
	return {"ready": true, "issues": [], "posterior": post, "prior": cx.get("prior", {}), "cases": cx.get("cases", {}), "requested": requested, "plan": plan}
