## Chronicler role definition and simulation hooks.
##
## On night 3, learns 3 other people (living or dead). By how the case began, one was an
## ordinary townsfolk (good with no secret modifier), one carried a secret modifier
## (Marked always reads in this slot), and one was a minion.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "chronicler"
	display_name = "Chronicler"
	align = "good"
	kind = "info"
	tags = ["ongoing_info", "evil_id"]
	desc = "On night 3, learns three other people (living or dead): at case start, one was an ordinary townsfolk, one carried a secret, and one was a minion."
	shape = "CHRONICLER_TRIO"
	min_gift_day = 3
	cannot_hold_solo_secret = true


func is_valid_gift_time(observed_at: Dictionary) -> bool:
	return int(observed_at.get("day", -1)) == 3 and str(observed_at.get("phase", "")) == "night"


func is_ongoing_info() -> bool:
	return true


func gift_live_tonight(w, _n) -> bool:
	return w.day == 3


## Before night 3 the gift is still to come (the base day-tapered ongoing-info terms);
## after it, the one reading is spent, like a first-night gift.
func score_public_claim(w, _n, parts: Dictionary) -> void:
	if w.day < 3:
		var ongoing: float = ongoing_info_claim_term(w.day)
		if ongoing != 0.0:
			parts["gift_keeps_giving"] = ongoing
	else:
		parts["one_shot_gift"] = Tuning.Roles.ONE_SHOT_GIFT_CLAIM


func score_reveal_cost(w, _n, parts: Dictionary) -> void:
	if w.day < 3:
		var ongoing: float = ongoing_info_claim_term(w.day)
		if ongoing != 0.0:
			parts["gift_keeps_giving"] = -ongoing


func implicated(d: Dictionary) -> Array:
	return d.get("trio", []).duplicate()


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	return "%s Chronicler: folk/secret/minion in %s" % [src, _names(d.get("trio", []), nm)]


func _spoken_text(w, trio: Array) -> String:
	return "I pieced together from the town's earliest rolls that at the start of the case, among %s, one was an ordinary townsperson, one carried a secret, and one was a minion" % w._names(trio)


func _case_start_pools(w, exclude_npc) -> Dictionary:
	var init_minions: Array = w.initial_minion_ids if not w.initial_minion_ids.is_empty() else w.minion_ids
	var init_evil: Array = w.initial_evil_ids if not w.initial_evil_ids.is_empty() else ([w.first_demon_id if w.first_demon_id != "" else w.demon_id] + init_minions)
	var init_secrets: Array = w.initial_secret_holders
	var minions: Array = []
	var secrets: Array = []
	var townsfolk: Array = []
	for m in w.npcs:
		if m == exclude_npc:
			continue
		var was_minion: bool = m.id in init_minions
		var was_evil: bool = m.id in init_evil
		var had_secret: bool = (m.id in init_secrets) if not init_secrets.is_empty() else (not was_evil and m.secret_mod != "")
		if was_minion:
			minions.append(m)
		elif not was_evil and had_secret:
			secrets.append(m)
		elif not was_evil and not had_secret:
			townsfolk.append(m)
	return {"minions": minions, "secrets": secrets, "townsfolk": townsfolk}


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	if w.day != 3:
		return {}
	var broken: bool = n.gift_broken()
	var pools: Dictionary = _case_start_pools(w, n)
	var others: Array = w.npcs.filter(func(m): return m != n)
	if others.size() < 3:
		return {}
	var trio: Array = []
	var ok: bool = true
	if broken or pools["minions"].is_empty() or pools["secrets"].is_empty() or pools["townsfolk"].is_empty():
		var non_minions: Array = others.filter(func(m): return not (m in pools["minions"]))
		var pool_pick: Array = non_minions if non_minions.size() >= 3 else others
		trio = w.shuffled(pool_pick).slice(0, 3).map(func(m): return m.id)
		var has_m: bool = trio.any(func(pid): return pools["minions"].any(func(x): return x.id == pid))
		var has_s: bool = trio.any(func(pid): return pools["secrets"].any(func(x): return x.id == pid))
		var has_t: bool = trio.any(func(pid): return pools["townsfolk"].any(func(x): return x.id == pid))
		ok = has_m and has_s and has_t
	else:
		var m_pick = w.pick(pools["minions"])
		var s_pick = w.pick(pools["secrets"])
		var t_pick = w.pick(pools["townsfolk"])
		trio = w.shuffled([m_pick.id, s_pick.id, t_pick.id])
		ok = true
	return {
		"data": {"trio": trio},
		"true": ok,
		"text": _spoken_text(w, trio),
	}


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, _mate, _asked: Array) -> Dictionary:
	if w.day != 3:
		return {}
	var goods: Array = w.npcs.filter(func(m): return m != n and not m.is_evil())
	var others: Array = w.npcs.filter(func(m): return m != n)
	if others.size() < 3:
		return {}
	var chosen: Array = []
	if s != "" and s != n.id and w.by_id.has(s):
		chosen.append(s)
	for g in w.shuffled(goods):
		if chosen.size() >= 3:
			break
		if g.id not in chosen:
			chosen.append(g.id)
	for o in w.shuffled(others):
		if chosen.size() >= 3:
			break
		if o.id not in chosen:
			chosen.append(o.id)
	var trio: Array = w.shuffled(chosen)
	return {
		"entry": {"data": {"trio": trio}, "text": _spoken_text(w, trio)},
		"why": "places scapegoat %s in a Chronicler trio of innocents" % s,
	}


func fake_medium_reading(w, _n, dd, s: String, _sg, _d, goods: Array, _other: Callable, e: Dictionary, _demon_implicated: bool) -> Dictionary:
	if int(e.get("day", -1)) < 3:
		return {}
	e["day"] = 3
	var chosen: Array = []
	if s != "" and s != dd.id and w.by_id.has(s):
		chosen.append(s)
	for g in w.shuffled(goods):
		if chosen.size() >= 3:
			break
		if g.id != dd.id and g.id not in chosen:
			chosen.append(g.id)
	for o in w.shuffled(w.npcs):
		if chosen.size() >= 3:
			break
		if o.id != dd.id and o.id not in chosen:
			chosen.append(o.id)
	if chosen.size() < 3:
		return {}
	var trio: Array = w.shuffled(chosen)
	e["data"] = {"trio": trio}
	e["text"] = _spoken_text(w, trio)
	return {"entry": e, "why": "the dead Chronicler %s placed scapegoat %s in a minion trio" % [dd.id, s], "frames": true}
