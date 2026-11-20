## A live town presentation through the real game path (shared effects on): every native
## reading filed as one case and presented to every living listener at a meeting. Reports
## how many listeners used the shared assessment, why the rest weren't assessed, the
## wall time, and the slowest profiled stages.
##   godot --headless --path . --script res://tools/profile_live_presentation.gd -- [--seed N] [--allow-fallback]
## Exits with failure if any listener wasn't assessed: a timing that silently skips the
## shared evaluator measures less work. --allow-fallback reports it without failing.
extends SceneTree
const GamePresentation = preload("res://game/game_presentation.gd")
const GameBoard = preload("res://game/game_board.gd")
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Jury = preload("res://workshop/jury.gd")
const Prof = preload("res://workshop/profiler.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var seeds: Array = [692, 4242, 1234, 77]
	var fell_back: Array = []
	if "--seed" in args:
		seeds = [int(args[args.find("--seed") + 1])]
	for seed_value in seeds:
		var g = Game.new()
		g.new_case(seed_value, 10)
		g.w.dlog.detailed = false
		g.w._day_gifts()
		var reports: Array = []
		for person in g.w.npcs:
			for reading in person.info_log:
				if reading.role in Live.Assess.ROLES:
					reports.append(GameBoard.add_card(g, {"kind": "info", "source": person.id, "subject": [], "role": reading.role,
						"day": reading.day, "phase": reading.get("phase", 3 if reading.day == 0 else 0), "data": reading.data, "text": "Native reading"}))
		var board = Canvas.new(Live.view(g))
		var root_id: String = board.selected
		var target = g.w.living_good()[0]
		board.nodes[root_id].conclusion.target = target.id
		for number in reports:
			board.connect_cards("e:" + Evidence.normalize_card(g.board[number - 1]).id, root_id)
		var number = Live.file(g, board.compile(root_id))
		var shared = 0
		var unassessed: Array = []
		var why = {}
		Prof.start()
		var t0 = Time.get_ticks_msec()
		for n in g.w.living().filter(func(x): return x != target):
			var r = GamePresentation._evaluate_deduction(g, n, g.board[number - 1], 1.0, false, "meeting")
			if r.get("workshop", false):
				shared += 1
			else:
				unassessed.append(n.id)
				for issue in n.workshop_state.get("issues", []):
					var kind: String = issue.get_slice(":", 0)
					why[kind] = why.get(kind, 0) + 1
		var elapsed = Time.get_ticks_msec() - t0
		var rep = Prof.finish()
		var stages = {}
		for row in rep.rows:
			stages[row.stage] = stages.get(row.stage, 0) + row.self_us
		var keys = stages.keys()
		keys.sort_custom(func(a, b): return stages[a] > stages[b])
		print("seed %d: %d readings; %d shared, %d unassessed %s; %d ms" % [seed_value, reports.size(), shared, unassessed.size(), unassessed, elapsed])
		if not unassessed.is_empty():
			fell_back.append("seed %d: %s" % [seed_value, unassessed])
		for kind in why:
			print("  unassessed because: %s (%d)" % [kind, why[kind]])
		print("  slowest: " + ", ".join(PackedStringArray(keys.slice(0, 4).map(func(k): return "%s %.0f ms" % [k, stages[k] / 1000.0]))))
	if not fell_back.is_empty():
		print("%s: listeners weren't assessed, so these timings skip their work: %s" % ["WARNING" if "--allow-fallback" in args else "FAIL", "; ".join(PackedStringArray(fell_back))])
		quit(0 if "--allow-fallback" in args else 1)
		return
	quit()
