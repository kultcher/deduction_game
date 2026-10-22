## Reversible application boundary for the opt-in, restricted reading model.
extends RefCounted
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Mind = preload("res://sim/mind.gd")
const Profiler = preload("res://workshop/profiler.gd")

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
				var expected = clampf(state.outside[id] + state.requested.get(id, 0.0), 0.0, 1.5)
				var before: float = n.suspicion.get(id, expected)
				var external_change: float = before - expected
				# Preserve the exact stored baseline when nothing changed. Adding
				# then subtracting the same float introduced rounding drift, which
				# broke exact cache/repetition keys and fed priors on every refresh.
				n.suspicion[id] = state.outside[id] if absf(external_change) < 0.000000001 else clampf(state.outside[id] + external_change, 0.0, 1.5)
				if not is_equal_approx(before, n.suspicion[id]):
					removed[id] = {"from": before, "to": n.suspicion[id], "delta": n.suspicion[id] - before}
			g.w.dlog.trace_event("workshop_retraction", n.id, "", {"removed": removed,
				"previous_owned": state.previous_owned}, "Retract the entire previous joint vector before reassessment; independent suspicion remains.")
		state.active = false
		state.requested = {}
		state.applied = {}
		state.owned = {}
		g._workshop_plans.erase(key)
		if not state.get("enabled", false):
			state.issues = ["Shared effects disabled; legacy contributions restored."]
			return
		var input = Bridge.capture(g, [], n.id, "private", n)
		var plan = Shared.prepare(input, state.get("presentations", {}), n.ledger, state.get("withdrawn", {}))
		state.issues = plan.issues
		state.facts = plan.facts
		state.owners = plan.owners
		state.quoted = plan.quotations.keys()
		state.reason_visibility = _visibility(n, plan.facts)
		state.owned = plan.owned
		if plan.ready:
			g._workshop_plans[key] = plan
	else:
		if not g._workshop_plans.has(key):
			return
		var plan: Dictionary = g._workshop_plans[key]
		plan.input.listener.discounted = n.discounted.duplicate(true)
		plan.input.listener.suspicion = n.suspicion.duplicate(true)
		plan = Shared.prepare(plan.input, state.get("presentations", {}), n.ledger, state.get("withdrawn", {}))
		if not plan.ready:
			state.owned = {}
			state.issues = plan.issues
			g._workshop_busy = true
			Mind.recompute_beliefs(g.w, n, " (shared capability fallback)")
			g._workshop_busy = false
			return
		# Derive interval doubt first; evaluate joint effects only after removing
		# the owned legacy grounds from honesty and the entire previous vector.
		var started = Time.get_ticks_msec()
		var inputs = [plan.prepared, n.suspicion, n.discounted]
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
			g._workshop_evaluations[key] = {"input": inputs.duplicate(true), "proposal": proposal}
		state.outside = n.suspicion.duplicate(true)
		state.requested = {}
		state.applied = {}
		for id in proposal.effects:
			if id == n.id or not n.suspicion.has(id):
				continue
			var desired: float = proposal.effects[id].requested
			state.requested[id] = desired
			var old: float = n.suspicion[id]
			n.suspicion[id] = clampf(old + desired, 0.0, 1.5)
			state.applied[id] = n.suspicion[id] - old
			if not is_zero_approx(state.applied[id]):
				g.w.dlog.trace_event("value_change", n.id, id, {"quantity": "suspicion", "from": old,
					"to": n.suspicion[id], "requested_delta": desired, "applied_delta": state.applied[id],
				"ledger_id": "workshop:shared"}, "Shared original reading evidence")
		state.active = true
		state.elapsed_ms = Time.get_ticks_msec() - started
		state.cache_hit = cache_hit
		g.w.dlog.trace_event("workshop_ownership", n.id, "", {"owned": state.owned, "facts": state.facts,
			"owners": state.owners, "requested": state.requested, "applied": state.applied,
			"elapsed_ms": state.elapsed_ms}, "One joint vector replaces certified legacy suspicion; preferences and role beliefs retain their owners.")

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
