## Observational debug capture: analytical chances, UI controls and gameplay/RNG parity.
extends SceneTree
const Feed = preload("res://sim/decision_feed.gd")
const World = preload("res://sim/world.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const DevLog = preload("res://sim/devlog.gd")
const C = preload("res://sim/content.gd")
const RollWindow = preload("res://ui/decision_window.gd")
var failures = 0
var checks = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.000001

func _init() -> void:
	_math()
	_capture()
	_draws()
	await _window()
	await _main_ui()
	await _parity()
	_batch4_decisions()
	print("DECISION INSPECTOR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _math() -> void:
	_check(Feed.estimate({"probability": -0.1}, false).chance == 0 and Feed.estimate({"probability": 1.2}, true).chance == 1, "probability display clamps impossible cutoffs")
	_check(_near(Feed.estimate({"probability": Mind.sigmoid(0.5 * 4)}, true).chance, 0.880797078), "weighted checks display their sigmoid probability without rounding it first")
	var d = {"openness": 0.55, "parts": {"jitter": 0.1}, "jitter_min": -0.2, "jitter_max": 0.2, "thresholds": [{"above": 0.75, "tier": 4}, {"above": 0.45, "tier": 3}, {"above": 0.15, "tier": 2}]}
	var e: Dictionary = Feed.estimate(d, 3)
	_check(_near(e.chances[0], 0) and _near(e.chances[1], 0.5) and _near(e.chances[2], 0.5) and _near(e.chances[3], 0), "uniform disclosure jitter integrates all four tier bands")
	d.thresholds = [{"above": 0.6, "tier": 4}, {"above": 0.4, "tier": 3}, {"above": 0.3, "tier": 2}]
	e = Feed.estimate(d, 3)
	_check(_near(e.chances[0], 0.125) and _near(e.chances[1], 0.25) and _near(e.chances[2], 0.5) and _near(e.chances[3], 0.125), "tier display uses supplied thresholds and sums to one")
	_check(_near(Feed.estimate({"weights": {"a": 2, "b": 3, "none": 1}, "selected": "b"}, "b").chance, 0.5), "weighted choice includes the no-selection weight")
	_check(_near(Feed.estimate({"score": 0.5, "noise": 0.1, "noise_min": 0.0, "noise_max": 0.2, "threshold": 0.45}, true).chance, 0.75), "conditional target jitter chance integrates its interval")
	_check(Feed.estimate({"score": 0.6, "threshold": 0.45}, true).type == "deterministic", "deterministic score comparisons have no invented RNG chance")
	_check("fixed" in Feed.estimate({"mechanism": "fixed daily sample", "probability": 0.3}, false).label, "daily hashed checks are identified as fixed rather than fresh rolls")

func _emit(f, actor: String = "a", source: String = "real", kind: String = "question") -> void:
	f.observe(actor, kind, "roll", true, {"probability": 0.7, "draw": 0.2, "threshold": 0.7, "inputs": {"trust": 0.6}}, "b", source, 2, "Morning")

func _capture() -> void:
	var f = Feed.new()
	var calls = [0]
	f.resolve_actor = func(id, _stream):
		calls[0] += 1
		return {"name": "NPC " + id, "stats": {"trust": 0.6}}
	_emit(f)
	_check(f.records.is_empty() and calls[0] == 0, "disabled capture does not resolve or retain NPC data")
	f.enabled = true
	f.begin_action("command", {"cmd": "ask gift"})
	var d = {"probability": 0.6, "inputs": {"trust": 0.6}, "nested": {"value": 1}}
	var result = ["original"]
	f.observe("a", "gift", "roll", result, d, "b", "real", 2, "Morning")
	d.inputs.trust = 0.9
	d.nested.value = 2
	result[0] = "changed"
	var row: Dictionary = f.records[0]
	_check(row.name == "NPC a" and row.trigger == "ask gift" and row.action_id == 1 and row.day == 2 and row.target == "b", "records identify the NPC, trigger, action and time")
	_check(row.stats.trust == 0.6 and row.details.nested.value == 1 and row.result == ["original"], "records retain immutable values after game data changes")
	_emit(f, "a", "shadow")
	_check(f.records[-1].stream == "shadow" and "GOOD-SELF" in Feed.format_record(f.records[-1]), "hypothetical good-self records are explicitly labelled")
	for i in range(Feed.LIMIT + 10): _emit(f)
	_check(f.records.size() == Feed.LIMIT and f.records[0].seq > 1, "capture evicts oldest records at the 1000-row bound")
	var seq: int = f.next_sequence
	f.clear()
	_emit(f)
	_check(f.records.size() == 1 and f.records[0].seq == seq + 1, "clear removes history without reusing selected-row identities")

func _draws() -> void:
	var w = World.new()
	var f = Feed.new()
	f.enabled = true
	w.attach_decision_feed(f)
	w.rng.seed = 8675309
	var control = RandomNumberGenerator.new()
	control.state = w.rng.state
	for comparison in ["<", "<="]:
		for p in [-0.1, 0.0, 0.43, 1.0, 1.1]:
			var draw = control.randf()
			var expected: bool = draw <= p if comparison == "<=" else draw < p
			_check(w.decision_roll(null, "sample", p, {}, "", comparison) == expected and w.rng.state == control.state and f.records[-1].details.draw == draw, "single original sample/comparison retained: %s %.2f" % [comparison, p])
	var at_equality = w.rng.state
	var exact_cutoff = control.randf()
	_check(not w.decision_roll(null, "strict_edge", exact_cutoff), "strict comparison rejects an equal sampled cutoff")
	w.rng.state = at_equality
	_check(w.decision_roll(null, "inclusive_edge", exact_cutoff, {}, "", "<="), "inclusive comparison accepts the same equal sampled cutoff")
	var options = ["alpha", "beta", "gamma"]
	var expected = options[control.randi_range(0, options.size() - 1)]
	_check(w.decision_pick(null, "choice", options) == expected and w.rng.state == control.state, "uniform option capture consumes exactly the original integer draw")
	var state = w.rng.state
	_check(w.decision_pick(null, "empty", []) == null and w.rng.state == state, "empty choice does not invent a random draw")
	w.observe_ranked(null, "sole_target", {"a": {"score": 0.1, "noise": 0.1}}, "a", 0.3)
	_check(not f.records[-1].details.has("threshold") and "only eligible" in f.records[-1].details.gate, "single target is reported without an infinite or fake threshold")
	var weak_world = weakref(w)
	w = null
	_check(weak_world.get_ref() == null, "retaining captured records does not keep the world alive")
	_emit(f)
	_check(f.records[-1].actor == "a", "value-only capture remains safe after the observed world is freed")


func _window() -> void:
	var f = Feed.new()
	f.enabled = true
	_emit(f, "a")
	_emit(f, "b", "real", "vote")
	_emit(f, "a", "shadow")
	var win = RollWindow.new()
	root.add_child(win)
	win.set_feed(f)
	win.show()
	await process_frame
	_check(win._shown.size() == 2 and "Actual draw" in win.detail.text and "70.0%" in win.detail.text, "window starts with real checks and full sampled-draw detail")
	win.people.select(1)
	win._refresh()
	_check(win._shown.size() == 1 and win._shown[0].actor == "a", "NPC filter shows only the selected actor")
	win.people.select(0)
	win.kinds.select(2)
	win._refresh()
	_check(win._shown.size() == 1 and win._shown[0].kind == "vote", "category filter shows only the selected decision kind")
	win.kinds.select(0)
	win.shadows.button_pressed = true
	win._refresh()
	_check(win._shown.size() == 3 and "GOOD-SELF" in win.visible_text(), "explicit shadow toggle and copy-visible include labelled hypothetical checks")
	win.pause.button_pressed = true
	_emit(f, "b")
	win._refresh()
	_check(f.records.size() == 4 and win._shown.size() == 3, "pause freezes the view while capture continues")
	win.pause.button_pressed = false
	win._refresh()
	_check(win._shown.size() == 4 and win.tree.get_selected().get_metadata(0) == f.records[-1].seq, "resuming follows the latest captured row")
	win.tree.get_root().get_child(0).select(0)
	_emit(f, "b")
	win._refresh()
	_check(win.tree.get_selected().get_metadata(0) == f.records[0].seq, "new arrivals preserve a manually selected older calculation")
	win.size = win.min_size
	await process_frame
	await process_frame
	_check(win.tree.size.x <= win.size.x and win.detail.size.x <= win.size.x, "inspector resizes within its minimum-width window")
	win.mirror.button_pressed = true
	_check(f.console and f.console_shadow, "console and good-self controls update only observer preferences")
	f.console = false
	f.clear()
	win._refresh()
	_check(win._shown.is_empty() and win.visible_text().is_empty(), "clear removes copied and displayed records")
	win.queue_free()
	await process_frame

func _main_ui() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.roles_win.hide()
	_check(not scene.roll_button.visible and not scene.g.decision_feed.enabled, "roll controls and capture start disabled with Debug")
	var state = scene.g.w.rng.state
	scene.debug_check.button_pressed = true
	scene.roll_button.pressed.emit()
	_check(scene.roll_button.visible and scene.roll_window.visible and scene.g.prediction_spoiled and scene.g.w.rng.state == state, "Debug opens inspector without RNG and preserves unscored identification rule")
	scene._set_roles_pinned(true)
	_check(scene.roles_dock.visible and scene.roll_window.visible and scene.g.w.rng.state == state, "pinned Roles and live inspector coexist without changing game RNG")
	scene._new_case()
	_check(scene.roles_pinned and scene.g.debug_overlay and scene.roll_window.feed == scene.g.decision_feed and not scene.g.decision_feed.records.is_empty(), "new case preserves pin/debug preferences and binds the inspector to fresh setup checks")
	scene.debug_check.button_pressed = false
	_check(not scene.roll_window.visible and not scene.g.decision_feed.enabled and scene.roles_dock.visible, "turning Debug off stops capture while keeping the independently pinned Roles panel")
	scene.queue_free()
	await process_frame

func _fingerprint(g) -> Dictionary:
	var npcs = {}
	for n in g.w.npcs:
		npcs[n.id] = {"real": DevLog.npc_state(n)}
		if n.shadow != null:
			npcs[n.id].shadow = DevLog.npc_state(n.shadow)
			npcs[n.id].shadow_rng = n.shadow.shadow_rng.state
	return {"npcs": npcs, "rng": g.w.rng.state, "day": g.w.day, "phase": g.w.phase, "state": g.state,
		"board": g.board.duplicate(true), "meeting": g.w.meeting.duplicate(true), "over": g.w.game_over, "winner": g.w.winner}

func _passive(g) -> String:
	match g.state:
		"approach": return "decline"
		"talk": return "bye"
		"meeting": return "done" if g.town_quiet else "wait"
		"nomination": return "vote no"
		"night": return "sleep"
	return "wait"

func _parity() -> void:
	var on = Game.new()
	var off = Game.new()
	for g in [on, off]:
		g.detailed_logging = false
		g.log_dir = "user://decision_inspector_tests"
	on.debug_overlay = true
	on.new_case(54875, 10)
	off.new_case(54875, 10)
	_check(not on.decision_feed.records.is_empty() and off.decision_feed.records.is_empty() and on.w.dlog.trace_events().is_empty(), "pre-enabled Debug captures setup independently of detailed file tracing")
	_check(on.prediction_spoiled and not off.prediction_spoiled, "starting Debug preserves the existing spoiler scoring rule")
	var identical = _fingerprint(on) == _fingerprint(off)
	var steps = 0
	# Exercise private dialogue directly before running a passive meeting/night.
	for i in range(3):
		for g in [on, off]:
			var n = g.w.npcs[i]
			Mind.greeting_cue(g.w, n)
			Mind.answer_gift(g.w, n)
			Mind.answer_opinion(g.w, n, g.w.npcs[(i + 1) % 10])
			Mind.end_conversation(g.w, n)
		identical = identical and _fingerprint(on) == _fingerprint(off)
	while on.w.day < 2 and not on.w.game_over and steps < 100 and identical:
		var cmd = _passive(off)
		var a = on.command(cmd)
		var b = off.command(cmd)
		identical = a == b and _fingerprint(on) == _fingerprint(off)
		steps += 1
	_check(identical and (on.w.day >= 2 or on.w.game_over), "Debug on/off preserves dialogue, cards, all NPC/shadow state and RNG through a meeting and night (%d commands)" % steps)
	_check(on.decision_feed.records.any(func(e): return e.kind == "gift_disclosure") and on.decision_feed.records.any(func(e): return e.kind == "vote" or e.kind == "nomination"), "real play emits disclosure and public decision calculations")
	var old = on.decision_feed
	on.new_case(42, 7)
	_check(on.decision_feed != old and on.decision_feed.records.size() < Feed.LIMIT and on.decision_feed.enabled, "new cases start a fresh bounded observer while retaining Debug preference")
	await process_frame

## The merged batch must keep its approved filters and draw order while exposing
## new decision points to the inspector. Deliberately use low Gossip and a friend.
func _batch4_decisions() -> void:
	var on = Game.new()
	var off = Game.new()
	on.debug_overlay = true
	for g in [on, off]:
		g.detailed_logging = false
		g.log_dir = "user://decision_inspector_tests"
		g.new_case(4242, 10)
		var w = g.w
		var n = w.living_good()[0]
		var t = w.living_good()[1]
		w.day = 3
		w.set_log_time()
		n.role = "clerk"
		n.secret_mod = ""
		n.claimed_role = ""
		n.silenced = false
		n.home_block = "square"
		n.history[w.time_key(2, C.NIGHT)] = "home:square"
		n.traits.gossip = 0.0
		n.traits.composure = 0.0
		n.npc_trust[t.id] = 0.95
		n.beliefs = [{"kind": "saw", "who": t.id, "block": "square", "day": 2, "phase": C.NIGHT, "how": "window"}]
	var probe = RandomNumberGenerator.new()
	for expected in [true, false]:
		var initial = 0
		var draw = 0.0
		for seed_value in range(1, 1000):
			probe.seed = seed_value
			initial = probe.state
			draw = probe.randf()
			if (draw < 0.95) == expected: break
		on.decision_feed.clear()
		var replies: Array = []
		for g in [on, off]:
			g.w.rng.state = initial
			g.w.dlog.begin_action("command", {"cmd": "ask night"})
			replies.append(Mind.answer_night(g.w, g.w.living_good()[0], 2))
			g.w.dlog.end_action()
		_check(replies[0] == replies[1] and _fingerprint(on) == _fingerprint(off), "batch-4 direct report response/state is identical with inspector on/off: " + str(expected))
		_check(on.w.rng.state == probe.state and off.w.rng.state == probe.state, "95 percent willingness remains the sole draw; old friend/Gossip filters stay removed")
		var rows = on.decision_feed.records.filter(func(e): return e.kind == "direct_night_sightings")
		_check(rows.size() == 1 and rows[0].details.draw == draw and rows[0].details.threshold == 0.95 and rows[0].result == expected and rows[0].estimate.chance == 0.95, "inspector displays the exact new willingness draw, cutoff, outcome and chance")
		_check(rows[0].trigger == "ask night" and rows[0].stats.eligible_sightings == 1 and off.decision_feed.records.is_empty(), "new willingness row retains command/input context and stays disabled in control")
		_check(on.w.living_good()[0].told_to == off.w.living_good()[0].told_to and on.w.living_good()[0].dialogue_memory == off.w.living_good()[0].dialogue_memory, "private telling/account bookkeeping is identical with capture enabled")
	# No RNG in voluntary testimony; its percentage must stay N/A.
	for eligible in [true, false]:
		on.decision_feed.clear()
		var replies: Array = []
		var before_rng = on.w.rng.state
		for g in [on, off]:
			var n = g.w.living_good()[0]
			n.traits.gossip = 0.6 if eligible else 0.1
			n.traits.confidence = 0.6 if eligible else 0.1
			n.told_to = {}
			var lines: Array = []
			var facts: Array = []
			Mind._volunteer_night_sightings(g.w, n, lines, facts)
			replies.append({"lines": lines, "facts": facts})
		_check(replies[0] == replies[1] and _fingerprint(on) == _fingerprint(off) and on.w.rng.state == before_rng, "volunteering threshold and facts preserve on/off parity without RNG: " + str(eligible))
		var row: Dictionary = on.decision_feed.records.filter(func(e): return e.kind == "volunteer_night_sightings")[0]
		_check(row.result == eligible and row.estimate.type == "deterministic" and row.stats.gossip == (0.6 if eligible else 0.1) and row.details.threshold == 1.2, "inspector shows raw volunteering stats and threshold without inventing a probability")

	# Refusing whereabouts can expose an off-home sighting only through the
	# existing privacy-slip draw; capture must show that exact sample too.
	var captured = false
	for seed_value in range(1, 60):
		on.decision_feed.clear()
		var replies: Array = []
		for g in [on, off]:
			var w = g.w
			var n = w.minion()
			var t = w.living_good()[0]
			w.day = 2
			w.set_log_time()
			n.home_block = "square"
			n.history[w.time_key(1, C.NIGHT)] = "night:market"
			n.claimed_role = ""
			n.claim_public = false
			n.info_log = []
			n.secret_mod = ""
			n.traits.gossip = 1.0
			n.traits.confidence = 0.0
			n.traits.privacy = 1.0
			n.traits.composure = 0.0
			n.trust = 0.5
			n.pressure = 0.0
			n.pressed_today = 0
			n.dialogue_memory = {}
			n.beliefs = [{"kind": "saw", "who": t.id, "block": "market", "day": 1, "phase": C.NIGHT, "how": "street"}]
			w.rng.seed = seed_value
			replies.append(Mind.answer_night(w, n, 1))
		var rows = on.decision_feed.records.filter(func(e): return e.kind == "refused_whereabouts_slip")
		if rows.is_empty(): continue
		probe.seed = seed_value
		probe.randf() # Existing lie/stonewall draw comes before the slip.
		var sample = probe.randf()
		_check(rows.size() == 1 and rows[0].details.draw == sample and rows[0].details.threshold == 0.25 and rows[0].estimate.chance == 0.25, "inspector reuses the original refused-whereabouts slip sample and cutoff")
		_check(replies[0] == replies[1] and _fingerprint(on) == _fingerprint(off), "refused-whereabouts response, privacy and RNG match with capture enabled")
		captured = true
		break
	_check(captured, "integration fixture reaches the batch-4 refusal-slip path")
