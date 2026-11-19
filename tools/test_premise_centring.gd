## Premise centring, option B (Michael, Nov 18; docs/design/premise_centring.md). What a card
## adds when only presented cases brought it, and what a stored case's cards add together,
## count in full on the case's target and at PREMISE_BYSTANDER_SHARE (1/3) on everyone else:
##   - presented as the right person, a case lifts them as before; misframed, it lifts the
##     person the evidence points at less;
##   - a card counts as brought (SharedLedger.brought_by_premise, step 1's selection) while
##     only cases hold it, still after its case fades, and not once the listener holds it any
##     other way.
## Constructed on seed 692's 7-NPC deal (as the premise suites), flat beliefs.
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

var checks := 0
var fails := 0
var _texts: Dictionary = {}


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("PASS: " if ok else "FAIL: ") + label)


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


func _chances(g, n) -> Dictionary:
	var eff: Dictionary = g._workshop_evaluations.get(n.id + ":good", {}).get("proposal", {}).get("effects", {})
	var out: Dictionary = {}
	for id in eff:
		out[id] = float(eff[id].get("posterior", -1.0))
	return out


## The sighting-against-alibi case presented as `frame` (p[3] is the one the cards point at,
## p[4] the named sighter): the listener's chances after, and its connections result.
func _present(frame_index: int, centring: bool, kind: String = "sighting vs alibi") -> Dictionary:
	Connections.premise_centring = centring
	_texts = {}
	var g = _game()
	var n = g.w.npcs[0]
	var p: Array = g.w.npcs
	g.w.defer_beliefs = false
	var cards: Array = _cards(g, kind)
	var filed: int = _file(g, p[frame_index].id, cards)
	g._evaluate_deduction(n, g.board[filed - 1], 1.0, false)
	Connections.premise_centring = true
	return {"g": g, "n": n, "p": p, "post": _chances(g, n), "cx": g._workshop_evaluations[n.id + ":good"].proposal.connections}


func _init() -> void:
	# 1. Presented as the right person, the case lifts them about as before; misframed (as the
	#    named sighter), it lifts them less.
	var right_on: Dictionary = _present(3, true)
	var right_off: Dictionary = _present(3, false)
	var wrong_on: Dictionary = _present(4, true)
	var wrong_off: Dictionary = _present(4, false)
	var x: String = right_on.p[3].id
	print("X (%s) after the case: presented as X %.3f (without centring %.3f); presented as the sighter %.3f (without %.3f)" % [x, right_on.post[x], right_off.post[x], wrong_on.post[x], wrong_off.post[x]])
	check(absf(right_on.post[x] - right_off.post[x]) < 0.05, "presented as the right person, the case lifts them about as without centring")
	check(wrong_on.post[x] < wrong_off.post[x] - 0.05, "misframed, it lifts the person the evidence points at less")
	check(wrong_on.post[x] < right_on.post[x], "...and less than the right frame does")
	# 1b. Centring shapes only what the brought items add by themselves. The core and the
	#     stored case still subtract the raw values from their joint judgements, so what they
	#     add for X is the same interaction as without centring, the case's at the bystander
	#     share (Codex on #246: a centred value there turned the suppressed part into a false
	#     interaction).
	var moved: float = 0.0
	for kind in ["two names", "sighting vs alibi", "mixed"]:
		var on: Dictionary = _present(4, true, kind)
		var off: Dictionary = _present(4, false, kind)
		var worst_core: float = 0.0
		var worst_case: float = 0.0
		for p in off.cx.get("prior", {}):
			var core_on: float = float(on.cx.get("core", {}).get("lean", {}).get(p, 0.0))
			var core_off: float = float(off.cx.get("core", {}).get("lean", {}).get(p, 0.0))
			var case_on: float = float(on.cx.get("cases", {}).get("lean", {}).get(p, 0.0))
			var case_off: float = float(off.cx.get("cases", {}).get("lean", {}).get(p, 0.0))
			var share: float = 1.0 if p == on.p[4].id else Connections.PREMISE_SHARE
			worst_core = maxf(worst_core, absf(core_on - core_off))
			worst_case = maxf(worst_case, absf(case_on - share * case_off))
			moved = maxf(moved, maxf(absf(core_off), absf(case_off)))
		print("%s: the core's largest change %.6f, the case's largest gap from its share %.6f" % [kind, worst_core, worst_case])
		check(worst_core < 1e-6 and worst_case < 1e-6, "%s: the core adds the same as without centring, and the case its interaction at the share" % kind)
	check(moved > 0.01, "...and some core or case part is non-zero, so that was tested (largest %.3f)" % moved)
	# 2. The case's cards are brought, for its target.
	var brought: Dictionary = wrong_on.n.workshop_state.get("connections", {}).get("brought", {})
	if brought.is_empty():
		var plan: Dictionary = wrong_on.g._workshop_plans.get(wrong_on.n.id + ":good", {})
		brought = plan.get("input", {}).get("listener", {}).get("connections", {}).get("brought", {})
	var to_y: bool = not brought.is_empty() and brought.values().all(func(t): return t == [wrong_on.p[4].id])
	check(to_y, "the cards only the case brought are recorded for its target (%d cards)" % brought.size())
	# 3. The lens stays after the case fades: a day on, still brought.
	var g = wrong_on.g
	var n = wrong_on.n
	g.w.day += 1
	Mind.refresh_beliefs(g.w, n, " (next day)")
	var plan2: Dictionary = g._workshop_plans.get(n.id + ":good", {})
	var brought2: Dictionary = plan2.get("input", {}).get("listener", {}).get("connections", {}).get("brought", {})
	check(brought2.size() == brought.size() and brought.size() > 0, "a day later, with the case faded, its cards are still brought (%d)" % brought2.size())
	# 4. Held another way, a card is no longer brought.
	var owners: Dictionary = {"a": ["case:1"], "b": ["case:1", "public"], "c": ["case:1", "case:2"], "d": ["case:3"]}
	var cases_list: Array = [{"key": "case:1", "target": "x"}, {"key": "case:2", "target": "y"}, {"key": "case:3", "target": ""}]
	var b: Dictionary = preload("res://workshop/shared_ledger.gd").brought_by_premise(owners, cases_list)
	check(b.has("a") and b.a == ["x"], "a card only one case holds is brought for its target")
	check(not b.has("b"), "a card the listener also holds another way (here the public record) isn't")
	check(b.has("c") and b.c.size() == 2, "a card two cases hold serves both their targets")
	check(not b.has("d"), "a case with no alignment target (Marked, conflict) shapes nothing")
	# 5. A direct presentation can argue about several people: every one is a target, in any
	#    order (Codex on #246); an NPC nomination carries only its nominee.
	var both: Dictionary = preload("res://workshop/shared_ledger.gd").brought_by_premise({"e": ["case:4"]}, [{"key": "case:4", "target": "x", "targets": ["x", "y"]}])
	check(both.has("e") and both.e == ["x", "y"], "a card a two-person presentation brought serves both people")
	check(Connections.case_targets({"target": "z"}) == ["z"], "a nomination's only target is its nominee")
	print("Premise centring: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
