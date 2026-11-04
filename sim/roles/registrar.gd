## Registrar role definition and simulation hooks.
##
## Shape: REGISTRAR (Night 0 slate: {roles: [r0, r1, r2]} drawn from the current script,
## excluding Registrar and Demon, with at most 1 minion at 50% odds and >= 1 role guaranteed
## in play; Night 1+ checks: {roles, target, yes} on one other person, with Marked registering
## as a false Yes 50% of the time when a minion role is on the slate).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "registrar"
	display_name = "Registrar"
	align = "good"
	kind = "info"
	tags = ["first_night_info", "ongoing_info", "role_id"]
	desc = "Starts knowing three roles on the script (at most one minion, never the demon), at least one of which is in play. Each night from night 1, checks one person and learns if they hold one of those roles."
	shape = "REGISTRAR"
	marked_registers = true
	public_threat_bonus = Tuning.Roles.SEER.public_threat_bonus * 0.75
	public_threat_key = "registrar"
	request_agree_line = "Very well. Tonight I'll check %s against my register."
	request_agree_slot = "target"


func is_valid_gift_time(observed_at: Dictionary) -> bool:
	return int(observed_at.get("day", -1)) >= 0 and str(observed_at.get("phase", "")) == "night"


func _roles_short_list(roles: Array) -> String:
	var C = content()
	return ", ".join(PackedStringArray(roles.map(func(r): return C.role_name(str(r)))))


func _roles_prose(roles: Array) -> String:
	var C = content()
	var named: Array = roles.map(func(r): return "the " + C.role_name(str(r)))
	if named.size() == 3:
		return "%s, %s, and %s" % [named[0], named[1], named[2]]
	return ", ".join(PackedStringArray(named))


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	var roles: Array = d.get("roles", [])
	var rlist: String = _roles_short_list(roles)
	if d.has("target"):
		return "%s Registrar: %s in [%s] → %s" % [src, nm.call(str(d.get("target", ""))), rlist, "YES" if bool(d.get("yes", false)) else "no"]
	return "%s Registrar: %s" % [src, rlist]


func implicated(d: Dictionary) -> Array:
	if not d.has("target") or not bool(d.get("yes", false)):
		return []
	var C = content()
	var has_minion: bool = d.get("roles", []).any(func(r): return C.is_minion(str(r)))
	var tgt: String = str(d.get("target", ""))
	return [tgt] if (has_minion and tgt != "") else []


func clears(d: Dictionary) -> Array:
	if not d.has("target") or not bool(d.get("yes", false)):
		return []
	var C = content()
	var has_minion: bool = d.get("roles", []).any(func(r): return C.is_minion(str(r)))
	var tgt: String = str(d.get("target", ""))
	return [tgt] if (not has_minion and tgt != "") else []


func on_reading_heard(listener, source, entry: Dictionary, fresh: bool) -> void:
	if listener != source or not fresh:
		return
	var d: Dictionary = entry.get("data", {})
	if not d.has("target") or not bool(d.get("yes", false)):
		return
	var C = content()
	var has_minion: bool = d.get("roles", []).any(func(r): return C.is_minion(str(r)))
	var tgt: String = str(d.get("target", ""))
	if not has_minion and tgt != "" and tgt != listener.id:
		listener.cleared[tgt] = true


func draw_slate(w, broken: bool = false) -> Array:
	var sc = w.case_script
	var town_pool: Array = sc.town.filter(func(r): return r != "registrar")
	var minion_pool: Array = sc.minions.duplicate()
	var in_good: Array = w.initial_good_roles.filter(func(r): return r != "registrar" and r in town_pool)
	var init_mins: Array = w.initial_minion_ids if not w.initial_minion_ids.is_empty() else w.minion_ids
	var in_minions: Array = []
	for mid in init_mins:
		if w.by_id.has(mid):
			var mr: String = "scion" if mid == w.scion_rose else str(w.by_id[mid].role)
			if mr in minion_pool and not (mr in in_minions):
				in_minions.append(mr)
	var out_good: Array = town_pool.filter(func(r): return not (r in in_good))
	var out_minions: Array = minion_pool.filter(func(r): return not (r in in_minions))
	var use_minion: bool = not minion_pool.is_empty() and town_pool.size() >= 2 and w.chance(0.5)
	var roles: Array = []
	if broken:
		# A Delusional Registrar draws an out-of-play slate whenever the script has enough
		# spare roles, so the Night 0 reading is genuinely false.
		if use_minion and not out_minions.is_empty() and out_good.size() >= 2:
			roles.append(w.pick(out_minions))
			roles.append_array(w.shuffled(out_good).slice(0, 2))
			return w.shuffled(roles)
		if out_good.size() >= 3:
			return w.shuffled(out_good).slice(0, 3)
	if use_minion:
		var m_pick: String = w.pick(minion_pool)
		roles.append(m_pick)
		if m_pick in in_minions or in_good.is_empty():
			roles.append_array(w.shuffled(town_pool).slice(0, 2))
		else:
			var g0: String = w.pick(in_good)
			roles.append(g0)
			var rest_g: Array = town_pool.filter(func(r): return r != g0)
			if not rest_g.is_empty():
				roles.append(w.pick(rest_g))
	else:
		if not in_good.is_empty():
			var g0: String = w.pick(in_good)
			roles.append(g0)
			var rest_g2: Array = town_pool.filter(func(r): return r != g0)
			roles.append_array(w.shuffled(rest_g2).slice(0, 2))
		else:
			roles.append_array(w.shuffled(town_pool).slice(0, 3))
	return w.shuffled(roles)


func _ensure_slate(w, n) -> Array:
	if n.registrar_roles.size() == 3:
		return n.registrar_roles
	n.registrar_roles = draw_slate(w, n.secret_mod == "delusional")
	return n.registrar_roles


func pick_targets(w, n, mind):
	var asked: Array = mind.requested_targets(w, n, "registrar")
	if not asked.is_empty() and w.by_id.has(asked[0]) and w.by_id[asked[0]].alive and asked[0] != n.id:
		w.dlog.think(n.id, "registrar_pick", "Registrar: checks whom the Demonologist asked.", {"pick": asked[0]})
		return asked[0]
	var roles: Array = _ensure_slate(w, n)
	var checked = {}
	for e in n.info_log:
		if e.get("role", "") == "registrar" and e.get("data", {}).has("target"):
			checked[str(e["data"]["target"])] = true
	var ranked: Array = mind.ranked_suspects(w, n)
	var unchecked: Array = ranked.filter(func(m): return not checked.has(m.id))
	var pool: Array = unchecked if not unchecked.is_empty() else ranked
	if pool.is_empty():
		return ""
	# Prefer testing an unchecked living claimant of one of the Registrar's three roles.
	var claimants: Array = unchecked.filter(func(m): return m.claim_public and m.claimed_role in roles)
	if not claimants.is_empty():
		var pick_c: String = claimants[0].id
		w.dlog.think(n.id, "registrar_pick", "Registrar: tests public claimant of a listed role.", {"pick": pick_c, "role": claimants[0].claimed_role})
		return pick_c
	var C = content()
	var has_minion: bool = roles.any(func(r): return C.is_minion(str(r)))
	var ins: float = mind.trait_of(n, "insight")
	var chosen = pool[0] if (has_minion and ins >= 0.45) else w.decision_pick(n, "registrar_target", pool.slice(0, mini(3, pool.size())), {"insight": ins})
	w.dlog.think(n.id, "registrar_pick", "Registrar: checks %s against %s." % [chosen.id, str(roles)], {"pick": chosen.id})
	return chosen.id


func score_gift_request(_w, n, targets: Array, top: String, parts: Dictionary, _mind) -> void:
	if targets.is_empty():
		return
	var t: String = str(targets[0])
	if t == top:
		parts["already_wondering"] = Tuning.Roles.SEER.req_already_wondering
	if n.npc_trust.get(t, 0.5) >= 0.7:
		parts["doubting_a_friend"] = Tuning.Roles.SEER.req_doubting_friend
	var already: bool = n.info_log.any(func(e): return e.get("role", "") == "registrar" and str(e.get("data", {}).get("target", "")) == t)
	if already:
		parts["already_looked"] = Tuning.Roles.SEER.req_already_looked


func counter_gift_request(w, _n, _targets: Array, top: String) -> String:
	return "I'd sooner check %s against my register." % w.by_id[top].name


func _slate_has_in_play(w, roles: Array) -> bool:
	var init_mins: Array = w.initial_minion_ids if not w.initial_minion_ids.is_empty() else w.minion_ids
	for r in roles:
		if r in w.initial_good_roles:
			return true
		for mid in init_mins:
			if w.by_id.has(mid):
				var mr: String = "scion" if mid == w.scion_rose else str(w.by_id[mid].role)
				if mr == r:
					return true
	return false


func generate_reading(w, n, _ctx: Dictionary, mind) -> Dictionary:
	var broken: bool = n.gift_broken()
	if w.day == 0:
		# Like Executor's Night 0 charge, the Registrar's permanent 3-role register is only
		# corrupted if the Registrar is permanently Delusional; a Night 0 blind poison cannot
		# permanently brick Night 1+ checks or break the solver's >=1 in-play invariant on
		# later healthy nights.
		var slate_broken: bool = n.secret_mod == "delusional"
		var roles: Array = draw_slate(w, slate_broken)
		if roles.size() != 3:
			return {}
		n.registrar_roles = roles.duplicate()
		var ok: bool = not slate_broken and _slate_has_in_play(w, roles)
		return {
			"data": {"roles": roles.duplicate()},
			"true": ok,
			"text": "My register lists three roles: %s" % _roles_prose(roles),
		}
	var roles_n: Array = _ensure_slate(w, n)
	if roles_n.size() != 3:
		return {}
	var tid: String = pick_targets(w, n, mind)
	if tid == "" or not w.by_id.has(tid):
		return {}
	var tgt = w.by_id[tid]
	var C = content()
	var tgt_true_role: String = "scion" if tgt.id == w.scion_rose else str(tgt.role)
	var true_yes: bool = tgt_true_role in roles_n
	var has_minion: bool = roles_n.any(func(r): return C.is_minion(str(r)))
	var yes: bool = true_yes
	var swhy: String = ""
	if not yes and has_minion and tgt.secret_mod == "marked" and w.chance(0.5):
		yes = true
		swhy = "a Marked soul matched the minion role on the register"
	var reported_yes: bool = w.chance(0.5) if broken else yes
	return {
		"data": {"roles": roles_n.duplicate(), "target": tid, "yes": reported_yes},
		"true": (reported_yes == true_yes) and _slate_has_in_play(w, roles_n),
		"why": swhy,
		"text": "I checked %s against my register (%s): %s" % [
			tgt.name,
			_roles_short_list(roles_n),
			"they hold one of those roles" if reported_yes else "they hold none of those roles",
		],
	}


func _ensure_bluff_slate(w, n, plan: Dictionary, mate) -> Array:
	var key: String = "registrar_bluff_roles_" + n.id
	if plan.has(key) and plan[key] is Array and plan[key].size() == 3:
		return plan[key]
	var sc = w.case_script
	var town_pool: Array = sc.town.filter(func(r): return r != "registrar")
	var minion_pool: Array = sc.minions.filter(func(m): return m != "breathstealer" or w.living_with_role("breathstealer") != null)
	if minion_pool.is_empty():
		minion_pool = sc.minions.duplicate()
	var roles: Array = []
	var use_min: bool = not minion_pool.is_empty() and town_pool.size() >= 2 and w.chance(0.6)
	if use_min:
		roles.append(w.pick(minion_pool))
	if mate != null and mate != n:
		var m_bluff: String = str(plan.get("bluffs", {}).get(mate.id, ""))
		if m_bluff in town_pool and not (m_bluff in roles):
			roles.append(m_bluff)
	for g in w.shuffled(town_pool):
		if roles.size() >= 3:
			break
		if not (g in roles):
			roles.append(g)
	roles = w.shuffled(roles)
	plan[key] = roles
	return roles


func generate_bluff_reading(w, n, plan: Dictionary, s: String, mate, asked: Array) -> Dictionary:
	var roles: Array = _ensure_bluff_slate(w, n, plan, mate)
	if roles.size() != 3:
		return {}
	if w.day == 0:
		var entry0: Dictionary = {
			"data": {"roles": roles.duplicate()},
			"text": "My register lists three roles: %s" % _roles_prose(roles),
		}
		return {"entry": entry0, "why": "declares Registrar slate %s" % str(roles)}
	var C = content()
	var has_minion: bool = roles.any(func(r): return C.is_minion(str(r)))
	var checked = {}
	for e in n.info_log:
		if e.get("role", "") == "registrar" and e.get("data", {}).has("target"):
			checked[str(e["data"]["target"])] = true
	var clean_asked: Array = asked.filter(func(x): return x != n.id and w.by_id.has(x) and w.by_id[x].alive)
	var tid: String = ""
	var yes: bool = false
	var why: String = ""
	if not clean_asked.is_empty():
		tid = str(clean_asked[0])
		var t_npc = w.by_id[tid]
		if tid == s and has_minion:
			yes = true
			why = "checks requested scapegoat %s and frames via minion on slate" % s
		elif mate != null and mate != n and tid == mate.id and str(plan.get("bluffs", {}).get(mate.id, "")) in roles:
			yes = true
			why = "vouches for requested teammate %s's bluff" % mate.id
		elif not t_npc.is_evil() and t_npc.claim_public and t_npc.claimed_role in roles and tid != s:
			yes = true
			why = "confirms requested %s's public claim %s" % [tid, t_npc.claimed_role]
		else:
			yes = false
			why = "reports 'no' on requested %s" % tid
	elif s != "" and w.by_id.has(s) and w.by_id[s].alive and s != n.id and not checked.has(s) and (has_minion or (w.by_id[s].claim_public and w.by_id[s].claimed_role in roles)):
		tid = s
		if w.by_id[s].claim_public and w.by_id[s].claimed_role in roles:
			yes = false
			why = "contradicts scapegoat %s's claimed gift %s" % [s, w.by_id[s].claimed_role]
		else:
			yes = true
			why = "frames scapegoat %s with a 'yes' on minion-bearing slate" % s
	elif mate != null and mate != n and mate.alive and not checked.has(mate.id) and str(plan.get("bluffs", {}).get(mate.id, "")) in roles and w.chance(0.45):
		tid = mate.id
		yes = true
		why = "vouches for teammate %s's bluff on register" % mate.id
	else:
		var others: Array = w.living().filter(func(m): return m != n and not checked.has(m.id) and m.id != (mate.id if mate != null else ""))
		if others.is_empty():
			others = w.living().filter(func(m): return m != n)
		if others.is_empty():
			return {}
		var pick_m = w.pick(others)
		tid = pick_m.id
		yes = not pick_m.is_evil() and pick_m.claim_public and pick_m.claimed_role in roles and tid != s
		why = "harmless '%s' check on %s" % ["yes" if yes else "no", tid]
	var tgt_name: String = w.by_id[tid].name
	var entry: Dictionary = {
		"data": {"roles": roles.duplicate(), "target": tid, "yes": yes},
		"text": "I checked %s against my register (%s): %s" % [
			tgt_name,
			_roles_short_list(roles),
			"they hold one of those roles" if yes else "they hold none of those roles",
		],
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(w, _n, dd, s: String, _sg, _d, _goods: Array, _other: Callable, e: Dictionary, _demon_implicated: bool) -> Dictionary:
	var roles: Array = []
	for pe in dd.info_log:
		if pe.get("role", "") == "registrar" and pe.get("data", {}).get("roles", []).size() == 3:
			roles = pe["data"]["roles"].duplicate()
			break
	var C = content()
	if roles.size() != 3:
		var sc = w.case_script
		var mpool: Array = sc.minions.filter(func(m): return m != "breathstealer" or w.living_with_role("breathstealer") != null)
		var tpool: Array = sc.town.filter(func(r): return r != "registrar")
		if mpool.is_empty() or tpool.size() < 2:
			return {}
		roles = w.shuffled([w.pick(mpool)] + w.shuffled(tpool).slice(0, 2))
	if s == "" or s == dd.id or not w.by_id.has(s) or not w.by_id[s].alive:
		return {}
	var has_minion: bool = roles.any(func(r): return C.is_minion(str(r)))
	var s_npc = w.by_id[s]
	var yes: bool = true
	if s_npc.claim_public and s_npc.claimed_role in roles:
		yes = false
	elif not has_minion:
		return {}
	e["day"] = maxi(1, mini(int(dd.death_day), int(e.get("day", 1))))
	e.erase("phase")
	e["data"] = {"roles": roles.duplicate(), "target": s, "yes": yes}
	e["text"] = "I checked %s against my register (%s): %s" % [
		s_npc.name,
		_roles_short_list(roles),
		"they hold one of those roles" if yes else "they hold none of those roles",
	]
	return {"entry": e, "why": "the dead Registrar %s framed %s" % [dd.id, s], "frames": true}
