## Reversible application boundary for the opt-in, restricted reading model.
extends RefCounted
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Mind = preload("res://sim/mind.gd")

static func refresh(g, n, phase: String) -> void:
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
				n.suspicion[id] = clampf(state.outside[id] + n.suspicion.get(id, expected) - expected, 0.0, 1.5)
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
		var proposal = Shared.evaluate(plan, n.suspicion, n.discounted)
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
		g.w.dlog.trace_event("workshop_ownership", n.id, "", {"owned": state.owned, "facts": state.facts,
			"owners": state.owners, "requested": state.requested, "applied": state.applied,
			"elapsed_ms": state.elapsed_ms}, "One joint vector replaces certified legacy suspicion; preferences and role beliefs retain their owners.")
