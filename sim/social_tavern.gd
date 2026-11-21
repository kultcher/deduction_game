## The evening tavern: its gossip and the town's mood toward the Demonologist (split from
## `sim/social.gd`; part of Social's inheritance chain).
extends "res://sim/social_approaches.gd"


# ---------------------------------------------------------------- evening tavern gossip



static func _anonymize_reading_text(w, src_id: String, e: Dictionary) -> String:
	var raw: String = C.third_person(str(e.get("text", "")))
	if src_id != "" and w.by_id.has(src_id):
		var nm: String = w.by_id[src_id].name
		if nm in raw:
			raw = raw.replace(nm + "'s", "their").replace(nm, "they")
	return raw.trim_suffix(".")

static func _player_heard_gossip_key(g, gkey: String) -> bool:
	var w = g.w
	for c in g.board:
		if c.get("deleted", false):
			continue
		var ck: String = str(c.get("kind", ""))
		if ck == "sighting":
			for who in c.get("subject", []):
				var sk: String = "sighting:%s:%d:%d:%s" % [who, int(c.get("day", -1)), int(c.get("phase", -1)), str(c.get("block", ""))]
				if sk == gkey:
					return true
		elif ck == "info":
			var rk: String = "reading:%s:%d:%s" % [str(c.get("role", "")), int(c.get("day", -1)), JSON.stringify(c.get("data", {}))]
			if rk == gkey:
				return true
			if gkey == "claim:" + str(c.get("role", "")):
				return true
		elif ck == "claim":
			if gkey == "claim:" + str(c.get("role", "")):
				return true
		elif ck == "hint":
			var subjs: Array = c.get("subject", [])
			if not subjs.is_empty() and gkey == "hint:%s:%s" % [str(subjs[0]), str(c.get("package", ""))]:
				return true
		elif ck == "secret":
			var owner: String = str(c.get("owner", c.get("subject", [""])[0] if not c.get("subject", []).is_empty() else ""))
			if gkey == "secret:" + owner:
				return true
	for c in w.public_claims:
		if gkey == "claim:" + str(c.get("role", "")):
			return true
	return false

## A tavern gossip item's value to the player (graded gossip; the tiers approved by Michael,
## Nov 20, drafted by Quill and Beadle):
##   1: something the player can file or check: an anonymous reading, or a night sighting
##      with a block and a night;
##   2: useful but softer: a gift claim in circulation, a gift-family hint about a named
##      person, or a secret about a named person;
##   3: colour: daytime sightings, haunts and town relationships.
static func gossip_tier(cand: Dictionary) -> int:
	var f: Dictionary = cand.get("fact", {})
	match str(f.get("kind", "")):
		"info":
			return 1
		"sighting":
			return 1 if int(f.get("phase", -1)) == C.NIGHT and str(f.get("block", "")) != "" else 3
		"claim", "hint", "secret":
			return 2
	return 3

## Evening Tavern Gossip: harvests 3-5 anonymized rumours from all non-strategizing
## NPC-to-NPC exchanges across the whole day (Morning, Afternoon, and Evening) plus
## unlearned profile haunts and public town relationships, favoring unheard items.
static func tavern_evening_gossip(g) -> Dictionary:
	var w = g.w
	var trng := RandomNumberGenerator.new()
	trng.seed = hash([w.seed_value, w.n_npcs, w.day, g.board.size(), "tavern_evening_gossip"])
	var target_count: int = trng.randi_range(Tuning.Social.TAVERN_GOSSIP_MIN_ITEMS, Tuning.Social.TAVERN_GOSSIP_MAX_ITEMS)
	var candidates: Array = []
	var seen_keys: Dictionary = {}

	# 1. Spoken NPC-to-NPC items from anywhere in town today and yesterday (evil strategizing
	# never enters daily_npc_shares). Yesterday's weigh less (TAVERN_YESTERDAY_MULT).
	var group_mult: Dictionary = {}
	for rec in w.daily_npc_shares:
		var rec_day: int = int(rec.get("day", -1))
		if rec_day != w.day and rec_day != w.day - 1:
			continue
		var it: Dictionary = rec.get("item", {})
		var ik: String = str(it.get("kind", ""))
		var share_group: String = "share:%d" % candidates.size()
		group_mult[share_group] = 1.0 if rec_day == w.day else Tuning.Social.TAVERN_YESTERDAY_MULT
		if ik in ["opinion", "unease", "case", ""]:
			continue
		if ik == "reading":
			var e: Dictionary = it.get("entry", {})
			var role: String = str(e.get("role", ""))
			if role == "" or (role == "medium" and e.get("data", {}).get("item", {}).get("type", "") == "suspicion"):
				continue
			var src_id: String = str(it.get("from", ""))
			var gkey: String = "reading:%s:%d:%s" % [role, int(e.get("day", w.day)), JSON.stringify(e.get("data", {}))]
			if not seen_keys.has(gkey):
				seen_keys[gkey] = true
				var clean_rep: String = _anonymize_reading_text(w, src_id, e)
				var rname: String = C.role_name(role)
				var body: String = "someone heard a %s reading that %s." % [rname, clean_rep]
				var fact: Dictionary = {
					"kind": "info", "role": role, "day": int(e.get("day", w.day)),
					"data": e.get("data", {}).duplicate(true), "subject": [],
					"source": "rumour", "anonymous": true, "tavern_gossip": true,
					"workshop_usable": false, "pressable": false, "class": "speech",
					"text": "Tavern rumour: someone heard a %s reading (%s)." % [rname, clean_rep],
				}
				if e.has("phase"):
					fact["phase"] = int(e["phase"])
				var heard: bool = _player_heard_gossip_key(g, gkey)
				candidates.append({"gkey": gkey, "group": share_group, "heard": heard,
					"weight": Tuning.Social.TAVERN_HEARD_SPOKEN_WEIGHT if heard else Tuning.Social.TAVERN_UNHEARD_SPOKEN_WEIGHT,
					"body": body, "fact": fact})
			# A shared reading also put that gift claim and role family into circulation:
			var ckey: String = "claim:" + role
			if not seen_keys.has(ckey):
				seen_keys[ckey] = true
				var rname2: String = C.role_name(role)
				var heard_c: bool = _player_heard_gossip_key(g, ckey)
				candidates.append({"gkey": ckey, "group": share_group, "heard": heard_c,
					"weight": (Tuning.Social.TAVERN_HEARD_SPOKEN_WEIGHT if heard_c else Tuning.Social.TAVERN_UNHEARD_SPOKEN_WEIGHT) * 0.65,
					"body": "they'd heard of a %s in town." % rname2,
					"fact": {"kind": "claim", "role": role, "subject": [], "source": "rumour",
						"tavern_gossip": true, "workshop_usable": false, "pressable": false, "class": "speech",
						"text": "Tavern rumour: word is there's a %s in town." % rname2}})
			var pkg: String = C.hint_package(w, role)
			if src_id != "" and w.by_id.has(src_id) and C.HINT_PACKAGES.has(pkg):
				var hkey: String = "hint:%s:%s" % [src_id, pkg]
				if not seen_keys.has(hkey):
					seen_keys[hkey] = true
					var sname: String = w.by_id[src_id].name
					var htopic: String = HINT_TOPICS.get(pkg, C.HINT_PACKAGES[pkg]["name"])
					var heard_h: bool = _player_heard_gossip_key(g, hkey)
					candidates.append({"gkey": hkey, "group": share_group, "heard": heard_h,
						"weight": (Tuning.Social.TAVERN_HEARD_SPOKEN_WEIGHT if heard_h else Tuning.Social.TAVERN_UNHEARD_SPOKEN_WEIGHT) * 0.65,
						"body": "%s's role has to do with %s." % [sname, htopic],
						"fact": {"kind": "hint", "subject": [src_id], "package": pkg,
							"roles": C.HINT_PACKAGES[pkg]["roles"].duplicate(), "source": "rumour",
							"tavern_gossip": true, "workshop_usable": false, "pressable": false, "class": "speech",
							"text": "Tavern rumour: %s's gift has to do with %s." % [sname, htopic]}})
		elif ik in ["claim", "role_claim"]:
			var cr: String = str(it.get("role", ""))
			if cr in C.ROLES:
				var ckey2: String = "claim:" + cr
				if not seen_keys.has(ckey2):
					seen_keys[ckey2] = true
					var cr_name: String = C.role_name(cr)
					var heard_cr: bool = _player_heard_gossip_key(g, ckey2)
					candidates.append({"gkey": ckey2, "group": share_group, "heard": heard_cr,
						"weight": Tuning.Social.TAVERN_HEARD_SPOKEN_WEIGHT if heard_cr else Tuning.Social.TAVERN_UNHEARD_SPOKEN_WEIGHT,
						"body": "they'd heard of a %s in town." % cr_name,
						"fact": {"kind": "claim", "role": cr, "subject": [], "source": "rumour",
							"tavern_gossip": true, "workshop_usable": false, "pressable": false, "class": "speech",
							"text": "Tavern rumour: word is there's a %s in town." % cr_name}})
		elif ik in ["hint", "role_hint"]:
			var habout: String = str(it.get("about", it.get("from", "")))
			var hpkg: String = str(it.get("package", ""))
			if habout != "" and w.by_id.has(habout) and C.HINT_PACKAGES.has(hpkg):
				var hkey2: String = "hint:%s:%s" % [habout, hpkg]
				if not seen_keys.has(hkey2):
					seen_keys[hkey2] = true
					var hname: String = w.by_id[habout].name
					var htop: String = HINT_TOPICS.get(hpkg, C.HINT_PACKAGES[hpkg]["name"])
					var heard_rh: bool = _player_heard_gossip_key(g, hkey2)
					candidates.append({"gkey": hkey2, "group": share_group, "heard": heard_rh,
						"weight": Tuning.Social.TAVERN_HEARD_SPOKEN_WEIGHT if heard_rh else Tuning.Social.TAVERN_UNHEARD_SPOKEN_WEIGHT,
						"body": "%s's role has to do with %s." % [hname, htop],
						"fact": {"kind": "hint", "subject": [habout], "package": hpkg,
							"roles": C.HINT_PACKAGES[hpkg]["roles"].duplicate(), "source": "rumour",
							"tavern_gossip": true, "workshop_usable": false, "pressable": false, "class": "speech",
							"text": "Tavern rumour: %s's gift has to do with %s." % [hname, htop]}})
		elif ik == "sighting":
			var about: String = str(it.get("about", ""))
			var blk: String = str(it.get("block", ""))
			var s_day: int = int(it.get("day", w.day - 1))
			if about != "" and w.by_id.has(about) and C.BLOCKS.has(blk):
				var skey: String = "sighting:%s:%d:%d:%s" % [about, s_day, C.NIGHT, blk]
				if not seen_keys.has(skey):
					seen_keys[skey] = true
					var who_name: String = w.by_id[about].name
					var blk_name: String = C.block_name(blk)
					var when_s: String = C.spoken_when(s_day, w.day)
					var heard_s: bool = _player_heard_gossip_key(g, skey)
					candidates.append({"gkey": skey, "group": share_group, "heard": heard_s,
						"weight": Tuning.Social.TAVERN_HEARD_SPOKEN_WEIGHT if heard_s else Tuning.Social.TAVERN_UNHEARD_SPOKEN_WEIGHT,
						"body": "someone saw %s out on %s %s." % [who_name, blk_name, when_s],
						"fact": {"kind": "sighting", "subject": [about], "block": blk, "day": s_day, "phase": C.NIGHT,
							"source": "rumour", "tavern_gossip": true, "workshop_usable": false, "pressable": false, "class": "speech",
							"text": "Tavern rumour: someone saw %s out on %s on night %d." % [who_name, blk_name, s_day]}})
		elif ik == "day_sighting":
			var dabout: String = str(it.get("about", ""))
			var dloc: String = str(it.get("loc", ""))
			var dblk: String = str(it.get("block", C.loc_block(dloc)))
			var d_day: int = int(it.get("day", w.day))
			var d_phase: int = int(it.get("phase", C.MORNING))
			if dabout != "" and w.by_id.has(dabout) and C.BLOCKS.has(dblk):
				var dskey: String = "sighting:%s:%d:%d:%s" % [dabout, d_day, d_phase, dblk]
				if not seen_keys.has(dskey):
					seen_keys[dskey] = true
					var dname: String = w.by_id[dabout].name
					var place_s: String = w.loc_name(dloc) if dloc != "" else C.block_name(dblk)
					var when_d: String = ("this " + C.PHASES[d_phase].to_lower()) if d_day == w.day else ("yesterday " + C.PHASES[d_phase].to_lower())
					var heard_ds: bool = _player_heard_gossip_key(g, dskey)
					var ds_fact: Dictionary = {"kind": "sighting", "subject": [dabout], "block": dblk, "day": d_day, "phase": d_phase,
						"source": "rumour", "tavern_gossip": true, "workshop_usable": false, "pressable": false, "class": "speech",
						"text": "Tavern rumour: someone saw %s at %s, day %d %s." % [dname, place_s, d_day, C.PHASES[d_phase]]}
					if dloc != "":
						ds_fact["loc"] = dloc
					candidates.append({"gkey": dskey, "group": share_group, "heard": heard_ds,
						"weight": Tuning.Social.TAVERN_HEARD_SPOKEN_WEIGHT if heard_ds else Tuning.Social.TAVERN_UNHEARD_SPOKEN_WEIGHT,
						"body": "someone spotted %s at %s %s." % [dname, place_s, when_d],
						"fact": ds_fact})
		elif ik == "secret":
			var owner: String = str(it.get("about", ""))
			if owner != "" and w.by_id.has(owner) and not w.by_id[owner].secret.is_empty():
				var seckey: String = "secret:" + owner
				if not seen_keys.has(seckey):
					seen_keys[seckey] = true
					var o = w.by_id[owner]
					var stext: String = str(o.secret.get("text", "keeps late hours"))
					var heard_sec: bool = _player_heard_gossip_key(g, seckey)
					candidates.append({"gkey": seckey, "group": share_group, "heard": heard_sec,
						"weight": Tuning.Social.TAVERN_HEARD_SPOKEN_WEIGHT if heard_sec else Tuning.Social.TAVERN_UNHEARD_SPOKEN_WEIGHT,
						"body": "%s %s." % [o.name, stext],
						"fact": {"kind": "secret", "subject": [owner], "owner": owner, "source": "rumour",
							"secret_kind": o.secret.get("kind", ""), "tavern_gossip": true, "workshop_usable": false, "pressable": false, "class": "speech",
							"text": "Tavern rumour: %s %s." % [o.name, stext]}})

	for c in candidates:
		c["weight"] = float(c.get("weight", 0.0)) * float(group_mult.get(str(c.get("group", "")), 1.0))
	# 2. Non-case-board profile backfill pool: unlearned haunts and public town relationships (never Secret Lovers).
	for n in w.npcs:
		var known_h: Array = g.known_haunts.get(n.id, [])
		for loc_id in n.haunts:
			if loc_id in known_h:
				continue
			var h_gkey: String = "haunt:%s:%s" % [n.id, loc_id]
			if seen_keys.has(h_gkey):
				continue
			seen_keys[h_gkey] = true
			candidates.append({"gkey": h_gkey, "group": "haunt:" + n.id, "heard": false,
				"weight": Tuning.Social.TAVERN_BACKFILL_PROFILE_WEIGHT * (1.0 if n.alive else 0.7),
				"body": "%s likes to hang out at %s." % [n.name, w.loc_name(loc_id)],
				"profile_haunt": {"id": n.id, "loc": loc_id}})

	for bond in w.town_relationships:
		var people: Array = bond.get("people", []).duplicate()
		if people.size() != 2 or not people.all(func(pid): return w.by_id.has(pid)):
			continue
		var raw_key: String = str(bond.get("kind", "")) + ":" + ":".join(PackedStringArray(people))
		var sorted_p: Array = people.duplicate()
		sorted_p.sort()
		var sorted_key: String = str(bond.get("kind", "")) + ":" + ":".join(PackedStringArray(sorted_p))
		if g.known_relationships.has(raw_key) or g.known_relationships.has(sorted_key):
			continue
		var b_gkey: String = "bond:" + sorted_key
		if seen_keys.has(b_gkey):
			continue
		seen_keys[b_gkey] = true
		var na: String = w.by_id[people[0]].name
		var nb: String = w.by_id[people[1]].name
		var bbody: String = ("%s and %s are close." % [na, nb]) if bond.get("kind", "") == "friend" else ("%s and %s don't get along." % [na, nb])
		candidates.append({"gkey": b_gkey, "group": b_gkey, "heard": false,
			"weight": Tuning.Social.TAVERN_BACKFILL_PROFILE_WEIGHT,
			"body": bbody,
			"profile_bond": {"key": raw_key, "kind": str(bond.get("kind", "")), "people": people}})

	# Each item's value to the player (graded gossip, Michael, Nov 19).
	for c in candidates:
		c["tier"] = gossip_tier(c)
	# Tiered selection: prefer unheard spoken & profile backfill first; only touch already-heard
	# spoken items if the unheard pools cannot fill the rolled 3-5 slots.
	var unheard_pool: Array = candidates.filter(func(c): return not c.get("heard", false))
	var heard_pool: Array = candidates.filter(func(c): return c.get("heard", false))
	var chosen: Array = []
	var used_groups: Dictionary = {}
	# The budget comes first: up to TAVERN_TIER1_TARGET unheard tier-1 items and
	# TAVERN_TIER2_TARGET unheard tier-2 items, each drawn by weight within its tier, so the
	# player usually gets at least two useful pieces. Already-heard items don't count: they
	# aren't news. Whatever the offer lacks, the ordinary draw below fills.
	var budget: Array = [[1, Tuning.Social.TAVERN_TIER1_TARGET], [2, Tuning.Social.TAVERN_TIER2_TARGET]]
	for b in budget:
		var tier_pool: Array = unheard_pool.filter(func(c): return int(c["tier"]) == int(b[0]))
		_tavern_draw(trng, tier_pool, chosen, used_groups, mini(target_count, chosen.size() + int(b[1])))
	for pool in [unheard_pool, heard_pool]:
		_tavern_draw(trng, pool, chosen, used_groups, target_count)
	# The budget's picks were drawn first; mix them in so the useful items don't always lead.
	for i in range(chosen.size() - 1, 0, -1):
		var j: int = trng.randi_range(0, i)
		var tmp = chosen[i]
		chosen[i] = chosen[j]
		chosen[j] = tmp

	if chosen.is_empty():
		var quiet_lines: Array = ["You spend the evening nursing a cup in the corner, but the taproom talk turns up nothing beyond the weather."]
		var quiet_vibe: Dictionary = town_vibe(g)
		if not quiet_vibe.is_empty():
			quiet_lines.append("  • " + str(quiet_vibe["line"]))
		return {"lines": quiet_lines, "facts": [], "haunts": [], "bonds": [], "vibe": quiet_vibe}

	var lead_order: Array = range(TAVERN_LEADS.size())
	for i in range(lead_order.size() - 1, 0, -1):
		var j: int = trng.randi_range(0, i)
		var tmp = lead_order[i]
		lead_order[i] = lead_order[j]
		lead_order[j] = tmp

	var lines: Array = ["You settle into a quiet corner of the Drowned Lamb and listen as the evening crowd trades talk from around town:"]
	var facts: Array = []
	var haunts: Array = []
	var bonds: Array = []
	for i in range(chosen.size()):
		var item: Dictionary = chosen[i]
		var lead: String = TAVERN_LEADS[lead_order[i % lead_order.size()]]
		lines.append("  • " + lead + str(item["body"]))
		if item.has("fact"):
			facts.append(item["fact"])
		if item.has("profile_haunt"):
			haunts.append(item["profile_haunt"])
		if item.has("profile_bond"):
			bonds.append(item["profile_bond"])
	# Always, beside the drawn items: what the town makes of the Demonologist.
	var vibe: Dictionary = town_vibe(g)
	if not vibe.is_empty():
		lines.append("  • " + str(vibe["line"]))
	w.dlog.add("tavern_evening_gossip", "player", "", {"count": chosen.size(), "keys": chosen.map(func(c): return c["gkey"]),
		"tiers": chosen.map(func(c): return int(c.get("tier", 3))), "offered_tiers": candidates.map(func(c): return int(c.get("tier", 3))),
		"offered_groups": candidates.map(func(c): return str(c.get("group", "")))},
		"Evening tavern gossip yielded %d item(s)." % chosen.size())
	return {"lines": lines, "facts": facts, "haunts": haunts, "bonds": bonds, "vibe": vibe}



## The tavern's weighted draw: adds items from `pool` to `chosen` (one per share group, an item
## not already chosen) until `chosen` holds `up_to` or the pool runs dry.
static func _tavern_draw(trng: RandomNumberGenerator, pool: Array, chosen: Array, used_groups: Dictionary, up_to: int) -> void:
	var avail: Array = pool.filter(func(c): return not chosen.has(c))
	while chosen.size() < up_to and not avail.is_empty():
		avail = avail.filter(func(c): return not used_groups.has(c.get("group", "")))
		if avail.is_empty():
			break
		var tot: float = 0.0
		for c in avail:
			tot += maxf(float(c.get("weight", 0.1)), 0.001)
		var draw: float = trng.randf() * tot
		var picked_idx: int = avail.size() - 1
		for idx in range(avail.size()):
			draw -= maxf(float(avail[idx].get("weight", 0.1)), 0.001)
			if draw <= 0.0:
				picked_idx = idx
				break
		var sel: Dictionary = avail[picked_idx]
		chosen.append(sel)
		used_groups[sel.get("group", "")] = true
		avail.remove_at(picked_idx)


## 0.1-wide bands centred on neutral: 0..6 for <0.25, 0.25-0.35, ..., >=0.75.
static func vibe_band(v: float) -> int:
	return clampi(int(floor((v - 0.25) / 0.1 + 1e-9)) + 1, 0, 6)  # epsilon: 0.35 is the band above

static func town_vibe(g) -> Dictionary:
	var w = g.w
	var goods: Array = w.living().filter(func(n): return not n.is_evil())
	if goods.is_empty():
		return {}
	var rap: float = 0.0
	var cred: float = 0.0
	var low: float = 1.0
	for n in goods:
		rap += float(n.trust)
		cred += float(n.credibility)
		low = minf(low, float(n.trust))
	rap /= goods.size()
	cred /= goods.size()
	var rb: int = vibe_band(rap)
	var cb: int = vibe_band(cred)
	var r_text: String = VIBE_RAPPORT[rb]
	var c_text: String = VIBE_COMPETENCE[cb]
	var trend: Dictionary = {}
	var last: Dictionary = g.town_vibe_heard
	if not last.is_empty():
		# Compare the same people: a death (or a turned soul) alone shouldn't read as a change
		# of mood. Mean change over those in both readings; older saves fall back to averages.
		var dr: float = rap - float(last.get("rapport", rap))
		var dc: float = cred - float(last.get("credibility", cred))
		var per_last: Dictionary = last.get("per", {})
		if not per_last.is_empty():
			var both: Array = goods.filter(func(n): return per_last.has(n.id))
			dr = 0.0
			dc = 0.0
			for n in both:
				dr += float(n.trust) - float(per_last[n.id][0])
				dc += float(n.credibility) - float(per_last[n.id][1])
			if not both.is_empty():
				dr /= both.size()
				dc /= both.size()
		if absf(dr) >= Tuning.Social.TOWN_VIBE_TREND:
			trend["rapport"] = dr
			r_text += ", and warming since you last listened" if dr > 0.0 else ", though cooling since you last listened"
		if absf(dc) >= Tuning.Social.TOWN_VIBE_TREND:
			trend["credibility"] = dc
			c_text += ", and rising" if dc > 0.0 else ", but slipping"
	var line: String = "And about you, Demonologist: %s; %s." % [r_text, c_text]
	if low <= rap - Tuning.Social.TOWN_VIBE_OUTLIER and low < 0.45:
		line += " Not everyone agrees, mind: someone still doesn't trust you."
	var per: Dictionary = {}
	for n in goods:
		per[n.id] = [float(n.trust), float(n.credibility)]
	g.town_vibe_heard = {"day": w.day, "rapport": rap, "credibility": cred, "per": per}
	w.dlog.add("town_vibe", "player", "", {"rapport": snappedf(rap, 0.001), "credibility": snappedf(cred, 0.001),
		"rapport_band": rb, "credibility_band": cb, "trend": trend, "low": snappedf(low, 0.001)}, line)
	return {"line": line, "rapport": rap, "credibility": cred, "rapport_band": rb, "credibility_band": cb, "trend": trend}
