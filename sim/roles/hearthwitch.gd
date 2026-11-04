## Hearthwitch role definition and simulation hooks (benched role kept in code).
##
## Shape: ROLE_AT_SITE (group_count mode: each night, learns how many of their two
## living lane-neighbours register as evil).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "hearthwitch"
	display_name = "Hearthwitch"
	align = "good"
	kind = "info"
	status = "benched"
	desc = "Each night, learns how many of their two living lane-neighbours are evil. (Benched: not in the script.)"
	shape = "ROLE_AT_SITE"
	site_mode = "group_count"
	site_group_key = "nbrs"
	marked_registers = true


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	return "%s %s: %d evil of %s" % [src, display_name, d.get("count", 0), _names(group_of(d), nm)]


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	var broken: bool = n.gift_broken()
	var nb: Array = w.living_neighbours(n)
	var ids: Array = nb.map(func(m): return m.id)
	var count: int = nb.filter(func(m): return w.registers_evil(m)).size()
	var reported: int = count
	if broken:
		reported = w._other_than(count, 0, nb.size())
	return {
		"data": {"nbrs": ids, "count": reported},
		"true": reported == count,
		"text": "I sensed that %d of my neighbours (%s) %s evil" % [reported, w._names(ids), "is" if reported == 1 else "are"],
	}


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, _mate, _asked: Array) -> Dictionary:
	var nbrs: Array = w.living_neighbours(n).map(func(x): return x.id)
	var count: int = 0
	var why: String = ""
	if s in nbrs:
		count = 1
		why = "frames scapegoat %s as an evil neighbour" % s
	else:
		var framable: Array = nbrs.filter(func(x): return not w.by_id[x].is_evil())
		if not framable.is_empty() and w.day >= 1 and w.chance(0.3):
			count = 1
			why = "frames a good neighbour"
		else:
			why = "reports 0 to clear neighbours (incl. any teammate)"
	var entry: Dictionary = {
		"data": {"nbrs": nbrs, "count": count},
		"text": "I sensed that %d of my neighbours (%s) %s evil" % [count, w._names(nbrs), "is" if count == 1 else "are"],
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(w, _n, dd, s: String, sg, d, goods: Array, _other: Callable, e: Dictionary, demon_implicated: bool) -> Dictionary:
	var C = content()
	if d != null and d.alive and demon_implicated and w.chance(0.5):
		var near: Array = goods.filter(func(x): return x.home_block == d.home_block).slice(0, 2)
		var grp: Array = [d.id] + near.map(func(x): return x.id)
		if grp.size() >= 2:
			e["data"] = {"group": grp, "count": 0, "block": d.home_block}
			e["text"] = "on %s I sensed 0 evil among %s" % [C.block_name(d.home_block), w._names(grp)]
			return {"entry": e, "why": "the dead Dowser %s 'found no evil' with the demon %s" % [dd.id, d.id], "frames": false}
	var near2: Array = goods.filter(func(x): return x != sg and x.home_block == sg.home_block).slice(0, 2)
	var grp2: Array = [s] + near2.map(func(x): return x.id)
	if grp2.size() < 2:
		return {}
	e["data"] = {"group": grp2, "count": 1, "block": sg.home_block}
	e["text"] = "on %s I sensed 1 evil among %s" % [C.block_name(sg.home_block), w._names(grp2)]
	return {"entry": e, "why": "the dead Dowser %s sensed evil around scapegoat %s" % [dd.id, s], "frames": true}
