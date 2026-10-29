## Slice 2 tests: 200-seed trace generator feasibility & non-subset guard,
## 3:1 three-valued (matches / unknown / contradicts) evaluation, Scion succession safety,
## Workshop candidate summary, and NPC trace reactions with minion Demon-protection.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Mind = preload("res://sim/mind.gd")

var checks = 0
var fails = 0

func _init() -> void:
	_test_200_seed_feasibility_and_nonsubset()
	_test_three_valued_3_to_1_solver_and_summary()
	_test_scion_epoch_safety()
	_test_npc_trace_reactions_and_minion_guard()
	print("Profile traces (Slice 2): %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)

func _game(sd: int = 801, count: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, count)
	return g

func _test_200_seed_feasibility_and_nonsubset() -> void:
	var total_traces = 0
	var all_fit_demon = true
	var zero_dup_keys = true
	var zero_subset_pairs = true
	var token_n = 0
	var scent_n = 0
	for sd in range(1000, 1200):
		var g = _game(sd, 10 if sd % 2 == 0 else 7)
		var w = g.w
		var d = w.demon()
		var victims: Array = w.living_good().slice(0, 3)
		var seen_keys = {}
		var loc_sets: Array = []
		for step in range(victims.size()):
			w.day = step + 1
			var v = victims[step]
			w._kill(v)
			# Scene traces are shuffled; the first card may belong to a passer.
			var tr: Dictionary = w.scenes["scene_" + v.id]["trace"]
			total_traces += 1
			if not w.actor_fits_trace_truth(d, tr):
				all_fit_demon = false
			if seen_keys.has(tr.trace_key):
				zero_dup_keys = false
			seen_keys[tr.trace_key] = true
			if tr.trace_family == "locations":
				if tr.trace_subtype == "token":
					token_n += 1
				else:
					scent_n += 1
				for prev in loc_sets:
					if w._is_subset_or_superset(tr.locs, prev) and loc_sets.size() < 4:
						zero_subset_pairs = false
				loc_sets.append(tr.locs)
	_check(total_traces == 600 and all_fit_demon, "all 600 traces across 200 7p/10p seeds are 100% compatible with the Demon")
	_check(zero_dup_keys and zero_subset_pairs, "trace generator never repeats clue keys or rolls subset/superset location sets across 3 murders")
	var ratio: float = float(token_n) / maxf(float(token_n + scent_n), 1.0)
	_check(ratio > 0.55 and ratio < 0.79, "location traces blend ~67% 2-spot tokens and ~33% 3-spot scents")
	_check(token_n + scent_n >= 390, "locations family (tokens & scents) forms the ~75% primary backbone of crime-scene traces")
	_check(C.TRACE_TOKENS.size() == 28 and C.TRACE_SCENTS.size() == 56, "all 28 2-spot trade tokens and all 56 3-spot scents are bespoke")

func _test_three_valued_3_to_1_solver_and_summary() -> void:
	var g = _game(1402, 7)
	var w = g.w
	var victim = w.living_good()[0]
	var match_npc = w.npcs.filter(func(p): return p != victim)[0]
	var partial_npc = w.npcs.filter(func(p): return p != victim and p != match_npc)[0]
	var contra_npc = w.npcs.filter(func(p): return p != victim and p != match_npc and p != partial_npc)[0]
	var speaker = w.npcs.filter(func(p): return p not in [victim, match_npc, partial_npc, contra_npc])[0]
	# Force deterministic workplaces & haunts to test matches (3.0) vs unknown (1.6) vs contradicts (1.0).
	match_npc.work = "bakery"
	match_npc.haunts = ["mill", "well"]
	partial_npc.work = "chapel"
	partial_npc.haunts = ["mill", "tavern"]
	contra_npc.work = "chapel"
	contra_npc.haunts = ["mill", "well"]
	# Refresh setup work receipts to match overridden workplaces
	g.profile_receipts.clear()
	g._profile_card_keys.clear()
	g._profile_fact_keys.clear()
	g._home_cards()
	w.day = 1
	g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "day": 1, "phase": C.NIGHT, "night": 1, "block": victim.home_block, "text": "%s was killed on night 1." % victim.name})
	w.public_event("demon_death", [victim.id], "town")
	var trace_num: int = g.add_card({
		"kind": "trace", "subject": [], "block": victim.home_block, "source": "evidence",
		"day": 1, "phase": C.EVENING, "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"victim": victim.id, "victim_block": victim.home_block, "crime_night": 1,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0,
		"trace_key": "locations:bakery:tavern", "locs": ["bakery", "tavern"],
		"item_label": "a grease-darkened brass farthing",
		"text": "Trace at %s's death scene: a grease-darkened brass farthing suggests someone tied to the bakery or the Drowned Lamb tavern." % victim.name,
	})
	# Reveal ONLY 1 haunt for partial_npc (mill -> not in {bakery, tavern}, so still unknown, NOT contradicts!)
	g.known_haunts[partial_npc.id] = ["mill"]
	g.add_profile_receipt({"kind": "haunt", "subject": [partial_npc.id], "source": speaker.id, "loc": "mill", "locs": ["mill"], "block": "docks", "day": 1, "phase": 0, "text": "Partial haunt 1"})
	# Reveal BOTH haunts for contra_npc (mill, well -> neither in {bakery, tavern}, plus work chapel -> contradicts!)
	g.known_haunts[contra_npc.id] = ["mill", "well"]
	g.add_profile_receipt({"kind": "haunt", "subject": [contra_npc.id], "source": speaker.id, "loc": "mill", "locs": ["mill"], "block": "docks", "day": 1, "phase": 0, "text": "Contra haunt 1"})
	g.add_profile_receipt({"kind": "haunt", "subject": [contra_npc.id], "source": speaker.id, "loc": "well", "locs": ["well"], "block": "square", "day": 1, "phase": 0, "text": "Contra haunt 2"})
	var view: Dictionary = WorkshopCanvas.view(g)
	var board = CanvasModel.new(view)
	var root_id: String = board.selected
	board.nodes[root_id].conclusion = {"type": "suspicious", "target": match_npc.id, "at": view.alignment_epoch}
	var tid: String = "e:" + WorkshopCanvas.Evidence.normalize_card(g.board[trace_num - 1]).id
	board.connect_cards(tid, root_id)
	for p in [match_npc, partial_npc, contra_npc]:
		var pnode: String = board.add_profile_info(p.id, ["home_work", "haunts"])
		board.connect_cards(pnode, root_id)
	var compiled: Dictionary = board.compile(root_id)
	var tsum: Dictionary = WorkshopCanvas.trace_summary(g, compiled)
	_check(tsum.get("has_traces", false), "trace_summary activates when structured trace is linked")
	_check(match_npc.name in tsum.compatible, "NPC whose workplace matches trace appears in compatible list")
	_check(tsum.unresolved.any(func(s): return s.begins_with(partial_npc.name)) and not (partial_npc.name in tsum.contradicted), "knowing only 1 non-matching haunt stays unresolved rather than contradicted")
	_check(contra_npc.name in tsum.contradicted, "NPC with work and both haunts outside trace appears in contradicted list")
	var ghost: Dictionary = Ghost.live(WorkshopCanvas.snapshot(g, compiled))
	_check(ghost.ready and ghost.proposal.effects[match_npc.id].requested > ghost.proposal.effects[contra_npc.id].requested, "3:1 trace factor raises suspicion of matching candidate over contradicted candidate")

func _test_scion_epoch_safety() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square", "alive": id not in ["g", "a", "f"]})
	var view = {
		"people": people,
		"cards": [],
		"evil_count": 2,
		"alignment_epoch": "Original alignment",
		"live_activity": true,
		"timeline": {
			"executions": {"2": ["a"]},
			"deaths": {"g": 2, "a": 2, "f": 3},
			"death_ticks": {"g": 7, "a": 10, "f": 11},
			"events": [
				{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}},
				{"kind": "execution", "subjects": ["a"], "at": {"day": 2}},
				{"kind": "demon_death", "subjects": ["f"], "at": {"day": 2}},
			],
		},
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked"]},
	}
	# Night 1 (before Day 2 execution) matches 'a'; Night 2 (execution day's night, AFTER Scion 'b' took over!) matches 'c' and contradicts 'b'.
	var pre_cards: Array = [
		{"id": "tr1", "kind": "trace", "source": "evidence", "night": 1, "subject": "", "data": {"family": "locations", "locs": ["bakery", "tavern"], "scene": "scene_g", "scene_block": "square", "slot": 0, "scene_trace_count": 1}},
		{"id": "wa", "kind": "context", "source": "town", "context_kind": "work", "subject": "a", "data": {"loc": "bakery"}},
		{"id": "wb", "kind": "context", "source": "town", "context_kind": "work", "subject": "b", "data": {"loc": "chapel"}},
		{"id": "hb1", "kind": "context", "source": "town", "context_kind": "haunt", "subject": "b", "data": {"locs": ["mill"]}},
		{"id": "hb2", "kind": "context", "source": "town", "context_kind": "haunt", "subject": "b", "data": {"locs": ["well"]}},
	]
	var factor_pre: Dictionary = Activity.factors(view, pre_cards, {})[0]
	var scion_world = {"evil": (1 << 0) | (1 << 1), "demon": 1}
	var non_scion_world = {"evil": (1 << 2) | (1 << 1), "demon": 1}
	_check(Activity.score(scion_world, factor_pre) > Activity.score(non_scion_world, factor_pre), "Scion succession split credits pre-execution Night 1 (< exec_day) trace match on hanged original Demon")
	# Execution day's own night (Night 2 == exec_day) belongs to the promoted Scion ('b'), NEVER hanged 'a'.
	var exec_night_cards: Array = pre_cards + [
		{"id": "tr2", "kind": "trace", "source": "evidence", "night": 2, "subject": "", "data": {"family": "locations", "locs": ["bakery", "tavern"], "scene": "scene_f", "scene_block": "square", "slot": 0, "scene_trace_count": 1}},
		{"id": "wc", "kind": "context", "source": "town", "context_kind": "work", "subject": "c", "data": {"loc": "bakery"}},
	]
	var factor_both: Dictionary = Activity.factors(view, exec_night_cards, {})[0]
	var c_demon_world = {"evil": (1 << 0) | (1 << 2), "demon": 2}
	_check(Activity.score(c_demon_world, factor_both) > Activity.score(scion_world, factor_both), "Execution day's night (night == exec_day) is evaluated against the surviving Scion rather than the Demon hanged earlier that evening")

func _test_npc_trace_reactions_and_minion_guard() -> void:
	var g = _game(1505, 7)
	var w = g.w
	var demon = w.demon()
	var minions: Array = w.npcs.filter(func(p): return p.is_evil() and p != demon)
	var minion = minions[0]
	var victim = w.living_good()[0]
	var townie = w.living_good()[1]
	# Craft a trace that fits both the Demon (via haunt) and townie (via haunt), but NOT minion.
	demon.work = "bakery"
	demon.haunts = ["tavern", "mill"]
	townie.work = "chapel"
	townie.haunts = ["tavern", "well"]
	minion.work = "smithy"
	minion.haunts = ["graveyard", "well"]
	minion.trust = 0.85
	minion.traits["gossip"] = 0.9
	var trace_card = {
		"n": 1, "kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING,
		"victim": victim.id, "trace_family": "locations", "trace_subtype": "token",
		"locs": ["bakery", "tavern"], "item_label": "a grease-darkened brass farthing",
		"text": "Trace card",
	}
	var m_reply: Dictionary = Mind.react_to_trace(w, minion, trace_card, {}, true)
	var named_demon: bool = m_reply.get("profile_haunts", []).any(func(ph): return ph.subject == demon.id) or " ".join(PackedStringArray(m_reply.lines.map(func(l): return l.text if l is Dictionary else str(l)))).contains(demon.name)
	_check(not named_demon, "Minion trace reaction never volunteers their Demon as a deflection suspect")
	var pointers: Array = m_reply.get("profile_haunts", [])
	_check(not pointers.is_empty() and pointers.all(func(ph): return ph.subject not in [demon.id, minion.id, victim.id] and w.by_id.has(ph.subject) and w.by_id[ph.subject].alive and ph.loc in w.by_id[ph.subject].haunts and ph.loc in trace_card.locs), "Minion deflects onto truthful matching haunts of eligible non-Demon townsfolk")
	# Also test multi-trace deduction pressed against townie triggers forceful frame-up denial
	var trace2 = trace_card.duplicate(true)
	trace2["n"] = 2
	var ded = {"kind": "deduction", "conclusion": {"type": "evil", "a": townie.id}, "supports": [1, 2], "support_cards": [trace_card, trace2], "text": "Two-trace case"}
	var p_reply: Dictionary = Mind.press(w, townie, ded)
	var joined: String = " ".join(PackedStringArray(p_reply.lines.map(func(l): return l.text if l is Dictionary else str(l))))
	_check(joined.contains("frame") or joined.contains("stringing scraps"), "pressing an NPC with a multi-trace deduction triggers the forceful frame-up denial")
	# Pressing with a single structured trace card in live conversation saves disclosed haunts to known_haunts and profile_receipts.
	var g_press = _game(1505, 7)
	var speaker = g_press.w.living_good()[0]
	var target_p = g_press.w.living_good()[1]
	var vic_p = g_press.w.living_good()[2]
	speaker.work = "bakery"
	speaker.haunts = ["mill", "well"]
	speaker.trust = 0.9
	speaker.traits["gossip"] = 0.95
	target_p.work = "chapel"
	target_p.haunts = ["tavern", "graveyard"]
	for other in g_press.w.npcs:
		if other not in [speaker, target_p]:
			other.work = "smithy"
			other.haunts = ["wharf", "well"]
	var tnum: int = g_press.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": vic_p.id, "scene": "scene_" + vic_p.id, "scene_block": vic_p.home_block,
		"trace_family": "locations", "trace_subtype": "token", "locs": ["bakery", "tavern"],
		"item_label": "a grease-darkened brass farthing", "text": "Scene trace: farthing (the Bakery or the Tavern).",
	})
	g_press.state = "talk"
	g_press.talk_with = speaker
	g_press.questions_left = 3
	g_press.command("press %d" % tnum)
	_check("tavern" in g_press.known_haunts.get(target_p.id, []) and not g_press.profile_receipts_for(target_p.id, "haunts").is_empty(), "pressing with a trace card persists any disclosed haunt to known_haunts and profile_receipts")
