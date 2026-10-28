## Lamplighter role definition and simulation hooks.
##
## Shape: GROUP_COUNT (walkers mode: each night, walks the lamp route through every
## block and learns how many other people were out).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "lamplighter"
	display_name = "Lamplighter"
	align = "good"
	kind = "info"
	night_walk = true
	desc = "Each night, walks the lamp route and learns how many other people were out."
	shape = "GROUP_COUNT"
	count_mode = "walkers"


func short_text(d: Dictionary, src: String, _nm: Callable) -> String:
	return "%s Lamplighter: %d others out" % [src, d.get("count", 0)]


func generate_reading(w, n, ctx: Dictionary, _mind) -> Dictionary:
	if ctx.get("lamp", null) != n:
		return {}
	var broken: bool = n.gift_broken()
	var count: int = w.night_walkers.filter(func(wk): return wk["id"] != n.id).size()
	var truth: int = count
	if broken:
		count = w._other_than(truth, 0, maxi(3, w.living().size() - 1))
	return {
		"data": {"count": count},
		"true": count == truth,
		"text": "walking the lamps, I counted %d other%s out" % [count, "" if count == 1 else "s"],
	}


func generate_bluff_reading(w, _n, _plan: Dictionary, _s: String, _mate, _asked: Array) -> Dictionary:
	var cnt: int = clampi(w.night_walkers.size() + w.pick([-1, 0, 1]), 0, w.living().size() - 1)
	var why: String = "guesses a plausible count of walkers (%d)" % cnt
	var entry: Dictionary = {
		"data": {"count": cnt},
		"text": "walking the lamps, I counted %d other%s out" % [cnt, "" if cnt == 1 else "s"],
	}
	return {"entry": entry, "why": why}


func public_sighting_allowed(w, n, b: Dictionary) -> bool:
	var where: String = n.history.get(w.time_key(b.day, 3), "home:" + n.home_block)
	return b.block == (where.trim_prefix("night:") if where.begins_with("night:") else n.home_block)


func uses_night_duty_alibi(_w, n, _nd: int, was_out: bool) -> bool:
	return (n.claim_public or n.max_tier >= 3) and ((n.role == "lamplighter" and was_out) or n.is_evil())


func night_duty_alibi(w, n, nd: int, was_out: bool, block: String, mind, block_name_fn: Callable) -> Dictionary:
	if not uses_night_duty_alibi(w, n, nd, was_out):
		return {}
	if n.is_evil():
		block = block if was_out else n.home_block
		w.dlog.think(n.id, "lie", "Evil bluffing %s: claims their gift took them out on night %d." % [n.claimed_role, nd], {"lie": true})
	return {
		"handled": true,
		"line": mind.say(n, "Walking the lamp route, as I do every night."),
		"fact": {
			"kind": "sighting",
			"subject": [n.id],
			"block": block,
			"day": nd,
			"phase": 3,
			"source": n.id,
			"duty_claim": true,
			"duty": "lamplighter",
			"text": "%s says they were out on %s on night %d (the lamp route)." % [n.name, block_name_fn.call(block), nd],
		},
		"vantage": block,
		"how": "street",
	}


func pressed_night_line(_w, _n, _fact: Dictionary, _night: int, when: String, alternate: bool, _block_name_fn: Callable) -> String:
	return ("My lamp route still accounts for my being out %s." if alternate else "I was out on my lamp route %s. I haven't changed that account.") % when
