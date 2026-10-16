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

func set_time(d: int, p: String) -> void:
	day = d
	phase = p

func add(type: String, actor: String = "", target: String = "", data: Dictionary = {}, reason: String = "") -> void:
	_seq += 1
	var e = {"seq": _seq, "day": day, "phase": phase, "type": type,
		"actor": actor, "target": target, "data": data.duplicate(true), "reason": reason}
	entries.append(e)
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
	return [jsonl_path, txt_path]
