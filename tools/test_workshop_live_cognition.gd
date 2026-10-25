## Native profiles, committed union memory, scoped replies and reversible ownership.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_insight()
	_attention()
	_confidence()
	_cover_and_fallback()
	_registration()
	print("Live Workshop cognition: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		# This suite tests persistence Confidence, which live play no longer uses by default.
		p.workshop_state["confidence_mode"] = "persistence"
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.trust = 0.7
		p.trust_at_reconsider = 0.7
		for id in p.suspicion:
			p.suspicion[id] = 0.25
			p.npc_trust[id] = 1.0
	# Fix the listener at a known domain index. The interpreter receives its
	# permitted good/own-gift knowledge, never the actual other roles or modifier.
	var n = g.w.npcs[0]
	n.alignment = "good"
	n.role = "warden"
	n.traits.insight = 0.9
	n.traits.confidence = 0.5
	return g

func _read(g, source, role: String, day: int, data: Dictionary) -> int:
	return g.add_card({"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 3 if day == 0 else 0, "data": data,
		"text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})

func _proof(g) -> int:
	var p: Array = g.w.npcs
	var rumor = _read(g, p[1], "rumormonger", 0, {"pair": [p[4].id, p[5].id], "secret": "marked"})
	var dowser = _read(g, p[2], "dowser", 1, {"group": [p[3].id, p[4].id, p[5].id], "count": 3})
	return g.file_deduction({"type": "evil", "a": p[3].id}, [rumor, dowser])

func _insight() -> void:
	var results: Array = []
	for insight in [0.1, 0.5, 0.9]:
		var g = _game()
		var n = g.w.npcs[0]
		n.traits.insight = insight
		var number = _proof(g)
		g.set_workshop_effects(true)
		var rng: int = g.w.rng.state
		var r = g._evaluate_deduction(n, g.board[number - 1], 1.0, true)
		check(r.get("workshop", false), "native cognitive profile uses shared presentation")
		check(r.assessment.reasoning.profile == Reasoner.profile(insight).name and r.assessment.theory.mode == "persistence", "live traits select the bounded profile and persistent confidence")
		check(r.assessment.calculation.confidence_factor == 1.0, "persistent confidence does not stack the old incoming-effect multiplier")
		check(r.assessment.reasoning.support_tested <= Reasoner.profile(insight).support and r.assessment.reasoning.rivals_tested <= Reasoner.profile(insight).rivals, "live search respects both hard test budgets")
		check(g.w.rng.state == rng, "cognitive assessment uses no random draws")
		results.append(r)
		print("Insight %.1f: %s agreement %.4f; %d/%d checks; compatible %d" % [insight, r.assessment.reasoning.status, r.agreement, r.assessment.reasoning.support_tested, r.assessment.reasoning.rivals_tested, r.assessment.shared_assessment.compatible])
		var beliefs = n.suspicion.duplicate(true)
		var theories = n.workshop_state.theories.duplicate(true)
		var plan: Dictionary = g._workshop_plans[n.id + ":good"]
		var fresh_plan = plan.duplicate(true)
		fresh_plan.prepared.listener.theories = {}
		var once = Shared.evaluate(fresh_plan, n.workshop_state.outside, n.discounted)
		var next_plan = fresh_plan.duplicate(true)
		next_plan.prepared.listener.theories = once.theories.duplicate(true)
		var twice = Shared.evaluate(next_plan, n.workshop_state.outside, n.discounted)
		check(once == twice, "a committed live theory returns the exact same assessment on unchanged input")
		for venue in ["private", "meeting", "nomination", "private"]:
			g._evaluate_deduction(n, g.board[number - 1], 0.6, true, venue)
			check(_close(beliefs, n.suspicion) and n.workshop_state.theories == theories, "repeated venues cannot sharpen a native theory or compound suspicion")
		check(g._workshop_evaluations[n.id + (":cover" if n.is_shadow else ":good")].cache_hit, "unchanged presentations reuse the committed union assessment")
		var before = JSON.stringify([n.workshop_state, n.suspicion, n.trust, g.w.rng.state])
		var preview = g.workshop_preview(number, n.id)
		var ghost = g.workshop_ghost_preview(number)
		check(preview.ready and preview.proposal.reasoning.profile == Reasoner.profile(insight).name, "read-only NPC preview uses that NPC's cognitive profile")
		check(ghost.ready and ghost.proposal.reasoning.profile == "Full" and ghost.proposal.theory.mode == "scale", "neutral ghost remains full reasoning without native theory memory")
		check(JSON.stringify([n.workshop_state, n.suspicion, n.trust, g.w.rng.state]) == before, "both preview types leave theories, beliefs and RNG untouched")
		g.w.day += 1
		Mind.recompute_beliefs(g.w, n, "new date, original alignment unchanged")
		check(n.workshop_state.theories == theories and _close(beliefs, n.suspicion), "day advance does not reset original-alignment theories or award evidence again")
		if insight < 0.2:
			n.traits.insight = 0.9
			var revised = g._evaluate_deduction(n, g.board[number - 1], 1.0, false)
			check(not revised.repeated and revised.assessment.reasoning.profile == "High" and n.workshop_state.reasoning.profile == "High", "a changed live trait invalidates both assessment caches and repetition status")
		g.workshop_retract(number, n.id)
		check(n.workshop_state.facts.is_empty() and _close(n.suspicion, n.workshop_state.outside), "sole-case retraction removes all persuasion even while theory memory remains")
		g.set_workshop_effects(false)
		check(not n.workshop_state.active and n.workshop_state.owned.is_empty(), "disable restores native ownership")
	check(results[0].assessment.reasoning.limited and results[0].assessment.reasoning.status != "entailed_in_attention", "low Insight cannot borrow the complete referee proof")
	check(results[2].assessment.reasoning.status == "entailed_in_attention" and results[2].agreement > results[0].agreement, "high Insight can establish the implication missed by the low profile")

func _attention() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var n = p[0]
	n.role = "rumormonger"
	n.traits.insight = 0.1
	var own = {"role": "rumormonger", "day": 0, "phase": 3, "data": {"pair": [p[4].id, p[5].id], "secret": "marked"}, "text": "Personally received gift"}
	n.info_log.append(own)
	var own_id: String = Shared.reading(n.id, own).id
	var cards: Array = []
	for day in range(1, 7):
		cards.append(_read(g, p[1], "dowser", day, {"group": [p[3].id], "count": 0}))
	var number = g.file_deduction({"type": "good", "a": p[3].id}, cards)
	g.set_workshop_effects(true)
	var r = g._evaluate_deduction(n, g.board[number - 1], 1.0, false)
	check(r.get("workshop", false), "seven legal receipts fit the unchanged workload capability gate")
	check(r.assessment.reasoning.considered.size() == cards.size() and own_id in r.assessment.reasoning.ignored, "all six presented cards are read; private evidence competes for the remaining budget")
	check(n.workshop_state.reasoning.considered.size() == cards.size(), "applied union reserves the same presented roots")
	var thought = n.workshop_state.theories.duplicate(true)
	var beliefs = n.suspicion.duplicate(true)
	for i in range(3):
		Mind.recompute_beliefs(g.w, n, "same evidence")
	check(n.workshop_state.theories == thought and _close(beliefs, n.suspicion), "automatic refresh cannot accumulate theory commitment")
	# Known testimony from other people is not firsthand gift experience.
	Mind.apply_info(g.w, n, p[1], {"role": "dowser", "day": 1, "phase": 0, "data": {"group": [p[3].id], "count": 0}}, 1.0)
	check(n.workshop_state.reasoning.considered.size() == cards.size(), "independently learning an already presented report does not create a second attention slot")

func _confidence() -> void:
	# Hold source quality fixed and vary independent prior evidence about the
	# target. A moderate contrary comparison should move the less committed mind.
	var outcomes: Array = []
	var initial: Array = []
	var atoms: Array = []
	for confidence in [0.1, 0.9]:
		var g = _game()
		var p: Array = g.w.npcs
		var n = p[0]
		n.traits.confidence = confidence
		n.suspicion[p[3].id] = 0.6
		var card = _read(g, p[1], "dowser", 1, {"group": [p[3].id], "count": 1})
		var number = g.file_deduction({"type": "evil", "a": p[3].id}, [card])
		g.set_workshop_effects(true)
		var first = g._evaluate_deduction(n, g.board[number - 1], 1.0, false)
		initial.append(n.workshop_state.requested.duplicate(true))
		atoms.append(first.assessment.support_model.atoms)
		var key: String = p[3].id + "|Original alignment"
		var old: String = n.workshop_state.theories[key].position
		Mind.adjust(g.w, n, p[3].id, 0.15 - n.workshop_state.outside[p[3].id], "independent contrary evidence", "", false)
		Mind.recompute_beliefs(g.w, n, "changed independent evidence")
		outcomes.append([old, n.workshop_state.theories[key].position, n.workshop_state.theories[key].decision.status])
		if confidence > 0.5:
			var clear = _read(g, p[1], "dowser", 2, {"group": [p[3].id], "count": 0})
			var defence = g.file_deduction({"type": "good", "a": p[3].id}, [clear])
			g._evaluate_deduction(n, g.board[defence - 1], 1.0, false)
			check(n.workshop_state.theories[key].position == "good", "decisive contrary evidence can dislodge the live high-confidence theory")
	check(outcomes[0] == ["evil", "good", "revised"] and outcomes[1] == ["evil", "evil", "retained"], "live low confidence revises while high confidence retains under the same moderate contrary evidence")
	check(_close(initial[0], initial[1]) and atoms[0] == atoms[1], "initial evidence effects and source/accuracy weights are equal across confidence levels")

func _cover_and_fallback() -> void:
	var g = _game()
	var n = g.w.npcs[0]
	var number = _proof(g)
	g.set_workshop_effects(true)
	g._evaluate_deduction(n, g.board[number - 1], 1.0, false)
	var committed = n.workshop_state.theories.duplicate(true)
	g.w.public_log.append({"day": 1, "kind": "curse", "subjects": [n.id], "by": "town"})
	Mind.recompute_beliefs(g.w, n, "unsupported public transition")
	check(not n.workshop_state.active and n.workshop_state.owned.is_empty() and n.workshop_state.theories == committed, "unsupported history falls back without applying or changing dormant theory memory")
	g.w.public_log.clear()
	Mind.recompute_beliefs(g.w, n, "supported evidence again")
	check(n.workshop_state.active, "supported ownership recovers after capability fallback")
	var evil = g.w.npcs.filter(func(p): return p.is_evil())[0]
	Mind.shadow_run(g.w, evil, func(_cover): pass)
	var real_before = [evil.suspicion.duplicate(true), evil.intel.duplicate(true)]
	g._evaluate_deduction(evil, g.board[number - 1], 1.0, true)
	check(evil.shadow.workshop_state.get("enabled", false) and g.workshop_snapshot([number], evil.id).listener.reasoning_mode == "bounded", "evil's cover receives the bounded native profile")
	check(real_before == [evil.suspicion, evil.intel] and not evil.workshop_state.has("theories"), "cover cognition never changes the real evil mind or supplies evil intelligence")
	g.new_case(692, 7)
	check(g.w.npcs.all(func(p): return p.workshop_state.get("presentations", {}).is_empty() and p.workshop_state.get("discussion", {}).is_empty()) and g.workshop_effects, "new case clears prior presentations and keeps shared evaluation enabled")

func _registration() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var n = p[0]
	var number = _proof(g)
	g.set_workshop_effects(true)
	g._evaluate_deduction(n, g.board[number - 1], 1.0, false)
	var marked = g.file_deduction({"type": "marked", "a": p[4].id}, g.board[number - 1].supports)
	var before = n.suspicion.duplicate(true)
	var r = g._evaluate_deduction(n, g.board[marked - 1], 1.0, false)
	var key: String = p[4].id + "|Original alignment|marked"
	check(r.get("workshop", false) and n.workshop_state.theories.has(key), "live Marked questions persist a separate registration theory")
	check(_close(before, n.suspicion), "asking a Marked question adds no extra alignment evidence effect")
	var memory = n.workshop_state.theories.duplicate(true)
	g._evaluate_deduction(n, g.board[marked - 1], 0.6, true, "meeting")
	check(n.workshop_state.theories == memory and _close(before, n.suspicion), "repeating registration claims cannot sharpen alignment or registration commitment")
	check(r.assessment.theory == n.workshop_state.theories[key].decision, "scoped registration reply uses the committed union decision")

func _close(a: Dictionary, b: Dictionary) -> bool:
	if a.keys() != b.keys():
		return false
	for key in a:
		if not is_equal_approx(a[key], b[key]):
			return false
	return true

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
