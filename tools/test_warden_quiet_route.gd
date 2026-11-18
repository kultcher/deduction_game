## BACKLOG "Quiet-night evidence argued by the player" (Michael, Nov 17), the judge side: a
## Warden's guard of a door on a night the Demon killed nobody. Where the Warden and the
## guarded person are both good, the quiet is the guard holding, so the Demon's walk that
## night ended at that door, as for the player's held ward (the scorched sigil). It holds at
## the reliability of a claimed save, shared with any other living Veteran claimant.
##   godot --headless --path . --script res://tools/test_warden_quiet_route.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const History = preload("res://workshop/live_history.gd")
const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")

var _checks: int = 0
var _fails: int = 0

const IDS = ["a", "t", "d", "e", "f", "g", "h"]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1


func _initialize() -> void:
	call_deferred("_run")


## a the Warden (hill), t guarded (docks), d and e (market) the two suspects.
func _view(killed_night: int = -1) -> Dictionary:
	var homes = {"a": "hill", "t": "docks", "d": "market", "e": "market", "f": "square", "g": "square", "h": "hill"}
	var people: Array = []
	for id in IDS:
		people.append({"id": id, "name": id.to_upper(), "home": homes[id], "alive": true})
	var events: Array = []
	if killed_night >= 1:
		events.append({"kind": "demon_death", "subjects": ["g"], "at": {"day": killed_night, "phase": "night"}, "by": ""})
	return {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment",
		"live_activity": true, "timeline": History.from_events(events), "script_demons": ["demon"],
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}


func _sighting(subject: String, night: int, block: String) -> Dictionary:
	return {"id": "s-" + subject, "fact_id": "s-" + subject, "kind": "sighting", "source": "player", "subject": subject, "subjects": [subject],
		"night": night, "block": block, "data": {}, "role": "", "observed_at": {"day": night, "phase": "night"}}


func _guard(target: String, night: int = 1, saved: bool = true) -> Dictionary:
	var data: Dictionary = {"target": target}
	if saved:
		data["saved"] = true
	return {"id": "guard", "fact_id": "guard", "kind": "report", "source": "a", "role": "warden", "night": night, "block": "docks",
		"data": data, "observed_at": {"day": night, "phase": "night"}}


func _mask(ids: Array) -> int:
	var m: int = 0
	for id in ids:
		m |= 1 << IDS.find(id)
	return m


## How much more the movement favours d as the Demon over e, with f the minion (or the
## given partner).
func _lean(view: Dictionary, cards: Array, partner: String = "f") -> float:
	var fs: Array = LiveActivity.factors(view, cards, {})
	if fs.is_empty():
		return -1.0
	var wd: Dictionary = {"evil": _mask(["d", partner]), "demon": IDS.find("d")}
	var we: Dictionary = {"evil": _mask(["e", partner]), "demon": IDS.find("e")}
	return LiveActivity.score(wd, fs[0]) / LiveActivity.score(we, fs[0])


func _run() -> void:
	var seen: Dictionary = _sighting("d", 1, "docks")
	var quiet: Dictionary = _view()
	var base: float = _lean(quiet, [seen])
	var guarded: float = _lean(quiet, [seen, _guard("t")])
	_check(base > 0.0 and guarded > base * 1.2, "seen on the guarded door's block on a quiet night: the guard makes d likelier the Demon (%.3f -> %.3f)" % [base, guarded])
	var fs: Array = LiveActivity.factors(quiet, [seen, _guard("t")], {})
	_check(not fs.is_empty() and fs[0].has("guards") and is_equal_approx(float(fs[0].guards.items[0].r), Tuning.Roles.WARDEN_SAVE_RELIABILITY), "the guard holds at a claimed save's reliability")
	# Elsewhere: d seen on another block that night counts against d once the Demon went to the docks.
	var away: Dictionary = _sighting("d", 1, "square")
	_check(_lean(quiet, [away, _guard("t")]) < _lean(quiet, [away]), "seen on another block on that night: the guard makes d less likely the Demon")
	# Worlds where the guard can't have held.
	_check(is_equal_approx(_lean(quiet, [seen, _guard("t")], "a"), _lean(quiet, [seen], "a")), "an evil Warden's guard says nothing of the Demon's route")
	_check(is_equal_approx(_lean(quiet, [seen, _guard("t")], "t"), _lean(quiet, [seen], "t")), "nor a guard of an evil door: the Demon goes for the good")
	# Nights it doesn't apply.
	var killed: Dictionary = _view(1)
	var kf: Array = LiveActivity.factors(killed, [seen, _guard("t")], {})
	_check(not kf.is_empty() and not kf[0].has("guards"), "a night with a Demon kill isn't quiet: no guard route")
	_check(not LiveActivity.factors(quiet, [seen, _guard("t", 0)], {})[0].has("guards"), "no guard on night 0")
	# An unclaimed save reads the same; a Veteran claim shares the quiet.
	var plain: Array = LiveActivity.factors(quiet, [seen, _guard("t", 1, false)], {})
	_check(plain[0].has("guards"), "a guard report without a claimed save still counts on a quiet night")
	var vet: Dictionary = {"id": "vet", "fact_id": "vet", "kind": "claim", "source": "h", "subject": "h", "role": "veteran", "night": -1, "data": {}, "observed_at": {"day": 1, "phase": "morning"}}
	var vf: Array = LiveActivity.factors(quiet, [seen, _guard("t"), vet], {})
	_check(vf[0].has("guards") and is_equal_approx(float(vf[0].guards.items[0].r), Tuning.Roles.WARDEN_SAVE_RELIABILITY / 2.0), "a living Veteran claimant halves it (%.3f)" % float(vf[0].guards.items[0].r))
	# The diagnostic switch.
	LiveActivity.quiet_guards_enabled = false
	var off: float = _lean(quiet, [seen, _guard("t")])
	LiveActivity.quiet_guards_enabled = true
	_check(is_equal_approx(off, base), "with the switch off, the guard leaves the route alone")
	_listener_doubt(quiet, seen)
	_codex_243(seen)
	_juror()
	print("Warden quiet route: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails else 0)


## Through the game and the Test juror: a case citing a sighting near the guarded door, with
## and without the Warden's report of the save.
func _juror() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(4460, 7)
	var w = g.w
	var demon = w.by_id[w.demon_id]
	var goods: Array = w.living_good()
	var target = null
	for n in goods:
		if n.home_block != demon.home_block:
			target = n
			break
	var warden = goods.filter(func(n): return n != target)[0]
	var witness = goods.filter(func(n): return n != target and n != warden)[0]
	w.day = 2
	g.add_card({"kind": "sighting", "subject": [demon.id], "block": target.home_block, "source": witness.id, "day": 1, "phase": C.NIGHT, "text": "Night 1 sighting: %s saw %s on %s." % [witness.name, demon.name, C.block_name(target.home_block)]})
	g.add_card({"kind": "info", "source": warden.id, "role": "warden", "day": 1, "phase": C.NIGHT, "data": {"target": target.id, "saved": true}, "text": "%s guarded %s's door on night 1 and turned the Demon away." % [warden.name, target.name]})
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	var seen_id: String = _node(model, view, func(c): return c.get("text", "").begins_with("Night 1 sighting"))
	var guard_id: String = _node(model, view, func(c): return c.get("kind", "") == "report" and c.get("role", "") == "warden")
	_check(seen_id != "" and guard_id != "", "the sighting and the Warden's report reach the Workshop (%s, %s)" % [seen_id, guard_id])
	if seen_id == "" or guard_id == "":
		return
	var premise = model.add_premise(demon.id, "evil", Vector2(0, 0))
	model.connect_cards(seen_id, premise)
	var without = Live.test_juror(g, model.compile(premise))
	model.connect_cards(guard_id, premise)
	var with_guard = Live.test_juror(g, model.compile(premise))
	# The compiled-case and factor keys carry the switch, so no cache needs clearing.
	LiveActivity.quiet_guards_enabled = false
	var off = Live.test_juror(g, model.compile(premise))
	LiveActivity.quiet_guards_enabled = true
	_check(with_guard.get("ready", false), "a case citing the guard can be judged (%s)" % str(with_guard.get("issues", [])))
	_check(with_guard.get("lr", 1.0) > without.get("lr", 1.0) * 1.05, "seen near the guarded door weighs more with the Warden's save (%.2f -> %.2f)" % [without.get("lr", 1.0), with_guard.get("lr", 1.0)])
	_check(off.get("lr", 1.0) < with_guard.get("lr", 1.0), "and the rise is the guard's route (%.2f with the switch off)" % off.get("lr", 1.0))
	var gr: Array = with_guard.get("guards", [])
	_check(gr.size() == 1 and gr[0].warden == warden.id and gr[0].guarded == target.id and gr[0].night == 1 and gr[0].report != "" and float(gr[0].shift) > 0.0,
		"the juror names the guard as a reason: Warden, guarded, night, card (%s)" % str(gr))
	_check(not without.has("guards"), "and doesn't without the Warden's report")


func _node(model, view, pick: Callable) -> String:
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and pick.call(Solver.card_by_id(view, nd.card)):
			return id
	return ""


## The listener's doubt of the Warden cuts the route too, not only the report's role check
## (Michael, Nov 18): its honest doubt of the reading, or a challenge that holds.
func _listener_doubt(quiet: Dictionary, seen: Dictionary) -> void:
	var guard: Dictionary = _guard("t")
	var half: Array = CaseEval._route_trusted([seen, guard], {"reading_doubt": {"guard": 0.5}})
	var hf: Array = LiveActivity.factors(quiet, half, {})
	_check(hf[0].has("guards") and is_equal_approx(float(hf[0].guards.items[0].r), Tuning.Roles.WARDEN_SAVE_RELIABILITY * 0.5), "an honest doubt of one half halves the route (%.3f)" % float(hf[0].guards.items[0].r))
	var none: Array = CaseEval._route_trusted([seen, guard], {"challenge_sources": {"a": 0.0}})
	_check(is_equal_approx(_lean(quiet, none), _lean(quiet, [seen])), "a challenge that sets the Warden's word aside leaves the route alone")
	_check(CaseEval._route_trusted([seen, guard], {}) == [seen, guard], "a listener with no doubt reads the cards as they are")
	# Through the judge: the subject's chance with the guard, with half doubt, and without.
	var view: Dictionary = quiet.duplicate(true)
	view.cards = [seen, guard]
	var value: Dictionary = Solver.empty_case()
	value.conclusion = {"type": "evil", "target": "d", "at": view.alignment_epoch}
	value.cards = ["s-d", "guard"]
	var trusting: Dictionary = CaseEval.evaluate(view, value, {"id": "x", "knowledge": {"good": [], "evil": []}})
	var doubting: Dictionary = CaseEval.evaluate(view, value, {"id": "x", "knowledge": {"good": [], "evil": []}, "reading_doubt": {"guard": 0.5}})
	LiveActivity.quiet_guards_enabled = false
	var bare: Dictionary = CaseEval.evaluate(view, value, {"id": "x", "knowledge": {"good": [], "evil": []}})
	LiveActivity.quiet_guards_enabled = true
	var p_t: float = float(trusting.get("people", {}).get("d", {}).get("posterior", -1.0))
	var p_d: float = float(doubting.get("people", {}).get("d", {}).get("posterior", -1.0))
	var p_b: float = float(bare.get("people", {}).get("d", {}).get("posterior", -1.0))
	_check(p_b >= 0.0 and p_t > p_d and p_d > p_b, "the judge: the subject's chance is highest trusting the Warden, lower doubting, lowest without the route (%.3f, %.3f, %.3f)" % [p_t, p_d, p_b])


## Codex on #243: the Scion succession branches carry the guards too, and the Test juror
## credits each guard with its own effect, not the guards' together.
func _codex_243(seen: Dictionary) -> void:
	var hanged: Dictionary = _view()
	hanged.timeline = History.from_events([{"kind": "execution", "subjects": ["h"], "at": {"day": 2, "phase": "evening"}}])
	var f: Array = LiveActivity.factors(hanged, [seen, _guard("t")], {})
	var splits: Array = f[0].get("scion_splits", []) if not f.is_empty() else []
	_check(not splits.is_empty() and splits[0].get("pre_guard_alt", []).size() == 1 and splits[0].get("post_guard_alt", []).size() == 1,
		"a possible Scion succession: both sides of the split carry the guard (%d splits)" % splits.size())
	# Two guards, the second on a night nothing places anyone: only the first moves the case.
	var quiet: Dictionary = _view()
	var g2: Dictionary = {"id": "guard2", "fact_id": "guard2", "kind": "report", "source": "h", "role": "warden", "night": 2, "block": "square",
		"data": {"target": "f"}, "observed_at": {"day": 2, "phase": "night"}}
	var view: Dictionary = quiet.duplicate(true)
	view.cards = [seen, _guard("t"), g2]
	var value: Dictionary = Solver.empty_case()
	value.conclusion = {"type": "evil", "target": "d", "at": view.alignment_epoch}
	value.cards = ["s-d", "guard", "guard2"]
	var ev: Dictionary = CaseEval.evaluate(view, value)
	var result: Dictionary = {}
	Live.guard_reasons(view, value, ev, result)
	var listed: Array = result.get("guards", []).map(func(g): return g.report)
	_check(listed == ["guard"], "two guards: the juror names only the one that moved the subject (%s)" % str(listed))
	_check(LiveActivity.quiet_guards_enabled and LiveActivity.quiet_guards_skip.is_empty(), "and puts the switch and the skip list back")
	# Four guards on four nights: the cap keeps the latest three, and leaving one of them out
	# doesn't let the fourth back in.
	var four: Array = []
	for nt in [1, 2, 3, 4]:
		four.append({"id": "q%d" % nt, "fact_id": "q%d" % nt, "kind": "report", "source": "a", "role": "warden", "night": nt, "block": "docks",
			"data": {"target": "t"}, "observed_at": {"day": nt, "phase": "night"}})
	var kept: Array = LiveActivity.quiet_guard_cards(quiet, four).map(func(g): return g.report)
	LiveActivity.quiet_guards_skip = ["q4"]
	var left: Array = LiveActivity.quiet_guard_cards(quiet, four).map(func(g): return g.report)
	LiveActivity.quiet_guards_skip = []
	_check(kept == ["q4", "q3", "q2"] and left == ["q3", "q2"], "the cap keeps the latest three; leaving one out doesn't admit the fourth (%s, %s)" % [str(kept), str(left)])
	# A contested sighting (an NPC witness who may have invented it): the branch where the
	# witness lied keeps the guard's evidence from the honest sighting elsewhere.
	var honest_away: Dictionary = _sighting("d", 1, "square")
	var told: Dictionary = {"id": "told", "fact_id": "told", "kind": "sighting", "source": "g", "subject": "d", "subjects": ["d"],
		"night": 1, "block": "docks", "data": {}, "role": "", "observed_at": {"day": 1, "phase": "night"}}
	var cf: Array = LiveActivity.factors(quiet, [honest_away, told, _guard("t")], {})
	var cts: Array = cf[0].get("contests", []) if not cf.is_empty() else []
	_check(not cts.is_empty() and cts[0].subsets[0].has("guard_alt") and cts[0].subsets[0].guard_alt.size() == 1,
		"a contested sighting's alternative carries the guard too (%s)" % str(cts.map(func(c): return c.person)))
	_check(_lean(quiet, [honest_away, told, _guard("t")], "g") < _lean(quiet, [honest_away, told], "g"),
		"where the witness is evil, the honest sighting away from the guarded door still counts against d")
	# A converted Warden (the Revenant's curse from the third night): good on the first night,
	# so their first-night guard still holds in the world where they're the converted person.
	var cursed: Dictionary = _view()
	cursed["chronology"] = {"curse": {"from": 3 * 4, "until": 99}}
	var wd: Dictionary = {"evil": _mask(["d", "f"]), "demon": IDS.find("d"), "converted": IDS.find("a")}
	var we: Dictionary = {"evil": _mask(["e", "f"]), "demon": IDS.find("e"), "converted": IDS.find("a")}
	var fg: Array = LiveActivity.factors(cursed, [seen, _guard("t")], {})
	var fn: Array = LiveActivity.factors(cursed, [seen], {})
	if not fg.is_empty() and not fn.is_empty():
		var conv_g: float = LiveActivity.score(wd, fg[0]) / LiveActivity.score(we, fg[0])
		var conv_n: float = LiveActivity.score(wd, fn[0]) / LiveActivity.score(we, fn[0])
		_check(conv_g > conv_n * 1.2, "a Warden converted only later: their earlier guard still holds (%.3f -> %.3f)" % [conv_n, conv_g])
	else:
		_check(false, "the cursed view gives a movement factor")
	# Two Wardens on the same quiet night at different doors: at most one held, and which
	# claimant is which doesn't matter (a and h both live on the hill).
	var ga: Dictionary = _guard("t")
	var gh: Dictionary = {"id": "gh", "fact_id": "gh", "kind": "report", "source": "h", "role": "warden", "night": 1, "block": "square",
		"data": {"target": "g"}, "observed_at": {"day": 1, "phase": "night"}}
	var ga2: Dictionary = ga.duplicate(true)
	ga2.data.target = "g"
	ga2.block = "square"
	var gh2: Dictionary = gh.duplicate(true)
	gh2.data.target = "t"
	gh2.block = "docks"
	var both: float = _lean(quiet, [seen, ga, gh], "f")
	var swapped: float = _lean(quiet, [seen, ga2, gh2], "f")
	var one: float = _lean(quiet, [seen, ga], "f")
	var bare: float = _lean(quiet, [seen], "f")
	_check(is_equal_approx(both, swapped), "two guards on one night: who guarded which door doesn't change the weighing (%.4f, %.4f)" % [both, swapped])
	_check(both > bare and both < one, "and the rival door draws some of the Demon's route (%.3f < %.3f < %.3f)" % [bare, both, one])
