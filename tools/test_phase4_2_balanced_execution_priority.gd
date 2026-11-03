## Phase 4.2 regression & checkpoint sweep: listener-mean execution priority traded against
## bandwagon consensus, death-spiral paranoia, and raw player ballot pull.
##
## Unit suite only:
##   godot --headless --path . --script res://tools/test_phase4_2_balanced_execution_priority.gd
## With 50-seed checkpoint sweep (prints progress every 10 seeds):
##   godot --headless --path . --script res://tools/test_phase4_2_balanced_execution_priority.gd -- --sweep 50 --out res://logs/sweep_4_2.json
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_test_listener_mean_centering_and_tie_symmetry()
	_test_bandwagon_pullback_vs_model_standout()
	_test_death_spiral_pullback_and_threshold_parts_parity()
	_test_player_ballot_leverage_trim()
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
				print("Wrote Phase 4.2 sweep JSON to %s" % out_path)
	print("Phase 4.2 balanced execution priority: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _test_listener_mean_centering_and_tie_symmetry() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 7)
	var goods: Array = g.w.living_good()
	var seer = goods[0]
	var p1 = goods[1]
	var p2 = goods[2]
	var p3 = goods[3]
	var bystander = goods[4]
	seer.role = "seer"
	seer.ledger.clear()
	seer.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	for id in seer.suspicion:
		seer.suspicion[id] = Tuning.Setup.INITIAL_SUSPICION_BASE
		seer.npc_trust[id] = 0.5

	# 1) Equal priors and a Seer YES produce a symmetric positive priority; the bystander gets 0.0.
	seer.info_log = [{"day": 1, "phase": C.NIGHT, "role": "seer", "data": {"pair": [p1.id, p2.id], "yes": true}, "true": true, "shared": false, "text": "seer yes"}]
	seer.applied_info = 0
	Mind.update_from_own_info(g.w)
	var ep_p1: float = Mind.execution_priority(seer, p1.id)
	var ep_p2: float = Mind.execution_priority(seer, p2.id)
	var ep_by: float = Mind.execution_priority(seer, bystander.id)
	var ep_self: float = Mind.execution_priority(seer, seer.id)
	_check(ep_p1 > 0.0 and is_equal_approx(ep_p1, ep_p2), "symmetric 2-person Seer YES pair receives equal positive execution_priority (%.3f == %.3f)" % [ep_p1, ep_p2])
	_check(is_zero_approx(ep_by) and is_zero_approx(ep_self), "untouched bystander and self receive 0.0 execution_priority (bystander %.3f, self %.3f)" % [ep_by, ep_self])

	# 2) Dead person receives 0.0 execution_priority even if implicated by an old card.
	p1.alive = false
	Mind.refresh_beliefs(g.w, seer, "p1 died")
	_check(is_zero_approx(Mind.execution_priority(seer, p1.id)) and Mind.execution_priority(seer, p2.id) > ep_p2, "dead suspect drops to 0.0 execution_priority while surviving partner concentrates priority")
	p1.alive = true

	# 3) A 4-way symmetric Dowser count=2 group [p1, p2, p3, bystander] has zero alphabetical ID bias across the 4 tied members.
	var dowser = seer
	for id in dowser.suspicion:
		dowser.suspicion[id] = Tuning.Setup.INITIAL_SUSPICION_BASE
	dowser.role = "dowser"
	dowser.ledger.clear()
	dowser.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	dowser.info_log = [{"day": 1, "phase": C.MORNING, "role": "dowser", "data": {"group": [p1.id, p2.id, p3.id, bystander.id], "count": 2}, "true": true, "shared": false, "text": "dowser 2 of 4"}]
	dowser.applied_info = 0
	Mind.update_from_own_info(g.w)
	var grp_eps: Array = [p1.id, p2.id, p3.id, bystander.id].map(func(id): return Mind.execution_priority(dowser, id))
	_check(grp_eps.all(func(v): return is_equal_approx(float(v), float(grp_eps[0]))), "4-way symmetric Dowser group has zero alphabetical ID bias in execution_priority (%s)" % str(grp_eps))


func _test_bandwagon_pullback_vs_model_standout() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7101, 7)
	var w = g.w
	w.day = 2
	w.begin_meeting()
	var goods: Array = w.living_good()
	var voter = goods[0]
	var target = goods[1]
	voter.role = "surveyor"
	voter.traits["confidence"] = 0.5
	voter.traits["composure"] = 0.5
	voter.cleared.clear()
	voter.spare_pref.clear()
	for m in w.npcs:
		voter.suspicion[m.id] = 0.10
		voter.npc_trust[m.id] = 0.50

	# Three bare public accusations against an uncorroborated 0.10 bystander must stay well below 0.52 vote bar.
	var accusers: Array = w.npcs.filter(func(m): return m != voter and m != target).slice(0, 3)
	for a in accusers:
		w.stances[a.id] = {"target": target.id, "day": w.day}
	Mind.refresh_consensus(w, voter, target.id)
	var chorus_p: float = float(voter.consensus_pressure.get(target.id, 0.0))
	_check(chorus_p < 0.17 and not Mind.vote(w, voter, target.id, accusers[0].id, false, "", 0), "3-voice bare bandwagon (%.3f) cannot stampede an uninformed voter over the 0.52 bar" % chorus_p)

	# Even 5 voices cap at CONSENSUS_CAP = 0.22.
	for a in w.npcs:
		if a != voter and a != target:
			w.stances[a.id] = {"target": target.id, "day": w.day}
	Mind.refresh_consensus(w, voter, target.id)
	_check(float(voter.consensus_pressure.get(target.id, 0.0)) <= Tuning.Meeting.CONSENSUS_CAP + 1e-6, "consensus_pressure respects tightened 0.22 cap")

	# Meanwhile, a genuine world-model standout (suspicion 0.42 + priority 0.55 -> +0.121) crosses 0.52 without needing a chorus.
	w.stances.clear()
	Mind.refresh_all_consensus(w)
	voter.suspicion[target.id] = 0.42
	voter.workshop_state = {"active": true, "action": {"execution_priority": {target.id: 0.55}}}
	# A vote-formula check: hold the shared refresh (vote reconsiders through it, purge 3)
	# so the injected priority and suspicion are what the formula sees.
	g._workshop_busy = true
	_check(Mind.vote(w, voter, target.id, accusers[0].id, false, "", 0), "world-model standout (0.42 susp + 0.22*0.55 priority = 0.541) crosses 0.52 vote bar without bandwagon chorus")


func _test_death_spiral_pullback_and_threshold_parts_parity() -> void:
	var g = Game.new()
	g.detailed_logging = true
	g.new_case(92974, 10)
	var w = g.w
	w.day = 3
	w.begin_meeting()
	var goods: Array = w.living_good()
	var voter = goods[0]
	var target = goods[1]
	# Kill 3 other villagers to simulate Day 3 in a 10-NPC case.
	for k_idx in [2, 3, 4]:
		goods[k_idx].alive = false
	voter.role = "surveyor"
	voter.traits["confidence"] = 0.5
	voter.traits["composure"] = 0.5
	voter.cleared.clear()
	voter.spare_pref.clear()
	voter.workshop_state.clear()
	for m in w.npcs:
		voter.suspicion[m.id] = 0.40
		voter.npc_trust[m.id] = 0.50

	# With 3 dead at mid composure: paranoia = 0.07 * 3 * 0.7 = 0.147.
	# Old need = 0.50 - 0.40*0.147 - 0.06 = 0.3812 (voted YES on lukewarm 0.40!).
	# New need = 0.52 - 0.20*0.147 - 0.06 = 0.4306 (refuses lukewarm 0.40 panic hang!).
	w.stances.clear()
	voter.consensus_pressure.clear()
	g._workshop_busy = true # threshold formula only; keep the fixture suspicions exact
	var panic_yes: bool = Mind.vote(w, voter, target.id, "player", false, "", 0)
	_check(not panic_yes, "3 deaths in a 10-NPC game no longer drop the vote bar below 0.40 on lukewarm suspects")

	var evals: Array = w.dlog.trace_events().filter(func(ev): return ev.type == "decision" and ev.data.kind == "vote" and ev.data.stage == "evaluation" and ev.actor == voter.id)
	_check(not evals.is_empty(), "recorded structured vote evaluation with dead villagers")
	if not evals.is_empty():
		var det: Dictionary = evals[-1].data.details
		var sum_thr: float = 0.0
		for v_part in det.threshold_parts.values():
			sum_thr += float(v_part)
		_check(absf(sum_thr - float(det.threshold)) < 1e-9, "vote threshold_parts sum matches exact threshold even with 3 dead (%.6f == %.6f)" % [sum_thr, float(det.threshold)])


func _test_player_ballot_leverage_trim() -> void:
	var g = Game.new()
	g.detailed_logging = true
	g.new_case(42, 7)
	var w = g.w
	w.day = 2
	w.begin_meeting()
	var voter = w.living_good()[0]
	var target = w.living_good()[1]
	voter.role = "surveyor"
	voter.credibility = 1.0
	voter.workshop_state.clear()
	voter.suspicion[target.id] = 0.20
	Mind.vote(w, voter, target.id, "player", true, "accuse", 0)
	var evals: Array = w.dlog.trace_events().filter(func(ev): return ev.type == "decision" and ev.data.kind == "vote" and ev.data.stage == "evaluation" and ev.actor == voter.id)
	var parts: Dictionary = evals[-1].data.details.parts
	_check(is_equal_approx(float(parts.get("player_votes_yes", 0.0)), 0.14) and is_equal_approx(float(parts.get("player_accuses", 0.0)), 0.15),
		"trimmed player_votes_yes (0.14 at cred 1.0) and player_accuses (0.15 at cred 1.0) prevent single-click rubber-stamp hangs")


func _run_checkpoint_sweep(games: int) -> Dictionary:
	var out: Dictionary = {"tuning": Tuning.fingerprint(), "games_per_setup": games, "setups": {}}
	for npc_count in [7, 10]:
		var day_stats: Dictionary = {}
		for d in [1, 2, 3]:
			day_stats[d] = {"active_games": 0, "living": 0, "public_claimed": 0, "pub_or_priv_ready": 0, "noms": 0, "execs": 0, "evil_execs": 0, "good_execs": 0}
		var good_wins: int = 0
		print("\nRunning Phase 4.2 sweep (%d NPCs, %d seeds)..." % [npc_count, games])
		for idx in range(games):
			var seed_v: int = 1000 + idx
			var g = Game.new()
			g.detailed_logging = false
			g.log_dir = "user://test_logs/sweep_4_2"
			g.new_case(seed_v, npc_count)
			var w = g.w
			var recorded_days: Dictionary = {}
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
			if w.winner == "good":
				good_wins += 1
			if (idx + 1) % 10 == 0 or idx + 1 == games:
				print("  [%d NPCs] %d / %d seeds complete" % [npc_count, idx + 1, games])
		var summary_days: Dictionary = {}
		print("=== PHASE 4.2 CHECKPOINT SWEEP (%d NPCs, %d seeds, tuning %s) ===" % [npc_count, games, Tuning.fingerprint()])
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
		print("  Passive-bot Good win rate: %.1f%% (%d / %d)" % [win_pct, good_wins, games])
		out.setups[str(npc_count)] = {
			"days": summary_days,
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
