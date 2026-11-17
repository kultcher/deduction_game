## A good listener allows that its own gift may be the Delusional one (Michael, Nov 17;
## BACKLOG, "A listener's small doubt that their own gift is Delusional"). With the secret on
## the script, SourceDoubt.derive gives each night of the listener's own readings a small
## honest doubt (DELUSIONAL_SELF_DOUBT), the way its home nights carry the Sleepwalker's.
## Its readings then pull a little less than certain; without the secret, nothing changes,
## and its sightings and alibis aren't touched.
## Found by search: a good listener whose own reading the doubt softens, at a day-2 meeting.
##   godot --headless --path . --script res://tools/test_delusional_self_doubt.gd
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const Mind = preload("res://sim/mind.gd")
const Caches = preload("res://workshop/caches.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks := 0
var fails := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1

## The listener's chances from a fresh refresh, with the self-doubt on or off.
func _post(g, n, on: bool) -> Dictionary:
	SourceDoubt.delusional_self_doubt = on
	Caches.clear_all()
	var key: String = n.id + ":good"
	g._workshop_evaluations.erase(key)
	var was: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	g.w.defer_beliefs = was
	SourceDoubt.delusional_self_doubt = true
	var out := {}
	var eff: Dictionary = g._workshop_evaluations.get(key, {}).get("proposal", {}).get("effects", {})
	for p in eff:
		out[p] = float(eff[p].get("posterior", -1.0))
	return out

func _init() -> void:
	var found: Dictionary = Seeds.search(2, func(g):
		for n in g.w.living_good():
			var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
			if plan.is_empty() or not "delusional" in plan.prepared.view.get("world_options", {}).get("modifiers", []):
				continue
			var off: Dictionary = _post(g, n, false)
			var on: Dictionary = _post(g, n, true)
			for p in off:
				if absf(float(on.get(p, 0.0)) - float(off[p])) >= 0.02:
					return {"listener": n.id, "person": p, "off": off[p], "on": on[p]}
		return {})
	check(not found.is_empty(), "found a good listener whose own reading the self-doubt softens by 0.02 or more")
	if found.is_empty():
		_finish()
		return
	var g = found.g
	var n = g.w.by_id[found.listener]
	var tag: String = "seed %d: %s (%s) on %s" % [int(found.seed), n.id, n.role, found.person]
	print("%s: %.3f without the self-doubt, %.3f with it" % [tag, float(found.off), float(found.on)])
	# 1. It's a small doubt: it softens, it doesn't overturn.
	check(absf(float(found.on) - float(found.off)) < 0.2, "%s: the change is small (%.3f)" % [tag, absf(float(found.on) - float(found.off))])
	# 2. The doubt is on the nights of the listener's own readings, at DELUSIONAL_SELF_DOUBT
	#    and honest (it reaches the role check too).
	var plan: Dictionary = g._workshop_plans[n.id + ":good"]
	var derived: Dictionary = SourceDoubt.derive(plan, n.ledger, {})
	var own: Array = plan.prepared.view.cards.filter(func(c): return str(c.get("kind", "")) == "report" and str(c.get("source", "")) == n.id and not c.get("quoted", false) and not c.has("relay_source"))
	var nights: Array = []
	for c in own:
		var nd: int = int(c.get("observed_at", {}).get("day", c.get("night", -1)))
		if nd >= 0 and nd not in nights:
			nights.append(nd)
	var all_on: bool = not nights.is_empty()
	for nd in nights:
		var k: String = "%s:%d" % [n.id, nd]
		all_on = all_on and float(derived.pre_eval.get(k, 0.0)) >= Tuning.Workshop.DELUSIONAL_SELF_DOUBT - 1e-9 and float(derived.honest.get(k, 0.0)) >= Tuning.Workshop.DELUSIONAL_SELF_DOUBT - 1e-9
	check(all_on, "%s: each night of its own readings carries the doubt (%s)" % [tag, str(nights)])
	var others: bool = derived.pre_eval.keys().all(func(k): return not str(k).begins_with(n.id + ":") or int(str(k).get_slice(":", 1)) in nights)
	check(others, "%s: no other night of the listener's is doubted" % tag)
	# 3. Without the secret on the script there is no such doubt.
	var no_secret: Dictionary = plan.duplicate(true)
	no_secret.prepared.view.world_options.modifiers = no_secret.prepared.view.world_options.get("modifiers", []).filter(func(m): return m != "delusional")
	var none: Dictionary = SourceDoubt.derive(no_secret, n.ledger, {})
	check(not nights.any(func(nd): return float(none.pre_eval.get("%s:%d" % [n.id, nd], 0.0)) >= Tuning.Workshop.DELUSIONAL_SELF_DOUBT - 1e-9), "%s: without the Delusional secret on the script its own nights carry no self-doubt" % tag)
	_finish()

## A good Medium's own gift results (relayed cards it holds with itself as relay_source)
## carry the self-doubt on the night it heard them (Codex on #216).
func _medium_case() -> void:
	var found: Dictionary = Seeds.search(3, func(g):
		for n in g.w.living_good():
			if str(n.role) != "medium":
				continue
			var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
			if plan.is_empty() or not "delusional" in plan.prepared.view.get("world_options", {}).get("modifiers", []):
				continue
			var mine: Array = plan.prepared.view.cards.filter(func(c): return str(c.get("relay_source", "")) == n.id and not c.get("quoted", false))
			if not mine.is_empty():
				return {"listener": n.id}
		return {})
	check(not found.is_empty(), "found a good Medium holding its own gift results with the Delusional secret on the script")
	if found.is_empty():
		return
	var g = found.g
	var n = g.w.by_id[found.listener]
	var plan: Dictionary = g._workshop_plans[n.id + ":good"]
	var derived: Dictionary = SourceDoubt.derive(plan, n.ledger, {})
	var nights: Array = []
	for c in plan.prepared.view.cards:
		if str(c.get("relay_source", "")) == n.id and not c.get("quoted", false):
			var nd: int = int(c.get("relay_observed_at", {}).get("day", -1))
			if nd >= 0 and nd not in nights:
				nights.append(nd)
	var tag: String = "seed %d: %s (Medium)" % [int(found.seed), n.id]
	check(not nights.is_empty() and nights.all(func(nd): return float(derived.honest.get("%s:%d" % [n.id, nd], 0.0)) >= Tuning.Workshop.DELUSIONAL_SELF_DOUBT - 1e-9), "%s: each night it heard the dead carries the self-doubt (%s)" % [tag, str(nights)])


func _finish() -> void:
	_medium_case()
	# A gift the deal never gives the Delusional secret (ScriptDef.PLACEMENT_RULES) rules the
	# self-doubt out: the Chronicler and Rumormonger know they can't be Delusional.
	check(not SourceDoubt.could_hold_secret("chronicler", "delusional") and not SourceDoubt.could_hold_secret("rumormonger", "delusional"), "a Chronicler or Rumormonger can't be Delusional, so doesn't doubt itself that way")
	check(SourceDoubt.could_hold_secret("archivist", "delusional") and SourceDoubt.could_hold_secret("", "delusional"), "an Archivist, or a listener whose gift is unknown, could be")
	check(SourceDoubt.could_hold_secret("chronicler", "lovers"), "the rule skips the secrets it excepts (a Chronicler can be a Lover)")
	print("Delusional self-doubt: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
