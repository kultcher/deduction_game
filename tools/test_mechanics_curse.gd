extends SceneTree
const History = preload("res://workshop/live_history.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Solver = preload("res://workshop/solver.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _init() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square", "alive": id != "b"})
	var events = [
		{"kind": "demon_death", "subjects": ["c"], "at": {"day": 1, "phase": "night"}},
		{"kind": "vote", "subjects": ["g"], "at": {"day": 2, "phase": "evening"}, "data": {"nominee": "g", "yes": ["a", "b", "c"], "outcome": "on_block"}},
		{"kind": "execution", "subjects": ["g"], "at": {"day": 2, "phase": "evening"}},
		{"kind": "curse", "subjects": ["g"], "by": "g", "at": {"day": 2, "phase": "evening"}}]
	var now = {"day": 3, "phase": "night"}
	var history = History.chronology(events, people, now)
	check(history.issues.is_empty() and history.value.curse.yes_voters == ["a", "b"], "eligibility uses alive-at-curse history, not today's alive flags")
	check(History.chronology([], people, now).value.is_empty(), "no curse allocates no chronology domain")
	check(not History.chronology(events.filter(func(e): return e.kind != "vote"), people, now).issues.is_empty(), "missing public vote is an explicit history gap")
	var view = {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Current alignment", "world_options": {"modifiers": ["marked", "delusional"], "roles": true, "identities": true}, "chronology": history.value, "timeline": History.from_events(events)}
	var universe: Array = Solver.universe(view)
	check(not universe.is_empty() and universe.all(func(w): return w.converted in [0, 1] and (w.evil & (1 << 6)) != 0 and not (w.evil & (1 << w.converted))), "only originally good eligible voters can turn; activation identifies the executed Revenant")
	var keys = {}
	var aligned = true
	for i in range(universe.size()):
		keys[universe[i].__key] = true
		aligned = aligned and universe[i].__i == i
	check(keys.size() == universe.size() and aligned, "expanded worlds retain unique integer keys and table indices")
	var listener = Eval.neutral_listener(view)
	listener.knowledge = {"good": ["a"], "good_epoch": "Current alignment"}
	var value = Solver.empty_case()
	value.conclusion = {"type": "evil", "target": "b", "at": "Current alignment"}
	var during = Eval.evaluate(view, value, listener)
	value.conclusion.at = "Original alignment"
	var before = Eval.evaluate(view, value, listener)
	check(not during.impossible and is_equal_approx(during.posterior, 1.0) and is_zero_approx(before.posterior), "current self-knowledge forces the other eligible voter evil now, but good before the curse")
	var report = {"id": "before", "kind": "report", "source": "a", "role": "dowser", "night": -1, "observed_at": {"day": 1, "phase": "morning"}, "data": {"group": ["d"], "count": 0}}
	var early: PackedByteArray = Solver.valid_table(view, report)
	report = report.duplicate(true)
	report.id = "during"
	report.observed_at = {"day": 3, "phase": "morning"}
	var late: PackedByteArray = Solver.valid_table(view, report)
	var valid = true
	var changed = 0
	for i in range(universe.size()):
		valid = valid and (late[i] != 0) == Solver.source_valid(view, universe[i], report)
		if universe[i].converted == 0 and early[i] != 0:
			changed += 1
			valid = valid and late[i] == 0
	check(valid and changed > 0, "reading validity changes only at the source's alignment boundary and matches scalar checks")
	var lifted: Array = events + [{"kind": "curse_lifted", "subjects": ["town"], "at": {"day": 4, "phase": "afternoon"}}]
	var restored = view.duplicate(true)
	restored.chronology = History.chronology(lifted, people, {"day": 5, "phase": "morning"}).value
	var world: Dictionary = Solver.universe(restored).filter(func(w): return w.converted == 0)[0]
	check(not TimeModel.evil_at(restored, world, "a", "Original alignment") and TimeModel.evil_at(restored, world, "a", "during curse") and not TimeModel.evil_at(restored, world, "a", "Current alignment"), "lifting restores original alignment without rewriting earlier evidence")
	var factor = {"profiles": [{"good": 1.0, "minion": 2.0, "demon": 3.0, "converted": 5.0}]}
	check(Activity.score({"evil": 0, "converted": 0}, factor) == 5.0, "movement selects the bounded time-varying turnee profile")
	value.conclusion = {"type": "evil", "target": "b", "at": "Current alignment"}
	listener["id"] = "a"
	listener["npc_trust"] = {}
	listener["trust"] = 0.5
	var searched = Reasoner._find_live(view, [], value, listener, 10000, true, {}, {})
	check(not searched.world.is_empty() and searched.world.get("converted", -1) == 1, "bounded reply searches the same public turnee domain")
	_live()
	print("Curse mechanics: %d checks; failures: %d" % [checks, fails])
	quit(1 if fails else 0)

func _live() -> void:
	var g = Game.new()
	g.new_case(54875, 10)
	g.w.dlog.detailed = false
	var rv = g.w.npcs.filter(func(n): return n.role == "revenant")[0]
	var voters: Array = g.w.living_good().slice(0, 3).map(func(n): return n.id)
	var observer = g.w.living_good().filter(func(n): return n.id not in voters)[0]
	g.w.day = 2
	g.w.phase = 2
	g.w.public_event("vote", [rv.id], "town", {"nominee": rv.id, "nominator": "player", "yes": voters, "no": [], "player_yes": false, "count": 3, "threshold": 3, "outcome": "on_block"})
	rv.alive = false
	g.add_card({"kind": "execution", "source": "player", "subject": [rv.id], "day": 2, "phase": 2, "alive_before": 10, "text": "Public execution."})
	g.w.totem = {"block": "square"}
	rv.poisoned = false
	g.w._revenant_curse(rv, {"yes": voters})
	g.add_card({"kind": "curse", "source": "player", "subject": [rv.id], "day": 2, "phase": 2, "text": "Public curse."})
	observer.info_log = []
	observer.known_claims = {}
	observer.ledger = {}
	var effects: Array = []
	for person in voters:
		Mind._eff(effects, person, 0.15, "voted to hang the Revenant")
	Mind.ledger_hear(g.w, observer, "curse:2", effects, 1.0, [], {"kind": "event"})
	var captured = Bridge.capture(g, [], observer.id)
	var plan = Shared.prepare(captured, {}, observer.ledger)
	check(plan.ready and not plan.empty and plan.owned.has("curse:2"), "a public curse is assessed with no cited reading and parks its native voter bump: " + str(plan.issues))
	check(observer.workshop_state.get("active", false) and not observer.workshop_state.get("reasoning", {}).get("impossible", true), "live curse refresh succeeds without an impossible state")
	var old_victim = g.w.curse.victim
	g.w.curse.victim = voters[1] if old_victim != voters[1] else voters[0]
	check(Bridge.capture(g, [], observer.id) == captured, "changing only the referee's chosen turnee cannot change assessment inputs")
	g.w.curse.victim = old_victim
	var withdrawn = {"role": g.w.by_id[old_victim].role, "day": 2, "phase": 3, "data": {}, "text": "Withdrawn turned testimony", "fake": true}
	g.w.by_id[old_victim].info_log.append(withdrawn)
	g.w.day = 3
	g.w.phase = 1
	g.w.free_turned()
	Mind.recompute_beliefs(g.w, observer, " (curse restoration test)")
	plan = Shared.prepare(Bridge.capture(g, [], observer.id), {}, observer.ledger)
	check(plan.ready and plan.prepared.view.chronology.curse.until == 13, "actual public restoration closes the epoch at its observed phase")
	var own = Bridge.capture(g, [], old_victim)
	check(not own.listener.disowned_reports.is_empty() and own.private_evidence.all(func(id): return id not in own.listener.disowned_reports), "a restored listener's disowned testimony is not firsthand evidence")
