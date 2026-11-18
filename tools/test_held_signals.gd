## Purge phase 6b (docs/connections_purge_plan.md): under the connections model an NPC believes
## from every card it holds, so the floor a "lying" challenge made outside any case puts
## under its teller applies even when the challenged reading isn't among the cards the
## listener attends to. Bot games never make such a challenge, so this builds one: a
## defence challenging a held, unattended reading, heard at full weight.
##   godot --headless --path . --script res://tools/test_held_signals.gd
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")

const SEEDS_FROM = 100
const SEEDS_COUNT = 40
const WANT = 3
const HELD_FLOOR_SEEN = 0.2

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	var tested := 0
	for seed_v in range(SEEDS_FROM, SEEDS_FROM + SEEDS_COUNT):
		tested += _seed(seed_v)
		if tested >= WANT:
			break
	_check(tested >= WANT, "found %d listeners holding a reading they don't attend to (wanted %d)" % [tested, WANT])
	print("Held signals: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## Play passively to day 2's afternoon. Give a low-Insight good listener a reading it knows
## is false (a Dowser count naming it as evil), then bury it under plausible readings so its
## attention drops it, challenge it as a lie, and check the teller takes the floor.
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
	if g.state == "over":
		return 0
	var goods: Array = g.w.living_good()
	var living: Array = g.w.living()
	if goods.size() < 3 or living.size() < 6:
		return 0
	var n = goods[0]
	n.traits["insight"] = 0.05
	var teller = goods[1]
	# A teller the listener distrusts, so a reading that can't be true reads as a lie rather
	# than an honest mistake (the lying agreement scales with distrust of the teller).
	n.npc_trust[teller.id] = 0.0
	var other = living.filter(func(x): return x.id != n.id and x.id != teller.id)[0]
	# "Both of these read as evil", naming the listener, who knows it is good.
	Mind.apply_info(g.w, n, teller, {"day": 1, "role": "dowser", "data": {"group": [n.id, other.id], "count": 2}, "text": "held-signal test"}, 1.0)
	var fillers: Array = living.filter(func(x): return x.id != n.id and x.id != teller.id)
	for k in range(12):
		var src = fillers[k % fillers.size()]
		var pair: Array = [fillers[(k + 1) % fillers.size()].id, fillers[(k + 2) % fillers.size()].id]
		Mind.apply_info(g.w, n, src, {"day": 2, "role": "seer", "data": {"pair": pair, "yes": false}, "text": "filler %d" % k}, 1.0)
	Mind.refresh_beliefs(g.w, n, " (before)")
	var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
	if plan.is_empty():
		return 0
	var mine: Array = plan.prepared.view.cards.filter(func(c): return c.get("kind", "") == "report" and str(c.get("source", "")) == teller.id and str(c.get("role", "")) == "dowser")
	if mine.is_empty():
		return 0
	var card: Dictionary = mine[0]
	var considered: Array = n.workshop_state.get("reasoning", {}).get("considered", [])
	var before: float = float(n.suspicion.get(teller.id, 0.1))
	Mind.ledger_hear(g.w, n, "def:test:held:" + card.id, [], 1.0, [teller.id, -1, "report"],
		{"kind": "defence", "move": "lying", "scope": {"type": "challenge", "mode": "lying", "reading": card.id}, "hearing_scale": 1.0})
	Mind.refresh_beliefs(g.w, n, " (after the challenge)")
	var attended: bool = card.id in n.workshop_state.get("reasoning", {}).get("considered", [])
	var after: float = float(n.suspicion.get(teller.id, 0.1))
	print("seed %d: %s on %s, attended before %s / after %s, suspicion %.3f -> %.3f" % [seed_v, n.id, teller.id, card.id in considered, attended, before, after])
	if attended:
		return 0
	# A teller already as suspected as the floor would put them (the floor lands at 0.2 to 0.22 on
	# every seed that lifts) has nothing to lift: not a case for this test (#269: a deal where
	# the teller started at 0.253).
	if absf(after - before) < 0.005 and before >= HELD_FLOOR_SEEN:
		print("  seed %d: %s already above the floor; skipped" % [seed_v, teller.id])
		return 0
	# The floor is a minimum on the evidence against the teller, so it lifts them only as far
	# as they weren't already suspected. Before purge phase 6b it never applied here (the
	# reading wasn't attended), and the teller didn't move at all.
	_check(after > before + 0.005, "seed %d: %s's challenge lifts %s from a reading it doesn't attend to (%.3f -> %.3f)" % [seed_v, n.id, teller.id, before, after])
	return 1
