## Reversible application boundary for the opt-in, restricted reading model.
extends RefCounted
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Mind = preload("res://sim/mind.gd")
const Profiler = preload("res://workshop/profiler.gd")
const Circumstantial = preload("res://workshop/circumstantial.gd")

static func refresh(g, n, phase: String) -> void:
	var span = Profiler.open("ownership_" + phase)
	_refresh(g, n, phase)
	Profiler.close(span)

static func _refresh(g, n, phase: String) -> void:
	if g._workshop_busy or n.workshop_state.is_empty():
		return
	var state: Dictionary = n.workshop_state
	var key = n.id + (":cover" if n.is_shadow else ":good")
	if phase == "before":
		state.previous_owned = state.get("owned", {}).duplicate(true)
		if state.get("active", false):
			var removed = {}
			for id in state.outside:
				# Preserve direct native assignments too (ordinary adjustments go
				# through Mind.adjust and already maintain the outside layer).
				var expected: float = state.outside[id] + state.requested.get(id, 0.0) + state.get("circumstantial_requested", {}).get(id, 0.0)
				var before: float = n.suspicion.get(id, expected)
				var external_change: float = before - expected
				# Preserve the exact stored baseline when nothing changed. Adding
				# then subtracting the same float introduced rounding drift, which
				# broke exact cache/repetition keys and fed priors on every refresh.
				n.suspicion[id] = state.outside[id] if absf(external_change) < 0.000000001 else state.outside[id] + external_change
				if not is_equal_approx(before, n.suspicion[id]):
					removed[id] = {"from": before, "to": n.suspicion[id], "delta": n.suspicion[id] - before}
			g.w.dlog.trace_event("workshop_retraction", n.id, "", {"removed": removed,
				"previous_owned": state.previous_owned}, "Retract the entire previous joint vector before reassessment; independent suspicion remains.")
		state.active = false
		state.requested = {}
		state.applied = {}
		state.circumstantial_requested = {}
		state.circumstantial_applied = {}
		state.circumstantial_incidents = {}
		state.owned = {}
		state.erase("action") # An unsupported/disabled refresh cannot retain an action.
		g._workshop_plans.erase(key)
		if not state.get("enabled", false):
			state.issues = ["Shared effects disabled; legacy contributions restored."]
			return
		var input = Bridge.capture(g, [], n.id, "private", n)
		var plan = Shared.prepare(input, state.get("presentations", {}), n.ledger, state.get("withdrawn", {}), state.get("attention_focus", []))
		state.issues = plan.issues
		state.facts = plan.facts
		state.owners = plan.owners
		state.quoted = plan.quotations.keys()
		state.reason_visibility = _visibility(n, plan.facts)
		state.owned = plan.owned
		if plan.ready:
			g._workshop_plans[key] = plan
		else:
			fallback(g, n, "ownership_before", plan.issues)
	else:
		if not g._workshop_plans.has(key):
			return
		var plan: Dictionary = g._workshop_plans[key]
		plan.input.listener.discounted = n.discounted.duplicate(true)
		plan.input.listener.suspicion = n.suspicion.duplicate(true)
		plan = Shared.prepare(plan.input, state.get("presentations", {}), n.ledger, state.get("withdrawn", {}), state.get("attention_focus", []))
		if not plan.ready:
			state.owned = {}
			state.issues = plan.issues
			fallback(g, n, "ownership_after", plan.issues)
			g._workshop_busy = true
			Mind.recompute_beliefs(g.w, n, " (shared capability fallback)")
			g._workshop_busy = false
			return
		# Derive interval doubt first; evaluate joint effects only after removing
		# the owned legacy grounds from honesty and the entire previous vector.
		var started = Time.get_ticks_msec()
		var inputs = [plan.prepared, n.suspicion, n.discounted, plan.marked_questions]
		var cached: Dictionary = g._workshop_evaluations.get(key, {})
		var cache_hit = cached.get("input") == inputs
		var proposal: Dictionary
		if cache_hit:
			Profiler.count("union_cache_hit")
			proposal = cached.proposal
		else:
			Profiler.count("union_cache_miss")
			var union_span = Profiler.open("joint_effects")
			proposal = Shared.evaluate(plan, n.suspicion, n.discounted)
			Profiler.close(union_span)
		state.outside = n.suspicion.duplicate(true)
		# Only the applied total-evidence assessment commits theory memory. Scoped
		# replies and developer/ghost previews operate on copies.
		state.theories = proposal.get("theories", state.get("theories", {})).duplicate(true)
		state.reasoning = proposal.get("reasoning", {}).duplicate(true)
		state.reading_challenges = proposal.get("reading_challenges", []).duplicate(true)
		if proposal.get("action", {}).is_empty():
			state.erase("action")
		else:
			state["action"] = proposal.action.duplicate(true)
		if proposal.get("public_good", []).is_empty():
			state.erase("public_good")
		else:
			state["public_good"] = proposal.public_good.duplicate()
		# Theory commitment is idempotent for the same evidence/baseline. Cache the
		# post-commit input too, so parking a native receipt cannot redo the entire
		# union merely because the first pass filled in its own memory.
		var committed_inputs: Array = inputs.duplicate(true)
		committed_inputs[0].listener.theories = state.theories.duplicate(true)
		g._workshop_evaluations[key] = {"input": committed_inputs, "proposal": proposal, "cache_hit": cache_hit}
		state.requested = {}
		state.applied = {}
		for id in proposal.effects:
			if id == n.id or not n.suspicion.has(id):
				continue
			var desired: float = proposal.effects[id].requested
			state.requested[id] = desired
			var old: float = n.suspicion[id]
			n.suspicion[id] = old + desired
			state.applied[id] = n.suspicion[id] - old
			if not is_zero_approx(state.applied[id]):
				g.w.dlog.trace_event("value_change", n.id, id, {"quantity": "suspicion", "from": old,
					"to": n.suspicion[id], "requested_delta": desired, "applied_delta": state.applied[id],
				"ledger_id": "workshop:shared"}, "Shared original reading evidence")
		# Stage 2 Circumstantial Evidence Hub: evaluated once on the frozen post-Stage-1
		# snapshot and stored in its own separately retractable ownership vector.
		state.circumstantial_requested = {}
		state.circumstantial_applied = {}
		state.circumstantial_incidents = {}
		var chubs: Array = plan.get("circumstantial_hubs", [])
		if not chubs.is_empty():
			var post_stage1: Dictionary = {}
			for pid in n.suspicion:
				post_stage1[pid] = clampf(float(n.suspicion[pid]), 0.0, 1.5)
			var stage2: Dictionary = Circumstantial.evaluate_union(
				plan.prepared.view,
				chubs,
				state.outside,
				state.requested,
				post_stage1,
				n.npc_trust,
				n.trust,
				n.id,
				state.get("public_good", []),
				plan.prepared.listener.knowledge,
				plan.prepared.case.get("disputes", [])
			)
			state.circumstantial_incidents = stage2.get("incidents", {}).duplicate(true)
			for id in stage2.get("requested", {}):
				if id == n.id or not n.suspicion.has(id):
					continue
				var c_des: float = float(stage2.requested[id])
				state.circumstantial_requested[id] = c_des
				var old_c: float = n.suspicion[id]
				n.suspicion[id] = old_c + c_des
				state.circumstantial_applied[id] = n.suspicion[id] - old_c
				if not is_zero_approx(state.circumstantial_applied[id]):
					g.w.dlog.trace_event("value_change", n.id, id, {"quantity": "suspicion", "from": old_c,
						"to": n.suspicion[id], "requested_delta": c_des, "applied_delta": state.circumstantial_applied[id],
						"ledger_id": "workshop:circumstantial"}, "Stage 2 circumstantial hub")
		state.active = true
		g.w.dlog.trace_event("workshop_ownership", n.id, "", {"owned": state.owned, "facts": state.facts,
			"owners": state.owners, "requested": state.requested, "applied": state.applied,
			"reasoning": state.reasoning, "reasoning_mode": plan.prepared.listener.reasoning_mode,
			"confidence_mode": plan.prepared.listener.confidence_mode,
			"elapsed_ms": Time.get_ticks_msec() - started, "cache_hit": cache_hit}, "One joint vector replaces certified legacy suspicion; preferences and role beliefs retain their owners.")

static func fallback(g, n, point: String, issues: Array, card: int = 0) -> void:
	var entry = {"listener": n.id, "point": point, "issues": issues.duplicate(true), "card": card, "day": g.w.day, "phase": g.w.phase}
	# Count each distinct fallback once per listener per day, so the totals mean
	# "things not tested", not "how often a refresh ran".
	var seen: bool = g.shared_fallbacks.any(func(f): return f.listener == entry.listener and f.point == entry.point and f.issues == entry.issues and f.card == entry.card and f.day == entry.day)
	if not seen:
		g.shared_fallbacks.append(entry)
		g.w.dlog.add("legacy_fallback", n.id, "", entry, "Legacy rules used (%s): %s" % [point, "; ".join(PackedStringArray(issues))])
	g.w.dlog.trace_event("workshop_fallback", n.id, "", {"listener": n.id,
		"card": card, "exit_point": point, "issues": issues.duplicate(true)},
		"Shared evaluation unavailable: " + "; ".join(PackedStringArray(issues)))

## Conservative disclosure: a joint inference is not automatically this NPC's
## own gift to reveal. Only explicit presentations/disclosures make roots citable.
static func _visibility(n, facts: Array) -> String:
	var public = {}
	var player = {}
	for id in n.workshop_state.get("disclosures", {}):
		var disclosure: Dictionary = n.workshop_state.disclosures[id]
		if disclosure.get("player", false):
			player[id] = true
		if disclosure.get("public", false):
			public[id] = true
	for snapshot in n.workshop_state.get("presentations", {}).values():
		for id in snapshot.selected:
			player[id] = true
			if snapshot.venue != "private":
				public[id] = true
	for entry in n.ledger.values():
		var meta: Dictionary = entry.get("meta", {})
		for receipt in meta.get("workshop_receipts", {}).values():
			if receipt.get("heard_in_public", false):
				public[receipt.id] = true
		if meta.get("workshop_public", false) and meta.has("workshop_card"):
			public[meta.workshop_card.id] = true
	for i in range(n.info_log.size()):
		var entry: Dictionary = n.info_log[i]
		var id: String = Shared.reading(n.id, entry).id
		if entry.get("shared", false):
			public[id] = true
		if i < n.told_readings:
			player[id] = true
	if not facts.is_empty() and facts.all(func(id): return public.has(id)):
		return "public"
	if not facts.is_empty() and facts.all(func(id): return public.has(id) or player.has(id)):
		return "shared_player"
	return "shared_private"
