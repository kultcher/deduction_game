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
	tags = ["ongoing_info", "evil_id", "role_id", "targeted_role_id", "execution"]
	desc = "Each night after an execution, learns the true role of the executed."
	shape = "ROLE_IN_GROUP"
	role_group_key = "executed"
	role_target_pool = "any"
	marked_registers = true
	requires_execution = true


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	return "%s Gravedigger: %s was %s" % [src, nm.call(d.get("executed", "")), content().role_name(d.get("role", ""))]


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	if w.executed_today == "":
		return {}
	var broken: bool = n.gift_broken()
	var C = content()
	var ex = w.by_id[w.executed_today]
	var role: String = ex.role
	var entry: Dictionary = {}
	if ex.secret_mod == "marked" and w.chance(Tuning.Roles.GRAVEDIGGER.marked_evil_chance):
		role = w.pick(w.case_script.demons + w.case_script.minions)
		entry["why"] = "Marked reads as evil"
	if broken:
		role = w.pick(C.ROLES.keys().filter(func(x): return x != ex.role and not C.is_demon(x) and x != "hearthwitch"))
	entry["data"] = {"executed": ex.id, "role": role}
	entry["true"] = role == ex.role
	entry["text"] = "I learned that %s, whom we hanged, was the %s" % [ex.name, C.role_name(role)]
	return entry


## How sure the town was that `id` was evil, from the vote that hanged them: 0 at a bare
## majority of the votes cast, 1 at unanimity. Votes are public, so evil can read them.
static func town_certainty(w, id: String) -> float:
	for i in range(w.executions.size() - 1, -1, -1):
		var ex: Dictionary = w.executions[i]
		if str(ex.get("id", "")) != id:
			continue
		var yes: int = ex.get("yes", []).size() + (1 if ex.get("player_yes", false) else 0)
		var no: int = ex.get("no", []).filter(func(v): return v != id).size()
		if yes + no <= 0:
			return 0.5
		return clampf((float(yes) / float(yes + no) - 0.5) * 2.0, 0.0, 1.0)
	return 0.5


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
	else:
		# What the town believed of them, from the vote that hanged them (public).
		var sure: float = town_certainty(w, ex.id)
		var conf: float = _n.traits.get("confidence", 0.5)
		var p_frame: float = clampf(Tuning.Evil.GRAVEDIGGER_FRAME_BASE + Tuning.Evil.GRAVEDIGGER_FRAME_CONF * conf + Tuning.Evil.GRAVEDIGGER_FRAME_SURE * sure, 0.0, 1.0)
		var minions: Array = w.case_script.minions
		if not minions.is_empty() and w.decision_roll(_n, "gravedigger_frame", p_frame, {"town_certainty": sure, "confidence": conf}, ex.id):
			role = w.pick(minions)
			why = "frames executed good NPC as a Minion (town certainty %.2f)" % sure
		elif ex.claimed_role != "" and ex.claimed_role != "none":
			role = ex.claimed_role
			why = "confirms executed good NPC's own claim (town certainty %.2f)" % sure
		else:
			role = w.pick(w.case_script.town)
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
		var pool: Array = w.case_script.minions.filter(func(m): return m != "breathstealer" or w.living_with_role("breathstealer") != null)
		rl = w.pick(pool)
	e["data"] = {"executed": ex.id, "role": rl}
	e["text"] = "I learned that %s, whom we hanged, was the %s" % [ex.name, C.role_name(rl)]
	return {"entry": e, "why": "the dead Gravedigger %s 'learned' %s was the %s" % [dd.id, ex.id, rl], "frames": not ex.is_evil()}
