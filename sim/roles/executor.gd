## Executor role definition and simulation hooks.
##
## Shape: EXECUTOR ({target, assigned} on night 0; {target, role} the morning after that
## person dies). Marked registers as an evil role 30% of the time on the death reading;
## Delusional or Morning-active Poison corrupts the learned role on the death reading.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "executor"
	display_name = "Executor"
	align = "good"
	kind = "info"
	tags = ["ongoing_info", "evil_id", "role_id", "targeted_role_id"]
	desc = "At case start, learns one person. Should they die, learns their role the next morning."
	shape = "EXECUTOR"
	marked_registers = true


func is_valid_gift_time(observed_at: Dictionary) -> bool:
	var d: int = int(observed_at.get("day", -1))
	var ph: String = str(observed_at.get("phase", ""))
	return (d == 0 and ph == "night") or (d >= 1 and ph == "morning")


func is_ongoing_info() -> bool:
	return true


func gift_live_tonight(w, n) -> bool:
	if n.executor_resolved:
		return false
	if n.executor_target == "":
		return true
	return w.by_id.has(n.executor_target) and w.by_id[n.executor_target].alive


## While the death reading is still to come: the base day-tapered ongoing-info terms;
## once it has resolved, the gift is spent.
func score_public_claim(w, n, parts: Dictionary) -> void:
	if n.executor_resolved:
		parts["one_shot_gift"] = Tuning.Roles.ONE_SHOT_GIFT_CLAIM
	else:
		var ongoing: float = ongoing_info_claim_term(w.day)
		if ongoing != 0.0:
			parts["gift_keeps_giving"] = ongoing


func score_reveal_cost(w, n, parts: Dictionary) -> void:
	if not n.executor_resolved:
		var ongoing: float = ongoing_info_claim_term(w.day)
		if ongoing != 0.0:
			parts["gift_keeps_giving"] = -ongoing


func implicated(d: Dictionary) -> Array:
	if not d.has("role"):
		return []
	var r_align: String = content().ROLES.get(str(d.get("role", "")), {}).get("align", "good")
	var tgt: String = str(d.get("target", ""))
	return [tgt] if (tgt != "" and r_align == "evil") else []


func clears(d: Dictionary) -> Array:
	if not d.has("role"):
		return []
	var r_align: String = content().ROLES.get(str(d.get("role", "")), {}).get("align", "good")
	var tgt: String = str(d.get("target", ""))
	return [tgt] if (tgt != "" and r_align == "good") else []


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	var who: String = nm.call(str(d.get("target", "")))
	if d.has("role"):
		return "%s Executor: %s was %s" % [src, who, content().role_name(str(d.get("role", "")))]
	return "%s Executor: charge %s" % [src, who]


func _assigned_text(tgt_name: String) -> String:
	return "I was named Executor for %s; if they die, I will learn what they were" % tgt_name


func _role_text(tgt_name: String, role_id: String) -> String:
	return "As Executor for %s, I learned upon their death that they were the %s" % [tgt_name, content().role_name(role_id)]


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	if w.day != 0:
		return {}
	var others: Array = w.npcs.filter(func(m): return m != n)
	if others.is_empty():
		return {}
	var tgt = w.pick(others)
	n.executor_target = tgt.id
	n.executor_resolved = false
	return {
		"data": {"target": tgt.id, "assigned": true},
		"true": true,
		"text": _assigned_text(tgt.name),
	}


func run_morning_gift(w, n) -> bool:
	if w.day < 1 or w.phase != content().MORNING or n == null or not n.alive or n.is_evil():
		return false
	if n.executor_resolved or n.executor_target == "" or not w.by_id.has(n.executor_target):
		return false
	var ex = w.by_id[n.executor_target]
	if ex.alive:
		return false
	n.executor_resolved = true
	var C = content()
	var broken: bool = n.gift_broken()
	var true_role: String = "scion" if ex.id == w.scion_rose and ex.death_cause != "executed" else ex.role
	# Note: if `ex` was the promoted Scion killed later (impossible while Demon lives unless
	# executed ending the game), `ex.role` is `"demon"`; if `ex` was the original Demon who
	# hung when Scion promoted, `ex.role` is `"demon"`.
	true_role = ex.role
	var role: String = true_role
	var entry: Dictionary = {}
	if ex.secret_mod == "marked" and w.chance(Tuning.Roles.GRAVEDIGGER.marked_evil_chance):
		role = w.pick(w.case_script.demons + w.case_script.minions)
		entry["why"] = "Marked reads as evil"
	if broken:
		var pool: Array = (w.case_script.town + w.case_script.demons + w.case_script.minions).filter(
			func(x): return x != true_role and x != "executor" and x != "hearthwitch"
		)
		if not pool.is_empty():
			role = w.pick(pool)
	entry["data"] = {"target": ex.id, "role": role}
	entry["true"] = (role == true_role)
	entry["text"] = _role_text(ex.name, role)
	w._add_info(n, entry)
	return true


func generate_bluff_reading(w, n, plan: Dictionary, s: String, mate, _asked: Array) -> Dictionary:
	if w.day != 0:
		return {}
	var others: Array = w.npcs.filter(func(m): return m != n)
	if others.is_empty():
		return {}
	var goods: Array = others.filter(func(m): return not m.is_evil() and m.id != s)
	var tgt = mate if (mate != null and mate != n and w.chance(0.35)) else w.pick(goods if not goods.is_empty() else others)
	plan["executor_bluff_target_" + n.id] = tgt.id
	plan["executor_bluff_resolved_" + n.id] = false
	var entry: Dictionary = {
		"data": {"target": tgt.id, "assigned": true},
		"text": _assigned_text(tgt.name),
	}
	return {"entry": entry, "why": "names %s as Executor charge" % tgt.id}


func run_morning_bluff(w, n) -> bool:
	if w.day < 1 or w.phase != content().MORNING or n == null or not n.alive or not n.is_evil():
		return false
	var plan: Dictionary = w.evil_plan
	if str(plan.get("bluffs", {}).get(n.id, "")) != "executor":
		return false
	if bool(plan.get("executor_bluff_resolved_" + n.id, false)):
		return false
	var shared_assign: bool = n.info_log.any(
		func(e): return e.get("role", "") == "executor" and bool(e.get("data", {}).get("assigned", false)) and bool(e.get("shared", false))
	)
	var cur_t: String = str(plan.get("executor_bluff_target_" + n.id, ""))
	var fresh_dead: Array = w.npcs.filter(func(m): return m != n and not m.alive and int(m.death_day) == w.day - 1)
	if fresh_dead.is_empty():
		return false
	var ex = null
	if cur_t != "" and w.by_id.has(cur_t) and w.by_id[cur_t] in fresh_dead:
		ex = w.by_id[cur_t]
	elif not shared_assign and w.chance(0.65):
		ex = w.pick(fresh_dead)
		# Keep any unshared Night 0 bluff charge consistent with the corpse they now claim.
		for prev in n.info_log:
			if prev.get("fake", false) and prev.get("role", "") == "executor" and bool(prev.get("data", {}).get("assigned", false)) and not bool(prev.get("shared", false)):
				prev["data"]["target"] = ex.id
				prev["text"] = _assigned_text(ex.name)
	if ex == null:
		return false
	plan["executor_bluff_target_" + n.id] = ex.id
	plan["executor_bluff_resolved_" + n.id] = true
	var role: String = ""
	var why: String = ""
	if ex.is_evil():
		role = str(plan.get("bluffs", {}).get(ex.id, ""))
		if role == "":
			role = w.pick(w.case_script.town.filter(func(r): return r != "executor"))
		why = "covers dead teammate %s as their bluff %s" % [ex.id, role]
	elif ex.death_cause == "executed" and w.chance(0.5):
		var mpool: Array = w.case_script.minions.filter(func(m): return m != "breathstealer" or w.living_with_role("breathstealer") != null)
		role = w.pick(mpool) if not mpool.is_empty() else w.pick(w.case_script.town)
		why = "frames hanged townsfolk %s as %s" % [ex.id, role]
	elif ex.claimed_role != "" and ex.claimed_role != "none" and ex.claimed_role != "executor":
		role = ex.claimed_role
		why = "confirms dead %s's own claim %s" % [ex.id, role]
	else:
		var tpool: Array = w.case_script.town.filter(func(r): return r != "executor")
		role = w.pick(tpool) if not tpool.is_empty() else "clerk"
		why = "guesses good role %s for dead %s" % [role, ex.id]
	var entry: Dictionary = {
		"day": w.day,
		"phase": content().MORNING,
		"role": "executor",
		"shared": false,
		"true": false,
		"fake": true,
		"why": "evil fabrication: " + why,
		"data": {"target": ex.id, "role": role},
		"text": _role_text(ex.name, role),
	}
	n.info_log.append(entry)
	w.dlog.add("fake_info", n.id, "", entry, "%s (evil, bluffing executor) prepares: %s [%s]" % [n.name, entry["text"], why])
	return true


func fake_medium_reading(w, _n, dd, s: String, _sg, _d, _goods: Array, _other: Callable, e: Dictionary, _demon_implicated: bool) -> Dictionary:
	var C = content()
	var prior_dead: Array = w.npcs.filter(func(x): return x != dd and not x.alive and int(x.death_day) >= 0 and int(x.death_day) < int(dd.death_day))
	if not prior_dead.is_empty():
		var ex = prior_dead[0]
		var rl: String = ""
		if ex.is_evil():
			rl = str(w.evil_plan.get("bluffs", {}).get(ex.id, ""))
			if rl == "":
				return {}
		else:
			var pool: Array = w.case_script.minions.filter(func(m): return m != "breathstealer" or w.living_with_role("breathstealer") != null)
			if pool.is_empty():
				return {}
			rl = w.pick(pool)
		e["day"] = int(ex.death_day) + 1
		e["phase"] = C.MORNING
		e["data"] = {"target": ex.id, "role": rl}
		e["text"] = _role_text(ex.name, rl)
		return {"entry": e, "why": "the dead Executor %s 'learned' %s was the %s" % [dd.id, ex.id, rl], "frames": not ex.is_evil()}
	var cands: Array = w.npcs.filter(func(x): return x != dd)
	if cands.is_empty():
		return {}
	var pick_t = w.by_id[s] if (s != "" and s != dd.id and w.by_id.has(s)) else w.pick(cands)
	e["day"] = 0
	e.erase("phase")
	e["data"] = {"target": pick_t.id, "assigned": true}
	e["text"] = _assigned_text(pick_t.name)
	return {"entry": e, "why": "the dead Executor %s had %s as their charge" % [dd.id, pick_t.id], "frames": false}
