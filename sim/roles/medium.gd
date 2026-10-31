## Medium role definition and simulation hooks.
##
## Shape: ROLE_AT_SITE (hearth_relay mode: each night after the first Demon kill, visits
## an unvisited Demon victim's hearth or revisits the most recent victim, learning one
## unshared piece of knowledge they held).
extends "res://sim/role_def.gd"

static var _gifts_script
static var _evil_script


static func _gifts():
	if _gifts_script == null:
		_gifts_script = load("res://sim/gifts.gd")
	return _gifts_script


static func _evil():
	if _evil_script == null:
		_evil_script = load("res://sim/evil.gd")
	return _evil_script


func _init() -> void:
	id = "medium"
	display_name = "Medium"
	align = "good"
	kind = "info"
	night_walk = true
	desc = "Each night after the first Demon kill, visits an unvisited Demon victim's hearth, or revisits the most recent victim. Learns something they knew but never shared, if anything new remains."
	shape = "ROLE_AT_SITE"
	site_mode = "hearth_relay"


func implicated(d: Dictionary) -> Array:
	var it: Dictionary = d.get("item", {})
	match it.get("type", ""):
		"reading":
			return _gifts().implicated(it["entry"])
		"sighting":
			return [it["who"]]
		"suspicion":
			return [] # Opinions remain opinions when relayed by a gift (Q4).
	return []


func clears(d: Dictionary) -> Array:
	var it: Dictionary = d.get("item", {})
	if it.get("type", "") == "reading":
		return _gifts().clears(it["entry"])
	return []


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	var it: Dictionary = d.get("item", {})
	var dead: String = nm.call(d.get("dead", ""))
	match it.get("type", ""):
		"reading":
			return "%s Medium (%s): %s" % [src, dead, _gifts().short_text(it["entry"]["role"], it["entry"]["data"], dead, nm)]
		"sighting":
			return "%s Medium: %s saw %s out" % [src, dead, nm.call(it.get("who", ""))]
		"suspicion":
			return "%s Medium: %s suspected %s" % [src, dead, nm.call(it.get("about", ""))]
		"home":
			return "%s Medium: %s was home on night %d" % [src, dead, it.get("night", 0)]
		"guard":
			return "%s Medium: %s guarded %s's door on night %d" % [src, dead, nm.call(it.get("who", "")), it.get("night", 0)]
	return "%s Medium: %s had nothing to tell" % [src, dead]


func reading_strength(_d: Dictionary, _t_id: String) -> float:
	return Tuning.Roles.MEDIUM.reading_strength


func info_effects(w, listener, source, entry: Dictionary, weight: float, _fresh: bool, mind) -> Array:
	var effs: Array = []
	var d: Dictionary = entry["data"]
	var own: bool = source == listener
	var tag: String = "own info" if own else "heard %s's info (w=%.2f)" % [source.id, weight]
	var it: Dictionary = d.get("item", {})
	var dead: String = d.get("dead", "")
	match it.get("type", ""):
		"reading":
			var inner: Dictionary = it["entry"]
			var dn = w.by_id.get(dead)
			if dn != null:
				for ef in mind._info_effects(w, listener, dn, inner, weight, false):
					ef[1] = ef[1] * Tuning.Roles.MEDIUM.relay_reading_scale
					effs.append(ef)
		"sighting":
			if it["who"] != listener.id:
				var sc2: float = mind.night_sighting_scale(w, listener, it["who"], it.get("block", ""), it.get("night", -1))
				mind._eff(effs, it["who"], Tuning.Roles.MEDIUM.eff_dead_sighting * sc2, tag + ": the dead %s saw them out at night (x%.2f)" % [dead, sc2],
					"the dead saw them out at night", not own)
		"suspicion":
			pass # A faithfully relayed opinion remains an opinion (Q4).
	return effs


## Public hearth eligibility: Demon victims only; revisit the latest after all are visited.
func pick_targets(w, m, _mind, before_day: int = -1):
	var dead: Array = w.npcs.filter(func(x): return not x.alive and x.death_cause == "demon" and (before_day < 0 or x.death_day < before_day))
	if dead.is_empty():
		return ""
	dead.sort_custom(func(a, b): return a.death_day > b.death_day)
	var unvisited: Array = dead.filter(func(x): return x.id not in m.medium_visited)
	var chosen = unvisited[0] if not unvisited.is_empty() else dead[0]
	if chosen.id not in m.medium_visited:
		m.medium_visited.append(chosen.id)
	w.dlog.think(m.id, "medium_pick", "Medium visits %s's home." % chosen.id)
	return chosen.id


## What the Medium hears from the dead: something they knew and never said in public.
func medium_item(w, m, dead, broken: bool, mind) -> Dictionary:
	var C = content()
	if broken:
		var who = w.pick(w.living().filter(func(x): return x != m))
		return {"type": "sighting", "who": who.id, "block": who.home_block, "night": maxi(0, dead.death_day - 1), "lie": true}
	for e in dead.info_log:
		if not e.get("shared", false) and not e.get("disowned", false) and C.ROLES.get(e.get("role", ""), {}).get("kind", "") == "info":
			e["shared"] = true
			return {"type": "reading", "entry": e.duplicate(true), "lie": e.get("fake", false)}
	for b in dead.beliefs:
		if b["kind"] == "saw" and b["phase"] == C.NIGHT and w.by_id.has(b["who"]) and not dead.told_to.has("medium|" + b["who"]):
			if dead.is_evil() and w.by_id[b["who"]].is_evil():
				continue
			dead.told_to["medium|" + b["who"]] = true
			return {"type": "sighting", "who": b["who"], "block": b["block"], "night": b["day"]}
	# A Warden's doors: whom they guarded, night by night (never said aloud).
	for k in dead.warden_log:
		if not dead.told_to.has("medium|guard:" + str(k)) and w.by_id.has(dead.warden_log[k]):
			dead.told_to["medium|guard:" + str(k)] = true
			return {"type": "guard", "who": dead.warden_log[k], "night": int(k), "lie": dead.is_evil()}
	if dead.is_evil():
		var sg: String = w.evil_plan.get("scapegoat", "")
		if sg != "" and w.by_id[sg].alive and not dead.told_to.has("medium|cover"):
			dead.told_to["medium|cover"] = true
			return {"type": "suspicion", "about": sg, "lie": true}
	else:
		var best = ""
		var bs = Tuning.Roles.MEDIUM.dead_suspicion_min
		for k in dead.suspicion:
			if w.by_id[k].alive and mind.susp(dead, k) > bs:
				bs = mind.susp(dead, k)
				best = k
		if best != "" and not dead.told_to.has("medium|susp:" + best):
			dead.told_to["medium|susp:" + best] = true
			return {"type": "suspicion", "about": best}
	# No untold knowledge remains. A revisit must not invent or repeat a home alibi.
	return {"type": "nothing", "lie": false}


func medium_text(w, dead, it: Dictionary) -> String:
	var C = content()
	match it["type"]:
		"reading":
			return "communing with the dead at %s's hearth, I heard what they never told us: %s" % [dead.name, C.third_person(it["entry"]["text"])]
		"sighting":
			return "communing with the dead at %s's hearth, I learned they saw %s out on %s on night %d" % [dead.name, w.by_id[it["who"]].name, C.block_name(it["block"]), it["night"]]
		"suspicion":
			return "communing with the dead at %s's hearth, I felt their distrust of %s" % [dead.name, w.by_id[it["about"]].name]
		"nothing":
			return "communing with the dead at %s's hearth, I learned nothing they hadn't already told us" % dead.name
		"guard":
			return "communing with the dead at %s's hearth, I learned they stood guard at %s's door on %s" % [dead.name, w.by_id[it["who"]].name, C.night_name(it["night"])]
	return "communing with the dead at %s's hearth, I learned only that they were home on their last night" % dead.name


func generate_reading(w, n, ctx: Dictionary, mind) -> Dictionary:
	var medium_t: String = ctx.get("medium_t", "")
	if medium_t == "":
		return {}
	var broken: bool = n.gift_broken()
	var dead = w.by_id[medium_t]
	var item: Dictionary = medium_item(w, n, dead, broken, mind)
	return {
		"data": {"dead": medium_t, "item": item},
		"true": not broken and not item.get("lie", false),
		"text": medium_text(w, dead, item),
	}


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, _mate, _asked: Array) -> Dictionary:
	# Match the real Medium's public hearth eligibility and revisit policy (INFO_BEFORE_KILL).
	if w.day == 0 or not w.by_id[s].alive:
		return {}
	var cutoff_day: int = w.day if content().INFO_BEFORE_KILL else -1
	var dead_id: String = pick_targets(w, n, null, cutoff_day)
	if dead_id == "":
		return {}
	var dd = w.by_id[dead_id]
	var fk: Dictionary = _evil()._fake_medium_item(w, n, dd, s)
	if fk.is_empty():
		return {}
	var it: Dictionary = fk["item"]
	var entry: Dictionary = {
		"data": {"dead": dd.id, "item": it},
		"text": medium_text(w, dd, it),
	}
	return {"entry": entry, "why": fk["why"]}


## Whose hearth a Medium's reading (real, or an evil bluff's fake) for night `nd` names.
func hearth_dead(w, n, nd: int):
	for e in n.info_log:
		if e.get("role", "") == "medium" and e.get("day", -1) == nd and (e.get("fake", false) == n.is_evil()):
			var dead = w.by_id.get(e.get("data", {}).get("dead", ""))
			if dead != null:
				return dead
	return null


## The block of the hearth an evil Medium bluff's fake reading for night `nd` names ("" if none).
func bluff_hearth(w, n, nd: int) -> String:
	var dead = hearth_dead(w, n, nd)
	return dead.home_block if dead != null and n.is_evil() else ""


func public_sighting_allowed(w, n, b: Dictionary) -> bool:
	return bluff_hearth(w, n, b.day) == b.block


func uses_night_duty_alibi(w, n, nd: int, was_out: bool) -> bool:
	return (n.claim_public or n.max_tier >= 3) and ((n.role == "medium" and was_out) or n.is_evil()) and not (n.is_evil() and bluff_hearth(w, n, nd) == "")


func night_duty_alibi(w, n, nd: int, was_out: bool, block: String, mind, block_name_fn: Callable) -> Dictionary:
	if not uses_night_duty_alibi(w, n, nd, was_out):
		return {}
	if n.is_evil():
		block = bluff_hearth(w, n, nd)
		w.dlog.think(n.id, "lie", "Evil bluffing Medium: claims to have sat at a hearth on %s on night %d." % [block, nd], {"lie": true})
	var hearth = hearth_dead(w, n, nd)
	var duty: String = "Communing with the dead at %s's hearth, as my gift asks." % hearth.name if hearth != null else "Communing with the dead, as my gift asks."
	var duty_line: Dictionary = mind.say_voiced(n, "duty_medium_hearth", duty, {"target": hearth.name}) if hearth != null else mind.say_voiced(n, "duty_medium_plain", duty)
	return {
		"handled": true,
		"line": duty_line,
		"fact": {
			"kind": "sighting",
			"subject": [n.id],
			"block": block,
			"day": nd,
			"phase": 3,
			"source": n.id,
			"duty_claim": true,
			"duty": "medium",
			"text": "%s says they were out on %s on night %d (visiting the dead)." % [n.name, block_name_fn.call(block), nd],
		},
		"vantage": block,
		"how": "street",
	}


func pressed_night_line(w, n, _fact: Dictionary, night: int, when: String, alternate: bool, _block_name_fn: Callable) -> String:
	var dead = hearth_dead(w, n, night)
	var hearth: String = "%s's hearth" % dead.name if dead != null else "the dead"
	return ("My account stands: I was visiting %s %s." if alternate else "My gift took me to %s %s. That is still my account.") % [hearth, when]
