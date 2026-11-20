## The nominator's case: which reasons a nominator cites and how they're resolved
## (split from `sim/mind_meeting.gd`).
extends "res://sim/mind_meeting_base.gd"


# ---------------------------------------------------------------- the nominator's case

## What drove n's suspicion of t most (meeting-flow plan, step 1): ledger entries ranked by
## how much they now add to it, at most `limit`. Each item: {eid, why, kind, strength,
## entry}, with kind as in reason_status (public | player | private) for that entry. An
## evil nominator ranks its good self's ledger (what an innocent would cite) but its own
## readings (real or fake) are looked up on the real NPC.
static func _visibility_maps(w, mind, real_npc) -> Dictionary:
	var public_ids: Dictionary = {}
	var player_ids: Dictionary = {}
	var st: Dictionary = mind.workshop_state
	for id in st.get("disclosures", {}):
		var d: Dictionary = st.disclosures[id]
		if d.get("player", false):
			player_ids[str(id)] = true
		if d.get("public", false):
			public_ids[str(id)] = true
	var withdrawn: Dictionary = st.get("withdrawn", {})
	for pkey in st.get("presentations", {}):
		if withdrawn.has(pkey) or withdrawn.has(str(pkey)):
			continue
		var snap: Dictionary = st.presentations[pkey]
		var is_pub_venue: bool = str(snap.get("venue", "private")) != "private"
		for id in snap.get("selected", []):
			player_ids[str(id)] = true
			if is_pub_venue:
				public_ids[str(id)] = true
	for entry in mind.ledger.values():
		var meta: Dictionary = entry.get("meta", {})
		for receipt in meta.get("workshop_receipts", {}).values():
			if receipt is Dictionary and receipt.get("heard_in_public", false):
				public_ids[str(receipt.get("id", ""))] = true
		if meta.get("workshop_public", false) and meta.has("workshop_card"):
			public_ids[str(meta.workshop_card.get("id", ""))] = true
	for i in range(real_npc.info_log.size()):
		var en: Dictionary = real_npc.info_log[i]
		var rid: String = WorkshopLedger.reading(real_npc.id, en).id
		if en.get("shared", false):
			public_ids[rid] = true
		if i < real_npc.told_readings:
			player_ids[rid] = true
	for p in w.npcs:
		if p == real_npc:
			continue
		for en in p.info_log:
			if en.get("shared", false):
				public_ids[WorkshopLedger.reading(p.id, en).id] = true
	for pc in w.public_claims:
		var who_id: String = str(pc.get("who", ""))
		var role_id: String = str(pc.get("role", ""))
		var c_eid: String = "claim:%s:%s" % [who_id, role_id]
		if mind.ledger.has(c_eid) and mind.ledger[c_eid].get("meta", {}).has("workshop_card"):
			public_ids[str(mind.ledger[c_eid].meta.workshop_card.get("id", ""))] = true
	return {"public": public_ids, "player": player_ids}


static func _root_is_public(w, mind, real_npc, rid: String, public_ids: Dictionary) -> bool:
	if public_ids.has(rid):
		return true
	var owners: Array = mind.workshop_state.get("owners", {}).get(rid, [])
	for owner in owners:
		var os: String = str(owner)
		if os == "public":
			return true
		if os.begins_with("claim:"):
			var c_eid: String = os.trim_prefix("claim:")
			var meta: Dictionary = mind.ledger.get(c_eid, {}).get("meta", {})
			var who_id: String = str(meta.get("who", ""))
			var role_id: String = str(meta.get("role", ""))
			if w.public_claims.any(func(pc): return str(pc.get("who", "")) == who_id and str(pc.get("role", "")) == role_id):
				return true
		elif os.begins_with("reading:"):
			var r_eid: String = os.trim_prefix("reading:")
			var parts: PackedStringArray = r_eid.split(":")
			if parts.size() >= 2:
				var holder = real_npc if parts[1] == real_npc.id else w.by_id.get(parts[1])
				if holder != null:
					for en in holder.info_log:
						if info_eid(holder.id, en) == r_eid and en.get("shared", false):
							return true
	return false


static func _find_reading_for_card(holder, cid: String, crole: String, cday: int) -> Array:
	for i in range(holder.info_log.size()):
		var en: Dictionary = holder.info_log[i]
		if WorkshopLedger.reading(holder.id, en).id == cid:
			return [i, en]
	for i in range(holder.info_log.size()):
		var en: Dictionary = holder.info_log[i]
		if str(en.get("role", "")) == crole and int(en.get("day", -1)) == cday and not en.get("disowned", false):
			return [i, en]
	return [-1, {}]


static func _resolve_shared_reason(w, mind, real_npc, t_id: String, raw: Dictionary, vis_maps: Dictionary) -> Dictionary:
	var cid: String = str(raw.get("card_id", ""))
	var ckind: String = str(raw.get("card_kind", ""))
	var channel: String = str(raw.get("channel", ""))
	var csrc: String = str(raw.get("source", ""))
	var crole: String = str(raw.get("role", ""))
	var cnight: int = int(raw.get("night", -1))
	var cblock: String = str(raw.get("block", ""))
	var contrib: float = float(raw.get("contrib", 0.0))
	var strength: float = float(raw.get("strength", 0.3))
	var is_joint: bool = bool(raw.get("joint", false))
	var root_ids: Array = raw.get("root_ids", [])
	var owners: Array = raw.get("owners", [])
	var public_ids: Dictionary = vis_maps["public"]
	var player_ids: Dictionary = vis_maps["player"]

	if ckind == "circumstantial":
		return {
			"eid": cid,
			"why": str(raw.get("why_public", "")),
			"kind": str(raw.get("circ_visibility", "shared_player")),
			"strength": strength,
			"contrib": contrib,
			"entry": {},
			"channel": channel,
		}

	if ckind == "joint":
		var all_pub: bool = root_ids.all(func(r): return _root_is_public(w, mind, real_npc, str(r), public_ids))
		var all_plr: bool = root_ids.all(func(r): return _root_is_public(w, mind, real_npc, str(r), public_ids) or player_ids.has(str(r)))
		var j_kind: String = "public" if all_pub else ("shared_player" if all_plr else "shared_private")
		return {
			"eid": cid,
			"why": str(raw.get("why_public", "")),
			"kind": j_kind,
			"strength": strength,
			"contrib": contrib,
			"entry": {},
			"channel": channel,
		}

	if channel == "role_clash" and csrc == real_npc.id and ckind == "claim":
		return {
			"eid": "own_role",
			"why": str(raw.get("why_own", "")),
			"kind": "public" if real_npc.claim_public else "private",
			"strength": strength,
			"contrib": contrib,
			"entry": {},
			"channel": channel,
		}

	if csrc == real_npc.id and ckind == "report":
		var matched: Array = _find_reading_for_card(real_npc, cid, crole, cnight)
		var idx: int = int(matched[0])
		var en: Dictionary = matched[1]
		if en.is_empty() and mind != real_npc:
			var m2: Array = _find_reading_for_card(mind, cid, crole, cnight)
			en = m2[1]
		if not en.is_empty() and en.get("disowned", false):
			return {}
		var r_eid: String = info_eid(real_npc.id, en) if not en.is_empty() else ("info:%s:%d:%s" % [real_npc.id, cnight, crole])
		var self_shared: bool = not en.is_empty() and bool(en.get("shared", false))
		var board_pub: bool = public_ids.has(cid)
		var told_direct: bool = idx >= 0 and idx < real_npc.told_readings
		var board_plr: bool = player_ids.has(cid)
		# Whether an own reading is revealable is a matter of the reading itself: whether the town
		# (or the Demonologist) has it and knows it's theirs. The cards cited with it don't decide
		# it (Beadle, Nov 20): a reading already shared and claimed isn't "revealed" again because
		# a partner card is private, and one on the board only anonymously (a relay, a rumour)
		# while the gift is unclaimed stays theirs to reveal.
		var r_kind: String = "private"
		var r_why: String = str(raw.get("why_own", ""))
		if self_shared or (board_pub and real_npc.claim_public):
			r_kind = "public"
		elif told_direct or (board_plr and real_npc.claim_public):
			r_kind = "player"
		return {
			"eid": r_eid,
			"why": r_why,
			"kind": r_kind,
			"strength": strength,
			"contrib": contrib,
			"entry": en,
			"channel": channel,
		}

	if csrc == real_npc.id and ckind == "sighting":
		var seen_b: Dictionary = {}
		for b in real_npc.beliefs:
			if b.get("kind", "") == "saw" and b.get("who", "") == t_id and int(b.get("day", -1)) == cnight and int(b.get("phase", -1)) == C.NIGHT:
				seen_b = b
				break
		var blk_label: String = C.block_name(cblock) if cblock in C.BLOCKS else "the street"
		var when_s: String = C.spoken_when(cnight, w.day)
		var s_why: String = str(raw.get("why_own", ""))
		if not seen_b.is_empty():
			if str(seen_b.get("how", "street")) == "window":
				s_why = "I saw them out in the street from my window %s" % when_s
			elif real_npc.claim_public and C.ROLES.get(real_npc.claimed_role, {}).get("night_walk", false):
				s_why = "I saw them out on %s %s, while I was out on my duty" % [blk_label, when_s]
			else:
				s_why = "I saw them out on %s %s" % [blk_label, when_s]
		elif cnight >= 0:
			s_why = s_why.replace("on " + C.night_name(cnight), when_s)
		var already_disclosed: bool = (not seen_b.is_empty() and real_npc.told_to.has(_meeting()._town_sighting_key(real_npc, seen_b))) or public_ids.has(cid)
		var allowed_pub: bool = not seen_b.is_empty() and _meeting()._public_sighting_allowed(w, real_npc, seen_b)
		var s_kind: String = "shared_private"
		if already_disclosed or allowed_pub:
			s_kind = "public"
		elif player_ids.has(cid):
			s_kind = "shared_player"
		elif C.ROLES.get(real_npc.role, {}).get("night_walk", false):
			s_kind = "private"
		return {
			"eid": "sighting:%s:%s:%d:%s" % [real_npc.id, t_id, cnight, cblock],
			"why": s_why,
			"kind": s_kind,
			"strength": strength,
			"contrib": contrib,
			"entry": {},
			"channel": channel,
			"own_sighting": true,
			"own_sighting_disclosed": already_disclosed,
		}

	if ckind == "report" and w.by_id.has(csrc):
		var src_npc = w.by_id[csrc]
		var m_other: Array = _find_reading_for_card(src_npc, cid, crole, cnight)
		var en_o: Dictionary = m_other[1]
		if not en_o.is_empty() and en_o.get("disowned", false):
			return {}
		var o_eid: String = info_eid(csrc, en_o) if not en_o.is_empty() else ("info:%s:%d:%s" % [csrc, cnight, crole])
		var o_shared: bool = (not en_o.is_empty() and bool(en_o.get("shared", false))) or public_ids.has(cid)
		if csrc == t_id and channel in ["role_clash", "challenge_lie"] and w.public_claims.any(func(pc): return str(pc.get("who", "")) == t_id):
			o_shared = true
		var o_other_pub: bool = not is_joint or root_ids.all(func(r): return str(r) == cid or _root_is_public(w, mind, real_npc, str(r), public_ids))
		var o_other_plr: bool = not is_joint or root_ids.all(func(r): return str(r) == cid or _root_is_public(w, mind, real_npc, str(r), public_ids) or player_ids.has(str(r)))
		if o_shared and o_other_pub:
			return {
				"eid": o_eid,
				"why": str(raw.get("why_public", "")),
				"kind": "public",
				"strength": strength,
				"contrib": contrib,
				"entry": en_o,
				"channel": channel,
			}
		var heard_anon: bool = mind.ledger.get(o_eid, {}).get("meta", {}).get("workshop_receipts", {}).values().any(func(r): return r is Dictionary and r.get("content", {}).get("anonymous", false))
		var direct_private: bool = not en_o.is_empty() and not heard_anon and owners.any(func(o): return str(o) == "learned" or str(o).begins_with("reading:"))
		if direct_private and not is_joint:
			return {
				"eid": o_eid,
				"why": str(raw.get("why_public", "")),
				"kind": "relay",
				"strength": strength * 0.5,
				"contrib": contrib,
				"entry": en_o,
				"src": src_npc,
				"channel": channel,
			}
		if heard_anon:
			return {
				"eid": o_eid,
				"why": str(raw.get("why_public", "")),
				"kind": "public",
				"strength": strength * 0.5,
				"contrib": contrib,
				"entry": {},
				"channel": channel,
			}
		return {
			"eid": o_eid,
			"why": str(raw.get("why_public", "")),
			"kind": "shared_player" if (player_ids.has(cid) and o_other_plr) else "shared_private",
			"strength": strength,
			"contrib": contrib,
			"entry": en_o,
			"channel": channel,
		}

	var fallback_eid: String = cid
	for owner in owners:
		var os2: String = str(owner)
		if os2.begins_with("share:") or os2.begins_with("claim:") or os2.begins_with("tell:") or os2.begins_with("testimony:"):
			fallback_eid = os2.substr(os2.find(":") + 1)
			break
	var g_kind: String = "public"
	if is_joint:
		var g_pub: bool = root_ids.all(func(r): return _root_is_public(w, mind, real_npc, str(r), public_ids))
		var g_plr: bool = root_ids.all(func(r): return _root_is_public(w, mind, real_npc, str(r), public_ids) or player_ids.has(str(r)))
		g_kind = "public" if g_pub else ("shared_player" if g_plr else "shared_private")
	elif csrc == "player" and not public_ids.has(cid):
		g_kind = "shared_player"
	var g_why: String = str(raw.get("why_public", ""))
	if cnight >= 0:
		g_why = g_why.replace("on " + C.night_name(cnight), C.spoken_when(cnight, w.day))
	return {
		"eid": fallback_eid,
		"why": g_why,
		"kind": g_kind,
		"strength": strength,
		"contrib": contrib,
		"entry": {},
		"channel": channel,
	}


## The evidence cards a shared reason rests on (their fact ids), for recency: a joint
## reason's roots, otherwise its own card. Circumstantial and resentment reasons have none.
static func _reason_cards(raw: Dictionary) -> Array:
	var ids: Array = []
	var roots: Array = raw.get("root_ids", [])
	for id in (roots if not roots.is_empty() else [raw.get("card_id", "")]):
		if str(id).begins_with("fact:") and str(id) not in ids:
			ids.append(str(id))
	return ids

## Recency (sim/recency.gd): an NPC who states a reason before the town brings the cards
## behind it back to mind for everyone who hears it, as a presentation does for its
## listener. `whys` are the reasons actually spoken (matched against n's case against t);
## `extra` are cards cited outright (a relayed reading). A hinted, unshared reason cites
## nothing. Attention only: nobody's weight on a card changes.
static func recall_cited(w, n, t_id: String, whys: Array, extra: Array = []) -> Array:
	var ids: Array = extra.duplicate()
	var spoken: Array = whys.filter(func(x): return str(x) != "")
	if not spoken.is_empty():
		for item in case_against(w, n, t_id, 6):
			if str(item.get("why", "")) in spoken:
				for id in item.get("cards", []):
					if id not in ids:
						ids.append(id)
	if ids.is_empty():
		return ids
	for l in w.living():
		var mind = l.shadow if l.is_evil() and l.shadow != null else l
		Recency.refresh_cards(w, mind, ids)
	w.dlog.think(n.id, "recall_cited", "Bringing %d card(s) back to the town's mind about %s." % [ids.size(), t_id], {"cards": ids})
	return ids

## The connections model (workshop/connections.gd): the cards a nominator cites are a case
## put to everyone who hears the nomination. Each listener keeps it, and weighs those cards
## together at its trust in the nominator, fading by the day.
static func remember_nomination(w, n, t_id: String, ids: Array) -> void:
	if ids.is_empty():
		return
	var case_data: Dictionary = {"key": "nomination:%s:%s" % [n.id, t_id], "presenter": n.id, "target": t_id, "type": "evil", "cards": ids.duplicate(), "day": int(w.day)}
	for l in w.living():
		if l.id == n.id:
			continue
		var mind = l.shadow if l.is_evil() and l.shadow != null else l
		if not mind.workshop_state.has("connections"):
			mind.workshop_state["connections"] = {}
		var memory: Dictionary = mind.workshop_state.connections
		memory["nominations"] = Connections.stored_with(memory.get("nominations", []), case_data.duplicate(true), int(w.day))
		# The listener weighs the case from its next refresh: queued during meeting testimony
		# (flushed before supporters and the vote), so a silenced nominee's missing defence
		# can't leave the vote on beliefs from before the case (Codex's review of #146).
		refresh_beliefs(w, l, " (heard %s's case against %s)" % [n.id, t_id])

static func case_against(w, n, t_id: String, limit: int = 3) -> Array:
	var mind = n
	if n.is_evil():
		mind = n.shadow if n.shadow != null else n
	var ws_active: bool = mind.workshop_state.get("active", false)
	var items: Array = []
	if ws_active:
		if mind.workshop_state.get("reasons_pending", false) and w.workshop_reasons.is_valid():
			w.workshop_reasons.call(mind)
		var raw_list: Array = mind.workshop_state.get("reasons", {}).get(t_id, [])
		if not raw_list.is_empty():
			var vis_maps: Dictionary = _visibility_maps(w, mind, n)
			for raw in raw_list:
				var resolved: Dictionary = _resolve_shared_reason(w, mind, n, t_id, raw, vis_maps)
				if not resolved.is_empty() and resolved.get("why", "") != "":
					resolved["cards"] = _reason_cards(raw)
					items.append(resolved)
	var best_res: Dictionary = _mind().best_resentment_against(w, mind, t_id)
	if not best_res.is_empty():
		var r_strength: float = float(best_res.get("strength", 0.0))
		if r_strength >= 0.03:
			var f_id: String = str(best_res.get("friend", ""))
			var f_nm: String = w.by_id[f_id].name if w.by_id.has(f_id) else f_id
			var r_why: String = ("they pushed to hang %s" % f_nm) if str(best_res.get("role", "nominator")) == "nominator" else ("they voted to hang %s" % f_nm)
			items.append({
				"eid": "resentment:%s:%s" % [f_id, t_id],
				"why": r_why,
				"kind": "public",
				"strength": clampf(r_strength * 2.0, 0.25, 0.75),
				"contrib": r_strength,
				"entry": {},
				"channel": "resentment",
			})
	items.sort_custom(func(x, y): return float(x["contrib"]) > float(y["contrib"]))
	return items.slice(0, limit)

## Several of the nominator's own readings from one gift, recapped as one reason ("what my
## gift showed me over several nights points at them") rather than one
## sentence each (89077 finding 3: Constance's three Lamplighter counts against Kiran).
## Each merged item keeps the sentences it stands for in "whys", so the cards behind
## them are still the ones recalled.
static func _merge_gift_reasons(w, n, items: Array) -> Array:
	var by_role: Dictionary = {}
	for x in items:
		var en: Dictionary = x.get("entry", {})
		if not en.is_empty() and str(x.get("eid", "")).begins_with("info:%s:" % n.id) and str(en.get("role", "")) != "" and int(en.get("phase", C.NIGHT)) == C.NIGHT:
			by_role[str(en.role)] = by_role.get(str(en.role), []) + [x]
	var out: Array = []
	var done: Dictionary = {}
	for x in items:
		var en: Dictionary = x.get("entry", {})
		var role: String = str(en.get("role", "")) if not en.is_empty() else ""
		var group: Array = by_role.get(role, []) if role != "" else []
		if group.size() < 2 or not (x in group):
			out.append(x)
			continue
		if done.has(role):
			continue
		done[role] = true
		var nights: Array = []
		for g in group:
			var nd: int = int(g.entry.get("day", 0))
			if not (nd in nights):
				nights.append(nd)
		nights.sort()
		if nights.size() < 2:
			for g in group:
				out.append(g)
			continue
		var m: Dictionary = x.duplicate()
		# The nights are on the player's board already (each merged reading was told to the
		# town), so the line doesn't list them (Herald, by Michael's test, Nov 17).
		m["why"] = "what my gift showed me %s points at them" % ("on two nights" if nights.size() == 2 else "over several nights")
		m["whys"] = group.map(func(g): return str(g.get("why", "")))
		out.append(m)
	return out

## The nominator lays out their case: public reasons recapped (cosmetic: hearing them again
## changes nothing), and their strongest private one hinted at or brought out (claim and
## reading, with their usual effect, as at any other time). Returns {lines, facts}.
static func nomination_case(w, n, t, already: String) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	var spoken: Array = []
	if already.begins_with("I saw"):
		_meeting()._append_accusation_sighting(w, n, t, already, lines, facts, spoken)
	var items = case_against(w, n, t.id)
	# Each reason once: three readings of one gift can give the same sentence (89077:
	# Constance's three Lamplighter counts against Kiran).
	var recap: Array = []
	var merged_whys: Array = []
	for x in _merge_gift_reasons(w, n, items.filter(func(x): return x["kind"] == "public")):
		if x["why"] != already and not (already in x.get("whys", [])) and not (x["why"] in recap):
			recap.append(x["why"])
			merged_whys.append_array(x.get("whys", []))
	for r_why in recap.slice(0, 2):
		if str(r_why).begins_with("I saw"):
			_meeting()._append_accusation_sighting(w, n, t, str(r_why), lines, facts, spoken)
	var priv: Array = items.filter(func(x): return x["kind"] in ["private", "player"])
	var relays: Array = items.filter(func(x): return x["kind"] == "relay")
	if priv.is_empty() and not relays.is_empty():
		_meeting().relay_reading(w, n, relays[0]["src"], relays[0]["entry"], lines, facts)
	var description = ", ".join(PackedStringArray(items.map(func(x): return "%s (%s, %.2f)" % [x["why"], x["kind"], x["contrib"]])))
	w.dlog.think(n.id, "nomination_case", "Case against %s: %s." % [t.id, description if description != "" else "no citable reasons on record"], {"items": items.map(func(x): return {"eid": x["eid"], "kind": x["kind"]})})
	# "No premise" only when they've given none: not after "I saw them out" (89077: Nisha).
	if items.is_empty() and already == "":
		lines.append(say_voiced(n, "nomination_no_reasons", "I don't trust %s, and I can't say better than that." % t.name, {"target": t.name}))
	var cited_whys: Array = [already] + recap.slice(0, 2) + merged_whys
	var cited_cards: Array = []
	if priv.is_empty() and not relays.is_empty():
		cited_cards = relays[0].get("cards", [])
	if not recap.is_empty():
		var recap_s: String = "; and ".join(PackedStringArray(recap.slice(0, 2))).trim_suffix(".")
		lines.append(say_voiced(n, "nomination_recap", "Remember: %s." % recap_s, {"recap": recap_s}))
	if not priv.is_empty():
		var top: Dictionary = priv[0]
		var cost = _meeting().reveal_cost(w, n)
		var nom_susp: float = susp(n.shadow if n.is_evil() and n.shadow != null else n, t.id)
		var parts = {"strength": (top["strength"] - 0.45) * 1.4,
			"suspicion": (nom_susp - Tuning.Meeting.REVEAL_SUSPICION_PIVOT) * Tuning.Meeting.REVEAL_SUSPICION_SLOPE,
			"confidence": (trait_of(n, "confidence") - 0.5) * 0.6, "nominating": 0.2}
		for k in cost:
			parts["cost_" + k] = -cost[k]
		if decide(w, n, "reveal_to_nominate", parts, "Bring out what points at %s (%s) to back the nomination?" % [t.id, top["why"]]):
			_meeting()._public_disclosure(w, n, lines, facts)
			for p_item in priv.slice(0, 2):
				cited_whys.append(str(p_item.get("why", "")))
			# The disclosure shares the gift and readings, not sightings: also state the private
			# observations behind the nomination (as _public_accusation does), so the town hears
			# them and the nominee's defence can answer them.
			for p_item in priv.slice(0, 2):
				if p_item.get("own_sighting", false) and str(p_item.get("why", "")).begins_with("I saw"):
					_meeting()._append_accusation_sighting(w, n, t, str(p_item["why"]), lines, facts)
		else:
			n.hints[t.id] = {"day": w.day, "src": top["eid"]}
			lines.append(say_voiced(n, "nomination_held_reason", "And I have another reason I'm not ready to share yet."))
			facts.append({"kind": "accusation", "subject": [t.id], "source": n.id, "hint": true,
				"text": "%s nominated %s, hinting at a private reason they won't share yet." % [n.name, t.name]})
	remember_nomination(w, n, t.id, recall_cited(w, n, t.id, cited_whys, cited_cards))
	return {"lines": lines, "facts": facts, "spoken_facts": spoken}
