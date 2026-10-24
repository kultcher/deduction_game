## Developer trace of everything that happens in a case, including hidden state
## and NPC reasoning. Written as JSONL (machine-readable) and a text transcript.
##
## Entry fields:
##   seq     running number
##   day     day number (0 = setup / first night)
##   phase   phase name
##   type    event type (see README "Dev log" for the list)
##   actor   npc id, "player", "world", or "" if none
##   target  npc id or ""
##   data    free-form dictionary
##   reason  human-readable explanation (the "why")
extends RefCounted

var entries: Array = []
var _seq = 0
var day = 0
var phase = "Setup"
var echo = false  # print each entry to stdout as it is logged

# Detailed trace is a separate, versioned sidecar. Legacy entries and text stay intact.
const TRACE_SCHEMA = 1
const TRACE_FIELDS = ["name", "traits", "role", "alignment", "alive", "death_day",
	"death_cause", "poisoned", "secret_mod", "lover", "red_herring", "loc",
	"trust", "trust_cap", "trust_at_reconsider", "npc_trust", "suspicion", "sus_why",
	"sus_src", "pressure", "consensus_pressure", "pressed_today", "role_guesses",
	"claimed_role", "claim_public", "max_tier", "told_readings", "secret_known",
	"secret_spread", "secret_spread_by_npc", "beliefs", "info_log", "known_claims",
	"known_secrets", "hearsay", "protect_pref", "spare_pref", "believed_roles",
	"discounted", "honesty", "ledger", "workshop_state", "cleared", "used_facts"]
var detailed = false
var stream = "real"
var trace_path = ""
# Shared by real/shadow logs; no NPC/world references or RNGs are retained here.
var _trace = {}

func configure_trace(enabled: bool, shared: Dictionary = {}, source: String = "real") -> void:
	detailed = enabled
	stream = source
	_trace = shared
	if detailed and shared.is_empty():
		_trace = {"seq": 0, "next_action": 0, "action": 0, "events": [], "states": {}}

func trace_context() -> Dictionary:
	return _trace

func trace_event(type: String, actor: String = "", target: String = "", data: Dictionary = {}, reason: String = "") -> void:
	if not detailed:
		return
	_trace["seq"] += 1
	_trace["events"].append({"schema": TRACE_SCHEMA, "seq": _trace["seq"],
		"day": day, "phase": phase, "type": type, "actor": actor, "target": target,
		"stream": stream, "action_id": _trace["action"],
		"data": data.duplicate(true), "reason": reason})

## Structured decision records are explanatory; they never mutate replay state.
## Reuse the returned id across start/gate/evaluation/outcome records.
func decision(actor: String, kind: String, stage: String, result, details: Dictionary = {}, target: String = "", decision_id: int = 0) -> int:
	if not detailed:
		return 0
	if decision_id == 0:
		_trace["next_decision"] = _trace.get("next_decision", 0) + 1
		decision_id = _trace["next_decision"]
	trace_event("decision", actor, target, {"decision_id": decision_id, "kind": kind,
		"stage": stage, "result": result, "details": details})
	return decision_id

func begin_action(label: String, data: Dictionary = {}) -> void:
	if not detailed:
		return
	# Commands are not nested. End any incomplete diagnostic scope explicitly.
	if _trace["action"] != 0:
		end_action("interrupted")
	_trace["next_action"] += 1
	_trace["action"] = _trace["next_action"]
	trace_event("action_begin", "player", "", {"label": label, "context": data})

func end_action(status: String = "complete") -> void:
	if not detailed or _trace["action"] == 0:
		return
	trace_event("action_end", "world", "", {"status": status})
	_trace["action"] = 0

## This is a deep value copy of tracked state, never a simulated/recomputed belief.
static func npc_state(n) -> Dictionary:
	var state = {}
	for field in TRACE_FIELDS:
		var value = n.get(field)
		state[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	return state

## Exact changes between observations. Dictionary paths are strings in JSON;
## arrays are atomic values, and existence flags distinguish deletion from null.
static func state_changes(before: Dictionary, after: Dictionary, path: Array = []) -> Array:
	var changes: Array = []
	for key in before:
		var at: Array = path.duplicate()
		at.append(str(key))
		if not after.has(key):
			changes.append({"path": at, "had_before": true, "has_after": false,
				"from": before[key], "to": null})
		elif before[key] is Dictionary and after[key] is Dictionary:
			changes.append_array(state_changes(before[key], after[key], at))
		elif before[key] != after[key]:
			changes.append({"path": at, "had_before": true, "has_after": true,
				"from": before[key], "to": after[key]})
	for key in after:
		if not before.has(key):
			var at: Array = path.duplicate()
			at.append(str(key))
			changes.append({"path": at, "had_before": false, "has_after": true,
				"from": null, "to": after[key]})
	return changes

func capture_npc(n, tag: String, checkpoint: bool = false) -> void:
	if not detailed:
		return
	var mind = "shadow" if n.is_shadow else "real"
	var key: String = mind + ":" + str(n.id)
	var current = npc_state(n)
	var states: Dictionary = _trace["states"]
	if states.has(key):
		var changes = state_changes(states[key], current)
		if not changes.is_empty():
			trace_event("state_delta", n.id, "", {"mind": mind, "tag": tag, "changes": changes},
				"Observed state change; tag identifies capture boundary, not an inferred cause")
	if checkpoint or not states.has(key):
		trace_event("state_checkpoint", n.id, "", {"mind": mind, "tag": tag, "state": current})
	states[key] = current

func trace_events() -> Array:
	return _trace.get("events", [])

func write_trace_file(dir_path: String, base: String) -> Error:
	if not detailed:
		return OK
	DirAccess.make_dir_recursive_absolute(dir_path)
	var path = dir_path.path_join(base + ".trace.jsonl")
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	for e in trace_events():
		f.store_line(JSON.stringify(e))
	f.flush()
	var error = f.get_error()
	f.close()
	if error == OK:
		trace_path = path
	return error

func set_time(d: int, p: String) -> void:
	day = d
	phase = p

func add(type: String, actor: String = "", target: String = "", data: Dictionary = {}, reason: String = "") -> void:
	_seq += 1
	var e = {"seq": _seq, "day": day, "phase": phase, "type": type,
		"actor": actor, "target": target, "data": data.duplicate(true), "reason": reason}
	entries.append(e)
	trace_event(type, actor, target, data, reason)
	if echo:
		print(format_entry(e))

## NPC reasoning snapshot. topic examples: "claim", "lie", "vote", "suspicion", "kill_choice".
func think(npc_id: String, topic: String, reason: String, data: Dictionary = {}) -> void:
	var d = data.duplicate()
	d["topic"] = topic
	add("think", npc_id, "", d, reason)

func format_entry(e: Dictionary) -> String:
	var head = "[%03d D%d %-9s] %-16s" % [e["seq"], e["day"], e["phase"], e["type"]]
	var who = ""
	if e["actor"] != "":
		who = e["actor"]
		if e["target"] != "":
			who += " -> " + e["target"]
		who += " "
	var line: String = head + " " + who
	if e["reason"] != "":
		line += "| " + e["reason"]
	var d: Dictionary = e["data"]
	if not d.is_empty():
		line += "  " + JSON.stringify(d)
	return line

func to_text() -> String:
	var lines = PackedStringArray()
	for e in entries:
		lines.append(format_entry(e))
	return "\n".join(lines)

func write_files(dir_path: String, base: String) -> Array:
	DirAccess.make_dir_recursive_absolute(dir_path)
	var jsonl_path = dir_path.path_join(base + ".jsonl")
	var txt_path = dir_path.path_join(base + ".txt")
	var f = FileAccess.open(jsonl_path, FileAccess.WRITE)
	if f:
		for e in entries:
			f.store_line(JSON.stringify(e))
		f.close()
	var t = FileAccess.open(txt_path, FileAccess.WRITE)
	if t:
		t.store_string(to_text())
		t.close()
	var trace_error = write_trace_file(dir_path, base)
	if trace_error != OK:
		push_error("Detailed trace export failed: %s" % error_string(trace_error))
	return [jsonl_path, txt_path]
