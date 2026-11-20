## A Lamplighter's count, mixed as sound or broken as a whole (Michael, Nov 19, the Lamplighter
## fix (b), step 1; Lantern's conditions): in a world where the Lamplighter is good the count is
## sound (the routes gate and the people it forces out) with chance 1 - b, or broken (it says
## nothing) with chance b, from its poison and Delusional priors; in a world where it is evil
## it says nothing at all. A count that no route mask of the certain evidence fits (the
## listener's own nights and sightings, physical traces) makes the sound branch impossible, so
## it tells against the Lamplighter. Night Watch lists are unchanged.
##   godot --headless --path . --script res://tools/test_lamplighter_count_mix.gd
extends SceneTree

const GameBoard = preload("res://game/game_board.gd")
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")

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
	_listener_keyed(_deal())
	_done()


## The count plus everyone else's home alibi, about the one left without one: mixed, the case is
## weaker than with the count taken as certain (the old behaviour, the mix switched off),
## because in worlds where the Lamplighter is evil or broken the count forces no one out.
func _count_with_alibis(f: Dictionary) -> void:
	var g = f.g
	var lamp = f.lamp
	var s = f.subject
	var nums: Array = [GameBoard.add_card(g, {"kind": "info", "source": lamp.id, "role": "lamplighter", "day": 1, "phase": C.NIGHT, "data": {"count": 1}, "text": "L: 1 other out"})]
	for n in g.w.npcs:
		if n.alive and n != s and n != lamp:
			nums.append(GameBoard.add_card(g, {"kind": "alibi", "subject": [n.id], "source": n.id, "day": 1, "phase": C.NIGHT, "home": true, "block": n.home_block, "text": "%s: home" % n.name}))
	var value: Dictionary = _case(g, s.id, "evil", nums)
	var mixed: Dictionary = Live.shape_reading(g, value)
	SourceDoubt.list_mix_enabled = false
	var certain: Dictionary = Live.shape_reading(g, value)
	SourceDoubt.list_mix_enabled = true
	check(mixed.get("ready", false) and certain.get("ready", false) and float(mixed.lr) < float(certain.lr) and float(mixed.lr) > 1.0,
		"mixed, the count still supports the case but less than taken as certain (x%.2f against x%.2f)" % [float(mixed.get("lr", 0.0)), float(certain.get("lr", 0.0))])


## A count of nobody out, against a witness's sighting of someone out that night, heard by a
## third party (Lantern on #346): either the witness or the Lamplighter could be lying, so the
## count isn't impossible to them and mustn't convict the Lamplighter. Only the listener's own
## sightings and nights, and physical traces, can rule a count out (certain_for_count below).
func _impossible_count(f: Dictionary) -> void:
	var g = f.g
	var lamp = f.lamp
	var out_one = f.subject
	var seen: int = GameBoard.add_card(g, {"kind": "sighting", "subject": [out_one.id], "block": "market" if out_one.home_block != "market" else "docks", "source": f.witness.id, "day": 1, "phase": C.NIGHT, "text": "W saw X out"})
	var count0: int = GameBoard.add_card(g, {"kind": "info", "source": lamp.id, "role": "lamplighter", "day": 1, "phase": C.NIGHT, "data": {"count": 0}, "text": "L: nobody out"})
	var with_count: Dictionary = Live.shape_reading(g, _case(g, lamp.id, "evil", [seen, count0]))
	var witness: Dictionary = Live.shape_reading(g, _case(g, f.witness.id, "evil", [seen, count0]))
	check(with_count.get("ready", false) and float(with_count.lr) < 1.5,
		"a third party hearing a sighting against the count doesn't convict the Lamplighter (x%.2f; the witness x%.2f)" % [float(with_count.get("lr", 0.0)), float(witness.get("lr", 0.0))])
	# Which cards can rule a count out.
	var cnt := {"id": "c1", "kind": "report", "source": lamp.id}
	check(LiveActivity.certain_for_count(cnt, "c1", "me"), "the count itself is in its own check")
	check(LiveActivity.certain_for_count({"id": "s1", "kind": "sighting", "source": "me"}, "c1", "me"), "the listener's own sighting can rule a count out")
	check(not LiveActivity.certain_for_count({"id": "s2", "kind": "sighting", "source": f.witness.id}, "c1", "me"), "another's sighting can't (it could be the lie)")
	check(not LiveActivity.certain_for_count({"id": "s3", "kind": "sighting", "source": f.witness.id}, "c1", ""), "nor can any sighting for a listener with no nights of its own")
	check(not LiveActivity.certain_for_count({"id": "a1", "kind": "alibi", "source": f.witness.id}, "c1", "me"), "nor anyone's alibi")
	check(LiveActivity.certain_for_count({"id": "h1", "kind": "alibi", "known_self": true, "self_doubt": Tuning.Workshop.OWN_ERR}, "c1", "me"), "the listener's own night can")
	check(not LiveActivity.certain_for_count({"id": "h2", "kind": "alibi", "known_self": true, "self_doubt": Tuning.Workshop.SLEEPWALK_SELF_DOUBT}, "c1", "me"),
		"but not a night it may have sleepwalked (a Sleepwalker script)")
	check(LiveActivity.certain_for_count({"id": "t1", "kind": "trace"}, "c1", "me") and not LiveActivity.certain_for_count({"id": "t2", "kind": "trace", "quoted": true}, "c1", "me"),
		"a trace seen for itself can, a report of one can't")


## A true count of 1 (the Demon was out) against everyone else's "home", the Demon's a lie
## (Lantern on #346): only testimony clashes, so the count isn't impossible. It must not
## convict the honest Lamplighter, as it did when anyone's alibi could rule it out.
func _testimony_clash(f: Dictionary) -> void:
	var g = f.g
	var lamp = f.lamp
	var count1: int = GameBoard.add_card(g, {"kind": "info", "source": lamp.id, "role": "lamplighter", "day": 1, "phase": C.NIGHT, "data": {"count": 1}, "text": "L: 1 other out"})
	var alibis: Array = []
	for n in g.w.npcs:
		if n.alive and n != lamp:
			alibis.append(GameBoard.add_card(g, {"kind": "alibi", "subject": [n.id], "source": n.id, "day": 1, "phase": C.NIGHT, "home": true, "block": n.home_block, "text": "%s: home" % n.name}))
	var r: Dictionary = Live.shape_reading(g, _case(g, lamp.id, "evil", [count1] + alibis))
	var d: Dictionary = Live.shape_reading(g, _case(g, f.subject.id, "evil", [count1] + alibis))
	check(r.get("ready", false) and float(r.lr) < 1.5,
		"a true count against a lying alibi doesn't convict the Lamplighter (x%.2f; the Demon x%.2f)" % [float(r.get("lr", 0.0)), float(d.get("lr", 0.0))])


## The same cards for two listeners with no home nights of their own (Codex on #346): the
## witness's own sighting rules the count out for the witness only, so the cached movement
## factor must not be shared between them.
func _listener_keyed(f: Dictionary) -> void:
	var g = f.g
	var lamp = f.lamp
	var out_one = f.subject
	var seen: int = GameBoard.add_card(g, {"kind": "sighting", "subject": [out_one.id], "block": "market" if out_one.home_block != "market" else "docks", "source": f.witness.id, "day": 1, "phase": C.NIGHT, "text": "W saw X out (keyed)"})
	var count0: int = GameBoard.add_card(g, {"kind": "info", "source": lamp.id, "role": "lamplighter", "day": 1, "phase": C.NIGHT, "data": {"count": 0}, "text": "L: nobody out (keyed)"})
	var view: Dictionary = Live.view(g)
	var cards: Array = view.cards.filter(func(c): return str(c.get("text", "")).ends_with("(keyed)")).map(func(c): return c.duplicate(true))
	for c in cards:
		if c.get("kind", "") == "report":
			c["count_mix"] = true
			c["broken_chance"] = 0.05
	var zero_for: Callable = func(me: String) -> bool:
		var v: Dictionary = view.duplicate(false)
		v["own_home"] = {"self": me, "block": "", "nights": {}}
		var fs: Array = LiveActivity.factors(v, cards, {})
		return not fs.is_empty() and bool(fs[0].get("list_mix", {}).get("sound_zero", false))
	var witness_zero: bool = zero_for.call(f.witness.id)
	var other_zero: bool = zero_for.call(lamp.id)
	var witness_again: bool = zero_for.call(f.witness.id)
	check(cards.size() == 2 and witness_zero and not other_zero and witness_again,
		"the witness's own sighting rules the count out for the witness only, cached or not (witness %s, other %s, witness again %s)" % [witness_zero, other_zero, witness_again])


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
