## The town meeting's flow, executions, the Martyr and the Scion, grief (split from
## `sim/world.gd`; part of World's inheritance chain).
extends "res://sim/world_base.gd"


# ---------------------------------------------------------------- town meeting

func begin_meeting() -> Array:
	open_meeting()
	return Mind.meeting_testimony(self)

## Everything before the testimony (begin_meeting without it), for a streamed meeting:
## then Mind.testimony_start / testimony_step.
func open_meeting() -> void:
	set_log_time()
	# A meeting is its own speaking scope for verbal tics (sim/dialogue.gd TICS).
	for n in npcs:
		Mind.Dialogue.begin_scope(n.dialogue_memory)
	# Hold belief refreshes from here until each speaker's turn (or the end of the
	# testimony): one refresh per mind instead of one now and another a moment later.
	defer_beliefs = true
	executed_today = ""
	meeting = {"block": "", "block_count": 0, "nominated": [], "nominators": [], "results": [], "pending": {}}
	meeting["accusations"] = []
	meeting["silenced"] = []
	for n in living():
		n.busy_with = ""
		if n.silence_pending == day and is_minion_suppressed():
			n.silence_pending = -1
			dlog.add("silence_suppressed", "world", n.id, {}, "The church bell holds: %s is not silenced at the meeting." % n.name)
		if n.silence_pending == day:
			n.silence_pending = -1
			n.silenced = true
			n.silence_day = day
			meeting["silenced"].append(n.id)
			public_event("silenced", [n.id], "")
			dlog.add("silenced", "world", n.id, {}, "%s cannot speak at the meeting (the Breathstealer's work)." % n.name)
			# Evil wanted them quiet: a point in their favour with everyone else.
			for real in living():
				var l = real.shadow if real.is_evil() else real
				if l != null and real != n:
					Mind.ledger_hear(self, l, "silenced:%s:%d" % [n.id, day], [], 1.0, [], {"kind": "silenced", "subject": n.id, "day": day})
	Mind.refresh_all_consensus(self)  # yesterday's accusations count for less today

func can_nominate(by: String, nominee: String) -> String:
	if not by_id.has(nominee) or not by_id[nominee].alive:
		return "They are not here."
	if nominee in meeting["nominated"]:
		return "%s has already been nominated today." % by_id[nominee].name
	if by in meeting["nominators"]:
		return "You have already nominated today." if by == "player" else "already nominated"
	return ""

## Opens a nomination. Returns the pending nomination dict.
func open_nomination(by: String, nominee: String, reason: String = "") -> Dictionary:
	meeting["nominated"].append(nominee)
	meeting["nominators"].append(by)
	var nm = {"by": by, "nominee": nominee, "statement": "", "reason": reason}
	meeting["pending"] = nm
	var target = by_id[nominee]
	public_event("nomination", [nominee], by)
	target.pressure += Tuning.Trust.NOMINATED_PRESSURE
	if by == "player":
		Mind.set_trust(self, target, target.trust - Tuning.Trust.NOMINATED_BY_PLAYER_DROP, "the Demonologist nominated me")
	else:
		target.npc_trust[by] = clampf(target.npc_trust.get(by, 0.5) - Tuning.Trust.NOMINATED_NPC_TRUST_DROP, 0.0, 1.0)
		dlog.add("npc_trust", nominee, by, {"to": target.npc_trust[by]}, "%s nominated me" % by)
		Social.backing_trust(self, nominee, by, "nominated %s, whom I suspect too" % nominee)
	dlog.add("nomination", by, nominee, {"reason": reason, "on_block": meeting["block"], "block_count": meeting["block_count"]})
	return nm

## The player intervenes with Clemency: the nomination is cancelled.
func clemency() -> void:
	var nm: Dictionary = meeting["pending"]
	var spared = by_id[nm["nominee"]]
	tools["clemency"] -= 1
	evil_plan["spared"].append(spared.id)
	dlog.add("clemency", "player", spared.id, {"nominator": nm["by"]}, "The Demonologist spares %s from this nomination." % spared.name)
	for n in living():
		if n == spared:
			Mind.set_trust(self, n, n.trust + Tuning.Trust.CLEMENCY_SPARED_BONUS, "the Demonologist spared me")
			continue
		if n.id == nm["by"]:
			var nom_drop: float = Tuning.Trust.CLEMENCY_OVERRULED_HIGH_SUSP_DROP if (not n.is_evil() and Mind.susp(n, spared.id) > Tuning.Trust.CLEMENCY_HIGH_SUSP_MIN) else Tuning.Trust.CLEMENCY_OVERRULED_DROP
			Mind.set_trust(self, n, n.trust - nom_drop, "the Demonologist overruled my nomination")
			Mind.tag_grievance(self, n, "the Demonologist overruled my nomination", {"subject": spared.id})
			continue
		if n.is_evil():
			continue
		var s = Mind.susp(n, spared.id)
		if s < Tuning.Trust.CLEMENCY_LOW_SUSP_MAX:
			Mind.set_trust(self, n, n.trust + Tuning.Trust.CLEMENCY_TRUSTED_BONUS, "the Demonologist spared %s, whom I trust" % spared.id)
		elif s > Tuning.Trust.CLEMENCY_HIGH_SUSP_MIN:
			Mind.set_trust(self, n, n.trust - Tuning.Trust.CLEMENCY_SUSPECTED_DROP, "the Demonologist spared %s, whom I suspect" % spared.id)
	meeting["pending"] = {}

## Count the votes on the pending nomination and update who is on the block.
func vote_pending(player_yes: bool) -> Dictionary:
	set_log_time()
	# Step 6 (meeting plan M2d): every reveal, press answer, supporter and player card so far
	# is in each voter's beliefs before they decide.
	Mind.flush_beliefs(self)
	var nm: Dictionary = meeting["pending"]
	var nid: String = nm["nominee"]
	var yes: Array = []
	var no: Array = []
	var prev_block: String = meeting["block"]
	var prev_block_count: int = int(meeting["block_count"])
	meeting["vote_parts"] = {}
	# The player's vote is declared up front, so a no pushes every voter (Michael, Nov 19).
	meeting["player_votes_no"] = not player_yes
	var order: Array = vote_order(nid)
	for vid in order:
		if vid == "player":
			continue  # declared up front; counted as the hand passes your seat
		var v = by_id[vid]
		if Mind.vote(self, v, nid, nm["by"], player_yes, nm["statement"], yes.size()):
			yes.append(v.id)
			public_event("vote_yes", [nid], v.id)
		else:
			no.append(v.id)
	meeting.erase("player_votes_no")
	var count = yes.size() + (1 if player_yes else 0)
	var thr = vote_threshold()
	var outcome = "fails"
	if count >= thr:
		if count > meeting["block_count"]:
			meeting["block"] = nid
			meeting["block_count"] = count
			outcome = "on_block"
		elif count == meeting["block_count"]:
			meeting["block"] = ""
			outcome = "tie"
		else:
			outcome = "short_of_block"
	var res = {"nominee": nid, "by": nm["by"], "yes": yes, "no": no, "player_yes": player_yes, "count": count,
		"threshold": thr, "order": order, "outcome": outcome, "block": meeting["block"], "block_count": meeting["block_count"],
		"prev_block": prev_block, "prev_block_count": prev_block_count, "voter_parts": meeting.get("vote_parts", {}).duplicate(true)}
	meeting.erase("vote_parts")
	meeting["results"].append(res)
	meeting["pending"] = {}
	# An aggregate process receipt is not another hostile act by the nominator.
	# Individual vote_yes records above retain their existing social meaning.
	public_event("vote", [nid], "town", {"nominee": nid, "nominator": nm["by"], "yes": yes.duplicate(), "no": no.duplicate(),
		"player_yes": player_yes, "count": count, "threshold": thr, "outcome": outcome})
	dlog.add("vote_tally", "world", nid, res)
	# The nominee remembers who voted to hang them, and who stood by them (Oct 30).
	var nominee_npc = by_id[nid]
	if nominee_npc.alive:
		for v in yes:
			if v != nid and by_id.has(v):
				nominee_npc.npc_trust[v] = clampf(nominee_npc.npc_trust.get(v, 0.5) - Tuning.Social.TRUST_VOTED_AGAINST, 0.0, 1.0)
		for v in no:
			if v != nid and by_id.has(v):
				nominee_npc.npc_trust[v] = clampf(nominee_npc.npc_trust.get(v, 0.5) + Tuning.Social.TRUST_VOTED_FOR, 0.0, 1.0)
	Social.vote_agreement_trust(self, nid, yes, no)
	if player_yes:
		var t = by_id[nid]
		if nm["by"] != "player":
			Mind.set_trust(self, t, t.trust - Tuning.Trust.VOTED_YES_ON_ME_DROP, "the Demonologist voted to hang me")
	elif nm["by"] != "player" and by_id[nid].alive:
		var t = by_id[nid]
		Mind.set_trust(self, t, t.trust + Tuning.Trust.VOTED_NO_ON_ME_RISE, "the Demonologist voted to spare me")
	return res

## Close the meeting: whoever is on the block is executed.
func end_meeting(last_words: Callable = Callable()) -> String:
	if meeting.get("closed", false): return ""
	meeting["closed"] = true
	set_log_time()
	public_event("meeting", [], "town")
	var b: String = meeting["block"]
	if b == "":
		dlog.add("no_execution", "world", "", {}, "Nobody is on the block when the meeting closes.")
		return ""
	var res = {}
	for r in meeting["results"]:
		if r["nominee"] == b:
			res = r
	execute(b, res, last_words)
	return b

func execute(id: String, res: Dictionary, last_words: Callable = Callable()) -> void:
	var n = by_id[id]
	if not n.alive: return
	var alive_before = living().size()
	# The Martyr dies in the place of a good soul they chose.
	var mart = living_with_role("martyr")
	var mart_def = C.role_def("martyr")
	var substituted: bool = mart_def.can_substitute_execution(self, mart, id)
	# The substitution decision is final before the actual condemned person speaks.
	if last_words.is_valid():
		last_words.call(mart if substituted else n)
	if substituted:
		_martyr_dies(mart, n, res)
		return
	n.alive = false
	n.death_day = day
	n.death_cause = "executed"
	n.loc = "dead"
	_bereave(n)
	executed_today = id
	executions.append({"day": day, "id": id, "nominator": res.get("by", ""), "yes": res.get("yes", []).duplicate(),
		"no": res.get("no", []).duplicate(), "player_yes": res.get("player_yes", false), "player_nominated": res.get("by", "") == "player"})
	dlog.add("execution", "world", id, {"role": n.role, "align": n.alignment},
		"%s (%s) executed by town vote." % [n.name, n.role])
	mart_def.on_chosen_executed(self, mart, n)
	mart_def.on_bluff_chosen_executed(self, n)
	C.role_def(n.role).on_executed(self, n, res, Mind)
	_grief(n, res)
	if id == demon_id:
		var sc = living_with_role("scion")
		if C.role_def("scion").can_promote_to_demon(sc, alive_before, self):
			_scion_rises(sc)
		else:
			_finish("good", "The Demon's host was executed.")
	else:
		_check_parity()

## The Martyr falls dead as the noose tightens; the nominee lives. Everyone sees it: both
## are proven good.
func _martyr_dies(mart, saved, res: Dictionary) -> void:
	C.role_def("martyr").on_substitute_execution(self, mart, saved, res, Mind)

## The Revenant hangs with a totem hidden: a good soul who voted for it turns evil, and
## the town is warned (not told who).
func _revenant_curse(rv, res: Dictionary) -> void:
	C.role_def("revenant").on_executed(self, rv, res, Mind)

func turn_evil(v, why: String) -> void:
	v.pre_turn_snapshot = Mind.capture_pre_turn_snapshot(self, v)
	v.alignment = "evil"
	Mind.shadow_reset(v)  # rebuilt from their good mind as it stands now
	v.turned = true
	v.turned_day = day
	evil_plan["bluffs"][v.id] = v.role  # they keep claiming their own gift
	for m in evil_team():
		if m != v:
			Evil.add_intel(self, m, "teammate", v.id, 0.0, "%s has joined us (%s)" % [v.name, why])
	dlog.add("turned", "world", v.id, {"why": why, "role": v.role}, "%s turns evil (%s). Keeps their gift and claims; now works for the Demon." % [v.name, why])

## The totem is found: the curse breaks. Restore the pre-turn good snapshot, disown fake
## turned readings, carry forward only public receipts from the turned period, and refresh.
func free_turned() -> String:
	if curse.is_empty():
		return ""
	var v = by_id[curse["victim"]]
	curse = {}
	if not v.alive:
		return ""
	v.alignment = "good"
	v.turned = false
	v.intel = {}
	for e in v.info_log:
		if e.get("fake", false):
			e["disowned"] = true
			e["shared"] = true  # never repeated
	v.applied_info = v.info_log.size()
	public_event("curse_lifted", ["town"], "")
	Mind.restore_pre_turn_snapshot(self, v)
	dlog.add("freed", "world", v.id, {}, "%s is freed from the curse; remembers nothing of their time as evil." % v.name)
	return v.id

## The demon hangs with five or more alive: the Scion takes its place.
func _scion_rises(sc) -> void:
	C.role_def("scion").promote_to_demon(self, sc)

## Those who trusted the executed resent whoever pushed for it (shifting allegiances).
## A Lover's death leaves the other withdrawn for the rest of the case: Privacy to the top,
## Gossip to the bottom, harder to read. Visible in their profile, so it's a clue.
func _bereave(dead) -> void:
	if dead.secret_mod != "lovers" or dead.lover == "" or not by_id.has(dead.lover):
		return
	var survivor = by_id[dead.lover]
	if not survivor.alive or survivor.withdrawn_since != "":
		return
	survivor.traits["privacy"] = 1.0
	survivor.traits["gossip"] = 0.0
	survivor.traits["composure"] = minf(1.0, survivor.traits.get("composure", 0.5) + 0.3)
	survivor.withdrawn_since = dead.id
	dlog.add("bereaved", survivor.id, dead.id, {"traits": survivor.traits.duplicate()},
		"%s withdraws after %s's death (Lovers)." % [survivor.name, dead.name])

func _grief(ex, res: Dictionary) -> void:
	if ex.id == demon_id:
		return  # the town was right; nobody mourns the demon
	if public_log.any(func(ev): return ev.get("kind", "") == "curse" and ex.id in ev.get("subjects", [])):
		return  # the Revenant's curse erupted publicly at the gallows; nobody mourns proven evil
	var yes_voters: Array = res.get("yes", [])
	for f in living_good():
		if f.id in yes_voters:
			continue  # no grief if the mourner voted yes to hang them
		var t: float = f.npc_trust.get(ex.id, 0.5)
		if t < Tuning.Trust.GRIEF_FRIEND_MIN_TRUST:
			continue
		# A friend who had come to believe they were evil doesn't mourn the hanging (Oct 30):
		# a minion the town rightly hanged, if the friend saw it too.
		if Mind.susp(f, ex.id) >= Tuning.Trust.GRIEF_BELIEVED_EVIL:
			continue
		var strength = (t - 0.5) * 2.0
		var nom: String = res.get("by", "")
		if nom != "" and nom != "player" and nom != f.id:
			Mind.add_resentment(self, f, nom, Tuning.Trust.RESENTMENT_NOMINATOR_SCALE * strength, ex.id, "nominator")
			f.npc_trust[nom] = clampf(f.npc_trust.get(nom, 0.5) - Tuning.Trust.GRIEF_NPC_NOMINATOR_DROP * strength, 0.0, 1.0)
		for v in yes_voters:
			if v != f.id and v != nom:
				Mind.add_resentment(self, f, v, Tuning.Trust.RESENTMENT_VOTER_SCALE * strength, ex.id, "voter")
		if nom == "player":
			Mind.set_trust(self, f, f.trust - Tuning.Trust.GRIEF_PLAYER_NOMINATOR_DROP * strength, "grief: the Demonologist nominated %s" % ex.id)
			Mind.cap_trust(self, f, Tuning.Trust.GRIEF_PLAYER_NOMINATOR_CAP, "grief: the Demonologist nominated %s" % ex.id)
		elif res.get("player_yes", false):
			Mind.set_trust(self, f, f.trust - Tuning.Trust.GRIEF_PLAYER_VOTER_DROP * strength, "grief: the Demonologist voted to hang %s" % ex.id)
		dlog.think(f.id, "grief", "Mourns %s (trust %.2f); resents those who pushed the execution." % [ex.id, t])

## Post-hearing execution-result rapport adjustment (Phase 2b): moved out of Gravedigger's
## `info_effects` and gated on the listener's own post-refresh belief about the source and
## the hanged person. Fires at most once per (listener, executed).
func on_execution_reading_heard(listener, source, entry: Dictionary, weight: float) -> void:
	if listener == null or listener.is_evil() or listener.is_shadow or source == listener or weight <= 0.2:
		return
	var d: Dictionary = {}
	var r_day: int = int(entry.get("day", -1))
	if str(entry.get("role", "")) in ["gravedigger", "executor"]:
		d = entry.get("data", {})
	elif str(entry.get("role", "")) == "medium":
		var item: Dictionary = entry.get("data", {}).get("item", {})
		if str(item.get("type", "")) == "reading" and str(item.get("role", "")) in ["gravedigger", "executor"]:
			d = item.get("data", {})
	if d.is_empty() or not d.has("role"):
		return
	var ex_id: String = str(d.get("executed", d.get("target", "")))
	if ex_id == "" or not by_id.has(ex_id) or by_id[ex_id].death_cause != "executed":
		return
	var ex_role: String = str(d.get("role", ""))
	if ex_id == "" or not by_id.has(ex_id) or not C.ROLES.has(ex_role) or listener.settled_execution_rapport.has(ex_id):
		return
	if public_log.any(func(ev): return ev.get("kind", "") == "curse" and ex_id in ev.get("subjects", [])) and ex_role != "revenant":
		return
	var rel_gd: float = Mind.reliability(listener, source.id, r_day, "reading")
	var trusts_gd: bool = Mind.susp(listener, source.id) < Tuning.Trust.EXEC_READING_MAX_SOURCE_SUSP and rel_gd >= Tuning.Trust.EXEC_READING_MIN_SOURCE_REL and listener.npc_trust.get(source.id, 0.5) >= Tuning.Trust.EXEC_READING_MIN_SOURCE_TRUST
	if not trusts_gd:
		return
	var ex_good: bool = C.ROLES[ex_role]["align"] == "good"
	var believes_outcome: bool = (Mind.susp(listener, ex_id) < Tuning.Trust.GRIEF_BELIEVED_EVIL) if ex_good else (Mind.susp(listener, ex_id) >= Tuning.Trust.EXEC_READING_MIN_EVIL_SUSP)
	if not believes_outcome:
		return
	for e in executions:
		if str(e.get("id", "")) != ex_id or not (bool(e.get("player_nominated", false)) or bool(e.get("player_yes", false))):
			continue
		listener.settled_execution_rapport[ex_id] = "good" if ex_good else "evil"
		if ex_good:
			# Execution accuracy is tracked by Credibility.dawn; personal Rapport only drops for close personal bonds.
			if ex_id in listener.friends or ex_id == listener.lover:
				Mind.set_trust(self, listener, listener.trust + float(Tuning.Roles.GRAVEDIGGER.trust_backed_innocent), "the Demonologist backed hanging %s, an innocent friend" % ex_id)
		else:
			Mind.set_trust(self, listener, listener.trust + float(Tuning.Roles.GRAVEDIGGER.trust_proven_right_base) + float(Tuning.Roles.GRAVEDIGGER.trust_proven_right_insight) * Mind.trait_of(listener, "insight"),
				"the Demonologist was proven right about %s" % ex_id)
		break

func _check_parity() -> void:
	if game_over:
		return
	if demon().alive and living().size() <= 2:
		_finish("evil", "Only two townsfolk remain and the Demon still walks among them.")
	elif demon().alive and living_good().is_empty():
		_finish("evil", "No good soul remains.")

func _finish(wn: String, why: String) -> void:
	game_over = true
	winner = wn
	end_reason = why
	dlog.add("game_over", "world", "", {"winner": wn}, why)
