## A Lamplighter's count, mixed as sound or broken as a whole (Michael, Nov 19, the Lamplighter
## fix (b), step 1; Lantern's conditions): in a world where the Lamplighter is good the count is
## sound (the routes gate and the people it forces out) with chance 1 - b, or broken (it says
## nothing) with chance b, from its poison and Delusional priors; in a world where it is evil
## it says nothing at all. A count that no route mask fits makes the sound branch impossible,
## so it tells against the Lamplighter. Night Watch lists are unchanged.
##   godot --headless --path . --script res://tools/test_lamplighter_count_mix.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	var f: Dictionary = _deal()
	check(not f.is_empty(), "(fixture) a deal with a good Lamplighter and others")
	if f.is_empty():
		_done()
		return
	_count_with_alibis(f)
	_impossible_count(_deal())
	_testimony_clash(_deal())
	_done()


## The count plus everyone else's home alibi, about the one left without one: mixed, the case is
## weaker than with the count taken as certain (the old behaviour, the mix switched off),
## because in worlds where the Lamplighter is evil or broken the count forces no one out.
func _count_with_alibis(f: Dictionary) -> void:
	var g = f.g
	var lamp = f.lamp
	var s = f.subject
	var nums: Array = [g.add_card({"kind": "info", "source": lamp.id, "role": "lamplighter", "day": 1, "phase": C.NIGHT, "data": {"count": 1}, "text": "L: 1 other out"})]
	for n in g.w.npcs:
		if n.alive and n != s and n != lamp:
			nums.append(g.add_card({"kind": "alibi", "subject": [n.id], "source": n.id, "day": 1, "phase": C.NIGHT, "home": true, "block": n.home_block, "text": "%s: home" % n.name}))
	var value: Dictionary = _case(g, s.id, "evil", nums)
	var mixed: Dictionary = Live.shape_reading(g, value)
	SourceDoubt.list_mix_enabled = false
	var certain: Dictionary = Live.shape_reading(g, value)
	SourceDoubt.list_mix_enabled = true
	check(mixed.get("ready", false) and certain.get("ready", false) and float(mixed.lr) < float(certain.lr) and float(mixed.lr) > 1.0,
		"mixed, the count still supports the case but less than taken as certain (x%.2f against x%.2f)" % [float(mixed.get("lr", 0.0)), float(certain.get("lr", 0.0))])


## A count of nobody out, against a sighting of someone out that night: no route mask fits, so
## the sound branch is impossible and only a broken or evil Lamplighter explains it. "The
## Lamplighter is evil" is then better supported with the count than without it. Before, an
## impossible count silently did nothing.
func _impossible_count(f: Dictionary) -> void:
	var g = f.g
	var lamp = f.lamp
	var out_one = f.subject
	var seen: int = g.add_card({"kind": "sighting", "subject": [out_one.id], "block": "market" if out_one.home_block != "market" else "docks", "source": f.witness.id, "day": 1, "phase": C.NIGHT, "text": "W saw X out"})
	var count0: int = g.add_card({"kind": "info", "source": lamp.id, "role": "lamplighter", "day": 1, "phase": C.NIGHT, "data": {"count": 0}, "text": "L: nobody out"})
	var with_count: Dictionary = Live.shape_reading(g, _case(g, lamp.id, "evil", [seen, count0]))
	var without: Dictionary = Live.shape_reading(g, _case(g, lamp.id, "evil", [seen]))
	check(with_count.get("ready", false) and without.get("ready", false) and float(with_count.lr) > float(without.lr) * 1.1,
		"a count that fits no route tells against the Lamplighter (x%.2f with it, x%.2f without)" % [float(with_count.get("lr", 0.0)), float(without.get("lr", 0.0))])


## A true count of 1 (the Demon was out) against everyone else's "home", the Demon's a lie
## (Lantern on #346): only testimony clashes, so the count isn't impossible. It must not
## convict the honest Lamplighter, as it did when anyone's alibi could rule it out.
func _testimony_clash(f: Dictionary) -> void:
	var g = f.g
	var lamp = f.lamp
	var count1: int = g.add_card({"kind": "info", "source": lamp.id, "role": "lamplighter", "day": 1, "phase": C.NIGHT, "data": {"count": 1}, "text": "L: 1 other out"})
	var alibis: Array = []
	for n in g.w.npcs:
		if n.alive and n != lamp:
			alibis.append(g.add_card({"kind": "alibi", "subject": [n.id], "source": n.id, "day": 1, "phase": C.NIGHT, "home": true, "block": n.home_block, "text": "%s: home" % n.name}))
	var r: Dictionary = Live.shape_reading(g, _case(g, lamp.id, "evil", [count1] + alibis))
	var d: Dictionary = Live.shape_reading(g, _case(g, f.subject.id, "evil", [count1] + alibis))
	check(r.get("ready", false) and float(r.lr) < 1.5,
		"a true count against a lying alibi doesn't convict the Lamplighter (x%.2f; the Demon x%.2f)" % [float(r.get("lr", 0.0)), float(d.get("lr", 0.0))])


func _case(g, target: String, type: String, nums: Array) -> Dictionary:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var texts: Array = nums.map(func(n): return str(g.board[n - 1].text))
	var p: String = model.add_premise(target, type, Vector2(0, 0))
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and str(Solver.card_by_id(view, nd.card).get("text", "")) in texts:
			model.connect_cards(id, p)
	return model.compile(p)


## A 10-NPC deal with a living good Lamplighter, a subject (the Demon) and a good witness.
func _deal() -> Dictionary:
	for sd in range(1, 120):
		var g = Game.new()
		g.log_dir = "user://test_logs"
		g.new_case(sd, 10)
		var lamp = null
		for n in g.w.living_good():
			if n.role == "lamplighter":
				lamp = n
		if lamp == null:
			continue
		var witness = g.w.living_good().filter(func(n): return n != lamp)[0]
		g.w.day = 3
		return {"g": g, "lamp": lamp, "subject": g.w.by_id[g.w.demon_id], "witness": witness}
	return {}


func _done() -> void:
	print("Lamplighter count mix: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
