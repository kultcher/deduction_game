## Phase 2 automated regression suite: Fair Night-0 Night Watch impairment & mechanical bug sweep.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const CaseMetrics = preload("res://game/case_metrics.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Jury = preload("res://workshop/jury.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Activity = preload("res://workshop/live_activity.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: " + label)


func _init() -> void:
	_test_2_1_no_gossip_cutoffs()
	_test_2_2_keep_request_fatigue_and_protect_lock()
	_test_2_3_gravedigger_credence_gate()
	_test_2_4_warden_credit_alternatives()
	_test_2_5_headline_firsthand_attention_reports()
	_test_2_6_scion_revenant_scoring_and_grimoire()
	_test_2_7_night0_nightwatch_impairment_and_cleanups()
	print("Phase 2 bug sweep: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _test_2_1_no_gossip_cutoffs() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(92974, 7)
	var n = g.w.living_good()[0]
	var other = g.w.living_good()[1]
	n.traits["gossip"] = 0.05
	n.pressure = 0.0
	n.trust = 0.75
	var op: Dictionary = Mind.answer_opinion(g.w, n, other)
	var statements: Array = op["lines"].map(func(l): return l.get("statement", l.get("text", "")) if l is Dictionary else str(l))
	_check(not statements.any(func(s): return "not my place to say" in s), "low-gossip NPC answers direct opinion question without a 0.20 cutoff")

	# Tavern gossip overhearing also works for low-gossip speakers holding a night sighting.
	for m in g.w.living():
		m.loc = "home"
	n.loc = "tavern"
	n.beliefs = [{"kind": "saw", "who": other.id, "block": "square", "day": 1, "phase": C.NIGHT}]
	n.told_to.clear()
	g.w.day = 2
	var gos: Dictionary = Mind.gossip(g.w)
	_check(gos["facts"].any(func(f): return f.get("kind", "") == "sighting"), "low-gossip speaker in tavern still shares recent night sighting")


func _test_2_2_keep_request_fatigue_and_protect_lock() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var n = g.w.living_good()[0]
	n.role = "seer"
	n.claimed_role = ""
	n.claim_public = false
	n.max_tier = 0
	n.pressed_today = 3
	n.trust = 0.60
	var before_trust: float = n.trust
	var res: Dictionary = Mind.keep_request(g.w, n, 4)
	_check(n.pressed_today == 3, "accepting Question-3 secrecy deal does not increment pressed_today to 4")
	_check(is_equal_approx(n.trust, before_trust + 0.03) and not res["facts"].is_empty(), "accepting secrecy deal grants +0.03 gift-share rapport without fatigue drop")

	# Hard protect_lock blocks voluntary public claim unless nominated, high pressure, or <= 4 alive.
	n.claim_public = false
	n.protect_lock = true
	n.pressure = 0.2
	n.traits["privacy"] = 0.0
	g.w.day = 3
	g.w.meeting = {"nominated": []}
	_check(Mind._public_claim_decision(g.w, n) == "", "protect_lock hard-blocks voluntary public claim above 4 living")


func _test_2_3_gravedigger_credence_gate() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var goods: Array = g.w.living_good()
	var listener = goods[0]
	var ex_villager = goods[1]
	var fake_gd = g.w.demon()
	ex_villager.alive = false
	ex_villager.death_day = 1
	ex_villager.death_cause = "executed"
	g.w.executions.append({"day": 1, "id": ex_villager.id, "nominator": "player", "yes": [], "player_yes": true, "player_nominated": true})
	listener.suspicion[fake_gd.id] = 0.55
	listener.friends = [ex_villager.id]
	var trust_before: float = listener.trust
	var entry = {"day": 1, "role": "gravedigger", "data": {"executed": ex_villager.id, "role": "surveyor"}, "fake": true, "shared": true, "text": "Was Surveyor"}
	C.role_def("gravedigger").info_effects(g.w, listener, fake_gd, entry, 1.0, true, Mind)
	_check(is_equal_approx(listener.trust, trust_before), "suspected Gravedigger claim never docks player Rapport")

	# Trusted Gravedigger still does not dock personal Rapport when executed Good villager was not a friend/lover.
	listener.suspicion[fake_gd.id] = 0.05
	listener.npc_trust[fake_gd.id] = 0.75
	listener.friends = []
	listener.lover = ""
	C.role_def("gravedigger").info_effects(g.w, listener, fake_gd, entry, 1.0, true, Mind)
	_check(is_equal_approx(listener.trust, trust_before), "non-friend execution accuracy stays in Credibility.dawn rather than personal Rapport")


func _test_2_4_warden_credit_alternatives() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(4242, 10)
	var w = g.w
	var warden = w.living_good()[0]
	var target = w.living_good()[1]
	warden.role = "warden"
	w.day = 2
	warden.warden_saves.clear()
	w.public_event("knell", [], "sexton_test")
	w._warden_credit(warden, target.id)
	_check(warden.warden_saves.has("2") and is_equal_approx(warden.warden_saves["2"].belief, 0.5), "public Sexton knell halves Warden quiet-night save belief")

	warden.warden_saves.clear()
	w.player_ward = warden.id
	w._warden_credit(warden, target.id)
	_check(not warden.warden_saves.has("2"), "public knell plus known player ward lowers Warden save belief below threshold (1/3 < 0.5)")


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
	holder.workshop_state["enabled"] = true
	holder.info_log = [{"role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [a.id, b.id], "yes": true}, "true": true, "shared": false, "text": "seer yes"}]
	var input: Dictionary = Bridge.capture(g, [], holder.id, "private", holder)
	var plan: Dictionary = Shared.prepare(input, {}, holder.ledger)
	_check(plan.ready and plan.prepared.listener.knowledge.get("own_reports", []).is_empty() and not plan.prepared.listener.knowledge.get("attention_reports", []).is_empty(), "SharedLedger moves firsthand report IDs into attention_reports")
	var h_own: float = Jury._headline(plan.prepared.view, plan.prepared.view.cards, a.id, 0.30, plan.prepared.listener, plan.prepared.listener, false)
	var stripped_eval: Dictionary = plan.prepared.listener.duplicate(true)
	stripped_eval.knowledge["attention_reports"] = []
	var h_default: float = Jury._headline(plan.prepared.view, plan.prepared.view.cards, a.id, 0.30, plan.prepared.listener, stripped_eval, false)
	_check(h_own > h_default, "Jury._headline uses OWN_ERR via attention_reports instead of DEFAULT_ERR (%.4f > %.4f)" % [h_own, h_default])


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
	_check("Warden (cursed by Revenant)" in grim and not ("bluffed Warden" in grim), "Grimoire labels Revenant-cursed Good villager without 'bluffed Warden'")


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
		"kind": "sighting", "subject": [], "block": "hill", "day": 1, "phase": C.NIGHT,
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
