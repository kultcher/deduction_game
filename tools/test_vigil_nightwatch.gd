## A player's vigil against a Night Watch report (BACKLOG "Challenge a Night Watch report
## using a conflicting player vigil", [decided]). The world model already weighs the clash;
## this pins it: same night and block versus another block, the challenge route, a vigil
## that saw someone (complete coverage), and the watcher's own walk to the block.
##   godot --headless --path . --script res://tools/test_vigil_nightwatch.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Caches = preload("res://workshop/caches.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")

const SEEDS = [1, 2, 3]
var checks = 0
var fails = 0
var _texts: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	var same: float = _mean("nobody", "same", "plain", ["x"])
	var other: float = _mean("nobody", "other", "plain", ["x"])
	check(same > other + 0.08, "a vigil on the watched block that night counts against the report; one elsewhere doesn't (%+.3f vs %+.3f)" % [same, other])
	var lying: float = _mean("nobody", "same", "lying", ["x"])
	check(lying > 0.03, "the vigil can be the grounds of a lying challenge on the report (%+.3f)" % lying)
	var saw: float = _mean("saw_y", "same", "plain", ["x"])
	check(saw > other + 0.08, "a vigil that saw someone else go out is complete coverage: it counts against the report too (%+.3f)" % saw)
	var own_missing: float = _mean("nobody", "same", "plain", [])
	var own_seen: float = _mean("saw_nw", "same", "plain", [])
	print("INFO watcher's own walk: nobody-stirred vigil %+.3f, vigil that saw the watcher %+.3f" % [own_missing, own_seen])
	check(own_missing > own_seen + 0.05, "a watcher who saw nobody, on a block a vigil saw nobody reach, was never there: that counts against them (%+.3f vs %+.3f)" % [own_missing, own_seen])
	print("Vigil and Night Watch: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## The mean change in good listeners' suspicion of the Night Watch when the player follows
## the report with a case. `vigil`: "nobody" (nobody stirred), "saw_y" (saw someone else go
## out), "saw_nw" (saw the watcher). `where`: the watched block or another. `seen`: whom the
## report names ("x", or [] for nobody).
func _mean(vigil: String, where: String, mode: String, seen: Array) -> float:
	var total := 0.0
	var n := 0
	for sd in SEEDS:
		var d = _one(sd, vigil, where, mode, seen)
		if d != null:
			total += d
			n += 1
	return total / maxf(1.0, n)

func _one(sd: int, vigil: String, where: String, mode: String, seen_spec: Array):
	LiveActivity.cache.clear()
	Caches.clear_all()
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.detailed_logging = false
	g.new_case(sd, 10)
	var goods: Array = g.w.npcs.filter(func(p): return not p.is_evil())
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.credibility = 0.5
		for id in p.suspicion:
			p.suspicion[id] = 0.25
			p.npc_trust[id] = 1.0
	g.w.day = 2
	var nw = goods[0]
	var x = goods[1]
	var y = goods[2]
	var block: String = OS.get_environment("BLK")
	if block == "":
		block = "docks" if x.home_block != "docks" else "market"
	print("DBG seed %d block %s x_home %s nw_home %s" % [sd, block, x.home_block, nw.home_block])
	var vblock: String = block
	if where == "other":
		for b in ["docks", "market", "hill", "square"]:
			if b != block and b != x.home_block and b != nw.home_block:
				vblock = b
	var seen: Array = [x.id] if "x" in seen_spec else []
	var watch: int = _card(g, {"kind": "info", "source": nw.id, "role": "nightwatch", "day": 1, "phase": 3, "data": {"block": block, "seen": seen}})
	var vig: int
	if vigil == "nobody":
		vig = _card(g, {"kind": "vigil", "subject": [], "block": vblock, "source": "player", "day": 1, "phase": 3})
	else:
		var who = y if vigil == "saw_y" else nw
		vig = _card(g, {"kind": "sighting", "subject": [who.id], "block": vblock, "source": "player", "day": 1, "phase": 3, "vigil": true})
	var listeners: Array = g.w.npcs.filter(func(p): return p != nw and p != x and p != y and p.alive and not p.is_evil())
	var first: int = _file(g, "evil" if not seen.is_empty() else "good", x.id, [watch])
	_present(g, listeners, first)
	var before: float = _sus(listeners, nw)
	var second: int = _file(g, "evil", nw.id, [watch, vig]) if mode == "plain" else _file(g, "good", x.id, [vig], watch, mode, [vig])
	if second <= 0:
		return null
	_present(g, listeners, second)
	var dd: float = _sus(listeners, nw) - before
	print("DELTA seed %d %s/%s/%s block %s nw_home %s x_home %s: %+.3f" % [sd, vigil, where, mode, block, nw.home_block, x.home_block, dd])
	return dd

func _card(g, card: Dictionary) -> int:
	card["text"] = "%s %s night 1 %s" % [card.get("source", ""), card.get("kind", ""), JSON.stringify(card.get("data", card.get("subject", [])))] + str(_texts.size())
	var number: int = g.add_card(card)
	_texts[number] = g.board[number - 1].text
	return number

func _sus(listeners: Array, p) -> float:
	var s := 0.0
	for n in listeners:
		s += float(n.suspicion.get(p.id, 0.0))
	return s / maxf(1.0, listeners.size())

func _present(g, listeners: Array, number: int) -> void:
	if number <= 0:
		return
	for n in listeners:
		g._evaluate_deduction(n, g.board[number - 1], 1.0, false)

func _node(model, view, number: int) -> String:
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and Solver.card_by_id(view, nd.card).get("text", "") == str(_texts.get(number, "")):
			return id
	return ""

func _file(g, type: String, target: String, support: Array, challenged: int = 0, mode: String = "", grounds: Array = []) -> int:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(target, type, Vector2(400, 40))
	for number in support:
		model.connect_cards(_node(model, view, number), premise)
	if challenged > 0:
		model.add_modifier(_node(model, view, challenged), mode)
		var challenge: String = model.selected
		for number in grounds:
			model.connect_cards(_node(model, view, number), challenge)
		model.connect_cards(challenge, premise)
	var n: int = Live.file(g, model.compile(premise))
	if n <= 0:
		print("FILE FAILED: %s" % g.last_error)
	return n
