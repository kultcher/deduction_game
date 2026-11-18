## ReadingChallenges.poison_chance with a reader: the night's unexplained outings as poison
## evidence ("poisoned, not lying", option A, Michael, Nov 18; docs/design/poisoned_not_lying.md).
##   godot --headless --path . --script res://tools/test_poison_outing.gd
extends SceneTree

const RC = preload("res://workshop/reading_challenges.gd")
const History = preload("res://workshop/live_history.gd")
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

## a reads (home docks, with b); c and d on the market, e on the hill, f and g on the square.
func _view(cards: Array, minions: Array = ["poisoner"]) -> Dictionary:
	var homes = {"a": "docks", "b": "docks", "c": "market", "d": "market", "e": "hill", "f": "square", "g": "square"}
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": homes[id]})
	return {"people": people, "cards": cards, "evil_count": 2, "script_minions": minions, "timeline": History.from_events([])}

func _seen(who: String, block: String, night: int = 1) -> Dictionary:
	return {"id": "s-%s-%s" % [who, block], "kind": "sighting", "source": "player", "subject": who, "subjects": [who], "block": block, "night": night}

func _listener(knowledge: Dictionary = {}) -> Dictionary:
	var k: Dictionary = {"self": "x", "good": []}
	k.merge(knowledge, true)
	return {"id": "x", "knowledge": k}

func _init() -> void:
	var base: float = RC.poison_chance(_view([]), _listener(), 1)
	check(is_equal_approx(base, 0.2), "with no outings, the chance is the base: one in five (%.3f)" % base)
	check(is_equal_approx(RC.poison_chance(_view([_seen("c", "docks")]), _listener(), 1), base), "without a reader, the outings aren't read (the self-doubt's call is unchanged)")
	# c (market) seen on the docks, the reader's block: c may be the Poisoner, going to a's or b's door.
	var near: float = RC.poison_chance(_view([_seen("c", "docks")]), _listener(), 1, "a")
	check(near > base * 1.5, "someone with no night errand seen on the reader's block raises it (%.3f from %.3f)" % [near, base])
	# Seen on the hill: going to e's door, not a's.
	var far: float = RC.poison_chance(_view([_seen("c", "hill")]), _listener(), 1, "a")
	check(far < base, "seen where they couldn't have been going to the reader's home lowers it (%.3f)" % far)
	# Seen with no block named, or on their own block: no word on whose door.
	check(is_equal_approx(RC.poison_chance(_view([_seen("c", "")]), _listener(), 1, "a"), base), "seen out with no block named: unchanged when a Poisoner is certainly in play")
	check(is_equal_approx(RC.poison_chance(_view([_seen("c", "market")]), _listener(), 1, "a"), base), "seen on their own block: unchanged")
	var unsure: float = RC.poison_chance(_view([_seen("c", "")], ["poisoner", "brute"]), _listener(), 1, "a")
	var unsure_base: float = RC.poison_chance(_view([], ["poisoner", "brute"]), _listener(), 1, "a")
	check(unsure > unsure_base, "but when a Poisoner may not be in play, any unexplained outing makes one likelier (%.3f from %.3f)" % [unsure, unsure_base])
	# Explained outings, and people the listener knows are good.
	var warden: Dictionary = {"id": "cl", "kind": "claim", "source": "c", "subject": "c", "role": "warden", "night": -1}
	check(is_equal_approx(RC.poison_chance(_view([_seen("c", "docks"), warden]), _listener(), 1, "a"), base), "a claimed night gift explains the outing")
	var sleep: Dictionary = {"id": "sw", "kind": "secret_claim", "source": "c", "subject": "c", "applies": {"from": 0, "through": 3}}
	check(is_equal_approx(RC.poison_chance(_view([_seen("c", "docks"), sleep]), _listener(), 1, "a"), base), "so does a confided secret that covers the night")
	check(is_equal_approx(RC.poison_chance(_view([_seen("c", "docks")]), _listener({"good": ["c"]}), 1, "a"), base), "someone the listener knows is good isn't a Poisoner")
	check(is_equal_approx(RC.poison_chance(_view([_seen("c", "docks", 2)]), _listener(), 1, "a"), base), "another night's outing says nothing of this one")
	# Two walkers on the reader's block: still at most one Poisoner.
	var two: float = RC.poison_chance(_view([_seen("c", "docks"), _seen("e", "docks")]), _listener(), 1, "a")
	check(two > near and two <= 1.0, "two walkers on the reader's block raise it further, within bounds (%.3f)" % two)
	check(RC.poison_chance(_view([_seen("c", "docks")], ["scout"]), _listener(), 1, "a") == 0.0, "no Poisoner on the script: none, whatever the outings")
	_track_record()
	print("Poison outing: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


## A "failed gift" call goes in the track record as "R is good" (Michael, Nov 18): a wrong
## call costs credibility at dawn like any argued conclusion.
func _track_record() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(692, 7)
	var goods: Array = g.w.living_good()
	var reader = goods[0]
	var listener = goods[1]
	g.w.day = 2
	var text: String = "%s's Archivist reading: one of %s and %s is the Poisoner" % [reader.name, goods[2].name, goods[3].name]
	g.add_card({"kind": "info", "source": reader.id, "role": "archivist", "day": 0, "phase": 3, "data": {"pair": [goods[2].id, goods[3].id], "role": "poisoner"}, "text": text})
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var node: String = ""
	for id in model.nodes:
		if model.nodes[id].kind == "evidence" and Solver.card_by_id(view, model.nodes[id].card).get("text", "") == text:
			node = id
	var premise: String = model.add_premise(goods[2].id, "good", Vector2(400, 40))
	model.add_modifier(node, "impaired")
	model.connect_cards(model.selected, premise)
	var filed: int = Live.file(g, model.compile(premise))
	check(filed > 0, "a case calling the reading a failed gift can be filed (%s)" % g.last_error)
	if filed <= 0:
		return
	listener.claim_record.erase(reader.id)
	g._evaluate_deduction(listener, g.board[filed - 1], 1.0, false)
	var rec: Dictionary = listener.claim_record.get(reader.id, {})
	check(str(rec.get("type", "")) == "good", "the listener records that the player called %s good (%s)" % [reader.name, str(rec)])
	check(str(listener.claim_record.get(goods[2].id, {}).get("type", "")) == "good", "and the case's own conclusion as before")
