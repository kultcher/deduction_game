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
