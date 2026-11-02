## Regression suite for Legacy Purge Phase 2a: shared-model refresh attribution
## (`workshop_state.reasons`), meeting citations (`case_against`, `reason_status`,
## `nomination_case`), and `defend_self` without legacy magnitudes.
##
## Unit suite:
##   godot --headless --path . --script res://tools/test_legacy_purge_phase2a.gd
## Optional passive nomination-citation sweep:
##   godot --headless --path . --script res://tools/test_legacy_purge_phase2a.gd -- --sweep 25
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const C = preload("res://sim/content.gd")
const Live = preload("res://game/workshop_canvas.gd")
const ReasonAttribution = preload("res://workshop/reason_attribution.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_test_hollis_gravedigger_vs_odette_archivist_and_no_legacy_why_read()
	_test_kiran_firsthand_night_sightings_and_visibility()
	_test_vigil_vs_nightwatch_joint_contradiction()
	_test_elimination_residual_reason()
	_test_defend_self_shared_attribution_and_visibility()
	_test_passive_meeting_nomination_reason_rate(2)
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--sweep" in user_args:
		var s_idx: int = user_args.find("--sweep")
		var n_games: int = int(user_args[s_idx + 1]) if s_idx + 1 < user_args.size() else 25
		_run_passive_citation_sweep(n_games)
	print("Legacy Purge Phase 2a: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh_game(seed_val: int, size: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_val, size)
	g.set_workshop_effects(true)
	return g


func _test_hollis_gravedigger_vs_odette_archivist_and_no_legacy_why_read() -> void:
	var g = _fresh_game(98933, 10)
	var w = g.w
	w.day = 3
	var hollis = w.by_id["hollis"]
	var odette = w.by_id["odette"]
	var edda = w.by_id["edda"]
	var agnes = w.by_id["agnes"]
	var lian = w.by_id["lian"]

	for p in [hollis, odette]:
		p.alignment = "good"
		p.shadow = null
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.claimed_role = ""
		p.claim_public = false
		p.told_readings = 0
		p.workshop_state = {"enabled": true, "reasoning_mode": "bounded", "confidence_mode": "scale"}

	w.executions.append({"day": 2, "id": edda.id, "nominator": "player", "yes": [hollis.id], "player_yes": true, "player_nominated": true})
	w.day = 2
	w.public_event("execution", [edda.id], "town")
	w.day = 3
	edda.alive = false
	edda.death_day = 2
	edda.death_cause = "executed"

	hollis.role = "gravedigger"
	var gd_entry: Dictionary = {
		"day": 2, "phase": C.NIGHT, "role": "gravedigger",
		"data": {"executed": edda.id, "role": "poisoner"},
		"true": true, "shared": false,
		"text": "I learned that Edda, whom we hanged, was the Poisoner",
	}
	hollis.info_log = [gd_entry]
	hollis.applied_info = 0
	Mind.update_from_own_info(w)

	var arch_entry: Dictionary = {
		"day": 0, "phase": C.NIGHT, "role": "archivist",
		"data": {"pair": [agnes.id, lian.id], "role": "poisoner"},
		"true": false, "fake": true, "shared": true,
		"text": "I learned that one of Agnes and Lian is the Poisoner",
	}
	odette.info_log = [arch_entry]
	odette.claimed_role = "archivist"
	odette.claim_public = true
	w.public_claims.append({"day": 3, "who": odette.id, "role": "archivist"})
	Mind.hear_claim(w, hollis, odette.id, "archivist", 0.5, "public")
	Mind.apply_info(w, hollis, odette, arch_entry, 0.5)
	Mind.flush_beliefs(w, hollis)

	# Poison legacy sus_why / sus_src to prove shared mode ignores them completely.
	hollis.sus_why[odette.id] = "POISONED_LEGACY_WHY"
	hollis.sus_src[odette.id] = "POISONED_LEGACY_SRC"

	var raw_reasons: Array = hollis.workshop_state.get("reasons", {}).get(odette.id, [])
	_check(not raw_reasons.is_empty(), "Hollis's refresh populates workshop_state.reasons for Odette")
	var items: Array = MindMeeting.case_against(w, hollis, odette.id)
	_check(not items.is_empty() and items[0]["kind"] == "private" and items[0]["entry"] == gd_entry,
		"case_against surfaces Hollis's private Gravedigger reading against Odette via leave-one-out (%s)" % str(items))
	var rs: Dictionary = Mind.reason_status(w, hollis, odette.id)
	_check(rs["why"] != "POISONED_LEGACY_WHY" and rs.get("eid", "") != "POISONED_LEGACY_SRC",
		"reason_status ignores legacy sus_why / sus_src in shared mode")
	_check(Mind.citable_reason(w, hollis, odette.id, "town") == "" and rs["strength"] >= 0.5,
		"unshared Gravedigger contradiction stays private with reveal-worthy strength")

	# Disclosing publicly immediately upgrades visibility without requiring a re-solve.
	hollis.claim_public = true
	hollis.claimed_role = "gravedigger"
	gd_entry["shared"] = true
	_check(Mind.reason_status(w, hollis, odette.id)["kind"] == "public" and Mind.citable_reason(w, hollis, odette.id, "town") != "",
		"sharing Hollis's reading upgrades the contradiction reason to public")


func _test_kiran_firsthand_night_sightings_and_visibility() -> void:
	var g = _fresh_game(4201, 10)
	var w = g.w
	var goods: Array = w.living_good()
	var kiran = goods[0]
	var suspect = goods[1]
	var off_walker = goods[2]
	var victim = goods[3]

	for p in [kiran, suspect, off_walker, victim]:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.told_to = {}
		p.secret = {}
		p.secret_mod = ""
		p.claimed_role = ""
		p.claim_public = false

	kiran.role = "surveyor"
	kiran.home_block = "docks"
	suspect.home_block = "square"
	off_walker.home_block = "square"
	victim.home_block = "docks"
	victim.alive = false
	victim.death_day = 1
	victim.death_cause = "demon"
	w.day = 1
	w.public_event("demon_death", [victim.id], "town")
	w.day = 2
	w.scenes[victim.id] = {"day": 1, "block": "docks", "loc": "wharf"}
	kiran.history[w.time_key(1, C.NIGHT)] = "home:docks"

	# Window sighting on the murder block ("docks") vs street sighting off the murder block ("hill").
	kiran.beliefs.append({"kind": "saw", "who": suspect.id, "loc": "", "block": "docks", "day": 1, "phase": C.NIGHT, "how": "window", "detail": "street"})
	kiran.beliefs.append({"kind": "saw", "who": off_walker.id, "loc": "", "block": "hill", "day": 1, "phase": C.NIGHT, "how": "street", "detail": "street"})
	Mind.recompute_beliefs(w, kiran, " (test firsthand sightings)")

	var sus_items: Array = MindMeeting.case_against(w, kiran, suspect.id)
	var off_items: Array = MindMeeting.case_against(w, kiran, off_walker.id)
	_check(not sus_items.is_empty() and sus_items[0]["kind"] == "public" and sus_items[0]["why"].begins_with("I saw"),
		"firsthand window sighting on murder block becomes a publicly citable reason (%s)" % str(sus_items))
	_check(off_items.is_empty(),
		"firsthand sighting away from murder block and home produces no incriminating reason (%s)" % str(off_items))

	# Nominating from a firsthand sighting emits the sighting card into case_facts.
	var nom_case: Dictionary = Mind.nomination_case(w, kiran, suspect, sus_items[0]["why"])
	_check(nom_case["facts"].any(func(f): return f.get("kind", "") == "sighting" and suspect.id in f.get("subject", [])),
		"nomination_case emits the witness's sighting card when citing 'I saw...'")

	# Unclaimed walking-gift street sighting stays private until the role is claimed.
	var g2 = _fresh_game(4202, 10)
	var w2 = g2.w
	var walker_witness = w2.living_good()[0]
	var target2 = w2.living_good()[1]
	var victim2 = w2.living_good()[2]
	walker_witness.role = "lamplighter"
	walker_witness.claimed_role = ""
	walker_witness.claim_public = false
	walker_witness.max_tier = 0
	walker_witness.secret = {}
	walker_witness.secret_mod = ""
	walker_witness.beliefs = []
	walker_witness.ledger = {}
	walker_witness.told_to = {}
	walker_witness.home_block = "square"
	target2.home_block = "market"
	victim2.home_block = "docks"
	victim2.alive = false
	victim2.death_day = 1
	victim2.death_cause = "demon"
	w2.day = 1
	w2.public_event("demon_death", [victim2.id], "town")
	w2.day = 2
	walker_witness.history[w2.time_key(1, C.NIGHT)] = "night:docks"
	walker_witness.beliefs.append({"kind": "saw", "who": target2.id, "loc": "", "block": "docks", "day": 1, "phase": C.NIGHT, "how": "street", "detail": "street"})
	Mind.recompute_beliefs(w2, walker_witness, " (unclaimed street sighting)")
	var rs_priv: Dictionary = Mind.reason_status(w2, walker_witness, target2.id)
	_check(rs_priv["kind"] == "private" and Mind.citable_reason(w2, walker_witness, target2.id, "town") == "",
		"unclaimed night-walker street sighting stays private rather than leaking night walk (%s)" % str(rs_priv))


func _test_vigil_vs_nightwatch_joint_contradiction() -> void:
	var g = _fresh_game(98933, 10)
	var w = g.w
	w.day = 3
	var listener = w.living_good().filter(func(p): return p.id not in ["agnes", "isolde", "hollis"])[0]
	var agnes = w.by_id["agnes"]
	var isolde = w.by_id["isolde"]
	var hollis = w.by_id["hollis"]
	listener.info_log = []
	listener.beliefs = []
	listener.ledger = {}
	listener.credibility = 0.85

	var c_vig: int = g.add_card({"kind": "sighting", "source": "player", "subject": [agnes.id], "vigil": true, "day": 2, "phase": C.NIGHT, "block": "market", "text": "Night 2 vigil on Market: saw only Agnes."})
	var c_clm: int = g.add_card({"kind": "claim", "source": agnes.id, "subject": [agnes.id], "role": "medium", "day": 2, "phase": C.EVENING, "text": "Agnes claims Medium."})
	var c_nw: int = g.add_card({"kind": "info", "source": isolde.id, "subject": [hollis.id], "role": "nightwatch", "day": 2, "phase": C.NIGHT, "data": {"block": "market", "seen": [hollis.id]}, "text": "Isolde (Night Watch): watched Market, saw Hollis."})
	var id_vig: String = Live.Evidence.normalize_card(g.board[c_vig - 1]).id
	var id_clm: String = Live.Evidence.normalize_card(g.board[c_clm - 1]).id
	var id_nw: String = Live.Evidence.normalize_card(g.board[c_nw - 1]).id
	var cards: Array = [id_vig, id_clm, id_nw]
	var case_doc: Dictionary = {
		"id": "case-vigil-nw", "version": 1, "cards": cards,
		"lines": [{"id": "direct", "label": "Direct", "relation": "supports", "cards": cards, "answers": {}, "positions": {}}],
		"conclusion": {"type": "evil", "target": isolde.id, "at": "Original alignment"},
		"reasons": {agnes.id + ":2": "gift"}, "citations": {agnes.id + ":2": id_clm},
		"answers": {}, "positions": {}, "disputes": [], "reading_challenges": {}, "faults": {}, "derived": [], "conflict_scope": [], "temporal_positions": [],
		"argument_root": "p:1", "arguments": [{"id": "p:1", "label": "Isolde is evil", "parents": [], "without": {}, "case": {
			"id": "case-vigil-nw", "version": 1, "cards": cards,
			"lines": [{"id": "direct", "label": "Direct", "relation": "supports", "cards": cards, "answers": {}, "positions": {}}],
			"conclusion": {"type": "evil", "target": isolde.id, "at": "Original alignment"},
			"reasons": {agnes.id + ":2": "gift"}, "citations": {agnes.id + ":2": id_clm},
			"answers": {}, "positions": {}, "disputes": [], "reading_challenges": {}, "faults": {}, "derived": [], "conflict_scope": [], "temporal_positions": []
		}}]
	}
	var num: int = Live.file(g, case_doc)
	# scale=1.0 is 1-on-1 private ("shared_player": citable to player, withheld from town);
	# scale=0.85 is town meeting ("public": citable to town).
	g._evaluate_deduction(listener, g.board[num - 1], 1.0, false, "private")
	var priv_reasons: Array = MindMeeting.case_against(w, listener, isolde.id)
	_check(not priv_reasons.is_empty() and priv_reasons[0]["kind"] == "shared_player" and Mind.citable_reason(w, listener, isolde.id, "player") != "" and Mind.citable_reason(w, listener, isolde.id, "town") == "",
		"1-on-1 Vigil vs Night Watch case stays shared_player until presented publicly (%s)" % str(priv_reasons))
	g._evaluate_deduction(listener, g.board[num - 1], 0.85, false, "meeting")
	var pub_reasons: Array = MindMeeting.case_against(w, listener, isolde.id)
	_check(not pub_reasons.is_empty() and pub_reasons[0]["kind"] == "public" and Mind.citable_reason(w, listener, isolde.id, "town") != "",
		"meeting Vigil vs Night Watch case upgrades to publicly citable contradiction reason (%s)" % str(pub_reasons))


func _test_elimination_residual_reason() -> void:
	var g = _fresh_game(5150, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var listener = goods[0]
	var suspect = goods[1]
	listener.info_log = []
	listener.beliefs = []
	listener.ledger = {}
	var others: Array = w.npcs.filter(func(p): return p != listener and p != suspect)
	for i in range(mini(4, others.size())):
		var v = others[i]
		v.alive = false
		v.death_day = i + 1
		v.death_cause = "demon"
		w.day = i + 1
		w.public_event("demon_death", [v.id], "town")
	w.day = 4
	Mind.recompute_beliefs(w, listener, " (elimination test)")
	if float(listener.workshop_state.get("requested", {}).get(suspect.id, 0.0)) >= 0.15:
		var rs: Dictionary = Mind.reason_status(w, listener, suspect.id)
		_check(rs["kind"] == "public" and rs["why"] != "",
			"process-of-elimination suspicion >= 0.15 produces a citable elimination reason (%s)" % str(rs))


func _test_defend_self_shared_attribution_and_visibility() -> void:
	var g = _fresh_game(6160, 10)
	var w = g.w
	var goods: Array = w.living_good()
	var defender = goods[0]
	var accuser = goods[1]
	var victim = goods[2]
	defender.role = "lamplighter"
	defender.claimed_role = ""
	defender.claim_public = false
	defender.secret = {}
	defender.home_block = "square"
	victim.home_block = "docks"
	victim.alive = false
	victim.death_day = 1
	victim.death_cause = "demon"
	w.day = 1
	w.public_event("demon_death", [victim.id], "town")
	w.day = 2
	var disclosed_sight: Array = [{
		"kind": "sighting", "source": accuser.id, "subject": [defender.id],
		"block": "docks", "day": 1, "phase": C.NIGHT, "text": "Saw defender on Docks on night 1.",
	}]
	var s_murder: Dictionary = ReasonAttribution.score_disclosed_fact_in_world(w, defender, disclosed_sight[0], defender.id)
	var s_benign: Dictionary = ReasonAttribution.score_disclosed_fact_in_world(w, defender, {"kind": "sighting", "source": accuser.id, "subject": [defender.id], "block": "market", "day": 1, "phase": C.NIGHT}, defender.id)
	_check(float(s_murder["contrib"]) > 0.15 and float(s_murder["contrib"]) > float(s_benign["contrib"]),
		"score_disclosed_fact_in_world weights murder-block sighting above off-scene walk (%.3f vs %.3f)" % [float(s_murder["contrib"]), float(s_benign["contrib"])])
	defender.traits["privacy"] = 0.0
	w.rng.seed = 42
	var df: Dictionary = Mind.defend_self(w, defender, accuser.id, disclosed_sight)
	_check("reveal" in df["moves"],
		"defend_self scores disclosed murder-block sighting via ReasonAttribution and triggers walking-gift reveal (%s)" % str(df["moves"]))


func _test_passive_meeting_nomination_reason_rate(seeds_per_size: int = 2) -> void:
	var stats: Dictionary = _measure_passive_nominations(seeds_per_size)
	var above_floor: int = int(stats.good_noms_above_floor)
	_check(above_floor == 0 or int(stats.good_noms_with_reason) == above_floor,
		"every good nomination with shared suspicion >= 0.15 has a shared reason (%d / %d)" % [int(stats.good_noms_with_reason), above_floor])


func _run_passive_citation_sweep(n_games: int) -> void:
	var stats: Dictionary = _measure_passive_nominations(n_games)
	var total_noms: int = int(stats.total_npc_noms)
	var cited_noms: int = int(stats.total_npc_noms_with_reason)
	var pct: float = 100.0 * float(cited_noms) / float(maxi(1, total_noms))
	print("=== PHASE 2A PASSIVE NOMINATION CITATION SWEEP (%d seeds x 2 setups) ===" % n_games)
	print("  NPC nominations: %d total | with shared/bluff reason: %d (%.1f%%) | Good above 0.15 floor: %d/%d | fallbacks: %d" % [
		total_noms, cited_noms, pct, int(stats.good_noms_with_reason), int(stats.good_noms_above_floor), int(stats.fallbacks)])


func _measure_passive_nominations(n_games: int) -> Dictionary:
	var fallbacks: int = 0
	var total_npc_noms: int = 0
	var total_npc_noms_with_reason: int = 0
	var good_noms_above_floor: int = 0
	var good_noms_with_reason: int = 0
	for npc_count in [7, 10]:
		for idx in range(n_games):
			var g = _fresh_game(10000 + npc_count * 1000 + idx, npc_count)
			var w = g.w
			var guard: int = 0
			while g.state != "over" and guard < 400:
				guard += 1
				var cmd: String = "look"
				match g.state:
					"approach": cmd = "decline"
					"day": cmd = "wait"
					"talk": cmd = "bye"
					"meeting": cmd = "done" if g.town_quiet else "wait"
					"nomination":
						var last_noms: Array = w.dlog.entries.filter(func(e): return e.get("type", "") == "think" and e.get("data", {}).get("topic", "") == "nomination_case")
						if not last_noms.is_empty():
							var latest: Dictionary = last_noms[-1]
							total_npc_noms += 1
							var items_logged: Array = latest.get("data", {}).get("items", [])
							if not items_logged.is_empty():
								total_npc_noms_with_reason += 1
							var actor_id: String = str(latest.get("actor", ""))
							var nom_npc = w.by_id.get(actor_id)
							var cur_nominee: String = str(w.meeting.get("nominated", [""])[-1]) if not w.meeting.get("nominated", []).is_empty() else ""
							if nom_npc != null and not nom_npc.is_evil() and cur_nominee != "":
								var req: float = float(nom_npc.workshop_state.get("requested", {}).get(cur_nominee, 0.0))
								if req >= 0.15:
									good_noms_above_floor += 1
									if not items_logged.is_empty():
										good_noms_with_reason += 1
						cmd = "vote no"
					"night": cmd = "sleep"
				g.command(cmd)
			fallbacks += g.shared_fallbacks.size()
	return {
		"fallbacks": fallbacks,
		"total_npc_noms": total_npc_noms,
		"total_npc_noms_with_reason": total_npc_noms_with_reason,
		"good_noms_above_floor": good_noms_above_floor,
		"good_noms_with_reason": good_noms_with_reason,
	}
