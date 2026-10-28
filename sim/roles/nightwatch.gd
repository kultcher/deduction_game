## Night Watch role definition and simulation hooks.
##
## Shape: NIGHT_ROUTE (each night, watches one block and learns who moved through it).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "nightwatch"
	display_name = "Night Watch"
	align = "good"
	kind = "info"
	night_walk = true
	desc = "Each night, watches one block and learns who moved through it. Is out on that block."
	shape = "NIGHT_ROUTE"
	request_agree_line = "I'll keep my watch over %s tonight, then."


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	var C = content()
	var seen_str: String = ", ".join(PackedStringArray(d.get("seen", []).map(nm))) if not d.get("seen", []).is_empty() else "nobody"
	return "%s Watch %s: %s" % [src, C.block_name(d.get("block", "")), seen_str]


func card_strength(d: Dictionary, suspect_id: String) -> float:
	return 1.0 if suspect_id in d.get("seen", []) else 0.0


func defend_strength(_d: Dictionary, _nominee: String) -> float:
	return 0.0


func info_effects(w, listener, source, entry: Dictionary, weight: float, _fresh: bool, mind) -> Array:
	var effs: Array = []
	var d: Dictionary = entry["data"]
	var own: bool = source == listener
	var src_bare: String = "I" if own else source.name
	var tag: String = "own info" if own else "heard %s's info (w=%.2f)" % [source.id, weight]
	var seen: Array = d["seen"]
	for i in seen:
		if i == listener.id:
			var where: String = listener.history.get(w.time_key(entry["day"], 3), "")
			if where.begins_with("home") and not own:
				mind._eff(effs, source.id, 0.45, tag + ": claims to have seen me out, but I was home",
					"%s claims to have seen me out at night, which is a lie" % src_bare)
			continue
		var sc: float = mind.night_sighting_scale(w, listener, i, d["block"], entry["day"])
		mind._eff(effs, i, 0.5 * sc, tag + ": seen out at night (x%.2f: %s)" % [sc, "near a death" if sc >= 0.99 else "nowhere near a death" if sc > 0.1 else "discounted"],
			"%s saw them out at night%s" % [src_bare, " where someone was killed" if sc >= 0.5 else ""], not own)
	return effs


func pick_targets(w, n, mind):
	var asked: Array = mind.requested_targets(w, n, "nightwatch")
	if not asked.is_empty():
		w.dlog.think(n.id, "watch_pick", "Night Watch watches the block the Demonologist asked for.", {"block": asked[0]})
		return asked[0]
	var ranked: Array = mind.ranked_suspects(w, n)
	var b: String = ""
	if w.day == 0 or ranked.is_empty():
		b = w.decision_pick(n, "watch_block", content().BLOCKS.keys())
	else:
		b = ranked[0].home_block
	w.dlog.think(n.id, "watch_pick", "Night Watch watches the block of their top suspect's home.", {"block": b})
	return b


func score_gift_request(w, _n, targets: Array, top: String, parts: Dictionary, _mind) -> void:
	if top != "" and w.by_id[top].home_block == targets[0]:
		parts["already_wondering"] = 0.3


func counter_gift_request(w, _n, targets: Array, top: String) -> String:
	if w.by_id[top].home_block != targets[0]:
		return "I'd sooner watch %s." % content().block_name(w.by_id[top].home_block)
	return ""


func request_target_text(_w, targets: Array, block_name_fn: Callable) -> String:
	return block_name_fn.call(targets[0])


func generate_reading(w, n, ctx: Dictionary, _mind) -> Dictionary:
	var watch_block: String = ctx.get("watch_block", "")
	if watch_block == "":
		return {} # didn't go out (the knell)
	var broken: bool = n.gift_broken()
	var seen: Array = []
	for wk in w.night_walkers:
		if watch_block in wk.get("path", [wk["block"]]) and wk["id"] != n.id:
			seen.append(wk["id"])
	var real: Array = seen.duplicate()
	if broken:
		seen = []
		var innocent = w.pick(w.living().filter(func(m): return m != n and not (m.id in real)))
		if innocent:
			seen.append(innocent.id)
	return {
		"data": {"block": watch_block, "seen": seen},
		"true": seen == real,
		"text": "I watched %s: %s" % [content().block_name(watch_block),
			("I saw " + w._names(seen) + " pass by") if not seen.is_empty() else "nobody stirred"],
	}


func generate_bluff_reading(w, n, plan: Dictionary, s: String, _mate, asked: Array) -> Dictionary:
	var block: String = asked[0] if not asked.is_empty() else w.by_id[s].home_block
	var seen: Array = []
	for k in n.intel:
		var it: Dictionary = n.intel[k]
		if it["kind"] == "walker" and it.get("night", -1) == w.day and it.get("block", "") == block and w.by_id[it["about"]].alive:
			if not (it["about"] in seen):
				seen.append(it["about"])
	var why: String = ""
	if not (s in seen) and w.day >= 1 and w.by_id[s].home_block == block:
		seen.append(s)
		why = "watches scapegoat's block; adds fake sighting of %s to true ones" % s
	else:
		why = "reports walkers it knows of on scapegoat's block, hiding teammates"
	plan["fake_watch"][str(w.day)] = block
	var entry: Dictionary = {
		"data": {"block": block, "seen": seen},
		"text": "I watched %s: %s" % [content().block_name(block),
			("I saw " + w._names(seen) + " pass by") if not seen.is_empty() else "nobody stirred"],
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(_w, _n, dd, s: String, sg, _d, _goods: Array, _other: Callable, e: Dictionary, _demon_implicated: bool) -> Dictionary:
	e["data"] = {"block": dd.home_block, "seen": [s]}
	e["text"] = "I watched %s: I saw %s pass by" % [content().block_name(dd.home_block), sg.name]
	return {"entry": e, "why": "the dead Night Watch %s saw scapegoat %s on their last watch" % [dd.id, s], "frames": true}
