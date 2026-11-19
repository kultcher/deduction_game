## The three reading labels (Michael, Nov 18, via Seneschal): an honest mistake, a lie, and
## Delusional (about a person, not a reading). This suite pins the honest mistake: "misled"
## and "failed gift" ("impaired") are one call.
##   - Both names carry the same honest doubt, at the player's credibility, and come back
##     from the assessment as one mode.
##   - With no Poisoner on the script the call still doubts the reading, at the credibility
##     doubt alone, and points at no one.
##   - It counts in the track record as saying the reader is good.
##   - It's allowed only where a cause the script allows could have fooled that gift
##     (Michael, Nov 18): poison or Delusion reach any reading, a Red Herring only a Seer's,
##     Marked only a reading that points someone toward evil. With none, no Mistaken.
## And the lie: a "lying" call, with grounds that contradict the reading, raises its teller's
## suspicion (the Nov 18 retune; before, listeners' agreement never passed the gate).
##   godot --headless --path . --script res://tools/test_honest_mistake.gd
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


## The first seed from 1 whose 7-NPC case has a Poisoner on its script.
func _seed() -> int:
	for sd in range(1, 200):
		var g = Game.new()
		g.log_dir = "user://test_logs"
		g.new_case(sd, 7)
		if "poisoner" in g.w.case_script.minions and g.w.living_good().size() >= 5:
			return sd
	return -1


## A case that goods[2] is good, citing a good Archivist's night-0 reading that one of
## goods[2] and goods[3] is the Poisoner, with the reading called `mode` (or not called).
## `poisoner` false takes the Poisoner off the script; `causes` false takes every honest
## failure off it (the Poisoner, Delusional and Marked; an Archivist registers no Red Herring).
func _game(sd: int, mode: String, poisoner: bool = true, causes: bool = true) -> Dictionary:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 7)
	if not poisoner or not causes:
		g.w.case_script.minions = g.w.case_script.minions.filter(func(m): return m != "poisoner")
	if not causes:
		g.w.case_script.secrets = g.w.case_script.secrets.filter(func(m): return m not in ["delusional", "marked"])
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
	var refused: String = ""
	if mode != "":
		refused = model.add_modifier(node, mode)
	model.connect_cards(model.selected, premise)
	var filed: int = Live.file(g, model.compile(premise))
	return {"g": g, "goods": goods, "reader": reader, "filed": filed, "refused": refused}


## What listener goods[1] makes of the case at credibility `trust` in the player.
func _hear(made: Dictionary, trust: float) -> Dictionary:
	var g = made.g
	var listener = made.goods[1]
	listener.trust = trust
	listener.credibility = trust
	g._workshop_evaluations.erase(listener.id + ":good")
	g._evaluate_deduction(listener, g.board[made.filed - 1], 1.0, false)
	var plan: Dictionary = g._workshop_plans.get(listener.id + ":good", {})
	if plan.is_empty():
		return {}
	var honest: Dictionary = SourceDoubt.derive(plan, listener.ledger, {}).honest
	var assessed: Dictionary = RC.assess(plan.prepared.view, plan.prepared.get("case", {}), plan.prepared.listener, plan.prepared.view.get("cards", []))
	return {"doubt": float(honest.get("%s:0" % made.reader.id, 0.0)), "c": float(plan.prepared.listener.get("player_credibility", -1.0)),
		"results": assessed.get("results", []), "listener": listener}


func _card(g, source, role: String, day: int, data: Dictionary) -> String:
	var text: String = "%s's %s reading, day %d: %s" % [source.name, role, day, JSON.stringify(data)]
	g.add_card({"kind": "info", "source": source.id, "role": role, "day": day, "phase": 3 if role == "archivist" else 0, "data": data, "text": text})
	return text


func _node(model, view: Dictionary, text: String) -> String:
	for id in model.nodes:
		if model.nodes[id].kind == "evidence" and Solver.card_by_id(view, model.nodes[id].card).get("text", "") == text:
			return id
	return ""


## A case that goods[2] is good citing the Dowser; with `lie`, calling the Archivist's reading
## a lie on the Dowser's grounds, otherwise citing the Archivist plainly.
func _file_lie(g, goods: Array, arch: String, dowse: String, lie: bool) -> int:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(goods[2].id, "good", Vector2(400, 40))
	model.connect_cards(_node(model, view, dowse), premise)
	if lie:
		model.add_modifier(_node(model, view, arch), "lying")
		var challenge: String = model.selected
		model.connect_cards(_node(model, view, dowse), challenge)
		model.connect_cards(challenge, premise)
	else:
		model.connect_cards(_node(model, view, arch), premise)
	return Live.file(g, model.compile(premise))


## A good Archivist names goods[2] and goods[3] as possibly the Poisoner, and a Dowser clears
## them both. Listener goods[1] hears a plain case, then one calling the Archivist a liar.
func _lie(sd: int) -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 7)
	var goods: Array = g.w.living_good()
	g.w.day = 2
	var arch: String = _card(g, goods[0], "archivist", 0, {"pair": [goods[2].id, goods[3].id], "role": "poisoner"})
	var dowse: String = _card(g, goods[4], "dowser", 1, {"group": [goods[2].id, goods[3].id], "count": 0})
	var listener = goods[1]
	listener.trust = 0.9
	listener.credibility = 0.9
	var plain: int = _file_lie(g, goods, arch, dowse, false)
	check(plain > 0, "the plain case can be filed (%s)" % g.last_error)
	if plain <= 0:
		return
	g._evaluate_deduction(listener, g.board[plain - 1], 1.0, false)
	var before: float = float(listener.suspicion.get(goods[0].id, 0.0))
	var called: int = _file_lie(g, goods, arch, dowse, true)
	check(called > 0, "a case calling the reading a lie can be filed (%s)" % g.last_error)
	if called <= 0:
		return
	g._evaluate_deduction(listener, g.board[called - 1], 1.0, false)
	var after: float = float(listener.suspicion.get(goods[0].id, 0.0))
	print("lie call: the reader's suspicion %.3f -> %.3f" % [before, after])
	check(after > before + 0.01, "a lie call against a contradicted reading raises its teller's suspicion (%.3f -> %.3f)" % [before, after])


func _init() -> void:
	Connections.enabled = true
	SourceDoubt.delusional_self_doubt = false  # the listener's own self-doubt, off to keep the numbers plain
	var sd: int = _seed()
	check(sd > 0, "a seed with a Poisoner on the script (%d)" % sd)
	if sd <= 0:
		_finish()
		return
	# 1. The two names are one call.
	var by_name: Dictionary = {}
	for mode in ["misled", "impaired"]:
		var made: Dictionary = _game(sd, mode)
		check(made.filed > 0, "a case calling the reading '%s' can be filed (%s)" % [mode, made.g.last_error])
		if made.filed <= 0:
			_finish()
			return
		by_name[mode] = _hear(made, 0.7)
		by_name[mode]["made"] = made
	var m: Dictionary = by_name.misled
	var i: Dictionary = by_name.impaired
	print("misled doubt %.3f, failed-gift doubt %.3f, credibility %.2f" % [m.doubt, i.doubt, m.c])
	check(m.doubt > 0.0 and is_equal_approx(m.doubt, i.doubt), "'misled' carries the same honest doubt as a failed gift (%.3f, %.3f)" % [m.doubt, i.doubt])
	check(m.doubt >= SourceDoubt.call_doubt(m.c) - 1e-9, "the doubt is at least the call taken at the player's credibility (%.3f)" % SourceDoubt.call_doubt(m.c))
	check(RC.canonical("misled") == RC.HONEST and RC.canonical("impaired") == RC.HONEST and RC.canonical("lying") == "lying", "both names map to one mode, and a lie stays a lie")
	var Shared = preload("res://workshop/shared_ledger.gd")
	check(not Shared.challenges_conflict({"mode": "misled"}, {"mode": "impaired"}) and Shared.challenges_conflict({"mode": "misled"}, {"mode": "lying"}), "stored 'misled' and 'impaired' calls on one reading don't conflict; a lie still does (Codex on #296)")
	# 2. Both record "the reader is good" in the track record.
	for mode in ["misled", "impaired"]:
		var made2: Dictionary = by_name[mode].made
		var lis = made2.goods[1]  # heard the case in _hear
		var entry: Dictionary = lis.claim_record.get(made2.reader.id, {})
		print("%s: track record on the reader %s" % [mode, entry])
		check(str(entry.get("type", "")) == "good", "an honest-mistake call ('%s') records that the reader is good" % mode)
	# 3. No Poisoner on the script: the call still doubts the reading, at the credibility
	#    doubt alone, and no one is pointed at.
	var nopo: Dictionary = _game(sd, "misled", false)
	check(nopo.filed > 0, "with no Poisoner, the call can still be filed (%s)" % nopo.g.last_error)
	if nopo.filed > 0:
		var h: Dictionary = _hear(nopo, 0.9)
		check(is_equal_approx(h.doubt, SourceDoubt.call_doubt(0.9)), "with no Poisoner the call carries the credibility doubt alone (%.3f against %.3f)" % [h.doubt, SourceDoubt.call_doubt(0.9)])
		var cands: int = 0
		for r in h.results:
			cands += r.get("candidates", {}).size()
		check(not h.results.is_empty() and cands == 0, "with no Poisoner no one is pointed at (%d results, %d candidates)" % [h.results.size(), cands])
	# 4. The gate: which causes reach which readings, and no Mistaken with none.
	check(RC.script_honest_causes(["poisoner", "scion"], ["marked", "delusional"], ["seer", "dowser"]) == ["poison", "delusion", "red_herring", "marked"], "a script's causes come in order")
	check(RC.script_honest_causes(["scion"], ["lovers"], ["dowser"]).is_empty(), "a script with no Poisoner, Delusional, Marked or Seer allows none")
	var seer_yes: Dictionary = {"kind": "report", "role": "seer", "data": {"pair": ["a", "b"], "yes": true}}
	var seer_no: Dictionary = {"kind": "report", "role": "seer", "data": {"pair": ["a", "b"], "yes": false}}
	var dowse_some: Dictionary = {"kind": "report", "role": "dowser", "data": {"group": ["a", "b"], "count": 1}}
	var dowse_none: Dictionary = {"kind": "report", "role": "dowser", "data": {"group": ["a", "b"], "count": 0}}
	check(RC.cause_reaches("red_herring", seer_no) and not RC.cause_reaches("red_herring", dowse_some), "a Red Herring reaches a Seer's reading and no other gift")
	check(RC.cause_reaches("marked", seer_yes) and RC.cause_reaches("marked", dowse_some) and not RC.cause_reaches("marked", dowse_none) and not RC.cause_reaches("marked", seer_no), "Marked reaches only a reading that points someone toward evil")
	check(RC.cause_reaches("poison", dowse_none) and RC.cause_reaches("delusion", seer_no), "poison and Delusion reach any reading")
	var bare: Dictionary = {"script_minions": ["scion"], "world_options": {"modifiers": ["lovers"]}}
	check(not RC.honest_allowed(bare, dowse_some) and RC.honest_allowed(bare, seer_no), "with nothing on the script, no Mistaken, except a Seer's (its Red Herring)")
	var none: Dictionary = _game(sd, "misled", true, false)
	var nv: Dictionary = Live.view(none.g)
	print("no causes: refused '%s', minions %s, modifiers %s" % [none.refused, nv.get("script_minions"), nv.get("world_options")])
	check(none.refused != "", "with no cause on the script, the canvas refuses a Mistaken call on an Archivist reading")
	# 5. The lie.
	_lie(sd)
	_finish()


func _finish() -> void:
	print("Honest mistake: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
