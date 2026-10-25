## Original playtest opening through case #85's first vote. Measurements, not tuning.
## godot --headless --path . --script res://tools/replay_54875.gd [-- --allow-fallback]
## --stage day3-four | day4-six selects an original recorded late continuation.
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
	var args = OS.get_cmdline_user_args()
	var stage: String = args[args.find("--stage") + 1] if "--stage" in args and args.find("--stage") + 1 < args.size() else "opening"
	var late: Array = fixture.get("late_stages", []).filter(func(v): return v.id == stage)
	if stage != "opening" and late.is_empty():
		print("FAIL: unknown replay stage ", stage)
		quit(1)
		return
	var actions: Array = fixture.actions.duplicate(true)
	if not late.is_empty():
		actions.append_array(late[0].actions)
	var g = Game.new()
	g.log_dir = "res://logs/migration/replay_54875"
	g.detailed_logging = true
	g.new_case(int(fixture.seed), int(fixture.npcs))
	var filed = 0
	var presentation = []
	var errors = []
	var commands = []
	var profile = {}
	var filed_versions: Array = []
	var profiles = {}
	var continuation_steps = []
	while not actions.is_empty():
		var action: Dictionary = actions.pop_front()
		if action.has("file_case"):
			if action.has("checkpoint_recovery") and g.w.day == action.expected_day and g.state == "day":
				var recovery: Array = action.checkpoint_recovery
				action.erase("checkpoint_recovery")
				actions.push_front(action)
				for index in range(recovery.size() - 1, -1, -1):
					actions.push_front({"command": recovery[index]})
				continuation_steps.append({"day": g.w.day, "state": g.state, "commands": recovery, "reason": "Recorded conversation unavailable; repeat the recorded evening visit at its filing checkpoint."})
				continue
			var value: Dictionary = action.file_case.duplicate(true)
			if action.has("expected_day") and (g.w.day != action.expected_day or g.state != "meeting"):
				errors.append("Recorded filing checkpoint drifted: expected day %d meeting, got day %d %s" % [action.expected_day, g.w.day, g.state])
				break
			var previous_version: int = filed if action.get("revise", false) else 0
			filed = Canvas.file(g, value, previous_version)
			filed_versions.append({"day": g.w.day, "number": filed, "previous": previous_version, "reports": value.cards.size(), "facts": value.cards.duplicate()})
			if filed < 1:
				errors.append("Cannot file original case #85: " + g.last_error)
				break
			continue
		var command: String = action.command
		# Later native nominations can differ from the historical build. Finish
		# those public votes with the recorded player's default no, and retain
		# every added step in the measurement rather than forcing night/state.
		if command == "done" and not late.is_empty() and late[0].get("settle_extra_nominations", false) and (g.state == "nomination" or (g.state == "meeting" and not g.town_quiet)):
			if continuation_steps.size() >= 100:
				errors.append("Extra nomination continuation exceeded its guard.")
				break
			var extra: String = "vote no" if g.state == "nomination" else "wait"
			continuation_steps.append({"day": g.w.day, "state": g.state, "command": extra, "before_original_seq": action.get("original_seq", 0)})
			actions.push_front(action)
			actions.push_front({"command": extra})
			continue
		if action.has("card_spec"):
			var spec: Dictionary = action.card_spec
			var originals: Array = g.board.filter(func(card): return spec.keys().all(func(key): return card.get(key) == spec[key]))
			if originals.size() != 1:
				errors.append("Recorded public receipt is absent or ambiguous for " + command + ": " + JSON.stringify(spec))
				break
			var words: PackedStringArray = command.split(" ")
			words[1] = str(originals[0].n)
			command = " ".join(words)
		if action.has("card_fact"):
			var originals: Array = g.board.filter(func(c): return Evidence.normalize_card(c).id == action.card_fact)
			if originals.is_empty():
				errors.append("Original evidence is absent for " + command)
				break
			var words: PackedStringArray = command.split(" ")
			words[1] = str(originals[0].n)
			command = " ".join(words)
		var parts: PackedStringArray = command.split(" ", false)
		if parts.size() >= 2 and parts[0] == "present" and parts[1] == "85":
			parts[1] = str(filed)
			command = " ".join(parts)
		var presents_case: bool = parts.size() >= 2 and parts[0] == "present" and parts[1] == str(filed)
		var previous = g.workshop_deliveries.size()
		var before: String = g.state
		var started = Time.get_ticks_msec()
		if presents_case:
			Profiler.start()
		var reply = g.command(command)
		if presents_case:
			profile = Profiler.finish()
			profiles[str(g.w.day)] = profile
		print("%s: %s -> %s (%d ms)" % [command, before, g.state, Time.get_ticks_msec() - started])
		commands.append({"command": command, "before": before, "after": g.state, "day": g.w.day, "phase": g.w.phase, "original_seq": action.get("original_seq", 0), "elapsed_ms": Time.get_ticks_msec() - started, "output": reply})
		if presents_case:
			for delivery in g.workshop_deliveries.slice(previous):
				var real = g.w.by_id[delivery.listener]
				var n = real.shadow if real.is_evil() else real
				var response: Dictionary = g._workshop_responses.get(real.id + (":cover" if real.is_evil() else ":good"), {}).get("assessment", {})
				var reasoning: Dictionary = response.get("reasoning", {})
				presentation.append({"day": g.w.day, "filed": filed, "listener": real.id, "model": delivery.model, "issues": delivery.issues,
					"suspicion": Mind.susp(n, "constance") if n != null else null,
					"considered": reasoning.get("considered", []), "ignored": reasoning.get("ignored", []),
					"held_facts": n.workshop_state.get("facts", []).size() if n != null else 0,
					"belief_ignored": n.workshop_state.get("reasoning", {}).get("ignored", []) if n != null else [],
					"belief_considered": n.workshop_state.get("reasoning", {}).get("considered", []) if n != null else []})
	if not late.is_empty() and (filed_versions.is_empty() or filed_versions[-1].day != late[0].day or filed_versions[-1].reports != late[0].reports):
		errors.append("The requested late case version was not reached.")
	var trace = g.w.dlog.trace_events()
	var agreement = []
	var margins = []
	for event in trace:
		if event.type == "workshop_presentation":
			agreement.append({"day": event.day, "listener": event.actor, "agreement": event.data.agreement, "stance": event.data.stance})
		if event.type == "decision" and event.data.kind == "vote" and event.data.stage == "evaluation" and event.target == "constance":
			margins.append({"day": event.day, "listener": event.actor, "stream": event.stream, "yes": event.data.result,
				"margin": event.data.details.margin, "score": event.data.details.score, "need": event.data.details.threshold})
	var tallies: Array = g.w.dlog.entries.filter(func(e): return e.type == "vote_tally" and e.target == "constance")
	var result = {"seed": 54875, "npcs": 10, "scope": fixture.scope if late.is_empty() else late[0].scope, "stage": stage, "continuation_steps": continuation_steps, "filed_versions": filed_versions, "profiles": profiles, "errors": errors, "commands": commands,
		"outcome": {"day": g.w.day, "state": g.state, "winner": g.w.winner, "reason": g.w.end_reason}, "filed_number": filed, "presentation": presentation, "agreement": agreement, "vote_margins": margins, "profile": profile,
		"tallies": tallies, "legacy_fallbacks": g.shared_fallbacks.duplicate(true), "fallbacks": trace.filter(func(e): return e.type == "workshop_fallback")}
	var refreshes: Array = trace.filter(func(e): return e.type == "workshop_ownership")
	result["refreshes"] = refreshes.size()
	result["impossible_refreshes"] = refreshes.filter(func(e): return e.data.get("reasoning", {}).get("impossible", false))
	if not result.impossible_refreshes.is_empty():
		errors.append("impossible belief refresh")
	var native: Array = presentation.filter(func(d): return d.model != "shared").map(func(d): return d.listener)
	if not native.is_empty() or not result.fallbacks.is_empty() or not result.legacy_fallbacks.is_empty():
		var allowed: bool = "--allow-fallback" in OS.get_cmdline_user_args()
		print("%s: shared evaluation incomplete (native listeners %s; %d fallback events). The timing skips their work." % ["WARNING" if allowed else "FAIL", native, result.fallbacks.size() + result.legacy_fallbacks.size()])
		if not allowed:
			errors.append("fallback")
	DirAccess.make_dir_recursive_absolute("res://logs/migration/replay_54875")
	var out = FileAccess.open("res://logs/migration/replay_54875/measurement.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(result, "\t"))
	print("54875 replay: filed #%d; %d shared, %d native; %d vote tallies; errors %s" % [filed,
		presentation.filter(func(d): return d.model == "shared").size(), presentation.filter(func(d): return d.model == "legacy").size(), tallies.size(), errors])
	for tally in tallies:
		print("Case #85 day %d vote: %d yes / %d needed; %s" % [tally.day, tally.data.count, tally.data.threshold, tally.data.outcome])
	print("Measurement: logs/migration/replay_54875/measurement.json")
	quit(1 if not errors.is_empty() or presentation.is_empty() else 0)
