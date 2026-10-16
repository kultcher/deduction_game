## Evil team AI: shared plan, bluffs, scapegoat framing, poison and kill choices,
## fabricated info, and evil behaviour in votes and conversations.
## Every decision is logged with its reasoning.
extends RefCounted

const C = preload("res://sim/content.gd")

static func say(n, text: String) -> Dictionary:
	return {"speaker": n.id, "name": n.name, "text": text}

static func is_teammate(w, n, id: String) -> bool:
	return id != n.id and w.by_id[id].is_evil()

static func make_plan(w) -> Dictionary:
	var d = w.demon()
	var m = w.minion()
	var mood: String = w.pick(C.DEMON_MOODS)
	var info_bluffs: Array = w.bluffs.filter(func(r): return r in C.INFO_ROLES)
	var other_bluffs: Array = w.bluffs.filter(func(r): return not (r in C.INFO_ROLES))
	var ordered: Array = info_bluffs + other_bluffs
	var plan = {
		"mood": mood,
		"scapegoat": "",
		"bluffs": {d.id: ordered[0], m.id: ordered[1] if ordered.size() > 1 else ordered[0]},
		"player_suspects": {},
		"silence": {},
		"failed": [],
		"fake_watch": {},
		"fake_sightings": {},
		"spared": [],
	}
	w.evil_plan = plan
	_pick_scapegoat(w, "initial plan")
	w.dlog.think(d.id, "evil_plan", "Demon temperament '%s'. Demon bluffs %s, minion bluffs %s. Scapegoat %s." %
		[mood, plan["bluffs"][d.id], plan["bluffs"][m.id], plan["scapegoat"]], plan.duplicate(true))
	return plan

static func _pick_scapegoat(w, why: String) -> void:
	var goods: Array = w.living_good()
	if goods.is_empty():
		return
	var best = null
	var best_s = -1.0
	for g in goods:
		var s: float = w.rng.randf()
		if not g.secret.is_empty():
			s += 1.0  # out at night: easier to frame
		if w.demon().npc_trust.get(g.id, 0.5) < 0.4:
			s += 0.5
		if g.role == "veteran" or g.role == "warden":
			s += 0.2
		if s > best_s:
			best_s = s
			best = g
	w.evil_plan["scapegoat"] = best.id
	w.dlog.think(w.demon_id, "scapegoat", "Evil picks %s as scapegoat (%s)." % [best.id, why])

static func ensure_scapegoat(w) -> void:
	var s: String = w.evil_plan.get("scapegoat", "")
	if s == "" or not w.by_id[s].alive:
		_pick_scapegoat(w, "previous scapegoat gone")

## True if an info result points toward the evil team.
static func info_implicates(w, e: Dictionary) -> bool:
	var d: Dictionary = e["data"]
	match e["role"]:
		"seer":
			return d["yes"] and (w.demon_id in d["pair"])
		"hearthwitch":
			return d["count"] > 0 and (w.demon_id in d["nbrs"] or w.minion_id in d["nbrs"])
		"archivist":
			return w.minion_id in d["pair"]
		"nightwatch":
			return w.demon_id in d["seen"] or w.minion_id in d["seen"]
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
		var hostility: float = n.suspicion.get(d.id, 0.0)
		if hostility > 0.4:
			parts["hostile_to_demon"] = snappedf(hostility * 1.5, 0.01)
		for b in n.beliefs:
			if b["kind"] == "saw" and b["who"] in [w.demon_id, w.minion_id] and b["phase"] == C.NIGHT:
				parts["saw_us_at_night"] = 2.0
		if plan["silence"].has(n.id):
			parts["confided_in_player"] = plan["silence"][n.id]
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
				if s.npc_trust.get(n.id, 0.5) < 0.4 or n.home_block == s.home_block:
					parts["mood_cunning_frame"] = 1.5
			"hungry":
				parts["mood_hungry"] = snappedf(w.rng.randf() * 2.0, 0.01)
		if n.id == plan["scapegoat"] and w.living().size() > 4:
			parts["keep_scapegoat"] = -4.0
		var fails: int = plan["failed"].filter(func(x): return x == n.id).size()
		if fails > 0:
			parts["failed_before"] = -10.0 * fails
		if n.id in plan["spared"] and w.living().size() > 4:
			parts["spared_keep_to_frame"] = -1.5
		if warden_claimed and n.claim_public and n.claimed_role in C.INFO_ROLES:
			parts["likely_warded"] = -0.8
		parts["noise"] = snappedf(w.rng.randf() * 0.8, 0.01)
		var total = 0.0
		for k in parts:
			total += parts[k]
		scores[n.id] = {"total": snappedf(total, 0.01), "parts": parts}
		if total > best_s:
			best_s = total
			best = n.id
	w.dlog.think(d.id, "kill_choice", "Demon targets %s (score %.2f)." % [best, best_s], {"scores": scores})
	return best

static func choose_poison_target(w, exclude: String = "") -> String:
	var m = w.minion()
	var scores = {}
	var best = ""
	var best_s = -99.0
	for n in w.living_good():
		if n.id == exclude:
			continue
		var parts = _public_threat(w, n)
		var hostility: float = n.suspicion.get(w.demon_id, 0.0) + n.suspicion.get(m.id, 0.0)
		if hostility > 0.5:
			parts["hostile_to_us"] = snappedf(hostility, 0.01)
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
	if outcome != "killed":
		w.evil_plan["failed"].append(target)
		w.dlog.think(w.demon_id, "kill_failed", "Attack on %s failed; demon will switch to a new target." % target)

# ---------------------------------------------------------------- fabricated info

static func make_fake_info(w) -> void:
	ensure_scapegoat(w)
	var plan: Dictionary = w.evil_plan
	var s: String = plan["scapegoat"]
	for n in [w.demon(), w.minion()]:
		if not n.alive:
			continue
		var bluff: String = plan["bluffs"][n.id]
		var mate = w.minion() if n == w.demon() else w.demon()
		var entry = {}
		var why = ""
		match bluff:
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
				var others_s: Array = goods.filter(func(x): return x != s)
				var others_m: Array = goods.filter(func(x): return x != mate.id)
				if w.by_id[s].alive and (w.day % 2 == 1 or w.day == 0) and not others_s.is_empty():
					pair = [s, w.pick(others_s)]
					yes = true
					why = "frames scapegoat %s with a 'yes'" % s
				elif mate.alive and w.chance(0.4) and not others_m.is_empty():
					pair = [mate.id, w.pick(others_m)]
					why = "clears teammate %s with a 'no'" % mate.id
				elif goods.size() >= 2:
					pair = w.shuffled(goods).slice(0, 2)
					why = "harmless 'no' on two people"
				else:
					continue
				pair = w.shuffled(pair)
				entry = {"data": {"pair": pair, "yes": yes},
					"text": "I looked at %s: %s" % [w._names(pair), "one of them reads as the demon" if yes else "neither is the demon"]}
			"nightwatch":
				var block: String = w.by_id[s].home_block
				var seen: Array = []
				for wk in w.night_walkers:
					if wk["block"] == block and not w.by_id[wk["id"]].is_evil():
						seen.append(wk["id"])
				if not (s in seen) and w.day >= 1:
					seen.append(s)
					why = "watches scapegoat's block; adds fake sighting of %s to true ones" % s
				else:
					why = "reports true walkers on scapegoat's block, hiding teammates"
				plan["fake_watch"][str(w.day)] = block
				entry = {"data": {"block": block, "seen": seen},
					"text": "I watched %s: %s" % [C.block_name(block),
						("I saw " + w._names(seen) + " pass by") if not seen.is_empty() else "nobody stirred"]}
			"archivist":
				if w.day != 0:
					continue
				var other = w.pick(w.living_good().filter(func(x): return x.id != s))
				var pair = w.shuffled([s, other.id])
				why = "names scapegoat %s as a possible Poisoner" % s
				entry = {"data": {"pair": pair, "role": "poisoner"}, "text": "I learned that one of %s is the Poisoner" % w._names(pair)}
			"clerk":
				if w.day != 0:
					continue
				var other = w.pick(w.living_good())
				var role: String = plan["bluffs"][mate.id]
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

static func fake_night_sighting(w, n, nd: int):
	var key = "%s:%d" % [n.id, nd]
	var cache: Dictionary = w.evil_plan["fake_sightings"]
	if cache.has(key):
		return cache[key] if cache[key] is Dictionary else null
	var s: String = w.evil_plan["scapegoat"]
	var result = null
	if s != n.id and w.by_id[s].alive and nd >= 1 and w.chance(0.5):
		var block: String = w.by_id[s].home_block
		for sid in w.scenes:
			if w.scenes[sid]["day"] == nd:
				block = w.scenes[sid]["block"]
		result = {"kind": "saw", "who": s, "loc": "", "block": block, "day": nd, "phase": C.NIGHT}
		w.dlog.think(n.id, "lie", "Evil: invents a night sighting of scapegoat %s on %s." % [s, block], {"lie": true})
	cache[key] = result if result != null else false
	return result

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
		var named: Array = d.get("pair", []) + d.get("nbrs", []) + d.get("seen", [])
		if e.get("fake", false) and e["shared"] and t.id in named:
			opts.append("my own reading pointed at them")
	var mate = w.minion() if n.id == w.demon_id else w.demon()
	for e in mate.info_log:
		var d2: Dictionary = e["data"]
		var named2: Array = d2.get("pair", []) + d2.get("nbrs", []) + d2.get("seen", [])
		if e.get("fake", false) and e["shared"] and t.id in named2:
			opts.append("%s's reading pointed at them" % mate.name)
	for k in w.evil_plan["fake_sightings"]:
		var fs = w.evil_plan["fake_sightings"][k]
		if fs is Dictionary and fs["who"] == t.id and k.begins_with(n.id + ":"):
			opts.append("I saw them out on %s at night" % C.block_name(fs["block"]))
	if opts.is_empty():
		return ""
	return w.pick(opts)

## What the town (good NPCs) thinks of someone on average; evil mimics this.
static func town_view(w, t) -> float:
	var goods: Array = w.living_good().filter(func(g): return g != t)
	if goods.is_empty():
		return 0.3
	var total = 0.0
	for g in goods:
		total += g.suspicion.get(t.id, 0.0)
	return total / goods.size()

static func evil_nomination(w, n):
	ensure_scapegoat(w)
	var s: String = w.evil_plan["scapegoat"]
	var m: Dictionary = w.meeting
	if w.day < 2 or s == "" or not w.by_id[s].alive or s in m["nominated"] or m["block"] == s:
		return null
	if m["block"] != "" and not w.by_id[m["block"]].is_evil():
		w.dlog.think(n.id, "nominate", "Evil: a good NPC (%s) is already on the block; no need to nominate." % m["block"])
		return null
	var goods: Array = w.living_good()
	var total = 0.0
	for g in goods:
		total += g.suspicion.get(s, 0.0)
	var avg = total / maxf(1.0, goods.size())
	var bold = n.traits.get("confidence", 0.5)
	if avg >= 0.4 - 0.2 * bold:
		return {"nominee": s, "by": n.id, "score": avg + 0.2,
			"reason": "Evil: town suspicion of scapegoat %s averages %.2f; pushes the nomination." % [s, avg]}
	w.dlog.think(n.id, "nominate", "Evil: scapegoat %s not suspected enough yet (avg %.2f); waits." % [s, avg])
	return null

static func evil_vote(w, v, nominee: String, yes_so_far: int) -> bool:
	var thr: int = w.vote_threshold()
	var block: String = w.meeting["block"]
	var yes = false
	var why = ""
	if is_teammate(w, v, nominee):
		if v.id == w.demon_id and yes_so_far >= thr - 1:
			yes = true
			why = "Demon votes to execute own minion: it will pass anyway, and this looks good."
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

static func evil_hear_accusation(w, n, suspect, card: Dictionary, relevance: float) -> Dictionary:
	var plan: Dictionary = w.evil_plan
	var lines: Array = []
	var src: String = card.get("source", "")
	if suspect.is_evil():
		plan["player_suspects"][suspect.id] = true
		if src != "" and w.by_id.has(src) and not w.by_id[src].is_evil() and w.by_id[src].alive:
			plan["silence"][src] = 2.0
		w.dlog.think(n.id, "evil_learns", "Player suspects teammate %s; evil will try to silence source %s and keep framing %s." %
			[suspect.id, src, plan["scapegoat"]], {"card": card.get("text", "")})
		if suspect == n:
			lines.append(say(n, "Me? That's madness."))
		else:
			lines.append(say(n, "Hm. I'll keep an eye on %s, then." % suspect.name))
	elif suspect.id == plan["scapegoat"]:
		w.dlog.think(n.id, "evil_learns", "Player already suspects the scapegoat %s. Good." % suspect.id)
		lines.append(say(n, "I knew it. I've thought so about %s for days." % suspect.name))
	else:
		w.dlog.think(n.id, "evil_learns", "Player suspects good NPC %s; evil encourages it." % suspect.id)
		lines.append(say(n, "Could be. I wouldn't put it past %s." % suspect.name))
	return {"lines": lines, "facts": []}
