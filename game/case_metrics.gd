## Post-case analysis only. Never consulted by NPCs or the player's bot policy.
extends RefCounted

const C = preload("res://sim/content.gd")
const Gifts = preload("res://sim/gifts.gd")

## Everyone guessed as any minion role (the generic minion guess is any of them).
static func minion_guesses(guesses: Dictionary) -> Array:
	var ids: Array = []
	for id in guesses:
		if C.is_minion(guesses[id].get("guess", "")):
			ids.append(id)
	ids.sort()
	return ids

static func named_guesses(guesses: Dictionary, role: String) -> Array:
	var ids: Array = []
	for id in guesses:
		if guesses[id].get("guess", "") == role:
			ids.append(id)
	ids.sort()
	return ids

## Was there evidence pointing at the demon, and where? on_board: cards you held; reachable:
## held by living townsfolk (true readings, night sightings) or an unsearched true trace.
## Descriptive only: it says what existed, not that the player should have found it.
static func demon_evidence(w, board: Array) -> Dictionary:
	var d: String = w.demon_id
	var dn = w.by_id[d]
	var on_board: Array = []
	for c in board:
		if c.get("deleted", false) or c.get("kind", "") == "deduction":
			continue
		if _points_at(w, c.get("kind", ""), c.get("role", ""), c.get("data", {}), c.get("subject", []), c.get("phase", -1), d):
			on_board.append(c["n"])
		elif c.get("kind", "") == "trace" and c.get("block", "") == w.loc_block(dn.history.get(w.time_key(c.get("day", -1), 2), "home:" + dn.home_block)):
			on_board.append(c["n"])
	var reachable: Array = []
	for n in w.npcs:
		if n.is_evil():
			continue
		for e in n.info_log:
			if not e.get("true", true):
				continue
			if _points_at(w, "info", e.get("role", ""), e.get("data", {}), [], -1, d):
				reachable.append("%s's %s reading (night %d)" % [n.name, e.get("role", ""), e.get("day", -1)])
		for b in n.beliefs:
			if b.get("kind", "") == "saw" and b.get("who", "") == d and b.get("phase", -1) == 3:
				reachable.append("%s saw %s out on night %d" % [n.name, dn.name, b.get("day", -1)])
	for sid in w.scenes:
		var sc: Dictionary = w.scenes[sid]
		if not sc["searched"] and sc["trace_true"]:
			reachable.append("the unsearched trace at %s" % sc["name"])
	return {"on_board": on_board, "reachable": reachable}

static func _points_at(w, kind: String, role: String, data: Dictionary, subj: Array, phase: int, d: String) -> bool:
	match kind:
		"info":
			return d in Gifts.implicated({"role": role, "data": data})
		"sighting", "vigil":
			return phase == 3 and d in subj
	return false

## Night outcomes: how often the demon was stopped, and by what; how well the Warden did.
static func night_stats(w) -> Dictionary:
	var out = {"kills": 0, "blocked_warden": 0, "blocked_veteran": 0, "blocked_ward": 0, "warden_protects": 0,
		"warden_spotted": 0, "warden_killed": false, "warden_in_play": false}
	for n in w.npcs:
		if n.role == "warden":
			out["warden_in_play"] = true
	for e in w.dlog.entries:
		match e["type"]:
			"kill":
				out["kills"] += 1
				if e["data"].get("role", "") == "warden":
					out["warden_killed"] = true
			"kill_failed":
				var why: String = e["data"].get("why", "")
				if why == "protected_warden":
					out["blocked_warden"] += 1
				elif why == "veteran":
					out["blocked_veteran"] += 1
				elif why == "protected_player":
					out["blocked_ward"] += 1
			"protect":
				if e["actor"] != "player":
					out["warden_protects"] += 1
			"evil_intel":
				if "likely the Warden" in e.get("reason", ""):
					out["warden_spotted"] += 1
	out["warden_hit_rate"] = float(out["blocked_warden"]) / out["warden_protects"] if out["warden_protects"] > 0 else null
	return out

static func summarize(w, snapshot: Dictionary, spoiled: bool, board: Array = []) -> Dictionary:
	var guesses: Dictionary = snapshot.get("guesses", {})
	var demon_guesses = named_guesses(guesses, "demon")
	var m_guesses = minion_guesses(guesses)
	var eligible = not spoiled and not snapshot.is_empty()
	# Credit goes for naming the demon the case started with (if a Scion took over, the
	# single demon guess can't name both).
	var first: String = w.first_demon_id if w.first_demon_id != "" else w.demon_id
	var demon_correct = eligible and demon_guesses == [first]
	var true_minions: Array = w.minion_ids.duplicate()
	true_minions.sort()
	var minion_correct = eligible and m_guesses == true_minions
	var goods = w.npcs.filter(func(n): return not n.is_evil())
	var survivors = w.living_good().size()
	var executions: Array = []
	var wrongful = 0
	var backed_wrongful = 0
	var opposed_wrongful = 0
	var mixed_wrongful = 0
	for ex in w.executions:
		# A Martyr's death is recorded against the nomination: the nominee (who lived) and
		# the Martyr who died in their place.
		var target = w.by_id[ex.get("saved", ex["id"])]
		var died = w.by_id[ex["id"]]
		var accused = false
		var defended = false
		for event in w.dlog.entries:
			if event["day"] == ex["day"] and event["target"] == target.id and event["type"] == "player_statement":
				accused = accused or event["data"].get("statement", "") == "accuse"
				defended = defended or event["data"].get("statement", "") == "defend"
		var yes: bool = ex.get("player_yes", false)
		var nominated: bool = ex.get("player_nominated", false)
		var backed = nominated or yes or accused
		var opposed = not yes or defended
		var stance = "mixed" if backed and opposed else "backed" if backed else "opposed"
		var row = {"day": ex["day"], "id": target.id, "role": target.role, "alignment": target.alignment,
			"nominator": ex.get("nominator", ""), "player_nominated": nominated, "player_voted_yes": yes,
			"player_voted_no": not yes, "player_accused": accused, "player_defended": defended,
			"player_backed": backed, "player_opposed": opposed, "player_stance": stance}
		if ex.get("martyr", false):
			row["martyr_died"] = died.id
		executions.append(row)
		if not died.is_evil():
			wrongful += 1
			if stance == "backed":
				backed_wrongful += 1
			elif stance == "mixed":
				mixed_wrongful += 1
			else:
				opposed_wrongful += 1
	var saved: bool = w.game_over and w.winner == "good"
	var ev = demon_evidence(w, board)
	var loss_hint = ""
	if w.game_over and not saved:
		if demon_correct:
			loss_hint = "identified_not_persuaded"
		elif not ev["on_board"].is_empty():
			loss_hint = "evidence_on_board"
		elif not ev["reachable"].is_empty():
			loss_hint = "evidence_reachable"
		else:
			loss_hint = "no_evidence"
	var outcome = "incomplete"
	if w.game_over:
		outcome = "identified_and_saved" if saved and demon_correct else "saved_without_identification" if saved else "identified_but_lost" if demon_correct else "lost_without_identification"
	return {"schema_version": 2, "seed": w.seed_value, "loss_hint": loss_hint,
		"demon_evidence_on_board": ev["on_board"], "demon_evidence_reachable": ev["reachable"], "nights": night_stats(w), "complete": w.game_over, "winner": w.winner,
		"day": w.day, "reason": w.end_reason, "outcome": outcome, "town_saved": saved,
		"prediction_eligible": eligible, "prediction_spoiled": spoiled, "prediction": snapshot.duplicate(true),
		"demon_guesses": demon_guesses, "minion_guesses": m_guesses,
		"demon_identified": demon_correct, "minion_identified": minion_correct,
		"both_identified": demon_correct and minion_correct, "identified_but_lost": demon_correct and w.game_over and not saved,
		"good_initial": goods.size(), "good_surviving": survivors,
		"good_survival_fraction": float(survivors) / maxi(1, goods.size()),
		"executions_total": executions.size(), "executions_good": wrongful, "executions_evil": executions.size() - wrongful,
		"wrongful_execution_fraction": float(wrongful) / executions.size() if not executions.is_empty() else null,
		"wrongful_backed": backed_wrongful, "wrongful_opposed": opposed_wrongful, "wrongful_mixed": mixed_wrongful,
		"executions": executions}

static func aggregate(cases: Array) -> Dictionary:
	var complete: Array = cases.filter(func(c): return c.get("complete", false))
	var totals = {"cases": cases.size(), "complete": complete.size(), "incomplete": cases.size() - complete.size(),
		"town_saved": 0, "demon_identified": 0, "minion_identified": 0, "both_identified": 0, "identified_but_lost": 0,
		"prediction_eligible": 0, "prediction_spoiled": 0, "demon_recorded": 0,
		"executions_total": 0, "executions_good": 0, "executions_evil": 0,
		"wrongful_backed": 0, "wrongful_opposed": 0, "wrongful_mixed": 0, "good_surviving": 0, "saved_good_surviving": 0}
	for c in complete:
		for key in ["town_saved", "demon_identified", "minion_identified", "both_identified", "identified_but_lost", "prediction_eligible", "prediction_spoiled"]:
			if c[key]:
				totals[key] += 1
		if c["prediction_eligible"] and not c["demon_guesses"].is_empty():
			totals["demon_recorded"] += 1
		for key in ["executions_total", "executions_good", "executions_evil", "wrongful_backed", "wrongful_opposed", "wrongful_mixed", "good_surviving"]:
			totals[key] += c[key]
		if c["town_saved"]:
			totals["saved_good_surviving"] += c["good_surviving"]
	var hints = {}
	var nights = {"kills": 0, "blocked_warden": 0, "blocked_veteran": 0, "blocked_ward": 0, "warden_protects": 0, "warden_spotted": 0, "warden_killed": 0, "warden_cases": 0}
	for c in complete:
		var h: String = c.get("loss_hint", "")
		if h != "":
			hints[h] = hints.get(h, 0) + 1
		var ns: Dictionary = c.get("nights", {})
		for k in ["kills", "blocked_warden", "blocked_veteran", "blocked_ward", "warden_protects", "warden_spotted"]:
			nights[k] += ns.get(k, 0)
		if ns.get("warden_killed", false):
			nights["warden_killed"] += 1
		if ns.get("warden_in_play", false):
			nights["warden_cases"] += 1
	nights["warden_hit_rate"] = float(nights["blocked_warden"]) / nights["warden_protects"] if nights["warden_protects"] > 0 else null
	totals["loss_hints"] = hints
	totals["nights"] = nights
	totals["win_rate"] = float(totals["town_saved"]) / complete.size() if not complete.is_empty() else null
	totals["identification_rate"] = float(totals["demon_identified"]) / totals["prediction_eligible"] if totals["prediction_eligible"] > 0 else null
	totals["execution_wrongful_fraction"] = float(totals["executions_good"]) / totals["executions_total"] if totals["executions_total"] > 0 else null
	totals["saved_good_surviving_average"] = float(totals["saved_good_surviving"]) / totals["town_saved"] if totals["town_saved"] > 0 else null
	return totals
