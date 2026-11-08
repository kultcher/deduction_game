## Recency (sim/recency.gd, docs/premises_plan.md "Recency as built"): cards fade from a
## bounded mind's attention with age (faster at low Insight), the town's topic of the day
## draws attention, presenting a card brings it back to mind, and that restores attention,
## never weight. Also the headline blend's strength scaling (folded in with recency).
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const Recency = preload("res://sim/recency.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_fade()
	_topic()
	_ranking()
	_recall()
	print("Recency: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _fade() -> void:
	var card = {"id": "c1", "kind": "report", "role": "seer", "source": "a", "learned_at": {"day": 1}}
	var dull: float = Recency.salience(card, [], {"today": 5, "topic": {}, "card_refresh": {}}, 0.0)
	var sharp: float = Recency.salience(card, [], {"today": 5, "topic": {}, "card_refresh": {}}, 1.0)
	check(is_equal_approx(dull, -4 * Tuning.Workshop.RECENCY_DECAY_LOW) and is_equal_approx(sharp, -4 * Tuning.Workshop.RECENCY_DECAY_HIGH), "a four-day-old card fades %.1f at Insight 0 and %.1f at Insight 1" % [dull, sharp])
	var ancient: float = Recency.salience(card, [], {"today": 30, "topic": {}, "card_refresh": {}}, 0.0)
	check(is_equal_approx(ancient, -Tuning.Workshop.RECENCY_AGE_CAP), "the fade is capped")
	var recalled: float = Recency.salience(card, [], {"today": 5, "topic": {}, "card_refresh": {"c1": 5}}, 0.0)
	check(is_equal_approx(recalled, 0.0), "bringing a card up again resets its age")
	check(is_equal_approx(Recency.salience(card, [], {}, 0.0), 0.0), "no recency snapshot, no change (fixtures and tools)")

func _topic() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	var w = g.w
	var p: Array = w.npcs
	w.public_log.append({"day": w.day, "kind": "nomination", "subjects": [p[1].id], "by": p[2].id})
	w.public_log.append({"day": w.day, "kind": "accusation", "subjects": [p[3].id], "by": p[2].id})
	w.defences[p[4].id] = {"target": p[3].id, "day": w.day}
	w.meeting_arguments.append({"day": w.day, "target": p[5].id})
	var today: Dictionary = Recency.topic(w)
	check(is_equal_approx(today.get(p[1].id, 0.0), 1.0), "today's nominee is the topic (1.0)")
	check(is_equal_approx(today.get(p[3].id, 0.0), 0.9), "accused and defended adds up (0.6 + 0.3)")
	check(is_equal_approx(today.get(p[5].id, 0.0), 0.6), "a case the player argued at the meeting counts like an accusation")
	w.day += 1
	var tomorrow: Dictionary = Recency.topic(w)
	check(is_equal_approx(tomorrow.get(p[1].id, 0.0), 0.5), "a day later it has halved")
	# A busy day saturates its subject for that day only: nomination plus accusation is 1.0
	# today and 0.5 tomorrow, not 0.8 (the excess over the cap is gone, Codex on #96).
	var g2 = Game.new()
	g2.detailed_logging = false
	g2.new_case(692, 7)
	var w2 = g2.w
	var q: Array = w2.npcs
	w2.public_log.append({"day": w2.day, "kind": "nomination", "subjects": [q[1].id], "by": q[2].id})
	w2.public_log.append({"day": w2.day, "kind": "accusation", "subjects": [q[1].id], "by": q[3].id})
	check(is_equal_approx(Recency.topic(w2).get(q[1].id, 0.0), 1.0), "nomination plus accusation caps at 1.0")
	w2.day += 1
	check(is_equal_approx(Recency.topic(w2).get(q[1].id, 0.0), 0.5), "and halves from the cap the next day (%.2f)" % Recency.topic(w2).get(q[1].id, 0.0))
	w2.public_log.append({"day": w2.day, "kind": "accusation", "subjects": [q[1].id], "by": q[4].id})
	check(is_equal_approx(Recency.topic(w2).get(q[1].id, 0.0), 1.0), "a fresh accusation on a half-faded topic tops it back up to the cap")
	w2.day += 2
	check(is_equal_approx(Recency.topic(w2).get(q[1].id, 0.0), 0.25), "and two quiet days later it is a quarter")
	var card = {"id": "c2", "kind": "report", "role": "dowser", "source": p[6].id, "learned_at": {"day": w.day}}
	var boost: float = Recency.salience(card, [p[1].id], {"today": w.day, "topic": tomorrow, "card_refresh": {}}, 0.5)
	check(is_equal_approx(boost, Tuning.Workshop.RECENCY_TOPIC_WEIGHT * 0.5), "a card naming yesterday's nominee gains topic salience")

## A low-Insight mind ranks a fresh card about the topic above an old gift reading.
func _ranking() -> void:
	var listener = {"npc_trust": {}, "insight": 0.0, "recency": {"today": 5, "topic": {"t": 1.0}, "card_refresh": {}}}
	var old_gift = {"id": "old", "kind": "report", "role": "seer", "source": "s", "data": {"pair": ["x", "y"], "yes": true}, "learned_at": {"day": 1}}
	var fresh = {"id": "fresh", "kind": "sighting", "source": "s2", "subject": "t", "subjects": ["t"], "learned_at": {"day": 5}}
	var a: float = Reasoner._salience(old_gift, {}, listener, true)
	var b: float = Reasoner._salience(fresh, {}, listener, true)
	check(b > a, "for a low-Insight mind, today's sighting of the topic (%.2f) outranks a four-day-old Seer reading (%.2f)" % [b, a])
	listener.insight = 1.0
	listener.recency.topic = {}
	check(Reasoner._salience(old_gift, {}, listener, true) > Reasoner._salience(fresh, {}, listener, true), "a sharp mind with no topic keeps the gift reading ahead")

## Re-presenting an old card restores attention, never weight: a bounded listener moves back
## toward their full-attention belief, never past it, and repeating it changes nothing more.
func _recall() -> void:
	var results: Dictionary = {}
	for mode in ["bounded", "full"]:
		var g = _setup()
		var n = g.w.npcs[0]
		n.workshop_state["reasoning_mode"] = mode
		var p: Array = g.w.npcs
		var old = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true}, 1)
		var first = g.file_deduction({"type": "evil", "a": p[3].id}, [old])
		g._evaluate_deduction(n, g.board[first - 1], 1.0, false)
		# Day 4: two more readings; day 5: two more again. A low-Insight budget (4 cards)
		# leaves two slots beside the day-5 cards, and the day-4 pair is fresher than the
		# day-1 Seer reading.
		g.w.day = 4
		var mid: Array = [_read(g, p[5], "dowser", 4, {"group": [p[1].id, p[2].id], "count": 1}, 4), _read(g, p[6], "dowser", 4, {"group": [p[1].id, p[5].id], "count": 0}, 4)]
		var second = g.file_deduction({"type": "evil", "a": p[1].id}, mid)
		g._evaluate_deduction(n, g.board[second - 1], 1.0, false)
		g.w.day = 5
		var late: Array = [_read(g, p[5], "dowser", 5, {"group": [p[2].id, p[6].id], "count": 1}, 5), _read(g, p[6], "dowser", 5, {"group": [p[2].id, p[4].id], "count": 1}, 5)]
		var third = g.file_deduction({"type": "evil", "a": p[2].id}, late)
		g._evaluate_deduction(n, g.board[third - 1], 1.0, false)
		Mind.refresh_beliefs(g.w, n, " (day 5)")
		var drifted: float = n.suspicion[p[3].id]
		var again = g.file_deduction({"type": "evil", "a": p[3].id}, [old])
		g._evaluate_deduction(n, g.board[again - 1], 1.0, false)
		var recalled: float = n.suspicion[p[3].id]
		var repeat = g.file_deduction({"type": "evil", "a": p[3].id}, [old])
		g._evaluate_deduction(n, g.board[repeat - 1], 1.0, false)
		results[mode] = {"drifted": drifted, "recalled": recalled, "repeated": n.suspicion[p[3].id], "refresh": n.workshop_state.get("card_refresh", {}).duplicate()}
	var b: Dictionary = results.bounded
	var f: Dictionary = results.full
	print("recall: bounded drifted %.4f -> recalled %.4f -> repeated %.4f; full attention %.4f -> %.4f" % [b.drifted, b.recalled, b.repeated, f.drifted, f.recalled])
	check(absf(b.drifted - f.drifted) > 0.005, "by day 5 the bounded listener has drifted from their full-attention belief")
	check(absf(b.recalled - f.recalled) < absf(b.drifted - f.drifted), "re-presenting moves a bounded listener back toward their full-attention belief")
	check(absf(b.recalled - b.drifted) <= absf(f.recalled - b.drifted) + 0.02, "and not past it")
	check(absf(b.repeated - b.recalled) < 0.005, "repeating it at once changes nothing more")
	check(not b.refresh.is_empty(), "the presentation recorded the card as brought back to mind")

func _setup():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.trust = 0.7
		p.credibility = 0.7
		for id in p.suspicion:
			p.suspicion[id] = 0.25
			p.npc_trust[id] = 1.0
	var n = g.w.npcs[0]
	n.alignment = "good"
	n.role = "warden"
	n.traits.insight = 0.0
	n.traits.confidence = 0.5
	g.w.day = 1
	return g

func _read(g, source, role: String, day: int, data: Dictionary, _learned: int) -> int:
	return g.add_card({"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 3 if role == "seer" else 0, "data": data,
		"text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
