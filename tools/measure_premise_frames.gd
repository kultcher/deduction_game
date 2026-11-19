## Premise centring (option B, Michael Nov 18) on constructed, misframed cases
## (docs/design/premise_centring.md section 8).
## One strong case against X, presented three ways: "X is evil"; "Y is evil", Y an innocent
## named in the cards; "Z is evil", Z unconnected. For each kind of evidence and each rule
## (without centring, and with option B at PREMISE_BYSTANDER_SHARE) it prints the listener's chance that X, Y and Z
## are evil after hearing the case. The listener holds nothing before it, so it has no
## connections reading then; its starting beliefs are printed once for reference.
## Run: godot --headless --path . --script res://tools/measure_premise_frames.gd
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Connections = preload("res://workshop/connections.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Caches = preload("res://workshop/caches.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const C = preload("res://sim/content.gd")

var _texts: Dictionary = {}
const RULES = [["without", false], ["B 1/3", true]]
const KINDS = ["two names", "sighting vs alibi", "mixed"]


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
		p.trust = 0.7
		p.credibility = 0.7
		p.trust_at_reconsider = 0.7
		for id in p.suspicion:
			p.suspicion[id] = 0.25
			p.npc_trust[id] = 1.0
	var n = g.w.npcs[0]
	n.alignment = "good"
	n.role = "warden"
	n.traits.insight = 0.5
	n.traits.confidence = 0.5
	n.workshop_state["reasoning_mode"] = "full"
	g.w.day = 2
	return g


func _add(g, card: Dictionary) -> int:
	var number: int = g.add_card(card)
	_texts[number] = g.board[number - 1].text
	return number


## The case's cards for `kind`. p[3] is X, p[4] is Y (named), p[6] is Z (unconnected).
func _cards(g, kind: String) -> Array:
	var p: Array = g.w.npcs
	var x = p[3]
	var y = p[4]
	var out: Array = []
	var away: String = p[2].home_block if p[2].home_block != x.home_block else p[1].home_block
	if kind in ["two names", "mixed"]:
		out.append(_add(g, {"kind": "info", "source": p[1].id, "role": "dowser", "day": 1, "phase": 0, "data": {"group": [x.id, y.id], "count": 1},
			"text": "%s dowser day 1: one of %s and %s is evil" % [p[1].id, x.id, y.id]}))
	if kind == "two names":
		out.append(_add(g, {"kind": "info", "source": p[5].id, "role": "dowser", "day": 2, "phase": 0, "data": {"group": [x.id, p[2].id], "count": 1},
			"text": "%s dowser day 2: one of %s and %s is evil" % [p[5].id, x.id, p[2].id]}))
	if kind in ["sighting vs alibi", "mixed"]:
		var sighter = y if kind == "sighting vs alibi" else p[5]
		out.append(_add(g, {"kind": "sighting", "subject": [x.id], "day": 1, "phase": C.NIGHT, "source": sighter.id, "block": away,
			"text": "%s saw %s out on night 1." % [sighter.id, x.id]}))
		out.append(_add(g, {"kind": "alibi", "source": x.id, "subject": [x.id], "home": true, "block": x.home_block, "day": 1, "phase": C.NIGHT,
			"text": "%s says they were home on night 1." % x.id}))
	if kind == "sighting vs alibi":
		out.append(_add(g, {"kind": "sighting", "subject": [x.id], "day": 1, "phase": C.NIGHT, "source": p[5].id, "block": away,
			"text": "%s also saw %s out on night 1." % [p[5].id, x.id]}))
	return out


func _node(model, view, number: int) -> String:
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and Solver.card_by_id(view, nd.card).get("text", "") == str(_texts.get(number, "")):
			return id
	return ""


func _file(g, target: String, support: Array) -> int:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(target, "evil", Vector2(400, 40))
	for number in support:
		model.connect_cards(_node(model, view, number), premise)
	return Live.file(g, model.compile(premise))


func _posteriors(g, n) -> Dictionary:
	var eff: Dictionary = g._workshop_evaluations.get(n.id + ":good", {}).get("proposal", {}).get("effects", {})
	var out: Dictionary = {}
	for id in eff:
		out[id] = float(eff[id].get("posterior", -1.0))
	return out


func _run(kind: String, frame: String, rule: Array) -> Dictionary:
	Connections.premise_centring = rule[1]
	_texts = {}
	var g = _game()
	var n = g.w.npcs[0]
	var p: Array = g.w.npcs
	var who: Dictionary = {"X": p[3].id, "Y": p[4].id, "Z": p[6].id}
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (before)")
	var before: Dictionary = _posteriors(g, n)
	var trust0: float = n.trust
	var cards: Array = _cards(g, kind)
	var filed: int = _file(g, who[frame], cards)
	var r: Dictionary = g._evaluate_deduction(n, g.board[filed - 1], 1.0, false)
	var after: Dictionary = _posteriors(g, n)
	var out: Dictionary = {"trust": n.trust - trust0, "agreement": float(r.get("agreement", -1.0))}
	for k in who:
		out[k] = float(after.get(who[k], -1.0)) - float(before.get(who[k], 0.25))
		out[k + "_after"] = float(after.get(who[k], -1.0))
	return out


func _init() -> void:
	var g0 = _game()
	var p0: Array = g0.w.npcs
	g0.w.defer_beliefs = false
	Mind.refresh_beliefs(g0.w, p0[0], " (start)")
	print("Listener %s; X %s, Y %s, Z %s. Starting beliefs: X %.2f, Y %.2f, Z %.2f" % [p0[0].id, p0[3].id, p0[4].id, p0[6].id, p0[0].suspicion[p0[3].id], p0[0].suspicion[p0[4].id], p0[0].suspicion[p0[6].id]])
	for kind in KINDS:
		print("\n== %s" % kind)
		print("%-8s %-26s %-26s %-26s" % ["rule", "presented as X", "presented as Y", "presented as Z"])
		for rule in RULES:
			var cells: Array = []
			for frame in ["X", "Y", "Z"]:
				var r: Dictionary = _run(kind, frame, rule)
				cells.append("X %.2f Y %.2f Z %.2f t%+.2f a%.2f" % [r.X_after, r.Y_after, r.Z_after, r.trust, r.agreement])
				print("ROW|%s|%s|%s|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f" % [kind, rule[0], frame, r.X, r.Y, r.Z, r.X_after, r.Y_after, r.Z_after])
			print("%-8s %-26s %-26s %-26s" % [rule[0], cells[0], cells[1], cells[2]])
	Connections.premise_centring = true
	quit(0)
