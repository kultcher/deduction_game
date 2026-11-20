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


## The Gravedigger's gift reads the hanged, so it is at its best when someone is hanged every
## day. A good Gravedigger always leans a little toward a hanging, as a hidden motive (Michael,
## Nov 17 and Nov 21): logged with its reason, never said. These are real people, so the lean
## is small. It doesn't depend on whether the gift is broken, which the Gravedigger can't know.
func _wants_a_hanging(n) -> bool:
	return n.role == "gravedigger" and not n.is_evil()


func nomination_lean(_w, n) -> float:
	return Tuning.Roles.GRAVEDIGGER.hanging_lean if _wants_a_hanging(n) else 0.0


func score_vote_reluctance(_w, v, _nominee: String, _base: float, _panic: float, parts: Dictionary) -> void:
	if _wants_a_hanging(v):
		parts["gravedigger_wants_hanging"] = Tuning.Roles.GRAVEDIGGER.hanging_lean


func short_text(d: Dictionary, _src: String, nm: Callable) -> String:
	return "Hanged %s = %s" % [nm.call(d.get("executed", "")), content().role_name(d.get("role", ""))]


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
		entry["why"] = "a Marked soul reads as evil"
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
		# The player always votes (World.vote_pending): player_yes false is a no.
		var player_yes: bool = bool(ex.get("player_yes", false))
		var yes: int = ex.get("yes", []).size() + (1 if player_yes else 0)
		var no: int = ex.get("no", []).filter(func(v): return v != id).size() + (0 if player_yes else 1)
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
	# A hanged teammate: blending in or disruption (Michael, Nov 18; Evil.blend_chance).
	# Blending names the teammate's true role, as an honest Gravedigger would; disruption
	# covers its false claim. A hanged good soul keeps the frame roll below.
	if ex.is_evil():
		var Evil = load("res://sim/evil.gd")
		var first: bool = not _n.info_log.any(func(e): return e.get("fake", false) and e.get("role", "") == "gravedigger")
		if w.chance(Evil.blend_chance(w, _n, first)):
			role = ex.role
			why = "named their hanged fellow evil %s as the %s, to pass as an honest Gravedigger" % [ex.id, content().role_name(role)]
		else:
			role = plan["bluffs"][ex.id]
			why = "covered for their hanged fellow evil as the %s they had claimed" % content().role_name(role)
	else:
		# What the town believed of them, from the vote that hanged them (public).
		var sure: float = town_certainty(w, ex.id)
		var conf: float = _n.traits.get("confidence", 0.5)
		var p_frame: float = clampf(Tuning.Evil.GRAVEDIGGER_FRAME_BASE + Tuning.Evil.GRAVEDIGGER_FRAME_CONF * conf + Tuning.Evil.GRAVEDIGGER_FRAME_SURE * sure, 0.0, 1.0)
		var minions: Array = w.case_script.minions
		if not minions.is_empty() and w.decision_roll(_n, "gravedigger_frame", p_frame, {"town_certainty": sure, "confidence": conf}, ex.id):
			role = w.pick(minions)
			why = "named %s, hanged and good, as a Minion" % ex.id
		elif ex.claimed_role != "" and ex.claimed_role != "none":
			role = ex.claimed_role
			why = "confirmed the hanged %s's true claim, to seem honest" % ex.id
		else:
			role = w.pick(w.case_script.town)
			why = "guessed a good gift for the hanged %s" % ex.id
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
	return {"entry": e, "why": "made up a reading from the late Gravedigger %s that %s was the %s" % [dd.id, ex.id, content().role_name(rl)], "frames": not ex.is_evil()}


## Another role for the hanged: their own claim, or a good role on the script
## (FabricationCheck: a better lie).
func bluff_alternatives(w, _n, _plan: Dictionary, _s: String, _mate, entry: Dictionary) -> Array:
	var d: Dictionary = entry.get("data", {})
	var ex_id: String = str(d.get("executed", ""))
	if not w.by_id.has(ex_id):
		return []
	var ex = w.by_id[ex_id]
	var cur: String = str(d.get("role", ""))
	var roles: Array = []
	if ex.claimed_role != "" and ex.claimed_role != "none" and ex.claimed_role != cur:
		roles.append(ex.claimed_role)
	for r in w.case_script.town:
		if r != cur and not (r in roles):
			roles.append(r)
	var out: Array = []
	for r in roles:
		out.append({"entry": {"data": {"executed": ex_id, "role": r}, "text": "I learned that %s, whom we hanged, was the %s" % [ex.name, content().role_name(r)]},
			"why": ("confirms %s's own claim, %s" if r == ex.claimed_role else "names %s the %s") % [ex_id, r]})
	# Their own claim first, if they made one; then a few good roles.
	var claim: Array = out.slice(0, 1) if (ex.claimed_role != "" and ex.claimed_role != "none" and ex.claimed_role != cur) else []
	return claim + cap_alternatives(w, out.slice(claim.size()), 6 - claim.size())
