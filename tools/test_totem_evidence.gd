## A found totem as Workshop evidence (Nov 20; BACKLOG "Workshop gaps: Minion gifts", playtest
## 54875's note): searching where the Revenant's totem is hidden puts a card on the board, the
## judge reads it as "one of the people living where its material is from is the Revenant"
## (LiveAssessment's `totem` adapter, RoleConstraints), and a case citing it argues against a
## resident more than against someone who lives elsewhere.
##   godot --headless --path . --script res://tools/test_totem_evidence.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const GameDayNight = preload("res://game/game_day_night.gd")
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


func _init() -> void:
	var f: Dictionary = _deal()
	check(not f.is_empty(), "(fixture) a 10-person deal with a Revenant and someone living on another block")
	if not f.is_empty():
		_found_totem(f)
	print("Totem evidence: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _found_totem(f: Dictionary) -> void:
	var g = f.g
	var rv = f.revenant
	var l: String = "well"
	g.w.totem = {"loc": l, "day": g.w.day, "owner": rv.id, "material": rv.home_block}
	g.loc = l
	g.moved = true
	var before: int = g.board.size()
	GameDayNight._search(g)
	var found: Array = g.board.slice(before).filter(func(c): return str(c.get("kind", "")) == "totem")
	check(found.size() == 1 and str(found[0].get("block", "")) == rv.home_block, "the search puts the totem on the board, caked with the Revenant's home material")
	if found.is_empty():
		return
	var view: Dictionary = Live.view(g)
	var cards: Array = view.cards.filter(func(c): return str(c.get("kind", "")) == "totem")
	var residents: Array = g.w.npcs.filter(func(n): return n.home_block == rv.home_block).map(func(n): return n.id)
	residents.sort()
	var named: Array = cards[0].get("data", {}).get("candidates", []).duplicate() if not cards.is_empty() else []
	named.sort()
	check(cards.size() == 1 and named == residents and rv.id in named, "the judge reads it as one of the people living there (%s)" % str(named))
	var on_block: Dictionary = Live.shape_reading(g, _case(g, rv.id, "evil", [found[0].n]))
	var off_block: Dictionary = Live.shape_reading(g, _case(g, f.outsider.id, "evil", [found[0].n]))
	check(on_block.get("ready", false) and off_block.get("ready", false) and float(on_block.lr) > float(off_block.lr),
		"a case citing it argues against a resident more than against someone from elsewhere (x%.2f against x%.2f)" % [float(on_block.get("lr", 0.0)), float(off_block.get("lr", 0.0))])


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


## A 10-person deal with a Revenant among the Minions and a good townsperson living elsewhere.
func _deal() -> Dictionary:
	for sd in range(1, 200):
		var g = Game.new()
		g.detailed_logging = false
		g.log_dir = "user://test_logs"
		g.new_case(sd, 10)
		if g.state == "approach":
			g.command("decline")
		var rvs: Array = g.w.npcs.filter(func(n): return n.role == "revenant" and n.alive)
		if rvs.is_empty():
			continue
		var outsiders: Array = g.w.living_good().filter(func(n): return n.home_block != rvs[0].home_block)
		if outsiders.is_empty():
			continue
		g.w.day = 2
		return {"g": g, "revenant": rvs[0], "outsider": outsiders[0]}
	return {}
