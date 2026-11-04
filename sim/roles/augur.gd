## Augur role definition and simulation hooks.
##
## Each evening (from day 1), learns whether or not they crossed paths with the Demon
## (both out in a public area on the same block) earlier that day (morning or afternoon,
## excluding the evening timeslot itself). Marked may register as the Demon (50%).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "augur"
	display_name = "Augur"
	align = "good"
	kind = "info"
	tags = ["ongoing_info", "demon_id"]
	day = true
	desc = "Each evening, learns whether they crossed paths with the demon in public on the same block earlier that day."
	shape = "AUGUR_CROSSING"
	marked_registers = true
	min_gift_day = 1


func is_valid_gift_time(observed_at: Dictionary) -> bool:
	return int(observed_at.get("day", -1)) >= 1 and str(observed_at.get("phase", "")) == "evening"


func short_text(d: Dictionary, src: String, _nm: Callable) -> String:
	return "%s Augur: %s" % [src, "YES (crossed Demon)" if bool(d.get("yes", false)) else "no crossing"]


func _spoken_text(yes: bool) -> String:
	if yes:
		return "I sensed that I crossed paths with the demon earlier in the day"
	return "I sensed no sign of the demon along my path earlier in the day"


func run_day_gift(w, ag, mind, _evil) -> void:
	if w.day < min_gift_day or w.phase != content().EVENING:
		return
	if not ag.is_evil() and not ag.info_log.any(func(e): return e.get("role", "") == "augur" and int(e.get("day", -1)) == w.day):
		var entry: Dictionary = generate_reading(w, ag, {"day_phase": true}, mind)
		if not entry.is_empty():
			w._add_info(ag, entry)
			mind.update_from_own_info(w)


func _public_block_at(w, npc, day_num: int, phase_num: int) -> String:
	var h: String = str(npc.history.get(w.time_key(day_num, phase_num), ""))
	if h == "" or h.begins_with("home") or h.begins_with("night:"):
		return ""
	return w.loc_block(h)


func generate_reading(w, ag, ctx: Dictionary, _mind) -> Dictionary:
	var C = content()
	if not ctx.get("day_phase", false) or w.day < min_gift_day or w.phase != C.EVENING:
		return {}
	var crossed: bool = false
	var truth_crossed: bool = false
	var marked_triggered: bool = false
	for ph in [C.MORNING, C.AFTERNOON]:
		var my_blk: String = _public_block_at(w, ag, w.day, ph)
		if my_blk == "":
			continue
		for m in w.npcs:
			if m == ag:
				continue
			var m_blk: String = _public_block_at(w, m, w.day, ph)
			if m_blk != my_blk:
				continue
			if m.id == w.demon_id:
				crossed = true
				truth_crossed = true
			elif m.secret_mod == "marked" and not m.is_evil():
				if w.registers_evil(m):
					crossed = true
					marked_triggered = true
	var awhy: String = ""
	if ag.gift_broken():
		crossed = not truth_crossed
	elif crossed != truth_crossed and marked_triggered:
		awhy = "a Marked soul read as the demon"
	return {
		"data": {"yes": crossed},
		"true": crossed == truth_crossed,
		"why": awhy,
		"text": _spoken_text(crossed),
	}


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, _mate, _asked: Array) -> Dictionary:
	var C = content()
	if w.day < min_gift_day or w.phase != C.EVENING:
		return {}
	if n.info_log.any(func(e): return e.get("fake", false) and e.get("role", "") == "augur" and int(e.get("day", -1)) == w.day):
		return {}
	var shared_with_sg: bool = false
	var shared_with_demon: bool = false
	var sg = w.by_id.get(s)
	for ph in [C.MORNING, C.AFTERNOON]:
		var my_blk: String = _public_block_at(w, n, w.day, ph)
		if my_blk == "":
			continue
		if sg != null and sg != n and _public_block_at(w, sg, w.day, ph) == my_blk:
			shared_with_sg = true
		if n.id != w.demon_id and w.by_id.has(w.demon_id) and _public_block_at(w, w.by_id[w.demon_id], w.day, ph) == my_blk:
			shared_with_demon = true
	var yes: bool = false
	var why: String = "reports no demon crossing today"
	if shared_with_demon and not shared_with_sg:
		yes = false
		why = "clears demon after sharing a daytime block"
	elif shared_with_sg and w.chance(0.75):
		yes = true
		why = "claims a demon crossing after sharing a daytime block with scapegoat %s" % s
	elif w.chance(0.25):
		yes = true
		why = "claims an unspecific daytime demon crossing"
	return {
		"entry": {"data": {"yes": yes}, "text": _spoken_text(yes)},
		"why": why,
	}


func fake_medium_reading(w, _n, dd, s: String, _sg, d, _goods: Array, _other: Callable, e: Dictionary, demon_implicated: bool) -> Dictionary:
	var C = content()
	var r_day: int = maxi(1, int(e.get("day", 1)))
	e["day"] = r_day
	e["phase"] = C.EVENING
	if d != null and d.alive and demon_implicated and w.chance(0.5):
		e["data"] = {"yes": false}
		e["text"] = _spoken_text(false)
		return {"entry": e, "why": "the dead Augur %s 'sensed no demon' on day %d" % [dd.id, r_day], "frames": false}
	e["data"] = {"yes": true}
	e["text"] = _spoken_text(true)
	return {"entry": e, "why": "the dead Augur %s 'sensed the demon' on day %d (toward %s)" % [dd.id, r_day, s], "frames": true}
