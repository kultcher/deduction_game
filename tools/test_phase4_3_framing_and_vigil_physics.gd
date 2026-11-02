## Phase 4.3 regression & checkpoint sweep:
## - Non-cheating single-daily_planter Evil death-block whisper framing & meeting patience
## - Strict single-witness provenance across relayed sightings + source-discount collapse
## - Vigil vs. Night-Walker self-location physics (LiveActivity + ReadingChallenges)
## - Playtest #98933 polish fixes (Good nominator self-vote, cross-card case_against,
##   authoring-validation preflight non-fallback, and Jury empty-Marked formatting)
##
## Unit suite only:
##   godot --headless --path . --script res://tools/test_phase4_3_framing_and_vigil_physics.gd
## With 50-seed checkpoint sweep (prints progress every 10 seeds):
##   godot --headless --path . --script res://tools/test_phase4_3_framing_and_vigil_physics.gd -- --sweep 50 --out res://logs/sweep_4_3.json
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Social = preload("res://sim/social.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Challenges = preload("res://workshop/reading_challenges.gd")
const Jury = preload("res://workshop/jury.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Live = preload("res://game/workshop_canvas.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_test_evil_daily_planter_and_meeting_patience()
	_test_single_witness_provenance_and_discount_collapse()
	_test_vigil_vs_nightwatch_self_walk_and_challenge()
	_test_case_98933_polish_fixes()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--sweep" in user_args:
		var s_idx: int = user_args.find("--sweep")
		var n_games: int = int(user_args[s_idx + 1]) if s_idx + 1 < user_args.size() else 50
		var out_path: String = ""
		if "--out" in user_args:
			var o_idx: int = user_args.find("--out")
			if o_idx + 1 < user_args.size():
				out_path = user_args[o_idx + 1]
		var sweep_data: Dictionary = _run_checkpoint_sweep(n_games)
		if out_path != "":
			var dir_path: String = out_path.get_base_dir()
			if dir_path != "":
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
			var f = FileAccess.open(out_path, FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(sweep_data, "\t") + "\n")
				f.close()
				print("Wrote Phase 4.3 sweep JSON to %s" % out_path)
	print("Phase 4.3 framing, provenance & vigil physics: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


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


func _test_single_witness_provenance_and_discount_collapse() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(44814, 10)
	var w = g.w
	w.day = 2
	var planter = w.evil_team()[0]
	var goods: Array = w.living_good()
	var gossip_b = goods[0]
	var gossip_d = goods[1]
	var listener_c = goods[2]
	var target = goods[3]
	for n in [gossip_b, gossip_d, listener_c]:
		n.info_log = []
		n.known_claims = {}
		n.ledger = {}
		n.beliefs = []
		n.hearsay = []
		n.discounted = {}
		n.npc_trust[planter.id] = 0.55
	listener_c.npc_trust[gossip_b.id] = 0.85
	listener_c.npc_trust[gossip_d.id] = 0.85

	var direct_sight = {"kind": "sighting", "about": target.id, "block": "market", "day": 1, "from": planter.id, "key": "sighting:%s:1" % target.id, "lie": true}
	Social._deliver(w, planter, gossip_b, direct_sight)
	Social._deliver(w, planter, gossip_d, direct_sight)

	var relay_from_b = direct_sight.duplicate(true)
	relay_from_b["relay"] = true
	relay_from_b["key"] = "relay:" + direct_sight["key"]
	Social._deliver(w, gossip_b, listener_c, relay_from_b)
	var susp_after_one_relay: float = Mind.susp(listener_c, target.id)
	var sight_keys: Array = listener_c.ledger.keys().filter(func(k): return str(k).begins_with("heard:"))
	_check(sight_keys.size() == 1, "relayed sighting creates a single ledger entry on listener C")
	var eid: String = sight_keys[0]
	_check(listener_c.ledger[eid].get("rel", ["?"])[0] == planter.id,
		"relayed sighting preserves original witness A in rel[0] (%s), never relayer B (%s)" % [str(listener_c.ledger[eid].get("rel", ["?"])[0]), gossip_b.id])

	# Second Good gossip D relays the exact same sighting from A -> must NOT duplicate or stack!
	var relay_from_d = relay_from_b.duplicate(true)
	Social._deliver(w, gossip_d, listener_c, relay_from_d)
	var receipt_id: String = listener_c.ledger[eid].meta.workshop_card.id
	_check(listener_c.workshop_state.facts.count(receipt_id) == 1 and absf(Mind.susp(listener_c, target.id) - susp_after_one_relay) < 0.005,
		"second relayer recounting planter A's sighting produces 1 receipt.id and zero stacked suspicion")

	# Catching/discounting original planter A collapses hearing_weight on listener C despite high trust in B & D!
	Mind.recompute_beliefs(w, listener_c, " (planter caught)")
	listener_c.workshop_state["source_doubt"][planter.id + ":*"] = 1.0
	var plan = Shared.prepare(g.workshop_snapshot([], listener_c.id), {}, listener_c.ledger)
	var card_after: Dictionary = plan.prepared.view.cards.filter(func(c): return c.id == receipt_id)[0]
	_check(is_zero_approx(float(card_after.get("hearing_weight", 1.0))),
		"discounting original witness A collapses relayed sighting hearing_weight to 0.0 (got %.4f)" % float(card_after.get("hearing_weight", 1.0)))


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


func _test_case_98933_polish_fixes() -> void:
	var g = Game.new()
	g.detailed_logging = true
	g.new_case(98933, 10)
	var w = g.w

	# 1) Good nominator self-vote follow-through on Day 1 + exact trace sum parity.
	w.day = 1
	w.phase = C.EVENING
	w.begin_meeting()
	var nisha = w.by_id["nisha"]
	var edda = w.by_id["edda"]
	nisha.suspicion[edda.id] = 0.39
	var self_yes: bool = Mind.vote(w, nisha, edda.id, nisha.id, false, "", 0)
	_check(self_yes, "Good nominator follows through with YES on their own Day 1 nomination")
	var eval_events: Array = w.dlog.trace_events().filter(func(e): return e.get("type", "") == "decision" and e.get("actor", "") == nisha.id and e.get("data", {}).get("topic", "") == "vote" and e.get("data", {}).get("stage", "") == "evaluation")
	if not eval_events.is_empty():
		var details: Dictionary = eval_events[-1]["data"]["details"]
		var p_sum: float = 0.0
		for v in details["parts"].values():
			p_sum += float(v)
		_check(absf(p_sum - float(details["score"])) < 1e-9, "self_nomination vote part preserves exact score sum for Decision Inspector")

	# 2) Cross-card Workshop contradiction surfaces private Gravedigger reading in case_against.
	w.day = 3
	var hollis = w.by_id["hollis"]
	var odette = w.by_id["odette"]
	var agnes = w.by_id["agnes"]
	var lian = w.by_id["lian"]
	w.executions.append({"day": 2, "id": edda.id, "nominator": "player", "yes": [hollis.id], "player_yes": true, "player_nominated": true})
	w.day = 2
	w.public_event("execution", [edda.id], "town")
	w.day = 3
	edda.alive = false
	edda.death_day = 2
	edda.death_cause = "executed"
	hollis.role = "gravedigger"
	var gd_entry: Dictionary = {"day": 2, "phase": C.NIGHT, "role": "gravedigger", "data": {"executed": edda.id, "role": "poisoner"}, "true": true, "shared": false, "text": "I learned that Edda, whom we hanged, was the Poisoner"}
	hollis.info_log = [gd_entry]
	hollis.applied_info = 0
	Mind.update_from_own_info(w)
	var arch_entry: Dictionary = {"day": 0, "phase": C.NIGHT, "role": "archivist", "data": {"pair": [agnes.id, lian.id], "role": "poisoner"}, "true": false, "fake": true, "shared": true, "text": "I learned that one of Agnes and Lian is the Poisoner"}
	odette.info_log = [arch_entry]
	odette.claimed_role = "archivist"
	odette.claim_public = true
	w.public_claims.append({"day": 3, "who": odette.id, "role": "archivist"})
	Mind.hear_claim(w, hollis, odette.id, "archivist", 0.5, "public")
	Mind.apply_info(w, hollis, odette, arch_entry, 0.5)
	Mind.flush_beliefs(w, hollis)
	var reasons: Array = Mind.MindMeeting.case_against(w, hollis, odette.id)
	# Superseded by purge phase 2a: reasons now come from the shared model's attribution,
	# and only for people the shared model actually suspects. This synthetic fixture (legacy
	# apply_info, no poisoning explanation ruled out) leaves Odette below Hollis's average,
	# so she has no reasons at all. The realistic version of this case is covered in
	# tools/test_legacy_purge_phase2a.gd ("case_against surfaces Hollis's private
	# Gravedigger reading against Odette via leave-one-out").
	var odette_req: float = float(hollis.workshop_state.get("requested", {}).get(odette.id, 0.0))
	_check(odette_req <= 0.0 or (not reasons.is_empty() and reasons[0]["kind"] == "private" and reasons[0]["entry"] == gd_entry),
		"case_against cites Hollis's private Gravedigger reading whenever the shared model suspects Odette (%s)" % str(reasons))

	# 3) Authoring validation block (citing 'gift' without walking-role claim card) leaves legacy_fallbacks at 0.
	g.shared_fallbacks.clear()
	var fb_before: int = w.dlog.entries.filter(func(e): return e.get("type", "") == "legacy_fallback").size()
	var c_vig: int = g.add_card({"kind": "sighting", "source": "player", "subject": [agnes.id], "vigil": true, "day": 2, "phase": C.NIGHT, "block": "market", "text": "Vigil saw Agnes."})
	var c_clm: int = g.add_card({"kind": "claim", "source": agnes.id, "subject": [agnes.id], "role": "medium", "day": 2, "phase": C.EVENING, "text": "Agnes Medium."})
	var id_clm: String = Live.Evidence.normalize_card(g.board[c_clm - 1]).id
	var id_vig: String = Live.Evidence.normalize_card(g.board[c_vig - 1]).id
	var bad_case: Dictionary = {
		"id": "case-bad", "cards": [id_vig], "lines": [{"id": "direct", "label": "Direct", "relation": "supports", "cards": [id_vig], "answers": {}, "positions": {}}],
		"conclusion": {"type": "suspicious", "target": "isolde", "at": "Original alignment"},
		"reasons": {agnes.id + ":2": "gift"}, "citations": {agnes.id + ":2": id_clm},
		"answers": {}, "positions": {}, "disputes": [], "reading_challenges": {}, "faults": {}, "derived": [], "conflict_scope": [], "temporal_positions": [],
		"argument_root": "p:1", "arguments": [{"id": "p:1", "label": "Isolde is suspicious", "parents": [], "without": {}, "case": {
			"id": "case-bad", "cards": [id_vig], "lines": [{"id": "direct", "label": "Direct", "relation": "supports", "cards": [id_vig], "answers": {}, "positions": {}}],
			"conclusion": {"type": "suspicious", "target": "isolde", "at": "Original alignment"},
			"reasons": {agnes.id + ":2": "gift"}, "citations": {agnes.id + ":2": id_clm},
			"answers": {}, "positions": {}, "disputes": [], "reading_challenges": {}, "faults": {}, "derived": [], "conflict_scope": [], "temporal_positions": []
		}}]
	}
	var bad_num: int = Live.file(g, bad_case)
	var gate_ok: bool = g._presentation_gate(g.board[bad_num - 1], w.living(), ["isolde"], "deduction", "meeting")
	var fb_after: int = w.dlog.entries.filter(func(e): return e.get("type", "") == "legacy_fallback").size()
	_check(not gate_ok and g.shared_fallbacks.is_empty() and fb_after == fb_before,
		"Incomplete canvas authoring validation block returns false with 0 legacy_fallbacks")

	# 4) Jury rival-world formatting omits ';  Marked' when marked == ''.
	var snap_ok: Dictionary = g.workshop_snapshot([bad_num], hollis.id, "meeting")
	var view_dummy: Dictionary = {"people": [{"id": "odette", "name": "Odette", "home": "square"}, {"id": "isolde", "name": "Isolde", "home": "hill"}, {"id": "edda", "name": "Edda", "home": "market"}], "evil_count": 2, "day": 2, "timeline": {"events": []}}
	var desc_unmarked: Dictionary = Jury.Solver.describe_world(view_dummy, {"evil": 3, "marked": -1, "demon": 0}, "Original alignment")
	var marked_clause: String = ("; %s Marked" % Jury.Solver.person_name(view_dummy, desc_unmarked.marked)) if str(desc_unmarked.get("marked", "")) != "" else ""
	var formatted: String = "I checked another explanation and it also fits: %s evil%s." % [", ".join(PackedStringArray(desc_unmarked.evil.map(func(id): return Jury.Solver.person_name(view_dummy, id)))), marked_clause]
	_check(not (";  Marked" in formatted) and formatted.ends_with("evil."), "Unmarked rival-world string omits empty ';  Marked' (%s)" % formatted)
	_check(snap_ok is Dictionary, "snapshot helper remains intact")


func _run_checkpoint_sweep(games: int) -> Dictionary:
	var out: Dictionary = {"tuning": Tuning.fingerprint(), "games_per_setup": games, "setups": {}}
	for npc_count in [7, 10]:
		var day_stats: Dictionary = {}
		for d in [1, 2, 3]:
			day_stats[d] = {"active_games": 0, "living": 0, "public_claimed": 0, "pub_or_priv_ready": 0, "noms": 0, "execs": 0, "evil_execs": 0, "good_execs": 0}
		var good_wins: int = 0
		var planter_whispers: int = 0
		var frame_hangs: int = 0
		var total_fallbacks: int = 0
		print("\nRunning Phase 4.3 sweep (%d NPCs, %d seeds)..." % [npc_count, games])
		for idx in range(games):
			var seed_v: int = 1000 + idx
			var g = Game.new()
			g.detailed_logging = false
			g.log_dir = "user://test_logs/sweep_4_3"
			g.new_case(seed_v, npc_count)
			var w = g.w
			var recorded_days: Dictionary = {}
			var planted_targets: Dictionary = {}
			var guard: int = 0
			while g.state != "over" and guard < 500:
				guard += 1
				if g.state == "night" and w.day in [1, 2, 3] and not recorded_days.has(w.day):
					recorded_days[w.day] = true
					_record_day_snapshot(w, day_stats[w.day])
				var cmd: String = "look"
				match g.state:
					"approach": cmd = "decline"
					"day": cmd = "wait"
					"talk": cmd = "bye"
					"meeting": cmd = "done" if g.town_quiet else "wait"
					"nomination": cmd = "vote no"
					"night": cmd = "sleep"
				g.command(cmd)
			if w.day in [1, 2, 3] and not recorded_days.has(w.day):
				recorded_days[w.day] = true
				_record_day_snapshot(w, day_stats[w.day])
			for e in w.dlog.entries:
				if e.get("type", "") == "npc_share" and e.get("data", {}).get("lie", false) and e.get("data", {}).get("kind", "") == "sighting":
					planter_whispers += 1
					var abt: String = str(e.get("data", {}).get("about", ""))
					if abt != "":
						planted_targets[abt] = true
			for ex in w.executions:
				var ex_id: String = str(ex.get("id", ""))
				if planted_targets.has(ex_id) and w.by_id.has(ex_id) and not w.by_id[ex_id].is_evil():
					frame_hangs += 1
			total_fallbacks += g.shared_fallbacks.size()
			if w.winner == "good":
				good_wins += 1
			if (idx + 1) % 10 == 0 or idx + 1 == games:
				print("  [%d NPCs] %d / %d seeds complete" % [npc_count, idx + 1, games])
		var summary_days: Dictionary = {}
		print("=== PHASE 4.3 CHECKPOINT SWEEP (%d NPCs, %d seeds, tuning %s) ===" % [npc_count, games, Tuning.fingerprint()])
		for d in [1, 2, 3]:
			var st: Dictionary = day_stats[d]
			var ag: int = maxi(1, int(st.active_games))
			var lv: int = maxi(1, int(st.living))
			var pub_pct: float = 100.0 * float(st.public_claimed) / float(lv)
			var priv_pct: float = 100.0 * float(st.pub_or_priv_ready) / float(lv)
			var nom_pct: float = 100.0 * float(st.noms) / float(ag)
			var exec_pct: float = 100.0 * float(st.execs) / float(ag)
			var wrong_pct: float = 100.0 * float(st.good_execs) / float(maxi(1, int(st.execs))) if int(st.execs) > 0 else 0.0
			summary_days[str(d)] = {
				"active_games": st.active_games,
				"public_claim_pct": snappedf(pub_pct, 0.1),
				"public_or_private_ready_pct": snappedf(priv_pct, 0.1),
				"meeting_with_nomination_pct": snappedf(nom_pct, 0.1),
				"meeting_with_execution_pct": snappedf(exec_pct, 0.1),
				"evil_executions": st.evil_execs,
				"good_executions": st.good_execs,
				"wrongful_exec_share_pct": snappedf(wrong_pct, 0.1),
			}
			print("  Day %d (active %d): public %.1f%% | nom-games %.1f%% | exec-games %.1f%% (%d evil, %d good, %.1f%% wrongful)" % [
				d, st.active_games, pub_pct, nom_pct, exec_pct, st.evil_execs, st.good_execs, wrong_pct])
		var win_pct: float = 100.0 * float(good_wins) / float(maxi(1, games))
		print("  Evil fake sighting whispers: %d total (%.2f/game) | Whisper-framed Good hangs: %d | legacy_fallbacks: %d" % [
			planter_whispers, float(planter_whispers) / float(maxi(1, games)), frame_hangs, total_fallbacks])
		print("  Passive-bot Good win rate: %.1f%% (%d / %d)" % [win_pct, good_wins, games])
		out.setups[str(npc_count)] = {
			"days": summary_days,
			"evil_sighting_whispers": planter_whispers,
			"whisper_framed_good_hangs": frame_hangs,
			"legacy_fallbacks": total_fallbacks,
			"passive_good_win_pct": snappedf(win_pct, 0.1),
		}
	return out


func _record_day_snapshot(w, st: Dictionary) -> void:
	st.active_games += 1
	for n in w.living():
		st.living += 1
		if n.claim_public:
			st.public_claimed += 1
			st.pub_or_priv_ready += 1
		elif n.max_tier >= 3 or (Mind.MindDialogue._target_tier(w, n) >= 3 and not Mind.MindDialogue._afraid(w, n)):
			st.pub_or_priv_ready += 1
	if w.dlog.entries.any(func(e): return e["type"] == "nomination" and int(e.get("day", -1)) == w.day):
		st.noms += 1
	for ex in w.executions:
		if int(ex.get("day", -1)) == w.day:
			st.execs += 1
			var ex_npc = w.by_id.get(str(ex.get("id", "")))
			if ex_npc != null and ex_npc.is_evil():
				st.evil_execs += 1
			else:
				st.good_execs += 1
