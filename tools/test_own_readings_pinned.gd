## Step 0b of the premises pass: during a presentation, a bounded listener's own readings that
## bear on the premise's target (or a presented card) stay in view outside the card budget.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Reasoner = preload("res://workshop/reasoner.gd")

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
	for seed_v in [13910, 42, 900, 692]:
		tested += _seed(seed_v)
	_check(tested >= 2, "found listeners with an own reading to test (%d)" % tested)
	print("Own readings pinned: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

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
		Mind.refresh_beliefs(g.w, n, " (probe)")
		var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
		if plan.is_empty():
			continue
		var view: Dictionary = plan.prepared.view
		var own: Array = view.cards.filter(func(c): return c.get("kind", "") == "report" and str(c.get("source", "")) == n.id and not Reasoner._mentions(c).filter(func(p): return p != n.id).is_empty())
		var others: Array = view.cards.filter(func(c): return str(c.get("source", "")) != n.id and c.get("kind", "") in ["report", "sighting", "claim"])
		if own.is_empty() or others.size() < 5:
			continue
		var mine: Dictionary = own[0]
		var target: String = Reasoner._mentions(mine).filter(func(p): return p != n.id)[0]
		var presented: Array = others.slice(0, 5).map(func(c): return c.id)
		var listener: Dictionary = plan.prepared.listener.duplicate(true)
		listener.insight = 0.2 # the Low profile: 4 cards, fewer than the case
		listener.reasoning_mode = "bounded"
		listener.knowledge["attention_reports"] = [mine.id]
		listener.knowledge["presented_reports"] = presented
		var case_v: Dictionary = plan.prepared.case.duplicate(true)
		case_v.cards = presented.duplicate()
		case_v.lines = [{"id": "direct", "relation": "supports", "cards": presented.duplicate(), "answers": {}, "positions": {}, "label": ""}]
		case_v.conclusion = {"type": "evil", "target": target, "at": case_v.get("conclusion", {}).get("at", "")}
		case_v["reading_challenges"] = {}
		var r: Dictionary = Reasoner._prepare(view, case_v, listener)
		_check(mine.id in r.considered, "%s/%s: their own reading about %s stays in view beside a 5-card case" % [seed_v, n.id, target])
		_check(r.considered.size() <= presented.size() + 2, "%s/%s: attention stays bounded (%d)" % [seed_v, n.id, r.considered.size()])
		# Not about the target or any presented card: no pin.
		var case_far: Dictionary = case_v.duplicate(true)
		case_far.conclusion.target = n.id
		var unrelated: bool = not presented.any(func(id): var c = view.cards.filter(func(x): return x.id == id)[0]; return Reasoner._mentions(c).any(func(p): return p in Reasoner._mentions(mine)) or str(c.get("source", "")) in Reasoner._mentions(mine))
		if unrelated:
			var r2: Dictionary = Reasoner._prepare(view, case_far, listener)
			_check(r2.considered.size() <= 4 + 1 or not (mine.id in r2.considered) or mine.id in presented, "%s/%s: an unrelated own reading isn't pinned" % [seed_v, n.id])
		tested += 1
	return tested
