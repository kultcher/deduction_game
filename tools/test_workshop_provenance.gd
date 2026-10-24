extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
var checks = 0
var fails = 0

func _init() -> void:
	for size in [7, 10]:
		_live(size)
	print("Reading provenance: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _live(size: int) -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, size)
	g.w.day = 2
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener == null:
				continue
			listener.info_log = []
			listener.known_claims = {}
			listener.beliefs = []
			listener.believed_roles = {}
			listener.ledger = {}
			listener.workshop_state = {"enabled": true, "reasoning_mode": "full", "confidence_mode": "scale"}
	var observer = g.w.living_good()[0]
	var source = g.w.living_good()[1]
	var teller = g.w.living_good()[2]
	observer.role = "warden"
	source.role = "surveyor"
	var entry = {"day": 0, "phase": 0, "role": "surveyor", "data": {"count": 2}, "text": "I counted two evil presences.", "shared": false}
	var eid = Mind.info_eid(source.id, entry)
	var anonymous = Shared.reading(source.id, entry, teller.id, true)
	check(anonymous.source == "" and anonymous.provenance.original_source == "" and anonymous.content.teller == teller.id, "an anonymous receipt preserves the teller, never the hidden original source")
	check(anonymous.id == Shared.reading(observer.id, entry, teller.id, true).id, "changing the referee's hidden source cannot change the anonymous fact")
	check(anonymous.id != Shared.reading(source.id, entry, observer.id, true).id, "unrelated anonymous tellings remain distinct until acknowledged")
	var rng = g.w.rng.state
	Mind.apply_info(g.w, observer, source, entry, 0.25, teller.id, true)
	var input = g.workshop_snapshot([], observer.id)
	var plan = Shared.prepare(input, {}, observer.ledger)
	check(not plan.ready and plan.issues.any(func(issue): return "anonymous" in str(issue)), "an unresolved anonymous reading has an explicit capability failure")
	check(not observer.workshop_state.active, "unresolved provenance cannot acquire shared ownership using a secret identity")
	var exported = input.listener.legacy_evidence.filter(func(item): return item.kind == "reading")
	check(exported.size() == 1 and exported[0].id == "anonymous:" + anonymous.id and exported[0].rel[0] == "" and exported[0].supports.is_empty(), "the portable compatibility reference also redacts hidden source identity")
	check(input.listener.known_claims.is_empty(), "an anonymous gift-holder does not become a named role claim")
	var weight: float = observer.ledger[eid].weight
	# Merely hearing the same reading from a named person does not prove that they
	# were the unnamed person in a previous story.
	Mind.apply_info(g.w, observer, source, entry, 0.25, source.id)
	check(observer.ledger[eid].meta.workshop_receipts.size() == 2 and not observer.workshop_state.active, "matching content alone cannot resolve an anonymous telling")
	Mind.acknowledge_reading(g.w, observer, source, entry, teller.id)
	var receipts: Dictionary = observer.ledger[eid].meta.workshop_receipts
	var named = Shared.reading(source.id, entry, teller.id)
	check(receipts.size() == 1 and receipts.has(named.id) and not receipts.has(anonymous.id), "an explicit public acknowledgement binds precisely the anonymous telling")
	check(receipts[named.id].provenance_paths.any(func(path): return path.origin_certainty == "anonymous") and receipts[named.id].provenance_paths.any(func(path): return path.origin_certainty == "public_acknowledgement"), "one fact retains the anonymous and acknowledged routes")
	check(observer.workshop_state.active and observer.workshop_state.owned.has(eid) and observer.workshop_state.facts.size() == 1, "the resolved reading acquires one shared owner")
	check(observer.ledger[eid].weight == weight and observer.ledger[eid].applied.values().all(func(value): return is_zero_approx(value)), "binding grants no weight bonus and retracts the native effect")
	check(g.w.rng.state == rng, "recording or acknowledging provenance draws no RNG")
	var once = observer.suspicion.duplicate(true)
	Mind.acknowledge_reading(g.w, observer, source, entry, teller.id)
	check(observer.suspicion == once and receipts.size() == 1, "a repeated acknowledgement adds no evidence")
	# A second named relay is another provenance path to the same report.
	Mind.apply_info(g.w, observer, source, entry, 0.25, observer.id)
	check(observer.ledger[eid].meta.workshop_receipts.size() == 1 and observer.ledger[eid].meta.workshop_receipts[named.id].provenance_paths.any(func(path): return path.via == observer.id), "named relays retain their tellers without duplicating the original reading")
	# Exercise the actual public meeting path, including evil cover minds.
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener != null:
				listener.ledger = {}
				listener.workshop_state = {"enabled": true, "reasoning_mode": "full", "confidence_mode": "scale"}
	source.silenced = true # The existing corroboration chance is ineligible.
	var lines: Array = []
	var facts: Array = []
	rng = g.w.rng.state
	Mind.relay_reading(g.w, teller, source, entry, lines, facts)
	check(g.w.rng.state == rng and facts.size() == 1 and facts[0].kind == "accusation", "an unacknowledged meeting relay preserves the existing speech/RNG contract")
	for n in g.w.living():
		if n == source or n == teller:
			continue
		var listener = n.shadow if n.is_evil() else n
		check(not listener.workshop_state.active and listener.ledger[eid].meta.workshop_receipts.has(anonymous.id), "actual unnamed relay uses an explicit fallback for " + n.id)
	# Pick an independent deterministic probe seed for the pre-existing 5% public
	# acknowledgement. Only that original draw may advance the world's RNG.
	var probe = RandomNumberGenerator.new()
	for seed_value in range(1000):
		probe.seed = seed_value
		if probe.randf() < 0.05:
			g.w.rng.seed = seed_value
			break
	var expected_state = probe.state
	source.silenced = false
	source.claim_public = false
	source.info_log = [entry.duplicate(true)]
	lines = []
	facts = []
	Mind.relay_reading(g.w, teller, source, entry, lines, facts)
	check(source.claim_public and lines.any(func(line): return "That was me" in str(line)), "the real public acknowledgement path names the original source")
	check(g.w.rng.state == expected_state, "public acknowledgement preserves the single existing corroboration draw")
	for n in g.w.living():
		if n == source or n == teller:
			continue
		var listener = n.shadow if n.is_evil() else n
		var learned: Dictionary = listener.ledger[eid].meta.workshop_receipts
		check(not learned.has(anonymous.id) and learned.has(named.id) and listener.workshop_state.active, "actual acknowledgement resolves the receipt for " + n.id)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
