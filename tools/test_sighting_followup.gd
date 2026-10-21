## Person-specific recent reports and automatic public work observations.
## godot --headless --path . --script res://tools/test_sighting_followup.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Recent = preload("res://game/recent_sightings.gd")
const C = preload("res://sim/content.gd")
const CardModel = preload("res://game/card_model.gd")
var fails = 0

func _init() -> void:
	_workers()
	_recent()
	_night()
	_integration()
	print("SIGHTING FAILURES: %d" % fails)
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(92641, 10)
	return g

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _workers() -> void:
	var g = _game()
	var w = g.w
	var initial: Array = g.board.filter(func(c): return c.get("work_sighting", false))
	_check(not initial.is_empty(), "a new case automatically records public morning workers")
	for phase in [C.MORNING, C.AFTERNOON, C.EVENING]:
		w.phase = phase
		w.start_phase()
		g._phase_header()
		var cards: Array = g.board.filter(func(c): return c.get("work_sighting", false) and c["day"] == w.day and c["phase"] == phase)
		var workers: Array = w.living().filter(func(n): return n.working and not n.at_home() and n.loc == n.work)
		_check(cards.size() == workers.size(), "phase %d records every visible worker exactly once" % phase)
		_check(cards.all(func(c): return c["source"] == "player" and c["class"] == "concrete" and c["loc"] == w.by_id[c["subject"][0]].work and CardModel.place_markers(c)[0]["mark"] == "solid"), "phase %d cards retain observed location, time and firsthand status" % phase)
		var count: int = g.board.size()
		g._phase_header()
		_check(g.board.size() == count, "looking again in phase %d does not duplicate cards" % phase)
	w.day += 1
	w.phase = C.MORNING
	w.start_phase()
	w.deaths_last_night = []
	g._morning_report()
	_check(g.board.any(func(c): return c.get("work_sighting", false) and c["day"] == w.day), "the following dawn records a new day's work observations")
	w.day += 1 # A fresh frame ensures deduplication cannot conceal an invalid observation.
	for n in w.living():
		n.working = false
	var worker = w.living()[0]
	worker.working = true
	worker.loc = "home_" + worker.id
	var count: int = g.board.size()
	g._card_workers()
	_check(g.board.size() == count, "a work flag alone does not reveal someone at home")
	worker.loc = worker.work
	worker.alive = false
	g._card_workers()
	_check(g.board.size() == count, "a dead person is never recorded as working")
	worker.alive = true
	worker.working = false
	g._card_workers()
	_check(g.board.size() == count, "being at a workplace without working does not create an automatic observation")
	w.phase = C.NIGHT
	worker.working = true
	g._card_workers()
	_check(g.board.size() == count, "night does not generate public work cards")
	# Actual command transitions, rather than only the report helpers.
	var live = _game()
	live.command("wait")
	_check(live.board.any(func(c): return c.get("work_sighting", false) and c["phase"] == C.AFTERNOON), "spending a phase produces the next phase's work cards")

func _belief(target, day: int, phase: int, block: String = "square", how: String = "street") -> Dictionary:
	return {"kind": "saw", "who": target.id, "day": day, "phase": phase, "block": block, "loc": "", "how": how}

func _report(g, speaker, target, board: Array = []) -> Dictionary:
	var reply = {"lines": [], "facts": []}
	Recent.append_to(g.w, speaker, target, reply, board)
	return reply

func _recent() -> void:
	var g = _game()
	var w = g.w
	var speaker = w.living_good()[0]
	var target = w.living_good()[1]
	var other = w.living_good()[2]
	w.day = 2
	w.phase = C.EVENING
	speaker.traits["gossip"] = 1.0
	speaker.beliefs = [_belief(target, 1, C.EVENING), _belief(target, 1, C.NIGHT), _belief(target, 2, C.MORNING),
		_belief(other, 2, C.AFTERNOON), _belief(target, 2, C.AFTERNOON), _belief(target, 2, C.EVENING), _belief(target, 3, C.MORNING)]
	var rng_state = w.rng.state
	var r = _report(g, speaker, target)
	_check(r["facts"].size() == 3 and r["facts"].all(func(c): return c["subject"] == [target.id] and c["day"] == 2), "only the requested person in the current and previous two frames is reported")
	_check(r["facts"].map(func(c): return c["phase"]) == [C.EVENING, C.AFTERNOON, C.MORNING], "specific sightings are reported newest first")
	_check(r["facts"].all(func(c): return c["source"] == speaker.id), "NPC memories remain attributed testimony")
	_check(w.rng.state == rng_state, "the optional report does not perturb simulation randomness")
	speaker.beliefs.append(_belief(target, 2, C.EVENING))
	_check(_report(g, speaker, target)["facts"].size() == 3, "multiple observations in one frame do not repeat that frame")
	speaker.traits["gossip"] = 0.0
	speaker.pressure = 0.0
	_check(_report(g, speaker, target)["facts"].is_empty(), "a private speaker may withhold the extra sightings")
	speaker.traits["gossip"] = 1.0
	speaker.silenced = true
	_check(_report(g, speaker, target)["facts"].is_empty(), "silenced people cannot add reports")
	speaker.silenced = false
	w.phase = C.MORNING
	speaker.beliefs = [_belief(target, 1, C.AFTERNOON), _belief(target, 1, C.EVENING), _belief(target, 2, C.MORNING)]
	_check(_report(g, speaker, target)["facts"].size() == 2, "the three-frame window crosses midnight and excludes the fourth frame")
	speaker.beliefs = []
	_check(_report(g, speaker, target)["lines"].is_empty(), "missing observations do not become claims that someone was absent")

func _night() -> void:
	var g = _game()
	var w = g.w
	w.day = 2
	w.phase = C.MORNING
	var speaker = w.living_good()[0]
	var target = w.living_good()[1]
	speaker.traits["gossip"] = 1.0
	speaker.role = "nightwatch"
	speaker.claimed_role = "nightwatch"
	speaker.claim_public = false
	speaker.max_tier = 0
	speaker.secret_mod = ""
	speaker.history[w.time_key(1, C.NIGHT)] = "night:square"
	speaker.beliefs = [_belief(target, 1, C.NIGHT)]
	_check(_report(g, speaker, target)["facts"].is_empty(), "a hidden night role is not exposed by asking about another person")
	speaker.max_tier = 3
	var r = _report(g, speaker, target)
	_check(r["facts"].size() == 1 and r["facts"][0]["phase"] == C.NIGHT and "night 1" in r["lines"][0]["text"], "a disclosed night walker may report the requested person with an explicit night")
	var alibi = {"kind": "alibi", "source": speaker.id, "subject": [speaker.id], "day": 1, "phase": C.NIGHT, "home": true, "block": speaker.home_block}
	_check(_report(g, speaker, target, [alibi])["facts"].is_empty(), "the new report does not contradict an existing home alibi")
	speaker.beliefs = [_belief(target, 1, C.NIGHT, speaker.home_block, "window")]
	_check(_report(g, speaker, target, [alibi])["facts"].size() == 1, "a window observation can accompany a home alibi")
	speaker.secret_mod = "sleepwalker"
	_check(_report(g, speaker, target)["facts"].is_empty(), "the new path cannot disclose unconscious night observations")
	var evil = w.demon()
	evil.claimed_role = "nightwatch"
	evil.claim_public = true
	evil.traits["gossip"] = 1.0
	evil.beliefs = [_belief(target, 1, C.NIGHT)]
	evil.info_log = []
	_check(_report(g, evil, target)["facts"].is_empty(), "a night-role bluff does not expose real evil night movements")
	evil.info_log = [{"fake": true, "shared": true, "role": "nightwatch", "day": 1, "data": {"seen": [target.id], "block": "market"}}]
	r = _report(g, evil, target)
	_check(r["facts"].size() == 1 and r["facts"][0]["block"] == "market", "a false Night Watch reuses its approved report instead of real sightings")
	evil.info_log[0]["data"]["seen"] = []
	_check(_report(g, evil, target)["facts"].is_empty(), "a false watch cannot add someone missing from its report")
	var teammate = w.by_id[w.minion_ids[0]]
	evil.beliefs = [_belief(teammate, 2, C.MORNING)]
	_check(_report(g, evil, teammate)["facts"].is_empty(), "evil keeps the existing policy of withholding teammates' sightings")

func _integration() -> void:
	var g = _game()
	var speaker = g.w.living_good()[0]
	var target = g.w.living_good()[1]
	speaker.traits["gossip"] = 1.0
	speaker.beliefs = [_belief(target, g.w.day, g.w.phase)]
	g.state = "talk"
	g.talk_with = speaker
	g.questions_left = 3
	g.command("ask about " + target.id)
	var reports: Array = g.board.filter(func(c): return c["kind"] == "sighting" and c.get("source", "") == speaker.id)
	_check(g.questions_left == 2 and reports.size() == 1, "asking about a person adds the report while using one question total")
	_check(reports[0]["class"] == "circumstantial" and CardModel.place_markers(reports[0])[0]["mark"] == "hollow", "the report does not become firsthand evidence")
	g.command("ask about " + target.id)
	_check(g.board.filter(func(c): return c["kind"] == "sighting" and c.get("source", "") == speaker.id).size() == 1, "asking again merges the same sighting instead of making duplicate cards")
