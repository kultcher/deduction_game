## One supported presentation path: assessment, parked legacy receipt, social response.
## Runs only on a good mind (including evil's cover). No actual evil intelligence enters.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Mind = preload("res://sim/mind.gd")
const Deduction = preload("res://sim/deduction.gd")
const PresentationReply = preload("res://sim/presentation_reply.gd")
const Profiler = preload("res://workshop/profiler.gd")
const Recency = preload("res://sim/recency.gd")
const Ownership = preload("res://game/workshop_ownership.gd")
const Circumstantial = preload("res://workshop/circumstantial.gd")
const Presentations = preload("res://sim/dialogue_presentations.gd")

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
	if not preload("res://game/game_presentation.gd")._all_authoring_validation_issues(issues):
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
		var rep_tic_mem: Dictionary = Mind._tic_memory(n) if (speak and not n.silenced and not n.is_shadow) else {}
		var rep_line: Dictionary = Presentations.render_repeat(n, existing.venue != "private", text, rep_tic_mem)
		result.lines = [rep_line] if speak and not n.silenced else []
		result.repeated = true
		result.dialogue.special = text
		result.dialogue["voiced_text"] = rep_line["text"]
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
	# Recency: the presented cards are back on this listener's mind, and a case argued at a
	# meeting puts its subject on the town's topic (sim/recency.gd). Settled before the
	# capture, so this presentation is judged with the attention it creates and an
	# unchanged repeat finds the same inputs.
	Recency.refresh_cards(g.w, n, snapshot.selected)
	if venue != "private":
		var argued_root: Array = snapshot.arguments.filter(func(a): return a.board_number == snapshot.root)
		var argued: String = str(argued_root[0].conclusion.get("a", argued_root[0].conclusion.get("target", ""))) if not argued_root.is_empty() else ""
		if argued != "" and not g.w.meeting_arguments.any(func(e): return e.day == g.w.day and e.target == argued):
			g.w.meeting_arguments.append({"day": g.w.day, "target": argued})
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
	Mind.refresh_beliefs(g.w, n, " (interpreted presentation)")
	Profiler.close(initial_span)
	if not state.get("active", false) or not g._workshop_plans.has(listener_key):
		# An interval-derived budget can change during refresh. Do not leave
		# an unsupported endorsement behind when blocking the presentation.
		state.presentations = previous
		state.attention_focus = previous_focus
		Mind.refresh_beliefs(g.w, n, " (presentation capability fallback)")
		return _unavailable(g, n, card, "ownership", state.get("issues", ["Ownership was not activated."]))
	var plan: Dictionary = g._workshop_plans[listener_key]
	# Rebuild against final interval reliability, matching the applied union.
	plan.input.listener.source_doubt = state.get("source_doubt", {}).duplicate(true)
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
	var trapped_out: bool = false
	var trapped_canonical: String = ""
	var trapped_voiced: String = ""
	if not repeated and not n.is_shadow and n.secret_mod != "sleepwalker":
		for dispute in snapshot.arguments[0].get("workshop_case", {}).get("disputes", []):
			var alibis: Array = snapshot.evidence.filter(func(e): return e.id == dispute.challenged and n.id in e.subjects)
			if not alibis.is_empty() and str(n.history.get(g.w.time_key(alibis[0].observed_at.day, 3), "")).begins_with("night:") and dispute.preferred in assessment.reasoning.considered:
				trapped_canonical = "Fine, I was out. Doesn't mean I was doing anything wrong."
				trapped_voiced = Mind.Dialogue.voice_line(n.id, "trapped_night_out", trapped_canonical)
				text = trapped_voiced
				trapped_out = true
				break
	var repeated_same_audience: bool = repeated and state.get("delivered", {}).get(delivery_key, "") == inputs
	if repeated_same_audience:
		text = "Those are the same reports. My assessment is unchanged."
	elif targets.size() > 1:
		for claim in assessment.claims:
			if claim.conclusion.target in targets.slice(1):
				text += " About %s: %s" % [g.w.by_id[claim.conclusion.target].name, claim.note]
	if direction != "deduction":
		for target in targets:
			preload("res://game/credibility.gd").record(n, "good" if direction == "defend" else "evil", target, g.w.day, Tuning.Trust.CRED_WEIGHT_FORMAL)
			var eid = "workshop:tell:%s:%s" % [key, target]
			var meta = {"kind": "tell", "workshop_card": Evidence.normalize_card(card), "text": card.get("text", ""), "conclusion": root.conclusion.duplicate(true)}
			if card.get("kind") == "deduction":
				meta = {"kind": "arg", "workshop_conclusion": root.conclusion.type, "conclusion": root.conclusion.duplicate(true), "workshop_roots": Shared.roots([card], g.all_receipts()),
					"workshop_case": key, "supports": PresentationReply.support_refs([card], g.all_receipts())}
			var scoped: Array = assessment.claims.filter(func(c): return c.conclusion.target == target and c.conclusion.type == root.conclusion.type)
			var agreement: float = scoped[0].agreement if not scoped.is_empty() else assessment.agreement
			Mind.ledger_hear(g.w, n, eid, [], maxf(0.0, agreement), Mind.support_ref(card), meta)
	var voiced_stance: String = assessment.stance
	var already_aligned: bool = false
	var fell: bool = false  # the case moved their belief away from the claim
	if not repeated and text == assessment.response and stance_subject != "" and g.w.by_id.has(stance_subject):
		var after_susp: float = n.suspicion.get(stance_subject, 0.1)
		already_aligned = stance_before <= 0.15 if headline.conclusion.type in ["good", "marked"] else stance_before >= 0.48
		text = _belief_stance_text(g, n, headline.conclusion.type, stance_subject, stance_before, assessment.stance, text, fresh.is_empty())
		if headline.conclusion.type in ["evil", "demon", "minion", "suspicious", "good", "marked"]:
			var b_stance: String = belief_stance(headline.conclusion.type, stance_before, after_susp)
			# Nothing new (or already convinced) keeps an accepting reply, but only if their belief
			# didn't move away: a case that lowered their suspicion isn't voiced as agreement
			# (Dorian, playtest 12926 day 4: "it changes how I see Kiran", then a no vote).
			fell = belief_toward(headline.conclusion.type, stance_before, after_susp) <= -STANCE_MOVE.partial
			voiced_stance = assessment.stance if (b_stance == "reject" and not fell and (fresh.is_empty() or already_aligned) and assessment.stance == "accept") else b_stance
	if not state.has("rewarded_facts"):
		state.rewarded_facts = {}
	for id in snapshot.selected:
		state.rewarded_facts[id] = true
	var trust_before: float = n.trust
	var pressure_before: float = n.pressure
	var self_support: bool = direction == "defend" and targets == [n.id] and venue == "private"
	var self_support_variant: String = ""
	if self_support:
		# Beliefs use the shared receipts; appreciation remains the original social
		# response. Knowing oneself good supplies no evidential agreement bonus.
		var support_key = "support_self:" + Mind.fact_id(card)
		var already: bool = n.heard.has(support_key)
		n.heard[support_key] = n.heard.get(support_key, 0) + 1
		if already:
			self_support_variant = "repeat"
			text = "You've told me that already. Thank you."
		elif Mind.card_clears(card, n.id, true):
			Mind.set_trust(g.w, n, n.trust + Tuning.Trust.SELF_SUPPORT_BONUS, "the Demonologist spoke up for me")
			Mind.refresh_beliefs(g.w, n, " (self-support rapport)")
			self_support_variant = "thanks"
			text = "Thank you for believing me."
		else:
			self_support_variant = "weak"
			text = "I appreciate the support, but I'm not sure that explains it."
	elif not repeated:
		# Premises pass step 1: a well-supported premise earns trust, a clearly wrong one
		# costs the same. Both are judged on the case plus the listener's own readings.
		var reward_span = Profiler.open("trust_reward")
		# Always judged on the narrower pass: the broader assessment's sign doesn't bound it
		# (hearsay can lift a case its own cards and the listener's readings argue against;
		# Codex review of PR #92).
		var judged: float = float(assessment.agreement)
		if root.conclusion.type != "conflict":
			judged = _reward_agreement(plan, snapshot, state.outside, assessment)
		if not fresh.is_empty() and judged >= 0.6:
			Mind.set_trust(g.w, n, n.trust + Tuning.Trust.PRESENTATION_REWARD, "the presented reports support the argument")
			Mind.refresh_beliefs(g.w, n, " (presentation trust reward)")
		elif judged <= Tuning.Trust.PRESENTATION_WRONG_AGREEMENT and root.conclusion.type != "conflict":
			Mind.set_trust(g.w, n, n.trust - Tuning.Trust.PRESENTATION_WRONG_COST, "the presented reports argue against the claim")
			Mind.refresh_beliefs(g.w, n, " (presentation wrong-premise cost)")
		if _challenge_backfired(plan, snapshot, state.outside, assessment):
			# Premises step 3: doubting a reading the evidence backs up costs the same; a
			# neutral challenge costs nothing. Judged on the case plus own readings.
			Mind.set_trust(g.w, n, n.trust - Tuning.Trust.PRESENTATION_WRONG_COST, "the doubted reading holds up")
			Mind.refresh_beliefs(g.w, n, " (challenge backfire cost)")
		Profiler.close(reward_span)
	# The premise's agreement gates its protect / believed-role preference (Mind).
	if not state.has("presentation_agreement"):
		state.presentation_agreement = {}
	state.presentation_agreement[key] = float(assessment.agreement)
	Mind._refresh_ledger_preferences(g.w, n)
	var presented_hubs: Array = root.get("workshop_case", {}).get("circumstantial", [])
	var hub_canonical_tail: String = ""
	var hub_voiced_tail: String = ""
	if not presented_hubs.is_empty() and not self_support and not repeated:
		var post_s1_view: Dictionary = {}
		for pid in state.outside:
			post_s1_view[pid] = clampf(float(state.outside[pid]) + float(state.requested.get(pid, 0.0)), 0.0, 1.5)
		var smear: Dictionary = Circumstantial.evaluate_smear_backlash(
			plan.prepared.view,
			presented_hubs,
			state.outside,
			state.requested,
			post_s1_view,
			n.npc_trust,
			n.id,
			state.get("public_good", []),
			root.get("workshop_case", {}).get("disputes", [])
		)
		if smear.penalty > 0.0:
			if not state.has("smear_penalized"):
				state.smear_penalized = {}
			if not state.smear_penalized.has(signature):
				state.smear_penalized[signature] = true
				Mind.set_trust(g.w, n, n.trust - smear.penalty, "the Demonologist padded a case with thin circumstantial smears")
				Mind.refresh_beliefs(g.w, n, " (circumstantial smear backlash)")
			var smear_fb: String = "Thin guilt-by-association doesn't make a case for me."
			hub_canonical_tail = " " + smear_fb
			hub_voiced_tail = " " + Mind.Dialogue.voice_line(n.id, "circumstantial_smear_pushback", smear_fb)
			text += hub_voiced_tail
		elif stance_subject != "" and float(state.get("circumstantial_applied", {}).get(stance_subject, 0.0)) > 0.0 and g.w.by_id.has(stance_subject):
			var s_name: String = g.w.by_id[stance_subject].name
			var hub_fb: String = "Taken with the rest of your case, those surrounding circumstances make %s harder to wave away." % s_name
			hub_canonical_tail = " " + hub_fb
			hub_voiced_tail = " " + Mind.Dialogue.voice_line(n.id, "circumstantial_hub_landed", "Taken with the rest of your case, those surrounding circumstances make {target} harder to wave away.", {"target": s_name})
			text += hub_voiced_tail
	if root.conclusion.type == "suspicious" and direction == "deduction" and not self_support:
		_suspicious_pressure(g, n, root, snapshot, venue, listener_key, key)
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
	var base_canonical: String = text
	if hub_voiced_tail != "" and base_canonical.ends_with(hub_voiced_tail):
		base_canonical = base_canonical.substr(0, base_canonical.length() - hub_voiced_tail.length()) + hub_canonical_tail
	if trapped_out and base_canonical.begins_with(trapped_voiced):
		base_canonical = trapped_canonical + base_canonical.substr(trapped_voiced.length())
	var tic_mem: Dictionary = Mind._tic_memory(n) if (speak and not n.silenced and not n.is_shadow) else {}
	var spoken_line: Dictionary
	if trapped_out:
		spoken_line = {"speaker": n.id, "name": n.name, "text": text, "statement": base_canonical}
	elif self_support:
		spoken_line = Presentations.render_self_support(n, self_support_variant, base_canonical, tic_mem)
	elif repeated_same_audience:
		spoken_line = Presentations.render_repeat(n, venue != "private", base_canonical, tic_mem)
	else:
		spoken_line = Presentations.render_workshop_reply(g.w, n, root.conclusion, targets, assessment, plan.prepared.view, snapshot, voiced_stance, already_aligned and not fell, fresh.is_empty() and not fell, base_canonical, tic_mem)
		if hub_voiced_tail != "":
			spoken_line["text"] = str(spoken_line["text"]) + Mind.Dialogue.apply_tics(n.id, hub_voiced_tail, tic_mem)
	var descriptor_special: String = text if trapped_out else base_canonical
	var descriptor = {"kind": "argument", "key": signature, "facts": snapshot.selected, "stance": voiced_stance,
		"claim": card.get("text", "the presented case"), "target_id": root.conclusion.get("a", ""), "special": descriptor_special, "voiced_text": spoken_line["text"]}
	var lines: Array = [spoken_line] if speak and not n.silenced else []
	g.w.dlog.trace_event("workshop_presentation", n.id, root.conclusion.get("a", ""),
		{"venue": venue, "key": key, "agreement": assessment.agreement, "stance": assessment.stance,
		"reading_challenges": assessment.get("reading_challenges", []),
		"repeated": repeated, "fresh": fresh, "claims": assessment.claims, "response": text,
		"reasoning": assessment.reasoning, "theory": assessment.theory, "cognition": cognitive_inputs,
		"quoted": state.get("quoted", []), "trust_before": trust_before, "trust_after": n.trust,
		"pressure_delta": n.pressure - pressure_before, "requested": state.requested,
		"circumstantial_requested": state.get("circumstantial_requested", {})}, "One assessment controls supported presentation and shared belief ownership.")
	g.w.dlog.add("argument_stance", n.id, root.conclusion.get("a", ""), {"key": signature, "stance": voiced_stance, "scoped_stance": assessment.stance,
		"evil": false, "repeat": repeated, "model": "shared"})
	# A public case they said they accepted: if they then vote no on that person, they say
	# why (meeting plan M2d, vote resistance lines).
	var ctype: String = str(root.conclusion.get("type", ""))
	var ctarget: String = str(root.conclusion.get("a", root.conclusion.get("target", "")))
	if venue != "private" and voiced_stance == "accept" and ctarget != "" and ctype in ["evil", "demon", "minion", "suspicious"]:
		if not n.dialogue_memory.has("accepted_cases"):
			n.dialogue_memory["accepted_cases"] = {}
		n.dialogue_memory["accepted_cases"][ctarget] = {"day": g.w.day, "key": key}
	var result = {"lines": lines, "facts": [], "agreement": assessment.agreement, "repeated": repeated,
		"dialogue": descriptor, "workshop": true, "assessment": assessment}
	g._workshop_repeats[repeat_key] = {"input": state.discussion[signature], "result": result.duplicate(true)}
	return result

## Replies must match beliefs (BACKLOG, decided Oct 26). The scoped reply and the belief
## refresh are separate assessments with different attention, so a listener could say
## "I couldn't follow it" while their suspicion moved as if convinced (54875). The stance
## they voice now comes from how far the refresh actually moved the subject; the scoped
## reply only supplies the reasons. Nothing here changes a belief, only the words.
const STANCE_MOVE = Tuning.Workshop.STANCE_MOVE   # suspicion moved toward the claim
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
	"The evidence I considered weighs against this conclusion; my search was limited.",
	"The reports I considered point away from that conclusion.",
	"The accounts I considered conflict with each other, and do not establish that conclusion.",
	"I checked another explanation that also fits, but the movement evidence makes your explanation more convincing. This is persuasion, not a proof that the alternative is impossible.",
	"I checked another explanation that also fits, but the trace evidence makes your explanation more convincing. This is persuasion, not a proof that the alternative is impossible.",
	"I checked another explanation that also fits, but the movement and trace evidence makes your explanation more convincing. This is persuasion, not a proof that the alternative is impossible.",
]

## Premises pass step 2: a "suspicious" filing heard at half weight puts the other half on
## its target as pressure, once per filing (target and cards): the average full-weight rise
## across everyone who heard it, scaled by venue. Each new listener updates the average;
## the target gets only the change, so a meeting gives the average and a refiling nothing.
static func _suspicious_pressure(g, n, root: Dictionary, snapshot: Dictionary, venue: String, listener_key: String, key: String = "") -> void:
	var target_id: String = str(root.conclusion.get("a", root.conclusion.get("target", "")))
	if target_id == "" or target_id == n.id or not g.w.by_id.has(target_id):
		return
	var effect: Dictionary = g._workshop_evaluations.get(listener_key, {}).get("proposal", {}).get("effects", {}).get(target_id, {})
	var rise: float = maxf(0.0, float(effect.get("suspicious_case_full", 0.0)))
	# The remembered suspicious union's rise covers every suspicious filing this listener
	# holds. With another one there, measure this filing's own share: the full union
	# against the union without it (Codex review of PR #93).
	var others: Array = _other_suspicious(n, key)
	if not others.is_empty():
		rise = maxf(0.0, _filing_rise(g, n, listener_key, key, target_id))
	var ids: Array = snapshot.selected.duplicate()
	ids.sort()
	var filing: String = target_id + "|" + ",".join(PackedStringArray(ids))
	var book: Dictionary = g.w.suspicious_pressure
	var entry: Dictionary = book.get(filing, {"sum": 0.0, "count": 0, "applied": 0.0, "venue": venue, "heard": []})
	if n.id in entry.heard:
		return
	if entry.count > 0 and entry.venue != venue:
		return  # pressure comes from the first hearing; telling another audience adds none
	entry.heard.append(n.id)
	entry.sum += rise
	entry.count += 1
	var scale: float = float(Tuning.Workshop.SUSPICIOUS_PRESSURE_PER_RISE.get("private" if venue == "private" else "meeting", 1.0))
	var due: float = scale * entry.sum / float(entry.count)
	var delta: float = due - float(entry.applied)
	entry.applied = due
	book[filing] = entry
	var target = g.w.by_id[target_id]
	if not is_zero_approx(delta):
		target.pressure = maxf(0.0, target.pressure + delta)
		g.w.dlog.trace_event("value_change", target_id, n.id, {"quantity": "pressure", "delta": delta, "rise": rise, "filing": filing, "venue": venue},
			"A suspicious case presses its subject to explain (premises step 2)")

## The listener's other remembered (not withdrawn) suspicious filings, besides `key`.
static func _other_suspicious(n, key: String) -> Array:
	var state: Dictionary = n.workshop_state
	var withdrawn: Dictionary = state.get("withdrawn", {})
	var out: Array = []
	for k in state.get("presentations", {}):
		if str(k) == key or withdrawn.has(k) or str(k).begins_with("direct:"):
			continue
		if Shared._root_type(state.presentations[k]) == "suspicious":
			out.append(str(k))
	return out

## The rise in `target_id`'s requested change that the filing `key` brings, at full weight:
## the unshaped union with it against the union without it.
static func _filing_rise(g, n, listener_key: String, key: String, target_id: String) -> float:
	var plan: Dictionary = g._workshop_plans.get(listener_key, {})
	if not plan.get("ready", false):
		return 0.0
	var state: Dictionary = n.workshop_state
	var rest: Dictionary = state.get("presentations", {}).duplicate()
	rest.erase(key)
	var without: Dictionary = Shared.prepare(plan.input, rest, n.ledger, state.get("withdrawn", {}), state.get("attention_focus", []))
	if not without.get("ready", false):
		return 0.0
	var doubt: Dictionary = state.get("source_doubt", {})
	var with_e: Dictionary = Shared.evaluate(plan, n.suspicion, doubt, doubt).get("effects", {}).get(target_id, {})
	var without_e: Dictionary = Shared.evaluate(without, n.suspicion, doubt, doubt).get("effects", {}).get(target_id, {})
	return float(with_e.get("requested", 0.0)) - float(without_e.get("requested", 0.0))

## How far the belief moved toward the claim (negative: away from it).
static func belief_toward(kind: String, before: float, after: float) -> float:
	return (before - after) if kind in ["good", "marked"] else (after - before)

static func belief_stance(kind: String, before: float, after: float) -> String:
	var toward: float = belief_toward(kind, before, after)
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
	for lead_s in STANCE_ONLY:
		if reasons.begins_with(lead_s):
			reasons = reasons.substr(lead_s.length()).strip_edges()
			break
	if believed == "reject":
		reasons = Shared.Jury.strip_accept_persuasion_tail(reasons)
	var name: String = g.w.by_id[subject].name
	var lead: String
	match believed:
		"accept":
			lead = "it does change how I see %s." % name
		"partial":
			lead = "it moves me a little on %s." % name
		_:
			var already: bool = before <= 0.15 if kind in ["good", "marked"] else before >= 0.48
			if nothing_new and belief_toward(kind, before, after) > -STANCE_MOVE.partial:
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
	return JSON.stringify(Evidence.canonical([root.conclusion, ids, choices])).sha256_text()

static func _discussion_inputs(n, snapshot: Dictionary) -> String:
	var state: Dictionary = n.workshop_state
	var cognition = [state.get("reasoning_mode", "bounded"), n.traits.get("insight", 0.5),
		state.get("confidence_mode", "scale"), n.traits.get("confidence", 0.5)]
	return JSON.stringify(Evidence.canonical([state.get("outside", n.suspicion), state.get("facts", []),
		state.get("attention_focus", []), state.get("source_doubt", {}), n.trust, n.npc_trust, n.role, snapshot.public_events, cognition])).sha256_text()

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

## Premises step 3: did a challenge in this case backfire for this listener, judged like the
## trust reward on the case cards plus their own readings?
static func _challenge_backfired(plan: Dictionary, snapshot: Dictionary, outside: Dictionary, assessment: Dictionary) -> bool:
	var broad: Array = assessment.get("reading_challenges", [])
	if broad.is_empty():
		return false
	# Always the narrower pass (as for the wrong-premise cost): hearsay can't decide it.
	var narrow: Dictionary = Shared.response(plan, snapshot, outside, true)
	var results: Array = narrow.get("reading_challenges", broad) if not narrow.is_empty() else broad
	return results.any(func(r): return r.get("backfire", false))

## Agreement for the trust reward: the case cards plus the listener's own readings only, not
## hearsay the player may never have heard (premises pass, step 0b). A listener with no
## hearsay in view gets the same number as the reply, so skip the second pass then.
static func _reward_agreement(plan: Dictionary, snapshot: Dictionary, outside: Dictionary, assessment: Dictionary) -> float:
	var me: String = str(plan.prepared.listener.get("id", ""))
	var considered: Array = assessment.get("reasoning", {}).get("considered", [])
	var extra: bool = plan.prepared.view.cards.any(func(c): return c.id in considered and c.id not in snapshot.selected and not (str(c.get("kind", "")) == "report" and str(c.get("source", "")) == me))
	if not extra:
		return float(assessment.agreement)
	var narrow: Dictionary = Shared.response(plan, snapshot, outside, true)
	return float(narrow.get("agreement", 0.0)) if not narrow.is_empty() else float(assessment.agreement)
