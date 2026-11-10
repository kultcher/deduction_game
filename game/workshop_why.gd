## Why a presented case moved a listener as far as it did (developer inspection).
##
## The evidence half is workshop/case_why.gd: what the cards are worth and where the
## probability went instead. This is the belief half for a real listener, read back from
## the shared model after the presentation has been applied:
##
##   the suspicion the case could add, if it settled the question outright
##   -> if every card were news, read in full, at face value   (other explanations remain)
##   -> as this listener hears each card                        (hearing weight, trust, doubt)
##   -> within this listener's attention                        (what else crowds in or out)
##   -> against what they already held                          (only new cards add anything)
##   -> after resistance to moving against a lean               (Confidence)
##   -> applied                                                 (the suspicion scale's floor and ceiling)
##   -> action: the vote and nomination bars
##
## Each step re-runs the listener's own union evaluation on copies with one idealisation
## dropped (Shared.prepare / Jury.refresh on duplicates). It draws no game RNG, writes to no
## mind and changes no belief; the caches it touches are value caches. It costs several
## union evaluations per listener, so it only runs on demand: the Workshop's Debug menu,
## `g.workshop_why` (records one per listener when a case is presented), and
## tools/explain_case.gd --why.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Jury = preload("res://workshop/jury.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Why = preload("res://workshop/case_why.gd")
const Canvas = preload("res://game/workshop_canvas.gd")

const KEEP = 24

## The Workshop's test juror, explained: the same neutral listener and inputs as
## WorkshopCanvas.test_juror, with the evidence breakdown and its text.
static func test_juror(g, value: Dictionary) -> Dictionary:
	var input = Canvas.snapshot(g, value)
	input.private_evidence = []
	input.evidence = input.evidence.filter(func(e): return e.id in input.selected)
	input.listener = {"id": "ghost", "name": "Test juror", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "source_doubt": {}, "own_gift": "", "legacy_evidence": []}
	var prepared = Assess.prepare(input)
	if not prepared.ready:
		return {"ready": false, "issues": prepared.issues.duplicate(), "text": "This case can't be judged yet:\n• " + "\n• ".join(PackedStringArray(prepared.issues))}
	var b: Dictionary = Why.evidence(prepared.view, prepared.case)
	b["ready"] = true
	b["listener"] = "test juror"
	b["text"] = "Test juror: public facts and default trust. It hears every card at full weight; a real listener discounts what they're told (tick \"Record why each listener moved\" and present to see theirs).\n" + Why.describe(prepared.view, b, _numbers(g))
	return b

## Board number of each fact id, for the readout.
static func _numbers(g) -> Dictionary:
	var out: Dictionary = {}
	var Evidence = preload("res://workshop/live_evidence.gd")
	for card in g.board:
		if card.get("kind", "") == "deduction" or card.get("deleted", false):
			continue
		var id: String = Evidence.normalize_card(card).id
		if not out.has(id):
			out[id] = int(card.get("n", 0))
	return out

## The mind that judges for this person: themselves, or an evil NPC's good cover.
static func mind_of(real):
	return real.shadow if real.is_evil() and real.shadow != null else real

## One union evaluation of everything `n` holds plus `presentations`, the way
## WorkshopOwnership runs it (premise shaping included). mutate: applied to the
## doubt-adjusted copy before it is judged. Returns the proposal, or {} if it can't be
## prepared. Statics the game reads after its own evaluations are put back.
static func _union(n, input: Dictionary, presentations: Dictionary, outside: Dictionary, doubt: Dictionary, focus: Array, mutate: Callable = Callable(), read_everything: bool = false, sink: Dictionary = {}) -> Dictionary:
	var state: Dictionary = n.workshop_state
	var withdrawn: Dictionary = state.get("withdrawn", {})
	var kept_ctx: Dictionary = Shared.last_reason_ctx
	var kept_memo: Dictionary = Jury._eval_memo
	var kept_attention: bool = Reasoner.capture_attention
	Reasoner.capture_attention = false
	# "Reads every card" is the existing developer switch (autoplay --no-attention). The
	# attention cache isn't keyed on it, so it is bypassed while the switch is flipped.
	var kept_unlimited: bool = Reasoner.unlimited_cards
	var kept_reuse: bool = Reasoner.reuse_preparations
	if read_everything:
		Reasoner.unlimited_cards = true
		Reasoner.reuse_preparations = false
	var proposal: Dictionary = {}
	var plan: Dictionary = Shared.prepare(input, presentations, n.ledger, withdrawn, focus)
	sink["plan"] = plan
	if plan.get("ready", false) and not plan.get("empty", false):
		var shaping: Dictionary = Shared.premise_shaping(plan, presentations, withdrawn, float(plan.prepared.listener.get("insight", 0.5)))
		var shaping_eval: Dictionary = {}
		if not shaping.is_empty():
			var without_plan: Dictionary = Shared.prepare(input, Shared.without_shaping(presentations, shaping), n.ledger, withdrawn, focus)
			if without_plan.get("ready", false):
				shaping_eval = shaping.duplicate(true)
				shaping_eval["without"] = without_plan
				if not shaping.hedged.is_empty() and shaping.hedged.size() < shaping.keys.size():
					shaping_eval["without_firm"] = Shared.prepare(input, Shared.without_shaping(presentations, shaping, "hedged"), n.ledger, withdrawn, focus)
		if mutate.is_valid():
			var prepared: Dictionary = Shared._doubt_adjusted(plan, outside, doubt.pre_eval, doubt.full)
			mutate.call(prepared)
			proposal = Shared._evaluate_adjusted(plan, prepared, outside, doubt.pre_eval, doubt.full, shaping_eval)
		else:
			proposal = Shared.evaluate(plan, outside, doubt.pre_eval, doubt.full, shaping_eval)
	elif plan.get("ready", false):
		proposal = {"effects": {}}
	Shared.last_reason_ctx = kept_ctx
	Jury._eval_memo = kept_memo
	Reasoner.capture_attention = kept_attention
	Reasoner.unlimited_cards = kept_unlimited
	Reasoner.reuse_preparations = kept_reuse
	return proposal

## How far the listener trusts a reading (the value CaseEval.reading_error looks up), or
## -1 when it isn't a reading they hold a reliability for.
static func _reliability(listener: Dictionary, card: Dictionary) -> float:
	var rel: Dictionary = listener.get("reading_reliability", {})
	for k in [card.get("accuracy_origin", ""), Solver.semantic_key(card), card.get("fact_id", ""), card.get("id", "")]:
		if k != "" and rel.has(k):
			return float(rel[k])
	return -1.0

static func _scale_reliability(prepared: Dictionary, card: Dictionary, ratio: float) -> void:
	var rel: Dictionary = prepared.listener.get("reading_reliability", {})
	for k in [card.get("accuracy_origin", ""), Solver.semantic_key(card), card.get("fact_id", ""), card.get("id", "")]:
		if k != "" and rel.has(k):
			rel[k] = clampf(float(rel[k]) * ratio, 0.0, 1.0)

static func _post(proposal: Dictionary, id: String) -> float:
	var e: Dictionary = _effect(proposal, id)
	return float(e.get("posterior", e.get("prior", 0.0)))

## Call just before a case is presented to `real`: what the "without this case" side of
## the breakdown needs that the presentation overwrites (what their attention was on, and
## where their suspicions stood).
static func before(real) -> Dictionary:
	var n = mind_of(real)
	if n == null:
		return {}
	return {"focus": n.workshop_state.get("attention_focus", []).duplicate(), "suspicion": Mind.suspicion_view(n)}

static func _effect(proposal: Dictionary, target: String) -> Dictionary:
	return proposal.get("effects", {}).get(target, {})

## Everything about how `real` took the filed case `card` (a board deduction with a
## Workshop case), after it was presented to them. {} with "issues" when it can't be read
## (not presented to them, or the shared model isn't active for them).
## was: before(real) taken just before the presentation. Without it the "without this
## case" side assumes their attention was where the case left it.
static func presentation(g, real, card: Dictionary, venue: String = "meeting", was: Dictionary = {}) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var n = mind_of(real)
	if n == null:
		return {"ready": false, "issues": ["No good mind to ask."]}
	var state: Dictionary = n.workshop_state
	var key: String = str(card.get("n", 0))
	var listener_key: String = n.id + (":cover" if n.is_shadow else ":good")
	if not state.get("active", false) or not state.get("presentations", {}).has(key) or not g._workshop_plans.has(listener_key):
		return {"ready": false, "issues": ["%s hasn't been shown case #%s (or the shared model isn't active for them)." % [n.name, key]]}
	var plan: Dictionary = g._workshop_plans[listener_key]
	var snapshot: Dictionary = state.presentations[key]
	var scoped: Dictionary = Assess.prepare(snapshot)
	if not scoped.get("ready", false):
		return {"ready": false, "issues": scoped.get("issues", [])}
	var conclusion: Dictionary = scoped.case.conclusion
	var target: String = str(conclusion.get("target", conclusion.get("a", "")))
	var dir: int = Why.direction(conclusion)
	var sign: float = -1.0 if dir < 0 else 1.0
	var outside: Dictionary = state.get("outside", n.suspicion).duplicate(true)
	var doubt: Dictionary = SourceDoubt.derive(plan, n.ledger, state.get("manual_source_doubt", {}))
	var presentations: Dictionary = state.presentations
	var rest: Dictionary = presentations.duplicate()
	rest.erase(key)
	var case_ids: Array = snapshot.selected.duplicate()
	var focus_now: Array = state.get("attention_focus", [])
	var focus_was: Array = was.get("focus", focus_now)
	var bounded: bool = str(plan.prepared.listener.get("reasoning_mode", "full")) == "bounded"
	var per_card: bool = bool(plan.prepared.listener.get("per_card_source_trust", false))
	var scale: float = Tuning.Workshop.JURY_BELIEF_SCALE if per_card else 1.5

	var strip := func(prepared: Dictionary) -> void:
		Why._strip(prepared.case, case_ids)
		for field in ["own_reports", "attention_reports", "presented_reports"]:
			if prepared.listener.knowledge.has(field):
				prepared.listener.knowledge[field] = prepared.listener.knowledge[field].filter(func(id): return id not in case_ids)
	var face := func(prepared: Dictionary) -> void:
		prepared.listener["challenge_reports"] = {}
		prepared.listener["challenge_sources"] = {}
		for c in prepared.view.cards:
			if c.id not in case_ids:
				continue
			for k in [c.get("accuracy_origin", ""), Solver.semantic_key(c), c.get("fact_id", ""), c.id]:
				if k != "":
					prepared.listener.reading_reliability[k] = 1.0
			if c.has("hearing_weight"):
				c["hearing_weight"] = 1.0
				c.erase("base_hearing_weight")

	# The applied evaluation is cached with the plan; the rest are counterfactuals.
	var applied: Dictionary = g._workshop_evaluations.get(listener_key, {}).get("proposal", {})
	var e_with: Dictionary = _effect(applied, target)
	var wo_sink: Dictionary = {}
	var p_wo: Dictionary = _union(n, plan.input, rest, outside, doubt, focus_was, Callable(), false, wo_sink)
	var e_wo: Dictionary = _effect(p_wo, target)
	var e_wo_all: Dictionary = _effect(_union(n, plan.input, rest, outside, doubt, focus_was, strip), target)
	var e_wo_all_full: Dictionary = e_wo_all
	var e_heard: Dictionary = e_with
	if bounded and not Reasoner.unlimited_cards:
		e_wo_all_full = _effect(_union(n, plan.input, rest, outside, doubt, focus_was, strip, true), target)
		e_heard = _effect(_union(n, plan.input, presentations, outside, doubt, focus_now, Callable(), true), target)
	var e_face: Dictionary = _effect(_union(n, plan.input, presentations, outside, doubt, focus_now, face, true), target)

	var out: Dictionary = {"ready": true, "listener": real.id, "name": real.name, "cover": n.is_shadow, "card": int(card.get("n", 0)),
		"venue": venue, "day": g.w.day, "conclusion": conclusion.duplicate(true), "target": target}
	var raw := func(e: Dictionary) -> float: return float(e.get("raw_requested", 0.0))
	var base_full: float = raw.call(e_wo_all_full)
	var certain: float = scale * Tuning.Workshop.JURY_ALIGNMENT_COEFF
	var held_n: int = 0
	for id in case_ids:
		var owned_by: Array = plan.owners.get(id, [])
		if owned_by.any(func(o): return str(o) != "case:" + key):
			held_n += 1
	var profile: String = str(applied.get("reasoning", {}).get("profile", "Full"))
	var considered_n: int = applied.get("reasoning", {}).get("considered", []).size()
	var ignored_n: int = applied.get("reasoning", {}).get("ignored", []).size()
	var chain: Array = []
	# With nothing else held about them, the "without" side has no effect to read: their
	# suspicion rests at the outside layer.
	var rest_at: float = clampf(float(outside.get(target, 0.0)), 0.0, 1.5)
	out["is_subject"] = target == n.id
	out["unread"] = applied.get("reasoning", {}).get("ignored", []).duplicate()
	if target != "" and target != n.id and not e_with.is_empty():
		chain = [
			{"stage": "certain", "label": "If the case settled it outright", "move": certain - sign * base_full},
			{"stage": "face", "label": "If every card were news, at face value, nothing out of view", "move": sign * (raw.call(e_face) - base_full),
				"loss_label": "the cards don't settle it: other explanations remain"},
			{"stage": "heard", "label": "As %s hears each card (hearing weight, trust, doubt)" % real.name, "move": sign * (raw.call(e_heard) - base_full),
				"loss_label": "hearing weight and trust in the tellers"},
			{"stage": "attention", "label": "Within %s's attention (%s: %d of %d cards read)" % [real.name, profile, considered_n, considered_n + ignored_n],
				"move": sign * (raw.call(e_with) - raw.call(e_wo_all)), "loss_label": "attention: putting these cards in front of them pushed others out of view"},
			{"stage": "new", "label": "Against what %s already held (%d of %d cards were not new)" % [real.name, held_n, case_ids.size()],
				"move": sign * (raw.call(e_with) - raw.call(e_wo)),
				"loss_label": "nothing was new to them: any change comes from a challenge the case attached, or from what else they now have in view" if held_n == case_ids.size() else "already held: only new cards add anything"},
			{"stage": "resistance", "label": "After resistance to moving against a lean", "move": sign * (float(e_with.get("requested", 0.0)) - float(e_wo.get("requested", 0.0))),
				"loss_label": "resistance to moving against a lean (Confidence)"},
			{"stage": "applied", "label": "Applied to suspicion (the scale runs 0 to 1.5)", "move": sign * (float(e_with.get("after", rest_at)) - float(e_wo.get("after", rest_at))),
				"loss_label": "the scale's floor and ceiling (they started surer of innocence than zero shows, or were already at the top)"},
		]
	out["chain"] = chain
	out["biggest_loss"] = Why.biggest_loss(chain, "move")
	out["held"] = held_n
	out["cards_n"] = case_ids.size()
	out["effect"] = {"prior": float(e_with.get("prior", 0.0)), "posterior": float(e_with.get("posterior", 0.0)),
		"posterior_without": float(e_wo.get("posterior", e_with.get("prior", 0.0))), "headline_signal": float(e_with.get("headline_signal", 0.0)),
		"alignment_signal": float(e_with.get("alignment_signal", 0.0)), "route": str(e_with.get("route", "")),
		"requested": float(e_with.get("requested", 0.0)), "requested_without": float(e_wo.get("requested", 0.0))}
	out["suspicion"] = {"now": Mind.susp(n, target) if target != "" else 0.0, "outside": float(outside.get(target, 0.0)),
		"was": was.get("suspicion", {}).get(target, null), "focus_known": was.has("focus"),
		"circumstantial": float(state.get("circumstantial_applied", {}).get(target, 0.0))}
	if target != "" and g.w.by_id.has(target) and target != n.id:
		out["action"] = _action(g, n, target)
	var has_effect: bool = target != "" and target != n.id and not e_with.is_empty()
	# What each challenge the case attached did: how the listener graded it, and where the
	# subject and the challenged reader would stand had the case not made it.
	var challenge_ids: Array = []
	for argument in snapshot.get("arguments", []):
		for id in argument.get("workshop_case", {}).get("reading_challenges", {}):
			if id not in challenge_ids:
				challenge_ids.append(id)
	var challenges: Array = []
	for graded in applied.get("reading_challenges", []):
		var cid: String = str(graded.get("card", ""))
		if cid not in challenge_ids or not has_effect:
			continue
		var drop := func(prepared: Dictionary) -> void:
			prepared.case.reading_challenges.erase(cid)
		var p_no: Dictionary = _union(n, plan.input, presentations, outside, doubt, focus_now, drop)
		var src: String = str(graded.get("source", ""))
		challenges.append({"card": cid, "source": src, "mode": str(graded.get("mode", "")),
			"agreement": float(graded.get("agreement", 0.0)), "multiplier": float(graded.get("multiplier", 1.0)),
			"supported": bool(graded.get("supported", false)), "note": str(graded.get("graded", {}).get("note", graded.get("note", ""))),
			"target_with": _post(applied, target), "target_without": _post(p_no, target),
			"raw_move": sign * (raw.call(e_with) - raw.call(_effect(p_no, target))),
			"source_with": _post(applied, src) if src != "" and src != n.id else -1.0,
			"source_without": _post(p_no, src) if src != "" and src != n.id else -1.0})
	out["challenges"] = challenges
	# Citing a card can change how far they trust it (the case's own copy counts as a way
	# of holding it): each cited reading's reliability before and with the case, and where
	# the subject would stand with every cited reading heard as it was before.
	var trust_changes: Array = []
	var plan_wo: Dictionary = wo_sink.get("plan", {})
	if plan_wo.get("ready", false) and not plan_wo.get("empty", false):
		for id in case_ids:
			var c_now: Dictionary = Solver.card_by_id(plan.prepared.view, id)
			var c_was: Dictionary = Solver.card_by_id(plan_wo.prepared.view, id)
			if c_now.is_empty() or c_was.is_empty() or c_now.get("kind", "") != "report":
				continue
			var r_now: float = _reliability(plan.prepared.listener, c_now)
			var r_was: float = _reliability(plan_wo.prepared.listener, c_was)
			if r_now >= 0.0 and r_was >= 0.0 and absf(r_now - r_was) >= 0.005:
				trust_changes.append({"id": id, "was": r_was, "now": r_now})
	var trust: Dictionary = {"cards": trust_changes}
	if not trust_changes.is_empty() and has_effect:
		var as_before := func(prepared: Dictionary) -> void:
			for t in trust_changes:
				_scale_reliability(prepared, Solver.card_by_id(prepared.view, t.id), float(t.was) / maxf(float(t.now), 1e-6))
		var p_tb: Dictionary = _union(n, plan.input, presentations, outside, doubt, focus_now, as_before)
		trust["target_with"] = _post(applied, target)
		trust["target_as_before"] = _post(p_tb, target)
		trust["raw_move"] = sign * (raw.call(e_with) - raw.call(_effect(p_tb, target)))
	out["trust"] = trust
	# What the change of view did: which held cards the presentation pushed out of what
	# they read and which it pulled in, where the subject would stand had their view stayed
	# put, and who else moved (people the case didn't name).
	var view_change: Dictionary = {}
	if bounded and not Reasoner.unlimited_cards and was.has("focus") and has_effect:
		var read_was: Array = p_wo.get("reasoning", {}).get("considered", [])
		var read_now: Array = applied.get("reasoning", {}).get("considered", [])
		var p_old: Dictionary = _union(n, plan.input, presentations, outside, doubt, focus_was)
		var others: Array = []
		for id in applied.get("effects", {}):
			if id == target or id == n.id or not p_wo.get("effects", {}).has(id):
				continue
			var o_was: float = _post(p_wo, id)
			var o_now: float = _post(applied, id)
			if absf(o_now - o_was) >= 0.05:
				others.append({"id": id, "was": o_was, "now": o_now, "old_view": _post(p_old, id)})
		others.sort_custom(func(x, y): return absf(float(x.now) - float(x.was)) > absf(float(y.now) - float(y.was)))
		view_change = {"left": read_was.filter(func(id): return id not in read_now and id not in case_ids),
			"entered": read_now.filter(func(id): return id not in read_was and id not in case_ids),
			"target_was": float(e_wo.get("posterior", e_with.get("prior", 0.0))), "target_now": _post(applied, target), "target_old_view": _post(p_old, target),
			"raw_move": sign * (raw.call(e_with) - raw.call(_effect(p_old, target))), "others": others}
	out["view_change"] = view_change
	# The evidence half, as this listener weighs the presented cards.
	var adjusted: Dictionary = Shared._doubt_adjusted(plan, outside, doubt.pre_eval, doubt.full)
	var own: Array = adjusted.listener.knowledge.get("own_reports", []).filter(func(id): return id not in scoped.case.cards)
	var eval_listener: Dictionary = Jury._eval_listener(adjusted.listener, own)
	var considered: Array = applied.get("reasoning", {}).get("considered", [])
	var held_ids: Array = case_ids.filter(func(id): return plan.owners.get(id, []).any(func(o): return str(o) != "case:" + key))
	var evidence: Dictionary = Why.evidence(adjusted.view, scoped.case, eval_listener, {
		"attended": considered if not considered.is_empty() else null,
		"rejected": applied.get("reasoning", {}).get("private_checks", {}).get("rejected", []),
		"held": held_ids})
	for row in evidence.cards:
		var c: Dictionary = Solver.card_by_id(adjusted.view, row.id)
		if not c.is_empty() and Jury._spoken(c):
			row["teller_trust"] = Jury._card_trust(c, adjusted.listener, bool(c.get("via_player_only", false)))
	out["evidence"] = evidence
	out["alternative"] = Why.strongest_alternative(adjusted.view, evidence)
	out["text"] = describe(g, out, adjusted.view)
	out["elapsed_ms"] = Time.get_ticks_msec() - started
	return out

## Where the listener stands against the vote and nomination bars for `target` right now,
## with no statement from the player. The same parts Mind's vote adds up (mind_meeting.gd
## `_vote_impl`, `_good_nomination_impl`), read without rolling or logging anything.
static func _action(g, n, target: String) -> Dictionary:
	var w = g.w
	var score: float = Mind.action_susp(n, target) + Mind.resentment_toward(w, n, target)
	var dead: int = w.npcs.filter(func(m): return not m.alive).size()
	var need: float = Tuning.Meeting.VOTE_BASE_NEED \
		- Tuning.Meeting.VOTE_CONFIDENCE_SCALE * (Mind.trait_of(n, "confidence") - 0.5) * 2.0 \
		+ (Tuning.Meeting.VOTE_DAY1_PENALTY if w.day <= 1 else 0.0) \
		- Tuning.Meeting.VOTE_PARANOIA_WEIGHT * Mind.paranoia(w, n) \
		- Tuning.Meeting.VOTE_URGENCY_PER_DEATH * dead
	var bar: float = maxf(Tuning.Meeting.NOMINATION_FLOOR, Tuning.Meeting.NOMINATION_BASE - Tuning.Meeting.NOMINATION_DAY_SLOPE * w.day) \
		- Tuning.Meeting.NOMINATION_CONFIDENCE_SCALE * (Mind.trait_of(n, "confidence") - 0.5) * 2.0 \
		- Tuning.Meeting.NOMINATION_PARANOIA_SCALE * Mind.paranoia(w, n)
	return {"suspicion": Mind.susp(n, target), "town_pressure": clampf(n.suspicion.get(target, 0.0) + n.consensus_pressure.get(target, 0.0), 0.0, 1.5) - clampf(n.suspicion.get(target, 0.0), 0.0, 1.5),
		"execution_priority": Mind.execution_priority_contribution(n, target), "resentment": Mind.resentment_toward(w, n, target),
		"vote_score": score, "vote_need": need, "vote_margin": score - need, "nomination_bar": bar, "nomination_margin": score - bar}

static func describe(g, b: Dictionary, view: Dictionary) -> String:
	var lines: PackedStringArray = []
	var c: Dictionary = b.conclusion
	var t_name: String = g.w.by_id[b.target].name if g.w.by_id.has(b.target) else "(case)"
	lines.append("Why %s%s moved this far on \"%s %s\" (case #%d, %s, day %d)" % [b.name, " (good cover)" if b.get("cover", false) else "", t_name, str(c.get("type", "")), b.card, b.venue, b.day])
	if b.get("is_subject", false):
		lines.append("%s is the subject: they know their own alignment, so the case can't move them about it." % b.name)
	if not b.chain.is_empty():
		var ceiling: float = float(b.chain[0].move)
		var got: float = float(b.chain[-1].move)
		var top: Dictionary = b.get("biggest_loss", {})
		var verb: String = "moved them the other way (%+.2f)" % got if got < -0.005 else ("moved them %+.2f" % got if absf(got) >= 0.005 else "didn't move them")
		var lost: String = " Most was lost to: %s." % top.label if float(top.get("loss", 0.0)) >= 0.03 else ""
		if ceiling < 0.05:
			lines.append("In short: they already believed nearly as much as this evidence could make them (%+.2f left at most); it %s." % [ceiling, verb])
		else:
			lines.append("In short: at most %+.2f was on offer; it %s.%s" % [ceiling, verb, lost])
	if not b.chain.is_empty():
		var away: bool = Why.direction(c) < 0
		lines.append("Suspicion of %s the case could %s, step by step:" % [t_name, "remove" if away else "add"])
		var prev = null
		for step in b.chain:
			var note: String = ""
			if prev != null and absf(float(prev) - float(step.move)) >= 0.005:
				note = "   (%+.2f)" % (float(step.move) - float(prev))
			lines.append("  %-68s %+.2f%s" % [step.label, float(step.move), note])
			prev = step.move
		var loss: Dictionary = b.get("biggest_loss", {})
		if not loss.is_empty():
			lines.append("  Biggest loss: %s (-%.2f)" % [loss.label, float(loss.loss)])
		var e: Dictionary = b.effect
		lines.append("  %s's chance that %s is evil: %.0f%% without this case, %.0f%% with it. Suspicion %s%.2f." % [b.name, t_name,
			100.0 * float(e.posterior_without), 100.0 * float(e.posterior),
			"%.2f before, now " % float(b.suspicion.was) if b.suspicion.get("was", null) != null else "now ", float(b.suspicion.now)])
		if not b.suspicion.get("focus_known", false):
			lines.append("  (What their attention was on beforehand wasn't recorded: the attention step assumes it was where this case left it.)")
		if not b.get("unread", []).is_empty():
			var nums: Dictionary = _numbers(g)
			var on_board: Array = b.unread.filter(func(id): return nums.has(id)).map(func(id): return "#%d" % int(nums[id]))
			var private_n: int = b.unread.size() - on_board.size()
			lines.append("  Held but out of view this time: %d cards%s%s" % [b.unread.size(),
				" (" + ", ".join(PackedStringArray(on_board)) + ")" if not on_board.is_empty() else "",
				"; %d of them the Demonologist hasn't seen" % private_n if private_n > 0 else ""])
		lines.append_array(_describe_extras(g, b, t_name))
		if float(e.headline_signal) >= 0.005:
			lines.append("  (A headline reading also pulls a less sharp listener toward its face value: signal %.2f.)" % float(e.headline_signal))
	if b.has("action"):
		var a: Dictionary = b.action
		lines.append("Action: a vote on %s now scores %.2f against a need of %.2f (%s by %.2f); nomination bar %.2f." % [t_name, float(a.vote_score), float(a.vote_need),
			"clears it" if float(a.vote_margin) >= 0.0 else "short", absf(float(a.vote_margin)), float(a.nomination_bar)])
		lines.append("  (suspicion %.2f + town pressure %.2f + execution priority %.2f + resentment %.2f; the player's own vote and statement would add to this)" % [
			float(a.suspicion), float(a.town_pressure), float(a.execution_priority), float(a.resentment)])
	lines.append("")
	lines.append(Why.describe(view, b.evidence, _numbers(g)))
	return "\n".join(lines)

## "#32, #118 and 2 the Demonologist hasn't seen", or "nothing".
static func _tags(ids: Array, nums: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in ids:
		if nums.has(id):
			parts.append("#%d" % int(nums[id]))
	var private_n: int = ids.size() - parts.size()
	if private_n > 0:
		parts.append("%d the Demonologist hasn't seen" % private_n)
	return ", ".join(parts) if not parts.is_empty() else "nothing"

## The lines for what the case's challenges, the citing itself and the change of view did.
static func _describe_extras(g, b: Dictionary, t_name: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var nums: Dictionary = _numbers(g)
	var tag := func(id) -> String: return "#%d" % int(nums[id]) if nums.has(id) else "(a card the Demonologist hasn't seen)"
	var who := func(id) -> String: return g.w.by_id[id].name if g.w.by_id.has(id) else str(id)
	var pct := func(v) -> String: return "%.0f%%" % (100.0 * float(v))
	for ch in b.get("challenges", []):
		var took: String = "rejected" if float(ch.agreement) <= 0.0 and is_equal_approx(float(ch.multiplier), 1.0) else "they agree at %.2f" % float(ch.agreement)
		lines.append("  Challenge on %s (%s's reading), called \"%s\": %s; the reading now counts at x%.2f." % [tag.call(ch.card), who.call(ch.source), ch.mode, took, float(ch.multiplier)])
		lines.append("    Without this challenge: %s %s (with it %s)%s." % [t_name, pct.call(ch.target_without), pct.call(ch.target_with),
			"; %s %s (with it %s)" % [who.call(ch.source), pct.call(ch.source_without), pct.call(ch.source_with)] if float(ch.source_with) >= 0.0 and who.call(ch.source) != t_name else ""])
		if ch.note != "":
			lines.append("    \"%s\"" % ch.note)
	var trust: Dictionary = b.get("trust", {})
	if not trust.get("cards", []).is_empty():
		var parts: PackedStringArray = []
		for t in trust.cards:
			parts.append("%s %.2f -> %.2f" % [tag.call(t.id), float(t.was), float(t.now)])
		lines.append("  Citing changed how far they trust: %s." % ", ".join(parts))
		if trust.has("target_as_before"):
			lines.append("    Heard as they were before: %s %s (with the change %s)." % [t_name, pct.call(trust.target_as_before), pct.call(trust.target_with)])
	var vc: Dictionary = b.get("view_change", {})
	if not vc.is_empty():
		if vc.left.is_empty() and vc.entered.is_empty():
			lines.append("  Change of view: none (the same cards read before and after).")
		else:
			lines.append("  Change of view: left %s; entered %s." % [_tags(vc.left, nums), _tags(vc.entered, nums)])
		lines.append("    With their old view kept: %s %s (%s before the case, %s now)." % [t_name, pct.call(vc.target_old_view), pct.call(vc.target_was), pct.call(vc.target_now)])
		for o in vc.others.slice(0, 4):
			lines.append("    Not named in the case: %s %s -> %s (with the old view %s)." % [who.call(o.id), pct.call(o.was), pct.call(o.now), pct.call(o.old_view)])
	return lines

## Record one breakdown per listener after a real presentation (`g.workshop_why` on).
## Goes to g.workshop_whys (the Workshop's Debug menu shows them), the dev log and the
## trace sidecar. Called after the presentation has been applied; changes nothing.
static func record(g, real, card: Dictionary, venue: String, was: Dictionary = {}) -> void:
	var b: Dictionary = presentation(g, real, card, venue, was)
	if not b.get("ready", false):
		return
	g.workshop_whys.append(b)
	if g.workshop_whys.size() > KEEP:
		g.workshop_whys.pop_front()
	var summary: Dictionary = {"card": b.card, "venue": venue, "conclusion": b.conclusion, "chain": b.chain, "biggest_loss": b.biggest_loss,
		"alternative": b.alternative, "held": b.held, "cards_n": b.cards_n, "effect": b.effect, "action": b.get("action", {}),
		"premise": {"prior": b.evidence.prior, "posterior": b.evidence.posterior, "lr": b.evidence.lr, "chain": b.evidence.chain},
		"cards": b.evidence.cards.map(func(r): return {"id": r.id, "source": r.source, "role": r.role, "kind": r.kind, "status": r.status,
			"held": r.get("held", false), "world_share": r.get("world_share", null), "q_used": r.get("q_used", null), "q_fixed": r.get("q_fixed", false),
			"reliability": r.get("reliability", null), "adds": r.get("adds", null)}),
		"alternatives": b.evidence.alternatives, "challenges": b.get("challenges", []), "trust": b.get("trust", {}),
		"view_change": b.get("view_change", {}), "elapsed_ms": b.elapsed_ms}
	var loss: Dictionary = b.biggest_loss
	var reason: String = "Why %s moved this far: %s%s" % [real.name,
		"biggest loss: %s (-%.2f)" % [loss.label, float(loss.loss)] if not loss.is_empty() else "no stage lost anything",
		"; what's left is mostly: " + b.alternative if b.alternative != "" else ""]
	g.w.dlog.add("workshop_why", real.id, b.target, summary, reason)
	g.w.dlog.trace_event("workshop_why", real.id, b.target, {"text": b.text}, "Read-only breakdown of the applied presentation.")
