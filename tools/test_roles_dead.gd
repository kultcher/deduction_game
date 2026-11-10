## Gifts of the dead (hint package 'the_dead'): Gravedigger, Medium, Sexton, Martyr, Executor.
## Merged from: test_chunk3_executor_registrar, test_chunk6a_sexton_brute, test_roster, test_workshop_martyr_sexton, test_workshop_medium.
extends SceneTree

const Game = preload("res://game/game.gd")
const World = preload("res://sim/world.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Support = preload("res://workshop/support_model.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Evil = preload("res://sim/evil.gd")
const Factored = preload("res://workshop/factored_channels.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Caches = preload("res://workshop/caches.gd")
const Oracle = preload("res://workshop/channel_likelihood.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_roster()
	_run_workshop_medium()
	_run_workshop_martyr_sexton()
	_run_chunk6a_sexton_brute()
	_run_chunk3_executor_registra()
	print("Roles: the dead: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## One shared check helper (the merged suites used both names).
func check(ok: bool, label: String) -> void:
	_count(ok, label)


func _check(ok: bool, label: String) -> void:
	_count(ok, label)


func _count(ok: bool, label: String) -> void:
	checks += 1
	_checks += 1
	if not ok:
		fails += 1
		failures += 1
		_fails += 1
		printerr("FAIL: " + label)


# ---------------------------------------------------------------- from test_roster

func _run_roster() -> void:
	_test_martyr_save()
	_test_martyr_evil()
	_test_sexton()
	_test_medium_priority()


# ---------------------------------------------------------------- from test_workshop_medium

func _run_workshop_medium() -> void:
	_run()


# ---------------------------------------------------------------- from test_workshop_martyr_sexton

func _run_workshop_martyr_sexton() -> void:
	_constraints()
	_live()


# ---------------------------------------------------------------- from test_chunk6a_sexton_brute

func _run_chunk6a_sexton_brute() -> void:
	_test_sexton_registration_and_attributes()
	_test_sexton_lamplighter_walk_on_toll()
	_test_sexton_minion_suppression()
	_test_sexton_townsfolk_gifts_unaffected()
	_test_sexton_once_per_case()
	_test_sexton_bell_stops_breathstealer()
	_test_sexton_honest_about_toll_night()


# ---------------------------------------------------------------- from test_chunk3_executor_registrar

func _run_chunk3_executor_registra() -> void:
	_test_executor_sim()
	_test_executor_workshop_and_parity()


# ---- test_roster


## Pure World setup for multi-hundred-seed role/home/bluff distribution checks.
func _game(sd: int, size: int = 7):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


func _give(w, n, role: String) -> void:
	var holder = w.npc_with_role(role)
	if holder != null and holder != n:
		holder.role = n.role
	n.role = role


func _test_martyr_save() -> void:
	var gm = _game(9100)
	var w = gm.w
	w.day = 2
	var goods: Array = w.living_good()
	var mart = goods[0]
	var target = goods[1]
	_give(w, mart, "martyr")
	mart.secret_mod = ""
	mart.poisoned = false
	mart.martyr_target = target.id
	w.begin_meeting()
	w.execute(target.id, {"by": "player", "yes": [], "player_yes": true})
	_check(target.alive and not mart.alive and mart.death_cause == "martyr", "the Martyr dies in a good target's place")
	var l = w.living_good().filter(func(x): return x != target)[0]
	_check(l.cleared.has(target.id) and l.cleared.has(mart.id) and Mind.susp(l, target.id) < 0.05, "the town knows both are good")
	_check(not w.game_over or w.winner != "good", "the case goes on")


func _test_martyr_evil() -> void:
	var w = _game(9101).w
	w.day = 2
	var mart = w.living_good()[0]
	_give(w, mart, "martyr")
	mart.secret_mod = ""
	mart.poisoned = false
	var ev = w.minions()[0]
	mart.martyr_target = ev.id
	w.begin_meeting()
	w.execute(ev.id, {"by": "player", "yes": [], "player_yes": true})
	var last: Dictionary = mart.info_log.back() if not mart.info_log.is_empty() else {}
	_check(not ev.alive and mart.alive and last.get("data", {}).get("evil", false), "an evil target hangs; the surviving Martyr learns they were evil")


func _test_sexton() -> void:
	var tolled = 0
	var killed_on_knell = 0
	for sd in range(9140, 9160):
		var w = _game(sd).w
		var sx = w.living_good()[0]
		_give(w, sx, "sexton")
		w.day = 3
		var goods: Array = w.living_good().filter(func(x): return x != sx)
		goods[0].alive = false
		goods[1].alive = false
		goods[2].alive = false
		var poisoner = w.living_with_role("poisoner")
		w.resolve_night()
		if w.sexton_suppression_night == 3:
			tolled += 1
			# Nov 5 rework: the bell walks every parish and suppresses minions (no poison lands),
			# but the Demon still hunts.
			if poisoner != null and w.npcs.any(func(p): return p.poisoned):
				killed_on_knell += 1
	print("bell tolled in %d/20; poison landed anyway in %d" % [tolled, killed_on_knell])
	_check(tolled > 0 and killed_on_knell == 0, "the Sexton's bell suppresses the Poisoner that night")


func _test_medium_priority() -> void:
	var w = _game(9180).w
	var m = w.living_good()[0]
	_give(w, m, "medium")
	var dead = w.living_good()[1]
	dead.alive = false
	dead.death_day = 1
	dead.death_cause = "demon"
	dead.info_log = []
	dead.beliefs = []
	dead.info_log.append({"day": 0, "role": "seer", "data": {"pair": [w.demon_id, m.id], "yes": true}, "text": "I looked: one is the demon", "shared": false, "true": true})
	dead.beliefs.append({"kind": "saw", "who": w.demon_id, "loc": "", "block": "hill", "day": 1, "phase": C.NIGHT})
	var it1 = w._medium_item(m, dead, false)
	var it2 = w._medium_item(m, dead, false)
	_check(it1["type"] == "reading" and it2["type"] == "sighting", "the Medium hears unshared readings first, then night sightings")


# ---- test_workshop_medium


func _run() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	var medium = g.w.npcs[0]
	var dead = g.w.npcs[1]
	var pair: Array = g.w.npcs.filter(func(n): return n != medium and n != dead).slice(0, 2).map(func(n): return n.id)
	g.add_card({"kind": "death", "source": "player", "subject": [dead.id], "night": 1, "text": "Public death"})
	var entry = {"role": "seer", "day": 0, "data": {"pair": pair, "yes": true}, "text": "Original Seer reading", "why": "HIDDEN CAUSE", "true": false, "fake": true}
	var number = g.add_card({"kind": "info", "source": medium.id, "subject": [], "role": "medium", "day": 2, "phase": 3,
		"data": {"dead": dead.id, "item": {"type": "reading", "entry": entry, "lie": true}}, "text": "Medium repeats dead Seer"})
	var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
	var view = Live.view(g)
	var card = Solver.card_by_id(view, id)
	check(card.role == "seer" and card.source == dead.id and card.relay_source == medium.id, "relay retains original evaluator and both speakers")
	check(card.observed_at.day == 0 and card.relay_observed_at.day == 2, "original reading and Medium acquisition keep distinct times")
	var serialized = JSON.stringify(Live.Evidence.normalize_card(g.board[number - 1]))
	check(not serialized.contains("HIDDEN CAUSE") and not serialized.contains('"fake"') and not serialized.contains('"lie"'), "nested referee cause fields do not cross the evidence boundary")
	var board = Canvas.new(view)
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "evil", "target": pair[0], "at": "Original alignment"}
	board.connect_cards("e:" + id, root)
	var value = board.compile(root)
	check(Live.status(g, value).ready, "supported Medium reading uses live evaluator")
	var prepared = Live.Assess.prepare(_ghost_input(g, value))
	check(prepared.ready, "Medium source knowledge is complete for neutral assessment")
	var listener = Ghost.profile(prepared.view.people)
	var attention = preload("res://workshop/reasoner.gd").prepare(prepared.view, prepared.case, listener)
	var mixture = Support._mixture(prepared.view, attention.case, listener, attention, false, {})
	check(mixture.atoms.any(func(a): return a.key == "source:" + medium.id) and mixture.atoms.any(func(a): return a.key == "source:" + dead.id), "credibility distinguishes Medium transmission from original speaker")
	var preview = Ghost.live(Live.snapshot(g, value))
	check(preview.ready, "Medium gets neutral preview")
	var full = Support.assess(prepared.view, prepared.case, listener)
	listener.npc_trust[medium.id] = 0.0
	var distrusted = Support.assess(prepared.view, prepared.case, listener)
	check(distrusted.report_acceptance[id] < full.report_acceptance[id], "distrusting Medium lowers relay acceptance")
	listener.npc_trust[medium.id] = 0.5
	listener.npc_trust[dead.id] = 0.0
	distrusted = Support.assess(prepared.view, prepared.case, listener)
	check(distrusted.report_acceptance[id] < full.report_acceptance[id], "distrusting original source also lowers relay acceptance")
	var original = Live.Evidence.normalize_card({"kind": "info", "source": dead.id, "subject": [], "role": "seer", "day": 0, "phase": 3, "data": entry.data, "text": entry.text})
	var direct = card.duplicate(true)
	for key in ["relay_source", "relay_observed_at", "relay_role", "logical_origin", "accuracy_origin"]:
		direct.erase(key)
	direct.id = original.id
	direct.fact_id = original.id
	check(Support._contributing(prepared.view, [card, direct]).size() == 1, "relay and direct copy count as one original reading")
	var direct_number = g.add_card({"kind": "info", "source": dead.id, "subject": [], "role": "seer", "day": 0, "phase": 3, "data": entry.data, "text": entry.text})
	var combined = Canvas.new(Live.view(g))
	combined.nodes[combined.selected].conclusion = value.conclusion.duplicate(true)
	combined.connect_cards("e:" + id, combined.selected)
	combined.connect_cards("e:" + Live.Evidence.normalize_card(g.board[direct_number - 1]).id, combined.selected)
	var combined_input = _ghost_input(g, combined.compile(combined.selected))
	var combined_prepared = Live.Assess.prepare(combined_input)
	check(combined_prepared.ready, "direct reading and Medium copy can share a live case")
	var combined_cards: Array = combined_prepared.view.cards
	check(combined_cards.size() == 2 and combined_cards[0].accuracy_origin == combined_cards[1].accuracy_origin and combined_cards[0].accuracy_origin.begins_with("health:"), "original health is shared separately from receipt route weights")
	var comparison_listener = Ghost.profile(combined_prepared.view.people)
	comparison_listener.knowledge.good = [medium.id]
	var both = Support.assess(combined_prepared.view, combined_prepared.case, comparison_listener)
	var direct_only = combined_prepared.case.duplicate(true)
	direct_only.cards = [original.id]
	direct_only.lines = []
	var just_original = Support.assess(combined_prepared.view, direct_only, comparison_listener)
	check(is_equal_approx(both.agreement, just_original.agreement), "a faithful relay does not corroborate an already-present identical original")
	var wrapped = combined_cards.filter(func(c): return c.has("relay_source"))[0]
	var index: int = combined_prepared.view.people.map(func(p): return p.id).find(medium.id)
	var possible = Solver.solve(combined_prepared.view, [], {medium.id: "good", dead.id: "good"}).worlds
	var evil_free: Dictionary = possible[0].duplicate(true)
	evil_free.modifier = "delusional"
	evil_free.marked = -1
	evil_free.holders = 1 << index
	check(not Solver.Roles.fits(combined_prepared.view, evil_free, [wrapped], {}), "Delusional Medium cannot supply a healthy transmission")
	evil_free.holders = 1 << combined_prepared.view.people.map(func(p): return p.id).find(pair[0])
	Solver.Roles.reuse = false
	var uncached = Solver.Roles.fits(combined_prepared.view, evil_free, [wrapped], {})
	Solver.Roles.reuse = true
	check(Solver.Roles.fits(combined_prepared.view, evil_free, [wrapped], {}) == uncached, "relay health cache distinguishes Delusional holder assignments")
	var filed = Live.file(g, value)
	check(filed > 0, "Medium filing preserves original outer receipt")
	var npc = g.w.living_good().filter(func(n): return n != medium and n != dead)[0]
	npc.info_log = []
	npc.known_claims = {}
	npc.ledger = {}
	npc.beliefs = []
	npc.role = "warden"
	npc.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	var response = g._evaluate_deduction(npc, g.board[filed - 1], 1.0)
	check(response.get("workshop", false), "Medium presentation reaches shared owner")
	var before: Dictionary = npc.workshop_state.get("requested", {}).duplicate(true)
	response = g._evaluate_deduction(npc, g.board[filed - 1], 1.0)
	check(response.get("repeated", false) and npc.workshop_state.get("requested", {}) == before, "Medium repeat does not stack")
	check(board.add_modifier("e:" + id, "lying") != "", "ambiguous relay blame cannot silently accuse the wrong speaker")
	var alive_input = _ghost_input(g, value)
	alive_input.public_events = []
	var unverified = Live.Assess.prepare(alive_input)
	check(unverified.ready and unverified.view.cards.any(func(c): return c.get("testimony_only", false) and not c.has("relay_source")), "without public death timing the Medium supplies weak teller testimony, not a verified relay")
	var nested = g.board[number - 1].duplicate(true)
	nested.data.item.entry.role = "medium"
	var nested_receipt = Live.Evidence.normalize_card(nested)
	check(Live.Assess.medium_card(nested_receipt, _ghost_input(g, value)).is_empty(), "nested Medium chains explicitly remain unsupported")
	var second = g.board[number - 1].duplicate(true)
	second.data = {"dead": dead.id, "item": {"type": "sighting", "who": pair[0], "block": "square", "night": 1}}
	var sight = Live.Assess.medium_card(Live.Evidence.normalize_card(second), _ghost_input(g, value))
	check(not sight.is_empty() and sight.kind == "sighting" and sight.night == 1, "Medium sighting inherits the original night and movement logic")
	var opinion = Live.Evidence.normalize_card({"kind": "info", "source": npc.id, "subject": [], "role": "medium", "day": 2, "phase": 3, "data": {"dead": dead.id, "item": {"type": "suspicion", "about": pair[0]}}, "text": "Unsupported private opinion"})
	check(not preload("res://workshop/shared_ledger.gd").supported(opinion), "Medium opinions remain outside alignment evidence")
	var independent = _ghost_input(g, value)
	independent.evidence.append(opinion)
	independent.private_evidence.append(opinion.id)
	check(Live.Assess.prepare(independent).ready, "independent unsupported private Medium knowledge does not block a supported case")


func _ghost_input(g, value: Dictionary) -> Dictionary:
	var input = Live.snapshot(g, value)
	var ghost = Ghost.profile(input.people)
	input.listener = {"id": ghost.id, "name": ghost.name, "trust": 0.5, "confidence": 0.5, "insight": 0.5, "npc_trust": ghost.npc_trust, "suspicion": ghost.suspicion, "discounted": {}, "own_gift": ""}
	return input


# ---- test_workshop_martyr_sexton


func _report(id: String, source: String, role: String, data: Dictionary, night: int) -> Dictionary:
	return {"id": id, "kind": "report", "source": source, "role": role, "night": night, "data": data, "observed_at": {"day": night, "phase": "night"}}


func _constraints() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square"})
	var view = {"people": people, "cards": [], "day": 3, "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": {"events": [], "deaths": {}}, "world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}
	var world = {"evil": 96, "demon": 5, "marked": 4, "modifier": "marked", "holders": 16}
	var chosen = _report("chosen", "a", "martyr", {"target": "f", "chosen": true}, 1)
	check(Solver.Roles.fits(view, world, [chosen], {}), "a Martyr's choice does not establish that chosen person is good")
	var other = chosen.duplicate(true)
	other.data.target = "d"
	check(not Solver.Roles.fits(view, world, [chosen, other], {}), "one Martyr cannot truthfully claim two choices")
	var outcome = _report("outcome", "a", "martyr", {"target": "e", "evil": true}, 2)
	check(not Solver.Roles.fits(view, world, [outcome], {}), "Martyr outcome needs a matching public execution")
	view.timeline["executions"] = {"2": ["e"]}
	check(Solver.Roles.fits(view, world, [outcome], {}), "healthy Martyr's evil-registration outcome permits Marked")
	outcome.data.target = "d"
	view.timeline.executions["2"] = ["d"]
	check(not Solver.Roles.fits(view, world, [outcome], {}), "ordinary good cannot explain healthy evil-registration outcome")
	outcome.data.target = "g"
	view.timeline.executions["2"] = ["g"]
	check(Solver.Roles.fits(view, world, [outcome], {}), "evil chosen target explains failure to substitute")
	var substitution = {"id": "public", "kind": "event", "event": "martyr", "source": "player", "data": {"martyr": "a", "saved": "b"}}
	check(Solver.Roles.fits(view, world, [substitution], {}), "public substitution assigns unique good Martyr and good saved participant")
	substitution.data.saved = "g"
	check(not Solver.Roles.fits(view, world, [substitution], {}), "public substitution cannot save an evil participant")
	substitution.data.saved = "b"
	var claim = {"id": "claim", "kind": "claim", "source": "c", "subject": "c", "role": "martyr"}
	check(not Solver.Roles.fits(view, world, [substitution, claim], {}), "public Martyr identity challenges another person's role claim")
	var sexton = _report("toll", "a", "sexton", {"night": 2}, 2)
	# Nov 5 rework (patch_015): the bell can toll on any night from 1, whoever is alive, and it
	# suppresses minions only: walking gifts and the Demon's kill go on as usual.
	check(Solver.Roles.fits(view, world, [sexton], {}), "a healthy Sexton can toll with seven living")
	view.timeline.deaths = {"d": 1, "e": 1, "g": 2}
	check(Solver.Roles.fits(view, world, [sexton], {}), "four publicly living residents permit Sexton activation")
	var watch = _report("watch", "b", "nightwatch", {"block": "square", "seen": []}, 2)
	check(Solver.Roles.fits(view, world, [sexton, watch], {}), "the bell leaves a working walking gift alone")
	var lamp = _report("lamp", "b", "lamplighter", {"count": 1}, 2)
	check(Solver.Roles.fits(view, world, [sexton, lamp], {}), "the bell leaves the lamp count alone")
	var sight = {"id": "out", "kind": "sighting", "source": "player", "subject": "c", "subjects": ["c"], "night": 2, "block": "market"}
	check(Solver.Roles.fits(view, world, [sexton, sight], {}), "secret outings remain possible during a working knell")
	var seer = _report("seer", "b", "seer", {"pair": ["c", "f"], "yes": true}, 2)
	check(Solver.Roles.fits(view, world, [sexton, seer], {}), "knell permits nonwalking gifts")
	var twice = _report("twice", "a", "sexton", {"night": 3}, 3)
	check(not Solver.Roles.fits(view, world, [sexton, twice], {}), "Sexton activation is once per case")
	view.timeline.events = [{"kind": "demon_death", "subjects": ["c"], "at": {"day": 2}}]
	check(Solver.Roles.fits(view, world, [sexton], {}), "the bell night can still have a Demon kill")


func _live() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	g.w.day = 4
	var source = g.w.npcs[0]
	var target = g.w.npcs[4]
	for i in range(1, 4):
		g.add_card({"kind": "execution", "source": "player", "subject": [g.w.npcs[i].id], "day": i, "phase": 2, "text": "Public execution %d" % i})
	for role in ["martyr", "sexton"]:
		var data: Dictionary = {"target": target.id, "chosen": true} if role == "martyr" else {"night": 3}
		var number = g.add_card({"kind": "info", "source": source.id, "subject": [], "role": role, "day": 3 if role == "sexton" else 1, "phase": 3, "data": data, "text": role + " use claim"})
		var board = Canvas.new(Live.view(g))
		var root: String = board.selected
		board.nodes[root].conclusion = {"type": "suspicious", "target": target.id, "at": "Original alignment"}
		var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
		board.connect_cards("e:" + id, root)
		var value = board.compile(root)
		check(Live.status(g, value).ready, role + " actual use report has live support")
		check(Ghost.live(Live.snapshot(g, value)).ready, role + " actual use report previews")
		var filed = Live.file(g, value)
		check(filed > 0, role + " use claim files")
		var listener = g.w.living_good().filter(func(n): return n != source)[0]
		listener.info_log = []
		listener.known_claims = {}
		listener.beliefs = []
		listener.ledger = {}
		listener.role = "warden"
		listener.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
		var response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.get("workshop", false), role + " actual presentation uses shared owner")
		var before: Dictionary = listener.workshop_state.get("requested", {}).duplicate(true)
		response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.get("repeated", false) and listener.workshop_state.get("requested", {}) == before, role + " presentation repeat is stable")
		check(board.add_modifier("e:" + id, "misled") == "", role + " supports reading modifier")
		check(Live.status(g, board.compile(root)).ready, role + " modifier retains capability")
		if role == "martyr":
			var execution = g.add_card({"kind": "execution", "source": "player", "subject": [target.id], "day": 2, "phase": 2, "text": "Target executed after promise"})
			var changed_view = Live.view(g)
			board = Canvas.new(changed_view)
			root = board.selected
			board.nodes[root].conclusion.target = target.id
			board.connect_cards("e:" + id, root)
			board.connect_cards("e:" + Live.Evidence.normalize_card(g.board[execution - 1]).id, root)
			var status = Live.status(g, board.compile(root))
			check(not status.ready and status.issues.any(func(issue): return "dated outcome" in issue), "prior promise versus later execution explicitly flags missing temporal-health inference")


# ---- test_chunk6a_sexton_brute


func _give_role(w, n, role_id: String) -> void:
	n.role = role_id
	n.alignment = C.ROLES[role_id]["align"]
	if C.ROLES[role_id].get("minion", false):
		if n.id not in w.minion_ids:
			w.minion_ids.append(n.id)


func _test_sexton_registration_and_attributes() -> void:
	_check(C.has_role_def("sexton"), "Sexton registered in role registry")
	var rdef = C.role_def("sexton")
	_check(rdef.id == "sexton", "Sexton id matches")
	_check(rdef.align == "good", "Sexton align is good")
	_check(rdef.kind == "protect", "Sexton kind is protect")
	_check(rdef.min_gift_day == 1, "Sexton min_gift_day is 1")
	_check("protection" in rdef.tags, "Sexton has protection tag")
	_check("sexton" in C.GOOD_ROLES, "Sexton in C.GOOD_ROLES")


func _test_sexton_lamplighter_walk_on_toll() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(56789, 7)
	var w = g.w
	var sexton_npc = w.living_good()[0]
	_give_role(w, sexton_npc, "sexton")
	sexton_npc.gift_used = false

	w.day = 1
	var rdef = C.role_def("sexton")
	# Force toll
	var tolled = rdef.try_toll(w, sexton_npc, Mind)
	# Even if AI decision weights vary, manual call sets suppression when true
	if not tolled:
		sexton_npc.gift_used = true
		w.sexton_suppression_night = w.day
		w.sexton_tolled_night = w.day  # a forced toll walks too (the decision's roll varies by seed)

	w.resolve_night()

	_check(w.is_minion_suppressed(), "Minions are suppressed on the night of the toll")
	_check(sexton_npc.out_last_night, "Sexton performs night walk when tolling the bell")
	_check(sexton_npc.night_path.size() >= 4, "Sexton visits all parishes on the Lamplighter walk")


func _test_sexton_minion_suppression() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(67890, 7)
	var w = g.w

	var evils = w.living().filter(func(p): return p.is_evil())
	var demon_npc = w.demon()
	var poisoner_npc = evils.filter(func(p): return p != demon_npc)[0]
	_give_role(w, poisoner_npc, "poisoner")

	var sexton_npc = w.living_good()[0]
	_give_role(w, sexton_npc, "sexton")
	sexton_npc.poisoned = false
	sexton_npc.gift_used = false

	# Suppress minions on night 1
	w.day = 1
	w.sexton_suppression_night = 1

	w.resolve_night()

	# Check that no living person was poisoned despite poisoner being in play
	var poisoned_count: int = w.living().filter(func(p): return p.poisoned).size()
	_check(poisoned_count == 0, "Poisoner is suppressed by church bell: zero targets poisoned")


func _test_sexton_townsfolk_gifts_unaffected() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(78901, 7)
	var w = g.w

	var sexton_npc = w.living_good()[0]
	_give_role(w, sexton_npc, "sexton")
	w.sexton_suppression_night = 1

	var seer_npc = w.living_good()[1]
	_give_role(w, seer_npc, "seer")

	w.day = 1
	w.resolve_night()

	# Seer reading generated normally despite Sexton bell
	var has_seer_reading: bool = seer_npc.info_log.any(func(e): return e.get("role") == "seer" and e.get("day") == 1)
	_check(has_seer_reading, "Townsfolk gift (Seer) continues working under Sexton bell")


## The Brute is experimental until the solver models a non-Demon killer: never drawn on the
## Default or a dynamic script, but a playtest mark (or the editor) can still put it on.
func _test_sexton_once_per_case() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(89012, 7)
	var w = g.w

	var sexton_npc = w.living_good()[0]
	_give_role(w, sexton_npc, "sexton")
	sexton_npc.gift_used = true

	w.day = 2
	var rdef = C.role_def("sexton")
	var second_toll = rdef.try_toll(w, sexton_npc, Mind)
	_check(not second_toll, "Sexton cannot toll a second time in the same case")


## Maintenance A2 + design: the honest Sexton never lies about the toll night. While the
## bell holds they keep it quiet (refuse) unless pressed hard; from the morning after it
## wears off they tell of it.
func _test_sexton_bell_stops_breathstealer() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(67890, 7)
	var w = g.w
	var bs = w.living().filter(func(p): return p.is_evil() and p != w.demon())[0]
	_give_role(w, bs, "breathstealer")
	w.day = 2
	w.phase = C.MORNING
	w.sexton_suppression_night = 1
	_check(w.is_minion_suppressed(), "bell rung on night 1 still holds on day 2")
	C.role_def("breathstealer").run_day_gift(w, bs, Mind, Evil)
	_check(w.living().all(func(p): return p.silence_pending != 2), "Breathstealer chooses nobody to silence while the bell holds")
	var victim = w.living_good()[1]
	victim.silence_pending = 2
	w.phase = C.EVENING
	w.open_meeting()
	_check(not victim.silenced and not victim.id in w.meeting.get("silenced", []), "an earlier silencing doesn't land at a meeting under the bell")
	_check(w.dlog.entries.any(func(e): return str(e.get("type", e.get("kind", ""))) == "silence_suppressed"), "the suppressed silencing is logged")


## Design: evil plays the bell only once a Sexton has told the town of it.
func _test_sexton_honest_about_toll_night() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(56789, 7)
	var w = g.w
	var sx = w.living_good()[0]
	_give_role(w, sx, "sexton")
	sx.gift_used = true
	sx.claimed_role = ""
	sx.claim_public = false
	sx.secret = {}
	sx.secret_mod = ""
	sx.pressure = 0.0
	w.sexton_tolled_night = 1
	w.sexton_suppression_night = 1
	var other_block: String = C.BLOCKS.keys().filter(func(b): return b != sx.home_block)[0]
	sx.history[w.time_key(1, C.NIGHT)] = "night:" + other_block
	w.day = 2
	w.phase = C.MORNING
	var r: Dictionary = Mind.answer_night(w, sx, 1)
	var kinds: Array = r.facts.map(func(f): return str(f.get("kind", "")))
	_check(not (1 in sx.lied_nights), "honest Sexton doesn't lie about the toll night while the bell holds")
	_check(not r.facts.any(func(f): return f.get("kind", "") == "alibi" and f.get("home", false)), "no 'home all night' account for the toll night")
	_check("refusal" in kinds or r.facts.any(func(f): return f.get("duty", "") == "sexton"), "while the bell holds: a refusal, or the truth if pressed")
	# Pressed hard (nominated, rattled): they tell the truth early.
	var sx2_res: Array = []
	for i in range(6):
		sx.dialogue_memory.erase("honest_outing")
		sx.dialogue_memory.erase("night_accounts")
		sx.claimed_role = ""
		sx.max_tier = 0
		sx.pressure = 1.0
		w.meeting["nominated"] = [sx.id]
		var rr: Dictionary = Mind.answer_night(w, sx, 1)
		sx2_res.append(rr.facts.any(func(f): return f.get("duty", "") == "sexton"))
	w.meeting["nominated"] = []
	_check(sx2_res.count(true) >= 4, "under pressure the Sexton is quick to tell of the toll (%d/6)" % sx2_res.count(true))
	# The morning after the bell wears off: open about it.
	sx.dialogue_memory.erase("honest_outing")
	sx.dialogue_memory.erase("night_accounts")
	sx.claimed_role = ""
	sx.max_tier = 0
	sx.pressure = 0.0
	w.day = 3
	var r3: Dictionary = Mind.answer_night(w, sx, 1)
	_check(r3.facts.any(func(f): return f.get("duty", "") == "sexton" and f.get("kind", "") == "sighting"), "from day 3 the Sexton tells of the toll when asked")
	_check(sx.claimed_role == "sexton", "telling of the toll names the gift")
	_check(r3.facts.any(func(f): return f.get("kind", "") == "claim" and f.get("role", "") == "sexton"), "with a private claim card")
	# At the meeting: the claim leans to waiting while the bell holds, to telling after.
	var parts_wait: Dictionary = {}
	w.day = 2
	C.role_def("sexton").score_public_claim(w, sx, parts_wait)
	var parts_over: Dictionary = {}
	w.day = 3
	C.role_def("sexton").score_public_claim(w, sx, parts_over)
	_check(parts_wait.get("toll_wait", 0.0) < 0.0 and parts_over.get("toll_over", 0.0) > 0.0, "meeting claim waits while the bell holds, then leans open")


# ---- test_chunk3_executor_registrar


func _test_executor_sim() -> void:
	var sc = ScriptDef.default_script()
	sc.town.erase("sexton")
	sc.town.append("executor")
	sc.forced = ["executor"]
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9301, 7, sc)
	var w = g.w
	var ex_n = w.npc_with_role("executor")
	var charge_id: String = ex_n.executor_target
	var charge = w.by_id[charge_id]

	# Night kill on Night 1 does NOT give a Night 1 reading; Executor learns on Morning 2!
	w.day = 1
	w.phase = C.NIGHT
	w._kill(charge)
	_check(ex_n.info_log.size() == 1 and not ex_n.executor_resolved,
		"Executor does not learn role during Night 1 immediately on _kill")
	w.start_new_day() # Advances to Day 2 Morning -> _morning_executor_gifts()
	_check(ex_n.executor_resolved and ex_n.info_log.size() == 2 and ex_n.info_log[1].get("data", {}).get("role", "") == charge.role and int(ex_n.info_log[1].get("day", -1)) == 2 and int(ex_n.info_log[1].get("phase", -1)) == C.MORNING,
		"Executor learns deceased charge's true role on the following Morning (Day 2 Morning)")

	# Poisoned on Night 1 -> Morning 2 role reading is corrupted (role != charge.role):
	var g2 = Game.new()
	g2.detailed_logging = false
	g2.new_case(9302, 7, sc)
	var w2 = g2.w
	var ex2 = w2.npc_with_role("executor")
	var ch2 = w2.by_id[ex2.executor_target]
	ex2.poisoned = true
	w2.day = 1
	w2.phase = C.NIGHT
	w2._kill(ch2)
	w2.start_new_day()
	var p_entry: Dictionary = ex2.info_log.back()
	_check(ex2.executor_resolved and p_entry.get("data", {}).get("role", "") != ch2.role and not bool(p_entry.get("true", true)),
		"Executor poisoned the night before Morning learns a corrupted off-script-safe false role")

	# Marked charge reads as an evil role ~30% of the time:
	var marked_evil_hits: int = 0
	for sd in range(9310, 9350):
		var gm = Game.new()
		gm.detailed_logging = false
		gm.new_case(sd, 7, sc)
		var wm = gm.w
		var exm = wm.npc_with_role("executor")
		var goods_other: Array = wm.living_good().filter(func(m): return m != exm)
		var chm = goods_other[0]
		exm.executor_target = chm.id
		exm.executor_resolved = false
		chm.secret_mod = "marked"
		wm.day = 1
		wm.phase = C.EVENING
		wm.begin_meeting()
		wm.execute(chm.id, {"by": "player", "yes": [], "player_yes": true})
		wm.day = 2
		wm.phase = C.MORNING
		wm._morning_executor_gifts()
		var r_out: String = str(exm.info_log.back().get("data", {}).get("role", ""))
		if C.ROLES.get(r_out, {}).get("align") == "evil":
			marked_evil_hits += 1
	_check(marked_evil_hits >= 3 and marked_evil_hits <= 28,
		"Marked Executor charge registers as an evil role ~30%% of the time (%d/40)" % marked_evil_hits)


func _test_executor_workshop_and_parity() -> void:
	Caches.clear_all()

	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": i != 1})
	var events: Array = [
		{"kind": "demon_death", "subjects": [people[1].id], "by": "town", "at": {"day": 1, "phase": "night"}},
	]
	var timeline: Dictionary = preload("res://workshop/live_history.gd").from_events(events)

	var c_assign: Dictionary = {
		"id": "ex_n0", "fact_id": "ex_n0", "kind": "report", "source": people[0].id,
		"role": "executor", "night": 0, "observed_at": {"day": 0, "phase": "night"},
		"data": {"target": people[1].id, "assigned": true}, "text": "Charge is P1."
	}
	var c_role_good: Dictionary = {
		"id": "ex_m2", "fact_id": "ex_m2", "kind": "report", "source": people[0].id,
		"role": "executor", "night": -1, "observed_at": {"day": 2, "phase": "morning"},
		"data": {"target": people[1].id, "role": "clerk"}, "text": "P1 was Clerk."
	}
	var c_mismatch: Dictionary = {
		"id": "ex_bad_t", "fact_id": "ex_bad_t", "kind": "report", "source": people[0].id,
		"role": "executor", "night": -1, "observed_at": {"day": 2, "phase": "morning"},
		"data": {"target": people[2].id, "role": "clerk"}, "text": "P2 was Clerk."
	}
	var view: Dictionary = {
		"seed": 301, "day": 2, "people": people, "cards": [c_assign, c_role_good, c_mismatch],
		"evil_count": 2, "alignment_epoch": "Original alignment", "history": [],
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "roles": true, "identities": true},
		"timeline": timeline,
	}

	var s_consistent: Dictionary = Solver.solve(view, [c_assign, c_role_good])
	_check(not s_consistent.worlds.is_empty() and s_consistent.worlds.all(func(uw): return (int(uw.evil) & (1 << 1)) == 0),
		"Consistent Night 0 + Morning 2 Executor reading clears dead good target (%d worlds)" % s_consistent.worlds.size())

	var s_mismatch: Dictionary = Solver.solve(view, [c_assign, c_mismatch])
	_check(s_mismatch.worlds.is_empty(),
		"Mismatched Executor charge vs death target (or undead target) yields 0 worlds")

	# Scion promotion: P1 executed Day 1 with 7 alive, Executor learns 'demon' on Morning 2,
	# while P2 is the surviving promoted Scion Demon!
	var events_sc: Array = [
		{"kind": "execution", "subjects": [people[1].id], "by": "town", "at": {"day": 1, "phase": "evening"}},
	]
	var view_sc: Dictionary = view.duplicate(true)
	view_sc.timeline = preload("res://workshop/live_history.gd").from_events(events_sc)
	var c_role_demon: Dictionary = {
		"id": "ex_dem", "fact_id": "ex_dem", "kind": "report", "source": people[0].id,
		"role": "executor", "night": -1, "observed_at": {"day": 2, "phase": "morning"},
		"data": {"target": people[1].id, "role": "demon"}, "text": "P1 was Demon."
	}
	view_sc.cards = [c_assign, c_role_demon]
	var s_scion: Dictionary = Solver.solve(view_sc, [c_assign, c_role_demon])
	var has_promoted_world: bool = s_scion.worlds.any(func(uw): return int(uw.demon) != 1 and (int(uw.evil) & (1 << 1)) != 0 and int(uw.marked) != 1)
	_check(has_promoted_world,
		"Executor reading 'demon' on hanged target with >=5 alive supports worlds where Scion promoted to active Demon")

	# FactoredChannels vs exhaustive Oracle parity:
	var fac: Dictionary = Factored.assess(view, [c_assign, c_role_good], {}, {"gift_honesty:" + people[0].id: 0.85, "gift_accuracy:" + people[0].id + ":0": 0.98, "gift_accuracy:" + people[0].id + ":1": 0.95}, {})
	var ora: Dictionary = Oracle.assess(view, [c_assign, c_role_good], {}, {"gift_honesty:" + people[0].id: 0.85, "gift_accuracy:" + people[0].id + ":0": 0.98, "gift_accuracy:" + people[0].id + ":1": 0.95}, {})
	var max_diff: float = 0.0
	for idx in range(fac.post.size()):
		max_diff = maxf(max_diff, absf(fac.post[idx] - ora.post[idx]))
	_check(max_diff <= 1e-12,
		"FactoredChannels matches exhaustive ChannelLikelihood oracle on Executor (max diff %.3g)" % max_diff)
