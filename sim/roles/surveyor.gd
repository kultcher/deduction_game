## Surveyor role definition and simulation hooks.
##
## Shape: GROUP_COUNT (blocks mode: starts knowing how many of the four blocks have
## an evil resident).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "surveyor"
	display_name = "Surveyor"
	align = "good"
	kind = "info"
	first_night = true
	desc = "Starts knowing how many blocks have an evil resident."
	shape = "GROUP_COUNT"
	count_mode = "blocks"
	marked_registers = true


func short_text(d: Dictionary, src: String, _nm: Callable) -> String:
	var c: int = d.get("count", 0)
	return "%s Surveyor: %d block%s with evil" % [src, c, "" if c == 1 else "s"]


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	var broken: bool = n.gift_broken()
	var blocks = {}
	for m in w.npcs:
		if w.registers_evil(m):
			blocks[m.home_block] = true
	var count: int = blocks.size()
	var tb = {}
	for m in w.npcs:
		if m.is_evil():
			tb[m.home_block] = true
	var truth: int = tb.size()
	if broken:
		count = w.surveyor_result(truth)
	return {
		"data": {"count": count},
		"true": count == truth,
		"text": "I learned that %d of the four blocks %s an evil resident" % [count, "has" if count == 1 else "have"],
	}


func generate_bluff_reading(w, _n, _plan: Dictionary, _s: String, _mate, _asked: Array) -> Dictionary:
	if w.day != 0:
		return {}
	var tb = {}
	for x in w.npcs:
		if x.is_evil():
			tb[x.home_block] = true
	var cnt: int = w.surveyor_result()
	var why: String = "reports %d blocks: weighted bluff count (true %d)" % [cnt, tb.size()]
	var entry: Dictionary = {
		"data": {"count": cnt},
		"text": "I learned that %d of the four blocks %s an evil resident" % [cnt, "has" if cnt == 1 else "have"],
	}
	return {"entry": entry, "why": why}
