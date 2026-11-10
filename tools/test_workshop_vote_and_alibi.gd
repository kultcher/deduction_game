## Workshop cases built on votes and alibis: a vote card in a Circumstantial hub makes a
## shielding case against a no-voter (only when the player presents it), and a Night Watch
## report against a third party's home alibi cuts both ways, weighted by trust.
## Gathered from the Legacy Purge phase 2b suite on 2026-11-04.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_test_vote_shielding()
	_test_nightwatch_against_third_party_alibi_both_ways()
	print("Workshop vote and alibi: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _clean_game(seed_val: int, size: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_val, size)
	for p in g.w.npcs:
		for m in [p, p.shadow]:
			if m == null:
				continue
			m.info_log = []
			m.applied_info = 0
			m.known_claims = {}
			m.beliefs = []
			m.hearsay = []
			m.ledger = {}
			m.resentments = []
			m.settled_execution_rapport = {}
			m.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
			for id in m.suspicion:
				m.suspicion[id] = 0.1
			if not m.is_evil():
				Mind.refresh_beliefs(g.w, m, " (clean)")
	return g


func _test_vote_shielding() -> void:
	var g = _clean_game(88310, 10)
	var w = g.w
	w.day = 2
	w.phase = C.EVENING
	var goods: Array = w.living_good()
	var listener = goods[0]
	var nominator = goods[1]
	var shielder = w.evil_team()[0]
	var nom_evil = w.demon()
	if shielder == nom_evil:
		shielder = w.minions()[0]

	# Give `listener` Stage 1 grounds on both `nom_evil` (believed evil >= 0.48) and `shielder` (passes Stage 1 gate).
	var foil_a = goods[2]
	var foil_b = goods[3]
	listener.role = "seer"
	var s1: Dictionary = {"day": 0, "phase": C.NIGHT, "role": "seer", "data": {"pair": [nom_evil.id, foil_a.id], "yes": true}, "true": true, "shared": false, "text": "Demon among pair 1"}
	var s2: Dictionary = {"day": 1, "phase": C.NIGHT, "role": "seer", "data": {"pair": [nom_evil.id, foil_b.id], "yes": true}, "true": true, "shared": false, "text": "Demon among pair 2"}
	var d1: Dictionary = {"day": 1, "phase": C.MORNING, "role": "dowser", "data": {"group": [shielder.id, nominator.id], "count": 1}, "true": true, "shared": true, "text": "One evil"}
	listener.info_log = [s1, s2]
	listener.applied_info = 0
	Mind.hear_claim(w, listener, listener.id, "seer", 1.5, "own")
	Mind.update_from_own_info(w)
	Mind.apply_info(w, listener, nominator, d1, 0.8)
	# Two Seer pings top out near 0.3 (the nominee could be the red herring), so add an
	# ambient reason outside the shared ledger. Shielding fires from 0.48, but an incident
	# is only citable from 0.01 applied, which takes a firm belief (about 0.7+).
	Mind.adjust(w, listener, nom_evil.id, 0.55, "fixture: ambient reasons to think the nominee is evil", "", false)
	_check(Mind.susp(listener, nom_evil.id) >= 0.48, "precondition: listener believes nominee is evil (%.3f)" % Mind.susp(listener, nom_evil.id))

	# Hold a public vote where `shielder` votes NO on `nom_evil`.
	w.meeting = {"block": "", "block_count": 0, "nominated": [], "nominators": [], "results": [], "pending": {}}
	w.open_nomination(nominator.id, nom_evil.id)
	var tally: Dictionary = w.vote_pending(true)
	_check(shielder.id in tally["no"], "vote_pending records evil teammate in no voters")

	var susp_before_hub: float = Mind.susp(listener, shielder.id)
	Mind.refresh_beliefs(w, listener, " (ambient refresh after public vote)")
	_check(is_equal_approx(Mind.susp(listener, shielder.id), susp_before_hub) and listener.workshop_state.get("circumstantial_incidents", {}).is_empty(),
		"ambient refresh does NOT auto-compute vote shielding without a player-presented Circumstantial hub")

	# Add the vote card and present a Circumstantial hub targeting `shielder`!
	var vote_card_num: int = g.add_card({
		"kind": "vote", "source": "player", "subject": tally["yes"] + [nom_evil.id],
		"day": 2, "phase": C.EVENING, "nominee": nom_evil.id, "by": nominator.id,
		"yes": tally["yes"].duplicate(), "no": tally["no"].duplicate(),
		"player_yes": tally["player_yes"], "count": tally["count"],
		"threshold": tally["threshold"], "outcome": tally["outcome"],
		"text": "Day 2 vote on %s" % nom_evil.name,
	})
	var dowser_card_num: int = g.add_card({
		"kind": "info", "source": nominator.id, "subject": [shielder.id, nominator.id],
		"day": 1, "phase": C.MORNING, "role": "dowser",
		"data": {"group": [shielder.id, nominator.id], "count": 1},
		"text": "Dowser count 1",
	})
	var vote_cid: String = WorkshopCanvas.Evidence.normalize_card(g.board[vote_card_num - 1]).id
	var dowser_cid: String = WorkshopCanvas.Evidence.normalize_card(g.board[dowser_card_num - 1]).id
	var view: Dictionary = WorkshopCanvas.view(g)
	var canvas = CanvasModel.new(view)
	var prem_id: String = canvas.nodes.keys().filter(func(k): return canvas.nodes[k].kind == "premise")[0]
	canvas.nodes[prem_id].conclusion = {"type": "suspicious", "target": shielder.id, "at": view.alignment_epoch}
	canvas.connect_cards("e:" + dowser_cid, prem_id)
	var hub_id: String = canvas.add_circumstantial_hub(Vector2(280, 220))
	canvas.connect_cards("e:" + vote_cid, hub_id)
	canvas.connect_cards(hub_id, prem_id)
	var filed_num: int = WorkshopCanvas.file(g, canvas.compile(prem_id))
	_check(filed_num > 0, "WorkshopCanvas files case with vote card wired into Circumstantial hub")

	g._evaluate_deduction(listener, g.board[filed_num - 1], 1.0, false, "meeting")
	var incs: Array = listener.workshop_state.get("circumstantial_incidents", {}).get(shielder.id, [])
	_check(incs.any(func(inc): return str(inc.get("family", "")) == "shielding") and float(listener.workshop_state.get("circumstantial_applied", {}).get(shielder.id, 0.0)) > 0.0,
		"player-presented Circumstantial hub fires shielding incident against no-voter (%s)" % str(incs))
	var reasons: Array = MindMeeting.case_against(w, listener, shielder.id, 6)
	_check(reasons.any(func(r): return "voted against hanging %s" % nom_evil.name in str(r.get("why", ""))),
		"case_against surfaces citable shielding reason (%s)" % str(reasons))


func _canvas_node(model, view, pick: Callable) -> String:
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and pick.call(Solver.card_by_id(view, nd.card)):
			return id
	return ""


## Present Night Watch `W`'s "saw A out on night 1" against A's "I was home" to a listener,
## blaming either the alibi ("alibi") or the report ("report"). Returns {a, w} suspicion after.
func _present_watch_vs_alibi(trust_w: float, trust_a: float, blame: String) -> Dictionary:
	var g = _clean_game(61204, 10)
	var w = g.w
	w.day = 2
	w.phase = C.MORNING
	var goods: Array = w.living_good()
	var listener = goods[0]
	var watcher = goods[1]
	var alibied = goods[2]
	listener.npc_trust[watcher.id] = trust_w
	listener.npc_trust[alibied.id] = trust_a
	g.add_card({"kind": "info", "source": watcher.id, "role": "nightwatch", "day": 1, "phase": C.NIGHT,
		"data": {"block": alibied.home_block, "seen": [alibied.id]}, "text": "%s's watch on night 1 saw %s" % [watcher.name, alibied.name]})
	g.add_card({"kind": "alibi", "subject": [alibied.id], "home": true, "day": 1, "phase": C.NIGHT, "source": alibied.id,
		"block": alibied.home_block, "text": "%s says they were home on night 1." % alibied.name})
	var view: Dictionary = WorkshopCanvas.view(g)
	var model = CanvasModel.new(view)
	var report: String = _canvas_node(model, view, func(c): return c.kind == "report" and c.source == watcher.id)
	var alibi: String = _canvas_node(model, view, func(c): return c.kind == "alibi")
	# "evil", not "suspicious": a suspicious premise is heard at half weight since premises
	# step 2, and this checks how trust splits the blame, not the hedge.
	var premise: String = model.add_premise(alibied.id if blame == "alibi" else watcher.id, "evil", Vector2(0, 0))
	model.connect_cards(report, alibi)
	var contradiction: String = model.selected
	if blame == "report":
		model.doubt_report(contradiction)
		model.connect_cards(report, premise)
		model.connect_cards(alibi, premise)
	else:
		model.connect_cards(contradiction, premise)
	var filed: int = WorkshopCanvas.file(g, model.compile(premise))
	g._evaluate_deduction(listener, g.board[filed - 1], 1.0, false, "meeting")
	return {"a": Mind.susp(listener, alibied.id), "w": Mind.susp(listener, watcher.id)}


## A Night Watch report can still break a third party's home alibi, and the listener's
## trust decides how far each side falls: the source_doubt change for a Night Watch report
## naming the listener themselves must not reach this case.
func _test_nightwatch_against_third_party_alibi_both_ways() -> void:
	var alibi_false_trust_w: Dictionary = _present_watch_vs_alibi(0.85, 0.3, "alibi")
	var alibi_false_trust_a: Dictionary = _present_watch_vs_alibi(0.3, 0.85, "alibi")
	_check(alibi_false_trust_w.a > 0.3 and alibi_false_trust_a.a > 0.2 and alibi_false_trust_w.a > alibi_false_trust_w.w,
		"a Night Watch report against a home alibi raises the alibi-giver (%.3f trusting the watcher, %.3f trusting the alibi-giver)" % [alibi_false_trust_w.a, alibi_false_trust_a.a])
	_check(alibi_false_trust_w.a > alibi_false_trust_a.a,
		"the alibi-giver falls further when the listener trusts the watcher more (%.3f > %.3f)" % [alibi_false_trust_w.a, alibi_false_trust_a.a])
	var report_false_trust_w: Dictionary = _present_watch_vs_alibi(0.85, 0.3, "report")
	var report_false_trust_a: Dictionary = _present_watch_vs_alibi(0.3, 0.85, "report")
	# Bar lowered from 0.2 (Michael, Nov 10): since the subject's own alibi became lie-aware
	# (belief-model fix 3), "the alibi-giver lied" is a third explanation, so blaming the
	# report raises the watcher less (0.120, from 0.225). Trust in the subject doesn't scale
	# it: in a world where the subject is evil, they lie however trusted they are.
	# The alibi-giver can now stay the likelier liar even when the report is blamed, so the
	# watcher no longer has to end above them.
	_check(report_false_trust_a.w > 0.1,
		"the other world is open too: doubting the report raises the watcher (%.3f; alibi-giver %.3f)" % [report_false_trust_a.w, report_false_trust_a.a])
	_check(report_false_trust_a.w > report_false_trust_w.w,
		"and the watcher falls further when the listener trusts the alibi-giver more (%.3f > %.3f)" % [report_false_trust_a.w, report_false_trust_w.w])
