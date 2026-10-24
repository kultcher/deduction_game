## Reproducible native-game floor benchmark. Profiling begins after meeting setup.
extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Profile = preload("res://workshop/profiler.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
var result: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	preload("res://workshop/role_constraints.gd").reuse = "--no-role-cache" not in args
	preload("res://workshop/support_model.gd").reuse_priors = "--no-prior-cache" not in args
	preload("res://workshop/support_model.gd").reuse_comparisons = "--no-comparison-reuse" not in args
	preload("res://workshop/reasoner.gd").reuse_matches = "--no-match-cache" not in args
	preload("res://workshop/support_model.gd").reuse_batches = "--no-batch-reuse" not in args
	var seed_value = 692
	if "--seed" in args:
		seed_value = int(args[args.find("--seed") + 1])
	var g = Game.new()
	g.new_case(seed_value, 10)
	if "--reference-cognition" in args:
		for person in g.w.npcs:
			person.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
			if person.shadow != null:
				person.shadow.workshop_state = person.workshop_state.duplicate(true)
	g.w.dlog.detailed = false
	g.w._day_gifts()
	var reports: Array = []
	for person in g.w.npcs:
		for reading in person.info_log:
			if reading.role in Live.Assess.ROLES:
				reports.append(g.add_card({"kind": "info", "source": person.id, "subject": [], "role": reading.role,
					"day": reading.day, "phase": reading.get("phase", 3 if reading.day == 0 else 0),
					"data": reading.data, "text": "Native %s: %s" % [reading.role, reading.text]}))
	var board = Canvas.new(Live.view(g))
	var root_id: String = board.selected
	var target = g.w.living_good()[0]
	var listener = g.w.living_good().filter(func(n): return n != target)[0]
	board.nodes[root_id].conclusion.target = target.id
	for number in reports:
		board.connect_cards("e:" + Evidence.normalize_card(g.board[number - 1]).id, root_id)
	var number = Live.file(g, board.compile(root_id))
	assert(number > 0)
	g.set_workshop_effects(true)
	g.state = "talk"
	g.talk_with = listener
	g.questions_left = 3
	g.command("convince %d" % number)
	g.command("bye")
	g.w.phase = 2
	g._start_meeting()
	g.workshop_deliveries.clear()
	var before_rng: int = g.w.rng.state
	print("Profiling native ten-person town, seed %d, %d presented reports" % [seed_value, reports.size()])
	Profile.start()
	var town_span = Profile.open("town")
	var output = await g.workshop_command("present %d" % number, func(_name): await process_frame)
	Profile.close(town_span)
	result = Profile.finish()
	result["seed"] = seed_value
	result["cognition"] = "full/scale reference" if "--reference-cognition" in args else "native bounded/persistence"
	result["reports"] = reports.size()
	result["optimizations"] = {"priors": preload("res://workshop/support_model.gd").reuse_priors,
		"comparisons": preload("res://workshop/support_model.gd").reuse_comparisons,
		"candidate_checks": preload("res://workshop/reasoner.gd").reuse_matches,
		"mixture_plans": preload("res://workshop/support_model.gd").reuse_batches}
	result["deliveries"] = g.workshop_deliveries.duplicate(true)
	result["output"] = output
	result["rng_before"] = str(before_rng)
	result["rng_after"] = str(g.w.rng.state)
	result["behavior"] = _behavior(g)
	result["behavior_hash"] = JSON.stringify(Evidence.canonical(result.behavior)).sha256_text()
	var totals = {}
	for row in result.rows:
		if row.stage == "listener":
			print("  %s: %.2f ms" % [row.listener, row.total_us / 1000.0])
		if not totals.has(row.stage):
			totals[row.stage] = {"calls": 0, "total_us": 0, "self_us": 0}
		for field in ["calls", "total_us", "self_us"]:
			totals[row.stage][field] += row[field]
	result["stages"] = totals
	print("Stage totals: ", JSON.stringify(totals))
	print("Town: %.2f ms; behavior %s" % [result.elapsed_us / 1000.0, result.behavior_hash])
	# A listener on native rules does none of the shared work, so the timing would
	# understate the town. Fail unless explicitly allowed.
	var fallbacks: Array = result.deliveries.filter(func(d): return d.get("model", "") != "shared").map(func(d): return d.get("listener", "?"))
	result["fallback_listeners"] = fallbacks
	var path = "res://logs/workshop_profile.json"
	if "--output" in args:
		path = args[args.find("--output") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	if not fallbacks.is_empty():
		print("%s: listeners used native rules, so this timing skips shared work: %s" % ["WARNING" if "--allow-fallback" in args else "FAIL", fallbacks])
		quit(0 if "--allow-fallback" in args else 1)
		return
	quit()

func _behavior(g) -> Dictionary:
	var people = {}
	for n in g.w.npcs:
		people[n.id] = _mind(n)
		if n.shadow != null:
			people[n.id]["cover"] = _mind(n.shadow)
	return {"people": people, "output": g.render(g.last_events), "deliveries": g.workshop_deliveries,
		"rng": str(g.w.rng.state), "state": g.state, "presented": g.presented_today}

func _mind(n) -> Dictionary:
	var value = {}
	for field in ["suspicion", "trust", "npc_trust", "discounted", "honesty", "ledger", "pressure", "believed_roles", "used_facts", "heard", "dialogue_memory"]:
		value[field] = n.get(field)
	var state: Dictionary = n.workshop_state.duplicate(true)
	for field in ["elapsed_ms", "cache_hit"]:
		state.erase(field)
	value["workshop_state"] = state
	return value
