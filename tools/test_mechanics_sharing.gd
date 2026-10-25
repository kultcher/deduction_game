extends SceneTree
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _init() -> void:
	var g = Game.new()
	g.new_case(44814, 10)
	g.w.dlog.detailed = false
	var goods: Array = g.w.living_good()
	var s = goods[0]
	var l = goods[1]
	var t = goods[2]
	for n in [s, l, t]:
		n.info_log = []
		n.known_claims = {}
		n.ledger = {}
		n.beliefs = []
	g.w.day = 2
	var sight = {"kind": "sighting", "about": "constance", "block": "square", "day": 1, "from": s.id, "key": "sighting:constance:1"}
	Social._deliver(g.w, s, l, sight)
	var key: String = l.ledger.keys().filter(func(id): return str(id).begins_with("heard:"))[0]
	var receipt: Dictionary = l.ledger[key].meta.workshop_card
	check(l.workshop_state.get("active", false) and l.workshop_state.owned.has(key), "NPC sighting enters shared evidence and its native effect is parked")
	check(receipt.source == s.id and receipt.provenance.via == s.id and receipt.observed_at.day == 1, "original observer, teller and observation time remain separate")
	var first: Dictionary = l.workshop_state.requested.duplicate(true)
	var heard: int = l.workshop_state.facts.size()
	l.npc_trust[s.id] -= 0.02 # Hold trust fixed; conversation itself changes the bond.
	Social._deliver(g.w, s, l, sight)
	check(l.workshop_state.facts.size() == heard and l.workshop_state.requested == first, "same sighting does not stack on repetition")
	var weak = Shared.prepare(g.workshop_snapshot([], l.id), {}, l.ledger)
	var old_weight: float = l.ledger[key].weight
	l.ledger[key].weight = 1.0
	var strong = Shared.prepare(g.workshop_snapshot([], l.id), {}, l.ledger)
	var weak_card: Dictionary = weak.prepared.view.cards.filter(func(c): return c.id == receipt.id)[0]
	var strong_card: Dictionary = strong.prepared.view.cards.filter(func(c): return c.id == receipt.id)[0]
	check(weak_card.hearing_weight < strong_card.hearing_weight and strong_card.hearing_weight == 1.0, "teller hearing weight reaches the movement model")
	var weak_paths = Solver.movement_for(weak.prepared.view, [weak_card])
	check(not weak_paths.nights["1"].forced_out.has("constance"), "weak hearsay does not force a walking role")
	l.ledger[key].weight = old_weight
	var relayed = sight.duplicate(true)
	relayed.relay = true
	relayed.key = "relay:" + sight.key
	Social._deliver(g.w, s, t, sight)
	Social._deliver(g.w, t, l, relayed)
	check(l.workshop_state.facts.count(receipt.id) == 1, "a second teller cannot create an independent copy of the observation")
	var other = sight.duplicate(true)
	other.block = "docks"
	Social._deliver(g.w, s, l, other)
	check(l.workshop_state.facts.size() == heard + 1, "different same-night contents retain distinct receipt identities")
	var report = {"role": "surveyor", "day": 0, "phase": 3, "data": {"count": 2}, "text": "Shared reading", "shared": false}
	var before_reading: int = l.workshop_state.facts.size()
	Social._deliver(g.w, s, l, {"kind": "reading", "entry": report, "from": s.id, "key": "reading:0:surveyor"})
	var reading = Shared.reading(s.id, report)
	check(l.workshop_state.facts.has(reading.id) and l.workshop_state.owned.has(Shared.reading_key(reading)), "NPC reading retains its canonical shared owner")
	var implied: Dictionary = l.ledger[Mind.claim_eid(s.id, "surveyor")].meta.workshop_card
	check(l.workshop_state.facts.size() == before_reading + 1 and implied.id == reading.id, "a relayed reading's implied gift claim reuses the same evidence receipt")
	check(implied.observed_at.day == 0 and implied.provenance.via == s.id, "the implied declaration retains original reading time and teller provenance")
	var number = g.add_card({"kind": "info", "source": s.id, "role": "surveyor", "subject": [], "day": 0, "phase": 3, "data": {"count": 2}, "text": "Shared reading"})
	var filed = g.file_deduction({"type": "evil", "a": "constance"}, [number], {}, 0, true)
	var item = {"kind": "case", "about": "constance", "card": g.board[filed - 1], "from": "player", "key": "case:" + str(filed)}
	Social._deliver(g.w, s, l, item)
	var wrappers: Array = l.ledger.keys().filter(func(id): return str(id).begins_with("relayed-case:"))
	check(wrappers.size() == 1 and l.workshop_state.owned.has(wrappers[0]), "relayed player-case wrapper is parked")
	check(l.workshop_state.facts.count(reading.id) == 1, "a relayed case reuses its already-heard reading")
	var count: int = l.workshop_state.facts.size()
	Social._deliver(g.w, s, l, {"kind": "opinion", "about": "constance", "from": s.id, "key": "opinion:constance", "why": "a feeling"})
	check(l.workshop_state.facts.size() == count, "opinions stay outside evidence")
	print("Sharing mechanics: %d checks; failures: %d" % [checks, fails])
	quit(1 if fails else 0)
