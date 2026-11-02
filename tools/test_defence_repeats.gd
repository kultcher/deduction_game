extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
var checks = 0
var fails = 0

func _init() -> void:
	for size in [7, 10]:
		_reveal(size)
		_challenges(size)
		_plea(size)
	print("Defence repeats: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(size: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7350, size)
	g.w.day = 4
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener == null:
				continue
			listener.info_log = []
			listener.ledger = {}
			listener.beliefs = []
			listener.known_claims = {}
			listener.cleared = {}
			listener.traits.confidence = 0.5
			for id in listener.suspicion:
				listener.suspicion[id] = 0.1
			Mind.refresh_beliefs(g.w, listener, " (clean)")
	return g

func _reveal(size: int) -> void:
	var g = _game(size)
	var w = g.w
	var goods: Array = w.living_good()
	var d = goods[0]
	var accuser = goods[1]
	var listener = goods[2]
	var v1 = goods[3]
	v1.home_block = "docks"
	d.home_block = "square"
	accuser.home_block = "docks"
	w.day = 1
	w._kill(v1)
	w.day = 4
	d.role = "lamplighter"
	d.claimed_role = "lamplighter"
	d.claim_public = true
	listener.npc_trust[d.id] = 0.95
	accuser.beliefs = [{"kind": "saw", "who": d.id, "loc": "", "block": "docks", "day": 1, "phase": 3, "how": "window", "detail": "street"}]
	Mind.refresh_beliefs(w, accuser, " (first outing)")
	var rng = w.rng.state
	var first = Mind.defend_self(w, d, accuser.id)
	var defs1: Array = _defences(listener)
	check(first.moves == ["reveal"] and defs1.size() == 1 and defs1[0].effects.is_empty(), "a first gift defence records one receipt-only defence entry")
	var w1: float = defs1[0].weight
	var once = listener.suspicion.duplicate(true)
	w.day += 1
	Mind.defend_self(w, d, accuser.id)
	check(listener.suspicion == once and _defences(listener).size() == 1 and is_equal_approx(_defences(listener)[0].weight, w1), "repeating the same gift explanation tomorrow adds no second discount or weight")
	# Lowering trust while re-defending cannot overwrite a stronger prior hearing weight.
	listener.npc_trust[d.id] = 0.05
	Mind.defend_self(w, d, accuser.id)
	check(_defences(listener).size() == 1 and is_equal_approx(_defences(listener)[0].weight, w1), "one owner keeps the strongest complete hearing weight")
	for n in w.living():
		if n == d:
			continue
		var cover = n.shadow if n.is_evil() else n
		check(_defences(cover).size() == 1 and _defences(cover)[0].meta.scope == {"type": "gift_claim", "role": "lamplighter"}, "stable defence ownership reaches " + n.id)
	check(w.rng.state == rng, "repeat identity introduces no RNG draws")

func _challenges(size: int) -> void:
	var g = _game(size)
	var w = g.w
	var source = w.living_good()[0]
	var d = w.living_good()[1]
	var observer = w.living_good()[2]
	var other = w.living_good()[3]
	d.role = "surveyor"
	d.secret = {}
	d.traits.confidence = 0.7
	source.role = "seer"
	source.claimed_role = "seer"
	source.claim_public = true
	var reading = {"day": 0, "role": "seer", "data": {"pair": [d.id, other.id], "yes": true}, "text": "One reads as the Demon", "shared": true}
	source.info_log = [reading]
	Mind.apply_info(w, source, source, reading, 1.0)
	Mind.apply_info(w, observer, source, reading, 0.5)
	d.suspicion[other.id] = 0.6
	d.suspicion[source.id] = 0.2
	var first = Mind.defend_self(w, d, source.id)
	check("pair_other" in first.moves and not ("lying" in first.moves) and not ("misled" in first.moves), "suspecting the other more, a named pair gets the rival explanation only")
	var once = observer.suspicion.duplicate(true)
	w.day += 1
	Mind.defend_self(w, d, source.id)
	check(observer.suspicion == once and _defences(observer).size() == 1, "the same rival does not stack on the next day")
	var g2 = _game(size)
	var w2 = g2.w
	var source2 = w2.living_good()[0]
	var d2 = w2.living_good()[1]
	var observer2 = w2.living_good()[2]
	var other2 = w2.living_good()[3]
	d2.role = "surveyor"
	d2.secret = {}
	d2.traits.confidence = 0.7
	source2.role = "seer"
	source2.claimed_role = "seer"
	source2.claim_public = true
	var reading2 = {"day": 0, "role": "seer", "data": {"pair": [d2.id, other2.id], "yes": true}, "text": "One reads as the Demon", "shared": true}
	source2.info_log = [reading2]
	Mind.apply_info(w2, source2, source2, reading2, 1.0)
	Mind.apply_info(w2, observer2, source2, reading2, 0.5)
	d2.suspicion[other2.id] = 0.1
	d2.suspicion[source2.id] = 0.5
	var second = Mind.defend_self(w2, d2, source2.id)
	check("lying" in second.moves and not ("pair_other" in second.moves), "trusting the other more, a confident nominee says the reading is a lie, and only that")
	var once2 = observer2.suspicion.duplicate(true)
	w2.day += 1
	Mind.defend_self(w2, d2, source2.id)
	check(observer2.suspicion == once2 and _defences(observer2).size() == 1, "the same challenge does not stack on the next day")
	var challenges = _defences(observer2).filter(func(entry): return entry.meta.scope.type == "challenge")
	check(challenges.size() == 1 and challenges[0].meta.scope.reading == Shared.reading(source2.id, reading2).id, "a challenge is bound to the exact original reading")
	source2.ledger.erase(Mind.info_eid(source2.id, reading2))
	var new_reading = reading2.duplicate(true)
	new_reading.day = 1
	source2.info_log = [new_reading]
	Mind.apply_info(w2, source2, source2, new_reading, 1.0)
	Mind.apply_info(w2, observer2, source2, new_reading, 0.5)
	Mind.defend_self(w2, d2, source2.id)
	challenges = _defences(observer2).filter(func(entry): return entry.meta.scope.type == "challenge")
	check(challenges.size() == 2 and challenges.any(func(entry): return entry.meta.scope.reading == Shared.reading(source2.id, new_reading).id), "a genuinely different original report has a distinct challenge")

func _plea(size: int) -> void:
	var g = _game(size)
	var w = g.w
	var d = w.living_good()[0]
	var observer = w.living_good()[1]
	d.role = "surveyor"
	d.secret = {}
	d.claim_public = false
	for day in range(1, 100):
		w.day = day
		if Mind._afraid(w, d):
			break
	var first = Mind.defend_self(w, d, "player")
	check(first.moves == ["fear"], "an undisclosed afraid nominee gives the fear wording")
	var once = observer.suspicion.duplicate(true)
	w.day += 1
	d.claim_public = true
	var second = Mind.defend_self(w, d, "player")
	check(second.moves == ["desperation"] and observer.suspicion == once and _defences(observer).size() == 1 and _defences(observer)[0].meta.scope.type == "plea", "different plea wording remains one weak hearing across days")

func _defences(n) -> Array:
	return n.ledger.values().filter(func(entry): return entry.meta.get("kind") == "defence")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
