## How evil plays: bluffs and fake readings, framing and planters, demon targeting, Scion and Revenant scoring, threat intel.
## Merged from: test_backlog_batch2, test_claude_audit_cleanup, test_fixes, test_phase2_bug_sweep, test_phase4_1_reveal_and_rumor_pacing, test_phase4_3_framing_and_vigil_physics, test_playtest_nov4_fixes, test_playtest_regressions.
extends SceneTree

const Game = preload("res://game/game.gd")
const Evil = preload("res://sim/evil.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
const Jury = preload("res://workshop/jury.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const CaseMetrics = preload("res://game/case_metrics.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Tuning = preload("res://sim/tuning.gd")
const Social = preload("res://sim/social.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_backlog_batch2()
	_run_fixes()
	_run_claude_audit_cleanup()
	_run_phase2_bug_sweep()
	_run_phase4_1_reveal_and_rumo()
	_run_phase4_3_framing_and_vig()
	_run_playtest_nov4_fixes()
	_run_playtest_regressions()
	print("Evil play: %d checks, %d failures" % [checks, fails])
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


# ---------------------------------------------------------------- from test_backlog_batch2

func _run_backlog_batch2() -> void:
	_medium_hearths()


# ---------------------------------------------------------------- from test_fixes

func _run_fixes() -> void:
	_medium_bluff()
	_zag()


# ---------------------------------------------------------------- from test_claude_audit_cleanup

func _run_claude_audit_cleanup() -> void:
	_test_dowser_bluff_can_report_two_plus()


# ---------------------------------------------------------------- from test_phase2_bug_sweep

func _run_phase2_bug_sweep() -> void:
	_test_2_6_scion_revenant_scoring_and_grimoire()
	_test_2_7_night0_nightwatch_impairment_and_cleanups()


# ---------------------------------------------------------------- from test_phase4_1_reveal_and_rumor_pacing

func _run_phase4_1_reveal_and_rumo() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	_test_threat_intel_escalation()


# ---------------------------------------------------------------- from test_phase4_3_framing_and_vigil_physics

func _run_phase4_3_framing_and_vig() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	_test_evil_daily_planter_and_meeting_patience()


# ---------------------------------------------------------------- from test_playtest_nov4_fixes

func _run_playtest_nov4_fixes() -> void:
	_test_evil_promised_vigil_and_ward_avoidance()
	_test_scion_cover_and_doomed_demon_votes()


# ---------------------------------------------------------------- from test_playtest_regressions

func _run_playtest_regressions() -> void:
	_survival()
	_medium_fake_dead_reading_fallback()


# ---- test_backlog_batch2


func fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch2_tests"
	g.new_case(4242, 10)
	return g


func _medium_hearths() -> void:
	var g = fresh()
	var w = g.w
	var goods: Array = w.living_good()
	var m = goods[0]
	var older = goods[1]
	var recent = goods[2]
	var executed = goods[3]
	check(w._medium_choice(m) == "", "no Medium visit before any Demon death")
	for victim in [older, recent, executed]:
		victim.alive = false
		victim.beliefs = []
		victim.suspicion = {}
		victim.info_log = []
		victim.warden_log = {}
	older.death_cause = "demon"
	older.death_day = 1
	recent.death_cause = "demon"
	recent.death_day = 2
	executed.death_cause = "executed"
	executed.death_day = 9
	check([w._medium_choice(m), w._medium_choice(m), w._medium_choice(m)] == [recent.id, older.id, recent.id], "only Demon victims are visited; exhausted hearths revisit the newest")
	check(m.medium_visited.size() == 2, "revisits do not duplicate the visited set")
	recent.info_log = [{"role": "seer", "day": 1, "shared": false, "text": "first", "data": {}}, {"role": "seer", "day": 2, "shared": false, "text": "second", "data": {}}]
	var first = w._medium_item(m, recent, false)
	var second = w._medium_item(m, recent, false)
	check(first.type == "reading" and second.type == "reading" and first.entry.text == "first" and second.entry.text == "second", "a revisited hearth can reveal another untold reading")
	check(w._medium_item(m, recent, false).type == "nothing" and w._medium_item(m, older, false).type == "nothing", "exhausted and empty hearths report nothing new")
	var fake = w.minion()
	w.evil_plan.bluffs = {fake.id: "medium"}
	w.evil_plan.scapegoat = goods[4].id
	var state = w.rng.state
	check(Evil._fake_medium_item(w, fake, executed, goods[4].id).is_empty() and w.rng.state == state, "fake reports reject executed hearths without a random choice")
	var visited: Array = []
	for day in [3, 4, 5]:
		w.day = day
		Evil.make_fake_info(w)
		var entries: Array = fake.info_log.filter(func(e): return e.role == "medium" and e.day == day)
		check(entries.size() == 1, "the fake Medium produces one report on a visit/revisit")
		if entries.size() == 1:
			visited.append(entries[0].data.dead)
	check(visited == [recent.id, older.id, recent.id], "fake hearth sequence matches real eligibility and revisits")


# ---- test_fixes


func _game(sd: int, size: int = 10):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


func _medium_bluff() -> void:
	var g = _game(7103)
	var w = g.w
	var ev = w.npcs.filter(func(x): return x.is_evil())[0]
	var dead = w.npcs.filter(func(x): return not x.is_evil() and x != ev and x.home_block != "docks")[0]
	dead.alive = false
	dead.death_day = 1
	dead.death_cause = "demon"
	ev.claimed_role = "medium"
	ev.claim_public = true
	ev.info_log.append({"day": 2, "role": "medium", "fake": true, "data": {"dead": dead.id, "item": {}}, "text": "x"})
	ev.history[w.time_key(2, C.NIGHT)] = "night:docks"
	w.day = 3
	var r = Mind.answer_night(w, ev, 2)
	var out: Array = r["facts"].filter(func(f): return f.get("duty_claim", false))
	_check(not out.is_empty() and out[0]["block"] == dead.home_block, "evil Medium claims the hearth's block (%s), not where they were (docks)" % dead.home_block)
	_check(r["lines"].any(func(l): return l is Dictionary and dead.name in l["text"]), "the Medium names whose hearth")
	# Fake readings can only visit corpses from an earlier night, then revisit the most recent.
	var fresh = _game(7104)
	var w2 = fresh.w
	var mate = w2.npcs.filter(func(x): return x.is_evil())[0]
	w2.evil_plan["bluffs"][mate.id] = "medium"
	var goods: Array = w2.npcs.filter(func(x): return not x.is_evil())
	goods[0].alive = false
	goods[0].death_day = 1
	goods[0].death_cause = "demon"
	goods[1].alive = false
	goods[1].death_day = 2
	goods[1].death_cause = "demon"
	var seen: Array = []
	for d in [2, 3, 4]:
		w2.day = d
		Evil.make_fake_info(w2)
		for e in mate.info_log:
			if e.get("role", "") == "medium" and e.get("day", -1) == d:
				seen.append(e["data"]["dead"])
	_check(seen == [goods[0].id, goods[1].id, goods[1].id], "fake Medium readings: Demon victims first, then revisit the most recent (%s)" % str(seen))


func _zag() -> void:
	var zags = 0
	var nights = 0
	for sd in range(7200, 7240):
		var g = _game(sd, 7)
		for i in range(3):
			Evil.choose_kill_target(g.w)
			nights += 1
		for e in g.w.dlog.entries:
			if e["type"] == "think" and e["data"].get("topic", "") == "kill_choice" and e["data"].get("zag", false):
				zags += 1
	_check(zags >= 1 and zags <= nights * 0.12, "the demon sometimes skips its top three (%d of %d choices)" % [zags, nights])


# ---- test_claude_audit_cleanup


func _test_dowser_bluff_can_report_two_plus() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var w = g.w
	w.day = 2
	var evil_actor = w.demon()
	var goods: Array = w.living_good()
	# Place evil_actor and 4 good villagers (including scapegoat) on the same block, and move any minion elsewhere.
	var blk: String = "market"
	for m in w.living():
		m.loc = "wharf" # docks
	evil_actor.loc = "tavern" # market
	for i in range(4):
		goods[i].loc = "tavern"
	var scapegoat_id: String = goods[0].id
	var dw = C.role_def("dowser")
	var saw_one: bool = false
	var saw_two: bool = false
	for trial in range(80):
		evil_actor.dowsed_day = -1
		var res: Dictionary = dw.generate_bluff_reading(w, evil_actor, {}, scapegoat_id, null, [])
		var cnt: int = int(res.get("entry", {}).get("data", {}).get("count", -1))
		if cnt == 1:
			saw_one = true
		elif cnt == 2:
			saw_two = true
	_check(saw_one and saw_two, "Dowser bluff in a 4+ all-Good crowd can report both 1 and 2 evil")


# ---- test_phase2_bug_sweep


func _test_2_6_scion_revenant_scoring_and_grimoire() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var orig_demon = g.w.demon()
	var scion = g.w.by_id[g.w.minion_ids[0]]
	scion.role = "scion"
	g.set_guess(orig_demon.id, "demon", 4)
	g.capture_prediction("before_execution", {"on_block": orig_demon.id})
	g.w.executions.append({"day": 2, "id": orig_demon.id, "nominator": "player", "yes": [], "player_yes": true, "player_nominated": true})
	C.role_def("scion").promote_to_demon(g.w, scion)
	# Player later updates Demon guess to chase a wrong new suspect after Scion rises.
	var wrong_suspect = g.w.living_good()[0]
	g.set_guess(wrong_suspect.id, "demon", 2)
	var final_snap: Dictionary = g.capture_prediction("before_night")
	var summary_pre: Dictionary = CaseMetrics.summarize(g.w, final_snap, false, g.board, g.prediction_snapshots)
	_check(summary_pre["demon_identified"], "CaseMetrics credits Demon identification when pre-execution snapshot named the hung original Demon")

	# Also credits naming the promoted Scion directly at the end.
	g.set_guess(scion.id, "demon", 4)
	var snap_scion: Dictionary = g.capture_prediction("before_execution", {"on_block": scion.id})
	var summary_scion: Dictionary = CaseMetrics.summarize(g.w, snap_scion, false, g.board, [])
	_check(summary_scion["demon_identified"], "CaseMetrics credits naming the active promoted Scion Demon")

	# Grimoire labels for promoted Scion and Revenant-cursed Good villager.
	var cursed_good = g.w.living_good()[1]
	cursed_good.role = "warden"
	g.w.turn_evil(cursed_good, "Revenant curse")
	var grim: String = g._grimoire()
	_check("Scion (promoted to Demon)" in grim, "Grimoire labels promoted Scion clearly")
	_check("turned evil by the Revenant on day" in grim and not ("bluffed Warden" in grim), "Grimoire labels Revenant-cursed Good villager without 'bluffed Warden'")


func _test_2_7_night0_nightwatch_impairment_and_cleanups() -> void:
	# 1) Fair Night-0 Night Watch impairment: poisoned N0 Night Watch naming the Demon never zeroes P(Demon).
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id.to_upper(), "home": "hill" if id == "a" else ("market" if id == "b" else "square")})
	var view = {
		"people": people,
		"cards": [],
		"evil_count": 2,
		"alignment_epoch": "Original alignment",
		"live_activity": true,
		"timeline": {"events": [{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}}]},
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked", "delusional"]},
	}
	var n0_watch = {"id": "nw0", "fact_id": "nw0", "kind": "report", "source": "b", "role": "nightwatch", "night": 0, "data": {"block": "market", "seen": ["a"]}, "observed_at": {"day": 0, "phase": "night"}}
	var n1_sight = {"id": "s1", "fact_id": "s1", "kind": "sighting", "source": "player", "subject": "a", "subjects": ["a"], "night": 1, "block": "square", "data": {}, "role": "", "observed_at": {"day": 1, "phase": "night"}}
	view.cards = [n0_watch, n1_sight]
	var factors: Array = Activity.factors(view, view.cards, {})
	var demon_world = {"evil": (1 << 0) | (1 << 2), "demon": 0, "marked": 3, "modifier": "marked", "holders": 1 << 3}
	var score_a_demon: float = Activity.score(demon_world, factors[0])
	_check(score_a_demon > 0.01, "Night-0 Night Watch decoy sighting uses realistic impairment floor instead of zeroing Demon world (score=%.4f)" % score_a_demon)

	# 2) Clemency non-stacking Rapport loss on nominator who suspects nominee.
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var nom_by = g.w.living_good()[0]
	var nominee = g.w.living_good()[1]
	nom_by.trust = 0.60
	nom_by.suspicion[nominee.id] = 0.85
	g.w.begin_meeting()
	g.w.open_nomination(nom_by.id, nominee.id, "suspect")
	g.w.clemency()
	_check(is_equal_approx(nom_by.trust, 0.50), "Clemency applies single -0.10 max Rapport loss on suspicious nominator instead of -0.18 (got %.3f)" % nom_by.trust)

	# 3) Seer scattered look avoids re-checking already-checked pair while unchecked pairs exist.
	var seer = g.w.living_good()[2]
	seer.role = "seer"
	seer.traits["insight"] = 0.0
	var pool: Array = Mind.ranked_suspects(g.w, seer)
	seer.info_log = []
	for i_p in range(pool.size()):
		for j_p in range(i_p + 1, pool.size()):
			if not (i_p == 0 and j_p == 1):
				seer.info_log.append({"day": 1, "role": "seer", "data": {"pair": [pool[i_p].id, pool[j_p].id], "yes": false}, "true": true, "shared": false, "text": "no"})
	g.w.day = 2
	var picked_pair: Array = C.role_def("seer").pick_targets(g.w, seer, Mind)
	picked_pair.sort()
	var expected_only: Array = [pool[0].id, pool[1].id]
	expected_only.sort()
	_check(picked_pair == expected_only, "Seer scattered look selects the remaining unchecked pair instead of repeating a checked pair")

	# 4) Legacy street mud drops suppressed during Game._search while personal belongings still surface.
	var loc_key: String = C.LOCATIONS.keys()[0]
	g.w.dropped[loc_key] = [{"night": 1, "material": "market", "owner": "", "who": nominee.id, "why": "walk"}]
	var cards_before: int = g.board.size()
	g.loc = loc_key
	g._search()
	_check(g.board.size() == cards_before, "unowned legacy street mud drops do not mint board cards during search")

	# 5) Spoken unshared bluff claims (`watch_claim` / `duty_claim`) normalize to `report` and support `lying` challenges.
	var bluffer = g.w.demon()
	var watch_card_num: int = g.add_card({
		"kind": "sighting", "subject": [bluffer.id], "block": "hill", "day": 1, "phase": C.NIGHT,
		"source": bluffer.id, "watch_claim": true, "text": "%s says they kept watch on Chapel Hill on night 1." % bluffer.name,
	})
	var vig_num: int = g.add_card({
		"kind": "vigil", "subject": [], "block": "hill", "day": 1, "phase": C.NIGHT,
		"source": "player", "vigil": true, "text": "Night 1 vigil: nobody came to Chapel Hill.",
	})
	var cview: Dictionary = WorkshopCanvas.view(g)
	var wc_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[watch_card_num - 1]).id
	var vg_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[vig_num - 1]).id
	var cm = CanvasModel.new(cview)
	var root_id: String = cm.selected
	cm.nodes[root_id].conclusion = {"type": "evil", "target": bluffer.id, "at": cview.alignment_epoch}
	cm.connect_cards("e:" + wc_id, root_id)
	_check(cm.add_modifier("e:" + wc_id, "lying") == "", "spoken watch_claim card accepts lying modifier in Workshop")
	var mod_id: String = cm.selected
	cm.connect_cards("e:" + vg_id, mod_id)
	cm.connect_cards("e:" + vg_id, root_id)
	var preview: Dictionary = Ghost.live(WorkshopCanvas.snapshot(g, cm.compile(root_id)))
	_check(preview.ready, "spoken watch_claim with lying challenge evaluates cleanly in live Workshop")

	var lamp_duty_num: int = g.add_card({
		"kind": "sighting", "subject": [bluffer.id], "block": "hill", "day": 1, "phase": C.NIGHT,
		"source": bluffer.id, "duty_claim": true, "duty": "lamplighter", "text": "%s says they were out on Chapel Hill on night 1 (the lamp route)." % bluffer.name,
	})
	var cview2: Dictionary = WorkshopCanvas.view(g)
	var lc_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[lamp_duty_num - 1]).id
	var cm2 = CanvasModel.new(cview2)
	var root2: String = cm2.selected
	cm2.nodes[root2].conclusion = {"type": "evil", "target": bluffer.id, "at": cview2.alignment_epoch}
	cm2.connect_cards("e:" + lc_id, root2)
	_check(cm2.add_modifier("e:" + lc_id, "lying") == "", "spoken duty_claim (Lamplighter) card accepts lying modifier in Workshop")
	var mod2: String = cm2.selected
	cm2.connect_cards("e:" + vg_id, mod2)
	cm2.connect_cards("e:" + vg_id, root2)
	var preview2: Dictionary = Ghost.live(WorkshopCanvas.snapshot(g, cm2.compile(root2)))
	_check(preview2.ready, "spoken duty_claim with lying challenge evaluates cleanly in live Workshop")

	# 6) Dialogue & Jury copy checks: Constance Day 1 Morning reveal & Greta non-visual doubted line.
	var constance = g.w.by_id.get("constance")
	if constance != null:
		constance.max_tier = 0
		constance.claim_public = false
		constance.trust = 1.0
		constance.traits["privacy"] = 0.0
		g.w.day = 1
		g.w.phase = C.MORNING
		var rev_d1: Dictionary = Mind.answer_gift(g.w, constance, 3, false)
		var joined_d1: String = " ".join(PackedStringArray(rev_d1["lines"].map(func(l): return l.get("text", "") if l is Dictionary else str(l))))
		_check(not ("conducted this inquiry properly" in joined_d1), "Constance Day 1 Morning private reveal avoids premature 'conducted this inquiry properly'")
	var greta = g.w.by_id.get("greta")
	if greta != null:
		var non_vis_resp = {"lines": [{"speaker": "greta", "name": "Greta", "text": "I remained at home."}]}
		Mind._challenged(greta, non_vis_resp, {"kind": "alibi", "source": "greta", "day": 1})
		_check(not ("eyes are going" in non_vis_resp["lines"][0]["text"]), "Greta non-visual doubted line omits eyesight phrasing")
		var vis_resp = {"lines": [{"speaker": "greta", "name": "Greta", "text": "I saw them on Market."}]}
		greta.dialogue_memory.clear()
		Mind._challenged(greta, vis_resp, {"kind": "sighting", "source": "greta", "day": 1})
		_check("eyes are going" in vis_resp["lines"][0]["text"], "Greta visual sighting doubted line retains eyesight phrasing")

	# Movement-only vs trace-only Jury label separation.
	_check(Jury._movement_trace_kind({}, [{"kind": "sighting"}]) == "movement", "movement-only cards report 'movement'")
	_check(Jury._movement_trace_kind({}, [{"kind": "trace"}]) == "trace", "trace-only cards report 'trace'")
	_check(Jury._movement_trace_kind({}, [{"kind": "sighting"}, {"kind": "trace"}]) == "movement and trace", "combined movement+trace cards report 'movement and trace'")


# ---- test_phase4_1_reveal_and_rumor_pacing


func _test_threat_intel_escalation() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var w = g.w
	var a = w.evil_team()[0]
	var b = w.evil_team()[1]
	var speaker = w.living_good()[0]
	a.intel.clear()
	b.intel.clear()
	var item: Dictionary = {"kind": "unease", "about": a.id}
	Evil.intel_from_share(w, a, speaker, item)
	_check(is_equal_approx(Evil.intel_threat(a, speaker.id), 0.5), "mild unease starts as half-strength threat intel")
	Evil.share_intel(w, a, b, "test unease")
	_check(is_equal_approx(Evil.intel_threat(b, speaker.id), 0.5) and Evil.unshared_intel(a, b) == 0, "pooled unease is shared once")
	for kind in ["opinion", "case"]:
		item.kind = kind
		Evil.intel_from_share(w, a, speaker, item)
		_check(is_equal_approx(Evil.intel_threat(a, speaker.id), 1.0), "stronger %s upgrades an existing threat without stacking" % kind)
		if kind == "opinion":
			_check(Evil.unshared_intel(a, b) == 1, "a threat upgrade counts as news for a teammate with stale intel")
	Evil.share_intel(w, b, a, "test reverse pool")
	_check(is_equal_approx(Evil.intel_threat(a, speaker.id), 1.0) and is_equal_approx(Evil.intel_threat(b, speaker.id), 1.0), "stronger threat survives reverse-order pooling and reaches the stale teammate")
	item.kind = "unease"
	Evil.intel_from_share(w, a, speaker, item)
	Evil.share_intel(w, a, b, "test repeat")
	_check(a.intel.size() == 1 and b.intel.size() == 1 and is_equal_approx(Evil.intel_threat(a, speaker.id), 1.0) and Evil.unshared_intel(a, b) == 0, "repeated or weaker intel cannot downgrade or duplicate an upgraded threat")


# ---- test_phase4_3_framing_and_vigil_physics


func _test_evil_daily_planter_and_meeting_patience() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(98933, 10)
	var w = g.w
	var demon = w.demon()
	var minions: Array = w.evil_team().filter(func(m): return m != demon)
	var m1 = minions[0]
	var m2 = minions[1]
	var goods: Array = w.living_good()
	var sg = goods[0]
	var victim = goods[1]
	var gossip_good = goods[2]

	# Configure a clean Day 2 murder on Market where Minion m1 lives on Market and sg lives on Docks.
	w.day = 2
	m1.home_block = "market"
	m2.home_block = "hill"
	demon.home_block = "square"
	sg.home_block = "docks"
	m1.traits["gossip"] = 0.75
	m2.traits["gossip"] = 0.40
	demon.traits["gossip"] = 0.90
	w.evil_plan["scapegoat"] = sg.id
	w.evil_plan["bluffs"][m1.id] = "rumormonger"
	w.evil_plan["bluffs"][m2.id] = "archivist"
	w.evil_plan["fake_sightings"] = {}
	w.scenes["scene_test"] = {"day": 1, "block": "market", "victim": victim.id}

	# Even if the player privately kept a Vigil on Market (seeing nobody), Evil cannot peek at it!
	g.add_card({"kind": "vigil", "source": "player", "subject": [], "day": 1, "phase": C.NIGHT, "block": "market", "text": "Cold vigil on Market: nobody."})
	Evil.plan_daily_frame(w)
	var planter_id: String = str(w.evil_plan.get("daily_planter", ""))
	var ps: Dictionary = w.evil_plan.get("planter_sighting", {})
	_check(planter_id == m1.id, "plan_daily_frame prefers eligible Minion over higher-gossip Demon (%s vs %s)" % [planter_id, m1.id])
	_check(ps.get("block", "") == "market" and ps.get("how", "") == "window" and ps.get("who", "") == sg.id,
		"daily_planter prepares coherent death-block window frame without peeking at private player vigil")

	# Non-planter teammate is locked out of inventing a competing Night-1 sighting on scapegoat.
	var non_planter_fs = Evil.fake_night_sighting(w, m2, 1)
	_check(non_planter_fs == null, "non-planter Evil teammate is locked out of inventing competing Night-1 scapegoat sightings")

	# Whisper pairing bonus targets high-Gossip trusting Good townsfolk until MAX_DIRECT_PLANTS is reached.
	gossip_good.traits["gossip"] = 0.80
	gossip_good.npc_trust[m1.id] = 0.65
	var nb_active: float = Social.news_bonus(w, m1, gossip_good)
	_check(nb_active >= Tuning.Social.PLANTER_WHISPER_BONUS - 1e-5, "daily_planter receives +0.65 whisper news_bonus with trusting high-gossip villager (%.2f)" % nb_active)

	var plant_item = {"kind": "sighting", "about": sg.id, "block": "market", "day": 1, "from": m1.id, "key": "sighting:%s:1" % sg.id, "lie": true}
	Social._deliver(w, m1, gossip_good, plant_item)
	Social._deliver(w, m1, goods[3], plant_item)
	_check(int(w.evil_plan.get("plants_today", 0)) == 2, "plants_today increments on direct planter whispers to Good villagers")
	_check(is_zero_approx(Social.news_bonus(w, m1, goods[4])), "daily_planter whisper bonus stops once MAX_DIRECT_PLANTS (2) is reached")

	# Rule 4 (Meeting Patience): non-planter Evil does not echo meeting_agree_accuse before any Good villager speaks.
	w.meeting = {"block": "", "block_count": 0, "nominated": [], "nominators": [], "results": [], "pending": {}, "accusations": [{"by": m1.id, "target": sg.id}]}
	m2.traits["confidence"] = 1.0
	var premature_echo = Mind.MindMeeting._public_accusation(w, m2)
	_check(premature_echo == null, "Rule 4: non-planter Evil teammate holds back from echoing scapegoat accusation before any Good voice")
	w.meeting["accusations"].append({"by": gossip_good.id, "target": sg.id})
	var backed_echo = Mind.MindMeeting._public_accusation(w, m2)
	_check(backed_echo != null and backed_echo.get("fact", {}).get("subject", []) == [sg.id],
		"Rule 4: once a Good villager accuses scapegoat, Evil teammate can join in")


# ---- test_playtest_nov4_fixes


func _test_evil_promised_vigil_and_ward_avoidance() -> void:
	var g = Game.new()
	g.new_case(95955, 10)
	var w = g.w
	w.day = 1
	w.phase = C.AFTERNOON
	var d = w.demon()
	var goods: Array = w.living_good()
	var same_block_good = goods[0]
	same_block_good.home_block = d.home_block
	var alt_blk: String = "square" if d.home_block != "square" else "docks"
	for idx in range(1, goods.size()):
		goods[idx].home_block = alt_blk
	same_block_good.claim_public = true
	same_block_good.claimed_role = "seer"
	w.public_claims.append({"day": 1, "who": same_block_good.id, "role": "seer"})
	# Demon receives a vigil promise on their own home block (like Jory in 95955).
	g._offer_command(d, "vigil", true)
	_check(Evil._knows_promised_vigil_tonight(d, d.home_block, w.day),
		"GameConversation._offer_command records promised vigil block in evil recipient's intel")
	var kt: String = Evil.choose_kill_target(w)
	_check(kt != "" and w.by_id[kt].home_block != d.home_block,
		"Demon avoids killing on a block where it asked for / received a player vigil (%s on %s vs vigil %s)" % [kt, w.by_id[kt].home_block if kt != "" else "?", d.home_block])

	# Minion receives vigil promise and passes it to Demon via share_intel (no telepathy before meeting).
	var m = w.minion()
	w.day = 2
	m.home_block = alt_blk
	g.offer = {}
	g._offer_command(m, "vigil", false)
	_check(Evil._knows_promised_vigil_tonight(m, alt_blk, 2) and not Evil._knows_promised_vigil_tonight(d, alt_blk, 2),
		"Minion vigil promise is not telepathically known to Demon before conversing")
	Social.converse(w, d, m, "afternoon")
	_check(Evil._knows_promised_vigil_tonight(d, alt_blk, 2),
		"Demon learns Minion's promised vigil block once teammates pool intel via Social.converse")


func _test_scion_cover_and_doomed_demon_votes() -> void:
	var g = Game.new()
	g.new_case(40741, 10)
	var w = g.w
	w.day = 2
	w.begin_meeting()
	var d = w.demon()
	var sc = w.living_with_role("scion")
	if sc == null:
		sc = w.minion()
		sc.role = "scion"
	sc.poisoned = false
	_check(Evil.scion_fallback_active(w),
		"scion_fallback_active is true with unbroken Scion and >= 5 living NPCs")
	_check(Evil.teammate_value(w, sc.id) > Evil.teammate_value(w, d.id),
		"Active Scion carries higher teammate_value than replaceable Demon (%.2f vs %.2f)" % [Evil.teammate_value(w, sc.id), Evil.teammate_value(w, d.id)])

	# Landslide Demon vote with active Scion: exposed Scion whose good shadow votes YES keeps cover.
	sc.pressure = 1.2
	w.meeting["nominated"].append(d.id)
	Mind.shadow_run(w, sc, func(sh):
		sh.suspicion[d.id] = 0.95
		sh.workshop_state["outside"][d.id] = 0.95)
	var sh_yes = Mind.shadow_eval(w, sc, func(sh): return Mind.vote(w, sh, d.id, "player", true, "accuse", 6))
	_check(sh_yes == true, "Scion's good shadow wants to vote YES on heavily implicated Demon")
	var sc_vote: bool = Mind.vote(w, sc, d.id, "player", true, "accuse", 6)
	_check(sc_vote == true,
		"Exposed Scion votes YES with town landslide on Demon to preserve cover for succession")

	# Without active Scion (< 5 alive), even an exposed minion still votes NO on the Demon, and a Demon on the block backs a live rescue nomination.
	var kept: int = 0
	for p in w.npcs:
		if p == d or p == sc:
			p.alive = true
		elif kept < 2:
			p.alive = true
			kept += 1
		else:
			p.alive = false
	_check(not Evil.scion_fallback_active(w),
		"scion_fallback_active is false once fewer than 5 NPCs remain alive")
	_check(not Mind.vote(w, sc, d.id, "player", false, "", 0),
		"Without active Scion fallback, evil teammate still refuses to vote YES on the Demon")
	var villager = w.living_good()[0]
	w.meeting["block"] = d.id
	w.meeting["block_count"] = 2
	d.pressure = 3.0
	var rescue_vote: bool = Mind.vote(w, d, villager.id, sc.id, false, "", 1)
	_check(rescue_vote == true,
		"Doomed Demon on the block without Scion fallback backs mathematically live rescue counter-nomination")


# ---- test_playtest_regressions


func playtest_regressions__game():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(25923, 10)
	return g


func _survival() -> void:
	var g = playtest_regressions__game()
	var w = g.w
	# An evil minion (the deal decides who; Isolde was the Revenant before the night-walker band).
	var n = w.minions().filter(func(x): return x.role != "scion")[0] if w.minions().any(func(x): return x.role != "scion") else w.minions()[0]
	var demon = w.demon()
	# Without a Scion ready to inherit (patch_012 lets evil spend the demon when one is).
	for sc in w.npcs.filter(func(x): return x.role == "scion"):
		sc.alive = false
	w.day = 5
	w.begin_meeting()
	n.pressure = 10.0
	w.meeting["nominated"].append(n.id)
	Mind.shadow_run(w, n, func(sh): Mind.adjust(w, sh, demon.id, 5.0, "a persuasive public case"))
	var shadow_vote = Mind.shadow_eval(w, n, func(sh): return Mind.vote(w, sh, demon.id, "player", false, "", 0))
	_check(shadow_vote == true, "regression setup: the good shadow wants to execute the demon")
	_check(not Mind.vote(w, n, demon.id, "player", false, "", 0), "an early evil vote cannot sacrifice the demon to maintain cover")
	var nomination = Mind._evil_nomination(w, n, w.meeting, "")
	_check(nomination == null or nomination["nominee"] != demon.id, "even an exposed minion refuses its shadow's demon nomination")
	# A plausible Warden alibi is allowed to name a teammate.
	for other in w.npcs:
		if other != n and other != demon:
			other.alive = false
	n.warden_log.clear()
	n.history[w.time_key(4, C.NIGHT)] = "home:" + n.home_block
	_check(Mind.warden_door(w, n, 4) == demon.id, "a claimed protection target is not a guaranteed non-teammate")


func _medium_fake_dead_reading_fallback() -> void:
	var g = playtest_regressions__game()
	var w = g.w
	var evil_npc = w.demon()
	var dd = w.living_good()[0]
	var sg = w.living_good()[1]
	w.evil_plan["scapegoat"] = sg.id
	var ok = true
	for role in ["rumormonger", "lamplighter", "veteran", "martyr"]:  # surveyor has its own (patch_011)
		var res: Dictionary = Mind.Evil._fake_dead_reading(w, evil_npc, dd, role, sg.id, 1)
		if not res.is_empty():
			ok = false
	_check(ok, "Evil._fake_dead_reading safely returns {} for roles without custom fabricated Medium relays")
