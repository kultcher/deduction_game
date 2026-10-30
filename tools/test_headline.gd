## Headline reading (Oct 30): a dull listener takes a strong evil reading at its word on
## top of the full model; a sharp one mostly follows the model. Constructed fixtures.
extends SceneTree
const Game = preload("res://game/game.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Caches = preload("res://workshop/caches.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(4, 10)
	var holder = g.w.living_good().filter(func(m): return not m.workshop_state.is_empty())[0]
	var demon: String = g.w.demon_id
	var good: Array = g.w.npcs.filter(func(m): return m.id != holder.id and not m.is_evil()).map(func(m): return m.id)
	var minion: String = g.w.npcs.filter(func(m): return m.is_evil() and m.id != demon)[0].id
	var cases = {
		"seer": {"role": "seer", "day": 0, "phase": 3, "data": {"pair": [demon, good[0]], "yes": true}, "named": [demon, good[0]]},
		"archivist": {"role": "archivist", "day": 0, "phase": 3, "data": {"pair": [minion, good[1]], "role": g.w.by_id[minion].role}, "named": [minion, good[1]]},
		"dowser": {"role": "dowser", "day": 1, "phase": 0, "data": {"group": [demon, minion, good[2]], "count": 2}, "named": [demon, minion, good[2]]},
	}
	for role in cases:
		var c: Dictionary = cases[role]
		holder.role = role
		holder.info_log = [{"role": role, "day": c.day, "phase": c.phase, "data": c.data, "true": true, "text": "%s reading" % role}]
		var steps = {}
		for insight in [0.1, 0.9]:
			holder.traits.insight = insight
			Caches.clear_all()
			var effects = _own_view(g, holder)
			var total := 0.0
			var head := 0.0
			for id in c.named:
				total += float(effects[id].requested)
				head += float(effects[id].headline_signal)
			steps[insight] = total
			print("  %s insight %.1f: named people step %+.3f (headline %.3f)" % [role, insight, total, head])
			_check(head > 0.0, "%s: the reading has a headline on the people it names (insight %.1f)" % [role, insight])
		# The headline only adds where it beats the model (an Archivist reading is already
		# strong in the model), so a dull holder moves at least as far, never less.
		_check(steps[0.1] >= steps[0.9] - 0.000001, "%s: a dull holder moves at least as far as a sharp one (%+.3f vs %+.3f)" % [role, steps[0.1], steps[0.9]])
		_check(steps[0.9] > 0.0, "%s: a sharp holder still moves toward the named people" % role)
	print("Headline: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _own_view(g, n) -> Dictionary:
	var st = n.workshop_state
	var outside: Dictionary = st.get("outside", n.suspicion).duplicate(true)
	var input = Bridge.capture(g, [], n.id, "private", n)
	input.listener.suspicion = outside.duplicate(true)
	var plan = Shared.prepare(input, st.get("presentations", {}), n.ledger, st.get("withdrawn", {}), st.get("attention_focus", []))
	return Shared.evaluate(plan, outside, n.discounted).effects if plan.ready else {}
