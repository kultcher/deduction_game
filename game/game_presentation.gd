## Workshop and deduction presentation routing for `Game`: snapshots, previews,
## audience readiness gates, retraction/retirement, private conversation presentation
## routing (`_route_present`), ward/sigil context presentation, and meeting deduction
## presentation (`_present_deduction`).
##
## Extracted from `game/game.gd`; `Game` retains thin forwarding methods so all
## UI panels (`ui/`) and test suites can continue calling `g.<fn>(...)` unchanged.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Deduction = preload("res://sim/deduction.gd")
const PresentationReply = preload("res://sim/presentation_reply.gd")
const WorkshopBridge = preload("res://game/workshop_bridge.gd")
const WorkshopOwnership = preload("res://game/workshop_ownership.gd")
const WorkshopPresentation = preload("res://game/workshop_presentation.gd")
const WorkshopGhost = preload("res://workshop/ghost_juror.gd")
const WorkshopAssessment = preload("res://workshop/live_assessment.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const WorkshopProfiler = preload("res://workshop/profiler.gd")


static func _canvas_status(g, value: Dictionary) -> Dictionary:
	var key = JSON.stringify(value)
	if not g._canvas_status_memo.has(key):
		g._canvas_status_memo[key] = WorkshopCanvas.status(g, value)
	return g._canvas_status_memo[key].duplicate(true)


## Read-only integration boundary. No NPC effects, time costs or Workshop fixture truth.
static func workshop_snapshot(g, numbers: Array, listener_id: String = "", venue: String = "private") -> Dictionary:
	return WorkshopBridge.capture(g, numbers, listener_id, venue)


static func workshop_preview(g, number: int, listener_id: String, venue: String = "private") -> Dictionary:
	return WorkshopAssessment.evaluate(workshop_snapshot(g, [number], listener_id, venue))


static func workshop_ghost_preview(g, number: int) -> Dictionary:
	var result: Dictionary = WorkshopGhost.live(workshop_snapshot(g, [number]))
	if number > 0 and number <= g.board.size():
		result["audience"] = workshop_readiness(g, g.board[number - 1], g.w.living(), [], "deduction", "meeting")
	return result


## Read-only and exhaustive: one unavailable listener blocks the whole test-mode
## submission. A preview may display only capability reasons, never private facts.
static func workshop_readiness(g, card: Dictionary, listeners: Array, targets: Array, direction: String, venue: String) -> Dictionary:
	var result = {"ready": true, "listeners": [], "issues": []}
	for real in listeners:
		var n = real.shadow if real.is_evil() else real
		var check: Dictionary
		if n == null:
			check = {"ready": false, "issues": ["Listener assessment is not available yet."], "exit_point": "listener"}
		else:
			check = WorkshopPresentation.readiness(g, n, card, targets, direction, venue)
		result.listeners.append({"listener": real.id, "ready": check.ready, "issues": check.issues, "exit_point": check.exit_point})
		if not check.ready:
			result.ready = false
			for issue in check.issues:
				if issue not in result.issues:
					result.issues.append(issue)
	return result


static func _presentation_gate(g, card: Dictionary, listeners: Array, targets: Array, direction: String, venue: String) -> bool:
	g._workshop_native_submission = false
	var rejected: String = _presentation_rejection(g, card)
	if rejected != "":
		g._err(rejected)
		return false
	g._workshop_native_social = false
	if card.get("conclusion", {}).get("type", "") in ["protect", "spare"]:
		# Mechanics-support item 0: a preference is social speech even when the
		# speaker attaches a card. It is not an unsupported evidence conclusion.
		g._workshop_native_submission = true
		g._workshop_native_social = true
		g.w.dlog.add("social_presentation", "player", "", {"card": card.get("n", 0)}, "A protection or mercy preference: native social response.")
		return true
	var check: Dictionary = workshop_readiness(g, card, listeners, targets, direction, venue)
	if check.ready:
		return true
	if _bare_speech(check.issues):
		# No evidence at all ("I believe they're not the Demon"): speech, which stays
		# social and native (like accusing or defending without a card).
		g._workshop_native_submission = true
		g._workshop_native_social = true
		g.w.dlog.add("social_presentation", "player", "", {"card": card.get("n", 0)}, "A bare belief with no evidence: native social response.")
		return true
	var kinds: Array = _unsupported_conclusions(check.issues)
	if not kinds.is_empty():
		# Supported evidence, but a conclusion type the shared model doesn't judge
		# (secret, red herring). There is no legacy judge behind it any more (purge
		# phase 4): block it with its reason, like any other unsupported submission.
		g.w.dlog.trace_event("workshop_conclusion_blocked", "player", "", {"card": card.get("n", 0), "kinds": kinds.duplicate()}, "Unsupported conclusion type blocked (no legacy route).")
		g._err("Cannot present. Card #%d: the town can't weigh a '%s' conclusion. Present it as a case about who is good or evil instead." % [card.get("n", 0), ", ".join(PackedStringArray(kinds))])
		return false
	# Per listener: a row blocked only by canvas authoring problems (a missing cited
	# claim, an empty hub) is not a model gap, so it is not counted as a fallback.
	for row in check.listeners:
		if not row.ready and not _all_authoring_validation_issues(row.issues):
			WorkshopOwnership.fallback(g, g.w.by_id[row.listener], "preflight_" + row.exit_point, row.issues, card.get("n", 0))
	if _all_authoring_validation_issues(check.issues):
		g.w.dlog.trace_event("workshop_validation_blocked", "player", "", {"card": card.get("n", 0), "issues": check.issues.duplicate(true)}, "Blocked incomplete canvas submission without legacy fallback.")
	# No legacy route for presentations: an unsupported submission is blocked with its
	# reason, so a playtest always tests the shared model (user, Oct 25).
	var reason = "Card #%d: %s" % [card.get("n", 0), "; ".join(PackedStringArray(check.issues))]
	g._err("Cannot present. " + reason + " Remove the unsupported card and present the rest.")
	return false


## Conclusion types named by issues that are only about the conclusion ("Unsupported
## claim: role"), or [] if any issue is about the evidence itself.
static func _all_authoring_validation_issues(issues: Array) -> bool:
	if issues.is_empty():
		return false
	const PREFIXES = [
		"Activity citations need an included walking-role or applicable secret claim",
		"Invalid activity citations:",
		"Link at least one supporting card into the Circumstantial Evidence hub",
		"Circumstantial Evidence hubs support accusatory premises",
		"Circumstantial Evidence hub references missing root cards",
		"Invalid reading challenge or missing grounds",
		"Invalid or unsupported disputes:",
		"Select a filed deduction as the comparison's headline claim",
		"No supported reading is presented",
		"Conflicting reading challenges need separate alternatives",
	]
	for issue in issues:
		var s: String = str(issue)
		if not PREFIXES.any(func(p): return s.begins_with(p)):
			return false
	return true


static func _unsupported_conclusions(issues: Array) -> Array:
	var kinds: Array = []
	for issue in issues:
		var text = str(issue)
		if text.begins_with("Unsupported claim: ") or text.begins_with("Unsupported endorsed claim: "):
			var kind = text.get_slice(": ", 1)
			if kind not in kinds:
				kinds.append(kind)
		else:
			return []
	return kinds


## Issues that only say "there's no evidence here", as opposed to evidence the shared
## model can't read.
static func _bare_speech(issues: Array) -> bool:
	if not "No supported reading is presented." in issues:
		return false
	return issues.all(func(issue): return issue == "No supported reading is presented." or str(issue).begins_with("Unsupported claim:"))


static func _presentation_rejection(g, card: Dictionary) -> String:
	if card.get("tavern_gossip", false) or not card.get("workshop_usable", true):
		return "Card #%d is an unattributed tavern rumour and cannot be cited as evidence." % int(card.get("n", 0))
	if card.get("superseded_by", 0) > 0:
		return "Case #%d was superseded by case #%d." % [card.n, card.superseded_by]
	var speech: Array = []
	if card.kind == "deduction":
		var input: Dictionary = workshop_snapshot(g, [card.n])
		for number in input.board_map:
			var rec: Dictionary = g.receipt_by_number(int(number))
			if not rec.is_empty() and input.board_map[number] in input.selected and WorkshopPresentation.Evidence.contains_opinion(rec):
				speech.append(rec)
	elif WorkshopPresentation.Evidence.contains_opinion(card):
		speech = [card]
	if not speech.is_empty():
		if speech[0].kind == "info":
			return "A relayed opinion is not evidence. Cite the deceased person's supporting observations or readings."
		return "An %s is not evidence. Cite the supporting observations or readings." % speech[0].kind
	return ""


static func workshop_retract(g, number: int, listener_id: String) -> void:
	if g.workshop_presenting:
		# Internal revision retirement is part of the same presentation, so it
		# goes through the private helper; external withdrawal waits its turn.
		return
	_workshop_retract(g, number, listener_id)


static func _workshop_retract(g, number: int, listener_id: String) -> void:
	var real = g.w.by_id.get(listener_id)
	if real == null:
		return
	var n = real.shadow if real.is_evil() else real
	if n == null:
		return
	var paths: Array = [str(number)]
	for key in n.workshop_state.get("presentations", {}):
		if str(key).begins_with("direct:%d:" % number):
			paths.append(key)
	if not n.workshop_state.has("withdrawn"):
		n.workshop_state.withdrawn = {}
	for key in paths:
		n.workshop_state.get("presentations", {}).erase(key)
		n.workshop_state.withdrawn[key] = true
	if number > 0 and number <= g.board.size() and g.board[number - 1].has("workshop_case"):
		var entry: Dictionary = n.ledger.get("arg:workshop:%d" % number, {})
		if not entry.is_empty():
			entry.weight = 0.0
			entry.justs = []
			entry.meta = {"kind": "retired_workshop"}
	Mind.refresh_beliefs(g.w, n, " (case endorsement withdrawn)")


## All three deduction venues share receipt ownership and optional comparison.
static func _evaluate_deduction(g, n, ded: Dictionary, scale: float, speak: bool = true, venue: String = "private") -> Dictionary:
	var span = WorkshopProfiler.open("listener", n.id)
	# The player argued this to them: it joins their track record (game/credibility.gd).
	var said: Dictionary = ded.get("conclusion", {})
	preload("res://game/credibility.gd").record(n, str(said.get("type", "")), str(said.get("a", "")), g.w.day, Tuning.Trust.CRED_WEIGHT_FORMAL)
	var result: Dictionary = _evaluate_deduction_inner(g, n, ded, scale, speak, venue)
	WorkshopProfiler.close(span)
	return result


static func _evaluate_deduction_inner(g, n, ded: Dictionary, scale: float, speak: bool = true, venue: String = "private") -> Dictionary:
	var rejected: String = _presentation_rejection(g, ded)
	if rejected != "":
		return {"blocked": true, "lines": [rejected], "facts": [], "agreement": 0.0}
	if g.strict_evaluator:
		var check: Dictionary = workshop_readiness(g, ded, [n], [], "deduction", venue)
		if not check.ready:
			return {"blocked": true, "lines": ["Cannot present: " + "; ".join(PackedStringArray(check.issues))], "facts": [], "agreement": 0.0}
	if ded.has("workshop_case"):
		workshop_canvas_retire(g, n, ded)
	var snapshot: Dictionary = workshop_snapshot(g, [ded.n], n.id, venue) if g.workshop_compare else {}
	var before: Dictionary = n.suspicion.duplicate(true) if g.workshop_compare else {}
	var result: Dictionary = PresentationReply.evaluate(g.w, n, ded, g.all_receipts(), scale, speak)
	if result.get("blocked", false):
		return result
	if not result.get("workshop", false):
		Mind.refresh_beliefs(g.w, n, " (shared presentation)")
		_conflict_pressure(g, ded, 0.1 if venue == "private" else 0.2, n, true)
	if g.workshop_compare:
		var comparison: Dictionary = WorkshopAssessment.evaluate(snapshot)
		comparison.listener = n.id
		comparison["card"] = ded.n
		comparison["venue"] = venue
		comparison["actual"] = {
			"model": "shared" if result.get("workshop", false) else "legacy",
			"agreement": result.get("agreement", 0.0),
			"before": before,
			"after": n.suspicion.duplicate(true),
		}
		if not result.get("workshop", false):
			comparison["legacy"] = comparison.actual.duplicate(true)
		g.workshop_comparisons.append(comparison)
		if g.workshop_comparisons.size() > 24:
			g.workshop_comparisons.pop_front()
		g.w.dlog.trace_event("workshop_comparison", n.id, ded.conclusion.get("a", ""), {"comparison": comparison, "input": snapshot},
			"Read-only proposal beside the actual named presentation model; the comparison itself applies no effects.")
	if ded.has("workshop_case"):
		var capability: Dictionary = _canvas_status(g, ded.workshop_case)
		var issues: Array = capability.issues.duplicate()
		if not result.get("workshop", false) and issues.is_empty():
			issues.append("This listener could not use the shared assessment; existing response rules were used.")
		g.workshop_deliveries.append({
			"listener": n.id,
			"name": n.name,
			"card": ded.n,
			"venue": venue,
			"model": "shared" if result.get("workshop", false) else "legacy",
			"issues": issues,
		})
		g.w.dlog.trace_event("workshop_delivery", n.id, ded.conclusion.get("a", ""), g.workshop_deliveries[-1],
			"Actual live-canvas presentation model and player-safe fallback feedback.")
		if g.workshop_deliveries.size() > 100:
			g.workshop_deliveries.pop_front()
	return result


## Canvas revisions replace this listener's previous endorsement only when heard.
## Keep a dedicated native ledger entry so other filed arguments are untouched.
static func workshop_canvas_retire(g, real, ded: Dictionary) -> void:
	if ded.n < 1 or ded.n > g.board.size() or g.board[ded.n - 1].get("workshop_case", {}) != ded.workshop_case:
		return # An old relayed wrapper cannot retract a newer heard revision.
	var n = real.shadow if real.is_evil() else real
	if n == null:
		return
	var st: Dictionary = n.workshop_state
	var ancestor: int = ded.get("revises", 0)
	while ancestor > 0 and ancestor <= g.board.size():
		if st.get("presentations", {}).has(str(ancestor)) or n.ledger.has("arg:workshop:%d" % ancestor):
			_workshop_retract(g, ancestor, n.id)
		ancestor = g.board[ancestor - 1].get("revises", 0)
	if not st.has("canvas_versions"):
		st.canvas_versions = {}
	var key = str(ded.n)
	var signature = JSON.stringify(ded.workshop_case)
	if st.canvas_versions.get(key, signature) != signature:
		_workshop_retract(g, ded.n, n.id)
	st.canvas_versions[key] = signature


## "present <card#> [for|against <name>]" in conversation: work out what the player means.
static func _route_present(g, n, rest: String) -> Dictionary:
	var p = rest.strip_edges().split(" ", false)
	if p.is_empty():
		return {"error": "Present which card? ('present <card#>')"}
	var num = p[0].trim_prefix("#").to_int()
	if num < 1 or num > g.board.size() or g.board[num - 1].get("deleted", false):
		return {"error": "No such card on your board."}
	var card: Dictionary = g.board[num - 1]
	if card.get("tavern_gossip", false) or not card.get("pressable", true) or not card.get("workshop_usable", true):
		return {"error": "Card #%d is only an unattributed tavern rumour; you can't press or cite someone with it." % num}
	if card["kind"] in ["home", "haunt"]:
		return {"flat": "Where %s lives or idles is nothing to put to anyone." % g.w.by_id[card["subject"][0]].name}
	var dir = ""
	var who = null
	if p.size() >= 3 and p[1].to_lower() in ["for", "against", "about"]:
		dir = p[1].to_lower()
		who = g.find_npc(p[2], true)
		if who == null:
			return {"error": "Who is '%s'?" % p[2]}
	# An explicit supportive statement is not a demand that the listener explain
	# themselves, whether the cited card is a claim or one of the player's deductions.
	if who == n and dir == "for":
		return {"verb": "defend", "rest": "%s %d" % [n.id, num], "note": "You speak up for %s." % n.name}
	if card["kind"] == "deduction":
		var cc: Dictionary = Deduction.normalize(card["conclusion"].duplicate())
		if cc.get("a", "") == n.id and not (cc["type"] in ["misled", "unreliable"]):
			return {"verb": "press", "rest": str(num), "note": "You put it to %s directly." % n.name}
		return {"verb": "convince", "rest": str(num), "note": "You argue it to %s." % n.name}
	var subj: Array = card.get("subject", []).duplicate()
	for x in card.get("data", {}).get("pair", []):
		if not (x in subj):
			subj.append(x)
	if who == null and (n.id in subj or card.get("owner", "") == n.id):
		return {"verb": "press", "rest": str(num), "note": "You put it to %s directly." % n.name}
	if who == n and dir != "for":
		return {"verb": "press", "rest": str(num), "note": "You put it to %s directly." % n.name}
	if who == null and card.get("kind", "") == "trace" and card.get("trace_family", "") != "":
		return {"verb": "trace_ask", "rest": str(num), "note": "You ask %s what they make of the scene trace." % n.name}
	var targets: Array = [who.id] if who != null else subj.filter(func(x): return x != n.id and x != card.get("source", "") and g.w.by_id.has(x) and g.w.by_id[x].alive)
	if targets.is_empty():
		return _present_fallback(g, n, num, "the card isn't about anyone living")
	if dir == "":
		# Which way the card points, from its structure alone (purge phase 4b): who it
		# implicates and who it speaks for. A secret both points at its owner and partly
		# explains them; pressing it on someone is an accusation, as before.
		var inc = false
		var dfn = false
		for x in targets:
			inc = inc or Mind.card_implicates(g.w, card, x)
			dfn = dfn or Mind.card_clears(card, x)
		if inc and (not dfn or card.get("kind", "") == "secret"):
			dir = "against"
		elif dfn and not inc:
			dir = "for"
		else:
			return _present_fallback(g, n, num, "no clear direction (incriminating %s, clearing %s)" % [str(inc), str(dfn)])
	var names = Deduction._names(g.w, targets)
	var ids = ",".join(PackedStringArray(targets))
	if dir == "for":
		return {"verb": "defend", "rest": "%s %d" % [ids, num], "note": "You speak up for %s." % names}
	return {"verb": "tell", "rest": "%s %d" % [ids, num], "note": ("You make your case against %s." if targets.size() == 1 else "You point out it implicates one of %s.") % names}


## The card has no direction of its own: it falls flat, costs no question, and is logged
## so we can see which cards keep landing here.
static func _present_fallback(g, n, num: int, why: String) -> Dictionary:
	g.fallback_count += 1
	g.w.dlog.add("present_fallback", "player", n.id, {"card": num, "kind": g.board[num - 1]["kind"], "why": why},
		"present couldn't tell what the card was meant to prove (%s)" % why)
	return {"verb": "", "rest": "", "note": "", "flat": "%s: \"I'm not sure what you're trying to prove.\" (You can say 'present %d for <name>' or 'against <name>'.)" % [n.name, num]}


## "Something doesn't add up" puts the people involved under scrutiny: publicly, all of
## them; privately, only the listener if they're one of them.
static func _conflict_pressure(g, ded: Dictionary, amount: float, listener, fallback: bool = false) -> void:
	if not fallback:
		return # The supported assessment owns scrutiny; unsupported paths retain native behavior.
	var c: Dictionary = ded.get("conclusion", {})
	if c.get("type", "") != "conflict":
		return
	for id in c.get("group", []):
		var m = g.w.by_id[id]
		if not m.alive or (listener != null and m != listener):
			continue
		m.pressure += amount
		g.w.dlog.think(m.id, "pressed", "Under scrutiny: the Demonologist says something doesn't add up (pressure +%.2f -> %.2f)." % [amount, m.pressure])


## A deduction resting on someone's confessed secret spreads it, just like citing it.
static func _secrets_used(g, ded: Dictionary, depth: int = 0) -> void:
	for x in ded.get("supports", []):
		var c: Dictionary = g.receipt_by_number(x)
		if c.is_empty():
			continue
		if c["kind"] == "secret":
			Mind._secret_used(g.w, c)
		elif c["kind"] == "deduction" and depth < 3:
			_secrets_used(g, c, depth + 1)


## Present a deduction to the whole meeting (once per meeting).
## Context receipts are shown directly, without a shared-model adapter or numeric
## evidence effect. Claude owns that adapter; this only delivers the approved trust.
static func _ward_context_card(g, rest: String) -> Dictionary:
	var parts = rest.strip_edges().split(" ", false)
	if parts.size() != 1:
		return {}
	var num = parts[0].trim_prefix("#").to_int()
	if num < 1 or num > g.board.size():
		return {}
	var card: Dictionary = g.board[num - 1]
	return card if not card.get("deleted", false) and card.kind in ["ward", "scorched_sigil"] else {}


static func _show_ward_context(g, card: Dictionary, listeners: Array) -> Dictionary:
	var public_show: bool = g.state in ["meeting", "nomination"]
	if public_show:
		card["private"] = false
		g._disclose(card, g._disclosure(card))
	var rewarded: Array = []
	if card.kind == "scorched_sigil":
		var heard: Array = g.sigil_heard.get(card.n, [])
		for listener in listeners:
			if not listener.alive or listener.id in heard:
				continue
			heard.append(listener.id)
			rewarded.append(listener.id)
			var bonus: float = Tuning.Trust.WARD_SIGIL_BONUS + (Tuning.Trust.WARD_SIGIL_TARGET_BONUS if listener.id == card.target else 0.0)
			Mind.set_trust(g.w, listener, listener.trust + bonus, "the Demonologist showed a scorched ward sigil")
		g.sigil_heard[card.n] = heard
	var ward_night: int = int(card.get("night", card.get("day", -1)))
	g.w.dlog.add("player_ward_context", "player", card.get("target", ""), {"card": card.n, "night": ward_night, "kind": str(card.get("kind", "")), "listeners": listeners.map(func(n): return n.id), "rewarded": rewarded, "public": public_show})
	if ward_night >= 1:
		for listener in listeners:
			if listener.alive:
				g.w.reweigh_warden_credit_for_ward(listener, ward_night, str(card.get("kind", "")), str(card.get("target", "")))
	return {"lines": ["You show %s: %s" % ["the town" if public_show else ", ".join(PackedStringArray(listeners.map(func(n): return n.name))), card.text]], "facts": []}


static func _present_deduction(g, rest: String, progress: Callable = Callable()) -> void:
	if g.presented_today:
		g._err("You've already had the floor today.")
		return
	var context_card: Dictionary = _ward_context_card(g, rest)
	if not context_card.is_empty():
		g.presented_today = true
		g._lines(_show_ward_context(g, context_card, g.w.living()).lines)
		return
	var num = rest.strip_edges().trim_prefix("#").to_int()
	if num < 1 or num > g.board.size() or g.board[num - 1]["kind"] != "deduction" or g.board[num - 1].get("deleted", false):
		g._err("Present which case? ('present <card#>'; file one in the Case Workshop)")
		return
	var ded: Dictionary = g.board[num - 1]
	if not _presentation_gate(g, ded, g.w.living(), [], "deduction", "meeting"):
		return
	g.presented_today = true
	g._narr("You take the floor: %s" % ded["text"])
	if g.public_presentations.has(num):
		g._ev({"k": "note", "text": "This case is already public knowledge: presenting it again doesn't sway the town further, but it stands on its own merits."})
	g.public_presentations[num] = true
	g.w.dlog.add("player_present", "player", ded["conclusion"].get("a", ""), {"card": num})
	g._break_confidences([num] + Array(ded.get("supports", [])))
	_secrets_used(g, ded)
	_conflict_pressure(g, ded, 0.2, null)
	for n in g.w.living():
		if progress.is_valid():
			await progress.call(n.name)
		var r: Dictionary = _evaluate_deduction(g, n, ded, Tuning.Workshop.VENUE_MULTS.meeting, true, "meeting")
		g._lines(r["lines"])
