extends SceneTree
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Solver = preload("res://workshop/solver.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Mind = preload("res://sim/mind.gd")
const LedgerAudit = preload("res://workshop/ledger_audit.gd")
var checks = 0
var fails = 0

func _init() -> void:
	check(not Assess.evaluate({"format": "future-model"}).ready, "unknown transport versions return unsupported without evaluating")
	for size in [7, 10]:
		var g = _game(size)
		var n = g.w.living_good()[0]
		n.info_log = []
		n.known_claims = {}
		n.beliefs = []
		var source = g.w.npcs.filter(func(p): return p != n)[0]
		var target = g.w.npcs.filter(func(p): return p != n and p != source)[0]
		var card = g.add_card({"kind": "info", "source": source.id, "role": "surveyor", "day": 0,
			"data": {"count": 2}, "subject": [], "text": "Surveyor report"})
		var ded = g.file_deduction({"type": "evil", "a": target.id}, [card])
		Mind.apply_info(g.w, n, source, {"day": 0, "role": "surveyor", "data": {"count": 2}}, 0.5)
		var input = g.workshop_snapshot([ded], n.id)
		var prepared = Assess.prepare(input)
		check(prepared.ready, "count reading is supported without a hidden modifier lookup")
		var worlds = Domain.worlds(prepared.view)
		check(worlds.size() == (525 if size == 7 else 5040), "all four legal modifier kinds have the expected public domain")
		var unique = {}
		for world in worlds:
			unique[TimeModel.key(prepared.view, world)] = true
		check(unique.size() == worlds.size(), "world IDs distinguish absent Marked, all holder identities and modifier kinds")
		check(worlds.any(func(w): return w.marked == -1) and worlds.any(func(w): return w.modifier == "marked"), "no-Marked and Marked explanations coexist")
		check(worlds.filter(func(w): return w.modifier == "lovers").all(func(w): return Solver.popcount(w.holders) == 2 and not w.evil & w.holders), "Lovers worlds contain two originally-good holders")
		var all = Solver.solve(prepared.view, []).worlds
		check(all.size() == worlds.size(), "solver preserves the full modifier domain before evidence")
		if size == 7:
			var expected = all.duplicate(true)
			for revision in range(17):
				var varied = prepared.view.duplicate(true)
				varied.world_options["revision"] = revision
				Solver.solve(varied, [])
			check(Solver.universes.size() <= 16 and Solver.solve(prepared.view, []).worlds == expected, "universe cache eviction bounds memory without changing legal explanations")
		var narrower = prepared.view.duplicate(true)
		narrower.world_options.modifiers = ["marked"]
		check(Solver.solve(narrower, []).worlds.size() == (105 if size == 7 else 840) and Solver.solve(prepared.view, []).worlds.size() == worlds.size(), "world caches invalidate when the modifier domain changes")
		var report: Dictionary = prepared.view.cards[0]
		var delusional: Dictionary = worlds.filter(func(w): return w.modifier == "delusional" and w.holders & (1 << prepared.view.people.map(func(p): return p.id).find(source.id)))[0]
		check(not Solver._report_holds(prepared.view, delusional, report, {}), "accepting a healthy report excludes a Delusional source in that branch")
		var marked_source: Dictionary = worlds.filter(func(w): return w.marked == prepared.view.people.map(func(p): return p.id).find(source.id))[0]
		var registration = {}
		for i in range(size):
			if marked_source.evil & (1 << i) or marked_source.marked == i:
				registration[prepared.view.people[i].home] = true
		var self_marked_read = report.duplicate(true)
		self_marked_read.data.count = registration.size()
		check(Solver._report_holds(prepared.view, marked_source, self_marked_read, {}), "a healthy Surveyor can itself be Marked and register in its own count")
		var late = self_marked_read.duplicate(true)
		late.observed_at.day = 1
		check(not Solver._report_holds(prepared.view, marked_source, late, {}), "first-night-only gifts cannot produce a new healthy report on a later night")
		check(not Domain.claims_compatible([report], {"self": n.id, "own_role": "surveyor"}), "the listener's own known unique gift excludes another healthy claimant")
		var rumors = report.duplicate(true)
		rumors.role = "rumormonger"
		rumors.data = {"pair": [n.id, target.id], "secret": "lovers"}
		var compatible = Solver.solve(prepared.view, [rumors]).worlds
		check(not compatible.is_empty() and compatible.any(func(w): return w.modifier == "lovers" and w.marked == -1) and compatible.all(func(w): return w.modifier == "lovers" or w.holders == 1 << prepared.view.people.map(func(p): return p.id).find(source.id)), "Rumormonger permits Lovers and the native self-holder fallback without assuming one Marked")
		var double = report.duplicate(true)
		double.source = target.id
		check(Solver.solve(prepared.view, [report, double]).worlds.is_empty(), "two different healthy Surveyors cannot both hold a unique gift")
		var before = _state(g)
		var start = Time.get_ticks_msec()
		var result = g.workshop_preview(ded, n.id)
		print("Live comparison %d people: %d ms" % [size, Time.get_ticks_msec() - start])
		check(result.ready and result.proposal.effects.size() == size, "live assessment produces collateral proposals for every person")
		check(not result.ledger_audit.reading_entries.is_empty() and not result.ledger_audit.safe_to_apply_additively, "real raw-reading entries are identified before applying an overlapping proposal")
		check(before == _state(g), "preview does not mutate beliefs, ledger, RNG or time")
		var ambiguous = input.duplicate(true)
		var variant: Dictionary = ambiguous.evidence.filter(func(e): return e.kind == "info")[0].duplicate(true)
		variant.id += ":variant"
		variant.content.data.count = 3
		ambiguous.evidence.append(variant)
		ambiguous.private_evidence.append(variant.id)
		check(not Assess.evaluate(ambiguous).ready, "unresolved shared reading identities prevent false precision")
		var child = g.file_deduction({"type": "evil", "a": source.id}, [card])
		var nested = g.file_deduction({"type": "evil", "a": target.id}, [card, child])
		var nested_result = g.workshop_preview(nested, n.id)
		check(nested_result.ready and nested_result.proposal.claims.size() == 2, "nested live deductions retain separately assessed intermediate claims")
		check(result.proposal.effects.keys().all(func(id): return is_equal_approx(result.proposal.effects[id].requested, nested_result.proposal.effects[id].requested)), "sharing evidence through a live intermediate claim does not multiply its consequences")
		var cleared = input.duplicate(true)
		cleared.public_events.append({"kind": "demon_death", "subjects": [target.id], "at": {"day": 0, "phase": "night"}})
		var known = Assess.prepare(cleared)
		check(target.id in known.listener.knowledge.good, "public Demon victims remain private-world constraints even if their death card is not cited")
		cleared.public_events.append({"kind": "martyr", "subjects": [source.id, target.id], "at": {"day": 1, "phase": "evening"}})
		check(source.id in Assess.prepare(cleared).listener.knowledge.good, "a public Martyr sacrifice preserves its known-good participants")
		for person in g.w.npcs:
			if person != n:
				person.role = "poisoner"
			person.poisoned = true
			person.secret_mod = "marked"
		check(input == g.workshop_snapshot([ded], n.id), "changing hidden causes does not change comparison inputs")
		var again = g.workshop_preview(ded, n.id)
		check(result.proposal.effects == again.proposal.effects, "hidden changes do not change proposed consequences")
		g.w.public_event("curse", [source.id], source.id)
		check(not g.workshop_preview(ded, n.id).ready, "unsupported live transitions prevent numeric comparison")
		g.w.public_log = []
		var unsupported = g.add_card({"kind": "info", "source": source.id, "role": "seer", "day": 1, "data": {"pair": [source.id, target.id], "yes": true}, "text": "Seer report"})
		var other = g.file_deduction({"type": "evil", "a": target.id}, [unsupported])
		check(not g.workshop_preview(other, n.id).ready, "unsupported roles do not silently become unconditional good-source constraints")
	_routes()
	_audit()
	_rumormonger_fallback()
	print("Workshop integration: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _rumormonger_fallback() -> void:
	var g = _game(7)
	var source = g.w.living_good()[0]
	for n in g.w.npcs:
		n.secret_mod = ""
	source.role = "rumormonger"
	source.secret_mod = "marked"
	source.poisoned = false
	g.w.day = 0
	g.w.phase = C.NIGHT
	g.w._receive_info(source, "")
	var report: Dictionary = source.info_log[-1]
	var people: Array = g.w.npcs.map(func(n): return {"id": n.id, "name": n.name, "home": n.home_block})
	var evil = 0
	for i in range(people.size()):
		if g.w.npcs[i].is_evil():
			evil |= 1 << i
	var view = {"people": people, "evil_count": 2, "alignment_epoch": "now", "world_options": {"modifiers": C.SECRET_MOD_LIST}}
	var index: int = people.map(func(n): return n.id).find(source.id)
	var world = {"evil": evil, "marked": index, "modifier": "marked", "holders": 1 << index}
	var card = {"kind": "report", "source": source.id, "role": "rumormonger", "observed_at": {"day": g.w.day, "phase": "night"}, "data": report.data}
	check(not report["true"] and Solver._report_holds(view, world, card, {}), "actual healthy self-Marked Rumormonger fallback remains a legal live explanation")

func _audit() -> void:
	var input = {"evidence": [], "listener": {"legacy_evidence": [
		{"id": "info:bart:2:dowser", "kind": "reading", "rel": [], "supports": []},
		{"id": "arg:evil:hollis", "kind": "arg", "rel": [], "supports": [["bart", 2, "reading"]]},
		{"id": "ordinary", "kind": "tell", "rel": ["bart", 2, "report"], "supports": []}]}}
	for id in ["first", "changed"]:
		input.evidence.append({"id": id, "kind": "info", "source": "bart", "observed_at": {"day": 2}, "content": {"role": "dowser"}})
	var result = LedgerAudit.inspect(input)
	check(result.aliases.size() == 1 and result.aliases[0].facts.size() == 2, "same-day legacy collisions are exposed rather than silently merged")
	check(result.potential_arguments.size() == 1 and result.potential_arguments[0].certainty == "coarse_dependency", "argument dependencies are identified without treating ordinary testimony as gift evidence")
	check(not result.safe_to_apply_additively, "audit findings never authorize stacking or deleting effects")
	var g = _game(7)
	var listener = g.w.living_good()[0]
	var source = g.w.npcs.filter(func(n): return n != listener)[0]
	var other = g.w.npcs.filter(func(n): return n != listener and n != source)[0]
	var entry = {"day": 1, "phase": 1, "role": "dowser", "data": {"group": [source.id, other.id], "count": 1}}
	var number = g.add_card({"kind": "info", "source": source.id, "role": "dowser", "day": 1, "phase": 1,
		"data": entry.data, "text": "Dowser group"})
	Mind.apply_info(g.w, listener, source, entry, 0.5)
	var audit = LedgerAudit.inspect(g.workshop_snapshot([number], listener.id))
	check(not listener.ledger[Mind.info_eid(source.id, entry)].applied.is_empty() and not audit.reading_entries.is_empty(), "audit detects a native Dowser reading with actual suspicion already applied")

func _routes() -> void:
	var off = _game(7)
	var on = _game(7)
	for g in [off, on]:
		var src = g.w.npcs[0]
		var num = g.add_card({"kind": "info", "source": src.id, "role": "surveyor", "day": 0, "data": {"count": 2}, "text": "Count"})
		g.file_deduction({"type": "evil", "a": g.w.npcs[1].id}, [num])
	on.workshop_compare = true
	for venue in ["private", "meeting", "nomination"]:
		var a = off.w.living_good()[0]
		var b = on.w.by_id[a.id]
		a.info_log = []
		b.info_log = []
		var ar = off._evaluate_deduction(a, off.board[-1], 0.6, false, venue)
		var br = on._evaluate_deduction(b, on.board[-1], 0.6, false, venue)
		check(ar == br and _state(off) == _state(on), "comparison preserves actual legacy behavior and RNG at " + venue)
		check(on.workshop_comparisons[-1].venue == venue and on.workshop_comparisons[-1].has("legacy"), "each venue retains side-by-side diagnostics")
	check(off.workshop_comparisons.is_empty(), "comparison is opt-in")

func _game(size: int):
	var g = Game.new()
	g.workshop_effects = false # This suite compares the native route with diagnostics.
	g.detailed_logging = false
	g.new_case(692, size)
	return g

func _state(g) -> Dictionary:
	var people = []
	for n in g.w.npcs:
		people.append({"suspicion": n.suspicion.duplicate(true), "ledger": n.ledger.duplicate(true),
			"trust": n.trust, "heard": n.heard.duplicate(true), "pressure": n.pressure})
	return {"people": people, "rng": g.w.rng.state, "day": g.w.day, "phase": g.w.phase}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		fails += 1
		push_error("FAIL: " + label)
