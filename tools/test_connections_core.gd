## The connections belief model, step 3 (workshop/connections.gd; Project doc
## belief-model-direction, "Phase 6 spec" section 4): the core.
##
## - The seed is every item holding a card the listener knows firsthand: its own readings,
##   and a sighting of it on a night it knows it spent at home. A night (or the movement
##   connection) seeds it when it holds the listener's own Night Watch or Lamplighter
##   report, or such a sighting. The Hexer's day connection never does.
## - Another item joins when it is worth 0.4 more next to the seed than apart, for any one
##   person. It is tested against the seed only. Always-on connections are never tested.
## - The core adds what its members say together beyond their own values.
## - It is rebuilt on a new day and when the firsthand cards change. Otherwise its members
##   stay for the day and only an item with a newly held card is tested.
## - What the firsthand cards prove by themselves stays proved.
## - In game the memory lives in the NPC's workshop_state.connections, is written only by
##   the applied refresh, and isn't there at all while the switch is off.
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const Connections = preload("res://workshop/connections.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Ownership = preload("res://game/workshop_ownership.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Jury = preload("res://workshop/jury.gd")
const Caches = preload("res://workshop/caches.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	check(is_equal_approx(Connections.CORE_JOIN, 0.4), "an item joins the core at 0.4")
	check(Connections.seed_wrong_sightings, "a wrong sighting of the listener is firsthand knowledge in play")
	_firsthand()
	_tests_and_members()
	_arithmetic()
	_combine()
	_states(900, 7, 3, 99)
	_states(902, 10, 3, 3)
	_wrong_sighting()
	_in_game(900, 7, 3)
	Connections.enabled = Tuning.Workshop.CONNECTIONS
	Connections.force_row = ""
	Connections.seed_wrong_sightings = true
	print("Connections core: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


# ------------------------------------------------------------ the rules, on hand-made cards

func _cards() -> Dictionary:
	return {
		"own": {"id": "own", "kind": "report", "role": "archivist", "source": "me", "data": {"pair": ["x", "y"]}},
		"theirs": {"id": "theirs", "kind": "report", "role": "archivist", "source": "x", "data": {"pair": ["y", "z"]}},
		"watch": {"id": "watch", "kind": "report", "role": "nightwatch", "source": "me", "night": 1, "data": {"seen": ["x"]}},
		"saw_me_home": {"id": "saw_me_home", "kind": "sighting", "source": "y", "subject": "me", "subjects": ["me"], "night": 2},
		"saw_me_out": {"id": "saw_me_out", "kind": "sighting", "source": "y", "subject": "me", "subjects": ["me"], "night": 3},
		"saw_x": {"id": "saw_x", "kind": "sighting", "source": "y", "subject": "x", "subjects": ["x"], "night": 2},
		"alibi_x": {"id": "alibi_x", "kind": "alibi", "source": "x", "subject": "x", "night": 3},
		"log": {"id": "log", "kind": "watch_log", "source": "z", "day": 2},
		"claim_x": {"id": "claim_x", "kind": "claim", "source": "x", "subject": "x", "role": "archivist"},
	}


func _firsthand() -> void:
	var by_id: Dictionary = _cards()
	var people: Array = ["me", "x", "y", "z"]
	# Home on nights 1 and 2, out on night 3.
	var listener: Dictionary = {"id": "me", "knowledge": {"own_outings": {"1": false, "2": false, "3": true}}}
	var held: Array = by_id.keys()
	var first: Array = Connections.firsthand(by_id, held, listener)
	check(first == ["own", "saw_me_home", "watch"], "firsthand: its own readings, and a sighting of it on a night it was home (%s)" % str(first))
	check("saw_me_out" not in first and "saw_x" not in first and "theirs" not in first, "not a true sighting of it, a sighting of someone else, or another's reading")
	Connections.seed_wrong_sightings = false
	check(Connections.firsthand(by_id, held, listener) == ["own", "watch"], "with the option off, only its own readings")
	Connections.seed_wrong_sightings = true
	check(Connections.firsthand(by_id, held, {"id": "me", "knowledge": {}}) == ["own", "watch"], "a listener that doesn't know where it was that night makes nothing of the sighting")
	var none: Array = Connections.items(by_id, held, people, "none")
	check(Connections.seed_keys(none, first) == ["night:1", "night:2", "own"], "night by night: the night with its own watch, the night it was wrongly sighted, and its own reading seed the core (%s)" % str(Connections.seed_keys(none, first)))
	check(Connections.seed_keys(none, ["own"]) == ["own"], "without the watch report or the wrong sighting, no night seeds it")
	var walker: Array = Connections.items(by_id, held, people, "walker")
	check(Connections.seed_keys(walker, first) == ["movement", "own"], "a Walker reading: the movement connection seeds it instead")
	var hexer: Array = Connections.items(by_id, held, people, "hexer")
	check("day" in hexer.map(func(it): return it.key) and "day" not in Connections.seed_keys(hexer, first), "a Hexer reading: the day connection never seeds it")
	check(Connections.seed_keys([{"key": "day", "kind": "day", "ids": ["own"]}], ["own"]).is_empty(), "the day connection is never a seed, whatever it re-reads")


func _tests_and_members() -> void:
	var item_list: Array = [
		{"key": "movement", "kind": "movement", "ids": ["m1", "m2"], "ctx": []},
		{"key": "own", "kind": "card", "ids": ["own"], "ctx": []},
		{"key": "a", "kind": "card", "ids": ["a"], "ctx": []},
		{"key": "night:1", "kind": "unit", "ids": ["n1", "n2"], "ctx": []},
		{"key": "b", "kind": "card", "ids": ["b"], "ctx": []},
		{"key": "day", "kind": "day", "ids": ["n1"], "ctx": []}]
	var fresh: Dictionary = Connections.candidates(item_list, ["own"], ["own"], {}, 3)
	check(fresh.rebuilt and fresh.test == ["a", "night:1", "b"] and fresh.kept.is_empty(), "no memory: every other card and pairing is tested, and no always-on connection (%s)" % str(fresh.test))
	var members: Array = Connections.membership(item_list, fresh.kept, {"a": 0.4, "night:1": 0.39, "b": 1.2})
	check(members == ["a", "b"], "an item joins at 0.4 or more and not below (%s)" % str(members))
	var memory: Dictionary = Connections.core_memory(3, ["own"], ["own"], members, ["m1", "m2", "own", "a", "n1", "b"])
	var same: Dictionary = Connections.candidates(item_list, ["own"], ["own"], memory, 3)
	check(not same.rebuilt and same.kept == ["a", "b"] and same.test == ["night:1"], "the same day: members stay, and only the pairing with a newly held card (n2) is tested (%s)" % str(same.test))
	check(Connections.membership(item_list, same.kept, {"night:1": 0.1}) == ["a", "b"], "a member stays for the day without being tested again")
	check(Connections.membership(item_list, same.kept, {"night:1": 0.7}) == ["a", "night:1", "b"], "a newly heard card that passes joins on arrival")
	var all_known: Dictionary = Connections.core_memory(3, ["own"], ["own"], ["a"], ["m1", "m2", "own", "a", "n1", "n2", "b"])
	var quiet: Dictionary = Connections.candidates(item_list, ["own"], ["own"], all_known, 3)
	check(not quiet.rebuilt and quiet.test.is_empty() and quiet.kept == ["a"], "nothing new: nothing is tested, and a card that didn't join at dawn doesn't join later")
	check(Connections.candidates(item_list, ["own"], ["own"], all_known, 4).rebuilt, "a new day rebuilds the core")
	check(Connections.candidates(item_list, ["own", "a"], ["a", "own"], all_known, 3).rebuilt, "a new reading of its own rebuilds the core")
	check(Connections.candidates(item_list, ["own"], ["own", "n1"], all_known, 3).rebuilt, "so does a new firsthand card in a seed it already had")
	var moving: Dictionary = Connections.candidates(item_list, ["movement", "own"], ["m1", "own"], {}, 3)
	check("movement" not in moving.test and "day" not in moving.test, "a connection that seeds the core isn't tested against it")


## A stand-in for a refresh's working state: every judgement the core will ask for is
## already in its memo, so the arithmetic is checked on chosen numbers.
func _fake_run(leans: Dictionary, chances: Dictionary = {}) -> Dictionary:
	var others: Array = ["x", "y", "z"]
	var run: Dictionary = {"others": others, "baseline": {"x": 0.3, "y": 0.3, "z": 0.3}, "memo": {}, "judgements": 0,
		"listener": {"id": "me", "knowledge": {}}}
	for key in leans:
		var ids: Array = Array(key.split(","))
		ids.sort()
		var full: Dictionary = {}
		var chance_of: Dictionary = {}
		for p in others:
			full[p] = float(leans[key].get(p, 0.0))
			chance_of[p] = float(chances.get(key, {}).get(p, Connections.chance(Connections.logit(0.3) + full[p])))
		run.memo[",".join(PackedStringArray(ids))] = {"lean": full, "chance": chance_of, "impossible": leans[key].has("impossible")}
	return run


func _arithmetic() -> void:
	var by_id: Dictionary = {
		"own": {"id": "own", "kind": "report", "role": "archivist", "source": "me"},
		"a": {"id": "a", "kind": "report", "role": "archivist", "source": "x"},
		"b": {"id": "b", "kind": "report", "role": "archivist", "source": "y"},
		"s": {"id": "s", "kind": "sighting", "source": "y", "subject": "x", "subjects": ["x"], "night": 1},
		"c": {"id": "c", "kind": "claim", "source": "x", "subject": "x", "role": "archivist"}}
	var held: Array = ["a", "b", "c", "own", "s"]
	var item_list: Array = Connections.items(by_id, held, ["me", "x", "y", "z"], "none")
	check(item_list.map(func(it): return it.key) == ["night:1", "a", "b", "c", "own"], "the hand-made state: a night, three plain cards and the listener's own reading")
	# Alone: own +1.0 on x; a +0.2; b -0.3; the claim +0.1 on y; the night +0.6 on x given the claim.
	# Next to the seed: a is worth 0.5 more, b 0.3 more, the claim nothing, the night 0.45 less.
	var run: Dictionary = _fake_run({
		"own": {"x": 1.0}, "a": {"x": 0.2}, "b": {"x": -0.3}, "c": {"y": 0.1}, "c,s": {"x": 0.6, "y": 0.1},
		"a,own": {"x": 1.7}, "b,own": {"x": 1.0}, "c,own": {"x": 1.0, "y": 0.1}, "c,own,s": {"x": 1.15, "y": 0.1},
		"a,c,own,s": {"x": 2.5, "y": 0.1}})
	var values: Dictionary = {}
	for it in item_list:
		values[it.key] = Connections.value(run, it)
	check(is_equal_approx(float(values["night:1"].lean.get("x", 0.0)), 0.6) and not values["night:1"].lean.has("y"), "a pairing's value leaves out what its context says alone")
	var core: Dictionary = Connections.core(run, by_id, item_list, values, held, {})
	check(core.seed == ["own"] and core.firsthand == ["own"], "the seed is the listener's own reading")
	check(is_equal_approx(core.tested.a, 0.5) and is_equal_approx(core.tested.b, 0.3) and is_equal_approx(core.tested["night:1"], 0.45) and is_zero_approx(core.tested.c),
		"each candidate's test: together with the seed, less the seed alone, less the candidate alone (a %.2f, b %.2f, the night %.2f, the claim %.2f)" % [core.tested.a, core.tested.b, core.tested["night:1"], core.tested.c])
	check(core.members == ["night:1", "a"], "0.4 and over joins (%s)" % str(core.members))
	check(core.lean.keys() == ["x"] and is_equal_approx(core.lean.x, 2.5 - 1.0 - 0.2 - 0.6), "the core adds what its members say together beyond their own values (%+.2f on x)" % core.lean.get("x", 0.0))
	check(core.cards == 3 and core.rebuilt and core.proved.is_empty() and not core.impossible, "three cards weighed together; nothing proved")
	check(run.judgements == 0, "every judgement came from the ones already made")
	# The same day with that memory: nothing is tested, the members and the lean are the same.
	var again: Dictionary = Connections.core(run, by_id, item_list, values, held, {"day": -1, "core": core.memory})
	check(not again.rebuilt and again.tested.is_empty() and again.members == core.members and again.lean == core.lean, "the same day: the core is reused without testing anything")
	# A core of the seed alone adds nothing.
	var alone: Dictionary = Connections.core(_fake_run({"own": {"x": 1.0}}), by_id, [item_list[4]], {"own": {"lean": {"x": 1.0}, "impossible": false}}, ["own"], {})
	check(alone.members.is_empty() and alone.lean.is_empty() and alone.cards == 1, "a seed with nothing joined adds nothing beyond its own value")
	# No firsthand card: no core.
	var no_seed: Dictionary = Connections.core(run, by_id, item_list.slice(0, 4), values, ["a", "b", "c", "s"], {})
	check(no_seed.seed.is_empty() and no_seed.members.is_empty() and no_seed.lean.is_empty(), "a listener with no firsthand card has no core")
	# What the firsthand card proves alone stays proved.
	var proving: Dictionary = _fake_run({"own": {"x": 1.0, "z": -4.0}}, {"own": {"z": 0.0}})
	var proved: Dictionary = Connections.core(proving, by_id, [item_list[4]], {"own": {"lean": {"x": 1.0, "z": -4.0}, "impossible": false}}, ["own"], {})
	check(proved.proved.keys() == ["z"] and is_zero_approx(proved.proved.z), "a firsthand reading that rules someone out proves it")
	# A candidate no world allows beside the seed is set aside, not weighed.
	var clashing: Dictionary = _fake_run({"own": {"x": 1.0}, "a": {"x": 0.2}, "a,own": {"impossible": true}})
	var clash: Dictionary = Connections.core(clashing, by_id, [item_list[1], item_list[4]], {"a": {"lean": {"x": 0.2}, "impossible": false}, "own": {"lean": {"x": 1.0}, "impossible": false}}, ["a", "own"], {})
	check(clash.clash == ["a"] and clash.members.is_empty() and clash.lean.is_empty(), "a card no world allows beside the seed doesn't join")


func _combine() -> void:
	var others: Array = ["x", "y", "v", "z", "w"]
	var baseline: Dictionary = {"x": 0.5, "y": 0.5, "v": 0.5, "z": 0.5, "w": 0.0}
	var plain: Dictionary = Connections.combine(others, baseline, {"x": 1.0})
	check(absf(plain.posterior.x + plain.posterior.y + plain.posterior.v + plain.posterior.z - 2.0) < 1e-9 and plain.posterior.x > plain.posterior.y and is_zero_approx(plain.posterior.w),
		"nothing proved: the open chances keep the baseline's sum, and a settled person stays settled")
	var out: Dictionary = Connections.combine(others, baseline, {"x": 1.0, "z": -3.0}, {"z": 1.0, "w": 0.7})
	check(is_equal_approx(out.posterior.z, 1.0), "a proved person keeps the proved chance, whatever the other cards lean")
	check(absf(out.posterior.x + out.posterior.y + out.posterior.v - 1.0) < 1e-9, "and the others share what is left of the sum (%.3f)" % (out.posterior.x + out.posterior.y + out.posterior.v))
	check(is_zero_approx(out.posterior.w), "a person the baseline settles isn't reopened by a proof")
	var both: Dictionary = Connections.combine(["x", "y", "z"], {"x": 0.6, "y": 0.7, "z": 0.7}, {}, {"y": 1.0, "z": 1.0})
	check(both.posterior.x < 0.001, "with every evil proved, nobody else is left under suspicion (%.5f)" % both.posterior.x)


# ------------------------------------------------------------ on real listener states

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


## What the game's refresh hands the model for this listener: the prepared view, the
## whole-evidence case, the listener, and the cards it holds (less the ones it rejects).
func _inputs(g, n) -> Dictionary:
	var ws: Dictionary = n.workshop_state
	var kept := [Shared.last_reason_ctx, Jury._eval_memo, Reasoner.capture_attention, Reasoner.unlimited_cards, Reasoner.reuse_preparations]
	Reasoner.capture_attention = false
	Reasoner.unlimited_cards = true
	Reasoner.reuse_preparations = false
	var outside: Dictionary = Ownership._candidate_outside(n, ws)
	var input = Bridge.capture(g, [], n.id, "private", n)
	input.listener.suspicion = outside.duplicate(true)
	var plan: Dictionary = Shared.prepare(input, ws.get("presentations", {}), n.ledger, ws.get("withdrawn", {}), [])
	var out: Dictionary = {"ready": false}
	if plan.get("ready", false) and not plan.get("empty", false):
		var doubt: Dictionary = SourceDoubt.derive(plan, n.ledger, ws.get("manual_source_doubt", {}))
		var prepared: Dictionary = Shared._doubt_adjusted(plan, outside, doubt.pre_eval, doubt.full)
		var by_id: Dictionary = {}
		for c in prepared.view.cards:
			by_id[c.id] = c
		var rejected: Array = Reasoner.direct_checks(prepared.view, prepared.case, prepared.listener.get("knowledge", {})).get("rejected", [])
		out = {"ready": true, "view": prepared.view, "case": prepared.case, "listener": prepared.listener, "by_id": by_id,
			"held": prepared.case.cards.filter(func(id): return by_id.has(id) and id not in rejected)}
	Shared.last_reason_ctx = kept[0]
	Jury._eval_memo = kept[1]
	Reasoner.capture_attention = kept[2]
	Reasoner.unlimited_cards = kept[3]
	Reasoner.reuse_preparations = kept[4]
	return out


func _same(a: Dictionary, b: Dictionary) -> bool:
	for p in a:
		if absf(float(a[p]) - float(b.get(p, -9.0))) > 1e-9:
			return false
	return a.size() == b.size()


func _states(seed_v: int, npcs: int, day: int, most: int) -> void:
	Connections.enabled = false
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, npcs)
	_play(g, day)
	var tag: String = "seed %d" % seed_v
	if g.state != "meeting":
		check(false, "%s reaches the day-%d meeting" % [tag, day])
		return
	var seeded := 0
	var joined := 0
	var arrivals := 0
	for n in g.w.living().filter(func(x): return not x.is_evil()):
		if seeded >= most:
			break
		var st: Dictionary = _inputs(g, n)
		if not st.ready:
			continue
		var r: Dictionary = Connections.refresh(st.view, st.case, st.listener, st.held, {})
		var core: Dictionary = r.core
		var who: String = "%s %s" % [tag, n.id]
		var keys: Dictionary = {}
		for it in r.items:
			keys[it.key] = it
		if core.seed.is_empty():
			check(core.members.is_empty() and core.lean.is_empty() and core.firsthand.is_empty(), "%s: no firsthand card, no core" % who)
			continue
		seeded += 1
		joined += core.members.size()
		# The seed is exactly the items holding a firsthand card.
		var want_seed: Array = r.items.filter(func(it): return it.kind != "day" and it.cards.any(func(id): return id in core.firsthand)).map(func(it): return it.key)
		check(core.seed == want_seed, "%s: the seed is the items holding its firsthand cards (%s)" % [who, str(core.seed)])
		# Every other card and pairing is tested once; members are the ones at 0.4 or more.
		var candidates: Array = r.items.filter(func(it): return it.kind not in Connections.ALWAYS_ON and it.key not in core.seed).map(func(it): return it.key)
		var accounted: Array = core.tested.keys() + core.clash
		accounted.sort()
		candidates.sort()
		var want_members: Array = r.items.filter(func(it): return float(core.tested.get(it.key, -1.0)) >= Connections.CORE_JOIN).map(func(it): return it.key)
		check(core.rebuilt and accounted == candidates and core.members == want_members, "%s: every other card and pairing is tested against the seed, and those at 0.4 or more join (%d tested, %d joined)" % [who, candidates.size(), core.members.size()])
		check(core.members.all(func(k): return keys[k].kind not in Connections.ALWAYS_ON and k not in core.seed), "%s: no always-on connection joins by the test" % who)
		# The same day, with the memory: nothing is tested, the same beliefs, fewer judgements.
		var same: Dictionary = Connections.refresh(st.view, st.case, st.listener, st.held, {"day": day, "core": r.core_memory})
		var first_day: Dictionary = Connections.refresh(st.view, st.case, st.listener, st.held, {"day": day, "core": {}})
		check(first_day.core.rebuilt and first_day.core_memory.day == day and first_day.core.members == core.members, "%s: the first refresh of a day builds the core and dates its memory" % who)
		same = Connections.refresh(st.view, st.case, st.listener, st.held, {"day": day, "core": first_day.core_memory})
		check(not same.core.rebuilt and same.core.tested.is_empty() and same.core.members == core.members and _same(same.posterior, r.posterior) and same.judgements <= r.judgements,
			"%s: later that day the core is reused untested, and the beliefs are the same (%d judgements instead of %d)" % [who, same.judgements, r.judgements])
		check(Connections.refresh(st.view, st.case, st.listener, st.held, {"day": day + 1, "core": first_day.core_memory}).core.rebuilt, "%s: the next day it is rebuilt" % who)
		# The order the cards come in can't matter.
		var reversed: Array = st.held.duplicate()
		reversed.reverse()
		var other_order: Dictionary = Connections.refresh(st.view, st.case, st.listener, reversed, {})
		check(other_order.core.members == core.members and _same(other_order.posterior, r.posterior), "%s: the order of the cards doesn't matter" % who)
		# Membership is fixed for the day: a card that didn't join at dawn doesn't join later,
		# and a member isn't dropped, when nothing new arrives.
		if not core.members.is_empty():
			var without: Dictionary = first_day.core_memory.duplicate(true)
			without.members = core.members.slice(1)
			var fixed: Dictionary = Connections.refresh(st.view, st.case, st.listener, st.held, {"day": day, "core": without})
			check(fixed.core.members == core.members.slice(1) and fixed.core.tested.is_empty(), "%s: a card that wasn't in the core at dawn isn't tested again that day" % who)
		# A newly held card is tested on arrival, alone.
		var plain: Array = core.members.filter(func(k): return keys[k].kind == "card" and st.by_id[k].kind not in Connections.CONTEXT_KINDS)
		if not plain.is_empty() and arrivals < 3:
			arrivals += 1
			var late: String = plain[0]
			var before: Dictionary = Connections.refresh(st.view, st.case, st.listener, st.held.filter(func(id): return id != late), {"day": day, "core": {}})
			var after: Dictionary = Connections.refresh(st.view, st.case, st.listener, st.held, {"day": day, "core": before.core_memory})
			check(late not in before.core.members and not after.core.rebuilt and after.core.tested.keys() == [late] and after.core.members == core.members and _same(after.posterior, r.posterior),
				"%s: a card heard during the day is tested when it arrives, and only it (%s)" % [who, late])
	check(seeded > 0, "%s: listeners with firsthand cards to test (%d, %d cards and pairings joined)" % [tag, seeded, joined])
	if most > 3:
		check(joined > 0 and arrivals > 0, "%s: some cores have members, and a late arrival was tried" % tag)


## Seed 100034, day 2: the evil Constance says she saw Odette out; Odette was home.
func _wrong_sighting() -> void:
	Connections.enabled = false
	LiveActivity.cache.clear()
	Caches.clear_all()
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(100034, 7)
	_play(g, 2)
	var n = g.w.by_id.get("odette")
	if n == null or not n.alive:
		check(false, "seed 100034 reaches day 2 with Odette alive")
		return
	var st: Dictionary = _inputs(g, n)
	var wrong: Array = st.held.filter(func(id): return st.by_id[id].kind == "sighting" and "odette" in st.by_id[id].get("subjects", [st.by_id[id].get("subject", "")]))
	check(wrong.size() == 1 and str(st.by_id[wrong[0]].get("source", "")) == "constance", "Odette holds Constance's sighting of her")
	for row in ["none", "walker"]:
		Connections.force_row = row
		var on: Dictionary = Connections.refresh(st.view, st.case, st.listener, st.held, {})
		Connections.seed_wrong_sightings = false
		var off: Dictionary = Connections.refresh(st.view, st.case, st.listener, st.held, {})
		Connections.seed_wrong_sightings = true
		var holder: String = "movement" if row == "walker" else "night:%d" % int(st.by_id[wrong[0]].night)
		check(wrong[0] in on.core.firsthand and holder in on.core.seed, "%s reading: the sighting is firsthand knowledge, and %s seeds her core" % [row, holder])
		check(wrong[0] not in off.core.firsthand and holder not in off.core.seed, "%s reading, option off: it doesn't" % row)
		print("NOTE: seed 100034, %s reading: Odette on Constance %.2f with the wrong sighting in her core's seed, %.2f without (core members %d and %d)" % [row,
			float(on.posterior.constance), float(off.posterior.constance), on.core.members.size(), off.core.members.size()])
	Connections.force_row = ""


# ------------------------------------------------------------ in the game

func _refresh(g, n) -> Dictionary:
	var was_defer: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	g.w.defer_beliefs = was_defer
	return g._workshop_evaluations.get(n.id + ":good", {})


func _in_game(seed_v: int, npcs: int, day: int) -> void:
	# Played with the model on from the start.
	Connections.enabled = true
	LiveActivity.cache.clear()
	Caches.clear_all()
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, npcs)
	_play(g, day)
	var tag: String = "seed %d, model on" % seed_v
	if g.state != "meeting":
		check(false, "%s reaches the day-%d meeting" % [tag, day])
		return
	var dated := 0
	var remembered := 0
	for n in g.w.living().filter(func(x): return not x.is_evil()):
		var memory: Dictionary = n.workshop_state.get("connections", {}).get("core", {})
		if memory.is_empty():
			continue
		remembered += 1
		var now: Dictionary = _refresh(g, n)
		var core: Dictionary = now.get("proposal", {}).get("connections", {}).get("core", {})
		memory = n.workshop_state.connections.core
		if int(memory.day) == int(g.w.day):
			dated += 1
		check(memory.members == core.get("members", ["?"]) and memory.seed == core.get("seed", ["?"]), "%s %s: the NPC remembers the core its beliefs were built on" % [tag, n.id])
		var hit: Dictionary = _refresh(g, n)
		check(bool(hit.get("cache_hit", false)), "%s %s: a refresh with nothing new is still answered from the kept result" % [tag, n.id])
		# Redone from scratch on the same day: the core is reused, not rebuilt.
		g._workshop_evaluations.erase(n.id + ":good")
		var redone: Dictionary = _refresh(g, n)
		var again: Dictionary = redone.get("proposal", {}).get("connections", {}).get("core", {})
		check(not redone.get("cache_hit", true) and (core.get("seed", []).is_empty() or not again.get("rebuilt", true)) and again.get("members", ["?"]) == memory.members,
			"%s %s: redone the same day, the core's members stay" % [tag, n.id])
	check(remembered >= 2 and dated == remembered, "%s: every good NPC's core memory is dated today (%d of %d)" % [tag, dated, remembered])
	# The switch off: the memory isn't read, written or created.
	Connections.enabled = false
	var off_game = Game.new()
	off_game.detailed_logging = false
	LiveActivity.cache.clear()
	Caches.clear_all()
	off_game.new_case(seed_v, npcs)
	_play(off_game, day)
	check(off_game.w.npcs.all(func(x): return not x.workshop_state.has("connections")), "seed %d, model off: no NPC has any connections memory" % seed_v)
	var listener = off_game.w.living().filter(func(x): return not x.is_evil())[0]
	var input: Dictionary = Bridge.capture(off_game, [], listener.id, "private", listener)
	check(not input.listener.has("connections"), "seed %d, model off: the listener carries nothing of the model" % seed_v)
