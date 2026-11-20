## Live NPC cognitive profiles, committed union memory, scoped replies and reversible ownership.
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
var checks = 0
var fails = 0

func _init() -> void:
	# Workshop listeners' theories (persistence) across a day advance.
	_insight()
	_attention()
	# Persistence Confidence on a belief refresh (a working theory biasing belief) went with
	# the earlier model in purge phase 3; the connections refresh doesn't read through a
	# theory (BACKLOG, "Persistence Confidence"; the checks are on archive/legacy-belief-final).
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
		var rng: int = g.w.rng.state
		var r = g._evaluate_deduction(n, g.board[number - 1], 1.0, true)
		check(r.get("workshop", false), "native cognitive profile uses shared presentation")
		check(r.assessment.reasoning.profile == Reasoner.profile(insight).name and r.assessment.theory.mode == "persistence", "live traits select the bounded profile and persistent confidence")
		check(r.assessment.calculation.confidence_factor == 1.0, "persistent confidence does not stack the old incoming-effect multiplier")
		check(r.assessment.reasoning.support_tested <= Reasoner.profile(insight).support and r.assessment.reasoning.rivals_tested <= Reasoner.profile(insight).rivals, "live search respects both hard test budgets")
		check(g.w.rng.state == rng, "cognitive assessment uses no random draws")
		results.append(r)
		print("Insight %.1f: %s agreement %.4f; %d/%d checks; compatible %d" % [insight, r.assessment.reasoning.status, r.agreement, r.assessment.reasoning.support_tested, r.assessment.reasoning.rivals_tested, r.assessment.assessment.compatible])
		var beliefs = n.suspicion.duplicate(true)
		var theories = n.workshop_state.theories.duplicate(true)
		var plan: Dictionary = g._workshop_plans[n.id + ":good"]
		var fresh_plan = plan.duplicate(true)
		fresh_plan.prepared.listener.theories = {}
		var sd_map: Dictionary = n.workshop_state.get("source_doubt", {})
		var once = Shared.evaluate(fresh_plan, n.workshop_state.outside, sd_map)
		var next_plan = fresh_plan.duplicate(true)
		next_plan.prepared.listener.theories = once.theories.duplicate(true)
		var twice = Shared.evaluate(next_plan, n.workshop_state.outside, sd_map)
		check(once == twice, "a committed live theory returns the exact same assessment on unchanged input")
		for venue in ["private", "meeting", "nomination", "private"]:
			g._evaluate_deduction(n, g.board[number - 1], 0.6, true, venue)
			check(_close(beliefs, n.suspicion) and n.workshop_state.theories == theories, "repeated venues cannot sharpen a native theory or compound suspicion")
		# The first meeting presentation puts its subject on the town's topic (recency), a real
		# input change; after that, nothing has changed and a refresh reuses the assessment.
		Mind.refresh_beliefs(g.w, n, "unchanged")
		check(g._workshop_evaluations[n.id + (":cover" if n.is_shadow else ":good")].cache_hit, "unchanged presentations reuse the committed union assessment")
		var before = JSON.stringify([n.workshop_state, n.suspicion, n.trust, g.w.rng.state])
		var preview = g.workshop_preview(number, n.id)
		var ghost = g.workshop_ghost_preview(number)
		check(preview.ready and preview.proposal.reasoning.profile == Reasoner.profile(insight).name, "read-only NPC preview uses that NPC's cognitive profile")
		check(ghost.ready and ghost.proposal.reasoning.profile == "Full" and ghost.proposal.theory.mode == "scale", "neutral ghost remains full reasoning without native theory memory")
		check(JSON.stringify([n.workshop_state, n.suspicion, n.trust, g.w.rng.state]) == before, "both preview types leave theories, beliefs and RNG untouched")
		g.w.day += 1
		Mind.refresh_beliefs(g.w, n, "new date, original alignment unchanged")
		# The connections model (purge phase 2): a presented case fades by the day, so the
		# people it named drop a little at the new date and the others take up the slack. A
		# second award would raise them instead. Measured as the group: the ones the case only
		# mentions can take up a sliver of the slack from its subject (Nov 20, +0.001 on 692).
		var named: Array = [g.w.npcs[3].id, g.w.npcs[4].id, g.w.npcs[5].id]
		var named_sum = func(m: Dictionary) -> float:
			return named.reduce(func(acc, id): return acc + float(m[id]), 0.0)
		check(n.workshop_state.theories == theories and named_sum.call(n.suspicion) <= named_sum.call(beliefs) + 0.000001, "day advance does not reset original-alignment theories or award evidence again")
		if insight < 0.2:
			n.traits.insight = 0.9
			var revised = g._evaluate_deduction(n, g.board[number - 1], 1.0, false)
			check(not revised.repeated and revised.assessment.reasoning.profile == "High" and n.workshop_state.reasoning.profile == "High", "a changed live trait invalidates both assessment caches and repetition status")
		g.workshop_retract(number, n.id)
		check(n.workshop_state.facts.is_empty() and _close(n.suspicion, n.workshop_state.outside), "sole-case retraction removes all persuasion even while theory memory remains")
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
	var r = g._evaluate_deduction(n, g.board[number - 1], 1.0, false)
	check(r.get("workshop", false), "seven legal receipts fit the unchanged workload capability gate")
	# Premises step 0b: the listener's own reading is pinned outside the budget, beside the case.
	check(r.assessment.reasoning.considered.size() == cards.size() + 1 and own_id in r.assessment.reasoning.considered, "all six presented cards are read, and the listener's own reading stays in view")
	check(n.workshop_state.reasoning.considered.size() == cards.size() + 1, "applied union reserves the same presented roots (plus the pinned own reading)")
	var thought = n.workshop_state.theories.duplicate(true)
	var beliefs = n.suspicion.duplicate(true)
	for i in range(3):
		Mind.refresh_beliefs(g.w, n, "same evidence")
	check(n.workshop_state.theories == thought and _close(beliefs, n.suspicion), "automatic refresh cannot accumulate theory commitment")
	# Known testimony from other people is not firsthand gift experience.
	Mind.apply_info(g.w, n, p[1], {"role": "dowser", "day": 1, "phase": 0, "data": {"group": [p[3].id], "count": 0}}, 1.0)
	check(n.workshop_state.reasoning.considered.size() == cards.size() + 1, "independently learning an already presented report does not create a second attention slot")

func _cover_and_fallback() -> void:
	var g = _game()
	var n = g.w.npcs[0]
	var number = _proof(g)
	g._evaluate_deduction(n, g.board[number - 1], 1.0, false)
	var committed = n.workshop_state.theories.duplicate(true)
	var last_good = n.suspicion.duplicate(true)
	g.unprepared_refreshes.clear()
	g.w.public_log.append({"day": 1, "kind": "curse", "subjects": [n.id], "by": "town"})
	Mind.refresh_beliefs(g.w, n, "unsupported public transition")
	check(n.workshop_state.active and _close(n.suspicion, last_good) and not g.unprepared_refreshes.is_empty() and n.workshop_state.theories == committed, "unsupported history keeps last good vector and theory memory while logging an unprepared refresh")
	g.w.public_log.clear()
	Mind.refresh_beliefs(g.w, n, "supported evidence again")
	check(n.workshop_state.active and n.workshop_state.issues.is_empty(), "supported ownership clears fallback issues once resolved")
	var evil = g.w.npcs.filter(func(p): return p.is_evil())[0]
	Mind.shadow_run(g.w, evil, func(_cover): pass)
	var real_before = [evil.suspicion.duplicate(true), evil.intel.duplicate(true)]
	g._evaluate_deduction(evil, g.board[number - 1], 1.0, true)
	check(evil.shadow.workshop_state.get("active", false) and g.workshop_snapshot([number], evil.id).listener.reasoning_mode == "bounded", "evil's cover receives the bounded native profile")
	check(real_before == [evil.suspicion, evil.intel] and not evil.workshop_state.has("theories"), "cover cognition never changes the real evil mind or supplies evil intelligence")
	g.new_case(692, 7)
	check(g.w.npcs.all(func(p): return p.workshop_state.get("presentations", {}).is_empty() and p.workshop_state.get("discussion", {}).is_empty()), "new case clears prior presentations")

func _registration() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var n = p[0]
	var number = _proof(g)
	g._evaluate_deduction(n, g.board[number - 1], 1.0, false)
	var centred: Dictionary = _brought(g, n)
	var marked = g.file_deduction({"type": "marked", "a": p[4].id}, g.board[number - 1].supports)
	var r = g._evaluate_deduction(n, g.board[marked - 1], 1.0, false)
	var key: String = p[4].id + "|Original alignment|marked"
	check(r.get("workshop", false) and n.workshop_state.theories.has(key), "live Marked questions persist a separate registration theory")
	# Premise centring (#246): cards only presented cases brought count in full on those
	# cases' targets. A Marked question names no alignment target, so cards it also brought
	# are left unshaped: they count in full for everyone, as cards held directly do
	# (Shared.brought_by_premise). Before #246 the cards counted in full for everyone anyway,
	# so a Marked question moved no one; now it lifts the first case's centring.
	check(not centred.is_empty() and centred.values().all(func(t): return t == [p[3].id]) and _brought(g, n).is_empty(),
		"a Marked question names no alignment target, so it leaves its cards unshaped (centred on %s before, %s after)" % [str(centred.values()), str(_brought(g, n).values())])
	var after = n.suspicion.duplicate(true)
	var memory = n.workshop_state.theories.duplicate(true)
	g._evaluate_deduction(n, g.board[marked - 1], 0.6, true, "meeting")
	check(n.workshop_state.theories == memory and _close(after, n.suspicion), "repeating registration claims cannot sharpen alignment or registration commitment")
	check(r.assessment.theory == n.workshop_state.theories[key].decision, "scoped registration reply uses the committed union decision")
	# Its target does (premise centring, #246, Michael's option B): the same cards aimed at
	# someone else count in full on them too, so they rise; the cards aren't weighed twice.
	var g2 = _game()
	var p2: Array = g2.w.npcs
	var n2 = p2[0]
	var first = _proof(g2)
	g2._evaluate_deduction(n2, g2.board[first - 1], 1.0, false)
	var before2 = n2.suspicion.duplicate(true)
	# The premise's type doesn't move beliefs: the same cards argued as "demon" about the same
	# target weigh as they did. (In a game of their own: after a Marked question, any later
	# case of the player's citing the same cards takes its place, and with it its frame.)
	var retyped = g2.file_deduction({"type": "demon", "a": p2[3].id}, g2.board[first - 1].supports)
	g2._evaluate_deduction(n2, g2.board[retyped - 1], 1.0, false)
	check(_close(before2, n2.suspicion), "the same cards under another premise type about the same target move beliefs no differently")
	var retargeted = g2.file_deduction({"type": "evil", "a": p2[5].id}, g2.board[first - 1].supports)
	g2._evaluate_deduction(n2, g2.board[retargeted - 1], 1.0, false)
	var aimed: Dictionary = _brought(g2, n2)
	check(not aimed.is_empty() and aimed.values().all(func(t): return p2[3].id in t and p2[5].id in t) and float(n2.suspicion[p2[5].id]) > float(before2[p2[5].id]),
		"aiming the same cards at someone else centres them on both targets, so the new one rises (%.3f -> %.3f)" % [float(before2[p2[5].id]), float(n2.suspicion[p2[5].id])])
	var shaped = n2.suspicion.duplicate(true)
	Mind.refresh_beliefs(g2.w, n2, " (later refresh)")
	check(_close(shaped, n2.suspicion), "a later refresh reproduces the remembered premise shaping exactly")

## The listener's centred cards ({card id: [targets]}, Shared.brought_by_premise) at its last refresh.
func _brought(g, n) -> Dictionary:
	return g._workshop_plans.get(n.id + ":good", {}).get("prepared", {}).get("listener", {}).get("connections", {}).get("brought", {})

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
