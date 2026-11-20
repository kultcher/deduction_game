## Live canvas boundary. Only player board receipts cross into the editor.
extends RefCounted
const Bridge = preload("res://game/workshop_bridge.gd")
const Tuning = preload("res://sim/tuning.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Assess = preload("res://workshop/live_assessment.gd")

static func view(g) -> Dictionary:
	var numbers: Array = g.board.filter(func(c): return not c.get("deleted", false) and not c.get("tavern_gossip", false) and c.get("workshop_usable", true) and c.kind != "deduction").map(func(c): return c.n)
	var profile_ids = {}
	for pr in g.profile_receipts:
		numbers.append(pr.n)
		profile_ids[Evidence.normalize_card(pr).id] = true
	var snapshot = Bridge.capture(g, numbers)
	# The board's short form for each card, for the canvas's evidence cards (Michael, Nov 18:
	# the fewest words on a card, the full sentence on hover). Display only.
	var CardModel = load("res://game/card_model.gd")
	var names: Dictionary = {}
	for p in g.w.npcs:
		names[p.id] = p.name
	var shorts: Dictionary = {}
	for number in numbers:
		if number >= 1 and number <= g.board.size():
			var board_card: Dictionary = g.board[number - 1]
			shorts[Evidence.normalize_card(board_card).id] = str(CardModel.short_text(board_card, names)).replace("\n", " ")
	var cards: Array = []
	for receipt in snapshot.evidence:
		var content: Dictionary = receipt.content
		# The note under a Workshop card, in the player's words (Michael, Nov 19). Whether the
		# Workshop can weigh the card is the `fallback` flag, not the note's wording.
		var note = "The Workshop can't weigh this card yet."
		var fallback: bool = true
		if (receipt.kind == "claim" and content.get("role") in Assess.C.GOOD_ROLES) or (receipt.kind in ["sighting", "alibi"] and receipt.observed_at.phase == "night"):
			note = "Testimony and circumstance: not proof of evil."
			fallback = false
		var activity = Assess.activity_card(receipt, snapshot)
		if receipt.kind == "info" and content.get("role") == "medium":
			activity = Assess.medium_card(receipt, snapshot)
			if activity.is_empty():
				activity = Assess.testimony_card(receipt, snapshot)
		elif receipt.kind == "info" and content.get("anonymous", false):
			activity = Assess.testimony_card(receipt, snapshot)
		if not activity.is_empty():
			note = ""
			fallback = false
			if activity.kind == "town_hall":
				note = "Town Hall records: exactly one of these two gifts is in play."
			elif activity.kind in ["context", "location"]:
				note = "Where someone was: not a sign of guilt on its own."
		if receipt.kind == "info" and content.get("role") in Assess.ROLES:
			note = ""
			fallback = false
			if not Assess.Domain.gift_time({"role": content.role, "observed_at": receipt.observed_at}):
				note = "The Workshop can't weigh a reading from this time yet."
				fallback = true
			var ids: Array = snapshot.people.map(func(p): return p.id)
			if not Assess.reading_valid(receipt, ids, snapshot.rules.modifier_options):
				note = "This reading is missing details, so the Workshop can't weigh it."
				fallback = true
			if content.role == "medium" and activity.is_empty():
				note = "The Workshop needs the original reading, when it was taken and whose it was before it can weigh this."
				fallback = true
		cards.append({"id": receipt.id, "fact_id": receipt.id, "kind": "report" if receipt.kind == "info" else receipt.kind,
			"source": receipt.source, "subject": receipt.subjects[0] if not receipt.subjects.is_empty() else "", "subjects": receipt.subjects.duplicate(),
			"role": content.get("role", ""), "data": content.get("data", {}).duplicate(true),
			"night": receipt.observed_at.day if receipt.observed_at.phase == "night" or content.get("role") in ["martyr", "sexton"] else -1,
			"block": content.get("block", ""), "observed_at": receipt.observed_at,
			"reported_at": receipt.reported_at if receipt.reported_at != null else {"day": "?"},
			"learned_at": receipt.learned_at if receipt.learned_at != null else {"day": "?"},
			"acquired_day": receipt.learned_at.day if receipt.learned_at != null else snapshot.now.day,
			"text": receipt.text, "short": shorts.get(receipt.id, receipt.text), "support_note": note, "fallback": fallback, "profile_receipt": profile_ids.has(receipt.id)})
		if not activity.is_empty():
			cards[-1].merge(activity, true)
			cards[-1].support_note = "A passed-on reading: a challenge says which part failed, the passing-on or the original." if activity.has("relay_source") else note
			# An adapted relay or teller's testimony is weighable even where the outer reading
			# alone isn't (Codex, #348): the old note override made these supported.
			if activity.has("relay_source") or activity.get("testimony_only", false):
				cards[-1].fallback = false
			if activity.get("testimony_only", false):
				cards[-1].support_note = "Context only: " + activity.context_note if activity.kind == "context" else "Hearsay: the teller can't say whose reading it was, or prove the gift."
	# Excuses for a caught "I was home" soften or contradict it, as in a listener's view.
	Assess._mark_excuses(cards, int(snapshot.now.day))
	var history = Assess.History.chronology(snapshot.public_events, snapshot.people, snapshot.now)
	var result = {"seed": g.w.seed_value, "day": snapshot.now.day, "people": snapshot.people, "cards": cards,
		"profile_facets": _profile_facets(g),
		"evil_count": snapshot.rules.initial_evil_count, "alignment_epoch": "Original alignment",
		"world_options": {"modifiers": snapshot.rules.modifier_options}, "live": true, "live_activity": true,
		# The script's minions, as a listener's view carries them, so the canvas knows when a
		# Mistaken call has a Poisoner to blame (ReadingChallenges.honest_allowed; Nov 18).
		"script_minions": snapshot.rules.get("minions", []).duplicate(),
		"timeline": Assess.History.from_events(snapshot.public_events)}
	if not history.value.is_empty():
		result["chronology"] = history.value
		result.alignment_epoch = "Current alignment"
	return result

## Resolve exact original facts afresh. Missing/deleted evidence is a blocker, never
## permission to file a weaker argument with fewer roots.
static func _profile_facets(g) -> Dictionary:
	var out = {}
	var C = Assess.C
	for n in g.w.npcs:
		var hw_recs: Array = g.profile_receipts_for(n.id, "home_work")
		var haunt_recs: Array = g.profile_receipts_for(n.id, "haunts")
		var trait_recs: Array = g.profile_receipts_for(n.id, "personality")
		var bond_recs: Array = g.profile_receipts_for(n.id, "bonds")
		var haunt_names: Array = haunt_recs.map(func(c): return g.w.loc_name(c.get("loc", c.get("locs", [""])[0])))
		var latest_traits = {}
		for c in trait_recs:
			latest_traits[c.get("trait", "")] = c.get("tier", "?") + (" (bereaved)" if c.get("withdrawn", false) else "")
		var trait_parts: Array = []
		for k in C.TRAITS:
			if latest_traits.has(k):
				trait_parts.append("%s: %s" % [k.capitalize(), latest_traits[k]])
		var bond_parts: Array = []
		for c in bond_recs:
			var others: Array = c.get("subject", []).filter(func(pid): return pid != n.id)
			if not others.is_empty() and g.w.by_id.has(others[0]):
				bond_parts.append("%s with %s" % ["Close" if c.get("bond_kind") == "friend" else "At odds", g.w.by_id[others[0]].name])
		out[n.id] = {
			"home_work": {
				"unlocked": not hw_recs.is_empty(),
				"summary": "Lives on %s · %s (%s at %s)" % [C.block_name(n.home_block), n.occupation.capitalize(), C.phase_list(n.work_phases), g.w.loc_name(n.work)],
				"receipt_ids": hw_recs.map(func(c): return Evidence.normalize_card(c).id),
			},
			"haunts": {
				"unlocked": not haunt_recs.is_empty(),
				"summary": ("Often at " + ", ".join(PackedStringArray(haunt_names)) + (" (1 of 2 known)" if haunt_recs.size() < 2 else " (both known)")) if not haunt_recs.is_empty() else "Unknown (ask around town)",
				"receipt_ids": haunt_recs.map(func(c): return Evidence.normalize_card(c).id),
			},
			"personality": {
				"unlocked": not trait_recs.is_empty(),
				"summary": ", ".join(PackedStringArray(trait_parts)) if not trait_parts.is_empty() else "Unobserved (talk or ask around)",
				"receipt_ids": trait_recs.map(func(c): return Evidence.normalize_card(c).id),
			},
			"bonds": {
				"unlocked": not bond_recs.is_empty(),
				"summary": ", ".join(PackedStringArray(bond_parts)) if not bond_parts.is_empty() else "None learned yet",
				"receipt_ids": bond_recs.map(func(c): return Evidence.normalize_card(c).id),
			},
		}
	return out

static func supports(g, value: Dictionary) -> Dictionary:
	var numbers: Array = []
	var missing: Array = []
	var pool: Array = g.all_receipts()
	for id in value.cards:
		var matches: Array = pool.filter(func(c): return c.kind != "deduction" and not c.get("deleted", false) and Evidence.normalize_card(c).id == id)
		if matches.is_empty():
			missing.append("Missing or changed original evidence: " + id)
		else:
			numbers.append(matches[0].n)
	return {"numbers": numbers, "issues": missing}

static func snapshot(g, value: Dictionary, listener: String = "", venue: String = "private", extra_numbers: Array = []) -> Dictionary:
	var roots = supports(g, value)
	var input = Bridge.capture(g, roots.numbers + extra_numbers.filter(func(x): return x not in roots.numbers), listener, venue)
	input.root = -1
	input.arguments = [{"board_number": -1, "supports": roots.numbers,
		"conclusion": native_conclusion(g, value.conclusion), "workshop_case": value.duplicate(true)}]
	for issue in roots.issues:
		input.issues.append({"code": "missing_card", "detail": issue})
	return input

static func native_conclusion(g, conclusion: Dictionary) -> Dictionary:
	var result = {"type": conclusion.type, "a": conclusion.target}
	for field in ["role", "mod", "night"]:
		if conclusion.has(field):
			result[field] = conclusion[field]
	if conclusion.has("report"):
		var reports: Array = g.board.filter(func(c): return c.kind != "deduction" and Evidence.normalize_card(c).id == conclusion.report)
		if not reports.is_empty():
			result["card"] = reports[0].n
	return result

static func status(g, value: Dictionary) -> Dictionary:
	var input = snapshot(g, value)
	# Use a synthetic profile for capability checks, without running the expensive
	# numerical preview or looking at any real listener's private knowledge.
	input.listener = {"id": "ghost", "name": "Neutral reference", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "source_doubt": {}, "own_gift": ""}
	var prepared = Assess.prepare(input)
	var issues: Array = prepared.issues.duplicate()
	var audience_ready = true
	# Reuse the same exact graph for each real listener; capability checks never
	# evaluate numbers or reveal the listener's private evidence to the player.
	for real in g.w.living():
		var n = real.shadow if real.is_evil() else real
		if n == null:
			audience_ready = false
			continue
		var scoped = snapshot(g, value, n.id)
		var check = Assess.prepare(scoped)
		if not check.ready:
			audience_ready = false
			continue
		var proposals: Dictionary = n.workshop_state.get("presentations", {}).duplicate(true)
		proposals["draft"] = scoped
		var plan = preload("res://workshop/shared_ledger.gd").prepare(Bridge.capture(g, [], n.id, "private", n), proposals, n.ledger, n.workshop_state.get("withdrawn", {}))
		if not check.ready or not plan.ready:
			audience_ready = false
			for issue in check.issues + plan.issues:
				if issue not in issues:
					issues.append(issue)
	var blocked = not supports(g, value).issues.is_empty() or value.cards.is_empty()
	if value.cards.is_empty():
		issues.append("Connect evidence to the selected premise before filing.")
	return {"ready": prepared.ready and not blocked, "audience_ready": audience_ready, "blocked": blocked, "issues": issues}

static func file(g, value: Dictionary, previous: int = 0) -> int:
	if g.workshop_presenting:
		g.last_error = "Wait for the current presentation to finish before changing a filed case."
		return -1
	if previous > 0 and previous <= g.board.size() and g.board[previous - 1].get("deleted", false):
		previous = 0
	while previous > 0 and previous <= g.board.size() and g.board[previous - 1].get("superseded_by", 0) > 0:
		previous = g.board[previous - 1].superseded_by
	var check = status(g, value)
	if check.blocked:
		g.last_error = "\n".join(PackedStringArray(player_issues(g, value, check.issues, previous)))
		return -1
	var roots = supports(g, value)
	var conclusion = native_conclusion(g, value.conclusion)
	if previous > 0 and previous <= g.board.size() and g.board[previous - 1].get("workshop_case", {}) == value:
		return previous
	# Build native fallback footing through the ordinary filer, then retain the
	# entire graph. A unique label prevents text-based card merging across drafts.
	var old_size: int = g.board.size()
	var number = g.file_deduction(conclusion, roots.numbers, true)
	if number < 1:
		return number
	var card: Dictionary = g.board[number - 1].duplicate(true)
	card["workshop_case"] = value.duplicate(true)
	card["text"] = "Case: %s (%d original reports)." % [g.Deduction.conclusion_text(g.w, conclusion), roots.numbers.size()]
	# A revision is a new historical receipt. Listeners retain the version they
	# actually heard until the new card is presented.
	if previous > 0 and previous <= g.board.size() and g.board[previous - 1].has("workshop_case"):
		card["revises"] = previous
		g.board[previous - 1]["superseded_by"] = number
		g.board[previous - 1].text += " (Superseded by case #%d.)" % number
	# The native filer may have returned a pre-existing flat deduction. Never
	# overwrite that card or turn another draft into this graph.
	# The log says which case this one replaces ("revises", 0 for a new case): a replay
	# files it the same way, or the superseded case would still stand (case 16010, Nov 18).
	var revises: int = int(card.get("revises", 0))
	if number > old_size:
		g.board[number - 1] = card
	else:
		number = g.add_card(card)
	if number < 1:
		return number
	g.w.dlog.add("workshop_canvas_filed", "player", conclusion.get("a", ""), {"card": number, "revision": revises > 0, "revises": revises, "case": value, "supports": roots.numbers})
	if g.state_digests:
		g.w.dlog.add("state_digest", "", "", g.w.state_digest())
	return number

## The test juror: how an average listener would take the case, put to the town today
## (Michael, Nov 19, juror fix (a), option (i)): the full listener path
## (Connections.judge_for_profile: credibility 0.5, trust 0.5, nothing first-hand, each card
## weighed as heard and the case's own joining at the filing day's weight). Its strength
## (`lr`) is how far that listener's chance of the premise moves, as an odds ratio; the badge
## is cut from it (CaseEval.category). No full-weight figure is kept. CaseEval still reads the
## case's shape for the words around the badge (cards that clash, what it rests on, guards).
## Says why a case can't be judged yet when it can't. The Workshop runs it after a pause in
## editing.
static func test_juror(g, value: Dictionary, hear_claims: bool = true) -> Dictionary:
	var juror: Dictionary = juror_case(g, value, hear_claims)
	if not juror.ready:
		return {"ready": false, "issues": juror.issues}
	var heard: Dictionary = listener_reading(g, value)
	if not heard.ready:
		return {"ready": false, "issues": heard.issues}
	var prepared = juror.prepared
	var judged: Dictionary = juror.case
	var CaseEval = preload("res://workshop/case_eval.gd")
	var ev: Dictionary = CaseEval.evaluate(prepared.view, judged)
	if not ev.get("impossible", false):
		ev.lr = heard.lr
		# The top tier reads the listener's chance only where that chance is the premise's own
		# (Herald and Codex on #358): an accusing premise (would the town vote for them), "is
		# good" and "is not the Demon". Elsewhere it's the target's chance of being good or evil,
		# which doesn't settle "holds their gift", "was misled" and the like, nor a conflict.
		ev.category = CaseEval.category(heard.lr, top_tier_chance(str(value.get("conclusion", {}).get("type", "")), float(heard.chance)))
	var result: Dictionary = CaseEval.strength_from(ev)
	result["ready"] = true
	result["issues"] = []
	result["listener"] = {"before": heard.before, "after": heard.after, "chance_before": heard.chance_before, "chance": heard.chance, "presses": heard.presses, "challenges": heard.challenges}
	feedback(prepared.view, judged, ev, result)
	guard_reasons(prepared.view, judged, ev, result)
	# A weak or contrary accusation that points more at someone else (Michael, Nov 20): the
	# rule a listener uses to say "points elsewhere", naming no one here.
	var c_type: String = str(value.get("conclusion", {}).get("type", ""))
	if c_type in POINTS_ELSEWHERE_TYPES and str(result.get("category", "")) in POINTS_ELSEWHERE_BANDS:
		var Presentations = preload("res://sim/dialogue_presentations.gd")
		if Presentations.points_elsewhere(g.w, ev.get("rivals", []), [str(value.get("conclusion", {}).get("target", ""))]) != "":
			result["points_elsewhere"] = true
	# A challenge is weighed as the listener weighs it (its grounds decide whether it's
	# accepted), no longer assumed to hold; the readings it questions are still listed, for the
	# words around the badge. (Herald drafts a line for an ungrounded challenge.)
	var aside: Array = juror.get("set_aside", [])
	if not aside.is_empty():
		result["set_aside"] = aside
	return result

## The judge's own reading of how the case's cards fit together (CaseEval over the juror's
## case, every card at full weight): {ready, issues, lr, category}. Never shown to the player
## as a strength (Michael, Nov 19: no full-weight figure); it's what the words around the
## badge describe, and what tests of the judge's mechanisms read.
static func shape_reading(g, value: Dictionary, hear_claims: bool = true) -> Dictionary:
	var juror: Dictionary = juror_case(g, value, hear_claims)
	if not juror.ready:
		return {"ready": false, "issues": juror.issues}
	var CaseEval = preload("res://workshop/case_eval.gd")
	var ev: Dictionary = CaseEval.evaluate(juror.prepared.view, juror.case)
	var result: Dictionary = CaseEval.strength_from(ev)
	result["ready"] = true
	result["issues"] = []
	return result

## The premises and badge bands the "points elsewhere" flag can join (test_juror): an
## accusation the case doesn't carry.
const POINTS_ELSEWHERE_TYPES = ["evil", "demon", "minion", "suspicious"]
const POINTS_ELSEWHERE_BANDS = ["contradicts", "none", "weak"]

## Which way each premise points an average listener's suspicion of its subject: up for an
## accusation, down for one that clears them. The listener weighs every case through its
## subject's chance of being evil, so that is what the juror reads. A "conflict" premise has
## no single subject: it is read through whoever it moves most, upward (one of them lied).
const PREMISE_CLEARS = ["good", "notdemon", "role", "truthful", "misled", "marked", "secret_mod"]
## The clearing premises a listener's chance of the target being good settles outright, for
## the badge's top tier (Conclusive): test_juror.
const TOP_TIER_CLEARS = ["good", "notdemon"]

## The listener's chance as the badge's top tier reads it for a premise of `type`: the chance
## itself where it settles the premise, else -1 (no top tier).
static func top_tier_chance(type: String, chance: float) -> float:
	var settles: bool = type in TOP_TIER_CLEARS or (type not in PREMISE_CLEARS and type != "conflict")
	return chance if settles else -1.0

## How an average listener takes `value`: {ready, issues, before, after (the subject's
## chance of being evil), chance_before, chance (the premise's chance, its side of that),
## lr (the odds ratio of chance over chance_before)}.
static func listener_reading(g, value: Dictionary) -> Dictionary:
	var Connections = preload("res://workshop/connections.gd")
	# The case against a town that hasn't heard its cards (Lantern's "without_cards"): how strong
	# the case is as heard, not what presenting it adds (that's the town note's question).
	var pj: Dictionary = Connections.judge_for_profile(g, value, {"baseline": "without_cards"})
	if not pj.get("ready", false):
		return {"ready": false, "issues": pj.get("issues", ["This case can't be weighed as the town would hear it."])}
	var conclusion: Dictionary = value.get("conclusion", {})
	var type: String = str(conclusion.get("type", ""))
	var target: String = str(pj.get("target", ""))
	var before: float = float(pj.get("before", -1.0))
	var after: float = float(pj.get("after", -1.0))
	if type == "conflict" or before < 0.0 or after < 0.0:
		# The person the case moves most, upward.
		var best: float = 0.0
		for id in pj.get("posterior_after", {}):
			var b: float = float(pj.get("posterior_before", {}).get(id, -1.0))
			var a: float = float(pj.posterior_after[id])
			if b >= 0.0 and _logit(a) - _logit(b) > best:
				best = _logit(a) - _logit(b)
				target = id
				before = b
				after = a
		if before < 0.0 or after < 0.0:
			before = 0.5
			after = 0.5
	var clears: bool = type in PREMISE_CLEARS
	var chance_before: float = 1.0 - before if clears else before
	var chance: float = 1.0 - after if clears else after
	var lr: float = exp(_logit(chance) - _logit(chance_before))
	# An accepted lie call presses its teller as the liar rather than moving the odds (the
	# clash is in the worlds already): the badge's words name it (Herald words the line).
	var presses: Array = []
	# `floors` lists every lie call assessed; one presses its teller exactly as the refresh
	# applies it (Jury): agreement at or over the bar (Lantern, Nov 19).
	for f in pj.get("floors", []):
		if str(f.get("mode", "")) == "lying" and float(f.get("agreement", 0.0)) >= Tuning.Workshop.JURY_CHALLENGE_LYING_MIN_AGR:
			presses.append({"source": str(f.get("source", "")), "reading": str(f.get("card", "")), "agreement": float(f.get("agreement", 0.0))})
	# Each lie call's outcome for this listener, for the badge's words (Herald, Nov 19; Lantern's
	# review of #332), read from its own assessment (the `floors` entry for that reading):
	# "pressed": accepted (agreement at the bar): the town presses the teller as the liar;
	# "draw": its grounds clash with the reading, but not enough (your word against theirs);
	# "unestablished": grounds are cited, but they don't contradict the reading;
	# "bare": no grounds on the case. `witnesses`: the tellers of its grounds.
	var by_card: Dictionary = {}
	for f in pj.get("floors", []):
		if str(f.get("mode", "")) == "lying":
			by_card[str(f.get("card", ""))] = f
	var outcomes: Array = []
	var challenges: Dictionary = value.get("reading_challenges", {})
	for rid in challenges:
		var ch: Dictionary = challenges[rid]
		if str(ch.get("mode", "")) != "lying":
			continue
		var teller: String = _card_source(g, str(rid))
		var witnesses: Array = []
		for sid in ch.get("supports", []):
			var w: String = _card_source(g, str(sid))
			if w != "" and w != "player" and w not in witnesses:
				witnesses.append(w)
		var f: Dictionary = by_card.get(str(rid), {})
		var kind: String = "bare"
		if float(f.get("agreement", 0.0)) >= Tuning.Workshop.JURY_CHALLENGE_LYING_MIN_AGR:
			kind = "pressed"
		elif not ch.get("supports", []).is_empty():
			var clash: bool = float(f.get("accuracy_agreement", 0.0)) > 0.0 or str(f.get("note", "")).begins_with("The report conflicts")
			kind = "draw" if clash else "unestablished"
		outcomes.append({"reading": str(rid), "teller": teller, "kind": kind, "witnesses": witnesses})
	return {"ready": true, "issues": [], "target": target, "before": before, "after": after,
		"chance_before": chance_before, "chance": chance, "lr": lr, "presses": presses, "challenges": outcomes}

## The words for one lie call's outcome (a `challenges` entry of listener_reading), approved
## by Michael (Herald, Nov 19). {name} is the teller of the challenged reading; a draw names
## the witnesses whose grounds clash with it. `name_of` turns an id into a name.
static func lie_call_line(c: Dictionary, name_of: Callable) -> String:
	var name: String = str(name_of.call(str(c.get("teller", ""))))
	match str(c.get("kind", "")):
		"pressed":
			return "The town would press %s as the liar." % name
		"draw":
			var witnesses: Array = c.get("witnesses", [])
			if witnesses.is_empty():
				return "Your word against %s's." % name  # grounds only the player's own (Michael, through Herald)
			if witnesses.size() == 1:
				return "It's %s's word against %s's: some may be swayed by your assessment." % [str(name_of.call(str(witnesses[0]))), name]
			return "Their word against %s's: some may be swayed by your assessment." % name
		"unestablished":
			return "Nothing you've cited shows the reading is wrong; the town will still believe it."
		_:
			return "The town won't take this challenge on your word: nothing on the case shows why the reading is wrong."

## The teller of the board card whose Workshop id is `id`, or "".
static func _card_source(g, id: String) -> String:
	for card in g.board:
		if card.get("kind", "") != "deduction" and Evidence.normalize_card(card).id == id:
			return str(Evidence.normalize_card(card).get("source", ""))
	return ""

## The way back from a wrong lie call (Michael, Nov 19). The refusal a second case meets when
## it calls a reading Mistaken that an earlier case called a lie ("Conflicting reading
## challenges…") becomes a signpost to revising that case.
const CONFLICTING_CALLS = "Conflicting reading challenges need separate alternatives"
const SIGNPOST_PRESENTED = "You called %s's reading a lie in case #%d. To call it a mistake instead, open case #%d in the Workshop, change the challenge to Mistaken, and present it again: it replaces the old case for everyone who hears it."
const SIGNPOST_UNPRESENTED = "You called %s's reading a lie in case #%d. To call it a mistake instead, change the challenge in case #%d."

## The live filed case (not `own`, nor any version of it) that calls a lie on a reading `value`
## calls Mistaken: {number, teller}, or {}. A case someone has heard comes first: only a heard
## case can refuse the new one, so a newer unheard draft with the same call isn't the one to
## revise. With two or more heard cases making the call, revising one leaves the others' call
## standing, so there's no single case to name and the plain refusal stays (Codex, #363).
##
## A listener keeps the version it heard until it hears the revision, so a heard version
## that has since been revised still counts: the player is pointed at the latest version
## (`latest`) to present (Codex, #363). Several heard versions of one case are one case.
static func lie_called_elsewhere(g, value: Dictionary, own: int = 0) -> Dictionary:
	var found: Array = _lie_calls_elsewhere(g, value, own)
	var heard: Dictionary = {}
	for f in found:
		if was_presented(g, f.number) and not heard.has(f.latest):
			heard[f.latest] = f
	if heard.size() > 1:
		return {}
	if heard.size() == 1:
		return heard.values()[0]
	var live: Array = found.filter(func(f): return f.number == f.latest)
	return live[0] if not live.is_empty() else {}

## The newest version of case `number`.
static func latest_version(g, number: int) -> int:
	var v: int = number
	var seen: Array = []
	while v > 0 and v <= g.board.size() and int(g.board[v - 1].get("superseded_by", 0)) > 0 and not (v in seen):
		seen.append(v)
		v = int(g.board[v - 1].superseded_by)
	return v

## Every such case version, newest first: {number (the version with the call), latest, teller}.
static func _lie_calls_elsewhere(g, value: Dictionary, own: int) -> Array:
	var out: Array = []
	var RC = preload("res://workshop/reading_challenges.gd")
	var mine: Dictionary = value.get("reading_challenges", {})
	var lineage: Array = versions_of(g, own)
	for i in range(g.board.size() - 1, -1, -1):
		var c: Dictionary = g.board[i]
		if c.get("kind", "") != "deduction" or c.get("deleted", false) or c.get("withdrawn", false) or not c.has("workshop_case"):
			continue
		var latest: int = latest_version(g, int(c.n))
		if int(c.n) in lineage or latest in lineage or g.board[latest - 1].get("deleted", false) or g.board[latest - 1].get("withdrawn", false):
			continue
		var theirs: Dictionary = c.workshop_case.get("reading_challenges", {})
		for rid in mine:
			# Same side of a Medium's relay only: switching the mode can't settle calls on
			# different sides (the passing-on and the original; Codex, #363).
			if theirs.has(rid) and RC.canonical(str(theirs[rid].get("mode", ""))) == "lying" and RC.canonical(str(mine[rid].get("mode", ""))) == RC.HONEST \
					and str(theirs[rid].get("attribution", "")) == str(mine[rid].get("attribution", "")):
				out.append({"number": int(c.n), "latest": latest, "teller": _challenged_teller(g, str(rid), str(theirs[rid].get("attribution", "")))})
				break
	return out

## Whose reading a challenge on card `id` accuses: its teller, or, on the original side of a
## Medium's relay, the dead reader the Medium passed on (Codex, #363).
static func _challenged_teller(g, id: String, attribution: String) -> String:
	if attribution == "original":
		for card in g.board:
			if card.get("kind", "") != "deduction" and str(card.get("role", "")) == "medium" and Evidence.normalize_card(card).id == id:
				return str(card.get("data", {}).get("dead", ""))
	return _card_source(g, id)

## Case `number` and every version it revises.
static func versions_of(g, number: int) -> Array:
	var out: Array = []
	var v: int = number
	while v > 0 and v <= g.board.size() and not (v in out):
		out.append(v)
		v = int(g.board[v - 1].get("revises", 0))
	return out

## Has anyone heard case `number`, or a version it revises?
static func was_presented(g, number: int) -> bool:
	var lineage: Array = versions_of(g, number)
	for v in lineage:
		if g.public_presentations.has(v):
			return true
	for real in g.w.npcs:
		var mind = real.shadow if real.is_evil() and real.shadow != null else real
		var held: Dictionary = mind.workshop_state.get("presentations", {})
		for v in lineage:
			if held.has(str(v)) or mind.ledger.has("arg:workshop:%d" % v):
				return true
			# A case put in a private accusation or defence is held as "direct:<n>:…" (Codex, #363).
			for key in held:
				if str(key).begins_with("direct:%d:" % v):
					return true
	return false

## The issues the player reads: the conflicting-calls refusal becomes the signpost when an
## earlier case's lie call is the cause. Routing still matches the raw issue text, so this
## is applied only where words reach the player.
static func player_issues(g, value: Dictionary, issues: Array, own: int = 0) -> Array:
	if not issues.any(func(i): return str(i).begins_with(CONFLICTING_CALLS)):
		return issues
	var other: Dictionary = lie_called_elsewhere(g, value, own)
	if other.is_empty():
		return issues
	var who: String = g.w.by_id[other.teller].name if g.w.by_id.has(other.teller) else "the teller"
	var line: String = (SIGNPOST_PRESENTED % [who, other.number, other.latest]) if was_presented(g, other.number) else (SIGNPOST_UNPRESENTED % [who, other.number, other.latest])
	return issues.map(func(i): return line if str(i).begins_with(CONFLICTING_CALLS) else i)

static func _logit(p: float) -> float:
	p = clampf(p, 1e-6, 1.0 - 1e-6)
	return log(p / (1.0 - p))

## "This weakens your previous case" (Michael, Nov 18; BACKLOG "Believable public
## revisions"): would `value`, filed as a revision of case `previous`, leave its premise
## less likely than the version it replaces? Judged by the Test juror, or, with
## `listener_id`, by that listener's own view, on the same conclusion: a revision that
## changes whom or what the case concludes is a different case and gets no warning.
## Belief follows the evidence, so this only warns; the revision can still be filed.
## Returns {} or {"text", "before", "after"} (the premise's chance under each version).
const REVISION_WEAKENS_TEXT: String = "This weakens your previous case"
static func revision_weakens(g, value: Dictionary, previous: int, listener_id: String = "") -> Dictionary:
	if previous < 1 or previous > g.board.size():
		return {}
	var old: Dictionary = g.board[previous - 1].get("workshop_case", {})
	if old.is_empty() or old == value:
		return {}
	var oc: Dictionary = old.get("conclusion", {})
	var nc: Dictionary = value.get("conclusion", {})
	# Every field names the proposition (type, target, secret, the questioned report, a
	# claimed role, the alignment epoch): any change asks a different question (Codex on #275).
	if JSON.stringify(oc) != JSON.stringify(nc):
		return {}
	var before: float = _premise_chance(g, old, listener_id)
	var after: float = _premise_chance(g, value, listener_id)
	if before < 0.0 or after < 0.0 or after >= before - 1e-9:
		return {}
	return {"text": REVISION_WEAKENS_TEXT, "before": before, "after": after}

## The chance the case's premise holds, as the Test juror (or `listener_id`) would judge
## the case alone; -1 when it can't be judged.
static func _premise_chance(g, value: Dictionary, listener_id: String) -> float:
	var CaseEval = preload("res://workshop/case_eval.gd")
	var prepared
	var judged: Dictionary
	var listener: Dictionary = {}
	if listener_id == "":
		# The Test juror: an average listener's chance of the premise (listener_reading).
		if not juror_case(g, value).ready:
			return -1.0
		var heard: Dictionary = listener_reading(g, value)
		return float(heard.chance) if heard.ready else -1.0
	else:
		prepared = Assess.prepare(snapshot(g, value, listener_id))
		if not prepared.ready:
			return -1.0
		judged = prepared.case
		listener = prepared.listener  # that listener's own trust, doubts and knowledge (Codex on #275)
	var ev: Dictionary = CaseEval.evaluate(prepared.view, judged, listener)
	if ev.get("impossible", false):
		return 0.0
	return float(ev.get("posterior", -1.0))

## What the test juror judges (shared with its "why" readout, game/workshop_why.gd):
## {"ready", "issues", "prepared", "case"}. The public claims it hears are weighed with the
## case's cards (CaseEval reads the case's cards), on a copy; the case itself is unchanged.
static func juror_case(g, value: Dictionary, hear_claims: bool = true) -> Dictionary:
	var claims: Array = public_claims_for(g, value) if hear_claims else []
	var input = snapshot(g, value, "", "private", claims)
	input.private_evidence = []
	input.evidence = input.evidence.filter(func(e): return e.id in input.selected)
	input.listener = {"id": "ghost", "name": "Test juror", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "source_doubt": {}, "own_gift": "", "legacy_evidence": []}
	var prepared = Assess.prepare(input)
	if not prepared.ready:
		return {"ready": false, "issues": prepared.issues.duplicate()}
	var judged: Dictionary = prepared.case
	if not claims.is_empty():
		judged = prepared.case.duplicate(true)
		var in_view: Dictionary = {}
		for c in prepared.view.cards:
			in_view[c.id] = true
		for number in claims:
			var id: String = Evidence.normalize_card(g.board[int(number) - 1]).id
			if in_view.has(id) and id not in judged.cards:
				judged.cards.append(id)
	# Challenges apply (triage 5.4; the cheap version): CaseEval doesn't weigh a challenge, so
	# the juror judges the case as if each holds, with the challenged readings set aside. A
	# poisoned or misled reading says nothing; a lie would say the opposite, which this
	# doesn't model. Answers stay theory, not evidence.
	var set_aside: Array = []
	var challenges: Dictionary = value.get("reading_challenges", {})
	if not challenges.is_empty():
		var kept: Array = judged.cards.filter(func(id): return not challenges.has(id))
		if kept.is_empty():
			# Every card challenged: nothing left to judge (Codex on #159).
			return {"ready": false, "issues": ["Judged as if your challenges hold, nothing is left in this case to weigh."]}
		if kept.size() < judged.cards.size():
			judged = judged.duplicate(true)
			set_aside = judged.cards.filter(func(id): return challenges.has(id))
			judged.cards = kept
			judged.reading_challenges = {}
			for line in judged.get("lines", []):
				line.cards = line.get("cards", []).filter(func(id): return not challenges.has(id))
	return {"ready": true, "issues": [], "prepared": prepared, "case": judged, "set_aside": set_aside}

## The public gift claims of everyone the case's cards name (its tellers and the people
## their readings are about), on the board but not in the case: the test juror hears them
## as any listener would (triage 5.5: Nisha's Registrar reading alone was x1.3 because the
## juror didn't know Kiran claimed Dowser). Board numbers.
static func public_claims_for(g, value: Dictionary) -> Array:
	var Meeting = preload("res://game/game_meeting.gd")
	var roots: Dictionary = supports(g, value)
	var named: Dictionary = {}
	for number in roots.numbers:
		var card: Dictionary = g.receipt_by_number(int(number))
		for field in ["source", "subject"]:
			var v = card.get(field, "")
			for id in (v if v is Array else [v]):
				named[str(id)] = true
		# Everyone the reading's data names, however nested (a Psychologist's statements
		# carry their speakers and subjects inside; Codex on #159).
		_collect_people(g, card.get("data", {}), named)
	var result: Array = []
	for card in g.board:
		if card.get("kind", "") != "claim" or card.get("deleted", false) or int(card.get("n", 0)) in roots.numbers:
			continue
		var who = card.get("subject", [])
		var subject: String = str(who[0] if who is Array and not who.is_empty() else who)
		if named.has(subject) and subject == str(card.get("source", "")) and Meeting.already_public(g, card):
			result.append(int(card.n))
	return result

## What presenting this case to the town would add, under the connections model
## (workshop/connections.gd). The strength chip says whether
## the argument is sound; this says when a sound argument would still move the town
## little, from public information and your own public cases only:
##   "none"     the case's cards are all public already, and weighed together they add
##              little (a single card, or cards that say nothing more together);
##   "repeat"   you put these cards to the town today already;
##   "presses"  the same, under a "suspicious" premise: no new belief, but it still
##              presses its subject;
##   "refresh"  you put them to the town on an earlier day: this brings that back;
##   "settled"  the public record already settles its subject.
## A case that brings any card the town hasn't heard never gets a note. It is judged
## by a neutral listener who holds only the cards of this case and of your public cases,
## without your watch record (the town doesn't have it), by the game's own rules for
## stored cases (Connections.cases).
## Returns {} or {"kind", "text", "adds": the most the case's own part moves anyone, in
## log-odds at full weight}. `little`: under this, the cards add little together.
const NOTE_ADDS_LITTLE: float = 0.2
## A refresh is only noted when it changes something (log-odds at full weight).
const NOTE_REFRESH_MIN: float = 0.01
static func town_note(g, value: Dictionary, little: float = NOTE_ADDS_LITTLE) -> Dictionary:
	var Connections = preload("res://workshop/connections.gd")
	var Meeting = preload("res://game/game_meeting.gd")
	if value.get("cards", []).is_empty():
		return {}
	# A reading challenge changes how the town weighs a case (SharedLedger.prepare), and the
	# stored-case arithmetic below doesn't carry it: no note rather than a wrong one.
	if not value.get("reading_challenges", {}).is_empty():
		return {}
	# Earlier versions of a case you've revised in public: the town retracted them
	# (GamePresentation.workshop_canvas_retire), so their cards are heard but their
	# arguments no longer stand.
	var retired: Dictionary = {}
	for number in g.public_presentations:
		if int(number) < 1 or int(number) > g.board.size():
			continue
		var ancestor: int = int(g.board[int(number) - 1].get("revises", 0))
		while ancestor > 0 and ancestor <= g.board.size() and not retired.has(ancestor):
			retired[ancestor] = true
			ancestor = int(g.board[ancestor - 1].get("revises", 0))
	# Your public cases, oldest first, as the town heard them.
	var earlier: Array = []
	var said: Dictionary = {}
	for number in g.public_presentations:
		if int(number) < 1 or int(number) > g.board.size():
			continue
		var filed: Dictionary = g.board[int(number) - 1]
		# A case deleted from your board still stands with the town (GameBoard.delete_deduction
		# retracts nothing).
		if filed.get("kind", "") != "deduction":
			continue
		var ids: Array = Array(filed.get("workshop_case", {}).get("cards", [])).duplicate()
		if ids.is_empty():
			for support in filed.get("supports", []):
				var root: Dictionary = g.receipt_by_number(int(support))  # board cards and profile receipts
				if not root.is_empty() and root.get("kind", "") != "deduction":
					ids.append(Evidence.normalize_card(root).id)
		var conclusion: Dictionary = filed.get("workshop_case", {}).get("conclusion", {})
		var kind: String = str(conclusion.get("type", filed.get("conclusion", {}).get("type", "")))
		# public_presentations held `true` before it held the day.
		var day: int = int(g.public_presentations[number]) if g.public_presentations[number] is int else int(g.w.day)
		for id in ids:
			said[id] = true
		# A retired version, or one whose reading challenges this arithmetic can't carry,
		# doesn't count as an argument of yours here (its cards are still heard).
		if retired.has(int(number)) or not filed.get("workshop_case", {}).get("reading_challenges", {}).is_empty():
			continue
		# Only the cards it argues for count as its argument: a "conflict" case argues for none,
		# and a quoted-only line's cards are heard but not endorsed (SharedLedger.endorsed_facts).
		if filed.has("workshop_case"):
			ids = _endorsed(filed.workshop_case)
		if ids.is_empty():
			continue
		earlier.append({"key": "case:%d" % int(number), "number": int(number), "presenter": "player", "day": day, "cards": ids, "suspicious": kind == "suspicious",
			"same": filed.get("workshop_case", {}) == value})
	earlier.sort_custom(func(a, b): return a.day < b.day or (a.day == b.day and a.number < b.number))
	# Any card the town hasn't heard is news: no note.
	var roots: Dictionary = supports(g, value)
	if not roots.issues.is_empty():
		return {}
	for number in roots.numbers:
		var card: Dictionary = g.receipt_by_number(int(number))  # board cards and profile receipts
		if card.is_empty() or not (Meeting.already_public(g, card) or said.has(Evidence.normalize_card(card).id)):
			return {}
	# The neutral listener's view: this case's cards and your public cases', no watch record.
	var all: Dictionary = value.duplicate(true)
	for id in said:
		if id not in all.cards:
			all.cards.append(id)
	var input = snapshot(g, all)
	input.private_evidence = []
	input.evidence = input.evidence.filter(func(e): return e.id in input.selected)
	input["watched"] = []
	input.listener = {"id": "ghost", "name": "Test juror", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "source_doubt": {}, "own_gift": "", "legacy_evidence": []}
	var prepared = Assess.prepare(input)
	if not prepared.ready:
		return {}
	var CaseEval = preload("res://workshop/case_eval.gd")
	var Solver = preload("res://workshop/solver.gd")
	var view: Dictionary = prepared.view
	var target: String = str(value.get("conclusion", {}).get("target", ""))
	var run: Dictionary = Connections.begin(view, prepared.case, CaseEval.neutral_listener(view))
	if run.impossible or target not in run.others:
		return {}
	var name: String = Solver.person_name(view, target)
	if float(run.baseline[target]) <= Connections.FIXED or float(run.baseline[target]) >= 1.0 - Connections.FIXED:
		return {"kind": "settled", "adds": 0.0, "text": "No new info: the public record already settles %s." % name}
	var by_id: Dictionary = {}
	for c in view.cards:
		by_id[c.id] = c
	run["by_id"] = by_id
	var held: Array = prepared.case.cards.filter(func(id): return by_id.has(id))
	var item_list: Array = Connections.items(by_id, held, run.people, run.row)
	var values: Dictionary = {}
	for it in item_list:
		values[it.key] = Connections.value(run, it)
	var today: int = int(g.w.day)
	# The draft's argument is the cards it argues for, as an earlier case's is: a "conflict"
	# draft argues for none (no note), and quoted-only lines are heard, not endorsed.
	var argued: Array = _endorsed(value)
	if argued.is_empty():
		return {}
	var draft: Dictionary = {"key": "draft", "presenter": "player", "day": today, "cards": argued.duplicate(), "suspicious": str(value.get("conclusion", {}).get("type", "")) == "suspicious"}
	# The same filed case presented again takes its own earlier place (a revision).
	var case_list: Array = earlier.filter(func(c): return not c.same) + [draft]
	var empty_core: Dictionary = {"seed": [], "members": [], "lean": {}, "impossible": false}
	var res: Dictionary = Connections.cases(run, item_list, values, empty_core, case_list, today)
	var before: Dictionary = Connections.cases(run, item_list, values, empty_core, earlier, today)
	var entries: Array = res.entries.filter(func(e): return e.key == "draft")
	var entry: Dictionary = entries[0] if not entries.is_empty() else {}
	# What presenting it would change, by the arithmetic itself (Codex on #154): the stored
	# cases' lean with the draft against without it, per person, at the draft's full weight.
	# Faded, replaced, superseded and shared cases all come out of this, as they would for a
	# listener.
	var adds: float = 0.0
	var people: Dictionary = {}
	for p in res.lean:
		people[p] = true
	for p in before.lean:
		people[p] = true
	for p in people:
		adds = maxf(adds, absf(float(res.lean.get(p, 0.0)) - float(before.lean.get(p, 0.0))) / maxf(0.001, float(entry.get("weight", 1.0))))
	# The same question through the listener path (Michael, Nov 19, juror fix (a)): what
	# presenting it would change for an average listener, each card as heard
	# (Connections.judge_for_profile, its "marginal" default), at the case's full weight as
	# the threshold reads it: the logit move divided by the case's weight, an approximation
	# (the posterior isn't quite linear in the weight; Lantern, #332). The note and the badge
	# then come from one entry point.
	var heard: Dictionary = Connections.judge_for_profile(g, value)
	if heard.get("ready", false):
		var w: float = maxf(0.001, float(heard.get("case", {}).get("weight", 1.0)))
		var moved: float = 0.0
		for p in heard.get("posterior_after", {}):
			var b: float = float(heard.get("posterior_before", {}).get(p, -1.0))
			if b >= 0.0:
				moved = maxf(moved, absf(_logit(float(heard.posterior_after[p])) - _logit(b)) / w)
		adds = moved
	# Earlier arguments of yours that hold all of these cards and still count today.
	var counting: Dictionary = {}
	for e in before.entries:
		if float(e.get("weight", 0.0)) > 0.0:
			counting[str(e.key)] = true
	var covering: Array = earlier.filter(func(c): return counting.has(c.key) and argued.all(func(id): return id in c.cards))
	# The same cards on an earlier day, renewed at today's weight (even faded out entirely):
	# a refresh, if it changes anything at all. A "suspicious" draft over a firm case
	# counts for less: it doesn't renew it.
	var renewed: Dictionary = {}
	for c in earlier:
		if c.day < today and c.cards.all(func(id): return id in argued) and argued.all(func(id): return id in c.cards) and not (draft.suspicious and not c.suspicious):
			if renewed.is_empty() or c.day > renewed.day:
				renewed = c
	var latest_today: bool = covering.any(func(c): return c.day == today)
	if not renewed.is_empty() and not latest_today and adds > NOTE_REFRESH_MIN:
		return {"kind": "refresh", "adds": adds, "text": "Refreshes your day-%d argument (case #%d): the town weighs it at full strength again." % [renewed.day, renewed.number]}
	if adds >= little:
		return {}
	if not covering.is_empty():
		var latest: Dictionary = covering[-1]
		for c in covering:
			if c.day > latest.day:
				latest = c
		if draft.suspicious and _would_press(run, entry, target, _neutral_posterior(run, values, before)) and not _pressure_spent(g, target, roots.numbers):
			return {"kind": "presses", "adds": adds, "text": "Adds no new belief (you've put these cards to the town in case #%d), but still presses %s." % [latest.number, name]}
		return {"kind": "repeat", "adds": adds, "text": "No new info: you've already put these cards to the town (case #%d)." % latest.number}
	var shared_with: Array = earlier.filter(func(c): return counting.has(c.key) and c.cards.any(func(id): return id in argued))
	if int(entry.get("shared", 0)) >= 2 and not shared_with.is_empty():
		return {"kind": "none", "adds": adds, "text": "No new info: the town already counts these cards, and what they add together you've mostly argued in case #%d." % shared_with[-1].number}
	return {"kind": "none", "adds": adds, "text": "No new info: the town already counts these cards, and together they add little."}


## Would this "suspicious" entry press its subject noticeably (NOTE_PRESSES or more at a
## meeting), going by the neutral listener? The game's own pressure rule on its numbers.
const NOTE_PRESSES: float = 0.15
static func _would_press(run: Dictionary, entry: Dictionary, target: String, now: Dictionary) -> bool:
	var Presentation = preload("res://game/workshop_presentation.gd")
	# The game's own rise (WorkshopPresentation._connections_rise): the subject's chance as the
	# neutral listener holds it now (`now`: every heard card and your standing cases, not the
	# no-card baseline; Codex on #155) against their chance with the case's points taken away.
	var Connections = preload("res://workshop/connections.gd")
	var chance: float = float(now.get(target, 0.0))
	if chance <= Connections.FIXED or chance >= 1.0 - Connections.FIXED:
		return false
	var without: Dictionary = {}
	var points: Dictionary = entry.get("points", {})
	for p in points:
		without[p] = -float(points[p])
	var rise: float = float(now.get(target, 0.0)) - Presentation.held_back_chance(now, without, target)
	return Presentation.connections_pressure(maxf(0.0, rise)) >= NOTE_PRESSES

## The neutral listener's chances as a refresh would give them: the baseline plus every heard
## card's lean and your standing cases' (it holds no knowledge of its own, so no core).
static func _neutral_posterior(run: Dictionary, values: Dictionary, standing: Dictionary) -> Dictionary:
	var Connections = preload("res://workshop/connections.gd")
	var total: Dictionary = {}
	for p in run.others:
		total[p] = float(standing.get("lean", {}).get(p, 0.0))
	for key in values:
		for p in values[key].get("lean", {}):
			if total.has(p):
				total[p] += float(values[key].lean[p])
	return Connections.combine(run.others, run.baseline, total).posterior

## Has this "suspicious" filing (its target and cards) already pressed? Pressure comes once
## per filing, from its first hearing, and only in that venue (WorkshopPresentation.
## _suspicious_pressure): once anyone has heard it, in private or at a meeting, presenting it
## at the meeting presses no one more (Codex on #155).
static func _pressure_spent(g, target: String, numbers: Array) -> bool:
	var ids: Array = numbers.duplicate()
	ids.sort()
	var filing: String = target + "|" + ",".join(PackedStringArray(ids))
	var entry: Dictionary = g.w.suspicious_pressure.get(filing, {})
	return int(entry.get("count", 0)) > 0

## The cards a filed Workshop case argues for, as SharedLedger.endorsed_facts reads them.
static func _endorsed(value: Dictionary) -> Array:
	if str(value.get("conclusion", {}).get("type", "")) == "conflict":
		return []
	var assigned: Array = []
	var endorsed: Array = []
	for line in value.get("lines", []):
		assigned.append_array(line.get("cards", []))
		if line.get("relation", "supports") == "supports":
			for id in line.get("cards", []):
				if id not in endorsed:
					endorsed.append(id)
	for id in value.get("cards", []):
		if id not in assigned and id not in endorsed:
			endorsed.append(id)
	return endorsed

## Every person id anywhere in `v` (strings, arrays, dictionaries), into `named`.
static func _collect_people(g, v, named: Dictionary) -> void:
	if v is String:
		if g.w.by_id.has(v):
			named[v] = true
	elif v is Array:
		for x in v:
			_collect_people(g, x, named)
	elif v is Dictionary:
		for k in v:
			_collect_people(g, v[k], named)

## What you saw around an Augur reading (triage 5.10): the reading names nobody, so its
## hint lists who your own sightings put on the Augur's block that morning and afternoon,
## where your sightings place the Augur, and how many more you couldn't make out at those
## places ("crowd_unseen"). "Sightings: Edda, Kiran +at least 2 unknowns", or "" if you
## never saw where the Augur was that day.
static func augur_sightings(view: Dictionary, card: Dictionary) -> String:
	var Solver = preload("res://workshop/solver.gd")
	var augur: String = str(card.get("source", ""))
	var day: int = int(card.get("observed_at", {}).get("day", -1))
	# (Daytime sightings are "location" cards in the case view.)
	var mine: Array = view.get("cards", []).filter(func(c): return str(c.get("kind", "")) in ["location", "sighting"] and str(c.get("source", "")) == "player" and int(c.get("observed_at", {}).get("day", -2)) == day)
	var names: Array = []
	var unknowns: int = 0
	var placed: bool = false
	for phase in ["morning", "afternoon"]:
		var at: Array = mine.filter(func(c): return str(c.observed_at.get("phase", "")) == phase)
		var blocks: Array = at.filter(func(c): return augur in c.get("subjects", [])).map(func(c): return str(c.get("block", "")))
		if blocks.is_empty() or blocks[0] == "":
			continue
		placed = true
		var counted: Dictionary = {}
		var phase_unknowns: int = 0
		for c in at:
			if str(c.get("block", "")) != blocks[0]:
				continue
			for who in c.get("subjects", []):
				var nm: String = Solver.person_name(view, str(who))
				if str(who) != augur and nm not in names:
					names.append(nm)
			var place: String = str(c.get("loc", ""))
			if not counted.has(place):
				counted[place] = true
				phase_unknowns += int(c.get("crowd_unseen", 0))
		# The same unseen people may be there both phases: the larger phase is the lower bound
		# (Codex, #162).
		unknowns = maxi(unknowns, phase_unknowns)
	if not placed:
		return ""
	var text: String = "Sightings: " + (", ".join(PackedStringArray(names)) if not names.is_empty() else "nobody")
	if unknowns > 0:
		text += " +at least %d unknown%s" % [unknowns, "" if unknowns == 1 else "s"]
	return text

## The test juror's notes beyond its strength chip: the clash headline and clashing
## cards when the case can't hold, and who it would mostly raise suspicion of.
static func feedback(view: Dictionary, case_data: Dictionary, ev: Dictionary, result: Dictionary) -> void:
	var Solver = preload("res://workshop/solver.gd")
	var target: String = case_data.conclusion.get("target", "")
	if ev.impossible:
		# The real diagnosis goes first: with the player's own choices (answers, doubts,
		# assumptions), the cards can't all hold. Point at the cards that clash.
		var chose: bool = not case_data.answers.is_empty() or not case_data.get("reading_challenges", {}).is_empty() or not case_data.positions.is_empty() or not case_data.get("disputes", []).is_empty()
		result["headline"] = "Your chosen explanation doesn't fit: with it, these cards can't all be true." if chose else "These cards can't all be true together; something here is false."
		var cards: Array = Solver.selected(view, case_data)
		var cores: Array = Solver.minimal_conflicts(view, cards)
		if not cores.is_empty():
			result["clashing"] = cores[0]
		else:
			# The cards clash only under the player's choices: point at the chosen ones.
			var chosen: Array = case_data.answers.keys() + case_data.get("reading_challenges", {}).keys()
			for dispute in case_data.get("disputes", []):
				chosen.append_array(dispute.reports)
			for card in cards:
				if card.get("source", "") in case_data.positions or card.get("subject", "") in case_data.positions:
					chosen.append(card.id)
			var unique: Array = []
			for id in chosen:
				if id not in unique:
					unique.append(id)
			result["clashing"] = unique
	# Collateral: who this case would mostly raise suspicion of, if not the subject.
	if case_data.conclusion.get("type", "") in ["evil", "demon", "minion", "suspicious"] and ev.has("people"):
		var people: Dictionary = ev.people
		var own: float = people.get(target, {}).get("posterior", 0.0) - people.get(target, {}).get("prior", 0.0)
		var top = ""
		var top_rise = 0.05
		for id in people:
			var rise: float = people[id].posterior - people[id].prior
			if id != target and rise > top_rise and rise > own:
				top = id
				top_rise = rise
		if top != "":
			result["raises"] = top
			result["raises_text"] = "If presented, this mostly raises suspicion of %s." % Solver.person_name(view, top)
	# A defence whose evidence points the other way (premises pass step 1, preview hint).
	if case_data.conclusion.get("type", "") == "good" and ev.has("people") and target != "":
		var mine: Dictionary = ev.people.get(target, {})
		if float(mine.get("posterior", 0.0)) - float(mine.get("prior", 0.0)) > 0.05:
			result["against"] = target
			result["raises_text"] = "These cards make %s look more suspicious, not less." % Solver.person_name(view, target)

## A Warden's guard on a quiet night that the case cites (LiveActivity.quiet_guard_cards,
## the ones the route uses): each that moved the subject by at least a reason's weight
## (REASON_MIN_ITEM_CONTRIB) on its own goes in result["guards"] as {warden, guarded,
## night, saved, report (card id), quiet (the night's quiet card id, or ""), shift (the
## subject's chance with that guard's route, less without it)}. One guard is judged once more
## with the guards off; with several, each is left out in turn (Codex on #243). The factor
## and compiled-case keys carry the switch and the skip list. Only when the case cites one.
static func guard_reasons(view: Dictionary, case_data: Dictionary, ev: Dictionary, result: Dictionary) -> void:
	var Solver = preload("res://workshop/solver.gd")
	var LiveActivity = preload("res://workshop/live_activity.gd")
	var Tuning = preload("res://sim/tuning.gd")
	var CaseEval = preload("res://workshop/case_eval.gd")
	var target: String = case_data.conclusion.get("target", "")
	if target == "" or ev.get("impossible", false) or not ev.has("people") or not ev.people.has(target):
		return
	var guards: Array = LiveActivity.quiet_guard_cards(view, Solver.selected(view, case_data))
	if guards.is_empty():
		return
	var with_p: float = float(ev.people[target].posterior)
	var out: Array = []
	for g in guards:
		var was_on: bool = LiveActivity.quiet_guards_enabled
		var was_skip: Array = LiveActivity.quiet_guards_skip
		if guards.size() == 1:
			LiveActivity.quiet_guards_enabled = false
		else:
			LiveActivity.quiet_guards_skip = [g.report]
		var ev_off: Dictionary = CaseEval.evaluate(view, case_data)
		LiveActivity.quiet_guards_enabled = was_on
		LiveActivity.quiet_guards_skip = was_skip
		if ev_off.get("impossible", false) or not ev_off.get("people", {}).has(target):
			continue
		var shift: float = with_p - float(ev_off.people[target].posterior)
		if absf(shift) < Tuning.Workshop.REASON_MIN_ITEM_CONTRIB:
			continue
		var quiet: String = ""
		for card in view.cards:
			if card.get("kind", "") == "quiet" and int(card.get("night", -1)) == int(g.night):
				quiet = str(card.get("id", ""))
				break
		out.append({"warden": g.source, "guarded": g.target, "night": g.night, "saved": g.saved, "report": g.report, "quiet": quiet, "shift": shift})
	if not out.is_empty():
		result["guards"] = out

## The Test juror's reason line for each quiet-night guard in `result["guards"]` (Herald,
## Nov 19; debug text, so Michael's Nov 18 rule needs no wording approval): which cards,
## what they argue, and how far they move the case. Card numbers are board numbers.
static func guard_reason_lines(g, result: Dictionary, case_value: Dictionary = {}) -> Array:
	var C = preload("res://sim/content.gd")
	var number_of = func(id: String) -> int:
		if id == "":
			return 0
		for c in g.board:
			if c.kind != "deduction" and not c.get("deleted", false) and Evidence.normalize_card(c).id == id:
				return int(c.n)
		return 0
	var name_of = func(pid: String) -> String:
		return g.w.by_id[pid].name if g.w.by_id.has(pid) else pid
	# `shift` moves the subject's chance of being evil, so for a case that someone is good
	# (or Marked, an innocent who registers evil) a rise works against it (Codex on #299).
	var innocence: bool = str(case_value.get("conclusion", {}).get("type", "")) in ["good", "marked"]
	var out: Array = []
	for gd in result.get("guards", []):
		var warden: String = name_of.call(str(gd.warden))
		var guarded: String = name_of.call(str(gd.guarded))
		var night: String = C.spoken_night(int(gd.night), -1)
		var report_n: int = number_of.call(str(gd.report))
		var quiet_n: int = number_of.call(str(gd.get("quiet", "")))
		var line: String = "%s%s guarded %s's door on %s" % ["#%d " % report_n if report_n > 0 else "", warden, guarded, night]
		if quiet_n > 0:
			line += ", and #%d no one died that night" % quiet_n
		line += ": if %s is a working Warden, the Demon came to %s's door that night." % [warden, guarded]
		var helps: bool = (float(gd.shift) > 0.0) != innocence
		# No points (Herald, Nov 19): the badge is an average listener's, and the judge's
		# per-guard share would be a full-weight figure.
		line += " This %s the case." % ("strengthens" if helps else "weakens")
		out.append(line)
	return out

## "Connections" (Find Links, rebuilt on the shared model): board cards not yet in this
## case that bear on its premise, ranked by how far each would move the test juror, up
## to limit. On demand only: one test-juror run per candidate. Candidates mention someone
## the case is about (its subject, or anyone on its cards). Each entry: {number, id, text,
## move (log likelihood-ratio change), helps}.
static func connections(g, value: Dictionary, limit: int = 5, budget: int = 20) -> Array:
	var base: float = 1.0
	if not value.cards.is_empty():
		var r: Dictionary = test_juror(g, value)
		if not r.get("ready", false):
			return []
		base = r.get("lr", 1.0)
	var people: Dictionary = {}
	var target: String = value.conclusion.get("target", "")
	if target != "":
		people[target] = true
	var known: Array = []
	for card in g.board:
		if card.kind == "deduction" or card.get("deleted", false):
			continue
		var id: String = Evidence.normalize_card(card).id
		if id in value.cards:
			known.append(id)
			for who in _mentions(card):
				people[who] = true
	var candidates: Array = []
	for i in range(g.board.size() - 1, -1, -1):
		var card: Dictionary = g.board[i]
		if card.kind in ["deduction", "home"] or card.get("deleted", false) or card.get("tavern_gossip", false) or not card.get("workshop_usable", true):
			continue
		var id: String = Evidence.normalize_card(card).id
		if id in value.cards or id in candidates.map(func(c): return c.id):
			continue
		if card.kind == "town_hall" or _mentions(card).any(func(who): return people.has(who)):
			candidates.append({"number": card.n, "id": id, "text": card.get("text", "")})
		if candidates.size() >= budget:
			break
	var out: Array = []
	for c in candidates:
		var with_card: Dictionary = value.duplicate(true)
		with_card.cards.append(c.id)
		var r: Dictionary = test_juror(g, with_card)
		if not r.get("ready", false):
			continue
		var move: float = log(maxf(r.get("lr", 1.0), 0.000001)) - log(maxf(base, 0.000001))
		if absf(move) < 0.01:
			continue
		c["move"] = move
		c["helps"] = move > 0.0
		out.append(c)
	out.sort_custom(func(a, b): return absf(a.move) > absf(b.move))
	return out.slice(0, limit)

## Listener-independent investigative breakdown of how the cited traces + profile/sighting
## receipts in `value` narrow the townsfolk, without revealing listener persuasion.
static func trace_summary(g, value: Dictionary) -> Dictionary:
	var input = snapshot(g, value)
	input.private_evidence = []
	input.evidence = input.evidence.filter(func(e): return e.id in input.selected)
	input.listener = {"id": "ghost", "name": "Trace check", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "source_doubt": {}, "own_gift": "", "legacy_evidence": []}
	var prepared = Assess.prepare(input)
	if not prepared.ready:
		return {"has_traces": false}
	var Solver = preload("res://workshop/solver.gd")
	var Activity = preload("res://workshop/live_activity.gd")
	var cited_cards: Array = Solver.selected(prepared.view, prepared.case)
	var struct_traces: Array = cited_cards.filter(func(c): return c.kind == "trace" and c.get("data", {}).has("family"))
	if struct_traces.is_empty():
		return {"has_traces": false}
	# Group cited structured traces by scene so two-trace scenes evaluate as (Killer / Passer) pairs.
	var scenes_map: Dictionary = {}
	var scene_order: Array = []
	for tc in struct_traces:
		var sc_id: String = str(tc.data.get("scene", tc.id))
		if not scenes_map.has(sc_id):
			scenes_map[sc_id] = []
			scene_order.append(sc_id)
		scenes_map[sc_id].append(tc)
	var compatible: Array = []
	var unresolved: Array = []
	var contradicted: Array = []
	for p in prepared.view.people:
		if not p.get("alive", true):
			continue
		var scene_contra = false
		var missing_notes: Array = []
		for sc_id in scene_order:
			var group: Array = scenes_map[sc_id]
			if group.size() >= 2:
				var e0: Dictionary = Activity.evaluate_trace_for_person(prepared.view, cited_cards, group[0], p.id)
				var e1: Dictionary = Activity.evaluate_trace_for_person(prepared.view, cited_cards, group[1], p.id)
				if e0.state == "contradicts" and e1.state == "contradicts":
					scene_contra = true
				elif e0.state != "matches" and e1.state != "matches":
					for evx in [e0, e1]:
						if evx.state == "unknown" and evx.missing != "" and evx.missing not in missing_notes:
							missing_notes.append(evx.missing)
			else:
				var ev: Dictionary = Activity.evaluate_trace_for_person(prepared.view, cited_cards, group[0], p.id)
				if int(group[0].data.get("scene_trace_count", 1)) >= 2 and ev.state != "matches":
					var note = "other scene trace uncited"
					if note not in missing_notes:
						missing_notes.append(note)
				elif ev.state == "contradicts":
					scene_contra = true
				elif ev.state == "unknown" and ev.missing != "" and ev.missing not in missing_notes:
					missing_notes.append(ev.missing)
		if scene_contra:
			contradicted.append(p.name)
		elif not missing_notes.is_empty():
			unresolved.append("%s (%s)" % [p.name, "; ".join(PackedStringArray(missing_notes))])
		else:
			compatible.append(p.name)
	var pairing_lines: Array = []
	for sc_id in scene_order:
		var group: Array = scenes_map[sc_id]
		var t0: Dictionary = group[0]
		var total_at_scene: int = int(t0.data.get("scene_trace_count", group.size()))
		if group.size() == 1 and total_at_scene >= 2:
			pairing_lines.append("• Two-trace scene note: only 1 of 2 traces from this cottage is linked (50% passer chance until paired).")
		elif group.size() >= 2:
			var t1: Dictionary = group[1]
			var night: int = int(t0.get("night", 1))
			var sblock: String = str(t0.data.get("scene_block", ""))
			var victim_id: String = str(t0.data.get("victim", ""))
			var sighted_walkers: Array = []
			for p in prepared.view.people:
				if p.id == victim_id:
					continue
				if Activity.crossing_probability(prepared.view, cited_cards, p, night, "good", sblock) >= 0.75:
					sighted_walkers.append(p)
			if not sighted_walkers.is_empty():
				for wk in sighted_walkers:
					var w_e0: String = Activity.evaluate_trace_for_person(prepared.view, cited_cards, t0, wk.id).state
					var w_e1: String = Activity.evaluate_trace_for_person(prepared.view, cited_cards, t1, wk.id).state
					if w_e1 == "matches" and w_e0 == "contradicts":
						pairing_lines.append("• Scene pairing: %s (possible walker) could account for trace 2, leaving trace 1 as a possible killer trace." % wk.name)
					elif w_e0 == "matches" and w_e1 == "contradicts":
						pairing_lines.append("• Scene pairing: %s (possible walker) could account for trace 1, leaving trace 2 as a possible killer trace." % wk.name)
					elif w_e0 == "matches" and w_e1 == "matches":
						pairing_lines.append("• Scene pairing: %s (possible walker) fits both traces; either trace could still be the killer's." % wk.name)
			else:
				pairing_lines.append("• Two-trace scene: 1 trace is the killer's and 1 is a passing night-walker's (link sightings or Watch reports on %s to separate them)." % Assess.C.block_name(sblock))
	var lines: Array = ["Trace narrowing across living townsfolk (%d cited trace%s):" % [struct_traces.size(), "s" if struct_traces.size() > 1 else ""]]
	lines.append("• Fits cited scene trace(s): " + (", ".join(PackedStringArray(compatible)) if not compatible.is_empty() else "none confirmed yet"))
	lines.append("• Unresolved (missing info): " + (", ".join(PackedStringArray(unresolved)) if not unresolved.is_empty() else "none"))
	lines.append("• Pushed against (3:1): " + (", ".join(PackedStringArray(contradicted)) if not contradicted.is_empty() else "none"))
	lines.append_array(pairing_lines)
	return {
		"has_traces": true,
		"compatible": compatible,
		"unresolved": unresolved,
		"contradicted": contradicted,
		"pairings": pairing_lines,
		"text": "\n".join(PackedStringArray(lines)),
	}

## Player-facing summary of Stage 2 Circumstantial Evidence hubs compiled in `value`.
static func circumstantial_summary(g, value: Dictionary) -> Dictionary:
	var hubs: Array = value.get("circumstantial", [])
	if hubs.is_empty():
		return {"has_hub": false}
	var input = snapshot(g, value)
	input.private_evidence = []
	input.evidence = input.evidence.filter(func(e): return e.id in input.selected)
	input["watched"] = []  # a listener's view: no raw watch record (see GhostJuror.live)
	input.listener = {"id": "ghost", "name": "Hub check", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "source_doubt": {}, "own_gift": "", "legacy_evidence": []}
	var prepared = Assess.prepare(input)
	if not prepared.ready:
		return {"has_hub": false}
	var Circumstantial = preload("res://workshop/circumstantial.gd")
	var Ghost = preload("res://workshop/ghost_juror.gd")
	var ghost: Dictionary = Ghost.live(input)
	var lines: Array = ["Circumstantial Evidence Hub (Stage 2 social framing, max +0.015/incident, +0.045 cap):"]
	var total_incidents: int = 0
	for hub in hubs:
		var t: String = str(hub.get("target", ""))
		var tname: String = g.w.by_id[t].name if g.w.by_id.has(t) else t
		var post_susp: Dictionary = {}
		for p in prepared.view.people:
			post_susp[p.id] = float(ghost.get("proposal", {}).get("effects", {}).get(p.id, {}).get("after", 0.1)) if ghost.get("ready", false) else 0.1
		var default_trust: Dictionary = {}
		for p in prepared.view.people:
			default_trust[p.id] = 0.5
		var extracted: Dictionary = Circumstantial.extract_hub_incidents(prepared.view, hub.get("cards", []), t, post_susp, default_trust, [], value.get("disputes", []))
		for k in extracted.incidents:
			total_incidents += 1
			lines.append("• %s: %s" % [tname, extracted.incidents[k].label])
		if extracted.incidents.is_empty():
			lines.append("• %s: listener-dependent (depends on each listener's trust/suspicions and Stage 1 case strength; avoid unrelated padding)." % tname)
	return {
		"has_hub": true,
		"incident_count": total_incidents,
		"text": "\n".join(PackedStringArray(lines)),
	}

static func _mentions(card: Dictionary) -> Array:
	var out: Array = []
	for who in card.get("subject", []) + [card.get("source", ""), card.get("owner", "")] + card.get("data", {}).get("seen", []) + card.get("data", {}).get("pair", []) + card.get("data", {}).get("group", []):
		if who is String and who != "" and who not in ["player", "town"] and who not in out:
			out.append(who)
	return out
