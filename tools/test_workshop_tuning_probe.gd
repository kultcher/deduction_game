## Phase 0 & Phase 1 regression suite + receipt-level Workshop tuning ablation probe.
## Runs automatically under `python tools/run_gd_tests.py` (zero CLI args) and also
## supports `-- --out <path.json>` to export frozen receipt-level tuning ablations.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Credibility = preload("res://game/credibility.gd")
const WorkshopBridge = preload("res://game/workshop_bridge.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const TraceSolver = preload("res://workshop/trace_solver.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: " + label)


func _init() -> void:
	_test_phase0_fingerprints_and_credibility_dlog()
	_test_phase1_1_meeting_reasons_and_defence_non_leak()
	_test_phase1_2_pre_gift_workshop_attach()
	_test_phase1_3_evil_nomination_and_vote_coherence()
	_test_phase1_4_daytime_dowser_bluff_and_medium_n1_timing()
	_test_phase1_5_revenant_curse_order_and_role_invalidation()
	_test_phase1_6_compiled_trace_chain_speed_and_boundaries()
	var ablation_rows: Array = _run_receipt_level_ablation_probe()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--out" in user_args:
		var idx: int = user_args.find("--out")
		if idx + 1 < user_args.size():
			var f = FileAccess.open(user_args[idx + 1], FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(ablation_rows, "\t"))
				f.close()
	print("Phase 0/1 & Workshop tuning probe: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _test_phase0_fingerprints_and_credibility_dlog() -> void:
	var g = Game.new()
	g.detailed_logging = true
	g.new_case(97930, 10)
	var starts: Array = g.w.dlog.entries.filter(func(e): return e["type"] == "case_start")
	_check(starts.size() == 1 and str(starts[0]["data"].get("tuning", "")).length() == 12, "case_start stamps 12-char deterministic tuning fingerprint")
	_check(starts[0]["data"].has("build") and starts[0]["data"].has("shared_execution_priority_weight"), "case_start stamps build and shared_execution_priority_weight")

	var listener = g.w.living_good()[0]
	var target_good = g.w.living_good()[1]
	g.w.public_event("demon_death", [target_good.id], "town")
	g.add_card({"kind": "death", "source": "player", "subject": [target_good.id], "day": 1, "phase": C.NIGHT, "night": 1, "block": target_good.home_block, "text": "Death"})
	Mind.recompute_beliefs(g.w, listener, "test death")
	Credibility.record(listener, "evil", target_good.id, 1)
	Credibility.dawn(g)
	var cred_entries: Array = g.w.dlog.entries.filter(func(e): return e["type"] == "credibility" and e["actor"] == listener.id)
	_check(not cred_entries.is_empty() and float(cred_entries[0]["data"].get("to", 0.5)) < 0.5, "Credibility.dawn writes standard dlog credibility entry when track record moves")


func _test_phase1_1_meeting_reasons_and_defence_non_leak() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7350, 7)
	var goods: Array = g.w.living_good()
	var seer = goods[0]
	var nom = goods[1]
	var other = goods[2]
	seer.role = "seer"
	seer.claimed_role = ""
	seer.claim_public = false
	seer.info_log = []
	seer.applied_info = 0
	var rd = {"day": 1, "role": "seer", "data": {"pair": [nom.id, other.id], "yes": true}, "true": true, "shared": false, "text": "between %s and %s, one reads as the Demon" % [nom.name, other.name]}
	seer.info_log.append(rd)
	Mind.update_from_own_info(g.w)
	_check(seer.workshop_state.get("active", false) and seer.workshop_state.get("owned", {}).has(Mind.info_eid(seer.id, rd)), "Seer reading is owned by Workshop with zeroed native applied delta")
	var items: Array = Mind.case_against(g.w, seer, nom.id)
	_check(not items.is_empty() and items[0]["kind"] == "private", "case_against recovers Workshop-owned private Seer reading without marginal re-solve")
	var rs: Dictionary = Mind.reason_status(g.w, seer, nom.id)
	_check(rs["kind"] == "private" and rs["strength"] >= 0.5, "reason_status exposes private gift reason for reveal_to_accuse instead of generic fallback")

	# Non-leak check: if Seer withholds reading as a bare hint, nominee cannot leak pair_other or source-specific reading challenge.
	nom.role = "surveyor"
	nom.secret = {}
	nom.claim_public = false
	nom.suspicion[other.id] = 0.8
	nom.suspicion[seer.id] = 0.1
	var hint_fact = [{"kind": "accusation", "subject": [nom.id], "source": seer.id, "hint": true, "text": "Hint only"}]
	var df_hidden: Dictionary = Mind.defend_self(g.w, nom, seer.id, hint_fact)
	_check(not ("pair_other" in df_hidden["moves"]) and not ("lying" in df_hidden["moves"]) and not ("misled" in df_hidden["moves"]), "defend_self never leaks an unshared private Seer reading when nominator only hints")

	# Anonymous relay non-leak check: if a third party relays the Seer reading without naming the Seer, nominee cannot name Seer.
	var relayer = goods[3]
	Mind.apply_info(g.w, nom, seer, rd, C.RELAY_WEIGHT, relayer.id, true)
	var relay_fact = [{"kind": "accusation", "subject": [nom.id, other.id], "source": relayer.id, "relay": true, "role": "seer", "text": "Unnamed Seer relay"}]
	var df_anon: Dictionary = Mind.defend_self(g.w, nom, relayer.id, relay_fact)
	_check(not ("pair_other" in df_anon["moves"]) and not ("lying" in df_anon["moves"]) and not ("misled" in df_anon["moves"]), "defend_self never unmasks an unnamed relayed Seer source")

	# Once reading is actually shared publicly, nominee CAN respond with pair_other.
	rd["shared"] = true
	seer.claim_public = true
	seer.claimed_role = "seer"
	var pub_fact = [Mind.info_fact(g.w, seer, rd)]
	var df_public: Dictionary = Mind.defend_self(g.w, nom, seer.id, pub_fact)
	_check("pair_other" in df_public["moves"], "defend_self responds with pair_other once the Seer reading is publicly disclosed")


func _test_phase1_2_pre_gift_workshop_attach() -> void:
	var g = Game.new()
	g.detailed_logging = true
	g.new_case(92974, 7)
	var toggled: Array = g.w.dlog.entries.filter(func(e): return "shared ownership toggled" in str(e.get("reason", "")))
	_check(toggled.is_empty(), "new_case attaches Workshop before Night 0 and Day 1 gifts with zero ownership-toggled retraction churn")
	_check(g.w.living_good().all(func(n): return n.workshop_state.get("enabled", false)), "all Good NPCs have Workshop enabled from initial setup")


func _test_phase1_3_evil_nomination_and_vote_coherence() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	g.w.day = 3
	g.w.open_meeting()
	var demon = g.w.demon()
	var minions: Array = g.w.minion_ids.map(func(id): return g.w.by_id[id])
	var m0 = minions[0]
	var sg_id: String = g.w.evil_plan["scapegoat"]
	g.w.open_nomination(m0.id, sg_id, "test")
	var self_vote: bool = Mind.vote(g.w, m0, sg_id, m0.id, false, "", 0)
	_check(self_vote, "Evil nominator always votes YES on their own scapegoat nomination even at yes_so_far == 0")

	# Demon on the block: fellow Evil voter rallies behind counter-nomination even early in ballot order.
	g.w.meeting["block"] = demon.id
	g.w.meeting["block_count"] = g.w.vote_threshold()
	var rescue_vote: bool = Mind.vote(g.w, m0, sg_id, g.w.living_good()[0].id, false, "", 0)
	_check(rescue_vote, "Evil voter breaks cover to back counter-nomination when the Demon is on the block")


func _test_phase1_4_daytime_dowser_bluff_and_medium_n1_timing() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var evil_actor = g.w.demon()
	g.w.evil_plan["bluffs"][evil_actor.id] = "dowser"
	evil_actor.info_log = []
	evil_actor.dowsed_day = -1
	g.w.day = 2
	g.w.phase = C.MORNING
	Evil.make_day_fake_info(g.w)
	Mind.update_from_own_info(g.w)
	var dowser_fakes: Array = evil_actor.info_log.filter(func(e): return e.get("fake", false) and e.get("role", "") == "dowser")
	_check(dowser_fakes.size() == 1 and int(dowser_fakes[0].get("phase", -1)) == C.MORNING, "Evil Dowser bluffer fabricates a daytime crowd reading during _day_gifts")

	# Medium N1 timing check: victim killed on Night 1 (death_day == 1) cannot be read by Evil Medium on Night 1.
	var g2 = Game.new()
	g2.detailed_logging = false
	g2.new_case(93047, 10)
	var med_bluffer = g2.w.by_id[g2.w.minion_ids[0]]
	g2.w.evil_plan["bluffs"][med_bluffer.id] = "medium"
	med_bluffer.info_log = []
	med_bluffer.medium_visited = []
	g2.w.day = 1
	g2.w.phase = C.NIGHT
	var victim = g2.w.living_good()[0]
	victim.alive = false
	victim.death_day = 1
	victim.death_cause = "demon"
	Evil.make_fake_info(g2.w)
	var n1_med: Array = med_bluffer.info_log.filter(func(e): return e.get("role", "") == "medium" and int(e.get("day", -1)) == 1)
	_check(n1_med.is_empty(), "Evil Medium bluffer never fabricates a Night 1 reading on Night 1's fresh victim under INFO_BEFORE_KILL")
	g2.w.day = 2
	Evil.make_fake_info(g2.w)
	var n2_med: Array = med_bluffer.info_log.filter(func(e): return e.get("role", "") == "medium" and int(e.get("day", -1)) == 2)
	_check(n2_med.size() == 1 and n2_med[0]["data"]["dead"] == victim.id, "Evil Medium bluffer visits Night 1's victim starting on Night 2")


func _test_phase1_5_revenant_curse_order_and_role_invalidation() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	g.w.day = 3
	g.w.phase = C.EVENING
	var rev = g.w.by_id[g.w.minion_ids[0]]
	rev.role = "revenant"
	rev.alignment = "evil"
	var friend = g.w.living_good()[0]
	var voter_good = g.w.living_good()[1]
	friend.npc_trust[rev.id] = 0.85
	friend.suspicion[rev.id] = 0.10
	var trust_before: float = friend.trust
	Mind.hear_claim(g.w, friend, rev.id, "medium", 0.8, "public")
	g.w.totem = {"loc": "well", "day": 3, "owner": rev.id, "material": rev.home_block}
	g.w.open_meeting()
	g.w.execute(rev.id, {"by": "player", "yes": [voter_good.id], "no": [], "player_yes": true})
	_check(is_equal_approx(friend.trust, trust_before), "friend does not mourn or dock player Rapport when executed target triggers public Revenant curse")
	_check(friend.believed_roles.get(rev.id, "") == "revenant", "public Revenant curse sets believed_roles to revenant and invalidates fake Good claim")

	# Fake Gravedigger claiming proven Revenant held a Good role backfires onto the Gravedigger.
	var fake_gd = g.w.by_id[g.w.demon_id]
	var fake_entry = {"day": 3, "role": "gravedigger", "data": {"executed": rev.id, "role": "medium"}, "fake": true, "shared": true, "text": "Isolde was Medium"}
	var gd_effs: Array = C.role_def("gravedigger").info_effects(g.w, friend, fake_gd, fake_entry, 1.0, true, Mind)
	_check(gd_effs.any(func(ef): return ef[0] == fake_gd.id and float(ef[1]) >= 0.45), "Gravedigger claiming a proven Revenant held a Good role triggers impossible-source suspicion")


func _test_phase1_6_compiled_trace_chain_speed_and_boundaries() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(3110, 10)
	var w = g.w
	var goods: Array = w.living_good()
	var v1 = goods[0]
	var v2 = goods[1]
	var match_p = goods[2]
	var unk_p = goods[3]
	var contra_p = goods[4]
	match_p.work = "bakery"
	match_p.haunts = ["chapel", "mill"]
	unk_p.work = "wharf"
	unk_p.haunts = ["chapel", "well"]
	contra_p.work = "smithy"
	contra_p.haunts = ["well", "graveyard"]

	g.profile_receipts.clear()
	g._profile_card_keys.clear()
	g._profile_fact_keys.clear()
	g._home_cards()
	# Unlock full profile for match_p and contra_p, leave unk_p's haunts undiscovered!
	for p in [match_p, contra_p]:
		for hl in p.haunts:
			g.add_profile_receipt({"kind": "haunt", "subject": [p.id], "source": "town", "loc": hl, "locs": [hl], "block": w.loc_block(hl), "day": 1, "phase": 0, "text": "Haunt"})

	w.day = 2
	v1.alive = false
	v2.alive = false
	w.public_event("demon_death", [v1.id], "town")
	w.public_event("demon_death", [v2.id], "town")
	g.add_card({"kind": "death", "source": "player", "subject": [v1.id], "day": 1, "phase": C.NIGHT, "night": 1, "block": v1.home_block, "text": "Death 1"})
	g.add_card({"kind": "death", "source": "player", "subject": [v2.id], "day": 2, "phase": C.NIGHT, "night": 2, "block": v2.home_block, "text": "Death 2"})
	var t1_n: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": v1.id, "scene": "scene_" + v1.id, "scene_block": v1.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "brass token", "text": "Trace N1",
	})
	var t2_n: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 2, "phase": C.EVENING, "crime_night": 2,
		"victim": v2.id, "scene": "scene_" + v2.id, "scene_block": v2.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["chapel", "mill"], "item_label": "wax seal", "text": "Trace N2",
	})

	var view: Dictionary = WorkshopCanvas.view(g)
	var t1_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[t1_n - 1]).id
	var t2_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[t2_n - 1]).id
	var model = CanvasModel.new(view)
	var root_id: String = model.selected
	model.nodes[root_id].conclusion = {"type": "evil", "target": match_p.id, "at": view.alignment_epoch}
	var tc_id: String = model.add_trace_chain({1: t1_id, 2: t2_id})
	model.connect_cards(tc_id, root_id)
	var compiled: Dictionary = model.compile(root_id)
	_check(compiled.cards.size() <= 6 and compiled.has("trace_assessments"), "compiled trace_chain keeps card list compact without 38-card profile expansion")

	var t0: int = Time.get_ticks_usec()
	var ghost: Dictionary = Ghost.live(WorkshopCanvas.snapshot(g, compiled))
	var cold_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var t1_warm: int = Time.get_ticks_usec()
	var ghost_warm: Dictionary = Ghost.live(WorkshopCanvas.snapshot(g, compiled))
	var warm_ms: float = float(Time.get_ticks_usec() - t1_warm) / 1000.0
	_check(ghost.ready and ghost_warm.ready and warm_ms < 50.0, "compiled trace_chain evaluates cleanly under 50ms warm (cold %.1fms, warm %.1fms)" % [cold_ms, warm_ms])

	var effs: Dictionary = ghost.proposal.effects
	_check(effs[match_p.id].posterior > effs[unk_p.id].posterior and effs[unk_p.id].posterior > effs[contra_p.id].posterior, "compiled trace_chain preserves matches > unknown > contradicts ordering")
	_check(effs[contra_p.id].posterior > 0.05, "contradicting trace_chain only lowers Demon candidacy and never clears someone of being a Minion")

	# Also link raw t1_id directly alongside trace_chain to verify zero double-counting!
	model.connect_cards("e:" + t1_id, root_id)
	var compiled_dup: Dictionary = model.compile(root_id)
	var ghost_dup: Dictionary = Ghost.live(WorkshopCanvas.snapshot(g, compiled_dup))
	_check(is_equal_approx(effs[match_p.id].posterior, ghost_dup.proposal.effects[match_p.id].posterior), "raw trace card alongside trace_chain never double-counts covered scene")

	# Presentation key size check: argument_stance key must be a 64-char SHA-256 hex digest.
	var filed_num: int = WorkshopCanvas.file(g, compiled)
	_check(filed_num > 0, "compiled trace_chain case files onto board")
	var listener = goods[5]
	g.w.workshop_present.call(listener, g.board[filed_num - 1], [match_p.id], "deduction", "private", true)
	var stances: Array = g.w.dlog.entries.filter(func(e): return e["type"] == "argument_stance" and e["actor"] == listener.id)
	_check(not stances.is_empty() and str(stances[-1]["data"].get("key", "")).length() == 64, "argument_stance logs 64-char SHA-256 digest instead of 16KB JSON string")


func _run_receipt_level_ablation_probe() -> Array:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var holder = g.w.living_good()[0]
	var a = g.w.living_good()[1]
	var b = g.w.living_good()[2]
	holder.role = "seer"
	holder.info_log = [{"day": 1, "role": "seer", "data": {"pair": [a.id, b.id], "yes": true}, "true": true, "shared": false, "text": "between %s and %s, one reads as the Demon" % [a.name, b.name]}]
	holder.applied_info = 0
	Mind.update_from_own_info(g.w)

	# Capture frozen receipt-level input via WorkshopBridge.
	var frozen_input: Dictionary = WorkshopBridge.capture(g, [], holder.id, "private", holder)
	var outside: Dictionary = holder.workshop_state.get("outside", holder.suspicion).duplicate(true)
	var plan: Dictionary = Shared.prepare(frozen_input, holder.workshop_state.get("presentations", {}), holder.ledger, {}, [])
	_check(plan.ready and not plan.facts.is_empty(), "ablation probe freezes listener state at normalized receipt level")

	var saved_k: float = CaseEval.prior_k
	var out_rows: Array = []
	for k_val in [-1.0, 1.5]:
		CaseEval.prior_k = k_val
		var prop: Dictionary = Shared.evaluate(plan, outside, holder.discounted)
		var eff_a: Dictionary = prop.effects.get(a.id, {})
		out_rows.append({
			"prior_k": k_val,
			"prior": eff_a.get("prior", 0.0),
			"posterior": eff_a.get("posterior", 0.0),
			"requested": eff_a.get("requested", 0.0),
			"headline_signal": eff_a.get("headline_signal", 0.0),
		})
	CaseEval.prior_k = saved_k
	_check(out_rows.size() == 2 and is_finite(float(out_rows[1]["posterior"])), "receipt-level ablation probe compares old and new prior_k cleanly")
	return out_rows
