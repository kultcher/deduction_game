## Live canvas boundary. Only player board receipts cross into the editor.
extends RefCounted
const Bridge = preload("res://game/workshop_bridge.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Assess = preload("res://workshop/live_assessment.gd")

static func view(g) -> Dictionary:
	var numbers: Array = g.board.filter(func(c): return not c.get("deleted", false) and c.kind != "deduction").map(func(c): return c.n)
	var profile_ids = {}
	for pr in g.profile_receipts:
		numbers.append(pr.n)
		profile_ids[Evidence.normalize_card(pr).id] = true
	var snapshot = Bridge.capture(g, numbers)
	var cards: Array = []
	for receipt in snapshot.evidence:
		var content: Dictionary = receipt.content
		var note = "FALLBACK: this evidence has no live Workshop evaluator"
		if (receipt.kind == "claim" and content.get("role") in Assess.C.GOOD_ROLES) or (receipt.kind in ["sighting", "alibi"] and receipt.observed_at.phase == "night"):
			note = "Adapter available · testimony and circumstances, not proof of evil"
		var activity = Assess.activity_card(receipt, snapshot)
		if receipt.kind == "info" and content.get("role") == "medium":
			activity = Assess.medium_card(receipt, snapshot)
			if activity.is_empty():
				activity = Assess.testimony_card(receipt, snapshot)
		elif receipt.kind == "info" and content.get("anonymous", false):
			activity = Assess.testimony_card(receipt, snapshot)
		if not activity.is_empty():
			note = "Adapter available · experimental joint activity/trace comparison"
			if activity.kind in ["context", "location"]:
				note = "Adapter available · location context; this does not establish guilt"
		if receipt.kind == "info" and content.get("role") in Assess.ROLES:
			note = "Reading adapter available · check whole-case support"
			if not Assess.Domain.gift_time({"role": content.role, "observed_at": receipt.observed_at}):
				note = "FALLBACK: this reading time is outside the live adapter"
			var ids: Array = snapshot.people.map(func(p): return p.id)
			if not Assess.reading_valid(receipt, ids, snapshot.rules.modifier_options):
				note = "FALLBACK: reading payload is incomplete or invalid"
			if content.role == "medium" and activity.is_empty():
				note = "FALLBACK: this Medium item needs supported original evidence, its observation time, and a known deceased source"
		cards.append({"id": receipt.id, "fact_id": receipt.id, "kind": "report" if receipt.kind == "info" else receipt.kind,
			"source": receipt.source, "subject": receipt.subjects[0] if not receipt.subjects.is_empty() else "", "subjects": receipt.subjects.duplicate(),
			"role": content.get("role", ""), "data": content.get("data", {}).duplicate(true),
			"night": receipt.observed_at.day if receipt.observed_at.phase == "night" or content.get("role") in ["martyr", "sexton"] else -1,
			"block": content.get("block", ""), "observed_at": receipt.observed_at,
			"reported_at": receipt.reported_at if receipt.reported_at != null else {"day": "?"},
			"learned_at": receipt.learned_at if receipt.learned_at != null else {"day": "?"},
			"acquired_day": receipt.learned_at.day if receipt.learned_at != null else snapshot.now.day,
			"text": receipt.text, "support_note": note, "profile_receipt": profile_ids.has(receipt.id)})
		if not activity.is_empty():
			cards[-1].merge(activity, true)
			cards[-1].support_note = "Adapter available · Medium relay retains original source and time; transmission/source modifiers need separate attribution" if activity.has("relay_source") else note
			if activity.get("testimony_only", false):
				cards[-1].support_note = "Context only: " + activity.context_note if activity.kind == "context" else "Weak teller testimony · no original-source identity or gift proof"
	var history = Assess.History.chronology(snapshot.public_events, snapshot.people, snapshot.now)
	var result = {"seed": g.w.seed_value, "day": snapshot.now.day, "people": snapshot.people, "cards": cards,
		"profile_facets": _profile_facets(g),
		"evil_count": snapshot.rules.initial_evil_count, "alignment_epoch": "Original alignment",
		"world_options": {"modifiers": snapshot.rules.modifier_options}, "live": true, "live_activity": true,
		"timeline": Assess.History.from_events(snapshot.public_events)}
	if not history.value.is_empty():
		result["chronology"] = history.value
		result.alignment_epoch = "Current alignment"
	return result

## Resolve exact original facts afresh. Missing/deleted evidence is a blocker, never
## permission to file a weaker argument with fewer roots.
static func _profile_facets(g) -> Dictionary:
	var out = {}
	var C = Assess.C
	for n in g.w.npcs:
		var hw_recs: Array = g.profile_receipts_for(n.id, "home_work")
		var haunt_recs: Array = g.profile_receipts_for(n.id, "haunts")
		var trait_recs: Array = g.profile_receipts_for(n.id, "personality")
		var bond_recs: Array = g.profile_receipts_for(n.id, "bonds")
		var haunt_names: Array = haunt_recs.map(func(c): return g.w.loc_name(c.get("loc", c.get("locs", [""])[0])))
		var latest_traits = {}
		for c in trait_recs:
			latest_traits[c.get("trait", "")] = c.get("tier", "?") + (" (bereaved)" if c.get("withdrawn", false) else "")
		var trait_parts: Array = []
		for k in C.TRAITS:
			if latest_traits.has(k):
				trait_parts.append("%s: %s" % [k.capitalize(), latest_traits[k]])
		var bond_parts: Array = []
		for c in bond_recs:
			var others: Array = c.get("subject", []).filter(func(pid): return pid != n.id)
			if not others.is_empty() and g.w.by_id.has(others[0]):
				bond_parts.append("%s with %s" % ["Close" if c.get("bond_kind") == "friend" else "At odds", g.w.by_id[others[0]].name])
		out[n.id] = {
			"home_work": {
				"unlocked": not hw_recs.is_empty(),
				"summary": "Lives on %s · %s (%s at %s)" % [C.block_name(n.home_block), n.occupation.capitalize(), C.phase_list(n.work_phases), g.w.loc_name(n.work)],
				"receipt_ids": hw_recs.map(func(c): return Evidence.normalize_card(c).id),
			},
			"haunts": {
				"unlocked": not haunt_recs.is_empty(),
				"summary": ("Often at " + ", ".join(PackedStringArray(haunt_names)) + (" (1 of 2 known)" if haunt_recs.size() < 2 else " (both known)")) if not haunt_recs.is_empty() else "Unknown (ask around town)",
				"receipt_ids": haunt_recs.map(func(c): return Evidence.normalize_card(c).id),
			},
			"personality": {
				"unlocked": not trait_recs.is_empty(),
				"summary": ", ".join(PackedStringArray(trait_parts)) if not trait_parts.is_empty() else "Unobserved (talk or ask around)",
				"receipt_ids": trait_recs.map(func(c): return Evidence.normalize_card(c).id),
			},
			"bonds": {
				"unlocked": not bond_recs.is_empty(),
				"summary": ", ".join(PackedStringArray(bond_parts)) if not bond_parts.is_empty() else "None learned yet",
				"receipt_ids": bond_recs.map(func(c): return Evidence.normalize_card(c).id),
			},
		}
	return out

static func supports(g, value: Dictionary) -> Dictionary:
	var numbers: Array = []
	var missing: Array = []
	var pool: Array = g.all_receipts()
	for id in value.cards:
		var matches: Array = pool.filter(func(c): return c.kind != "deduction" and not c.get("deleted", false) and Evidence.normalize_card(c).id == id)
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
		"conclusion": native_conclusion(g, value.conclusion), "workshop_case": value.duplicate(true)}]
	for issue in roots.issues:
		input.issues.append({"code": "missing_card", "detail": issue})
	return input

static func native_conclusion(g, conclusion: Dictionary) -> Dictionary:
	var result = {"type": conclusion.type, "a": conclusion.target}
	for field in ["role", "mod", "night"]:
		if conclusion.has(field):
			result[field] = conclusion[field]
	if conclusion.has("report"):
		var reports: Array = g.board.filter(func(c): return c.kind != "deduction" and Evidence.normalize_card(c).id == conclusion.report)
		if not reports.is_empty():
			result["card"] = reports[0].n
	return result

static func status(g, value: Dictionary) -> Dictionary:
	var input = snapshot(g, value)
	# Use a synthetic profile for capability checks, without running the expensive
	# numerical preview or looking at any real listener's private knowledge.
	input.listener = {"id": "ghost", "name": "Neutral reference", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "discounted": {}, "own_gift": ""}
	var prepared = Assess.prepare(input)
	var issues: Array = prepared.issues.duplicate()
	var audience_ready = true
	# Reuse the same exact graph for each real listener; capability checks never
	# evaluate numbers or reveal the listener's private evidence to the player.
	for real in g.w.living():
		var n = real.shadow if real.is_evil() else real
		if n == null:
			audience_ready = false
			continue
		var scoped = snapshot(g, value, n.id)
		var check = Assess.prepare(scoped)
		if not check.ready:
			audience_ready = false
			continue
		var proposals: Dictionary = n.workshop_state.get("presentations", {}).duplicate(true)
		proposals["draft"] = scoped
		var plan = preload("res://workshop/shared_ledger.gd").prepare(Bridge.capture(g, [], n.id, "private", n), proposals, n.ledger, n.workshop_state.get("withdrawn", {}))
		if not check.ready or not plan.ready:
			audience_ready = false
			for issue in check.issues + plan.issues:
				if issue not in issues:
					issues.append(issue)
	var blocked = not supports(g, value).issues.is_empty() or value.cards.is_empty()
	if value.cards.is_empty():
		issues.append("Connect evidence to the selected premise before filing.")
	return {"ready": prepared.ready and not blocked, "audience_ready": audience_ready, "blocked": blocked or (g.strict_evaluator and (not prepared.ready or not audience_ready)), "issues": issues,
		"mode": "shared" if prepared.ready and g.workshop_effects else "legacy",
		"warning": "Fallback evaluates the headline and original cards using the existing argument system. Canvas answers, assumptions, intermediate claims and link meanings are NOT interpreted by that system."}

static func file(g, value: Dictionary, previous: int = 0) -> int:
	if g.workshop_presenting:
		g.last_error = "Wait for the current presentation to finish before changing a filed case."
		return -1
	if previous > 0 and previous <= g.board.size() and g.board[previous - 1].get("deleted", false):
		previous = 0
	while previous > 0 and previous <= g.board.size() and g.board[previous - 1].get("superseded_by", 0) > 0:
		previous = g.board[previous - 1].superseded_by
	var check = status(g, value)
	if check.blocked:
		g.last_error = "\n".join(PackedStringArray(check.issues))
		return -1
	var roots = supports(g, value)
	var conclusion = native_conclusion(g, value.conclusion)
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
	# A revision is a new historical receipt. Listeners retain the version they
	# actually heard until the new card is presented.
	if previous > 0 and previous <= g.board.size() and g.board[previous - 1].has("workshop_case"):
		card["revises"] = previous
		g.board[previous - 1]["superseded_by"] = number
		g.board[previous - 1].text += " (Superseded by case #%d.)" % number
	# The native filer may have returned a pre-existing flat deduction. Never
	# overwrite that card or turn another draft into this graph.
	if number > old_size:
		g.board[number - 1] = card
		g.w.dlog.add("workshop_canvas_filed", "player", conclusion.get("a", ""), {"card": number, "revision": false, "case": value, "supports": roots.numbers})
		return number
	return g.add_card(card)

## The test juror: public facts and default trust, no private knowledge. Says how well
## a draft case holds together (CaseEval.strength), or why it can't be judged yet.
## One evaluation; the Workshop runs it after a pause in editing.
static func test_juror(g, value: Dictionary) -> Dictionary:
	var input = snapshot(g, value)
	input.private_evidence = []
	input.evidence = input.evidence.filter(func(e): return e.id in input.selected)
	input.listener = {"id": "ghost", "name": "Test juror", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "discounted": {}, "honesty": {}, "own_gift": "", "legacy_evidence": []}
	var prepared = Assess.prepare(input)
	if not prepared.ready:
		return {"ready": false, "issues": prepared.issues.duplicate()}
	var CaseEval = preload("res://workshop/case_eval.gd")
	var ev: Dictionary = CaseEval.evaluate(prepared.view, prepared.case)
	var result: Dictionary = CaseEval.strength_from(ev)
	result["ready"] = true
	result["issues"] = []
	feedback(prepared.view, prepared.case, ev, result)
	return result

## The test juror's notes beyond its strength chip: the clash headline and clashing
## cards when the case can't hold, and who it would mostly raise suspicion of.
static func feedback(view: Dictionary, case_data: Dictionary, ev: Dictionary, result: Dictionary) -> void:
	var Solver = preload("res://workshop/solver.gd")
	var target: String = case_data.conclusion.get("target", "")
	if ev.impossible:
		# The real diagnosis goes first: with the player's own choices (answers, doubts,
		# assumptions), the cards can't all hold. Point at the cards that clash.
		var chose: bool = not case_data.answers.is_empty() or not case_data.get("reading_challenges", {}).is_empty() or not case_data.positions.is_empty() or not case_data.get("disputes", []).is_empty()
		result["headline"] = "Your chosen explanation doesn't fit: with it, these cards can't all be true." if chose else "These cards can't all be true together; something here is false."
		var cards: Array = Solver.selected(view, case_data)
		var cores: Array = Solver.minimal_conflicts(view, cards)
		if not cores.is_empty():
			result["clashing"] = cores[0]
		else:
			# The cards clash only under the player's choices: point at the chosen ones.
			var chosen: Array = case_data.answers.keys() + case_data.get("reading_challenges", {}).keys()
			for dispute in case_data.get("disputes", []):
				chosen.append_array(dispute.reports)
			for card in cards:
				if card.get("source", "") in case_data.positions or card.get("subject", "") in case_data.positions:
					chosen.append(card.id)
			var unique: Array = []
			for id in chosen:
				if id not in unique:
					unique.append(id)
			result["clashing"] = unique
	# Collateral: who this case would mostly raise suspicion of, if not the subject.
	if case_data.conclusion.get("type", "") in ["evil", "demon", "minion", "suspicious"] and ev.has("people"):
		var people: Dictionary = ev.people
		var own: float = people.get(target, {}).get("posterior", 0.0) - people.get(target, {}).get("prior", 0.0)
		var top = ""
		var top_rise = 0.05
		for id in people:
			var rise: float = people[id].posterior - people[id].prior
			if id != target and rise > top_rise and rise > own:
				top = id
				top_rise = rise
		if top != "":
			result["raises"] = top
			result["raises_text"] = "If presented, this mostly raises suspicion of %s." % Solver.person_name(view, top)

## "Connections" (Find Links, rebuilt on the shared model): board cards not yet in this
## case that bear on its premise, ranked by how far each would move the test juror, up
## to limit. On demand only: one test-juror run per candidate. Candidates mention someone
## the case is about (its subject, or anyone on its cards). Each entry: {number, id, text,
## move (log likelihood-ratio change), helps}.
static func connections(g, value: Dictionary, limit: int = 5, budget: int = 20) -> Array:
	var base: float = 1.0
	if not value.cards.is_empty():
		var r: Dictionary = test_juror(g, value)
		if not r.get("ready", false):
			return []
		base = r.get("lr", 1.0)
	var people: Dictionary = {}
	var target: String = value.conclusion.get("target", "")
	if target != "":
		people[target] = true
	var known: Array = []
	for card in g.board:
		if card.kind == "deduction" or card.get("deleted", false):
			continue
		var id: String = Evidence.normalize_card(card).id
		if id in value.cards:
			known.append(id)
			for who in _mentions(card):
				people[who] = true
	var candidates: Array = []
	for i in range(g.board.size() - 1, -1, -1):
		var card: Dictionary = g.board[i]
		if card.kind in ["deduction", "home"] or card.get("deleted", false):
			continue
		var id: String = Evidence.normalize_card(card).id
		if id in value.cards or id in candidates.map(func(c): return c.id):
			continue
		if _mentions(card).any(func(who): return people.has(who)):
			candidates.append({"number": card.n, "id": id, "text": card.get("text", "")})
		if candidates.size() >= budget:
			break
	var out: Array = []
	for c in candidates:
		var with_card: Dictionary = value.duplicate(true)
		with_card.cards.append(c.id)
		var r: Dictionary = test_juror(g, with_card)
		if not r.get("ready", false):
			continue
		var move: float = log(maxf(r.get("lr", 1.0), 0.000001)) - log(maxf(base, 0.000001))
		if absf(move) < 0.01:
			continue
		c["move"] = move
		c["helps"] = move > 0.0
		out.append(c)
	out.sort_custom(func(a, b): return absf(a.move) > absf(b.move))
	return out.slice(0, limit)

## Listener-independent investigative breakdown of how the cited traces + profile/sighting
## receipts in `value` narrow the townsfolk, without revealing listener persuasion.
static func trace_summary(g, value: Dictionary) -> Dictionary:
	var input = snapshot(g, value)
	input.private_evidence = []
	input.evidence = input.evidence.filter(func(e): return e.id in input.selected)
	input.listener = {"id": "ghost", "name": "Trace check", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "discounted": {}, "honesty": {}, "own_gift": "", "legacy_evidence": []}
	var prepared = Assess.prepare(input)
	if not prepared.ready:
		return {"has_traces": false}
	var Solver = preload("res://workshop/solver.gd")
	var Activity = preload("res://workshop/live_activity.gd")
	var cited_cards: Array = Solver.selected(prepared.view, prepared.case)
	var struct_traces: Array = cited_cards.filter(func(c): return c.kind == "trace" and c.get("data", {}).has("family"))
	if struct_traces.is_empty():
		return {"has_traces": false}
	var compatible: Array = []
	var unresolved: Array = []
	var contradicted: Array = []
	for p in prepared.view.people:
		if not p.get("alive", true):
			continue
		var any_contra = false
		var missing_notes: Array = []
		for tc in struct_traces:
			var ev: Dictionary = Activity.evaluate_trace_for_person(prepared.view, cited_cards, tc, p.id)
			if ev.state == "contradicts":
				any_contra = true
			elif ev.state == "unknown" and ev.missing != "" and ev.missing not in missing_notes:
				missing_notes.append(ev.missing)
		if any_contra:
			contradicted.append(p.name)
		elif not missing_notes.is_empty():
			unresolved.append("%s (%s)" % [p.name, "; ".join(PackedStringArray(missing_notes))])
		else:
			compatible.append(p.name)
	var lines: Array = ["Trace narrowing across living townsfolk (%d cited trace%s):" % [struct_traces.size(), "s" if struct_traces.size() > 1 else ""]]
	lines.append("• Fits all cited traces: " + (", ".join(PackedStringArray(compatible)) if not compatible.is_empty() else "none confirmed yet"))
	lines.append("• Unresolved (missing info): " + (", ".join(PackedStringArray(unresolved)) if not unresolved.is_empty() else "none"))
	lines.append("• Pushed against (3:1): " + (", ".join(PackedStringArray(contradicted)) if not contradicted.is_empty() else "none"))
	return {
		"has_traces": true,
		"compatible": compatible,
		"unresolved": unresolved,
		"contradicted": contradicted,
		"text": "\n".join(PackedStringArray(lines)),
	}

static func _mentions(card: Dictionary) -> Array:
	var out: Array = []
	for who in card.get("subject", []) + [card.get("source", ""), card.get("owner", "")] + card.get("data", {}).get("seen", []) + card.get("data", {}).get("pair", []) + card.get("data", {}).get("group", []):
		if who is String and who != "" and who not in ["player", "town"] and who not in out:
			out.append(who)
	return out
