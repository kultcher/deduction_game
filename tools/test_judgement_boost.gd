## The player's judgement in a word-against-word lie call (Michael, Nov 19): the grounds' side
## of the clash counts as x (1 + PLAYER_JUDGEMENT_WEIGHT x (credibility + PLAYER_EXPERTISE))
## (ReadingChallenges.judgement_boost), so a listener who trusts the player's judgement leans
## a little toward the player's side. It works for a misleading call as for a true one: the
## listener can't tell them apart. Never for an NPC's own defence.
##   godot --headless --path . --script res://tools/test_judgement_boost.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
const RC = preload("res://workshop/reading_challenges.gd")
const Connections = preload("res://workshop/connections.gd")
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	check(is_equal_approx(RC.judgement_boost({"player_credibility": 0.5}), 1.3) and is_equal_approx(RC.judgement_boost({"player_credibility": 0.7}), 1.4),
		"the factor is x1.3 at credibility 0.5 and x1.4 at 0.7 (%.3f, %.3f)" % [RC.judgement_boost({"player_credibility": 0.5}), RC.judgement_boost({"player_credibility": 0.7})])
	RC.player_judgement = false
	check(is_equal_approx(RC.judgement_boost({"player_credibility": 0.7}), 1.0), "with the switch off the call adds nothing")
	RC.player_judgement = true
	var f: Dictionary = _deal()
	check(not f.is_empty(), "(fixture) a deal with a good Gravedigger, a Minion and an innocent to hang")
	if f.is_empty():
		_done()
		return
	var g = f.g
	var hanged = f.hanged
	hanged.alive = false
	hanged.death_cause = "executed"
	g.w.public_log.append({"day": 2, "kind": "execution", "subjects": [hanged.id], "by": ""})
	# The Minion bluffs the Gravedigger and calls the hanged innocent a Minion; the real
	# Gravedigger gives their true role. The player calls the TRUE reading a lie, on the
	# Minion's word: a misleading call, where the boost is the player leading the town astray.
	var bluff: int = g.add_card({"kind": "info", "source": f.minion.id, "role": "gravedigger", "day": 2, "phase": C.NIGHT, "data": {"executed": hanged.id, "role": f.minion.role}, "text": "B"})
	var truth: int = g.add_card({"kind": "info", "source": f.gd.id, "role": "gravedigger", "day": 2, "phase": C.NIGHT, "data": {"executed": hanged.id, "role": hanged.role}, "text": "T"})
	var view: Dictionary = Live.view(g)
	var b_id: String = _id(g, view, bluff)
	var t_id: String = _id(g, view, truth)
	var value = Solver.empty_case()
	value.conclusion = {"type": "evil", "target": f.gd.id, "at": view.alignment_epoch}
	value.cards = [b_id, t_id]
	value.reading_challenges = {t_id: {"mode": "lying", "supports": [b_id]}}
	var profile: Dictionary = {"baseline": "without_cards", "credibility": 0.7, "npc_trust": 0.7}
	var on: float = _agreement(g, value, profile, f.gd.id)
	RC.player_judgement = false
	var off: float = _agreement(g, value, profile, f.gd.id)
	RC.player_judgement = true
	check(on > off + 0.01, "a listener who trusts the player's judgement leans toward the player's side, even on a misleading call (agreement %.3f against %.3f)" % [on, off])
	var low: float = _agreement(g, value, {"baseline": "without_cards", "credibility": 0.2, "npc_trust": 0.7}, f.gd.id)
	var high: float = _agreement(g, value, {"baseline": "without_cards", "credibility": 0.95, "npc_trust": 0.7}, f.gd.id)
	check(high > low + 0.01, "more trust in the player's judgement, more lean (%.3f at credibility 0.95, %.3f at 0.2)" % [high, low])
	check(off < Tuning.Workshop.JURY_CHALLENGE_LYING_MIN_AGR and on < Tuning.Workshop.JURY_CHALLENGE_LYING_MIN_AGR,
		"it stays small: this listener still doesn't take the misleading call (%.3f, under the %.2f bar)" % [on, Tuning.Workshop.JURY_CHALLENGE_LYING_MIN_AGR])
	# An NPC's own defence isn't backed by the player's judgement.
	var npc_value = value.duplicate(true)
	npc_value.reading_challenges[t_id]["npc_defence"] = true
	var npc_on: float = _agreement(g, npc_value, profile, f.gd.id)
	check(is_equal_approx(npc_on, off), "an NPC's own defence gets no boost (%.3f, as with the switch off %.3f)" % [npc_on, off])
	_done()


## The agreement of the lie call on `teller` as the profile's listener weighs it.
func _agreement(g, value: Dictionary, profile: Dictionary, teller: String) -> float:
	var r: Dictionary = Connections.judge_for_profile(g, value, profile)
	var best: float = -1.0
	for fl in r.get("floors", []):
		if str(fl.get("source", "")) == teller and str(fl.get("mode", "")) == "lying":
			best = maxf(best, float(fl.get("agreement", 0.0)))
	return best


func _deal() -> Dictionary:
	for sd in range(1, 200):
		var g = Game.new()
		g.log_dir = "user://test_logs"
		g.new_case(sd, 10)
		var goods: Array = g.w.living_good()
		var gd = null
		for n in goods:
			if n.role == "gravedigger":
				gd = n
		var minion = null
		for n in g.w.npcs:
			if n.alive and n.is_evil() and n.id != g.w.demon_id:
				minion = n
				break
		var rest: Array = goods.filter(func(n): return n != gd)
		if gd == null or minion == null or rest.is_empty():
			continue
		g.w.day = 3
		return {"g": g, "gd": gd, "minion": minion, "hanged": rest[0]}
	return {}


func _id(g, view: Dictionary, number: int) -> String:
	var text: String = str(g.board[number - 1].text)
	for c in view.cards:
		if str(c.get("text", "")) == text:
			return c.id
	return ""


func _done() -> void:
	print("Judgement boost: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
