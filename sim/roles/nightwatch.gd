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


## An evil member's made-up Night Watch report for night `nd`, or `{}`.
func fake_watch_entry(n, nd: int) -> Dictionary:
	for e in n.info_log:
		if e.get("fake", false) and e.get("role", "") == "nightwatch" and e.get("day", -1) == nd:
			return e
	return {}


func check_public_sighting_pregate(_w, n, b: Dictionary, mind) -> int:
	for e in n.info_log:
		if e.get("role", "") == "nightwatch" and e.get("day", -1) == b.day and not mind.reading_disclosed(n, e):
			return -1
	if n.is_evil():
		var story: Dictionary = fake_watch_entry(n, b.day)
		return 1 if (not story.is_empty() and b.block == story.data.block and b.who in story.data.get("seen", [])) else -1
	return 0


func uses_night_duty_alibi(w, n, nd: int, was_out: bool) -> bool:
	if n.is_evil():
		return w.evil_plan["fake_watch"].has(str(nd))
	return was_out and n.role == "nightwatch" and n.claimed_role == "nightwatch"


func night_duty_alibi(w, n, nd: int, was_out: bool, block: String, mind, block_name_fn: Callable) -> Dictionary:
	if not uses_night_duty_alibi(w, n, nd, was_out):
		return {}
	var watch_b: String = block
	if n.is_evil():
		watch_b = w.evil_plan["fake_watch"][str(nd)]
		var where: String = n.history.get(w.time_key(nd, 3), "home:" + n.home_block)
		w.dlog.think(n.id, "lie", "Evil bluffing Night Watch: claims to have watched %s (actually %s)." % [watch_b, where], {"lie": true})
	return {
		"handled": true,
		"line": mind.say(n, "Keeping watch over %s, as is my duty." % block_name_fn.call(watch_b)),
		"fact": {
			"kind": "sighting",
			"subject": [n.id],
			"block": watch_b,
			"day": nd,
			"phase": 3,
			"source": n.id,
			"watch_claim": true,
			"text": "%s says they kept watch on %s on night %d." % [n.name, block_name_fn.call(watch_b), nd],
		},
		"vantage": watch_b,
		"how": "street",
	}


func withholds_night_sightings(n, nd: int, mind) -> String:
	for e in n.info_log:
		if e.get("role", "") == "nightwatch" and e.get("day", -1) == nd and not mind.reading_disclosed(n, e):
			return "Where I kept watch is one thing. Who I saw there, I'm not ready to share."
	return ""


func override_night_sightings(w, n, nd: int) -> Dictionary:
	if not n.is_evil():
		return {}
	var watch_story: Dictionary = fake_watch_entry(n, nd)
	if watch_story.is_empty():
		return {}
	var reported: Array = []
	for x in watch_story["data"].get("seen", []):
		if x != n.id and w.by_id.has(x):
			reported.append({"kind": "saw", "who": x, "loc": "", "block": watch_story["data"]["block"], "day": nd, "phase": 3, "how": "street", "detail": "street"})
	w.dlog.think(n.id, "lie", "Evil bluffing Night Watch: night-%d sightings match the fake watch report (%s)." % [nd, ", ".join(PackedStringArray(watch_story["data"].get("seen", [])))])
	return {"handled": true, "reported": reported}


func pressed_night_line(_w, _n, fact: Dictionary, _night: int, when: String, alternate: bool, block_name_fn: Callable) -> String:
	return ("I was keeping watch on %s %s; my account stands." if alternate else "My watch took me through %s %s. That's where I was.") % [block_name_fn.call(fact.block), when]
