## Tracing milestones 1-2 smoke tests. Exit status is nonzero on failure.
## godot --headless --path . --script res://tools/test_trace.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const DevLog = preload("res://sim/devlog.gd")
const Mind = preload("res://sim/mind.gd")
const Argue = preload("res://sim/argue.gd")
const C = preload("res://sim/content.gd")

var fails = 0
var checks = 0

func _init() -> void:
	var args = OS.get_cmdline_user_args()
	if "--parity" in args:
		var at: int = args.find("--parity")
		if at + 2 >= args.size():
			push_error("--parity requires a seed and NPC count")
			quit(1)
			return
		_test_parity(int(args[at + 1]), int(args[at + 2]))
		print("TRACE selected parity: %d checks, %d failures" % [checks, fails])
		quit(1 if fails else 0)
		return
	_test_diff()
	_test_trace()
	_test_decision_records()
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
	print("TRACE parity starting: seed %d / %d NPCs" % [sd, count])
	var traced = _fresh(sd, count, true)
	var control = _fresh(sd, count, false)
	var identical = _fingerprint(traced) == _fingerprint(control)
	var steps = 0
	while not traced.w.game_over and not control.w.game_over and steps < 400:
		var cmd = _passive_command(control)
		var started: int = Time.get_ticks_msec()
		var a = traced.command(cmd)
		var b = control.command(cmd)
		var elapsed: int = Time.get_ticks_msec() - started
		if elapsed > 5000:
			print("TRACE parity seed %d / %d NPCs, step %d, day %d, %s: %d ms" % [sd, count, steps, control.w.day, cmd, elapsed])
		if a != b or _fingerprint(traced) != _fingerprint(control):
			identical = false
			break
		steps += 1
	_check(identical, "trace on/off parity seed %d, NPCs %d, through step %d" % [sd, count, steps])
	_check(traced.w.game_over and control.w.game_over, "passive case finishes within smoke-test limit")
	print("TRACE parity finished: seed %d / %d NPCs, %d steps" % [sd, count, steps])

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

func _last_decision(w, kind: String, stage: String, actor: String = "") -> Dictionary:
	var events = w.dlog.trace_events().filter(func(e):
		return e["type"] == "decision" and e["data"]["kind"] == kind and e["data"]["stage"] == stage and (actor == "" or e["actor"] == actor))
	return events[-1] if not events.is_empty() else {}

func _sum_parts(parts: Dictionary) -> float:
	var total = 0.0
	for value in parts.values():
		total += value
	return total

func _test_decision_records() -> void:
	var g = _fresh(25923, 7, true)
	var w = g.w
	var n = w.living_good()[0]
	var others: Array = w.living().filter(func(x): return x != n)
	var target = others[0]
	var block = others[1]
	w.begin_meeting()
	n.trust = 0.5
	n.trust_at_reconsider = 0.5
	n.role = "warden"
	n.traits["confidence"] = 0.5
	n.cleared.clear()
	n.spare_pref.clear()
	for other in others:
		n.suspicion[other.id] = 0.1
		n.npc_trust[other.id] = 0.5
	n.suspicion[target.id] = 0.700123
	n.suspicion[block.id] = 0.9
	w.meeting["block"] = block.id
	var yes = Mind.vote(w, n, target.id, "player", false, "", 0)
	var evaluation = _last_decision(w, "vote", "evaluation", n.id)
	_check(not evaluation.is_empty(), "good vote has structured evaluation")
	if not evaluation.is_empty():
		var data: Dictionary = evaluation["data"]["details"]
		_check(data["parts"].get("prefers_block") == -0.4, "vote explains existing-block penalty")
		_check(absf(_sum_parts(data["parts"]) - data["score"]) < 0.000000001,
			"vote parts reproduce the unrounded score")
		_check(absf(_sum_parts(data["threshold_parts"]) - data["threshold"]) < 0.000000001,
			"vote threshold parts reproduce threshold")
		var outcome = _last_decision(w, "vote", "outcome", n.id)
		_check(outcome["data"]["result"] == yes and outcome["data"]["decision_id"] == evaluation["data"]["decision_id"],
			"vote evaluation and outcome share an id")
	w.day = 3
	w.meeting["nominated"] = [block.id]
	var nomination = Mind._good_nomination(w, n, w.meeting, block.id)
	var gate = _last_decision(w, "nomination", "gate", n.id)
	_check(nomination == null and gate["data"]["details"].get("gate") == "prefers_existing_block",
		"nomination refusal distinguishes existing execution preference")
	_check(Mind._good_nomination(w, n, w.meeting, "") != null,
		"nomination with sufficient suspicion and no competing block remains available")
	n.traits["gossip"] = 0.1
	n.pressure = 0.0
	_check(Mind._gossip_share(w, n, "test") == 0, "low-gossip refusal retains behavior")
	gate = _last_decision(w, "gossip_share", "gate", n.id)
	_check(gate["data"]["details"].get("gate") == "gossip_and_pressure_cutoff",
		"gossip cutoff has machine-readable refusal reason")
	n.pressure = 0.5
	_check(Mind._gossip_share(w, n, "test") > 0, "pressure override retains its inclusive boundary")
	w.day = 1
	n.role = "seer"
	n.traits["privacy"] = 1.0
	n.trust = 0.0
	n.pressure = 0.0
	n.max_tier = 0
	n.claim_public = false
	n.pressed_today = 0
	var answer = Mind.answer_gift(w, n)
	var tier = _last_decision(w, "gift_disclosure", "tier", n.id)
	_check(answer["facts"].any(func(f): return f["kind"] == "refusal") and tier["data"]["result"] == 1,
		"private role refusal records actual tier")
	var details: Dictionary = tier["data"]["details"]
	_check(absf(_sum_parts(details["parts"]) - details["openness"]) < 0.000000001,
		"openness records full formula including the consumed jitter")
	_check(details["thresholds"].size() == 4, "all disclosure tier thresholds are exported")
	var support = {"n": 1, "kind": "sighting", "subject": [target.id], "source": "player",
		"class": "concrete", "day": 0, "phase": C.NIGHT, "block": target.home_block, "text": "test sighting"}
	var ded = {"n": 2, "kind": "deduction", "text": "test suspicion",
		"conclusion": {"type": "suspicious", "a": target.id}, "supports": [1]}
	# These records exercise the deliberately retained native argument routes.
	g.set_workshop_effects(false)
	Argue.evaluate(w, n, ded, [support], 1.0, false)
	var argument = _last_decision(w, "argument", "evaluation", n.id)
	_check(argument["data"]["details"]["route"] == "generic_support",
		"generic inference evaluation is labeled separately")
	var ledger = _last_decision(w, "argument", "ledger", n.id)
	_check(ledger["data"]["details"].has("suspicion_before") and ledger["data"]["details"].has("after"),
		"argument trace separates nominal weight from resulting ledger/suspicion state")
	ded["template"] = "trace_test"
	ded["chosen"] = 1
	ded["explanations"] = [
		{"id": 1, "kind": "accuse", "blame": target.id, "label": "suspicious",
			"conclusion": {"type": "suspicious", "a": target.id}},
		{"id": 2, "kind": "clear", "blame": target.id, "label": "innocent",
			"conclusion": {"type": "good", "a": target.id}}]
	Argue.evaluate(w, n, ded, [support], 1.0, false)
	var contest = _last_decision(w, "argument", "contest", n.id)
	_check(not contest.is_empty() and contest["data"]["details"]["explanations"].size() == 2,
		"template contest includes raw and rounded explanation weights")
	_test_active_parity()

func _test_active_parity() -> void:
	var a = _fresh(61251, 7, true)
	var b = _fresh(61251, 7, false)
	var na = a.w.living_good()[0]
	var nb = b.w.by_id[na.id]
	var identical = true
	for forced in [0, 4, 0]:
		var ra = Mind.answer_gift(a.w, na, forced)
		var rb = Mind.answer_gift(b.w, nb, forced)
		identical = identical and ra == rb and _fingerprint(a) == _fingerprint(b)
	var sa = Mind.decide(a.w, na, "test_roll", {"base": 0.123456}, "parity")
	var sb = Mind.decide(b.w, nb, "test_roll", {"base": 0.123456}, "parity")
	identical = identical and sa == sb and _fingerprint(a) == _fingerprint(b)
	var target = a.w.living().filter(func(n): return n.id != na.id)[0]
	var support = {"n": 1, "kind": "sighting", "subject": [target.id], "source": "player",
		"class": "concrete", "day": 0, "phase": C.NIGHT, "block": target.home_block, "text": "parity sighting"}
	var ded = {"kind": "deduction", "text": "parity suspicion",
		"conclusion": {"type": "suspicious", "a": target.id}, "supports": [1]}
	for structured in [false, true]:
		if structured:
			ded["template"] = "trace_parity"
			ded["chosen"] = 1
			ded["explanations"] = [
				{"id": 1, "kind": "accuse", "blame": target.id, "label": "suspicious",
					"conclusion": {"type": "suspicious", "a": target.id}},
				{"id": 2, "kind": "clear", "blame": target.id, "label": "innocent",
					"conclusion": {"type": "good", "a": target.id}}]
		var ra = Argue.evaluate(a.w, na, ded.duplicate(true), [support], 1.0, false)
		var rb = Argue.evaluate(b.w, nb, ded.duplicate(true), [support], 1.0, false)
		identical = identical and ra == rb and _fingerprint(a) == _fingerprint(b)
	_check(identical, "disclosure, rolls, generic and structured arguments preserve on/off parity")
	var roll = _last_decision(a.w, "test_roll", "roll", na.id)
	var parts: Dictionary = roll["data"]["details"]
	_check(parts.has("draw") and parts["probability"] == Mind.sigmoid(parts["total"] * 4.0),
		"decision roll reports the existing draw and exact probability")
