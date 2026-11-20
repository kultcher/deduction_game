## Finding real games for test fixtures, instead of naming one seed.
##
## A test that needs "a game where an evil planter's fake sighting of a good person reached
## them" used to name the seed where that happened (100034). Every change to play moved
## those games, and the fixtures broke (Nov 13, Nov 14, Nov 16). These helpers search a
## range of seeds for the scenario itself, so a test keeps testing the same thing however
## play changes. Each returns {} if no seed in the range has it; the caller fails loudly.
##
## Games are played passively (decline, wait, sleep, vote no) to the day-`day` meeting.
## Each game is played on the connections model, like play itself.
extends RefCounted

const Game = preload("res://game/game.gd")

const SEEDS_FROM: int = 100000
const SEEDS_COUNT: int = 60


## A passive game at its day-`day` meeting, or null if it ended first.
static func play_to_meeting(seed_v: int, day: int, npcs: int = 7):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, npcs)
	var guard := 0
	while g.state != "over" and guard < 600 and not (g.state == "meeting" and g.w.day >= day):
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	return g if g.state == "meeting" and g.w.day >= day else null


## The first seed whose game, at the day-`day` meeting, `pick.call(g)` finds the scenario
## in: {"seed", "g", ...what pick returned}, or {}.
static func search(day: int, pick: Callable, npcs: int = 7, from: int = SEEDS_FROM, count: int = SEEDS_COUNT) -> Dictionary:
	var found: Dictionary = {}
	for seed_v in range(from, from + count):
		var g = play_to_meeting(seed_v, day, npcs)
		if g == null:
			continue
		found = pick.call(g)
		if not found.is_empty():
			found["seed"] = seed_v
			found["g"] = g
			break
	return found


## The cards a mind holds (its ledger's workshop cards) that `keep` accepts.
static func held_cards(n, keep: Callable) -> Array:
	var out: Array = []
	for eid in n.ledger:
		var card = n.ledger[eid].get("meta", {}).get("workshop_card", {})
		if card is Dictionary and not card.is_empty() and keep.call(card):
			out.append(card)
	return out


## The readings a mind holds (its ledger's workshop receipts, by content) that `keep` accepts.
static func held_readings(n, keep: Callable) -> Array:
	var out: Array = []
	for eid in n.ledger:
		var receipts = n.ledger[eid].get("meta", {}).get("workshop_receipts", {})
		if not receipts is Dictionary:
			continue
		for k in receipts:
			var content = receipts[k].get("content", {}) if receipts[k] is Dictionary else {}
			if content is Dictionary and not content.is_empty() and keep.call(content):
				out.append(content)
	return out


static func _night_of(card: Dictionary) -> int:
	var at = card.get("observed_at", {})
	return int(at.get("day", -1)) if at is Dictionary and str(at.get("phase", "")) == "night" else int(card.get("night", -1))


## Where `n` really was on night `nd`: true if out.
static func was_out(w, n, nd: int) -> bool:
	return str(n.history.get(w.time_key(nd, 3), "home:")).begins_with("night:")


## An evil planter's fake sighting of a good person that the framed person holds:
## {"sighter", "subject", "bystander"} (bystander: another living good person who holds
## it too, or "" when need_bystander is false and there's none).
## `how`: only fake sightings told that way ("street": seen out in the street; "window":
## seen leaving home), or any. `bystander_doubt`: a bystander must hold the sighter at least
## this suspect, so it isn't one who already clears the sighter outright (it would believe
## the sighting, rightly by its own lights).
## `subject_trust`: the subject must trust the sighter at least this much, so it hears the
## sighting nearly in full (an unshared sighting is weighed by the hearer's trust in its teller).
## How far framed_sighting searches: a frame away from home that a bystander weighs against
## the subject's own home alibi is rarer than the other cases (Nov 20), so 3× the usual.
const FRAMED_SEEDS: int = 3 * SEEDS_COUNT

static func framed_sighting(day: int, need_bystander: bool = false, how: String = "", bystander_doubt: float = 0.0, from: int = SEEDS_FROM, subject_trust: float = 0.0, bystander_alibi: bool = true) -> Dictionary:
	return search(day, func(g):
		var w = g.w
		for key in w.evil_plan.get("fake_sightings", {}):
			var fs = w.evil_plan.fake_sightings[key]
			if not fs is Dictionary:
				continue
			var sighter = w.by_id.get(str(key).split(":")[0])
			var subject = w.by_id.get(str(fs.get("who", "")))
			if sighter == null or subject == null or not sighter.alive or not sighter.is_evil() or not subject.alive or subject.is_evil():
				continue
			if was_out(w, subject, int(fs.get("day", -1))) or (how != "" and str(fs.get("how", "")) != how):
				continue
			if float(subject.npc_trust.get(sighter.id, 0.5)) < subject_trust:
				continue
			var about = func(c): return str(c.get("kind", "")) == "sighting" and str(c.get("source", "")) == sighter.id and subject.id in c.get("subjects", [c.get("subject", "")]) and not c.has("relay_source")
			# A real frame puts them away from home: a sighting on their own block ("seen
			# leaving home") barely clashes with having stayed in (seed 100009 under #327).
			if held_cards(subject, about).is_empty() or held_cards(subject, about).all(func(c): return str(c.get("block", c.get("content", {}).get("block", ""))) == str(subject.home_block)):
				continue
			# A bystander must also hold the subject's own "I was home" for that night, so the
			# sighter contest has the subject's account to weigh the sighting against (Lantern,
			# Nov 20). With `bystander_alibi` false the caller hands it to them instead: a frame
			# away from home that gossip has also brought the alibi to is rare (none in 60 seeds
			# after the drop removal, Nov 20).
			var night: int = int(fs.get("day", -1))
			var home_alibi = func(c):
				var ct: Dictionary = c.get("content", {}) if c.get("content") is Dictionary else {}
				var at = c.get("observed_at", ct.get("observed_at", {}))
				return str(c.get("kind", "")) == "alibi" and str(c.get("source", ct.get("source", ""))) == subject.id \
					and bool(c.get("home", ct.get("home", false))) and at is Dictionary and int(at.get("day", -1)) == night
			var bystander: String = ""
			for m in w.living_good():
				if m != subject and not held_cards(m, about).is_empty() and (not bystander_alibi or not held_cards(m, home_alibi).is_empty()) and float(m.suspicion.get(sighter.id, 0.0)) >= bystander_doubt:
					bystander = m.id
					break
			if need_bystander and bystander == "":
				continue
			return {"sighter": sighter.id, "subject": subject.id, "bystander": bystander, "night": night}
		return {}, 7, from, SEEDS_FROM + FRAMED_SEEDS - from)


## A good person's honest sighting of a real Sleepwalker, out on a night they believe they
## spent at home, that the Sleepwalker holds: {"sighter", "subject"}.
## A rare case (a Sleepwalker must be dealt and seen), so it searches further than the rest.
static func sleepwalker_sighting(day: int, count: int = 3 * SEEDS_COUNT) -> Dictionary:
	return search(day, func(g):
		var w = g.w
		for s in w.living_good():
			if str(s.secret_mod) != "sleepwalker":
				continue
			for c in held_cards(s, func(c): return str(c.get("kind", "")) == "sighting" and s.id in c.get("subjects", [c.get("subject", "")]) and not c.has("relay_source")):
				var sighter = w.by_id.get(str(c.get("source", "")))
				if sighter != null and sighter.alive and not sighter.is_evil() and was_out(w, s, _night_of(c)):
					return {"sighter": sighter.id, "subject": s.id}
		return {}, 7, SEEDS_FROM, count)


## A Medium's relayed sighting held by a living good listener, from a relayer that
## `relayer_ok` accepts: {"listener", "teller"}. `about_listener`: the relayed sighting names
## the listener, out on a night they were home (an invented relay of them).
static func relay(day: int, relayer_ok: Callable, about_listener: bool = false, from: int = SEEDS_FROM) -> Dictionary:
	return search(day, func(g):
		var w = g.w
		for l in w.living_good():
			var relays: Array = held_readings(l, func(c): return str(c.get("role", "")) == "medium" and c.get("data", {}) is Dictionary and str(c.data.get("item", {}).get("type", "")) == "sighting")
			for c in relays:
				var teller = w.by_id.get(str(c.get("source", "")))
				if teller == null or teller == l or not teller.alive or not relayer_ok.call(teller):
					continue
				var item: Dictionary = c.data.item
				if about_listener and not (str(item.get("who", "")) == l.id and not was_out(w, l, int(item.get("night", -1)))):
					continue
				return {"listener": l.id, "teller": teller.id}
		return {}, 7, from)


## What a teller's Medium relays do to the listener's chance of the teller being evil, under
## connections: {"with", "without"}, the teller's chance with every held card, and with the
## cards the teller relayed left out. Both from one refresh's own inputs (the jury's
## weigher), so the difference is the relays' alone. {} if the listener has no plan.
## "firsthand": the teller's chance with the relays recast as the teller's own sightings (the
## same cards, told by them, no dead in between), so a relay can be held to what its relayer's
## own word would do.
static func relay_effect(g, listener_id: String, teller_id: String) -> Dictionary:
	var recast = func(c: Dictionary) -> void:
		c.erase("relay_source")
		c.erase("relay_role")
		c.erase("relay_observed_at")
		c["source"] = teller_id
	var eff: Dictionary = cards_effect(g, listener_id, [teller_id], func(c): return str(c.get("relay_source", "")) == teller_id, recast)
	if eff.is_empty():
		return {}
	return {"with": float(eff.with[teller_id]), "without": float(eff.without[teller_id]), "firsthand": float(eff.recast[teller_id]), "relayed": int(eff.dropped)}


## What some of a listener's held cards do, under connections: {"with": {id: chance},
## "without": {id: chance}, "dropped": how many cards `drop` picked}, each person in `ids`
## with every held card and with the cards `drop.call(card)` picks left out. Both from one
## refresh's own inputs (the jury's weigher), so the difference is those cards' alone, whatever
## else the game gave the listener. The model's kept answers are bypassed, so a switch a test
## flips between calls (LiveActivity.sighter_contests_enabled) takes effect. {} if the
## listener has no plan. With `recast`, also "recast": {id: chance} with every held card and
## `recast.call(card)` applied to a copy of each card `drop` picks.
## With `view_fn`, both refreshes read a copy of the view that `view_fn.call(view)` changed
## (say, the listener's own home nights read without sleepwalking doubt).
## Both refreshes start from an empty connections state, not the listener's stored one. That's
## fair for the comparison, which shares it, but the absolute chances can differ from the
## game's (Lantern on #397).
static func cards_effect(g, listener_id: String, ids: Array, drop: Callable, recast: Callable = Callable(), view_fn: Callable = Callable()) -> Dictionary:
	var Connections = preload("res://workshop/connections.gd")
	var Jury = preload("res://workshop/jury.gd")
	var Mind = preload("res://sim/mind.gd")
	var n = g.w.by_id.get(listener_id)
	if n == null:
		return {}
	var key: String = n.id + ":good"
	g._workshop_evaluations.erase(key)
	var was_defer: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (fixture)")
	g.w.defer_beliefs = was_defer
	var plan: Dictionary = g._workshop_plans.get(key, {})
	var cx: Dictionary = g._workshop_evaluations.get(key, {}).get("proposal", {}).get("connections", {})
	if plan.is_empty() or cx.is_empty():
		return {}
	var baseline: Dictionary = plan.prepared.listener
	var weigher: Dictionary = Jury._eval_listener(baseline, baseline.knowledge.get("own_reports", []))
	weigher["trust"] = baseline.get("trust", 0.5)
	weigher["insight"] = baseline.get("insight", 0.5)
	if baseline.has("player_credibility"):
		weigher["player_credibility"] = baseline.player_credibility
	var held: Array = []
	for it in cx.get("items", []):
		for id in it.cards:
			if id not in held:
				held.append(id)
	var view0: Dictionary = plan.prepared.view
	if view_fn.is_valid():
		view0 = view0.duplicate(true)
		view_fn.call(view0)
	var dropped: Array = view0.cards.filter(func(c): return drop.call(c)).map(func(c): return c.id)
	var state: Dictionary = {} if view_fn.is_valid() else baseline.get("connections", {})
	var was_cache: bool = Connections.cache_enabled
	Connections.cache_enabled = false
	preload("res://workshop/caches.gd").clear_all()
	var with_: Dictionary = Connections.refresh(view0, plan.prepared.case, weigher, held, state)
	var without: Dictionary = Connections.refresh(view0, plan.prepared.case, weigher, held.filter(func(id): return id not in dropped), state)
	var recast_r: Dictionary = {}
	if recast.is_valid():
		preload("res://workshop/caches.gd").clear_all()
		var view: Dictionary = plan.prepared.view.duplicate(true)
		for c in view.cards:
			if c.id in dropped:
				recast.call(c)
		recast_r = Connections.refresh(view, plan.prepared.case, weigher, held, state)
	Connections.cache_enabled = was_cache
	var out: Dictionary = {"with": {}, "without": {}, "dropped": dropped.filter(func(id): return id in held).size()}
	if recast.is_valid():
		out["recast"] = {}
	for id in ids:
		out.with[id] = float(with_.posterior.get(id, -1.0))
		out.without[id] = float(without.posterior.get(id, -1.0))
		if recast.is_valid():
			out.recast[id] = float(recast_r.posterior.get(id, -1.0))
	return out
