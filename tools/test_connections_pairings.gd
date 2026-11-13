## The connections belief model, step 2 (workshop/connections.gd; Project doc
## belief-model-direction, "Phase 6 spec" section 3): the built-in pairings and how the
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

const Game = preload("res://game/game.gd")
const GameMeeting = preload("res://game/game_meeting.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
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
	Connections.enabled = Tuning.Workshop.CONNECTIONS
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
	check(n1.get("kind", "") == "unit" and n1.get("ids", []) == ["s1", "al1", "lamp1", "ev1"], "a night's sighting, alibi, Lamplighter count and evening card are one item (%s)" % str(n1.get("ids", [])))
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
	check(mv.get("ids", []) == ["s1", "al1", "lamp1", "ev1", "s2", "tr"], "walker: every night and the trace are one movement connection (%s)" % str(mv.get("ids", [])))
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
		var total: float = 0.0
		for it in c.items:
			total += float(it.lean.get(id, 0.0))
		var settled: bool = c.baseline[id] <= Connections.FIXED or c.baseline[id] >= 1.0 - Connections.FIXED
		var want: float = c.baseline[id] if settled else Connections.chance(Connections.logit(c.baseline[id]) + total + float(c.shift))
		if absf(want - float(c.posterior[id])) > 1e-9:
			return false
	return true


## The three readings of movement on one real state: a script with both kinds of Demon.
func _rows_in_game() -> void:
	var sc = ScriptDef.default_script()
	sc.demons = ["demon", "daykiller"]
	sc.forced = sc.forced.filter(func(r): return not r in sc.demons) + ["daykiller"]
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(12, 7, sc)
	_play(g, 3)
	if g.state != "meeting":
		check(false, "the two-kind game reaches the day-3 meeting")
		return
	var listeners: Array = g.w.living().filter(func(n): return not n.is_evil())
	Connections.enabled = true
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
			check(_adds_up(c), "%s: each chance is the baseline plus every item's lean, plus the common shift" % tag)
	LiveActivity.declared_demon_type = ""
	Connections.enabled = false
	check(LiveActivity.hex_factor_enabled, "the Hexer factor is left on after the model's judgements")
	check(nights > 0 and movement > 0, "the game exercises nights (%d) and the movement connection (%d); day connections: %d" % [nights, movement, day_items])


## A passive game played as it is today (the model off), then read with the model on,
## night by night.
func _known_game(seed_v: int, day: int):
	Connections.enabled = false
	Connections.force_row = ""
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, 7)
	_play(g, day)
	Connections.enabled = true
	Connections.force_row = "none"
	return g


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
	# Seed 100034: the evil Constance says she saw Odette out; Odette was home.
	var g = _known_game(100034, 2)
	var framed: Dictionary = _chance(g, "odette", "constance")
	var watcher: Dictionary = _chance(g, "isolde", "constance")
	var watcher_subject: Dictionary = _chance(g, "isolde", "odette")
	LiveActivity.sighter_contests_enabled = false
	var framed_off: Dictionary = _chance(g, "odette", "constance")
	var watcher_off: Dictionary = _chance(g, "isolde", "constance")
	var watcher_subject_off: Dictionary = _chance(g, "isolde", "odette")
	LiveActivity.sighter_contests_enabled = true
	if framed.is_empty() or watcher.is_empty():
		check(false, "seed 100034 reaches day 2 with Odette and Isolde alive")
	else:
		check(framed.night > 0.5, "#139: the night Odette was wrongly sighted counts against the sighter (its lean on Constance %+.2f)" % framed.night)
		check(framed.chance > framed_off.chance + 0.1, "#139 works through #135: Odette on Constance, %.2f with the sighter contest and %.2f without" % [framed.chance, framed_off.chance])
		check(watcher.chance > watcher_off.chance + 0.05, "#135: a bystander weighs the sighter too (Isolde on Constance, %.2f against %.2f without)" % [watcher.chance, watcher_off.chance])
		check(watcher_subject.chance < watcher_subject_off.chance - 0.05, "#135: and holds the sighting less against its subject (Isolde on Odette, %.2f against %.2f without)" % [watcher_subject.chance, watcher_subject_off.chance])
	# Seed 100031: the honest Constance saw Edda, a real Sleepwalker who believes she was home.
	g = _known_game(100031, 2)
	var sleepwalker: Dictionary = _chance(g, "edda", "constance")
	check(not sleepwalker.is_empty() and sleepwalker.chance < 0.5, "the Sleepwalker Edda, seen by the honest Constance, is far from sure she lied (%.2f)" % sleepwalker.get("chance", -1.0))
	# Seed 100020: the evil Hollis bluffs Medium and invents a relay (#140).
	g = _known_game(100020, 3)
	var relay: Dictionary = _chance(g, "constance", "hollis")
	check(not relay.is_empty() and relay.chance >= 0.6, "the evil Medium Hollis's invented relay doesn't clear him for Constance (%.2f)" % relay.get("chance", -1.0))
	Connections.force_row = ""
	Connections.enabled = false
