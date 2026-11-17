## Finding real games for test fixtures, instead of naming one seed.
##
## A test that needs "a game where an evil planter's fake sighting of a good person reached
## them" used to name the seed where that happened (100034). Every change to play moved
## those games, and the fixtures broke (Nov 13, Nov 14, Nov 16). These helpers search a
## range of seeds for the scenario itself, so a test keeps testing the same thing however
## play changes. Each returns {} if no seed in the range has it; the caller fails loudly.
##
## Games are played passively (decline, wait, sleep, vote no) to the day-`day` meeting. The
## search plays them on the earlier belief model, which is several times faster (as
## test_connections_pairings' _known_game does), and restores the switch for the caller's
## reading of the game it found.
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
	var Connections = preload("res://workshop/connections.gd")
	var was: bool = Connections.enabled
	Connections.enabled = false
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
	Connections.enabled = was
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
## seen leaving home), or any.
static func framed_sighting(day: int, need_bystander: bool = false, how: String = "") -> Dictionary:
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
			var about = func(c): return str(c.get("kind", "")) == "sighting" and str(c.get("source", "")) == sighter.id and subject.id in c.get("subjects", [c.get("subject", "")]) and not c.has("relay_source")
			if held_cards(subject, about).is_empty():
				continue
			var bystander: String = ""
			for m in w.living_good():
				if m != subject and not held_cards(m, about).is_empty():
					bystander = m.id
					break
			if need_bystander and bystander == "":
				continue
			return {"sighter": sighter.id, "subject": subject.id, "bystander": bystander}
		return {})


## A good person's honest sighting of a real Sleepwalker, out on a night they believe they
## spent at home, that the Sleepwalker holds: {"sighter", "subject"}.
static func sleepwalker_sighting(day: int) -> Dictionary:
	return search(day, func(g):
		var w = g.w
		for s in w.living_good():
			if str(s.secret_mod) != "sleepwalker":
				continue
			for c in held_cards(s, func(c): return str(c.get("kind", "")) == "sighting" and s.id in c.get("subjects", [c.get("subject", "")]) and not c.has("relay_source")):
				var sighter = w.by_id.get(str(c.get("source", "")))
				if sighter != null and sighter.alive and not sighter.is_evil() and was_out(w, s, _night_of(c)):
					return {"sighter": sighter.id, "subject": s.id}
		return {})


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
