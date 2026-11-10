## Workshop and shared-model behaviour pinned by past bugs: juror feedback, connections, presentation replies, ledger guards, caches.
## Merged from: test_backlog_batch4, test_claude_audit_cleanup, test_claude_batch, test_phase2_bug_sweep, test_phase4_3_framing_and_vigil_physics, test_playtest_nov4_fixes, test_playtest_regressions, test_workshop_slice5_voices_and_bot.
extends SceneTree

const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const Solver = preload("res://workshop/solver.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Jury = preload("res://workshop/jury.gd")
const Roles = preload("res://workshop/role_constraints.gd")
const Caches = preload("res://workshop/caches.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const TraceSolver = preload("res://workshop/trace_solver.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const GhostJuror = preload("res://workshop/ghost_juror.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Challenges = preload("res://workshop/reading_challenges.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Tuning = preload("res://sim/tuning.gd")
const Evil = preload("res://sim/evil.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Voices = preload("res://sim/dialogue_voices.gd")
const ReasonAttribution = preload("res://workshop/reason_attribution.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Presentations = preload("res://sim/dialogue_presentations.gd")
const BotWorkshop = preload("res://tools/autoplay_workshop.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_backlog_batch4()
	_run_claude_batch()
	_run_claude_audit_cleanup()
	_run_phase2_bug_sweep()
	_run_phase4_3_framing_and_vig()
	_run_playtest_nov4_fixes()
	_run_playtest_regressions()
	_run_workshop_slice5_voices_a()
	print("Workshop: regressions: %d checks, %d failures" % [checks, fails])
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


# ---------------------------------------------------------------- from test_backlog_batch4

func _run_backlog_batch4() -> void:
	count_reason_names()


# ---------------------------------------------------------------- from test_claude_batch

func _run_claude_batch() -> void:
	_alibi_against_report()
	_test_juror_feedback()
	_connections()
	_sigil_is_an_attack()
	_evil_subject_never_accepts()


# ---------------------------------------------------------------- from test_claude_audit_cleanup

func _run_claude_audit_cleanup() -> void:
	_test_warden_credit_leak_free_and_sigil_reweigh()
	_test_case_against_skips_non_incriminating_sightings()
	_test_live_role_constraints_non_strict_nightwatch()
	_test_shared_ledger_zero_weight_reading_guard()
	_test_caches_clear_all_and_constance_inquiry_gate()
	_test_jury_persuasion_tail_helper()


# ---------------------------------------------------------------- from test_phase2_bug_sweep

func _run_phase2_bug_sweep() -> void:
	_test_2_5_headline_firsthand_attention_reports()


# ---------------------------------------------------------------- from test_phase4_3_framing_and_vigil_physics

func _run_phase4_3_framing_and_vig() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	_test_vigil_vs_nightwatch_self_walk_and_challenge()


# ---------------------------------------------------------------- from test_playtest_nov4_fixes

func _run_playtest_nov4_fixes() -> void:
	_test_rumormonger_and_chronicler_chance_content()
	_test_presentation_reply_routing()


# ---------------------------------------------------------------- from test_playtest_regressions

func _run_playtest_regressions() -> void:
	_workshop_merge_order_of_operations()


# ---------------------------------------------------------------- from test_workshop_slice5_voices_and_bot

func _run_workshop_slice5_voices_a() -> void:
	_test_live_voiced_trace_and_hub_delivery()
	_test_autoplay_workshop_and_hub_builder()
	_test_bears_on_trace_no_hidden_truth_leak()


# ---- test_backlog_batch4


func fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch4_tests"
	g.new_case(4242, 10)
	return g


func count_reason_names():
	var g = fresh()
	var listener = g.w.living_good()[1]
	# A Hearthwitch reads her own neighbours, so the source must live next to the listener.
	var near: Array = g.w.living_neighbours(listener).filter(func(m): return not m.is_evil())
	var source = near[0] if not near.is_empty() else g.w.living_good()[0]
	var rng = g.w.rng.state
	# Purge phase 4 retired the hand-set defence strengths: no role keeps legacy hooks.
	for role in ["hearthwitch", "dowser"]:
		var zero = {"day": 1, "phase": 0, "role": role, "data": {"group": [listener.id], "count": 0}, "shared": true}
		check(not C.role_def(role).has_method("info_effects") and not C.role_def(role).has_method("defend_strength"), "no legacy info_effects or strength hooks remain: " + role)
		if role == "hearthwitch":
			continue # benched (not in the script) and not read by the shared model
		listener.ledger = {}
		listener.suspicion[source.id] = 0.1
		var group: Array = [listener.id]
		if role == "hearthwitch":
			group = g.w.living_neighbours(source).map(func(m): return m.id)
		# Everyone in the group evil, the (good) listener included: impossible for them.
		var impossible = {"day": 1, "phase": 0, "role": role, "data": {"group": group, "count": group.size()}, "shared": true}
		Mind.apply_info(g.w, listener, source, impossible, 1.0)
		check(listener.id in group and Mind.susp(listener, source.id) > 0.1, "impossible-count reading against self raises shared suspicion of source: " + role)
	check(g.w.rng.state == rng, "reason evaluation consumes no RNG")


# ---- test_claude_batch


func _game(sd: int):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 7)
	return g


func _alibi_against_report() -> void:
	var g = _game(692)
	var goods: Array = g.w.living_good()
	var watcher = goods[1]
	var seen = goods[2]
	var block: String = seen.home_block
	g.w.day = 2
	g.add_card({"kind": "alibi", "subject": [seen.id], "home": true, "day": 1, "phase": C.NIGHT, "source": seen.id, "block": seen.home_block, "text": "%s says they were home on night 1." % seen.name})
	g.add_card({"kind": "info", "source": watcher.id, "role": "nightwatch", "day": 1, "phase": 3, "data": {"block": block, "seen": [seen.id]}, "text": "%s's watch on night 1 saw %s" % [watcher.name, seen.name]})
	g.add_card({"kind": "alibi", "subject": [watcher.id], "home": true, "day": 1, "phase": C.NIGHT, "source": watcher.id, "block": watcher.home_block, "text": "%s says they were home on night 1." % watcher.name})
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	var alibi = _node(model, view, func(c): return c.kind == "alibi" and c.subject == seen.id)
	var own_alibi = _node(model, view, func(c): return c.kind == "alibi" and c.subject == watcher.id)
	var report = _node(model, view, func(c): return c.kind == "report" and c.source == watcher.id)
	_check(model.connect_cards(report, alibi) == "" and model.nodes[model.selected].kind == "contradiction", "a watch report against an alibi links as a contradiction")
	var contradiction: String = model.selected
	_check(model.report_doubtable(contradiction), "and, the report being someone's word, it can be doubted instead")
	_check(model.doubt_report(contradiction) == "" and model.nodes[model.selected].kind == "modifier" and model.nodes[model.selected].mode == "lying", "doubting it puts a suspected lie on the report")
	_check(not model.nodes[alibi].has("merged") and not model.nodes[report].has("merged"), "and restores the two cards")
	_check(model.connect_cards(report, own_alibi) == "" and model.nodes[model.selected].kind == "contradiction", "one person's own watch report against their own 'home' links as a contradiction too")


## The test juror leads with "your explanation doesn't fit" and names the clashing cards;
## it also says who a case would mostly raise suspicion of, if not its subject.
func _node(model, view, pick: Callable) -> String:
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and pick.call(Solver.card_by_id(view, nd.card)):
			return id
	return ""


## Connections: board cards that bear on a premise, ranked by how far they'd move it.
func _test_juror_feedback() -> void:
	var g = _game(692)
	var goods: Array = g.w.living_good()
	var source = goods[0]
	g.w.day = 2
	g.add_card({"kind": "info", "source": source.id, "role": "surveyor", "day": 0, "phase": 3,
		"data": {"count": 0}, "text": "%s surveyed the town: no block has an evil resident" % source.name})
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	var reading = _node(model, view, func(c): return c.kind == "report" and c.source == source.id)
	var premise = model.add_premise(goods[1].id, "evil", Vector2(0, 0))
	model.connect_cards(reading, premise)
	var value = model.compile(premise)
	var card_id: String = model.nodes[reading].card
	value.answers[card_id] = {"positive": [], "blocks": []}
	var other: String = goods[2].id
	var result = {}
	Live.feedback(view, value, {"impossible": true, "people": {goods[1].id: {"prior": 0.3, "posterior": 0.32}, other: {"prior": 0.3, "posterior": 0.5}}}, result)
	_check(result.get("headline", "").begins_with("Your chosen explanation doesn't fit"), "a clash under your own choices is the headline (%s)" % result.get("headline", ""))
	_check(card_id in result.get("clashing", []), "and the card you answered is outlined")
	_check(result.get("raises", "") == other, "a case that mostly raises someone else says so (%s)" % result.get("raises_text", ""))
	var plain = {}
	Live.feedback(view, value, {"impossible": false, "people": {goods[1].id: {"prior": 0.3, "posterior": 0.6}, other: {"prior": 0.3, "posterior": 0.4}}}, plain)
	_check(not plain.has("headline") and not plain.has("raises"), "a case that holds and mostly moves its subject has no such notes")


## "I've been known to sleepwalk": the real Sleepwalker and evil bluffers may say it; the
## shared model reads it as true of the one Sleepwalker, or a lie by evil.
func _connections() -> void:
	var g = _game(692)
	var goods: Array = g.w.living_good()
	var watcher = goods[1]
	var seen = goods[2]
	g.w.day = 2
	g.add_card({"kind": "info", "source": watcher.id, "role": "nightwatch", "day": 1, "phase": 3, "data": {"block": seen.home_block, "seen": [seen.id]}, "text": "%s's watch on night 1 saw %s" % [watcher.name, seen.name]})
	var alibi_n: int = g.add_card({"kind": "alibi", "subject": [seen.id], "home": true, "day": 1, "phase": C.NIGHT, "source": seen.id, "block": seen.home_block, "text": "%s says they were home on night 1." % seen.name})
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	var report = _node(model, view, func(c): return c.kind == "report" and c.source == watcher.id)
	var premise = model.add_premise(seen.id, "evil", Vector2(0, 0))
	model.connect_cards(report, premise)
	var found: Array = Live.connections(g, model.compile(premise))
	_check(found.any(func(c): return c.number == alibi_n), "Connections finds the alibi that bears on the premise (%s)" % str(found.map(func(c): return [c.number, snappedf(c.move, 0.01)])))
	var sorted = true
	for i in range(1, found.size()):
		if absf(found[i].move) > absf(found[i - 1].move):
			sorted = false
	_check(sorted and found.size() <= 5, "ranked by how far each moves it, at most five")


## The evil subject of a case against them never accepts it, whatever the conclusion says
## ("is a minion" read as not accusing, so Agnes said "Yes, I follow you", 37291).
func _sigil_is_an_attack() -> void:
	var g = _game(4460)
	var w = g.w
	var demon = w.by_id[w.demon_id]
	var target = null
	for n in w.living_good():
		if n.home_block != demon.home_block:
			target = n
			break
	w.day = 2
	g.add_card({"kind": "ward", "source": "player", "subject": [target.id], "target": target.id, "loc": "home_" + target.id, "block": target.home_block, "night": 1, "day": 1, "phase": C.NIGHT, "private": true, "text": "Night 1: you spent your ward on %s's door." % target.name})
	var seen_n: int = g.add_card({"kind": "sighting", "subject": [demon.id], "block": target.home_block, "source": "player", "day": 1, "phase": C.NIGHT, "vigil": true, "text": "Night 1 vigil: you saw %s on %s." % [demon.name, C.block_name(target.home_block)]})
	var sigil_n: int = g.add_card({"kind": "scorched_sigil", "source": "evidence", "subject": [target.id], "target": target.id, "loc": "home_" + target.id, "block": target.home_block, "night": 1, "day": 1, "phase": C.NIGHT, "private": true, "text": "You alone found a scorched sigil on %s's door: the Demon came on night 1." % target.name})
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	var seen = _node(model, view, func(c): return c.get("text", "").begins_with("Night 1 vigil"))
	var sigil = _node(model, view, func(c): return c.get("text", "").begins_with("You alone found"))
	_check(seen != "" and sigil != "", "the sigil and the ward reach the Workshop (%s, %s)" % [seen, sigil])
	var premise = model.add_premise(demon.id, "evil", Vector2(0, 0))
	model.connect_cards(seen, premise)
	var without = Live.test_juror(g, model.compile(premise))
	model.connect_cards(sigil, premise)
	var with_sigil = Live.test_juror(g, model.compile(premise))
	_check(with_sigil.get("ready", false), "a case citing the sigil can be judged (%s)" % str(with_sigil.get("issues", [])))
	_check(with_sigil.get("lr", 1.0) > without.get("lr", 1.0) * 1.1, "seen near the attacked door that night weighs more with the sigil (%.2f -> %.2f)" % [without.get("lr", 1.0), with_sigil.get("lr", 1.0)])
	_check(preload("res://ui/evidence_context.gd").numbers(g).has(g.board.filter(func(c): return c.kind == "ward")[0].n), "the spent-ward receipt is context")


func _evil_subject_never_accepts() -> void:
	var accepted = 0
	var tried = 0
	for sd in range(4470, 4490):
		var g = _game(sd)
		var e = g.w.evil_team()[0]
		for type in ["minion", "evil", "demon"]:
			var mask: Dictionary = preload("res://sim/presentation_reply.gd")._evil_mask(g.w, e, {"type": type, "a": e.id}, 0, false)
			tried += 1
			if mask.get("stance", "") == "accept":
				accepted += 1
	_check(accepted == 0, "an evil subject never accepts a case against themselves (%d of %d)" % [accepted, tried])


# ---- test_claude_audit_cleanup


func _test_warden_credit_leak_free_and_sigil_reweigh() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(4242, 10)
	var w = g.w
	var goods: Array = w.living_good()
	var warden = goods[0]
	var protectee = goods[1]
	var third = goods[2]
	warden.role = "warden"
	w.day = 1

	# Unannounced private ward on someone else must NOT leak into Warden's credit calculation.
	w.player_ward = third.id
	warden.warden_saves.clear()
	w._warden_credit(warden, protectee.id)
	_check(warden.warden_saves.has("1") and is_equal_approx(warden.warden_saves["1"].belief, 1.0), "private ward on another villager does not omnisciently discount Warden save belief")

	# Next day, showing a scorched sigil on third's door revokes the Warden's mistaken save belief.
	w.player_ward = ""
	w.day = 2
	var sigil_n: int = g.add_card({
		"kind": "scorched_sigil", "source": "evidence", "subject": [third.id], "target": third.id,
		"loc": "home_" + third.id, "block": third.home_block, "night": 1, "day": 1, "phase": C.NIGHT,
		"private": true, "text": "Scorched sigil on %s's door on night 1." % third.name,
	})
	g._show_ward_context(g.board[sigil_n - 1], [warden])
	_check(not warden.warden_saves.has("1"), "showing a scorched sigil on another villager's door revokes Warden save credit for that night")

	# Showing an un-scorched ward card when a public Veteran also exists drops belief below 0.5.
	w.day = 2
	warden.warden_saves.clear()
	w.public_claims.append({"who": goods[3].id, "role": "veteran", "day": 2})
	w._warden_credit(warden, protectee.id)
	_check(warden.warden_saves.has("2") and is_equal_approx(warden.warden_saves["2"].belief, 0.5), "Warden starts with 0.5 save belief alongside one living Veteran claim")
	var ward_n: int = g.add_card({
		"kind": "ward", "source": "player", "subject": [third.id], "target": third.id,
		"loc": "home_" + third.id, "block": third.home_block, "night": 2, "day": 2, "phase": C.NIGHT,
		"private": true, "text": "Night 2: you spent your ward on %s's door." % third.name,
	})
	g._show_ward_context(g.board[ward_n - 1], [warden])
	_check(not warden.warden_saves.has("2"), "showing a ward card to the Warden adds the ward alternative and drops 0.5 belief below threshold")


func _test_case_against_skips_non_incriminating_sightings() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(92974, 7)
	var w = g.w
	var listener = w.living_good()[0]
	var walker = w.living_good()[1]
	var victim = w.living_good()[2]
	walker.home_block = "square"
	victim.home_block = "docks"
	victim.alive = false
	victim.death_day = 1
	victim.death_cause = "demon"
	w.day = 1
	w.public_event("demon_death", [victim.id], "town")
	w.day = 2
	w.scenes[victim.id] = {"day": 1, "block": "docks", "loc": "wharf"}

	# Off-murder-block night sighting ("hill" while walker lives on "square" and victim died on "docks")
	# has LR < 1.0 in LiveActivity even when another card raises walker's suspicion.
	var other = w.living_good()[3]
	var dowse_entry: Dictionary = {"day": 1, "phase": C.MORNING, "role": "dowser", "data": {"group": [walker.id, other.id], "count": 1}, "shared": true, "text": "1 evil in pair"}
	Mind.apply_info(w, listener, other, dowse_entry, 1.0)
	var wcard_off = preload("res://workshop/live_evidence.gd").normalize_card({
		"kind": "sighting", "source": other.id, "subject": [walker.id],
		"block": "hill", "day": 1, "phase": C.NIGHT, "text": "A witnessed outing off murder block"
	})
	Mind.ledger_hear(w, listener, "heard:sight_off_block", [], 1.0, [other.id, 1, "report"], {"kind": "tell", "workshop_card": wcard_off})
	Mind.refresh_beliefs(w, listener, " (test off-block sighting)")
	var reasons_off: Array = MindMeeting.case_against(w, listener, walker.id)
	_check(not reasons_off.any(func(r): return r.get("channel", "") == "movement_out"), "case_against does not cite an off-murder-block night sighting in shared attribution")

	# Same sighting ON the murder block ("docks") IS cited when walker has no credible walking claim.
	var wcard_on = preload("res://workshop/live_evidence.gd").normalize_card({
		"kind": "sighting", "source": other.id, "subject": [walker.id],
		"block": "docks", "day": 1, "phase": C.NIGHT, "text": "A witnessed outing on murder block"
	})
	Mind.ledger_hear(w, listener, "heard:sight_on_block", [], 1.0, [other.id, 1, "report"], {"kind": "tell", "workshop_card": wcard_on})
	Mind.refresh_beliefs(w, listener, " (test murder-block sighting)")
	var reasons_on: Array = MindMeeting.case_against(w, listener, walker.id)
	_check(reasons_on.any(func(r): return r.get("channel", "") == "movement_out"), "case_against cites a murder-block night sighting when walker has no credible walking claim")


func _test_live_role_constraints_non_strict_nightwatch() -> void:
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
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked"]},
	}
	# Night Watch b claims seeing a on market, while player saw a on docks (two non-home blocks for hill resident a).
	# If b is lying/poisoned and a is actually a Minion (not Demon), live bluffs=true fitting must NOT rule out the world via forced_lamp.
	var false_watch = {"id": "nw1", "fact_id": "nw1", "kind": "report", "source": "b", "role": "nightwatch", "night": 1, "data": {"block": "market", "seen": ["a"]}, "observed_at": {"day": 1, "phase": "night"}}
	var real_sight = {"id": "s1", "fact_id": "s1", "kind": "sighting", "source": "player", "subject": "a", "subjects": ["a"], "night": 1, "block": "docks", "data": {}, "role": "", "observed_at": {"day": 1, "phase": "night"}}
	var universe: Array = preload("res://workshop/solver.gd").universe(view)
	var fit_live: PackedFloat64Array = Roles.fits_weights(view, universe, [false_watch, real_sight], {}, {}, true)
	var minion_a_idx: int = -1
	for i in range(universe.size()):
		var uw: Dictionary = universe[i]
		if (int(uw.evil) & 1) != 0 and int(uw.get("demon", -1)) != 0:
			minion_a_idx = i
			break
	_check(minion_a_idx >= 0 and fit_live[minion_a_idx] > 0.0, "live RoleConstraints (bluffs=true) does not prune Minion worlds via forced_lamp from a fallible Night Watch report")


func _test_shared_ledger_zero_weight_reading_guard() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(4, 7)
	var listener = g.w.living_good()[0]
	var speaker = g.w.living_good()[1]
	var t1 = g.w.living_good()[2]
	var t2 = g.w.living_good()[3]
	listener.ledger.clear()
	listener.workshop_state = {}
	var card = {
		"kind": "info", "source": speaker.id, "role": "seer", "day": 1, "phase": C.NIGHT,
		"data": {"pair": [t1.id, t2.id], "yes": true}, "subject": [t1.id, t2.id], "text": "seer yes",
	}
	var norm: Dictionary = preload("res://workshop/live_evidence.gd").normalize_card(card)
	Mind.ledger_hear(g.w, listener, "info:%s:1:seer" % speaker.id, [], 0.0, [speaker.id, 1, "reading"], {
		"kind": "reading", "workshop_receipts": {norm.id: norm},
	})
	var input: Dictionary = Bridge.capture(g, [], listener.id, "private", listener)
	var plan: Dictionary = Shared.prepare(input, {}, listener.ledger)
	_check(plan.ready and is_zero_approx(float(plan.prepared.listener.reading_reliability.get(norm.id, 1.0))), "zero-weight reading: ledger entry yields 0.0 reading_reliability instead of 0.5 floor")

	# And under Codex's _card_route_trust rule, a zero-weight reading: entry must not shadow a live player case route.
	listener.npc_trust[speaker.id] = 0.20
	listener.credibility = 0.90
	var rt: Dictionary = Shared._card_route_trust(norm, {}, ["reading:info:%s:1:seer" % speaker.id, "case:1"], listener.ledger, listener.id, listener.npc_trust, listener.credibility)
	_check(bool(rt.get("via_player_only", false)) and is_equal_approx(float(rt.get("trust", 0.0)), 0.55), "zero-weight reading: owner does not shadow a live player case route in _card_route_trust")


func _test_caches_clear_all_and_constance_inquiry_gate() -> void:
	TraceSolver._compiled_cache["dummy"] = {"digest": "dummy"}
	GhostJuror._live_cache[12345] = {"result": {}}
	Caches.clear_all()
	_check(TraceSolver._compiled_cache.is_empty() and GhostJuror._live_cache.is_empty(), "Caches.clear_all empties TraceSolver._compiled_cache and GhostJuror._live_cache")

	# Constance Day 1 Afternoon with 1 prior question still uses private_reveal_early; after 2 prior questions uses private_reveal.
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(42, 10)
	var constance = g.w.by_id.get("constance")
	if constance != null:
		constance.alignment = "good"
		constance.role = "surveyor"
		constance.claimed_role = ""
		constance.claim_public = false
		constance.max_tier = 0
		constance.trust = 0.95
		constance.traits["privacy"] = 0.0
		constance.dialogue_memory = {}
		g.w.day = 1
		g.w.phase = C.AFTERNOON
		constance.pressed_today = 1 # 1 prior question asked before this gift question
		var r_early: Dictionary = Mind.answer_gift(g.w, constance)
		var txt_early: String = str(r_early["lines"][0].get("text", ""))
		_check("orderly beginning" in txt_early, "Constance on Day 1 Afternoon with <2 prior questions uses private_reveal_early (%s)" % txt_early)

		constance.claimed_role = ""
		constance.max_tier = 0
		constance.dialogue_memory = {}
		constance.pressed_today = 2 # 2 prior questions asked before this gift question
		var r_proper: Dictionary = Mind.answer_gift(g.w, constance)
		var txt_proper: String = str(r_proper["lines"][0].get("text", ""))
		_check("conducted this inquiry properly" in txt_proper, "Constance after 2 prior questions uses standard private_reveal (%s)" % txt_proper)


func _test_jury_persuasion_tail_helper() -> void:
	for kind in ["", "movement", "trace", "movement and trace"]:
		var sample: String = "I checked another explanation and it also fits: Odette, Bram evil; Kira Marked." + Jury.accept_persuasion_tail(kind)
		var stripped: String = Jury.strip_accept_persuasion_tail(sample)
		_check(not ("Even so," in stripped) and stripped.begins_with("I checked another explanation"), "Jury.strip_accept_persuasion_tail cleanly removes persuasion tail (%s)" % (kind if kind != "" else "plain"))


# ---- test_phase2_bug_sweep


func _test_2_5_headline_firsthand_attention_reports() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(4, 10)
	var holder = g.w.living_good()[0]
	var a = g.w.living_good()[1]
	var b = g.w.living_good()[2]
	holder.role = "seer"
	holder.claimed_role = ""
	holder.claim_public = false
	holder.ledger.clear()
	holder.workshop_state.clear()
	holder.info_log = [{"role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [a.id, b.id], "yes": true}, "true": true, "shared": false, "text": "seer yes"}]
	var input: Dictionary = Bridge.capture(g, [], holder.id, "private", holder)
	var plan: Dictionary = Shared.prepare(input, {}, holder.ledger)
	_check(plan.ready and plan.prepared.listener.knowledge.get("own_reports", []).is_empty() and not plan.prepared.listener.knowledge.get("attention_reports", []).is_empty(), "SharedLedger moves firsthand report IDs into attention_reports")
	var h_own: float = Jury._headline(plan.prepared.view, plan.prepared.view.cards, a.id, 0.30, plan.prepared.listener, plan.prepared.listener, false)
	var stripped_eval: Dictionary = plan.prepared.listener.duplicate(true)
	stripped_eval.knowledge["attention_reports"] = []
	var h_default: float = Jury._headline(plan.prepared.view, plan.prepared.view.cards, a.id, 0.30, plan.prepared.listener, stripped_eval, false)
	_check(h_own > h_default, "Jury._headline uses OWN_ERR via attention_reports instead of DEFAULT_ERR (%.4f > %.4f)" % [h_own, h_default])


# ---- test_phase4_3_framing_and_vigil_physics


func _test_vigil_vs_nightwatch_self_walk_and_challenge() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(98933, 10)
	var w = g.w
	w.day = 3
	w.phase = C.EVENING
	var isolde = w.by_id["isolde"]
	var agnes = w.by_id["agnes"]
	var hollis = w.by_id["hollis"]

	# Reproduce #98933 Day 3: #81 complete Vigil on Market (saw only Agnes) + #63 Agnes Medium claim + #110 Isolde Night Watch on Market.
	var c_vigil: int = g.add_card({"kind": "sighting", "source": "player", "subject": [agnes.id], "vigil": true,
		"day": 2, "phase": C.NIGHT, "block": "market", "text": "Night 2 vigil on the Market: saw Agnes."})
	var c_agnes_claim: int = g.add_card({"kind": "claim", "source": agnes.id, "subject": [agnes.id], "role": "medium",
		"day": 2, "phase": C.EVENING, "text": "Agnes publicly claims to be the Medium."})
	var c_isolde_nw: int = g.add_card({"kind": "info", "source": isolde.id, "role": "nightwatch", "subject": [hollis.id],
		"day": 2, "phase": C.NIGHT, "data": {"block": "market", "seen": [hollis.id]},
		"text": "Isolde (Night Watch): Last night I watched the Market: I saw Hollis pass by."})

	var board = Canvas.new(Live.view(g))
	var root: String = board.selected
	board.nodes[root].conclusion = {"target": isolde.id, "type": "evil", "at": "Original alignment"}
	var id_vigil: String = Live.Evidence.normalize_card(g.board[c_vigil - 1]).id
	var id_claim: String = Live.Evidence.normalize_card(g.board[c_agnes_claim - 1]).id
	var id_nw: String = Live.Evidence.normalize_card(g.board[c_isolde_nw - 1]).id
	board.connect_cards("e:" + id_vigil, root)
	board.connect_cards("e:" + id_claim, root)
	board.connect_cards("e:" + id_nw, root)
	board.nodes["e:" + id_vigil].reasons[agnes.id + ":2"] = "gift"
	board.nodes["e:" + id_vigil].citations[agnes.id + ":2"] = id_claim
	var compiled_case: Dictionary = board.compile(root)
	var filed_num: int = Live.file(g, compiled_case)
	var snap: Dictionary = g.workshop_snapshot([filed_num], hollis.id, "meeting")
	var prep: Dictionary = Assess.prepare(snap)
	_check(prep.ready, "Vigil + Medium claim + Isolde Night Watch report prepares cleanly (%s)" % str(prep.issues))
	var ev: Dictionary = Eval.evaluate(prep.view, prep.case, prep.listener)
	_check(not ev.impossible and ev.lr >= Tuning.Workshop.LR_STRONG and ev.posterior > 0.85,
		"Complete Vigil missing Night Watch on her watched block strongly supports Evil (LR=%.2f, post=%.3f)" % [ev.lr, ev.posterior])

	# Also verify right-click / 'lied' reading challenge recognizes absent physical presence cannot be impairment!
	var ch_case: Dictionary = prep.case.duplicate(true)
	ch_case["reading_challenges"] = {id_nw: {"mode": "lying", "supports": [id_vigil, id_claim]}}
	var ch_listener: Dictionary = prep.listener.duplicate(true)
	ch_listener["player_credibility"] = 0.65
	var ch_res: Dictionary = Challenges.assess(prep.view, ch_case, ch_listener, prep.view.cards)
	_check(ch_res.results.size() == 1 and ch_res.results[0].supported and ch_res.results[0].agreement >= 0.60 and ch_res.sources.has(isolde.id),
		"Reading challenge 'lying' with complete Vigil crosses 0.60 agreement and penalizes source (%s)" % str(ch_res.results))
	_check(not ("not convinced the reader deliberately lied" in str(ch_res.results[0].get("note", ""))),
		"Self-presence conflict note explains impairment cannot account for absent feet")


# ---- test_playtest_nov4_fixes


func _test_rumormonger_and_chronicler_chance_content() -> void:
	var g = Game.new()
	g.new_case(95955, 10)
	var w = g.w
	w.day = 1
	w.phase = C.EVENING
	var goods: Array = w.living_good()
	var speaker = goods[0]
	var pair_a = goods[1]
	var pair_b = goods[2]
	var listener = goods[3]
	speaker.role = "rumormonger"
	speaker.claimed_role = ""
	speaker.claim_public = false
	var entry: Dictionary = {
		"day": 0,
		"role": "rumormonger",
		"data": {"pair": [pair_a.id, pair_b.id], "secret": "delusional"},
		"text": "The night before you arrived, I heard that one of %s and %s carries a Delusional secret." % [pair_a.name, pair_b.name],
		"true": true,
		"shared": false,
	}
	speaker.info_log = [entry]
	Mind.refresh_beliefs(w, listener, "baseline before rumormonger reveal")
	var susp_before: float = Mind.susp(listener, speaker.id)
	var pub_lines: Array = []
	var pub_facts: Array = []
	Mind.MindMeeting._go_public(w, speaker, pub_lines, pub_facts)
	g._facts(pub_facts)
	Mind.refresh_beliefs(w, listener, "after truthful rumormonger reveal")
	var susp_after: float = Mind.susp(listener, speaker.id)
	_check(susp_after <= susp_before + 0.03,
		"Uncorroborated Rumormonger report does not spike speaker suspicion (%.3f -> %.3f)" % [susp_before, susp_after])
	var reasons: Array = Mind.MindMeeting.case_against(w, listener, speaker.id)
	_check(not reasons.any(func(r): return "Rumormonger report doesn't fit" in str(r.get("why", ""))),
		"Uncontradicted Rumormonger reading never emits false 'doesn't fit what we know' reason (%s)" % str(reasons))

	var view: Dictionary = ReasonAttribution.public_view_from_world(w)
	var rm_card: Dictionary = {
		"id": "probe_rm", "kind": "report", "source": speaker.id, "role": "rumormonger",
		"night": 0, "observed_at": {"day": 0, "phase": "night"},
		"data": {"pair": [pair_a.id, pair_b.id], "secret": "marked"},
	}
	var q_rm: float = CaseEval.chance_content(view, rm_card)
	_check(q_rm > 0.02 and q_rm < 0.08,
		"10-NPC live Marked Rumormonger chance_content matches ~0.0325 prior hold rate (got %.4f)" % q_rm)
	var chr_card: Dictionary = {
		"id": "probe_chr", "kind": "report", "source": speaker.id, "role": "chronicler",
		"night": 3, "observed_at": {"day": 3, "phase": "night"},
		"data": {"trio": [pair_a.id, pair_b.id, goods[4].id]},
	}
	var q_chr: float = CaseEval.chance_content(view, chr_card)
	_check(q_chr > 0.10 and q_chr < 0.18,
		"10-NPC live Chronicler chance_content matches ~0.1394 prior hold rate (got %.4f)" % q_chr)


func _test_presentation_reply_routing() -> void:
	var g = Game.new()
	g.new_case(40741, 10)
	var w = g.w
	var listener = w.living_good()[0]
	var target = w.demon()
	# Simulate background town conflict (assessment.status == 'conflicting') while attended case is coherent & accepted.
	var fake_assessment: Dictionary = {
		"agreement": 0.78,
		"stance": "accept",
		"path_kind": "reading",
		"assessment": {"status": "conflicting"},
		"case_eval": {"consistent": false, "impossible": false, "posterior": 0.88, "movement": [], "rivals": []},
		"reasoning": {
			"status": "provisional",
			"rivals_tested": 4,
			"considered": ["c1", "c2", "c3"],
			"ignored": ["bg_1", "bg_2", "bg_3"],
			"ignored_lines": [],
			"private_checks": {"fatal": false, "objections": [], "rejected": []},
		},
	}
	var fake_view: Dictionary = {"people": [], "listener": {}}
	var fake_snap: Dictionary = {"selected": ["c1", "c2", "c3"]}
	var reply: Dictionary = Presentations.render_workshop_reply(
		w, listener, {"type": "demon", "a": target.id, "at": "Original alignment"},
		[target.id], fake_assessment, fake_view, fake_snap, "accept", false, false,
		"Your explanation fits what I considered.", {}
	)
	var expected_solid: String = Dialogue.apply_tics(listener.id, Voices.VOICES[listener.id]["present_accept_solid"], {})
	_check(reply.text == expected_solid,
		"Accepted coherent presentation voices present_accept_solid with zero conflict or attention-drop complaints (%s)" % reply.text)

	# Conversely, an actual attended inconsistency with dropped supporting lines voices conflict + partial attention.
	var inc_assessment: Dictionary = fake_assessment.duplicate(true)
	inc_assessment.reasoning.status = "inconsistent"
	inc_assessment.reasoning.ignored_lines = ["sub_branch_3"]
	var inc_reply: Dictionary = Presentations.render_workshop_reply(
		w, listener, {"type": "demon", "a": target.id, "at": "Original alignment"},
		[target.id], inc_assessment, fake_view, fake_snap, "reject", false, false,
		"The accounts I considered conflict with each other.", {}
	)
	var expected_inc: String = Dialogue.apply_tics(
		listener.id,
		Voices.VOICES[listener.id]["present_conflict_weighing"] + " " + Voices.VOICES[listener.id]["present_partial_attention"],
		{}
	)
	_check(inc_reply.text == expected_inc,
		"Genuinely inconsistent attended case with dropped lines still voices conflict + partial attention")


# ---- test_playtest_regressions


func playtest_regressions__game():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(25923, 10)
	return g


func _workshop_merge_order_of_operations() -> void:
	var g = playtest_regressions__game()
	var target = g.w.demon()
	var c_alibi = g.add_card({"kind": "alibi", "subject": [target.id], "source": target.id, "day": 2, "phase": C.NIGHT, "claimed": "home:" + target.home_block, "text": "%s says they stayed home on night 2." % target.name})
	var c_sight = g.add_card({"kind": "sighting", "subject": [target.id], "source": "player", "day": 2, "phase": C.NIGHT, "block": "docks", "text": "You saw %s on the Docks on night 2." % target.name})
	var view: Dictionary = Live.view(g)
	var alibi: String = "e:" + Live.Evidence.normalize_card(g.board[c_alibi - 1]).id
	var sight: String = "e:" + Live.Evidence.normalize_card(g.board[c_sight - 1]).id
	var m1 = Canvas.new(view)
	var p1 = m1.add_premise(target.id, "evil", Vector2.ZERO)
	m1.connect_cards(alibi, sight)
	var merged1: String = m1.selected
	m1.connect_cards(merged1, p1)
	var comp1 = m1.compile(p1)
	var m2 = Canvas.new(view)
	var p2 = m2.add_premise(target.id, "evil", Vector2.ZERO)
	m2.connect_cards(alibi, p2)
	m2.connect_cards(sight, p2)
	var err = m2.connect_cards(alibi, sight)
	var comp2 = m2.compile(p2)
	_check(err == "" and m2.selected == p2, "merging two cards already linked to a premise succeeds and keeps the premise selected")
	_check(comp1.cards == comp2.cards and comp1.disputes.size() == 1 and comp1.disputes == comp2.disputes and comp1.reasons == comp2.reasons, "merge-before-link and merge-after-link preserve the same evidence and interpretation")


# ---- test_workshop_slice5_voices_and_bot


func workshop_slice5_voices_a__game(seed_val: int = 2501, size: int = 7):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_val, size)
	for p in g.w.npcs:
		for m in [p, p.shadow]:
			if m == null:
				continue
			m.info_log = []
			m.known_claims = {}
			m.beliefs = []
			m.ledger = {}
			m.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
			for id in m.suspicion:
				m.suspicion[id] = 0.1
			if not m.is_evil():
				Mind.refresh_beliefs(g.w, m, " (clean)")
	return g


func _test_live_voiced_trace_and_hub_delivery() -> void:
	var g = workshop_slice5_voices_a__game(2502, 7)
	var listener = g.w.living_good()[0]
	var target = g.w.living_good()[1]
	var silenced_p = g.w.living_good()[2]
	var victim = g.w.living_good()[3]
	g.w.day = 1
	g.w.phase = C.EVENING
	listener.work = "bakery"
	listener.haunts = ["mill", "well"]
	listener.trust = 0.85
	listener.traits["gossip"] = 0.9
	target.work = "bakery"
	target.haunts = ["tavern", "graveyard"]
	var trace_card = {
		"n": 1, "kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": victim.id, "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a brass farthing",
		"text": "Scene trace: brass farthing (the Bakery or the Tavern).",
	}
	var bare: Dictionary = Mind.react_to_trace(g.w, listener, trace_card, {}, true)
	_check(not bare.lines.is_empty() and not "[PH]" in bare.lines[0].text and bare.lines[0].has("statement"), "live react_to_trace uses character voice without [PH] and preserves canonical statement")
	var pressed: Dictionary = Mind.press(g.w, listener, trace_card)
	var p_speeches: Array = pressed.lines.filter(func(l): return l is Dictionary)
	_check(not p_speeches.is_empty() and not "[PH]" in p_speeches[0].text and p_speeches[0].has("statement"), "pressing with a trace card wraps voiced response cleanly and retains canonical statement")

	g.w.public_event("demon_death", [victim.id], "town")
	g.w.public_event("silenced", [silenced_p.id], "town")
	var death_num: int = g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1, "block": victim.home_block, "text": "Public death"})
	var sil_num: int = g.add_card({"kind": "silenced", "source": "player", "subject": [silenced_p.id], "day": 1, "phase": C.EVENING, "text": "Silenced"})
	var conv_num: int = g.add_card({"kind": "conversation", "source": "player", "subject": [target.id, silenced_p.id], "block": "market", "loc": "bakery", "day": 1, "phase": C.MORNING, "text": "Talking before silence"})
	var tr_num: int = g.add_card(trace_card)
	# Being near the silencing is Stage 1 now (Breathstealer by presence), so the hub's Stage 2
	# incident here is a rivalry with the victim.
	g.add_profile_receipt({"kind": "bond", "subject": [target.id, victim.id], "bond_kind": "rival", "source": g.w.living_good()[4].id, "day": 1, "phase": 0, "text": "At odds with victim"})
	var view: Dictionary = WorkshopCanvas.view(g)
	var board = CanvasModel.new(view)
	var root_id: String = board.selected
	board.nodes[root_id].conclusion = {"type": "evil", "target": target.id, "at": view.alignment_epoch}
	var hub_id: String = board.add_circumstantial_hub()
	for num in [death_num, tr_num, sil_num, conv_num]:
		board.connect_cards("e:" + WorkshopCanvas.Evidence.normalize_card(g.board[num - 1]).id, hub_id)
	var pnode: String = board.add_profile_info(target.id, ["home_work", "bonds"])
	board.connect_cards(pnode, hub_id)
	board.connect_cards(hub_id, root_id)
	var filed_ok: int = WorkshopCanvas.file(g, board.compile(root_id))
	var pres_ok: Dictionary = g._evaluate_deduction(listener, g.board[filed_ok - 1], 1.0, true)
	var expected_hub_line: String = Dialogue.voice_line(listener.id, "circumstantial_hub_landed", "", {"target": target.name})
	_check(not pres_ok.lines.is_empty() and expected_hub_line in pres_ok.lines[0].text and not "[PH]" in pres_ok.lines[0].text, "grounded Circumstantial Hub presentation speaks listener's bespoke voice line without [PH]")


func _test_autoplay_workshop_and_hub_builder() -> void:
	var g = workshop_slice5_voices_a__game(2503, 7)
	var suspect = g.w.living_good()[0]
	var silenced_p = g.w.living_good()[1]
	var victim = g.w.living_good()[2]
	var cleared_other = g.w.living_good()[3]
	g.w.day = 2
	g.w.phase = C.EVENING
	suspect.work = "bakery"
	suspect.haunts = ["tavern", "mill"]
	cleared_other.work = "chapel"
	cleared_other.haunts = ["well", "graveyard"]
	g.add_profile_receipt({"kind": "haunt", "subject": [cleared_other.id], "loc": "well", "locs": ["well"], "source": "town", "day": 1, "phase": 0, "text": "Haunt 1"})
	g.add_profile_receipt({"kind": "haunt", "subject": [cleared_other.id], "loc": "graveyard", "locs": ["graveyard"], "source": "town", "day": 1, "phase": 0, "text": "Haunt 2"})
	g.w.public_event("demon_death", [victim.id], "town")
	g.w.public_event("silenced", [silenced_p.id], "town")
	g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1, "block": victim.home_block, "text": "Public death"})
	g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": victim.id, "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a brass farthing",
		"text": "Scene trace: brass farthing (the Bakery or the Tavern).",
	})
	g.add_card({"kind": "sighting", "source": "player", "subject": [suspect.id], "block": victim.home_block, "day": 1, "phase": C.NIGHT, "text": "Player vigil sighting"})
	g.add_card({"kind": "silenced", "source": "player", "subject": [silenced_p.id], "day": 2, "phase": C.EVENING, "text": "Silenced"})
	g.add_card({"kind": "conversation", "source": "player", "subject": [suspect.id, silenced_p.id], "block": "market", "loc": "bakery", "day": 2, "phase": C.MORNING, "text": "Talking before silence"})
	# A Stage 2 incident for the hub (being near the silencing is Stage 1 now): at odds with the victim.
	g.add_profile_receipt({"kind": "bond", "subject": [suspect.id, victim.id], "bond_kind": "rival", "source": cleared_other.id, "day": 1, "phase": 0, "text": "At odds with victim"})

	# The analyst reads the board through the shared model (tools/analyst.gd).
	var Analyst = preload("res://tools/analyst.gd")
	var arng = RandomNumberGenerator.new()
	arng.seed = 1
	var state: Dictionary = Analyst.new_state(1.0)
	var sc: Dictionary = Analyst.belief(g, state, arng)
	_check(sc.get(suspect.id, 0.0) > sc.get(cleared_other.id, 1.0), "the analyst's juror ranks the trace-matching, sighted suspect above a trace-contradicted townsperson (%s vs %s)" % [str(sc.get(suspect.id)), str(sc.get(cleared_other.id))])

	# Stage-1-only mode (--no-hub): files valid Workshop case without Circumstantial Hub
	var sigs_s1: Dictionary = {}
	var last_s1: Dictionary = {}
	var built_s1: Dictionary = Analyst.build_case(g, state, suspect.id, sc, false, sigs_s1, last_s1)
	_check(int(built_s1.card) > 0 and not built_s1.used_hub and g.board[int(built_s1.card) - 1].get("workshop_case", {}).get("circumstantial", []).is_empty(), "the analyst builds a clean Stage-1-only Workshop case when include_hub is false")

	# Also add a public failed vote where suspect voted yes to hang cleared_other so adapted vote cards are tested too
	g.w.public_event("vote", [cleared_other.id], "town", {"nominee": cleared_other.id, "nominator": suspect.id, "yes": [suspect.id], "no": [silenced_p.id], "player_yes": false, "count": 1, "threshold": 4, "outcome": "fails"})
	g.add_card({"kind": "vote", "source": "player", "subject": [suspect.id, cleared_other.id], "day": 2, "phase": C.EVENING, "nominee": cleared_other.id, "by": suspect.id, "yes": [suspect.id], "no": [silenced_p.id], "player_yes": false, "count": 1, "threshold": 4, "outcome": "fails", "text": "Vote tally"})

	# Full mode (with Hub): files valid Workshop case attaching adapted silenced + conversation + vote cards in hub
	var sigs_full: Dictionary = {}
	var last_full: Dictionary = {}
	var built_full: Dictionary = Analyst.build_case(g, state, suspect.id, Analyst.belief(g, state, arng), true, sigs_full, last_full)
	var full_hubs: Array = g.board[int(built_full.card) - 1].get("workshop_case", {}).get("circumstantial", []) if int(built_full.card) > 0 else []
	_check(int(built_full.card) > 0 and built_full.used_hub and not full_hubs.is_empty(), "the analyst attaches a verified Circumstantial Evidence Hub when Stage 1 grounding and Stage 2 incidents align")
	if not full_hubs.is_empty():
		var hub_cards: Array = full_hubs[0].get("cards", [])
		# Breathstealer by presence makes the silenced Bart nearly cleared and Constance (the
		# vote's nominee) a little less so, so the vote's "voted to hang the good" incident no
		# longer holds here; the silencing and the conversation by it are still selected.
		var sil_cards: Array = g.board.filter(func(c): return c.get("kind", "") == "silenced").map(func(c): return WorkshopCanvas.Evidence.normalize_card(c).id)
		_check(hub_cards.size() >= 2 and hub_cards.any(func(id): return id in sil_cards), "BotWorkshop.select_circumstantial_cards selects the adapted silenced and conversation cards via view.timeline.events")


func _test_bears_on_trace_no_hidden_truth_leak() -> void:
	var g = workshop_slice5_voices_a__game(2504, 7)
	var secret_match = g.w.living_good()[0]
	var secret_miss = g.w.living_good()[1]
	var victim = g.w.living_good()[2]
	# Both suspects work at the Chapel (outside trace); secret_match secretly haunts the Bakery, secret_miss does not.
	secret_match.work = "chapel"
	secret_match.haunts = ["bakery", "mill"]
	secret_miss.work = "chapel"
	secret_miss.haunts = ["well", "graveyard"]
	# Sync initial work profile receipts to Chapel for both so player holds identical discovered receipts for both.
	for pr in g.profile_receipts:
		if pr.get("kind", "") == "work" and (secret_match.id in pr.get("subject", []) or secret_miss.id in pr.get("subject", [])):
			pr["loc"] = "chapel"
			pr["block"] = C.LOCATIONS["chapel"]["block"]
	var tnum: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": victim.id, "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a brass farthing",
		"text": "Scene trace: brass farthing (the Bakery or the Tavern).",
	})
	var pool_before: Array = g.all_receipts()
	_check(g.Deduction.trace_fit_from_receipts(secret_match.id, g.board[tnum - 1], pool_before) == "unknown" and g.Deduction.trace_fit_from_receipts(secret_miss.id, g.board[tnum - 1], pool_before) == "unknown", "undiscovered haunts stay in unknown state for both secret-match and secret-miss suspects")
	var d_match: int = g.file_deduction({"type": "demon", "a": secret_match.id}, [tnum])
	var d_miss: int = g.file_deduction({"type": "demon", "a": secret_miss.id}, [tnum])
	_check(d_match > 0 and d_miss > 0 and g.board[d_match - 1]["unfounded"] == g.board[d_miss - 1]["unfounded"] and not g.board[d_miss - 1]["unfounded"], "filing conclude <suspect> because <trace> never leaks undiscovered haunts via unfounded flag")

	# Once both non-matching haunts of secret_miss are learned, relevance flips to contradicts (unfounded = true).
	g.add_profile_receipt({"kind": "haunt", "subject": [secret_miss.id], "loc": "well", "locs": ["well"], "source": "town", "day": 1, "phase": 0, "text": "Haunt 1"})
	g.add_profile_receipt({"kind": "haunt", "subject": [secret_miss.id], "loc": "graveyard", "locs": ["graveyard"], "source": "town", "day": 1, "phase": 0, "text": "Haunt 2"})
	_check(g.Deduction.trace_fit_from_receipts(secret_miss.id, g.board[tnum - 1], g.all_receipts()) == "contradicts", "learning all contradicting work + haunts resolves trace_fit_from_receipts to contradicts")
	var d_ruled_out: int = g.file_deduction({"type": "evil", "a": secret_miss.id}, [tnum])
	_check(d_ruled_out > 0 and g.board[d_ruled_out - 1]["unfounded"], "deduction from trace becomes unfounded once discovered profile receipts rule out all prongs")
