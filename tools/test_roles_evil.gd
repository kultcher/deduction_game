## Evil roles: the Demon's targeting, Poisoner, Breathstealer, Revenant (totem and curse), Scion, Brute.
## Merged from: test_chunk6a_sexton_brute, test_mechanics_curse, test_roster.
extends SceneTree

const World = preload("res://sim/world.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const History = preload("res://workshop/live_history.gd")
const Solver = preload("res://workshop/solver.gd")
const ScriptBuilder = preload("res://sim/script_builder.gd")
const BruteDef = preload("res://sim/roles/brute.gd")
const Tuning = preload("res://sim/tuning.gd")
const ScriptDef = preload("res://sim/script_def.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_roster()
	_run_mechanics_curse()
	_run_chunk6a_sexton_brute()
	print("Roles: evil: %d checks, %d failures" % [checks, fails])
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
	_test_revenant_curse()
	_test_revenant_fizzle()
	_test_totem_once_per_day()
	_test_scion()
	_test_breathstealer()
	_test_spent_gift_kills()


# ---------------------------------------------------------------- from test_mechanics_curse

func _run_mechanics_curse() -> void:
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


# ---------------------------------------------------------------- from test_chunk6a_sexton_brute

func _run_chunk6a_sexton_brute() -> void:
	_test_brute_registration_and_attributes()
	_test_brute_hunting_and_demon_idle()
	_test_brute_drops_two_traces()
	_test_brute_identifier_interactions()
	_test_brute_death_demon_resumes_hunt()
	_test_brute_experimental_on_scripts()
	_test_evil_reads_the_bell()
	_test_veteran_reads_the_hunter()


# ---- test_roster


## Pure World setup for multi-hundred-seed role/home/bluff distribution checks.
func _game(sd: int, size: int = 7):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


## Give a good NPC a role (swapping with whoever holds it, so roles stay unique).
func _world(sd: int, size: int = 7):
	var w = World.new()
	w.setup(sd, size)
	return w


func _give(w, n, role: String) -> void:
	var holder = w.npc_with_role(role)
	if holder != null and holder != n:
		holder.role = n.role
	n.role = role


func _revenant_world(sd: int):
	var w = _game(sd).w
	w.day = 2
	var rv = w.minions()[0]
	rv.role = "revenant"
	return w


func _test_revenant_curse() -> void:
	var w = _revenant_world(9110)
	var rv = w.minions()[0]
	w.totem = {"loc": "well", "day": 2, "owner": rv.id, "material": rv.home_block}
	var voter = w.living_good()[0]
	voter.info_log.append({"day": 1, "role": voter.role, "data": {}, "text": "real", "shared": true, "true": true})
	w.begin_meeting()
	w.execute(rv.id, {"by": "player", "yes": [voter.id], "player_yes": true})
	_check(voter.is_evil() and voter.turned and w.public_log.any(func(e): return e["kind"] == "curse"), "a hanged Revenant with a totem turns a good yes-voter, and the town is warned")
	_check(w.evil_plan["bluffs"].get(voter.id, "") == voter.role, "the turned keep claiming their own gift")
	voter.info_log.append({"day": 2, "role": voter.role, "data": {}, "text": "lie", "shared": false, "fake": true, "true": false})
	var t = w.find_totem("well")
	_check(not t.is_empty() and t["freed"] == voter.id and not voter.is_evil() and voter.intel.is_empty(), "finding the totem frees them, forgetting their team")
	_check(voter.info_log.back().get("disowned", false) and not voter.info_log[0].get("disowned", false), "they no longer stand by what they said while turned")


func _test_revenant_fizzle() -> void:
	var w = _revenant_world(9111)
	var rv = w.minions()[0]
	var voter = w.living_good()[0]
	w.begin_meeting()
	w.execute(rv.id, {"by": "player", "yes": [voter.id], "player_yes": true})
	_check(not voter.is_evil() and w.curse.is_empty(), "no totem in play: no curse")


func _test_totem_once_per_day() -> void:
	var placed_after_find = 0
	var placed_next_day = 0
	for sd in range(9120, 9140):
		var w = _revenant_world(sd)
		var rv = w.minions()[0]
		w.totem = {"loc": "well", "day": 1, "owner": rv.id, "material": rv.home_block}
		w.phase = C.MORNING
		w.start_phase()                      # a totem at dawn
		w.find_totem("well")                 # found in the morning
		for p in [C.AFTERNOON, C.EVENING]:
			w.phase = p
			rv.loc = "tavern"
			w._day_gifts()
		if not w.totem.is_empty():
			placed_after_find += 1
		w.day = 3
		w.phase = C.MORNING
		w.start_phase()
		for p in [C.MORNING, C.AFTERNOON, C.EVENING]:
			w.phase = p
			rv.loc = "tavern"
			w._day_gifts()
		if not w.totem.is_empty():
			placed_next_day += 1
	print("totem re-hidden the same day: %d/20; the next day: %d/20" % [placed_after_find, placed_next_day])
	_check(placed_after_find == 0 and placed_next_day == 20, "a found totem can only be replaced the next day")


func _test_scion() -> void:
	var w = _game(9130).w
	w.day = 2
	var sc = w.minions()[0]
	sc.role = "scion"
	var d = w.demon()
	w.begin_meeting()
	w.execute(d.id, {"by": "player", "yes": [], "player_yes": true})
	_check(not w.game_over and w.demon_id == sc.id and sc.role == "demon", "the demon hangs with 5+ alive: the Scion becomes the demon")
	var w2 = _game(9131).w
	w2.day = 4
	var sc2 = w2.minions()[0]
	sc2.role = "scion"
	var goods: Array = w2.living_good()
	for i in range(goods.size() - 2):
		goods[i].alive = false
	w2.begin_meeting()
	w2.execute(w2.demon_id, {"by": "player", "yes": [], "player_yes": true})
	_check(w2.game_over and w2.winner == "good", "with fewer than five alive, hanging the demon wins")


func _test_breathstealer() -> void:
	var w = _game(9160).w
	w.day = 2
	var bs = w.minions()[0]
	bs.role = "breathstealer"
	var t = w.living_good()[0]
	t.silence_pending = 2
	var testimony: Array = w.begin_meeting()
	_check(t.silenced and testimony.all(func(x): return x["who"] != t.id), "a silenced person says nothing at the meeting")
	_check(Mind.defence_line(w, t).get("silent", false), "...not even in their own defence")
	t.loc = "tavern"
	bs.breath_last = t.id
	var picked_again = 0
	for i in range(30):
		t.silenced = false
		t.silence_pending = -1
		bs.loc = t.loc
		if Evil.breath_target(w, bs) == t.id:
			picked_again += 1
	_check(picked_again == 0, "never the same person twice running")
	bs.breath_last = ""
	var saved_locs: Dictionary = {}
	for m in w.living_good():
		saved_locs[m.id] = m.loc
		m.loc = "home:" + m.home_block
	t.home_block = C.loc_block("tavern")
	t.loc = "home:" + t.home_block
	bs.loc = "tavern"
	_check(Evil.breath_target(w, bs) == "", "Breathstealer cannot target someone inside their home")
	for m in w.living_good():
		m.loc = saved_locs[m.id]
	w.day = 3
	w.phase = C.EVENING
	t.silenced = true
	t.silence_day = 2
	w.start_phase()
	_check(not t.silenced, "the silence lifts the next evening")


func _test_spent_gift_kills() -> void:
	var spent_picked = 0
	var tries = 0
	for sd in range(9300, 9330):
		var w = _world(sd)
		var goods: Array = w.living_good()
		var a = goods[0]
		var b = goods[1]
		_give(w, a, "archivist")
		_give(w, b, "seer")
		for pr in [[a, "archivist"], [b, "seer"]]:
			pr[0].claimed_role = pr[1]
			pr[0].claim_public = true
			w.public_claims.append({"day": 1, "who": pr[0].id, "role": pr[1]})
		w.day = 2
		var kt = Evil.choose_kill_target(w)
		if kt in [a.id, b.id]:
			tries += 1
			if kt == a.id:
				spent_picked += 1
	print("between a spent Archivist and a live Seer, the demon took the Archivist %d/%d" % [spent_picked, tries])
	_check(tries > 0 and spent_picked * 3 < tries, "the demon prefers a gift that keeps reporting")


# ---- test_mechanics_curse


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
	Mind.ledger_hear(g.w, observer, "curse:2", [], 1.0, [], {"kind": "event"})
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
	Mind.refresh_beliefs(g.w, observer, " (curse restoration test)")
	plan = Shared.prepare(Bridge.capture(g, [], observer.id), {}, observer.ledger)
	check(plan.ready and plan.prepared.view.chronology.curse.until == 13, "actual public restoration closes the epoch at its observed phase")
	var own = Bridge.capture(g, [], old_victim)
	check(not own.listener.disowned_reports.is_empty() and own.private_evidence.all(func(id): return id not in own.listener.disowned_reports), "a restored listener's disowned testimony is not firsthand evidence")


# ---- test_chunk6a_sexton_brute


func _give_role(w, n, role_id: String) -> void:
	n.role = role_id
	n.alignment = C.ROLES[role_id]["align"]
	if C.ROLES[role_id].get("minion", false):
		if n.id not in w.minion_ids:
			w.minion_ids.append(n.id)


func _test_brute_registration_and_attributes() -> void:
	_check(C.has_role_def("brute"), "Brute registered in role registry")
	var rdef = C.role_def("brute")
	_check(rdef.id == "brute", "Brute id matches")
	_check(rdef.align == "evil", "Brute align is evil")
	_check(rdef.kind == "evil", "Brute kind is evil")
	_check(rdef.minion, "Brute minion flag is true")
	_check(rdef.night_walk, "Brute night_walk is true")
	_check("brute" in C.MINION_ROLES, "Brute in C.MINION_ROLES")
	_check("brute" in C.EVIL_ROLES, "Brute in C.EVIL_ROLES")
	_check(not ("brute" in C.GOOD_ROLES), "Brute not in C.GOOD_ROLES")


func _test_brute_hunting_and_demon_idle() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(12345, 7)
	var w = g.w
	var evils = w.living().filter(func(p): return p.is_evil())
	var demon_npc = w.demon()
	var minion_npc = evils.filter(func(p): return p != demon_npc)[0]
	_give_role(w, minion_npc, "brute")

	w.day = 1
	var victim = w.living_good()[0]
	w.resolve_night()

	# While Brute is alive and active: Brute hunted and Demon stayed home
	_check(minion_npc.out_last_night, "Brute night-walked on the hunt")
	# The demon's chosen target (not necessarily living_good()[0]): read the Brute's hunt walk.
	var hunt: Array = w.night_walkers.filter(func(wk): return wk.id == minion_npc.id and "(as Brute)" in str(wk.why))
	var hunted: Array = w.living().filter(func(p): return not hunt.is_empty() and ("hunting %s (as Brute)" % p.name) == str(hunt[0].why))
	hunted.append_array(w.npcs.filter(func(p): return not p.alive and not hunt.is_empty() and ("hunting %s (as Brute)" % p.name) == str(hunt[0].why)))
	_check(not hunted.is_empty() and minion_npc.night_block == hunted[0].home_block, "Brute arrived at the hunted victim's home block")
	_check(not demon_npc.out_last_night, "Demon stayed home while Brute was hunting")
	_check(demon_npc.night_block == demon_npc.home_block, "Demon remained on their home block")


func _test_brute_drops_two_traces() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(23456, 7)
	var w = g.w
	var evils = w.living().filter(func(p): return p.is_evil())
	var demon_npc = w.demon()
	var minion_npc = evils.filter(func(p): return p != demon_npc)[0]
	_give_role(w, minion_npc, "brute")

	w.day = 1
	w.resolve_night()

	# Check the murder scene traces
	_check(w.deaths_last_night.size() == 1, "Victim was killed overnight")
	var victim_id = w.deaths_last_night[0]
	var sid = "scene_" + victim_id
	_check(w.scenes.has(sid), "Murder scene recorded")
	var sc = w.scenes[sid]
	_check(sc.traces.size() == 2, "Brute murder scene leaves exactly two physical traces")
	# Both traces point toward the Brute
	_check(sc.trace != null, "Primary trace exists")
	_check(sc.traces[1] != null, "Second trace exists")


func _test_brute_identifier_interactions() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(34567, 7)
	var w = g.w
	var evils = w.living().filter(func(p): return p.is_evil())
	var demon_npc = w.demon()
	var brute_npc = evils.filter(func(p): return p != demon_npc)[0]
	_give_role(w, brute_npc, "brute")

	var seer_npc = w.living_good()[0]
	_give_role(w, seer_npc, "seer")
	seer_npc.red_herring = ""

	var good_other = w.living_good()[1]
	good_other.secret_mod = ""

	# Seer reading on pair [brute, good_other] without demon or marked
	var rdef_seer = C.role_def("seer")
	var r_seer = rdef_seer.generate_reading(w, seer_npc, {}, Mind)
	# When checked against Brute: Brute does NOT register as demon
	_check(not w.registers_demon(brute_npc), "Brute does not register as the demon to Seer")

	# Archivist can target Brute as minion
	_check(C.is_minion("brute"), "Brute registers as a minion")


func _test_brute_death_demon_resumes_hunt() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(45678, 7)
	var w = g.w
	var evils = w.living().filter(func(p): return p.is_evil())
	var demon_npc = w.demon()
	var brute_npc = evils.filter(func(p): return p != demon_npc)[0]
	_give_role(w, brute_npc, "brute")

	# Execute or kill Brute
	brute_npc.alive = false
	brute_npc.death_day = 1
	brute_npc.death_cause = "executed"

	w.day = 1
	w.resolve_night()

	# Demon resumes hunting!
	_check(demon_npc.out_last_night, "Demon resumes hunting when Brute is dead")


## Maintenance 2026-11-05 A1: the bell stops the Breathstealer (choosing and the meeting).
func _test_brute_experimental_on_scripts() -> void:
	_check(BruteDef.new().status == "experimental", "Brute is marked experimental")
	_check(not ("brute" in ScriptDef.default_script().minions) and ScriptDef.default_script().is_default(), "the Default script leaves the Brute off")
	var drawn: bool = false
	for sd in range(1, 61):
		if "brute" in ScriptBuilder.dynamic({"seed": sd}).minions:
			drawn = true
	_check(not drawn, "60 dynamic scripts never draw the Brute")
	_check("brute" in ScriptBuilder.dynamic({"seed": 7, "include": ["brute"]}).minions, "a playtest 'include' mark still puts the Brute on")
	_check("brute" in ScriptDef.roster().minions, "the script editor still offers the Brute")


## Maintenance A12: the Veteran reads whoever hunted (the Brute, when it hunts).
func _test_evil_reads_the_bell() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(67890, 10)
	var w = g.w
	var minion = w.living().filter(func(p): return p.is_evil() and p != w.demon())[0]
	_give_role(w, minion, "scion")
	w.day = 2
	w.phase = C.EVENING
	w.sexton_tolled_night = 1
	w.sexton_suppression_night = 1
	var before: bool = Evil.scion_fallback_active(w)
	_check(before, "evil that hasn't heard of the bell still counts on the Scion")
	var sx = w.living_good()[0]
	_give_role(w, sx, "sexton")
	sx.gift_used = true
	var lines: Array = []
	var facts: Array = []
	C.role_def("sexton").on_public_claim(w, sx, lines, facts, Mind)
	_check(int(w.evil_plan.get("bell_believed", -1)) == 1, "a public toll tells evil the bell rang on night 1")
	_check(not lines.is_empty() and facts.any(func(f): return f.get("duty", "") == "sexton" and f.get("public", false)), "the Sexton tells the town of the toll, with a card")
	_check(not Evil.scion_fallback_active(w), "evil that believes the bell holds stops counting on the Scion")
	w.day = 3
	w.phase = C.MORNING
	_check(Evil.scion_fallback_active(w), "once the bell has worn off, the Scion counts again")
	# Revenant: fine to let it hang while its curse is ready, not under a believed bell.
	_give_role(w, minion, "revenant")
	w.totem = {"loc": "church", "day": 3, "owner": minion.id, "material": minion.home_block}
	_check(Evil.teammate_value(w, minion.id) < Tuning.Evil.TEAMMATE_VALUE_MINION, "a Revenant with its curse ready is worth less to protect")
	w.day = 2
	w.phase = C.EVENING
	_check(Evil.teammate_value(w, minion.id) >= Tuning.Evil.TEAMMATE_VALUE_MINION, "not while evil believes the bell holds (no curse)")


func _test_veteran_reads_the_hunter() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(67890, 10)
	var w = g.w
	var brute = w.living().filter(func(p): return p.is_evil() and p != w.demon())[0]
	_give_role(w, brute, "brute")
	brute.poisoned = false
	_check(w.night_killer() == brute, "an active Brute is tonight's killer")
	w.sexton_suppression_night = w.day
	w.phase = C.NIGHT
	_check(w.night_killer() == w.demon(), "under the bell the Demon hunts")
