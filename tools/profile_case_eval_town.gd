## Whole-town timing for CaseEval on the same native ten-person setup as
## profile_workshop_town.gd: every native reading filed as one case, then evaluated for
## every living listener. Reports, for the town (all living listeners but the accused):
##   first case    everything cold: universe setup, each reading's tables, the case
##   new case      a different premise over a subset of the same readings: the cost of a
##                 presentation once its readings' tables exist (built when they arrive)
##   repeat        the same case again (everything cached)
##   godot --headless --path . --script res://tools/profile_case_eval_town.gd -- --seed 692 [--allow-fallback]
## Exits with failure if any listener's case wasn't ready (not evaluated): those listeners
## add no cost, so the timing would understate the town. --allow-fallback only reports it.
extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")

var g
var seed_value = 692
var not_ready: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _file(numbers: Array, target_id: String) -> int:
	var board = Canvas.new(Live.view(g))
	var root_id: String = board.selected
	board.nodes[root_id].conclusion.target = target_id
	for number in numbers:
		board.connect_cards("e:" + Evidence.normalize_card(g.board[number - 1]).id, root_id)
	return Live.file(g, board.compile(root_id))

## Evaluates the filed case for every listener; returns [prepare ms, evaluate ms, rows].
func _town(number: int, listeners: Array) -> Array:
	var capture_us = 0
	var eval_us = 0
	var rows: Array = []
	for n in listeners:
		var t0 = Time.get_ticks_usec()
		var prepared = Assess.prepare(g.workshop_snapshot([number], n.id, "meeting"), false)
		capture_us += Time.get_ticks_usec() - t0
		if not prepared.ready:
			rows.append("  %s: not ready (%s)" % [n.id, "; ".join(PackedStringArray(prepared.issues))])
			not_ready.append(n.id)
			continue
		t0 = Time.get_ticks_usec()
		var r = CaseEval.evaluate(prepared.view, prepared.case, prepared.listener)
		eval_us += Time.get_ticks_usec() - t0
		rows.append("  %-9s %.2f -> %.2f  %-11s rivals %s" % [n.id, r.prior, r.posterior, r.category,
			", ".join(PackedStringArray(r.rivals.map(func(x): return "%s %.2f" % [x.id, x.posterior])))])
	return [capture_us / 1000.0, eval_us / 1000.0, rows]

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	if "--seed" in args:
		seed_value = int(args[args.find("--seed") + 1])
	g = Game.new()
	g.new_case(seed_value, 10)
	g.w.dlog.detailed = false
	g.w._day_gifts()
	var reports: Array = []
	for person in g.w.npcs:
		for reading in person.info_log:
			if reading.role in Live.Assess.ROLES:
				reports.append(g.add_card({"kind": "info", "source": person.id, "subject": [], "role": reading.role,
					"day": reading.day, "phase": reading.get("phase", 3 if reading.day == 0 else 0),
					"data": reading.data, "text": "Native %s: %s" % [reading.role, reading.text]}))
	var target = g.w.living_good()[0]
	var number = _file(reports, target.id)
	var listeners: Array = g.w.living().filter(func(n): return n != target)
	print("CaseEval town, seed %d: %d readings, premise '%s is evil', %d listeners" % [seed_value, reports.size(), target.id, listeners.size()])
	var first = _town(number, listeners)
	for row in first[2]:
		print(row)
	var worlds = 0
	var probe = Assess.prepare(g.workshop_snapshot([number], listeners[0].id, "meeting"), false)
	if probe.ready:
		worlds = Solver.universe(probe.view).size()
	# A different premise over most of the same readings.
	var other = g.w.living_good()[1] if g.w.living_good().size() > 1 else target
	var subset: Array = reports.slice(0, maxi(1, reports.size() - 1))
	var second_number = _file(subset, other.id)
	var second = _town(second_number, g.w.living().filter(func(n): return n != other))
	var repeat = _town(second_number, g.w.living().filter(func(n): return n != other))
	print("first case (all cold):        prepare %.0f ms, evaluation %.0f ms, %d worlds" % [first[0], first[1], worlds])
	print("new case, readings known:     prepare %.0f ms, evaluation %.0f ms ('%s is evil', %d readings)" % [second[0], second[1], other.id, subset.size()])
	print("repeat:                       prepare %.0f ms, evaluation %.0f ms" % [repeat[0], repeat[1]])
	if not not_ready.is_empty():
		print("%s: listeners not evaluated, so these timings skip their work: %s" % ["WARNING" if "--allow-fallback" in args else "FAIL", not_ready])
		quit(0 if "--allow-fallback" in args else 1)
		return
	quit()
