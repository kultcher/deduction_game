## The shadow self: evil's model of its own good self, kept in sync and consulted for
## cover (split from `sim/mind.gd`; part of Mind's inheritance chain).
extends "res://sim/mind_base.gd"


# ---------------------------------------------------------------- shadow self

## Evil NPCs keep a second, good mind: what they'd believe if they were the good
## townsperson they pretend to be, with their bluff as their gift (docs/shadow_self_plan.md).
## Every belief entry point below that used to skip evil listeners now feeds the shadow
## instead, through shadow_run. The shadow is a separate NPC object, never in w.npcs or
## w.by_id; it hears what the real NPC heard, minus what only evil could know (night
## sightings made while out on evil work), and takes evil's fake readings as its own.
## It runs on its own random stream and its own log (w.shadow_log), so it can't change
## the case. Step 1: nothing reads it yet.


## Run f(shadow) for evil NPC n inside the shadow context: the shadow's RNG and log in
## place of the world's, and the shadow synced with what n has seen since last time.
static func shadow_run(w, n, f: Callable) -> void:
	if not C.SHADOW_SELF or not n.is_evil():
		return
	var saved_rng = w.rng
	var saved_log = w.dlog
	var made = n.shadow == null
	if made:
		n.shadow = _make_shadow(w, n)
	var s = n.shadow
	w.rng = s.shadow_rng
	w.shadow_log.set_time(saved_log.day, saved_log.phase)
	w.dlog = w.shadow_log
	w.dlog.capture_npc(s, "before_shadow_sync")
	_shadow_sync(w, n, s)
	w.dlog.capture_npc(s, "after_shadow_sync")
	if made and s.role != "":
		_mind().hear_claim(w, s, s.id, s.role, Tuning.Setup.OWN_ROLE_CLAIM_WEIGHT, "own")  # knows "its own" gift, as every good NPC does
	f.call(s)
	w.dlog.capture_npc(s, "shadow_return")
	w.rng = saved_rng
	w.dlog = saved_log

static func _make_shadow(w, n):
	var s = n.get_script().new()
	for f in SHADOW_SAME:
		s.set(f, n.get(f))
	for f in SHADOW_COPY:
		s.set(f, n.get(f).duplicate(true))
	s.credibility = n.credibility  # the player's track record carries over (a Revenant turn included)
	s.alignment = "good"
	s.is_shadow = true
	var bluff: String = w.evil_plan["bluffs"].get(n.id, "")
	s.role = bluff if C.ROLES.has(bluff) and C.ROLES[bluff]["align"] == "good" else ""
	# A turned NPC's own true readings were theirs before the curse; fake ones arrive below.
	s.info_log = n.info_log.filter(func(e): return not e.get("fake", false)).map(func(e): return e.duplicate(true))
	s.applied_info = s.info_log.size()
	s.shadow_rng = RandomNumberGenerator.new()
	s.shadow_rng.seed = hash("%d:shadow:%s" % [w.seed_value, n.id])
	n.shadow_seen = {"beliefs": n.beliefs.size() if n.turned else 0, "hearsay": n.hearsay.size() if n.turned else 0, "fake": 0}
	if n.turned:
		s.beliefs = n.beliefs.map(func(b): return b.duplicate(true))
		s.hearsay = n.hearsay.map(func(h): return h.duplicate(true))
	return s

## Bring the shadow up to date with what the real NPC has seen and heard. Night sightings
## made while out (killing, poisoning, guarding a teammate) stay out: a good self would
## have been at home.
static func _shadow_sync(w, n, s) -> void:
	for f in ["alive", "death_day", "loc", "working", "busy_with", "silenced", "trust", "trust_cap", "credibility",
			"pressure", "claimed_role", "claim_public", "max_tier", "told_readings", "night_block", "out_last_night"]:
		s.set(f, n.get(f))
	for k in n.npc_trust:
		s.npc_trust[k] = n.npc_trust[k]
	for k in n.claim_record:
		s.claim_record[k] = n.claim_record[k].duplicate(true)
	s.history = n.history.duplicate()
	var seen: Dictionary = n.shadow_seen
	while seen["beliefs"] < n.beliefs.size():
		var b: Dictionary = n.beliefs[seen["beliefs"]]
		seen["beliefs"] += 1
		if b.get("phase", -1) == C.NIGHT and not str(n.history.get(w.time_key(b.get("day", 0), C.NIGHT), "home")).begins_with("home"):
			continue
		s.beliefs.append(b.duplicate(true))
	while seen["hearsay"] < n.hearsay.size():
		s.hearsay.append(n.hearsay[seen["hearsay"]].duplicate(true))
		seen["hearsay"] += 1
	for k in n.known_claims:
		if not s.known_claims.has(k) or s.known_claims[k] != n.known_claims[k]:
			s.known_claims[k] = n.known_claims[k].duplicate(true)

## Evil's fake readings, taken by the shadow as its own (firmly, not unshakably).
static func _shadow_own_info(w, n) -> void:
	shadow_run(w, n, func(s):
		var seen: Dictionary = n.shadow_seen
		while seen["fake"] < n.info_log.size():
			var e: Dictionary = n.info_log[seen["fake"]]
			seen["fake"] += 1
			if not e.get("fake", false):
				continue
			var mine = e.duplicate(true)
			s.info_log.append(mine)
			s.applied_info = s.info_log.size()
			_mind().apply_info(w, s, s, mine, C.SHADOW_OWN_READING_WEIGHT))

## A made-up reading of n's own changed before it was told (Evil.blend_clerk_readings): the
## shadow, which took the old version as its own reading, drops that one's evidence and takes
## the new, so its cover follows the reading n will actually claim (Codex on #269). A reading
## the shadow hasn't taken yet needs nothing: _shadow_own_info copies the new version.
static func shadow_replace_own_info(w, n, old_entry: Dictionary, new_entry: Dictionary) -> void:
	shadow_run(w, n, func(s):
		for i in range(s.info_log.size()):
			var e: Dictionary = s.info_log[i]
			if not e.get("fake", false) or e.get("role", "") != old_entry.get("role", "") or e.get("day", -1) != old_entry.get("day", -1) or e.get("data", {}) != old_entry.get("data", {}):
				continue
			s.ledger.erase(_mind().info_eid(s.id, e))
			var mine: Dictionary = new_entry.duplicate(true)
			s.info_log[i] = mine
			_mind().apply_info(w, s, s, mine, C.SHADOW_OWN_READING_WEIGHT)
			return)

## Step 2: should evil NPC n break cover, doing the evil choice instead of what its good
## self would? stakes: what the evil choice buys (a teammate saved, a frame pushed);
## deviation: how far the evil choice strays from the shadow's (0..1). Logged either way.
static func evil_override(w, n, act: String, stakes: float, deviation: float, detail: String) -> bool:
	var exp_parts: Dictionary = Evil.exposure(w, n)
	var exposure = 0.0
	for k in exp_parts:
		exposure += exp_parts[k]
	var cost = deviation * exposure
	var caution = Evil.caution(w, n)
	var yes = stakes - cost > caution
	w.dlog.decision(n.id, "evil_override", "evaluation", yes, {"act": act, "detail": detail,
		"stakes": stakes, "deviation": deviation, "exposure": exposure, "exposure_parts": exp_parts,
		"cost": cost, "caution": caution, "score": stakes - cost, "threshold": caution, "comparison": ">"})
	w.dlog.think(n.id, "override", "%s %s: %s (stakes %.2f - exposure cost %.2f vs caution %.2f)." %
		["Breaks cover on" if yes else "Keeps cover on", act, detail, stakes, cost, caution],
		{"act": act, "stakes": snappedf(stakes, 0.01), "cost": snappedf(cost, 0.01), "caution": snappedf(caution, 0.01), "exposure": exp_parts, "override": yes})
	return yes

## Run f(shadow) and return what it returns (null without a shadow).
static func shadow_eval(w, n, f: Callable):
	var box = {}
	shadow_run(w, n, func(sh): box["r"] = f.call(sh))
	return box.get("r")

## Snapshot the pre-curse good mind at `turn_evil` so `free_turned` restores it cleanly,
## carrying forward only public claims and readings from the turned period (Decision 3).
static func capture_pre_turn_snapshot(w, n) -> Dictionary:
	var snap: Dictionary = {"fields": {}, "public_claims_cursor": w.public_claims.size(), "shared_readings": {}}
	for f in SHADOW_COPY:
		if f in ["traits", "trait_base", "work_phases", "haunts", "friends", "rivals"]:
			continue
		snap.fields[f] = n.get(f).duplicate(true)
	snap["credibility"] = n.credibility
	snap["trust"] = n.trust
	snap["trust_cap"] = n.trust_cap
	snap["trust_at_reconsider"] = n.trust_at_reconsider
	snap["beliefs"] = n.beliefs.duplicate(true)
	snap["hearsay"] = n.hearsay.duplicate(true)
	snap["claimed_role"] = n.claimed_role
	snap["claim_public"] = n.claim_public
	snap["max_tier"] = n.max_tier
	snap["told_readings"] = n.told_readings
	for p in w.npcs:
		for en in p.info_log:
			if en.get("shared", false):
				snap.shared_readings[_mind().info_eid(p.id, en)] = true
	return snap

static func restore_pre_turn_snapshot(w, n) -> void:
	var snap: Dictionary = n.pre_turn_snapshot if n.pre_turn_snapshot is Dictionary else {}
	var turned_shadow = n.shadow
	if not snap.is_empty():
		var fields: Dictionary = snap.get("fields", {})
		for f in fields:
			n.set(f, fields[f].duplicate(true))
		n.credibility = float(snap.get("credibility", n.credibility))
		n.trust = float(snap.get("trust", n.trust))
		n.trust_cap = float(snap.get("trust_cap", n.trust_cap))
		n.trust_at_reconsider = float(snap.get("trust_at_reconsider", n.trust_at_reconsider))
		n.beliefs = snap.get("beliefs", []).duplicate(true)
		n.hearsay = snap.get("hearsay", []).duplicate(true)
		n.claimed_role = str(snap.get("claimed_role", n.claimed_role))
		n.claim_public = bool(snap.get("claim_public", n.claim_public))
		n.max_tier = int(snap.get("max_tier", n.max_tier))
		n.told_readings = int(snap.get("told_readings", n.told_readings))
	# Public hearings from the turned period (meeting testimony, volunteered sightings,
	# defences) were heard by the good-self shadow; carry those forward, nothing private.
	if turned_shadow != null:
		for eid in turned_shadow.ledger:
			var le: Dictionary = turned_shadow.ledger[eid]
			if not n.ledger.has(eid) and bool(le.get("meta", {}).get("workshop_public", false)):
				n.ledger[eid] = le.duplicate(true)
	n.pre_turn_snapshot = {}
	shadow_reset(n)
	for e in n.info_log:
		if e.get("fake", false):
			n.ledger.erase(_mind().info_eid(n.id, e))
	var prev_defer: bool = w.defer_beliefs
	w.defer_beliefs = true
	_mind().hear_claim(w, n, n.id, n.role, Tuning.Setup.OWN_ROLE_CLAIM_WEIGHT, "own")
	var cursor: int = int(snap.get("public_claims_cursor", 0))
	for idx in range(maxi(0, cursor), w.public_claims.size()):
		var pc: Dictionary = w.public_claims[idx]
		var who_id: String = str(pc.get("who", ""))
		var role_id: String = str(pc.get("role", ""))
		if who_id == n.id:
			if role_id == n.role:
				n.claimed_role = role_id
				n.claim_public = true
		elif who_id != "":
			_mind().hear_claim(w, n, who_id, role_id, Tuning.Mind.PUBLIC_CLAIM_HEARING_WEIGHT, "public")
	var prev_shared: Dictionary = snap.get("shared_readings", {})
	for p in w.npcs:
		if p == n:
			continue
		for en in p.info_log:
			if not en.get("shared", false) or en.get("disowned", false):
				continue
			var r_eid: String = _mind().info_eid(p.id, en)
			if not prev_shared.has(r_eid):
				_mind().apply_info(w, n, p, en, _mind().heard_weight(n, p))
	for a in w.stances:
		var st_target: String = str(w.stances[a].get("target", ""))
		if st_target != "" and st_target != n.id:
			MindMeeting.refresh_consensus(w, n, st_target)
	w.defer_beliefs = prev_defer
	_mind().flush_beliefs(w, n)
	_mind().refresh_beliefs(w, n, " (freed from the curse)")
	w.dlog.think(n.id, "freed_restore", "Freed: restored pre-curse mind and public receipts (%d ledger entries)." % n.ledger.size())

## Turned or freed by the Revenant's curse: the shadow is rebuilt (or dropped) next time.
static func shadow_reset(n) -> void:
	n.shadow = null
	n.shadow_seen = {}

## Debug: the shadow's view, for snapshots. {} if none.
static func shadow_view(w, n) -> Dictionary:
	if n.shadow == null:
		return {}
	var sus = {}
	for k in n.shadow.suspicion:
		if w.by_id.has(k) and w.by_id[k].alive:
			sus[k] = snappedf(_mind().susp(n.shadow, k), 0.01)
	return {"role": n.shadow.role, "trust": snappedf(n.shadow.trust, 0.01), "suspicion": sus}
