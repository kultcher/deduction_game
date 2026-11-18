## A case with no cards, on a record with a silencing, reads every day card on the view for
## "who was near each silencing" (DayPresence.breath_factor). The same situation must give the
## same belief whether or not an earlier, different view was compiled first (BACKLOG section
## 6, "A case with no cards can be answered from an older compile"; seed 962 read 0.612 cold
## and 0.579 warm, Nov 13). Before the fix the compile key left out the view's cards, so two
## views with different silencing factors shared one compile. Found by search, not a
## hard-coded seed.
##   godot --headless --path . --script res://tools/test_bare_compile.gd
extends SceneTree
const Seeds = preload("res://tools/fixture_seeds.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Caches = preload("res://workshop/caches.gd")
const DayPresence = preload("res://workshop/day_presence.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	# A listener at a day-2 meeting whose view has a silencing, and a day card whose removal
	# changes what a no-card case says (so a stale compile would show).
	DayPresence.bare_reads_view = true  # as in play outside the connections judge
	var found: Dictionary = Seeds.search(2, func(g):
		for n in g.w.living_good():
			var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
			if plan.is_empty():
				continue
			var view: Dictionary = plan.prepared.view
			if not view.get("timeline", {}).get("events", []).any(func(e): return str(e.get("kind", "")) == "silenced"):
				continue
			var bare_c: Dictionary = plan.prepared.case.duplicate(true)
			bare_c.cards = []
			Caches.clear_all()
			var full: Dictionary = CaseEval.evaluate(view, bare_c, plan.prepared.listener)
			for c in view.get("cards", []):
				if str(c.get("kind", "")) not in ["sighting", "evening", "coverage", "alibi"]:
					continue
				var fewer_v: Dictionary = view.duplicate(true)
				fewer_v.cards = fewer_v.cards.filter(func(x): return x.id != c.id)
				Caches.clear_all()
				var less: Dictionary = CaseEval.evaluate(fewer_v, bare_c, plan.prepared.listener)
				for p in full.get("people", {}):
					if absf(float(full.people[p].get("posterior", 0.0)) - float(less.get("people", {}).get(p, {}).get("posterior", 0.0))) > 1e-6:
						return {"plan": plan, "drop": c.id}
		return {}, 10)
	check(not found.is_empty(), "found a listener with a silencing on the record and a day card that changes a no-card case")
	if found.is_empty():
		_finish()
		return
	var plan: Dictionary = found.plan
	var view: Dictionary = plan.prepared.view
	var listener: Dictionary = plan.prepared.listener
	var bare: Dictionary = plan.prepared.case.duplicate(true)
	bare.cards = []
	var fewer: Dictionary = view.duplicate(true)
	fewer.cards = fewer.cards.filter(func(c): return c.id != found.drop)
	# The two views' silencing factors differ, so their compiles must not share a key.
	var b_full: Dictionary = DayPresence.breath_factor(view, [])
	var b_less: Dictionary = DayPresence.breath_factor(fewer, [])
	var keys_differ: bool = CaseEval.compile(view, [], bare).key != CaseEval.compile(fewer, [], bare).key
	check(JSON.stringify(b_full) == JSON.stringify(b_less) or keys_differ, "seed %d: views whose silencing factor differs compile under different keys" % found.seed)
	# Cold: nothing compiled before.
	Caches.clear_all()
	var cold: Dictionary = CaseEval.evaluate(fewer, bare, listener)
	# Warm: the full view compiled first, then the view with one day card fewer.
	Caches.clear_all()
	CaseEval.evaluate(view, bare, listener)
	var warm: Dictionary = CaseEval.evaluate(fewer, bare, listener)
	var same: bool = true
	var worst: float = 0.0
	for p in cold.get("people", {}):
		var d: float = absf(float(cold.people[p].get("posterior", 0.0)) - float(warm.get("people", {}).get(p, {}).get("posterior", -1.0)))
		worst = maxf(worst, d)
		if d > 1e-12:
			same = false
	print("seed %d: dropped %s; largest difference warm vs cold %.6f" % [found.seed, found.drop, worst])
	check(same, "seed %d: a no-card case gives the same chances whether or not a different view was compiled first (largest gap %.6f)" % [found.seed, worst])
	_finish()

func _finish() -> void:
	print("Bare compile: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
