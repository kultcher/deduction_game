## "Was my gift turned?" in played games (OwnGiftDoubt; Michael, Nov 19): a good NPC's
## self-doubt is the judge's chance its own reading that night was wrong, from the clash with
## everything else it holds, and it doubts its gift on a night at or above
## Tuning.Workshop.SELF_DOUBT_TRIGGER. A seed search for a 10-NPC game where someone does, so
## it runs with the full list, not on the fast list (about one game in five has one).
##   godot --headless --path . --script res://tools/test_own_gift_doubt.gd
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const OwnGiftDoubt = preload("res://workshop/own_gift_doubt.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	var found: Dictionary = Seeds.search(4, func(g):
		for n in g.w.living_good():
			if not SourceDoubt.doubts_own_gift(n).is_empty():
				return {"listener": n.id}
		return {}, 10, 3000, 40)
	check(not found.is_empty(), "a played game where a good NPC doubts its own gift")
	if found.is_empty():
		print("Own gift doubt: %d checks, %d failures" % [checks, fails])
		quit(1)
		return
	var g = found.g
	var n = g.w.by_id[found.listener]
	var judged: Dictionary = SourceDoubt.self_doubt(n)
	var prior: Dictionary = SourceDoubt.self_doubt_prior(n)
	var nights: Array = SourceDoubt.doubts_own_gift(n)
	print("seed %d: %s (%s) doubts its gift on nights %s; judged %s, prior %s" % [int(found.seed), n.id, n.role, str(nights), str(judged), str(prior)])
	var trig: float = Tuning.Workshop.SELF_DOUBT_TRIGGER
	check(nights.all(func(k): return float(judged[k]) >= trig) and judged.keys().all(func(k): return float(judged[k]) < trig or k in nights), "the nights it doubts are those at or above the trigger")
	check(nights.any(func(k): return float(judged[k]) > float(prior.get(k, 0.0))), "on a night it doubts, the clash raised its doubt above the prior")
	# Every night in its self-doubt is a night of its own reading that the judge can check.
	var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
	var ok: bool = not plan.is_empty()
	if ok:
		for k in judged:
			ok = ok and plan.prepared.view.cards.any(func(c): return str(c.get("kind", "")) == "report" and str(c.get("source", "")) == n.id and not c.has("relay_source") and int(c.get("observed_at", {}).get("day", c.get("night", -1))) == int(k) and OwnGiftDoubt.checked(plan.prepared.view, c))
	check(ok, "each night of its self-doubt is a night of its own checkable reading")
	# Across that game's good NPCs, a reading that fits the rest is doubted below its prior
	# (not just raised everywhere, as the prior alone was).
	var below: int = 0
	var total: int = 0
	for m in g.w.living_good():
		var j: Dictionary = SourceDoubt.self_doubt(m)
		var p: Dictionary = SourceDoubt.self_doubt_prior(m)
		for k in j:
			total += 1
			if float(j[k]) < float(p.get(k, 0.0)):
				below += 1
	print("nights doubted below their prior: %d of %d" % [below, total])
	check(below > 0, "a reading that fits the rest is doubted less than its prior (%d of %d nights)" % [below, total])
	print("Own gift doubt: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
