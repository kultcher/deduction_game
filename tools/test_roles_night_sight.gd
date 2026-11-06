## Night-sight gifts (hint package 'night_sight'): Seer, Night Watch, Lamplighter, Hearthwitch, Monitor.
## Merged from: test_chunk5_monitor_confessor, test_lamplighter_drops, test_roster, test_workshop_lamplighter, test_workshop_nightwatch_gravedigger.
extends SceneTree

const Game = preload("res://game/game.gd")
const World = preload("res://sim/world.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const History = preload("res://workshop/live_history.gd")
const Muddler = preload("res://sim/muddler.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_roster()
	_run_lamplighter_drops()
	_run_workshop_lamplighter()
	_run_workshop_nightwatch_grav()
	_run_chunk5_monitor_confessor()
	print("Roles: night sight: %d checks, %d failures" % [checks, fails])
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
	_test_lamplighter()
	_test_seer_insight()


# ---------------------------------------------------------------- from test_lamplighter_drops

func _run_lamplighter_drops() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	var w = g.w
	var lamp = w.living_good()[0]
	for n in w.npcs:
		n.secret_mod = ""
		n.secret = {}
	lamp.home_block = "square"
	var found = {}
	var correct = true
	for night in range(1000):
		w.day = night
		w.dropped.clear()
		w._night_movement("", "", null, "", null, "", null, "", lamp)
		var count = 0
		for loc in w.dropped:
			found[C.loc_block(loc)] = true
			count += w.dropped[loc].size()
			correct = correct and C.LOCATIONS.has(loc) and w.dropped[loc][0].who == lamp.id
		correct = correct and count <= 1
	check(found.size() == 4, "Lamplighter drops can occur on every block of its actual route")
	check(correct, "one ordinary drop roll uses only public locations and the correct walker")
	check(lamp.night_path == C.BLOCKS.keys() and w.night_walkers[0].path == lamp.night_path, "drop sampling and sightings use the same completed lamp route")
	var ordinary = true
	for night in range(1000):
		w.day = night
		w.dropped.clear()
		w.night_walkers.clear()
		w._walk(lamp, "market", "ordinary trip")
		for loc in w.dropped:
			ordinary = ordinary and C.loc_block(loc) in ["square", "market"]
	check(ordinary and lamp.night_path == C.route("square", "market"), "ordinary walkers still drop only along their shortest route")


# ---------------------------------------------------------------- from test_workshop_lamplighter

func _run_workshop_lamplighter() -> void:
	_constraints()
	_live()


# ---------------------------------------------------------------- from test_workshop_nightwatch_gravedigger

func _run_workshop_nightwatch_grav() -> void:
	_semantics()
	workshop_nightwatch_grav__live()


# ---------------------------------------------------------------- from test_chunk5_monitor_confessor

func _run_chunk5_monitor_confessor() -> void:
	_test_monitor_role_def_registration()
	_test_monitor_readings_and_marked()
	_test_monitor_poisoned_misread()
	_test_monitor_window_sighting_suppression()
	_test_monitor_bluff_and_fake_medium()
	_test_workshop_live_evidence_and_assessment()
	_test_workshop_solver_monitor_and_confessor()
	_test_muddler_monitor_and_confessor()
	_test_maintenance_2026_11_05()


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


func _test_lamplighter() -> void:
	var ok = 0
	for sd in range(9200, 9220):
		var w = _game(sd).w
		var lp = w.living_good()[0]
		_give(w, lp, "lamplighter")
		lp.secret_mod = ""
		w.day = 1
		w.resolve_night()
		if not lp.alive:
			ok += 1  # killed in the night: no reading
			continue
		for e in lp.info_log:
			if e["role"] == "lamplighter" and e["day"] == 1:
				var others = w.night_walkers.filter(func(wk): return wk["id"] != lp.id).size()
				if e["data"]["count"] == others or not e["true"]:
					ok += 1
	_check(ok == 20, "the Lamplighter counts the others out (unless their gift is broken)")


func _test_seer_insight() -> void:
	var hits = {"sharp": 0, "dull": 0}
	for sd in range(9600, 9640):
		for kind in ["sharp", "dull"]:
			var w = _game(sd).w
			var sr = w.living_good()[0]
			_give(w, sr, "seer")
			sr.traits["insight"] = 0.95 if kind == "sharp" else 0.05
			w.day = 2
			var top = Mind.ranked_suspects(w, sr)[0]
			if top.id in Mind.seer_picks(w, sr):
				hits[kind] += 1
	print("Seer re-checks the top suspect: sharp %d/40, dull %d/40" % [hits["sharp"], hits["dull"]])
	_check(hits["sharp"] > hits["dull"] + 8, "a sharp Seer drills into their top suspect more than a dull one")


# ---- test_workshop_lamplighter


func _constraints() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square"})
	var view = {"people": people, "cards": [], "day": 2, "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": {"events": [], "deaths": {}}, "world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}
	var lamp = {"id": "lamp", "kind": "report", "source": "a", "role": "lamplighter", "night": 1, "data": {"count": 3}, "observed_at": {"day": 1, "phase": "night"}}
	var sight = {"id": "sight", "kind": "sighting", "source": "player", "subjects": ["b", "c"], "subject": "b", "night": 1, "block": "square"}
	var cards: Array = [lamp, sight]
	for id in ["d", "e", "f"]:
		cards.append({"id": "home" + id, "kind": "alibi", "source": "player", "subject": id, "night": 1})
	var result = Activity.routes(view, cards)
	check(result.okay and "g" in result.nights["1"].forced_out, "count plus sightings and home alibis identifies final outing")
	check("a" in result.nights["1"].forced_out, "Lamplighter's own tour is separate from the count")
	check(Activity.routes(view, [lamp]).okay, "unanswered count requires no minimum number of named people")
	var extra = sight.duplicate(true)
	extra.id = "extra"
	extra.subjects = ["d", "e"]
	check(not Activity.routes(view, [lamp, sight, extra]).okay, "four established other outings conflict with count three")
	check(Activity.routes(view, [lamp], {"lamp": {"positive": ["b"]}}).okay, "partial player answer leaves unresolved slots")
	view.cards = [lamp]
	var value = Solver.empty_case()
	value.cards = ["lamp"]
	value.answers.lamp = {"positive": ["a"]}
	check(not Solver.validate_answers(view, value).is_empty(), "answer cannot count Lamplighter as an other person")
	view.timeline.deaths = {"g": 1}
	check(not Activity.routes(view, cards).okay, "already-dead resident cannot fill a later night's remaining slot")
	view.timeline.deaths.g = 2
	check(Activity.routes(view, cards).okay, "person dying that night still counts as an outing")
	view.timeline.deaths = {}
	var factors = Activity.factors(view, cards, {})
	check(factors[0].profiles[6].good < 1.0, "forced outing enters joint activity likelihood")
	lamp.data.count = 0
	check(Activity.routes(view, [lamp]).okay, "zero other outings still permits Lamplighter tour")
	check(not Activity.routes(view, [lamp, sight]).okay, "positive sighting contradicts zero-other count")


func _live() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	var source = g.w.npcs[0]
	var number = g.add_card({"kind": "info", "source": source.id, "subject": [], "role": "lamplighter", "day": 1, "phase": 3, "data": {"count": 3}, "text": "Three others out on N1"})
	var board = Canvas.new(Live.view(g))
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "suspicious", "target": g.w.npcs[1].id, "at": "Original alignment"}
	var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
	board.connect_cards("e:" + id, root)
	var value = board.compile(root)
	check(Live.status(g, value).ready, "Lamplighter live card is supported")
	check(Ghost.live(Live.snapshot(g, value)).ready, "Lamplighter neutral preview succeeds")
	var filed = Live.file(g, value)
	check(filed > 0, "Lamplighter filing succeeds: " + g.last_error)
	if filed < 1:
		return
	var listener = g.w.living_good().filter(func(n): return n != source)[0]
	listener.info_log = []
	listener.known_claims = {}
	listener.ledger = {}
	listener.role = "seer"
	listener.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	var response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
	check(response.get("workshop", false), "Lamplighter reaches real shared delivery")
	var before: Dictionary = listener.workshop_state.get("requested", {}).duplicate(true)
	response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
	check(response.get("repeated", false) and listener.workshop_state.get("requested", {}) == before, "Lamplighter presentation is repeat stable")
	check(board.add_modifier("e:" + id, "misled") == "", "Lamplighter permits supported reading challenges")
	check(Live.status(g, board.compile(root)).ready, "Lamplighter modifier stays in live evaluator")


# ---- test_workshop_nightwatch_gravedigger


func report(id: String, source: String, role: String, data: Dictionary, night: int = 1) -> Dictionary:
	return {"id": id, "kind": "report", "source": source, "role": role, "data": data, "night": night, "observed_at": {"day": night, "phase": "night"}}


func _semantics() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square"})
	var view = {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment", "world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}
	var world = {"evil": 96, "demon": 5, "marked": 4, "modifier": "marked", "holders": 16}
	var knowledge = {"self": "a", "good": ["a"], "own_role": "warden"}
	var grave = report("grave", "b", "gravedigger", {"executed": "g", "role": "poisoner"})
	check(Solver.Roles.fits(view, world, [grave], knowledge), "named minion role fits actual minion")
	grave.data.executed = "f"
	check(not Solver.Roles.fits(view, world, [grave], knowledge), "Demon cannot fill named minion role")
	grave.data.role = "demon"
	check(Solver.Roles.fits(view, world, [grave], knowledge), "Demon role report fixes Demon identity")
	grave.data.executed = "e"
	check(Solver.Roles.fits(view, world, [grave], knowledge), "Marked may register as Demon without being evil")
	grave.data.executed = "d"
	check(not Solver.Roles.fits(view, world, [grave], knowledge), "ordinary good cannot register as Demon")
	grave.data.role = "warden"
	check(not Solver.Roles.fits(view, world, [grave], knowledge), "executed good-role read conflicts with firsthand unique role")
	grave.data.executed = "a"
	check(Solver.Roles.fits(view, world, [grave], knowledge), "good-role read corroborates firsthand holder")
	grave.data.role = "seer"
	check(not Solver.Roles.fits(view, world, [grave], knowledge), "good role report must fit original role identity")
	grave.data.executed = "g"
	check(not Solver.Roles.fits(view, world, [grave], knowledge), "evil target cannot fill good gift")
	grave.data.executed = "e"
	grave.data.role = "poisoner"
	var other: Dictionary = world.duplicate(true)
	other.marked = 3
	other.holders = 8
	check(not Solver.Roles.fits(view, other, [grave], knowledge), "role cache distinguishes different Marked holders")
	var timeline = History.from_events([
		{"kind": "execution", "subjects": ["f"], "at": {"day": 1}},
		{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}},
		{"kind": "martyr", "subjects": ["b", "c"], "by": "b", "at": {"day": 2}}])
	view.timeline = timeline
	check(not History.alive_at_night(view, "f", 1), "execution precedes same-night movement")
	check(History.alive_at_night(view, "g", 1) and not History.alive_at_night(view, "g", 2), "Demon victim participates in death-night readings")
	check(not History.alive_at_night(view, "b", 2) and History.alive_at_night(view, "c", 2), "Martyr substitution kills only the Martyr")
	check(History.executed(view, "f", 1) and not History.executed(view, "g", 1), "execution bookkeeping does not confuse night deaths")
	check(History.observer_alive(view, "f", {"day": 1, "phase": "morning"}) and not History.observer_alive(view, "f", {"day": 1, "phase": "night"}), "execution-day daytime reading precedes death while night reading does not")
	var watch = report("watch", "c", "nightwatch", {"block": "square", "seen": ["d", "e"]})
	var home = {"id": "home", "kind": "alibi", "source": "d", "subject": "d", "night": 1, "observed_at": {"day": 1, "phase": "night"}}
	check(not Solver.solve(view, [watch, home], {}, {}, knowledge).movement_ok, "Watch list challenges each named person's home alibi")
	check(Solver.solve(view, [watch], {}, {}, knowledge).movement["1"].forced_out.has("c"), "watcher is also out on duty")
	check(Assess.Domain.gift_time(watch), "Night Watch night interval is supported")
	watch.observed_at.phase = "morning"
	check(not Assess.Domain.gift_time(watch), "daytime Watch payload cannot masquerade as night evidence")


func workshop_nightwatch_grav__live() -> void:
	for role in ["nightwatch", "gravedigger"]:
		var g = Game.new()
		g.new_case(692, 7)
		g.w.dlog.detailed = false
		var source = g.w.npcs[0]
		var target = g.w.npcs[1]
		g.add_card({"kind": "execution", "source": "player", "subject": [target.id], "day": 1, "phase": 2, "text": "Public execution fixture"})
		var data: Dictionary = {"block": "square", "seen": [target.id]} if role == "nightwatch" else {"executed": target.id, "role": "poisoner"}
		var night: int = 0 if role == "nightwatch" else 1
		var number = g.add_card({"kind": "info", "source": source.id, "role": role, "day": night, "phase": 3, "data": data, "text": "New supported report " + role})
		var board = Canvas.new(Live.view(g))
		var root: String = board.selected
		board.nodes[root].conclusion.target = target.id
		var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
		board.connect_cards("e:" + id, root)
		var value = board.compile(root)
		check(Live.status(g, value).ready, role + " live case is supported")
		check(not Solver.card_by_id(board.view, id).support_note.begins_with("FALLBACK"), role + " live card label announces support")
		var preview = Ghost.live(Live.snapshot(g, value))
		check(preview.ready and preview.proposal.assessment.compatible > 0, role + " ghost preview finds legal explanations")
		var filed = Live.file(g, value)
		check(filed > 0 and g.board[filed - 1].supports == [number], role + " filing preserves exact original")
		var listener = g.w.living_good().filter(func(n): return n != source and n != target)[0]
		listener.info_log = []
		listener.known_claims = {}
		listener.ledger = {}
		listener.role = "warden"
		listener.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
		var response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.get("workshop", false), role + " actual NPC delivery uses shared evaluator")
		var before: Dictionary = listener.workshop_state.get("requested", {}).duplicate(true)
		response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.get("repeated", false) and listener.workshop_state.get("requested", {}) == before, role + " repeat does not stack effects")
		check(board.add_modifier("e:" + id, "misled") == "", role + " supports Misled attachment")
		check(Live.status(g, board.compile(root)).ready, role + " attached modifier preserves live capability")
		if role == "gravedigger":
			g.board[0]["deleted"] = true
			# Public process receipts remain the only authority; without a matching
			# execution, the Gravedigger report stays ready and cannot hold for a good reader.
			g.board = g.board.filter(func(c): return c.kind != "execution")
			for i in range(g.board.size()):
				g.board[i].n = i + 1
			check(Live.status(g, value).ready, "missing execution history remains ready in shared model")
			var bogus_preview = Ghost.live(Live.snapshot(g, value))
			check(bogus_preview.ready and bogus_preview.proposal.assessment.compatible == 0, "missing execution makes accepted Gravedigger report impossible for a good reader")


# ---- test_chunk5_monitor_confessor


func _give_role(w, n, role_id: String) -> void:
	n.role = role_id
	n.alignment = C.ROLES[role_id]["align"]


func _test_monitor_role_def_registration() -> void:
	_check(C.has_role_def("monitor"), "Monitor registered in role registry")
	var rdef = C.role_def("monitor")
	_check(rdef.id == "monitor", "Monitor id matches")
	_check(rdef.align == "good", "Monitor align is good")
	_check(rdef.kind == "info", "Monitor kind is info")
	_check(rdef.min_gift_day == 1, "Monitor min_gift_day is 1")
	_check(not rdef.night_walk, "Monitor does not night walk (home block only)")
	_check(rdef.marked_registers, "Monitor marked_registers is true")
	_check("ongoing_info" in rdef.tags, "Monitor has ongoing_info tag")
	_check("role_id" in rdef.tags, "Monitor has role_id tag")
	_check("monitor" in C.GOOD_ROLES, "Monitor in C.GOOD_ROLES")
	_check("monitor" in C.INFO_ROLES, "Monitor in C.INFO_ROLES")
	_check("monitor" in C.HINT_PACKAGES["night_sight"]["roles"], "Monitor in night_sight hint package")


func _test_monitor_readings_and_marked() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(12345, 7)
	var w = g.w
	var n = w.living_good()[0]
	_give_role(w, n, "monitor")
	n.home_block = "square"
	n.secret_mod = ""
	n.poisoned = false

	var rdef = C.role_def("monitor")

	# Day 0: produces no reading
	w.day = 0
	var r0: Dictionary = rdef.generate_reading(w, n, {}, Mind)
	_check(r0.is_empty(), "Monitor produces no reading on Night 0")

	# Day 1 with 0 night walkers on home block -> fallback "walked: false"
	w.day = 1
	w.night_walkers = []
	var r_none: Dictionary = rdef.generate_reading(w, n, {}, Mind)
	_check(not r_none.is_empty(), "Monitor produces reading on Night 1")
	_check(bool(r_none.data.walked) == false, "Monitor reports walked == false when 0 walkers abroad")
	_check(r_none.data.block == "square", "Monitor reading block matches home block")
	_check(not r_none.data.has("role"), "Monitor fallback reading omits role field")
	_check(r_none.text == "no one walked by my house", "Monitor fallback text matches exact spec (no time: the sentence adds it)")
	_check(bool(r_none["true"]) == true, "Monitor fallback reading is true when 0 walkers")

	# Day 1 with 1 walker abroad on home block
	var walker = w.living().filter(func(p): return p != n)[0]
	_give_role(w, walker, "seer")
	w.night_walkers = [{"id": walker.id, "block": "square", "path": ["market", "square"]}]
	var r_walk: Dictionary = rdef.generate_reading(w, n, {}, Mind)
	_check(bool(r_walk.data.walked) == true, "Monitor reports walked == true when walker abroad")
	_check(str(r_walk.data.role) == "seer", "Monitor learns role of the walker")
	_check(bool(r_walk["true"]) == true, "Monitor reading is true")

	# Marked walker registers as random active-script Minion or Demon
	walker.secret_mod = "marked"
	var saw_evil_role: bool = false
	for seed_i in range(100):
		w.rng.seed = 20000 + seed_i
		var r_m: Dictionary = rdef.generate_reading(w, n, {}, Mind)
		if str(r_m.data.get("role", "")) in (C.MINION_ROLES + ["demon"]):
			saw_evil_role = true
			_check(r_m.get("why", "") == "a Marked soul read as evil", "Marked registration sets correct why clause")
			break
	_check(saw_evil_role, "Marked walker on home block registers as evil role")


func _test_monitor_poisoned_misread() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(54321, 7)
	var w = g.w
	var n = w.living_good()[0]
	_give_role(w, n, "monitor")
	n.home_block = "docks"
	n.poisoned = true
	w.day = 1

	var rdef = C.role_def("monitor")

	# Poisoned with 0 walkers: can misread and report a role walked
	w.night_walkers = []
	var r_pois: Dictionary = rdef.generate_reading(w, n, {}, Mind)
	_check(bool(r_pois["true"]) == false, "Poisoned Monitor produces false reading")
	_check(r_pois.why == "poisoned", "Poisoned Monitor sets why == poisoned")
	_check(str(r_pois.data.get("role", "")) in (C.GOOD_ROLES + C.EVIL_ROLES), "Misread names role on active script")


func _test_monitor_window_sighting_suppression() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(77123, 7)
	var w = g.w
	var mon = w.living_good()[0]
	_give_role(w, mon, "monitor")
	mon.home_block = "hill"
	mon.out_last_night = false

	var walker = w.living().filter(func(p): return p != mon)[0]
	w.night_walkers = [{"id": walker.id, "block": "hill", "path": ["hill"]}]

	# Run night sightings multiple times; monitor should never get window sighting
	for iter in range(20):
		mon.beliefs.clear()
		w._night_sightings()
		var got_window: bool = mon.beliefs.any(func(b): return b.get("kind") == "saw" and str(b.get("how")) == "window")
		_check(not got_window, "Monitor never receives out-the-window street sightings")


func _test_monitor_bluff_and_fake_medium() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(88123, 7)
	var w = g.w
	w.day = 1
	var bluffer = w.living().filter(func(p): return p.is_evil())[0]
	var sg = w.living_good()[0]
	var rdef = C.role_def("monitor")

	var bluff_res = rdef.generate_bluff_reading(w, bluffer, {}, sg.id, null, [])
	_check(bluff_res.has("entry"), "Bluffing Monitor generates bluff entry")
	_check(bluff_res.entry.data.has("block"), "Bluffing Monitor includes block")
	_check(bluff_res.entry.data.has("walked"), "Bluffing Monitor includes walked")

	var dead_mon = w.living_good()[1]
	var med_res = rdef.fake_medium_reading(w, bluffer, dead_mon, sg.id, sg, null, [], func(): pass, {}, false)
	_check(med_res.has("entry"), "Fake medium Monitor reading generates entry")
	_check(med_res.entry.data.walked == true, "Fake medium Monitor reading reports walker")


func _test_workshop_live_evidence_and_assessment() -> void:
	_check(Evidence.REPORT_FIELDS.has("monitor"), "REPORT_FIELDS contains monitor")
	_check(Evidence.REPORT_FIELDS.has("confessor"), "REPORT_FIELDS contains confessor")
	_check("walked" in Evidence.FIELDS, "walked in Evidence.FIELDS")
	_check("good" in Evidence.FIELDS, "good in Evidence.FIELDS")
	_check("forgot" in Evidence.FIELDS, "forgot in Evidence.FIELDS")

	var ids = ["alice", "bob", "clara", "dan", "eve", "felix", "gwen"]
	var mods = ["delusional", "marked", "lovers", "sleepwalker"]

	# Monitor assessment validation
	var mon_card_valid = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 1, "phase": "night"},
		"content": {"role": "monitor", "data": {"block": "square", "walked": true, "role": "seer"}}
	}
	_check(Assess.reading_valid(mon_card_valid, ids, mods), "Valid Monitor reading passes reading_valid")

	var mon_card_fallback_valid = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 1, "phase": "night"},
		"content": {"role": "monitor", "data": {"block": "square", "walked": false}}
	}
	_check(Assess.reading_valid(mon_card_fallback_valid, ids, mods), "Valid fallback Monitor reading passes reading_valid")

	var mon_card_day0 = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 0, "phase": "night"},
		"content": {"role": "monitor", "data": {"block": "square", "walked": false}}
	}
	_check(not Assess.reading_valid(mon_card_day0, ids, mods), "Day 0 Monitor reading rejected by reading_valid")

	# Confessor assessment validation
	var conf_card_good_valid = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 1, "phase": "night"},
		"content": {"role": "confessor", "data": {"target": "bob", "good": true}}
	}
	_check(Assess.reading_valid(conf_card_good_valid, ids, mods), "Valid Confessor good reading passes reading_valid")

	var conf_card_forgot_valid = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 1, "phase": "night"},
		"content": {"role": "confessor", "data": {"forgot": true}}
	}
	_check(Assess.reading_valid(conf_card_forgot_valid, ids, mods), "Valid Confessor forgot reading passes reading_valid")

	var conf_card_self_target = {
		"kind": "info",
		"source": "alice",
		"observed_at": {"day": 1, "phase": "night"},
		"content": {"role": "confessor", "data": {"target": "alice", "good": true}}
	}
	_check(not Assess.reading_valid(conf_card_self_target, ids, mods), "Confessor self-target rejected by reading_valid")


func _test_workshop_solver_monitor_and_confessor() -> void:
	_check("monitor" in Solver.CONTENT_ROLES, "monitor in Solver.CONTENT_ROLES")
	_check("confessor" in Solver.CONTENT_ROLES, "confessor in Solver.CONTENT_ROLES")

	# View setup
	var view: Dictionary = {
		"people": [
			{"id": "alice", "home": "square"},
			{"id": "bob", "home": "square"},
			{"id": "clara", "home": "market"},
			{"id": "dan", "home": "market"},
			{"id": "eve", "home": "docks"},
			{"id": "felix", "home": "docks"},
			{"id": "gwen", "home": "hill"},
		]
	}
	# World with evil: dan (minion), eve (demon)
	var world: Dictionary = {
		"evil": (1 << 3) | (1 << 4), # dan (3), eve (4)
		"demon": 4, # eve
		"marked": -1,
		"holders": 0,
	}

	# Confessor card on bob (good): good: true -> should fit
	var c_conf_good = {"kind": "report", "role": "confessor", "source": "alice", "data": {"target": "bob", "good": true}}
	_check(Solver._report_content(view, world, c_conf_good, {}), "Confessor reading on good bob holds in world")

	# Confessor card on dan (evil): good: true -> should NOT fit
	var c_conf_evil = {"kind": "report", "role": "confessor", "source": "alice", "data": {"target": "dan", "good": true}}
	_check(not Solver._report_content(view, world, c_conf_evil, {}), "Confessor reading good: true on evil dan fails in world")

	# Confessor card forgot: true with positive answer chips pointing to dan (evil) -> holds
	var c_conf_forgot = {"kind": "report", "role": "confessor", "source": "alice", "data": {"forgot": true}}
	_check(Solver._report_content(view, world, c_conf_forgot, {"positive": ["dan"]}), "Confessor forgot: true with positive chip on evil dan holds in world")

	# Confessor card forgot: true with positive answer chips pointing to bob (good) -> fails
	_check(not Solver._report_content(view, world, c_conf_forgot, {"positive": ["bob"]}), "Confessor forgot: true with positive chip on good bob fails in world")

	# Monitor card on square reporting minion with positive chip on dan (who is not on square, or evil)
	var c_mon_minion = {"kind": "report", "role": "monitor", "source": "alice", "data": {"block": "square", "walked": true, "role": "poisoner"}}
	_check(Solver._report_content(view, world, c_mon_minion, {"positive": ["dan"]}), "Monitor minion reading with chip on evil dan holds")

	# Monitor card with chip on good bob for minion role -> fails
	_check(not Solver._report_content(view, world, c_mon_minion, {"positive": ["bob"]}), "Monitor minion reading with chip on good bob fails")


## Maintenance 2026-11-05: A3 (Monitor bluffer night-scoped), A8 (Confessor clears),
## A11 (Marked rolled once; misreads recorded false).
func _test_muddler_monitor_and_confessor() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(66123, 7)
	var w = g.w
	var muddler = w.living_good()[0]
	muddler.secret_mod = "muddler"

	# Test Monitor mutation
	var orig_mon = {
		"role": "monitor",
		"data": {"block": "square", "walked": true, "role": "seer"},
		"text": "I learned that a Seer was abroad on Square last night"
	}
	var mut_mon = Muddler.mutate_reading_entry(w, muddler, "other", orig_mon)
	_check(not mut_mon.is_empty(), "Muddler mutates Monitor reading")
	_check(mut_mon.data.get("role") != "seer" or mut_mon.data.get("walked") == false, "Muddler changes Monitor role or walked flag")

	# Test Confessor mutation
	var orig_conf = {
		"role": "confessor",
		"data": {"target": "bob", "good": true},
		"text": "I heard Bob's confession: their heart was pure and their spirit good"
	}
	var mut_conf = Muddler.mutate_reading_entry(w, muddler, "other", orig_conf)
	_check(not mut_conf.is_empty(), "Muddler mutates Confessor reading")
	_check(mut_conf.data.get("target") != "bob" or mut_conf.data.get("forgot") == true, "Muddler changes Confessor target or flips to forgot")


func _test_maintenance_2026_11_05() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(33123, 7)
	var w = g.w
	var rdef = C.role_def("monitor")
	var bluffer = w.demon()
	var mate = w.living().filter(func(p): return p.is_evil() and p != bluffer)
	var good = w.living_good()
	var reported: Array = [
		{"kind": "saw", "who": good[0].id, "block": bluffer.home_block, "day": 2, "phase": C.NIGHT, "how": "street"},
		{"kind": "saw", "who": good[1].id, "block": bluffer.home_block, "day": 1, "phase": C.NIGHT, "how": "street"},
		{"kind": "saw", "who": good[2].id, "block": bluffer.home_block, "day": 2, "phase": C.NIGHT, "how": "window"},
	]
	if not mate.is_empty():
		bluffer.beliefs.append({"kind": "saw", "who": mate[0].id, "block": bluffer.home_block, "day": 2, "phase": C.NIGHT, "how": "street"})
	var ov: Dictionary = rdef.override_night_sightings(w, bluffer, 2, reported)
	var whos: Array = ov.get("reported", []).map(func(b): return b.who)
	_check(ov.get("handled", false) and whos == [good[0].id], "evil Monitor bluffer reports only the night asked, from the filtered list, no window sightings")
	_check(mate.is_empty() or not mate[0].id in whos, "and never a teammate")

	var cdef = C.role_def("confessor")
	_check(cdef.clears({"target": good[0].id, "good": true}) == [good[0].id], "a remembered confession clears the confessed")
	_check(cdef.clears({"forgot": true}).is_empty(), "a forgotten one clears nobody")

	# Marked: one roll. Over many seeds the Confessor's misread rate is MARKED_EVIL_CHANCE,
	# not the ~75% the second roll gave; and the misread is recorded as false.
	var conf = good[0]
	_give_role(w, conf, "confessor")
	conf.poisoned = false
	conf.secret_mod = ""
	var tgt = good[1]
	tgt.secret_mod = "marked"
	w.day = 2
	var forgot: int = 0
	var false_ok: bool = true
	for i in range(400):
		w.rng.seed = 90000 + i
		var r: Dictionary = cdef.generate_reading(w, conf, {"confessor_t": tgt.id}, Mind)
		if bool(r.data.get("forgot", false)):
			forgot += 1
			false_ok = false_ok and not bool(r["true"])
	var rate: float = forgot / 400.0
	_check(absf(rate - Tuning.Setup.MARKED_EVIL_CHANCE) < 0.08, "Confessor reads a Marked soul as evil at the Marked chance (%.2f vs %.2f)" % [rate, Tuning.Setup.MARKED_EVIL_CHANCE])
	_check(false_ok, "a Marked misread is recorded as a false reading")
