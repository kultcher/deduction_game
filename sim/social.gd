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

static func trait_of(n, t: String) -> float:
	return n.traits.get(t, 0.5)

static func _told(s, l, key: String) -> bool:
	return s.told_to.has(l.id + "|" + key)

static func _mark(s, l, key: String) -> void:
	s.told_to[l.id + "|" + key] = true

static func _implicated(e: Dictionary) -> Array:
	return Gifts.implicated(e)

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
		if h.get("public", false) or h["from"] == l.id or h.get("about", "") in [s.id, l.id] or h["kind"] in ["secret", "day_sighting", "unease"]:
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

static func _deliver(w, s, l, item: Dictionary, public: bool = false, original: Dictionary = {}) -> void:
	_mark(s, l, item["key"])
	var lie: bool = item.get("lie", false)
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
				l.known_claims[src.id] = {"role": e["role"], "readings": [], "via": s.id}
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
		"opinion", "unease":
			# Remember the conversation and teller, without turning their conclusion
			# into evidence about its target (Q4).
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
			var e: Dictionary = h["entry"]
			var f = Mind.info_fact(w, src, e)
			f["via"] = n.id
			f["text"] = "Via %s: " % n.name + f["text"]
			var role_s: String = C.role_name(e["role"])
			var report_s: String = C.third_person(e["text"])
			var reading_fallback: String = "%s told me their gift is %s, and that %s." % [src.name, role_s, report_s]
			return {"lines": [Mind.say_voiced(n, "gossip_reading", reading_fallback, {"source": src.name, "role": role_s, "report": report_s})], "facts": [f]}
		if h["kind"] == "sighting":
			var who = w.by_id[h["about"]]
			var by = w.by_id[h["from"]].name if w.by_id.has(h["from"]) else "someone"
			var block_s: String = C.block_name(h["block"])
			var night_s: String = "on night %d" % h["day"]
			var sighting_fallback: String = "%s says %s was out on %s %s." % [by, who.name, block_s, night_s]
			return {"lines": [Mind.say_voiced(n, "gossip_sighting", sighting_fallback, {"source": by, "subject": who.name, "block": block_s, "night": night_s})],
				"facts": [{"kind": "sighting", "subject": [who.id], "block": h["block"], "day": h["day"], "phase": C.NIGHT, "source": h["from"], "via": n.id,
					"text": "Via %s: %s saw %s on %s on night %d." % [n.name, by, who.name, block_s, h["day"]]}]}
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
			for e in kc["readings"]:
				var said_rd: String = C.third_person(e["text"])
				var rd_fb: String = "They said %s." % said_rd
				text += " " + rd_fb
				voiced_chunks.append(Dialogue.voice_line(n.id, "role_query_reading", rd_fb, {"reading": said_rd}))
				var f = Mind.info_fact(w, who, e)
				f["via"] = n.id
				f["text"] = "Via %s: " % n.name + f["text"]
				facts.append(f)
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
