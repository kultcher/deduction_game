## Dowser role definition and simulation hooks.
##
## Shape: ROLE_AT_SITE (group_count mode: the first time each day the Dowser is on a
## block with two or more others, learns how many of them register as evil).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "dowser"
	display_name = "Dowser"
	align = "good"
	kind = "info"
	day = true
	desc = "The first time each day the Dowser is on a block with two or more others, learns how many of them are evil."
	shape = "ROLE_AT_SITE"
	site_mode = "group_count"
	site_group_key = "group"
	marked_registers = true
	min_gift_day = 1


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	return "%s %s: %d evil of %s" % [src, display_name, d.get("count", 0), _names(group_of(d), nm)]


func info_effects(_w, listener, source, entry: Dictionary, weight: float, _fresh: bool, mind) -> Array:
	var effs: Array = []
	var d: Dictionary = entry["data"]
	var own: bool = source == listener
	var src_name: String = "my own" if own else source.name + "'s"
	var tag: String = "own info" if own else "heard %s's info (w=%.2f)" % [source.id, weight]
	var nbrs: Array = group_of(d)
	var count: int = d["count"]
	var others: Array = nbrs.filter(func(i): return i != listener.id)
	var excluded: int = nbrs.size() - others.size()
	if count == 0:
		for i in others:
			mind._eff(effs, i, Tuning.Roles.DOWSER.eff_zero, tag + ": dowser count 0", "", not own)
	else:
		var per: float = Tuning.Roles.DOWSER.eff_per_evil * count
		if excluded > 0:
			per = Tuning.Roles.DOWSER.eff_per_evil_excluded * count
		if count > others.size() and not own:
			mind._eff(effs, source.id, Tuning.Roles.DOWSER.eff_impossible_source, tag + ": dowser count impossible from my view",
				"%s reading about the lane can't be right" % src_name)
		for i in others:
			mind._eff(effs, i, per, tag + ": dowser count %d" % count,
				"%s reading pointed at that crowd" % src_name, not own)
	return effs


func run_day_gift(w, dw, mind, _evil) -> void:
	if not dw.is_evil() and dw.dowsed_day != w.day:
		var dw_entry: Dictionary = generate_reading(w, dw, {"day_phase": true}, mind)
		if not dw_entry.is_empty():
			w._add_info(dw, dw_entry)
			mind.update_from_own_info(w)


func generate_reading(w, dw, ctx: Dictionary, _mind) -> Dictionary:
	if not ctx.get("day_phase", false):
		return {}
	var b: String = dw.home_block if dw.at_home() else w.loc_block(dw.loc)
	var others: Array = w.living().filter(func(m): return m != dw and (m.home_block if m.at_home() else w.loc_block(m.loc)) == b)
	if others.size() < 2:
		return {}
	dw.dowsed_day = w.day
	var ids: Array = others.map(func(m): return m.id)
	var count: int = others.filter(func(m): return w.registers_evil(m)).size()
	var truth: int = others.filter(func(m): return m.is_evil()).size()
	var dwhy: String = ""
	if dw.gift_broken():
		count = w._other_than(truth, 0, others.size())
	elif count != truth:
		dwhy = "a Marked soul read as evil"
	return {
		"data": {"group": ids, "count": count, "block": b},
		"true": count == truth,
		"why": dwhy,
		"text": "on %s I sensed %d evil among %s" % [content().block_name(b), count, w._names(ids)],
	}


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
