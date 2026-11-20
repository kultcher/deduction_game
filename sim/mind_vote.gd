## Voting: how each NPC weighs a nomination, the dry run, and the lines that explain a no
## (split from `sim/mind_meeting.gd`).
extends "res://sim/mind_meeting_base.gd"


## One NPC's vote on a nomination. statement is always "" since Speak against / in defence
## was replaced by presenting a case (Michael, option (b), Nov 19): a case moves a voter through
## what it believes, not through a free nudge on the vote. Kept as a parameter for the callers.
static func vote(w, v, nominee: String, nominator: String, player_yes: bool, statement: String, yes_so_far: int) -> bool:
	var id = w.dlog.decision(v.id, "vote", "start", null, {"nominator": nominator,
		"player_yes": player_yes, "statement": statement, "yes_so_far": yes_so_far,
		"route": "self" if v.id == nominee else "evil_strategy" if v.is_evil() else "good_threshold"}, nominee)
	var result = _vote_impl(w, v, nominee, nominator, player_yes, statement, yes_so_far, id)
	w.dlog.decision(v.id, "vote", "outcome", result, {}, nominee, id)
	return result

static func _vote_impl(w, v, nominee: String, nominator: String, player_yes: bool, statement: String, yes_so_far: int, trace_id: int) -> bool:
	if v.id == nominee:
		w.dlog.think(v.id, "vote", "Votes no on own execution.", {"nominee": nominee, "yes": false})
		return false
	if v.is_evil():
		var scion_safe: bool = Evil.scion_fallback_active(w)
		if C.is_demon(w.by_id[nominee].role) and not scion_safe:
			w.dlog.think(v.id, "team_survival", "Votes no on the Demon: later voters can make even an early vote decisive.")
			return false
		if v.id == nominator and not Evil.is_teammate(w, v, nominee):
			w.dlog.think(v.id, "vote", "YES on %s. Follows through on own nomination." % nominee, {"evil": true})
			return true
		var evil_yes: bool = Evil.evil_vote(w, v, nominee, yes_so_far, player_yes)
		if not C.SHADOW_SELF:
			return evil_yes
		var have = yes_so_far + (1 if player_yes else 0)
		var order: Array = w.vote_order(nominee)
		var my_idx: int = order.find(v.id)
		var expected_later: int = 0
		var remaining_possible: int = 0
		if my_idx >= 0:
			for k_idx in range(my_idx + 1, order.size()):
				var rem_id: String = order[k_idx]
				if rem_id == nominee:
					continue
				remaining_possible += 1
				if rem_id == "player" or not w.by_id.has(rem_id):
					continue
				var rem_n = w.by_id[rem_id]
				if rem_n.is_evil() and evil_yes:
					expected_later += 1
				elif w.stances.get(rem_id, {}).get("target", "") == nominee and int(w.stances.get(rem_id, {}).get("day", -1)) == w.day:
					expected_later += 1
		var target_votes: int = maxi(w.vote_threshold(), int(w.meeting.get("block_count", 0)))
		var cur_block: String = w.meeting.get("block", "")
		var demon_on_block: bool = cur_block != "" and cur_block == w.demon_id
		if v.id == w.demon_id and demon_on_block and not scion_safe and evil_yes and not Evil.is_teammate(w, v, nominee) and have + 1 + remaining_possible >= target_votes:
			w.dlog.think(v.id, "team_survival", "Demon on the block backs counter-nominee %s: survival overrides cover." % nominee)
			return true
		# Shadow self (step 2): vote as their good self would, unless breaking cover is worth it.
		var sh_yes = shadow_eval(w, v, func(sh): return vote(w, sh, nominee, nominator, player_yes, statement, yes_so_far))
		if sh_yes == null or sh_yes == evil_yes:
			return evil_yes
		if Evil.martyr_bluff_chosen(v) == nominee:
			# A Martyr bluff votes on its own "chosen" as its good self would, a real Martyr's
			# reluctance included (Michael, Nov 21): pushing that hanging would be a tell.
			w.dlog.think(v.id, "team_strategy", "Martyr bluff: votes on %s, its 'chosen', as a real Martyr would." % nominee)
			return sh_yes
		var projected: int = have + 1 + expected_later
		var pivot = 1.0 if (absi(have + 1 - target_votes) <= 1 or (projected >= target_votes - 1 and have + 1 <= target_votes + 1)) else 0.45
		var landslide: bool = have >= target_votes or projected >= target_votes + 2
		var mate_on_block: bool = cur_block != "" and w.by_id.has(cur_block) and w.by_id[cur_block].is_evil()
		var rescue: float = 0.0
		if demon_on_block:
			rescue = (Tuning.Meeting.EVIL_VOTE_RESCUE_MINION * (0.5 if v.role == "scion" else 1.0)) if scion_safe else Tuning.Meeting.EVIL_VOTE_RESCUE_DEMON
		elif mate_on_block:
			rescue = Tuning.Meeting.EVIL_VOTE_RESCUE_MINION
		var stakes = 0.3
		if Evil.is_teammate(w, v, nominee) or C.is_demon(w.by_id[nominee].role):
			if not evil_yes:
				var mate_pivot: float = 1.0 if pivot >= 1.0 else (Tuning.Meeting.EVIL_VOTE_LANDSLIDE_PIVOT if landslide else Tuning.Meeting.EVIL_VOTE_NONPIVOTAL_TEAMMATE)
				stakes = Evil.teammate_value(w, nominee) * mate_pivot
				if scion_safe and C.is_demon(w.by_id[nominee].role) and v.role == "scion":
					stakes *= Tuning.Meeting.EVIL_VOTE_SCION_COVER_MULT
			else:
				stakes = 0.75
		elif evil_yes:
			stakes = (0.55 + (0.30 if nominee == w.evil_plan.get("scapegoat", "") else 0.0)) * pivot + rescue
		var detail = "%s on %s (good self: %s)" % ["YES" if evil_yes else "no", nominee, "yes" if sh_yes else "no"]
		return evil_yes if evil_override(w, v, "vote", stakes, 0.6, detail) else sh_yes
	reconsider(w, v, "thinking it over before the vote")
	var base = action_susp(v, nominee)
	var v_resent: float = _mind().resentment_toward(w, v, nominee)
	var s = base
	var parts = {"suspicion": snappedf(susp(v, nominee), 0.01), "town_pressure": base - execution_priority_contribution(v, nominee) - susp(v, nominee)}
	if C.SHARED_EXECUTION_PRIORITY_WEIGHT != 0.0:
		parts["shared_execution_priority"] = execution_priority_contribution(v, nominee)
	if v_resent > 0.0:
		parts["resentment"] = v_resent
	if player_yes:
		parts["player_votes_yes"] = Tuning.Meeting.PLAYER_VOTE_YES_SLOPE * v.credibility + Tuning.Meeting.PLAYER_VOTE_YES_OFFSET
	elif w.meeting.get("player_votes_no", false):
		# The player's no, mirrored at about two-thirds of the yes (Michael, Nov 19). Only a
		# real vote sets it, so would_vote and other dry runs stay neutral.
		parts["player_votes_no"] = -(Tuning.Meeting.PLAYER_VOTE_NO_SLOPE * v.credibility + Tuning.Meeting.PLAYER_VOTE_NO_OFFSET)
	if nominator != "player" and susp(v, nominator) > Tuning.Meeting.VOTE_DISTRUST_NOMINATOR_MIN_SUSP:
		parts["distrusts_nominator"] = Tuning.Meeting.VOTE_DISTRUST_NOMINATOR_OFFSET
	var block: String = w.meeting["block"]
	if block != "" and block != nominee and (action_susp(v, block) + _mind().resentment_toward(w, v, block)) >= (base + v_resent):
		parts["prefers_block"] = Tuning.Meeting.VOTE_PREFERS_BLOCK_OFFSET
	C.role_def(v.role).score_vote_reluctance(w, v, nominee, base, paranoia(w, v), parts)
	for k in parts:
		if k not in ["suspicion", "town_pressure", "shared_execution_priority"]:
			s += parts[k]
	var conf_need: float = -Tuning.Meeting.VOTE_CONFIDENCE_SCALE * (trait_of(v, "confidence") - 0.5) * 2.0
	var early_need: float = Tuning.Meeting.VOTE_DAY1_PENALTY if w.day <= 1 else 0.0
	var para_need: float = -Tuning.Meeting.VOTE_PARANOIA_WEIGHT * paranoia(w, v)
	var urg_need: float = -Tuning.Meeting.VOTE_URGENCY_PER_DEATH * w.npcs.filter(func(m): return not m.alive).size()
	var need: float = Tuning.Meeting.VOTE_BASE_NEED + conf_need + early_need + para_need + urg_need
	if v.id == nominator and (block == "" or block == nominee or action_susp(v, nominee) > action_susp(v, block)) and s < need:
		var commit_gap: float = (need - s) + Tuning.Meeting.VOTE_SELF_NOMINATION_MARGIN
		parts["self_nomination"] = commit_gap
		s += commit_gap
	var yes = s >= need
	var exact_parts: Dictionary = parts.duplicate()
	exact_parts["suspicion"] = susp(v, nominee) # pressure is reported separately
	w.dlog.decision(v.id, "vote", "evaluation", yes, {"parts": exact_parts,
		"score": s, "threshold": need, "comparison": ">=", "margin": s - need,
		"inputs": {"confidence": trait_of(v, "confidence"), "composure": trait_of(v, "composure"),
			"paranoia": paranoia(w, v), "trust": v.trust, "credibility": v.credibility, "trust_in_nominee": v.npc_trust.get(nominee, 0.5), "suspicion": susp(v, nominee)},
		"threshold_parts": {"base": Tuning.Meeting.VOTE_BASE_NEED,
			"confidence": conf_need, "early_day": early_need, "paranoia": para_need, "urgency": urg_need},
		"trust": v.trust, "block": block,
		"shared_execution_priority": execution_priority(v, nominee), "shared_execution_weight": C.SHARED_EXECUTION_PRIORITY_WEIGHT,
		"reluctance_rounding": "martyr contribution retains existing two-decimal rounding"}, nominee, trace_id)
	parts["total"] = snappedf(s, 0.01)
	parts["need"] = snappedf(need, 0.01)
	w.dlog.think(v.id, "vote", "%s on %s (score %.2f vs %.2f)." % ["YES" if yes else "no", nominee, s, need], parts)
	# The parts behind the vote, for the resistance lines (M2d). An evil voter's are its
	# good self's: the shadow runs this same path under the same id.
	if w.meeting.has("vote_parts"):
		w.meeting["vote_parts"][v.id] = {"parts": exact_parts, "margin": s - need, "yes": yes}
	return yes

## Measurement only (Michael, Nov 19: how a case moves votes; Quill's case slate): how the
## good townsfolk would vote on `nominee` if it were nominated now, by `nominator` ("" for a
## neutral nominator), with the player's vote and statement left out. Each good, living voter
## other than the nominee runs the real vote (`_vote_impl`), including its reconsideration, so
## its beliefs refresh as at a real meeting. Nothing else is left behind: no random draw, no
## log entry (nor detailed trace event, nor live-feed record), and the meeting state as it was. Evil voters are left out.
## Returns {yes: [ids], no: [ids], voters, threshold, crosses}. `voters` and `threshold` are
## the real meeting's (World.vote_threshold, the player counted among the voters); `crosses`
## is whether the good yes votes alone reach it.
static func would_vote(w, nominee: String, nominator: String = "") -> Dictionary:
	var rng_state = w.rng.state
	var meeting_was: Dictionary = w.meeting.duplicate(true)
	var log_size: int = w.dlog.entries.size()
	var log_seq = w.dlog._seq
	# The detailed trace and the live decision feed don't take these votes either (Codex on #347).
	var was_detailed: bool = w.dlog.detailed
	var was_feed = w.dlog.live_feed
	var was_echo: bool = w.dlog.echo
	w.dlog.detailed = false
	w.dlog.live_feed = null
	w.dlog.echo = false
	if not w.meeting.has("block"):
		w.meeting["block"] = ""
	var yes: Array = []
	var no: Array = []
	for v in w.living():
		if v.id == nominee or v.is_evil():
			continue
		if _vote_impl(w, v, nominee, nominator, false, "", 0, 0):
			yes.append(v.id)
		else:
			no.append(v.id)
	w.rng.state = rng_state
	w.meeting = meeting_was
	w.dlog.entries.resize(log_size)
	w.dlog._seq = log_seq
	w.dlog.detailed = was_detailed
	w.dlog.live_feed = was_feed
	w.dlog.echo = was_echo
	var threshold: int = w.vote_threshold()
	return {"yes": yes, "no": no, "voters": w.voter_count(), "threshold": threshold, "crosses": yes.size() >= threshold}

## Whether a case catches `target` in a home lie: among `ids`, their own "I was home"
## for a night and something that puts them out that night (a sighting, a Night Watch
## report, their own walking gift's reading). The judge's own dispute rule
## (`CaseGraph.valid_dispute`). Lie severity (BACKLOG, Michael Nov 17): since #210 the
## judge reads that as evidence, not proof, so a listener can accept it and still not hang.
static func catches_home_lie(view: Dictionary, ids: Array, target: String) -> bool:
	if target == "":
		return false
	for aid in ids:
		var alibi: Dictionary = CaseGraph.find_card(view, aid)
		if alibi.is_empty() or str(alibi.get("kind", "")) != "alibi" or str(alibi.get("subject", "")) != target:
			continue
		for oid in ids:
			if oid == aid:
				continue
			if CaseGraph.valid_dispute(view, {"reports": [aid, oid], "challenged": aid, "preferred": oid}):
				return true
	return false

## Step 6 (meeting plan M2d): after the tally, at most MAX_VOTE_RESISTANCE_SPEAKERS voters
## say why they voted as they did. First, anyone who accepted the Demonologist's public case
## against the nominee today (or granted that it caught them in a home lie) and still voted
## no, voicing the vote part that held them back;
## failing that, on a count within one of what was needed, the voter who swung it. An evil
## voter speaks from its good self's parts (the shadow's), never from the override.
static func vote_resistance_lines(w, res: Dictionary) -> Array:
	var out: Array = []
	var nominee: String = str(res.get("nominee", ""))
	if not w.by_id.has(nominee):
		return out
	var t = w.by_id[nominee]
	var parts_map: Dictionary = res.get("voter_parts", {})
	var picked: Array = []
	for vid in res.get("no", []):
		if picked.size() >= Tuning.Meeting.MAX_VOTE_RESISTANCE_SPEAKERS:
			break
		if vid == nominee or not w.by_id.has(vid):
			continue
		var v = w.by_id[vid]
		if v.silenced or not v.alive:
			continue
		var acc: Dictionary = v.dialogue_memory.get("accepted_cases", {}).get(nominee, {})
		var accepted: bool = not acc.is_empty() and int(acc.get("day", -1)) == w.day
		var mind = v.shadow if v.is_evil() and v.shadow != null else v
		if accepted and mind.workshop_state.get("withdrawn", {}).has(str(acc.get("key", ""))):
			accepted = false
		# Granted today that the nominee lied about being home (lie severity, the vote side).
		var grant: Dictionary = v.dialogue_memory.get("granted_lies", {}).get(nominee, {})
		var lie: bool = int(grant.get("day", -1)) == w.day and not mind.workshop_state.get("withdrawn", {}).has(str(grant.get("key", "")))
		var agree: Dictionary = load("res://sim/social.gd").readings_agree_record(v, nominee)
		if not accepted and not lie and agree.is_empty():
			continue
		var key: String = _resistance_key(w, v, parts_map.get(vid, {}), res, lie) if (accepted or lie) else ""
		# Their readings confirm what I know (Michael, Nov 19): the reason, ahead of the
		# generic ones; a card for the player (res.resistance_facts).
		if not agree.is_empty() and key in ["", "vote_no_reluctant", "vote_no_short_of_rope"]:
			key = "vote_resist_readings_agree"
			var rf: Array = res.get("resistance_facts", [])
			rf.append(load("res://sim/social.gd").readings_agree_fact(v, t, agree))
			res["resistance_facts"] = rf
		if key == "":
			continue
		out.append(_resistance_line(w, v, t, key, res))
		picked.append(vid)
	if picked.is_empty():
		var needed: int = maxi(int(res.get("threshold", 0)), int(res.get("prev_block_count", 0)) + 1)
		if absi(int(res.get("count", 0)) - needed) <= 1:
			var swing = _swing_voter(w, res, parts_map, picked)
			if swing != null:
				var sv = swing[0]
				var skey: String = swing[1]
				if skey == "yes":
					var why: String = _meeting().citable_reason(w, sv, nominee)
					if why != "":
						out.append(say_voiced(sv, "vote_yes_swing", "I voted to hang %s: %s." % [t.name, why], {"nominee": t.name, "reason": why}))
				else:
					out.append(_resistance_line(w, sv, t, skey, res))
	return out


## Which reason a no-voter gives, from the parts their vote actually had.
static func _resistance_key(w, v, vp: Dictionary, res: Dictionary, granted_lie: bool = false) -> String:
	var parts: Dictionary = vp.get("parts", {})
	if v.is_evil() and bool(vp.get("yes", false)):
		# Their good self would have voted yes: the no came from cover-breaking, which is
		# never voiced. Say what any reluctant townsperson would.
		return "vote_no_prefers_block" if str(res.get("prev_block", "")) not in ["", res.get("nominee", "")] else "vote_no_short_of_rope"
	if vp.is_empty():
		return "" # no record of how they weighed it (an evil voter's team rule, say)
	if float(parts.get("prefers_block", 0.0)) < 0.0 and str(res.get("prev_block", "")) not in ["", res.get("nominee", "")]:
		return "vote_no_prefers_block"
	# They granted a case that caught the nominee in a home lie, and still voted no: they
	# believe the lie and say it isn't enough to hang (lie severity, the vote side).
	if granted_lie:
		return "vote_no_lie_not_rope"
	var known: Array = ["suspicion", "town_pressure", "shared_execution_priority", "resentment", "player_votes_yes",
		"player_votes_no", "distrusts_nominator", "prefers_block", "self_nomination"]
	if parts.keys().any(func(k): return k not in known and float(parts[k]) < 0.0):
		return "vote_no_reluctant"
	if float(parts.get("distrusts_nominator", 0.0)) < 0.0 and str(res.get("by", "")) != "player":
		return "vote_no_distrust_nominator"
	if float(vp.get("margin", -99.0)) > -Tuning.Meeting.VOTE_RESISTANCE_CLOSE_MARGIN:
		return "vote_no_short_of_rope"
	return ""


static func _resistance_line(w, v, t, key: String, res: Dictionary) -> Dictionary:
	var block_id: String = str(res.get("prev_block", ""))
	var block_name: String = w.by_id[block_id].name if w.by_id.has(block_id) else ""
	var nom_id: String = str(res.get("by", ""))
	var nom_name: String = "the Demonologist" if nom_id == "player" else (w.by_id[nom_id].name if w.by_id.has(nom_id) else "")
	match key:
		"vote_resist_readings_agree":
			return say_voiced(v, key, "I won't hang %s: their readings agree with what I know." % t.name, {"nominee": t.name})
		"vote_no_prefers_block":
			return say_voiced(v, key, "I take your point about %s, truly, but %s is already on the block and I'd sooner hang %s tonight." % [t.name, block_name, block_name],
				{"nominee": t.name, "block": block_name})
		"vote_no_reluctant":
			return say_voiced(v, key, "Even with what you laid out, I'm not ready to put a rope on %s tonight." % t.name, {"nominee": t.name})
		"vote_no_lie_not_rope":
			return say_voiced(v, key, "I'll grant %s lied about where they were that night. But there's many a reason to be abroad at night that isn't the Demon's work, and I won't hang them for it." % t.name,
				{"nominee": t.name})
		"vote_no_distrust_nominator":
			return say_voiced(v, key, "The case against %s troubles me, yes, though I don't trust %s's hand in pushing it." % [t.name, nom_name],
				{"nominee": t.name, "nominator": nom_name})
	if nom_id != "player":
		# Not the Demonologist's nomination: don't hand them a case they never made.
		return say_voiced(v, "vote_no_short_of_rope_town", "There's something in what %s says about %s, but not enough to hang them today." % [nom_name if nom_name != "" else "the accuser", t.name],
			{"nominee": t.name, "nominator": nom_name})
	return say_voiced(v, "vote_no_short_of_rope", "Your case against %s has merit, Demonologist, just not enough to hang them today." % t.name, {"nominee": t.name})


## The voter who swung a close count: on a narrow block or tie, the yes-voter nearest the
## line; on a one-vote miss, the no-voter the Demonologist has the most rapport with.
## Returns [voter, key] (key "yes", or a resistance key), or null.
static func _swing_voter(w, res: Dictionary, parts_map: Dictionary, skip: Array):
	var outcome: String = str(res.get("outcome", ""))
	var best = null
	var best_score: float = 1e9
	if outcome in ["on_block", "tie"]:
		for vid in res.get("yes", []):
			if vid in skip or vid == res.get("by", "") or not w.by_id.has(vid) or not parts_map.has(vid):
				continue
			var v = w.by_id[vid]
			if v.silenced:
				continue
			var m: float = absf(float(parts_map[vid].get("margin", 0.0)))
			if m < best_score:
				best_score = m
				best = [v, "yes"]
		return best
	for vid in res.get("no", []):
		if vid in skip or vid == res.get("nominee", "") or not w.by_id.has(vid) or not parts_map.has(vid):
			continue
		var v = w.by_id[vid]
		if v.silenced:
			continue
		var key: String = _resistance_key(w, v, parts_map[vid], res)
		if key == "":
			continue
		var score: float = -float(v.trust)
		if score < best_score:
			best_score = score
			best = [v, key]
	return best
