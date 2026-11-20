extends SceneTree
const GamePresentation = preload("res://game/game_presentation.gd")
const GameBoard = preload("res://game/game_board.gd")
const Game = preload("res://game/game.gd")
const Speech = preload("res://tools/speech.gd")
const Mind = preload("res://sim/mind.gd")
const Presentation = preload("res://game/workshop_presentation.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const LiveCanvas = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_direct_and_migration()
	_venues_and_mixed()
	_cover()
	_intermediate()
	_private_reasons()
	_self_support_paths()
	_trapped_group_response()
	print("Workshop presentation: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
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
	return GameBoard.add_card(g, {"kind": "info", "source": source.id, "role": role, "day": day, "phase": 3 if day == 0 else 0,
		"data": data, "text": "%s's %s report at %d: %s" % [source.name, role, day, JSON.stringify(data)]})

func _trapped_group_response() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	var others = g.w.npcs.filter(func(p): return p != n)
	var block = "market" if n.home_block != "market" else "docks"
	n.history[g.w.time_key(1, 3)] = "night:" + block
	var alibi = GameBoard.add_card(g, {"kind": "alibi", "subject": [n.id], "source": n.id, "day": 1, "phase": 3, "home": true, "text": "I stayed home."})
	var sight = GameBoard.add_card(g, {"kind": "sighting", "subject": [n.id], "source": "player", "day": 1, "phase": 3, "block": block, "text": "Seen away from home."})
	var canvas = Canvas.new(LiveCanvas.view(g))
	var root: String = canvas.add_premise(n.id, "evil", Vector2.ZERO)
	var a: String = "e:" + Evidence.normalize_card(g.board[alibi - 1]).id
	var b: String = "e:" + Evidence.normalize_card(g.board[sight - 1]).id
	canvas.connect_cards(a, b)
	canvas.connect_cards(canvas.selected, root)
	var number: int = LiveCanvas.file(g, canvas.compile(root))
	check(number > 0, "challenged home alibi can be filed for a group presentation")
	if number <= 0: return
	var result: Dictionary = Presentation.present(g, n, g.board[number - 1], [others[0].id, others[1].id], "accuse", "private", true)
	check(result.get("workshop", false), "challenged alibi is supported in group presentation")
	if not result.get("workshop", false): return
	var expected: String = Mind.Dialogue.voice_line(n.id, "trapped_night_out", "Fine, I was out. Doesn't mean I was doing anything wrong.")
	check(result.dialogue.special.begins_with(expected) and ("About " + others[1].name + ":") in result.dialogue.special, "group response includes the voiced admission and the second target assessment")
	check(result.lines.size() == 1 and Speech.shown(result.lines[0]) == result.dialogue.special, "spoken group response retains the complete assessed response")

func _direct_and_migration() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	var source = g.w.npcs.filter(func(p): return p != n)[0]
	var target = g.w.npcs.filter(func(p): return p != n and p != source)[0]
	var card = _reading(g, source, "dowser", 1, {"group": [target.id], "count": 0})
	var first_def = Mind.hear_defence(g.w, n, target, g.board[card - 1])
	check(first_def.get("workshop", false) and n.workshop_state.active and n.workshop_state.owned.size() == 1, "direct card defence uses shared presentation and acquires one owner")
	check(n.ledger.values().any(func(e): return e.meta.get("kind") == "tell" and e.meta.has("workshop_card")), "card presentations retain an exact original receipt")
	var baseline = n.suspicion.duplicate(true)
	n.pressed_today = 0
	var result = Mind.hear_defence(g.w, n, target, g.board[card - 1])
	# The voiced stance follows the belief refresh (Oct 26): a retold report moves nothing.
	check(result.get("workshop", false) and (result.dialogue.stance == result.assessment.stance or result.dialogue.special.contains("already")), "direct defence dialogue uses the applied model's assessment (or says it already knew)")
	check(_close(baseline, n.suspicion), "retelling the same directly learned report adds no second effect")
	var ded = GameBoard.file_deduction(g, {"type": "good", "a": target.id}, [card])
	var trust = n.trust
	var filed = GamePresentation._evaluate_deduction(g, n, g.board[ded - 1], 1.0, true)
	check(filed.get("workshop", false) and _close(baseline, n.suspicion), "wrapping a directly learned card in a deduction does not stack")
	check(is_equal_approx(trust, n.trust), "the same original facts cannot farm sound-argument trust rewards")
	var bad = GameBoard.file_deduction(g, {"type": "evil", "a": target.id}, [card])
	var rejected = GamePresentation._evaluate_deduction(g, n, g.board[bad - 1], 1.0, true)
	check(rejected.get("workshop", false) and rejected.dialogue.stance == "reject", "an accusation contradicted by the report is rejected by the new model")
	check(Speech.said(rejected.lines[0]) == rejected.dialogue.special and _close(baseline, n.suspicion), "spoken rejection and collateral exoneration derive from the same reports")
	n.pressed_today = 0
	var cited = Mind.hear_accusation(g.w, n, target, g.board[ded - 1])
	check(cited.get("workshop", false) and n.workshop_state.active, "citing a deduction as a card follows original evidence instead of promoting its label")
	check(not n.player_cases.is_empty() and n.player_cases[-1].card.supports == g.board[ded - 1].supports, "a supported private accusation remains available to ordinary NPC gossip with its original case")
	check(_close(baseline, n.suspicion), "deduction-as-card presentation cannot duplicate its original report")
	# The rejected accusation above cost trust (premises step 1, a clearly wrong premise), so
	# the defence is judged afresh for the new audience rather than flagged as a repeat; it
	# still awards no evidence a second time.
	var repeat_result = GamePresentation._evaluate_deduction(g, n, g.board[ded - 1], 0.6, true, "meeting")
	check("unchanged" not in repeat_result.dialogue.special and _close(baseline, n.suspicion), "a new audience receives an explanation without another evidence award")
	repeat_result = GamePresentation._evaluate_deduction(g, n, g.board[ded - 1], 0.6, true, "meeting")
	check(repeat_result.repeated and "unchanged" in repeat_result.dialogue.special, "repeating the explanation to the same audience is recognized")
	var before_public = n.suspicion.duplicate(true)
	Mind.public_case(g.w, target, g.board[card - 1], "accuse")
	check(n.workshop_state.active and _close(before_public, n.suspicion), "public raw-card accusation shares the same report owner as private defence and deductions")
	var group = [target, source]
	n.pressed_today = 0
	var grouped = Mind.hear_group_case(g.w, n, group, g.board[card - 1])
	check(grouped.get("workshop", false) and n.workshop_state.facts.size() == 1, "group presentations assess individual questions against one shared evidence set")

func _venues_and_mixed() -> void:
	var results: Array = []
	for venue in ["private", "meeting", "nomination"]:
		var g = _game()
		var n = g.w.living_good()[0]
		var source = g.w.npcs.filter(func(p): return p != n)[0]
		var target = g.w.npcs.filter(func(p): return p != n and p != source)[0]
		var card = _reading(g, source, "dowser", 1, {"group": [target.id], "count": 0})
		var ded = GameBoard.file_deduction(g, {"type": "good", "a": target.id}, [card])
		var response = GamePresentation._evaluate_deduction(g, n, g.board[ded - 1], 1.0 if venue == "private" else 0.6 if venue == "meeting" else 0.5, true, venue)
		check(response.get("workshop", false), "supported deduction uses unified presentation at " + venue)
		results.append([response.agreement, n.suspicion.duplicate(true), n.trust])
		if venue == "private":
			var vector: Dictionary = n.workshop_state.requested.duplicate(true)
			Mind.refresh_beliefs(g.w, n, "unchanged inputs")
			check(g._workshop_evaluations[n.id + (":cover" if n.is_shadow else ":good")].cache_hit and _close(vector, n.workshop_state.requested), "unchanged joint reassessment reuses an exact cached input without changing effects")
			n.npc_trust[source.id] = 0.1
			Mind.refresh_beliefs(g.w, n, "source credibility changed")
			check(not g._workshop_evaluations[n.id + (":cover" if n.is_shadow else ":good")].cache_hit and not _close(vector, n.workshop_state.requested), "source trust invalidates the aggregate cache")
			n.npc_trust[source.id] = 1.0
			Mind.refresh_beliefs(g.w, n, "source credibility restored")
			check(_close(vector, n.workshop_state.requested), "restoring source trust restores the same joint vector")
			var unsupported_source = g.w.npcs.filter(func(p): return p != n and p != source and p != target)[0]
			Mind.apply_info(g.w, n, unsupported_source, {"role": "hearthwitch", "day": 1, "data": {"nbrs": [source.id, target.id], "count": 1}}, 0.2)
			var unsupported_id = Mind.info_eid(unsupported_source.id, {"role": "hearthwitch", "day": 1, "data": {"nbrs": [source.id, target.id], "count": 1}})
			check(n.workshop_state.active and n.ledger.has(unsupported_id) and not n.workshop_state.owned.has(unsupported_id), "independent unsupported readings retain native ownership without disabling supported evidence")
			var hw_eid = Mind.info_eid(source.id, {"role": "hearthwitch", "day": 1, "data": {"nbrs": [source.id, target.id], "count": 1}})
			Mind.apply_info(g.w, n, source, {"role": "hearthwitch", "day": 1, "data": {"nbrs": [source.id, target.id], "count": 1}}, 0.2)
			n.ledger[hw_eid].effects = [[target.id, 0.1, false, "coupled legacy probe", ""]]
			var before_coupled: Dictionary = n.suspicion.duplicate(true)
			Mind.refresh_beliefs(g.w, n, "coupled unsupported probe")
			check(_close(n.suspicion, before_coupled) and n.workshop_state.issues.any(func(s): return "shares a source" in s), "coupled unsupported entry keeps last good vector and flags shared-source issue")
			n.ledger[hw_eid].weight = 0.0
			Mind.refresh_beliefs(g.w, n, "coupled unsupported reading withdrawn")
			check(n.workshop_state.active and n.workshop_state.issues.is_empty(), "removing the coupled unsupported contribution clears the issue")
			var extra = _reading(g, unsupported_source, "hearthwitch", 1, {"nbrs": [source.id, target.id], "count": 1})
			var mixed = GameBoard.file_deduction(g, {"type": "evil", "a": target.id}, [card, extra])
			var fallback = GamePresentation._evaluate_deduction(g, n, g.board[mixed - 1], 1.0, true)
			# A rejected native argument can contribute nothing; in that case the
			# independent supported evidence need not lose its existing owner.
			check(not fallback.get("workshop", false) and (fallback.agreement == 0.0 or not n.workshop_state.active), "unsupported argument falls back; contributing mixed evidence cannot count only its convenient part")
	check(results[0] == results[1] and results[1] == results[2], "venue does not change interpretation, evidence strength, or sound-argument reward")

func _cover() -> void:
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
	g.board[a - 1].data.count = 2
	var c = _reading(g, source, "dowser", 2, {"group": [first.id], "count": 0})
	# Cover reasoning receives reports on repetitions too, even if the real evil
	# chooses a different public stance for strategic reasons.
	var evil = g.w.npcs.filter(func(p): return p.is_evil())[0]
	Mind.shadow_run(g.w, evil, func(sh):
		sh.role = "warden"
		sh.info_log = []
		sh.known_claims = {}
		sh.ledger = {})
	var target = g.w.npcs.filter(func(p): return p != evil and p != source)[0]
	var claim = GameBoard.file_deduction(g, {"type": "good", "a": target.id}, [c])
	var real_before = JSON.stringify([evil.suspicion, evil.trust, evil.ledger])
	GamePresentation._evaluate_deduction(g, evil, g.board[claim - 1], 0.6, true, "meeting")
	GamePresentation._evaluate_deduction(g, evil, g.board[claim - 1], 0.6, true, "meeting")
	check(real_before == JSON.stringify([evil.suspicion, evil.trust, evil.ledger]), "new presentation never awards beliefs or trust to the real evil mind")
	check(evil.shadow.workshop_state.get("presentations", {}).has(str(claim)), "the good cover receives and remembers the real presented argument")
	check(evil.shadow.workshop_state.get("discussion", {}).size() > 0, "cover repetitions use the new assessment rather than skipping cover updates")
	# A supported revision must update the existing presentation, not add its old roots.
	g.board[claim - 1].supports = [b]
	GamePresentation._evaluate_deduction(g, evil, g.board[claim - 1], 0.6, true, "meeting")
	var stored: Dictionary = evil.shadow.workshop_state.presentations[str(claim)]
	check(stored.selected == [Evidence.normalize_card(g.board[b - 1]).id], "a revised argument updates the cover's endorsement on a repeated presentation")
	var own_claim = GameBoard.file_deduction(g, {"type": "evil", "a": evil.id}, [b])
	GamePresentation._evaluate_deduction(g, evil, g.board[own_claim - 1], 0.6, true, "meeting")
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
	# This fixture exercises uptake of a trusted intermediate case, not low-credibility rejection.
	n.credibility = 1.0
	n.alignment = "good"
	# The listener is the Dowser (Oct 30). This used to be Fenwick's reading, trusted only
	# because suspicion 0.0 read as near-proven good. Under the relative prior a 4-of-4
	# count from an unvetted source is better explained by a lie (likelihood 0.2) than by
	# the whole evil team plus the Marked standing in one group, so the listener's own
	# reading carries the case instead, as the intermediate-claim check intends.
	n.role = "dowser"
	n.trust = 0.7
	for id in n.suspicion:
		n.suspicion[id] = 0.3
		n.npc_trust[id] = 1.0
	for id in ["bart", "merrin", "fenwick"]:
		n.suspicion[id] = 0.0
	var survey = _reading(g, g.w.by_id.bart, "surveyor", 0, {"count": 4})
	var rumor = _reading(g, g.w.by_id.merrin, "rumormonger", 0, {"pair": ["nisha", "constance"], "secret": "marked"})
	var own_dowse = {"role": "dowser", "day": 1, "phase": 0, "data": {"group": ["hollis", "lian", "nisha", "constance"], "count": 4}}
	n.info_log.append(own_dowse)
	var dowse = _reading(g, n, "dowser", 1, own_dowse.data)
	var child = GameBoard.file_deduction(g, {"type": "evil", "a": "hollis"}, [rumor, dowse])
	var parent = GameBoard.file_deduction(g, {"type": "evil", "a": "constance"}, [survey, child])
	var started = Time.get_ticks_msec()
	var result = GamePresentation._evaluate_deduction(g, n, g.board[parent - 1], 1.0, true)
	var first_ms = Time.get_ticks_msec() - started
	check(result.get("workshop", false), "a multi-line ten-person case uses the new presentation path")
	if result.get("workshop", false):
		var accepted = result.assessment.claims.filter(func(c): return c.conclusion.target == "hollis")
		# Partial is the honest ceiling here (Oct 30): the count says three of the four are
		# evil and one is the Marked, and Hollis is the Marked unless Merrin's rumour holds.
		check(not accepted.is_empty() and accepted[0].stance in ["accept", "partial"] and n.workshop_state.get("requested", {}).get("hollis", 0.0) >= 0.3, "the listener can take up an intermediate alignment claim")
		check("Hollis" in result.dialogue.special and (result.dialogue.stance != "accept" or "does not by itself settle Constance" in result.dialogue.special), "the reply acknowledges Hollis while retaining uncertainty about Constance")
		check(n.workshop_state.requested.get("hollis", 0.0) > 0, "the acknowledged collateral claim has an actual shared belief effect")
		check(Mind.citable_reason(g.w, n, "hollis", "player") != "" and Mind.citable_reason(g.w, n, "hollis", "town") == "", "joint reasons from a private presentation are citable to that audience only")
		started = Time.get_ticks_msec()
		var previous_input: Array = g._workshop_responses[n.id + ":good"].input.duplicate(true)
		var repeated = GamePresentation._evaluate_deduction(g, n, g.board[parent - 1], 1.0, true)
		print("Ten-person grouped presentation cold/repeat: %d/%d ms" % [first_ms, Time.get_ticks_msec() - started])
		var current_input: Array = g._workshop_responses[n.id + ":good"].input
		# The refresh after a presentation can settle once (theory commitment), so the union
		# cache may miss on the repeat; the reply assessment is still reused exactly.
		check(previous_input == current_input and repeated.repeated, "ten-person repeated cases preserve an exact baseline and reuse the reply assessment")
		GamePresentation._evaluate_deduction(g, n, g.board[parent - 1], 0.6, true, "meeting")
		check(Mind.citable_reason(g.w, n, "hollis", "town") != "", "public presentation makes its shared report-based reason publicly citable")
		GamePresentation._evaluate_deduction(g, n, g.board[parent - 1], 1.0, true)
		check(Mind.citable_reason(g.w, n, "hollis", "town") != "", "a later private restatement does not erase an earlier public disclosure")
		g.workshop_retract(parent, n.id)

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
	check(n.workshop_state.active and n.workshop_state.requested.get(target.id, 0.0) >= 0.15, "a joint private inference can supply a substantial real belief effect")
	check(Mind.reason_status(g.w, n, target.id).kind == "private" and Mind.citable_reason(g.w, n, target.id, "town") == "", "unpublished joint reports do not acquire a public citation")
	var tier = Mind._accuse_tier(g.w, n, target, n.suspicion[target.id])
	check(tier.tier in ["reveal", "hint"] and (tier.tier == "reveal" or tier.why == ""), "an actual own Dowser reading can trigger its normal reveal or hint decision")
	var before = n.workshop_state.requested.duplicate(true)
	n.claim_public = true
	n.claimed_role = "dowser"
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
	Mind.refresh_beliefs(g.w, evil.shadow, "self/group repeat")
	check(_close(fixed, evil.shadow.suspicion), "self and group roots cannot stack their original evidence")

func _close(a: Dictionary, b: Dictionary) -> bool:
	return a.size() == b.size() and a.keys().all(func(k): return b.has(k) and absf(a[k] - b[k]) < 0.000001)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
