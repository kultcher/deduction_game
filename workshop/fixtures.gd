## Additional bounded experiments, built from a legal scripted town. Optional
## developer causes are never passed to an assessment.
extends RefCounted
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Gifts = preload("res://sim/gifts.gd")
const KINDS = ["core", "movement", "poison", "revenant"]
const NAMES = ["692 · Reading chains", "Movement & soot", "Poison & recovery", "Revenant & restoration"]

static func configure(base: Dictionary, kind: String, native) -> Dictionary:
	base["fixture"] = kind
	var view: Dictionary = base.public_view
	view["fixture"] = kind
	if kind == "movement":
		view.day = 4
		view.scope += " Movement experiment: dawn 4, a third scripted attack, fixed public route/haunt hypotheses. No hidden cause is an assessment input."
		view["movement_experiment"] = {"version": 1, "subjects": [base.slots.demon, base.slots.warden],
			"haunt_visit": 0.7,
			"scenes": {"1": "docks", "2": "docks", "3": "square"},
			"gift_destinations": {},
			"note": "Fixture priors: evil = 1/3 hunting Demon + 2/3 minion (1/4 walks); good = ordinary/gift/secret mixture. Haunt persists across nights. Rates are hypotheses, not calibrated town prevalence."}
		view.people.filter(func(p): return p.id == base.slots.lamplighter)[0].alive = false
		view.movement_experiment.gift_destinations[base.slots.demon] = {"1": [], "2": [], "3": ["docks"]}
		view.movement_experiment.gift_destinations[base.slots.warden] = {"1": C.BLOCKS.keys(), "2": C.BLOCKS.keys(), "3": ["square", "market", "hill"]}
		base.timeline.append({"night": 3, "attack": base.slots.lamplighter, "survived": false})
		for night in [2, 3]:
			var block: String = view.movement_experiment.scenes[str(night)]
			var background = {"square": 0.25, "market": 0.25, "docks": 0.25, "hill": 0.25}
			_add(view, {"id": "soot%d" % night, "kind": "trace", "subject": base.slots.demon, "night": night, "block": block,
				"data": {"scene_block": block, "material": "market", "passers": ["hill"], "background": background},
				"text": "Market soot at the night %d murder scene. An eligible passer can leave misleading evening material." % night})
			_add(view, {"id": "evening%d" % night, "kind": "evening", "subject": base.slots.demon, "night": night, "block": "market",
				"text": "You saw Constance at the Market bakery on evening %d." % night})
		_add(view, {"id": "vigil3", "kind": "sighting", "subject": base.slots.demon, "night": 3, "block": "square", "text": "You saw Constance on the Square on night 3."})
		_add(view, {"id": "coverage3", "kind": "coverage", "subject": base.slots.warden, "night": 3, "block": "square", "data": {"seen": false, "detection": 1.0}, "text": "You watched the Square all night 3 and did not see Nisha. This does not cover other blocks."})
		_add(view, {"id": "secret_claim", "kind": "secret_claim", "source": base.slots.demon, "subject": base.slots.demon, "night": -1, "role": "secret", "applies": {"from": 1, "through": 3}, "text": "Constance claims a private errand could explain leaving home."})
		_add(view, {"id": "item3", "kind": "item", "subject": base.slots.demon, "night": 3, "block": "square", "data": {"locations_in_block": C.LOCATIONS.values().filter(func(l): return l.block == "square").size()}, "text": "A personal item belonging to Constance was found at a searched Square location after night 3. This is a dropped item, not the crime-scene material."})
	elif kind == "poison":
		view.scope += " Poison experiment: one possible Night 1-to-Night 2 impairment interval, supported or unsupported explanations and a Day 3 recovered reading."
		var poisoner = native.by_id[base.slots.scion]
		poisoner.role = "poisoner"
		base.truth.filter(func(p): return p.id == poisoner.id)[0].role = "poisoner"
		base.slots["poisoner"] = poisoner.id
		var dowser = native.by_id[base.slots.dowser]
		view["chronology"] = {"epochs": {view.alignment_epoch: 15}, "poison_windows": {"night1": {"subject": dowser.id, "from": 7, "until": 11}}, "reserved_events": ["scion_succession"]}
		for card in view.cards:
			if card.id == "watch1":
				card.data.seen.append(poisoner.id)
				card.text = Gifts.short_text(card.role, card.data, native.by_id[card.source].name, func(id): return native.by_id[id].name)
			elif card.id == "lamp1":
				card.data.count += 1
				card.text = Gifts.short_text(card.role, card.data, native.by_id[card.source].name, func(id): return native.by_id[id].name)
		base.timeline[0].walkers.append({"id": poisoner.id, "block": "docks", "path": C.route(poisoner.home_block, "docks"), "why": "poisoning"})
		native.day = 2
		native.phase = C.AFTERNOON
		for n in native.npcs:
			n.loc = "home"
		for role in ["warden", "scion", "rumormonger", "revenant", "dowser"]:
			native.by_id[base.slots[role]].loc = "bakery"
		dowser.poisoned = true
		for attempt in range(200):
			dowser.dowsed_day = -1
			native._day_gifts()
			if dowser.info_log[-1].data.count < 2:
				break
		var bad: Dictionary = view.cards.filter(func(c): return c.id == "dowse")[0]
		bad.data = dowser.info_log[-1].data.duplicate(true)
		bad.text = Gifts.short_text("dowser", bad.data, dowser.name, func(id): return native.by_id[id].name)
		var relay = bad.duplicate(true)
		relay.id = "dowse_relay"
		relay.fact_id = "retelling:poisoned-dowse"
		relay["accuracy_origin"] = bad.fact_id
		relay.reported_at = {"day": 2, "phase": "evening"}
		relay.learned_at = relay.reported_at.duplicate(true)
		view.cards.append(relay)
		dowser.poisoned = false
		native.day = 3
		for attempt in range(200):
			dowser.dowsed_day = -1
			native._day_gifts()
			if dowser.info_log[-1].data.count == 3:
				break
		var recovered = bad.duplicate(true)
		recovered.id = "dowse_recovered"
		recovered.fact_id = "recovered-dowse"
		recovered.event_ids = [recovered.fact_id]
		recovered.provenance.origin = recovered.id
		recovered.acquired_day = 3
		recovered.observed_at = {"day": 3, "phase": "afternoon"}
		recovered.data = dowser.info_log[-1].data.duplicate(true)
		recovered.text = Gifts.short_text("dowser", recovered.data, dowser.name, func(id): return native.by_id[id].name)
		recovered.reported_at = {"day": 3, "phase": "evening"}
		recovered.learned_at = recovered.reported_at.duplicate(true)
		view.cards.append(recovered)
		_add(view, {"id": "vial1", "kind": "fault_evidence", "subject": dowser.id, "night": 1, "window": "night1", "text": "A witness saw a vial left at Fenwick's door on night 1. This supports possible poisoning, not certainty."})
		for juror in base.jury:
			for card in [relay, recovered]:
				juror.reading_reliability[card.fact_id] = 1.0
	elif kind == "revenant":
		var rv = native.by_id[base.slots.revenant]
		var merrin = native.by_id[base.slots.rumormonger]
		var voters: Array = [merrin.id, base.slots.warden, base.slots.nightwatch]
		native.day = 3
		native.phase = C.EVENING
		rv.alive = false
		native.totem = {"loc": "bakery", "day": 3, "owner": rv.id}
		# Exercise the real eligibility/turn/restoration paths. Seed until this fixture
		# chooses Merrin; the public model still considers every eligible voter.
		for attempt in range(100):
			native.rng.seed = attempt
			if native.pick(voters) == merrin.id:
				native.rng.seed = attempt
				break
		native._revenant_curse(rv, {"yes": voters})
		base.timeline.append({"day": 3, "curse_victim": native.curse.get("victim", ""), "executed": rv.id})
		merrin.shadow = Mind._make_shadow(native, merrin)
		Evil.add_intel(native, merrin, "teammate", base.slots.demon, 0.0, "learned while converted")
		base.timeline[-1]["evil_intel_count"] = merrin.intel.size()
		merrin.info_log.append({"day": 4, "role": "rumormonger", "data": {"pair": [base.slots.nightwatch, base.slots.veteran], "secret": "marked"}, "fake": true, "shared": false})
		native.day = 5
		native.phase = C.MORNING
		var freed: String = native.find_totem("bakery").get("freed", "")
		base.timeline.append({"day": 5, "freed": freed, "intel_after": merrin.intel.duplicate(true), "fake_disowned": merrin.info_log[-1].get("disowned", false)})
		view.day = 5
		view.scope = "Revenant experiment: public Day 3 activation and Day 5 restoration. Converted identity is unknown to the assessor; epochs are explicit. Scion succession is reserved but unsupported."
		view.history.append("Day 3: a good surviving yes-voter was cursed; identity was not announced.")
		view.history.append("Dawn 5: the hidden totem was destroyed and the curse ended.")
		view.alignment_epoch = "after restoration"
		view.people.filter(func(p): return p.id == rv.id)[0].alive = false
		view["chronology"] = {"epochs": {"before curse": 13, "during curse": 17, "after restoration": 21},
			"curse": {"from": 14, "until": 20, "executed": rv.id, "yes_voters": voters, "alive": view.people.filter(func(p): return p.alive).map(func(p): return p.id)},
			"withdrawals": [{"card": "totem_found", "reports": ["rumor_retold"]}], "reserved_events": ["scion_succession"]}
		_add(view, {"id": "curse_warning", "kind": "event", "event": "curse", "subject": rv.id, "night": 3, "observed_at": {"day": 3, "phase": "evening"}, "data": {"count": 1, "eligible": voters}, "text": "Day 3: the hanged Revenant's curse activated. One surviving good yes-voter became evil: Merrin, Nisha or Odette."})
		_add(view, {"id": "totem_found", "kind": "event", "event": "restoration", "subject": rv.id, "night": 5, "observed_at": {"day": 5, "phase": "morning"}, "text": "Day 5: the totem was found and destroyed. The curse ended. Statements withdrawn by the restored speaker must be considered separately from earlier readings."})
		var retold: Dictionary = view.cards.filter(func(c): return c.id == "rumor")[0].duplicate(true)
		retold.id = "rumor_retold"
		retold.fact_id = "retold:rumor"
		retold.acquired_day = 4
		retold.event_ids = ["report:%s:rumor" % merrin.id, "statement:rumor_retold"]
		retold.provenance.origin = retold.id
		retold.provenance["references"] = "rumor"
		retold.data.pair = [base.slots.nightwatch, base.slots.veteran]
		retold.reported_at = {"day": 4, "phase": "day"}
		retold.learned_at = retold.reported_at.duplicate(true)
		retold.text = "Day 4: Merrin retells his old Rumormonger result while the curse is active. After restoration he withdraws this retelling; the earlier report remains."
		view.cards.append(retold)
		for juror in base.jury:
			juror.knowledge["known_events"] = ["curse_warning", "totem_found"]
			juror.knowledge["good_epoch"] = "before curse"
			juror.reading_reliability[retold.fact_id] = 1.0
	var actors = {"Constance": "demon", "Nisha": "warden", "Merrin": "rumormonger", "Odette": "nightwatch", "Fenwick": "dowser"}
	for card in view.cards:
		if not card.get("fact_id", "").begins_with("fixture:") and card.id != "rumor_retold":
			continue
		for name in actors:
			card.text = card.text.replace(name, "<actor_" + actors[name] + ">")
		for role in actors.values():
			card.text = card.text.replace("<actor_" + role + ">", native.by_id[base.slots[role]].name)
	return base

static func _add(view: Dictionary, card: Dictionary) -> void:
	card["source"] = card.get("source", "player")
	card["data"] = card.get("data", {})
	var after_night: bool = card.kind in ["trace", "item", "coverage"]
	card["incident_at"] = {"day": maxi(card.night, 1), "phase": "night"}
	card["observed_at"] = card.get("observed_at", {"day": maxi(card.night + int(after_night), 1), "phase": "morning" if after_night else ("evening" if card.kind == "evening" else "night")})
	card["acquired_day"] = card.observed_at.day
	card["reported_at"] = card.observed_at.duplicate(true)
	card["learned_at"] = card.reported_at.duplicate(true)
	card["fact_id"] = "fixture:" + card.id
	card["event_ids"] = ["%s:%s:%d" % [card.kind, card.subject, card.night]]
	card["provenance"] = {"source": card.source, "channel": "firsthand" if card.source == "player" else "testimony", "origin": card.id}
	view.cards.append(card)
