## Post-case analysis only. Never consulted by NPCs or the player's bot policy.
extends RefCounted

static func named_guesses(guesses: Dictionary, role: String) -> Array:
	var ids: Array = []
	for id in guesses:
		if guesses[id].get("guess", "") == role:
			ids.append(id)
	ids.sort()
	return ids

static func summarize(w, snapshot: Dictionary, spoiled: bool) -> Dictionary:
	var guesses: Dictionary = snapshot.get("guesses", {})
	var demon_guesses = named_guesses(guesses, "demon")
	var minion_guesses = named_guesses(guesses, "poisoner")
	var eligible = not spoiled and not snapshot.is_empty()
	var demon_correct = eligible and demon_guesses == [w.demon_id]
	var minion_correct = eligible and minion_guesses == [w.minion_id]
	var goods = w.npcs.filter(func(n): return not n.is_evil())
	var survivors = w.living_good().size()
	var executions: Array = []
	var wrongful = 0
	var backed_wrongful = 0
	var opposed_wrongful = 0
	var mixed_wrongful = 0
	for ex in w.executions:
		var target = w.by_id[ex["id"]]
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
		executions.append(row)
		if not target.is_evil():
			wrongful += 1
			if stance == "backed":
				backed_wrongful += 1
			elif stance == "mixed":
				mixed_wrongful += 1
			else:
				opposed_wrongful += 1
	var saved: bool = w.game_over and w.winner == "good"
	var outcome = "incomplete"
	if w.game_over:
		outcome = "identified_and_saved" if saved and demon_correct else "saved_without_identification" if saved else "identified_but_lost" if demon_correct else "lost_without_identification"
	return {"schema_version": 1, "seed": w.seed_value, "complete": w.game_over, "winner": w.winner,
		"day": w.day, "reason": w.end_reason, "outcome": outcome, "town_saved": saved,
		"prediction_eligible": eligible, "prediction_spoiled": spoiled, "prediction": snapshot.duplicate(true),
		"demon_guesses": demon_guesses, "minion_guesses": minion_guesses,
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
	totals["win_rate"] = float(totals["town_saved"]) / complete.size() if not complete.is_empty() else null
	totals["identification_rate"] = float(totals["demon_identified"]) / totals["prediction_eligible"] if totals["prediction_eligible"] > 0 else null
	totals["execution_wrongful_fraction"] = float(totals["executions_good"]) / totals["executions_total"] if totals["executions_total"] > 0 else null
	totals["saved_good_surviving_average"] = float(totals["saved_good_surviving"]) / totals["town_saved"] if totals["town_saved"] > 0 else null
	return totals
