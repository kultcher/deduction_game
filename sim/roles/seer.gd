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
	tags = ["ongoing_info", "demon_id"]
	desc = "Each night, picks two people and learns if either is the Demon. One good soul reads falsely as the Demon."
	shape = "PING"
	marked_registers = true
	red_herring_registers = true
	request_agree_line = "All right. Tonight I'll look at %s."
	request_agree_voice_key = "gift_req_agree_seer"
	request_agree_slot = "target"


func setup_world(w, holder) -> void:
	var cands = w.npcs.filter(func(m): return m != holder and not m.is_evil())
	holder.red_herring = w.pick(cands).id


func short_text(d: Dictionary, _src: String, nm: Callable) -> String:
	# Michael's form (Nov 19): what the Seer is for, and the reminder only when it matters.
	# A NO rules out the Demon and the Red Herring (a Marked soul may still read NO).
	var pair: String = _names(d.get("pair", []), nm)
	if d.get("yes", false):
		# Marked only when it's on the script (reading_interpretation.md §2.1).
		var marked_possible: bool = script_secrets.is_empty() or "marked" in script_secrets
		return "%s: Demon? YES\n(%s?)" % [pair, "Marked or Red Herring" if marked_possible else "Red Herring"]
	return "%s: Demon? NO" % pair


func on_reading_heard(listener, source, entry: Dictionary, fresh: bool) -> void:
	if listener != source or not fresh:
		return
	var d: Dictionary = entry.get("data", {})
	if d.get("yes", true):
		return
	for i in d.get("pair", []):
		if i != listener.id:
			listener.cleared[i] = true


func try_reading_defence(_w, d, src, src_id: String, rd: Dictionary, mind, workshop_ledger) -> Dictionary:
	var pings: int = src.info_log.filter(func(e): return e.get("shared", false) and e.get("role", "") == "seer" and e["data"].get("yes", false) and d.id in e["data"].get("pair", [])).size()
	if pings >= 2:
		return {
			"handled": true,
			"move": "red_herring",
			"line": mind.say_voiced(d, "defence_red_herring", "%s keeps finding me because I'm the one the Seer always misreads. Look at who else they named." % src.name, {"source": src.name}),
			"hearing_scale": absf(float(Tuning.Roles.SEER.red_herring_defence_eff)),
			"scope": {"type": "challenge", "mode": "misled", "reading": workshop_ledger.reading(src_id, rd).id},
		}
	return {}


## The Seer's two picks, by Insight (reading_interpretation.md §2.1, Michael, Nov 21).
## - It looks for the Demon, not just for evil: anyone its own "no" readings cleared of being
##   the Demon goes to the back, however evil it thinks them (Lantern's interim stand-in, Nov 21,
##   until the town holds a belief about who is the Demon).
## - After a "yes" not yet narrowed down, with its top suspect one of the two (Michael, Nov 22),
##   a focused Seer re-checks that suspect beside either
##   someone fresh (its likeliest Demon among those it hasn't looked at) or someone it trusts
##   as good (someone it has cleared, or failing that its least suspected), on a coin flip
##   (Michael, Nov 21).
## - Otherwise a sharp Seer re-checks its top suspect and pairs them with someone it hasn't
##   looked at yet; once two readings have said "yes" with that suspect in them, it's settled
##   as far as sight can tell, so it spends its sight on two fresh people instead.
func pick_targets(w, n, mind):
	var by_demon: Array = demon_ranked(w, n, mind)
	var judged: bool = not load("res://workshop/demon_candidates.gd").demon_chances_of_npc(n).is_empty()
	var ranked: Array = by_demon.filter(func(m): return not n.cleared.has(m.id)) + by_demon.filter(func(m): return n.cleared.has(m.id))
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
	var narrow: Array = _narrowing_pick(w, n, ranked, seen_pairs, yes_on, checked, mind.ranked_suspects(w, n))
	if w.day == 0 or ranked.size() < 3:
		pair = w.shuffled(ranked).slice(0, 2)
		why = "first look: two at random"
	elif not w.decision_roll(n, "seer_focused_look", Tuning.Roles.SEER.focus_base + Tuning.Roles.SEER.focus_insight_scale * ins, {"insight": ins}):
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
	elif not narrow.is_empty():
		pair = narrow.slice(0, 2)
		why = "narrows a \"yes\": %s again, beside %s, %s" % [narrow[0].id, narrow[1].id, narrow[2]]
	elif ins >= Tuning.Roles.SEER.sharp_insight_threshold and yes_on.get(ranked[0].id, 0) >= 2 and fresh.size() >= 2:
		pair = w.shuffled(fresh).slice(0, 2)
		why = "settled on %s (two yeses); looks at two fresh people" % ranked[0].id
	else:
		var others: Array = ranked.slice(1)
		var unrepeated: Array = others.filter(func(m):
			var p_ids: Array = [ranked[0].id, m.id]
			p_ids.sort()
			return not seen_pairs.has("%s:%s" % [p_ids[0], p_ids[1]])
		)
		if not unrepeated.is_empty():
			others = unrepeated
		if ins >= Tuning.Roles.SEER.sharp_insight_threshold:
			var fr: Array = others.filter(func(m): return not checked.has(m.id))
			if not fr.is_empty():
				others = fr
		pair = [ranked[0], w.decision_pick(n, "seer_second_target", others, {"insight": ins})]
		why = "top suspect plus %s (insight %.2f)" % ["someone unchecked" if ins >= Tuning.Roles.SEER.sharp_insight_threshold else "one other", ins]
	var ids: Array = pair.map(func(m): return m.id)
	w.dlog.think(n.id, "seer_pick", "Seer: " + why + ".", {"pair": ids, "by_demon": judged})
	return ids


## The living others, likeliest Demon first, by its chance each is the Demon (Lantern's
## DemonCandidates.demon_chances_of_npc: its belief model's evil chance for each, times the joint
## judgement's chance they're the Demon if evil, from its last refresh; reading_interpretation.md
## section 2.1). It looks for the Demon, not just for evil: a Minion it's sure of, whom its own
## readings put outside the Demon's seat, ranks below someone it only half suspects. With
## nothing staged (no refresh yet), its suspicion alone. Ties keep the suspicion order.
func demon_ranked(w, n, mind) -> Array:
	var by_susp: Array = mind.ranked_suspects(w, n)
	var chances: Dictionary = load("res://workshop/demon_candidates.gd").demon_chances_of_npc(n)
	if chances.is_empty():
		return by_susp
	var order: Dictionary = {}
	for i in range(by_susp.size()):
		order[by_susp[i].id] = i
	var out: Array = by_susp.duplicate()
	out.sort_custom(func(a, b):
		var da: float = float(chances.get(a.id, 0.0))
		var db: float = float(chances.get(b.id, 0.0))
		return da > db or (da == db and order[a.id] < order[b.id]))
	return out


## The latest "yes" not yet narrowed down: neither of the two cleared since, neither in a
## second "yes". Returns [its top suspect, a partner, why], or [] if there's none or its top
## suspect isn't one of the two. The partner, on a coin flip (Michael, Nov 21), is someone
## fresh (its likeliest Demon among those unchecked) or someone it trusts as good (one its own
## readings cleared, else its least suspected), avoiding a pair it has already looked at.
func _narrowing_pick(w, n, ranked: Array, seen_pairs: Dictionary, yes_on: Dictionary, checked: Dictionary = {}, by_evil: Array = []) -> Array:
	var open: Array = []
	for i in range(n.info_log.size() - 1, -1, -1):
		var e: Dictionary = n.info_log[i]
		if e.get("role", "") != "seer" or not e["data"].get("yes", false):
			continue
		var p: Array = e["data"]["pair"]
		if p.any(func(id): return n.cleared.has(id) or yes_on.get(id, 0) >= 2):
			continue
		open = p
		break
	if open.is_empty():
		return []
	# Only when its top suspect is in that "yes" (Michael, Nov 22): otherwise it reads its top
	# suspect, rather than spending a night on the other of the two.
	if ranked.is_empty() or not (ranked[0].id in open):
		return []
	var target = ranked[0]
	var fresh: Array = ranked.filter(func(m): return not (m.id in open) and not checked.has(m.id))
	if not fresh.is_empty() and w.decision_roll(n, "seer_confirm_beside_fresh", 0.5, {"fresh": fresh.size()}):
		return [target, fresh[0], "someone fresh"]
	# Trusted as good: the least suspected of evil, not the least likely Demon (Codex on #549),
	# so a Minion it's sure of is never its "trusted" partner.
	var trusted: Array = (by_evil if not by_evil.is_empty() else ranked).filter(func(m): return not (m.id in open))
	trusted.reverse()
	var cleared_first: Array = trusted.filter(func(m): return n.cleared.has(m.id)) + trusted.filter(func(m): return not n.cleared.has(m.id))
	for m in cleared_first:
		var key: Array = [target.id, m.id]
		key.sort()
		if not seen_pairs.has("%s:%s" % [key[0], key[1]]):
			return [target, m, "whom it trusts"]
	return []


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
		"text": "I looked at %s: %s" % [w._names(pair), "one of them reads as the Demon" if reported_yes else "neither is the Demon"],
	}
	if yes and not true_yes and not broken:
		entry["why"] = "%s is the Seer's red herring, so reads as the Demon" % n.red_herring if n.red_herring in pair else "a Marked soul reads as the Demon"
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
	var clean_asked: Array = asked.filter(func(x): return x != n.id)
	if not clean_asked.is_empty():
		# Looked where the Demonologist asked: a 'yes' only frames the scapegoat.
		# A real Seer never reads themself: drop the bluffer from the asked pair.
		pair = clean_asked.slice(0, 2)
		if pair.size() < 2:
			var fill: Array = goods.filter(func(x): return not (x in pair) and x != mate.id and x != n.id)
			if fill.is_empty():
				return {}
			pair.append(w.pick(fill))
		yes = s in pair
		why = "looked where asked; %s" % ["framed evil's scapegoat" if yes else "made up a reading that harmed nobody"]
	elif w.by_id[s].alive and (w.day % 2 == 1 or w.day == 0 or late) and not others_s.is_empty():
		pair = [s, w.pick(others_s)]
		yes = true
		why = "said %s, evil's scapegoat, read as the Demon" % s
	elif mate != n and mate.alive and w.chance(Tuning.Roles.SEER.bluff_clear_mate_prob) and not others_m.is_empty():
		# (A lone evil's "mate" is itself: clearing it would put the bluffer in its own pair.)
		pair = [mate.id, w.pick(others_m)]
		why = "cleared %s, a fellow evil" % mate.id
	elif others_s.size() >= 2:
		pair = w.shuffled(others_s).slice(0, 2)
		why = "made up a reading that harmed nobody"
	else:
		return {}
	pair = w.shuffled(pair)
	var entry: Dictionary = {
		"data": {"pair": pair, "yes": yes},
		"text": "I looked at %s: %s" % [w._names(pair), "one of them reads as the Demon" if yes else "neither is the Demon"],
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(w, _n, dd, s: String, _sg, d, _goods: Array, other: Callable, e: Dictionary, demon_implicated: bool) -> Dictionary:
	# Clear the demon if it's been named; else carry on an earlier yes of theirs on a
	# good person (a red herring or a poisoned read), or name the scapegoat.
	if d != null and d.alive and demon_implicated and w.chance(0.5):
		var o = other.call([])
		if o != null:
			e["data"] = {"pair": [d.id, o.id], "yes": false}
			e["text"] = "I looked at %s: neither is the Demon" % w._names([d.id, o.id])
			return {"entry": e, "why": "made up a reading from the late Seer %s that cleared %s, the Demon" % [dd.id, d.id], "frames": false}
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
	e["text"] = "I looked at %s: one of them reads as the Demon" % w._names([a, o2.id])
	return {"entry": e, "why": "made up a reading from the late Seer %s that pointed at %s again" % [dd.id, a], "frames": true}


## The other answer on the same pair, or the same answer on a pair with a bystander in
## place of a teammate (FabricationCheck: a better lie). Never the bluffer's own pair.
func bluff_alternatives(w, n, _plan: Dictionary, _s: String, _mate, entry: Dictionary) -> Array:
	var d: Dictionary = entry.get("data", {})
	var pair: Array = d.get("pair", [])
	var yes: bool = bool(d.get("yes", false))
	var out: Array = []
	var make = func(p: Array, y: bool, why: String) -> Dictionary:
		return {"entry": {"data": {"pair": p, "yes": y}, "text": "I looked at %s: %s" % [w._names(p), "one of them reads as the Demon" if y else "neither is the Demon"]}, "why": why}
	out.append(make.call(pair.duplicate(), not yes, "gives the other answer on %s" % str(pair)))
	var free: Array = bluff_bystanders(w, n)
	for i in range(pair.size()):
		if not w.by_id.has(pair[i]) or not w.by_id[pair[i]].is_evil():
			continue
		for b in free:
			if b in pair:
				continue
			var p2: Array = pair.duplicate()
			p2[i] = b
			out.append(make.call(p2, yes, "looks at %s instead" % str(p2)))
	return [out[0]] + cap_alternatives(w, out.slice(1), 5)
