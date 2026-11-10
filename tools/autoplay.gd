## Headless test harness: a simple bot plays cases through the same command interface
## a human uses, then reports results and writes dev logs.
##
##   godot --headless --path . --script res://tools/autoplay.gd -- [--seed N] [--games G]
##         [--npcs 7] [--log-dir DIR] [--transcript] [--echo-log] [--passive] [--results FILE] [--no-trace]
##         [--no-attention] [--insight 1.0] [--dynamic] [--results-jsonl FILE] [--sha SHA]
##
## --force-demon ID deals that demon type (the Demon stays on the script too, so the
## solver weighs both): e.g. --force-demon daykiller for the Hexer.
## Balance sweep (docs/balance_sweep.md): --dynamic deals each case from
## ScriptBuilder.dynamic seeded by the case seed, so a game is reproducible from its seed.
## --results-jsonl appends one flat `sweep_v1` record per finished game (tools/sweep_record.gd)
## and flushes after each, so a killed run keeps what it finished. --sha tags the records.
## Both read finished state only: no world RNG draws, no decisions changed.
##
## --passive: a control player who does nothing (waits every phase, declines approaches,
## never nominates, votes no, sleeps). The town's win rate on its own: the floor.
## Otherwise the bot is the analyst (tools/analyst.gd): a neutral test juror reads the
## player's board through the shared model and gives everyone a posterior chance of being
## evil; the bot ranks, nominates, votes and builds Workshop cases from it. That is the
## ceiling, a near-ideal reader. --insight < 1.0 makes it miss that share of cards.
##
## --transcript prints everything the player would see. Logs go to <log-dir>/case_<seed>.*
## --no-trace skips detailed state sidecars; ordinary developer logs and metrics remain.
## --no-attention (experiment): every shared-model listener reads every card it holds;
## Insight still limits links and the explanation search. Measures how much the card
## budget scatters the town's beliefs, and what reading everything costs.
##
## The M4 policy (meeting plan slice M4; default): the bot presses the nominee at the
## podium, nominates less (and not below the one on the block), keeps vigils where the
## Demon is likeliest to strike (the homes of trusted high-value gifts, away from a suspect
## walker's own home), lets exclusion cards (empty vigils, complete vigil lists) into its
## cases against claimed walkers, and names the Demon from P(Demon), not P(evil).
## --pre-m4 restores the earlier policy, for A/Bs.
##
## Suspicion scale: at the end of each day (entering night, or the game's end) every
## living good NPC's suspicion is summarised against the truth: their top suspicion,
## the Demon's and minions' suspicion and rank, their good-nomination threshold, and
## every vote's score against its need. Printed per day; stored per case in --results
## ("suspicion_days", "votes"). Reads state only: no RNG draws, no decisions changed.
## The bot only uses information a player could see, except that it knows which idle NPCs
## are at which exact location within a block (to keep it from wasting moves).
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const Metrics = preload("res://game/case_metrics.gd")
const BotWorkshop = preload("res://tools/autoplay_workshop.gd")
const Analyst = preload("res://tools/analyst.gd")
const MindPodium = preload("res://sim/mind_podium.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const ScriptBuilder = preload("res://sim/script_builder.gd")
const SweepRecord = preload("res://tools/sweep_record.gd")
const VoteShape = preload("res://tools/vote_shape.gd")

## Analyst decision thresholds on the juror's posterior P(evil) (bot policy, not game tuning).
const TELL_P = 0.55
const NOMINATE_P = 0.6
const ACCUSE_P = 0.6
const VOTE_P = 0.5
const DEFEND_P = 0.12
const CLEMENCY_P = 0.06
const CASE_P = 0.4
# M4 (meeting plan slice M4; --pre-m4 restores the old values and rules).
const M4_NOMINATE_P = 0.7      # half the bot's wrongful hangs were its own nominations
const M4_BLOCK_MARGIN = 0.1    # don't nominate unless they're this far above the one on the block
const PRESS_INTEREST_P = 0.35  # press a nominee it suspects at least this much (always its own)
const VIGIL_SAFE_P = 0.35      # a trusted claimant: below this P(evil)
const DEMON_CANDIDATES = 3     # the Demon guess weighs P(Demon) for the top few by P(evil)
const HIGH_VALUE_GIFTS = ["warden", "veteran"]   # plus C.INFO_ROLES
const WALK_CLAIMS = ["lamplighter", "nightwatch", "medium", "warden", "sexton"]

const NEW_ACTIONS = ["offer_ward", "offer_vigil", "ask_person", "answer_confidence", "answer_protection", "apologise", "request_check", "request_guard", "request_watch", "keep_ward", "keep_vigil"]
var talk_policy_used = {}
var new_talk_counts = {}
var g
var transcript = false
var passive = false
var trace_enabled = true
var no_workshop_cases = false
var no_hub = false
var talked = {}
var linked_pairs = {}
var blocked_cmds = {}
var probed_traces = {}
var filed_workshop_sigs = {}
var last_workshop_case_by_target = {}
var workshop_cases_filed: int = 0
var hub_cases_filed: int = 0
var rng = RandomNumberGenerator.new()
var insight: float = 1.0
var analyst = {}
var _belief_key = ""
var _belief_cache = {}
var dynamic_scripts = false
var force_demon = ""          # --force-demon ID: deal this demon type, with the Demon also on the script (demon types step 3)
var m4 = true
var _demon_key = ""
var _demon_guess = ""
var last_commands: int = 0
var last_guard: int = 0

func _init() -> void:
	var args = _parse(OS.get_cmdline_user_args())
	var first: int = int(args.get("seed", "1"))
	var games: int = int(args.get("games", "1"))
	# Only the town sizes with a defined setup make real games (others silently play with
	# no working evil team: no kills, nothing to find).
	if not C.SETUPS.has(int(args.get("npcs", "7"))):
		push_error("--npcs must be one of %s (got %s)" % [str(C.SETUPS.keys()), args.get("npcs", "7")])
		quit(2)
		return
	transcript = args.has("transcript")
	insight = float(args.get("insight", "1.0"))
	passive = args.has("passive")
	trace_enabled = not args.has("no-trace")
	dynamic_scripts = args.has("dynamic")
	force_demon = str(args.get("force-demon", ""))
	m4 = not args.has("pre-m4")
	var jsonl = null
	if args.has("results-jsonl"):
		var jpath = ProjectSettings.globalize_path(args["results-jsonl"])
		DirAccess.make_dir_recursive_absolute(jpath.get_base_dir())
		jsonl = FileAccess.open(jpath, FileAccess.READ_WRITE) if FileAccess.file_exists(jpath) else FileAccess.open(jpath, FileAccess.WRITE)
		if jsonl == null:
			push_error("Cannot open results-jsonl: " + jpath)
			quit(1)
			return
		jsonl.seek_end()
	no_workshop_cases = args.has("no-workshop-cases")
	no_hub = args.has("no-hub")
	if args.has("no-attention"):
		preload("res://workshop/reasoner.gd").unlimited_cards = true
	# The solver is C# only (Nov 4 cutover); --backend is accepted for old scripts and ignored.
	if args.has("backend") and str(args["backend"]).to_lower() != "csharp":
		push_warning("autoplay: --backend %s ignored; the solver is C# only." % args["backend"])
	var log_dir: String = ProjectSettings.globalize_path(args.get("log-dir", "res://logs"))
	var keys = ["days", "exec_evil", "exec_good", "kills", "lies", "nominations", "clemency", "reveals", "max_tier4", "pairs", "guards",
		"shares", "evil_shares", "approaches", "kill_on_threat", "deductions", "arguments", "matched_links", "links",
		"workshop_cases", "hub_cases"]
	keys.append_array(NEW_ACTIONS)
	keys.append_array(VoteShape.KEYS)
	var stats = {"good": 0, "evil": 0}
	var case_results: Array = []
	var scale_cases: Array = []
	for k in keys:
		stats[k] = 0
	for i in range(games):
		var seed_v = first + i
		print("SWEEP_BEGIN %d" % seed_v)
		var t0: int = Time.get_ticks_msec()
		var r = _play(seed_v, int(args.get("npcs", "7")), log_dir, args.has("echo-log"))
		if jsonl != null:
			var rec: Dictionary = SweepRecord.build(g, {"seed": seed_v, "mode": "passive" if passive else ("bot" if m4 else "bot_pre_m4"),
				"insight": insight, "sha": str(args.get("sha", "")), "dynamic": dynamic_scripts, "metrics": r["metrics"], "r": r,
				"commands": last_commands, "guard": last_guard, "stuck": r["metrics"].get("guard_exhausted", false),
				"wall_s": (Time.get_ticks_msec() - t0) / 1000.0})
			jsonl.store_line(JSON.stringify(rec))
			jsonl.flush()
		print("SWEEP_END %d" % seed_v)
		case_results.append(r["metrics"])
		scale_cases.append(r["metrics"])
		stats[r["winner"]] += 1
		for k in keys:
			stats[k] += r[k]
		print("case %d: %s wins on day %d | exec good=%d evil=%d | kills=%d | lies=%d | noms=%d | pairs=%d | legacy=%d | %s" %
			[seed_v, r["winner"], r["days"], r["exec_good"], r["exec_evil"], r["kills"], r["lies"], r["nominations"], r["pairs"], r["metrics"].get("legacy_fallbacks", 0), r["reason"]])
	if games > 1:
		var gf = float(games)
		print("\n%sSUMMARY over %d cases: good %d / evil %d (%.0f%%), avg days %.1f, wrongful executions %.2f/case, evil executed %.2f/case," %
			["PASSIVE " if passive else "", games, stats["good"], stats["evil"], 100.0 * stats["good"] / gf, stats["days"] / gf, stats["exec_good"] / gf, stats["exec_evil"] / gf])
		print("  nominations %.1f/case, trait reveals %.1f/case, NPCs reaching tier 4 %.1f/case, NPC conversations %.1f/case, lies %.1f/case, stuck games %d" %
			[stats["nominations"] / gf, stats["reveals"] / gf, stats["max_tier4"] / gf, stats["pairs"] / gf, stats["lies"] / gf, stats["guards"]])
		print("  NPC shares %.1f/case, evil intel pools %.1f/case, approaches %.1f/case" %
			[stats["shares"] / gf, stats["evil_shares"] / gf, stats["approaches"] / gf])
		print("  links %.1f/case (%.1f matched), deductions %.1f/case (workshop %.1f, hub %.1f), NPC argument evaluations %.1f/case" %
			[stats["links"] / gf, stats["matched_links"] / gf, stats["deductions"] / gf, stats["workshop_cases"] / gf, stats["hub_cases"] / gf, stats["arguments"] / gf])
	print("  vote shape: %d votes, unanimous but the nominee %d, only the nominator %d; evil nominations %d (carried %d, hanged %d), on good targets %d (carried %d, hanged %d)" %
		[stats["votes"], stats["votes_unanimous"], stats["votes_only_nominator"], stats["evil_nominations"], stats["evil_nominations_carried"], stats["evil_nominations_executed"],
		stats["evil_nominations_good_target"], stats["evil_nominations_good_target_carried"], stats["evil_nominations_good_target_executed"]])
	print("  New talk actions: " + ", ".join(PackedStringArray(NEW_ACTIONS.map(func(key): return "%s=%d" % [key, stats[key]]))))
	var summary = Metrics.aggregate(case_results)
	print("  identification: demon %d, minion %d, both %d; identified but lost %d; eligible recorded theories %d/%d" %
		[summary["demon_identified"], summary["minion_identified"], summary["both_identified"], summary["identified_but_lost"], summary["demon_recorded"], summary["complete"]])
	print("  wrongful executions %d/%d; player's stance: backed %d, opposed %d, mixed %d; good survivors in wins %s" %
		[summary["executions_good"], summary["executions_total"], summary["wrongful_backed"], summary["wrongful_opposed"], summary["wrongful_mixed"], str(summary["saved_good_surviving_average"])])
	_print_scale(scale_cases)
	if args.has("results"):
		var path = ProjectSettings.globalize_path(args["results"])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write results: " + path)
			quit(1)
			return
		file.store_string(JSON.stringify({"schema_version": 2, "mode": "passive" if passive else "active", "beliefs": "shared", "workshop_cases": not no_workshop_cases, "circumstantial_hub": not (no_workshop_cases or no_hub), "attention": "unlimited" if args.has("no-attention") else "budgeted", "seed_start": first,
			"npcs": int(args.get("npcs", "7")), "rng_note": "Same seed matches setup; player actions can change later random draws.",
			"summary": summary, "cases": case_results}, "\t"))
		file.close()
		print("  Results written: " + path)
	quit()

func _play(seed_v: int, npc_count: int, log_dir: String, echo: bool) -> Dictionary:
	g = Game.new()
	g.detailed_logging = trace_enabled
	g.log_dir = log_dir.path_join("passive" if passive else "active")
	rng.seed = seed_v * 7919
	talked = {}
	linked_pairs = {}
	blocked_cmds = {}
	probed_traces = {}
	filed_workshop_sigs = {}
	last_workshop_case_by_target = {}
	workshop_cases_filed = 0
	hub_cases_filed = 0
	analyst = Analyst.new_state(insight)
	analyst["exclusion_cards"] = m4
	_belief_key = ""
	_belief_cache = {}
	_demon_key = ""
	_demon_guess = ""
	talk_policy_used = {}
	new_talk_counts = {}
	for key in NEW_ACTIONS: new_talk_counts[key] = 0
	var case_script = ScriptBuilder.dynamic({"seed": seed_v, "name": "Sweep #%d" % seed_v}) if dynamic_scripts else null
	if force_demon != "":
		if case_script == null:
			case_script = ScriptDef.default_script()
		if not force_demon in case_script.demons:
			case_script.demons.append(force_demon)
		case_script.forced = case_script.forced.filter(func(r): return not r in case_script.demons) + [force_demon]
	_out(g.new_case(seed_v, npc_count, case_script))
	if echo:
		g.w.dlog.echo = true
	var guard = 0
	var scale_days: Array = []
	var recorded_day = -1
	while g.state != "over" and guard < 600:
		guard += 1
		if g.state == "night" and recorded_day != g.w.day:
			recorded_day = g.w.day
			scale_days.append(_scale_snapshot())
		if not passive and g.state in ["meeting", "nomination", "night"]:
			_record_theory()
		var cmd = _decide()
		if blocked_cmds.has(cmd):
			cmd = _unblocked(cmd)
		_out("\n> " + cmd)
		var action_kind = new_action_kind(g, cmd)
		var reply: String = g.command(cmd)
		if action_kind != "" and not g.last_events.any(func(e): return e.k == "error"):
			new_talk_counts[action_kind] += 1
		_out(reply)
		if "Cannot present" in reply:
			blocked_cmds[cmd] = true # never retry a blocked presentation
	last_commands = guard
	last_guard = guard
	var w = g.w
	if recorded_day != w.day:
		scale_days.append(_scale_snapshot())
	var r = {"winner": w.winner if w.winner != "" else "evil", "days": w.day, "reason": w.end_reason,
		"exec_good": 0, "exec_evil": 0, "kills": 0, "lies": 0, "nominations": 0, "clemency": 0, "reveals": 0,
		"max_tier4": 0, "pairs": 0, "guards": 1 if guard >= 600 else 0, "shares": 0, "evil_shares": 0, "approaches": 0, "kill_on_threat": 0, "deductions": 0, "arguments": 0, "matched_links": 0, "links": 0,
		"workshop_cases": workshop_cases_filed, "hub_cases": hub_cases_filed}
	for key in NEW_ACTIONS: r[key] = new_talk_counts[key]
	r.merge(VoteShape.build(g.w))
	for e in w.executions:
		if w.by_id[e["id"]].is_evil():
			r["exec_evil"] += 1
		else:
			r["exec_good"] += 1
	for e in w.dlog.entries:
		match e["type"]:
			"kill":
				r["kills"] += 1
			"nomination":
				r["nominations"] += 1
			"trait_reveal":
				r["reveals"] += 1
			"npc_conversation":
				r["pairs"] += 1
			"npc_share":
				r["shares"] += 1
			"evil_share":
				r["evil_shares"] += 1
			"approach":
				r["approaches"] += 1
			"deduction":
				r["deductions"] += 1
			"argument":
				r["arguments"] += 1
			"player_link":
				r["links"] += 1
				if not e["data"]["matches"].is_empty():
					r["matched_links"] += 1
			"think":
				if e["data"].get("topic", "") == "lie":
					r["lies"] += 1
	for n in w.npcs:
		if n.max_tier >= 4:
			r["max_tier4"] += 1
	if g.log_paths.is_empty():
		g.command("log")
	r["metrics"] = g.case_summary.duplicate(true) if not g.case_summary.is_empty() else Metrics.summarize(w, {}, false)
	r["metrics"]["new_talk_actions"] = new_talk_counts.duplicate()
	r["metrics"]["mode"] = "passive" if passive else "active"
	r["metrics"]["guard_exhausted"] = guard >= 600 and g.state != "over"
	r["metrics"]["beliefs"] = "shared"
	r["metrics"]["suspicion_days"] = scale_days
	r["metrics"]["votes"] = _vote_records()
	var points = {}
	for f in g.shared_fallbacks:
		points[f.point] = points.get(f.point, 0) + 1
	r["metrics"]["legacy_fallbacks"] = g.shared_fallbacks.size()
	r["metrics"]["legacy_fallback_points"] = points
	r["metrics"]["workshop_cases"] = workshop_cases_filed
	r["metrics"]["hub_cases"] = hub_cases_filed
	r["metrics"]["analyst"] = {"insight": insight, "juror_evals": analyst.get("evals", 0), "juror_ms": analyst.get("eval_ms", 0),
		"accepted": analyst.get("accepted", []).size(), "set_aside": analyst.get("rejected", {}).size(), "missed": analyst.get("missed", {}).size()}
	return r

# ---------------------------------------------------------------- suspicion scale

## One day's suspicion picture for every living good NPC (real minds only), read
## against the truth. Uses the same bounded reads the simulation acts on.
func _scale_snapshot() -> Dictionary:
	var w = g.w
	var npcs: Array = []
	for n in w.living():
		if n.is_evil():
			continue
		var others: Array = w.living().filter(func(o): return o != n)
		if others.is_empty():
			continue
		others.sort_custom(func(a, b): return Mind.susp(n, a.id) > Mind.susp(n, b.id) if Mind.susp(n, a.id) != Mind.susp(n, b.id) else a.id < b.id)
		var top = others[0]
		var good_vals: Array = others.filter(func(o): return not o.is_evil()).map(func(o): return Mind.susp(n, o.id))
		var evil: Array = []
		for i in range(others.size()):
			var o = others[i]
			if o.is_evil():
				evil.append({"id": o.id, "demon": C.is_demon(o.role), "susp": Mind.susp(n, o.id), "action": Mind.action_susp(n, o.id), "rank": i + 1})
		var top_action = 0.0
		var top_nom_score = -1.0
		for o in others:
			var act: float = Mind.action_susp(n, o.id)
			top_action = maxf(top_action, act)
			var own_clear: float = Tuning.Meeting.NOMINATION_OWN_CLEAR_RELIEF if n.cleared.has(o.id) else 0.0
			var cooloff: float = Mind.nomination_cooloff(w, n.id, o.id)
			top_nom_score = maxf(top_nom_score, act - own_clear - cooloff)
		# End-of-day score readiness, including cooloff and own-clear relief.
		# Meeting eligibility (already nominated, current block) is deliberately not replayed here.
		var thr: float = maxf(Tuning.Meeting.NOMINATION_FLOOR, Tuning.Meeting.NOMINATION_BASE - Tuning.Meeting.NOMINATION_DAY_SLOPE * w.day) - Tuning.Meeting.NOMINATION_CONFIDENCE_SCALE * (Mind.trait_of(n, "confidence") - 0.5) * 2.0 - Tuning.Meeting.NOMINATION_PARANOIA_SCALE * Mind.paranoia(w, n)
		var headroom: float = (top_nom_score - thr) if not n.silenced else -1.0
		npcs.append({"id": n.id, "top": Mind.susp(n, top.id), "top_is_evil": top.is_evil(), "top_action": top_action, "top_nom_score": maxf(0.0, top_nom_score),
			"good_mean": _mean(good_vals), "evil": evil, "nomination_threshold": thr, "nomination_headroom": headroom,
			"top3": others.slice(0, 3).map(func(o): return o.id), "top3_evil": others.slice(0, 3).filter(func(o): return o.is_evil()).size(),
			"rapport": n.trust, "credibility": n.credibility})
	# Agreement: how far the rest of the good town shares each NPC's suspects.
	for entry in npcs:
		var me = w.by_id[entry.id]
		var peers: Array = npcs.filter(func(o): return o.id != entry.id)
		var top_id: String = entry.top3[0]
		var shared_top: Array = peers.filter(func(o): return o.id != top_id).map(func(o): return Mind.susp(w.by_id[o.id], top_id))
		var overlaps: Array = peers.map(func(o): return entry.top3.filter(func(id): return id in o.top3).size())
		entry["peers_susp_of_my_top"] = _mean(shared_top)
		entry["peers_same_top"] = peers.filter(func(o): return o.top3[0] == top_id).size() / maxf(peers.size(), 1.0)
		entry["top3_overlap"] = _mean(overlaps)
	return {"day": w.day, "living": w.living().size(), "npcs": npcs}

## Every good NPC's vote evaluation (score, need) from the ordinary developer log,
## so it works with --no-trace.
func _vote_records() -> Array:
	var out: Array = []
	var current: String = ""  # votes follow their nomination entry
	for e in g.w.dlog.entries:
		if e["type"] == "nomination":
			current = e.get("target", "")
			continue
		if e["type"] != "think" or e["data"].get("topic", "") != "vote" or not e["data"].has("need"):
			continue
		var voter = g.w.by_id.get(e["actor"])
		var nominee = g.w.by_id.get(current)
		if voter == null or voter.is_evil():
			continue
		out.append({"day": e["day"], "voter": e["actor"], "nominee": current,
			"nominee_evil": nominee != null and nominee.is_evil(), "score": e["data"].get("total", 0.0),
			"need": e["data"]["need"], "yes": e["data"].get("total", 0.0) >= e["data"]["need"]})
	return out

func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var t = 0.0
	for v in values:
		t += v
	return t / values.size()

## Per-day averages over every good NPC in every case.
func _print_scale(cases: Array) -> void:
	var by_day = {}
	for c in cases:
		for d in c.get("suspicion_days", []):
			var k: int = d.day
			if not by_day.has(k):
				by_day[k] = {"n": 0, "top": 0.0, "top_evil": 0, "good": 0.0, "demon": 0.0, "demon_n": 0, "demon_first": 0, "headroom": 0, "action": 0.0,
					"peer_susp": 0.0, "same_top": 0.0, "overlap": 0.0, "top3_evil": 0.0, "demon_top3": 0}
			var b = by_day[k]
			for n in d.npcs:
				b.n += 1
				b.top += n.top
				b.action += n.top_action
				b.good += n.good_mean
				b.top_evil += 1 if n.top_is_evil else 0
				b.headroom += 1 if n.nomination_headroom >= 0.0 else 0
				b.peer_susp += n.peers_susp_of_my_top
				b.same_top += n.peers_same_top
				b.overlap += n.top3_overlap
				b.top3_evil += n.top3_evil
				for e in n.evil:
					if e.demon:
						b.demon += e.susp
						b.demon_n += 1
						b.demon_first += 1 if e.rank == 1 else 0
						b.demon_top3 += 1 if e.rank <= 3 else 0
	print("\n  SUSPICION SCALE (%s beliefs; good NPCs, end of day)" % ("shared"))
	print("  day   NPCs  top   top+crowd  mean-good  demon  demon#1  top-is-evil  score-ready")
	var days: Array = by_day.keys()
	days.sort()
	for k in days:
		var b = by_day[k]
		var n = float(maxi(b.n, 1))
		print("  %3d  %5d  %.3f  %.3f      %.3f      %.3f  %5.0f%%  %8.0f%%  %10.0f%%" % [k, b.n, b.top / n, b.action / n, b.good / n,
			b.demon / maxf(b.demon_n, 1.0), 100.0 * b.demon_first / maxf(b.demon_n, 1.0), 100.0 * b.top_evil / n, 100.0 * b.headroom / n])
	print("\n  AGREEMENT (good NPCs, end of day)")
	print("  day  peers' susp of my top  peers with same top  top-3 overlap (of 3)  evil in my top 3  demon in top 3")
	for k in days:
		var b = by_day[k]
		var n = float(maxi(b.n, 1))
		print("  %3d  %12.3f  %18.0f%%  %17.2f  %16.2f  %13.0f%%" % [k, b.peer_susp / n, 100.0 * b.same_top / n, b.overlap / n,
			b.top3_evil / n, 100.0 * b.demon_top3 / maxf(b.demon_n, 1.0)])
	var votes = {"n": 0, "score": 0.0, "need": 0.0, "yes": 0, "evil_n": 0, "evil_yes": 0, "good_n": 0, "good_yes": 0}
	for c in cases:
		for v in c.get("votes", []):
			votes.n += 1
			votes.score += v.score
			votes.need += v.need
			votes.yes += 1 if v.yes else 0
			if v.nominee_evil:
				votes.evil_n += 1
				votes.evil_yes += 1 if v.yes else 0
			else:
				votes.good_n += 1
				votes.good_yes += 1 if v.yes else 0
	if votes.n > 0:
		print("  good NPC votes: %d, mean score %.3f vs need %.3f; yes on evil nominees %d/%d, on good nominees %d/%d" %
			[votes.n, votes.score / votes.n, votes.need / votes.n, votes.evil_yes, votes.evil_n, votes.good_yes, votes.good_n])

## A safe substitute for a presentation the game already blocked.
func _unblocked(cmd: String) -> String:
	if cmd.begins_with("accuse"):
		return "accuse"
	if cmd.begins_with("press"):
		return "press skip"
	if cmd.begins_with("present") or cmd.begins_with("defend"):
		return "done" if g.town_quiet else "wait"
	return "ask today"

## Record the bot's existing heuristic ranking without consulting hidden identities.
## This adds no simulation RNG draws and doesn't alter its decisions.
func _record_theory() -> void:
	var scores = _scores()
	var candidates: Array = g.w.living()
	candidates.sort_custom(func(a, b): return scores[a.id] > scores[b.id] if scores[a.id] != scores[b.id] else a.id < b.id)
	if candidates.size() >= 2 and scores[candidates[0].id] > 0.0:
		var demon_id: String = _demon_pick(candidates.slice(0, DEMON_CANDIDATES)) if m4 else candidates[0].id
		var minion_id: String = candidates[0].id if demon_id != candidates[0].id else candidates[1].id
		g.set_guess(demon_id, "demon", 2)
		g.set_guess(minion_id, "poisoner", 1)

## M4: the likeliest Demon among the top suspects by P(evil), from the juror's P(Demon),
## so a confident Minion read isn't scored as the Demon guess. Cached per board state.
func _demon_pick(candidates: Array) -> String:
	if _demon_key == _belief_key and _demon_guess != "":
		return _demon_guess
	_demon_key = _belief_key
	_demon_guess = candidates[0].id
	var best: float = -1.0
	for n in candidates:
		var p: float = Analyst.demon_posterior(g, analyst, n.id)
		if p > best + 1e-9:
			best = p
			_demon_guess = n.id
	return _demon_guess

func _out(s: String) -> void:
	if transcript:
		print(s)

# ---------------------------------------------------------------- bot brain

## The analyst's picture: posterior P(evil) per person, from the juror's reading of the
## board (tools/analyst.gd). Recomputed only when the visible evidence changes.
func _scores() -> Dictionary:
	var w = g.w
	var key: String = "%d:%d:%d:%d:%d:%d" % [g.board.size(), g.profile_receipts.size(), w.day, w.phase, w.executions.size(), w.living().size()]
	if key != _belief_key:
		_belief_key = key
		_belief_cache = Analyst.belief(g, analyst, rng)
	var sc: Dictionary = {}
	for n in w.npcs:
		sc[n.id] = float(_belief_cache.get(n.id, 0.0))
		if not n.alive and n.death_cause == "demon":
			sc[n.id] = 0.0
	return sc

func _top_suspect():
	var sc = _scores()
	var best = null
	var best_s = -99.0
	for n in g.w.living():
		if sc[n.id] > best_s:
			best_s = sc[n.id]
			best = n
	return [best, best_s]

## Public UI knowledge only. Deterministic simple rules avoid repeated free-action loops.
static func new_talk_option(game, used: Dictionary) -> String:
	if game.state == "approach" and game.approach.get("agenda", "") == "protect":
		var kind: String = game.approach.get("what", "vigil")
		return "yes" if game.offer.is_empty() and (kind != "ward" or game.w.tools.ward > 0) else "no"
	if game.state != "talk" or game.talk_with == null: return ""
	var n = game.talk_with
	if n.silenced: return ""
	if not game.pending_request.is_empty():
		if game.pending_request.kind == "confidence": return "yes"
		var kind: String = game.pending_request.get("what", "vigil")
		return "yes" if game.offer.is_empty() and (kind != "ward" or game.w.tools.ward > 0) else "no"
	var prefix = "%s:%d:" % [n.id, game.w.day]
	if not Mind.open_grievances(n).is_empty() and not used.has(prefix + "apology"):
		used[prefix + "apology"] = true
		return "apologise 1"
	var known: bool = n.claim_public or n.max_tier >= 3
	var role: String = n.claimed_role if known else ""
	if game.offer.is_empty() and not used.has(prefix + "offer"):
		used[prefix + "offer"] = true
		return "offer ward" if game.w.tools.ward > 0 and role in C.INFO_ROLES else "offer vigil"
	if game.questions_left <= 0: return ""
	var others: Array = game.w.living().filter(func(person): return person != n)
	if others.is_empty(): return ""
	if game.questions_left <= 2 and role in ["seer", "warden", "nightwatch"] and not used.has(prefix + "gift_request"):
		used[prefix + "gift_request"] = true
		if role == "nightwatch": return "ask watch " + others[0].home_block
		return ("ask check " if role == "seer" else "ask guard ") + others[0].id
	if game.questions_left == 1 and not used.has(prefix + "person"):
		used[prefix + "person"] = true
		return "ask about " + others[0].id
	return ""

static func new_night_option(game) -> String:
	var ward: String = game.offer.get("ward", "")
	if ward != "" and game.w.tools.ward > 0 and game.w.by_id[ward].alive: return "ward " + ward
	for id in game.offer.get("vigil", {}):
		if game.w.by_id[id].alive: return "vigil " + game.offer.vigil[id]
	return ""

static func new_action_kind(game, command: String) -> String:
	if command == "offer ward": return "offer_ward"
	if command == "offer vigil": return "offer_vigil"
	if command.begins_with("apologise "): return "apologise"
	for verb in ["check", "guard", "watch"]:
		if command.begins_with("ask " + verb + " "): return "request_" + verb
	if command.begins_with("ask about ") and game.find_npc(command.trim_prefix("ask about "), true) != null: return "ask_person"
	if command in ["yes", "no", "accept", "decline"]:
		if game.state == "approach" and game.approach.get("agenda") == "protect": return "answer_protection"
		if game.state == "talk" and not game.pending_request.is_empty():
			return "answer_confidence" if game.pending_request.kind == "confidence" else "answer_protection"
	if game.state == "night":
		if command == "ward " + str(game.offer.get("ward", "")): return "keep_ward"
		if command.begins_with("vigil ") and command.trim_prefix("vigil ") in game.offer.get("vigil", {}).values(): return "keep_vigil"
	return ""

func _decide() -> String:
	var w = g.w
	if passive:
		match g.state:
			"approach":
				return "decline"
			"day":
				return "wait"
			"talk":
				return "bye"
			"meeting":
				return "done" if g.town_quiet else "wait"
			"nomination":
				return "vote no"
			"night":
				return "sleep"
		return "look"
	var new_option = new_talk_option(g, talk_policy_used)
	if new_option != "": return new_option
	match g.state:
		"approach":
			return "accept" if rng.randf() < 0.7 else "decline"
		"day":
			if not g.moved:
				return "go " + _pick_location()
			var here: Array = w.npcs_at(g.loc)
			if w.scenes.has(g.loc) and not w.scenes[g.loc]["searched"]:
				return "search"
			var fresh: Array = here.filter(func(n): return n.busy_with == "" and not n.silenced and talked.get(n.id, -1) != w.day)
			if fresh.is_empty() and not g.free_move_used:
				for l in w.locations_on(w.loc_block(g.loc)):
					if l != g.loc and not w.npcs_at(l).filter(func(n): return n.busy_with == "").is_empty():
						return "go " + l
			if w.phase == C.EVENING and g.loc == "tavern" and rng.randf() < 0.4:
				return "gossip"
			if not fresh.is_empty():
				var n = fresh[rng.randi_range(0, fresh.size() - 1)]
				talked[n.id] = w.day
				return "talk " + n.id
			if w.phase == C.EVENING and g.loc == "tavern":
				return "gossip"
			if rng.randf() < 0.5:
				return "search"
			return "wait"
		"talk":
			var n = g.talk_with
			if n.silenced:
				return "bye"
			var asked: int = 3 - g.questions_left
			if asked == 0:
				return "ask gift"
			if asked == 1:
				# The talk menu asks about one stretch of time: last night, today, or yesterday.
				return "ask night" if rng.randf() < 0.5 else ("ask seen yesterday" if w.day > 1 and rng.randf() < 0.5 else "ask today")
			if asked == 2:
				var tr_num: int = BotWorkshop.unprobed_trace_for(g, n.id, probed_traces)
				if tr_num > 0 and rng.randf() < 0.45:
					probed_traces["%s:%d" % [n.id, tr_num]] = true
					return "present %d" % tr_num
				if rng.randf() < 0.5:
					var dd = _latest_deduction()
					if dd > 0:
						return "convince %d" % dd
			var ts = _top_suspect()
			if ts[0] != null and ts[1] >= TELL_P and ts[0] != n:
				# Tell them the latest card that points at the top suspect.
				var best_c = 0
				for c in g.board:
					if ts[0].id in c.get("subject", []) and c.get("source", "") != ts[0].id and not (c["kind"] in ["vote", "secret", "deduction", "conversation", "home", "haunt"]) and g._presentation_rejection(c) == "":
						if Mind.card_implicates(w, c, ts[0].id):
							best_c = c["n"]
				if best_c > 0:
					return "tell %s %d" % [ts[0].id, best_c]
			if rng.randf() < 0.25:
				return "ask about " + C.role_name(C.GOOD_ROLES[rng.randi_range(0, C.GOOD_ROLES.size() - 1)]).to_lower()
			var others: Array = w.living().filter(func(m): return m != n)
			return "ask about " + others[rng.randi_range(0, others.size() - 1)].id
		"meeting":
			if not g.presented_today:
				var ded = _find_or_file_deduction()
				if ded > 0:
					return "present %d" % ded
			var ts = _top_suspect()
			var nominate_p: float = M4_NOMINATE_P if m4 else NOMINATE_P
			if ts[0] != null and ts[1] >= nominate_p and w.day >= 2 and w.can_nominate("player", ts[0].id) == "":
				var blk: String = w.meeting["block"]
				# M4: back the one already on the block unless this is clearly stronger.
				if blk != ts[0].id and (not m4 or blk == "" or ts[1] > _scores().get(blk, 0.0) + M4_BLOCK_MARGIN):
					return "nominate " + ts[0].id
			return "done" if g.town_quiet else "wait"
		"nomination":
			var sc = _scores()
			var nm: Dictionary = w.meeting["pending"]
			var s: float = sc.get(nm["nominee"], 0.0)
			if m4 and nm.get("press", "") == "open":
				return _press_choice(nm, s)
			if not g.statement_used and nm["by"] != "player":
				var best_card = 0
				for c in g.board:
					# Only cards the game will accept as evidence (not deprecated, superseded or
					# rumour); citing a rejected one repeats forever and the game never ends.
					if nm["nominee"] in c.get("subject", []) and c.get("source", "") != nm["nominee"] and c["kind"] in ["info", "sighting", "trace"] and g._presentation_rejection(c) == "":
						best_card = c["n"]
				if s <= DEFEND_P:
					return "defend"
				if s >= ACCUSE_P:
					return "accuse %d" % best_card if best_card > 0 else "accuse"
			if w.tools["clemency"] > 0 and nm["by"] != "player" and s <= CLEMENCY_P and rng.randf() < 0.5:
				return "clemency"
			return "vote yes" if s >= VOTE_P else "vote no"
		"night":
			var promised = new_night_option(g)
			if promised != "": return promised
			var sc = _scores()
			if w.tools["ward"] > 0 and w.day >= 2 and rng.randf() < 0.5:
				var cands: Array = w.living().filter(func(n): return n.claim_public and n.claimed_role in C.INFO_ROLES)
				if not cands.is_empty():
					cands.sort_custom(func(a, b): return sc[a.id] < sc[b.id])
					return "ward " + cands[0].id
			if m4:
				var blk: String = _vigil_block(sc)
				if blk != "":
					return "vigil " + blk
			var ts = _top_suspect()
			if ts[0] != null:
				return "vigil " + ts[0].home_block
			return "sleep"
	return "look"

## M4, the podium press: a card about the nominee (a sighting or trace) if it holds one,
## else their gift (or, once claimed, readings they haven't shared), else last night. Skip a nominee it doesn't
## suspect (unless it nominated them).
func _press_choice(nm: Dictionary, s: float) -> String:
	var t = g.w.by_id[nm["nominee"]]
	if nm["by"] != "player" and s < PRESS_INTEREST_P:
		return "press skip"
	for i in range(g.board.size() - 1, -1, -1):
		var c: Dictionary = g.board[i]
		if c["kind"] in ["sighting", "trace"] and t.id in c.get("subject", []) and c.get("source", "") != t.id \
				and g._presentation_rejection(c) == "" and MindPodium.card_fits(g.w, t, c):
			return "press card %d" % c["n"]
	var opts: Dictionary = MindPodium.options(g.w, t)
	if opts.get("gift", "") != "":
		return "press role"
	if (g.w.day - 1) in opts.get("nights", []):
		return "press night %d" % (g.w.day - 1)
	return "press skip"

## M4: keep the vigil where the Demon is likeliest to strike: the home of a trusted
## high-value gift (an information gift, the Warden, the Veteran). A watch there sees the
## killer arrive. Avoid the home block of a suspected walker claimant, so the vigil also
## tests the claim (an empty vigil is soft evidence against a claimed walker who should have
## passed: Tuning.Workshop.VIGIL_MISS). Returns "" when no trusted high-value claim is known.
func _vigil_block(sc: Dictionary) -> String:
	var living: Array = g.w.living()
	var targets: Array = living.filter(func(n): return n.claim_public and (n.claimed_role in C.INFO_ROLES or n.claimed_role in HIGH_VALUE_GIFTS) and sc.get(n.id, 0.0) < VIGIL_SAFE_P)
	if targets.is_empty():
		return ""
	targets.sort_custom(func(a, b): return sc[a.id] < sc[b.id] if not is_equal_approx(sc[a.id], sc[b.id]) else a.id < b.id)
	var avoid: Dictionary = {}
	for n in living:
		if n.claim_public and n.claimed_role in WALK_CLAIMS and sc.get(n.id, 0.0) >= VIGIL_SAFE_P:
			avoid[n.home_block] = true
	for n in targets:
		if not avoid.has(n.home_block):
			return n.home_block
	return targets[0].home_block

func _pick_location() -> String:
	var w = g.w
	for sid in w.scenes:
		if not w.scenes[sid]["searched"] and w.phase == C.MORNING:
			return sid
	if w.phase == C.EVENING and rng.randf() < 0.5:
		return "tavern"
	var best = "tavern"
	var best_n = -1.0
	for l in C.LOCATIONS:
		# Free people it can see there, plus the "someone's there" count for those it can't.
		var n: float = w.npcs_at(l).filter(func(m): return m.busy_with == "" and g.can_see(m) and talked.get(m.id, -1) != w.day).size() + 0.8 * g.unseen_at(l)
		if n > best_n:
			best_n = n
			best = l
	return best

static func _parse(argv: PackedStringArray) -> Dictionary:
	var out = {}
	var i = 0
	while i < argv.size():
		var a = argv[i]
		if a.begins_with("--"):
			var k = a.substr(2)
			if i + 1 < argv.size() and not argv[i + 1].begins_with("--"):
				out[k] = argv[i + 1]
				i += 1
			else:
				out[k] = "true"
		i += 1
	return out

## Build a Workshop case against the analyst's top suspects (the top two, if the first
## won't hold) and return its card number; else the latest filed case, or 0.
func _find_or_file_deduction() -> int:
	if no_workshop_cases:
		return _latest_deduction()
	var sc = _scores()
	var ranked: Array = g.w.living().filter(func(n): return sc.get(n.id, 0.0) >= CASE_P)
	ranked.sort_custom(func(a, b): return sc[a.id] > sc[b.id] if not is_equal_approx(sc[a.id], sc[b.id]) else a.id < b.id)
	for target in ranked.slice(0, 2):
		var built: Dictionary = Analyst.build_case(g, analyst, target.id, sc, not no_hub, filed_workshop_sigs, last_workshop_case_by_target)
		if int(built.get("card", 0)) > 0:
			workshop_cases_filed += 1
			if built.get("used_hub", false):
				hub_cases_filed += 1
			return int(built.card)
	return _latest_deduction()

func _latest_deduction() -> int:
	for i in range(g.board.size() - 1, -1, -1):
		if g.board[i]["kind"] == "deduction" and g._presentation_rejection(g.board[i]) == "":
			return g.board[i]["n"]
	return 0
