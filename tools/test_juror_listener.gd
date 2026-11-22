## The Test juror as an average listener (Michael, Nov 19, juror fix (a), option (i)): its
## strength is how far an average listener's chance of the premise moves
## (Connections.judge_for_profile, without the case's cards as the baseline), the badge is
## cut from it, a clearing premise reads the same move the other way, and a challenge is
## weighed as that listener weighs it: accepted with grounds, not assumed to hold.
##   godot --headless --path . --script res://tools/test_juror_listener.gd
extends SceneTree

const GameBoard = preload("res://game/game_board.gd")
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
	var lie: int = GameBoard.add_card(g, {"kind": "claim", "subject": [minion.id], "role": "seer", "source": minion.id, "text": "%s claims the Seer" % minion.name})
	var bluff: int = GameBoard.add_card(g, {"kind": "info", "source": minion.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [innocent.id, other.id], "yes": true}, "text": "%s's Seer: %s or %s is the Demon" % [minion.name, innocent.name, other.name]})
	var truth: int = GameBoard.add_card(g, {"kind": "info", "source": seer.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [innocent.id, other.id], "yes": false}, "text": "%s's Seer: neither %s nor %s is the Demon" % [seer.name, innocent.name, other.name]})
	GameBoard.add_card(g, {"kind": "claim", "subject": [seer.id], "role": "seer", "source": seer.id, "text": "%s claims the Seer" % seer.name})
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
	# "Is not the Demon" reads the chance of not being the Demon, which a Minion also meets, not
	# the chance of being good (Seneschal's check, Nov 20). The real Seer's "neither is the
	# Demon" says nothing about a Minion, so it clears the Demon question further than "good".
	var nd_p: String = model.add_premise(innocent.id, "notdemon", Vector2(0, 400))
	_link(model, view, nd_p, [truth_id])
	var nd: Dictionary = Live.test_juror(g, model.compile(nd_p))
	var gd_p: String = model.add_premise(innocent.id, "good", Vector2(0, 600))
	_link(model, view, gd_p, [truth_id])
	var gd: Dictionary = Live.test_juror(g, model.compile(gd_p))
	var nd_heard: Dictionary = nd.get("listener", {})
	check(nd.get("ready", false) and gd.get("ready", false) and float(nd.lr) > float(gd.lr) and float(nd.lr) > 1.0,
		"\"is not the Demon\" on \"neither is the Demon\" reads stronger than \"is good\" on it (x%.3f against x%.3f)" % [float(nd.get("lr", 0.0)), float(gd.get("lr", 0.0))])
	check(not nd_heard.is_empty() and float(nd_heard.chance) >= 1.0 - float(nd_heard.after) - 1e-9 and float(nd_heard.chance_before) >= 1.0 - float(nd_heard.before) - 1e-9,
		"its chance is at least the chance of being good, before and after (%.3f, %.3f)" % [float(nd_heard.get("chance_before", -1.0)), float(nd_heard.get("chance", -1.0))])
	# A bare lie call on that reading leaves the listener believing it, so the Demon share
	# still reads it (Codex on #410): the call can't turn the badge against the premise.
	# (The case also cites the Minion's Seer claim, so something is left once the call applies.)
	var nd2_p: String = model.add_premise(innocent.id, "notdemon", Vector2(0, 800))
	_link(model, view, nd2_p, [truth_id, _id(g, view, lie)])
	var nd2: Dictionary = Live.test_juror(g, model.compile(nd2_p))
	var nd_called: Dictionary = model.compile(nd2_p)
	nd_called["reading_challenges"] = {truth_id: {"mode": "lying", "supports": []}}
	var ndc: Dictionary = Live.test_juror(g, nd_called)
	check(nd2.get("ready", false) and ndc.get("ready", false) and float(ndc.lr) > 1.0 and absf(log(float(ndc.lr)) - log(float(nd2.lr))) < 0.5 * absf(log(float(nd2.lr))),
		"a bare lie call on \"neither is the Demon\" doesn't turn \"is not the Demon\" against itself (x%.3f, x%.3f uncalled)" % [float(ndc.get("lr", 0.0)), float(nd2.get("lr", 0.0))])
	# An honest-mistake call the listener takes discounts the reading in the Demon share too
	# (Codex on #410), as it does in the listener's own chances: the share moves with the call.
	# Word against word (the Minion's bluff against the real Seer) an average listener doesn't
	# take the call, so the grounds are taken as true here (the "legacy" clash rule) to reach it.
	var RC = preload("res://workshop/reading_challenges.gd")
	var rule_was: String = RC.clash_rule
	RC.clash_rule = "legacy"
	var nd_mist: Dictionary = model.compile(nd2_p)
	nd_mist["reading_challenges"] = {truth_id: {"mode": "impaired", "supports": [bluff_id]}}
	if bluff_id not in nd_mist.cards:
		nd_mist.cards.append(bluff_id)
	var nd_plain: Dictionary = model.compile(nd2_p)
	if bluff_id not in nd_plain.cards:
		nd_plain.cards.append(bluff_id)
	var Conn = preload("res://workshop/connections.gd")
	var share_mist: Dictionary = Live._demon_share(Conn.judge_for_profile(g, nd_mist, {"baseline": "without_cards"}), nd_mist.conclusion)
	var share_plain: Dictionary = Live._demon_share(Conn.judge_for_profile(g, nd_plain, {"baseline": "without_cards"}), nd_plain.conclusion)
	RC.clash_rule = rule_was
	check(not share_mist.is_empty() and not share_plain.is_empty() and float(share_mist.after) > float(share_plain.after) + 1e-6,
		"a Mistaken call on \"neither is the Demon\" weakens it in the Demon share too (share of evil that is the Demon %.3f, %.3f uncalled)" % [float(share_mist.get("after", -1.0)), float(share_plain.get("after", -1.0))])
	# The split hears the reading as the listener does (Codex on #410): a listener who trusts
	# the town less takes less from the Seer's "neither is the Demon", in the Demon share too.
	var nd2_v: Dictionary = model.compile(nd2_p)
	var share_mid: Dictionary = Live._demon_share(Conn.judge_for_profile(g, nd2_v, {"baseline": "without_cards"}), nd2_v.conclusion)
	var share_low: Dictionary = Live._demon_share(Conn.judge_for_profile(g, nd2_v, {"baseline": "without_cards", "npc_trust": 0.1}), nd2_v.conclusion)
	check(not share_mid.is_empty() and not share_low.is_empty() and float(share_mid.after) < float(share_mid.before) and float(share_low.after) > float(share_mid.after) + 1e-6,
		"a less trusting listener clears less in the Demon share too (share after %.3f at trust 0.1, %.3f at 0.5; %.3f before)" % [float(share_low.get("after", -1.0)), float(share_mid.get("after", -1.0)), float(share_mid.get("before", -1.0))])
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
	# A Mistaken call in an earlier case counts only while that case does (Codex on #410): once
	# it has faded below the connections model's floor, it no longer discounts the reading in the
	# Demon share either. (Last: filing the earlier case changes the town's record.)
	RC.clash_rule = "legacy"
	var earlier: int = Live.file(g, nd_mist)
	g.public_presentations[earlier] = int(g.w.day)  # put to the town today
	var share_fresh: Dictionary = Live._demon_share(Conn.judge_for_profile(g, nd2_v, {"baseline": "without_cards"}), nd2_v.conclusion)
	var day_was: int = g.w.day
	g.w.day = day_was + 30
	var share_faded: Dictionary = Live._demon_share(Conn.judge_for_profile(g, nd2_v, {"baseline": "without_cards"}), nd2_v.conclusion)
	g.w.day = day_was
	g.public_presentations.erase(earlier)
	RC.clash_rule = rule_was
	check(earlier > 0 and not share_fresh.is_empty() and not share_faded.is_empty(), "(fixture) the earlier called case is filed and the draft still reads (%d)" % earlier)
	check(float(share_fresh.after) > float(share_mid.after) + 1e-6, "while the earlier case counts, its Mistaken call weakens the reading in the Demon share (%.3f against %.3f without it)" % [float(share_fresh.get("after", -1.0)), float(share_mid.get("after", -1.0))])
	check(absf(float(share_faded.after) - float(share_mid.after)) < absf(float(share_fresh.after) - float(share_mid.after)) - 1e-6, "once it has faded, the call no longer weakens it (%.3f faded, %.3f fresh, %.3f without)" % [float(share_faded.get("after", -1.0)), float(share_fresh.get("after", -1.0)), float(share_mid.get("after", -1.0))])
	_draw_and_bare()
	_top_tier()
	_lines()
	_hidden_burden()
	_done()


## A listener weighs a lie call against everything on the case, not only its cited grounds
## (ReadingChallenges.assess): with the real Seer's reading on the case, it accepts the call
## (agreement 0.49 against the 0.3 bar) whether or not the call cites it. Without anything
## on the case that contradicts the reading, the call is bare and presses no one.
func _draw_and_bare() -> void:
	var f: Dictionary = _deal()
	var g = f.g
	var bluff: int = GameBoard.add_card(g, {"kind": "info", "source": f.minion.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [f.innocent.id, f.other.id], "yes": true}, "text": "B2"})
	var truth: int = GameBoard.add_card(g, {"kind": "info", "source": f.seer.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [f.innocent.id, f.other.id], "yes": false}, "text": "T2"})
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
	var likely: int = GameBoard.add_card(g, {"kind": "info", "source": f.minion.id, "role": "seer", "day": 2, "phase": C.NIGHT, "data": {"pair": [f.innocent.id, f.other.id], "yes": false}, "text": "N2"})
	var n_id: String = _id(g, Live.view(g), likely)
	var alone = value.duplicate(true)
	alone.conclusion = {"type": "good", "target": f.innocent.id, "at": view.alignment_epoch}
	alone.cards = [n_id]
	alone.reading_challenges = {n_id: {"mode": "lying", "supports": []}}
	var u: Array = Live.listener_reading(g, uncited).get("challenges", [])
	var a: Array = Live.listener_reading(g, alone).get("challenges", [])
	check(u.size() == 1 and u[0].kind == "pressed", "a lie call is weighed against the whole case: with the contradicting reading on it, it's accepted uncited (%s)" % str(u))
	check(a.size() == 1 and a[0].kind == "bare", "a bare call on a reading nothing argues against presses no one (%s)" % str(a))
	# Grounds that agree with the reading establish no lie (Lantern's review of #332). The two
	# still both claim the one Seer gift, so the call is your word against theirs on who holds
	# it: before the player's judgement counted (Nov 19) that came out "unestablished" only
	# because equal trust gave the clash a share of exactly 0; now it leans a little, a draw.
	# Either way it presses no one.
	var agreeing = value.duplicate(true)
	agreeing.conclusion = {"type": "good", "target": f.innocent.id, "at": view.alignment_epoch}
	agreeing.cards = [n_id, t_id]
	agreeing.reading_challenges = {n_id: {"mode": "lying", "supports": [t_id]}}
	var e: Array = Live.listener_reading(g, agreeing).get("challenges", [])
	check(e.size() == 1 and e[0].kind in ["unestablished", "draw"], "a call whose cited grounds agree with the reading presses no one (%s)" % str(e))


## The badge's top tier reads the chance only where it settles the premise (Herald and Codex on
## #358): accusing premises, "is good", "is not the Demon"; not "is Marked" and the like.
func _top_tier() -> void:
	var CaseEval = preload("res://workshop/case_eval.gd")
	var cat: Callable = func(type: String) -> String: return CaseEval.category(1.1, Live.top_tier_chance(type, 0.95))
	check(cat.call("evil") == "damning" and cat.call("demon") == "damning" and cat.call("good") == "damning" and cat.call("notdemon") == "damning",
		"at a 95% chance, an accusing premise, \"is good\" and \"is not the Demon\" reach the top tier")
	check(cat.call("misled") == "none" and cat.call("truthful") == "none" and cat.call("marked") == "none"
		and cat.call("secret_mod") == "none",
		"a clearing premise the target's goodness doesn't settle keeps the tier its strength earns")


## The words for each outcome (Michael's, through Herald, Nov 19).
func _lines() -> void:
	var names: Dictionary = {"t": "Tamsin", "w": "Wil", "x": "Ilse"}
	var name_of: Callable = func(id: String) -> String: return names.get(id, id)
	check(Live.lie_call_line({"kind": "pressed", "teller": "t", "witnesses": ["w"]}, name_of) == "The town would press Tamsin as the liar.", "the pressed line names the teller")
	check(Live.lie_call_line({"kind": "draw", "teller": "t", "witnesses": ["w"]}, name_of) == "It's Wil's word against Tamsin's: some may be swayed by your assessment.", "a draw with one witness names them")
	check(Live.lie_call_line({"kind": "draw", "teller": "t", "witnesses": ["w", "x"]}, name_of) == "Their word against Tamsin's: some may be swayed by your assessment.", "a draw with several witnesses")
	check(Live.lie_call_line({"kind": "draw", "teller": "t", "witnesses": []}, name_of) == "Your word against Tamsin's.", "a draw on the player's own grounds")
	check(Live.lie_call_line({"kind": "unestablished", "teller": "t", "witnesses": ["w"]}, name_of) == "Nothing you've cited shows the reading is wrong; the town will still believe it.", "the unestablished line")
	check(Live.lie_call_line({"kind": "bare", "teller": "t", "witnesses": []}, name_of) == "The town won't take this challenge on your word: nothing on the case shows why the reading is wrong.", "the bare line")


## "Carries a hidden burden: Delusional" is graded on the listener's chance that the subject
## is Delusional (Michael, Nov 22, the shared Delusion doubt), not their chance of being good:
## a Seer's own readings that clash count for it.
func _hidden_burden() -> void:
	var found: Dictionary = _deal()
	if found.is_empty():
		return
	var g = found.g
	if g.w.case_script != null and not ("delusional" in g.w.case_script.secrets):
		g.w.case_script.secrets.append("delusional")
	var seer = found.seer
	var a = found.innocent
	var b = found.other
	var yes_n: int = GameBoard.add_card(g, {"kind": "info", "source": seer.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [a.id, b.id], "yes": true}, "text": "%s's Seer (night 1): %s or %s is the Demon" % [seer.name, a.name, b.name]})
	var no_n: int = GameBoard.add_card(g, {"kind": "info", "source": seer.id, "role": "seer", "day": 2, "phase": C.NIGHT, "data": {"pair": [a.id, b.id], "yes": false}, "text": "%s's Seer (night 2): neither %s nor %s is the Demon" % [seer.name, a.name, b.name]})
	GameBoard.add_card(g, {"kind": "claim", "subject": [seer.id], "role": "seer", "source": seer.id, "text": "%s claims the Seer" % seer.name})
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var p: String = model.add_premise(seer.id, "secret_mod", Vector2(0, 0))
	model.nodes[p].conclusion["mod"] = "delusional"
	_link(model, view, p, [_id(g, view, yes_n), _id(g, view, no_n)])
	var r: Dictionary = Live.test_juror(g, model.compile(p))
	var heard: Dictionary = r.get("listener", {})
	print("hidden burden: Delusional %.3f -> %.3f (x%.2f, %s)" % [float(heard.get("chance_before", -1.0)), float(heard.get("chance", -1.0)), float(r.get("lr", 0.0)), str(r.get("category", ""))])
	check(r.get("ready", false) and float(heard.get("chance_before", 1.0)) < 0.2, "the hidden-burden premise reads the chance of being Delusional, low before the case (%.3f)" % float(heard.get("chance_before", -1.0)))
	check(float(heard.get("chance", 0.0)) > float(heard.get("chance_before", 1.0)) and float(r.get("lr", 0.0)) > 1.0, "and a Seer's clashing readings raise it (x%.2f)" % float(r.get("lr", 0.0)))

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
