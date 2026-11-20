## The player's "failed gift" call as testimony ("Poisoned, not lying", option C, Michael,
## Nov 18; docs/design/poisoned_not_lying.md): a "failed gift" challenge in the player's
## presented case is the player's word that the reading was poisoned. Each listener takes it at
## its credibility in the player (SourceDoubt.call_doubt: FAILED_GIFT_DOUBT_LOW at the lowest
## credibility to FAILED_GIFT_DOUBT_HIGH at the highest, Michael, Nov 18), or as one witness
## against the chance that reader was poisoned that night where that is more, as honest doubt
## (SourceDoubt.derive). With no Poisoner on the script, the call still carries the
## credibility doubt, with no poison chance to weigh on top (#296's one honest-mistake label).
##   godot --headless --path . --script res://tools/test_player_failed_gift.gd
extends SceneTree

const GamePresentation = preload("res://game/game_presentation.gd")
const GameBoard = preload("res://game/game_board.gd")
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const RC = preload("res://workshop/reading_challenges.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


## A game on seed 692 (7 NPCs, a Poisoner on the script) where a good Archivist's night-0
## reading names two good people as "one of them is the Poisoner", and the player files a case
## that the first is good, calling the reading a failed gift (or not).
func _game(failed_gift: bool) -> Dictionary:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(692, 7)
	var goods: Array = g.w.living_good()
	var reader = goods[0]
	g.w.day = 2
	var text: String = "%s's Archivist reading: one of %s and %s is the Poisoner" % [reader.name, goods[2].name, goods[3].name]
	GameBoard.add_card(g, {"kind": "info", "source": reader.id, "role": "archivist", "day": 0, "phase": 3, "data": {"pair": [goods[2].id, goods[3].id], "role": "poisoner"}, "text": text})
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var node: String = ""
	for id in model.nodes:
		if model.nodes[id].kind == "evidence" and Solver.card_by_id(view, model.nodes[id].card).get("text", "") == text:
			node = id
	var premise: String = model.add_premise(goods[2].id, "good", Vector2(400, 40))
	if failed_gift:
		model.add_modifier(node, "impaired")
	model.connect_cards(model.selected, premise)
	var filed: int = Live.file(g, model.compile(premise))
	return {"g": g, "goods": goods, "reader": reader, "filed": filed}


## A listener's honest doubt of the reader's night-0 reading after hearing the case, its
## inputs, and its chance of the reader being evil, at trust `trust` in the player.
func _hear(made: Dictionary, listener_index: int, trust: float) -> Dictionary:
	var g = made.g
	var listener = made.goods[listener_index]
	listener.trust = trust
	listener.credibility = trust
	g._workshop_evaluations.erase(listener.id + ":good")
	GamePresentation._evaluate_deduction(g, listener, g.board[made.filed - 1], 1.0, false)
	var plan: Dictionary = g._workshop_plans.get(listener.id + ":good", {})
	if plan.is_empty():
		return {}
	var honest: Dictionary = SourceDoubt.derive(plan, listener.ledger, {}).honest
	var reader_id: String = made.reader.id
	var prior: float = RC.poison_chance(plan.prepared.view, plan.prepared.listener, 0, reader_id)
	var c: float = float(plan.prepared.listener.get("player_credibility", -1.0))
	var eff: Dictionary = g._workshop_evaluations.get(listener.id + ":good", {}).get("proposal", {}).get("effects", {})
	return {"doubt": float(honest.get("%s:0" % reader_id, 0.0)), "prior": prior, "c": c,
		"evil": float(eff.get(reader_id, {}).get("posterior", -1.0))}


func _init() -> void:
	# Seed 692's script carries Delusional: its self-doubt is the listener's own, not the
	# reader's, so it doesn't touch the reader's doubt here; off to keep the numbers plain.
	SourceDoubt.delusional_self_doubt = false
	var call: Dictionary = _game(true)
	check(call.filed > 0, "a case calling the reading a failed gift can be filed (%s)" % call.g.last_error)
	if call.filed <= 0:
		_finish()
		return
	# 1. The doubt is the call taken at the listener's credibility in the player, or the
	#    one-witness weighing where that is more (here the poison chance is small, so the line).
	var heard: Dictionary = _hear(call, 1, 0.7)
	var want: float = maxf(SourceDoubt.call_doubt(heard.c), SourceDoubt.witness_doubt(heard.prior, heard.c))
	print("trust 0.70: poison chance %.3f, credibility %.2f, doubt %.3f (want %.3f)" % [heard.prior, heard.c, heard.doubt, want])
	check(heard.prior > 0.0 and absf(heard.doubt - want) < 1e-9 and heard.doubt > SourceDoubt.witness_doubt(heard.prior, heard.c), "the call is taken at the listener's credibility in the player, above the one-witness weighing")
	# 2. The line's ends and middle (Michael, Nov 18): FAILED_GIFT_DOUBT_LOW at the lowest
	#    credibility, half at the starting one, FAILED_GIFT_DOUBT_HIGH at the highest.
	var even: Dictionary = _hear(call, 1, 0.5)
	check(absf(even.doubt - 0.5) < 1e-9, "at the starting credibility in the player the call is a doubt of a half (%.3f)" % even.doubt)
	check(absf(SourceDoubt.call_doubt(0.1) - 0.2) < 1e-9 and absf(SourceDoubt.call_doubt(0.9) - 0.8) < 1e-9 and absf(SourceDoubt.call_doubt(0.0) - 0.2) < 1e-9, "the line runs 0.2 at the lowest credibility to 0.8 at the highest, clamped outside")
	var high: Dictionary = _hear(call, 1, 0.9)
	check(high.doubt > heard.doubt and heard.doubt > even.doubt, "more trust in the player, more doubt (%.3f, %.3f, %.3f)" % [even.doubt, heard.doubt, high.doubt])
	# Where the one-witness weighing is more (a likely poisoning, a trusted player), it wins.
	check(SourceDoubt.witness_doubt(0.6, 0.9) > SourceDoubt.call_doubt(0.9), "a likely poisoning and a trusted player give more than the line (%.3f against %.3f)" % [SourceDoubt.witness_doubt(0.6, 0.9), SourceDoubt.call_doubt(0.9)])
	# 3. The switch off: the call doesn't reach honest doubt.
	SourceDoubt.player_failed_gift = false
	var off: Dictionary = _hear(call, 1, 0.7)
	SourceDoubt.player_failed_gift = true
	check(off.doubt == 0.0, "with the switch off the call doesn't reach honest doubt (%.3f)" % off.doubt)
	# 4. No Poisoner on the script: the one honest-mistake call (Nov 18) still carries the
	# credibility doubt, with no poison chance to weigh on top.
	var g4 = call.g
	var mins: Array = g4.w.case_script.minions.duplicate()
	g4.w.case_script.minions = mins.filter(func(m): return m != "poisoner")
	var nopo: Dictionary = _hear(call, 1, 0.9)
	g4.w.case_script.minions = mins
	check(is_equal_approx(nopo.doubt, SourceDoubt.call_doubt(0.9)), "with no Poisoner on the script the call carries the credibility doubt alone (%.3f against %.3f)" % [nopo.doubt, SourceDoubt.call_doubt(0.9)])
	# 4b. Codex on #270: the challenged card as a Registrar's night-0 register (never poisoned)
	#     carries nothing; as a relayed reading, the call lands on whichever side it names.
	var call5: Dictionary = _game(true)
	var g5 = call5.g
	var lis = call5.goods[1]
	_hear(call5, 1, 0.9)
	var plan5: Dictionary = g5._workshop_plans.get(lis.id + ":good", {})
	var rid: String = ""
	for cs in plan5.prepared.listener.get("connections", {}).get("cases", []):
		for id in cs.get("challenges", {}):
			rid = str(id)
	var medium_id: String = str(call5.goods[4].id)
	var doubts: Dictionary = {}
	for variant in ["registrar", "original", "transmission"]:
		var p5: Dictionary = plan5.duplicate(true)
		for c in p5.prepared.view.cards:
			if str(c.get("id", "")) != rid:
				continue
			if variant == "registrar":
				c["role"] = "registrar"
			else:
				c["relay_source"] = medium_id
				c["relay_observed_at"] = {"day": 1, "phase": "night"}
		for cs in p5.prepared.listener.connections.cases:
			if cs.get("challenges", {}).has(rid) and variant != "registrar":
				cs.challenges[rid]["attribution"] = variant
		doubts[variant] = SourceDoubt.derive(p5, lis.ledger, {}).honest
	var reader_key: String = "%s:0" % call5.reader.id
	var medium_key: String = "%s:1" % medium_id
	check(float(SourceDoubt.derive(plan5, lis.ledger, {}).honest.get(reader_key, 0.0)) > 0.0, "the unchanged call does carry a doubt (so the checks below test something)")
	var reg_d: float = float(doubts.registrar.get(reader_key, 0.0))
	var unchanged_d: float = float(SourceDoubt.derive(plan5, lis.ledger, {}).honest.get(reader_key, 0.0))
	check(reg_d > 0.0 and reg_d <= unchanged_d + 1e-9, "a call on a Registrar's night-0 register carries the call's doubt but no poison chance (%.3f, at most %.3f)" % [reg_d, unchanged_d])
	check(float(doubts.original.get(reader_key, 0.0)) > 0.0 and float(doubts.original.get(medium_key, 0.0)) == 0.0, "a call on a relayed reading's original doubts the dead reader, not the Medium")
	check(float(doubts.transmission.get(medium_key, 0.0)) > 0.0 and float(doubts.transmission.get(reader_key, 0.0)) == 0.0, "a call on its transmission doubts the Medium's night, not the reader")
	# 4c. A Gravedigger verdict called poisoned proves less (Codex on #270): the doubt goes in
	#     before the Gravedigger proofs, so a trusted teller's "X was the Poisoner" puts less
	#     doubt on X's own word than the same verdict uncalled.
	var p6: Dictionary = plan5.duplicate(true)
	var hanged: String = str(call5.goods[3].id)
	var digger: String = str(call5.goods[4].id)
	for c in p6.prepared.view.cards:
		if str(c.get("id", "")) == rid:
			c["source"] = digger
			c["role"] = "gravedigger"
			c["data"] = {"executed": hanged, "role": "poisoner"}
			c["night"] = 1
			c["observed_at"] = {"day": 1, "phase": "night"}
	# The hanging on the record, so the verdict is possible (day 1's execution, dead from night 1).
	p6.prepared.view["timeline"] = p6.prepared.view.get("timeline", {}).duplicate(true)
	if not p6.prepared.view.timeline.has("executions"):
		p6.prepared.view.timeline["executions"] = {}
	p6.prepared.view.timeline.executions["1"] = [hanged]
	if not p6.prepared.view.timeline.has("deaths"):
		p6.prepared.view.timeline["deaths"] = {}
	p6.prepared.view.timeline.deaths[hanged] = 1
	p6.prepared.listener["npc_trust"] = p6.prepared.listener.get("npc_trust", {}).duplicate()
	p6.prepared.listener.npc_trust[digger] = 1.0
	p6.prepared.listener["player_credibility"] = 0.99
	var called: float = float(SourceDoubt.derive(p6, lis.ledger, {}).pre_eval.get(hanged + ":*", 0.0))
	SourceDoubt.player_failed_gift = false
	var uncalled: float = float(SourceDoubt.derive(p6, lis.ledger, {}).pre_eval.get(hanged + ":*", 0.0))
	SourceDoubt.player_failed_gift = true
	print("the verdict's doubt on %s's word: %.3f called poisoned, %.3f uncalled" % [hanged, called, uncalled])
	check(uncalled > 0.0 and called < uncalled, "a Gravedigger verdict called poisoned puts less doubt on its subject than the same verdict uncalled")
	# 5. How far one call moves a listener (Michael, Nov 18: report it at typical and high
	#    trust in the player, in game terms): the reader's chance of being evil with the call
	#    weighed, against the same case with it left out of honest doubt.
	#    Each from a fresh game, so neither hearing follows the other.
	for trust in [0.1, 0.5, 0.9]:
		var with_call: Dictionary = _hear(_game(true), 1, trust)
		SourceDoubt.player_failed_gift = false
		var without: Dictionary = _hear(_game(true), 1, trust)
		SourceDoubt.player_failed_gift = true
		print("MEASURE trust %.1f: doubt %.3f; reader evil %.3f with the call weighed, %.3f without" % [trust, with_call.doubt, with_call.evil, without.evil])
	_finish()


func _finish() -> void:
	print("Player failed gift: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
