## Surveyor role definition and simulation hooks.
##
## Shape: BLOCK_PARITY (starts knowing whether or not all residents on a random block
## other than their own — with at least two residents — share the same alignment).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "surveyor"
	display_name = "Surveyor"
	align = "good"
	kind = "info"
	tags = ["first_night_info", "evil_id"]
	first_night = true
	desc = "Starts knowing whether or not all the residents on a random block (not their own) share the same alignment."
	shape = "GROUP_COUNT"
	count_mode = "blocks"
	marked_registers = true


## A parity reading ({block, same}) is about the block's residents; a count names no block.
func residents_block(d: Dictionary) -> String:
	return str(d.get("block", "")) if d.has("same") else ""

func short_text(d: Dictionary, _src: String, _nm: Callable) -> String:
	if d.has("block") and d.has("same"):
		var bname: String = content().block_name(str(d.get("block", "square"))).trim_prefix("the ")
		return "%s: %s" % [bname, "one side" if bool(d.get("same", false)) else "mixed"]
	var c: int = int(d.get("count", 0))
	return "Evil on %d block%s" % [c, "" if c == 1 else "s"]


func _eligible_blocks(w, n) -> Array:
	var C = content()
	var out: Array = []
	for b in C.BLOCKS.keys():
		if b == n.home_block:
			continue
		var res: Array = w.npcs.filter(func(m): return m.home_block == b)
		if res.size() >= 2:
			out.append(b)
	return out


func _spoken_text(b: String, same: bool) -> String:
	var bname: String = content().block_name(b)
	if same:
		return "I learned that all the folk living on %s share the same alignment" % bname
	return "I learned that not everyone living on %s shares the same alignment" % bname


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	var broken: bool = n.gift_broken()
	var eligible: Array = _eligible_blocks(w, n)
	if eligible.is_empty():
		return {}
	var blk: String = w.pick(eligible)
	var res: Array = w.npcs.filter(func(m): return m.home_block == blk)
	var reg_evil_cnt: int = res.filter(func(m): return w.registers_evil(m)).size()
	var true_evil_cnt: int = res.filter(func(m): return m.is_evil()).size()
	var same: bool = (reg_evil_cnt == 0 or reg_evil_cnt == res.size())
	var truth_same: bool = (true_evil_cnt == 0 or true_evil_cnt == res.size())
	var swhy: String = ""
	if broken:
		same = not truth_same
	elif same != truth_same:
		swhy = "a Marked soul reads as evil"
	return {
		"data": {"block": blk, "same": same},
		"true": same == truth_same,
		"why": swhy,
		"text": _spoken_text(blk, same),
	}


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, mate, _asked: Array) -> Dictionary:
	if w.day != 0:
		return {}
	var eligible: Array = _eligible_blocks(w, n)
	if eligible.is_empty():
		return {}
	var sg = w.by_id.get(s)
	var blk: String = ""
	var same: bool = false
	var why: String = ""
	if sg != null and sg.home_block in eligible and w.chance(0.6):
		blk = sg.home_block
		var res_sg: Array = w.npcs.filter(func(m): return m.home_block == blk)
		var has_mate: bool = res_sg.any(func(m): return m.is_evil())
		same = false if not has_mate else w.chance(0.35)
		why = "cast doubt on %s's street" % s
	elif mate != null and mate != n and mate.home_block in eligible and w.chance(0.5):
		blk = mate.home_block
		same = true
		why = "cleared the street of %s, a fellow evil" % mate.id
	else:
		blk = w.pick(eligible)
		same = w.chance(0.5)
		why = "claimed %s's households %s all on one side" % [content().block_name(blk), "were" if same else "weren't"]
	var entry: Dictionary = {
		"data": {"block": blk, "same": same},
		"text": _spoken_text(blk, same),
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(w, _n, dd, s: String, sg, d, _goods: Array, _other: Callable, e: Dictionary, demon_implicated: bool) -> Dictionary:
	var eligible: Array = _eligible_blocks(w, dd)
	if eligible.is_empty():
		return {}
	if d != null and d.alive and demon_implicated and d.home_block in eligible and w.chance(0.5):
		e["data"] = {"block": d.home_block, "same": true}
		e["text"] = _spoken_text(d.home_block, true)
		return {"entry": e, "why": "made up a reading from the late Surveyor %s that cleared the Demon %s's street" % [dd.id, d.id], "frames": false}
	var blk: String = sg.home_block if (sg != null and sg.home_block in eligible) else w.pick(eligible)
	var frames_sg: bool = (sg != null and blk == sg.home_block)
	var same: bool = false if frames_sg else true
	e["data"] = {"block": blk, "same": same}
	e["text"] = _spoken_text(blk, same)
	return {"entry": e, "why": "made up a reading from the late Surveyor %s about who lives on %s" % [dd.id, content().block_name(blk)], "frames": frames_sg}


## The other answer on the same quarter (FabricationCheck: a better lie).
func bluff_alternatives(_w, _n, _plan: Dictionary, _s: String, _mate, entry: Dictionary) -> Array:
	var d: Dictionary = entry.get("data", {})
	var blk: String = str(d.get("block", ""))
	var same: bool = not bool(d.get("same", false))
	return [{"entry": {"data": {"block": blk, "same": same}, "text": _spoken_text(blk, same)}, "why": "gives the other answer on %s" % blk}]
