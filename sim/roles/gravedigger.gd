## Gravedigger role definition and simulation hooks.
##
## Shape: ROLE_IN_GROUP ({executed, role}) — each night after an execution, learns the
## true role of the executed (a Marked executed townsfolk reads as an evil role 30% of the time).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "gravedigger"
	display_name = "Gravedigger"
	align = "good"
	kind = "info"
	desc = "Each night after an execution, learns the true role of the executed."
	shape = "ROLE_IN_GROUP"
	role_group_key = "executed"
	role_target_pool = "any"
	marked_registers = true
	requires_execution = true


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	return "%s Gravedigger: %s was %s" % [src, nm.call(d.get("executed", "")), content().role_name(d.get("role", ""))]


func card_strength(_d: Dictionary, _suspect_id: String) -> float:
	return 0.3


func info_effects(w, listener, source, entry: Dictionary, weight: float, fresh: bool, mind) -> Array:
	var effs: Array = []
	var d: Dictionary = entry["data"]
	var own: bool = source == listener
	var tag: String = "own info" if own else "heard %s's info (w=%.2f)" % [source.id, weight]
	var ex = w.by_id[d["executed"]]
	var ex_good: bool = content().ROLES[d["role"]]["align"] == "good"
	if ex.id != listener.id:
		# "X was evil" (or good) is evidence about X like any other; X's credibility
		# follows from it in recompute_beliefs, not from a role-specific rule.
		mind._eff(effs, ex.id, 1.0 if not ex_good else -0.4, tag + ": %s was the %s" % [ex.id, d["role"]], "", false)
	for e in w.executions:
		if e["id"] == ex.id:
			var nom: String = e["nominator"]
			if nom != "" and nom != "player":
				mind._eff(effs, nom, (0.25 if ex_good else -0.2),
					tag + ": nominator of %s, who was %s" % [ex.id, d["role"]],
					"they pushed to hang %s, who was innocent" % ex.name)
			if fresh and not own and weight > 0.2 and (e["player_nominated"] or e["player_yes"]):
				if ex_good:
					mind.set_trust(w, listener, listener.trust - 0.06, "the Demonologist backed hanging %s, an innocent" % ex.id)
				else:
					mind.set_trust(w, listener, listener.trust + 0.08 + 0.06 * mind.trait_of(listener, "insight"),
						"the Demonologist was proven right about %s" % ex.id)
	return effs


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	if w.executed_today == "":
		return {}
	var broken: bool = n.gift_broken()
	var C = content()
	var ex = w.by_id[w.executed_today]
	var role: String = ex.role
	var entry: Dictionary = {}
	if ex.secret_mod == "marked" and w.chance(0.3):
		role = w.pick(C.EVIL_ROLES)
		entry["why"] = "Marked reads as evil"
	if broken:
		role = w.pick(C.ROLES.keys().filter(func(x): return x != ex.role and x != "demon" and x != "hearthwitch"))
	entry["data"] = {"executed": ex.id, "role": role}
	entry["true"] = role == ex.role
	entry["text"] = "I learned that %s, whom we hanged, was the %s" % [ex.name, C.role_name(role)]
	return entry


func generate_bluff_reading(w, _n, plan: Dictionary, _s: String, _mate, _asked: Array) -> Dictionary:
	if w.executed_today == "":
		return {}
	var C = content()
	var ex = w.by_id[w.executed_today]
	var role = ""
	var why = ""
	if ex.is_evil():
		role = plan["bluffs"][ex.id]
		why = "covers executed teammate as their bluff %s" % role
	elif ex.claimed_role != "" and ex.claimed_role != "none":
		role = ex.claimed_role
		why = "confirms executed good NPC's own claim (safe)"
	else:
		role = w.pick(C.GOOD_ROLES)
		why = "guesses a good role for executed NPC"
	var entry: Dictionary = {
		"data": {"executed": ex.id, "role": role},
		"text": "I learned that %s, whom we hanged, was the %s" % [ex.name, C.role_name(role)],
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(w, _n, dd, _s: String, _sg, _d, _goods: Array, _other: Callable, e: Dictionary, _demon_implicated: bool) -> Dictionary:
	var read: Array = dd.info_log.filter(func(x): return x.get("role", "") == "gravedigger").map(func(x): return x["data"].get("executed", ""))
	var hanged: Array = w.npcs.filter(func(x): return not x.alive and x.death_cause == "executed" and not (x.id in read) and x != dd)
	if hanged.is_empty():
		return {}
	var C = content()
	var ex = hanged[0]
	var rl = ""
	if ex.is_evil():
		rl = w.evil_plan["bluffs"].get(ex.id, "")  # a hanged teammate was who they claimed
		if rl == "":
			return {}
	else:
		# A good hanged soul "was a minion": sometimes one that isn't even in the game.
		# Never the Breathstealer unless there is one: its silences would give it away.
		var pool: Array = C.MINION_ROLES.filter(func(m): return m != "breathstealer" or w.living_with_role("breathstealer") != null)
		rl = w.pick(pool)
	e["data"] = {"executed": ex.id, "role": rl}
	e["text"] = "I learned that %s, whom we hanged, was the %s" % [ex.name, C.role_name(rl)]
	return {"entry": e, "why": "the dead Gravedigger %s 'learned' %s was the %s" % [dd.id, ex.id, rl], "frames": not ex.is_evil()}
