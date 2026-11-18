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
	if card.get("deprecated", false):
		var by_id: String = str(card.get("disclaimed_by", ""))
		var by_nm: String = g.w.by_id[by_id].name if g.w.by_id.has(by_id) else "its source"
		return "Card #%d was disclaimed by %s as muddled and is deprecated." % [int(card.get("n", 0)), by_nm]
	if card.get("tavern_gossip", false) or not card.get("workshop_usable", true):
		return "Card #%d is an unattributed tavern rumour and cannot be cited as evidence." % int(card.get("n", 0))
	if card.get("superseded_by", 0) > 0:
		return "Case #%d was superseded by case #%d." % [card.n, card.superseded_by]
	if card.get("withdrawn", false):
		return "Case #%d was withdrawn." % card.n
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


## `clear_now`: the case was replaced by a revision backed by new evidence, so the claims it
## made leave the player's track record at once; otherwise they are judged once more at the
## next dawn (Credibility.retire_case; Michael, Nov 18, option c).
static func _workshop_retract(g, number: int, listener_id: String, clear_now: bool = false) -> void:
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
	preload("res://game/credibility.gd").retire_case(real, number, clear_now)
	Mind.refresh_beliefs(g.w, n, " (case endorsement withdrawn)")


## All three deduction venues share receipt ownership and optional comparison.
static func _evaluate_deduction(g, n, ded: Dictionary, scale: float, speak: bool = true, venue: String = "private") -> Dictionary:
	var span = WorkshopProfiler.open("listener", n.id)
	# The player argued this to them: it joins their track record (game/credibility.gd).
	var said: Dictionary = ded.get("conclusion", {})
	preload("res://game/credibility.gd").record(n, str(said.get("type", "")), str(said.get("a", "")), g.w.day, Tuning.Trust.CRED_WEIGHT_FORMAL, int(ded.get("n", 0)))
	preload("res://game/credibility.gd").record_case_secrets(n, ded, g.w.day)
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
	var why_was: Dictionary = preload("res://game/workshop_why.gd").before(n, g) if g.workshop_why else {}
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
	if g.workshop_why and (result.get("workshop", false) or n.is_evil()) and not result.get("repeated", false):
		# Read-only: why this listener moved as far as they did (docs/DECISION_INSPECTOR.md).
		# An evil listener's entry is its good cover's, when the cover was shown the case.
		preload("res://game/workshop_why.gd").record(g, n, ded, venue, why_was)
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
		if st.get("presentations", {}).has(str(ancestor)) or n.ledger.has("arg:workshop:%d" % ancestor) or _record_cites(real, ancestor):
			_workshop_retract(g, ancestor, n.id, new_evidence(g.board[ancestor - 1], ded))
		ancestor = g.board[ancestor - 1].get("revises", 0)
	if not st.has("canvas_versions"):
		st.canvas_versions = {}
	var key = str(ded.n)
	var signature = JSON.stringify(ded.workshop_case)
	if st.canvas_versions.get(key, signature) != signature:
		_workshop_retract(g, ded.n, n.id)
	st.canvas_versions[key] = signature


## A revision of a case the town has heard, backed by new evidence, is narrated as one
## (Michael, Nov 18: the player is silent; the game narrates): "You stand and revise case #N
## in light of something new: <the new card, in the board's short form>." "" otherwise.
static func _revision_narration(g, ded: Dictionary) -> String:
	var CardModel = load("res://game/card_model.gd")
	var older: int = int(ded.get("revises", 0))
	while older > 0 and older <= g.board.size() and not g.public_presentations.has(older):
		older = int(g.board[older - 1].get("revises", 0))
	if older < 1 or older > g.board.size() or not new_evidence(g.board[older - 1], ded):
		return ""
	var before: Array = g.board[older - 1].get("supports", [])
	var names: Dictionary = {}
	for n in g.w.npcs:
		names[n.id] = n.name
	for x in ded.get("supports", []):
		if int(x) > 0 and not (x in before) and int(x) <= g.board.size():
			var short: String = str(CardModel.short_text(g.board[int(x) - 1], names)).strip_edges()
			if not short.ends_with(".") and not short.ends_with("…"):
				short += "."
			return "You stand and revise case #%d in light of something new: %s" % [older, short]
	return ""


## Does `case` cite an original card that `older` didn't? Then a revision from `older` to
## `case` is "changing your mind for a reason", and the old version's claims leave the
## track record at once (Michael, Nov 18, option c).
static func new_evidence(older: Dictionary, case: Dictionary) -> bool:
	var before: Array = older.get("supports", []).filter(func(x): return int(x) > 0)
	for x in case.get("supports", []):
		if int(x) > 0 and not (x in before):
			return true
	return false


## A public withdrawal takes back the argument, not the evidence: each original card the
## listener heard only through case `number` gets an owner of its own, as testimony the
## player passed on (Codex on #262). A private developer retraction still removes them.
static func _keep_receipts(g, mind, number: int) -> void:
	var Shared = preload("res://workshop/shared_ledger.gd")
	var presentations: Dictionary = mind.workshop_state.get("presentations", {})
	for key in presentations:
		if str(key) != str(number) and not str(key).begins_with("direct:%d:" % number):
			continue
		var presented: Dictionary = presentations[key]
		var endorsed: Array = Shared.endorsed_facts(presented, presented.root)
		for receipt in presented.get("evidence", []):
			if receipt.id in presented.get("selected", []) and receipt.id in endorsed:
				var eid: String = "tell:kept:%d:%s" % [number, str(receipt.id)]
				if not mind.ledger.has(eid):
					# The shape Mind.ledger_hear gives a heard card; no weight of its own.
					mind.ledger[eid] = {"eid": eid, "effects": [], "weight": 0.0, "rel": ["player", g.w.day, "tell"], "day": g.w.day, "times": 1,
						"justs": [], "meta": {"kind": "tell", "workshop_card": receipt.duplicate(true),
						"text": str(receipt.get("text", "")), "kept_from_case": number}}


## Does `real`'s track record still hold a claim from case `number`?
static func _record_cites(real, number: int) -> bool:
	for entry in real.claim_record.values():
		if int(entry.get("case", 0)) == number:
			return true
	return false


## The player takes back case `number` in public ("I take back case #N"; BACKLOG "Believable
## public revisions", Michael, Nov 18). Everyone who heard it drops the argument (the same
## retraction as a private withdrawal) and keeps the cards it cited as their own items. The
## board keeps the case, marked withdrawn; it can't be presented or nominated on again.
## Its claims stay in each listener's track record for the next dawn's check, then leave.
## Returns "" or why it can't be withdrawn.
static func workshop_withdraw_public(g, number: int) -> String:
	if g.workshop_presenting:
		return "Wait until the current presentation ends."
	if number < 1 or number > g.board.size():
		return "There's no case #%d." % number
	var card: Dictionary = g.board[number - 1]
	if card.get("kind", "") != "deduction" or card.get("deleted", false):
		return "Only a case you've filed can be taken back."
	if int(card.get("superseded_by", 0)) > 0:
		return "Case #%d was replaced by case #%d. Take that one back instead." % [number, int(card.superseded_by)]
	if card.get("withdrawn", false):
		return "You've already taken back case #%d." % number
	card["withdrawn"] = true
	card["withdrawn_day"] = g.w.day
	# The case and every earlier version of it: someone who missed a revision still holds
	# the version they heard, and that is taken back too (Codex on #262).
	var versions: Array = []
	var v: int = number
	while v > 0 and v <= g.board.size() and not (v in versions):
		versions.append(v)
		v = int(g.board[v - 1].get("revises", 0))
	var heard: Array = []
	for real in g.w.npcs:
		var mind = real.shadow if real.is_evil() and real.shadow != null else real
		var st: Dictionary = mind.workshop_state
		for ver in versions:
			var has_it: bool = st.get("presentations", {}).has(str(ver)) or mind.ledger.has("arg:workshop:%d" % ver) or _record_cites(real, ver)
			for key in st.get("presentations", {}):
				if str(key).begins_with("direct:%d:" % ver):
					has_it = true
			if has_it:
				_keep_receipts(g, mind, ver)
				_workshop_retract(g, ver, real.id, false)
				if not (real.id in heard):
					heard.append(real.id)
		real.player_cases = real.player_cases.filter(func(c): return not (int(c.get("card", {}).get("n", 0)) in versions))
	g.w.dlog.add("deduction_withdrawn", "player", str(card.get("conclusion", {}).get("a", "")), {"card": number, "heard": heard, "day": g.w.day},
		"The Demonologist took back case #%d in public." % number)
	return ""


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


## What a protection receipt shows, for buttons and prompts ("your ward on Agnes's door, night 2").
static func protection_label(g, card: Dictionary) -> String:
	var t = g.w.by_id.get(str(card.get("target", "")))
	var who: String = ("%s's" % t.name) if t != null else "a"
	var night: int = int(card.get("night", card.get("day", -1)))
	var when: String = (", night %d" % night) if night >= 0 else ""
	if card.get("kind", "") == "scorched_sigil":
		return "the scorched sigil on %s door%s" % [who, when]
	return "your ward on %s door%s" % [who, when]


static func _present_deduction(g, rest: String, progress: Callable = Callable()) -> void:
	# A ward or scorched sigil is shown, not argued: it doesn't take the day's floor, and
	# each one is shown to the whole town once.
	var context_card: Dictionary = _ward_context_card(g, rest)
	if not context_card.is_empty():
		if g.shown_protection.has(int(context_card.n)):
			g._err("The town has already seen %s." % protection_label(g, context_card))
			return
		g.shown_protection[int(context_card.n)] = true
		g._lines(_show_ward_context(g, context_card, g.w.living()).lines)
		return
	if g.presented_today:
		g._err("You've already had the floor today.")
		return
	var num = rest.strip_edges().trim_prefix("#").to_int()
	if num < 1 or num > g.board.size() or g.board[num - 1]["kind"] != "deduction" or g.board[num - 1].get("deleted", false):
		g._err("Present which case? ('present <card#>'; file one in the Case Workshop)")
		return
	var ded: Dictionary = g.board[num - 1]
	if not _presentation_gate(g, ded, g.w.living(), [], "deduction", "meeting"):
		return
	g.presented_today = true
	var revised: String = _revision_narration(g, ded)
	if revised != "":
		g._narr(revised)
	g._narr("You take the floor: %s" % ded["text"])
	if g.public_presentations.has(num) and WorkshopPresentation.faded(g, ded):
		g._ev({"k": "note", "text": "The town has heard this case before. Putting it to them again brings it back to mind."})
	elif g.public_presentations.has(num):
		g._ev({"k": "note", "text": "This case is already public knowledge: presenting it again doesn't sway the town further, but it stands on its own merits."})
	g.public_presentations[num] = int(g.w.day)
	g.w.dlog.add("player_present", "player", ded["conclusion"].get("a", ""), {"card": num})
	g._break_confidences([num] + Array(ded.get("supports", [])))
	_secrets_used(g, ded)
	_conflict_pressure(g, ded, 0.2, null)
	for n in g.w.living():
		if progress.is_valid():
			await progress.call(n.name)
		var r: Dictionary = _evaluate_deduction(g, n, ded, Tuning.Workshop.VENUE_MULTS.meeting, true, "meeting")
		g._lines(r["lines"])
		# What a listener told the town in answer (a caught alibi explained) goes on the board
		# too (Codex on #261).
		g._facts(r.get("facts", []))
