## Evil team AI: shared plan, bluffs, scapegoat framing, poison and kill choices,
## fabricated info, and evil behaviour in votes and conversations.
## Every decision is logged with its reasoning.
extends RefCounted

const C = preload("res://sim/content.gd")
const Gifts = preload("res://sim/gifts.gd")

static func say(n, text: String) -> Dictionary:
	return {"speaker": n.id, "name": n.name, "text": text}

static func is_teammate(w, n, id: String) -> bool:
	return id != n.id and w.by_id[id].is_evil()

## Living teammates of an evil member.
static func mates(w, n) -> Array:
	return w.evil_team().filter(func(m): return m != n)

## One teammate to lean on (minions look to the demon first), or null.
static func mate(w, n):
	var ms: Array = mates(w, n)
	if ms.is_empty():
		return null
	for m in ms:
		if m.id == w.demon_id:
			return m
	return ms[0]

static func make_plan(w) -> Dictionary:
	var d = w.demon()
	var mood: String = w.pick(C.DEMON_MOODS)
	var info_bluffs: Array = w.bluffs.filter(func(r): return r in C.INFO_ROLES)
	var other_bluffs: Array = w.bluffs.filter(func(r): return not (r in C.INFO_ROLES))
	var ordered: Array = info_bluffs + other_bluffs
	var bl = {d.id: ordered[0]}
	var k = 1
	for mid in w.minion_ids:
		bl[mid] = ordered[k % ordered.size()]
		k += 1
	var plan = {
		"mood": mood,
		"scapegoat": "",
		"bluffs": bl,
		"failed": [],
		"caution": 0.0,        # after an unexplained failed kill: shy away from high-profile targets
		"fake_watch": {},
		"fake_sightings": {},
		"spared": [],
		"vet_suspects": [],    # failed kills nobody visibly explained: maybe a Veteran
		"warden_suspects": [], # glimpsed at a door when a kill failed
		"poison_for_kill": "", # tonight's kill target the Poisoner should poison (Veteran combo)
	}
	w.evil_plan = plan
	_pick_scapegoat(w, "initial plan")
	w.dlog.think(d.id, "evil_plan", "Demon temperament '%s'. Bluffs %s. Scapegoat %s." %
		[mood, str(plan["bluffs"]), plan["scapegoat"]], plan.duplicate(true))
	return plan

static func _pick_scapegoat(w, why: String) -> void:
	var goods: Array = w.living_good()
	if goods.is_empty():
		return
	var best = null
	var best_s = -1.0
	for g in goods:
		var s: float = w.rng.randf()
		# Only what the demon itself knows (its own sightings, and whatever the team has pooled).
		for k in w.demon().intel:
			var it: Dictionary = w.demon().intel[k]
			if it["kind"] == "walker" and it["about"] == g.id:
				s += 1.0  # seen out at night: easier to frame
		if w.demon().npc_trust.get(g.id, 0.5) < 0.4:
			s += 0.5
		if g.claim_public and g.claimed_role in ["veteran", "warden"]:
			s += 0.2  # claims a gift the demon can't kill through: better hanged
		if s > best_s:
			best_s = s
			best = g
	w.evil_plan["scapegoat"] = best.id
	w.dlog.think(w.demon_id, "scapegoat", "Evil picks %s as scapegoat (%s)." % [best.id, why])

## Each morning (from day 2), evil reconsiders its scapegoat: ride the town's suspect
## rather than steer it. Score per living good candidate, as named parts:
##   momentum   the town's heat on them, plus how far evil's good selves suspect them;
##   fit        lies already told that point at them, and being seen out at night;
##   dead_end   public clears;
##   keep       the current scapegoat's switching cost (more if the team has accused them
##              in public: dropping them cold would look odd).
static func review_scapegoat(w) -> void:
	ensure_scapegoat(w)
	var cur: String = w.evil_plan.get("scapegoat", "")
	if w.day < 2 or cur == "":
		return
	var team: Array = w.evil_team().filter(func(m): return m.alive)
	var best = ""
	var best_s = -99.0
	var table = {}
	for g in w.living_good():
		var parts = {"momentum": public_heat(w, g)}
		var sh_vals: Array = team.filter(func(m): return m.shadow != null).map(func(m): return clampf(m.shadow.suspicion.get(g.id, 0.1), 0.0, 1.5))
		if not sh_vals.is_empty():
			parts["momentum"] += 0.5 * sh_vals.reduce(func(a, b): return a + b) / sh_vals.size()
		var fit = 0.0
		for m in team:
			for e in m.info_log:
				if e.get("fake", false) and e.get("shared", false) and g.id in Gifts.implicated(e):
					fit += 0.25
			for k in m.intel:
				if m.intel[k]["kind"] == "walker" and m.intel[k]["about"] == g.id:
					fit += 0.15
		parts["fit"] = minf(fit, 0.6)
		var clears = 0.0
		for e in w.public_log:
			if e["kind"] == "clear" and g.id in e["subjects"]:
				clears += 0.3 * pow(HEAT_FADE, w.day - e["day"])
		if clears > 0.0:
			parts["dead_end"] = -clears
		if g.id == cur:
			var accused = w.public_log.filter(func(e): return e["kind"] == "accusation" and g.id in e["subjects"] and w.by_id.has(e["by"]) and w.by_id[e["by"]].is_evil()).size()
			parts["keep"] = 0.25 + 0.15 * accused
		var total = 0.0
		for k in parts:
			total += parts[k]
		table[g.id] = snappedf(total, 0.01)
		if total > best_s:
			best_s = total
			best = g.id
	if best != "" and best != cur:
		w.evil_plan["scapegoat"] = best
		w.dlog.think(w.demon_id, "scapegoat", "Evil switches scapegoat %s -> %s (scores %s)." % [cur, best, str(table)], {"scores": table, "from": cur, "to": best})
	else:
		w.dlog.think(w.demon_id, "scapegoat", "Evil keeps scapegoat %s (scores %s)." % [cur, str(table)], {"scores": table})

## A fake Medium reading at dd's hearth. Drawn from the same menu a real Medium's
## readings fall into, so no single kind of answer gives it away:
## - now and then (C.MEDIUM_USELESS_CHANCE) something true-sounding but empty, as a real
##   Medium sometimes gets;
## - a reading in the dead's publicly claimed gift that they "never shared"
##   (_fake_dead_reading): not always the most damning one; it may carry on an earlier
##   suspicion of theirs, or quietly clear the demon;
## - a sighting of the scapegoat near the death (the dead's own block, their last night),
##   unless that's the scapegoat's own block;
## - "nothing they hadn't already told us" (when they had shared readings), their last
##   public stance, or that they were home.
## Framing (anything that points at the good) isn't every night: after the first, about half.
static func _fake_medium_item(w, n, dd, s: String) -> Dictionary:
	if dd.alive or dd.death_cause != "demon":
		return {} # Public hearth eligibility only; fabrication choices below are unchanged.
	var night = maxi(0, dd.death_day - 1)
	var sg = w.by_id[s]
	if w.chance(C.MEDIUM_USELESS_CHANCE):
		var gs: Array = w.living_good()
		if not gs.is_empty() and w.chance(0.5):
			var g = w.pick(gs)
			return {"item": {"type": "sighting", "who": g.id, "block": g.home_block, "night": night, "lie": true, "idle": true},
				"why": "an empty one: the dead saw %s out on their own block (no frame)" % g.id}
		return {"item": {"type": "home", "night": night, "block": dd.home_block, "lie": false},
			"why": "an empty one: the dead was home"}
	var frames: int = w.evil_plan.get("medium_frames", 0)
	var frame_ok = frames == 0 or w.chance(0.5)
	var opts: Array = []   # [weight, {item, why, frames}]
	if dd.claim_public and dd.claimed_role != "":
		var r = _fake_dead_reading(w, n, dd, dd.claimed_role, s, night)
		if not r.is_empty() and (frame_ok or not r["frames"]):
			opts.append([3.0, {"item": {"type": "reading", "entry": r["entry"], "lie": true}, "why": r["why"], "frames": r["frames"]}])
	if frame_ok and sg.home_block != dd.home_block:
		opts.append([1.5, {"item": {"type": "sighting", "who": s, "block": dd.home_block, "night": night, "lie": true},
			"why": "claims the dead %s saw scapegoat %s out near their cottage on their last night" % [dd.id, s], "frames": true}])
	if dd.info_log.any(func(e): return e.get("shared", false)):
		opts.append([0.8, {"item": {"type": "nothing", "lie": false}, "why": "says the dead %s had nothing new to tell" % dd.id, "frames": false}])
	var said: String = w.stances.get(dd.id, {}).get("target", "")
	if said != "" and w.by_id.has(said) and w.by_id[said].alive and not w.by_id[said].is_evil():
		opts.append([0.8, {"item": {"type": "suspicion", "about": said, "lie": false},
			"why": "repeats the dead %s's public distrust of %s" % [dd.id, said], "frames": false}])
	opts.append([0.4, {"item": {"type": "home", "night": night, "block": dd.home_block, "lie": false},
		"why": "says only that the dead %s was home" % dd.id, "frames": false}])
	var total = 0.0
	for o in opts:
		total += o[0]
	var r2 = w.rng.randf() * total
	var pick: Dictionary = opts[-1][1]
	for o in opts:
		r2 -= o[0]
		if r2 <= 0.0:
			pick = o[1]
			break
	if pick["frames"]:
		w.evil_plan["medium_frames"] = frames + 1
	return pick

## Whether the demon has been named by any public reading (so clearing it is worth a lie).
static func _demon_implicated(w) -> bool:
	return w.public_log.any(func(e): return e["kind"] == "reading" and w.demon_id in e["subjects"])

## A reading the dead (publicly the `role`) supposedly never shared, for their last night
## (or the first night, for gifts that only read then). {} if none fits: the gift has no
## readings, they already shared that night's, or there's nobody to name.
## Returns {entry, why, frames} (frames: it points at the good).
static func _fake_dead_reading(w, n, dd, role: String, s: String, night: int) -> Dictionary:
	if not C.has_readings(role):
		return {}
	if role in C.START_ROLES:
		night = 0
	if dd.info_log.any(func(e): return e.get("shared", false) and e.get("role", "") == role and e.get("day", -1) == night):
		return {}
	var sg = w.by_id[s]
	var goods: Array = w.living_good().filter(func(x): return x != dd)
	var other = func(not_ids: Array): 
		var c = goods.filter(func(x): return not (x.id in not_ids))
		return w.pick(c) if not c.is_empty() else null
	var d = w.by_id[w.demon_id] if w.by_id.has(w.demon_id) else null
	var team_mates: Array = mates(w, n).filter(func(x): return x.alive)
	var e = {"role": role, "day": night, "fake": true}
	var rdef = C.role_def(role)
	if rdef != null:
		return rdef.fake_medium_reading(w, n, dd, s, sg, d, goods, other, e, _demon_implicated(w))
	match role:
		"psychologist":
			var subj = other.call([s])
			var tr = w.pick(team_mates) if not team_mates.is_empty() else null
			if subj == null or tr == null:
				return {}
			var sus_id: String = s if w.chance(0.6) else (other.call([subj.id]).id if other.call([subj.id]) != null else s)
			e["data"] = {"subject": subj.id, "trusts": tr.id, "suspects": sus_id}
			e["text"] = "I read %s: they trust %s most, and suspect %s most" % [subj.name, tr.name, w.by_id[sus_id].name]
			return {"entry": e, "why": "the dead Psychologist %s 'read' trust in %s" % [dd.id, tr.id], "frames": true}
	return {}

static func ensure_scapegoat(w) -> void:
	var s: String = w.evil_plan.get("scapegoat", "")
	if s == "" or not w.by_id[s].alive:
		_pick_scapegoat(w, "previous scapegoat gone")

# ---------------------------------------------------------------- what evil knows

## Record something an evil member knows. kind: threat | walker | player_suspects
static func add_intel(w, m, kind: String, about: String, score: float, why: String, extra: Dictionary = {}) -> void:
	var key = "%s:%s:%s" % [kind, about, why]
	if m.intel.has(key):
		return
	var it = {"kind": kind, "about": about, "score": score, "why": why, "day": w.day, "from": m.id}
	for k in extra:
		it[k] = extra[k]
	m.intel[key] = it
	w.dlog.add("evil_intel", m.id, about, it, "%s learns: %s (%s)" % [m.name, why, kind])

## Two evil members pool what they know (a meeting, a whisper, or the first night).
static func share_intel(w, a, b, how: String) -> void:
	var gave_a = 0
	var gave_b = 0
	for k in a.intel:
		if not b.intel.has(k):
			b.intel[k] = a.intel[k].duplicate()
			gave_a += 1
	for k in b.intel:
		if not a.intel.has(k):
			a.intel[k] = b.intel[k].duplicate()
			gave_b += 1
	w.dlog.add("evil_share", a.id, b.id, {"how": how, "a_gave": gave_a, "b_gave": gave_b},
		"Evil %s: %s and %s pool what they know (%d + %d items)." % [how, a.name, b.name, gave_a, gave_b])

static func unshared_intel(a, b) -> int:
	var c = 0
	for k in a.intel:
		if not b.intel.has(k):
			c += 1
	return c

static func intel_threat(m, id: String) -> float:
	var t = 0.0
	for k in m.intel:
		var it: Dictionary = m.intel[k]
		if it["kind"] == "threat" and it["about"] == id:
			t += it["score"]
	return minf(t, 3.0)

## After each night: evil members note who they saw out (and who may have seen them).
static func gather_night_intel(w) -> void:
	for m in w.evil_team():
		for b in m.beliefs:
			if b["kind"] == "saw" and b["phase"] == C.NIGHT and b["day"] == w.day and not w.by_id[b["who"]].is_evil():
				add_intel(w, m, "walker", b["who"], 0.0, "saw them out on %s on night %d" % [C.block_name(b["block"]), w.day],
					{"block": b["block"], "night": w.day})
				if m.out_last_night and m.night_block == b["block"]:
					add_intel(w, m, "threat", b["who"], 1.0, "was out near me on night %d; may have seen me" % w.day)
	if w.day == 0:
		var team: Array = w.evil_team()
		for i in range(team.size()):
			for j in range(i + 1, team.size()):
				share_intel(w, team[i], team[j], "first-night conference")

## How hot the public mood is against someone, from public events only (0..1). Evil
## discounts its own team's contributions: it knows those aren't the town's view.
## Readings count by how strongly they point at t (a Seer "yes" more than one of four in a
## Dowser's crowd); public clears cool it; older talk fades (HEAT_FADE a day).
const HEAT_FADE = 0.75
static func public_heat(w, t) -> float:
	var h = 0.15
	for e in w.public_log:
		if w.by_id.has(e["by"]) and w.by_id[e["by"]].is_evil():
			continue
		if t.id in e["subjects"]:
			h += _heat_of(e, t.id) * pow(HEAT_FADE, w.day - e["day"])
	return clampf(h, 0.0, 1.0)

static func _heat_of(e: Dictionary, id: String) -> float:
	match e["kind"]:
		"accusation":
			return 0.12
		"nomination":
			return 0.2
		"reading":
			var wt = e.get("data", {}).get("weights", {})
			return 0.4 * wt[id] if wt.has(id) else 0.2
		"vote_yes":
			return 0.04
		"clear":
			return -0.12
	return 0.0

## How exposed an evil member is right now (0..~1.5), as named parts: the town's public
## talk about them (evil's own included: the town can't tell it apart), the player's known
## suspicion, pressure, and being on the block. The cost of breaking cover scales with it.
static func exposure(w, n) -> Dictionary:
	var h = 0.0
	for e in w.public_log:
		if n.id in e["subjects"]:
			h += _heat_of(e, n.id) * pow(HEAT_FADE, w.day - e["day"])
	var parts = {"public_talk": snappedf(clampf(h, 0.0, 1.0), 0.01)}
	for k in n.intel:
		if n.intel[k]["kind"] == "player_suspects" and n.intel[k]["about"] == n.id:
			parts["player_suspects"] = 0.3
			break
	if n.pressure > 0.0:
		parts["pressure"] = snappedf(0.5 * n.pressure, 0.01)
	var m: Dictionary = w.meeting
	if m.get("block", "") == n.id or n.id in m.get("nominated", []):
		parts["on_the_block"] = 0.2
	return parts

## How much it takes for an evil member to break cover (stakes beyond exposure must beat
## it). The demon stays careful; minions loosen as the days pass, from self-preservation
## toward sowing chaos (their "evil id").
static func caution(w, n) -> float:
	if n.id == w.demon_id:
		return maxf(0.45, C.EVIL_CAUTION_DEMON - 0.03 * (w.day - 1))
	return maxf(C.MINION_CAUTION_FLOOR, C.EVIL_CAUTION_MINION - C.MINION_ID_DRIFT * maxi(0, w.day - 2))

## What a teammate's life is worth to the team: the demon's is the game.
static func teammate_value(w, id: String) -> float:
	return 2.0 if id == w.demon_id else 1.0

## How much someone has publicly acted against the evil team.
static func public_hostility(w, n) -> float:
	var h = 0.0
	for e in w.public_log:
		if e["by"] != n.id or e["kind"] == "clear":
			continue
		for sid in e["subjects"]:
			if w.by_id.has(sid) and w.by_id[sid].is_evil():
				h += 0.5 if e["kind"] == "vote_yes" else 1.0
	return minf(h, 2.5)

## True if an info result points toward the evil team.
static func info_implicates(w, e: Dictionary) -> bool:
	for id in Gifts.implicated(e):
		if w.by_id.has(id) and w.by_id[id].is_evil():
			return true
	return false

static func _public_threat(w, n) -> Dictionary:
	var parts = {}
	if n.claim_public and n.claimed_role in C.INFO_ROLES:
		parts["info_claim"] = 3.0
		if n.claimed_role == "seer":
			parts["seer"] = 1.0
	for e in n.info_log:
		if e["shared"] and info_implicates(w, e):
			parts["implicates_us"] = 2.0
	return parts

static func choose_kill_target(w) -> String:
	ensure_scapegoat(w)
	var d = w.demon()
	var plan: Dictionary = w.evil_plan
	var scores = {}
	var observed = {}
	var best = ""
	var best_s = -99.0
	var warden_claimed = false
	for pc in w.public_claims:
		if pc["role"] == "warden" and w.by_id[pc["who"]].alive and pc["who"] != d.id:
			warden_claimed = true
	for n in w.living_good():
		var parts = _public_threat(w, n)
		if parts.has("info_claim") and C.ROLES.get(n.claimed_role, {}).get("first_night", false) and w.day >= 1:
			# Their start knowledge is already out: less of a threat than a gift that keeps reporting.
			parts["info_claim"] = 1.0
		var hostile = public_hostility(w, n)
		if hostile > 0.0:
			parts["publicly_against_us"] = snappedf(hostile * 0.8, 0.01)
		var known = intel_threat(d, n.id)
		if known > 0.0:
			parts["known_threat"] = known
		var alone = true
		for m in w.living():
			if m != n and m.home_block == n.home_block:
				alone = false
		if alone:
			parts["lives_alone"] = 0.7
		match plan["mood"]:
			"vengeful":
				if d.npc_trust.get(n.id, 0.5) < 0.4:
					parts["mood_vengeful"] = 1.5
			"cunning":
				var s = w.by_id[plan["scapegoat"]]
				if n.home_block == s.home_block:
					parts["mood_cunning_frame"] = 1.5
			"hungry":
				parts["mood_hungry"] = snappedf(w.rng.randf() * 2.0, 0.01)
		if n.id == plan["scapegoat"] and w.living().size() > 4:
			parts["keep_scapegoat"] = -4.0
		var fails: int = plan["failed"].filter(func(x): return x == n.id).size()
		var vet = believed_veteran(w, n)
		var poisoner_up = w.living_with_role("poisoner") != null
		if vet and fails >= 1 and n.id in plan.get("vet_suspects", []) + _claimed_vets(w):
			# The Veteran survives only the first attack: that's spent now.
			parts["veteran_spent"] = 0.3
		elif vet and poisoner_up:
			# Survives the first attack... unless the Poisoner breaks the gift first.
			parts["veteran_with_poison"] = 0.6
		elif vet:
			parts["veteran_first_attack_wasted"] = -2.0
		elif fails > 0:
			parts["failed_before"] = -10.0 * fails
		if n.id in plan["spared"] and w.living().size() > 4:
			parts["spared_keep_to_frame"] = -1.5
		if warden_claimed and n.claim_public and n.claimed_role in C.INFO_ROLES:
			parts["likely_warded"] = -0.8
		var caution: float = plan.get("caution", 0.0)
		if caution > 0.05:
			var profile = 0.0
			for k in _public_threat(w, n):
				profile += _public_threat(w, n)[k]
			if profile > 0.0:
				parts["caution_low_profile"] = snappedf(-caution * minf(profile, 4.0) * 0.7, 0.01)
		var noise_draw = w.rng.randf()
		parts["noise"] = snappedf(noise_draw * 0.8, 0.01)
		var total = 0.0
		for k in parts:
			total += parts[k]
		if w.dlog.live_feed != null and w.dlog.live_feed.enabled:
			observed[n.id] = {"score": total, "raw_draw": noise_draw, "noise": parts["noise"], "parts": parts.duplicate()}
		scores[n.id] = {"total": snappedf(total, 0.01), "parts": parts}
		if total > best_s:
			best_s = total
			best = n.id
	w.observe_ranked(d, "kill_ranking", observed, best, 0.8)
	# Now and then the demon does something nobody would predict: it passes over its top
	# three and takes someone else.
	var zag = false
	if w.decision_roll(d, "unpredictable_kill", 0.03) and scores.size() > 3:
		var order: Array = scores.keys()
		order.sort_custom(func(x, y): return scores[x]["total"] > scores[y]["total"])
		var rest: Array = order.slice(3).filter(func(x): return scores[x]["total"] > -5.0)
		if not rest.is_empty():
			best = w.decision_pick(d, "unpredictable_kill_target", rest)
			best_s = scores[best]["total"]
			zag = true
	w.dlog.think(d.id, "kill_choice", "Demon targets %s (score %.2f)%s." % [best, best_s, " (an unpredictable choice: skipped its top three)" if zag else ""], {"scores": scores, "caution": plan.get("caution", 0.0), "zag": zag})
	plan["poison_for_kill"] = ""
	if best != "" and believed_veteran(w, w.by_id[best]) and w.living_with_role("poisoner") != null and best_s > -5.0 \
			and not (best in plan["failed"]):
		plan["poison_for_kill"] = best
		w.dlog.think(d.id, "evil_plan", "Asks the Poisoner to poison %s first, so the Veteran's gift fails tonight." % best)
	plan["caution"] = plan.get("caution", 0.0) * 0.5  # fades over the next nights
	return best

static func _claimed_vets(w) -> Array:
	return w.public_claims.filter(func(pc): return pc["role"] == "veteran").map(func(pc): return pc["who"])

## Whether evil believes this person is the Veteran: they claimed it publicly, or an
## attack on them failed with no Warden or ward in sight.
static func believed_veteran(w, n) -> bool:
	for pc in w.public_claims:
		if pc["who"] == n.id and pc["role"] == "veteran":
			return true
	return n.id in w.evil_plan.get("vet_suspects", [])

## Whether poisoning this person tonight would stop anything. Gifts of the first night only
## are spent after it; the Gravedigger only works after an execution; the Veteran only
## matters if attacked. Judged from what evil knows: public claims (else assume it's live).
static func gift_live_tonight(w, n) -> bool:
	if not n.claim_public:
		return true
	var r: String = n.claimed_role
	if not C.ROLES.has(r):
		return true
	var rdef = C.role_def(r)
	if rdef != null:
		return rdef.gift_live_tonight(w, n)
	if C.ROLES[r].get("first_night", false):
		return w.day == 0
	if r == "veteran":
		return false  # only worth it as part of an attack (see poison_for_kill)
	if r == "martyr":
		return w.day >= 1  # poison lasts through tomorrow's hanging
	if r == "sexton":
		return false  # the knell is tolled in the evening, after tonight's poison has worn off
	return true

static func choose_poison_target(w, exclude: String = "") -> String:
	var m = w.living_with_role("poisoner")
	if m == null:
		return ""
	var plan: Dictionary = w.evil_plan
	var combo: String = plan.get("poison_for_kill", "")
	if combo != "" and w.by_id[combo].alive and w.demon().alive:
		w.dlog.think(m.id, "poison_choice", "Poisoner targets %s, as the demon asked: the Veteran's gift must fail tonight." % combo, {"combo": true})
		return combo
	# A Warden at the door would spoil a kill on someone prominent: break the Warden instead.
	var kt = w.by_id.get(exclude)
	var wardens: Array = []
	for pc in w.public_claims:
		if pc["role"] == "warden" and w.by_id[pc["who"]].alive and not w.by_id[pc["who"]].is_evil():
			wardens.append(pc["who"])
	for id in plan.get("warden_suspects", []):
		if w.by_id[id].alive and not (id in wardens):
			wardens.append(id)
	var scores = {}
	var observed = {}
	var best = ""
	var best_s = -99.0
	for n in w.living_good():
		if n.id == exclude:
			continue
		var parts = _public_threat(w, n)
		if not gift_live_tonight(w, n):
			parts["gift_spent"] = -3.5  # poisoning them tonight would change nothing
		var hostile = public_hostility(w, n)
		if hostile > 0.0:
			parts["publicly_against_us"] = snappedf(hostile * 0.6, 0.01)
		var known = intel_threat(m, n.id)
		if known > 0.0:
			parts["known_threat"] = known
		if n.id in wardens and kt != null:
			parts["disable_warden"] = 2.5 if (kt.claim_public and kt.claimed_role in C.INFO_ROLES) else 1.2
		var noise_draw = w.rng.randf()
		parts["noise"] = snappedf(noise_draw * 1.5, 0.01)
		var total = 0.0
		for k in parts:
			total += parts[k]
		if w.dlog.live_feed != null and w.dlog.live_feed.enabled:
			observed[n.id] = {"score": total, "raw_draw": noise_draw, "noise": parts["noise"], "parts": parts.duplicate()}
		scores[n.id] = {"total": snappedf(total, 0.01), "parts": parts}
		if total > best_s:
			best_s = total
			best = n.id
	w.observe_ranked(m, "poison_ranking", observed, best, 1.5)
	w.dlog.think(m.id, "poison_choice", "Poisoner targets %s (score %.2f)%s." % [best, best_s,
		" (blind guess on the first night)" if w.day == 0 else ""], {"scores": scores})
	return best

static func note_kill_result(w, target: String, outcome: String) -> void:
	if outcome == "protected_player":
		# The Demonologist's chalk sigil is plain on the door, and a ward is spent once used.
		w.dlog.think(w.demon_id, "kill_failed", "Attack on %s failed: the Demonologist's sigil was on the door. Wards are single-use; no need for caution." % target)
		return
	var spotted = false
	if outcome == "protected_warden":
		# Anyone the demon glimpsed on that block tonight is probably the Warden at the door.
		var d = w.demon()
		var tb: String = w.by_id[target].home_block
		for b in d.beliefs:
			if b["kind"] == "saw" and b["day"] == w.day and b["phase"] == C.NIGHT and b["block"] == tb and b["who"] != target:
				spotted = true
				add_intel(w, d, "threat", b["who"], 2.0, "was outside %s's door when the attack failed: likely the Warden" % target)
				if not (b["who"] in w.evil_plan["warden_suspects"]):
					w.evil_plan["warden_suspects"].append(b["who"])
	if outcome != "killed":
		w.evil_plan["failed"].append(target)
		if not spotted and not (target in w.evil_plan["vet_suspects"]):
			# Nobody at the door: perhaps they simply can't be killed.
			w.evil_plan["vet_suspects"].append(target)
		w.evil_plan["caution"] = minf(w.evil_plan.get("caution", 0.0) + 1.0, 1.5)
		w.dlog.think(w.demon_id, "kill_failed", "Attack on %s failed (%s). Will shy away from high-profile targets for a while (caution %.2f)." %
			[target, "someone was at the door: a Warden" if spotted else "nobody in sight: a Warden unseen, or a Veteran; may try again with poison", w.evil_plan["caution"]])

# ---------------------------------------------------------------- fabricated info

static func make_fake_info(w) -> void:
	ensure_scapegoat(w)
	var plan: Dictionary = w.evil_plan
	var s: String = plan["scapegoat"]
	for n in w.evil_team():
		if not plan["bluffs"].has(n.id):
			continue
		var bluff: String = plan["bluffs"][n.id]
		var mate = mate(w, n)
		if mate == null:
			mate = n  # alone: "clear a teammate" options fall back to clearing themself
		var entry = {}
		var why = ""
		# An agreed player request for tonight (as Mind.requested_targets; no Mind here).
		var rq: Dictionary = n.gift_request
		var asked: Array = rq.get("targets", []) if rq.get("night", -1) == w.day and rq.get("role", "") == bluff else []
		var bdef = C.role_def(bluff)
		if bdef != null:
			bdef.on_evil_agreed_request(w, n, asked)
			if bdef.kind != "info":
				continue
			var gen: Dictionary = bdef.generate_bluff_reading(w, n, plan, s, mate, asked)
			if gen.is_empty():
				continue
			entry = gen["entry"]
			why = gen["why"]
		else:
			match bluff:
				"rumormonger":
					if w.day != 0:
						continue
					var other = w.pick(w.living_good().filter(func(x): return x.id != s))
					var pair = w.shuffled([mate.id, other.id])
					var sk: String = w.pick(C.SECRET_MOD_LIST)
					why = "lends teammate %s a harmless secret" % mate.id
					entry = {"data": {"pair": pair, "secret": sk}, "text": "I heard that one of %s is %s" % [w._names(pair), w._secret_phrase(sk)]}
				"psychologist":
					var talked: Array = n.talked_today.filter(func(i): return w.by_id[i].alive and i != s)
					if talked.is_empty() or not w.by_id[s].alive:
						continue
					var subj: String = talked[w.rng.randi_range(0, talked.size() - 1)]
					var tr = w.pick(w.living().filter(func(x): return x.id != subj and x.id != s))
					if tr == null:
						continue
					why = "says %s suspects scapegoat %s most" % [subj, s]
					entry = {"data": {"subject": subj, "trusts": tr.id, "suspects": s},
						"text": "I read %s: they trust %s most, and suspect %s most" % [w.by_id[subj].name, tr.name, w.by_id[s].name]}
				"martyr":
					if w.day == 0 or plan.has("martyr_bluff_" + n.id):
						continue
					plan["martyr_bluff_" + n.id] = true
					var tgt = mate if mate != n else w.pick(w.living_good())
					why = "'chooses' %s, vouching for them" % tgt.id
					entry = {"data": {"target": tgt.id, "chosen": true}, "text": "I have given my life over for %s, should the town ever hang them" % tgt.name}
				_:
					continue
		entry["day"] = w.day
		entry["role"] = bluff
		entry["shared"] = false
		entry["true"] = false
		entry["fake"] = true
		entry["why"] = "evil fabrication: " + why
		n.info_log.append(entry)
		w.dlog.add("fake_info", n.id, "", entry, "%s (evil, bluffing %s) prepares: %s [%s]" % [n.name, bluff, entry["text"], why])

## A made-up sighting of the scapegoat on night nd, told from where this evil member says
## they were (vantage): from their own window at home, or while out on a night-active bluff
## (Night Watch, Warden). One story per night: if the cached one was told from elsewhere, it
## isn't repeated here (it wouldn't fit). "" vantage = their own home.
static func fake_night_sighting(w, n, nd: int, vantage: String = "", how: String = "window"):
	if vantage == "":
		vantage = n.home_block
		how = "window"
	var key = "%s:%d" % [n.id, nd]
	var cache: Dictionary = w.evil_plan["fake_sightings"]
	if not cache.has(key):
		var s: String = w.evil_plan["scapegoat"]
		var result = null
		# One story per member per night: a made-up watch report for this night already says
		# who passed where, so a sighting can only repeat it (Constance, 54875: "I saw Isolde"
		# privately, "I saw Jory" in her Night Watch reading for the same night).
		var watch: Dictionary = _own_fake_reading(n, nd, "nightwatch")
		if not watch.is_empty():
			var seen: Array = watch.get("data", {}).get("seen", []).filter(func(x): return x != n.id and w.by_id.has(x))
			if watch["data"].get("block", "") == vantage and not seen.is_empty():
				var who: String = s if s in seen else seen[0]
				result = {"kind": "saw", "who": who, "loc": "", "block": vantage, "day": nd, "phase": C.NIGHT, "how": how, "detail": "street"}
				w.dlog.think(n.id, "lie", "Evil: tells the night-%d sighting of %s from its own fake watch report." % [nd, who], {"lie": true})
			cache[key] = result if result != null else false
		elif s != n.id and w.by_id[s].alive and nd >= 1 and w.chance(0.5):
			var detail = "leaving_home" if (how == "window" and w.by_id[s].home_block == vantage and w.chance(0.5)) else "street"
			result = {"kind": "saw", "who": s, "loc": "", "block": vantage, "day": nd, "phase": C.NIGHT, "how": how, "detail": detail}
			w.dlog.think(n.id, "lie", "Evil: invents a night sighting of scapegoat %s on %s (%s)." % [s, vantage, "from their window" if how == "window" else "while out"], {"lie": true})
		if not cache.has(key):
			cache[key] = result if result != null else false
	var r = cache[key]
	if not (r is Dictionary) or r["block"] != vantage:
		return null
	return r

## This member's own made-up reading of the given gift for night nd ({} if none).
static func _own_fake_reading(n, nd: int, role: String) -> Dictionary:
	for e in n.info_log:
		if e.get("fake", false) and e.get("role", "") == role and e.get("day", -1) == nd:
			return e
	return {}

static func fake_gossip(w, speaker):
	var s: String = w.evil_plan["scapegoat"]
	if s == "" or not w.by_id[s].alive or not w.decision_roll(speaker, "spread_false_gossip", 0.6, {}, s):
		return null
	var block: String = w.by_id[s].home_block
	for sid in w.scenes:
		if w.scenes[sid]["day"] == w.day - 1:
			block = w.scenes[sid]["block"]
	var sg = w.by_id[s]
	w.dlog.think(speaker.id, "lie", "Evil gossip: spreads a false rumour that %s was out on %s." % [s, block], {"lie": true})
	return {"lines": ["You overhear %s telling the room that %s was skulking around %s last night." % [speaker.name, sg.name, C.block_name(block)]],
		"facts": [{"kind": "sighting", "subject": [s], "block": block, "day": w.day - 1, "phase": C.NIGHT, "source": speaker.id,
			"text": "Gossip from %s: %s was out on %s on night %d." % [speaker.name, sg.name, C.block_name(block), w.day - 1]}]}

# ---------------------------------------------------------------- meeting behaviour

## Whether a speaker states their reason or keeps it vague ("something's off").
## Identical for both alignments, so vagueness is never a tell.
static func cite(w, n, why: String) -> String:
	if why == "":
		return ""
	if why.begins_with("my own") and not n.claim_public:
		return ""  # citing it would give away a gift they haven't claimed
	if w.decision_roll(n, "careless_bluff_reason", 0.5 * (1.0 - n.traits.get("insight", 0.5)), {"insight": n.traits.get("insight", 0.5)}):
		return ""
	return why

## A reason evil can give for distrusting someone, grounded only in an active bluff:
## a fabricated reading (own or teammate's) already shared that names them, or a fake
## sighting of them this NPC has told the player. "" if none (then they stay vague).
static func bluff_reason(w, n, t) -> String:
	var opts: Array = []
	for e in n.info_log:
		var d: Dictionary = e["data"]
		if e.get("fake", false) and e["shared"] and t.id in Gifts.implicated(e):
			opts.append("my own reading pointed at them")
	for mt in mates(w, n):
		for e in mt.info_log:
			if e.get("fake", false) and e["shared"] and t.id in Gifts.implicated(e):
				opts.append("%s's reading pointed at them" % mt.name)
	for k in w.evil_plan["fake_sightings"]:
		var fs = w.evil_plan["fake_sightings"][k]
		if fs is Dictionary and fs["who"] == t.id and k.begins_with(n.id + ":"):
			var night: int = int(fs.get("day", k.get_slice(":", 1)))
			var walking_claim: bool = C.ROLES.get(n.claimed_role, {}).get("night_walk", false)
			if walking_claim:
				opts.append("I saw them out on %s on night %d, while I was out on my duty" % [C.block_name(fs["block"]), night])
			else:
				opts.append("I saw them out in the street from my window on night %d" % night if fs.get("how", "window") == "window" else "I saw them out on %s on night %d" % [C.block_name(fs["block"]), night])
	if opts.is_empty():
		return ""
	return w.pick(opts)

## What the town seems to think of someone, judged from public events; evil mimics this.
static func town_view(w, t) -> float:
	return public_heat(w, t)

static func evil_nomination(w, n):
	ensure_scapegoat(w)
	var s: String = w.evil_plan["scapegoat"]
	var m: Dictionary = w.meeting
	if w.day < 2 or s == "" or not w.by_id[s].alive or s in m["nominated"] or m["block"] == s:
		return null
	if m["block"] != "" and not w.by_id[m["block"]].is_evil():
		w.dlog.think(n.id, "nominate", "Evil: a good NPC (%s) is already on the block; no need to nominate." % m["block"])
		return null
	var avg = public_heat(w, w.by_id[s])
	var bold = n.traits.get("confidence", 0.5)
	w.observe_decision(n, "evil_nomination", avg >= 0.45 - 0.15 * bold, {"score": avg, "threshold": 0.45 - 0.15 * bold, "comparison": ">=", "inputs": {"confidence": bold, "public_heat": avg}}, s)
	if avg >= 0.45 - 0.15 * bold:
		return {"nominee": s, "by": n.id, "score": avg + 0.2,
			"reason": "Evil: public heat on scapegoat %s is %.2f; pushes the nomination." % [s, avg]}
	w.dlog.think(n.id, "nominate", "Evil: public heat on scapegoat %s only %.2f; waits." % [s, avg])
	return null

static func evil_vote(w, v, nominee: String, yes_so_far: int, player_yes: bool = false) -> bool:
	var thr: int = w.vote_threshold()
	var block: String = w.meeting["block"]
	var bc: int = w.meeting["block_count"]
	var yes = false
	var why = ""
	var nom_n = w.by_id[nominee]
	if nom_n.role == "revenant" and nom_n.is_evil() and not w.totem.is_empty() and w.decision_roll(v, "vote_revenant_curse", 0.55, {}, nominee):
		# A hanged Revenant with a totem hidden curses the town: let it hang.
		yes = true
		why = "The Revenant's totem is hidden: its hanging will turn one of the town."
	elif is_teammate(w, v, nominee):
		var have = yes_so_far + (1 if player_yes else 0)  # counted so far, without me
		if v.id == w.demon_id and block == v.id and have + 1 == bc and have + 1 >= thr and w.decision_roll(v, "vote_to_tie", 0.4 + 0.5 * v.traits.get("confidence", 0.5), {"confidence": v.traits.get("confidence", 0.5)}, nominee):
			# On the block myself: one more vote ties the count and clears the block.
			yes = true
			why = "Demon on the block votes for own minion: %d votes ties the block's %d and clears it." % [have + 1, bc]
		elif v.id == w.demon_id and have >= thr and have > bc:
			yes = true
			why = "Demon votes to execute own minion: it passes without me (%d of %d), and this looks good." % [have, thr]
		else:
			why = "Protects teammate."
	elif block != "" and w.by_id[block].is_evil() and block != nominee:
		yes = true
		why = "A teammate is on the block; votes to replace them with a good NPC."
	elif nominee == w.evil_plan["scapegoat"]:
		yes = true
		why = "Votes to hang the scapegoat."
	elif yes_so_far >= thr - 2:
		yes = true
		why = "Joins a likely-winning vote against a good NPC."
	else:
		yes = w.decision_roll(v, "vote_to_look_natural", 0.35 + 0.2 * v.traits.get("confidence", 0.5), {"confidence": v.traits.get("confidence", 0.5)}, nominee)
		why = "Coin-flip vote on a good NPC to look natural."
	w.dlog.think(v.id, "vote", "%s on %s. %s" % ["YES" if yes else "no", nominee, why], {"evil": true})
	return yes

static func evil_hear_accusation(w, n, suspect, card: Dictionary, relevance: float, times: int = 0) -> Dictionary:
	var plan: Dictionary = w.evil_plan
	var lines: Array = []
	var src: String = card.get("source", "")
	var serves = 0.85  # how much evil wants this case to land
	if suspect.is_evil():
		serves = 0.1
		add_intel(w, n, "player_suspects", suspect.id, 0.0, "the Demonologist suspects %s" % suspect.id)
		if src != "" and w.by_id.has(src) and not w.by_id[src].is_evil() and w.by_id[src].alive:
			add_intel(w, n, "threat", src, 2.0, "their evidence is being used against %s" % suspect.id)
		w.dlog.think(n.id, "evil_learns", "Player suspects teammate %s; will try to silence source %s and keep framing %s." %
			[suspect.id, src, plan["scapegoat"]], {"card": card.get("text", "")})
	elif suspect.id == plan["scapegoat"]:
		w.dlog.think(n.id, "evil_learns", "Player already suspects the scapegoat %s. Good." % suspect.id)
	else:
		w.dlog.think(n.id, "evil_learns", "Player suspects good NPC %s; evil encourages it." % suspect.id)
	# Replies come from the same set a good listener uses (see mind.gd hear_accusation).
	var r = w.rng.randf()
	var strength: float = relevance
	if times > 0:
		lines.append(say(n, "You've told me that already."))
	elif suspect == n:
		lines.append(say(n, "Me? That's madness."))
	elif relevance < 0.3:
		lines.append(say(n, "I don't see what that has to do with %s." % suspect.name))
	elif serves < 0.5:
		if card.get("kind", "") in ["claim", "hint", "refusal", "opinion", "accusation", "alibi"] and r < 0.5:
			lines.append(say(n, "That's only talk. Show me something real."))
		else:
			lines.append(say(n, "Maybe. I'll keep an eye on %s." % suspect.name))
	elif strength >= 0.9 and r < 0.35:
		lines.append(say(n, "You're right. I'll not trust %s again." % suspect.name))
	elif r < 0.7:
		lines.append(say(n, "That... does look bad for %s." % suspect.name))
	else:
		lines.append(say(n, "Maybe. I'll keep an eye on %s." % suspect.name))
	return {"lines": lines, "facts": [], "repeated": times > 0}

## An evil NPC learns from what a good NPC told them in conversation.
static func intel_from_share(w, m, speaker, item: Dictionary) -> void:
	var about: String = item.get("about", "")
	match item["kind"]:
		"reading":
			if info_implicates(w, item["entry"]):
				add_intel(w, m, "threat", speaker.id, 2.0, "their %s reading points at us" % item["entry"]["role"])
		"sighting":
			if about != "" and w.by_id[about].is_evil():
				add_intel(w, m, "threat", speaker.id, 2.0, "says they saw %s out at night" % about)
			elif about != "":
				add_intel(w, m, "walker", about, 0.0, "heard they were out on %s on night %d" % [C.block_name(item["block"]), item["day"]],
					{"block": item["block"], "night": item["day"]})
		"opinion", "case":
			if about != "" and w.by_id[about].is_evil():
				add_intel(w, m, "threat", speaker.id, 1.0, "is suspicious of %s" % about)

# ---------------------------------------------------------------- day gifts

## The Breathstealer picks whom to silence, among the good on its block (not the same
## person twice running). Likelier as the day goes on; the most dangerous voice first.
static func breath_target(w, bs) -> String:
	# The Breathstealer must be out in a public place; the target can be anywhere on the
	# same block (Case 22485: no stealing breath from inside one's own house).
	if bs.at_home():
		return ""
	var b: String = w.loc_block(bs.loc)
	var cands: Array = w.living_good().filter(func(m): return m.id != bs.breath_last and m.silence_pending < 0 and not m.silenced \
		and (m.home_block if m.at_home() else w.loc_block(m.loc)) == b)
	if cands.is_empty():
		return ""
	var best = ""
	var best_s = -99.0
	var scores = {}
	var observed = {}
	for n in cands:
		var parts = _public_threat(w, n)
		var hostile = public_hostility(w, n)
		if hostile > 0.0:
			parts["publicly_against_us"] = hostile
		var known = intel_threat(bs, n.id)
		if known > 0.0:
			parts["known_threat"] = known
		var noise_draw = w.rng.randf()
		parts["noise"] = snappedf(noise_draw * 1.0, 0.01)
		var total = 0.0
		for k in parts:
			total += parts[k]
		if w.dlog.live_feed != null and w.dlog.live_feed.enabled:
			observed[n.id] = {"score": total, "raw_draw": noise_draw, "noise": parts["noise"], "parts": parts.duplicate()}
		scores[n.id] = snappedf(total, 0.01)
		if total > best_s:
			best_s = total
			best = n.id
	w.observe_ranked(bs, "silence_ranking", observed, best, 1.0)
	var p = [0.3, 0.5, 1.0][w.phase] if best_s > 1.0 else [0.15, 0.3, 0.7][w.phase]
	if not w.decision_roll(bs, "silence_this_phase", p, {"best_target_score": best_s}, best):
		w.dlog.think(bs.id, "breath_choice", "Breathstealer holds off this phase (best %s, %.2f)." % [best, best_s], {"scores": scores})
		return ""
	w.dlog.think(bs.id, "breath_choice", "Breathstealer silences %s (score %.2f)." % [best, best_s], {"scores": scores})
	return best

## Whether the Revenant hides its totem here and now (it will by evening).
static func place_totem_now(w, rv) -> bool:
	return w.decision_roll(rv, "place_totem_now", [0.45, 0.6, 1.0][w.phase])
