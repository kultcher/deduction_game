## Seer role definition and simulation hooks.
##
## Shape: PING ({pair, yes}) — picks two people each night and learns if either
## registers as the demon (the demon, the Seer's good red herring, or a Marked soul).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "seer"
	display_name = "Seer"
	align = "good"
	kind = "info"
	desc = "Each night, picks two people and learns if either is the demon. One good soul reads falsely as the demon."
	shape = "PING"
	marked_registers = true
	red_herring_registers = true
	public_threat_bonus = Tuning.Roles.SEER.public_threat_bonus
	public_threat_key = "seer"
	request_agree_line = "All right. Tonight I'll look at %s."
	request_agree_voice_key = "gift_req_agree_seer"
	request_agree_slot = "target"


func setup_world(w, holder) -> void:
	var cands = w.npcs.filter(func(m): return m != holder and not m.is_evil())
	holder.red_herring = w.pick(cands).id


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	return "%s Seer: %s → %s" % [src, _names(d.get("pair", []), nm), "YES" if d.get("yes", false) else "no"]


func reading_strength(d: Dictionary, _t_id: String) -> float:
	return Tuning.Roles.SEER.reading_strength_yes if d.get("yes", false) else 0.0


func card_strength(d: Dictionary, _suspect_id: String) -> float:
	return Tuning.Roles.SEER.card_strength_yes if d.get("yes", false) else 0.0


func defend_strength(d: Dictionary, _nominee: String) -> float:
	return 0.0 if d.get("yes", false) else Tuning.Roles.SEER.defend_strength_no


func info_effects(_w, listener, source, entry: Dictionary, weight: float, fresh: bool, mind) -> Array:
	var effs: Array = []
	var d: Dictionary = entry["data"]
	var own: bool = source == listener
	var src_name: String = "my own" if own else source.name + "'s"
	var tag: String = "own info" if own else "heard %s's info (w=%.2f)" % [source.id, weight]
	var pair: Array = d["pair"]
	var others: Array = pair.filter(func(i): return i != listener.id)
	if d["yes"]:
		var per: float = Tuning.Roles.SEER.eff_yes_pair if others.size() > 1 else Tuning.Roles.SEER.eff_yes_solo
		for i in others:
			mind._eff(effs, i, per, tag + ": seer yes",
				"%s sight said one of them is the demon" % src_name, not own)
	else:
		for i in others:
			mind._eff(effs, i, (Tuning.Roles.SEER.eff_no_own if own else Tuning.Roles.SEER.eff_no_heard), tag + ": seer no", "", not own)
			if own and fresh:
				listener.cleared[i] = true
	return effs


func try_reading_defence(_w, d, src, src_id: String, rd: Dictionary, mind, workshop_ledger) -> Dictionary:
	var pings: int = src.info_log.filter(func(e): return e.get("shared", false) and e.get("role", "") == "seer" and e["data"].get("yes", false) and d.id in e["data"].get("pair", [])).size()
	if pings >= 2:
		return {
			"handled": true,
			"move": "red_herring",
			"line": mind.say(d, "[PH] %s keeps finding me because I'm the one the Seer always misreads. Look at who else they named." % src.name),
			"effs": [[d.id, Tuning.Roles.SEER.red_herring_defence_eff, true, "says they're the Seer's red herring", ""]],
			"scope": {"type": "challenge", "mode": "misled", "reading": workshop_ledger.reading(src_id, rd).id},
		}
	return {}


## The Seer's two picks, by Insight. A sharp Seer usually re-checks their top suspect and
## pairs them with someone they haven't looked at yet; once two readings have said "yes"
## with that suspect in them, it's settled as far as sight can tell, so they spend their
## sight on two fresh people instead.
func pick_targets(w, n, mind):
	var ranked: Array = mind.ranked_suspects(w, n)
	var asked: Array = mind.requested_targets(w, n, "seer")
	if not asked.is_empty():
		var pair_req: Array = asked.slice(0, 2)
		if pair_req.size() < 2:
			var rest: Array = ranked.filter(func(m): return not (m.id in pair_req))
			if not rest.is_empty():
				pair_req.append(rest[0].id)
		w.dlog.think(n.id, "seer_pick", "Seer: looks where the Demonologist asked.", {"pair": pair_req, "requested": asked})
		return pair_req
	var ins: float = mind.trait_of(n, "insight")
	var pair: Array = []
	var why = ""
	var checked = {}
	var seen_pairs = {}
	var yes_on = {}
	for e in n.info_log:
		if e.get("role", "") == "seer":
			var ep: Array = e["data"]["pair"].duplicate()
			ep.sort()
			if ep.size() == 2:
				seen_pairs["%s:%s" % [ep[0], ep[1]]] = true
			for pid in e["data"]["pair"]:
				checked[pid] = true
				if e["data"]["yes"]:
					yes_on[pid] = yes_on.get(pid, 0) + 1
	var fresh: Array = ranked.filter(func(m): return not checked.has(m.id))
	if w.day == 0 or ranked.size() < 3:
		pair = w.shuffled(ranked).slice(0, 2)
		why = "first look: two at random"
	elif not w.decision_roll(n, "seer_focused_look", 0.3 + 0.5 * ins, {"insight": ins}):
		var shuf: Array = w.shuffled(ranked)
		for i_s in range(shuf.size()):
			for j_s in range(i_s + 1, shuf.size()):
				var cand_ids: Array = [shuf[i_s].id, shuf[j_s].id]
				cand_ids.sort()
				if not seen_pairs.has("%s:%s" % [cand_ids[0], cand_ids[1]]):
					pair = [shuf[i_s], shuf[j_s]]
					break
			if not pair.is_empty():
				break
		if pair.is_empty():
			pair = shuf.slice(0, 2)
		why = "a scattered look (insight %.2f): two unchecked together" % ins
	elif ins >= 0.6 and yes_on.get(ranked[0].id, 0) >= 2 and fresh.size() >= 2:
		pair = w.shuffled(fresh).slice(0, 2)
		why = "settled on %s (two yeses); looks at two fresh people" % ranked[0].id
	else:
		var others: Array = ranked.slice(1)
		if ins >= 0.6:
			var fr: Array = others.filter(func(m): return not checked.has(m.id))
			if not fr.is_empty():
				others = fr
		pair = [ranked[0], w.decision_pick(n, "seer_second_target", others, {"insight": ins})]
		why = "top suspect plus %s (insight %.2f)" % ["someone unchecked" if ins >= 0.6 else "one other", ins]
	var ids: Array = pair.map(func(m): return m.id)
	w.dlog.think(n.id, "seer_pick", "Seer: " + why + ".", {"pair": ids})
	return ids


func score_gift_request(_w, n, targets: Array, top: String, parts: Dictionary, _mind) -> void:
	if top in targets:
		parts["already_wondering"] = Tuning.Roles.SEER.req_already_wondering
	for t in targets:
		if n.npc_trust.get(t, 0.5) >= 0.7:
			parts["doubting_a_friend"] = Tuning.Roles.SEER.req_doubting_friend
	var checked = {}
	for e in n.info_log:
		if e.get("role", "") == "seer":
			for pid in e["data"]["pair"]:
				checked[pid] = true
	if targets.all(func(t): return checked.has(t)):
		parts["already_looked"] = Tuning.Roles.SEER.req_already_looked


func counter_gift_request(w, _n, _targets: Array, top: String) -> String:
	return "I'd sooner look at %s." % w.by_id[top].name


func generate_reading(w, n, _ctx: Dictionary, mind) -> Dictionary:
	var broken: bool = n.gift_broken()
	var pair: Array = pick_targets(w, n, mind)
	var yes = false
	var true_yes = false
	for pid in pair:
		if pid == n.red_herring or w.registers_demon(w.by_id[pid]):
			yes = true
		if pid == w.demon_id:
			true_yes = true
	var reported_yes: bool = yes
	if broken:
		reported_yes = w.chance(0.5)
	var entry: Dictionary = {
		"data": {"pair": pair, "yes": reported_yes},
		"true": reported_yes == true_yes,
		"text": "I looked at %s: %s" % [w._names(pair), "one of them reads as the demon" if reported_yes else "neither is the demon"],
	}
	if yes and not true_yes and not broken:
		entry["why"] = "red herring %s" % n.red_herring if n.red_herring in pair else "a Marked soul read as the demon"
	return entry


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, mate, asked: Array) -> Dictionary:
	var goods: Array = w.living_good().filter(func(x): return x.id != s).map(func(x): return x.id)
	if goods.size() < 2:
		goods = w.living().filter(func(x): return x != n).map(func(x): return x.id)
	var pair: Array = []
	var yes = false
	# Never a 'no' that covers the scapegoat: it would undo the frame.
	var others_s: Array = goods.filter(func(x): return x != s and x != mate.id)
	var others_m: Array = goods.filter(func(x): return x != mate.id and x != s)
	var late: bool = w.living().size() <= 5
	var why = ""
	if not asked.is_empty():
		# Looked where the Demonologist asked: a 'yes' only frames the scapegoat.
		pair = asked.slice(0, 2)
		if pair.size() < 2:
			var fill: Array = goods.filter(func(x): return not (x in pair) and x != mate.id)
			if fill.is_empty():
				return {}
			pair.append(w.pick(fill))
		yes = s in pair
		why = "looks where asked (%s); %s" % [str(asked), "frames the scapegoat" if yes else "a harmless 'no'"]
	elif w.by_id[s].alive and (w.day % 2 == 1 or w.day == 0 or late) and not others_s.is_empty():
		pair = [s, w.pick(others_s)]
		yes = true
		why = "frames scapegoat %s with a 'yes'" % s
	elif mate.alive and w.chance(0.4) and not others_m.is_empty():
		pair = [mate.id, w.pick(others_m)]
		why = "clears teammate %s with a 'no'" % mate.id
	elif others_s.size() >= 2:
		pair = w.shuffled(others_s).slice(0, 2)
		why = "harmless 'no' on two people"
	else:
		return {}
	pair = w.shuffled(pair)
	var entry: Dictionary = {
		"data": {"pair": pair, "yes": yes},
		"text": "I looked at %s: %s" % [w._names(pair), "one of them reads as the demon" if yes else "neither is the demon"],
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(w, _n, dd, s: String, _sg, d, _goods: Array, other: Callable, e: Dictionary, demon_implicated: bool) -> Dictionary:
	# Clear the demon if it's been named; else carry on an earlier yes of theirs on a
	# good person (a red herring or a poisoned read), or name the scapegoat.
	if d != null and d.alive and demon_implicated and w.chance(0.5):
		var o = other.call([])
		if o != null:
			e["data"] = {"pair": [d.id, o.id], "yes": false}
			e["text"] = "I looked at %s: neither is the demon" % w._names([d.id, o.id])
			return {"entry": e, "why": "the dead Seer %s 'cleared' the demon %s" % [dd.id, d.id], "frames": false}
	var prior: Array = []
	for pe in dd.info_log:
		if pe.get("shared", false) and pe.get("role", "") == "seer" and pe["data"].get("yes", false):
			for x in pe["data"]["pair"]:
				if w.by_id[x].alive and not w.by_id[x].is_evil():
					prior.append(x)
	var a: String = w.pick(prior) if not prior.is_empty() and w.chance(0.5) else s
	var o2 = other.call([a])
	if o2 == null:
		return {}
	e["data"] = {"pair": [a, o2.id], "yes": true}
	e["text"] = "I looked at %s: one of them reads as the demon" % w._names([a, o2.id])
	return {"entry": e, "why": "the dead Seer %s 'pinged' %s again" % [dd.id, a], "frames": true}
