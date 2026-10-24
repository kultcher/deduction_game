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

const Solver = preload("res://workshop/solver.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Graph = preload("res://workshop/case_graph.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Movement = preload("res://workshop/movement_model.gd")

## Chance a healthy reading from a good source is wrong anyway (unmodelled impairment).
## Kept small: the rules make a good, healthy reading accurate, and the failures the
## rules allow (evil, Delusional, Marked registering) are in the worlds themselves. A
## larger value lets "it was just wrong" explain away any surprising reading.
const DEFAULT_ERR = 0.01
## The same for the listener's own reading: they know what they saw.
const OWN_ERR = 0.002
## Likelihood-ratio thresholds for the case-strength categories (neutral listener).
const LR_WEAK = 1.5
const LR_MODERATE = 3.0
const LR_STRONG = 10.0

## Chance of this report's content arising by chance: roughly one over the number of
## different things the gift could have said.
static func chance_content(view: Dictionary, card: Dictionary) -> float:
	var d: Dictionary = card.get("data", {})
	match card.get("role", ""):
		"surveyor":
			var blocks = {}
			for p in view.people:
				blocks[p.home] = true
			return 1.0 / float(blocks.size() + 1)
		"dowser", "hearthwitch":
			return 1.0 / float(d.get("group", []).size() + 1)
		"lamplighter":
			return 1.0 / float(view.people.size())
		"nightwatch":
			return 0.25
	return 0.5

static var _valid_cache: Dictionary = {}

## Per world: can this card's source give a healthy reading? (cached per card and universe)
static func _valid_table(view: Dictionary, card: Dictionary) -> PackedByteArray:
	var key = hash([Solver._universe_key(view), card.kind, card.source, card.observed_at, card.get("role", ""), view.get("timeline", {})])
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
	var teams: Array = []
	var team_idx = {}
	var team_of = PackedInt32Array()
	team_of.resize(universe.size())
	for i in range(universe.size()):
		var evil: int = universe[i].evil
		if not team_idx.has(evil):
			team_idx[evil] = teams.size()
			teams.append(evil)
		team_of[i] = team_idx[evil]
	var out = {"teams": teams, "team_of": team_of}
	_index_cache[key] = out
	return out

## Uniform prior over legal worlds, with no private knowledge: the reference listener.
static func neutral_listener(view: Dictionary) -> Dictionary:
	return {"id": "", "suspicion": {}, "knowledge": {}, "reading_reliability": {}}

static var _premise_cache: Dictionary = {}

static func _premise_mask(view: Dictionary, conclusion: Dictionary) -> PackedByteArray:
	var key = hash([Solver._universe_key(view), conclusion, view.get("timeline", {})])
	if _premise_cache.has(key):
		return _premise_cache[key]
	if _premise_cache.size() > 256:
		_premise_cache.clear()
	_premise_cache[key] = _build_premise_mask(view, conclusion)
	return _premise_cache[key]

static func _build_premise_mask(view: Dictionary, conclusion: Dictionary) -> PackedByteArray:
	var universe: Array = Solver.universe(view)
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
	var nc: int = cc.team.size()
	var ns: int = oc.states
	# Per class: prior (team odds, role fits) and the case's likelihood.
	var team_prior = _team_prior(view, listener)
	var fits = _class_fits(view, cc, cards, knowledge)
	var case_like = _class_like(cc, cc.reports.map(func(c): return err_for.call(c)), -1)
	var own_like = _state_like(view, own, own.map(func(c): return err_for.call(c)), oc.codes)
	var compatible: bool = not Domain.live(view) or Domain.claims_compatible(cards, knowledge)
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
			base[k] = b
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

static var _compiled: Dictionary = {}

## Per presentation: the universe grouped into classes that every listener weighs alike.
## A class shares the evil team, what the role check reads, each report card's state
## (holds / healthy but wrong / source can't read healthily), the hard event facts and
## the premise. Listener-specific work is then per class, not per world.
## known: the listener's own readings, which can complete a test factor's route.
static func compile(view: Dictionary, cards: Array, case_data: Dictionary, known: Array = []) -> Dictionary:
	var conclusion: Dictionary = case_data.conclusion
	var key_input = [Solver._universe_key(view), view.get("timeline", {}), view.people, conclusion, case_data.get("citations", {}), case_data.get("test_factors", []),
		known.map(func(c): return c.get("fact_id", c.id)) if not case_data.get("test_factors", []).is_empty() else [],
		cards.map(func(c): return [c.get("fact_id", c.id), c.kind, c.source, c.get("role", ""), c.get("observed_at", {}), c.get("data", {}), c.get("event", ""), c.has("relay_source"), c.get("quoted", false), c.get("block", ""), c.get("night", -1), c.get("subject", ""), c.get("subjects", [])])]
	var key = hash(key_input)
	if _compiled.has(key) and _compiled[key].input == key_input:
		return _compiled[key]
	if _compiled.size() > 32:
		_compiled.clear()
	var universe: Array = Solver.universe(view)
	var n: int = universe.size()
	var ix = _index(view)
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
	var people: int = view.people.size()
	var roles_on: bool = view.get("world_options", {}).get("roles", false)
	var seer: bool = Solver.Roles.seer_flag(cards)
	var relay: bool = cards.any(func(c): return c.has("relay_source"))
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
	var rm_bound: int = (1 << people) * (people + 2) * (people + 2) * ((1 << people) * 2 if relay else 1)
	var int_keys: bool = k <= 16 and float(rm_bound) * float(radix) * 4.0 < 9.0e18
	# Each world's card states as one base-3 code, a card at a time.
	var codes = PackedInt64Array()
	codes.resize(n)
	codes.fill(0)
	for c in range(k):
		var t: PackedByteArray = tables[c]
		var v: PackedByteArray = valids[c]
		for i in range(n):
			codes[i] = codes[i] * 3 + (0 if t[i] == 1 else (1 if v[i] == 1 else 2))
	var live: bool = Domain.live(view)
	var rms: PackedInt64Array = _coarse(view, seer, relay) if roles_on else Solver.world_bits(view).evil
	if not live:
		# Fixture universes are small and carry conversion histories: one world per class.
		rms = PackedInt64Array()
		rms.resize(n)
		for i in range(n):
			rms[i] = i
	# Movement and trace observations: a likelihood per world from the evil team and
	# the Demon (live) or each subject's alignment and Mark (fixtures). Both are fixed
	# within a class.
	var movement: Array = Movement.factors(view, cards, case_data)
	movement.append_array(preload("res://workshop/public_evidence.gd").factors(view))
	# Supplied test factors (and a challenged home alibi in fixtures): a likelihood ratio
	# on their target being evil, once any of their routes is among the cards.
	# Each listener weighs them by how far they credit the route (see _factor_like).
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
	var test_hold = PackedByteArray()  # class-major: does each test factor's target fit?
	var move = PackedFloat64Array()
	var team_of: PackedInt32Array = ix.team_of
	var plain_bits: bool = Solver.world_bits(view).plain
	var group = PackedInt32Array()  # per class: index into group_bits (who is evil then)
	var group_bits: Array = ix.teams if plain_bits else []
	var group_index = {}
	for i in range(n):
		var code: int = codes[i]
		var rm: int = rms[i]
		# One int key when it fits in 63 bits, else an array.
		var ck = ((rm * radix + code) * 2 + premise[i]) * 2 + dead[i] if int_keys else [rm, code, premise[i], dead[i]]
		var c_id = index.get(ck, -1)
		if c_id < 0:
			c_id = team.size()
			index[ck] = c_id
			team.append(team_of[i])
			if plain_bits:
				group.append(team_of[i])
			else:
				# Conversion histories: who is evil at the case's epoch, not originally.
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
			move.append(_movement_score(view, universe[i], movement))
			for f in tests:
				var target: int = Solver.person_index(view, f.target)
				test_hold.append(1 if target >= 0 and TimeModel.evil_at(view, universe[i], f.target, f.epoch) else 0)
			for c in range(k - 1, -1, -1):
				digits[c] = code % 3
				code /= 3
			states.append_array(digits)
		count[c_id] += 1.0
		class_of[i] = c_id
	var out = {"input": key_input, "key": key, "reports": reports, "tables": tables, "valids": valids, "move": move,
		"movement": movement.map(func(f): return f.label), "factors": movement, "tests": tests, "test_hold": test_hold, "group": group, "group_bits": group_bits, "movement_ok": _movement_ok(view, cards, live),
		"q": reports.map(func(c): return chance_content(view, c)), "team": team, "rep": rep, "count": count,
		"premise": prem, "dead": is_dead, "states": states, "class_of": class_of, "k": k}
	_compiled[key] = out
	return out

static var _coarse_cache: Dictionary = {}

## Per universe: each world's role-check mask (Roles.coarse_mask), for these flags.
static func _coarse(view: Dictionary, seer: bool, relay: bool) -> PackedInt64Array:
	var key = hash([Solver._universe_key(view), seer, relay])
	if _coarse_cache.has(key):
		return _coarse_cache[key]
	if _coarse_cache.size() > 16:
		_coarse_cache.clear()
	var universe: Array = Solver.universe(view)
	var people: int = view.people.size()
	var out = PackedInt64Array()
	out.resize(universe.size())
	for i in range(universe.size()):
		out[i] = Solver.Roles.coarse_mask(people, universe[i], seer, relay)
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
	var class_of: PackedInt32Array = cc.class_of
	var n: int = class_of.size()
	var of = PackedInt32Array()
	of.resize(n)
	# Only states actually present in legal worlds can carry probability. Enumerating
	# all 3^private-readings combinations allocated mostly zero cells and made later
	# presentations exponentially slower. Byte-vector keys also avoid integer overflow.
	var codes: Array = []
	var indices = {}
	var k: int = own.size()
	if k <= 39:
		# Each world's state as one base-3 integer; a byte code is built only the first
		# time a state appears, so indices and codes keep first-appearance order.
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
	var out = {"states": ns, "counts": counts, "of": of, "codes": codes}
	_own_cache[key] = out
	return out

## Likelihood factor of one state for a card: holds, healthy but wrong, or no healthy reading.
static func _factor(st: int, err: float, q: float) -> float:
	match st:
		0: return (1.0 - err) + err * q
		1: return err * q
	return q

## The case's likelihood per class. skip >= 0 leaves that report card out (pivotal check).
static func _class_like(cc: Dictionary, errs: Array, skip: int) -> PackedFloat64Array:
	var nc: int = cc.team.size()
	var k: int = cc.k
	var like = PackedFloat64Array()
	like.resize(nc)
	var states: PackedByteArray = cc.states
	var dead: PackedByteArray = cc.dead
	# Three possible factors per card: price them once (a skipped card counts 1).
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
	var ix = _index(view)
	var ids: Array = Solver.person_ids(view)
	var odds: Array = []
	for id in ids:
		var sv: float = clampf(float(listener.get("suspicion", {}).get(id, 0.3)), 0.02, 0.98)
		# Trust in a person halves (full trust) or doubles (none) their odds of evil.
		var trust: float = float(listener.get("npc_trust", {}).get(id, 0.5))
		odds.append(sv / (1.0 - sv) * pow(2.0, -2.0 * (clampf(trust, 0.0, 1.0) - 0.5)))
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

static var _fits_cache: Dictionary = {}

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
	var neutral_key = hash([cc.key, "neutral"])
	if not _fits_cache.has(neutral_key):
		_fits_cache[neutral_key] = _fits_over(view, cc, cards, {}, range(nc))
	var neutral: PackedFloat64Array = _fits_cache[neutral_key]
	if personal.own_role == "" and personal.own_outings.is_empty():
		return neutral
	var key = hash([cc.key, personal])
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
	var reps: Array = []
	var which: Array = []
	for c in classes:
		reps.append(universe[cc.rep[c]])
		which.append(c)
	var t: PackedByteArray = Solver.Roles.fits_table(view, reps, cards, knowledge)
	for x in range(which.size()):
		out[which[x]] = float(t[x])
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
		if Solver.tabled(card) and (not positive.is_empty() or not blocks.is_empty()):
			masks.append(Solver.report_table(view, card, positive, blocks))
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
		var like = _class_like(cc, errs, skip)
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
	var r = evaluate(view, case_data)
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
