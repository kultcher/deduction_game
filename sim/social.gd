## The town talking to itself (stage 2): what NPCs tell each other, evil meetings and
## whispers, NPCs approaching the player, questions about roles, and paranoia.
##
## Every exchange is logged ("npc_share", "evil_share", "approach") with what was said,
## whether it was true, and who it came from originally.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Gifts = preload("res://sim/gifts.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const Muddler = preload("res://sim/muddler.gd")
const PsychologistRole = preload("res://sim/roles/psychologist.gd")

static func trait_of(n, t: String) -> float:
	return n.traits.get(t, 0.5)

static func _told(s, l, key: String) -> bool:
	return s.told_to.has(l.id + "|" + key)

static func _mark(s, l, key: String) -> void:
	s.told_to[l.id + "|" + key] = true

static func _implicated(e: Dictionary) -> Array:
	return Gifts.implicated(e)

## The gift this NPC would name to a peer: their own, or evil's agreed bluff.
static func _my_role(w, s) -> String:
	var r: String = str(w.evil_plan.get("bluffs", {}).get(s.id, "")) if s.is_evil() else str(s.role)
	return r if C.ROLES.has(r) else ""

## Has a good NPC told any trusted friend about their gift yet (hint or claim)?
static func _gift_told_a_friend(w, n) -> bool:
	for l in w.living():
		if l == n or n.npc_trust.get(l.id, 0.5) < Tuning.Social.GOOD_NEWS_TRUST_MIN:
			continue
		if _told(n, l, "role_hint:" + n.id) or _told(n, l, "role_claim:" + n.id):
			return true
	return false

# ---------------------------------------------------------------- news (drives who seeks whom out)

## Does this NPC have something they'd want to tell someone today?
static func has_news(w, n) -> bool:
	if n.is_evil():
		var sg_id: String = str(w.evil_plan.get("scapegoat", ""))
		if n.id == str(w.evil_plan.get("daily_planter", "")) and int(w.evil_plan.get("plants_today", 0)) < Tuning.Evil.MAX_DIRECT_PLANTS and sg_id != "" and w.by_id.has(sg_id) and w.by_id[sg_id].alive:
			return true
		for mate in Evil.mates(w, n):
			if Evil.unshared_intel(n, mate) > 0:
				return true
		return false
	for e in n.info_log:
		if not e["shared"]:
			return true
	# Early on, an unclaimed gift no trusted friend has heard about is news too (M1).
	if w.day <= Tuning.Social.ROLE_NEWS_LAST_DAY and not n.claim_public and _my_role(w, n) != "" and not _gift_told_a_friend(w, n):
		for l in w.living():
			if l != n and n.npc_trust.get(l.id, 0.5) >= Tuning.Social.GOOD_NEWS_TRUST_MIN:
				return true
	return false

## Extra pairing weight for someone with news and the person they'd tell.
static func news_bonus(w, a, b) -> float:
	var bonus = 0.0
	for p in [[a, b], [b, a]]:
		var x = p[0]
		var y = p[1]
		if not has_news(w, x):
			continue
		if x.is_evil():
			if y.is_evil():
				bonus += Tuning.Social.NEWS_BONUS_EVIL
			elif x.id == str(w.evil_plan.get("daily_planter", "")) and int(w.evil_plan.get("plants_today", 0)) < Tuning.Evil.MAX_DIRECT_PLANTS and y.id != str(w.evil_plan.get("scapegoat", "")) and trait_of(y, "gossip") >= Tuning.Social.PLANTER_TARGET_GOSSIP_MIN and y.npc_trust.get(x.id, 0.5) >= Tuning.Social.PLANTER_TARGET_TRUST_MIN:
				bonus += Tuning.Social.PLANTER_WHISPER_BONUS
		elif x.npc_trust.get(y.id, 0.5) > Tuning.Social.GOOD_NEWS_TRUST_MIN:
			bonus += Tuning.Social.NEWS_BONUS_GOOD
	return bonus

# ---------------------------------------------------------------- NPC-to-NPC exchanges

static func converse(w, a, b, when: String) -> void:
	if a.silenced or b.silenced:
		return  # one of them can't speak
	if a.is_evil() and b.is_evil():
		Evil.share_intel(w, a, b, "meeting (%s)" % when)
		return
	for p in [[a, b], [b, a]]:
		var item = _pick_item(w, p[0], p[1])
		if item != null:
			_deliver(w, p[0], p[1], item)

static func _pick_item(w, s, l):
	var cands: Array = []
	var priv = trait_of(s, "privacy")
	var gos = trait_of(s, "gossip")
	var bond: float = s.npc_trust.get(l.id, 0.5)
	if s.is_evil():
		var sg: String = w.evil_plan.get("scapegoat", "")
		for e in s.info_log:
			if e.get("fake", false) and not e["shared"] and not _told(s, l, "reading:%d:%s" % [e["day"], e["role"]]):
				# Same willingness formula as a good NPC sharing a real reading.
				var wgt = (1.0 - priv) * Tuning.Social.SHARE_READING_OPENNESS_SCALE * maxf(0.0, bond - Tuning.Social.SHARE_READING_BOND_FLOOR) * Tuning.Social.SHARE_READING_BOND_SLOPE + Tuning.Social.SHARE_READING_PRESSURE_SCALE * s.pressure
				cands.append([wgt, {"kind": "reading", "entry": e, "about": "", "from": s.id, "key": "reading:%d:%s" % [e["day"], e["role"]], "lie": true}])
		var planter_id: String = str(w.evil_plan.get("daily_planter", ""))
		# With a planter today, only the planter frames the scapegoat (anti-collusion). With no
		# planter (no murder scene, or no clean cover), the ordinary scapegoat whispers stand.
		var can_plant_sg: bool = planter_id == "" or (s.id == planter_id and int(w.evil_plan.get("plants_today", 0)) < Tuning.Evil.MAX_DIRECT_PLANTS)
		if sg != "" and sg != l.id and w.by_id[sg].alive and can_plant_sg:
			var fs = Evil.fake_night_sighting(w, s, w.day - 1)
			if fs != null and not _told(s, l, "sighting:%s:%d" % [sg, fs["day"]]):
				var p_scene: float = Tuning.Evil.PLANTER_SCENE_WEIGHT if s.id == planter_id else 0.0
				cands.append([gos * Tuning.Social.SHARE_SIGHTING_GOSSIP_SCALE + p_scene, {"kind": "sighting", "about": sg, "block": fs["block"], "day": fs["day"],
					"from": s.id, "key": "sighting:%s:%d" % [sg, fs["day"]], "lie": true}])
			if not _told(s, l, "opinion:" + sg) and Evil.public_heat(w, w.by_id[sg]) >= 0.3:
				cands.append([gos * Tuning.Social.SHARE_OPINION_GOSSIP_SCALE + (trait_of(s, "confidence") - 0.5) * Tuning.Social.SHARE_OPINION_CONF_SCALE, {"kind": "opinion", "about": sg, "why": Evil.bluff_reason(w, s, w.by_id[sg]), "from": s.id,
					"key": "opinion:" + sg, "lie": true}])
	else:
		for e in s.info_log:
			var key = "reading:%d:%s" % [e["day"], e["role"]]
			if not e["shared"] and not _told(s, l, key):
				var wgt = (1.0 - priv) * Tuning.Social.SHARE_READING_OPENNESS_SCALE * maxf(0.0, bond - Tuning.Social.SHARE_READING_BOND_FLOOR) * Tuning.Social.SHARE_READING_BOND_SLOPE + Tuning.Social.SHARE_READING_PRESSURE_SCALE * s.pressure
				cands.append([wgt, {"kind": "reading", "entry": e, "about": "", "from": s.id, "key": key}])
		if not s.secret.is_empty() and not l.known_secrets.has(s.id):
			cands.append([(1.0 - priv) * maxf(0.0, bond - Tuning.Social.SHARE_SECRET_BOND_FLOOR) * Tuning.Social.SHARE_SECRET_SLOPE, {"kind": "secret", "about": s.id, "from": s.id, "key": "secret:" + s.id}])
		var ranked = Mind.ranked_suspects(w, s).filter(func(m): return m != l)
		if not ranked.is_empty() and Mind.susp(s, ranked[0].id) >= Tuning.Social.SHARE_OPINION_MIN_SUSP and not _told(s, l, "opinion:" + ranked[0].id):
			var t = ranked[0]
			cands.append([gos * Tuning.Social.SHARE_OPINION_GOSSIP_SCALE + (trait_of(s, "confidence") - 0.5) * Tuning.Social.SHARE_OPINION_CONF_SCALE, {"kind": "opinion", "about": t.id,
				"why": Mind.citable_reason(w, s, t.id, "town"), "from": s.id, "key": "opinion:" + t.id}])
		for c in s.player_cases.slice(-2):
			var about: String = c["suspect"]
			var key: String = "case:" + str(c.card.get("n", c.card.text))
			if about != l.id and not _told(s, l, key):
				cands.append([gos * Tuning.Social.SHARE_CASE_GOSSIP_SCALE, {"kind": "case", "about": about, "card": c["card"], "from": "player", "key": key}])
	# Their own gift, told privately (M1). Evil uses its agreed bluff with the same formulas,
	# so a private claim is a social clue, never an alignment test.
	var my_role: String = _my_role(w, s)
	if my_role != "" and not s.claim_public:
		var pkg: String = C.package_of(my_role)
		var hint_key: String = "role_hint:" + s.id
		if pkg != "" and bond >= Tuning.Social.SHARE_ROLE_HINT_BOND_MIN and not _told(s, l, hint_key) and not l.known_claims.has(s.id):
			var hint_w: float = (1.0 - priv) * Tuning.Social.SHARE_ROLE_HINT_OPENNESS_SCALE * (bond - Tuning.Social.SHARE_ROLE_HINT_BOND_MIN + Tuning.Social.SHARE_ROLE_HINT_BOND_OFFSET) + gos * Tuning.Social.SHARE_ROLE_HINT_GOSSIP_SCALE
			cands.append([hint_w, {"kind": "role_hint", "about": s.id, "from": s.id, "package": pkg, "key": hint_key, "lie": s.is_evil()}])
		var claim_key: String = "role_claim:" + s.id
		var claim_ok: bool = bond >= Tuning.Social.SHARE_ROLE_CLAIM_BOND_MIN or (bond >= Tuning.Social.SHARE_ROLE_CLAIM_PRESSURED_BOND_MIN and s.pressure >= Tuning.Social.SHARE_ROLE_CLAIM_PRESSURE_MIN)
		if claim_ok and not s.protect_lock and not _told(s, l, claim_key) and str(l.known_claims.get(s.id, {}).get("role", "")) != my_role:
			var claim_w: float = (1.0 - priv) * Tuning.Social.SHARE_ROLE_CLAIM_SLOPE * maxf(Tuning.Social.SHARE_ROLE_CLAIM_MIN_WEIGHT, bond - Tuning.Social.SHARE_ROLE_CLAIM_BOND_FLOOR) + Tuning.Social.SHARE_READING_PRESSURE_SCALE * s.pressure
			cands.append([claim_w, {"kind": "role_claim", "about": s.id, "from": s.id, "role": my_role, "key": claim_key, "lie": s.is_evil()}])
	# Things anyone might pass on: what they saw at night, what they've heard, others' secrets.
	var has_recent_night_sighting: bool = false
	for b in s.beliefs:
		if b["kind"] == "saw" and b["phase"] == C.NIGHT and b["day"] >= w.day - 2 and b["who"] != l.id and w.by_id[b["who"]].alive:
			if s.is_evil() and w.by_id[b["who"]].is_evil():
				continue
			var key2 = "sighting:%s:%d" % [b["who"], b["day"]]
			if _told(s, l, key2):
				continue
			has_recent_night_sighting = true
			var scene = 0.0
			for sid in w.scenes:
				if w.scenes[sid]["day"] == b["day"] and w.scenes[sid]["block"] == b["block"]:
					scene = Tuning.Social.SHARE_SIGHTING_SCENE_BONUS
			cands.append([gos * Tuning.Social.SHARE_SIGHTING_GOSSIP_SCALE + scene, {"kind": "sighting", "about": b["who"], "block": b["block"], "day": b["day"], "from": s.id, "key": key2}])
	# Peer night-home alibis: townsfolk (and evil or sleepwalking bluffers) occasionally mention
	# having stayed home last night so alibis circulate naturally in 1-on-1 conversations.
	if w.day >= 1:
		var nd_alibi: int = w.day - 1
		var akey: String = "alibi:%s:%d" % [s.id, nd_alibi]
		if not _told(s, l, akey):
			var where_a: String = str(s.history.get(w.time_key(nd_alibi, C.NIGHT), "home:" + s.home_block))
			var claims_walk_duty: bool = C.has_role_def(s.claimed_role) and C.role_def(s.claimed_role).uses_night_duty_alibi(w, s, nd_alibi, where_a.begins_with("night:"))
			var claims_home: bool = not claims_walk_duty and (not where_a.begins_with("night:") or s.secret_mod == "sleepwalker" or s.is_evil())
			if claims_home:
				cands.append([gos * Tuning.Social.SHARE_ALIBI_WEIGHT, {"kind": "alibi", "about": s.id, "block": s.home_block, "day": nd_alibi, "from": s.id, "key": akey, "lie": where_a.begins_with("night:") and s.is_evil()}])
	# Low-walker daytime rumor fuel (Phase 4.1): when `s` holds no recent untold night sightings,
	# share daytime work/haunt sightings/alibis and mild unease so social chatter and gossip_bond
	# stay alive in Revenant + Scion setups without fabricating night evidence.
	if not has_recent_night_sighting:
		for idx in range(s.beliefs.size() - 1, -1, -1):
			var db: Dictionary = s.beliefs[idx]
			if db.get("kind", "") != "saw" or db.get("phase", C.NIGHT) == C.NIGHT:
				continue
			var who_id: String = str(db.get("who", ""))
			if who_id == "" or who_id == l.id or who_id == s.id or not w.by_id.has(who_id) or not w.by_id[who_id].alive:
				continue
			if int(db.get("day", -1)) < maxi(1, w.day - 1):
				continue
			var dkey: String = "day_sighting:%s:%d:%d" % [who_id, int(db["day"]), int(db["phase"])]
			if _told(s, l, dkey):
				continue
			var dloc: String = str(db.get("loc", ""))
			cands.append([gos * Tuning.Social.DAY_RUMOR_WEIGHT, {
				"kind": "day_sighting", "about": who_id, "loc": dloc, "block": str(db.get("block", "")),
				"day": int(db["day"]), "phase": int(db["phase"]), "from": s.id, "key": dkey,
			}])
			break
		# With no eligible observation, there is no daytime sighting to share.
		# Workplaces and haunts describe routines, not witnessed visits.
		if not s.is_evil():
			var uneasy_pool: Array = Mind.ranked_suspects(w, s).filter(func(m): return m != l)
			if not uneasy_pool.is_empty():
				var ut = uneasy_pool[0]
				var ususp: float = Mind.susp(s, ut.id)
				var ukey: String = "unease:" + ut.id
				if ususp >= Tuning.Social.UNEASE_SUSP_MIN and ususp < Tuning.Social.SHARE_OPINION_MIN_SUSP and not _told(s, l, ukey) and not _told(s, l, "opinion:" + ut.id):
					cands.append([gos * Tuning.Social.DAY_RUMOR_WEIGHT, {
						"kind": "unease", "about": ut.id, "why": Mind.citable_reason(w, s, ut.id, "town"),
						"from": s.id, "key": ukey,
					}])
	for h in s.hearsay.slice(-4):
		if h.get("public", false) or h["from"] == l.id or h.get("about", "") in [s.id, l.id] or h["kind"] in ["secret", "day_sighting", "unease", "role_hint", "role_claim"]:
			continue
		if s.is_evil() and h.get("about", "") != "" and w.by_id[h["about"]].is_evil():
			continue
		var key3 = "relay:" + h["key"]
		if _told(s, l, key3):
			continue
		var r = h.duplicate()
		r["key"] = key3
		r["relay"] = true
		var relay_scene: float = 0.0
		if not s.is_evil() and str(h.get("kind", "")) == "sighting":
			for sid in w.scenes:
				if int(w.scenes[sid].get("day", -2)) == int(h.get("day", -1)) and str(w.scenes[sid].get("block", "")) == str(h.get("block", "")):
					relay_scene = Tuning.Social.MURDER_RELAY_BONUS
					break
		cands.append([gos * Tuning.Social.SHARE_RELAY_GOSSIP_SCALE + relay_scene, r])
	for owner in s.known_secrets:
		if owner == l.id or owner == s.id or l.known_secrets.has(owner):
			continue
		cands.append([gos * Tuning.Social.SHARE_RELAY_SECRET_GOSSIP_SCALE * (Tuning.Social.SHARE_RELAY_SECRET_COMPOSURE_BASE - trait_of(s, "composure")), {"kind": "secret", "about": owner, "from": owner, "key": "secret:" + owner, "relay": true}])
	if cands.is_empty():
		return null
	var total = Tuning.Social.IDLE_CHAT_WEIGHT  # chance they just talk about the weather
	for c in cands:
		total += maxf(c[0], 0.0)
	var r2 = w.rng.randf() * total
	var observed_draw = r2
	for c in cands:
		r2 -= maxf(c[0], 0.0)
		if r2 <= 0:
			w.observe_weighted(s, "npc_share", cands, c[1]["key"], observed_draw, {"privacy": priv, "gossip": gos, "trust_in_listener": bond, "pressure": s.pressure}, l.id, Tuning.Social.IDLE_CHAT_WEIGHT)
			return c[1]
	w.observe_weighted(s, "npc_share", cands, "nothing", observed_draw, {"privacy": priv, "gossip": gos, "trust_in_listener": bond, "pressure": s.pressure}, l.id, Tuning.Social.IDLE_CHAT_WEIGHT)
	return null

## Public ordinary sightings use the same hearing/receipt path as private shares.
## The speaker has already chosen what to say; delivery adds no decision or RNG.
static func deliver_public_sighting(w, speaker, fact: Dictionary) -> void:
	if fact.get("kind", "") != "sighting" or fact.get("phase", -1) != C.NIGHT or fact.get("source", "") != speaker.id or fact.get("subject", []).size() != 1:
		return
	var who: String = fact.subject[0]
	if who == speaker.id or not w.by_id.has(who): return
	var item = {"kind": "sighting", "about": who, "block": fact.get("block", ""), "day": fact.get("day", -1),
		"from": speaker.id, "key": "sighting:%s:%d" % [who, fact.get("day", -1)]}
	for listener in w.living():
		if listener == speaker: continue
		_deliver(w, speaker, listener, item, true, fact)
		# The real evil mind receives its usual intel; its good self must hear the
		# public evidence too, through the same receipt path and its own ledger.
		if listener.is_evil():
			Mind.shadow_run(w, listener, func(sh): _deliver(w, speaker, sh, item, true, fact))

static func _record_direct_statement_for_listener(w, s, l, item: Dictionary, original: Dictionary = {}) -> void:
	if l == null or l.is_shadow or item.get("relay", false) or str(item.get("from", s.id)) != s.id:
		return
	var ik: String = str(item.get("kind", ""))
	if ik == "reading" and item.get("entry") is Dictionary:
		var e: Dictionary = item["entry"]
		var r_fact: Dictionary = Mind.info_fact(w, s, e)
		var is_f: bool = not bool(e.get("true", not e.get("fake", false)))
		var f_why: String = ("lying" if s.is_evil() else "misled") if is_f else ""
		PsychologistRole.record_heard(w, l, s.id, r_fact, is_f, f_why)
	elif ik == "sighting":
		var who_id: String = str(item.get("about", ""))
		if not w.by_id.has(who_id):
			return
		var s_fact: Dictionary = original.duplicate(true) if not original.is_empty() else {"kind": "sighting", "source": s.id, "subject": [who_id], "block": str(item.get("block", "")), "day": int(item.get("day", -1)), "phase": C.NIGHT,
			"text": "%s says they saw %s on %s on night %d." % [s.name, w.by_id[who_id].name, C.block_name(str(item.get("block", ""))), int(item.get("day", -1))]}
		var is_s_false: bool = bool(item.get("lie", false))
		if not is_s_false and not s.is_evil():
			is_s_false = not s.beliefs.any(func(b): return b.get("kind") == "saw" and b.get("phase") == C.NIGHT and str(b.get("who", "")) == who_id and str(b.get("block", "")) == str(item.get("block", "")) and int(b.get("day", -1)) == int(item.get("day", -1)))
		PsychologistRole.record_heard(w, l, s.id, s_fact, is_s_false, "lying" if is_s_false else "")
	elif ik == "alibi":
		var nd_a: int = int(item.get("day", w.day - 1))
		var a_fact: Dictionary = {"kind": "alibi", "source": s.id, "subject": [s.id], "home": true, "block": s.home_block, "day": nd_a, "phase": C.NIGHT,
			"text": "%s says they were home (on %s) on night %d." % [s.name, C.block_name(s.home_block), nd_a]}
		var where_n: String = str(s.history.get(w.time_key(nd_a, C.NIGHT), "home:" + s.home_block))
		var a_false: bool = where_n.begins_with("night:")
		var a_why: String = ("misled" if (not s.is_evil() and s.secret_mod == "sleepwalker") else "lying") if a_false else ""
		PsychologistRole.record_heard(w, l, s.id, a_fact, a_false, a_why)

static func _deliver(w, s, l, item: Dictionary, public: bool = false, original: Dictionary = {}) -> void:
	_mark(s, l, item["key"])
	if not public and item.get("relay", false):
		item = Muddler.maybe_muddle_item(w, s, item, l.id)
	_record_direct_statement_for_listener(w, s, l, item, original)
	var lie: bool = item.get("lie", false)
	if not public and not (s.is_evil() and l.is_evil()):
		w.daily_npc_shares.append({"day": w.day, "phase": w.phase, "loc": s.loc, "speaker": s.id, "listener": l.id, "item": item.duplicate(true)})
	var desc = _describe(w, s, item)
	w.dlog.add("npc_share", s.id, l.id, {"kind": item["kind"], "about": item.get("about", ""), "from": item.get("from", ""),
		"relay": item.get("relay", false), "lie": lie}, "%s tells %s: %s%s" % [s.name, l.name, desc, "  [LIE]" if lie else ""])
	if lie:
		w.dlog.think(s.id, "lie", "Evil: tells %s %s." % [l.name, desc], {"lie": true})
		if not public and s.is_evil() and not l.is_evil() and item.get("kind", "") in ["sighting", "opinion"] and s.id == str(w.evil_plan.get("daily_planter", "")):
			w.evil_plan["plants_today"] = int(w.evil_plan.get("plants_today", 0)) + 1
	if l.is_evil():
		Evil.intel_from_share(w, l, s, item)
		if item["kind"] == "secret":
			l.known_secrets[item["about"]] = s.id
		return
	# Repeats are handled by the listener's ledger (same reading never stacks).
	# The teller's credibility is applied live by the listener's ledger (rel = the source).
	var wgt = clampf(Tuning.Social.HEARSAY_TRUST_SCALE * l.npc_trust.get(s.id, 0.5), 0.0, Tuning.Social.HEARSAY_WEIGHT_CAP)
	var times: int = l.heard.get(item["key"].trim_prefix("relay:"), 0)
	l.heard[item["key"].trim_prefix("relay:")] = times + 1
	var hs = item.duplicate()
	hs["via"] = s.id
	hs["day_heard"] = w.day
	hs["key"] = item["key"].trim_prefix("relay:")
	hs["public"] = public
	match item["kind"]:
		"reading":
			var e: Dictionary = item["entry"]
			var src = w.by_id[item["from"]]
			Mind.apply_info(w, l, src, e, wgt, s.id)
			if not l.known_claims.has(src.id):
				l.known_claims[src.id] = {"role": e["role"], "readings": [], "via": s.id, "first_claimed_day": w.day}
			Mind.hear_claim(w, l, src.id, e["role"], wgt, "relayed", Mind.WorkshopLedger.reading(src.id, e, s.id))
			if not (e in l.known_claims[src.id]["readings"]):
				l.known_claims[src.id]["readings"].append(e)
			l.hearsay.append(hs)
		"sighting":
			var orig_src_id: String = str(item.get("from", s.id))
			var sight_wgt: float = wgt
			if orig_src_id != s.id:
				var chain_trust: float = minf(l.npc_trust.get(s.id, 0.5), l.npc_trust.get(orig_src_id, 0.5))
				sight_wgt = clampf(Tuning.Social.HEARSAY_TRUST_SCALE * chain_trust, 0.0, Tuning.Social.HEARSAY_WEIGHT_CAP)
			var card = {"kind": "sighting", "source": orig_src_id, "via": s.id, "subject": [item["about"]], "block": item.get("block", ""), "day": item.get("day", -1), "phase": C.NIGHT,
				"learned": [{"day": w.day, "phase": w.phase, "via": s.id}], "text": desc}
			if not original.is_empty():
				card = original.duplicate(true)
				card["via"] = s.id
				card["learned"] = [{"day": w.day, "phase": w.phase, "via": s.id, "public": public}]
			var receipt = Mind.WorkshopLedger.Evidence.normalize_card(card)
			Mind.ledger_hear(w, l, "heard:" + receipt.id, [], sight_wgt * 2.0, [orig_src_id, item.get("day", -1), "report"],
				{"kind": "tell", "workshop_card": receipt, "workshop_teller": s.id, "workshop_origin": orig_src_id, "workshop_public": public})
			l.hearsay.append(hs)
		"role_hint":
			# Only the gift's family: remembered, no claim on record yet.
			l.hearsay.append(hs)
		"role_claim":
			var prev: Dictionary = l.known_claims.get(s.id, {})
			l.known_claims[s.id] = {"role": item["role"], "readings": prev.get("readings", []) if prev.get("role", "") == item["role"] else [],
				"via": s.id, "first_claimed_day": mini(int(prev.get("first_claimed_day", w.day)), w.day)}
			Mind.hear_claim(w, l, s.id, item["role"], wgt, "relayed")
			l.hearsay.append(hs)
		"opinion", "unease":
			# Remember the conversation and teller, without turning their conclusion
			# into evidence about its target (Q4).
			l.hearsay.append(hs)
		"alibi":
			var nd_al: int = int(item.get("day", w.day - 1))
			var al_card = {"kind": "alibi", "source": s.id, "via": s.id, "subject": [s.id], "home": true, "block": s.home_block, "day": nd_al, "phase": C.NIGHT,
				"learned": [{"day": w.day, "phase": w.phase, "via": s.id}], "text": desc}
			var al_rec = Mind.WorkshopLedger.Evidence.normalize_card(al_card)
			Mind.ledger_hear(w, l, "heard:" + al_rec.id, [], wgt * 2.0, [s.id, nd_al, "report"],
				{"kind": "tell", "workshop_card": al_rec, "workshop_teller": s.id, "workshop_origin": s.id, "workshop_public": public})
			l.hearsay.append(hs)
		"day_sighting":
			# Witnessed daytime visits build social fabric and context
			# without manufacturing night-movement suspicion in the listener's ledger.
			l.hearsay.append(hs)
		"case":
			var proof = w.workshop_roots.call(item["card"]) if w.workshop_roots.is_valid() else {"complete": false, "receipts": {}}
			for receipt in proof.receipts.values():
				var path = {"via": s.id, "kind": "npc_case", "at": {"day": w.day, "phase": w.phase}}
				if not receipt.has("provenance_paths"):
					receipt["provenance_paths"] = []
				receipt.provenance_paths.append(path)
			Mind.ledger_hear(w, l, "relayed-case:%s>%s" % [str(item.card.get("n", Mind.fact_id(item.card))), item["about"]], [], wgt * 2.0, [],
				{"kind": "shared_case", "workshop_receipts": proof.receipts, "workshop_complete": proof.complete, "workshop_teller": s.id})
			if not proof.complete:
				w.dlog.add("evidence_excluded", l.id, item["about"], {"via": s.id}, "Relayed case excluded from shared evidence: its original roots are missing or unsupported.")
			l.hearsay.append(hs)
		"secret":
			var owner = w.by_id[item["about"]]
			l.known_secrets[owner.id] = s.id
			if owner != s:
				owner.secret_spread_by_npc = true
	if not public:
		l.npc_trust[s.id] = clampf(l.npc_trust.get(s.id, 0.5) + gossip_bond(l, s, item), 0.0, 1.0)

## How a private share changes the listener's trust in the teller (Oct 30): a small gain
## when the listener believes them (they don't suspect the teller), nothing otherwise, and
## a small loss when it runs down someone the listener trusts.
static func gossip_bond(l, s, item: Dictionary) -> float:
	var about: String = item.get("about", "")
	var against: bool = item["kind"] in ["opinion", "unease", "case", "sighting"] or (item["kind"] == "reading" and _implicates(item))
	if against and about != "" and about != s.id and l.npc_trust.get(about, 0.5) >= Tuning.Social.GOSSIP_SMEAR_TRUST:
		return -Tuning.Social.GOSSIP_BOND
	if Mind.susp(l, s.id) < Tuning.Social.GOSSIP_BELIEVED_BELOW:
		return Tuning.Social.GOSSIP_BOND
	return 0.0

## A relayed reading that speaks against someone (a "yes", a pair with an evil role, a
## positive count) rather than clearing them.
static func _implicates(item: Dictionary) -> bool:
	var data = item.get("entry", {}).get("data", {})
	if not data is Dictionary:
		return false
	return data.get("yes", false) or int(data.get("count", 0)) > 0 or (data.has("role") and C.ROLES.get(data.role, {}).get("align", "good") == "evil")

static func _describe(w, s, item: Dictionary) -> String:
	var src = item.get("from", "")
	var via = ""
	if item.get("relay", false) and src != s.id and w.by_id.has(src):
		via = " (heard from %s)" % w.by_id[src].name
	match item["kind"]:
		"reading":
			return "their %s reading: %s%s" % [C.role_name(item["entry"]["role"]), item["entry"]["text"], via]
		"sighting":
			return "%s was out on %s on night %d%s" % [w.by_id[item["about"]].name, C.block_name(item["block"]), item["day"], via]
		"alibi":
			return "%s stayed home on %s on night %d%s" % [w.by_id[item["about"]].name, C.block_name(item["block"]), item["day"], via]
		"opinion":
			return "they distrust %s%s" % [w.by_id[item["about"]].name, via]
		"unease":
			return "they feel uneasy about %s%s" % [w.by_id[item["about"]].name, via]
		"day_sighting":
			var dname: String = w.by_id[item["about"]].name
			var dloc: String = str(item.get("loc", ""))
			if dloc != "":
				var lname: String = w.loc_name(dloc)
				return "%s was seen at %s%s" % [dname, lname, via]
			return "%s was seen on %s during the day%s" % [dname, C.block_name(str(item.get("block", ""))), via]
		"case":
			return "the Demonologist's case against %s" % w.by_id[item["about"]].name
		"role_hint":
			return "their gift is %s" % C.HINT_PACKAGES[item["package"]]["name"]
		"role_claim":
			return "they are the %s" % C.role_name(item["role"])
		"secret":
			var o = w.by_id[item["about"]]
			return "%s's secret: %s %s" % [o.name, o.name, o.secret.get("text", "?")]
	return item["kind"]

## Evil members in the same crowded tavern can pass word unobserved (slow, partial).
static func tavern_whispers(w) -> void:
	if w.npcs_at("tavern").size() < Tuning.Social.TAVERN_WHISPER_MIN_CROWD:
		return
	var here: Array = w.evil_team().filter(func(x): return x.loc == "tavern" and x.busy_with == "")
	for i in range(here.size()):
		for j in range(i + 1, here.size()):
			var d = here[i]
			var m = here[j]
			if Evil.unshared_intel(d, m) + Evil.unshared_intel(m, d) > 0 and w.decision_roll(d, "whisper_intelligence", Tuning.Social.TAVERN_WHISPER_CHANCE, {}, m.id):
				Evil.share_intel(w, d, m, "whisper in the crowded tavern")

# ---------------------------------------------------------------- paranoia

## Paranoia drift (a nightly flat rise in everyone's suspicion) was removed Oct 30: under the
## relative listener prior it carried no information. Urgency now lowers the vote bar
## (Tuning.Meeting.VOTE_URGENCY_PER_DEATH).

# ---------------------------------------------------------------- approaches

## Pick an NPC who wants a word with the player at the start of a phase, or null.
static func approach_candidate(w):
	if not w.decision_roll(null, "approach_this_phase", Tuning.Social.APPROACH_PHASE_CHANCE):
		return null
	var best = null
	var best_s = 0.0
	var agenda = ""
	for n in w.living():
		if not n.available() or n.working or n.silenced:
			continue
		var s = 0.0
		var a = ""
		var gos = trait_of(n, "gossip")
		if n.is_evil():
			# Same conditions as a good NPC with news: unshared (fake) readings and some trust.
			var sg: String = w.evil_plan.get("scapegoat", "")
			var fresh = 0
			for i in range(n.told_readings, n.info_log.size()):
				if not n.info_log[i]["shared"]:
					fresh += 1
			if fresh > 0 and n.trust >= Tuning.Social.APPROACH_NEWS_MIN_TRUST and sg != "" and w.by_id[sg].alive:
				s = (1.0 - trait_of(n, "privacy")) + n.trust - Tuning.Social.APPROACH_NEWS_OFFSET
				a = "frame"
		else:
			var unshared = n.info_log.size() - n.told_readings
			var hidden_new = 0
			for i in range(n.told_readings, n.info_log.size()):
				if not n.info_log[i]["shared"]:
					hidden_new += 1
			if hidden_new > 0 and n.trust >= Tuning.Social.APPROACH_NEWS_MIN_TRUST and unshared > 0:
				s = (1.0 - trait_of(n, "privacy")) + n.trust - Tuning.Social.APPROACH_NEWS_OFFSET
				a = "news"
		if gos >= Tuning.Social.APPROACH_GOSSIP_MIN and has_gossip(w, n):
			var gs = gos - Tuning.Social.APPROACH_GOSSIP_OFFSET
			if gs > s:
				s = gs
				a = "gossip"
		if wants_protection(w, n):
			var ps = n.trust + Tuning.Social.APPROACH_PROTECT_COMPOSURE_SCALE * (1.0 - trait_of(n, "composure")) - Tuning.Social.APPROACH_PROTECT_OFFSET
			if ps > s:
				s = ps
				a = "protect"
		var noise_draw = w.rng.randf()
		var noise: float = noise_draw * Tuning.Social.APPROACH_NOISE
		s += noise
		w.observe_decision(n, "approach_score", s >= Tuning.Social.APPROACH_SCORE_THRESHOLD, {"inputs": {"gossip": gos, "privacy": trait_of(n, "privacy"), "trust": n.trust, "composure": trait_of(n, "composure")}, "score": s, "threshold": Tuning.Social.APPROACH_SCORE_THRESHOLD, "comparison": ">=", "draw": noise_draw, "noise": noise, "noise_min": 0.0, "noise_max": Tuning.Social.APPROACH_NOISE, "agenda": a, "note": "Threshold chance excludes competing NPCs; highest score chooses the approach"})
		if s > best_s:
			best_s = s
			best = n
			agenda = a
	if best == null or best_s < Tuning.Social.APPROACH_SCORE_THRESHOLD:
		w.observe_decision(best, "approach_selection", false, {"gate": "no eligible NPC cleared the approach threshold", "score": best_s, "threshold": Tuning.Social.APPROACH_SCORE_THRESHOLD, "comparison": ">="})
		return null
	w.observe_decision(best, "approach_selection", agenda, {"score": best_s, "threshold": Tuning.Social.APPROACH_SCORE_THRESHOLD, "comparison": ">=", "gate": "highest eligible score selected; no extra draw"})
	w.dlog.think(best.id, "approach", "Seeks out the Demonologist (agenda: %s, score %.2f)." % [agenda, best_s], {"agenda": agenda})
	return {"npc": best, "agenda": agenda}

## Afraid, trusting the player enough, and the player doesn't yet know their gift: they may
## come asking for a ward or a vigil (see Mind.protection_kind for who asks for which).
static func wants_protection(w, n) -> bool:
	if n.claim_public or n.max_tier >= 3 or n.protect_lock or n.request_day == w.day or n.trust < Tuning.Social.PROTECTION_MIN_TRUST:
		return false
	if Mind.protection_kind(w, n) == "":
		return false
	return Mind._afraid(w, n)

## A free line as they approach, naming what they want to talk about.
static func approach_teaser(w, n, agenda: String) -> Dictionary:
	match agenda:
		"news", "frame":
			return Mind.say_voiced(n, "approach_teaser_gift", "It's about my gift. I've learned something you should hear.")
		"gossip":
			return Mind.say_voiced(n, "approach_teaser_gossip", "I've heard something about one of our neighbours.")
		"protect":
			return Mind.protection_line(n, Mind.protection_kind(w, n))
	return Mind.say_voiced(n, "approach_word", "Demonologist, a word?")

## What they open with once the player accepts. Returns {lines, facts}.
static func approach_open(w, n, agenda: String) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	match agenda:
		"news", "frame":
			var r: Dictionary = Mind.answer_gift(w, n, 4)
			n.pressed_today -= 1
			lines.append(Mind.say_voiced(n, "approach_open_gift", "I've been meaning to find you."))
			lines += r["lines"]
			facts += r["facts"]
			if agenda == "frame":
				var sg = w.by_id[w.evil_plan["scapegoat"]]
				var why = Evil.cite(w, n, Evil.bluff_reason(w, n, sg))
				w.dlog.think(n.id, "lie", "Evil: approaches the player to push scapegoat %s." % sg.id)
				var reason_s: String = ((why[0].to_upper() + why.substr(1)).trim_suffix(".") + ".") if why != "" else "Something's off about them."
				var canonical_warn: String = "And keep an eye on %s. %s" % [sg.name, reason_s]
				lines.append(Mind.say_voiced(n, "approach_frame_warn", canonical_warn, {"subject": sg.name, "reason": reason_s}))
				facts.append({"kind": "opinion", "subject": [sg.id], "source": n.id, "text": "%s warned you about %s." % [n.name, sg.name]})
		"gossip":
			lines.append(Mind.say_voiced(n, "approach_open_gossip", "You'll want to hear this."))
			var g = gossip_item(w, n)
			lines += g["lines"]
			facts += g["facts"]
	return {"lines": lines, "facts": facts}

## Gossip the player hasn't heard from them, and that the whole town didn't already hear:
## a known secret, or a relayed reading or sighting. Returns [kind, owner/index] or [].
static func _gossip_items(w, n) -> Array:
	var out: Array = []
	for owner in n.known_secrets:
		if owner != n.id and w.by_id[owner].alive and not n.told_to.has("player|secret:" + owner):
			out.append(["secret", owner])
	for i in range(n.hearsay.size() - 1, -1, -1):
		var h: Dictionary = n.hearsay[i]
		if n.told_to.has("player|hs:%d" % i) or h.get("public", false) or h.get("about", "") == n.id:
			continue
		if h["kind"] == "reading" and w.by_id.has(h["from"]) and not h["entry"].get("shared", false):
			var src = w.by_id[h["from"]]
			if Mind.reading_disclosed(src, h["entry"]):
				continue
			out.append(["hearsay", i])
		elif h["kind"] in ["role_claim", "role_hint"] and w.by_id.has(h["from"]) and w.by_id[h["from"]].alive and not w.by_id[h["from"]].claim_public:
			if n.told_to.has("player|%s:%s" % [h["kind"], h["from"]]):
				continue
			out.append(["hearsay", i])
		elif h["kind"] == "sighting" and w.by_id.has(h["about"]):
			var src = w.by_id.get(h["from"])
			var town_key = "town|sighting:%s:%s:%d:%d:%s" % [h.get("from", ""), h["about"], h.get("day", -1), C.NIGHT, h.get("block", "")]
			var player_key = "player|saw:%s:%d" % [h["about"], h.get("day", -1)]
			if (src != null and (src.told_to.has(town_key) or src.told_to.has(player_key))) or n.told_to.has(player_key):
				continue
			out.append(["hearsay", i])
	return out

static func has_gossip(w, n) -> bool:
	return not _gossip_items(w, n).is_empty()

## A busybody's best bit of news for the player: a secret, a relayed reading or sighting,
## never one they've already told you or one the whole town heard at a meeting.
static func gossip_item(w, n) -> Dictionary:
	var items: Array = _gossip_items(w, n)
	for it in items:
		if it[0] != "secret":
			continue
		var owner: String = it[1]
		var o = w.by_id[owner]
		if w.decision_roll(n, "approach_gossip_direct", Tuning.Social.APPROACH_SECRET_DIRECT_BASE + Tuning.Social.APPROACH_SECRET_DIRECT_GOSSIP_SCALE * trait_of(n, "gossip"), {"gossip": trait_of(n, "gossip")}):
			n.told_to["player|secret:" + owner] = true
			w.dlog.think(n.id, "gossip", "Tells the player %s's secret (heard via %s)." % [owner, n.known_secrets[owner]])
			o.secret_spread_by_npc = true
			var secret_fallback: String = "Between you and me, %s %s. That's why they're about at night." % [o.name, o.secret["text"]]
			return {"lines": [Mind.say_voiced(n, "gossip_secret", secret_fallback, {"subject": o.name, "secret": o.secret["text"]})],
				"facts": [{"kind": "secret", "subject": [owner], "owner": owner, "source": n.id, "via": n.known_secrets[owner],
					"secret_kind": o.secret.get("kind", ""), "mod": "lovers" if o.secret.get("kind", "") == "lover" else "",
					"text": "%s told you %s's secret: %s %s." % [n.name, o.name, o.name, o.secret["text"]]}]}
	for it in items:
		if it[0] != "hearsay":
			continue
		var i: int = it[1]
		var h: Dictionary = n.hearsay[i]
		var src = w.by_id.get(h["from"])
		n.told_to["player|hs:%d" % i] = true
		if h["kind"] == "reading" and src != null:
			var mh_r: Dictionary = Muddler.maybe_muddle_item(w, n, h)
			var e: Dictionary = mh_r["entry"]
			var f = Mind.info_fact(w, src, e)
			f["via"] = n.id
			if e.get("muddled", false):
				f["muddled"] = true
				f["muddled_by"] = e.get("muddled_by", n.id)
			f["text"] = "Via %s: " % n.name + f["text"]
			var out_facts_r: Array = [f] + PsychologistRole.companion_facts(w, src, e, n.id)
			var role_s: String = C.role_name(e["role"])
			var report_s: String = C.third_person(e["text"])
			var reading_fallback: String = "%s told me their gift is %s, and that %s." % [src.name, role_s, report_s]
			return {"lines": [Mind.say_voiced(n, "gossip_reading", reading_fallback, {"source": src.name, "role": role_s, "report": report_s})], "facts": out_facts_r}
		if h["kind"] == "role_claim" and src != null:
			n.told_to["player|role_claim:" + src.id] = true
			var crn: String = C.role_name(h["role"])
			var claim_fb: String = "Between us, %s told me they're the %s." % [src.name, crn]
			return {"lines": [Mind.say_voiced(n, "role_query_private_direct", claim_fb, {"who": src.name, "role": crn})],
				"facts": [{"kind": "claim", "subject": [src.id], "role": h["role"], "source": src.id, "via": n.id, "private": true,
					"text": "Via %s: %s privately claims to be the %s." % [n.name, src.name, crn]}]}
		if h["kind"] == "role_hint" and src != null:
			n.told_to["player|role_hint:" + src.id] = true
			var hp: String = h["package"]
			var hint_fb: String = "Between us, %s hinted their gift is %s." % [src.name, C.HINT_PACKAGES[hp]["name"]]
			return {"lines": [Mind.say(n, hint_fb)],
				"facts": [{"kind": "hint", "subject": [src.id], "source": src.id, "via": n.id, "private": true, "package": hp,
					"roles": C.HINT_PACKAGES[hp]["roles"].duplicate(),
					"text": "Via %s: %s hinted at %s (%s)." % [n.name, src.name, C.HINT_PACKAGES[hp]["name"],
						" / ".join(PackedStringArray(C.HINT_PACKAGES[hp]["roles"].map(func(r): return C.role_name(r))))]}]}
		if h["kind"] == "sighting":
			var mh_s: Dictionary = Muddler.maybe_muddle_item(w, n, h)
			var who = w.by_id[mh_s["about"]]
			var by = w.by_id[mh_s["from"]].name if w.by_id.has(mh_s["from"]) else "someone"
			var block_s: String = C.block_name(mh_s["block"])
			var night_s: String = "on night %d" % mh_s["day"]
			var sighting_fallback: String = "%s says %s was out on %s %s." % [by, who.name, block_s, night_s]
			var s_fact_out: Dictionary = {"kind": "sighting", "subject": [who.id], "block": mh_s["block"], "day": mh_s["day"], "phase": C.NIGHT, "source": mh_s["from"], "via": n.id,
				"text": "Via %s: %s saw %s on %s on night %d." % [n.name, by, who.name, block_s, mh_s["day"]]}
			if mh_s.get("muddled", false):
				s_fact_out["muddled"] = true
				s_fact_out["muddled_by"] = mh_s.get("muddled_by", n.id)
			return {"lines": [Mind.say_voiced(n, "gossip_sighting", sighting_fallback, {"source": by, "subject": who.name, "block": block_s, "night": night_s})],
				"facts": [s_fact_out]}
	return {"lines": [Mind.say_voiced(n, "gossip_empty", "...Well, I thought I had something. The price of bread, mostly.")], "facts": []}

# ---------------------------------------------------------------- asking about a role

static func answer_about_role(w, n, role: String) -> Dictionary:
	Mind.on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var rn = C.role_name(role)
	var mine: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	if mine == role and (n.claim_public or n.max_tier >= 3):
		lines.append(Mind.say_voiced(n, "role_query_self", "That would be me."))
		return {"lines": lines, "facts": facts}
	# A general question about the town, but it touches their own gift: a small chance they
	# own up (likelier the more they trust you). Otherwise they answer like anyone else.
	if mine == role:
		var p = Tuning.Social.ROLE_OWN_UP_BASE + Tuning.Social.ROLE_OWN_UP_TRUST_SCALE * n.trust
		var out = w.decision_roll(n, "own_up_to_gift", p, {"trust": n.trust})
		w.dlog.think(n.id, "about_role", "Asked who holds their own gift (%s): owns up? -> %s (p=%.2f)." % [role, "yes" if out else "no", p])
		if out:
			n.pressed_today -= 1  # answer_gift counts the question again
			return Mind.answer_gift(w, n, maxi(2, Mind._target_tier(w, n)))
	var public: Array = w.public_claims.filter(func(c): return c["role"] == role and w.by_id[c["who"]].alive).map(func(c): return w.by_id[c["who"]].name)
	var text = ""
	var voiced_chunks: Array = []
	if not public.is_empty():
		var pub_names: String = " and ".join(PackedStringArray(public))
		var pub_fb: String = "Everyone heard %s claim the %s." % [pub_names, rn]
		text = pub_fb
		voiced_chunks.append(Dialogue.voice_line(n.id, "role_query_public", pub_fb, {"names": pub_names, "role": rn}))
	var willing = trait_of(n, "gossip") * Tuning.Social.ROLE_WILLING_GOSSIP_SCALE + n.trust * Tuning.Social.ROLE_WILLING_TRUST_SCALE + n.pressure * Tuning.Social.ROLE_WILLING_PRESSURE_SCALE > Tuning.Social.ROLE_WILLING_THRESHOLD
	var told = false
	if not n.is_evil() and willing:
		for sid in n.known_claims:
			var kc: Dictionary = n.known_claims[sid]
			var who = w.by_id[sid]
			if kc["role"] != role or who.claim_public:
				continue
			told = true
			if kc["via"] == sid:
				var priv_fb: String = "Between us, %s told me they're the %s." % [who.name, rn]
				text += (" " if text != "" else "") + priv_fb
				voiced_chunks.append(Dialogue.voice_line(n.id, "role_query_private_direct", priv_fb, {"who": who.name, "role": rn}))
			else:
				var via_name: String = w.by_id[kc["via"]].name
				var priv_fb: String = "Between us, %s told %s they're the %s." % [who.name, via_name, rn]
				text += (" " if text != "" else "") + priv_fb
				voiced_chunks.append(Dialogue.voice_line(n.id, "role_query_private_via", priv_fb, {"who": who.name, "via": via_name, "role": rn}))
			facts.append({"kind": "claim", "subject": [sid], "role": role, "source": sid, "via": n.id, "private": true,
				"text": "Via %s: %s privately claims to be the %s." % [n.name, who.name, rn]})
			for raw_e in kc["readings"]:
				var e: Dictionary = Muddler.maybe_muddle_reading(w, n, sid, raw_e)
				var said_rd: String = C.third_person(e["text"])
				var rd_fb: String = "They said %s." % said_rd
				text += " " + rd_fb
				voiced_chunks.append(Dialogue.voice_line(n.id, "role_query_reading", rd_fb, {"reading": said_rd}))
				var f = Mind.info_fact(w, who, e)
				f["via"] = n.id
				if e.get("muddled", false):
					f["muddled"] = true
					f["muddled_by"] = e.get("muddled_by", n.id)
				f["text"] = "Via %s: " % n.name + f["text"]
				facts.append(f)
				facts.append_array(PsychologistRole.companion_facts(w, who, e, n.id))
		w.dlog.think(n.id, "about_role", "Asked about the %s: shares private knowledge (willing)." % role if told else "Asked about the %s: knows nothing private." % role)
	elif not willing:
		w.dlog.think(n.id, "about_role", "Asked about the %s: not willing to share private knowledge." % role)
	if text == "":
		if mine == role or not (willing or n.is_evil()):
			lines.append(Mind.say_voiced(n, "role_query_refuse", "That's not for me to say."))
		else:
			lines.append(Mind.say_voiced(n, "role_query_unknown", "I couldn't tell you who the %s is." % rn, {"role": rn}))
	else:
		var line_dict: Dictionary = Mind.say(n, " ".join(PackedStringArray(voiced_chunks)))
		line_dict["statement"] = text
		lines.append(line_dict)
	return {"lines": lines, "facts": facts}

## "Are you the <gift>?": a direct guess at the listener's own gift. Right, they own up a
## little more readily than usual (only for the first guess you put to them, so going down
## the list doesn't pay). Wrong, or unwilling, they give the same non-answer either way, so
## a guess never eliminates anyone, and each wrong guess costs a little more trust.
static func answer_is_role(w, n, role: String) -> Dictionary:
	# Route before on_question: gift answers own both fatigue and disclosure.
	if (n.claim_public or n.max_tier >= 3) and n.claimed_role == role:
		return Mind.answer_gift(w, n)
	Mind.on_question(w, n)
	var rn = C.role_name(role)
	var mine: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var said: bool = n.claim_public or n.max_tier >= 3
	if said:
		var claimed: String = n.claimed_role
		if C.ROLES.has(claimed):
			var c_name: String = C.role_name(claimed)
			return {"lines": [Mind.say_voiced(n, "role_already_claimed", "No. I told you: I'm the %s." % c_name, {"role": c_name})], "facts": []}
		return {"lines": [Mind.say_voiced(n, "role_already_claimed_none", "No.")], "facts": []}
	if mine == role:
		var first = n.role_guesses == 0
		var tier: int = Mind._target_tier(w, n) + (1 if first and w.decision_roll(n, "correct_role_guess_bonus", Tuning.Social.CORRECT_ROLE_GUESS_BONUS_PROB) else 0)
		w.dlog.think(n.id, "about_role", "Asked if they are the %s (right): disclosure tier %d%s." % [role, tier,
			"" if first else " (no bonus: you guessed wrong before)"])
		if tier >= 2:
			n.pressed_today -= 1  # answer_gift counts the question again
			return Mind.answer_gift(w, n, mini(tier, 4))
	else:
		n.role_guesses += 1
		var cost = Tuning.Trust.WRONG_ROLE_GUESS_STEP * n.role_guesses
		Mind.set_trust(w, n, n.trust - cost, "the Demonologist guessed my gift wrong (%s; %d wrong so far)" % [role, n.role_guesses])
		w.dlog.think(n.id, "about_role", "Asked if they are the %s (wrong): gives the usual non-answer." % role)
	var line = "Why do you keep asking me that?" if n.role_guesses >= 3 else "What my gift is, I'll keep to myself."
	var guess_key = "guess_3" if n.role_guesses >= 3 else "guess_1"
	if n.role_guesses == 2:
		line = "You're grasping at straws, and I'm running out of patience."
		guess_key = "guess_2"
	return {"lines": [Mind.say_voiced(n, guess_key, line)], "facts": [], "refusal_line": 0}

# ---------------------------------------------------------------- evening tavern gossip

const TAVERN_LEADS = [
	"Word about town is that ",
	"Someone at the bar mentioned that ",
	"Talk in the taproom has it that ",
	"Over the clink of tankards, you hear that ",
	"Rumour making the rounds says that ",
]

const HINT_TOPICS = {
	"official": "records and official town business",
	"night_sight": "seeing things in the dark hours",
	"the_dead": "the dead",
	"shelter": "sheltering people from the demon",
	"people": "reading people",
}

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

	# 1. Spoken NPC-to-NPC items from anywhere in town today (evil strategizing never enters daily_npc_shares).
	for rec in w.daily_npc_shares:
		if int(rec.get("day", -1)) != w.day:
			continue
		var it: Dictionary = rec.get("item", {})
		var ik: String = str(it.get("kind", ""))
		var share_group: String = "share:%d" % candidates.size()
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
			var pkg: String = C.package_of(role)
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
							"secret_kind": o.secret.get("kind", ""), "mod": "lovers" if o.secret.get("kind", "") == "lover" else "",
							"tavern_gossip": true, "workshop_usable": false, "pressable": false, "class": "speech",
							"text": "Tavern rumour: %s %s." % [o.name, stext]}})

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

	# Tiered selection: prefer unheard spoken & profile backfill first; only touch already-heard
	# spoken items if the unheard pools cannot fill the rolled 3-5 slots.
	var unheard_pool: Array = candidates.filter(func(c): return not c.get("heard", false))
	var heard_pool: Array = candidates.filter(func(c): return c.get("heard", false))
	var chosen: Array = []
	var used_groups: Dictionary = {}
	for pool in [unheard_pool, heard_pool]:
		var avail: Array = pool.duplicate()
		while chosen.size() < target_count and not avail.is_empty():
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
	w.dlog.add("tavern_evening_gossip", "player", "", {"count": chosen.size(), "keys": chosen.map(func(c): return c["gkey"])},
		"Evening tavern gossip yielded %d item(s)." % chosen.size())
	return {"lines": lines, "facts": facts, "haunts": haunts, "bonds": bonds, "vibe": vibe}



## The town's vibe check on the Demonologist: rapport (trust in you) and competence (your
## credibility) averaged over the living good townsfolk. Evil's private view is left out on
## purpose (a deliberate fudge: the town's mood, not the demon's). No RNG draws.
## Returns {line, rapport, credibility, rapport_band, credibility_band, trend} or {}.
const VIBE_RAPPORT = ["the town is openly hostile to you", "folk mostly distrust you", "folk are wary of you",
	"the town hasn't made up its mind about you", "folk are warming to you", "you're well liked", "the town is fond of you"]
const VIBE_COMPETENCE = ["most take you for a fraud", "your word counts for little", "few put much stock in your judgement",
	"your judgement is still unproven", "your judgement shows promise", "they think you're sharp", "they reckon you're the real thing"]

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
		var dr: float = rap - float(last.get("rapport", rap))
		var dc: float = cred - float(last.get("credibility", cred))
		if absf(dr) >= Tuning.Social.TOWN_VIBE_TREND:
			trend["rapport"] = dr
			r_text += ", and warming since you last listened" if dr > 0.0 else ", though cooling since you last listened"
		if absf(dc) >= Tuning.Social.TOWN_VIBE_TREND:
			trend["credibility"] = dc
			c_text += ", and rising" if dc > 0.0 else ", but slipping"
	var line: String = "And about you, Demonologist: %s; %s." % [r_text, c_text]
	if low <= rap - Tuning.Social.TOWN_VIBE_OUTLIER and low < 0.45:
		line += " Not everyone agrees, mind: someone still doesn't trust you."
	g.town_vibe_heard = {"day": w.day, "rapport": rap, "credibility": cred}
	w.dlog.add("town_vibe", "player", "", {"rapport": snappedf(rap, 0.001), "credibility": snappedf(cred, 0.001),
		"rapport_band": rb, "credibility_band": cb, "trend": trend, "low": snappedf(low, 0.001)}, line)
	return {"line": line, "rapport": rap, "credibility": cred, "rapport_band": rb, "credibility_band": cb, "trend": trend}
