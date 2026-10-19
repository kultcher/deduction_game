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
static func public_heat(w, t) -> float:
	var h = 0.15
	for e in w.public_log:
		if w.by_id.has(e["by"]) and w.by_id[e["by"]].is_evil():
			continue
		if t.id in e["subjects"]:
			match e["kind"]:
				"accusation":
					h += 0.12
				"nomination":
					h += 0.2
				"reading":
					h += 0.2
				"vote_yes":
					h += 0.04
	return clampf(h, 0.0, 1.0)

## How exposed an evil member is right now (0..~1.5), as named parts: the town's public
## talk about them (evil's own included: the town can't tell it apart), the player's known
## suspicion, pressure, and being on the block. The cost of breaking cover scales with it.
static func exposure(w, n) -> Dictionary:
	var h = 0.0
	for e in w.public_log:
		if n.id in e["subjects"]:
			match e["kind"]:
				"accusation":
					h += 0.12
				"nomination":
					h += 0.2
				"reading":
					h += 0.2
				"vote_yes":
					h += 0.04
	var parts = {"public_talk": snappedf(minf(h, 1.0), 0.01)}
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
		if e["by"] != n.id:
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
		parts["noise"] = snappedf(w.rng.randf() * 0.8, 0.01)
		var total = 0.0
		for k in parts:
			total += parts[k]
		scores[n.id] = {"total": snappedf(total, 0.01), "parts": parts}
		if total > best_s:
			best_s = total
			best = n.id
	# Now and then the demon does something nobody would predict: it passes over its top
	# three and takes someone else.
	var zag = false
	if w.rng.randf() < 0.03 and scores.size() > 3:
		var order: Array = scores.keys()
		order.sort_custom(func(x, y): return scores[x]["total"] > scores[y]["total"])
		var rest: Array = order.slice(3).filter(func(x): return scores[x]["total"] > -5.0)
		if not rest.is_empty():
			best = rest[w.rng.randi_range(0, rest.size() - 1)]
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
	if C.ROLES[r].get("first_night", false):
		return w.day == 0
	if r == "gravedigger":
		return w.executed_today != ""
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
		parts["noise"] = snappedf(w.rng.randf() * 1.5, 0.01)
		var total = 0.0
		for k in parts:
			total += parts[k]
		scores[n.id] = {"total": snappedf(total, 0.01), "parts": parts}
		if total > best_s:
			best_s = total
			best = n.id
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
		match bluff:
			"surveyor":
				if w.day != 0:
					continue
				var tb = {}
				for x in w.npcs:
					if x.is_evil():
						tb[x.home_block] = true
				# Mostly a plausible wrong count (no more blocks than the team could cover);
				# sometimes the truth; now and then a count only a Marked soul could explain,
				# which can pass for a poisoned or Delusional reading.
				var team: int = 1 + w.minion_ids.size()
				var hi: int = mini(team, C.BLOCKS.size())
				var r_s = w.rng.randf()
				var cnt: int = tb.size()
				var kind_s = "the truth"
				if r_s < 0.6:
					var opts: Array = range(1, hi + 1).filter(func(x): return x != tb.size())
					if not opts.is_empty():
						cnt = w.pick(opts)
						kind_s = "a plausible wrong count"
				elif r_s >= 0.85 and team < C.BLOCKS.size():
					cnt = team + 1
					kind_s = "a count too high for the team (passes for a poisoned or Delusional reading)"
				why = "reports %d blocks: %s (true %d)" % [cnt, kind_s, tb.size()]
				entry = {"data": {"count": cnt}, "text": "I learned that %d of the four blocks %s an evil resident" % [cnt, "has" if cnt == 1 else "have"]}
			"rumormonger":
				if w.day != 0:
					continue
				var other = w.pick(w.living_good().filter(func(x): return x.id != s))
				var pair = w.shuffled([mate.id, other.id])
				var sk: String = w.pick(C.SECRET_MOD_LIST)
				why = "lends teammate %s a harmless secret" % mate.id
				entry = {"data": {"pair": pair, "secret": sk}, "text": "I heard that one of %s is %s" % [w._names(pair), w._secret_phrase(sk)]}
			"lamplighter":
				var cnt: int = clampi(w.night_walkers.size() + w.pick([-1, 0, 1]), 0, w.living().size() - 1)
				why = "guesses a plausible count of walkers (%d)" % cnt
				entry = {"data": {"count": cnt}, "text": "walking the lamps, I counted %d other%s out" % [cnt, "" if cnt == 1 else "s"]}
			"medium":
				# Like the real Medium: each of the dead once, the most recent first.
				var dead: Array = w.npcs.filter(func(x): return not x.alive and not x.is_evil() and not (x.id in n.medium_visited))
				if dead.is_empty() or w.day == 0 or not w.by_id[s].alive:
					continue
				dead.sort_custom(func(a, b): return a.death_day > b.death_day)
				var dd = dead[0]
				n.medium_visited.append(dd.id)
				var it = {"type": "sighting", "who": s, "block": w.by_id[s].home_block, "night": maxi(0, dd.death_day - 1)}
				why = "claims the dead %s saw scapegoat %s out" % [dd.id, s]
				entry = {"data": {"dead": dd.id, "item": it}, "text": w._medium_text(dd, it)}
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
			"hearthwitch":
				var nbrs: Array = w.living_neighbours(n).map(func(x): return x.id)
				var count = 0
				if s in nbrs:
					count = 1
					why = "frames scapegoat %s as an evil neighbour" % s
				else:
					var framable: Array = nbrs.filter(func(x): return not w.by_id[x].is_evil())
					if not framable.is_empty() and w.day >= 1 and w.chance(0.3):
						count = 1
						why = "frames a good neighbour"
					else:
						why = "reports 0 to clear neighbours (incl. any teammate)"
				entry = {"data": {"nbrs": nbrs, "count": count},
					"text": "I sensed that %d of my neighbours (%s) %s evil" % [count, w._names(nbrs), "is" if count == 1 else "are"]}
			"seer":
				var goods: Array = w.living_good().filter(func(x): return x.id != s).map(func(x): return x.id)
				if goods.size() < 2:
					goods = w.living().filter(func(x): return x != n).map(func(x): return x.id)
				var pair: Array = []
				var yes = false
				# Never a 'no' that covers the scapegoat: it would undo the frame.
				var others_s: Array = goods.filter(func(x): return x != s and x != mate.id)
				var others_m: Array = goods.filter(func(x): return x != mate.id and x != s)
				var late = w.living().size() <= 5
				if w.by_id[s].alive and (w.day % 2 == 1 or w.day == 0 or late) and not others_s.is_empty():
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
					continue
				pair = w.shuffled(pair)
				entry = {"data": {"pair": pair, "yes": yes},
					"text": "I looked at %s: %s" % [w._names(pair), "one of them reads as the demon" if yes else "neither is the demon"]}
			"nightwatch":
				var block: String = w.by_id[s].home_block
				var seen: Array = []
				for k in n.intel:
					var it: Dictionary = n.intel[k]
					if it["kind"] == "walker" and it.get("night", -1) == w.day and it.get("block", "") == block and w.by_id[it["about"]].alive:
						if not (it["about"] in seen):
							seen.append(it["about"])
				if not (s in seen) and w.day >= 1:
					seen.append(s)
					why = "watches scapegoat's block; adds fake sighting of %s to true ones" % s
				else:
					why = "reports walkers it knows of on scapegoat's block, hiding teammates"
				plan["fake_watch"][str(w.day)] = block
				entry = {"data": {"block": block, "seen": seen},
					"text": "I watched %s: %s" % [C.block_name(block),
						("I saw " + w._names(seen) + " pass by") if not seen.is_empty() else "nobody stirred"]}
			"archivist":
				if w.day != 0:
					continue
				var other = w.pick(w.living_good().filter(func(x): return x.id != s))
				var pair = w.shuffled([s, other.id])
				var mr: String = w.by_id[w.pick(w.minion_ids)].role
				why = "names scapegoat %s as a possible %s" % [s, mr]
				entry = {"data": {"pair": pair, "role": mr}, "text": "I learned that one of %s is the %s" % [w._names(pair), C.role_name(mr)]}
			"clerk":
				if w.day != 0:
					continue
				var other = w.pick(w.living_good())
				var role: String = plan["bluffs"].get(mate.id, w.pick(C.GOOD_ROLES))
				var pair = w.shuffled([mate.id, other.id])
				why = "vouches for teammate %s as the %s" % [mate.id, role]
				entry = {"data": {"pair": pair, "role": role}, "text": "I learned that one of %s is the %s" % [w._names(pair), C.role_name(role)]}
			"gravedigger":
				if w.executed_today == "":
					continue
				var ex = w.by_id[w.executed_today]
				var role = ""
				if ex.is_evil():
					role = plan["bluffs"][ex.id]
					why = "covers executed teammate as their bluff %s" % role
				elif ex.claimed_role != "" and ex.claimed_role != "none":
					role = ex.claimed_role
					why = "confirms executed good NPC's own claim (safe)"
				else:
					role = w.pick(C.GOOD_ROLES)
					why = "guesses a good role for executed NPC"
				entry = {"data": {"executed": ex.id, "role": role}, "text": "I learned that %s, whom we hanged, was the %s" % [ex.name, C.role_name(role)]}
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
		if s != n.id and w.by_id[s].alive and nd >= 1 and w.chance(0.5):
			var detail = "leaving_home" if (how == "window" and w.by_id[s].home_block == vantage and w.chance(0.5)) else "street"
			result = {"kind": "saw", "who": s, "loc": "", "block": vantage, "day": nd, "phase": C.NIGHT, "how": how, "detail": detail}
			w.dlog.think(n.id, "lie", "Evil: invents a night sighting of scapegoat %s on %s (%s)." % [s, vantage, "from their window" if how == "window" else "while out"], {"lie": true})
		cache[key] = result if result != null else false
	var r = cache[key]
	if not (r is Dictionary) or r["block"] != vantage:
		return null
	return r

static func fake_gossip(w, speaker):
	var s: String = w.evil_plan["scapegoat"]
	if s == "" or not w.by_id[s].alive or not w.chance(0.6):
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
	if w.rng.randf() < 0.5 * (1.0 - n.traits.get("insight", 0.5)):
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
			opts.append("I saw them out in the street from my window at night" if fs.get("how", "window") == "window" else "I saw them out on %s at night" % C.block_name(fs["block"]))
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
	if nom_n.role == "revenant" and nom_n.is_evil() and not w.totem.is_empty() and w.chance(0.55):
		# A hanged Revenant with a totem hidden curses the town: let it hang.
		yes = true
		why = "The Revenant's totem is hidden: its hanging will turn one of the town."
	elif is_teammate(w, v, nominee):
		var have = yes_so_far + (1 if player_yes else 0)  # counted so far, without me
		if v.id == w.demon_id and block == v.id and have + 1 == bc and have + 1 >= thr and w.chance(0.4 + 0.5 * v.traits.get("confidence", 0.5)):
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
		yes = w.chance(0.35 + 0.2 * v.traits.get("confidence", 0.5))
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
	var b: String = bs.home_block if bs.at_home() else w.loc_block(bs.loc)
	var cands: Array = w.living_good().filter(func(m): return m.id != bs.breath_last and m.silence_pending < 0 and not m.silenced \
		and (m.home_block if m.at_home() else w.loc_block(m.loc)) == b)
	if cands.is_empty():
		return ""
	var best = ""
	var best_s = -99.0
	var scores = {}
	for n in cands:
		var parts = _public_threat(w, n)
		var hostile = public_hostility(w, n)
		if hostile > 0.0:
			parts["publicly_against_us"] = hostile
		var known = intel_threat(bs, n.id)
		if known > 0.0:
			parts["known_threat"] = known
		parts["noise"] = snappedf(w.rng.randf() * 1.0, 0.01)
		var total = 0.0
		for k in parts:
			total += parts[k]
		scores[n.id] = snappedf(total, 0.01)
		if total > best_s:
			best_s = total
			best = n.id
	var p = [0.3, 0.5, 1.0][w.phase] if best_s > 1.0 else [0.15, 0.3, 0.7][w.phase]
	if not w.chance(p):
		w.dlog.think(bs.id, "breath_choice", "Breathstealer holds off this phase (best %s, %.2f)." % [best, best_s], {"scores": scores})
		return ""
	w.dlog.think(bs.id, "breath_choice", "Breathstealer silences %s (score %.2f)." % [best, best_s], {"scores": scores})
	return best

## Whether the Revenant hides its totem here and now (it will by evening).
static func place_totem_now(w, rv) -> bool:
	return w.chance([0.45, 0.6, 1.0][w.phase])
