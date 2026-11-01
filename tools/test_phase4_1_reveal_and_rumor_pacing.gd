## Phase 4.1 regression suite & optional 50-seed checkpoint sweep:
## - Knob 1: Tapered ONGOING_INFO_EARLY_CLAIM (-0.45 D1, -0.20 D2, 0.0 D3+) and
##           HIDE_FROM_DEMON_CLAIM (-0.50 D1, -0.30 D2, -0.10 D3+, -0.35 Warden floor),
##           plus 0.40 * (day - 1) public-claim day slope.
## - Knob 2: (s2 - 0.45) * 1.5 reactive reveal pivot in reveal_to_accuse / reveal_to_nominate
##           and removal of `- paranoia` from MindDialogue.fear_chance.
## - Knob 3: Low-walker daytime work/haunt & unease rumor fuel in Social._pick_item / _deliver.
##
## Optional CLI checkpoint sweep (before touching Phase 4.2):
##   godot --headless --path . --script res://tools/test_phase4_1_reveal_and_rumor_pacing.gd -- --sweep 50 [--out sweep_4_1.json]
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const Evil = preload("res://sim/evil.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: " + label)
	else:
		print("PASS: " + label)


func _init() -> void:
	_test_knob1_tapered_role_reluctance_and_day_slope()
	_test_knob2_reactive_reveal_pivot_and_fear_paranoia_fix()
	_test_knob3_zero_walker_daytime_rumor_fuel()
	_test_threat_intel_escalation()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--sweep" in user_args:
		var s_idx: int = user_args.find("--sweep")
		var games: int = 50
		if s_idx + 1 < user_args.size() and user_args[s_idx + 1].is_valid_int():
			games = maxi(1, int(user_args[s_idx + 1]))
		var report: Dictionary = _run_checkpoint_sweep(games)
		if "--out" in user_args:
			var o_idx: int = user_args.find("--out")
			if o_idx + 1 < user_args.size():
				var f = FileAccess.open(user_args[o_idx + 1], FileAccess.WRITE)
				if f != null:
					f.store_string(JSON.stringify(report, "\t"))
					f.close()
	print("Phase 4.1 reveal & rumor pacing: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _test_knob1_tapered_role_reluctance_and_day_slope() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var w = g.w
	var dummy = w.living_good()[0]

	# Ongoing info taper: -0.45 (D1) -> -0.20 (D2) -> absent/0.0 (D3+)
	var seer_def = C.role_def("seer")
	w.day = 1
	var p_d1: Dictionary = {}
	seer_def.score_public_claim(w, dummy, p_d1)
	w.day = 2
	var p_d2: Dictionary = {}
	seer_def.score_public_claim(w, dummy, p_d2)
	w.day = 3
	var p_d3: Dictionary = {}
	seer_def.score_public_claim(w, dummy, p_d3)
	_check(
		is_equal_approx(float(p_d1.get("gift_keeps_giving", 0.0)), -0.45)
		and is_equal_approx(float(p_d2.get("gift_keeps_giving", 0.0)), -0.20)
		and not p_d3.has("gift_keeps_giving"),
		"Ongoing info reluctance tapers cleanly (-0.45 D1, -0.20 D2, 0.0 D3)"
	)

	# Non-Warden utility taper (Veteran): -0.50 (D1) -> -0.30 (D2) -> -0.10 (D3+)
	var vet_def = C.role_def("veteran")
	w.day = 1
	var v_d1: Dictionary = {}
	vet_def.score_public_claim(w, dummy, v_d1)
	w.day = 2
	var v_d2: Dictionary = {}
	vet_def.score_public_claim(w, dummy, v_d2)
	w.day = 3
	var v_d3: Dictionary = {}
	vet_def.score_public_claim(w, dummy, v_d3)
	_check(
		is_equal_approx(float(v_d1.get("hides_from_demon", 0.0)), -0.50)
		and is_equal_approx(float(v_d2.get("hides_from_demon", 0.0)), -0.30)
		and is_equal_approx(float(v_d3.get("hides_from_demon", 0.0)), -0.10),
		"Utility role hides_from_demon tapers (-0.50 D1, -0.30 D2, -0.10 D3)"
	)

	# Warden retains -0.35 floor on D2 and D3+
	var warden_def = C.role_def("warden")
	w.day = 1
	var wd_d1: Dictionary = {}
	warden_def.score_public_claim(w, dummy, wd_d1)
	w.day = 2
	var wd_d2: Dictionary = {}
	warden_def.score_public_claim(w, dummy, wd_d2)
	w.day = 3
	var wd_d3: Dictionary = {}
	warden_def.score_public_claim(w, dummy, wd_d3)
	_check(
		is_equal_approx(float(wd_d1.get("hides_from_demon", 0.0)), -0.50)
		and is_equal_approx(float(wd_d2.get("hides_from_demon", 0.0)), -0.35)
		and is_equal_approx(float(wd_d3.get("hides_from_demon", 0.0)), -0.35),
		"Warden retains -0.35 floor on Day 2 and Day 3+ (-0.50 D1, -0.35 D2, -0.35 D3)"
	)

	# Monte Carlo check: public claim rate rises substantially from Day 1 to Day 2 to Day 3.
	dummy.role = "veteran"
	dummy.claim_public = false
	dummy.protect_lock = false
	dummy.pressure = 0.1
	dummy.traits["privacy"] = 0.45
	w.meeting = {"nominated": []}
	var counts: Dictionary = {1: 0, 2: 0, 3: 0}
	for d in [1, 2, 3]:
		w.day = d
		for _i in range(250):
			if Mind._public_claim_decision(w, dummy) != "":
				counts[d] += 1
	_check(counts[1] < counts[2] and counts[2] < counts[3] and counts[3] >= 120,
		"Public claim probability climbs across Days 1-3 (%d -> %d -> %d / 250)" % [counts[1], counts[2], counts[3]])


func _test_knob2_reactive_reveal_pivot_and_fear_paranoia_fix() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(92974, 10)
	var w = g.w
	var goods: Array = w.living_good()
	var seer = goods[0]
	var suspect = goods[1]
	var partner = goods[2]

	# Fear-paranoia fix: killing townsfolk (raising paranoia) must NEVER lower fear_chance!
	seer.traits["composure"] = 0.35
	seer.pressure = 0.0
	seer.fear_eased = false
	var fear_zero_dead: float = Mind.fear_chance(w, seer)
	goods[3].alive = false
	goods[4].alive = false
	goods[5].alive = false
	var fear_three_dead: float = Mind.fear_chance(w, seer)
	_check(is_equal_approx(fear_zero_dead, fear_three_dead) and fear_three_dead >= fear_zero_dead,
		"fear_chance no longer drops as deaths raise paranoia (0 dead %.3f vs 3 dead %.3f)" % [fear_zero_dead, fear_three_dead])
	goods[3].alive = true
	goods[4].alive = true
	goods[5].alive = true

	# Reactive reveal pivot: at Bayesian ping suspicion s2 = 0.54, Seer reveals on a healthy share of accusations.
	seer.role = "seer"
	seer.claim_public = false
	seer.claimed_role = ""
	seer.traits["privacy"] = 0.45
	seer.traits["confidence"] = 0.55
	seer.traits["composure"] = 0.75
	seer.ledger.clear()
	seer.workshop_state.clear()
	seer.workshop_state["enabled"] = true
	seer.info_log = [{"day": 1, "role": "seer", "data": {"pair": [suspect.id, partner.id], "yes": true}, "true": true, "shared": false, "text": "between %s and %s, one reads as the Demon" % [suspect.name, partner.name]}]
	seer.applied_info = 0
	Mind.update_from_own_info(w)
	w.day = 2
	var reveals: int = 0
	for _i in range(200):
		var res: Dictionary = Mind._accuse_tier_impl(w, seer, suspect, 0.54)
		if res.get("tier", "") == "reveal":
			reveals += 1
	_check(reveals >= 70,
		"Seer with 0.54 Bayesian ping suspicion chooses reveal_to_accuse regularly (%d / 200)" % reveals)


func _test_knob3_zero_walker_daytime_rumor_fuel() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var speaker = goods[0]
	var listener = goods[1]
	var third = goods[2]

	# Strip all night sightings, private gifts, secrets, and strong (>= 0.5) opinions to mimic a zero-walker Revenant+Scion drought.
	for p in [speaker, listener]:
		p.role = "veteran"
		p.info_log = []
		p.applied_info = 0
		p.secret = {}
		p.known_secrets = {}
		p.hearsay = []
		p.player_cases = []
		p.beliefs = []
		p.told_to = {}
		p.ledger.clear()
		for id in p.suspicion:
			p.suspicion[id] = 0.20

	w.day = 2
	w.phase = C.MORNING
	speaker.traits["gossip"] = 0.85
	# Routines alone cannot become observations, including when memories are stale.
	for memory in [[], [{"kind": "saw", "who": third.id, "loc": "bakery", "block": w.loc_block("bakery"), "day": 0, "phase": C.MORNING}]]:
		speaker.beliefs = memory
		var invented: bool = false
		for _attempt in range(30):
			var candidate = Social._pick_item(w, speaker, listener)
			invented = invented or (candidate != null and candidate.kind == "day_sighting")
		_check(not invented, "missing or stale observations never generate a sighting from work/haunt routines")
	speaker.beliefs = []
	third.work = "bakery"
	speaker.beliefs.append({"kind": "saw", "who": third.id, "loc": "bakery", "block": w.loc_block("bakery"), "day": 2, "phase": C.MORNING})

	# Seeing someone at their workplace establishes presence, not that they worked.
	var witnessed: Dictionary = {}
	for _attempt in range(30):
		var candidate = Social._pick_item(w, speaker, listener)
		if candidate != null and candidate.kind == "day_sighting":
			witnessed = candidate
			break
	_check(not witnessed.is_empty() and witnessed.about == third.id and witnessed.loc == "bakery" and witnessed.day == 2 and witnessed.phase == C.MORNING, "daytime rumor preserves the witnessed person, location and time")
	var wording: String = Social._describe(w, speaker, witnessed) if not witnessed.is_empty() else ""
	_check("was seen at" in wording and not "working" in wording and not "keeping to" in wording, "a witnessed visit does not invent work or habitual activity")
	var ledger_before: String = JSON.stringify(listener.ledger)
	var trust_before: float = float(listener.npc_trust.get(speaker.id, 0.5))
	var shares_before: int = w.dlog.entries.filter(func(e): return e["type"] == "npc_share").size()

	var delivered_count: int = 0
	for _i in range(25):
		speaker.told_to.clear()
		var picked = Social._pick_item(w, speaker, listener)
		if picked != null:
			_check(picked["kind"] in ["day_sighting", "unease"], "zero-walker pick produces daytime sighting or unease item (%s)" % str(picked["kind"]))
			Social._deliver(w, speaker, listener, picked)
			delivered_count += 1
			break

	var shares_after: int = w.dlog.entries.filter(func(e): return e["type"] == "npc_share").size()
	var trust_after: float = float(listener.npc_trust.get(speaker.id, 0.5))
	_check(delivered_count == 1 and shares_after == shares_before + 1,
		"Social._pick_item and _deliver emit npc_share in a zero-walker drought")
	_check(trust_after > trust_before,
		"believed daytime work/haunt share builds positive gossip_bond (%.3f -> %.3f)" % [trust_before, trust_after])
	_check(JSON.stringify(listener.ledger) == ledger_before,
		"daytime work/haunt share adds zero alignment suspicion entries to listener.ledger")

	if not witnessed.is_empty():
		Social._deliver(w, speaker, listener, witnessed)
	var repeated: bool = false
	for _attempt in range(30):
		var candidate = Social._pick_item(w, speaker, listener)
		repeated = repeated or (candidate != null and candidate.kind == "day_sighting")
	_check(not repeated, "an already shared observation cannot trigger an invented routine replacement")

	w.phase = C.AFTERNOON
	speaker.beliefs = [{"kind": "saw", "who": third.id, "loc": "", "block": "hill", "day": 2, "phase": C.AFTERNOON}]
	var block_only: Dictionary = {}
	for _attempt in range(30):
		var candidate = Social._pick_item(w, speaker, listener)
		if candidate != null and candidate.kind == "day_sighting":
			block_only = candidate
			break
	_check(not block_only.is_empty() and block_only.loc == "" and block_only.block == "hill" and "during the day" in Social._describe(w, speaker, block_only), "a block-only observation never acquires a workplace or haunt location")


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


func _run_checkpoint_sweep(games: int) -> Dictionary:
	var out: Dictionary = {"tuning": Tuning.fingerprint(), "games_per_setup": games, "setups": {}}
	for npc_count in [7, 10]:
		var day_stats: Dictionary = {}
		for d in [1, 2, 3]:
			day_stats[d] = {"active_games": 0, "living": 0, "public_claimed": 0, "pub_or_priv_ready": 0, "noms": 0, "execs": 0}
		var total_shares: int = 0
		var rev_scion_games: int = 0
		var rev_scion_shares: int = 0
		for idx in range(games):
			var seed_v: int = 1000 + idx
			var g = Game.new()
			g.detailed_logging = false
			g.log_dir = "user://test_logs/sweep_4_1"
			g.new_case(seed_v, npc_count)
			var w = g.w
			var is_rev_scion: bool = w.minion_ids.size() >= 2 and w.minion_ids.all(func(mid): return w.by_id[mid].role in ["revenant", "scion"])
			var recorded_days: Dictionary = {}
			var guard: int = 0
			while g.state != "over" and guard < 500:
				guard += 1
				if g.state == "night" and w.day in [1, 2, 3] and not recorded_days.has(w.day):
					recorded_days[w.day] = true
					_record_day_claim_snapshot(w, day_stats[w.day])
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
				_record_day_claim_snapshot(w, day_stats[w.day])
			var shares: int = w.dlog.entries.filter(func(e): return e["type"] == "npc_share").size()
			total_shares += shares
			if is_rev_scion:
				rev_scion_games += 1
				rev_scion_shares += shares
		var summary_days: Dictionary = {}
		print("\n=== PHASE 4.1 CHECKPOINT SWEEP (%d NPCs, %d seeds, tuning %s) ===" % [npc_count, games, Tuning.fingerprint()])
		for d in [1, 2, 3]:
			var st: Dictionary = day_stats[d]
			var ag: int = maxi(1, int(st.active_games))
			var lv: int = maxi(1, int(st.living))
			var pub_pct: float = 100.0 * float(st.public_claimed) / float(lv)
			var priv_pct: float = 100.0 * float(st.pub_or_priv_ready) / float(lv)
			var nom_pct: float = 100.0 * float(st.noms) / float(ag)
			var exec_pct: float = 100.0 * float(st.execs) / float(ag)
			summary_days[str(d)] = {
				"active_games": st.active_games,
				"public_claim_pct": snappedf(pub_pct, 0.1),
				"public_or_private_ready_pct": snappedf(priv_pct, 0.1),
				"meeting_with_nomination_pct": snappedf(nom_pct, 0.1),
				"meeting_with_execution_pct": snappedf(exec_pct, 0.1),
			}
			print("  Day %d (active %d): public %.1f%% | pub+priv-ready %.1f%% | nom-games %.1f%% | exec-games %.1f%%" % [d, st.active_games, pub_pct, priv_pct, nom_pct, exec_pct])
		var mean_shares: float = float(total_shares) / float(maxi(1, games))
		var rs_shares: float = float(rev_scion_shares) / float(maxi(1, rev_scion_games)) if rev_scion_games > 0 else 0.0
		print("  Mean npc_share/case: %.1f (Revenant+Scion %d cases: %.1f)" % [mean_shares, rev_scion_games, rs_shares])
		out.setups[str(npc_count)] = {
			"days": summary_days,
			"mean_npc_shares": snappedf(mean_shares, 0.1),
			"revenant_scion_games": rev_scion_games,
			"revenant_scion_mean_shares": snappedf(rs_shares, 0.1),
		}
	return out


func _record_day_claim_snapshot(w, st: Dictionary) -> void:
	st.active_games += 1
	for n in w.living():
		st.living += 1
		if n.claim_public:
			st.public_claimed += 1
			st.pub_or_priv_ready += 1
		elif n.max_tier >= 3 or (Mind.MindDialogue._target_tier(w, n) >= 3 and not Mind.MindDialogue._afraid(w, n)):
			st.pub_or_priv_ready += 1
	var day_noms: bool = w.dlog.entries.any(func(e): return e["type"] == "nomination" and int(e.get("day", -1)) == w.day)
	var day_execs: bool = w.executions.any(func(ex): return int(ex.get("day", -1)) == w.day)
	if day_noms:
		st.noms += 1
	if day_execs:
		st.execs += 1
