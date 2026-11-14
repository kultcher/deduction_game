## The connections belief model, step 4 (workshop/connections.gd; Project doc
## belief-model-direction, "Phase 6 spec", stored cases).
##
## - A stored case is a case someone put to the listener: the player's presentation, or
##   the cards an NPC nominator cited. Its cards are judged together, and it adds what they
##   say together beyond their own values, times its weight.
## - The weight is trust in the presenter, halved for each day since, halved again under a
##   "suspicious" premise, and nothing below 0.05. Presenting it again restores it.
## - A case sharing a card with the core is judged with the core (older cases first); a
##   card cited from an always-on connection never merges.
## - A challenge acts inside its own case: the reading's own value is untouched, and the
##   floors a challenge puts under people are scaled by the case's weight.
## - Spillover damping is off: a presentation is weighed as its own cards.
## - With the switch off, none of it exists.
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const Connections = preload("res://workshop/connections.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Caches = preload("res://workshop/caches.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const WorkshopPresentation = preload("res://game/workshop_presentation.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	check(is_equal_approx(Connections.CASE_FADE, 0.5) and is_equal_approx(Connections.CASE_FLOOR, 0.05), "a case keeps half its weight a day and stops counting under 0.05")
	_weights()
	_plan()
	_arithmetic()
	_presented()
	_reuse_in_game()
	_fading_and_repeat()
	_challenges()
	_challenged_factors()
	_nominations(900, 7, 3)
	Connections.enabled = Tuning.Workshop.CONNECTIONS
	print("Connections cases: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


# ------------------------------------------------------------ the rules, on hand-made cases

func _weights() -> void:
	var listener: Dictionary = {"id": "me", "trust": 0.3, "player_credibility": 0.6, "npc_trust": {"x": 0.8, "y": 1.4}}
	check(is_equal_approx(Connections.presenter_trust(listener, "player"), 0.6), "the player's cases weigh at the player's credibility with this listener")
	check(is_equal_approx(Connections.presenter_trust({"trust": 0.3}, "player"), 0.3), "or at its trust, for a listener that keeps no credibility")
	check(is_equal_approx(Connections.presenter_trust(listener, "x"), 0.8) and is_equal_approx(Connections.presenter_trust(listener, "y"), 1.0) and is_equal_approx(Connections.presenter_trust(listener, "z"), 0.5),
		"an NPC's cases weigh at the listener's trust in that NPC (0 to 1; 0.5 if it has none)")
	var cs: Dictionary = {"presenter": "x", "day": 3}
	check(is_equal_approx(Connections.case_weight(listener, cs, 3), 0.8) and is_equal_approx(Connections.case_weight(listener, cs, 4), 0.4) and is_equal_approx(Connections.case_weight(listener, cs, 6), 0.1),
		"a case keeps half its weight for each day since it was presented")
	check(is_equal_approx(Connections.case_weight(listener, cs.merged({"suspicious": true}), 3), 0.8 * Tuning.Workshop.SUSPICIOUS_HEARING), "a \"suspicious\" premise halves it")
	check(is_equal_approx(Connections.case_weight(listener, cs.merged({"day": 5}, true), 5), 0.8), "presented again today, it is back at full weight")
	# The store for NPC nominators' cases.
	var first: Dictionary = {"key": "n1", "presenter": "x", "target": "t", "type": "evil", "cards": ["a"], "day": 1}
	var store: Array = Connections.stored_with([], first, 1)
	store = Connections.stored_with(store, {"key": "n2", "presenter": "y", "target": "t", "type": "evil", "cards": ["b"], "day": 2}, 2)
	store = Connections.stored_with(store, {"key": "n3", "presenter": "x", "target": "u", "type": "evil", "cards": ["c"], "day": 2}, 2)
	check(store.map(func(c): return c.key) == ["n1", "n2", "n3"], "cases from other presenters or about other people sit side by side")
	store = Connections.stored_with(store, {"key": "n4", "presenter": "x", "target": "t", "type": "evil", "cards": ["a", "d"], "day": 3}, 3)
	check(store.map(func(c): return c.key) == ["n2", "n3", "n4"], "the same presenter's new case about the same person replaces its earlier one")
	store = Connections.stored_with(store, {"key": "n5", "presenter": "z", "target": "t", "type": "evil", "cards": ["e"], "day": 7}, 7)
	check(store.map(func(c): return c.key) == ["n4", "n5"], "a case too old to count at any trust is dropped (%s)" % str(store.map(func(c): return c.key)))
	check(Connections.challenged_ids([{"challenges": {"r1": {}}}, {"challenges": {"r1": {}, "r2": {}}}, {}]) == ["r1", "r2"], "the readings stored cases challenge")


func _items() -> Array:
	return [
		{"key": "movement", "kind": "movement", "ids": ["m1", "m2"], "ctx": []},
		{"key": "night:1", "kind": "unit", "ids": ["n1", "n2"], "ctx": ["claim"]},
		{"key": "own", "kind": "card", "ids": ["own"], "ctx": []},
		{"key": "a", "kind": "card", "ids": ["a"], "ctx": []},
		{"key": "b", "kind": "card", "ids": ["b"], "ctx": []},
		{"key": "c", "kind": "card", "ids": ["c"], "ctx": []},
		{"key": "day", "kind": "day", "ids": ["n1"], "ctx": []}]


func _plan() -> void:
	var listener: Dictionary = {"id": "me", "trust": 0.5, "player_credibility": 0.6, "npc_trust": {"x": 0.8}}
	var list: Array = [
		{"key": "new", "presenter": "player", "day": 3, "cards": ["a", "b", "unheld"]},
		{"key": "old", "presenter": "x", "day": 1, "cards": ["n1", "m1", "m1", "c"]},
		{"key": "gone", "presenter": "x", "day": -2, "cards": ["a", "b"]},
		{"key": "empty", "presenter": "x", "day": 3, "cards": ["unheld"]},
		{"key": "hedged", "presenter": "player", "day": 3, "cards": ["b", "c"], "suspicious": true, "challenges": {"b": {"mode": "misled"}}}]
	var plan: Array = Connections.case_plan(list, _items(), listener, 3)
	check(plan.map(func(c): return c.key) == ["old", "new", "hedged"], "the cases that count, oldest first; one under the floor or with no held card is left out (%s)" % str(plan.map(func(c): return c.key)))
	check(plan[1].keys == ["a", "b"] and plan[1].extra.is_empty(), "a card the listener doesn't hold isn't weighed")
	check(plan[0].keys == ["night:1", "c"] and plan[0].extra == ["m1"], "a night's card brings its night; a card from an always-on connection is cited alone (%s, %s)" % [str(plan[0].keys), str(plan[0].extra)])
	check(is_equal_approx(plan[0].weight, 0.8 * 0.25) and is_equal_approx(plan[1].weight, 0.6) and is_equal_approx(plan[2].weight, 0.3), "each at its presenter's trust, faded and hedged")
	check(plan[2].challenges.has("b") and plan[1].challenges.is_empty(), "a case carries its own challenges")
	check(Connections.case_plan(list, _items(), listener, 3, 1.0).map(func(c): return c.key) == ["gone", "old", "new", "hedged"], "the fade rate is the tool's to vary")


## A presenter's cases that reuse its own cards (Michael, Nov 13): one that cites every card
## of an earlier one takes its place; otherwise it adds nothing for what the earlier one
## already put together.
func _reuse(item_list: Array, values: Dictionary, leans: Dictionary) -> void:
	var none: Dictionary = {"seed": [], "members": [], "lean": {}, "impossible": false}
	var more: Dictionary = leans.merged({"a,b": 0.5, "a,b,c": 1.4})   # a,b: +0.6 beyond; a,b,c: +1.4 beyond 0.2 - 0.3 + 0.1; b,c: +0.6 beyond
	var first: Dictionary = {"key": "first", "presenter": "n", "day": 2, "cards": ["b", "c"]}
	# The same cards again, under another premise.
	var again: Dictionary = Connections.cases(_fake_run(more), item_list, values, none, [first, {"key": "again", "presenter": "n", "day": 3, "cards": ["c", "b"], "type": "suspicious", "suspicious": true}], 3)
	check(again.entries.map(func(e): return e.key) == ["again"] and again.entries[0].replaces == ["first"], "a case citing every card of the presenter's earlier case takes its place")
	check(is_equal_approx(again.lean.x, 0.8 * 0.5 * 0.6), "the set counts once, at the later case's weight (%+.3f)" % again.lean.x)
	# A bigger case that contains the earlier one.
	var bigger: Dictionary = Connections.cases(_fake_run(more), item_list, values, none, [first, {"key": "bigger", "presenter": "n", "day": 3, "cards": ["a", "b", "c"]}], 3)
	check(bigger.entries.map(func(e): return e.key) == ["bigger"] and is_equal_approx(bigger.lean.x, 0.8 * 1.4), "a bigger case that holds it carries the whole set at today's weight (%+.3f)" % bigger.lean.x)
	# Three in a row: each takes the last one's place.
	var chain: Dictionary = Connections.cases(_fake_run(more), item_list, values, none, [first, {"key": "second", "presenter": "n", "day": 2, "cards": ["b", "c"]}, {"key": "third", "presenter": "n", "day": 3, "cards": ["a", "b", "c"]}], 3)
	check(chain.entries.map(func(e): return e.key) == ["third"] and "first" in chain.entries[0].replaces and "second" in chain.entries[0].replaces, "and a third takes the place of both")
	# Sharing some cards: nothing again for the shared ones.
	var wide: Dictionary = {"key": "wide", "presenter": "n", "day": 2, "cards": ["a", "b", "c"]}
	var part: Dictionary = Connections.cases(_fake_run(more.merged({"b,c,own": 2.0})), item_list, values, none, [wide, {"key": "part", "presenter": "n", "day": 3, "cards": ["b", "c", "own"]}], 3)
	check(part.entries.map(func(e): return e.key) == ["wide", "part"] and part.entries[1].shared == 2, "a case sharing only some cards with an earlier one counts beside it")
	check(is_equal_approx(part.entries[1].lean.x, 0.8 * ((2.0 - 1.0 + 0.3 - 0.1) - 0.6)), "and adds only what involves a card new from that presenter (%+.3f)" % part.entries[1].lean.x)
	var one: Dictionary = Connections.cases(_fake_run(more), item_list, values, none, [first, {"key": "one", "presenter": "n", "day": 3, "cards": ["a", "b"]}], 3)
	check(is_equal_approx(one.entries[1].lean.x, 0.8 * 0.6) and one.entries[1].shared == 1, "one shared card takes nothing off: what it says next to a new card is new")
	var inside: Dictionary = Connections.cases(_fake_run(more), item_list, values, none, [wide, {"key": "inside", "presenter": "n", "day": 3, "cards": ["b", "c"]}], 3)
	check(inside.entries.size() == 2 and inside.entries[1].lean.is_empty(), "a smaller case made only of an earlier one's cards adds nothing")
	# Another presenter's case is its own.
	var other: Dictionary = Connections.cases(_fake_run(more), item_list, values, none, [first, {"key": "theirs", "presenter": "player", "day": 3, "cards": ["b", "c"]}], 3)
	check(other.entries.size() == 2 and is_equal_approx(other.entries[1].lean.x, 0.6 * 0.6), "the same cards from another presenter count as that presenter's case")
	# With the core: a shared part the core already holds isn't taken off a second time.
	var core: Dictionary = {"seed": ["own"], "members": ["a"], "lean": {"x": 0.5}, "impossible": false}
	var merged: Dictionary = Connections.cases(_fake_run(more), item_list, values, core, [
		{"key": "m1", "presenter": "n", "day": 2, "cards": ["a", "b"]}, {"key": "m2", "presenter": "n", "day": 3, "cards": ["b", "c"]}], 3)
	check(merged.entries[1].merged and is_equal_approx(merged.entries[1].lean.x, 0.8 * (1.3 - 1.1)), "with the core, a later case still adds what it brings on top of the grown set (%+.3f)" % merged.entries[1].lean.x)


## A stand-in for a refresh's working state: every judgement the cases ask for is already
## in its memo, so the arithmetic is checked on chosen numbers (all on person x).
func _fake_run(leans: Dictionary) -> Dictionary:
	var run: Dictionary = {"others": ["x", "y"], "baseline": {"x": 0.3, "y": 0.3}, "memo": {}, "judgements": 0, "by_id": {},
		"listener": {"id": "me", "trust": 0.5, "player_credibility": 0.6, "npc_trust": {"n": 0.8}, "knowledge": {}, "suspicion": {}}}
	for key in leans:
		var ids: Array = Array(key.split(","))
		ids.sort()
		run.memo[",".join(PackedStringArray(ids))] = {"lean": {"x": float(leans[key]), "y": 0.0}, "chance": {"x": 0.3, "y": 0.3}, "impossible": false}
	return run


func _arithmetic() -> void:
	var item_list: Array = _items().filter(func(it): return it.key in ["movement", "own", "a", "b", "c"])
	var values: Dictionary = {"movement": {"lean": {"x": 0.9}, "impossible": false}, "own": {"lean": {"x": 1.0}, "impossible": false},
		"a": {"lean": {"x": 0.2}, "impossible": false}, "b": {"lean": {"x": -0.3}, "impossible": false}, "c": {"lean": {"x": 0.1}, "impossible": false}}
	var core: Dictionary = {"seed": ["own"], "members": ["a"], "lean": {"x": 0.5}, "impossible": false}
	var leans: Dictionary = {"own": 1.0, "a": 0.2, "b": -0.3, "c": 0.1, "m1": 0.4,
		"b,c": 0.4,            # b and c together: +0.6 beyond -0.3 + 0.1
		"a,own": 1.7,          # the core alone: 0.5 beyond 1.0 + 0.2
		"a,b,own": 2.0,        # the core with b: 1.1 beyond 1.0 + 0.2 - 0.3
		"a,b,c,own": 2.3,      # then with c too: 1.3 beyond the four
		"c,m1": 1.0}           # c with one movement card: +0.5 beyond 0.1 + 0.4
	# One case apart from the core.
	var apart: Dictionary = Connections.cases(_fake_run(leans), item_list, values, core, [{"key": "k1", "presenter": "n", "day": 3, "cards": ["b", "c"]}], 3)
	check(apart.entries.size() == 1 and not apart.entries[0].merged and apart.entries[0].cards == 2, "a case that shares nothing with the core is judged by itself")
	check(is_equal_approx(apart.lean.x, 0.8 * 0.6), "it adds what its cards say together beyond their own values, at its weight (%+.3f)" % apart.lean.x)
	check(not apart.lean.has("y"), "and nothing on a person its cards say nothing more about")
	# The same case a day old, and hedged.
	var faded: Dictionary = Connections.cases(_fake_run(leans), item_list, values, core, [{"key": "k1", "presenter": "n", "day": 2, "cards": ["b", "c"], "suspicious": true}], 3)
	check(is_equal_approx(faded.lean.x, 0.8 * 0.5 * 0.5 * 0.6), "a day later under a \"suspicious\" premise it adds a quarter of that")
	# A case that shares a card with the core.
	var joined: Dictionary = Connections.cases(_fake_run(leans), item_list, values, core, [{"key": "k2", "presenter": "player", "day": 3, "cards": ["a", "b"]}], 3)
	check(joined.entries[0].merged and joined.entries[0].cards == 3, "a case that shares a card with the core is judged with the core as one set")
	check(is_equal_approx(joined.lean.x, 0.6 * (1.1 - 0.5)), "the core's own part isn't counted again: the case adds what it brings on top, at its weight (%+.3f)" % joined.lean.x)
	# Two cases: the older merges first, and the newer is measured on top of it.
	var both: Dictionary = Connections.cases(_fake_run(leans), item_list, values, core, [
		{"key": "newer", "presenter": "n", "day": 3, "cards": ["b", "c"]}, {"key": "older", "presenter": "player", "day": 2, "cards": ["a", "b"]}], 3)
	check(both.entries.map(func(e): return e.key) == ["older", "newer"] and both.entries[1].merged, "older cases merge first; a later case that meets the grown set joins it")
	check(is_equal_approx(both.entries[0].lean.x, 0.3 * (1.1 - 0.5)) and is_equal_approx(both.entries[1].lean.x, 0.8 * (1.3 - 1.1)), "each adds what it brings on top of what was already together (%+.3f, %+.3f)" % [both.entries[0].lean.x, both.entries[1].lean.x])
	# A card cited from an always-on connection.
	var cited: Dictionary = Connections.cases(_fake_run(leans), item_list, values, core, [{"key": "k3", "presenter": "n", "day": 3, "cards": ["c", "m1"]}], 3)
	check(not cited.entries[0].merged and is_equal_approx(cited.lean.x, 0.8 * 0.5), "a card cited from the movement connection adds only what it does next to the case's other cards (%+.3f)" % cited.lean.x)
	# A core that holds the movement connection counts a cited movement card where it sits.
	var moving: Dictionary = {"seed": ["movement", "own"], "members": [], "lean": {"x": 0.25}, "impossible": false}
	var held: Dictionary = Connections.cases(_fake_run(leans.merged({"m1,m2,own": 2.15, "c,m1,m2,own": 2.5})), item_list, values, moving, [{"key": "k4", "presenter": "n", "day": 3, "cards": ["own", "c", "m1"]}], 3)
	check(held.entries[0].merged and is_equal_approx(held.lean.x, 0.8 * ((2.5 - 0.9 - 1.0 - 0.1) - 0.25)), "a cited card that already sits in the core's movement connection isn't taken off twice (%+.3f)" % held.lean.x)
	# Two cards cited from the movement connection: it already weighs them together.
	var night_only: Dictionary = Connections.cases(_fake_run(leans.merged({"m1,m2": 1.6})), item_list, values, core, [{"key": "k7", "presenter": "n", "day": 3, "cards": ["m1", "m2"]}], 3)
	check(night_only.entries.size() == 1 and night_only.lean.is_empty() and night_only.entries[0].cards == 2, "a case of cards the movement connection holds adds nothing for their meeting each other")
	var night_and: Dictionary = Connections.cases(_fake_run(leans.merged({"m1,m2": 1.6, "c,m1,m2": 2.4})), item_list, values, core, [{"key": "k8", "presenter": "n", "day": 3, "cards": ["m1", "m2", "c"]}], 3)
	check(is_equal_approx(night_and.lean.x, 0.8 * (2.4 - 1.6 - 0.1)), "with another card it adds what the night cards, as the movement connection reads them, say next to that card (%+.3f)" % night_and.lean.x)
	_reuse(item_list, values, leans)
	# Nothing stored, a single card, an impossible set.
	check(Connections.cases(_fake_run(leans), item_list, values, core, [], 3).entries.is_empty(), "no stored case, nothing added")
	var single: Dictionary = Connections.cases(_fake_run(leans), item_list, values, core, [{"key": "k5", "presenter": "n", "day": 3, "cards": ["c"]}], 3)
	check(single.entries.size() == 1 and single.lean.is_empty(), "a case of one card adds nothing beyond that card's own value")
	var clash_run: Dictionary = _fake_run(leans)
	clash_run.memo["b,c"] = {"lean": {}, "chance": {}, "impossible": true}
	var clash: Dictionary = Connections.cases(clash_run, item_list, values, core, [{"key": "k6", "presenter": "n", "day": 3, "cards": ["b", "c"]}], 3)
	check(clash.entries[0].get("impossible", false) and clash.lean.is_empty(), "cards no world allows together add nothing as a case")
	var broken: Dictionary = Connections.cases(_fake_run(leans.merged({"a,b": -0.1})), item_list, values, core.merged({"impossible": true}, true), [{"key": "k2", "presenter": "player", "day": 3, "cards": ["a", "b"]}], 3)
	check(not broken.entries[0].merged, "a core that doesn't fit together is not merged with")


# ------------------------------------------------------------ the player's presentations

func _game():
	LiveActivity.cache.clear()
	Caches.clear_all()
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.trust = 0.7
		p.credibility = 0.7
		p.trust_at_reconsider = 0.7
		for id in p.suspicion:
			p.suspicion[id] = 0.25
			p.npc_trust[id] = 1.0
	var n = g.w.npcs[0]
	n.alignment = "good"
	n.role = "warden"
	n.traits.insight = 0.5
	n.traits.confidence = 0.5
	n.workshop_state["reasoning_mode"] = "full"
	g.w.day = 2
	return g


func _read(g, source, role: String, day: int, data: Dictionary) -> int:
	var number: int = g.add_card({"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 3 if role == "seer" else 0, "data": data, "text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})
	_texts[number] = g.board[number - 1].text
	return number


var _texts: Dictionary = {}


func _node(model, view, number: int) -> String:
	var card_id: String = ""
	for c in view.cards:
		if c.get("number", -1) == number or c.get("n", -1) == number:
			card_id = c.id
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and (nd.card == card_id or Solver.card_by_id(view, nd.card).get("text", "") == str(_texts.get(number, ""))):
			return id
	return ""


## File a case: premise (type, target) with `support` cards and, optionally, a challenge
## (mode) on `challenged` grounded by `grounds`. Returns its board number.
func _file(g, type: String, target: String, support: Array, challenged: int = 0, mode: String = "", grounds: Array = []) -> int:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(target, type, Vector2(400, 40))
	for number in support:
		model.connect_cards(_node(model, view, number), premise)
	if challenged > 0:
		model.add_modifier(_node(model, view, challenged), mode)
		var challenge: String = model.selected
		for number in grounds:
			model.connect_cards(_node(model, view, number), challenge)
		model.connect_cards(challenge, premise)
	return Live.file(g, model.compile(premise))


func _proposal(g, n) -> Dictionary:
	return g._workshop_evaluations.get(n.id + ":good", {}).get("proposal", {}).duplicate(true)


func _card_id(g, n, number: int) -> String:
	for c in g._workshop_plans.get(n.id + ":good", {}).get("prepared", {}).get("view", {}).get("cards", []):
		if str(c.get("text", "")) == str(_texts.get(number, "?")):
			return c.id
	return ""


## Each chance is the baseline plus every item's lean, the core's and the cases', plus the
## common shift.
func _adds_up(c: Dictionary) -> bool:
	for id in c.posterior:
		var total: float = float(c.core.lean.get(id, 0.0)) + float(c.cases.lean.get(id, 0.0))
		for it in c.items:
			total += float(it.lean.get(id, 0.0))
		var settled: bool = c.baseline[id] <= Connections.FIXED or c.baseline[id] >= 1.0 - Connections.FIXED
		var want: float = c.baseline[id] if settled else Connections.chance(Connections.logit(c.baseline[id]) + total + float(c.shift))
		if c.core.proved.has(id):
			want = float(c.core.proved[id])
		if absf(want - float(c.posterior[id])) > 1e-9:
			return false
	return true


## A Seer "yes" on p3 and p4 with a Dowser clearing p4, presented as "p3 is <type>".
func _seer_case(type: String, on: bool) -> Dictionary:
	Connections.enabled = on
	var g = _game()
	var n = g.w.npcs[0]
	var p: Array = g.w.npcs
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var dowser: int = _read(g, p[5], "dowser", 1, {"group": [p[4].id], "count": 0})
	var filed: int = _file(g, type, p[3].id, [seer, dowser])
	var reply: Dictionary = g._evaluate_deduction(n, g.board[filed - 1], 1.0, false)
	return {"g": g, "n": n, "p": p, "filed": filed, "seer": seer, "dowser": dowser, "reply": reply, "proposal": _proposal(g, n)}


func _presented() -> void:
	var s: Dictionary = _seer_case("evil", true)
	var c: Dictionary = s.proposal.get("connections", {})
	check(s.filed > 0 and not c.is_empty(), "a filed case presented to a listener is assessed with the model on")
	if c.is_empty():
		return
	var entries: Array = c.cases.entries
	var plan: Dictionary = s.g._workshop_plans[s.n.id + ":good"]
	var listener: Dictionary = plan.prepared.listener
	check(entries.size() == 1 and entries[0].key == "case:%d" % s.filed and entries[0].presenter == "player" and entries[0].day == int(s.g.w.day),
		"the presentation is one stored case: the player's, dated today (%s)" % str(entries.map(func(e): return [e.key, e.presenter, e.day])))
	if entries.size() != 1:
		return
	var stored: Dictionary = listener.connections.cases[0]
	var seer_id: String = _card_id(s.g, s.n, s.seer)
	var dowser_id: String = _card_id(s.g, s.n, s.dowser)
	check(seer_id != "" and seer_id in stored.cards and dowser_id in stored.cards and stored.type == "evil" and stored.target == s.p[3].id and not stored.suspicious,
		"it carries its own cards, premise and target")
	check(is_equal_approx(entries[0].weight, Connections.presenter_trust(listener, "player")) and entries[0].weight > 0.0, "it weighs at the listener's trust in the player (%.3f)" % entries[0].weight)
	check(entries[0].cards >= 2 and not entries[0].lean.is_empty(), "its two readings are judged together and say more together than apart (%s)" % str(entries[0].lean))
	print("NOTE: the Seer's pair with one of the two cleared: together they add %+.3f on the other beyond their own values" % float(entries[0].lean.get(s.p[3].id, 0.0)))
	check(_adds_up(c), "each chance is the baseline plus every item's lean, the core's and the cases', plus the common shift")
	check(c.items.any(func(it): return seer_id in it.cards) and c.items.any(func(it): return dowser_id in it.cards), "the cards it brought are held, and count alone as well")
	# Spillover damping is off; with the model off it is there.
	check(Shared.premise_shaping(plan, s.n.workshop_state.presentations, s.n.workshop_state.get("withdrawn", {}), 0.5).is_empty(), "no spillover damping: the case is weighed as its own cards")
	var off: Dictionary = _seer_case("evil", false)
	var off_plan: Dictionary = off.g._workshop_plans[off.n.id + ":good"]
	check(not off.proposal.has("connections") and not off_plan.prepared.listener.has("connections") and not off.n.workshop_state.has("connections"), "with the model off, nothing of it is there")
	check(not Shared.premise_shaping(off_plan, off.n.workshop_state.presentations, off.n.workshop_state.get("withdrawn", {}), 0.5).is_empty(), "and today's damping applies to the same presentation")
	# A "suspicious" premise halves the case.
	var hedged: Dictionary = _seer_case("suspicious", true)
	var h: Array = hedged.proposal.get("connections", {}).get("cases", {}).get("entries", [])
	check(h.size() == 1 and is_equal_approx(h[0].weight, entries[0].weight * Tuning.Workshop.SUSPICIOUS_HEARING), "a \"suspicious\" premise halves the case's weight (%.3f)" % (h[0].weight if h.size() == 1 else -1.0))
	if h.size() == 1:
		check(absf(float(h[0].lean.get(hedged.p[3].id, 0.0)) - 0.5 * float(entries[0].lean.get(s.p[3].id, 0.0))) < 1e-6, "and so what it adds")
	Connections.enabled = false


## In a game: the same two cards put to the listener again under another premise.
func _reuse_in_game() -> void:
	var s: Dictionary = _seer_case("evil", true)
	var g = s.g
	var n = s.n
	var first: Array = s.proposal.get("connections", {}).get("cases", {}).get("entries", [])
	var again: int = _file(g, "suspicious", s.p[4].id, [s.seer, s.dowser])
	g._evaluate_deduction(n, g.board[again - 1], 1.0, false)
	var now: Array = _proposal(g, n).get("connections", {}).get("cases", {}).get("entries", [])
	check(first.size() == 1 and now.size() == 1 and now[0].key == "case:%d" % again and now[0].replaces == ["case:%d" % s.filed],
		"in a game, the same cards under a second premise take the first case's place (%s)" % str(now.map(func(e): return e.key)))
	check(now.size() == 1 and is_equal_approx(now[0].weight, first[0].weight * Tuning.Workshop.SUSPICIOUS_HEARING), "and count once, at the second case's weight (%.2f, was %.2f)" % [now[0].weight if now.size() == 1 else -1.0, first[0].weight if first.size() == 1 else -1.0])
	check(n.workshop_state.presentations.size() == 2, "both presentations are still remembered; only the weighing changes")
	Connections.reuse_rule = false
	g._workshop_evaluations.clear()  # a kept refresh doesn't know the switch moved
	Mind.refresh_beliefs(g.w, n, " (rule off)")
	check(_proposal(g, n).connections.cases.entries.size() == 2, "with the rule off (the measurement switch) both count, as before")
	Connections.reuse_rule = true
	Connections.enabled = false


func _fading_and_repeat() -> void:
	var s: Dictionary = _seer_case("evil", true)
	var g = s.g
	var n = s.n
	var first: Array = s.proposal.get("connections", {}).get("cases", {}).get("entries", [])
	if first.size() != 1:
		check(false, "the fading fixture stores its case")
		return
	var again: Dictionary = g._evaluate_deduction(n, g.board[s.filed - 1], 1.0, false)
	check(again.get("repeated", false), "the same case again the same day is still waved off as a repeat")
	check(not WorkshopPresentation.faded(g, g.board[s.filed - 1]), "and at a meeting it is still \"already public knowledge\"")
	g.w.day += 1
	check(WorkshopPresentation.faded(g, g.board[s.filed - 1]), "a day later it has faded, so putting it to the town again is assessed")
	Mind.refresh_beliefs(g.w, n, " (next day)")
	var later: Array = _proposal(g, n).get("connections", {}).get("cases", {}).get("entries", [])
	check(later.size() == 1 and later[0].day == first[0].day and later[0].weight < first[0].weight and absf(later[0].weight / maxf(0.001, Connections.presenter_trust(g._workshop_plans[n.id + ":good"].prepared.listener, "player")) - 0.5) < 1e-6,
		"a day later the case counts at half its presenter's trust (%.3f)" % (later[0].weight if later.size() == 1 else -1.0))
	var restored: Dictionary = g._evaluate_deduction(n, g.board[s.filed - 1], 1.0, false)
	var back: Array = _proposal(g, n).get("connections", {}).get("cases", {}).get("entries", [])
	check(not restored.is_empty() and back.size() == 1 and back[0].day == int(g.w.day) and is_equal_approx(back[0].weight, Connections.presenter_trust(g._workshop_plans[n.id + ":good"].prepared.listener, "player")),
		"presenting it again on a later day restores its weight, and no more (%.3f)" % (back[0].weight if back.size() == 1 else -1.0))
	check(n.workshop_state.presentations.size() == 1, "it is still one stored case")
	g.w.day += 5
	Mind.refresh_beliefs(g.w, n, " (five days on)")
	var gone: Dictionary = _proposal(g, n).get("connections", {})
	check(gone.cases.entries.is_empty() and gone.cases.lean.is_empty(), "five days on it no longer counts")
	check(gone.items.any(func(it): return _card_id(g, n, s.seer) in it.cards), "but the cards it brought are still held at their own value")
	Connections.enabled = false
	# With the model off a later-day repeat is what it always was.
	var off: Dictionary = _seer_case("evil", false)
	off.g.w.day += 1
	check(not WorkshopPresentation.faded(off.g, off.g.board[off.filed - 1]) and off.g._evaluate_deduction(off.n, off.g.board[off.filed - 1], 1.0, false).get("repeated", false), "with the model off, a later repeat is waved off as before")


## A Seer "yes" on p3 and p4, both cleared by Dowsers, and someone seen out that night;
## presented as "p1 is evil", with or without a challenge on the Seer's reading.
func _challenge_case(mode: String, listener_role: String = "warden") -> Dictionary:
	Connections.enabled = true
	var g = _game()
	var n = g.w.npcs[0]
	n.role = listener_role
	var p: Array = g.w.npcs
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var d1: int = _read(g, p[5], "dowser", 1, {"group": [p[3].id], "count": 0})
	var d2: int = _read(g, p[6], "dowser", 1, {"group": [p[4].id], "count": 0})
	var seen: int = g.add_card({"kind": "sighting", "subject": [p[1].id], "day": 1, "phase": 3, "source": p[6].id, "block": p[1].home_block,
		"text": "%s saw %s out on night 1." % [p[6].name, p[1].name]})
	_texts[seen] = g.board[seen - 1].text
	var target: String = p[1].id if mode != "lying" else p[2].id
	var filed: int = _file(g, "evil", target, [seer, d1, d2, seen], seer if mode != "" else 0, mode, [d1, d2] if mode != "" else [])
	g._evaluate_deduction(n, g.board[filed - 1], 1.0, false)
	return {"g": g, "n": n, "p": p, "seer": _card_id(g, n, seer), "c": _proposal(g, n).get("connections", {}), "filed": filed}


func _challenges() -> void:
	var plain: Dictionary = _challenge_case("")
	var failed: Dictionary = _challenge_case("impaired")
	# For the lie, the listener holds the gift the reader claims, so it knows it is one.
	var lying: Dictionary = _challenge_case("lying", "seer")
	var plain_seer: Dictionary = _challenge_case("", "seer")
	if plain.c.is_empty() or failed.c.is_empty() or lying.c.is_empty() or plain.c.cases.entries.size() != 1 or failed.c.cases.entries.size() != 1 or lying.c.cases.entries.size() != 1:
		check(false, "the challenge fixtures store their cases")
		return
	var value_of := func(run: Dictionary) -> Dictionary:
		for it in run.c.items:
			if run.seer in it.cards:
				return it.lean
		return {"missing": true}
	check(plain.c.cases.challenged.is_empty() and plain.c.cases.floors.is_empty(), "a case with no challenge has none to assess")
	# A failed gift: discounted inside the case, and nowhere else.
	var fr: Array = failed.c.cases.floors
	check(failed.c.cases.challenged == [failed.seer] and fr.size() == 1 and fr[0].mode == "impaired" and fr[0].card == failed.seer, "a challenge is assessed inside its own case")
	check(fr.size() == 1 and float(fr[0].multiplier) < 0.95, "two clears of the Seer's pair make a failed-gift challenge land there (reliability x %.2f)" % (float(fr[0].multiplier) if fr.size() == 1 else 1.0))
	var same_value: bool = true
	var a: Dictionary = value_of.call(plain)
	var b: Dictionary = value_of.call(failed)
	for id in a:
		if absf(float(a[id]) - float(b.get(id, 0.0))) > 1e-9:
			same_value = false
	check(same_value and a.size() == b.size() and not a.has("missing"), "the challenged reading's own value is untouched")
	var differs: bool = false
	for id in plain.c.posterior:
		if absf(float(plain.c.cases.lean.get(id, 0.0)) - float(failed.c.cases.lean.get(id, 0.0))) > 1e-6:
			differs = true
	check(differs, "what the case's cards say together changes with the challenge")
	check(_adds_up(failed.c) and _adds_up(plain.c), "the sums still hold with a challenge in the case")
	check(fr.size() == 1 and is_equal_approx(fr[0].weight, failed.c.cases.entries[0].weight) and fr[0].case == failed.c.cases.entries[0].key, "the challenge carries its case's weight")
	# The floors fade with the case.
	failed.g.w.day += 1
	Mind.refresh_beliefs(failed.g.w, failed.n, " (next day)")
	var next: Dictionary = _proposal(failed.g, failed.n).get("connections", {})
	check(next.cases.floors.size() == 1 and absf(float(next.cases.floors[0].weight) - 0.5 * float(fr[0].weight)) < 0.02, "a day later it weighs half as much (%.3f against %.3f)" % [float(next.cases.floors[0].weight) if next.cases.floors.size() == 1 else -1.0, float(fr[0].weight)])
	failed.g.w.day += 5
	Mind.refresh_beliefs(failed.g.w, failed.n, " (five days on)")
	var last: Dictionary = _proposal(failed.g, failed.n).get("connections", {})
	check(last.cases.floors.is_empty() and last.cases.challenged == [failed.seer], "once the case no longer counts, neither does its challenge, in or out of the case")
	# A lie: no reliability changes; the floor under the teller is the case's.
	var lr: Array = lying.c.cases.floors
	check(lr.size() == 1 and lr[0].mode == "lying" and lr[0].source == lying.p[2].id, "a \"lying\" challenge is assessed inside its case too")
	var c2: Dictionary = value_of.call(lying)
	var c1: Dictionary = value_of.call(plain_seer)
	var unchanged: bool = not c2.has("missing") and c1.size() == c2.size()
	for id in c1:
		if absf(float(c1[id]) - float(c2.get(id, 0.0))) > 1e-9:
			unchanged = false
	check(unchanged, "and leaves the reading's own value alone")
	if lr.size() == 1 and float(lr[0].agreement) >= Tuning.Workshop.JURY_CHALLENGE_LYING_MIN_AGR:
		var effect: Dictionary = _proposal(lying.g, lying.n).effects.get(lying.p[2].id, {})
		var floor_value: float = Tuning.Workshop.JURY_CHALLENGE_LYING_SCALE * float(lr[0].agreement) * float(lr[0].weight)
		check(float(effect.get("raw_requested", -1.0)) >= floor_value * 0.99 * (Tuning.Workshop.JURY_BELIEF_SCALE if lying.n.workshop_state.get("per_card_source_trust", false) else 0.5),
			"the floor under the reader is scaled by the case's weight (at least %.3f)" % floor_value)
	else:
		print("NOTE: the lying challenge's agreement is %.2f, under the floor's bar; the floor isn't exercised here" % (float(lr[0].agreement) if lr.size() == 1 else -1.0))
	Connections.enabled = false


## Codex's review of #146: inside a stored case, a challenged reading is also on the judged
## case's reading_challenges, as it is today, so CaseEval leaves it out of the Augur
## crossing and the Psychologist corroboration.
func _challenged_factors() -> void:
	Connections.enabled = true
	var g = _game()
	var n = g.w.npcs[0]
	var p: Array = g.w.npcs
	var aug: int = g.add_card({"kind": "info", "source": p[2].id, "role": "augur", "day": 1, "phase": 2, "data": {"yes": true},
		"text": "%s augur day 1: crossed the Demon" % p[2].id})
	_texts[aug] = g.board[aug - 1].text
	var seen: int = g.add_card({"kind": "sighting", "subject": [p[3].id], "day": 1, "phase": 1, "source": p[4].id, "block": p[2].home_block,
		"text": "%s saw %s near %s's home on day 1." % [p[4].name, p[3].name, p[2].name]})
	_texts[seen] = g.board[seen - 1].text
	var filed: int = _file(g, "evil", p[3].id, [aug, seen])
	g._evaluate_deduction(n, g.board[filed - 1], 1.0, false)
	var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
	var view: Dictionary = plan.get("prepared", {}).get("view", {})
	var listener: Dictionary = plan.get("prepared", {}).get("listener", {})
	var aug_id: String = _card_id(g, n, aug)
	var ids: Array = view.get("cards", []).filter(func(c): return c.id == aug_id or c.get("kind", "") == "location").map(func(c): return c.id)
	if aug_id == "" or ids.size() < 2:
		check(false, "the Augur fixture has its reading and a day card (%s, %d cards)" % [aug_id, ids.size()])
		Connections.enabled = false
		return
	var run: Dictionary = Connections.begin(view, {}, listener)
	var by_id: Dictionary = {}
	for c in view.cards:
		by_id[c.id] = c
	run["by_id"] = by_id
	var challenges: Dictionary = {aug_id: {"mode": "lying", "supports": []}}
	var got: Dictionary = Connections.lean_challenged(run, ids, challenges)
	var marked: Dictionary = run.bare.duplicate(true)
	marked["reading_challenges"] = challenges.duplicate(true)
	var want: Dictionary = Connections.judge(view, marked, listener, ids)
	var plain: Dictionary = Connections.judge(view, run.bare, listener, ids)
	var same := true
	var moved := false
	for q in run.others:
		var w_: float = float(want.people.get(q, {}).get("posterior", run.baseline[q]))
		if absf(float(got.chance.get(q, -1.0)) - w_) > 1e-9:
			same = false
		if absf(w_ - float(plain.people.get(q, {}).get("posterior", run.baseline[q]))) > 1e-6:
			moved = true
	check(same, "a challenged reading inside a case is judged with the case's reading_challenges, as today")
	print("NOTE: on this fixture the Augur crossing %s once its reading is challenged" % ("changes the judgement" if moved else "doesn't move anyone"))
	# Codex's second finding: storing a nomination case queues each listener's refresh, so a
	# silenced nominee (no defence to refresh anyone) can't leave the vote on old beliefs.
	g.w.defer_beliefs = true
	g.w.pending_beliefs = []
	preload("res://sim/mind_meeting.gd").remember_nomination(g.w, p[1], p[3].id, [aug_id])
	var queued: Array = g.w.pending_beliefs.map(func(e): return e[0].id)
	var want_ids: Array = g.w.living().filter(func(l): return l.id != p[1].id).map(func(l): return l.id)
	queued.sort()
	want_ids.sort()
	check(queued == want_ids, "storing a nomination case queues a refresh for every listener but the nominator (%d of %d)" % [queued.size(), want_ids.size()])
	g.w.defer_beliefs = false
	g.w.pending_beliefs = []
	Connections.enabled = false


# ------------------------------------------------------------ NPC nominators' cases, in play

func _nominations(seed_v: int, npcs: int, day: int) -> void:
	Connections.enabled = true
	LiveActivity.cache.clear()
	Caches.clear_all()
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
	var tag: String = "seed %d, model on" % seed_v
	if g.state != "meeting":
		check(false, "%s reaches the day-%d meeting" % [tag, day])
		return
	var nominated: Array = g.w.public_log.filter(func(e): return e.kind == "nomination" and str(e.get("by", "")) != "player")
	var stored := 0
	var counted := 0
	var well_formed := true
	var own_kept := false
	var twice := false
	for n in g.w.living().filter(func(x): return not x.is_evil()):
		var store: Array = n.workshop_state.get("connections", {}).get("nominations", [])
		stored += store.size()
		var seen: Dictionary = {}
		for cs in store:
			if str(cs.presenter) == n.id:
				own_kept = true
			if cs.cards.is_empty() or int(cs.day) > int(g.w.day) or str(cs.type) != "evil" or not g.w.by_id.has(str(cs.target)) or not g.w.by_id.has(str(cs.presenter)):
				well_formed = false
			var slot: String = "%s>%s" % [cs.presenter, cs.target]
			if seen.has(slot):
				twice = true
			seen[slot] = true
		var was_defer: bool = g.w.defer_beliefs
		g.w.defer_beliefs = false
		Mind.refresh_beliefs(g.w, n, " (test)")
		g.w.defer_beliefs = was_defer
		var c: Dictionary = _proposal(g, n).get("connections", {})
		if c.is_empty():
			continue
		counted += c.cases.entries.size()
		check(_adds_up(c), "%s %s: each chance is the baseline plus the items, the core and %d stored cases, plus the common shift" % [tag, n.id, c.cases.entries.size()])
		check(c.cases.entries.all(func(e): return e.weight >= Connections.CASE_FLOOR and e.weight <= 1.0 and e.presenter != n.id), "%s %s: every counted case has a weight between the floor and full trust" % [tag, n.id])
		if not c.cases.entries.is_empty():
			check(Connections.summary(c).get("cases", []).size() == c.cases.entries.size(), "%s %s: the trace carries the cases" % [tag, n.id])
	check(not nominated.is_empty() and stored > 0, "%s: NPC nominators' cited cards are kept by the town (%d nominations, %d stored cases)" % [tag, nominated.size(), stored])
	check(well_formed and not own_kept and not twice, "%s: each has its nominator, target, cards and day; nobody stores its own; one per nominator and target" % tag)
	check(counted > 0, "%s: some of them count in a refresh (%d)" % [tag, counted])
	Connections.enabled = false
