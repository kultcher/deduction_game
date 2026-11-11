## Player-raised questions about a report. Never consult referee truth.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const Solver = preload("res://workshop/solver.gd")
const Domain = preload("res://workshop/world_domain.gd")
static var cache: Dictionary = {}
static var fraction_cache: Dictionary = {}
static var _index_cache: Dictionary = {}
const MODES = ["misled", "lying", "unlikely", "impaired", "delusional"]
## How a clash between the grounds and the reading is settled (belief model, challenge
## sides). "contest": the clash shows one side is wrong, not which, so the reading is
## discounted by how much more credible its grounds are than its teller, and a challenge
## citing less credible grounds than the reading backfires. "legacy": the grounds are
## taken as true (strength = their credibility alone). "graded": the clash only gates; the
## graded world-model test decides. Dev switch for tools/measure_evidence.gd; "contest" in play.
static var clash_rule: String = "contest"
const CaseEval = preload("res://workshop/case_eval.gd")

static func valid(view: Dictionary, id: String, value) -> bool:
	var card = Solver.card_by_id(view, id)
	if value is Dictionary and value.get("mode") == "delusional" and not value.has("group"):
		return false  # "they're Delusional" explains a source's readings together
	return value is Dictionary and value.get("mode") in MODES and card.get("kind") == "report" and not card.has("relay_source") and not card.get("testimony_only", false) and (value.mode != "unlikely" or (card.get("role") == "surveyor" and card.get("data", {}).has("count"))) and value.get("supports", []) is Array and value.get("supports", []).all(func(root): return root != id and not Solver.card_by_id(view, root).is_empty())

static func quality(listener: Dictionary, source: String) -> float:
	if source == listener.id or source == "evidence":
		return 1.0
	if source == "player":
		if listener.has("player_credibility"):
			var pcred: float = clampf(float(listener.get("player_credibility", 0.5)), 0.0, 1.0)
			return clampf(0.5 + 0.5 * pcred, 0.4, 1.0)
		return clampf(listener.trust, 0.0, 1.0)
	return clampf(Tuning.Workshop.WITNESS_QUALITY_BASE + Tuning.Workshop.WITNESS_QUALITY_TRUST_SCALE * listener.npc_trust.get(source, 0.5) - Tuning.Workshop.WITNESS_QUALITY_SUSP_SCALE * listener.suspicion.get(source, 0.1), Tuning.Workshop.WITNESS_QUALITY_MIN, Tuning.Workshop.WITNESS_QUALITY_MAX)

static func assess(view: Dictionary, value: Dictionary, listener: Dictionary, cards: Array) -> Dictionary:
	var selected: Dictionary = value.get("reading_challenges", {})
	if selected.is_empty():
		return {"reports": {}, "sources": {}, "results": []}
	var input = [view.people, view.get("timeline", {}), view.get("live_activity", false), view.get("world_options", {}), view.evil_count, selected, cards, listener.knowledge, listener.suspicion, listener.npc_trust, listener.trust,
		listener.get("reading_reliability", {}), view.get("script_minions", []), value.get("reasons", {})]
	var key = hash(input)
	if cache.has(key) and cache[key].input == input:
		return cache[key].result
	var result = {"reports": {}, "sources": {}, "results": []}
	var reference = null
	for id in selected:
		if not valid(view, id, selected[id]) or not cards.any(func(c): return c.id == id):
			continue
		var challenge: Dictionary = selected[id]
		var report = Solver.card_by_id(view, id)
		# All challenges share the listener's baseline. Filter the hypothetical good
		# claimant below instead of solving that same baseline once per report.
		if reference == null:
			reference = Solver.solve(view, [], {}, {}, listener.knowledge).worlds
		var counted = _fraction(view, report, listener.knowledge, reference)
		var fraction: float = counted.fraction
		var has_reference: bool = counted.possible
		var grounds: Array = cards.filter(func(c): return c.id in challenge.get("supports", []) and c.id != id and not c.get("quoted", false) and quality(listener, c.source) >= Tuning.Workshop.CHALLENGE_GROUND_MIN_QUALITY)
		var conflict = false
		var self_presence_conflict = false
		var strength = 1.0
		if not grounds.is_empty():
			var alone = Solver.solve(view, grounds, {}, {}, listener.knowledge)
			var together = Solver.solve(view, grounds + [report], {}, {}, listener.knowledge)
			conflict = not alone.worlds.is_empty() and alone.movement_ok and (together.worlds.is_empty() or not together.movement_ok)
			if not conflict and report.get("role", "") == "psychologist" and str(report.get("data", {}).get("mode", "")) == "none_false":
				var dh_ch: int = int(report.get("data", {}).get("day_heard", -1))
				var day_grounds: Array = grounds.filter(func(g_c): return Solver.Graph.is_day_statement(g_c, dh_ch))
				if day_grounds.size() >= 2:
					var d_joint = Solver.solve(view, day_grounds, {}, {}, listener.knowledge)
					var each_ok: bool = day_grounds.all(func(g_c): var sg = Solver.solve(view, [g_c], {}, {}, listener.knowledge); return not sg.worlds.is_empty() and sg.movement_ok)
					if each_ok and (d_joint.worlds.is_empty() or not d_joint.movement_ok):
						conflict = true
				elif day_grounds.size() == 1:
					var sg1 = Solver.solve(view, day_grounds, {}, {}, listener.knowledge)
					if sg1.worlds.is_empty() or not sg1.movement_ok:
						conflict = true
			if conflict and report.get("role", "") in ["nightwatch", "warden", "medium", "lamplighter"]:
				var duty_probe: Dictionary = report.duplicate(true)
				duty_probe["duty_only"] = true
				var duty_together = Solver.solve(view, grounds + [duty_probe], {}, {}, listener.knowledge)
				self_presence_conflict = alone.movement_ok and not duty_together.movement_ok
			for ground in grounds:
				strength = minf(strength, quality(listener, ground.source))
		# A clash says one side is wrong, not which. Before: the grounds were taken as true,
		# so a challenge landed whichever side lied, on trust in the grounds alone.
		var contest_lost: bool = false
		if conflict and clash_rule != "legacy":
			var q_r: float = quality(listener, report.source)
			# P(reading is the broken side | clash) - P(grounds are), with each side reliable
			# at its teller's quality: (q_g - q_r) / (1 - q_r q_g).
			var share: float = (strength - q_r) / maxf(1.0 - q_r * strength, 1e-6)
			if clash_rule == "graded" or share <= 0.0:
				contest_lost = clash_rule == "contest" and share < 0.0
				conflict = false
				self_presence_conflict = false
				strength = 0.0
			else:
				strength = share
		var supported = (fraction == 0.0 and has_reference) or conflict or (challenge.mode == "unlikely" and fraction < 0.05 and has_reference)
		var accuracy_agreement = 0.0
		var multiplier = 1.0
		var note = "You question that report, but the cited evidence does not establish a problem."
		if supported:
			accuracy_agreement = 0.8 * strength if conflict else (0.9 if fraction == 0.0 else 0.6)
			multiplier = 1.0 - (0.65 * strength if conflict else (0.75 if fraction == 0.0 else 0.35))
			note = "The report conflicts with the cited evidence. Its contents deserve less weight; the cause remains uncertain." if conflict else ("That report cannot fit the established facts under its good, healthy-source assumptions." if fraction == 0.0 else "That count requires an unusually restrictive town layout. I will treat it with some caution, though it may be accurate.")
		elif challenge.mode == "unlikely":
			note = "That count fits ordinary town layouts. Calling it unlikely supplies no reason to discount it."
		if challenge.mode == "misled" and report.role == "seer" and report.data.yes:
			var joint = Solver.solve(view, grounds + [report], {}, {}, listener.knowledge)
			var pair_indices: Array = report.data.pair.map(func(person): return Solver.person_index(view, person))
			if not grounds.is_empty() and not joint.worlds.is_empty() and joint.worlds.all(func(w): return w.has("demon") and w.demon not in pair_indices):
				supported = true
				accuracy_agreement = 0.8 * strength
				multiplier = 1.0 # The gift can function correctly and still mislead.
				note = "Together these readings exclude the Demon from that pair. A Red Herring or Marked registration can mislead an honest Seer without a broken gift."
			elif not supported:
				note = "A Red Herring or Marked registration could mislead an honest Seer. This modifier alone does not establish that explanation."
		var hearing: float = clampf(float(challenge.get("weight", 1.0)), 0.0, 1.0)
		accuracy_agreement *= hearing
		multiplier = 1.0 - hearing * (1.0 - multiplier)
		var cause_agreement: float = accuracy_agreement
		if challenge.mode == "lying":
			# Discrepancy alone does not identify the dishonest source unless the cited
			# observation rules out the speaker's own claimed physical presence, which
			# poisoning or Delusion cannot explain.
			if self_presence_conflict:
				# The ruling-out observation sets the strength; supporting context (such as a
				# claim explaining someone else's outing) must not dilute it.
				var obs_strength: float = 0.0
				for ground in grounds:
					if ground.kind in ["sighting", "coverage", "alibi"]:
						obs_strength = maxf(obs_strength, quality(listener, ground.source))
				if obs_strength <= 0.0:
					obs_strength = strength
				accuracy_agreement = maxf(accuracy_agreement, 0.85 * obs_strength * hearing)
				cause_agreement = accuracy_agreement
				note = "The cited observation rules out their presence where that gift required them to be; impairment cannot explain that."
			else:
				cause_agreement *= 1.0 - quality(listener, report.source)
			if report.role == "gravedigger" and view.has("timeline"):
				var gd_n: int = report.night if int(report.get("night", -1)) >= 0 else int(report.get("observed_at", {}).get("day", -1))
				if not preload("res://workshop/live_history.gd").executed(view, str(report.data.get("executed", "")), gd_n):
					accuracy_agreement = maxf(accuracy_agreement, 0.9 * hearing)
					cause_agreement = accuracy_agreement
					note = "No such public execution happened that night; impairment cannot explain that Gravedigger report."
			if report.role == "executor" and report.data.has("role") and view.has("timeline"):
				var ex_obs_d: int = int(report.get("observed_at", {}).get("day", -1))
				if not preload("res://workshop/live_history.gd").died_before_morning(view, str(report.data.get("target", "")), ex_obs_d):
					accuracy_agreement = maxf(accuracy_agreement, 0.9 * hearing)
					cause_agreement = accuracy_agreement
					note = "That person had not just died before that morning; impairment cannot explain that Executor report."
			if report.source != listener.id and report.role == listener.knowledge.get("own_role", ""):
				cause_agreement = hearing # firsthand knowledge of a unique gift claim
				note = "They claim the unique gift I know I hold. Impairment cannot explain that role claim."
			if report.source in listener.knowledge.good:
				cause_agreement = 0.0
				note += " My established good-alignment knowledge does not support the evil-reader explanation."
			if cause_agreement >= Tuning.Workshop.JURY_CHALLENGE_LYING_MIN_AGR:
				pass # no source discount for a lie: see the reports note below
			else:
				note += " I am not convinced the reader deliberately lied."
		elif challenge.mode == "misled" and supported:
			note += " Misled can include impairment or a gift's misleading registration; it does not establish poisoning."
		# Premises step 3: graded scoring. The hard cases above stay as floors; the graded
		# test asks how far the rest of the attended evidence, against chance, says the
		# reading (or the source's readings together) is wrong, and how well the named cause
		# explains that.
		var group: Array = challenge.get("group", [id])
		# A Seer "misled" (Red Herring, Marked registration) keeps its explicit rule: an
		# honest gift that registered correctly isn't discounted, and a yes/no flip on one
		# pair is no automatic discount either. Its registration is already in the worlds.
		# A bare defence (an NPC's word, no grounds; SharedLedger) isn't graded: see there.
		var ungraded: bool = challenge.get("bare", false) or (challenge.mode == "misled" and str(report.get("role", "")) == "seer" and not challenge.has("group"))
		var graded: Dictionary = {} if ungraded else graded_challenge(view, group, challenge.mode, listener, cards)
		var backfire: bool = false
		var candidates: Dictionary = {}
		if not graded.is_empty():
			var g_mult: float = 1.0 - hearing * graded.cause * graded.effect
			if g_mult < multiplier:
				multiplier = g_mult
				supported = true
				note = graded.note
			var g_agree: float = hearing * graded.cause * graded.effect
			accuracy_agreement = maxf(accuracy_agreement, hearing * graded.effect)
			if challenge.mode == "lying" and not (report.source in listener.knowledge.get("good", [])):
				if g_agree > cause_agreement:
					cause_agreement = g_agree
					if cause_agreement >= Tuning.Workshop.JURY_CHALLENGE_LYING_MIN_AGR:
						pass # no source discount for a lie: see the reports note below
			elif challenge.mode == "impaired":
				cause_agreement = g_agree
				# Everyone seen out on any of the group's nights (maintenance 2026-11-07 A4).
				for member in group:
					var m_card: Dictionary = Solver.card_by_id(view, member)
					if not m_card.is_empty():
						candidates.merge(poisoner_candidates(view, m_card, value, cards))
			elif challenge.mode in ["misled", "unlikely", "delusional"]:
				cause_agreement = maxf(cause_agreement, g_agree)
			backfire = graded.backfire
		# Citing less credible grounds against a more credible reading backfires.
		if contest_lost and not supported:
			backfire = true
			note = "Those grounds carry less weight with me than the report they contradict."
		# A lie is evidence against the reader, and the world model already counts it: in a
		# world where the reader is good and healthy the reading must hold, so the clash
		# with the grounds weighs against that world. Discounting the reading's reliability
		# would make it fit everywhere and throw that clash away (belief-model plan, Phase 1).
		# So an accepted "lying" challenge leaves the reading and its source's other readings
		# at full reliability; honest-error modes (misled, impaired, unlikely, Delusional)
		# still discount them. The reply and the floor nudge (Jury) still use the result.
		if challenge.mode != "lying":
			for member in group:
				if member != id and cards.any(func(c): return c.id == member):
					result.reports[member] = minf(result.reports.get(member, 1.0), multiplier)
			result.reports[id] = minf(result.reports.get(id, 1.0), multiplier)
		result.results.append({"card": id, "mode": challenge.mode, "supported": supported, "fraction": fraction,
			"agreement": cause_agreement, "accuracy_agreement": accuracy_agreement, "multiplier": multiplier, "source": report.source, "note": note,
			"graded": graded, "backfire": backfire, "candidates": candidates, "group": group})
	if cache.size() >= 64:
		cache.clear()
	cache[key] = {"input": input.duplicate(true), "result": result}
	return result

## Premises step 3: the graded test for a challenged reading (or a source's readings,
## `group`, taken together). With r the prior chance the reading(s) are accurate (the source
## good, times one minus the reading error), q the share of worlds in which the content
## holds before any evidence and f the share after the rest of the attended evidence (both
## from one CaseEval question, so on one footing), the chance the reading is wrong is
## (1 - r) q / ((1 - r) q + r f). Its rise above the prior 1 - r, as a share of r, is the
## challenge's `effect`; `cause` is how well the named explanation accounts for it. A
## neutral rest moves nothing; a rest that backs the reading up is a `backfire`.
static func graded_challenge(view: Dictionary, group: Array, mode: String, listener: Dictionary, cards: Array) -> Dictionary:
	var reports: Array = group.map(func(gid): return Solver.card_by_id(view, gid)).filter(func(c): return not c.is_empty() and c.get("kind", "") == "report" and Solver.tabled(c))
	if reports.is_empty():
		return {}
	var source: String = str(reports[0].source)
	var ids: Array = reports.map(func(c): return c.id)
	var rest: Array = cards.filter(func(c): return c.id not in ids and not c.get("quoted", false)).map(func(c): return c.id)
	var epoch = view.get("alignment_epoch", "")
	# f and q: does every reading in the group hold, after the rest and before anything.
	# Jointly: two readings that can't both hold have no shared share of worlds.
	var question: Dictionary = Solver.empty_case()
	question.cards = rest.duplicate()
	if ids.size() == 1:
		question.conclusion = {"type": "holds", "report": ids[0], "target": source, "at": epoch}
	else:
		question.conclusion = {"type": "inconsistent", "reports": ids, "target": source, "at": epoch}
	var ev: Dictionary = CaseEval.evaluate(view, question, listener)
	if ev.get("impossible", false):
		return {}
	var holds_p0: float = float(ev.prior) if ids.size() == 1 else 1.0 - float(ev.prior)
	var holds_p1: float = float(ev.posterior) if ids.size() == 1 else 1.0 - float(ev.posterior)
	var q: float = clampf(holds_p0, 1e-6, 1.0)
	var f: float = clampf(holds_p1, 0.0, 1.0)
	# r: the source good (before the case) and each reading's error. A case's prior doesn't
	# depend on its cards, so the source's prior comes from the same evaluation (its
	# per-person prior chance of being evil).
	var has_source: bool = source in view.people.map(func(p): return p.id)
	var accurate: float = clampf(1.0 - float(ev.get("people", {}).get(source, {}).get("prior", 0.0)), 0.0, 1.0) if has_source else 1.0
	for r_card in reports:
		accurate *= 1.0 - CaseEval.reading_error(view, r_card, listener)
	var r: float = clampf(accurate, 1e-6, 1.0 - 1e-6)
	var wrong_prior: float = 1.0 - r
	var wrong: float = wrong_prior * q / maxf(wrong_prior * q + r * f, 1e-12)
	var rise: float = wrong - wrong_prior
	var effect: float = clampf(rise / r, 0.0, 1.0)
	# The cause: how much of the reading being wrong the named explanation carries. It only
	# ever scales the effect, so with no effect it isn't weighed (most bare defences: the
	# rest of the evidence doesn't make the reading look wrong).
	var evil_share: float = 0.0
	if effect > 0.0 and has_source:
		var evil_q: Dictionary = Solver.empty_case()
		evil_q.cards = rest + ids
		evil_q.conclusion = {"type": "evil", "target": source, "at": epoch}
		var ev_evil: Dictionary = CaseEval.evaluate(view, evil_q, listener)
		evil_share = clampf(float(ev_evil.get("posterior", 0.0)) / maxf(wrong, 1e-9), 0.0, 1.0)
	var cause: float = 1.0
	var note: String = ""
	match mode:
		"lying":
			cause = evil_share
			note = "Weighed against the rest of what I know, that reading looks wrong, and a lying reader explains it."
		"impaired":
			cause = (1.0 - evil_share) if poisoner_possible(view) else 0.0
			note = "Weighed against the rest of what I know, that reading looks wrong; a failed gift that night could explain it." if cause > 0.0 else "A failed gift needs a Poisoner in play, and this town can't have one."
		"delusional":
			var del_q: Dictionary = Solver.empty_case()
			del_q.cards = rest + ids
			del_q.conclusion = {"type": "secret_mod", "target": source, "mod": "delusional", "at": epoch}
			var del_ok: bool = effect > 0.0 and "delusional" in view.get("world_options", {}).get("modifiers", [])
			var ev_del: Dictionary = CaseEval.evaluate(view, del_q, listener) if del_ok else {"posterior": 0.0}
			cause = clampf(float(ev_del.get("posterior", 0.0)) / maxf(wrong, 1e-9), 0.0, 1.0)
			note = "Those readings don't fit together; a Delusional gift would explain them without anyone lying."
		_:
			cause = 1.0 - evil_share if mode == "misled" else 1.0
			note = "Weighed against the rest of what I know, that reading looks wrong, though the reader may be honest."
	if effect <= 0.0:
		note = "Weighed against the rest of what I know, that reading still fits; I don't see a reason to doubt it."
	# Backfire: the rest of the evidence moves the content a quarter of the way toward
	# certainly holding (the mirror of the wrong-premise threshold).
	var backfire: bool = CaseEval.shift(q, f) >= Tuning.Workshop.CHALLENGE_BACKFIRE_SHIFT
	if backfire:
		note = "The rest of what I know backs that reading up; doubting it doesn't hold."
	return {"r": r, "q": q, "f": f, "wrong": wrong, "wrong_prior": wrong_prior, "rise": rise, "effect": effect, "cause": cause, "evil_share": evil_share, "backfire": backfire, "note": note}

## Whether a Poisoner can be in play (the minion lineup, premises step 3): the case's script
## has one, and no public fact rules it out. Unknown scripts allow it.
static func poisoner_possible(view: Dictionary) -> bool:
	var roles: Array = view.get("script_minions", [])
	return roles.is_empty() or "poisoner" in roles

## Poisoner candidates for a failed gift: people the attended cards saw out on the night
## the reading was taken, with no gift or private errand the case gives for it. Nobody
## without such a sighting is a candidate.
static func poisoner_candidates(view: Dictionary, report: Dictionary, value: Dictionary, cards: Array) -> Dictionary:
	var night: int = int(report.get("night", -1))
	if night < 0:
		var obs: Dictionary = report.get("observed_at", {})
		night = int(obs.get("day", 0)) - (1 if str(obs.get("phase", "")) == "morning" else 0)
	var reasons: Dictionary = value.get("reasons", {})
	var out: Dictionary = {}
	for c in cards:
		var seen: Array = []
		if c.get("kind", "") == "sighting" and int(c.get("night", -1)) == night:
			seen = c.get("subjects", [c.get("subject", "")])
		elif c.get("kind", "") == "report" and c.get("role", "") == "nightwatch" and int(c.get("night", -1)) == night:
			seen = c.get("data", {}).get("seen", [])
		for person in seen:
			var key: String = "%s:%d" % [person, night]
			if str(person) == "" or person == report.source or str(reasons.get(key, "")) in ["gift", "secret"]:
				continue
			out[person] = true
	return out

## Count distinct alignment/modifier layouts, ignoring redundant Demon identities.
## Report and role tables are compiled once; no per-world strings or role-cache hash.
static func _fraction(view: Dictionary, report: Dictionary, knowledge: Dictionary, reference: Array) -> Dictionary:
	var input = [Solver._universe_key(view), view.people, view.get("timeline", {}), view.get("live_activity", false), report, Solver._query_knowledge(knowledge)]
	var key = hash(input)
	if fraction_cache.has(key) and fraction_cache[key].input == input:
		return fraction_cache[key].result
	var u_key: String = Solver._universe_key(view)
	var universe: Array = Solver.universe(view)
	var u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var table: PackedByteArray = Solver.report_table(view, report)
	var roles: PackedByteArray = Solver.Roles.fits_table(view, universe, [report], knowledge, {}, false, u_handle)
	var compatible: bool = Domain.claims_compatible([report], knowledge)
	# Universe index of each reference world: live worlds carry it (__i); fixture worlds
	# are looked up by key (the map is cached per universe).
	var ref_idx := PackedInt32Array()
	ref_idx.resize(reference.size())
	var by_key: Dictionary = {}
	for k in range(reference.size()):
		var ui: int = int(reference[k].get("__i", -1))
		if ui < 0:
			if by_key.is_empty():
				by_key = _universe_index(view, u_key, universe)
			ui = by_key[Solver.TimeModel.key(view, reference[k])]
		ref_idx[k] = ui
	var epoch: String = knowledge.get("good_epoch", "")
	var eff_epoch = view.get("alignment_epoch", "") if epoch == "" else epoch
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(reference) if u_handle < 0 else PackedInt64Array()
	SolverBackend.record_boundary_call("ReadingChallenges.fraction", 0)
	var counts: PackedInt32Array = SolverBackend._bridge().ReadingFraction(u_handle, ref_idx, fallback, view.people.size(),
		Solver.person_index(view, report.source), Solver._curse_active_at(view, eff_epoch), table, roles, compatible)
	var numerator: int = counts[0]
	var denominator: int = counts[1]
	var result = {"fraction": float(numerator) / maxf(denominator, 1), "possible": denominator > 0}
	if fraction_cache.size() >= 128:
		fraction_cache.clear()
	fraction_cache[key] = {"input": input.duplicate(true), "result": result}
	return result


## Universe index by world key, per universe (fixture worlds carry no __i).
static func _universe_index(view: Dictionary, u_key: String, universe: Array) -> Dictionary:
	if _index_cache.has(u_key):
		return _index_cache[u_key]
	if _index_cache.size() >= 16:
		_index_cache.clear()
	var out: Dictionary = {}
	for i in range(universe.size()):
		out[Solver.TimeModel.key(view, universe[i])] = i
	_index_cache[u_key] = out
	return out
