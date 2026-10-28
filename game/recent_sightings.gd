## Extra, person-specific observations attached to an existing opinion answer.
## Reads the speaker's memory, never the target's real history, and costs no extra question.
extends RefCounted

const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")

static func append_to(w, speaker, target, reply: Dictionary, board: Array) -> void:
	if speaker.silenced or (speaker.is_evil() and Evil.is_teammate(w, speaker, target.id)):
		return
	var limit = Mind._gossip_share(w, speaker, "share_person_sightings")
	if limit == 0:
		return
	var candidates: Array = speaker.beliefs.filter(func(b):
		return b.get("kind", "") == "saw" and b.get("who", "") == target.id and b.get("phase", -1) != C.NIGHT)
	# Night information is optional and only accompanies an already disclosed walking gift.
	if (speaker.claim_public or speaker.max_tier >= 3) and C.ROLES.get(speaker.claimed_role, {}).get("night_walk", false):
		candidates.append_array(_night_candidates(w, speaker, target, board))
	var now: int = w.day * 4 + w.phase
	candidates = candidates.filter(func(b):
		var age: int = now - (int(b.get("day", -1)) * 4 + int(b.get("phase", -1)))
		return age >= 0 and age < 3 and not Mind.sighting_is_here(w, b, target.id))
	candidates.sort_custom(func(a, b): return a["day"] * 4 + a["phase"] > b["day"] * 4 + b["phase"])
	var groups: Array = []
	var frames = {}
	for b in candidates:
		var key: int = b["day"] * 4 + b["phase"]
		if frames.has(key):
			continue
		frames[key] = true
		if b["phase"] == C.NIGHT:
			var report = Mind.sighting_report(w, speaker, b, b["day"])
			Mind._add_observation(groups, report.observation)
			reply["facts"].append(report["fact"])
		else:
			var place: String = w.loc_name(b["loc"]) if b.get("loc", "") != "" else C.block_name(b["block"])
			var when_s: String = "%s %s" % ["this" if b["day"] == w.day else "yesterday", C.PHASES[b["phase"]].to_lower()]
			Mind._add_observation(groups, {"kind": "sighting", "scene": Mind._observation_scene(speaker, b, b.day),
				"subject": target.name, "before": "I saw ", "after": " at %s %s." % [place, when_s]})
			reply["facts"].append({"kind": "sighting", "subject": [target.id], "block": b["block"], "loc": b.get("loc", ""),
				"day": b["day"], "phase": b["phase"], "source": speaker.id,
				"text": "%s saw %s on %s, day %d %s." % [speaker.name, target.name, C.block_name(b["block"]), b["day"], C.PHASES[b["phase"]]]})
		if frames.size() >= limit:
			break
	reply.lines.append_array(Mind._observation_lines(speaker, groups, "player", "answer", true))

static func _night_candidates(w, speaker, target, board: Array) -> Array:
	var result: Array = []
	# The window can cross at most one night. Do not invent new bluff material here.
	var nd: int = w.day - 1
	if speaker.claimed_role == "nightwatch":
		for e in speaker.info_log:
			if e.get("role", "") == "nightwatch" and e.get("day", -1) == nd and not Mind.reading_disclosed(speaker, e):
				return []
	if speaker.is_evil():
		if speaker.claimed_role == "nightwatch":
			var story = Mind._fake_watch_entry(speaker, nd)
			if not story.is_empty() and target.id in story["data"].get("seen", []):
				result.append({"kind": "saw", "who": target.id, "block": story["data"]["block"], "day": nd, "phase": C.NIGHT, "how": "street"})
		else:
			# Other bluffs can repeat a sighting they have already committed to.
			for card in board:
				if card.get("source", "") == speaker.id and card.get("kind", "") == "sighting" and card.get("subject", []) == [target.id] \
						and card.get("day", -1) == nd and card.get("phase", -1) == C.NIGHT:
					result.append({"kind": "saw", "who": target.id, "block": card["block"], "day": nd, "phase": C.NIGHT, "how": card.get("how", "street")})
	elif speaker.role == speaker.claimed_role:
		for b in speaker.beliefs:
			if b.get("kind", "") != "saw" or b.get("who", "") != target.id or b.get("phase", -1) != C.NIGHT or b.get("day", -1) != nd:
				continue
			var where: String = speaker.history.get(w.time_key(nd, C.NIGHT), "home:" + speaker.home_block)
			# Do not expose secret walks or a Sleepwalker's unconscious observations.
			if speaker.secret_mod == "sleepwalker" or (b.get("how", "street") != "window" and not where.begins_with("night:")):
				continue
			result.append(b)
	return result.filter(func(b): return _fits_account(speaker, b, board))

static func _fits_account(speaker, belief: Dictionary, board: Array) -> bool:
	if belief.get("how", "street") == "window" and belief["block"] != speaker.home_block:
		return false
	for card in board:
		if card.get("source", "") != speaker.id or card.get("day", -1) != belief["day"] or card.get("phase", -1) != C.NIGHT \
				or not speaker.id in card.get("subject", []):
			continue
		if card.get("kind", "") == "refusal":
			return false
		if card.get("kind", "") == "alibi" and card.get("home", false) and belief.get("how", "street") != "window":
			return false
		if card.get("kind", "") in ["alibi", "sighting", "secret"] and card.get("block", "") != "" and card["block"] != belief["block"]:
			return false
	return true
