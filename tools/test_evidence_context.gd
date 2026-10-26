extends SceneTree
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Context = preload("res://ui/evidence_context.gd")
const CardList = preload("res://ui/card_list.gd")
const BoardView = preload("res://ui/board_view.gd")
const CaseState = preload("res://ui/case_state.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const CanvasView = preload("res://ui/workshop_canvas_view.gd")
var fails = 0
var checks = 0
func _init():
	call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", message)
func settle():
	for i in range(5):
		await process_frame
func run():
	root.size = Vector2i(1400, 900)
	root.content_scale_size = root.size
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://context_tests"
	g.new_case(4242, 10)
	g.w.day = 2
	var a = g.w.npcs[0]
	var b = g.w.npcs[1]
	var c = g.w.npcs[2]
	var location = g.add_card({"kind": "sighting", "source": "player", "subject": [a.id], "block": "square", "day": 2, "phase": C.MORNING, "text": "A public daytime sighting."})
	var night = g.add_card({"kind": "sighting", "source": "player", "subject": [a.id], "block": "square", "day": 1, "phase": C.NIGHT, "text": "A night sighting."})
	var psych = g.add_card({"kind": "info", "source": a.id, "subject": [b.id], "role": "psychologist", "day": 1, "data": {"subject": b.id, "trusts": a.id, "suspects": c.id}, "text": "A Psychologist reported public opinions."})
	var claim = g.add_card({"kind": "claim", "source": a.id, "subject": [a.id], "role": "seer", "text": "A claims Seer."})
	var opinion = g.add_card({"kind": "opinion", "source": a.id, "subject": [b.id], "text": "An unsupported opinion."})
	var original = JSON.stringify(g.board)
	var rng = g.w.rng.state
	var numbers = Context.numbers(g)
	check(numbers.has(location) and numbers.has(psych), "location and context adapter kinds are marked")
	check(not numbers.has(night) and not numbers.has(claim) and not numbers.has(opinion), "hard constraints and unsupported cards are not reclassified")
	check(Context.is_context({"kind": "location"}) and Context.is_context({"kind": "context"}) and not Context.is_context({"kind": "evening"}), "context classification uses the exact existing adapter kinds")
	var list = CardList.new()
	list.position = Vector2(820, 0)
	list.size = Vector2(560, 210)
	list.context_numbers = numbers
	root.add_child(list)
	var marked = list.add(CardList.line_for(g.board[psych - 1]), psych, "Original tooltip")
	var hard = list.add(CardList.line_for(g.board[claim - 1]), claim, "Claim tooltip")
	check(marked.get_text(0).begins_with("[context] ") and Context.EXPLANATION in marked.get_tooltip_text(0), "Card List rows have a context tag and explanation")
	check(not "[context]" in hard.get_text(0) and hard.get_tooltip_text(0) == "Claim tooltip", "hard-logic rows retain their text and tooltip")
	var state = CaseState.new()
	state.view = "statements"
	var board = BoardView.new()
	board.size = Vector2(800, 650)
	root.add_child(board)
	board.setup(g, state)
	board.fit_day(1)
	await settle()
	check(board.context_numbers == numbers, "board classification matches the library")
	check(list.get_node("ContextBorders").mouse_filter == Control.MOUSE_FILTER_IGNORE, "list borders preserve ordinary mouse hit targets")
	var cards: Array = board._items.filter(func(item): return item.n == psych)
	check(not cards.is_empty() and Context.EXPLANATION in board._get_tooltip(cards[0].rect.get_center()), "a drawn board card explains its context marker")
	state.view = "places"
	board.rebuild()
	board.fit_day(2)
	await settle()
	var dots: Array = board._items.filter(func(item): return item.n == location)
	check(not dots.is_empty() and Context.EXPLANATION in board._get_tooltip(dots[0].rect.get_center()), "a drawn location dot explains its context marker")
	var view = Context.Live.view(g)
	var model = Canvas.new(view)
	var id: String = Context.Live.Evidence.normalize_card(g.board[psych - 1]).id
	var node_id = "e:" + id
	var node: Dictionary = model.nodes[node_id]
	node.at = [20, 20]
	model.nodes = {node_id: node}
	model.selected = node_id
	var canvas = CanvasView.new()
	canvas.position = Vector2(820, 230)
	canvas.size = Vector2(560, 600)
	canvas.model = model
	root.add_child(canvas)
	await settle()
	check(canvas.hit.has(node_id), "Workshop context evidence is actually drawn")
	check(Context.EXPLANATION in canvas._get_tooltip(canvas.hit[node_id].get_center()), "Workshop context cards explain their marker throughout the card")
	check(JSON.stringify(g.board) == original and g.w.rng.state == rng, "context rendering leaves evidence and simulation randomness untouched")
	var args = OS.get_cmdline_user_args()
	if "--screenshot" in args:
		var index = args.find("--screenshot")
		root.get_texture().get_image().save_png(args[index + 1])
	board.free()
	list.free()
	canvas.free()
	print("Context UI: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
