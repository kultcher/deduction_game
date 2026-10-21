## Frozen, scripted Day 3 world. Reports come from the live simulation's gift routines.
## Only `public_view` is passed to the interpreter; truth is an optional dev inspector.
extends RefCounted

const World = preload("res://sim/world.gd")
const NPC = preload("res://sim/npc.gd")
const C = preload("res://sim/content.gd")
const Gifts = preload("res://sim/gifts.gd")

const IDS = ["constance", "bart", "nisha", "odette", "agnes", "hollis", "merrin", "lian", "greta", "fenwick"]
const ROLES = ["demon", "surveyor", "warden", "nightwatch", "lamplighter", "scion", "rumormonger", "revenant", "veteran", "dowser"]
const HOMES = ["hill", "hill", "square", "square", "square", "market", "market", "docks", "docks", "docks"]

static func generate(seed_value: int = 692) -> Dictionary:
	var w = World.new()
	w.seed_value = seed_value
	w.rng.seed = seed_value
	w.n_npcs = 10
	w.detailed_logging = false
	var ids = IDS.duplicate()
	if seed_value != 692:
		ids = w.shuffled(ids)
	var slots = {}
	var people: Array = []
	for i in range(ids.size()):
		var cast: Dictionary = C.CAST.filter(func(c): return c.id == ids[i])[0]
		var n = NPC.new()
		n.id = ids[i]
		n.name = cast.name
		n.role = ROLES[i]
		n.claimed_role = n.role if i not in [0, 5, 7] else ["medium", "martyr", "psychologist"][[0, 5, 7].find(i)]
		n.alignment = "evil" if i in [0, 5, 7] else "good"
		n.home_block = HOMES[i]
		n.loc = "home"
		n.secret_mod = "marked" if i == 2 else ""
		for t in cast.traits:
			n.traits[t] = cast.traits[t][0]
		w.npcs.append(n)
		w.by_id[n.id] = n
		slots[n.role] = n.id
		people.append({"id": n.id, "name": n.name, "home": n.home_block, "claim": n.claimed_role, "alive": true})
	w.demon_id = ids[0]
	w.first_demon_id = ids[0]
	w.minion_ids = [ids[5], ids[7]]
	w.minion_id = ids[5]
	w.evil_plan = {"bluffs": {ids[0]: "medium", ids[5]: "martyr", ids[7]: "psychologist"}}
	var cards: Array = []
	w.day = 0
	w.phase = C.NIGHT
	# Rejection-sample actual results to retain the deliberately ambiguous teaching fixture.
	# Marked registration is per reading, not permanent evil alignment.
	var survey = w.by_id[slots.surveyor]
	for attempt in range(200):
		w._receive_info(survey, "")
		if survey.info_log[-1].data.count == 4:
			break
	_add_report(cards, survey, "survey", 1)
	var rumor = w.by_id[slots.rumormonger]
	for attempt in range(200):
		w._receive_info(rumor, "")
		if ids[0] in rumor.info_log[-1].data.pair and ids[2] in rumor.info_log[-1].data.pair:
			break
	_add_report(cards, rumor, "rumor", 1)
	# The Dowser visits the Market on day 2 with exactly this group present.
	w.day = 2
	w.phase = C.AFTERNOON
	for n in w.npcs:
		n.loc = "home"
	var market_location: String = C.LOCATIONS.keys().filter(func(l): return C.loc_block(l) == "market")[0]
	for i in [2, 5, 6, 7, 9]:
		w.npcs[i].loc = market_location
	var dowser = w.by_id[slots.dowser]
	for attempt in range(200):
		dowser.dowsed_day = -1
		w._day_gifts()
		if dowser.info_log[-1].data.count == 3:
			break
	_add_report(cards, dowser, "dowse", 2)
	# Two scripted, legal nights. The Veteran survives the first attack, dies on the next.
	# Night Watch / Lamplighter still compute their own observations from these routes.
	var timeline: Array = []
	for night in [1, 2]:
		w.day = night
		w.phase = C.NIGHT
		w.night_walkers = []
		for role in ["demon", "nightwatch", "lamplighter", "warden"]:
			var n = w.by_id[slots[role]]
			var destination = "hill" if role == "warden" and night == 1 else "docks"
			var path: Array = C.BLOCKS.keys() if role == "lamplighter" else [n.home_block, destination]
			w.night_walkers.append({"id": n.id, "block": destination, "path": path, "why": role})
		var watch = w.by_id[slots.nightwatch]
		var lamp = w.by_id[slots.lamplighter]
		w._receive_info(watch, "docks")
		w._receive_info(lamp, "", "", lamp)
		_add_report(cards, watch, "watch%d" % night, night + 1)
		_add_report(cards, lamp, "lamp%d" % night, night + 1)
		timeline.append({"night": night, "walkers": w.night_walkers.duplicate(true), "attack": ids[8], "survived": night == 1})
	# Additional statements are testimony, not facts endorsed by the validator.
	cards.append({"id": "alibi1", "kind": "alibi", "source": ids[0], "subject": ids[0], "night": 1,
		"observed_at": {"day": 1, "phase": "night"}, "acquired_day": 2, "text": "%s says they stayed home on night 1." % w.npcs[0].name})
	cards.append({"id": "gift_claim", "kind": "claim", "source": ids[0], "subject": ids[0], "role": "medium", "night": -1,
		"observed_at": {"day": 1, "phase": "day"}, "acquired_day": 1, "text": "%s claims Medium: visiting the dead could explain night work." % w.npcs[0].name})
	cards.append({"id": "warden_claim", "kind": "claim", "source": ids[2], "subject": ids[2], "role": "warden", "night": -1,
		"observed_at": {"day": 1, "phase": "day"}, "acquired_day": 1, "text": "%s claims Warden: guarding a home could explain night work. This fixture's quiet night was not a confirmed Warden save." % w.npcs[2].name})
	cards.append({"id": "vigil1", "kind": "sighting", "source": "player", "subject": ids[0], "night": 1, "block": "docks",
		"observed_at": {"day": 1, "phase": "night"}, "acquired_day": 2, "text": "You also saw %s at the Docks on night 1 (the same outing as the Watch report)." % w.npcs[0].name})
	# Reporting an attributed gift result also conveys an implicit role assertion.
	# Keep it separately citable, linked to its origin, rather than a second witness.
	var claims: Array = []
	for card in cards:
		if card.kind != "report":
			continue
		var claim_id: String = "claim_" + card.role
		card["claim_id"] = claim_id
		if claims.any(func(c): return c.id == claim_id):
			continue
		claims.append({"id": claim_id, "kind": "claim", "source": card.source, "subject": card.source,
			"role": card.role, "night": -1, "observed_at": {"day": card.acquired_day, "phase": "day"},
			"acquired_day": card.acquired_day, "implicit": true, "origin": card.id,
			"text": "%s implicitly claims %s by reporting this gift result. This does not establish the result's accuracy." % [w.by_id[card.source].name, C.role_name(card.role)]})
	cards.append_array(claims)
	for card in cards:
		card["fact_id"] = "report:%s:%s" % [card.source, card.id] if card.kind != "claim" else "claim:%s:%s" % [card.subject, card.role]
		card["reported_at"] = {"day": card.acquired_day, "phase": "day"}
		card["learned_at"] = card.reported_at.duplicate(true)
		card["provenance"] = {"source": card.source, "channel": "firsthand" if card.source == "player" else "testimony", "origin": card.get("origin", card.id)}
		card["event_ids"] = ["outing:%s:%s" % [card.subject, card.night]] if card.kind in ["sighting", "alibi"] else [card.fact_id]
		if card.kind == "report" and card.role == "nightwatch":
			card.event_ids = card.data.seen.map(func(person): return "outing:%s:%s" % [person, card.night])
		if card.kind == "claim":
			card["applies"] = {"from": 0, "through": 3}
	people[8].alive = false
	w.npcs[8].alive = false
	w.npcs[8].vet_used = true
	w.npcs[8].death_day = 3
	w.npcs[8].death_cause = "demon"
	w.day = 3
	w.phase = C.MORNING
	var public_view = {"seed": seed_value, "day": 3, "people": people, "cards": cards, "evil_count": 3,
		"secret": "marked", "secret_count": 1, "alignment_epoch": "opening through day 3",
		"history": ["Night 1: the Veteran's protection stops an attack.", "Dawn 3: %s is found dead after a second attack." % w.npcs[8].name],
		"scope": "Ten people, three original evil, one good Marked. No alignment changes in this fixture. Reports may be lies or impaired; accepting a report assumes its source was good, held the claimed gift and was healthy when it was made."}
	var truth: Array = []
	for n in w.npcs:
		truth.append({"id": n.id, "role": n.role, "alignment": n.alignment, "secret": n.secret_mod})
	return {"public_view": public_view, "truth": truth, "timeline": timeline, "slots": slots, "jury": _jury(w, slots, cards)}

static func _add_report(cards: Array, n, id: String, acquired: int) -> void:
	var e: Dictionary = n.info_log[-1]
	cards.append({"id": id, "kind": "report", "source": n.id, "role": n.role, "data": e.data.duplicate(true),
		"night": e.day if not e.has("phase") else -1,
		"observed_at": {"day": e.day, "phase": "day" if e.has("phase") else "night"}, "acquired_day": acquired,
		"text": Gifts.short_text(n.role, e.data, n.name, func(pid): return n.name if pid == n.id else C.CAST.filter(func(c): return c.id == pid)[0].name)})

static func _jury(w, slots: Dictionary, cards: Array) -> Array:
	var result: Array = []
	var roles = ["surveyor", "rumormonger", "dowser", "nightwatch"]
	var presets = ["Trusts you", "Distrusts you", "Trusts the accused", "Suspects a rival"]
	for i in range(4):
		var n = w.by_id[slots[roles[i]]]
		var suspicion = {}
		var trust = {}
		for other in w.npcs:
			suspicion[other.id] = 0.1
			trust[other.id] = 0.5
		suspicion[n.id] = 0.0
		trust[n.id] = 1.0
		if i == 2:
			trust[slots.demon] = 0.9
		if i == 3:
			suspicion[slots.warden] = 0.65
		var own: Array = cards.filter(func(c): return c.kind == "report" and c.source == n.id).map(func(c): return c.id)
		var reading_reliability = {}
		for card in cards:
			if card.kind == "report":
				reading_reliability[card.fact_id] = 1.0
		result.append({"id": n.id, "name": n.name, "preset": presets[i], "trust": [0.85, 0.2, 0.5, 0.5][i],
			"confidence": n.traits.confidence, "npc_trust": trust, "suspicion": suspicion,
			"insight": n.traits.insight, "reasoning_mode": "full", "confidence_mode": "scale", "theories": {},
			"reading_reliability": reading_reliability,
			"knowledge": {"self": n.id, "good": [n.id], "own_reports": own,
				"own_outings": {"1": roles[i] == "nightwatch", "2": roles[i] == "nightwatch"}}, "ledger": {}, "case_memory": {}})
	return result
