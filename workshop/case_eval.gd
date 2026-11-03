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
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const Solver = preload("res://workshop/solver.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Graph = preload("res://workshop/case_graph.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Movement = preload("res://workshop/movement_model.gd")
const PublicEvidence = preload("res://workshop/public_evidence.gd")
const SpeechEvidence = preload("res://workshop/speech_evidence.gd")

## Chance a healthy reading from a good source is wrong anyway (unmodelled impairment).
## Kept small: the rules make a good, healthy reading accurate, and the failures the
## rules allow (evil, Delusional, Marked registering) are in the worlds themselves. A
## larger value lets "it was just wrong" explain away any surprising reading.
const DEFAULT_ERR = Tuning.Workshop.DEFAULT_ERR
## The same for the listener's own reading: they know what they saw.
const OWN_ERR = Tuning.Workshop.OWN_ERR
## Likelihood-ratio thresholds for the case-strength categories (neutral listener).
const LR_WEAK = Tuning.Workshop.LR_WEAK
const LR_MODERATE = Tuning.Workshop.LR_MODERATE
const LR_STRONG = Tuning.Workshop.LR_STRONG

static var _cc_handles: Dictionary = {}
static var _cc_handles_epoch: int = -1

static func _ensure_cc_epoch() -> void:
	var b = SolverBackend._bridge()
	if b == null:
		return
	var ep: int = int(b.GetContextEpoch())
	if ep != _cc_handles_epoch:
		_cc_handles.clear()
		_cc_handles_epoch = ep

static func _concl_type_code(c_type: String) -> int:
	match c_type:
		"evil", "suspicious":
			return 0
		"good", "role":
			return 1
		"notrole":
			return 2
		"lied":
			return 3
		"truthful":
			return 4
		"demon":
			return 5
		"minion":
			return 6
		"notdemon":
			return 7
		"marked":
			return 8
		"secret_mod":
			return 9
		_:
			return 10

## Chance of this report's content arising by chance: roughly one over the number of
## different things the gift could have said.
static func chance_content(view: Dictionary, card: Dictionary) -> float:
	var d: Dictionary = card.get("data", {})
	var rdef = Solver.C.role_def(card.get("role", ""))
	if rdef != null:
		if rdef.shape == "ROLE_AT_SITE" and rdef.site_mode == "group_count":
			return 1.0 / float(d.get("group", []).size() + 1)
		if rdef.shape == "GROUP_COUNT":
			if rdef.count_mode == "blocks":
				var blocks = {}
				for p in view.people:
					blocks[p.home] = true
				return 1.0 / float(blocks.size() + 1)
			if rdef.count_mode == "walkers":
				return 1.0 / float(view.people.size())
		if rdef.shape == "NIGHT_ROUTE":
			return 0.25
	return 0.5

static var _valid_cache: Dictionary = {}

## Per world: can this card's source give a healthy reading? (cached per card and universe)
static func _valid_table(view: Dictionary, card: Dictionary) -> PackedByteArray:
	var key = hash([Solver._universe_key(view), card.kind, card.get("source", ""), card.get("observed_at", {}), card.get("role", ""), view.get("timeline", {}), card.get("testimony_only", false), card.get("reported_at"), card.get("duty_only", false)])
	if _valid_cache.has(key):
		return _valid_cache[key]
	if _valid_cache.size() > 512:
		_valid_cache.clear()
	_valid_cache[key] = Solver.valid_table(view, card)
	return _valid_cache[key]

static var _index_cache: Dictionary = {}

## Per universe: the distinct evil teams, and which team each world has (cached).
static func _index(view: Dictionary) -> Dictionary:
	var key = Solver._universe_key(view)
	if _index_cache.has(key):
		return _index_cache[key]
	if _index_cache.size() > 16:
		_index_cache.clear()
	var universe: Array = Solver.universe(view)
	var mode: int = SolverBackend.active_mode()
	var out: Dictionary
	if mode == SolverBackend.Mode.GDSCRIPT:
		out = _index_gd(view, universe)
	elif mode == SolverBackend.Mode.CSHARP:
		out = _index_cs(view, key, universe)
	else:
		out = _index_gd(view, universe)
		var cs_out: Dictionary = _index_cs(view, key, universe)
		var b = SolverBackend._bridge()
		b.VerifyInt32Buffer("CaseEval._index.teams", PackedInt32Array(out.teams), PackedInt32Array(cs_out.teams))
		b.VerifyInt32Buffer("CaseEval._index.team_of", out.team_of, cs_out.team_of)
	_index_cache[key] = out
	return out

static func _index_gd(view: Dictionary, universe: Array) -> Dictionary:
	var teams: Array = []
	var team_idx = {}
	var team_of = PackedInt32Array()
	team_of.resize(universe.size())
	for i in range(universe.size()):
		var evil: int = universe[i].evil
		if universe[i].has("converted") and TimeModel.evil_index(view, universe[i], universe[i].converted, "Current alignment"):
			evil |= 1 << int(universe[i].converted)
		if not team_idx.has(evil):
			team_idx[evil] = teams.size()
			teams.append(evil)
		team_of[i] = team_idx[evil]
	return {"teams": teams, "team_of": team_of}

static func _index_cs(view: Dictionary, u_key: String, universe: Array) -> Dictionary:
	var u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(universe) if u_handle < 0 else PackedInt64Array()
	var curr_conv: bool = Solver._curse_active_at(view, "Current alignment")
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("CaseEval._index", pack_u)
	var raw: PackedInt32Array = SolverBackend._bridge().CaseEvalTeamIndex(u_handle, fallback, curr_conv)
	var t_len: int = raw[0]
	var teams: Array = []
	teams.resize(t_len)
	for i in range(t_len):
		teams[i] = int(raw[1 + i])
	return {"teams": teams, "team_of": raw.slice(1 + t_len)}

## Uniform prior over legal worlds, with no private knowledge: the reference listener.
static func neutral_listener(view: Dictionary) -> Dictionary:
	return {"id": "", "suspicion": {}, "knowledge": {}, "reading_reliability": {}}

static var _premise_cache: Dictionary = {}

static func _premise_mask(view: Dictionary, conclusion: Dictionary) -> PackedByteArray:
	var key = hash([Solver._universe_key(view), Solver.question_inputs(view, conclusion), view.get("timeline", {})])
	if _premise_cache.has(key):
		return _premise_cache[key]
	if _premise_cache.size() > 256:
		_premise_cache.clear()
	_premise_cache[key] = _build_premise_mask(view, conclusion)
	return _premise_cache[key]

static func _build_premise_mask(view: Dictionary, conclusion: Dictionary) -> PackedByteArray:
	if conclusion.type in ["misled", "unreliable"]:
		return Solver.question_table(view, conclusion)
	var mode: int = SolverBackend.active_mode()
	var u_key: String = Solver._universe_key(view)
	var universe: Array = Solver.universe(view)
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _build_premise_mask_gd(view, universe, conclusion)
	var cs_out: PackedByteArray = _build_premise_mask_cs(view, u_key, universe, conclusion)
	if mode == SolverBackend.Mode.CSHARP:
		return cs_out
	var gd_out: PackedByteArray = _build_premise_mask_gd(view, universe, conclusion)
	SolverBackend._bridge().VerifyByteBuffer("CaseEval._build_premise_mask", gd_out, cs_out)
	return gd_out

static func _build_premise_mask_gd(view: Dictionary, universe: Array, conclusion: Dictionary) -> PackedByteArray:
	var m = PackedByteArray()
	m.resize(universe.size())
	var bits = Solver.world_bits(view)
	var index: int = Solver.person_ids(view).find(conclusion.get("target", ""))
	if bits.plain and index >= 0 and conclusion.get("type", "") in ["evil", "suspicious", "good"]:
		# No conversions: alignment is the world's evil bit.
		var bit: int = 1 << index
		var evil: PackedInt64Array = bits.evil
		var want: int = 0 if conclusion.type == "good" else 1
		for i in range(universe.size()):
			m[i] = want if evil[i] & bit else 1 - want
		return m
	for i in range(universe.size()):
		m[i] = 1 if Solver.holds(view, universe[i], conclusion) else 0
	return m

static func _build_premise_mask_cs(view: Dictionary, u_key: String, universe: Array, conclusion: Dictionary) -> PackedByteArray:
	var u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(universe) if u_handle < 0 else PackedInt64Array()
	var is_live: bool = Domain.live(view)
	var c_type: String = str(conclusion.get("type", ""))
	var c_code: int = _concl_type_code(c_type)
	var target_idx: int = Solver.person_index(view, str(conclusion.get("target", "")))
	var sec_mod: int = Solver._secret_mod_code(str(conclusion.get("mod", "")))
	var check_at = conclusion.get("question_at", conclusion.get("at", "")) if c_type in ["lied", "truthful"] else (view.get("alignment_epoch", "") if str(conclusion.get("at", "")) == "" and c_type in ["demon", "minion", "notdemon"] else conclusion.get("at", ""))
	var conv_evil: bool = Solver._curse_active_at(view, check_at)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("Solver.premise_mask", pack_u)
	return SolverBackend._bridge().SolverPremiseMask(u_handle, fallback, is_live, c_code, target_idx, sec_mod, conv_evil)

static func _share(weights: PackedFloat64Array, mask: PackedByteArray) -> Array:
	var yes = 0.0
	var total = 0.0
	for i in range(weights.size()):
		total += weights[i]
		if mask[i] == 1:
			yes += weights[i]
	return [yes, total]

## The chance a reading is wrong despite a good, healthy source, for this listener:
## their reliability for it (impairment, a doubted route, a challenge they accept),
## starting from DEFAULT_ERR, or OWN_ERR for their own reading. A reading their own
## knowledge disowns says nothing.
static func reading_error(view: Dictionary, card: Dictionary, listener: Dictionary, own_ids: Array = []) -> float:
	var rel: Dictionary = listener.get("reading_reliability", {})
	var r = 1.0
	for key in [card.get("accuracy_origin", ""), Solver.semantic_key(card), card.get("fact_id", ""), card.id]:
		if key != "" and rel.has(key):
			r = float(rel[key])
			break
	if (card.has("relay_source") or card.has("route_origin")) and rel.has(card.id) and card.get("accuracy_origin", "") != card.id:
		r *= float(rel[card.id])  # the hearing route itself
	r *= float(listener.get("challenge_reports", {}).get(card.id, 1.0)) * float(listener.get("challenge_sources", {}).get(card.get("source", ""), 1.0))
	if card.kind == "report" and TimeModel.disowned(view, card, listener.get("knowledge", {}).get("known_events", [])):
		r = 0.0
	var base_err: float = OWN_ERR if card.id in own_ids else DEFAULT_ERR
	return clampf(1.0 - clampf(r, 0.0, 1.0) * (1.0 - base_err), OWN_ERR, 1.0)

## How far the evidence moved a probability toward certainty (+1: from p0 all the way
## to yes; -1: all the way to no; 0: no change).
static func shift(p0: float, p1: float) -> float:
	if p1 >= p0:
		return (p1 - p0) / (1.0 - p0) if p0 < 1.0 else 0.0
	return (p1 - p0) / p0 if p0 > 0.0 else 0.0

static func _odds(p: float) -> float:
	p = clampf(p, 1e-9, 1.0 - 1e-9)
	return p / (1.0 - p)

## Strength category from a likelihood ratio on the premise.
static func category(lr: float) -> String:
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
	return ""

## Evaluate a case for one listener. Returns:
##   prior, posterior    P(premise) before and after the case's evidence
##   lr, category        likelihood ratio on the premise and its category
##   people              per person {prior, posterior} probability of being evil
##   rivals              the people (other than the target) most likely evil after the case
##   theory_fit          how much of the posterior agrees with the player's answers/positions
##   pivotal             card ids whose removal would drop the category (reference listener)
##   impossible          no world survives the case's hard facts
static func evaluate(view: Dictionary, case_data: Dictionary, listener: Dictionary = {}) -> Dictionary:
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
	var err_for = func(card: Dictionary) -> float:
		return reading_error(view, card, listener, own_ids)
	var cc = compile(view, cards, case_data, own)
	var oc = _own_counts(view, cc, own)
	# Per class: prior (team odds, role fits) and the case's likelihood.
	var team_prior = _team_prior(view, listener)
	var fits = _class_fits(view, cc, cards, knowledge)
	# The "before" side of the case: role knowledge without the case's own cards. Role-
	# based readings (Seer, Archivist, Clerk...) act through the role check; applied to
	# both sides they cancel, and the reading never moved anyone (playtest 37291).
	var fits_before = _class_fits(view, cc, [], knowledge)
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

	var mode: int = SolverBackend.active_mode()
	if mode != SolverBackend.Mode.GDSCRIPT:
		_ensure_cc_epoch()
		var cc_h: int = int(_cc_handles.get(cc.key, -1))
		if cc_h >= 0:
			var cs_res: Dictionary = _evaluate_posterior_cs(view, case_data, cards, conclusion, listener, own_ids, own, err_for, cc, cc_h, oc, team_prior, fits, fits_before)
			if mode == SolverBackend.Mode.CSHARP:
				return cs_res
			var gd_res: Dictionary = _evaluate_posterior_gd(view, case_data, cards, conclusion, listener, own_ids, own, err_for, cc, oc, team_prior, fits, fits_before)
			_verify_evaluate_result(gd_res, cs_res)
			return gd_res
	return _evaluate_posterior_gd(view, case_data, cards, conclusion, listener, own_ids, own, err_for, cc, oc, team_prior, fits, fits_before)

static func _evaluate_posterior_gd(view: Dictionary, case_data: Dictionary, cards: Array, conclusion: Dictionary, listener: Dictionary, own_ids: Array, own: Array, err_for: Callable, cc: Dictionary, oc: Dictionary, team_prior: PackedFloat64Array, fits: PackedFloat64Array, fits_before: PackedFloat64Array) -> Dictionary:
	var nc: int = cc.team.size()
	var ns: int = oc.states
	var case_like = _class_like_gd(cc, cc.reports.map(func(c): return err_for.call(c)), -1)
	var own_like = _state_like(view, own, own.map(func(c): return err_for.call(c)), oc.codes)
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
	if not case_data.get("positions", {}).is_empty() or case_data.get("answers", {}).values().any(func(a): return not a.get("positive", []).is_empty() or not a.get("blocks", []).is_empty()):
		result["theory_fit"] = _theory_fit(view, case_data, cards, _expand(cc, oc, post))
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
		own_qs[i] = chance_content(view, own[i])

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
	var need_expand: bool = not case_data.get("positions", {}).is_empty() or case_data.get("answers", {}).values().any(func(a): return not a.get("positive", []).is_empty() or not a.get("blocks", []).is_empty())

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
		oc.counts, oc.of, flat_own_codes, route_credits, test_lrs, bias_factor
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
		result["theory_fit"] = _theory_fit(view, case_data, cards, exp_post)
	if compute_piv:
		result["pivotal"] = piv_ids
	return result

static func _verify_evaluate_result(gd_res: Dictionary, cs_res: Dictionary) -> void:
	var b = SolverBackend._bridge()
	b.VerifyScalarFloat64("CaseEval.evaluate.prior", gd_res.prior, cs_res.prior, 0.0)
	b.VerifyScalarFloat64("CaseEval.evaluate.posterior", gd_res.posterior, cs_res.posterior, 0.0)
	b.VerifyScalarFloat64("CaseEval.evaluate.lr", gd_res.lr, cs_res.lr, 0.0)
	b.VerifyScalarBool("CaseEval.evaluate.impossible", gd_res.impossible, cs_res.impossible)
	b.VerifyScalarBool("CaseEval.evaluate.consistent", gd_res.consistent, cs_res.consistent)
	b.VerifyScalarFloat64("CaseEval.evaluate.credence", gd_res.credence, cs_res.credence, 0.0)
	b.VerifyScalarFloat64("CaseEval.evaluate.theory_fit", gd_res.theory_fit, cs_res.theory_fit, 0.0)
	var gd_p := PackedFloat64Array()
	var cs_p := PackedFloat64Array()
	for pid in gd_res.people:
		gd_p.append(gd_res.people[pid].prior)
		gd_p.append(gd_res.people[pid].posterior)
		cs_p.append(cs_res.people[pid].prior)
		cs_p.append(cs_res.people[pid].posterior)
	b.VerifyFloat64Buffer("CaseEval.evaluate.people", gd_p, cs_p, 0.0)
	var gd_acc := PackedFloat64Array()
	var cs_acc := PackedFloat64Array()
	for cid in gd_res.acceptance:
		gd_acc.append(gd_res.acceptance[cid])
		cs_acc.append(cs_res.acceptance[cid])
	b.VerifyFloat64Buffer("CaseEval.evaluate.acceptance", gd_acc, cs_acc, 0.0)
	if gd_res.has("pivotal"):
		b.VerifyScalarBool("CaseEval.evaluate.pivotal", gd_res.pivotal == cs_res.pivotal, true)

static var _compiled: Dictionary = {}

## Per presentation: the universe grouped into classes that every listener weighs alike.
## A class shares the evil team, what the role check reads, each report card's state
## (holds / healthy but wrong / source can't read healthily), the hard event facts and
## the premise. Listener-specific work is then per class, not per world.
## known: the listener's own readings, which can complete a test factor's route.
static func compile(view: Dictionary, cards: Array, case_data: Dictionary, known: Array = []) -> Dictionary:
	if not SolverBackend.profiling_enabled:
		return _compile_impl(view, cards, case_data, known)
	var _st: int = SolverBackend.begin_stage("case_eval_compile")
	var _res: Dictionary = _compile_impl(view, cards, case_data, known)
	SolverBackend.end_stage(_st)
	return _res

static func _compile_impl(view: Dictionary, cards: Array, case_data: Dictionary, known: Array = []) -> Dictionary:
	var conclusion: Dictionary = case_data.conclusion
	var key_input = [view.get("trace_assessments", []), Solver._universe_key(view), view.get("timeline", {}), view.people, conclusion, case_data.get("citations", {}), case_data.get("test_factors", []),
		known.map(func(c): return c.get("fact_id", c.id)) if not case_data.get("test_factors", []).is_empty() else [],
		cards.map(func(c): return [c.get("fact_id", c.id), c.kind, c.get("source", ""), c.get("role", ""), c.get("observed_at", {}), c.get("data", {}), c.get("event", ""), c.has("relay_source"), c.get("quoted", false), c.get("block", ""), c.get("night", -1), c.get("subject", ""), c.get("subjects", []), c.get("duty_only", false)])]
	if cards.any(func(c): return c.has("hearing_weight")):
		key_input.append(cards.map(func(c): return c.get("hearing_weight", 1.0)))
	if cards.any(func(c): return c.get("testimony_only", false)):
		key_input.append(cards.map(func(c): return [c.get("testimony_only", false), c.get("reported_at")]))
	var key = hash(key_input)
	if _compiled.has(key) and _compiled[key].input == key_input:
		return _compiled[key]
	if _compiled.size() > 32:
		_compiled.clear()
		_cc_handles.clear()
		var b_clr = SolverBackend._bridge()
		if b_clr != null:
			b_clr.ClearCompiledCases()

	var universe: Array = Solver.universe(view)
	var n: int = universe.size()
	var reports: Array = []
	var tables: Array = []
	var valids: Array = []
	var dead = PackedByteArray()
	dead.resize(n)
	dead.fill(0)
	for card in cards:
		if not Solver.tabled(card):
			continue
		var table: PackedByteArray = Solver.report_table(view, card)
		if card.kind != "report":
			# A public event (the curse) is a fact, not a fallible reading.
			for i in range(n):
				if table[i] == 0:
					dead[i] = 1
			continue
		reports.append(card)
		tables.append(table)
		valids.append(_valid_table(view, card))
	var premise = _premise_mask(view, conclusion)
	var live: bool = Domain.live(view)
	var movement: Array = Movement.factors(view, cards, case_data).duplicate()
	movement.append_array(PublicEvidence.factors(view))
	movement.append_array(SpeechEvidence.factors(cards))

	var semantic = {}
	for card in cards + known:
		semantic[Solver.semantic_key(card)] = true
	var tests: Array = []
	for factor in case_data.get("test_factors", []):
		if is_zero_approx(float(factor.log2_ratio)):
			continue
		var routes: Array = factor.routes.filter(func(route): return route.all(func(id): return semantic.has(Solver.semantic_key(Solver.card_by_id(view, id)))))
		if not routes.is_empty():
			var f: Dictionary = factor.duplicate(true)
			f["epoch"] = conclusion.get("at", "")
			f.routes = routes
			tests.append(f)

	var movement_ok: bool = _movement_ok(view, cards, live)
	var q_arr: Array = reports.map(func(c): return chance_content(view, c))
	var mode: int = SolverBackend.active_mode()
	var out: Dictionary
	if mode == SolverBackend.Mode.GDSCRIPT:
		out = _compile_classes_gd(view, universe, key_input, key, conclusion, cards, reports, tables, valids, dead, premise, live, movement, movement_ok, tests, q_arr)
	elif mode == SolverBackend.Mode.CSHARP:
		out = _compile_classes_cs(view, universe, key_input, key, conclusion, cards, reports, tables, valids, dead, premise, live, movement, movement_ok, tests, q_arr)
	else:
		out = _compile_classes_gd(view, universe, key_input, key, conclusion, cards, reports, tables, valids, dead, premise, live, movement, movement_ok, tests, q_arr)
		var cs_out: Dictionary = _compile_classes_cs(view, universe, key_input, key, conclusion, cards, reports, tables, valids, dead, premise, live, movement, movement_ok, tests, q_arr)
		var b = SolverBackend._bridge()
		b.VerifyInt32Buffer("CaseEval.compile.team", out.team, cs_out.team)
		b.VerifyInt32Buffer("CaseEval.compile.rep", out.rep, cs_out.rep)
		b.VerifyInt32Buffer("CaseEval.compile.group", out.group, cs_out.group)
		b.VerifyInt32Buffer("CaseEval.compile.group_bits", PackedInt32Array(out.group_bits), PackedInt32Array(cs_out.group_bits))
		b.VerifyInt32Buffer("CaseEval.compile.class_of", out.class_of, cs_out.class_of)
		b.VerifyFloat64Buffer("CaseEval.compile.count", out.count, cs_out.count, 0.0)
		b.VerifyFloat64Buffer("CaseEval.compile.move", out.move, cs_out.move, 0.0)
		b.VerifyByteBuffer("CaseEval.compile.premise", out.premise, cs_out.premise)
		b.VerifyByteBuffer("CaseEval.compile.dead", out.dead, cs_out.dead)
		b.VerifyByteBuffer("CaseEval.compile.states", out.states, cs_out.states)
		b.VerifyByteBuffer("CaseEval.compile.test_hold", out.test_hold, cs_out.test_hold)
	_compiled[key] = out
	return out

static func _compile_classes_gd(view: Dictionary, universe: Array, key_input: Array, key: int, conclusion: Dictionary, cards: Array, reports: Array, tables: Array, valids: Array, dead: PackedByteArray, premise: PackedByteArray, live: bool, movement: Array, movement_ok: bool, tests: Array, q_arr: Array) -> Dictionary:
	var n: int = universe.size()
	var ix = _index(view)
	var people: int = view.people.size()
	var roles_on: bool = view.get("world_options", {}).get("roles", false)
	var ids: Array = Solver.person_ids(view)
	var seer: bool = Solver.Roles.seer_flag(cards)
	var mediums: int = Solver.Roles.relay_mediums(ids, cards)
	var walkers: int = Solver.Roles.sleepwalk_claimants(ids, cards)
	var k: int = reports.size()
	var index = {}
	var team = PackedInt32Array()
	var rep = PackedInt32Array()
	var count = PackedFloat64Array()
	var prem = PackedByteArray()
	var states = PackedByteArray()  # class-major, k per class
	var is_dead = PackedByteArray()
	var class_of = PackedInt32Array()
	class_of.resize(n)
	var digits = PackedByteArray()
	digits.resize(k)
	var radix: int = int(pow(3, k))
	var rm_bound: int = (1 << people) * (people + 2) * (people + 2) * ((1 << people) if mediums != 0 else 1) * ((1 << people) if walkers != 0 else 1)
	if view.get("chronology", {}).has("curse"):
		rm_bound *= people + 1
	var int_keys: bool = k <= 16 and float(rm_bound) * float(radix) * 4.0 < 9.0e18
	var codes = PackedInt64Array()
	codes.resize(n)
	codes.fill(0)
	for c in range(k):
		var t: PackedByteArray = tables[c]
		var v: PackedByteArray = valids[c]
		for i in range(n):
			codes[i] = codes[i] * 3 + (0 if t[i] == 1 else (1 if v[i] == 1 else 2))
	var rms: PackedInt64Array = _coarse(view, seer, mediums, walkers) if roles_on else Solver.world_bits(view).evil
	if not roles_on and view.get("chronology", {}).has("curse"):
		rms = rms.duplicate()
		for i in range(n):
			rms[i] = rms[i] * (people + 1) + int(universe[i].converted) + 1
	if not live:
		rms = PackedInt64Array()
		rms.resize(n)
		for i in range(n):
			rms[i] = i
	var test_hold = PackedByteArray()
	var team_of: PackedInt32Array = ix.team_of
	var plain_bits: bool = Solver.world_bits(view).plain
	var group = PackedInt32Array()
	var group_bits: Array = ix.teams if plain_bits else []
	var group_index = {}
	for i in range(n):
		var code: int = codes[i]
		var rm: int = rms[i]
		var ck = ((rm * radix + code) * 2 + premise[i]) * 2 + dead[i] if int_keys else [rm, code, premise[i], dead[i]]
		var c_id = index.get(ck, -1)
		if c_id < 0:
			c_id = team.size()
			index[ck] = c_id
			team.append(team_of[i])
			if plain_bits:
				group.append(team_of[i])
			else:
				var bits = 0
				for j in range(people):
					if TimeModel.evil_index(view, universe[i], j, conclusion.get("at", view.get("alignment_epoch", ""))):
						bits |= 1 << j
				var g_id = group_index.get(bits, -1)
				if g_id < 0:
					g_id = group_bits.size()
					group_index[bits] = g_id
					group_bits.append(bits)
				group.append(g_id)
			rep.append(i)
			count.append(0.0)
			prem.append(premise[i])
			is_dead.append(dead[i])
			for f in tests:
				var target: int = Solver.person_index(view, f.target)
				test_hold.append(1 if target >= 0 and TimeModel.evil_at(view, universe[i], f.target, f.epoch) else 0)
			for c in range(k - 1, -1, -1):
				digits[c] = code % 3
				code /= 3
			states.append_array(digits)
		count[c_id] += 1.0
		class_of[i] = c_id
	var u_handle: int = SolverBackend.get_universe_handle(Solver._universe_key(view), universe)
	var move: PackedFloat64Array = _movement_scores(view, universe, rep, u_handle, movement)
	var out = {"input": key_input, "key": key, "reports": reports, "tables": tables, "valids": valids, "move": move,
		"movement": movement.map(func(f): return f.label), "factors": movement, "tests": tests, "test_hold": test_hold, "group": group, "group_bits": group_bits, "movement_ok": movement_ok,
		"q": q_arr, "team": team, "rep": rep, "count": count,
		"premise": prem, "dead": is_dead, "states": states, "class_of": class_of, "k": k}
	for factor in movement:
		out.movement.append_array(factor.get("relationships", []))
	return out

static func _compile_classes_cs(view: Dictionary, universe: Array, key_input: Array, key: int, conclusion: Dictionary, cards: Array, reports: Array, tables: Array, valids: Array, dead: PackedByteArray, premise: PackedByteArray, live: bool, movement: Array, movement_ok: bool, tests: Array, q_arr: Array) -> Dictionary:
	_ensure_cc_epoch()
	var u_key: String = Solver._universe_key(view)
	var u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(universe) if u_handle < 0 else PackedInt64Array()
	var ids: Array = Solver.person_ids(view)
	var n_people: int = ids.size()
	var roles_on: bool = bool(view.get("world_options", {}).get("roles", false))
	var has_curse: bool = view.get("chronology", {}).has("curse")
	var seer: bool = Solver.Roles.seer_flag(cards)
	var mediums: int = Solver.Roles.relay_mediums(ids, cards)
	var walkers: int = Solver.Roles.sleepwalk_claimants(ids, cards)
	var curr_conv: bool = Solver._curse_active_at(view, "Current alignment")
	var concl_at = conclusion.get("at", view.get("alignment_epoch", ""))
	var concl_conv: bool = Solver._curse_active_at(view, concl_at)
	var k: int = reports.size()

	var flat_tables := PackedByteArray()
	var flat_valids := PackedByteArray()
	if k == 1:
		flat_tables = tables[0]
		flat_valids = valids[0]
	elif k > 1:
		for i in range(k):
			flat_tables.append_array(tables[i])
			flat_valids.append_array(valids[i])

	var q_packed := PackedFloat64Array()
	q_packed.resize(k)
	for i in range(k):
		q_packed[i] = float(q_arr[i])

	var test_specs := PackedInt32Array()
	test_specs.resize(tests.size() * 2)
	for j in range(tests.size()):
		test_specs[j * 2] = Solver.person_index(view, str(tests[j].target))
		test_specs[j * 2 + 1] = 1 if Solver._curse_active_at(view, tests[j].epoch) else 0

	var move_specs := PackedInt32Array()
	var move_doubles := PackedFloat64Array()
	move_specs.resize(movement.size() * 4)
	move_doubles.resize(movement.size() * 2)
	for fi in range(movement.size()):
		var f: Dictionary = movement[fi]
		var m_off: int = fi * 4
		if f.get("joint_live", false):
			move_specs[m_off] = 0
			move_specs[m_off + 1] = Movement.Live._ensure_factor_handle(f)
			move_specs[m_off + 2] = 0
			move_specs[m_off + 3] = 0
			move_doubles[fi * 2] = 0.0
			move_doubles[fi * 2 + 1] = 1.0
		else:
			var t_idx: int = Solver.person_index(view, str(f.target))
			var f_ep = f.get("epoch", view.get("alignment_epoch", ""))
			var is_mm: bool = f.get("origin", "") == "movement_model"
			move_specs[m_off] = 1
			move_specs[m_off + 1] = t_idx
			move_specs[m_off + 2] = 1 if Solver._curse_active_at(view, f_ep) else 0
			move_specs[m_off + 3] = 1 if is_mm else 0
			move_doubles[fi * 2] = float(f.log2_ratio)
			move_doubles[fi * 2 + 1] = (maxf(float(f.good_marked_likelihood), 1e-12) / maxf(float(f.good_likelihood), 1e-12)) if is_mm else 1.0

	var header := PackedInt32Array([
		n_people,
		1 if live else 0,
		1 if roles_on else 0,
		1 if has_curse else 0,
		1 if seer else 0,
		mediums,
		walkers,
		1 if curr_conv else 0,
		1 if concl_conv else 0,
		k,
		1 if movement_ok else 0,
	])

	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("CaseEval.compile", pack_u)
	var b = SolverBackend._bridge()
	var cc_h: int = int(b.CaseEvalCompile(u_handle, fallback, header, dead, premise, flat_tables, flat_valids, q_packed, test_specs, move_specs, move_doubles))
	_cc_handles[key] = cc_h

	var raw_ints: PackedInt32Array = b.CaseEvalGetCompiledInts(cc_h)
	var raw_bytes: PackedByteArray = b.CaseEvalGetCompiledBytes(cc_h)
	var raw_doubles: PackedFloat64Array = b.CaseEvalGetCompiledDoubles(cc_h)

	var nc: int = raw_ints[0]
	var n_worlds: int = raw_ints[1]
	var n_gbits: int = raw_ints[2]
	var p: int = 3
	var team: PackedInt32Array = raw_ints.slice(p, p + nc); p += nc
	var rep: PackedInt32Array = raw_ints.slice(p, p + nc); p += nc
	var group: PackedInt32Array = raw_ints.slice(p, p + nc); p += nc
	var group_bits: Array = []
	group_bits.resize(n_gbits)
	for gi in range(n_gbits):
		group_bits[gi] = int(raw_ints[p + gi])
	p += n_gbits
	var class_of: PackedInt32Array = raw_ints.slice(p, p + n_worlds)

	var bp: int = 0
	var prem: PackedByteArray = raw_bytes.slice(bp, bp + nc); bp += nc
	var is_dead: PackedByteArray = raw_bytes.slice(bp, bp + nc); bp += nc
	var s_len: int = nc * k
	var states: PackedByteArray = raw_bytes.slice(bp, bp + s_len); bp += s_len
	var t_len: int = nc * tests.size()
	var test_hold: PackedByteArray = raw_bytes.slice(bp, bp + t_len)

	var count: PackedFloat64Array = raw_doubles.slice(0, nc)
	var move: PackedFloat64Array = raw_doubles.slice(nc, 2 * nc)

	var out = {"input": key_input, "key": key, "reports": reports, "tables": tables, "valids": valids, "move": move,
		"movement": movement.map(func(f): return f.label), "factors": movement, "tests": tests, "test_hold": test_hold, "group": group, "group_bits": group_bits, "movement_ok": movement_ok,
		"q": q_arr, "team": team, "rep": rep, "count": count,
		"premise": prem, "dead": is_dead, "states": states, "class_of": class_of, "k": k}
	for factor in movement:
		out.movement.append_array(factor.get("relationships", []))
	return out

static var _coarse_cache: Dictionary = {}

## Per universe: each world's role-check mask (Roles.coarse_mask), for these flags.
static func _coarse(view: Dictionary, seer: bool, mediums: int, walkers: int = 0) -> PackedInt64Array:
	var key = hash([Solver._universe_key(view), seer, mediums, walkers])
	if _coarse_cache.has(key):
		return _coarse_cache[key]
	if _coarse_cache.size() > 16:
		_coarse_cache.clear()
	var u_key: String = Solver._universe_key(view)
	var universe: Array = Solver.universe(view)
	var people: int = view.people.size()
	var u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var out: PackedInt64Array = Solver.Roles.coarse_masks(people, universe, seer, mediums, walkers, u_handle)
	_coarse_cache[key] = out
	return out

## A world's movement/trace likelihood ratio (good everywhere = 1), as the support
## model's world_score without its prior ranks.
static func _movement_score(view: Dictionary, world: Dictionary, factors: Array) -> float:
	var score = 1.0
	for factor in factors:
		if factor.get("joint_live", false):
			score *= Movement.Live.score(world, factor)
			continue
		var target: int = Solver.person_index(view, factor.target)
		if target >= 0 and TimeModel.evil_at(view, world, factor.target, factor.get("epoch", view.get("alignment_epoch", ""))):
			score *= pow(2.0, float(factor.log2_ratio))
		elif target >= 0 and factor.get("origin", "") == "movement_model" and world.marked == target:
			score *= maxf(factor.good_marked_likelihood, 1e-12) / maxf(factor.good_likelihood, 1e-12)
	return score

static func _movement_scores(view: Dictionary, universe: Array, rep: PackedInt32Array, u_handle: int, factors: Array) -> PackedFloat64Array:
	var nc: int = rep.size()
	var out := PackedFloat64Array()
	out.resize(nc)
	out.fill(1.0)
	if nc == 0 or factors.is_empty():
		return out
	var rep_worlds: Array = []
	rep_worlds.resize(nc)
	for c in range(nc):
		rep_worlds[c] = universe[rep[c]]
	for factor in factors:
		if factor.get("joint_live", false):
			var j_scores: PackedFloat64Array = Movement.Live.scores(rep_worlds, factor, u_handle, rep)
			for c in range(nc):
				out[c] *= j_scores[c]
			continue
		var target: int = Solver.person_index(view, factor.target)
		if target < 0:
			continue
		var ep = factor.get("epoch", view.get("alignment_epoch", ""))
		var ratio: float = pow(2.0, float(factor.log2_ratio))
		var is_mm: bool = factor.get("origin", "") == "movement_model"
		for c in range(nc):
			var world: Dictionary = rep_worlds[c]
			if TimeModel.evil_at(view, world, factor.target, ep):
				out[c] *= ratio
			elif is_mm and world.marked == target:
				out[c] *= maxf(factor.good_marked_likelihood, 1e-12) / maxf(factor.good_likelihood, 1e-12)
	return out

## Fixture views: sightings and alibis that can't all be true leave no consistent world.
## (Live views check routes inside the role check.)
static func _movement_ok(view: Dictionary, cards: Array, live: bool) -> bool:
	if live:
		return true
	return Solver.solve(view, cards).get("movement_ok", true)

## How far the listener credits a test factor's best route: the product over its cards
## of each reading's reliability (0 when they reject one outright).
static func _route_credit(view: Dictionary, factor: Dictionary, listener: Dictionary, own_ids: Array) -> float:
	var best = 0.0
	for route in factor.routes:
		var credit = 1.0
		for id in route:
			var card: Dictionary = Solver.card_by_id(view, id)
			if card.kind == "report":
				credit *= (1.0 - reading_error(view, card, listener, own_ids)) / (1.0 - (OWN_ERR if id in own_ids else DEFAULT_ERR))
			elif listener.get("reading_reliability", {}).has(Solver.semantic_key(card)):
				credit *= float(listener.reading_reliability[Solver.semantic_key(card)])
		best = maxf(best, clampf(credit, 0.0, 1.0))
	return best

## Test factors per class: 2^log2_ratio where the target is evil, mixed with no
## effect by how far the listener credits the route.
static func _test_like(view: Dictionary, cc: Dictionary, listener: Dictionary, own_ids: Array) -> PackedFloat64Array:
	var nc: int = cc.team.size()
	var out = PackedFloat64Array()
	out.resize(nc)
	out.fill(1.0)
	var tests: Array = cc.tests
	var m: int = tests.size()
	if m == 0:
		return out
	var hold: PackedByteArray = cc.test_hold
	for j in range(m):
		var w: float = _route_credit(view, tests[j], listener, own_ids)
		var ratio: float = pow(2.0, float(tests[j].log2_ratio))
		for c in range(nc):
			if hold[c * m + j] == 1:
				out[c] *= (1.0 - w) + w * ratio
	return out

static var _own_cache: Dictionary = {}

## Class counts refined by the listener's own private readings' states (3^own states).
## Depends only on which own cards there are, so listeners holding the same share it.
static func _own_counts(view: Dictionary, cc: Dictionary, own: Array) -> Dictionary:
	if own.is_empty():
		return {"states": 1, "counts": cc.count, "of": PackedInt32Array(), "codes": [PackedByteArray()]}
	var key = hash([cc.key, own.map(func(c): return c.get("fact_id", c.id))])
	if _own_cache.has(key):
		return _own_cache[key]
	if _own_cache.size() > 64:
		_own_cache.clear()
	var tables: Array = own.map(func(c): return Solver.report_table(view, c))
	var valids: Array = own.map(func(c): return _valid_table(view, c))
	var mode: int = SolverBackend.active_mode()
	var out: Dictionary
	if mode == SolverBackend.Mode.GDSCRIPT:
		out = _own_counts_gd(cc, own, tables, valids)
	elif mode == SolverBackend.Mode.CSHARP:
		out = _own_counts_cs(cc, own, tables, valids)
	else:
		out = _own_counts_gd(cc, own, tables, valids)
		var cs_out: Dictionary = _own_counts_cs(cc, own, tables, valids)
		var b = SolverBackend._bridge()
		b.VerifyScalarInt64("CaseEval._own_counts.states", out.states, cs_out.states)
		b.VerifyInt32Buffer("CaseEval._own_counts.of", out.of, cs_out.of)
		b.VerifyFloat64Buffer("CaseEval._own_counts.counts", out.counts, cs_out.counts, 0.0)
	_own_cache[key] = out
	return out

static func _own_counts_gd(cc: Dictionary, own: Array, tables: Array, valids: Array) -> Dictionary:
	var class_of: PackedInt32Array = cc.class_of
	var n: int = class_of.size()
	var of = PackedInt32Array()
	of.resize(n)
	var codes: Array = []
	var indices = {}
	var k: int = own.size()
	if k <= 39:
		for i in range(n):
			var packed: int = 0
			for c in range(k):
				packed = packed * 3 + (0 if tables[c][i] == 1 else (1 if valids[c][i] == 1 else 2))
			if not indices.has(packed):
				var code = PackedByteArray()
				code.resize(k)
				for c in range(k):
					code[c] = 0 if tables[c][i] == 1 else (1 if valids[c][i] == 1 else 2)
				indices[packed] = codes.size()
				codes.append(code)
			of[i] = indices[packed]
	else:
		for i in range(n):
			var code = PackedByteArray()
			code.resize(k)
			for c in range(k):
				code[c] = 0 if tables[c][i] == 1 else (1 if valids[c][i] == 1 else 2)
			if not indices.has(code):
				indices[code] = codes.size()
				codes.append(code)
			of[i] = indices[code]
	var ns = codes.size()
	var counts = PackedFloat64Array()
	counts.resize(cc.team.size() * ns)
	counts.fill(0.0)
	for i in range(n):
		counts[class_of[i] * ns + of[i]] += 1.0
	return {"states": ns, "counts": counts, "of": of, "codes": codes}

static func _own_counts_cs(cc: Dictionary, own: Array, tables: Array, valids: Array) -> Dictionary:
	_ensure_cc_epoch()
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var cc_h: int = int(_cc_handles.get(cc.key, -1))
	var k_own: int = own.size()
	var flat_tables := PackedByteArray()
	var flat_valids := PackedByteArray()
	if k_own == 1:
		flat_tables = tables[0]
		flat_valids = valids[0]
	elif k_own > 1:
		for i in range(k_own):
			flat_tables.append_array(tables[i])
			flat_valids.append_array(valids[i])
	var fb_class_of: PackedInt32Array = cc.class_of if cc_h < 0 else PackedInt32Array()
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("CaseEval._own_counts", pack_u)
	var b = SolverBackend._bridge()
	var ns: int = int(b.CaseEvalCompileOwnCounts(cc_h, fb_class_of, cc.team.size(), k_own, flat_tables, flat_valids))
	var of: PackedInt32Array = b.CaseEvalGetLastOwnOf()
	var flat_codes: PackedByteArray = b.CaseEvalGetLastOwnFlatCodes()
	var counts: PackedFloat64Array = b.CaseEvalGetLastOwnCounts()
	var codes: Array = []
	codes.resize(ns)
	for s in range(ns):
		codes[s] = flat_codes.slice(s * k_own, (s + 1) * k_own)
	return {"states": ns, "counts": counts, "of": of, "codes": codes, "_flat_codes": flat_codes}

## Likelihood factor of one state for a card: holds, healthy but wrong, or no healthy reading.
static func _factor(st: int, err: float, q: float) -> float:
	match st:
		0: return (1.0 - err) + err * q
		1: return err * q
	return q

## The case's likelihood per class. skip >= 0 leaves that report card out (pivotal check).
static func _class_like(cc: Dictionary, errs: Array, skip: int) -> PackedFloat64Array:
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _class_like_gd(cc, errs, skip)
	var cs_out: PackedFloat64Array = _class_like_cs(cc, errs, skip)
	if mode == SolverBackend.Mode.CSHARP:
		return cs_out
	var gd_out: PackedFloat64Array = _class_like_gd(cc, errs, skip)
	SolverBackend._bridge().VerifyFloat64Buffer("CaseEval._class_like", gd_out, cs_out, 0.0)
	return gd_out

static func _class_like_gd(cc: Dictionary, errs: Array, skip: int) -> PackedFloat64Array:
	var nc: int = cc.team.size()
	var k: int = cc.k
	var like = PackedFloat64Array()
	like.resize(nc)
	var states: PackedByteArray = cc.states
	var dead: PackedByteArray = cc.dead
	var q: Array = cc.q
	var f = PackedFloat64Array()
	f.resize(3 * k)
	for c in range(k):
		for st in range(3):
			f[3 * c + st] = 1.0 if c == skip else _factor(st, errs[c], q[c])
	for x in range(nc):
		if dead[x] == 1:
			like[x] = 0.0
			continue
		var v = 1.0
		var at: int = x * k
		for c in range(k):
			v *= f[3 * c + states[at + c]]
		like[x] = v
	return like

static func _class_like_cs(cc: Dictionary, errs: Array, skip: int) -> PackedFloat64Array:
	_ensure_cc_epoch()
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var cc_h: int = int(_cc_handles.get(cc.key, -1))
	var k: int = int(cc.k)
	var errs_p := PackedFloat64Array()
	errs_p.resize(k)
	for i in range(k):
		errs_p[i] = float(errs[i])
	var fb_states: PackedByteArray = cc.states if cc_h < 0 else PackedByteArray()
	var fb_dead: PackedByteArray = cc.dead if cc_h < 0 else PackedByteArray()
	var fb_q := PackedFloat64Array()
	if cc_h < 0:
		fb_q.resize(k)
		for i in range(k):
			fb_q[i] = float(cc.q[i])
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("CaseEval._class_like", pack_u)
	return SolverBackend._bridge().CaseEvalClassLike(cc_h, cc.team.size(), k, fb_states, fb_dead, fb_q, errs_p, skip)

## The likelihood of each own-reading state (decoded from base 3).
static func _state_like(view: Dictionary, own: Array, errs: Array, codes: Array) -> PackedFloat64Array:
	var out = PackedFloat64Array()
	out.resize(codes.size())
	var qs: Array = own.map(func(c): return chance_content(view, c))
	for o in range(codes.size()):
		var v = 1.0
		for c in range(own.size() - 1, -1, -1):
			v *= _factor(codes[o][c], errs[c], qs[c])
		out[o] = v
	return out

## Per team: the listener's odds that exactly this team is evil (known-good people zero).
static func _team_prior(view: Dictionary, listener: Dictionary) -> PackedFloat64Array:
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _team_prior_gd(view, listener)
	var cs_out: PackedFloat64Array = _team_prior_cs(view, listener)
	if mode == SolverBackend.Mode.CSHARP:
		return cs_out
	var gd_out: PackedFloat64Array = _team_prior_gd(view, listener)
	SolverBackend._bridge().VerifyFloat64Buffer("CaseEval._team_prior", gd_out, cs_out, 0.0)
	return gd_out

static func _team_prior_gd(view: Dictionary, listener: Dictionary) -> PackedFloat64Array:
	var ix = _index(view)
	var ids: Array = Solver.person_ids(view)
	var odds: Array = []
	for id in ids:
		var raw: float = float(listener.get("suspicion", {}).get(id, 0.3))
		var sv: float = clampf(raw, 0.02, 0.98)
		# Trust in a person halves (full trust) or doubles (none) their odds of evil.
		var trust: float = float(listener.get("npc_trust", {}).get(id, 0.5))
		var base: float = sv / (1.0 - sv) if prior_k < 0.0 else exp(prior_k * clampf(raw, 0.0, 1.5))
		odds.append(base * pow(2.0, -2.0 * (clampf(trust, 0.0, 1.0) - 0.5)))
	var good_mask = 0
	for id in listener.get("knowledge", {}).get("good", []):
		var idx = ids.find(id)
		if idx >= 0:
			good_mask |= 1 << idx
	var team_prior = PackedFloat64Array()
	team_prior.resize(ix.teams.size())
	for t in range(ix.teams.size()):
		var evil: int = ix.teams[t]
		if evil & good_mask:
			team_prior[t] = 0.0
			continue
		var v = 1.0
		for j in range(ids.size()):
			if evil & (1 << j):
				v *= odds[j]
		team_prior[t] = v
	return team_prior

static func _team_prior_cs(view: Dictionary, listener: Dictionary) -> PackedFloat64Array:
	var u_key: String = Solver._universe_key(view)
	var universe: Array = Solver.universe(view)
	var u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(universe) if u_handle < 0 else PackedInt64Array()
	var ids: Array = Solver.person_ids(view)
	var n_people: int = ids.size()
	var raw_susp := PackedFloat64Array()
	var npc_trust := PackedFloat64Array()
	raw_susp.resize(n_people)
	npc_trust.resize(n_people)
	var susp_map: Dictionary = listener.get("suspicion", {})
	var trust_map: Dictionary = listener.get("npc_trust", {})
	for j in range(n_people):
		var pid: String = ids[j]
		raw_susp[j] = float(susp_map.get(pid, 0.3))
		npc_trust[j] = float(trust_map.get(pid, 0.5))
	var good_mask: int = 0
	for gid in listener.get("knowledge", {}).get("good", []):
		var idx: int = Solver.person_index(view, str(gid))
		if idx >= 0:
			good_mask |= (1 << idx)
	var curr_conv: bool = Solver._curse_active_at(view, "Current alignment")
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("CaseEval._team_prior", pack_u)
	return SolverBackend._bridge().CaseEvalTeamPrior(u_handle, fallback, curr_conv, raw_susp, npc_trust, good_mask, prior_k)

static var _fits_cache: Dictionary = {}
## Prior odds = exp(prior_k * suspicion) (Tuning.Workshop.PRIOR_K). Probes may override it;
## a negative value restores the old mapping (suspicion read as a probability) for comparison.
static var prior_k: float = Tuning.Workshop.PRIOR_K

## Role assignment per class (live views): one check per class representative, since
## a class shares everything the role check reads. A listener's own role and outings only
## add constraints, so only the classes the knowledge-free check allows are re-checked.
static func _class_fits(view: Dictionary, cc: Dictionary, cards: Array, knowledge: Dictionary) -> PackedFloat64Array:
	var nc: int = cc.team.size()
	if not view.get("world_options", {}).get("roles", false):
		var ones = PackedFloat64Array()
		ones.resize(nc)
		ones.fill(1.0)
		return ones
	var personal = {"self": knowledge.get("self", ""), "own_role": knowledge.get("own_role", ""), "own_outings": knowledge.get("own_outings", {})}
	if not knowledge.get("public_roles", {}).is_empty():
		personal["public_roles"] = knowledge.public_roles
	var bare: bool = cards.is_empty() # the "before" side: no case cards (see evaluate)
	var neutral_key = hash([cc.key, "neutral", Domain.live(view), bare])
	if not _fits_cache.has(neutral_key):
		_fits_cache[neutral_key] = _fits_over(view, cc, cards, {}, range(nc))
	var neutral: PackedFloat64Array = _fits_cache[neutral_key]
	if personal.own_role == "" and personal.own_outings.is_empty() and personal.get("public_roles", {}).is_empty():
		return neutral
	var key = hash([cc.key, personal, Domain.live(view), bare])
	if not _fits_cache.has(key):
		if _fits_cache.size() > 256:
			_fits_cache.clear()
			_fits_cache[neutral_key] = neutral
		var open: Array = []
		for c in range(nc):
			if neutral[c] > 0.0:
				open.append(c)
		_fits_cache[key] = _fits_over(view, cc, cards, personal, open)
	return _fits_cache[key]

static func _fits_over(view: Dictionary, cc: Dictionary, cards: Array, knowledge: Dictionary, classes) -> PackedFloat64Array:
	var out = PackedFloat64Array()
	out.resize(cc.team.size())
	out.fill(0.0)
	var universe: Array = Solver.universe(view)
	var base_u_handle: int = SolverBackend.get_universe_handle(Solver._universe_key(view), universe)
	var cc_reps_handle: int = SolverBackend.get_sub_universe_handle("cc_reps:" + str(cc.key), base_u_handle, cc.rep)
	var reps: Array = []
	var which: Array = []
	var sub_idx := PackedInt32Array()
	var full_cc: bool = classes.size() == cc.rep.size()
	for k_i in range(classes.size()):
		var c: int = int(classes[k_i])
		reps.append(universe[cc.rep[c]])
		which.append(c)
		if full_cc and c != k_i:
			full_cc = false
	if not full_cc and cc_reps_handle >= 0:
		sub_idx.resize(which.size())
		for k_i in range(which.size()):
			sub_idx[k_i] = int(which[k_i])
	var live: bool = Domain.live(view)
	var t: PackedFloat64Array = Solver.Roles.fits_weights(view, reps, cards, knowledge, {}, live, cc_reps_handle, sub_idx)
	# Only classes that fail the content check need the declaration-only check.
	var declarations = PackedByteArray()
	if live and t.has(0.0) and cards.any(func(card): return card.kind == "report"):
		var claims: Array = []
		for card in cards:
			var claim: Dictionary = card
			if card.kind == "report":
				claim = card.duplicate()
				claim.kind = "claim"
				claim.data = {}
			claims.append(claim)
		var failed: Array = []
		var at: PackedInt32Array = PackedInt32Array()
		var failed_cc_idx := PackedInt32Array()
		for x in range(reps.size()):
			if t[x] == 0.0:
				failed.append(reps[x])
				at.append(x)
				if cc_reps_handle >= 0:
					failed_cc_idx.append(int(which[x]))
		var sub: PackedByteArray = Solver.Roles.fits_table(view, failed, claims, knowledge, {}, true, cc_reps_handle, failed_cc_idx)
		declarations.resize(reps.size())
		declarations.fill(0)
		for y in range(at.size()):
			declarations[at[y]] = sub[y]
	var weights: PackedFloat64Array = Solver.Roles.bluff_weights(view, reps, cards, cc_reps_handle, sub_idx) if live else PackedFloat64Array()
	var relayed_seers: Array = cards.filter(func(card): return card.kind == "report" and card.get("role", "") == "seer" and card.get("testimony_only", false) and not card.get("quoted", false))
	var ids: Array = Solver.person_ids(view)
	var all_mask: int = (1 << ids.size()) - 1
	for x in range(which.size()):
		var content: float = t[x]
		if content == 0.0 and not declarations.is_empty() and declarations[x] != 0:
			# A joint report-content contradiction can be an erroneous reading too.
			# Identity/public constraints remain hard; never erase the whole view
			# merely because several claimed Seer results share no exact Red Herring.
			content = DEFAULT_ERR
		if content > 0.0 and not relayed_seers.is_empty():
			var w_rep: Dictionary = reps[x]
			var rel_readings: Array = []
			for rc in relayed_seers:
				if Solver.source_valid(view, w_rep, rc):
					var p_mask = 0
					for person in rc.data.get("pair", []):
						var idx: int = ids.find(person)
						if idx >= 0:
							p_mask |= 1 << idx
					rel_readings.append({"yes": bool(rc.data.yes), "pair": p_mask, "ping": p_mask, "reason": ""})
			if not rel_readings.is_empty():
				var rh_w: float = Solver.Roles._seer_rh_weight(all_mask & ~int(w_rep.evil), int(w_rep.get("demon", -1)), int(w_rep.marked), rel_readings)
				content *= rh_w if rh_w > 0.0 else DEFAULT_ERR
		out[which[x]] = content * (weights[x] if live else 1.0)
	return out

## Joint facts about the reports, for one listener:
##   consistent   every report could hold together in a world the listener allows
##   acceptance   per report (case and own), the posterior chance the reading is accurate
##   credence     the prior chance every case report's source could read healthily, times
##                each reading's own accuracy: how far a listener who looks for no rival
##                explanation takes the reports on trust
static func _joint(view: Dictionary, cc: Dictionary, oc: Dictionary, own: Array, base: PackedFloat64Array, post: PackedFloat64Array, ns: int, err_for: Callable) -> Dictionary:
	var k: int = cc.k
	var ko: int = own.size()
	var states: PackedByteArray = cc.states
	var dead: PackedByteArray = cc.dead
	var move: PackedFloat64Array = cc.move
	# A reading that holds was accurate with chance (1 - err) / ((1 - err) + err q).
	var accurate = PackedFloat64Array()
	var cards: Array = cc.reports + own
	for card in cards:
		var err: float = err_for.call(card)
		var q: float = chance_content(view, card)
		accurate.append((1.0 - err) / maxf((1.0 - err) + err * q, 1e-12))
	var held = PackedFloat64Array()
	held.resize(k + ko)
	held.fill(0.0)
	var total = 0.0
	var base_total = 0.0
	var readable = 0.0
	var consistent = false
	for x in range(base.size()):
		var c: int = x / ns
		var all_hold = dead[c] == 0 and move[c] > 0.0 and cc.movement_ok
		var all_valid = true
		for j in range(k):
			var st: int = states[c * k + j]
			if st == 0:
				held[j] += post[x]
			else:
				all_hold = false
			if st == 2:
				all_valid = false
		if ko > 0:
			var digits: PackedByteArray = oc.codes[x % ns]
			for j in range(ko):
				if digits[j] == 0:
					held[k + j] += post[x]
		total += post[x]
		base_total += base[x]
		if all_valid:
			readable += base[x]
		if all_hold and base[x] > 0.0:
			consistent = true
	var acceptance = {}
	for j in range(k + ko):
		acceptance[cards[j].id] = held[j] / total * accurate[j] if total > 0.0 else 0.0
	var credence: float = readable / base_total if base_total > 0.0 else 0.0
	for card in cc.reports:
		credence *= minf(1.0, (1.0 - err_for.call(card)) / (1.0 - DEFAULT_ERR))
	return {"consistent": consistent, "acceptance": acceptance, "credence": credence}

static func _class_share(cc: Dictionary, w: PackedFloat64Array, ns: int) -> Array:
	var yes = 0.0
	var total = 0.0
	var prem: PackedByteArray = cc.premise
	for k in range(w.size()):
		total += w[k]
		if prem[k / ns] == 1:
			yes += w[k]
	return [yes, total]

## Per-world weights from class weights (only for checks that read individual worlds).
static func _expand(cc: Dictionary, oc: Dictionary, w: PackedFloat64Array) -> PackedFloat64Array:
	var class_of: PackedInt32Array = cc.class_of
	var ns: int = oc.states
	var counts: PackedFloat64Array = oc.counts
	var of: PackedInt32Array = oc.of
	var out = PackedFloat64Array()
	out.resize(class_of.size())
	for i in range(class_of.size()):
		var k: int = class_of[i] * ns + (of[i] if ns > 1 else 0)
		out[i] = w[k] / counts[k] if counts[k] > 0.0 else 0.0
	return out

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
	var ids: Array = people.keys().filter(func(id): return id != conclusion.get("target", ""))
	ids.sort_custom(func(x, y): return people[x].posterior > people[y].posterior)
	return ids.slice(0, limit).map(func(id): return {"id": id, "posterior": people[id].posterior, "shift": people[id].posterior - people[id].prior})

## The player's answers and positions as a theory: the share of the posterior consistent
## with them. 1.0 when the player left everything open.
static func _theory_fit(view: Dictionary, case_data: Dictionary, cards: Array, post: PackedFloat64Array) -> float:
	var universe: Array = Solver.universe(view)
	var masks: Array = []
	for card in cards:
		var positive: Array = case_data.get("answers", {}).get(card.id, {}).get("positive", [])
		var blocks: Array = case_data.get("answers", {}).get(card.id, {}).get("blocks", [])
		var marked: Array = case_data.get("answers", {}).get(card.id, {}).get("marked", [])
		if Solver.tabled(card) and (not positive.is_empty() or not blocks.is_empty()):
			masks.append(Solver.report_table(view, card, positive, blocks, marked))
	var positions: Dictionary = case_data.get("positions", {})
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
	return ["contradicts", "none", "weak", "moderate", "strong"].find(cat)

## The case-strength label for the board: the neutral reference listener's category plus a
## one-line reason. Describes the case, not any particular NPC.
static func strength(view: Dictionary, case_data: Dictionary) -> Dictionary:
	return strength_from(evaluate(view, case_data))

## strength() from an evaluation already in hand.
static func strength_from(r: Dictionary) -> Dictionary:
	var reason = ""
	if r.impossible:
		reason = "These cards can't all be true together; something here is false."
	elif r.category in ["weak", "moderate", "strong"]:
		if r.pivotal.size() == 1:
			reason = "It rests on one card."
		elif r.pivotal.is_empty():
			reason = "Several lines of evidence agree."
		else:
			reason = "It rests on %d cards together." % r.pivotal.size()
	return {"category": r.category, "text": category_text(r.category), "reason": reason, "lr": r.lr}
