## A bare defence ("X is lying") cites no grounds, so it can't widen a bounded listener's
## attention (premises pass, step 0; case 13910).
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)
		print("FAIL: " + label)

func _init() -> void:
	var tested := 0
	for seed_v in [13910, 42, 900]:
		tested += _seed(seed_v)
	_check(tested >= 2, "found bounded listeners holding a reading to test (%d)" % tested)
	print("Defence grounds: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## Play passively to Day 2's afternoon, then give each bounded good listener a defence
## challenging one reading they hold, and compare.
func _seed(seed_v: int) -> int:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, 10)
	var guard := 0
	while g.state != "over" and (g.w.day < 2 or g.w.phase < 1) and guard < 200:
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	var tested := 0
	for n in g.w.living_good():
		Mind.refresh_beliefs(g.w, n, " (before)")
		var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
		if plan.is_empty() or str(plan.prepared.listener.get("reasoning_mode", "")) != "bounded":
			continue
		var reports: Array = plan.prepared.view.cards.filter(func(c): return c.get("kind", "") == "report" and str(c.get("source", "")) != n.id)
		if reports.is_empty() or plan.prepared.view.cards.size() < 6:
			continue
		var before: int = n.workshop_state.get("reasoning", {}).get("considered", []).size()
		var rid: String = str(reports[0].id)
		var eid: String = "def:test:challenge:" + rid
		Mind.ledger_hear(g.w, n, eid, [], 0.8, [str(reports[0].source), -1, "report"],
			{"kind": "defence", "move": "lying", "scope": {"type": "challenge", "mode": "lying", "reading": rid}, "hearing_scale": 0.05})
		Mind.refresh_beliefs(g.w, n, " (after defence)")
		var plan2: Dictionary = g._workshop_plans.get(n.id + ":good", {})
		var rc: Dictionary = plan2.prepared.case.get("reading_challenges", {})
		var after: int = n.workshop_state.get("reasoning", {}).get("considered", []).size()
		_check(rc.has(rid) and rc[rid].get("supports", ["x"]).is_empty(), "%s/%s: the defence is a challenge with no grounds" % [seed_v, n.id])
		_check(after <= before + 1, "%s/%s: attention stays bounded (%d -> %d of %d)" % [seed_v, n.id, before, after, plan2.prepared.view.cards.size()])
		tested += 1
	return tested
