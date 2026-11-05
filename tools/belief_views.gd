## What each good mind believes right now, from the shared possible-worlds model:
## P(evil) per person, the suspicion the meeting reads, the likeliest evil teams and the
## likeliest Demon. Developer inspection for tools/replay_why.gd.
##
## Each view re-runs that mind's ordinary belief refresh with CaseEval.capture_worlds on.
## The refresh is idempotent for unchanged evidence, so taking a view doesn't change the
## game (replay_why.gd checks the replay still matches the log).
extends RefCounted
const Mind = preload("res://sim/mind.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")

static func town(g, n_worlds: int = 5) -> Dictionary:
	var out := {"day": g.w.day, "phase": g.w.phase_name() if g.w.has_method("phase_name") else "", "minds": {}}
	for n in g.w.npcs:
		if not n.alive or n.is_evil():
			continue
		out.minds[n.id] = mind(g, n, n_worlds)
	return out

static func mind(g, n, n_worlds: int = 5) -> Dictionary:
	var key: String = n.id + ":good"
	g._workshop_evaluations.erase(key) # force a real evaluation, not the cached proposal
	var was_defer: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	CaseEval.captured = []
	CaseEval.capture_worlds = true
	Mind.refresh_beliefs(g.w, n, " (inspection)")
	CaseEval.capture_worlds = false
	g.w.defer_beliefs = was_defer
	var view_out := {"suspicion": {}, "p_evil": {}, "teams": [], "demon": {}, "worlds_total": 0}
	for id in n.suspicion:
		view_out.suspicion[id] = snappedf(Mind.susp(n, id), 0.01)
	if CaseEval.captured.is_empty() or not g._workshop_plans.has(key):
		view_out["note"] = "no shared-model evaluation (fallback or empty)"
		return view_out
	var cap: Dictionary = CaseEval.captured[0]
	CaseEval.captured = []
	for id in cap.people:
		view_out.p_evil[id] = snappedf(float(cap.people[id].posterior), 0.001)
	var view: Dictionary = g._workshop_plans[key].prepared.view
	var ids: Array = Solver.person_ids(view)
	var worlds: Array = Solver.universe(view)
	var weights: PackedFloat64Array = cap.worlds
	var total := 0.0
	var teams := {}
	var demon := {}
	for i in range(mini(worlds.size(), weights.size())):
		var wt: float = weights[i]
		if wt <= 0.0:
			continue
		total += wt
		var wd: Dictionary = worlds[i]
		var bits: int = int(wd.get("evil", 0))
		teams[bits] = teams.get(bits, 0.0) + wt
		var d: int = int(wd.get("demon", -1))
		if d >= 0 and d < ids.size():
			demon[ids[d]] = demon.get(ids[d], 0.0) + wt
	if total <= 0.0:
		view_out["note"] = "no world survives"
		return view_out
	var ranked: Array = teams.keys()
	ranked.sort_custom(func(a, b): return teams[a] > teams[b])
	for bits in ranked.slice(0, n_worlds):
		var names: Array = []
		for j in range(ids.size()):
			if bits & (1 << j):
				names.append(ids[j])
		view_out.teams.append({"evil": names, "p": snappedf(teams[bits] / total, 0.001)})
	for id in demon:
		view_out.demon[id] = snappedf(demon[id] / total, 0.001)
	view_out.worlds_total = teams.size()
	return view_out

static func _top(d: Dictionary, k: int) -> String:
	var ids: Array = d.keys()
	ids.sort_custom(func(a, b): return d[a] > d[b])
	return ", ".join(ids.slice(0, k).map(func(id): return "%s %.2f" % [id, d[id]]))

static func render(v: Dictionary) -> String:
	var lines: Array = ["", "=== %s (seq %d, day %d) ===" % [v.get("label", ""), int(v.get("seq", 0)), int(v.day)]]
	for id in v.minds:
		var m: Dictionary = v.minds[id]
		lines.append("%s" % id)
		if m.has("note"):
			lines.append("  (%s)" % m.note)
		lines.append("  suspicion: " + _top(m.suspicion, 5))
		if not m.p_evil.is_empty():
			lines.append("  P(evil):   " + _top(m.p_evil, 5))
		if not m.demon.is_empty():
			lines.append("  P(Demon):  " + _top(m.demon, 4))
		for t in m.teams:
			lines.append("  team %.3f  %s" % [t.p, ", ".join(t.evil)])
	return "\n".join(lines)
