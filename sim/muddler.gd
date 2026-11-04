## Muddler secret modifier ("muddler") simulation & card-deprecation helpers.
##
## A Muddler is unaware of their condition. Whenever they pass on someone else's gift
## reading or night sighting, they have a 65% chance (`Tuning.Social.MUDDLER_CHANCE`) to
## swap out one fact (a person, block, role, yes/no, or count) while preserving the
## original speaker/reader identity and gift role. Rolled once per heard item key so the
## Muddler repeats the same garbled version everywhere.
extends RefCounted

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Gifts = preload("res://sim/gifts.gd")


static func _script_good_roles(w) -> Array:
	if w.case_script != null and not w.case_script.town.is_empty():
		return w.case_script.town.duplicate()
	return C.GOOD_ROLES.duplicate()


static func _script_minion_roles(w) -> Array:
	if w.case_script != null and not w.case_script.minions.is_empty():
		return w.case_script.minions.duplicate()
	return C.MINION_ROLES.duplicate()


static func _script_all_roles(w) -> Array:
	var out: Array = _script_good_roles(w) + _script_minion_roles(w)
	var dem: Array = w.case_script.demons if (w.case_script != null and not w.case_script.demons.is_empty()) else ["demon"]
	for r in dem:
		if r not in out:
			out.append(r)
	return out


static func _script_secrets(w) -> Array:
	if w.case_script != null and not w.case_script.secrets.is_empty():
		return w.case_script.secrets.duplicate()
	return C.SECRET_MOD_LIST.duplicate()


static func _other_person(w, exclude: Array) -> String:
	var pool: Array = w.npcs.filter(func(p): return p.id not in exclude).map(func(p): return p.id)
	var alive_pool: Array = pool.filter(func(pid): return w.by_id[pid].alive)
	var use_pool: Array = alive_pool if not alive_pool.is_empty() else pool
	return str(w.pick(use_pool)) if not use_pool.is_empty() else ""


static func _other_block(w, exclude: String, min_residents: int = 0, not_home_of: String = "") -> String:
	var home_blk: String = w.by_id[not_home_of].home_block if (not_home_of != "" and w.by_id.has(not_home_of)) else ""
	var pool: Array = C.BLOCKS.keys().filter(func(b):
		if b == exclude or (home_blk != "" and b == home_blk):
			return false
		if min_residents > 0 and w.npcs.filter(func(p): return p.home_block == b).size() < min_residents:
			return false
		return true)
	if pool.is_empty():
		pool = C.BLOCKS.keys().filter(func(b): return b != exclude)
	return str(w.pick(pool)) if not pool.is_empty() else exclude


static func _other_int(w, cur: int, lo: int, hi: int) -> int:
	var opts: Array = []
	for v in range(lo, hi + 1):
		if v != cur:
			opts.append(v)
	return int(w.pick(opts)) if not opts.is_empty() else cur


static func _rebuild_reading_text(w, role: String, d: Dictionary, fallback_text: String) -> String:
	var nm = func(pid: String) -> String:
		return w.by_id[pid].name if w.by_id.has(pid) else pid
	match role:
		"seer":
			var p: Array = d.get("pair", [])
			if p.size() == 2:
				return "I looked at %s and %s: %s" % [nm.call(p[0]), nm.call(p[1]), "one of them is the demon" if d.get("yes", false) else "neither is the demon"]
		"clerk", "archivist":
			var p2: Array = d.get("pair", [])
			if p2.size() == 2:
				return "I learned that either %s or %s is the %s" % [nm.call(p2[0]), nm.call(p2[1]), C.role_name(str(d.get("role", "")))]
		"rumormonger":
			var p3: Array = d.get("pair", [])
			if p3.size() == 2:
				return "I heard that either %s or %s carries a secret (%s)" % [nm.call(p3[0]), nm.call(p3[1]), C.secret_name(str(d.get("secret", "marked")))]
		"surveyor":
			if d.has("block"):
				var bname: String = C.block_name(str(d.get("block", "")))
				return "I surveyed %s: %s" % [bname, "all the residents there share the same alignment" if d.get("same", false) else "not all the residents there share the same alignment"]
			var cnt: int = int(d.get("count", 1))
			return "at the start of the case, %d of the four blocks had an evil resident" % cnt
		"dowser":
			var grp: Array = d.get("group", [])
			var names: Array = grp.map(func(pid): return nm.call(str(pid)))
			var cnt2: int = int(d.get("count", 0))
			return "on %s with %s, I sensed %s evil among them" % [C.block_name(str(d.get("block", ""))), ", ".join(PackedStringArray(names)), "no" if cnt2 == 0 else str(cnt2)]
		"hearthwitch":
			var nb: Array = d.get("nbrs", [])
			if nb.size() == 2:
				return "between my neighbours %s and %s, %d of them %s evil" % [nm.call(nb[0]), nm.call(nb[1]), int(d.get("count", 0)), "is" if int(d.get("count", 0)) == 1 else "are"]
		"lamplighter":
			var lc: int = int(d.get("count", 0))
			return "on my rounds I counted %d other %s abroad" % [lc, "soul" if lc == 1 else "souls"]
		"nightwatch":
			var seen: Array = d.get("seen", [])
			var b_nw: String = C.block_name(str(d.get("block", "")))
			if seen.is_empty():
				return "I watched %s and nobody passed through" % b_nw
			var snames: String = ", ".join(PackedStringArray(seen.map(func(pid): return nm.call(str(pid)))))
			return "I watched %s and saw %s pass through" % [b_nw, snames]
		"warden":
			return "I stood guard at %s's door" % nm.call(str(d.get("target", "")))
		"gravedigger":
			return "when we buried %s, I saw they were the %s" % [nm.call(str(d.get("executed", ""))), C.role_name(str(d.get("role", "")))]
		"veteran":
			return "the demon came for me, and I drove it off; it came from %s" % C.block_name(str(d.get("block", "")))
		"martyr":
			if d.get("evil", false):
				return "when %s went to the gallows, my gift did not stir: they were evil" % nm.call(str(d.get("target", "")))
			return "I bound my life to %s" % nm.call(str(d.get("target", "")))
		"chronicler":
			var tr: Array = d.get("trio", [])
			if tr.size() == 3:
				return "at the start of the case, among %s, %s, and %s, there was one ordinary townsfolk, one secret-holder, and one Minion" % [nm.call(tr[0]), nm.call(tr[1]), nm.call(tr[2])]
		"augur":
			return "someone who crossed my path in public today registered as the demon" if d.get("yes", false) else "nobody who crossed my path in public today registered as the demon"
		"magistrate":
			return "in the nomination of %s by %s, %s" % [nm.call(str(d.get("nominee", ""))), nm.call(str(d.get("nominator", ""))), "both shared the same alignment" if d.get("same", false) else "they did not share the same alignment"]
		"executor":
			if d.get("assigned", false):
				return "at the start of the case, %s was placed in my charge" % nm.call(str(d.get("target", "")))
			return "upon %s's death, I learned their true role was the %s" % [nm.call(str(d.get("target", ""))), C.role_name(str(d.get("role", "")))]
		"registrar":
			var rnames: String = ", ".join(PackedStringArray(d.get("roles", []).map(func(r): return C.role_name(str(r)))))
			if not d.has("target"):
				return "my register lists %s, with at least one in town" % rnames
			return "I checked %s against my register (%s): %s" % [nm.call(str(d.get("target", ""))), rnames, "they hold one of those roles" if d.get("yes", false) else "they hold none of those roles"]
	return fallback_text


static func mutate_reading_entry(w, muddler, src_id: String, orig: Dictionary) -> Dictionary:
	var role: String = str(orig.get("role", ""))
	if role in ["", "medium", "sexton", "psychologist"]:
		return {}
	if orig.get("muddled", false):
		return orig.duplicate(true)
	var d: Dictionary = orig.get("data", {}).duplicate(true)
	var changed: bool = false
	match role:
		"seer":
			var pair: Array = d.get("pair", []).duplicate()
			if pair.size() == 2:
				if w.chance(0.5):
					var slot: int = w.rng.randi_range(0, 1)
					var rep: String = _other_person(w, [src_id, pair[0], pair[1]])
					if rep != "":
						pair[slot] = rep
						d["pair"] = pair
						changed = true
				if not changed:
					d["yes"] = not bool(d.get("yes", false))
					changed = true
		"clerk", "archivist":
			var pair2: Array = d.get("pair", []).duplicate()
			var rpool: Array = (_script_good_roles(w) if role == "clerk" else _script_minion_roles(w)).filter(func(r): return r != str(d.get("role", "")))
			if pair2.size() == 2 and (rpool.is_empty() or w.chance(0.5)):
				var slot2: int = w.rng.randi_range(0, 1)
				var rep2: String = _other_person(w, [src_id, pair2[0], pair2[1]])
				if rep2 != "":
					pair2[slot2] = rep2
					d["pair"] = pair2
					changed = true
			if not changed and not rpool.is_empty():
				d["role"] = str(w.pick(rpool))
				changed = true
		"rumormonger":
			var pair3: Array = d.get("pair", []).duplicate()
			var spool: Array = _script_secrets(w).filter(func(s): return s != str(d.get("secret", "")))
			if pair3.size() == 2 and (spool.is_empty() or w.chance(0.5)):
				var slot3: int = w.rng.randi_range(0, 1)
				var rep3: String = _other_person(w, [src_id, pair3[0], pair3[1]])
				if rep3 != "":
					pair3[slot3] = rep3
					d["pair"] = pair3
					changed = true
			if not changed and not spool.is_empty():
				d["secret"] = str(w.pick(spool))
				changed = true
		"surveyor":
			if d.has("block"):
				var alt_blk: String = _other_block(w, str(d.get("block", "")), 2, src_id)
				if alt_blk != str(d.get("block", "")) and w.chance(0.5):
					d["block"] = alt_blk
					changed = true
				else:
					d["same"] = not bool(d.get("same", false))
					changed = true
			else:
				var cur_c: int = int(d.get("count", 1))
				var nc: int = _other_int(w, cur_c, 1, 4)
				if nc != cur_c:
					d["count"] = nc
					changed = true
		"dowser":
			var grp: Array = d.get("group", []).duplicate()
			if not grp.is_empty() and w.chance(0.5):
				var gi: int = w.rng.randi_range(0, grp.size() - 1)
				var grep: String = _other_person(w, [src_id] + grp)
				if grep != "":
					grp[gi] = grep
					d["group"] = grp
					changed = true
			if not changed and not grp.is_empty():
				var cur_dc: int = int(d.get("count", 0))
				var ndc: int = _other_int(w, cur_dc, 0, grp.size())
				if ndc != cur_dc:
					d["count"] = ndc
					changed = true
		"hearthwitch":
			var cur_hc: int = int(d.get("count", 0))
			var nhc: int = _other_int(w, cur_hc, 0, 2)
			if nhc != cur_hc:
				d["count"] = nhc
				changed = true
		"lamplighter":
			var cur_lc: int = int(d.get("count", 0))
			var nlc: int = _other_int(w, cur_lc, 0, maxi(2, w.npcs.size() - 2))
			if nlc != cur_lc:
				d["count"] = nlc
				changed = true
		"nightwatch":
			var seen: Array = d.get("seen", []).duplicate()
			if not seen.is_empty() and w.chance(0.5):
				var si: int = w.rng.randi_range(0, seen.size() - 1)
				var srep: String = _other_person(w, [src_id] + seen)
				if srep != "":
					seen[si] = srep
					d["seen"] = seen
					changed = true
			if not changed:
				var nb_nw: String = _other_block(w, str(d.get("block", "")))
				if nb_nw != str(d.get("block", "")):
					d["block"] = nb_nw
					changed = true
		"warden", "martyr":
			var wrep: String = _other_person(w, [src_id, str(d.get("target", ""))])
			if wrep != "":
				d["target"] = wrep
				changed = true
		"gravedigger":
			var gr_pool: Array = _script_all_roles(w).filter(func(r): return r != str(d.get("role", "")))
			if not gr_pool.is_empty():
				d["role"] = str(w.pick(gr_pool))
				changed = true
		"veteran":
			var vblk: String = _other_block(w, str(d.get("block", "")))
			if vblk != str(d.get("block", "")):
				d["block"] = vblk
				changed = true
		"chronicler":
			var trio: Array = d.get("trio", []).duplicate()
			if trio.size() == 3:
				var ti: int = w.rng.randi_range(0, 2)
				var trep: String = _other_person(w, [src_id] + trio)
				if trep != "":
					trio[ti] = trep
					d["trio"] = trio
					changed = true
		"augur":
			d["yes"] = not bool(d.get("yes", false))
			changed = true
		"magistrate":
			d["same"] = not bool(d.get("same", false))
			changed = true
		"executor":
			if d.get("assigned", false):
				var erep: String = _other_person(w, [src_id, str(d.get("target", ""))])
				if erep != "":
					d["target"] = erep
					changed = true
			else:
				var ex_pool: Array = _script_all_roles(w).filter(func(r): return r != str(d.get("role", "")))
				if not ex_pool.is_empty():
					d["role"] = str(w.pick(ex_pool))
					changed = true
		"registrar":
			if d.has("target"):
				if w.chance(0.5):
					d["yes"] = not bool(d.get("yes", false))
					changed = true
				else:
					var rrep: String = _other_person(w, [src_id, str(d.get("target", ""))])
					if rrep != "":
						d["target"] = rrep
						changed = true
			else:
				var sl: Array = d.get("roles", []).duplicate()
				if sl.size() == 3:
					var ri: int = w.rng.randi_range(0, 2)
					var other_two: Array = []
					for k in range(3):
						if k != ri:
							other_two.append(str(sl[k]))
					var has_other_minion: bool = other_two.any(func(r): return r in C.MINION_ROLES)
					var reg_pool: Array = (_script_good_roles(w) + ([] if has_other_minion else _script_minion_roles(w))).filter(func(r): return r != "registrar" and r not in sl)
					if not reg_pool.is_empty():
						sl[ri] = str(w.pick(reg_pool))
						d["roles"] = sl
						changed = true
	if not changed:
		return {}
	var out: Dictionary = orig.duplicate(true)
	out["data"] = d
	out["text"] = _rebuild_reading_text(w, role, d, str(orig.get("text", "")))
	out["true"] = false
	out["muddled"] = true
	out["muddled_by"] = muddler.id
	out["why"] = "muddled by " + muddler.id
	out["original_entry"] = orig.duplicate(true)
	return out


static func _reading_cache_key(src_id: String, e: Dictionary) -> String:
	var orig: Dictionary = e.get("original_entry", e) if e.get("original_entry") is Dictionary else e
	return "reading:%s:%d:%s:%s" % [src_id, int(orig.get("day", -1)), str(orig.get("role", "")), JSON.stringify(orig.get("data", {}))]


static func maybe_muddle_reading(w, speaker, src_id: String, e: Dictionary) -> Dictionary:
	if speaker == null or speaker.secret_mod != "muddler" or src_id == "" or src_id == speaker.id:
		return e
	if e.get("muddled", false):
		return e
	var ckey: String = _reading_cache_key(src_id, e)
	if speaker.muddled_items.has(ckey):
		var cached = speaker.muddled_items[ckey]
		return cached.duplicate(true) if cached is Dictionary and not cached.is_empty() else e
	var roll: bool = w.decision_roll(speaker, "muddle_gossip", Tuning.Social.MUDDLER_CHANCE, {"kind": "reading", "source": src_id, "role": e.get("role", "")}, src_id)
	if not roll:
		speaker.muddled_items[ckey] = {}
		return e
	var mutated: Dictionary = mutate_reading_entry(w, speaker, src_id, e)
	speaker.muddled_items[ckey] = mutated.duplicate(true)
	if not mutated.is_empty():
		w.dlog.think(speaker.id, "unaware", "Muddler: garbles %s's %s reading into '%s'." % [src_id, str(e.get("role", "")), str(mutated.get("text", ""))], {"muddled": true})
		return mutated
	return e


static func maybe_muddle_item(w, speaker, item: Dictionary, avoid_listener_id: String = "") -> Dictionary:
	if speaker == null or speaker.secret_mod != "muddler":
		return item
	var kind: String = str(item.get("kind", ""))
	var src_id: String = str(item.get("from", speaker.id))
	if src_id == speaker.id or kind not in ["reading", "sighting"]:
		return item
	if item.get("muddled", false):
		return item
	if kind == "reading" and item.get("entry") is Dictionary:
		var m_entry: Dictionary = maybe_muddle_reading(w, speaker, src_id, item["entry"])
		if m_entry.get("muddled", false):
			var out_r: Dictionary = item.duplicate(true)
			out_r["entry"] = m_entry
			out_r["muddled"] = true
			out_r["muddled_by"] = speaker.id
			return out_r
		return item
	if kind == "sighting":
		var orig_about: String = str(item.get("about", ""))
		var orig_blk: String = str(item.get("block", ""))
		var orig_day: int = int(item.get("day", -1))
		var skey: String = "sighting:%s:%s:%d:%s" % [src_id, orig_about, orig_day, orig_blk]
		if speaker.muddled_items.has(skey):
			var cached_s = speaker.muddled_items[skey]
			if cached_s is Dictionary and not cached_s.is_empty():
				if avoid_listener_id != "" and str(cached_s.get("about", "")) == avoid_listener_id:
					return item
				return cached_s.duplicate(true)
			return item
		var roll_s: bool = w.decision_roll(speaker, "muddle_gossip", Tuning.Social.MUDDLER_CHANCE, {"kind": "sighting", "source": src_id, "about": orig_about}, src_id)
		if not roll_s:
			speaker.muddled_items[skey] = {}
			return item
		var out_s: Dictionary = item.duplicate(true)
		var modes: Array = ["about", "block"]
		if w.day >= 3 and orig_day >= 1:
			modes.append("day")
		var mode: String = str(w.pick(modes))
		var mutated_ok: bool = false
		if mode == "about":
			var rep_who: String = _other_person(w, [src_id, speaker.id, orig_about, avoid_listener_id])
			if rep_who != "":
				out_s["about"] = rep_who
				mutated_ok = true
		elif mode == "day":
			var new_day: int = _other_int(w, orig_day, 1, maxi(1, w.day - 1))
			if new_day != orig_day:
				out_s["day"] = new_day
				mutated_ok = true
		if not mutated_ok:
			var new_blk: String = _other_block(w, orig_blk)
			if new_blk != orig_blk:
				out_s["block"] = new_blk
				mutated_ok = true
		if not mutated_ok:
			speaker.muddled_items[skey] = {}
			return item
		out_s["muddled"] = true
		out_s["muddled_by"] = speaker.id
		out_s["original_sighting"] = item.duplicate(true)
		speaker.muddled_items[skey] = out_s.duplicate(true)
		w.dlog.think(speaker.id, "unaware", "Muddler: garbles %s's night sighting into %s on %s (night %d)." % [src_id, str(out_s.get("about", "")), str(out_s.get("block", "")), int(out_s.get("day", -1))], {"muddled": true})
		return out_s
	return item


static func deprecate_card(card: Dictionary, by_id: String, superseded_by_num: int = 0) -> void:
	card["deprecated"] = true
	card["disclaimed_by"] = by_id
	card["workshop_usable"] = false
	card["pressable"] = false
	if superseded_by_num > 0:
		card["superseded_by"] = superseded_by_num


static func _npc_has_matching_reading(n, card: Dictionary) -> bool:
	var c_role: String = str(card.get("role", ""))
	var c_day: int = int(card.get("day", -1))
	var c_data: Dictionary = card.get("data", {})
	for e in n.info_log:
		if e.get("disowned", false):
			continue
		if str(e.get("role", "")) == c_role and int(e.get("day", -1)) == c_day and e.get("data", {}) == c_data:
			return true
	return false


static func _npc_has_matching_sighting(w, n, card: Dictionary) -> bool:
	var subjs: Array = card.get("subject", [])
	if subjs.is_empty():
		return true
	var who: String = str(subjs[0])
	var blk: String = str(card.get("block", ""))
	var nd: int = int(card.get("day", -1))
	for b in n.beliefs:
		if b.get("kind", "") == "saw" and b.get("phase", -1) == C.NIGHT and str(b.get("who", "")) == who and str(b.get("block", "")) == blk and int(b.get("day", -1)) == nd:
			return true
	if n.is_evil():
		for key in w.evil_plan.get("fake_sightings", {}):
			var fb = w.evil_plan["fake_sightings"][key]
			if key.begins_with(n.id + ":") and fb is Dictionary and str(fb.get("who", "")) == who and str(fb.get("block", "")) == blk and int(fb.get("day", -1)) == nd:
				return true
	return false


## Private correction during `ask gift` or `ask night`: if the player's board holds an
## un-deprecated Via-relayed reading or sighting attributed to `n` that `n` never gave,
## `n` always disclaims the false card (deprecating it on the board), while still only
## providing the real reading/sighting if their normal disclosure flow included it.
static func apply_private_disclaimers(g, n, topic: String, response: Dictionary) -> void:
	var w = g.w
	var want_kind: String = "info" if topic in ["gift", "role", "info", "learned"] else ("sighting" if topic in ["night", "lastnight"] else "")
	if want_kind == "":
		return
	for c in g.board:
		if c.get("deleted", false) or c.get("deprecated", false) or c.get("tavern_gossip", false):
			continue
		if str(c.get("kind", "")) != want_kind or str(c.get("source", "")) != n.id:
			continue
		if want_kind == "sighting" and int(c.get("phase", -1)) != C.NIGHT:
			continue
		var via_id: String = str(c.get("via", n.id))
		if via_id == "" or via_id == n.id:
			continue
		var is_false_attrib: bool = bool(c.get("muddled", false))
		if not is_false_attrib:
			is_false_attrib = not (_npc_has_matching_reading(n, c) if want_kind == "info" else _npc_has_matching_sighting(w, n, c))
		if not is_false_attrib:
			continue
		deprecate_card(c, n.id)
		var via_name: String = w.by_id[via_id].name if w.by_id.has(via_id) else "whoever told you that"
		var line_txt: String
		if want_kind == "info":
			if n.claim_public or n.max_tier >= 3:
				line_txt = "Hold on: %s got my %s account wrong. That wasn't what I learned." % [via_name, C.role_name(str(c.get("role", n.claimed_role)))]
			else:
				line_txt = "Hold on: whatever %s told you I learned, they muddled it. I never gave that reading." % via_name
		else:
			var who_id: String = str(c.get("subject", [""])[0])
			var who_name: String = w.by_id[who_id].name if w.by_id.has(who_id) else "anyone"
			line_txt = "And %s got that night story twisted: I never saw %s on %s on night %d." % [via_name, who_name, C.block_name(str(c.get("block", ""))), int(c.get("day", 1))]
		response["lines"].push_front({"speaker": n.id, "name": n.name, "text": line_txt, "statement": line_txt})
		w.dlog.add("muddle_disclaimed", n.id, via_id, {"card": c.get("n", 0), "kind": want_kind},
			"%s privately disclaims muddled %s card #%d (via %s)." % [n.name, want_kind, int(c.get("n", 0)), via_id])
