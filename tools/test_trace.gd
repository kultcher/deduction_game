## Milestone 1 tracing smoke tests. Exit status is nonzero on failure.
## godot --headless --path . --script res://tools/test_trace.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const DevLog = preload("res://sim/devlog.gd")
const Mind = preload("res://sim/mind.gd")

var fails = 0
var checks = 0

func _init() -> void:
	_test_diff()
	_test_trace()
	for count in [7, 10]:
		for sd in [42, 61251, 25923]:
			_test_parity(sd, count)
	print("TRACE: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)

func _fresh(sd: int, count: int, enabled: bool):
	var g = Game.new()
	g.detailed_logging = enabled
	g.log_dir = "user://test_trace_logs"
	g.new_case(sd, count)
	return g

func _test_diff() -> void:
	var changes = DevLog.state_changes({"a": {"x": 1, "gone": 2}, "list": [1]},
		{"a": {"x": 1.00001, "new": null}, "list": [1, 2]})
	_check(changes.size() == 4, "nested changes, deletion, addition of null and arrays are represented")
	var no_change = DevLog.state_changes({"a": [1, {"b": 2}]}, {"a": [1, {"b": 2}]})
	_check(no_change.is_empty(), "equal values produce no delta")
	var log = DevLog.new()
	log.configure_trace(true)
	var g = _fresh(42, 7, false)
	var n = g.w.npcs[0]
	log.capture_npc(n, "test", true)
	var old = log.trace_events()[0]["data"]["state"].duplicate(true)
	# Mutating both a scalar and a nested map must leave the checkpoint unchanged.
	n.trust = 0.123456
	n.npc_trust["test_person"] = 0.987654
	_check(log.trace_events()[0]["data"]["state"] == old, "checkpoints retain deep value copies")

func _test_trace() -> void:
	var g = _fresh(61251, 10, true)
	var w = g.w
	var n = w.living_good()[0]
	var other = w.npcs.filter(func(x): return x != n)[0]
	var rng_before = w.rng.state
	var old: float = n.trust
	w.dlog.begin_action("small_mutations")
	Mind.set_trust(w, n, old + 0.0001, "tiny trust test")
	Mind.adjust(w, n, other.id, 0.0001, "tiny suspicion test", "", false)
	w.trace_capture("small_mutations")
	w.dlog.end_action()
	var trust_events = w.dlog.trace_events().filter(func(e):
		return e["type"] == "value_change" and e["reason"] == "tiny trust test")
	_check(trust_events.size() == 1, "sub-.01 trust mutation is present")
	if trust_events.size() == 1:
		_check(absf(trust_events[0]["data"]["to"] - n.trust) < 0.000000001,
			"trust values are not rounded for tracing")
	_check(w.rng.state == rng_before, "capture and trace-only action scopes consume no RNG")
	w.dlog.begin_action("direct_mutation")
	n.npc_trust[other.id] = 0.1234567
	w.trace_capture("direct_assignment")
	w.dlog.end_action()
	var found = false
	for e in w.dlog.trace_events():
		if e["type"] != "state_delta" or e["data"]["tag"] != "direct_assignment":
			continue
		for change in e["data"]["changes"]:
			if change["path"] == ["npc_trust", other.id]:
				found = change["to"] == 0.1234567
	_check(found, "boundary differences catch direct relationship assignments")
	Mind.ledger_hear(w, n, "trace:test", [[other.id, 0.02, false, "trace evidence", ""]],
		0.5, [], {"kind": "trace_test"})
	w.trace_capture("ledger", true)
	var last_state = w.dlog.trace_context()["states"]["real:" + n.id]
	_check(last_state["ledger"].has("trace:test"), "ledger contents and applied effects are captured")
	_check(last_state["ledger"]["trace:test"].has("eff"), "effective ledger weight is retained")
	_check(w.dlog.trace_events().any(func(e): return e["stream"] == "shadow"),
		"shadow events enter the combined timeline")
	var seq = 0
	var ordered = true
	for e in w.dlog.trace_events():
		ordered = ordered and e["seq"] == seq + 1
		seq = e["seq"]
	_check(ordered, "combined real/shadow sequence is unique and contiguous")
	_test_reconstruction(w.dlog)
	g.command("log")
	var path = w.dlog.trace_path
	_check(path != "" and FileAccess.file_exists(path), "log command writes trace sidecar")
	if path != "" and FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.READ)
		var parsed = 0
		var valid = true
		while f.get_position() < f.get_length():
			var line = f.get_line()
			if line.is_empty():
				continue
			var row = JSON.parse_string(line)
			valid = valid and row is Dictionary
			parsed += 1
		f.close()
		_check(valid and parsed == w.dlog.trace_events().size(), "export includes completed command boundary")
	var off = _fresh(42, 7, false)
	_check(off.w.dlog.trace_events().is_empty(), "disabled trace allocates no detailed event history")

func _passive_command(g) -> String:
	match g.state:
		"day": return "wait"
		"approach": return "decline"
		"talk": return "bye"
		"meeting": return "done" if g.town_quiet else "wait"
		"nomination": return "vote no"
		"night": return "sleep"
	return "look"

func _fingerprint(g) -> Dictionary:
	var npcs = {}
	for n in g.w.npcs:
		npcs[n.id] = {"real": DevLog.npc_state(n)}
		if n.shadow != null:
			npcs[n.id]["shadow"] = DevLog.npc_state(n.shadow)
			npcs[n.id]["shadow_rng"] = n.shadow.shadow_rng.state
	return {"npcs": npcs, "rng": g.w.rng.state, "day": g.w.day, "phase": g.w.phase,
		"winner": g.w.winner, "over": g.w.game_over, "state": g.state,
		"board": g.board.duplicate(true), "meeting": g.w.meeting.duplicate(true)}

func _test_parity(sd: int, count: int) -> void:
	var traced = _fresh(sd, count, true)
	var control = _fresh(sd, count, false)
	var identical = _fingerprint(traced) == _fingerprint(control)
	var steps = 0
	while not traced.w.game_over and not control.w.game_over and steps < 400:
		var cmd = _passive_command(control)
		var a = traced.command(cmd)
		var b = control.command(cmd)
		if a != b or _fingerprint(traced) != _fingerprint(control):
			identical = false
			break
		steps += 1
	_check(identical, "trace on/off parity seed %d, NPCs %d, through step %d" % [sd, count, steps])
	_check(traced.w.game_over and control.w.game_over, "passive case finishes within smoke-test limit")

## Reconstruct only from checkpoints/deltas. value_change events explain substeps
## and must not also be applied to the authoritative state timeline.
func _json_value(value):
	return JSON.parse_string(JSON.stringify(value))

func _test_reconstruction(log) -> void:
	var states = {}
	var valid = true
	for event in log.trace_events():
		if not event["type"] in ["state_checkpoint", "state_delta"]:
			continue
		var data: Dictionary = event["data"]
		var key: String = data["mind"] + ":" + event["actor"]
		if event["type"] == "state_checkpoint":
			var expected = _json_value(data["state"])
			if states.has(key):
				valid = valid and states[key] == expected
			states[key] = expected
			continue
		if not states.has(key):
			valid = false
			continue
		for change in data["changes"]:
			var path: Array = change["path"]
			var parent: Dictionary = states[key]
			for i in range(path.size() - 1):
				parent = parent[path[i]]
			var leaf = path[-1]
			valid = valid and parent.has(leaf) == change["had_before"]
			if change["had_before"]:
				valid = valid and parent.get(leaf) == _json_value(change["from"])
			if change["has_after"]:
				parent[leaf] = _json_value(change["to"])
			else:
				parent.erase(leaf)
	for key in log.trace_context()["states"]:
		valid = valid and states.get(key) == _json_value(log.trace_context()["states"][key])
	_check(valid, "state deltas reconstruct checkpoints and final observed state")
