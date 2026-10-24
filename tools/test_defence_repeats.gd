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
	g.workshop_effects = false # Isolate the compatibility slice's unchanged strengths.
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
				listener.suspicion[id] = 0.3
	return g

func _reveal(size: int) -> void:
	var g = _game(size)
	var w = g.w
	var d = w.living_good()[0]
	var accuser = w.living_good()[1]
	var listener = w.living_good()[2]
	d.role = "lamplighter"
	d.claimed_role = "lamplighter"
	d.claim_public = true
	listener.npc_trust[d.id] = 0.95
	Mind.ledger_hear(w, accuser, "test:out", [[d.id, 0.1, false, "seen out at night", "seen out at night"]], 1.0)
	var before: float = listener.suspicion[d.id]
	var rng = w.rng.state
	var first = Mind.defend_self(w, d, accuser.id)
	check(first.moves == ["reveal"] and is_equal_approx(before - listener.suspicion[d.id], 0.1 * 0.975), "a first gift defence retains its original strength, regard weight and Confidence coefficient")
	for confidence in [0.2, 0.8]:
		listener.traits.confidence = confidence
		Mind.recompute_beliefs(w, listener, "check deferred Confidence coefficient")
		check(is_equal_approx(before - listener.suspicion[d.id], 0.1 * 0.975 * (1.4 - 0.8 * confidence)), "defence repeat ownership retains the existing Confidence scaling")
	listener.traits.confidence = 0.5
	Mind.recompute_beliefs(w, listener, "restore controlled Confidence")
	var once = listener.suspicion.duplicate(true)
	w.day += 1
	Mind.defend_self(w, d, accuser.id)
	check(listener.suspicion == once and _defences(listener).size() == 1, "repeating the same gift explanation tomorrow adds no second discount")
	# New evidence makes the explanation stronger, while this listener now trusts
	# the defender less. The two hearings cannot lend each other their strengths.
	listener.npc_trust[d.id] = 0.05
	Mind.ledger_hear(w, accuser, "test:another-outing", [[d.id, 0.25, false, "seen out on another night", "seen out on another night"]], 1.0)
	Mind.defend_self(w, d, accuser.id)
	check(is_equal_approx(before - listener.suspicion[d.id], 0.35 * 0.525) and _defences(listener).size() == 1, "one owner keeps the strongest complete hearing without mixing strength and trust across paths")
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
	var first = Mind.defend_self(w, d, source.id)
	check("pair_other" in first.moves and "lying" in first.moves, "a named pair produces the expected rival and lying challenge")
	var once = observer.suspicion.duplicate(true)
	w.day += 1
	Mind.defend_self(w, d, source.id)
	check(observer.suspicion == once and _defences(observer).size() == 2, "the same rival and challenge do not stack on the next day")
	var challenges = _defences(observer).filter(func(entry): return entry.meta.scope.type == "challenge")
	check(challenges.size() == 1 and challenges[0].meta.scope.reading == Shared.reading(source.id, reading).id, "a challenge is bound to the exact original reading")
	source.ledger[Mind.info_eid(source.id, reading)].weight = 0.0
	var new_reading = reading.duplicate(true)
	new_reading.day = 1
	source.info_log = [new_reading]
	Mind.apply_info(w, source, source, new_reading, 1.0)
	Mind.defend_self(w, d, source.id)
	challenges = _defences(observer).filter(func(entry): return entry.meta.scope.type == "challenge")
	check(_defences(observer).size() == 3 and challenges.size() == 2 and challenges.any(func(entry): return entry.meta.scope.reading == Shared.reading(source.id, new_reading).id), "a genuinely different original report has a distinct challenge, while the repeated rival keeps one owner")

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
