## The town talking to itself (stage 2): what NPCs tell each other, evil meetings and
## whispers, NPCs approaching the player, questions about roles, and paranoia.
##
## Every exchange is logged ("npc_share", "evil_share", "approach") with what was said,
## whether it was true, and who it came from originally.
##
## Approaches and role questions are in `social_approaches.gd` and the evening tavern in
## `social_tavern.gd`, one inheritance chain over `social_base.gd`, so every `Social.<fn>`
## is unchanged for callers.
extends "res://sim/social_tavern.gd"


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
	# Each side can pass on several things; every further item needs more trust, and each
	# pick keeps the idle-chat chance, so a conversation can trail off (Nov 5).
	for p in [[a, b], [b, a]]:
		var bond: float = p[0].npc_trust.get(p[1].id, 0.5)
		for k in range(Tuning.Social.SHARE_EXTRA_ITEM_BOND.size()):
			if bond < float(Tuning.Social.SHARE_EXTRA_ITEM_BOND[k]):
				break
			var item = _pick_item(w, p[0], p[1])
			if item == null:
				break
			_deliver(w, p[0], p[1], item)

## How willing s is to tell a peer one of their readings: openness times bond above the floor,
## plus pressure, plus a steep extra for listeners they trust.
static func _reading_weight(s, priv: float, bond: float) -> float:
	return (1.0 - priv) * Tuning.Social.SHARE_READING_OPENNESS_SCALE * maxf(0.0, bond - Tuning.Social.SHARE_READING_BOND_FLOOR) * Tuning.Social.SHARE_READING_BOND_SLOPE \
		+ Tuning.Social.SHARE_READING_PRESSURE_SCALE * s.pressure \
		+ Tuning.Social.SHARE_READING_TRUSTED_SLOPE * maxf(0.0, bond - Tuning.Social.SHARE_READING_TRUSTED_PIVOT)

static func _pick_item(w, s, l):
	var cands: Array = []
	var priv = trait_of(s, "privacy")
	var gos = trait_of(s, "gossip")
	var bond: float = s.npc_trust.get(l.id, 0.5)
	# Unclaimed NPCs share their gift and readings privately a little more each day (Nov 19).
	var unclaimed_mult: float = 1.0 if s.claim_public else 1.0 + Tuning.Social.SHARE_UNCLAIMED_DAY_BOOST * maxf(0.0, float(w.day - 1))
	if s.is_evil():
		var sg: String = w.evil_plan.get("scapegoat", "")
		for e in s.info_log:
			if e.get("fake", false) and not e["shared"] and not _told(s, l, "reading:%d:%s" % [e["day"], e["role"]]):
				# Same willingness formula as a good NPC sharing a real reading.
				var wgt = _reading_weight(s, priv, bond) * unclaimed_mult
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
			if C.has_role_def(str(e.get("role", ""))) and not C.role_def(str(e.get("role", ""))).may_share_reading(w, s, e):
				continue
			if not e["shared"] and not _told(s, l, key) and not Burdens.withholds_for_beloved(w, s, e):
				var wgt = _reading_weight(s, priv, bond) * unclaimed_mult
				cands.append([wgt, {"kind": "reading", "entry": e, "about": "", "from": s.id, "key": key}])
		if not s.secret.is_empty() and not l.known_secrets.has(s.id):
			cands.append([(1.0 - priv) * maxf(0.0, bond - Tuning.Social.SHARE_SECRET_BOND_FLOOR) * Tuning.Social.SHARE_SECRET_SLOPE, {"kind": "secret", "about": s.id, "from": s.id, "key": "secret:" + s.id}])
		# A known burden, shared privately as trust allows (burdens prototype).
		var burden_w: float = Burdens.private_share_weight(w, s, bond)
		if burden_w > 0.0 and not l.known_secrets.has(s.id):
			cands.append([burden_w, {"kind": "secret", "about": s.id, "from": s.id, "key": "secret:" + s.id, "burden": s.secret_mod}])
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
	# Their own gift, told privately (M1; one roll since Nov 8). "Their gift" is one topic in
	# the draw; when it comes up, a single openness score (the same formula as answering the
	# Demonologist, `MindDialogue._target_tier`, with trust in this listener) picks what they
	# say: nothing, a hint at its family, or the gift itself. Evil uses its agreed bluff with
	# the same formula, so a private claim is a social clue, never an alignment test.
	var my_role: String = _my_role(w, s)
	if my_role != "" and not s.claim_public:
		var pkg: String = C.hint_package(w, my_role)
		var hint_key: String = "role_hint:" + s.id
		var claim_key: String = "role_claim:" + s.id
		var can_hint: bool = pkg != "" and not _told(s, l, hint_key) and not l.known_claims.has(s.id)
		var can_claim: bool = not s.protect_lock and not _told(s, l, claim_key) and str(l.known_claims.get(s.id, {}).get("role", "")) != my_role
		if can_hint or can_claim:
			var topic_w: float = (Tuning.Social.SHARE_GIFT_TOPIC_BASE + (1.0 - priv) * Tuning.Social.SHARE_GIFT_TOPIC_OPENNESS + gos * Tuning.Social.SHARE_GIFT_TOPIC_GOSSIP) * unclaimed_mult
			cands.append([topic_w, {"kind": "gift_topic", "about": s.id, "from": s.id, "role": my_role, "package": pkg, "key": "gift_topic:" + s.id,
				"can_hint": can_hint, "can_claim": can_claim, "lie": s.is_evil()}])
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
	# Peer night-home alibis: townsfolk (and evil bluffers) occasionally mention
	# having stayed home last night so alibis circulate naturally in 1-on-1 conversations.
	if w.day >= 1:
		var nd_alibi: int = w.day - 1
		var akey: String = "alibi:%s:%d" % [s.id, nd_alibi]
		if not _told(s, l, akey):
			var where_a: String = str(s.history.get(w.time_key(nd_alibi, C.NIGHT), "home:" + s.home_block))
			var claims_walk_duty: bool = C.has_role_def(s.claimed_role) and C.role_def(s.claimed_role).uses_night_duty_alibi(w, s, nd_alibi, where_a.begins_with("night:"))
			var claims_home: bool = not claims_walk_duty and (not where_a.begins_with("night:") or s.is_evil())
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
	# Who they saw talking with whom by day (BACKLOG item 3, Michael, Nov 18: meetings feed
	# the gossip network): the latest such meeting the listener isn't part of, passed on as
	# "X and Y were talking at Z". Evil keeps its teammates' meetings to itself.
	for idx in range(s.beliefs.size() - 1, -1, -1):
		var mb: Dictionary = s.beliefs[idx]
		if mb.get("kind", "") != "saw" or mb.get("phase", C.NIGHT) == C.NIGHT or str(mb.get("with", "")) == "" or str(mb.get("loc", "")) == "":
			continue
		if int(mb.get("day", -1)) < maxi(1, w.day - 1):
			continue
		var m_a: String = str(mb.get("who", ""))
		var m_b: String = str(mb["with"])
		if l.id in [m_a, m_b] or s.id in [m_a, m_b] or not w.by_id.has(m_a) or not w.by_id.has(m_b):
			continue
		if s.is_evil() and (Evil.is_teammate(w, s, m_a) or Evil.is_teammate(w, s, m_b)):
			continue
		var m_pair: Array = [m_a, m_b]
		m_pair.sort()
		var mkey: String = "meeting:%s:%s:%d:%d" % [m_pair[0], m_pair[1], int(mb["day"]), int(mb["phase"])]
		if _told(s, l, mkey):
			continue
		cands.append([gos * Tuning.Social.DAY_RUMOR_WEIGHT, {
			"kind": "meeting", "about": m_a, "with": m_b, "loc": str(mb["loc"]), "block": str(mb.get("block", "")),
			"day": int(mb["day"]), "phase": int(mb["phase"]), "from": s.id, "witness": s.id, "key": mkey,
		}])
		break
	# What a dead person told them is no longer someone else's to keep: readings from the
	# dead are passed on readily, the more so the more they trusted the dead (Nov 5).
	if not s.is_evil():
		var dead_keys := {}
		for h in s.hearsay:
			if h.get("public", false) or str(h.get("kind", "")) != "reading" or not w.by_id.has(str(h.get("from", ""))):
				continue
			var src = w.by_id[str(h["from"])]
			if src.alive or src.id == l.id or dead_keys.has(h["key"]):
				continue
			dead_keys[h["key"]] = true
			var dkey3: String = "relay:" + str(h["key"])
			if _told(s, l, dkey3):
				continue
			var dr = h.duplicate()
			dr["key"] = dkey3
			dr["relay"] = true
			dr["late"] = true
			cands.append([gos * Tuning.Social.SHARE_RELAY_GOSSIP_SCALE + Tuning.Social.SHARE_DEAD_RELAY_SLOPE * s.npc_trust.get(src.id, 0.5), dr])
	for h in s.hearsay.slice(-4):
		if h.get("public", false) or h["from"] == l.id or h.get("about", "") in [s.id, l.id] or h["kind"] in ["secret", "day_sighting", "meeting", "unease", "role_hint", "role_claim"]:
			continue
		if not s.is_evil() and str(h.get("kind", "")) == "reading" and w.by_id.has(str(h.get("from", ""))) and not w.by_id[str(h["from"])].alive:
			continue # offered above
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
		# Not a secret that names the teller (see _gossip_items).
		if owner == l.id or owner == s.id or l.known_secrets.has(owner) or str(w.by_id[owner].secret.get("with", "")) == s.id:
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
			if c[1]["kind"] == "gift_topic":
				return _gift_disclosure(w, s, l, c[1], bond)
			return c[1]
	w.observe_weighted(s, "npc_share", cands, "nothing", observed_draw, {"privacy": priv, "gossip": gos, "trust_in_listener": bond, "pressure": s.pressure}, l.id, Tuning.Social.IDLE_CHAT_WEIGHT)
	return null

## The gift topic came up: one openness score picks the tier, as with the Demonologist
## (`MindDialogue._target_tier`): below TIER_VAGUE nothing, then a hint, then the gift (a
## full-tier answer is the gift too; their readings travel as their own items). The score
## uses trust in this listener and a random draw in place of the daily mood. On day 1, until
## they've told someone and while the town has had fewer than CONFIDE_MAX_PER_GAME confidings,
## the confidant bonus is added: a confided claim warms the pair (see `_deliver`).
static func _gift_disclosure(w, s, l, topic: Dictionary, bond: float):
	var role: String = str(topic.role)
	var jitter: float = (w.rng.randf() - 0.5) * 2.0 * Tuning.Social.SHARE_GIFT_JITTER
	var parts: Dictionary = {
		"privacy": (1.0 - trait_of(s, "privacy")) * Tuning.Dialogue.OPENNESS_PRIVACY_WEIGHT,
		"trust": bond * Tuning.Dialogue.OPENNESS_TRUST_WEIGHT,
		"pressure": s.pressure * Tuning.Dialogue.OPENNESS_PRESSURE_WEIGHT * (1.0 - Tuning.Dialogue.OPENNESS_COMPOSURE_DAMP * trait_of(s, "composure")),
		"day": Tuning.Dialogue.OPENNESS_DAY_SLOPE * (w.day - 1), "base": Tuning.Dialogue.OPENNESS_BASE_OFFSET + Tuning.Social.SHARE_GIFT_PEER_OFFSET, "roll": jitter}
	if C.has_role_def(role):
		C.role_def(role).score_disclosure_tier(w, s, parts)
	var confide: bool = w.day <= 1 and not s.confided and w.confides_made < Tuning.Social.CONFIDE_MAX_PER_GAME
	if confide:
		parts["confidant"] = Tuning.Social.SHARE_ROLE_CONFIDE_BONUS
	var openness: float = 0.0
	for v in parts.values():
		openness += float(v)
	var tier: int = 1
	if openness > Tuning.Dialogue.TIER_PARTIAL:
		tier = 3
	elif openness > Tuning.Dialogue.TIER_VAGUE:
		tier = 2
	if tier == 3 and not topic.can_claim:
		tier = 2
	if tier == 2 and not topic.can_hint:
		tier = 1
	w.observe_decision(s, "npc_gift_disclosure", tier, {"openness": openness, "parts": parts,
		"thresholds": [{"above": Tuning.Dialogue.TIER_PARTIAL, "tier": 3}, {"above": Tuning.Dialogue.TIER_VAGUE, "tier": 2}, {"otherwise": 1}]}, l.id)
	if tier == 3:
		return {"kind": "role_claim", "about": s.id, "from": s.id, "role": role, "key": "role_claim:" + s.id, "lie": s.is_evil(), "confide": confide}
	if tier == 2:
		return {"kind": "role_hint", "about": s.id, "from": s.id, "package": str(topic.package), "key": "role_hint:" + s.id, "lie": s.is_evil()}
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
		var a_why: String = "lying" if a_false else ""
		PsychologistRole.record_heard(w, l, s.id, a_fact, a_false, a_why)

static func _deliver(w, s, l, item: Dictionary, public: bool = false, original: Dictionary = {}) -> void:
	_mark(s, l, item["key"])
	_record_direct_statement_for_listener(w, s, l, item, original)
	# A relay carries the original teller's "lie" flag (the listener's hearsay keeps it, so
	# the item stays what the source said). Passing it on is the relayer's lie only if they
	# are evil and know it: a good relayer repeating Edda's fabrication isn't lying
	# (playtest 26532: Greta was logged as lying for passing on Edda's fake Clerk reading).
	var relayed: bool = item.get("relay", false) and str(item.get("from", s.id)) != s.id
	var relayed_lie: bool = relayed and item.get("lie", false)
	var lie: bool = item.get("lie", false) and (not relayed or s.is_evil())
	if not public and not (s.is_evil() and l.is_evil()):
		w.daily_npc_shares.append({"day": w.day, "phase": w.phase, "loc": s.loc, "speaker": s.id, "listener": l.id, "item": item.duplicate(true)})
	var desc = _describe(w, s, item)
	# A public statement about the listener reaches them as a public receipt (every living
	# mind holds the same public record), but it isn't something told *to* them: no share line.
	var about_self: bool = public and str(item.get("about", "")) == l.id
	if not about_self:
		w.dlog.add("npc_share", s.id, l.id, {"kind": item["kind"], "about": item.get("about", ""), "from": item.get("from", ""),
			"relay": item.get("relay", false), "lie": lie, "relayed_lie": relayed_lie}, "%s tells %s: %s%s" % [s.name, l.name, desc, "  [LIE]" if lie else ""])
	if lie:
		w.dlog.think(s.id, "lie", "Told %s %s." % [l.name, desc], {"lie": true})
		if not public and s.is_evil() and not l.is_evil() and item.get("kind", "") in ["sighting", "opinion"] and s.id == str(w.evil_plan.get("daily_planter", "")):
			w.evil_plan["plants_today"] = int(w.evil_plan.get("plants_today", 0)) + 1
	if l.is_evil():
		Evil.intel_from_share(w, l, s, item)
		if item["kind"] == "secret":
			l.known_secrets[item["about"]] = s.id
			if item["about"] == s.id and str(item.get("burden", "")) != "":
				Burdens.claim(w, s, str(item["burden"]), false, "trusting %s" % l.name, l.id)
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
			if not public and not item.get("relay", false) and item.get("about", "") == s.id:
				s.confided = true
				if item.get("confide", false):
					w.confides_made += 1
					# Trusted with a secret, the listener warms to them; the confider a little too.
					l.npc_trust[s.id] = clampf(l.npc_trust.get(s.id, 0.5) + Tuning.Social.CONFIDE_TRUST_LISTENER, 0.0, 1.0)
					s.npc_trust[l.id] = clampf(s.npc_trust.get(l.id, 0.5) + Tuning.Social.CONFIDE_TRUST_TELLER, 0.0, 1.0)
					w.dlog.add("confide", s.id, l.id, {"role": item["role"], "lie": item.get("lie", false)}, "%s confides their gift to %s." % [s.name, l.name])
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
		"meeting":
			# Who was talking with whom: remembered, to pass on when asked about either of
			# them (MindDialogue._meeting_note). Not evidence in the listener's ledger.
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
			elif str(item.get("burden", "")) != "":
				Burdens.claim(w, s, str(item["burden"]), false, "trusting %s" % l.name, l.id)
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
		"meeting":
			return "%s and %s were talking at %s%s" % [w.by_id[item["about"]].name, w.by_id[item["with"]].name, w.loc_name(str(item["loc"])), via]
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
			return "%s's secret: %s %s" % [o.name, o.name, Burdens.phrase(o)]
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

# ---------------------------------------------------------------- agreement

## Backing a case builds trust (BACKLOG, Michael, Nov 18): a good NPC warms a little to
## someone who agrees with it (Trust.AGREEMENT_STEP, rebalanced Nov 19 so that confirming
## readings carry more of how trust builds), at most once a day for each ally: a day of
## agreeing votes is one agreement, not one per ballot. Evil NPCs' own trust isn't moved (their shadow copies it).
static func agreement_trust(w, l, ally_id: String, why: String) -> void:
	if l == null or not l.alive or l.is_evil() or ally_id == l.id or not w.by_id.has(ally_id):
		return
	var agreed: Dictionary = l.dialogue_memory.get("agreed_on_day", {})
	if int(agreed.get(ally_id, -1)) == w.day:
		return
	agreed[ally_id] = w.day
	l.dialogue_memory["agreed_on_day"] = agreed
	l.npc_trust[ally_id] = clampf(l.npc_trust.get(ally_id, 0.5) + Tuning.Trust.AGREEMENT_STEP, 0.0, 1.0)
	w.dlog.add("npc_trust", l.id, ally_id, {"to": snappedf(l.npc_trust[ally_id], 0.001), "agreement": why}, "%s %s" % [ally_id, why])

## Someone nominated or accused `target_id` in front of the town: every good NPC who already
## suspects them about as much as it takes to nominate (Meeting.NOMINATION_FLOOR) agrees.
static func backing_trust(w, target_id: String, backer_id: String, why: String) -> void:
	for l in w.living():
		if l.id == target_id or l.id == backer_id:
			continue
		if Mind.susp(l, target_id) >= Tuning.Meeting.NOMINATION_FLOOR:
			agreement_trust(w, l, backer_id, why)

## After a vote: each good voter warms to those who voted the same way (a no vote is how one
## NPC stands up for another, so this covers defences too).
static func vote_agreement_trust(w, nominee_id: String, yes: Array, no: Array) -> void:
	for side in [[yes, "voted with me to hang %s" % nominee_id], [no, "voted with me to spare %s" % nominee_id]]:
		var ids: Array = side[0]
		for a in ids:
			if a == nominee_id or not w.by_id.has(a):
				continue
			for b in ids:
				if b != a and b != nominee_id:
					agreement_trust(w, w.by_id[a], b, side[1])

# ---------------------------------------------------------------- paranoia

## Paranoia drift (a nightly flat rise in everyone's suspicion) was removed Oct 30: under the
## relative listener prior it carried no information. Urgency now lowers the vote bar
## (Tuning.Meeting.VOTE_URGENCY_PER_DEATH).

# ---------------------------------------------------------------- confirming readings

## Trust from a reading that confirms what I know or strongly believe (BACKLOG, Michael, Nov 19,
## set R3): each reading a good listener holds is judged once (ReadingConfirm.assess, on the
## listener's chances before it heard it), and a confirmation raises its trust in the teller by
## the tier's size. The record (`workshop_state.confirmed_readings`: teller -> its best
## confirmation; kept with the NPC's beliefs, not `dialogue_memory`, which holds only speech) is kept for
## what the NPC says (MindDialogue / MindMeeting: "their readings agree with what I know"). An
## evil NPC's good self keeps the record too, so it can say so honestly; its own trust doesn't
## move (the shadow copies the real NPC's). Returns whether any trust moved, so the refresh can
## capture again and solve with the new trust (a repeated refresh then changes nothing).
static func reading_confirm_trust(w, n, view: Dictionary, listener: Dictionary, chances: Dictionary) -> bool:
	var moved: bool = false
	var RC = load("res://workshop/reading_confirm.gd")
	var seen: Dictionary = n.workshop_state.get("confirm_seen", {})
	var record: Dictionary = n.workshop_state.get("confirmed_readings", {})
	var rank: Dictionary = {"small": 1, "moderate": 2, "known": 3}
	var size: Dictionary = {"small": Tuning.Trust.READING_TRUST_SMALL, "moderate": Tuning.Trust.READING_TRUST_MODERATE, "known": Tuning.Trust.READING_TRUST_KNOWN}
	for c in view.get("cards", []):
		var src: String = str(c.get("source", ""))
		var cid: String = str(c.get("id", ""))
		# Once for each reading: a Medium's relay of a reading already heard is the same reading
		# (its logical origin), though its receipt has an id of its own (Codex on #319).
		var origin: String = str(c.get("logical_origin", cid))
		if str(c.get("kind", "")) != "report" or src == n.id or seen.has(origin) or not w.by_id.has(src):
			continue
		seen[origin] = true
		var r: Dictionary = RC.assess(view, c, listener, chances)
		var tier: String = str(r.get("tier", "none"))
		if not rank.has(tier):
			continue
		var best: Dictionary = record.get(src, {})
		if best.is_empty() or int(rank[tier]) > int(rank.get(str(best.get("tier", "")), 0)):
			record[src] = {"tier": tier, "card": cid, "day": w.day, "source": str(r.get("source", "")), "agreement": snappedf(float(r.get("agreement", 0.0)), 0.001)}
		if n.is_shadow or n.is_evil():
			continue
		var was: float = n.npc_trust.get(src, 0.5)
		n.npc_trust[src] = clampf(was + float(size[tier]), 0.0, 1.0)
		moved = moved or not is_equal_approx(was, n.npc_trust[src])
		w.dlog.add("npc_trust", n.id, src, {"to": snappedf(n.npc_trust[src], 0.001), "step": float(size[tier]), "confirmation": tier, "source": str(r.get("source", "")), "card": cid},
			"%s's reading confirms what %s %s (%s)" % [src, n.id, "knows" if tier == "known" else "believes", tier])
	n.workshop_state["confirm_seen"] = seen
	n.workshop_state["confirmed_readings"] = record
	return moved

## "Their readings agree with what I know" (Michael, Nov 19): the speaker's best confirmation of
## `t_id`'s readings, when it's moderate or known, else {}. An evil speaker answers from its good
## self's record, so it only ever says this when it's true from that view.
static func readings_agree_record(n, t_id: String) -> Dictionary:
	var mind = n.shadow if n.is_evil() and n.shadow != null else n
	var rec: Dictionary = mind.workshop_state.get("confirmed_readings", {}).get(t_id, {})
	if str(rec.get("tier", "")) in ["moderate", "known"]:
		return rec
	return {}

## The player's card for it: the speaker speaks up for `t`, citing the reading.
static func readings_agree_fact(n, t, rec: Dictionary) -> Dictionary:
	return {"kind": "opinion", "subject": [t.id], "source": n.id, "stance": "for", "reason": "readings_agree", "cites": str(rec.get("card", "")),
		"text": "%s says %s's readings agree with what they know." % [n.name, t.name]}
