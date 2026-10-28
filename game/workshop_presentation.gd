## One supported presentation path: assessment, parked legacy receipt, social response.
## Runs only on a good mind (including evil's cover). No actual evil intelligence enters.
extends RefCounted
const Bridge = preload("res://game/workshop_bridge.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Mind = preload("res://sim/mind.gd")
const Argue = preload("res://sim/argue.gd")
const Profiler = preload("res://workshop/profiler.gd")
const Ownership = preload("res://game/workshop_ownership.gd")

## Pure capability check against the real listener and the proposed evidence union.
## Used for the entire audience before a command spends time or discloses secrets.
static func readiness(g, n, card: Dictionary, targets: Array, direction: String, venue: String) -> Dictionary:
	var snapshot = _snapshot(g, n, card, targets, direction, venue)
	if snapshot.is_empty():
		return {"ready": false, "issues": ["Card #%d is missing, stale, or has no supported target." % card.get("n", 0)], "exit_point": "snapshot"}
	var prepared = Assess.prepare(snapshot)
	if not prepared.ready:
		return {"ready": false, "issues": prepared.issues, "exit_point": "assessment"}
	var proposals: Dictionary = n.workshop_state.get("presentations", {}).duplicate(true)
	var withdrawn: Dictionary = n.workshop_state.get("withdrawn", {}).duplicate(true)
	var ancestor: int = card.get("revises", 0)
	while ancestor > 0 and ancestor <= g.board.size():
		for path in proposals.keys():
			if str(path).begins_with("direct:%d:" % ancestor):
				proposals.erase(path)
				withdrawn[path] = true
		proposals.erase(str(ancestor))
		withdrawn[str(ancestor)] = true
		ancestor = g.board[ancestor - 1].get("revises", 0)
	proposals[_key(card, targets, direction, snapshot)] = snapshot
	var plan = Shared.prepare(Bridge.capture(g, [], n.id, venue, n), proposals, n.ledger, withdrawn, snapshot.selected)
	return {"ready": plan.ready, "issues": plan.issues, "exit_point": "union"}

static func _key(card: Dictionary, targets: Array, direction: String, snapshot: Dictionary) -> String:
	var ids: Array = snapshot.selected.duplicate()
	ids.sort()
	var people = targets.duplicate()
	people.sort()
	var origin = str(card.n) if card.get("n", 0) > 0 else JSON.stringify(ids).sha256_text()
	return str(card.n) if direction == "deduction" else "direct:%s:%s:%s" % [origin, direction, ",".join(PackedStringArray(people))]

static func _unavailable(g, n, card: Dictionary, point: String, issues: Array) -> Dictionary:
	Ownership.fallback(g, n, point, issues, card.get("n", 0))
	# No legacy route for presentations (user, Oct 25): block with the reason.
	return {"blocked": true, "lines": ["Cannot present card #%d: %s" % [card.get("n", 0), "; ".join(PackedStringArray(issues))]], "facts": [], "agreement": 0.0}

static func present(g, n, card: Dictionary, targets: Array, direction: String, venue: String, speak: bool) -> Dictionary:
	var span = Profiler.open("presentation")
	var result = _present(g, n, card, targets, direction, venue, speak)
	Profiler.close(span)
	return result

static func _present(g, n, card: Dictionary, targets: Array, direction: String, venue: String, speak: bool) -> Dictionary:
	if n.is_evil():
		return {}
	var capability = readiness(g, n, card, targets, direction, venue)
	if not capability.ready:
		return _unavailable(g, n, card, capability.exit_point, capability.issues)
	if card.has("workshop_case"):
		g.workshop_canvas_retire(n, card)
	var snapshot = _snapshot(g, n, card, targets, direction, venue)
	if snapshot.is_empty() or not Assess.prepare(snapshot).ready:
		return _unavailable(g, n, card, "snapshot", ["Evidence changed after the readiness check."])
	var state: Dictionary = n.workshop_state
	var signature = _signature(snapshot)
	var listener_key = n.id + (":cover" if n.is_shadow else ":good")
	var repeat_key = listener_key + "|" + signature
	var cached_repeat: Dictionary = g._workshop_repeats.get(repeat_key, {})
	var existing: Dictionary = state.get("presentations", {}).get(_key(card, targets, direction, snapshot), {})
	if state.get("active", false) and not existing.is_empty() and cached_repeat.get("input", "") == _discussion_inputs(n, snapshot) and not (existing.venue == "private" and venue != "private"):
		Profiler.count("repeat_no_assessment")
		var result: Dictionary = cached_repeat.result.duplicate(true)
		var text = "I heard you say that at the meeting. My assessment is unchanged." if existing.venue != "private" else "You've heard this from me already. My assessment is unchanged."
		result.lines = [Mind.say(n, text)] if speak and not n.silenced else []
		result.repeated = true
		result.dialogue.special = text
		g.w.dlog.trace_event("workshop_repeat", n.id, "", {"card": card.get("n", 0), "venue": venue}, "Reuse an unchanged discussion without evaluating or rewarding it again.")
		return result
	var original_ids: Array = snapshot.selected.duplicate()
	original_ids.sort()
	var target_ids = targets.duplicate()
	target_ids.sort()
	var origin = str(card.n) if card.get("n", 0) > 0 else JSON.stringify(original_ids).sha256_text()
	var key = str(card.n) if direction == "deduction" else "direct:%s:%s:%s" % [origin, direction, ",".join(PackedStringArray(target_ids))]
	var previous: Dictionary = state.get("presentations", {}).duplicate(true)
	var proposals: Dictionary = previous.duplicate(true)
	proposals[key] = snapshot
	var current = Bridge.capture(g, [], n.id, venue, n)
	var proposed = Shared.prepare(current, proposals, n.ledger, state.get("withdrawn", {}), snapshot.selected)
	if not proposed.ready:
		return _unavailable(g, n, card, "proposals", proposed.issues)
	var earlier: Array = state.get("facts", []).duplicate()
	var novelty_ids = Shared.endorsed_facts(snapshot, snapshot.root)
	var headline: Dictionary = snapshot.arguments.filter(func(a): return a.board_number == snapshot.root)[0]
	if headline.conclusion.type == "conflict":
		novelty_ids = snapshot.selected
	var fresh: Array = novelty_ids.filter(func(id): return id not in earlier and not state.get("rewarded_facts", {}).has(id))
	state.enabled = true
	var previous_focus: Array = state.get("attention_focus", []).duplicate()
	state["attention_focus"] = original_ids.duplicate()
	state.presentations = proposals
	state.get("withdrawn", {}).erase(key)
	if not state.has("disclosures"):
		state.disclosures = {}
	for id in snapshot.selected:
		if not state.disclosures.has(id):
			state.disclosures[id] = {"player": true, "public": false}
		if venue != "private":
			state.disclosures[id].public = true
	# What they say follows what the case did to their belief (see _belief_stance_text).
	var stance_subject: String = headline.conclusion.get("a", "")
	var stance_before: float = n.suspicion.get(stance_subject, 0.1)
	var initial_span = Profiler.open("initial_refresh")
	Mind.recompute_beliefs(g.w, n, " (interpreted presentation)")
	Profiler.close(initial_span)
	if not state.get("active", false):
		# An interval-derived budget can change during recomputation. Do not leave
		# an unsupported endorsement behind when returning to native presentation.
		state.presentations = previous
		state.attention_focus = previous_focus
		Mind.recompute_beliefs(g.w, n, " (presentation capability fallback)")
		return _unavailable(g, n, card, "ownership", state.get("issues", ["Ownership was not activated."]))
	var plan: Dictionary = g._workshop_plans[listener_key]
	# Rebuild against final interval reliability, matching the applied union.
	plan.input.listener.discounted = n.discounted.duplicate(true)
	plan.input.listener.theories = state.get("theories", {}).duplicate(true)
	plan = Shared.prepare(plan.input, proposals, n.ledger, state.get("withdrawn", {}), snapshot.selected)
	var response_input = [plan.prepared, snapshot.arguments, snapshot.root, snapshot.board_map, snapshot.selected,
		snapshot.evidence.filter(func(e): return e.id in snapshot.selected), state.outside]
	var cached: Dictionary = g._workshop_responses.get(listener_key, {})
	var assessment: Dictionary
	if cached.get("input") == response_input:
		Profiler.count("response_cache_hit")
		assessment = cached.assessment
	else:
		Profiler.count("response_cache_miss")
		var response_span = Profiler.open("scoped_response")
		assessment = Shared.response(plan, snapshot, state.outside)
		Profiler.close(response_span)
		g._workshop_responses[listener_key] = {"input": response_input.duplicate(true), "assessment": assessment}
	if assessment.is_empty():
		return _unavailable(g, n, card, "response", ["The shared response could not be assessed."])
	var root: Dictionary = snapshot.arguments.filter(func(a): return a.board_number == snapshot.root)[0]
	var cognitive_inputs = [plan.prepared.listener.reasoning_mode, plan.prepared.listener.insight,
		plan.prepared.listener.confidence_mode, plan.prepared.listener.confidence]
	var inputs = _discussion_inputs(n, snapshot)
	var discussion: Dictionary = state.get("discussion", {})
	var repeated: bool = discussion.get(signature, "") == inputs
	var audience = "player" if venue == "private" else "town"
	var delivery_key = signature + "|" + audience
	var text: String = assessment.response
	if not repeated and not n.is_shadow and n.secret_mod != "sleepwalker":
		for dispute in snapshot.arguments[0].get("workshop_case", {}).get("disputes", []):
			var alibis: Array = snapshot.evidence.filter(func(e): return e.id == dispute.challenged and n.id in e.subjects)
			if not alibis.is_empty() and str(n.history.get(g.w.time_key(alibis[0].observed_at.day, 3), "")).begins_with("night:") and dispute.preferred in assessment.reasoning.considered:
				text = "Fine, I was out. Doesn't mean I was doing anything wrong."
				break
	if repeated and state.get("delivered", {}).get(delivery_key, "") == inputs:
		text = "Those are the same reports. My assessment is unchanged."
	elif targets.size() > 1:
		for claim in assessment.claims:
			if claim.conclusion.target in targets.slice(1):
				text += " About %s: %s" % [g.w.by_id[claim.conclusion.target].name, claim.note]
	# Keep a compatible native contribution parked underneath the owner. It can be
	# restored on fallback/disable; its agreement comes from this assessment too.
	if direction == "deduction":
		var supports: Array = g.board.filter(func(c): return c.n in card.supports)
		var park_span = Profiler.open("park_native")
		Argue._apply(g.w, n, card, supports, maxf(0.0, assessment.agreement) * (1.0 if venue == "private" else 0.5 if venue == "nomination" else 0.6), g.board)
		Profiler.close(park_span)
	else:
		for target in targets:
			var sign_value = -0.4 if direction == "defend" else 0.45
			var eid = "workshop:tell:%s:%s" % [key, target]
			var meta = {"kind": "tell", "workshop_card": Evidence.normalize_card(card), "text": card.get("text", "")}
			if card.get("kind") == "deduction":
				meta = {"kind": "arg", "workshop_conclusion": root.conclusion.type, "workshop_roots": Shared.roots([card], g.board),
					"workshop_case": key, "supports": Argue.support_refs([card], g.board)}
			var scoped: Array = assessment.claims.filter(func(c): return c.conclusion.target == target and c.conclusion.type == root.conclusion.type)
			var agreement: float = scoped[0].agreement if not scoped.is_empty() else assessment.agreement
			Mind.ledger_hear(g.w, n, eid, [[target, sign_value, true, "Presented original report", ""]], maxf(0.0, agreement), Mind.support_ref(card), meta)
	var voiced_stance: String = assessment.stance
	if not repeated and text == assessment.response and stance_subject != "" and g.w.by_id.has(stance_subject):
		text = _belief_stance_text(g, n, headline.conclusion.type, stance_subject, stance_before, assessment.stance, text, fresh.is_empty())
		if headline.conclusion.type in ["evil", "demon", "minion", "suspicious", "good", "marked"]:
			voiced_stance = belief_stance(headline.conclusion.type, stance_before, n.suspicion.get(stance_subject, 0.1))
	if not state.has("rewarded_facts"):
		state.rewarded_facts = {}
	for id in snapshot.selected:
		state.rewarded_facts[id] = true
	var trust_before: float = n.trust
	var pressure_before: float = n.pressure
	var self_support: bool = direction == "defend" and targets == [n.id] and venue == "private"
	if self_support:
		# Beliefs use the shared receipts; appreciation remains the original social
		# response. Knowing oneself good supplies no evidential agreement bonus.
		var support_key = "support_self:" + Mind.fact_id(card)
		var already: bool = n.heard.has(support_key)
		n.heard[support_key] = n.heard.get(support_key, 0) + 1
		if already:
			text = "You've told me that already. Thank you."
		elif Mind.defend_strength(card, n.id) >= 0.2:
			Mind.set_trust(g.w, n, n.trust + 0.03, "the Demonologist spoke up for me")
			Mind.recompute_beliefs(g.w, n, " (self-support rapport)")
			text = "Thank you for believing me."
		else:
			text = "I appreciate the support, but I'm not sure that explains it."
	elif assessment.agreement >= 0.6 and not fresh.is_empty() and not repeated:
		var reward_span = Profiler.open("trust_reward")
		Mind.set_trust(g.w, n, n.trust + 0.02, "the presented reports support the argument")
		Mind.recompute_beliefs(g.w, n, " (presentation trust reward)")
		Profiler.close(reward_span)
	if root.conclusion.type == "conflict" and assessment.agreement >= 0.6 and not repeated:
		if not state.has("scrutinized"):
			state.scrutinized = {}
		var sources: Array = snapshot.evidence.filter(func(e): return e.id in snapshot.selected).map(func(e): return e.source)
		if not state.scrutinized.has(signature) and n.id in sources:
			n.pressure += 0.1 if venue == "private" else 0.2
			state.scrutinized[signature] = true
	if not state.has("discussion"):
		state.discussion = {}
	# Trust rewards are part of the new starting inputs on a repeat.
	state.discussion[signature] = _discussion_inputs(n, snapshot)
	if speak and not n.silenced:
		if not state.has("delivered"):
			state.delivered = {}
		state.delivered[delivery_key] = state.discussion[signature]
	var descriptor = {"kind": "argument", "key": signature, "facts": snapshot.selected, "stance": voiced_stance,
		"claim": card.get("text", "the presented case"), "target_id": root.conclusion.get("a", ""), "special": text}
	var lines: Array = [Mind.say(n, text)] if speak and not n.silenced else []
	g.w.dlog.trace_event("workshop_presentation", n.id, root.conclusion.get("a", ""),
		{"venue": venue, "key": key, "agreement": assessment.agreement, "stance": assessment.stance,
		"reading_challenges": assessment.get("reading_challenges", []),
		"repeated": repeated, "fresh": fresh, "claims": assessment.claims, "response": text,
		"reasoning": assessment.reasoning, "theory": assessment.theory, "cognition": cognitive_inputs,
		"quoted": state.get("quoted", []), "trust_before": trust_before, "trust_after": n.trust,
		"pressure_delta": n.pressure - pressure_before, "requested": state.requested}, "One assessment controls supported presentation and shared belief ownership.")
	g.w.dlog.add("argument_stance", n.id, root.conclusion.get("a", ""), {"key": signature, "stance": voiced_stance, "scoped_stance": assessment.stance,
		"evil": false, "repeat": repeated, "model": "shared"})
	var result = {"lines": lines, "facts": [], "agreement": assessment.agreement, "repeated": repeated,
		"dialogue": descriptor, "workshop": true, "assessment": assessment}
	g._workshop_repeats[repeat_key] = {"input": state.discussion[signature], "result": result.duplicate(true)}
	return result

## Replies must match beliefs (BACKLOG, decided Oct 26). The scoped reply and the belief
## refresh are separate assessments with different attention, so a listener could say
## "I couldn't follow it" while their suspicion moved as if convinced (54875). The stance
## they voice now comes from how far the refresh actually moved the subject; the scoped
## reply only supplies the reasons. Nothing here changes a belief, only the words.
const STANCE_MOVE = {"accept": 0.06, "partial": 0.02}   # suspicion moved toward the claim
const STANCE_RANK = {"reject": 0, "partial": 1, "accept": 2}
## Scoped openings that only state a stance (dropped when the belief says otherwise). Any
## other opening is a reason, and stays.
const STANCE_ONLY = [
	"Taken together, those reports convince me.",
	"Those reports convince me, though another explanation is still possible.",
	"That moves me, but the reports also allow another explanation.",
	"I can see that possibility, but it doesn't settle much for me.",
	"I can see that possibility, but the reports also allow another explanation.",
	"Those reports don't change my view of that.",
	"These observations make your explanation convincing to me, though an alternative remains logically possible.",
	"Your explanation fits what I considered. I am provisionally persuaded, but I have not checked another explanation.",
	"I found your explanation coherent, but I am not convinced by its support. I have not checked another explanation.",
	"Your explanation fits what I considered, and none of the alternatives I checked held up.",
	"I found your explanation coherent, though I am not yet convinced by its support.",
	"The supplied evidence weighs against that conclusion.",
]

static func belief_stance(kind: String, before: float, after: float) -> String:
	var toward: float = (before - after) if kind in ["good", "marked"] else (after - before)
	if toward >= STANCE_MOVE.accept:
		return "accept"
	return "partial" if toward >= STANCE_MOVE.partial else "reject"

static func _belief_stance_text(g, n, kind: String, subject: String, before: float, scoped: String, text: String, nothing_new: bool = false) -> String:
	if kind not in ["evil", "demon", "minion", "suspicious", "good", "marked"]:
		return text  # conflicts and the like say nothing about one person's alignment
	var after: float = n.suspicion.get(subject, 0.1)
	var believed: String = belief_stance(kind, before, after)
	g.w.dlog.trace_event("stance_from_belief", n.id, subject, {"kind": kind, "before": before, "after": after,
		"scoped": scoped, "believed": believed}, "The voiced stance follows the belief refresh; the scoped reply gives the reasons.")
	if believed == scoped:
		return text
	var reasons: String = text
	for lead in STANCE_ONLY:
		if reasons.begins_with(lead):
			reasons = reasons.substr(lead.length()).strip_edges()
			break
	var name: String = g.w.by_id[subject].name
	var lead: String
	match believed:
		"accept":
			lead = "it does change how I see %s." % name
		"partial":
			lead = "it moves me a little on %s." % name
		_:
			var already: bool = before <= 0.15 if kind in ["good", "marked"] else before >= 0.7
			if nothing_new:
				lead = "I'd already taken that into account."
			elif already:
				lead = "I'd already come to that about %s." % name
			else:
				lead = "it doesn't change my mind about %s." % name
	if reasons == "":
		return lead[0].to_upper() + lead.substr(1) if believed != "reject" or lead.begins_with("I'd") else "It holds together, but " + lead
	if STANCE_RANK[believed] > STANCE_RANK[scoped]:
		return reasons + " Even so, " + lead
	return reasons + (" " + lead if lead.begins_with("I'd") else " So " + lead)

static func _signature(snapshot: Dictionary) -> String:
	var root: Dictionary = snapshot.arguments.filter(func(a): return a.board_number == snapshot.root)[0]
	var choices: Dictionary = root.get("workshop_case", {}).duplicate(true)
	choices.erase("version")
	var ids: Array = snapshot.selected.duplicate()
	ids.sort()
	return JSON.stringify(Evidence.canonical([root.conclusion, ids, choices]))

static func _discussion_inputs(n, snapshot: Dictionary) -> String:
	var state: Dictionary = n.workshop_state
	var cognition = [state.get("reasoning_mode", "bounded"), n.traits.get("insight", 0.5),
		state.get("confidence_mode", "scale"), n.traits.get("confidence", 0.5)]
	return JSON.stringify(Evidence.canonical([state.get("outside", n.suspicion), state.get("facts", []),
		state.get("attention_focus", []), n.discounted, n.trust, n.npc_trust, n.role, snapshot.public_events, cognition]))

static func _snapshot(g, n, card: Dictionary, targets: Array, direction: String, venue: String) -> Dictionary:
	if direction == "deduction":
		if card.get("n", 0) <= 0 or card.n > g.board.size():
			return {}
		if g.board[card.n - 1].get("conclusion", {}) != card.conclusion or g.board[card.n - 1].get("supports", []) != card.supports or g.board[card.n - 1].get("workshop_case", {}) != card.get("workshop_case", {}):
			return {} # Do not assess a stale wrapper as though it were the current filed case.
		return Bridge.capture(g, [card.n], n.id, venue, n)
	if targets.is_empty():
		return {}
	if card.get("kind") == "deduction":
		if card.get("n", 0) <= 0 or card.n > g.board.size() or g.board[card.n - 1].get("supports", []) != card.get("supports", []) or g.board[card.n - 1].get("conclusion", {}) != card.get("conclusion", {}) or g.board[card.n - 1].get("workshop_case", {}) != card.get("workshop_case", {}):
			return {} # A relay of an old wrapper must not learn a later board revision.
		var cited = Bridge.capture(g, [card.n], n.id, venue, n)
		cited.root = -1
		cited.arguments.append({"board_number": -1, "conclusion": {"type": "good" if direction == "defend" else "suspicious", "a": targets[0]}, "supports": [card.n]})
		for i in range(1, targets.size()):
			cited.arguments.append({"board_number": -2 - i, "conclusion": {"type": "good" if direction == "defend" else "suspicious", "a": targets[i]}, "supports": [card.n]})
		return cited
	var input = Bridge.capture(g, [], n.id, venue, n)
	var receipt = Evidence.normalize_card(card)
	input.evidence.append(receipt)
	input.selected = [receipt.id]
	input.board_map[str(card.get("n", 0))] = receipt.id
	input.root = -1
	input.arguments = [{"board_number": -1, "conclusion": {"type": "good" if direction == "defend" else "suspicious", "a": targets[0]}, "supports": [card.get("n", 0)]}]
	for i in range(1, targets.size()):
		input.arguments.append({"board_number": -2 - i, "conclusion": {"type": "good" if direction == "defend" else "suspicious", "a": targets[i]}, "supports": [card.get("n", 0)]})
	return input
