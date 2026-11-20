## BACKLOG "Medium challenge attribution" (Michael, Nov 17: the choice only). A challenge on a
## Medium's relay names its side: the Medium passed it on wrong ("transmission"), or the dead
## person was wrong in the first place ("original"). The named side is the one blamed: its
## teller's trust weighs the challenge, its evil share splits a lie from an honest error, and
## its source doubt rises. Relays of relays and relayed opinions stay unsupported.
extends SceneTree
const Solver = preload("res://workshop/solver.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Challenges = preload("res://workshop/reading_challenges.gd")
var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _view() -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square"})
	# a was killed on night 2; b, the Medium, relays a's reading.
	return {"people": people, "cards": [], "day": 3, "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": {"events": [{"kind": "demon_death", "subjects": ["a"], "at": {"day": 2, "phase": "night"}}], "deaths": {"a": 3}, "death_ticks": {"a": 11}, "executions": {}},
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked", "delusional"]}}

func _relay() -> Dictionary:
	# a's Gravedigger reading for night 1, "e was the Clerk", though nobody was hanged that
	# day: it can't be true as passed on. The Medium b passed it on on night 2.
	return {"id": "relay", "fact_id": "relay", "kind": "report", "source": "a", "role": "gravedigger", "night": 1,
		"data": {"executed": "e", "role": "clerk"}, "observed_at": {"day": 1, "phase": "night"},
		"relay_source": "b", "relay_observed_at": {"day": 2, "phase": "night"}, "relay_role": "medium",
		"logical_origin": "orig", "accuracy_origin": "health:orig"}

func _assess(view: Dictionary, card: Dictionary, challenge: Dictionary, listener: Dictionary) -> Dictionary:
	view.cards = [card]
	var value = Solver.empty_case()
	value.conclusion.at = view.alignment_epoch
	value.cards = [card.id]
	value.reading_challenges = {card.id: challenge}
	var r: Dictionary = Challenges.assess(view, value, listener, [card])
	return r.results[0] if not r.results.is_empty() else {}

func _assess_with(view: Dictionary, card: Dictionary, extra: Array, challenge: Dictionary, listener: Dictionary) -> Dictionary:
	view.cards = [card] + extra
	var value = Solver.empty_case()
	value.conclusion.at = view.alignment_epoch
	value.cards = [card.id] + extra.map(func(c): return c.id)
	value.reading_challenges = {card.id: challenge}
	var r: Dictionary = Challenges.assess(view, value, listener, [card] + extra)
	return r.results[0] if not r.results.is_empty() else {}

func _init() -> void:
	var view: Dictionary = _view()
	var relay: Dictionary = _relay()
	view.cards = [relay]
	var listener = Ghost.profile(view.people)
	listener.knowledge = {"good": [], "evil": []}
	# Validity: a relay must name its side; the passing-on takes only lie or failed gift.
	check(not Challenges.valid(view, "relay", {"mode": "lying", "supports": []}), "a relay challenge must name the Medium or the dead source")
	check(Challenges.valid(view, "relay", {"mode": "lying", "supports": [], "attribution": "transmission"}), "the Medium can be charged with a lie")
	check(Challenges.valid(view, "relay", {"mode": "impaired", "supports": [], "attribution": "transmission"}), "the Medium can be charged with a failed gift")
	check(not Challenges.valid(view, "relay", {"mode": "misled", "supports": [], "attribution": "transmission"}), "'misled' is the reading's, not the passing-on's")
	check(Challenges.valid(view, "relay", {"mode": "misled", "supports": [], "attribution": "original"}), "the dead source can be called misled")
	check(not Challenges.valid(view, "relay", {"mode": "lying", "supports": [], "attribution": "someone"}), "only the two sides exist")
	# Whom each side blames.
	var t: Dictionary = _assess(view.duplicate(true), relay, {"mode": "lying", "supports": [], "attribution": "transmission"}, listener)
	var o: Dictionary = _assess(view.duplicate(true), relay, {"mode": "lying", "supports": [], "attribution": "original"}, listener)
	check(t.get("source", "") == "b" and int(t.get("night", -1)) == 2, "'the Medium relayed it wrong' blames the Medium, on the night of the passing-on")
	check(o.get("source", "") == "a" and int(o.get("night", -1)) == 1, "'the dead person was wrong' blames the dead source, on their reading's night")
	# Trust decides: a distrusted Medium makes 'relayed it wrong' the likelier lie.
	var wary = Ghost.profile(view.people)
	wary.knowledge = {"good": [], "evil": []}
	wary.suspicion["b"] = 0.9
	wary.npc_trust["b"] = 0.1
	wary.npc_trust["a"] = 0.9
	var wt: Dictionary = _assess(view.duplicate(true), relay, {"mode": "lying", "supports": [], "attribution": "transmission"}, wary)
	var wo: Dictionary = _assess(view.duplicate(true), relay, {"mode": "lying", "supports": [], "attribution": "original"}, wary)
	check(float(wt.get("agreement", 0.0)) > float(wo.get("agreement", 0.0)), "with the Medium distrusted, blaming the passing-on lands better (%.2f vs %.2f)" % [float(wt.get("agreement", 0.0)), float(wo.get("agreement", 0.0))])
	# "No such hanging" says the dead reader's gift couldn't have produced it, not that the
	# Medium lied: it floors only the original side (Codex, #191).
	check(float(o.get("agreement", 0.0)) >= 0.9 - 1e-6, "the dead Gravedigger's impossible reading floors 'they lied' (%.2f)" % float(o.get("agreement", 0.0)))
	check(float(t.get("agreement", 0.0)) < 0.9 - 1e-6, "the same floor doesn't convict the Medium (%.2f)" % float(t.get("agreement", 0.0)))
	# A failed passing-on implicates those out on the Medium's night (Codex, #191).
	var sv: Dictionary = view.duplicate(true)
	sv.script_minions = ["poisoner"]
	# Seen on the Square, where everyone here lives: on the way to the reader's home. A Poisoner
	# candidate must have been (ReadingChallenges.poisoner_candidates, Nov 20; before, the
	# Market sightings here counted although they lay off every road).
	var s1: Dictionary = {"id": "s1", "kind": "sighting", "source": "g", "subject": "c", "subjects": ["c"], "night": 1, "block": "square"}
	var s2: Dictionary = {"id": "s2", "kind": "sighting", "source": "g", "subject": "d", "subjects": ["d"], "night": 2, "block": "square"}
	var ti: Dictionary = _assess_with(sv, relay, [s1, s2], {"mode": "impaired", "supports": [], "attribution": "transmission"}, listener)
	var oi: Dictionary = _assess_with(sv, relay, [s1, s2], {"mode": "impaired", "supports": [], "attribution": "original"}, listener)
	print("impaired candidates: transmission %s, original %s" % [str(ti.get("candidates", {}).keys()), str(oi.get("candidates", {}).keys())])
	check(ti.get("candidates", {}).has("d") and not ti.get("candidates", {}).has("c"), "a failed passing-on points at those out on the Medium's night")
	check(oi.get("candidates", {}).has("c") and not oi.get("candidates", {}).has("d"), "a failed reading points at those out on the reader's night")
	# A relayed morning reading (an Executor's) carries night -1: blaming the dead reader
	# names the day it was read (Codex, #195).
	var morning: Dictionary = relay.duplicate(true)
	morning.night = -1
	morning.role = "executor"
	morning.data = {"target": "e", "role": "clerk"}
	morning.observed_at = {"day": 2, "phase": "morning"}
	var mo: Dictionary = _assess(view.duplicate(true), morning, {"mode": "lying", "supports": [], "attribution": "original"}, listener)
	check(mo.get("source", "") == "a" and int(mo.get("night", -1)) == 2, "a relayed morning reading's challenge names the day it was read (%d)" % int(mo.get("night", -1)))
	# A plain report is unchanged: no attribution needed, its teller is its source.
	var plain: Dictionary = relay.duplicate(true)
	for k in ["relay_source", "relay_observed_at", "relay_role", "logical_origin", "accuracy_origin"]:
		plain.erase(k)
	plain.id = "plain"
	plain.fact_id = "plain"
	view.cards = [plain]
	check(Challenges.valid(view, "plain", {"mode": "lying", "supports": []}), "a plain reading still needs no attribution")
	var p: Dictionary = _assess(view.duplicate(true), plain, {"mode": "lying", "supports": []}, listener)
	check(p.get("source", "") == "a" and not p.has("attribution"), "a plain reading's challenge blames its teller, as before")
	print("medium relay challenge: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
