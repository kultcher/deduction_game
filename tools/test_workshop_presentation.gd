extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Presentation = preload("res://game/workshop_presentation.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_direct_and_migration()
	_conflicts()
	_venues_and_mixed()
	_scrutiny_and_cover()
	_intermediate()
	_private_reasons()
	_self_support_paths()
	print("Workshop presentation: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.workshop_effects = false # Explicit legacy baseline before testing migration.
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		# This suite isolates presentation/ownership under its original reference
		# cognition. Native bounded/persistent behavior has a separate live suite.
		p.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
		p.role = "warden" if not p.is_evil() else p.role
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.trust = 0.7
		p.trust_at_reconsider = 0.7
		for id in p.suspicion:
			p.suspicion[id] = 0.3
			p.npc_trust[id] = 1.0
	return g

func _reading(g, source, role: String, day: int, data: Dictionary) -> int:
	return g.add_card({"kind": "info", "source": source.id, "role": role, "day": day, "phase": 3 if day == 0 else 0,
		"data": data, "text": "%s's %s report at %d: %s" % [source.name, role, day, JSON.stringify(data)]})

func _direct_and_migration() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	var source = g.w.npcs.filter(func(p): return p != n)[0]
	var target = g.w.npcs.filter(func(p): return p != n and p != source)[0]
	var card = _reading(g, source, "dowser", 1, {"group": [target.id], "count": 0})
	var native = Mind.hear_defence(g.w, n, target, g.board[card - 1])
	check(not native.get("workshop", false), "disabled mode retains native presentation")
	check(n.ledger.values().any(func(e): return e.meta.get("kind") == "tell" and e.meta.has("workshop_card")), "native card presentations retain an exact original receipt for later migration")
	g.set_workshop_effects(true)
	check(n.workshop_state.active and n.workshop_state.owned.size() == 1, "existing direct card effects migrate into shared ownership")
	var baseline = n.suspicion.duplicate(true)
	n.pressed_today = 0
	var result = Mind.hear_defence(g.w, n, target, g.board[card - 1])
	# The voiced stance follows the belief refresh (Oct 26): a retold report moves nothing.
	check(result.get("workshop", false) and (result.dialogue.stance == result.assessment.stance or result.dialogue.special.contains("already")), "direct defence dialogue uses the applied model's assessment (or says it already knew)")
	check(_close(baseline, n.suspicion), "retelling the same directly learned report adds no second effect")
	var ded = g.file_deduction({"type": "good", "a": target.id}, [card])
	var trust = n.trust
	var filed = g._evaluate_deduction(n, g.board[ded - 1], 1.0, true)
	check(filed.get("workshop", false) and _close(baseline, n.suspicion), "wrapping a directly learned card in a deduction does not stack")
	check(is_equal_approx(trust, n.trust), "the same original facts cannot farm sound-argument trust rewards")
	var bad = g.file_deduction({"type": "evil", "a": target.id}, [card])
	var rejected = g._evaluate_deduction(n, g.board[bad - 1], 1.0, true)
	check(rejected.get("workshop", false) and rejected.dialogue.stance == "reject", "an accusation contradicted by the report is rejected by the new model")
	check(rejected.lines[0].text == rejected.dialogue.special and _close(baseline, n.suspicion), "spoken rejection and collateral exoneration derive from the same reports")
	n.pressed_today = 0
	var cited = Mind.hear_accusation(g.w, n, target, g.board[ded - 1])
	check(cited.get("workshop", false) and n.workshop_state.active, "citing a deduction as a card follows original evidence instead of promoting its label")
	check(not n.player_cases.is_empty() and n.player_cases[-1].card.supports == g.board[ded - 1].supports, "a supported private accusation remains available to ordinary NPC gossip with its original case")
	check(_close(baseline, n.suspicion), "deduction-as-card presentation cannot duplicate its original report")
	var repeat_result = g._evaluate_deduction(n, g.board[ded - 1], 0.6, true, "meeting")
	check(repeat_result.repeated and "unchanged" not in repeat_result.dialogue.special, "a new audience receives an explanation without another evidence award")
	repeat_result = g._evaluate_deduction(n, g.board[ded - 1], 0.6, true, "meeting")
	check(repeat_result.repeated and "unchanged" in repeat_result.dialogue.special, "repeating the explanation to the same audience is recognized")
	var before_public = n.suspicion.duplicate(true)
	Mind.public_case(g.w, target, g.board[card - 1], "accuse")
	check(n.workshop_state.active and _close(before_public, n.suspicion), "public raw-card accusation shares the same report owner as private defence and deductions")
	var group = [target, source]
	n.pressed_today = 0
	var grouped = Mind.hear_group_case(g.w, n, group, g.board[card - 1])
	check(grouped.get("workshop", false) and n.workshop_state.facts.size() == 1, "group presentations assess individual questions against one shared evidence set")

func _conflicts() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	var source = g.w.npcs.filter(func(p): return p != n)[0]
	var second = g.w.npcs.filter(func(p): return p != n and p != source)[0]
	var candidates = g.w.npcs.filter(func(p): return p != n and p != source and p != second)
	var a = candidates[0]
	var b = candidates.filter(func(p): return p.home_block != a.home_block)[0]
	var c = g.w.npcs.filter(func(p): return p.home_block != a.home_block and p.home_block != b.home_block)[0]
	var survey = _reading(g, source, "surveyor", 0, {"count": 1})
	# Marked may register differently on each read. Three pings on three
	# blocks require at least two actual evil blocks, so count 1 really conflicts.
	var dowse = _reading(g, second, "dowser", 1, {"group": [a.id, b.id, c.id], "count": 3})
	var conflict = g.file_deduction({"type": "conflict", "group": [source.id, second.id]}, [survey, dowse])
	check(conflict > 0, "native conflict builder can supply a real supported conflict")
	g.set_workshop_effects(true)
	var before = n.suspicion.duplicate(true)
	var result = g._evaluate_deduction(n, g.board[conflict - 1], 1.0, true)
	if not result.get("workshop", false) or result.dialogue.stance != "accept":
		print("Conflict diagnostic: ", JSON.stringify({"agreement": result.get("agreement"), "dialogue": result.get("dialogue"), "scope": result.get("assessment", {}).get("shared_assessment", {})}))
	check(result.get("workshop", false) and result.dialogue.stance == "accept", "a cross-role contradiction is assessed by shared logic")
	check(n.workshop_state.active and n.workshop_state.facts.is_empty(), "conflict receipts are quoted without endorsing either report")
	check(_close(before, n.suspicion) and n.discounted.is_empty(), "establishing a conflict awards no guilt and invents no blanket all-night impairment")
	check("cannot all be accurate" in result.dialogue.special and "does not establish" in result.dialogue.special, "the reply distinguishes conflicting reports from alignment guilt")
	var trust = n.trust
	var duplicate = g.file_deduction({"type": "conflict", "group": [source.id, second.id]}, [dowse, survey])
	var repeated = g._evaluate_deduction(n, g.board[duplicate - 1], 0.6, true, "meeting")
	check(repeated.repeated and is_equal_approx(trust, n.trust), "reordered conflict wrappers cannot farm rewards")
	var direct = g.file_deduction({"type": "evil", "a": a.id}, [dowse])
	var alone = g._evaluate_deduction(n, g.board[direct - 1], 1.0, true)
	var direct_effects = n.suspicion.duplicate(true)
	var shared = g.file_deduction({"type": "evil", "a": a.id}, [dowse, conflict])
	var with_quote = g._evaluate_deduction(n, g.board[shared - 1], 1.0, true)
	check(with_quote.get("workshop", false) and is_equal_approx(alone.agreement, with_quote.agreement), "quoting a child cannot erase the same report's direct endorsement from the spoken assessment")
	check(_close(direct_effects, n.suspicion), "direct and quoted routes share one actual contribution")
	var child_claims: Array = with_quote.assessment.claims.filter(func(c): return c.conclusion.type == "conflict")
	check(not child_claims.is_empty() and child_claims[0].links.all(func(link): return Evidence.normalize_card(g.board[dowse - 1]).id not in link.exclusive_cards), "branch diagnostics retain original roots still owned by a direct parent path")
	g.workshop_retract(direct, n.id)
	g.workshop_retract(shared, n.id)
	var clear = _reading(g, second, "dowser", 2, {"group": [a.id], "count": 0})
	var base = g.file_deduction({"type": "good", "a": a.id}, [clear])
	var base_result = g._evaluate_deduction(n, g.board[base - 1], 1.0, true)
	var accepted = n.suspicion.duplicate(true)
	var combined = g.file_deduction({"type": "good", "a": a.id}, [clear, conflict])
	var composed = g._evaluate_deduction(n, g.board[combined - 1], 1.0, true)
	check(composed.get("workshop", false) and _close(accepted, n.suspicion), "a nested conflict contributes quoted context, not two endorsed contradictory readings")
	check(n.workshop_state.facts.size() == 1 and composed.assessment.claims.any(func(c): return c.conclusion.type == "conflict"), "intermediate conflict assessments remain visible without adding evidence")
	g.workshop_retract(base, n.id)
	g.workshop_retract(combined, n.id)
	check(n.workshop_state.facts.is_empty() and _close(before, n.suspicion), "withdrawing alignment endorsements leaves quoted conflicts without residual guilt")
	# A coherent pair should not generate scrutiny simply because the player names a conflict.
	g.board[survey - 1].data.count = 3
	var consistent = g.file_deduction({"type": "conflict", "group": [source.id, second.id]}, [survey, clear])
	var denied = g._evaluate_deduction(n, g.board[consistent - 1], 1.0, true)
	check(denied.get("workshop", false) and denied.dialogue.stance == "reject", "a coherent set does not become conflicting just because it is labelled that way")

func _venues_and_mixed() -> void:
	var results: Array = []
	for venue in ["private", "meeting", "nomination"]:
		var g = _game()
		var n = g.w.living_good()[0]
		var source = g.w.npcs.filter(func(p): return p != n)[0]
		var target = g.w.npcs.filter(func(p): return p != n and p != source)[0]
		var card = _reading(g, source, "dowser", 1, {"group": [target.id], "count": 0})
		var ded = g.file_deduction({"type": "good", "a": target.id}, [card])
		g.set_workshop_effects(true)
		var response = g._evaluate_deduction(n, g.board[ded - 1], 1.0 if venue == "private" else 0.6 if venue == "meeting" else 0.5, true, venue)
		check(response.get("workshop", false), "supported deduction uses unified presentation at " + venue)
		results.append([response.agreement, n.suspicion.duplicate(true), n.trust])
		if venue == "private":
			var vector: Dictionary = n.workshop_state.requested.duplicate(true)
			Mind.recompute_beliefs(g.w, n, "unchanged inputs")
			check(g._workshop_evaluations[n.id + (":cover" if n.is_shadow else ":good")].cache_hit and _close(vector, n.workshop_state.requested), "unchanged joint reassessment reuses an exact cached input without changing effects")
			n.npc_trust[source.id] = 0.1
			Mind.recompute_beliefs(g.w, n, "source credibility changed")
			check(not g._workshop_evaluations[n.id + (":cover" if n.is_shadow else ":good")].cache_hit and not _close(vector, n.workshop_state.requested), "source trust invalidates the aggregate cache")
			n.npc_trust[source.id] = 1.0
			Mind.recompute_beliefs(g.w, n, "source credibility restored")
			check(_close(vector, n.workshop_state.requested), "restoring source trust restores the same joint vector")
			var unsupported_source = g.w.npcs.filter(func(p): return p != n and p != source and p != target)[0]
			Mind.apply_info(g.w, n, unsupported_source, {"role": "hearthwitch", "day": 1, "data": {"nbrs": [source.id, target.id], "count": 1}}, 0.2)
			var unsupported_id = Mind.info_eid(unsupported_source.id, {"role": "hearthwitch", "day": 1, "data": {"nbrs": [source.id, target.id], "count": 1}})
			check(n.workshop_state.active and n.ledger.has(unsupported_id) and not n.workshop_state.owned.has(unsupported_id), "independent unsupported readings retain native ownership without disabling supported evidence")
			Mind.apply_info(g.w, n, source, {"role": "hearthwitch", "day": 1, "data": {"nbrs": [source.id, target.id], "count": 1}}, 0.2)
			check(not n.workshop_state.active and n.workshop_state.issues.any(func(s): return "shares a source" in s), "unsupported reports from the same source cannot be treated as independent background evidence")
			n.ledger[Mind.info_eid(source.id, {"role": "hearthwitch", "day": 1, "data": {"nbrs": [source.id, target.id], "count": 1}})].weight = 0.0
			Mind.recompute_beliefs(g.w, n, "coupled unsupported reading withdrawn")
			check(n.workshop_state.active, "removing the coupled unsupported contribution restores supported ownership")
			var extra = _reading(g, unsupported_source, "hearthwitch", 1, {"nbrs": [source.id, target.id], "count": 1})
			var mixed = g.file_deduction({"type": "evil", "a": target.id}, [card, extra])
			var fallback = g._evaluate_deduction(n, g.board[mixed - 1], 1.0, true)
			# A rejected native argument can contribute nothing; in that case the
			# independent supported evidence need not lose its existing owner.
			check(not fallback.get("workshop", false) and (fallback.agreement == 0.0 or not n.workshop_state.active), "unsupported argument falls back; contributing mixed evidence cannot count only its convenient part")
	check(results[0] == results[1] and results[1] == results[2], "venue does not change interpretation, evidence strength, or sound-argument reward")

func _scrutiny_and_cover() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	n.role = "surveyor"
	var source = g.w.npcs.filter(func(p): return p != n)[0]
	n.suspicion[source.id] = 0.0
	var people = g.w.npcs
	var first = people[0]
	var second = people.filter(func(p): return p.home_block != first.home_block)[0]
	var third = people.filter(func(p): return p.home_block != first.home_block and p.home_block != second.home_block)[0]
	var a = _reading(g, n, "surveyor", 0, {"count": 1})
	var b = _reading(g, source, "dowser", 1, {"group": [first.id, second.id, third.id], "count": 3})
	var conflict = g.file_deduction({"type": "conflict", "group": [n.id, source.id]}, [a, b])
	g.set_workshop_effects(true)
	var result = g._evaluate_deduction(n, g.board[conflict - 1], 1.0, true)
	check(result.get("workshop", false) and result.agreement >= 0.6 and is_equal_approx(n.pressure, 0.1), "accepted conflict scrutiny applies once to an actual cited participant")
	var trust: float = n.trust
	g._evaluate_deduction(n, g.board[conflict - 1], 0.6, true, "meeting")
	check(is_equal_approx(n.pressure, 0.1) and is_equal_approx(n.trust, trust), "venue changes do not duplicate conflict pressure or trust rewards")
	g.board[a - 1].data.count = 2
	var c = _reading(g, source, "dowser", 2, {"group": [first.id], "count": 0})
	var coherent = g.file_deduction({"type": "conflict", "group": [n.id, source.id]}, [a, c])
	var previous: float = n.pressure
	var rejected = g._evaluate_deduction(n, g.board[coherent - 1], 1.0, true)
	if not rejected.get("workshop", false) or rejected.agreement != 0.0:
		print("Coherent diagnostic: ", JSON.stringify({"agreement": rejected.agreement, "dialogue": rejected.get("dialogue"), "shared": rejected.get("assessment", {}).get("shared_assessment", {}), "issues": n.workshop_state.get("issues", [])}))
	check(rejected.get("workshop", false) and rejected.agreement == 0.0 and is_equal_approx(n.pressure, previous), "an unsubstantiated conflict creates no assessment-based scrutiny")
	# Cover reasoning receives reports on repetitions too, even if the real evil
	# chooses a different public stance for strategic reasons.
	var evil = g.w.npcs.filter(func(p): return p.is_evil())[0]
	Mind.shadow_run(g.w, evil, func(sh):
		sh.role = "warden"
		sh.info_log = []
		sh.known_claims = {}
		sh.ledger = {})
	var target = g.w.npcs.filter(func(p): return p != evil and p != source)[0]
	var claim = g.file_deduction({"type": "good", "a": target.id}, [c])
	var real_before = JSON.stringify([evil.suspicion, evil.trust, evil.ledger])
	g._evaluate_deduction(evil, g.board[claim - 1], 0.6, true, "meeting")
	g._evaluate_deduction(evil, g.board[claim - 1], 0.6, true, "meeting")
	check(real_before == JSON.stringify([evil.suspicion, evil.trust, evil.ledger]), "new presentation never awards beliefs or trust to the real evil mind")
	check(evil.shadow.workshop_state.get("presentations", {}).has(str(claim)), "the good cover receives and remembers the real presented argument")
	check(evil.shadow.workshop_state.get("discussion", {}).size() > 0, "cover repetitions use the new assessment rather than skipping cover updates")
	# A supported revision must update the existing presentation, not add its old roots.
	g.board[claim - 1].supports = [b]
	g._evaluate_deduction(evil, g.board[claim - 1], 0.6, true, "meeting")
	var stored: Dictionary = evil.shadow.workshop_state.presentations[str(claim)]
	check(stored.selected == [Evidence.normalize_card(g.board[b - 1]).id], "a revised argument updates the cover's endorsement on a repeated presentation")
	var own_claim = g.file_deduction({"type": "evil", "a": evil.id}, [b])
	g._evaluate_deduction(evil, g.board[own_claim - 1], 0.6, true, "meeting")
	check(evil.shadow.workshop_state.presentations.has(str(own_claim)), "a self-targeting allegation still delivers evidence to the cover while evil keeps its mask")

func _intermediate() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 10)
	for p in g.w.npcs:
		p.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
	var n = g.w.by_id.odette
	n.alignment = "good"
	n.role = "warden"
	n.trust = 0.7
	for id in n.suspicion:
		n.suspicion[id] = 0.3
		n.npc_trust[id] = 1.0
	for id in ["bart", "merrin", "fenwick"]:
		n.suspicion[id] = 0.0
	var survey = _reading(g, g.w.by_id.bart, "surveyor", 0, {"count": 4})
	var rumor = _reading(g, g.w.by_id.merrin, "rumormonger", 0, {"pair": ["nisha", "constance"], "secret": "marked"})
	var dowse = _reading(g, g.w.by_id.fenwick, "dowser", 1, {"group": ["hollis", "lian", "nisha", "constance"], "count": 4})
	var child = g.file_deduction({"type": "evil", "a": "hollis"}, [rumor, dowse])
	var parent = g.file_deduction({"type": "evil", "a": "constance"}, [survey, child])
	g.set_workshop_effects(true)
	var started = Time.get_ticks_msec()
	var result = g._evaluate_deduction(n, g.board[parent - 1], 1.0, true)
	var first_ms = Time.get_ticks_msec() - started
	check(result.get("workshop", false), "a multi-line ten-person case uses the new presentation path")
	if result.get("workshop", false):
		var accepted = result.assessment.claims.filter(func(c): return c.conclusion.target == "hollis")
		check(not accepted.is_empty() and accepted[0].stance == "accept", "the listener can accept an intermediate alignment claim")
		check(result.dialogue.stance != "accept" and "Hollis" in result.dialogue.special, "the reply acknowledges Hollis while retaining uncertainty about Constance")
		check(n.workshop_state.requested.get("hollis", 0.0) > 0, "the acknowledged collateral claim has an actual shared belief effect")
		check(Mind.citable_reason(g.w, n, "hollis", "player") != "" and Mind.citable_reason(g.w, n, "hollis", "town") == "", "joint reasons from a private presentation are citable to that audience only")
		started = Time.get_ticks_msec()
		var previous_input: Array = g._workshop_responses[n.id + ":good"].input.duplicate(true)
		var repeated = g._evaluate_deduction(n, g.board[parent - 1], 1.0, true)
		print("Ten-person grouped presentation cold/repeat: %d/%d ms" % [first_ms, Time.get_ticks_msec() - started])
		var current_input: Array = g._workshop_responses[n.id + ":good"].input
		check(previous_input == current_input and g._workshop_evaluations[n.id + (":cover" if n.is_shadow else ":good")].cache_hit and repeated.repeated, "ten-person repeated cases preserve an exact baseline and reuse both assessments")
		g._evaluate_deduction(n, g.board[parent - 1], 0.6, true, "meeting")
		check(Mind.citable_reason(g.w, n, "hollis", "town") != "", "public presentation makes its shared report-based reason publicly citable")
		g._evaluate_deduction(n, g.board[parent - 1], 1.0, true)
		check(Mind.citable_reason(g.w, n, "hollis", "town") != "", "a later private restatement does not erase an earlier public disclosure")
		n.sus_why.constance = "old argument"
		n.sus_src.constance = n.workshop_state.owned.keys()[0]
		g.workshop_retract(parent, n.id)
		check(Mind.reason_status(g.w, n, "constance").why == "", "withdrawn shared evidence cannot leave an owned legacy accusation as the stated reason")

func _private_reasons() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	n.role = "dowser"
	var source = g.w.npcs.filter(func(p): return p != n)[0]
	var people = g.w.npcs.filter(func(p): return p != n and p != source)
	var target = people[0]
	var a = people[1]
	var b = people[2]
	var own = {"role": "dowser", "day": 1, "phase": 0, "data": {"group": [target.id, a.id, b.id], "count": 3}}
	var rumor = {"role": "rumormonger", "day": 0, "data": {"pair": [a.id, b.id], "secret": "marked"}}
	n.info_log.append(own)
	Mind.apply_info(g.w, n, n, own, 1.0)
	Mind.apply_info(g.w, n, source, rumor, 1.0)
	g.set_workshop_effects(true)
	check(n.workshop_state.active and n.workshop_state.requested.get(target.id, 0.0) >= 0.15, "a joint private inference can supply a substantial real belief effect")
	check(Mind.reason_status(g.w, n, target.id).kind == "shared_private" and Mind.citable_reason(g.w, n, target.id, "town") == "", "unpublished joint reports do not acquire a public citation")
	var rng = g.w.rng.state
	var tier = Mind._accuse_tier(g.w, n, target, n.suspicion[target.id])
	check(tier.tier == "generic" and tier.why == "" and g.w.rng.state == rng, "joint private reasons do not trigger a false own-gift reveal or invented hint")
	var before = n.workshop_state.requested.duplicate(true)
	own["shared"] = true
	rumor["shared"] = true
	Mind.apply_info(g.w, n, n, own, 1.0)
	Mind.apply_info(g.w, n, source, rumor, 1.0)
	check(Mind.reason_status(g.w, n, target.id).kind == "public", "explicit public disclosures make independently learned joint roots citable")
	check(_close(before, n.workshop_state.requested), "publishing already learned roots changes disclosure, not evidence strength")

func _self_support_paths() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	var source = g.w.living_good()[1]
	var target = g.w.living_good()[2]
	var number = _reading(g, source, "dowser", 1, {"group": [target.id], "count": 1})
	g.set_workshop_effects(true)
	var root = Evidence.normalize_card(g.board[number - 1]).id
	var heard = Mind.hear_defence(g.w, n, n, g.board[number - 1])
	check(heard.get("workshop", false) and root in n.workshop_state.facts, "a raw self-defence hears the evidence before deciding its reply")
	check(n.workshop_state.requested.get(target.id, 0.0) > 0.0, "a self-defence can update collateral beliefs about others")
	var evil = g.w.npcs.filter(func(p): return p.is_evil())[0]
	var rng = g.w.rng.state
	var own = Mind.hear_defence(g.w, evil, evil, g.board[number - 1])
	check(own.get("workshop", false) and root in evil.shadow.workshop_state.facts, "evil's self-defence delivers the same evidence to its cover")
	check(g.w.rng.state == rng, "evaluating a self-defence adds no game RNG draw")
	# Put the accused listener first: its self-good check must not discard all
	# collateral evidence from the group submission.
	var group_reply = Mind.hear_group_case(g.w, evil, [evil, target], g.board[number - 1])
	check(evil.shadow.workshop_state.presentations.keys().any(func(key): return str(key).begins_with("direct:%d:accuse:" % number)), "an accusation group containing evil still reaches its cover")
	check(group_reply.get("workshop", false), "a strategic evil group reply still reports the actual shared belief engine")
	var defence_reply = Mind.hear_defence(g.w, evil, [evil, target], g.board[number - 1])
	check(evil.shadow.workshop_state.presentations.keys().any(func(key): return str(key).begins_with("direct:%d:defend:" % number) and target.id in str(key)), "a defence group containing evil still reaches its cover")
	check(defence_reply.get("workshop", false), "a strategic evil defence still reports shared belief delivery")
	var accused = Mind.hear_accusation(g.w, evil, evil, g.board[number - 1])
	check(accused.get("workshop", false), "an evil self-accusation keeps its mask while reporting shared belief delivery")
	var fixed = evil.shadow.suspicion.duplicate(true)
	Mind.recompute_beliefs(g.w, evil.shadow, "self/group repeat")
	check(_close(fixed, evil.shadow.suspicion), "self and group roots cannot stack their original evidence")

func _close(a: Dictionary, b: Dictionary) -> bool:
	return a.size() == b.size() and a.keys().all(func(k): return b.has(k) and absf(a[k] - b[k]) < 0.000001)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
