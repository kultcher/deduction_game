## The Test juror as an average listener (Michael, Nov 19, juror fix (a), option (i)): its
## strength is how far an average listener's chance of the premise moves
## (Connections.judge_for_profile, without the case's cards as the baseline), the badge is
## cut from it, a clearing premise reads the same move the other way, and a challenge is
## weighed as that listener weighs it: accepted with grounds, not assumed to hold.
##   godot --headless --path . --script res://tools/test_juror_listener.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	var found: Dictionary = _deal()
	check(not found.is_empty(), "(fixture) a deal with a good Seer, a Minion and an innocent")
	if found.is_empty():
		_done()
		return
	var g = found.g
	var seer = found.seer
	var minion = found.minion
	var innocent = found.innocent
	var other = found.other
	# The Minion bluffs the Seer and names the innocent; the real Seer read the same pair
	# and saw no Demon there.
	var lie: int = g.add_card({"kind": "claim", "subject": [minion.id], "role": "seer", "source": minion.id, "text": "%s claims the Seer" % minion.name})
	var bluff: int = g.add_card({"kind": "info", "source": minion.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [innocent.id, other.id], "yes": true}, "text": "%s's Seer: %s or %s is the Demon" % [minion.name, innocent.name, other.name]})
	var truth: int = g.add_card({"kind": "info", "source": seer.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [innocent.id, other.id], "yes": false}, "text": "%s's Seer: neither %s nor %s is the Demon" % [seer.name, innocent.name, other.name]})
	g.add_card({"kind": "claim", "subject": [seer.id], "role": "seer", "source": seer.id, "text": "%s claims the Seer" % seer.name})
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var bluff_id: String = _id(g, view, bluff)
	var truth_id: String = _id(g, view, truth)
	var evil_p: String = model.add_premise(innocent.id, "evil", Vector2(0, 0))
	_link(model, view, evil_p, [bluff_id])
	var accuse: Dictionary = model.compile(evil_p)
	var r: Dictionary = Live.test_juror(g, accuse)
	check(r.get("ready", false), "the juror judges the bluffed reading's case (%s)" % str(r.get("issues", [])))
	var heard: Dictionary = r.get("listener", {})
	var odds = func(p: float) -> float: return clampf(p, 1e-6, 1.0 - 1e-6) / (1.0 - clampf(p, 1e-6, 1.0 - 1e-6))
	check(not heard.is_empty() and absf(float(r.lr) - odds.call(float(heard.chance)) / odds.call(float(heard.chance_before))) < 1e-6,
		"its strength is the average listener's odds ratio on the premise (x%.3f)" % float(r.get("lr", 0.0)))
	check(str(r.get("category", "")) == CaseEval.category(float(r.get("lr", 1.0))), "and the badge is cut from that strength (%s)" % str(r.get("category", "")))
	# Debug > Why explains the badge's own reading first, and labels the full-weight breakdown
	# as a diagnostic (Codex on #332).
	var why: Dictionary = preload("res://game/workshop_why.gd").test_juror(g, accuse)
	var why_text: String = str(why.get("text", ""))
	check(why_text.begins_with("Test juror: an average listener") and "x%.2f" % float(r.lr) in why_text and "Diagnostic, not the badge" in why_text,
		"the Why readout leads with the listener reading the badge uses, and labels the full-weight breakdown")
	# A clearing premise reads the same listener the other way.
	var good_p: String = model.add_premise(innocent.id, "good", Vector2(0, 200))
	_link(model, view, good_p, [bluff_id])
	var clear: Dictionary = Live.test_juror(g, model.compile(good_p))
	check(clear.get("ready", false) and absf(log(float(clear.lr)) + log(float(r.lr))) < 1e-6, "\"is good\" on the same card reads the inverse strength (x%.3f against x%.3f)" % [float(clear.get("lr", 0.0)), float(r.get("lr", 0.0))])
	# A challenge, weighed as the listener weighs it.
	var bare: Dictionary = accuse.duplicate(true)
	bare["reading_challenges"] = {bluff_id: {"mode": "lying", "supports": []}}
	var grounded: Dictionary = accuse.duplicate(true)
	if truth_id not in grounded.cards:
		grounded.cards.append(truth_id)
	grounded["reading_challenges"] = {bluff_id: {"mode": "lying", "supports": [truth_id]}}
	var with_truth: Dictionary = accuse.duplicate(true)
	if truth_id not in with_truth.cards:
		with_truth.cards.append(truth_id)
	var r_bare: Dictionary = Live.test_juror(g, bare)
	var r_grounded: Dictionary = Live.test_juror(g, grounded)
	var r_truth: Dictionary = Live.test_juror(g, with_truth)
	print("  plain x%.3f, bare challenge x%.3f, with the true reading x%.3f, challenge grounded on it x%.3f" % [float(r.get("lr", 0)), float(r_bare.get("lr", 0)), float(r_truth.get("lr", 0)), float(r_grounded.get("lr", 0))])
	# The challenge reaches the case, but a clash between two tellers says one is wrong, not
	# which (ReadingChallenges.assess): an average listener trusts both Seers alike, so a lie
	# call grounded on the other's reading moves nothing for it (Lantern, Nov 19).
	check(r_grounded.get("ready", false) and absf(float(r_grounded.lr) - float(r_truth.lr)) < 1e-6, "for an average listener, a lie call grounded on another teller's word is your word against theirs (x%.3f either way)" % float(r_grounded.get("lr", 0.0)))
	# A listener who trusts the real Seer more does take the challenge: it's wired through.
	var Connections = preload("res://workshop/connections.gd")
	var trusting: Dictionary = {"baseline": "without_cards", "npc_trust": {seer.id: 0.9, minion.id: 0.3}}
	var plain_t: Dictionary = Connections.judge_for_profile(g, with_truth, trusting)
	var chal_t: Dictionary = Connections.judge_for_profile(g, grounded, trusting)
	# An accepted lie call doesn't change the target's odds (the clash is in the worlds already):
	# it presses the teller as the liar, a floor on their suspicion (Lantern, Nov 19).
	var floors: Array = chal_t.get("floors", [])
	var rise_plain: float = float(plain_t.get("requested_after", {}).get(minion.id, 0.0))
	var rise_chal: float = float(chal_t.get("requested_after", {}).get(minion.id, 0.0))
	check(plain_t.get("ready", false) and chal_t.get("ready", false) and floors.any(func(f): return str(f.get("source", "")) == minion.id and str(f.get("mode", "")) == "lying") and rise_chal > rise_plain,
		"a listener who trusts the real Seer more takes the grounded lie call: it presses %s as the liar (requested rise %.3f against %.3f)" % [minion.name, rise_chal, rise_plain])
	check(not ("challenge holds" in str(r_grounded.get("reason", ""))), "and the badge never claims the challenge simply holds")
	# Here the Minion and the Seer both claim the gift, so the clash itself grounds the call:
	# an average listener accepts it and presses the Minion as the liar.
	var outs: Array = r_grounded.get("listener", {}).get("challenges", [])
	check(outs.size() == 1 and outs[0].kind == "pressed" and outs[0].teller == minion.id and outs[0].witnesses == [seer.id], "with both claiming the Seer, the call is accepted: the badge's data names the teller it presses and the witness (%s)" % str(outs))
	_draw_and_bare()
	_lines()
	_done()


## A listener weighs a lie call against everything on the case, not only its cited grounds
## (ReadingChallenges.assess): with the real Seer's reading on the case, it accepts the call
## (agreement 0.49 against the 0.3 bar) whether or not the call cites it. Without anything
## on the case that contradicts the reading, the call is bare and presses no one.
func _draw_and_bare() -> void:
	var f: Dictionary = _deal()
	var g = f.g
	var bluff: int = g.add_card({"kind": "info", "source": f.minion.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [f.innocent.id, f.other.id], "yes": true}, "text": "B2"})
	var truth: int = g.add_card({"kind": "info", "source": f.seer.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [f.innocent.id, f.other.id], "yes": false}, "text": "T2"})
	var view: Dictionary = Live.view(g)
	var b_id: String = _id(g, view, bluff)
	var t_id: String = _id(g, view, truth)
	var value = Solver.empty_case()
	value.conclusion = {"type": "evil", "target": f.innocent.id, "at": view.alignment_epoch}
	value.cards = [b_id, t_id]
	var uncited = value.duplicate(true)
	uncited.reading_challenges = {b_id: {"mode": "lying", "supports": []}}
	# A "no" reading is likely true from the start (a "yes" isn't: one in five, in ten), so a
	# bare call on it has nothing to stand on.
	var likely: int = g.add_card({"kind": "info", "source": f.minion.id, "role": "seer", "day": 2, "phase": C.NIGHT, "data": {"pair": [f.innocent.id, f.other.id], "yes": false}, "text": "N2"})
	var n_id: String = _id(g, Live.view(g), likely)
	var alone = value.duplicate(true)
	alone.conclusion = {"type": "good", "target": f.innocent.id, "at": view.alignment_epoch}
	alone.cards = [n_id]
	alone.reading_challenges = {n_id: {"mode": "lying", "supports": []}}
	var u: Array = Live.listener_reading(g, uncited).get("challenges", [])
	var a: Array = Live.listener_reading(g, alone).get("challenges", [])
	check(u.size() == 1 and u[0].kind == "pressed", "a lie call is weighed against the whole case: with the contradicting reading on it, it's accepted uncited (%s)" % str(u))
	check(a.size() == 1 and a[0].kind == "bare", "a bare call on a reading nothing argues against presses no one (%s)" % str(a))
	# Grounds that agree with the reading don't establish anything (Lantern's review of #332).
	var agreeing = value.duplicate(true)
	agreeing.conclusion = {"type": "good", "target": f.innocent.id, "at": view.alignment_epoch}
	agreeing.cards = [n_id, t_id]
	agreeing.reading_challenges = {n_id: {"mode": "lying", "supports": [t_id]}}
	var e: Array = Live.listener_reading(g, agreeing).get("challenges", [])
	check(e.size() == 1 and e[0].kind == "unestablished", "a call whose cited grounds agree with the reading is not established (%s)" % str(e))


## The words for each outcome (Michael's, through Herald, Nov 19).
func _lines() -> void:
	var names: Dictionary = {"t": "Tamsin", "w": "Wil", "x": "Ilse"}
	var name_of: Callable = func(id: String) -> String: return names.get(id, id)
	check(Live.lie_call_line({"kind": "pressed", "teller": "t", "witnesses": ["w"]}, name_of) == "The town would press Tamsin as the liar.", "the pressed line names the teller")
	check(Live.lie_call_line({"kind": "draw", "teller": "t", "witnesses": ["w"]}, name_of) == "It's Wil's word against Tamsin's: some may be swayed by your assessment.", "a draw with one witness names them")
	check(Live.lie_call_line({"kind": "draw", "teller": "t", "witnesses": ["w", "x"]}, name_of) == "Their word against Tamsin's: some may be swayed by your assessment.", "a draw with several witnesses")
	check(Live.lie_call_line({"kind": "unestablished", "teller": "t", "witnesses": ["w"]}, name_of) == "Nothing you've cited shows the reading is wrong; the town will still believe it.", "the unestablished line")
	check(Live.lie_call_line({"kind": "bare", "teller": "t", "witnesses": []}, name_of) == "The town won't take this challenge on your word: nothing on the case shows why the reading is wrong.", "the bare line")


func _done() -> void:
	print("Juror as listener: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A 10-NPC deal with a living good Seer, a living Minion, and two other living good people.
func _deal() -> Dictionary:
	for sd in range(1, 120):
		var g = Game.new()
		g.log_dir = "user://test_logs"
		g.new_case(sd, 10)
		var goods: Array = g.w.living_good()
		var seer = null
		for n in goods:
			if n.role == "seer":
				seer = n
		var minion = null
		for n in g.w.npcs:
			if n.alive and n.is_evil() and n.id != g.w.demon_id:
				minion = n
				break
		var rest: Array = goods.filter(func(n): return n != seer)
		if seer == null or minion == null or rest.size() < 2:
			continue
		g.w.day = 3
		return {"g": g, "seer": seer, "minion": minion, "innocent": rest[0], "other": rest[1]}
	return {}


func _id(g, view: Dictionary, number: int) -> String:
	var text: String = str(g.board[number - 1].text)
	for c in view.cards:
		if str(c.get("text", "")) == text:
			return c.id
	return ""


func _link(model, view: Dictionary, premise: String, ids: Array) -> void:
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and nd.card in ids:
			model.connect_cards(id, premise)
