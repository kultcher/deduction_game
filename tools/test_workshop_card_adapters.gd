## Location adapters retain actual observation times and do not manufacture guilt.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const Activity = preload("res://workshop/live_activity.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_context()
	_evening_conversation()
	_invalid_payloads()
	_opinions_are_not_evidence()
	_totem()
	_dropped_material()
	print("Card adapters: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
		for id in p.suspicion:
			p.suspicion[id] = 0.3
	g.set_workshop_effects(true)
	return g

func _context() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	var target = g.w.npcs.filter(func(p): return p != n)[0]
	var partner = g.w.npcs.filter(func(p): return p != n and p != target)[0]
	var raw = [
		{"kind": "home", "source": "town", "subject": [target.id], "block": target.home_block, "text": "Public home"},
		{"kind": "haunt", "source": n.id, "subject": [target.id], "locs": ["tavern", "well"], "text": "Reported haunts"},
		{"kind": "sighting", "source": "player", "subject": [target.id], "block": "market", "day": 1, "phase": 0, "text": "Morning sighting"},
		{"kind": "sighting", "source": "player", "subject": [target.id], "block": "market", "day": 1, "phase": 1, "text": "Afternoon sighting"},
		{"kind": "conversation", "source": "player", "subject": [target.id, partner.id], "block": "market", "loc": "bakery", "day": 1, "phase": 0, "text": "Morning conversation"}]
	for card in raw:
		var number = g.add_card(card)
		var normalized = Shared.Evidence.normalize_card(g.board[number - 1])
		check(Shared.supported(normalized), card.kind + " has a shared owner")
		var ded = g.file_deduction({"type": "evil", "a": target.id}, [number])
		var prepared = Assess.prepare(g.workshop_snapshot([ded], n.id))
		check(prepared.ready and normalized.id in prepared.case.cards, card.kind + " remains an exact cited root")
		var result = g._evaluate_deduction(n, g.board[ded - 1], 1.0, false)
		check(result.get("workshop", false) and n.workshop_state.active and normalized.id in n.workshop_state.facts, card.kind + " uses the shared presentation path and keeps ownership after parking")
		check(n.workshop_state.requested.values().all(func(v): return absf(v) < 0.000001), card.kind + " alone is context, not alignment evidence")
		if card.kind in ["sighting", "conversation"]:
			var adapted = prepared.view.cards.filter(func(c): return c.id == normalized.id)[0]
			check(adapted.kind == "location" and adapted.night == -1 and adapted.observed_at.phase in ["morning", "afternoon"], "daylight is never treated as a night outing")
	var a = Shared.Evidence.normalize_card({"kind": "haunt", "source": n.id, "subject": [target.id], "locs": ["tavern"]})
	var b = Shared.Evidence.normalize_card({"kind": "haunt", "source": n.id, "subject": [target.id], "locs": ["chapel"]})
	check(a.id != b.id, "distinct structured haunt claims retain distinct original identities")

func _evening_conversation() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	var others: Array = g.w.npcs.filter(func(p): return p != n)
	var target = others[0]
	var partner = others[1]
	var victim = others[2]
	g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1, "text": "Public death"})
	var trace = g.add_card({"kind": "trace", "source": "evidence", "subject": [], "day": 1, "phase": 2,
		"material": "market", "block": "market", "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"victim": victim.id, "crime_night": 1, "text": "Market scene trace"})
	var conversation = g.add_card({"kind": "conversation", "source": "player", "subject": [target.id, partner.id],
		"day": 1, "phase": 2, "block": "market", "loc": "bakery", "text": "Evening conversation at the bakery"})
	var sighting = g.add_card({"kind": "sighting", "source": "player", "subject": [target.id, partner.id],
		"day": 1, "phase": 2, "block": "market", "text": "Both seen on the Market that evening"})
	var results: Array = []
	for number in [conversation, sighting]:
		var ded = g.file_deduction({"type": "evil", "a": target.id}, [trace, number])
		var prepared = Assess.prepare(g.workshop_snapshot([ded], n.id))
		check(prepared.ready, "evening location and trace share one supported assessment")
		if prepared.ready:
			results.append(CaseEval.evaluate(prepared.view, prepared.case, prepared.listener))
	check(results.size() == 2 and results[0].people == results[1].people, "an evening conversation has the same location likelihood as seeing the same people")

func _invalid_payloads() -> void:
	var g = _game()
	var target = g.w.npcs[0]
	var input = g.workshop_snapshot([])
	for raw in [
		{"kind": "home", "source": "town", "subject": [target.id], "block": "nowhere"},
		{"kind": "haunt", "source": "player", "subject": [target.id], "locs": ["invented-place"]},
		{"kind": "conversation", "source": "player", "subject": [target.id], "block": "market", "day": 1, "phase": 0},
		{"kind": "conversation", "source": "player", "subject": [g.w.npcs[0].id, g.w.npcs[1].id], "block": "docks", "loc": "bakery", "day": 1, "phase": 2}]:
		check(Assess.activity_card(Shared.Evidence.normalize_card(raw), input).is_empty(), "malformed " + raw.kind + " is rejected without guessing its meaning")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)

func _opinions_are_not_evidence() -> void:
	var g = _game()
	var listener = g.w.living_good()[0]
	var target = g.w.npcs.filter(func(p): return p != listener)[0]
	for kind in ["opinion", "accusation"]:
		var number = g.add_card({"kind": kind, "source": target.id, "subject": [target.id], "text": "Unsupported " + kind})
		var ded = g.file_deduction({"type": "evil", "a": target.id}, [number])
		g.state = "talk"
		g.talk_with = listener
		g.questions_left = 3
		var before = [listener.suspicion.duplicate(true), listener.trust, g.w.rng.state]
		var reply = g.command("convince %d" % ded)
		check("is not evidence" in reply and g.questions_left == 3, kind + " is rejected in ordinary play with a semantic reason")
		check(before == [listener.suspicion, listener.trust, g.w.rng.state], kind + " cannot add suspicion, rewards or random draws")

func _totem() -> void:
	var g = _game()
	var block: String = g.w.npcs[0].home_block
	var number = g.add_card({"kind": "totem", "source": "evidence", "subject": [], "block": block,
		"loc": "well", "day": 1, "phase": 0, "text": "A totem bearing its maker's home material"})
	var target = g.w.npcs[0]
	var listener = g.w.living_good().filter(func(p): return p != target)[0]
	var ded = g.file_deduction({"type": "minion", "a": target.id}, [number])
	var prepared = Assess.prepare(g.workshop_snapshot([ded], listener.id))
	check(prepared.ready and prepared.view.world_options.identities, "a valid totem activates joint minion role assignments")
	if not prepared.ready:
		return
	var cards = Solver.selected(prepared.view, prepared.case)
	var worlds = Solver.solve(prepared.view, cards).worlds
	var candidates = 0
	for i in range(prepared.view.people.size()):
		if prepared.view.people[i].home == block:
			candidates |= 1 << i
	check(not worlds.is_empty() and worlds.all(func(w): return bool((w.evil & ~(1 << w.demon)) & candidates)), "the totem requires an actual minion on its material's home block, not a Demon or Marked registration")
	var id = Shared.Evidence.normalize_card(g.board[number - 1]).id
	check(cards.size() == 1 and cards[0].id == id and cards[0].data.candidates == prepared.view.people.filter(func(p): return p.home == block).map(func(p): return p.id), "totem candidates come only from the public roster")
	var result = g._evaluate_deduction(listener, g.board[ded - 1], 1.0, false)
	check(result.get("workshop", false) and listener.workshop_state.active, "a totem case uses shared ownership through presentation")

func _dropped_material() -> void:
	var g = _game()
	var input = g.workshop_snapshot([])
	# A controlled public roster; no actual roles, owners or night movements enter.
	for i in range(input.people.size()):
		input.people[i].home = "hill" if i == 0 else "square"
	var a: String = input.people[0].id
	var b: String = input.people[1].id
	var raw = {"kind": "dropped", "source": "evidence", "subject": [], "block": "market", "loc": "bakery",
		"material": "hill", "day": 1, "phase": 3, "text": "Chalk found at the bakery"}
	var receipt = Shared.Evidence.normalize_card(raw)
	var drop = Assess.activity_card(receipt, input)
	check(Shared.supported(receipt) and drop.kind == "dropped" and not drop.has("owner"), "material drops retain the home material without inventing an owner")
	var view = {"people": input.people, "live_activity": true, "timeline": Assess.History.from_events([])}
	var routes = Activity.routes(view, [drop])
	check(routes.okay and routes.nights["1"].forced_out == [a], "a material group with one eligible resident establishes that resident was out")
	var alibi = {"id": "home:a", "kind": "alibi", "source": a, "subject": a, "night": 1, "block": "hill"}
	check(not Activity.routes(view, [drop, alibi]).okay, "a home alibi conflicts with the sole eligible material owner")
	view.people[1].home = "hill"
	routes = Activity.routes(view, [drop])
	check(routes.okay and routes.nights["1"].forced_out.is_empty(), "several eligible residents remain alternatives")
	alibi.id = "home:b"
	alibi.source = b
	alibi.subject = b
	check(Activity.routes(view, [drop, alibi]).nights["1"].forced_out == [a], "accepted independent alibis can resolve the material owner")
	var second_raw = raw.duplicate(true)
	second_raw.block = "docks"
	second_raw.loc = "wharf"
	second_raw.text = "Chalk found at the wharf"
	var second = Assess.activity_card(Shared.Evidence.normalize_card(second_raw), input)
	check(Activity.routes(view, [drop, second]).nights["1"].forced_out.size() == 2, "distinct drops require distinct walkers under the native one-drop rule")
	view.people[1].home = "square"
	check(not Activity.routes(view, [drop, second]).okay, "one resident cannot account for two different drops in one night")
	check(Activity.routes(view, [drop, drop]).okay, "quoting the same original drop twice does not invent a second item")
