## The connections belief model, step 2 (workshop/connections.gd;
## docs/belief_model.md, "Phase 6 spec" section 3): the built-in pairings and how the
## demon-type declaration reads movement.
##
## - Cards that mean little alone are grouped with their partner: a night's movement cards,
##   an Augur reading with that day's sightings, a Psychologist reading with its statements,
##   a trace with the profile cards. Every held card sits in exactly one item.
## - No declaration: each night by itself. Walker: one always-on movement connection.
##   Hexer: each night by itself, plus the Hexer's day evidence as one always-on connection.
## - The two recent fixes work inside a night: a sighting against what the listener knows
##   of its own night counts against the sighter (#139), through the sighter contest (#135).
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")
const Tuning = preload("res://sim/tuning.gd")

const Game = preload("res://game/game.gd")
const GameMeeting = preload("res://game/game_meeting.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
const Connections = preload("res://workshop/connections.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const Caches = preload("res://workshop/caches.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_grouping()
	_rows_in_game()
	_fixes_inside_a_night()
	Connections.force_row = ""
	print("Connections pairings: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _item(items: Array, key: String) -> Dictionary:
	for it in items:
		if it.key == key:
			return it
	return {}


func _once(items: Array, held: Array) -> bool:
	var seen: Array = []
	for it in items:
		if it.kind == "day":
			continue
		for id in it.ids:
			if id in seen:
				return false
			seen.append(id)
	seen.sort()
	var want: Array = held.duplicate()
	want.sort()
	return seen == want


## The grouping itself, on a hand-made set of cards.
func _grouping() -> void:
	var cards: Array = [
		{"id": "s1", "kind": "sighting", "source": "c", "subject": "a", "subjects": ["a"], "night": 1},
		{"id": "al1", "kind": "alibi", "source": "a", "subject": "a", "subjects": ["a"], "night": 1},
		{"id": "lamp1", "kind": "report", "role": "lamplighter", "source": "d", "night": 1, "data": {}},
		{"id": "guard1", "kind": "report", "role": "warden", "source": "g", "night": 1, "block": "hill", "data": {"target": "d", "saved": true}},
		{"id": "ev1", "kind": "evening", "source": "b", "subject": "a", "subjects": ["a"], "night": 1},
		{"id": "s2", "kind": "sighting", "source": "b", "subject": "e", "subjects": ["e"], "night": 2},
		{"id": "tr", "kind": "trace", "source": "evidence", "data": {}},
		{"id": "claim_a", "kind": "claim", "source": "a", "subject": "a", "role": "clerk"},
		{"id": "claim_f", "kind": "claim", "source": "f", "subject": "f", "role": "dowser"},
		{"id": "secret_e", "kind": "secret_claim", "source": "e", "subject": "e"},
		{"id": "home_a", "kind": "context", "context_kind": "home", "subject": "a", "data": {}},
		{"id": "aug", "kind": "report", "role": "augur", "source": "f", "observed_at": {"day": 2, "phase": "afternoon"}, "data": {}},
		{"id": "loc2", "kind": "location", "source": "b", "subject": "c", "day": 2},
		{"id": "loc3", "kind": "location", "source": "b", "subject": "c", "day": 3},
		{"id": "psy", "kind": "report", "role": "psychologist", "source": "g", "data": {"statements": [{"fact_id": "st1"}, {"fact_id": "s2"}, {"fact_id": "claim_f"}]}},
		{"id": "st1", "kind": "report", "role": "dowser", "source": "f", "data": {}},
		{"id": "read", "kind": "report", "role": "seer", "source": "b", "data": {}},
		{"id": "log", "kind": "watch_log", "source": "evidence", "data": {}},
	]
	var by_id: Dictionary = {}
	for c in cards:
		by_id[c.id] = c
	var held: Array = cards.map(func(c): return c.id)
	var people: Array = ["a", "b", "c", "d", "e", "f", "g"]

	var none: Array = Connections.items(by_id, held, people, "none")
	check(_once(none, held), "no declaration: every held card is in exactly one item")
	var n1: Dictionary = _item(none, "night:1")
	# A Warden's guard too: on a quiet night it says the Demon came to that door, which means
	# something only beside who was seen near it (Quill, Nov 19: weighed alone it moved no one).
	check(n1.get("kind", "") == "unit" and n1.get("ids", []) == ["s1", "al1", "lamp1", "guard1", "ev1"], "a night's sighting, alibi, Lamplighter count, Warden guard and evening card are one item (%s)" % str(n1.get("ids", [])))
	check(n1.get("ctx", []) == ["claim_a"], "its context is the named people's claims, not everyone's (%s)" % str(n1.get("ctx", [])))
	var n2: Dictionary = _item(none, "night:2")
	check(n2.get("ids", []) == ["s2"] and n2.get("ctx", []) == ["secret_e"], "another night is its own item, with a named person's confessed secret as context")
	var tr: Dictionary = _item(none, "trace:tr")
	check(tr.get("kind", "") == "unit" and tr.get("ctx", []) == ["home_a"], "a trace is read with the profile cards")
	var aug: Dictionary = _item(none, "augur:2")
	check(aug.get("ids", []) == ["aug", "loc2"], "an Augur reading takes that day's sightings, and no other day's (%s)" % str(aug.get("ids", [])))
	# Two readings of one day share its sightings, whatever the card order; work schedules are
	# context, and are enough on their own (Codex, #144).
	var by2: Dictionary = by_id.duplicate()
	by2["aug_b"] = {"id": "aug_b", "kind": "report", "role": "augur", "source": "g", "observed_at": {"day": 2, "phase": "afternoon"}, "data": {}}
	by2["aug4"] = {"id": "aug4", "kind": "report", "role": "augur", "source": "f", "observed_at": {"day": 4, "phase": "afternoon"}, "data": {}}
	by2["work_c"] = {"id": "work_c", "kind": "context", "context_kind": "work", "subject": "c", "data": {"work_phases": [1], "loc": ""}}
	for order in [held + ["aug_b", "aug4", "work_c"], ["aug_b", "aug4", "work_c"] + held]:
		var two: Array = Connections.items(by2, order, people, "none")
		var day2: Dictionary = _item(two, "augur:2")
		check(_once(two, order), "two Augur readings: every held card in exactly one item")
		check("aug" in day2.get("ids", []) and "aug_b" in day2.get("ids", []) and "loc2" in day2.get("ids", []), "both of day 2's Augur readings are read with its sightings (%s)" % str(day2.get("ids", [])))
		check("work_c" in day2.get("ctx", []), "known work schedules are the Augur item's context")
		check(_item(two, "augur:4").get("ids", []) == ["aug4"] and "work_c" in _item(two, "augur:4").get("ctx", []), "a day with work schedules but no sightings still makes an Augur item")
	var psy: Dictionary = _item(none, "psychologist:psy")
	check(psy.get("ids", []) == ["psy", "st1"], "a Psychologist reading takes its statements that aren't already in a night, and no claim (%s)" % str(psy.get("ids", [])))
	for id in ["read", "claim_a", "claim_f", "secret_e", "home_a", "loc3", "log"]:
		check(_item(none, id).get("kind", "") == "card", "%s counts alone" % id)
	check(none.all(func(it): return it.kind not in Connections.ALWAYS_ON), "no declaration: no always-on connection")

	var walker: Array = Connections.items(by_id, held, people, "walker")
	var mv: Dictionary = _item(walker, "movement")
	check(_once(walker, held), "walker: every held card is in exactly one item")
	check(mv.get("ids", []) == ["s1", "al1", "lamp1", "guard1", "ev1", "s2", "tr"], "walker: every night and the trace are one movement connection (%s)" % str(mv.get("ids", [])))
	check(not walker.any(func(it): return it.key.begins_with("night:") or it.key.begins_with("trace:")), "walker: no night or trace stands alone")
	check("home_a" in mv.get("ctx", []) and "claim_a" in mv.get("ctx", []) and "secret_e" in mv.get("ctx", []), "walker: profiles and the named people's claims and secrets are its context")

	var hexer: Array = Connections.items(by_id, held, people, "hexer")
	check(_once(hexer, held), "hexer: every held card is in exactly one item, the day connection aside")
	check(_item(hexer, "night:1").get("ids", []) == n1.get("ids", []) and _item(hexer, "movement").is_empty(), "hexer: each night by itself, as with no declaration")
	var day: Dictionary = _item(hexer, "day")
	check(day.get("kind", "") == "day" and day.get("ids", []) == ["ev1", "loc2", "loc3", "log"], "hexer: day logs, daytime sightings and evening cards are the day connection (%s)" % str(day.get("ids", [])))
	check(day.get("ctx", []) == ["home_a"], "hexer: the day connection is read with the profile cards")
	check(Connections.items(by_id, held.filter(func(id): return by_id[id].kind not in Connections.DAY_KINDS), people, "hexer").all(func(it): return it.kind != "day"), "hexer: no day cards, no day connection")


func _play(g, day: int) -> void:
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


## A belief refresh for one NPC, from scratch (the switches below are test statics, which
## the caches don't all key on).
func _proposal(g, n) -> Dictionary:
	g._workshop_evaluations.erase(n.id + ":good")
	Caches.clear_all()
	LiveActivity.cache.clear()
	var was_defer: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	g.w.defer_beliefs = was_defer
	return g._workshop_evaluations.get(n.id + ":good", {}).get("proposal", {}).duplicate(true)


func _adds_up(c: Dictionary) -> bool:
	for id in c.posterior:
		var total: float = float(c.core.lean.get(id, 0.0))
		for it in c.items:
			total += float(it.lean.get(id, 0.0))
		# Stored cases (NPC nominations are among them).
		total += float(c.get("cases", {}).get("lean", {}).get(id, 0.0))
		var settled: bool = c.baseline[id] <= Connections.FIXED or c.baseline[id] >= 1.0 - Connections.FIXED
		var want: float = c.baseline[id] if settled else Connections.chance(Connections.logit(c.baseline[id]) + total + float(c.shift))
		if c.core.proved.has(id):
			want = float(c.core.proved[id])
		if absf(want - float(c.posterior[id])) > 1e-9:
			return false
	return true


## The three readings of movement on one real state: a script with both kinds of Demon.
## "Adds up" includes the stored cases' lean: NPC nominations are stored cases.
func _rows_in_game() -> void:
	var sc = ScriptDef.default_script()
	sc.demons = ["demon", "daykiller"]
	sc.forced = sc.forced.filter(func(r): return not r in sc.demons) + ["daykiller"]
	# The first deal from 12 that's still going at the day-3 meeting.
	var g = null
	for sd in range(12, 42):
		g = Game.new()
		g.detailed_logging = false
		g.new_case(sd, 7, sc)
		_play(g, 3)
		if g.state == "meeting":
			break
	if g.state != "meeting":
		check(false, "the two-kind game reaches the day-3 meeting")
		return
	var listeners: Array = g.w.living().filter(func(n): return not n.is_evil())
	var nights := 0
	var movement := 0
	var day_items := 0
	for stage in ["none", "hexer", "walker"]:
		if stage == "hexer":
			GameMeeting._meeting_command(g, "declare", "hexer")
			check(g.w.declared_demon_type == "hexer", "the town declares a Hexer")
		elif stage == "walker":
			# The developer stand-in for a declaration (a real change waits a day).
			LiveActivity.declared_demon_type = "walker"
		for n in listeners:
			var p: Dictionary = _proposal(g, n)
			if not p.has("connections"):
				continue
			var c: Dictionary = p.connections
			var tag: String = "%s, %s" % [stage, n.id]
			check(c.row == stage, "%s: movement is read as \"%s\"" % [tag, stage])
			var by_kind: Dictionary = {}
			var held: Array = []
			for it in c.items:
				by_kind[it.kind] = int(by_kind.get(it.kind, 0)) + 1
				if it.kind != "day":
					held.append_array(it.cards)
			var cards_by_id: Dictionary = {}
			for card in g._workshop_plans.get(n.id + ":good", {}).get("prepared", {}).get("view", {}).get("cards", []):
				cards_by_id[card.id] = card
			var night_units: int = c.items.filter(func(it): return it.key.begins_with("night:")).size()
			var has_night: bool = held.any(func(id): return cards_by_id.has(id) and (cards_by_id[id].kind in Connections.NIGHT_KINDS or (cards_by_id[id].kind == "report" and str(cards_by_id[id].get("role", "")) in Connections.NIGHT_ROLES)) and int(cards_by_id[id].get("night", -1)) >= 0)
			var has_day: bool = held.any(func(id): return cards_by_id.has(id) and cards_by_id[id].kind in Connections.DAY_KINDS)
			match stage:
				"none":
					check(int(by_kind.get("movement", 0)) + int(by_kind.get("day", 0)) == 0 and (night_units > 0) == has_night, "%s: each night by itself, and no always-on connection (%d nights)" % [tag, night_units])
					nights += night_units
				"hexer":
					check(int(by_kind.get("movement", 0)) == 0 and (night_units > 0) == has_night and (int(by_kind.get("day", 0)) == 1) == has_day, "%s: nights by themselves, and one day connection when day cards are held (%d nights, %d day)" % [tag, night_units, int(by_kind.get("day", 0))])
					day_items += int(by_kind.get("day", 0))
				"walker":
					check(night_units == 0 and int(by_kind.get("day", 0)) == 0 and (int(by_kind.get("movement", 0)) == 1) == has_night, "%s: one movement connection, and no night alone" % tag)
					movement += int(by_kind.get("movement", 0))
			check(_adds_up(c), "%s: each chance is the baseline plus every item's lean and the core's, plus the common shift" % tag)
	LiveActivity.declared_demon_type = ""
	check(LiveActivity.hex_factor_enabled, "the Hexer factor is left on after the model's judgements")
	check(nights > 0 and movement > 0, "the game exercises nights (%d) and the movement connection (%d); day connections: %d" % [nights, movement, day_items])


## A passive game, read night by night (the movement rows forced off).
func _known_game(seed_v: int, day: int):
	Connections.force_row = ""
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, 7)
	_play(g, day)
	Connections.force_row = "none"
	return g


## The first framed-sighting fixture whose subject, without the fake card, isn't already near
## sure the sighter is evil (below 0.9): near that ceiling the town's fixed evil count lets
## the card lift the other evil person instead (seed 100022 with #292: the Demon sighter at
## 0.97 for her subject, and the subject's Revenant teammate rose), so its own direction
## can't show. {} if no seed searched has one.
func _framed_case() -> Dictionary:
	var from: int = Seeds.SEEDS_FROM
	while from < Seeds.SEEDS_FROM + Seeds.FRAMED_SEEDS:
		var fc: Dictionary = Seeds.framed_sighting(2, true, "street", 0.1, from, 0.0, false)
		if fc.is_empty():
			return {}
		_hear_home_alibi(fc.g, fc.bystander, fc.subject, int(fc.night))
		Connections.force_row = "none"
		var sg: String = fc.sighter
		var sub: String = fc.subject
		var eff: Dictionary = Seeds.cards_effect(fc.g, sub, [sg], func(c): return str(c.get("kind", "")) == "sighting" and str(c.get("source", "")) == sg and sub in c.get("subjects", [c.get("subject", "")]) and not c.has("relay_source"))
		Connections.force_row = ""
		if not eff.is_empty() and float(eff.without[sg]) < 0.9:
			return fc
		print("NOTE: seed %d skipped for the framed-sighting checks: %s already holds %s at %.2f without the fake card" % [int(fc.seed), sub, sg, float(eff.get("without", {}).get(sg, -1.0))])
		from = int(fc.seed) + 1
	return {}

## The bystander hears the subject's own "I was home" for the framed night, so the sighter
## contest has the subject's account to weigh the sighting against (Lantern, Nov 20). Handed
## to them rather than searched for: gossip rarely brings it to a bystander of a frame.
func _hear_home_alibi(g, by_id: String, sub_id: String, night: int) -> void:
	var w = g.w
	var by = w.by_id[by_id]
	var sub = w.by_id[sub_id]
	if not Seeds.held_cards(by, func(c):
		var ct: Dictionary = c.get("content", {}) if c.get("content") is Dictionary else {}
		var at = c.get("observed_at", ct.get("observed_at", {}))
		return str(c.get("kind", "")) == "alibi" and str(c.get("source", ct.get("source", ""))) == sub_id and bool(c.get("home", ct.get("home", false))) and at is Dictionary and int(at.get("day", -1)) == night).is_empty():
		return
	var card: Dictionary = {"kind": "alibi", "source": sub_id, "via": sub_id, "subject": [sub_id], "home": true, "block": sub.home_block, "day": night, "phase": C.NIGHT,
		"learned": [{"day": w.day, "phase": w.phase, "via": sub_id}], "text": "test home alibi"}
	var receipt: Dictionary = Mind.WorkshopLedger.Evidence.normalize_card(card)
	Mind.ledger_hear(w, by, "heard:" + receipt.id, [], 1.0, [sub_id, night, "alibi"],
		{"kind": "tell", "workshop_card": receipt, "workshop_teller": sub_id, "workshop_origin": sub_id, "workshop_public": false})

func _chance(g, listener: String, person: String) -> Dictionary:
	var n = g.w.by_id.get(listener)
	if n == null or not n.alive:
		return {}
	var p: Dictionary = _proposal(g, n)
	var out: Dictionary = {"chance": float(p.get("effects", {}).get(person, {}).get("posterior", -1.0)), "night": 0.0}
	for it in p.get("connections", {}).get("items", []):
		if it.key.begins_with("night:") and absf(float(it.lean.get(person, 0.0))) > absf(out.night):
			out.night = float(it.lean.get(person, 0.0))
	return out


## #139 and #135 inside a night, on the real games the two fixes were tested on
## (test_self_sighting): passive play, walker-only scripts, read night by night.
func _fixes_inside_a_night() -> void:
	# Each a kind of case first found on one seed (100034, 100031, 100020), now searched for
	# so play changes don't break them (tools/fixture_seeds.gd). Read as _known_game.
	Connections.force_row = ""
	# (A "street" sighting, as 100034's: a "window" sighting of someone leaving home argues
	# less. The bystander holds the sighter at least 0.1, so it isn't one that already clears
	# them outright and so believes the sighting.)
	var framed_case: Dictionary = _framed_case()
	var relay_case: Dictionary = Seeds.relay(3, func(t): return t.is_evil(), true)
	Connections.force_row = "none"
	if framed_case.is_empty():
		check(false, "a seed has a planter's fake sighting held by its subject and a bystander")
	else:
		# The evil sighter says they saw the subject out; the subject was home. Each check reads
		# what the fake sighting itself does (Seeds.cards_effect: the listener's chances with it
		# held and with it left out), not where the night ends up: that depends on the game's
		# other cards (seed 100037, Nov 18: the subject's own true sighting of the Demon at the
		# night's kill pulled the whole night off the sighter).
		var g = framed_case.g
		var sg: String = framed_case.sighter
		var sub: String = framed_case.subject
		var by: String = framed_case.bystander
		var fake := func(c): return str(c.get("kind", "")) == "sighting" and str(c.get("source", "")) == sg and sub in c.get("subjects", [c.get("subject", "")]) and not c.has("relay_source")
		var lift := func(eff: Dictionary, id: String) -> float: return float(eff.get("with", {}).get(id, 0.0)) - float(eff.get("without", {}).get(id, 0.0))
		var framed: Dictionary = Seeds.cards_effect(g, sub, [sg], fake)
		var watcher: Dictionary = Seeds.cards_effect(g, by, [sg, sub], fake)
		LiveActivity.sighter_contests_enabled = false
		var framed_off: Dictionary = Seeds.cards_effect(g, sub, [sg], fake)
		var watcher_off: Dictionary = Seeds.cards_effect(g, by, [sg, sub], fake)
		LiveActivity.sighter_contests_enabled = true
		var tag: String = "seed %d, %s framed by %s, bystander %s" % [int(framed_case.seed), sub, sg, by]
		# Inside its own night, not overall: as firsthand knowledge (Michael, Nov 12) the card
		# also reseeds the subject's core, which can pull in other cards that clear the sighter
		# (seed 100002 on #454: a "one of Bart and Jory is Delusional" rumour undercuts Jory's
		# watch of Hollis, so overall Hollis falls 0.78 -> 0.71). Interim, Michael Nov 20: the
		# overall change is printed, not checked, until BACKLOG "Being lied about can pull in
		# evidence that clears the liar" (Lantern) is settled, after "A sighting places its
		# teller" lands.
		var night_lift: float = float(framed.get("item_with", {}).get(sg, 0.0)) - float(framed.get("item_without", {}).get(sg, 0.0))
		print("NOTE: #139 overall, the fake sighting moves the subject's chance its sighter is evil by %+.3f (%s)" % [lift.call(framed, sg), tag])
		check(not framed.is_empty() and int(framed.dropped) > 0 and night_lift > 0.0, "#139: the fake sighting counts against its sighter in its night, for the subject, who knows they were home (%+.3f log-odds; %s)" % [night_lift, tag])
		check(lift.call(framed, sg) > lift.call(framed_off, sg), "#139 works through #135: more with the sighter contest than without (%+.3f against %+.3f)" % [lift.call(framed, sg), lift.call(framed_off, sg)])
		check(not watcher.is_empty() and lift.call(watcher, sg) > lift.call(watcher_off, sg), "#135: a bystander weighs the sighter too (%+.3f with the contest, %+.3f without)" % [lift.call(watcher, sg), lift.call(watcher_off, sg)])
		check(lift.call(watcher, sub) < lift.call(watcher_off, sub), "#135: and holds the sighting less against its subject (%+.3f with the contest, %+.3f without)" % [lift.call(watcher, sub), lift.call(watcher_off, sub)])
	# (The Sleepwalker's home-night doubt check retired with the Sleepwalker: burdens rework.
	# No deal holds one, so Seeds.sleepwalker_sighting finds none.)
	# What the relay itself does to its relayer (Seeds.relay_effect: with it held, and left
	# out), not where the relayer ends up: that depends on the game's other cards, which any
	# change to play reshuffles (the Delusional self-doubt, Nov 17, moved this game's ending
	# so the relayer sat at 0.53 although the relay still counted against them).
	var relay: Dictionary = {} if relay_case.is_empty() else Seeds.relay_effect(relay_case.g, str(relay_case.listener), str(relay_case.teller))
	check(not relay.is_empty() and float(relay.with) >= float(relay.without) - 0.01, "an evil Medium's invented relay doesn't clear them for its subject (%.2f with it, %.2f without; seed %d)" % [float(relay.get("with", -1.0)), float(relay.get("without", -1.0)), int(relay_case.get("seed", -1))])
	Connections.force_row = ""
