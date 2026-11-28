## One finished autoplay game as a flat `sweep_v1` record for the balance sweep
## (tools/autoplay.gd --results-jsonl, docs/balance_sweep.md). Reads finished state
## only: no RNG draws, no decisions, nothing written back to the game.
extends RefCounted

const C = preload("res://sim/content.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const VoteShape = preload("res://tools/vote_shape.gd")
const BreathStats = preload("res://tools/breath_stats.gd")

const SCHEMA = "sweep_v1"

static func _tags(id: String) -> Array:
	return ScriptDef.tags_of(id)

static func _walks(id: String) -> bool:
	return "night_walker" in _tags(id)

## The role someone was dealt. Only the Scion changes role (it becomes "demon").
static func start_role(w, n) -> String:
	if C.is_demon(n.role) and n.id != w.first_demon_id and n.id in w.initial_minion_ids:
		return "scion"
	return n.role

static func build(g, ctx: Dictionary) -> Dictionary:
	var w = g.w
	var summary: Dictionary = ctx.get("metrics", {})
	var r: Dictionary = ctx.get("r", {})
	var rec := {"schema": SCHEMA}
	# ---- identity
	rec["seed"] = ctx.get("seed", w.seed_value)
	rec["npcs"] = w.n_npcs
	rec["mode"] = ctx.get("mode", "")
	rec["insight"] = ctx.get("insight", 1.0)
	rec["backend"] = "csharp"
	rec["sha"] = ctx.get("sha", "")
	rec["dynamic"] = ctx.get("dynamic", false)
	var sc = w.case_script
	rec["script_fingerprint"] = sc.fingerprint() if sc != null else ""
	rec["script"] = sc.to_dict() if sc != null else {}
	# ---- deal
	var town: Array = []
	var minions: Array = []
	var demon: Array = []
	for n in w.npcs:
		if n.id == w.first_demon_id:
			demon.append(n.role)
		elif n.id in w.initial_minion_ids:
			minions.append(start_role(w, n))
	town = w.initial_good_roles.duplicate()
	town.sort()
	minions.sort()
	rec["town_roles"] = town
	rec["minion_roles"] = minions
	rec["demon_roles"] = demon
	var secret := ""
	var secret_holders: Array = []
	for n in w.npcs:
		if n.secret_mod != "" and not n.id in w.initial_evil_ids:
			secret = n.secret_mod
			secret_holders.append(n.id)
	rec["secret"] = secret
	rec["scion_rose"] = w.npcs.any(func(n): return start_role(w, n) == "scion" and C.is_demon(n.role))
	rec["secret_holders"] = secret_holders
	var dealt: Array = town + minions
	var walkers: int = dealt.filter(func(x): return _walks(x)).size() + 1  # the Demon walks
	rec["night_walkers_dealt"] = walkers
	rec["start_knowledge_dealt"] = town.filter(func(x): return x in C.START_ROLES).size()
	rec["identifiers_dealt"] = town.filter(func(x): return x in C.IDENTIFIER_ROLES).size()
	var guaranteed: bool = rec["start_knowledge_dealt"] >= 2 and rec["identifiers_dealt"] >= 1
	rec["deal_fallback"] = not (guaranteed and ScriptDef.deal_ok(dealt, w.n_npcs))
	# ---- outcome
	rec["winner"] = r.get("winner", w.winner)
	rec["reason"] = w.end_reason
	rec["days"] = w.day
	for k in ["exec_good", "exec_evil", "kills", "lies", "nominations", "clemency", "pairs", "shares",
			"evil_shares", "approaches", "deductions", "arguments", "workshop_cases", "hub_cases", "cross_cases",
			"declarations", "declarations_right"]:
		rec[k] = r.get(k, 0)
	# ---- from case_summary
	rec["demon_evidence_on_board"] = not summary.get("demon_evidence_on_board", []).is_empty()
	rec["demon_evidence_reachable"] = not summary.get("demon_evidence_reachable", []).is_empty()
	rec["loss_hint"] = summary.get("loss_hint", "")
	rec["outcome"] = summary.get("outcome", "")
	rec["nights"] = summary.get("nights", {})
	rec["executions"] = summary.get("executions", [])
	rec["both_identified"] = summary.get("both_identified", false)
	rec["demon_identified"] = summary.get("demon_identified", false)
	rec["identified_but_lost"] = summary.get("identified_but_lost", false)
	rec["good_initial"] = summary.get("good_initial", 0)
	rec["good_surviving"] = summary.get("good_surviving", 0)
	rec["good_survival_fraction"] = summary.get("good_survival_fraction", 0.0)
	# ---- per NPC
	var claims_by_role := {}
	var first_claim := {}
	for pc in w.public_claims:
		var who: String = str(pc.get("who", ""))
		var role: String = str(pc.get("role", ""))
		if not claims_by_role.has(role):
			claims_by_role[role] = {}
		claims_by_role[role][who] = true
		if not first_claim.has(who):
			first_claim[who] = int(pc.get("day", -1))
	var executed_ids := {}
	for ex in w.executions:
		executed_ids[ex["id"]] = int(ex.get("day", -1))
	var people: Array = []
	for n in w.npcs:
		var evil_start: bool = n.id in w.initial_evil_ids
		var bluff: String = str(w.evil_plan.get("bluffs", {}).get(n.id, "")) if evil_start else ""
		var claimed: String = n.claimed_role if n.claimed_role != "none" else ""
		var contested: bool = claimed != "" and claims_by_role.get(claimed, {}).keys().filter(func(x): return x != n.id).size() > 0
		people.append({"id": n.id, "role": start_role(w, n), "role_now": n.role, "alignment": n.alignment, "evil_at_start": evil_start,
			"turned": n.turned, "alive": n.alive, "death_day": n.death_day, "death_cause": n.death_cause,
			"claimed_role": claimed, "claim_public": n.claim_public, "public_claim_day": first_claim.get(n.id, -1),
			"bluff": bluff, "claim_contested": contested, "secret": n.secret_mod,
			"executed_while_bluffing": evil_start and executed_ids.has(n.id) and claimed != "" and claimed != n.role})
	rec["people"] = people
	# ---- pace
	var exec_good_by_day := {}
	var exec_evil_by_day := {}
	var first_evil_exec := -1
	for ex in summary.get("executions", []):
		var d := str(ex.get("day", -1))
		if str(ex.get("alignment", "good")) == "evil":
			exec_evil_by_day[d] = exec_evil_by_day.get(d, 0) + 1
			if first_evil_exec < 0 or int(ex.get("day", -1)) < first_evil_exec:
				first_evil_exec = int(ex.get("day", -1))
		else:
			exec_good_by_day[d] = exec_good_by_day.get(d, 0) + 1
	rec["exec_good_by_day"] = exec_good_by_day
	rec["exec_evil_by_day"] = exec_evil_by_day
	rec["first_evil_exec_day"] = first_evil_exec
	var meetings := 0
	var noms_by_day := {}
	var kills_by_night := {}
	var player_noms := 0
	var player_nom_targets: Array = []
	for e in w.dlog.entries:
		match e["type"]:
			"nomination":
				var d := str(e.get("day", -1))
				noms_by_day[d] = noms_by_day.get(d, 0) + 1
				if e.get("actor", "") == "player":
					player_noms += 1
					player_nom_targets.append(e.get("target", ""))
			"kill":
				var dk := str(e.get("day", -1))
				kills_by_night[dk] = kills_by_night.get(dk, 0) + 1
			"vote_tally", "no_execution", "execution":
				pass
	# A meeting happens at the end of each completed day's evening (day 1 onward).
	var meeting_days := {}
	for e in w.dlog.entries:
		if e["type"] in ["vote_tally", "no_execution", "execution"] or (e["type"] == "nomination"):
			meeting_days[str(e.get("day", -1))] = true
	meetings = meeting_days.size()
	var exec_days := {}
	for ex in w.executions:
		exec_days[str(ex.get("day", -1))] = true
	var no_exec_meetings := 0
	for d in range(1, w.day + 1):
		var reached_meeting: bool = d < w.day or meeting_days.has(str(d)) or exec_days.has(str(d))
		if reached_meeting and not exec_days.has(str(d)):
			no_exec_meetings += 1
	rec["meetings_with_activity"] = meetings
	rec["meetings_without_execution"] = no_exec_meetings
	rec["nominations_by_day"] = noms_by_day
	rec["kills_by_night"] = kills_by_night
	# ---- vote shape (belief-model guardrail; tools/vote_shape.gd)
	rec.merge(VoteShape.build(w))
	rec.merge(BreathStats.build(w))
	# ---- night-walkers
	var gw_exec := 0
	var gw_exec_secret := 0
	for ex in summary.get("executions", []):
		# A Martyr substitution keeps the saved nominee in `id`; the one who hanged is
		# `martyr_died` (the Martyr, who doesn't walk). Count whoever actually died.
		var p = w.by_id.get(ex.get("martyr_died", ex.get("id", "")))
		if p == null or p.alignment != "good":
			continue
		if _walks(p.role):
			gw_exec += 1
		elif p.secret_mod in ["lovers", "sleepwalker"]:
			gw_exec_secret += 1
	rec["good_gift_walkers_executed"] = gw_exec
	rec["good_secret_walkers_executed"] = gw_exec_secret
	# ---- information
	var impaired := 0
	var impaired_shared := 0
	var fake := 0
	for n in w.npcs:
		for en in n.info_log:
			if en.has("true") and not bool(en.get("true", true)) and not n.is_evil():
				impaired += 1
				if en.get("shared", false):
					impaired_shared += 1
	for e in w.dlog.entries:
		if e["type"] == "fake_info":
			fake += 1
	rec["impaired_readings"] = impaired
	rec["impaired_readings_shared"] = impaired_shared
	rec["fake_info"] = fake
	# ---- bot only
	var player_exec_ok := 0
	var player_exec_wrong := 0
	for ex in summary.get("executions", []):
		if ex.get("player_nominated", false):
			if str(ex.get("alignment", "")) == "evil":
				player_exec_ok += 1
			else:
				player_exec_wrong += 1
	rec["player_commands"] = ctx.get("commands", 0)
	rec["player_nominations"] = player_noms
	rec["player_nominations_executed_evil"] = player_exec_ok
	rec["player_nominations_executed_good"] = player_exec_wrong
	# ---- the Marked watch (Michael, Nov 27): burden claims, the claimers' standing, and what
	# became of an evil Marked claimer once the real holder was hanged. Reads only.
	rec.merge(_marked_watch(w, ctx.get("marked_watch_samples", [])))
	# ---- health
	rec["wall_s"] = ctx.get("wall_s", 0.0)
	rec["guard"] = ctx.get("guard", 0)
	rec["stuck"] = bool(ctx.get("stuck", false))
	rec["unprepared_refreshes"] = summary.get("unprepared_refreshes", 0)
	rec["complete"] = summary.get("complete", w.game_over)
	return rec

## Claims that answer something that named the claimer (Burdens.claim's `why`): a reading, a
## nomination, the town turning on them, or a sighting that caught them out.
const REACTIVE_WHY = ["reading", "nominated", "turning on me", "caught out", "someone else claimed"]

static func _marked_watch(w, samples: Array) -> Dictionary:
	var claims: Array = []
	var claimers: Dictionary = {}
	for e in w.dlog.entries:
		if e["type"] != "burden_claim":
			continue
		var d: Dictionary = e.get("data", {})
		var who: String = str(e.get("actor", ""))
		var why: String = str(d.get("why", ""))
		var n = w.by_id.get(who)
		claims.append({"who": who, "kind": str(d.get("kind", "")), "day": int(e.get("day", -1)), "phase": str(e.get("phase", "")),
			"public": bool(d.get("public", false)), "alignment_at_claim": "evil" if bool(d.get("evil", false)) else "good",
			"role": start_role(w, n) if n != null else "", "reactive": REACTIVE_WHY.any(func(x): return x in why), "why": why})
		claimers[who] = true
	var standing: Dictionary = {}
	for who in claimers:
		var series: Array = []
		for smp in samples:
			if smp.get("mean_evil", {}).has(who):
				series.append({"day": smp.day, "phase": smp.phase, "mean_evil": smp.mean_evil[who]})
		standing[who] = series
	var holder: String = ""
	for n in w.npcs:
		if n.secret_mod == "marked" and not n.id in w.initial_evil_ids:
			holder = n.id
	var hanged_day: int = -1
	for ex in w.executions:
		if str(ex.get("id", "")) == holder and holder != "":
			hanged_day = int(ex.get("day", -1))
	var evil_claimers: Array = []
	if hanged_day >= 0:
		var seen: Dictionary = {}
		for c in claims:
			if c.kind != "marked" or c.alignment_at_claim != "evil" or seen.has(c.who):
				continue
			seen[c.who] = true
			var n = w.by_id.get(c.who)
			var first_nom: int = -1
			for e in w.dlog.entries:
				if e["type"] == "nomination" and str(e.get("target", "")) == c.who and int(e.get("day", -1)) > hanged_day:
					first_nom = int(e.get("day", -1))
					break
			var hanged: bool = w.executions.any(func(ex): return str(ex.get("id", "")) == c.who)
			evil_claimers.append({"id": c.who, "role": start_role(w, n) if n != null else "", "demon": n != null and n.id == w.first_demon_id,
				"first_nominated_after": first_nom, "hanged": hanged, "survived": n != null and n.alive})
	return {"burden_claims": claims, "claimer_suspicion": standing,
		"after_holder": {"holder": holder, "holder_hanged_day": hanged_day, "evil_claimers": evil_claimers}}
