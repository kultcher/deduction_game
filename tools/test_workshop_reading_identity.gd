extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Audit = preload("res://workshop/ledger_audit.gd")
var checks = 0
var fails = 0

func _init() -> void:
	for size in [7, 10]:
		_live(size)
	print("Exact reading identity: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _live(size: int) -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, size)
	g.w.day = 2
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener != null:
				listener.info_log = []
				listener.known_claims = {}
				listener.beliefs = []
				listener.ledger = {}
				listener.workshop_state = {"enabled": true, "reasoning_mode": "full", "confidence_mode": "scale"}
	var source = g.w.living_good()[0]
	var observer = g.w.living_good()[1]
	var first = {"day": 1, "phase": 0, "role": "dowser", "data": {"group": [source.id, observer.id], "count": 1}, "text": "One evil presence"}
	var changed = first.duplicate(true)
	changed.data.count = 0
	var later = first.duplicate(true)
	later.phase = 1
	var repeated = first.duplicate(true)
	repeated.text = "The same result, described differently"
	repeated.data.group.reverse()
	repeated["true"] = false
	repeated["fake"] = true
	repeated["why"] = "referee-only annotation"
	check(Mind.info_eid(source.id, first) != Mind.info_eid(source.id, changed) and Mind.info_eid(source.id, first) != Mind.info_eid(source.id, later), "same-day changed content and observation times have different native reading identities")
	check(Mind.info_eid(source.id, first) == Mind.info_eid(source.id, repeated), "prose, unordered groups and referee annotations cannot change an original reading's identity")
	var explicitly_dated = first.duplicate(true)
	explicitly_dated.kind = "info"
	explicitly_dated.source = source.id
	explicitly_dated["when"] = {"day": 1, "phase": 1}
	check(Mind.fact_id(explicitly_dated) == Mind.info_eid(source.id, later), "a board card's explicit observation stamp has the same precedence as its canonical receipt")
	var cards: Array = []
	for reading in [first, changed, later]:
		var raw = reading.duplicate(true)
		raw.kind = "info"
		raw.source = source.id
		cards.append(g.add_card(raw))
		check(Mind.fact_id(raw) == Mind.info_eid(source.id, reading), "board and learned readings use the same exact semantic key")
	var rng = g.w.rng.state
	for n in g.w.living():
		for reading in [first, changed, later, repeated]:
			Mind.apply_info(g.w, n, source, reading, 0.5)
		var listener = n.shadow if n.is_evil() else n
		var entries: Array = listener.ledger.values().filter(func(entry): return entry.meta.get("kind") == "reading")
		check(entries.size() == 3 and entries.all(func(entry): return entry.meta.workshop_receipts.size() == 1), "distinct readings and their repeat retain three exact owners for " + n.id)
		check(listener.workshop_state.active and entries.all(func(entry): return listener.workshop_state.owned.has(entry.eid) and entry.applied.values().all(func(value): return is_zero_approx(value))), "all exact native contributions are parked before joint assessment for " + n.id)
	check(g.w.rng.state == rng, "exact identity and repeated receipt ownership draw no game RNG")
	var ded = g.file_deduction({"type": "evil", "a": observer.id}, cards)
	g.strict_evaluator = true
	for n in g.w.living():
		var response = g._evaluate_deduction(n, g.board[ded - 1], 1.0, false)
		check(response.get("workshop", false), "same-day exact receipts remain fully shared in strict presentation to " + n.id)
	var plan = Shared.prepare(g.workshop_snapshot([], observer.id), {}, observer.ledger)
	var audit = Audit.inspect(plan.input)
	check(audit.reading_entries.size() == 3 and audit.reading_entries.all(func(entry): return entry.facts.size() == 1), "ownership diagnostics resolve each exact native key without conflating its siblings")
	# A pre-migration coarse record is safe only when exactly one receipt matches.
	var original = observer.ledger[Mind.info_eid(source.id, first)].duplicate(true)
	var coarse = "info:%s:%d:%s" % [source.id, first.day, first.role]
	original.eid = coarse
	var old = {coarse: original}
	var single = Shared.prepare(g.workshop_snapshot([], observer.id), {}, old)
	check(single.ready and single.owned.has(coarse), "an unambiguous old coarse record retains explicit backward compatibility")
	original.meta.workshop_receipts.merge(observer.ledger[Mind.info_eid(source.id, changed)].meta.workshop_receipts)
	var ambiguous = Shared.prepare(g.workshop_snapshot([], observer.id), {}, old)
	check(not ambiguous.ready and ambiguous.issues.any(func(issue): return "Unresolved original reading identity" in issue), "ambiguous coarse records still fail capability instead of selecting an arbitrary receipt")
	# The old and new records can coexist during migration. A weaker duplicate
	# neither adds another reading nor weakens the stronger, independently heard one.
	var once: Dictionary = observer.workshop_state.requested.duplicate(true)
	var duplicate = observer.ledger[Mind.info_eid(source.id, first)].duplicate(true)
	duplicate.eid = coarse
	duplicate.weight = 0.2
	observer.ledger[coarse] = duplicate
	Mind.recompute_beliefs(g.w, observer, "old/new exact ownership")
	check(observer.workshop_state.active and observer.workshop_state.owned.has(coarse) and observer.workshop_state.facts.size() == 3, "an exactly identified old record can coexist with new records without duplicating a fact")
	check(once.keys().all(func(id): return is_equal_approx(once[id], observer.workshop_state.requested.get(id, INF))), "a weaker duplicate path cannot reduce the strongest complete reading hearing")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
