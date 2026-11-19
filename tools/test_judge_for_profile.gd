## Connections.judge_for_profile (game/profile_judge.gd; Michael, Nov 19, juror fix (a)): how
## an average listener, with nothing first-hand, weighs a case put to the town, through the
## full listener path. Constructed on seed 692's 7-NPC deal, as test_town_note is.
##   godot --headless --path . --script res://tools/test_judge_for_profile.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Connections = preload("res://workshop/connections.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Caches = preload("res://workshop/caches.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")

var checks: int = 0
var fails: int = 0
var _texts: Dictionary = {}


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var dowser: int = _read(g, p[5], "dowser", 1, {"group": [p[4].id], "count": 0})
	var both: Dictionary = _value(g, "evil", p[3].id, [seer, dowser])
	var before_state: String = _state(g)
	# 1. Cards the town hasn't heard: heard only through the case, at the player's credibility.
	var fresh: Dictionary = Connections.judge_for_profile(g, both)
	print("unheard cards: %s" % _show(fresh))
	check(fresh.get("ready", false) and float(fresh.get("after", -1.0)) > float(fresh.get("before", 0.0)), "a case pointing at %s raises them for the average listener" % p[3].id)
	if not fresh.get("ready", false):
		print("Judge for profile: %d checks, %d failures" % [checks, fails + 1])
		quit(1)
		return
	var trusted: Dictionary = Connections.judge_for_profile(g, both, {"credibility": 0.9})
	var doubted: Dictionary = Connections.judge_for_profile(g, both, {"credibility": 0.1})
	print("credibility 0.9 / 0.5 / 0.1: after %.3f / %.3f / %.3f (before %.3f)" % [float(trusted.get("after", -1.0)), float(fresh.after), float(doubted.get("after", -1.0)), float(fresh.before)])
	check(float(fresh.before) >= 0.0 and absf(float(trusted.before) - float(fresh.before)) < 1e-9, "before the case, the listener holds only the public record: the same prior whatever its credibility")
	check(float(trusted.after) > float(doubted.after), "cards heard only through the case count for more the more the listener credits the player")
	# 2. Cards the town has heard from their tellers: they move the listener before the case,
	#    by its trust in the tellers.
	g.public_citations[seer] = true
	g.public_citations[dowser] = true
	var heard: Dictionary = Connections.judge_for_profile(g, both)
	var low_trust: Dictionary = Connections.judge_for_profile(g, both, {"npc_trust": 0.2})
	var high_trust: Dictionary = Connections.judge_for_profile(g, both, {"npc_trust": 0.9})
	print("public cards, trust 0.9 / 0.5 / 0.2: before %.3f / %.3f / %.3f; the case's shift at 0.5 %.4f" % [float(high_trust.get("before", -1.0)), float(heard.get("before", -1.0)), float(low_trust.get("before", -1.0)), float(heard.get("shift", 0.0))])
	check(float(high_trust.before) > float(heard.before) and float(heard.before) > float(low_trust.before) and float(heard.before) > float(fresh.before), "public cards move the listener before the case, more the more it trusts their tellers")
	check(absf(float(heard.get("shift", 0.0))) < absf(float(fresh.get("shift", 0.0))), "a case of cards the town already has moves the listener less than one bringing them")
	# The badge's baseline leaves the case's own cards out of `before` (Quill, Nov 19): the
	# same as a case of cards the town hadn't heard, and the same `after`.
	var strength: Dictionary = Connections.judge_for_profile(g, both, {"baseline": "without_cards"})
	print("public cards, without-cards baseline: %s" % _show(strength))
	check(absf(float(strength.get("before", -1.0)) - float(fresh.before)) < 1e-9 and absf(float(strength.get("after", -1.0)) - float(heard.after)) < 1e-12, "without the case's cards, before is the public record alone and after is unchanged")
	check(float(strength.get("shift", 0.0)) > float(heard.get("shift", 0.0)), "so the case shows its strength, not just what's new")
	# The player's watch record isn't the town's: it changes nothing (Codex on #326).
	g.watched.append({"day": 1, "phase": "night", "block": p[3].home_block, "at": p[3].home_block})
	var watched: Dictionary = Connections.judge_for_profile(g, both)
	g.watched.clear()
	check(absf(float(watched.get("before", -1.0)) - float(heard.before)) < 1e-12 and absf(float(watched.get("after", -1.0)) - float(heard.after)) < 1e-12, "the player's own watch record changes nothing")
	# 3. Put to the town already today: it takes its own place, so it adds about nothing more.
	var filed: int = Live.file(g, both)
	g.public_presentations[filed] = int(g.w.day)
	var again: Dictionary = Connections.judge_for_profile(g, both)
	print("the same case again: %s" % _show(again))
	check(again.get("ready", false) and absf(float(again.get("shift", 0.0))) < 1e-6, "the same case put again today takes its own place: no further change")
	check(not heard.get("case", {}).is_empty() and str(heard.case.get("key", "")) == "case:draft", "the result carries the case's own stored entry (%s)" % str(heard.get("case", {}).get("key", "")))
	check(str(again.get("case", {}).get("key", "")) == "case:%d" % filed, "put again, the entry is that case's own (%s)" % str(again.get("case", {}).get("key", "")))
	# A revision filed but not yet presented retires nothing: the town still holds the original.
	var revised: Dictionary = _value(g, "evil", p[3].id, [seer])
	revised["revises"] = filed
	var second: int = Live.file(g, revised, filed)
	var with_pending: Dictionary = Connections.judge_for_profile(g, both)
	print("with an unpresented revision #%d of #%d filed: %s" % [second, filed, _show(with_pending)])
	check(absf(float(with_pending.get("before", -1.0)) - float(again.before)) < 1e-12, "a revision only filed, not presented, leaves the town holding the original")
	# 4. Reads only.
	g.public_presentations.erase(filed)
	g.public_citations.erase(seer)
	g.public_citations.erase(dowser)
	check(_state(g) == before_state, "judging changes no NPC's beliefs or state")
	print("Judge for profile: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _show(r: Dictionary) -> String:
	return "ready %s, before %.3f, after %.3f, issues %s" % [str(r.get("ready", false)), float(r.get("before", -1.0)), float(r.get("after", -1.0)), str(r.get("issues", []))]


func _state(g) -> String:
	var out: Array = []
	for n in g.w.npcs:
		out.append([n.id, n.suspicion, n.npc_trust, n.workshop_state, n.ledger.keys()])
	return JSON.stringify(out)


func _game():
	LiveActivity.cache.clear()
	Caches.clear_all()
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
	g.w.day = 2
	return g


func _read(g, source, role: String, day: int, data: Dictionary) -> int:
	var number: int = g.add_card({"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 3 if role == "seer" else 0, "data": data, "text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})
	_texts[number] = g.board[number - 1].text
	return number


func _node(model, view, number: int) -> String:
	var card_id: String = ""
	for c in view.cards:
		if c.get("number", -1) == number or c.get("n", -1) == number:
			card_id = c.id
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and (nd.card == card_id or Solver.card_by_id(view, nd.card).get("text", "") == str(_texts.get(number, ""))):
			return id
	return ""


func _value(g, type: String, target: String, support: Array) -> Dictionary:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(target, type, Vector2(400, 40))
	for number in support:
		model.connect_cards(_node(model, view, number), premise)
	return model.compile(premise)
