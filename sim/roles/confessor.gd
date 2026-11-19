## Confessor role definition and simulation hooks.
##
## Shape: CONFESSOR (each night from Night 1, visits one living person in secret
## and learns whether their spirit is good. Evil souls and Marked souls return no
## memory of the visit: "forgot": true). Night-walker (night_walk: true). Cannot announce
## targets; visited person is unaware. Visit resolves before demon kills.
extends "res://sim/role_def.gd"

var request_refuse_line: String = ""


func _init() -> void:
	id = "confessor"
	display_name = "Confessor"
	align = "good"
	kind = "info"
	tags = ["ongoing_info", "evil_id", "night_walker"]
	min_gift_day = 1
	night_walk = true
	marked_registers = true
	desc = "Each night (not the first), visits one living person in secret and learns whether their spirit is good. Evil souls (and Marked souls) return no memory of the visit."
	shape = "CONFESSOR"
	request_refuse_line = "The confessional is secret and inviolable; I can take no direction on whose door I visit."


func is_valid_gift_time(observed_at: Dictionary) -> bool:
	return int(observed_at.get("day", -1)) >= min_gift_day and str(observed_at.get("phase", "")) == "night"


func is_ongoing_info() -> bool:
	return true


func pick_targets(w, n, _mind):
	var candidates: Array = w.living().filter(func(m): return m != n)
	if candidates.is_empty():
		return ""
	var visited: Array = n.confessor_visited
	var unvisited: Array = candidates.filter(func(m): return not (m.id in visited))
	var chosen = w.pick(unvisited) if not unvisited.is_empty() else w.pick(candidates)
	if chosen == null:
		return ""
	if not (chosen.id in visited):
		visited.append(chosen.id)
	return chosen.id


func score_gift_request(_w, _n, _targets: Array, _top: String, parts: Dictionary, _mind) -> void:
	parts["confessor_secret"] = -9999.0


func counter_gift_request(_w, _n, _targets: Array, _top: String) -> String:
	return request_refuse_line


func short_text(d: Dictionary, _src: String, nm: Callable) -> String:
	if bool(d.get("forgot", false)):
		return "Forgot the visit"
	return "%s: good" % nm.call(str(d.get("target", "")))


func _spoken_text(d: Dictionary, nm: Callable) -> String:
	if bool(d.get("forgot", false)):
		return "I heard a confession in the dark hours, but I cannot remember who came to me"
	return "I heard %s's confession: their heart was pure and their spirit good" % nm.call(str(d.get("target", "")))


func generate_reading(w, n, ctx: Dictionary, _mind) -> Dictionary:
	if w.day < min_gift_day:
		return {}
	var target_id: String = ctx.get("confessor_t", "")
	if target_id == "" or not w.by_id.has(target_id):
		return {}
	var target = w.by_id[target_id]
	var broken: bool = n.gift_broken()
	var is_evil: bool = target.is_evil()
	var reg_evil: bool = is_evil
	var marked_triggered: bool = false

	# One roll, as everywhere else (World.registers_evil already rolls the Marked chance).
	if target.secret_mod == "marked" and not is_evil and w.registers_evil(target):
		reg_evil = true
		marked_triggered = true

	var forgot: bool = reg_evil
	var why: String = ""

	if broken:
		why = "poisoned" if n.poisoned else "delusional"
		if not is_evil:
			forgot = true
		else:
			if target.claimed_role != "" and not w.chance(0.4):
				forgot = false
			else:
				forgot = true
	elif marked_triggered:
		why = "a Marked soul reads as evil"

	var data: Dictionary = {}
	if forgot:
		data = {"forgot": true}
	else:
		data = {"target": target.id, "good": true}

	var nm = func(id: String) -> String:
		return w.by_id[id].name if w.by_id.has(id) else id
	# Measured against the truth: a Marked soul read as evil (no memory) is a false reading.
	var is_true: bool = (forgot == is_evil)
	var entry: Dictionary = {
		"data": data,
		"true": is_true,
		"text": _spoken_text(data, nm),
	}
	if why != "":
		entry["why"] = why
	return entry


## A remembered confession speaks for the confessed: their spirit is good.
func clears(d: Dictionary) -> Array:
	if bool(d.get("forgot", false)) or str(d.get("target", "")) == "":
		return []
	return [str(d.get("target", ""))]


func uses_night_duty_alibi(_w, n, _nd: int, was_out: bool) -> bool:
	return (n.claim_public or n.max_tier >= 3) and ((n.role == "confessor" and was_out) or n.is_evil())


func night_duty_alibi(_w, n, nd: int, was_out: bool, block: String, mind, block_name_fn: Callable) -> Dictionary:
	if not uses_night_duty_alibi(_w, n, nd, was_out):
		return {}
	return {
		"handled": true,
		"line": mind.say_voiced(n, "duty_confessor", "I was abroad hearing a confession on %s." % block_name_fn.call(block), {"block": block_name_fn.call(block)}),
		"fact": {
			"kind": "alibi",
			"subject": [n.id],
			"home": false,
			"day": nd,
			"phase": 3,
			"source": n.id,
			"duty": "confession",
			"block": block,
			"text": "%s says they were abroad hearing a confession on %s on night %d." % [n.name, block_name_fn.call(block), nd],
		},
		"vantage": block,
		"how": "street",
	}


func pressed_night_line(_w, _n, fact: Dictionary, _night: int, when: String, alternate: bool, block_name_fn: Callable) -> String:
	var bname: String = block_name_fn.call(fact.get("block", ""))
	return ("I was abroad hearing a confession on %s %s; my account stands." if alternate else "I was abroad hearing a confession on %s %s.") % [bname, when]


func pressed_night_slots(_w, _n, fact: Dictionary, _night: int, when: String, block_name_fn: Callable) -> Dictionary:
	return {"block": block_name_fn.call(fact.get("block", "")), "when": when}


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, mate, _asked: Array) -> Dictionary:
	if w.day < min_gift_day:
		return {}
	var nm = func(id: String) -> String:
		return w.by_id[id].name if w.by_id.has(id) else id
	var data: Dictionary = {}
	var why: String = ""
	# Michael, Nov 18: a Minion tries to vouch for its Demon; a Demon or Scion tilts toward
	# blending in, by vouching for a good soul the town already trusts.
	# Each soul once: the same name night after night would give it away.
	var Evil = load("res://sim/evil.gd")
	var vouched: Array = []
	for e in n.info_log:
		if e.get("fake", false) and e.get("role", "") == "confessor" and e.get("data", {}).has("target"):
			vouched.append(str(e["data"]["target"]))
	var demon = w.by_id.get(w.demon_id)
	var trusted = Evil.most_trusted_good(w, [n.id, s] + vouched)
	if not Evil.blends_in(w, n) and demon != null and demon != n and demon.alive and not (demon.id in vouched):
		data = {"target": demon.id, "good": true}
		why = "cleared %s, its Demon, as good" % demon.id
	elif Evil.blends_in(w, n) and trusted != null and w.chance(1.0 - Tuning.Evil.BLUFF_BLEND_PROB):
		data = {"target": trusted.id, "good": true}
		why = "vouched for %s, a good soul the town trusts, to pass as an honest Confessor" % trusted.id
	elif mate != null and mate != n and mate.alive and not (mate.id in vouched):
		data = {"target": mate.id, "good": true}
		why = "cleared %s, a fellow evil, as good" % mate.id
	elif w.chance(0.5):
		data = {"forgot": true}
		why = "claimed to have forgotten whom they visited"
	else:
		var goods: Array = w.living_good().filter(func(m): return m.id != s and m != n and not (m.id in vouched))
		var tgt = w.pick(goods) if not goods.is_empty() else null
		if tgt != null:
			data = {"target": tgt.id, "good": true}
			why = "vouched for %s, to seem like any other Confessor" % tgt.id
		else:
			data = {"forgot": true}
			why = "claimed to have forgotten whom they visited"
	var entry: Dictionary = {
		"data": data,
		"text": _spoken_text(data, nm),
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(w, _n, dd, _s: String, _sg, d, _goods: Array, _other: Callable, e: Dictionary, demon_implicated: bool) -> Dictionary:
	var nm = func(id: String) -> String:
		return w.by_id[id].name if w.by_id.has(id) else id
	var data: Dictionary = {}
	var why: String = ""
	if d != null and d.alive and demon_implicated and w.chance(0.6):
		data = {"target": d.id, "good": true}
		why = "made up a reading from the late Confessor %s that cleared %s, the Demon" % [dd.id, d.id]
	else:
		data = {"forgot": true}
		why = "made up a reading from the late Confessor %s that couldn't remember their last visit" % dd.id
	e["data"] = data
	e["text"] = _spoken_text(data, nm)
	return {"entry": e, "why": why, "frames": false}
