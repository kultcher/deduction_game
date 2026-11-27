## Case evaluation (docs/CASE_REASONING.md, foundation pass).
##
## One pass over the world universe instead of the old 2^u credibility mixture. Each
## world gets a weight: the listener's prior times, for every report card, its likelihood
## in that world:
##   source can't give a healthy reading in this world (evil, impaired): q
##   otherwise: (1 - err) * [content holds] + err * q
## q is the chance of that particular content arising by chance (a false report), and err
## the chance a healthy reading from a good source is still wrong anyway (unmodelled
## impairment). Evil sources are part of the world, so a liar's several readings are wrong
## together without a separate honesty factor, and with independent errors this sum is
## exactly what enumerating every "which cards are true" combination would give.
##
## Chosen answers are the player's theory: they're scored for fit, never added as facts.
## Hard constraints that aren't reports (movement, alibis, claims, roles) stay with the
## solver's existing checks for now.
##
## Speed: compile() groups the universe once per presentation into classes that every
## listener weighs alike (same evil team, role-check mask, card states and premise), so
## each listener's work is per class (a few hundred), not per world (15,120 live).
## Report tables are per reading and cached, so they're built once, when a reading first
## appears in a case. tools/profile_case_eval_town.gd measures the town.
##
## Split across a chain (`case_eval_base` <- `case_eval_content` <- `case_eval_classes` <-
## this file): this file keeps the public face (evaluate, shift, category, strength) and the
## people, rivals and theory-fit readouts; every CaseEval.<fn> and static var still resolves here.
extends "res://workshop/case_eval_classes.gd"

## How far the evidence moved a probability toward certainty (+1: from p0 all the way
## to yes; -1: all the way to no; 0: no change).
static func shift(p0: float, p1: float) -> float:
	if p1 >= p0:
		return (p1 - p0) / (1.0 - p0) if p0 < 1.0 else 0.0
	return (p1 - p0) / p0 if p0 > 0.0 else 0.0

static func _odds(p: float) -> float:
	p = clampf(p, 1e-9, 1.0 - 1e-9)
	return p / (1.0 - p)

## Strength category from a likelihood ratio on the premise. With `chance`, the premise's
## chance after the case for the listener the badge speaks for, the top tier ("damning")
## applies at LR_DAMNING_CHANCE or above (Michael, Nov 19), whatever the strength.
static func category(lr: float, chance: float = -1.0) -> String:
	if chance >= LR_DAMNING_CHANCE:
		return "damning"
	if lr < 1.0 / LR_WEAK:
		return "contradicts"
	if lr < LR_WEAK:
		return "none"
	if lr < LR_MODERATE:
		return "weak"
	if lr < LR_STRONG:
		return "moderate"
	return "strong"

static func category_text(cat: String) -> String:
	match cat:
		"contradicts": return "The linked evidence argues against this premise."
		"none": return "The linked evidence doesn't support this premise."
		"weak": return "This case weakly supports the premise."
		"moderate": return "This case moderately supports the premise."
		"strong": return "This case strongly supports the premise."
		"damning": return "This case strongly supports the premise."  # Herald's wording to come
	return ""

## Evaluate a case for one listener. Returns:
##   prior, posterior    P(premise) before and after the case's evidence
##   lr, category        likelihood ratio on the premise and its category
##   people              per person {prior, posterior} probability of being evil
##   rivals              the people (other than the target) most likely evil after the case
##   theory_fit          how much of the posterior agrees with the player's answers/positions
##   pivotal             card ids whose removal would drop the category (reference listener)
##   impossible          no world survives the case's hard facts
## Developer inspection only (tools/belief_views.gd): when set, every evaluation also
## appends {"worlds": per-world posterior weights (universe order, unnormalised),
## "people": per-person odds} to captured, one entry per evaluation. Off in play; it
## changes no result.
static var capture_worlds: bool = false
static var captured: Array = []

static func evaluate(view: Dictionary, case_data: Dictionary, listener: Dictionary = {}) -> Dictionary:
	case_data = Solver.with_hanged_refuters(view, case_data)
	if not SolverBackend.profiling_enabled:
		return _evaluate_impl(view, case_data, listener)
	var _st: int = SolverBackend.begin_stage("channel_sum_product")
	var _res: Dictionary = _evaluate_impl(view, case_data, listener)
	SolverBackend.end_stage(_st)
	return _res

static func _evaluate_impl(view: Dictionary, case_data: Dictionary, listener: Dictionary = {}) -> Dictionary:
	if listener.is_empty():
		listener = neutral_listener(view)
	# An already-compiled (attended) case has its lines folded away: keep its factors.
	var supplied: Array = case_data.get("test_factors", [])
	case_data = Graph.compile_case(view, case_data)
	if case_data.test_factors.is_empty() and not supplied.is_empty():
		case_data.test_factors = supplied.duplicate(true)
	var cards: Array = Solver.selected(view, case_data)
	var conclusion: Dictionary = case_data.conclusion
	var knowledge: Dictionary = listener.get("knowledge", {})
	var own_ids: Array = knowledge.get("own_reports", [])
	var own: Array = own_ids.map(func(id): return Solver.card_by_id(view, id)).filter(func(c): return not c.is_empty() and not (c in cards) and c.kind == "report" and Solver.tabled(c))
	var corroborated_days: Dictionary = {}
	for p_c in cards:
		if p_c.kind == "report" and p_c.get("role", "") == "psychologist" and not p_c.get("quoted", false) and not case_data.get("reading_challenges", {}).has(p_c.id):
			if str(p_c.get("data", {}).get("mode", "")) == "none_false":
				corroborated_days[int(p_c.get("data", {}).get("day_heard", -1))] = p_c
	var err_for = func(card: Dictionary) -> float:
		var base_e: float = reading_error(view, card, listener, own_ids)
		if not corroborated_days.is_empty() and card.kind == "report" and card.get("role", "") != "psychologist" and not case_data.get("reading_challenges", {}).has(card.id):
			for d_ok in corroborated_days:
				if Graph.is_day_statement(card, int(d_ok)):
					var p_err: float = reading_error(view, corroborated_days[d_ok], listener, own_ids)
					var boost: float = clampf(1.0 - p_err, 0.0, 1.0)
					base_e = clampf(OWN_ERR + (base_e - OWN_ERR) * (1.0 - 0.55 * boost), OWN_ERR, 1.0)
					break
		return base_e
	var cc = compile(view, _list_broken(view, _route_trusted(cards, listener), listener), case_data, own)
	var oc = _own_counts(view, cc, own, knowledge)
	# Per class: prior (team odds, role fits) and the case's likelihood.
	var team_prior = _team_prior(view, listener)
	# The "before" side of the case: role knowledge without the case's own cards. Role-
	# based readings (Seer, Archivist, Clerk...) act through the role check; applied to
	# both sides they cancel, and the reading never moved anyone (playtest 37291).
	var fits_before = _class_fits(view, cc, [], knowledge)
	var fits = fits_before if (cache_enabled and Domain.live(view) and not _has_role_card(cards)) else _class_fits(view, cc, cards, knowledge)
	fits = _doubted_role_fits(view, cc, cards, knowledge, fits, listener)
	fits = delusion_odds_fits(view, cc, case_data, fits)
	if view.get("chronology", {}).has("curse"):
		fits = fits.duplicate() # Never modify a cached role table.
		var worlds: Array = Solver.universe(view)
		for c in range(fits.size()):
			var world: Dictionary = worlds[cc.rep[c]]
			for person in knowledge.get("good", []):
				if TimeModel.evil_at(view, world, person, knowledge.get("good_epoch", view.alignment_epoch)):
					fits[c] = 0.0
			for fact in knowledge.get("timed_good", []):
				if TimeModel.evil_at(view, world, fact.person, fact.at):
					fits[c] = 0.0

	var nc_check: int = cc.team.size()
	assert(fits.size() == nc_check and fits_before.size() == nc_check, "CaseEval.evaluate: per-class fits size mismatch (nc=%d, fits=%d, fits_before=%d)" % [nc_check, fits.size(), fits_before.size()])
	_ensure_cc_epoch()
	var cc_h: int = _handle_for(cc)
	if cc_h >= 0:
		return _evaluate_posterior_cs(view, case_data, cards, conclusion, listener, own_ids, own, err_for, cc, cc_h, oc, team_prior, fits, fits_before)
	# No compiled C# class table for this case (not registered): the GDScript posterior.
	return _evaluate_posterior_gd(view, case_data, cards, conclusion, listener, own_ids, own, err_for, cc, oc, team_prior, fits, fits_before)

static func _evaluate_posterior_gd(view: Dictionary, case_data: Dictionary, cards: Array, conclusion: Dictionary, listener: Dictionary, own_ids: Array, own: Array, err_for: Callable, cc: Dictionary, oc: Dictionary, team_prior: PackedFloat64Array, fits: PackedFloat64Array, fits_before: PackedFloat64Array) -> Dictionary:
	var nc: int = cc.team.size()
	var ns: int = oc.states
	var case_like = _class_like_gd(cc, cc.reports.map(func(c): return err_for.call(c)), -1)
	var own_like = _state_like(view, own, own.map(func(c): return err_for.call(c)), oc.codes)
	var own_w: PackedFloat64Array = oc.get("weights", PackedFloat64Array())
	if own_w.size() == ns:
		for o in range(ns):
			own_like[o] *= own_w[o]
	# Live role uniqueness is checked per world in Roles.fits, where an evil claimant may
	# bluff; a global "two people claimed one gift" gate would void every world.
	var compatible: bool = true
	var base = PackedFloat64Array()
	var post = PackedFloat64Array()
	base.resize(nc * ns)
	post.resize(nc * ns)
	var counts: PackedFloat64Array = oc.counts
	var team: PackedInt32Array = cc.team
	var move: PackedFloat64Array = cc.move if cc.movement_ok else PackedFloat64Array()
	if not cc.movement_ok:
		move.resize(nc)
		move.fill(0.0)
	var test_like = _test_like(view, cc, listener, own_ids)
	for c in range(nc):
		var w0: float = team_prior[team[c]] * fits[c] if compatible else 0.0
		for o in range(ns):
			var k = c * ns + o
			var b: float = counts[k] * w0 * own_like[o]
			base[k] = counts[k] * team_prior[team[c]] * fits_before[c] * own_like[o] if compatible else 0.0
			post[k] = b * case_like[c] * move[c] * test_like[c]
	# A listener holding a theory reads the evidence through it (Theory bias): worlds
	# that fit their theory count for more after the case.
	var bias: Dictionary = listener.get("theory_bias", {})
	if not bias.is_empty():
		var universe: Array = Solver.universe(view)
		var rep_of: PackedInt32Array = cc.rep
		for c in range(nc):
			if Solver.position_holds(view, universe[rep_of[c]], bias.target, bias.position, conclusion.get("at", "")):
				for o in range(ns):
					post[c * ns + o] *= float(bias.factor)
	var b2 = _class_share(cc, base, ns)
	var a2 = _class_share(cc, post, ns)
	var p0 = b2[0] / b2[1] if b2[1] > 0.0 else 0.0
	var p1 = a2[0] / a2[1] if a2[1] > 0.0 else 0.0
	var lr = _odds(p1) / _odds(p0) if p0 > 0.0 and p0 < 1.0 else 1.0
	var result = {"prior": p0, "posterior": p1, "lr": lr, "category": category(lr),
		"impossible": a2[1] <= 0.0}
	result["people"] = _people(view, cc, base, post, ns)
	var test_used: Array = cc.tests.filter(func(f): return _route_credit(view, f, listener, own_ids) > 0.0)
	var joint = _joint(view, cc, oc, own, base, post, ns, err_for)
	result["consistent"] = joint.consistent
	result["acceptance"] = joint.acceptance
	result["credence"] = joint.credence
	result["movement"] = cc.movement + test_used.map(func(f): return f.label)
	result["factors"] = cc.factors + test_used
	result["rivals"] = _rivals(view, result.people, conclusion)
	result["theory_fit"] = 1.0
	if capture_worlds:
		captured.append({"worlds": _expand(cc, oc, post), "people": result.people.duplicate(true)})
	if not case_data.get("positions", {}).is_empty() or case_data.get("answers", {}).values().any(func(a): return not a.get("positive", []).is_empty() or not a.get("blocks", []).is_empty() or str(a.get("in_play_role", "")) != "" or str(a.get("false_slot", "")) != ""):
		result["theory_fit"] = _theory_fit(view, case_data, cards, _expand(cc, oc, post), listener.get("knowledge", {}))
	if listener.get("id", "") == "":
		# Only the board's strength label needs it: the reference listener.
		result["pivotal"] = _pivotal(cc, base, ns, err_for, p0, result.category)
	return result

static func _evaluate_posterior_cs(view: Dictionary, case_data: Dictionary, cards: Array, conclusion: Dictionary, listener: Dictionary, own_ids: Array, own: Array, err_for: Callable, cc: Dictionary, cc_h: int, oc: Dictionary, team_prior: PackedFloat64Array, fits: PackedFloat64Array, fits_before: PackedFloat64Array) -> Dictionary:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var u_key: String = Solver._universe_key(view)
	var universe: Array = Solver.universe(view)
	var u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(universe) if u_handle < 0 else PackedInt64Array()

	var k: int = cc.k
	var ko: int = own.size()
	var ns: int = int(oc.states)

	var case_errs := PackedFloat64Array()
	case_errs.resize(k)
	for i in range(k):
		case_errs[i] = float(err_for.call(cc.reports[i]))

	var own_errs := PackedFloat64Array()
	var own_qs := PackedFloat64Array()
	own_errs.resize(ko)
	own_qs.resize(ko)
	for i in range(ko):
		own_errs[i] = float(err_for.call(own[i]))
		own_qs[i] = own_chance_content(view, own[i])

	var flat_own_codes := PackedByteArray()
	if ko > 0:
		if oc.has("_flat_codes"):
			flat_own_codes = oc["_flat_codes"]
		else:
			for code_arr in oc.codes:
				flat_own_codes.append_array(code_arr)

	var tests: Array = cc.tests
	var m_tests: int = tests.size()
	var route_credits := PackedFloat64Array()
	var test_lrs := PackedFloat64Array()
	route_credits.resize(m_tests)
	test_lrs.resize(m_tests)
	var test_used: Array = []
	for j in range(m_tests):
		var rc: float = _route_credit(view, tests[j], listener, own_ids)
		route_credits[j] = rc
		test_lrs[j] = float(tests[j].log2_ratio)
		if rc > 0.0:
			test_used.append(tests[j])

	var bias: Dictionary = listener.get("theory_bias", {})
	var has_bias: bool = not bias.is_empty()
	var bias_t_idx: int = -1
	var bias_pos_code: int = 0
	var bias_conv: bool = false
	var bias_factor: float = 1.0
	if has_bias:
		bias_t_idx = Solver.person_index(view, str(bias.target))
		bias_pos_code = Solver._position_code(str(bias.position))
		var b_ep = view.get("alignment_epoch", "") if str(conclusion.get("at", "")) == "" else conclusion.get("at", "")
		bias_conv = Solver._curse_active_at(view, b_ep)
		bias_factor = float(bias.factor)

	var compute_piv: bool = listener.get("id", "") == ""
	var theory_needed: bool = not case_data.get("positions", {}).is_empty() or case_data.get("answers", {}).values().any(func(a): return not a.get("positive", []).is_empty() or not a.get("blocks", []).is_empty() or str(a.get("in_play_role", "")) != "" or str(a.get("false_slot", "")) != "")
	var need_expand: bool = theory_needed or capture_worlds

	var eval_ints := PackedInt32Array([
		ns,
		ko,
		1 if has_bias else 0,
		bias_t_idx,
		bias_pos_code,
		1 if bias_conv else 0,
		1 if compute_piv else 0,
		1 if need_expand else 0,
		cc.team.size(),
	])
	var tuning_doubles := PackedFloat64Array([DEFAULT_ERR, LR_WEAK, LR_MODERATE, LR_STRONG])

	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("CaseEval.evaluate_posterior", pack_u)
	var raw: PackedFloat64Array = SolverBackend._bridge().CaseEvalEvaluatePosterior(
		cc_h, u_handle, fallback, eval_ints, tuning_doubles,
		team_prior, fits, fits_before, case_errs, own_errs, own_qs,
		oc.counts, oc.of, flat_own_codes, route_credits, test_lrs, bias_factor,
		oc.get("weights", PackedFloat64Array())
	)

	var p: int = 0
	var p0: float = raw[p]; p += 1
	var p1: float = raw[p]; p += 1
	var lr: float = raw[p]; p += 1
	var impossible: bool = raw[p] != 0.0; p += 1
	var consistent: bool = raw[p] != 0.0; p += 1
	var credence: float = raw[p]; p += 1

	var ids: Array = Solver.person_ids(view)
	var n_people: int = ids.size()
	var people_dict: Dictionary = {}
	for j in range(n_people):
		var pr_j: float = raw[p]; p += 1
		var po_j: float = raw[p]; p += 1
		people_dict[ids[j]] = {"prior": pr_j, "posterior": po_j}

	var all_cards: Array = cc.reports + own
	var acceptance: Dictionary = {}
	for j in range(k + ko):
		acceptance[all_cards[j].id] = raw[p]; p += 1

	var piv_count: int = int(raw[p]); p += 1
	var piv_ids: Array = []
	for s in range(piv_count):
		var rep_idx: int = int(raw[p]); p += 1
		piv_ids.append(cc.reports[rep_idx].id)

	var result: Dictionary = {
		"prior": p0,
		"posterior": p1,
		"lr": lr,
		"category": category(lr),
		"impossible": impossible,
		"people": people_dict,
		"consistent": consistent,
		"acceptance": acceptance,
		"credence": credence,
		"movement": cc.movement + test_used.map(func(f): return f.label),
		"factors": cc.factors + test_used,
		"rivals": _rivals(view, people_dict, conclusion),
		"theory_fit": 1.0,
	}
	if need_expand:
		var exp_post: PackedFloat64Array = raw.slice(p, p + universe.size())
		if capture_worlds:
			captured.append({"worlds": exp_post, "people": people_dict.duplicate(true)})
		if theory_needed:
			result["theory_fit"] = _theory_fit(view, case_data, cards, exp_post, listener.get("knowledge", {}))
	if compute_piv:
		result["pivotal"] = piv_ids
	return result

static func _people(view: Dictionary, cc: Dictionary, base: PackedFloat64Array, post: PackedFloat64Array, ns: int) -> Dictionary:
	var ids: Array = Solver.person_ids(view)
	var nt: int = cc.group_bits.size()
	var tb = PackedFloat64Array()
	var ta = PackedFloat64Array()
	tb.resize(nt)
	ta.resize(nt)
	tb.fill(0.0)
	ta.fill(0.0)
	var team: PackedInt32Array = cc.group
	for k in range(base.size()):
		var t: int = team[k / ns]
		tb[t] += base[k]
		ta[t] += post[k]
	var sb = 0.0
	var sa = 0.0
	for t in range(nt):
		sb += tb[t]
		sa += ta[t]
	var teams: Array = cc.group_bits
	var pbs = PackedFloat64Array()
	var pas = PackedFloat64Array()
	pbs.resize(ids.size())
	pas.resize(ids.size())
	pbs.fill(0.0)
	pas.fill(0.0)
	for t in range(nt):
		var evil: int = teams[t]
		var j = 0
		while evil:
			if evil & 1:
				pbs[j] += tb[t]
				pas[j] += ta[t]
			evil >>= 1
			j += 1
	var out = {}
	for j in range(ids.size()):
		var pb: float = pbs[j]
		var pa: float = pas[j]
		out[ids[j]] = {"prior": pb / sb if sb > 0.0 else 0.0, "posterior": pa / sa if sa > 0.0 else 0.0}
	return out

static func _rivals(view: Dictionary, people: Dictionary, conclusion: Dictionary, limit: int = 3) -> Array:
	var ids: Array = people.keys().filter(func(id): return id != conclusion.get("target", conclusion.get("a", "")))
	ids.sort_custom(func(x, y): return people[x].posterior > people[y].posterior)
	return ids.slice(0, limit).map(func(id): return {"id": id, "posterior": people[id].posterior, "shift": people[id].posterior - people[id].prior})

## The player's answers and positions as a theory: the share of the posterior consistent
## with them. 1.0 when the player left everything open.
static func _theory_fit(view: Dictionary, case_data: Dictionary, cards: Array, post: PackedFloat64Array, knowledge: Dictionary = {}) -> float:
	var universe: Array = Solver.universe(view)
	var masks: Array = []
	var has_th_answer: bool = false
	for card in cards:
		var positive: Array = case_data.get("answers", {}).get(card.id, {}).get("positive", [])
		var blocks: Array = case_data.get("answers", {}).get(card.id, {}).get("blocks", [])
		var marked: Array = case_data.get("answers", {}).get(card.id, {}).get("marked", [])
		if Solver.tabled(card) and (not positive.is_empty() or not blocks.is_empty()):
			masks.append(Solver.report_table(view, card, positive, blocks, marked))
		elif card.kind == "town_hall" and str(case_data.get("answers", {}).get(card.id, {}).get("in_play_role", "")) != "":
			has_th_answer = true
	if has_th_answer and view.get("world_options", {}).get("roles", false):
		var live_th: bool = Domain.live(view)
		var th_fit: PackedByteArray = Solver.Roles.fits_table(view, universe, cards, knowledge, case_data.get("answers", {}), live_th)
		if live_th and th_fit.has(0) and cards.any(func(card): return card.kind == "report"):
			var decl_cards: Array = []
			for card in cards:
				var decl: Dictionary = card
				if card.kind == "report":
					decl = card.duplicate()
					decl.kind = "claim"
					decl.data = {}
				decl_cards.append(decl)
			var decl_fit: PackedByteArray = Solver.Roles.fits_table(view, universe, decl_cards, knowledge, case_data.get("answers", {}), true)
			th_fit = th_fit.duplicate()
			for idx_f in range(th_fit.size()):
				if th_fit[idx_f] == 0 and decl_fit[idx_f] != 0:
					th_fit[idx_f] = 1
		masks.append(th_fit)
	var positions: Dictionary = case_data.get("positions", {}).duplicate(true)
	for pcard in cards:
		if pcard.get("kind") == "report" and pcard.get("role", "") == "psychologist" and not case_data.get("reading_challenges", {}).has(pcard.id):
			var pdata_t: Dictionary = pcard.get("data", {}) if pcard.get("data") is Dictionary else {}
			if str(pdata_t.get("mode", "")) == "pair" and pdata_t.get("statements") is Array and pdata_t.statements.size() == 2:
				var pans_t: Dictionary = case_data.get("answers", {}).get(pcard.id, {})
				var fslot_t: String = str(pans_t.get("false_slot", ""))
				var fwhy_t: String = str(pans_t.get("false_reason", ""))
				if fslot_t in ["0", "1"] and fwhy_t in ["lying", "misled"]:
					var st_t: Dictionary = pdata_t.statements[int(fslot_t)]
					var t_src_t: String = str(st_t.get("source", ""))
					if t_src_t != "" and not positions.has(t_src_t):
						positions[t_src_t] = "evil" if fwhy_t == "lying" else "good"
	if masks.is_empty() and positions.is_empty():
		return 1.0
	var fit = 0.0
	var total = 0.0
	for i in range(universe.size()):
		total += post[i]
		if post[i] == 0.0:
			continue
		var ok = true
		for m in masks:
			if m[i] == 0:
				ok = false
				break
		if ok:
			for id in positions:
				if not Solver.position_holds(view, universe[i], id, positions[id], case_data.conclusion.get("at", "")):
					ok = false
					break
		if ok:
			fit += post[i]
	return fit / total if total > 0.0 else 0.0

## Cards the case rests on: removing any one of them would drop the strength category.
static func _pivotal(cc: Dictionary, base: PackedFloat64Array, ns: int, err_for: Callable, p0: float, cat: String) -> Array:
	if cat in ["none", "contradicts"]:
		return []
	var reports: Array = cc.reports
	if reports.size() < 2:
		return reports.map(func(c): return c.id)
	var errs: Array = reports.map(func(c): return err_for.call(c))
	var out: Array = []
	for skip in range(reports.size()):
		var like = _class_like_gd(cc, errs, skip)
		var w = base.duplicate()
		for k in range(w.size()):
			w[k] *= like[k / ns]
		var a = _class_share(cc, w, ns)
		var p1 = a[0] / a[1] if a[1] > 0.0 else 0.0
		var lr = _odds(p1) / _odds(p0) if p0 > 0.0 and p0 < 1.0 else 1.0
		if _rank(category(lr)) < _rank(cat):
			out.append(reports[skip].id)
	return out

static func _rank(cat: String) -> int:
	return ["contradicts", "none", "weak", "moderate", "strong", "damning"].find(cat)

## The case-strength label for the board: the neutral reference listener's category plus a
## one-line reason. Describes the case, not any particular NPC.
static func strength(view: Dictionary, case_data: Dictionary) -> Dictionary:
	return strength_from(evaluate(view, case_data))

## strength() from an evaluation already in hand.
static func strength_from(r: Dictionary) -> Dictionary:
	var reason = ""
	if r.impossible:
		reason = "These cards can't all be true together; something here is false."
	elif r.category in ["weak", "moderate", "strong", "damning"]:
		if r.pivotal.size() == 1:
			reason = "It rests on one card."
		elif r.pivotal.is_empty():
			reason = "Several lines of evidence agree."
		# Several pivotal cards: no reason line. "It rests on N cards together" was cut
		# (Michael, Nov 27, case #136): a Moderate case already draws votes, and needs no excuse.
	return {"category": r.category, "text": category_text(r.category), "reason": reason, "lr": r.lr}
