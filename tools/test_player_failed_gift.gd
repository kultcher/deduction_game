## The player's "failed gift" call as testimony ("Poisoned, not lying", option C, Michael,
## Nov 18; docs/design/poisoned_not_lying.md): a "failed gift" challenge in the player's
## presented case is the player's word that the reading was poisoned. Each listener weighs it
## as one witness as accurate as its trust in the player, against the chance that reader was
## poisoned that night, as honest doubt (SourceDoubt.derive).
##   godot --headless --path . --script res://tools/test_player_failed_gift.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const RC = preload("res://workshop/reading_challenges.gd")
const Connections = preload("res://workshop/connections.gd")

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
	g.add_card({"kind": "info", "source": reader.id, "role": "archivist", "day": 0, "phase": 3, "data": {"pair": [goods[2].id, goods[3].id], "role": "poisoner"}, "text": text})
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
	g._evaluate_deduction(listener, g.board[made.filed - 1], 1.0, false)
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
	Connections.enabled = true
	# Seed 692's script carries Delusional: its self-doubt is the listener's own, not the
	# reader's, so it doesn't touch the reader's doubt here; off to keep the numbers plain.
	SourceDoubt.delusional_self_doubt = false
	var call: Dictionary = _game(true)
	check(call.filed > 0, "a case calling the reading a failed gift can be filed (%s)" % call.g.last_error)
	if call.filed <= 0:
		_finish()
		return
	# 1. The doubt is the one-witness weighing, at the listener's trust in the player.
	var heard: Dictionary = _hear(call, 1, 0.7)
	var want: float = SourceDoubt.witness_doubt(heard.prior, heard.c)
	print("trust 0.70: poison chance %.3f, credibility %.2f, doubt %.3f (want %.3f)" % [heard.prior, heard.c, heard.doubt, want])
	check(heard.prior > 0.0 and absf(heard.doubt - want) < 1e-9 and heard.doubt > heard.prior, "the call is weighed as one witness at the listener's trust in the player, above the poison chance alone")
	# 2. Even trust: the call makes the listener weigh poison at its plain chance, which it
	#    otherwise doesn't apply to another's reading; more trust raises it further.
	var even: Dictionary = _hear(call, 1, 0.5)
	check(absf(even.doubt - even.prior) < 1e-9, "at even trust in the player the call weighs poison at its plain chance (%.3f)" % even.doubt)
	var high: Dictionary = _hear(call, 1, 0.9)
	check(high.doubt > heard.doubt and heard.doubt > even.doubt, "more trust in the player, more doubt (%.3f, %.3f, %.3f)" % [even.doubt, heard.doubt, high.doubt])
	# 3. The switch off: the call doesn't reach honest doubt.
	SourceDoubt.player_failed_gift = false
	var off: Dictionary = _hear(call, 1, 0.7)
	SourceDoubt.player_failed_gift = true
	check(off.doubt == 0.0, "with the switch off the call doesn't reach honest doubt (%.3f)" % off.doubt)
	# 4. No Poisoner on the script: the call carries nothing (the "failed gift" cause is zero).
	var g4 = call.g
	var mins: Array = g4.w.case_script.minions.duplicate()
	g4.w.case_script.minions = mins.filter(func(m): return m != "poisoner")
	var nopo: Dictionary = _hear(call, 1, 0.9)
	g4.w.case_script.minions = mins
	check(nopo.doubt == 0.0, "with no Poisoner on the script the call carries nothing (%.3f)" % nopo.doubt)
	# 5. How far one call moves a listener (Michael, Nov 18: report it at typical and high
	#    trust in the player, in game terms): the reader's chance of being evil with the call
	#    weighed, against the same case with it left out of honest doubt.
	#    Each from a fresh game, so neither hearing follows the other.
	for trust in [0.5, 0.7, 0.9]:
		var with_call: Dictionary = _hear(_game(true), 1, trust)
		SourceDoubt.player_failed_gift = false
		var without: Dictionary = _hear(_game(true), 1, trust)
		SourceDoubt.player_failed_gift = true
		print("MEASURE trust %.1f: doubt %.3f; reader evil %.3f with the call weighed, %.3f without" % [trust, with_call.doubt, with_call.evil, without.evil])
	_finish()


func _finish() -> void:
	print("Player failed gift: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
