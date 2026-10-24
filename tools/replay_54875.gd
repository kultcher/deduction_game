## Original playtest opening through case #85's first vote. Measurements, not tuning.
## godot --headless --path . --script res://tools/replay_54875.gd [-- --allow-fallback]
## Also the Day 2 performance check: fails if any listener of case #85 used native rules
## or any workshop_fallback event fired, unless --allow-fallback is given.
extends SceneTree
const Game = preload("res://game/game.gd")
const Canvas = preload("res://game/workshop_canvas.gd")
const Mind = preload("res://sim/mind.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Profiler = preload("res://workshop/profiler.gd")

func _init() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/playtest_54875_opening.json"))
	var g = Game.new()
	g.log_dir = "res://logs/migration/replay_54875"
	g.detailed_logging = true
	g.new_case(int(fixture.seed), int(fixture.npcs))
	var filed = 0
	var presentation = []
	var errors = []
	var commands = []
	var profile = {}
	for action in fixture.actions:
		if action.has("file_case"):
			var value: Dictionary = action.file_case.duplicate(true)
			filed = Canvas.file(g, value)
			if filed < 1:
				errors.append("Cannot file original case #85: " + g.last_error)
				break
			continue
		var command: String = action.command
		if action.has("card_fact"):
			var originals: Array = g.board.filter(func(c): return Evidence.normalize_card(c).id == action.card_fact)
			if originals.is_empty():
				errors.append("Original evidence is absent for " + command)
				break
			command = "present %d" % originals[0].n
		if command == "present 85":
			command = "present %d" % filed
		var previous = g.workshop_deliveries.size()
		var before: String = g.state
		var started = Time.get_ticks_msec()
		if command == "present %d" % filed:
			Profiler.start()
		var reply = g.command(command)
		if command == "present %d" % filed:
			profile = Profiler.finish()
		print("%s: %s -> %s (%d ms)" % [command, before, g.state, Time.get_ticks_msec() - started])
		commands.append({"command": command, "before": before, "after": g.state, "day": g.w.day, "phase": g.w.phase, "elapsed_ms": Time.get_ticks_msec() - started, "output": reply})
		if command == "present %d" % filed:
			for delivery in g.workshop_deliveries.slice(previous):
				var real = g.w.by_id[delivery.listener]
				var n = real.shadow if real.is_evil() else real
				presentation.append({"listener": real.id, "model": delivery.model, "issues": delivery.issues,
					"suspicion": Mind.susp(n, "constance") if n != null else null})
	var trace = g.w.dlog.trace_events()
	var agreement = []
	var margins = []
	for event in trace:
		if event.type == "workshop_presentation":
			agreement.append({"listener": event.actor, "agreement": event.data.agreement, "stance": event.data.stance})
		if event.type == "decision" and event.data.kind == "vote" and event.data.stage == "evaluation" and event.target == "constance":
			margins.append({"listener": event.actor, "stream": event.stream, "yes": event.data.result,
				"margin": event.data.details.margin, "score": event.data.details.score, "need": event.data.details.threshold})
	var tallies: Array = g.w.dlog.entries.filter(func(e): return e.type == "vote_tally" and e.target == "constance")
	var result = {"seed": 54875, "npcs": 10, "scope": fixture.scope, "errors": errors, "commands": commands,
		"filed_number": filed, "presentation": presentation, "agreement": agreement, "vote_margins": margins, "profile": profile,
		"tallies": tallies, "fallbacks": trace.filter(func(e): return e.type == "workshop_fallback")}
	DirAccess.make_dir_recursive_absolute("res://logs/migration/replay_54875")
	var out = FileAccess.open("res://logs/migration/replay_54875/measurement.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(result, "\t"))
	print("54875 replay: filed #%d; %d shared, %d native; %d vote tallies; errors %s" % [filed,
		presentation.filter(func(d): return d.model == "shared").size(), presentation.filter(func(d): return d.model == "legacy").size(), tallies.size(), errors])
	for tally in tallies:
		print("Case #85 vote: %d yes / %d needed; %s" % [tally.data.count, tally.data.threshold, tally.data.outcome])
	print("Measurement: logs/migration/replay_54875/measurement.json")
	var native: Array = presentation.filter(func(d): return d.model != "shared").map(func(d): return d.listener)
	if not native.is_empty() or not result.fallbacks.is_empty():
		var allowed: bool = "--allow-fallback" in OS.get_cmdline_user_args()
		print("%s: shared evaluation incomplete (native listeners %s; %d fallback events). The timing skips their work." % ["WARNING" if allowed else "FAIL", native, result.fallbacks.size()])
		if not allowed:
			errors.append("fallback")
	quit(1 if not errors.is_empty() or presentation.is_empty() else 0)
