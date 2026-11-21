## compile() and the class machinery: grouping the universe into classes every listener
## weighs alike, and each listener's per-class likelihoods and fits (split from
## `workshop/case_eval.gd`; part of CaseEval's inheritance chain).
extends "res://workshop/case_eval_content.gd"

const ScriptDefRef = preload("res://sim/script_def.gd")

static var _cc_handles: Dictionary = {}
static var _cc_handles_epoch: int = -1
## Bumped whenever the C# compiled cases are dropped (context epoch, the 32-entry cap).
## Each compiled case carries its own handle and the generation it was made in, so a case
## held across a clear, or one whose 32-bit key hash collides with another's, can never
## reach a different case's C# entry (seed 101032: IndexOutOfRange in ComputeClassLikeCore).
static var _cc_generation: int = 0

static func _ensure_cc_epoch() -> void:
	var b = SolverBackend._bridge()
	if b == null:
		return
	var ep: int = int(b.GetContextEpoch())
	if ep != _cc_handles_epoch:
		_cc_handles.clear()
		_cc_generation += 1
		_cc_handles_epoch = ep

## The C# handle for this compiled case, or -1 when it isn't (or no longer) registered.
static func _handle_for(cc: Dictionary) -> int:
	if int(cc.get("cs_gen", -1)) != _cc_generation:
		return -1
	return int(cc.get("cs_handle", -1))

static var cache_enabled: bool = true
static var _compiled: Dictionary = {}
const SOFT_EVENTS: Array = ["nomination", "meeting", "vote", "vote_yes", "accusation", "reading", "clear"]

## Per presentation: the universe grouped into classes that every listener weighs alike.
## A class shares the evil team, what the role check reads, each report card's state
## (holds / healthy but wrong / source can't read healthily), the hard event facts and
## the premise. Listener-specific work is then per class, not per world.
## known: the listener's own readings, which can complete a test factor's route.
static func compile(view: Dictionary, cards: Array, case_data: Dictionary, known: Array = []) -> Dictionary:
	case_data = Solver.with_hanged_refuters(view, case_data, cards, true)
	if not SolverBackend.profiling_enabled:
		return _compile_impl(view, cards, case_data, known)
	var _st: int = SolverBackend.begin_stage("case_eval_compile")
	var _res: Dictionary = _compile_impl(view, cards, case_data, known)
	SolverBackend.end_stage(_st)
	return _res

static func _compile_impl(view: Dictionary, cards: Array, case_data: Dictionary, known: Array = []) -> Dictionary:
	var conclusion: Dictionary = case_data.conclusion
	var timeline: Dictionary = view.get("timeline", {})
	if timeline.has("events") and not (cards + known).any(func(c): return str(c.get("role", "")) == "magistrate"):
		timeline = timeline.duplicate(false)
		timeline["events"] = timeline.events.filter(func(e): return str(e.get("kind", "")) not in SOFT_EVENTS)
	var key_input = [view.get("trace_assessments", []), Solver._universe_key(view), timeline, view.people, conclusion, case_data.get("citations", {}), case_data.get("test_factors", []),
		known.map(func(c): return c.get("fact_id", c.id)) if not case_data.get("test_factors", []).is_empty() else [],
		cards.map(func(c): return [c.get("fact_id", c.id), c.kind, c.get("source", ""), c.get("role", ""), c.get("observed_at", {}), c.get("data", {}), c.get("event", ""), c.has("relay_source"), c.get("quoted", false), c.get("block", ""), c.get("night", -1), c.get("subject", ""), c.get("subjects", []), c.get("duty_only", false)])]
	if cards.any(func(c): return c.has("hearing_weight")):
		key_input.append(cards.map(func(c): return c.get("hearing_weight", 1.0)))
	if cards.any(func(c): return c.has("route_trust")):
		key_input.append(cards.map(func(c): return c.get("route_trust", 1.0)))
	if cards.any(func(c): return c.has("out_rate")):
		# An excused caught lie's softer out-rate (LiveAssessment._mark_excuses) is scored by the
		# movement factor, so it must be in the key (found by test_caught_lie_softening).
		key_input.append(cards.map(func(c): return c.get("out_rate", -1.0)))
	if cards.any(func(c): return c.has("broken_chance")):
		# A count mixed with no broken chance is still mixed (its evil teller says nothing).
		key_input.append(cards.map(func(c): return [c.get("broken_chance", 0.0), c.get("count_mix", false)]))
		if cards.any(func(c): return c.get("count_mix", false)):
			# Whether a count is impossible reads the listener's own sightings (certain_for_count;
			# Codex on #346), even for a listener with no home nights to key on below.
			key_input.append(str(view.get("own_home", {}).get("self", "")))
	if cards.any(func(c): return c.get("testimony_only", false)):
		key_input.append(cards.map(func(c): return [c.get("testimony_only", false), c.get("reported_at")]))
	if cards.any(func(c): return c.get("role", "") == "augur") and not case_data.get("reading_challenges", {}).is_empty():
		key_input.append(case_data.get("reading_challenges", {}).keys())
	if not view.get("regular_haunts", {}).is_empty():
		key_input.append(view.regular_haunts)  # traces and presence read the listener's regular knowledge
	if not view.get("own_home", {}).get("nights", {}).is_empty() or not view.get("own_home", {}).get("out_nights", {}).is_empty():
		key_input.append(view.own_home)  # the movement model reads the listener's known home nights
	if view.get("timeline", {}).get("events", []).any(func(e): return e.get("kind", "") == "silenced"):
		key_input.append(view.get("watched", []))  # Breathstealer by presence reads the watch record
		if cards.is_empty() and not DayPresence.bare_reads_view:
			# The connections model's no-card baseline reads no cards for presence.
			key_input.append("bare_presence")
		elif cards.is_empty():
			# Elsewhere a no-card case reads every card on the view for presence
			# (DayPresence.breath_factor), so they belong in the key: without them a later view
			# with different day cards reused an older answer (BACKLOG section 6, Nov 17).
			key_input.append(view.get("cards", []))
	# The town's demon mix (the demon-type declaration, game/demon_declaration.gd) changes the
	# movement factor: without it in the key, a declaration kept the old movement scores.
	var share: float = Movement.Live.day_demon_share(view)
	if share > 0.0 or view.has("declared_demon_type"):
		key_input.append(share)
	if share > 0.0 and not Movement.Live.hex_factor_enabled:
		# The Hexer factor can be switched off for a judgement (diagnostics, and the
		# connections model, which reads the day evidence in one place): movement scores
		# compiled without it must not be reused with it on. In play it is on, and the key
		# is as it always was.
		key_input.append("hex_off")
	if not Movement.Live.quiet_guards_enabled or not Movement.Live.quiet_guards_skip.is_empty():
		# The same for the quiet-night Warden guards (the Test juror's comparison without
		# them, WorkshopCanvas.guard_reasons).
		key_input.append(["quiet_guards_off", Movement.Live.quiet_guards_enabled, Movement.Live.quiet_guards_skip.duplicate()])
	var key = hash(key_input)
	if cache_enabled and _compiled.has(key) and _compiled[key].input == key_input:
		return _compiled[key]
	if _compiled.size() > 4096:
		_compiled.clear()
		_cc_handles.clear()
		_cc_generation += 1
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
	movement.append_array(_augur_factors(view, cards, case_data, live))
	var breath: Dictionary = DayPresence.breath_factor(view, cards) if live else {}
	if not breath.is_empty():
		movement.append(breath)

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
	var out: Dictionary = _compile_classes_cs(view, universe, key_input, key, conclusion, cards, reports, tables, valids, dead, premise, live, movement, movement_ok, tests, q_arr)
	if cache_enabled:
		_compiled[key] = out
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
	var chrono: Dictionary = view.get("chronology", {})
	var has_curse: bool = chrono.has("curse")
	var curse_from: int = int(chrono.curse.get("from", 0)) if has_curse else 0
	var curse_until: int = int(chrono.curse.get("until", 0)) if has_curse else 0
	var marked_m: int = Solver.Roles.marked_mask(ids, cards)
	for card in cards:
		if card.get("quoted", false):
			continue
		var cdata: Dictionary = card.get("data", {}) if card.get("data") is Dictionary else {}
		if card.get("kind", "") == "report" and str(card.get("role", "")) == "seer" and card.get("testimony_only", false):
			for person in cdata.get("pair", []):
				var pi: int = ids.find(str(person))
				if pi >= 0:
					marked_m |= 1 << pi
		if Solver.marked_counts(card):
			var role_s: String = str(card.get("role", ""))
			if role_s == "magistrate":
				for person in cdata.get("group", cdata.get("pair", [])):
					var pi: int = ids.find(str(person))
					if pi >= 0:
						marked_m |= 1 << pi
			elif role_s == "surveyor":
				if cdata.has("block") and cdata.has("same"):
					var blk_s: String = str(cdata.get("block", ""))
					for p_i in range(n_people):
						if str(view.people[p_i].get("home", "")) == blk_s:
							marked_m |= 1 << p_i
				else:
					marked_m |= (1 << n_people) - 1
			else:
				var rdef = Solver.C.role_def(role_s)
				if rdef != null and rdef.shape == "ROLE_AT_SITE" and rdef.site_mode == "group_count":
					for person in cdata.get(rdef.site_group_key, []):
						var pi: int = ids.find(str(person))
						if pi >= 0:
							marked_m |= 1 << pi
				else:
					marked_m |= (1 << n_people) - 1
	var mediums: int = Solver.Roles.relay_mediums(ids, cards)
	var forbidden_specs: PackedInt32Array = Solver.Roles.forbidden_specs(ids, cards) if (live and roles_on) else PackedInt32Array()
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
		elif f.get("breath_presence", false):
			move_specs[m_off] = 3
			move_specs[m_off + 1] = int(SolverBackend._bridge().CaseEvalRegisterPresenceWeights(f.weights))
			move_specs[m_off + 2] = 0
			move_specs[m_off + 3] = 0
			move_doubles[fi * 2] = DEFAULT_ERR
			move_doubles[fi * 2 + 1] = 0.0
		elif f.get("augur_crossing", false):
			var packed_af: int = (int(f.src_idx) & 0xFFFF) | ((1 if bool(f.yes) else 0) << 16) | ((1 if bool(f.conv_evil) else 0) << 17) | ((1 if bool(f.is_live) else 0) << 18)
			move_specs[m_off] = 2
			move_specs[m_off + 1] = packed_af
			move_specs[m_off + 2] = int(f.slot0_codes)
			move_specs[m_off + 3] = int(f.slot1_codes)
			move_doubles[fi * 2] = float(f.p_ref)
			move_doubles[fi * 2 + 1] = DEFAULT_ERR
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
		marked_m,
		mediums,
		1 if movement.any(func(f): return f.get("joint_live", false) and not f.get("profiles", []).is_empty() and f.profiles[0].has("unrequited")) else 0,  # Unrequited holders' own column
		1 if curr_conv else 0,
		1 if concl_conv else 0,
		k,
		1 if movement_ok else 0,
		curse_from,
		curse_until,
	])

	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("CaseEval.compile", pack_u)
	var b = SolverBackend._bridge()
	var cc_h: int = int(b.CaseEvalCompile(u_handle, fallback, header, dead, premise, flat_tables, flat_valids, q_packed, test_specs, move_specs, move_doubles, forbidden_specs))
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
		"premise": prem, "dead": is_dead, "states": states, "class_of": class_of, "k": k,
		"cs_handle": cc_h, "cs_gen": _cc_generation}
	for factor in movement:
		out.movement.append_array(factor.get("relationships", []))
	return out

static var _coarse_cache: Dictionary = {}

## A good listener knows its own burden unless it's hidden (WorkshopBridge.own_burden;
## ScriptDef.HIDDEN_SECRETS), so its worlds where it holds a burden it would know of, other
## than the one it knows, are impossible: it can't be Marked unaware, and, one burden to a
## game, a known holder rules out every other. Marks those worlds dead (dead is in the class
## key, so classes split by it). A hidden burden on the listener stays possible.
static func _own_burden_dead(view: Dictionary, universe: Array, dead: PackedByteArray) -> void:
	var ob: Dictionary = view.get("own_burden", {})
	if ob.is_empty():
		return
	var me: int = Solver.person_index(view, str(ob.get("self", "")))
	if me < 0:
		return
	for i in range(universe.size()):
		if not _own_burden_ok(ob, me, universe[i]):
			dead[i] = 1

## Whether a world fits what the listener knows of its own burden (see _own_burden_dead).
static func _own_burden_ok(ob: Dictionary, me: int, w: Dictionary) -> bool:
	var known: String = str(ob.get("kind", ""))
	var mine: String = ""
	if int(w.get("marked", -1)) == me:
		mine = "marked"
	elif int(w.get("holders", 0)) & (1 << me):
		mine = str(w.get("modifier", ""))
	return mine == known or (mine in ScriptDefRef.HIDDEN_SECRETS and known == "")

## Knowledge, not evidence: zero the classes it rules out on both sides of the case (the
## role fits before and after), as the listener's known-good people are, so a case with no
## burden evidence moves nobody (test_workshop_secrets, test_workshop_votes on bc9a742d).
## The classes split by it already (dead, in the class key), so each class's rep speaks for it.
static func _own_burden_fits(view: Dictionary, cc: Dictionary, fits: PackedFloat64Array) -> PackedFloat64Array:
	var ob: Dictionary = view.get("own_burden", {})
	if ob.is_empty() or not Domain.live(view):
		return fits
	var me: int = Solver.person_index(view, str(ob.get("self", "")))
	if me < 0:
		return fits
	var worlds: Array = Solver.universe(view)
	var out: PackedFloat64Array = fits.duplicate() # never modify a cached role table
	for c in range(out.size()):
		if not _own_burden_ok(ob, me, worlds[cc.rep[c]]):
			out[c] = 0.0
	return out

## A world's movement/trace likelihood ratio (good everywhere = 1), as the support
## model's world_score without its prior ranks.
static func _augur_factors(view: Dictionary, cards: Array, case_data: Dictionary, live: bool) -> Array:
	var result: Array = []
	var challenges: Dictionary = case_data.get("reading_challenges", {})
	for card in cards:
		if card.kind != "report" or card.get("role", "") != "augur" or card.get("quoted", false) or card.get("testimony_only", false):
			continue
		if challenges.has(card.id):
			continue
		var src: String = str(card.get("source", ""))
		var src_idx: int = Solver.person_index(view, src)
		if src_idx < 0:
			continue
		if live and (not Domain._gift_time_gd(card) or not Solver.History.observer_alive(view, src, card.get("observed_at", {}))):
			continue
		var spec: Dictionary = Solver.augur_day_spec(view, cards, card)
		if not spec.has_day_evidence:
			continue
		result.append({
			"origin": "augur_crossing",
			"augur_crossing": true,
			"target": "",
			"log2_ratio": 1.0,
			"label": "Day %d daytime crossings with Augur %s" % [int(spec.day), Solver.person_name(view, src)],
			"cards": [card.id],
			"src": src,
			"src_idx": src_idx,
			"yes": bool(spec.yes),
			"conv_evil": Solver._curse_active_at(view, card.get("observed_at", {})),
			"is_live": live,
			"slot0_codes": int(spec.slot0_codes),
			"slot1_codes": int(spec.slot1_codes),
			"p_ref": float(spec.p_ref),
		})
	return result

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
## Helper: world modifier code (0..3) for a burden name, or -1 for none.
static func _own_burden_mod(kind: String) -> int:
	return int(Solver.Roles.BURDEN_CODES.get(kind, 0)) - 1

static func _own_burden_hidden_mask() -> int:
	var m: int = 0
	for h in ScriptDefRef.HIDDEN_SECRETS:
		var code: int = _own_burden_mod(str(h))
		if code >= 0:
			m |= 1 << code
	return m

## Depends only on which own cards there are (and any live listener's own_burden filter),
## so listeners sharing the same compiled case share it without breaking CaseEval.compile reuse.
static func _own_counts(view: Dictionary, cc: Dictionary, own: Array) -> Dictionary:
	var ob: Dictionary = view.get("own_burden", {}) if Domain.live(view) else {}
	var ob_me: int = Solver.person_index(view, str(ob.get("self", ""))) if not ob.is_empty() else -1
	var ob_mod: int = _own_burden_mod(str(ob.get("kind", ""))) if ob_me >= 0 else -1
	if own.is_empty() and ob_me < 0:
		return {"states": 1, "counts": cc.count, "of": PackedInt32Array(), "codes": [PackedByteArray()]}
	# Keyed by the exact compiled case (its input and C# registration), not only a hash.
	var ref: Array = [cc.input, cc.get("cs_gen", -1), cc.get("cs_handle", -1), own.map(func(c): return c.get("fact_id", c.id)), ob_me, ob_mod]
	var key = hash(ref)
	if cache_enabled and _own_cache.has(key) and _own_cache[key].get("_ref", []) == ref:
		return _own_cache[key]
	if _own_cache.size() > 1024:
		_own_cache.clear()
	var tables: Array = own.map(func(c): return Solver.report_table(view, c))
	var valids: Array = own.map(func(c): return _valid_table(view, c))
	var out: Dictionary = _own_counts_cs(view, cc, own, tables, valids, ob_me, ob_mod)
	out["_ref"] = ref
	if cache_enabled:
		_own_cache[key] = out
	return out

static func _own_counts_cs(view: Dictionary, cc: Dictionary, own: Array, tables: Array, valids: Array, ob_me: int = -1, ob_mod: int = -1) -> Dictionary:
	_ensure_cc_epoch()
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var cc_h: int = _handle_for(cc)
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
	var u_handle: int = -1
	var fb_worlds := PackedInt64Array()
	if ob_me >= 0:
		var u_key: String = Solver._universe_key(view)
		var universe: Array = Solver.universe(view)
		u_handle = SolverBackend.get_universe_handle(u_key, universe)
		if u_handle < 0:
			fb_worlds = SolverBackend.pack_worlds(universe)
	var hidden_mask: int = _own_burden_hidden_mask() if ob_me >= 0 else 0
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("CaseEval._own_counts", pack_u)
	var b = SolverBackend._bridge()
	var ns: int = int(b.CaseEvalCompileOwnCounts(cc_h, fb_class_of, cc.team.size(), k_own, flat_tables, flat_valids, u_handle, fb_worlds, ob_me, ob_mod, hidden_mask))
	var of: PackedInt32Array = b.CaseEvalGetLastOwnOf()
	var flat_codes: PackedByteArray = b.CaseEvalGetLastOwnFlatCodes()
	var counts: PackedFloat64Array = b.CaseEvalGetLastOwnCounts()
	var codes: Array = []
	codes.resize(ns)
	for s in range(ns):
		codes[s] = flat_codes.slice(s * k_own, (s + 1) * k_own) if k_own > 0 else PackedByteArray()
	return {"states": ns, "counts": counts, "of": of, "codes": codes, "_flat_codes": flat_codes}

## Likelihood factor of one state for a card: holds, healthy but wrong, or no healthy reading.
static func _factor(st: int, err: float, q: float) -> float:
	match st:
		0: return (1.0 - err) + err * q
		1: return err * q
	return q

## The case's likelihood per class. skip >= 0 leaves that report card out (pivotal check).
static func _class_like(cc: Dictionary, errs: Array, skip: int) -> PackedFloat64Array:
	return _class_like_cs(cc, errs, skip)

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
	var cc_h: int = _handle_for(cc)
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

static var _team_prior_cache: Dictionary = {}

## Per team: the listener's odds that exactly this team is evil (known-good people zero).
static func _team_prior(view: Dictionary, listener: Dictionary) -> PackedFloat64Array:
	return _team_prior_cs(view, listener)

static func _team_prior_cs(view: Dictionary, listener: Dictionary) -> PackedFloat64Array:
	var u_key: String = Solver._universe_key(view)
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
	var ref: Array = [u_key, curr_conv, raw_susp, npc_trust, good_mask, prior_k]
	var key: int = hash(ref)
	if cache_enabled and _team_prior_cache.has(key) and _team_prior_cache[key].ref == ref:
		return _team_prior_cache[key].out
	var universe: Array = Solver.universe(view)
	var u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(universe) if u_handle < 0 else PackedInt64Array()
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("CaseEval._team_prior", pack_u)
	var out: PackedFloat64Array = SolverBackend._bridge().CaseEvalTeamPrior(u_handle, fallback, curr_conv, raw_susp, npc_trust, good_mask, prior_k)
	if cache_enabled:
		if _team_prior_cache.size() >= 256:
			_team_prior_cache.clear()
		_team_prior_cache[key] = {"ref": ref, "out": out}
	return out

static var _fits_cache: Dictionary = {}
static var _bare_fits_cache: Dictionary = {}
## Prior odds = exp(prior_k * suspicion) (Tuning.Workshop.PRIOR_K). Probes may override it;
## a negative value restores the old mapping (suspicion read as a probability) for comparison.
static var prior_k: float = Tuning.Workshop.PRIOR_K

const _MOVEMENT_ROLE_KINDS: Array = ["sighting", "evening", "trace", "coverage", "alibi"]

static func _is_role_card(card: Dictionary) -> bool:
	var k: String = str(card.get("kind", ""))
	return k in ["report", "claim", "secret_claim", "totem", "town_hall", "sighting", "evening", "trace", "coverage", "alibi"] or (k == "event" and card.get("event") == "martyr") or card.has("relay_source") or str(card.get("role", "")) != ""

static func _is_movement_role_card(card: Dictionary) -> bool:
	var k: String = str(card.get("kind", ""))
	return k in _MOVEMENT_ROLE_KINDS or card.has("relay_source") or (k in ["report", "claim"] and str(card.get("role", "")) in ["nightwatch", "warden", "lamplighter", "veteran", "medium", "monitor"])

## Doubted readings in the role check: the one place that handles a reading the listener
## doubts honestly (a poisoned or misled night: listener.reading_doubt, from source doubt).
## Role-checked readings (a Seer's Red Herring, an Archivist's or Clerk's role, a
## Gravedigger's verdict...) act through the role check, which never saw the doubt, so a
## reading the listener thought was misled still moved its pair (playtest fixture 5110,
## Nov 17). Each doubted reading is read as genuine with the listener's trust and as a bare
## claim of the gift otherwise: fits = trust x (fits with it) + doubt x (the chance a
## broken reading says this) x (fits with only its claim). Without that chance a broken
## reading counted as certain to say what it said, and doubt weighed double (Nov 17).
## Several doubted readings are weighed symmetrically (Michael, Nov 19, Steward A3): all
## genuine with chance prod(1 - d), or exactly one broken (each against the others read in
## full) with chance d_i x prod_{j != i}(1 - d_j), renormalised over those cases, so the
## order of the cards doesn't matter. Exact for one doubted reading; with several, the worlds
## where two or more broke at once are left out and the rest share their weight. (Before,
## each reading mixed in turn against the others in full, which depended on card order and
## under-doubted the earlier ones.) Trust in the teller is not here: the role check already
## lets an evil teller lie in the worlds where they are evil.
## Measuring switch (tools and tests): off, doubt doesn't reach the role check (before Nov 17).
static var doubted_role_check: bool = true

static func _doubted_role_fits(view: Dictionary, cc: Dictionary, cards: Array, knowledge: Dictionary, fits: PackedFloat64Array, listener: Dictionary) -> PackedFloat64Array:
	var doubts: Dictionary = listener.get("reading_doubt", {})
	if not doubted_role_check or doubts.is_empty() or not view.get("world_options", {}).get("roles", false):
		return fits
	var doubted: Array = []
	for card in cards:
		if card.get("kind", "") != "report" or card.get("quoted", false) or card.get("testimony_only", false):
			continue
		var doubt: float = clampf(float(doubts.get(card.id, 0.0)), 0.0, 1.0)
		if doubt > 0.000001:
			doubted.append([card, doubt])
	if doubted.is_empty():
		return fits
	if doubted.size() > 1:
		# Kept short of certain, so "every one broke" never leaves nothing to weigh: with one
		# reading the weights are exact whatever its doubt.
		for e in doubted:
			e[1] = minf(float(e[1]), 1.0 - 1e-6)
	# The chance that every doubted reading is genuine, and each one's chance of being the
	# only broken one.
	var all_sound: float = 1.0
	for e in doubted:
		all_sound *= 1.0 - float(e[1])
	var out := PackedFloat64Array()
	out.resize(fits.size())
	for c in range(fits.size()):
		out[c] = all_sound * fits[c]
	var total: float = all_sound
	for e in doubted:
		var card: Dictionary = e[0]
		var doubt: float = e[1]
		var alone_broken: float = doubt
		for o in doubted:
			if o[0].id != card.id:
				alone_broken *= 1.0 - float(o[1])
		total += alone_broken
		var claimed: Dictionary = card.duplicate()
		claimed.kind = "claim"
		claimed.data = {}
		var swapped: Array = cards.map(func(c): return claimed if c.id == card.id else c)
		var alt: PackedFloat64Array = _class_fits(view, cc, swapped, knowledge)
		# A broken reading says these words only by chance (CaseEval.chance_content).
		var content_p: float = chance_content(view, card)
		for c in range(out.size()):
			out[c] += alone_broken * content_p * alt[c]
	if total < 1.0 - 1e-12 and total > 0.0:
		for c in range(out.size()):
			out[c] /= total
	return out

## A Warden's guard on a quiet night sets the Demon's route only as far as the listener
## trusts the reading (Michael, Nov 18): copies of the Warden reports carry "route_trust",
## 1 less the listener's honest doubt of it (reading_doubt: a poisoned or misled night),
## times any challenge that holds against the report or its teller. The route reads it
## (LiveActivity.quiet_guard_cards); the role check has its own doubt (_doubted_role_fits).
static func _route_trusted(cards: Array, listener: Dictionary) -> Array:
	var doubts: Dictionary = listener.get("reading_doubt", {})
	var by_card: Dictionary = listener.get("challenge_reports", {})
	var by_source: Dictionary = listener.get("challenge_sources", {})
	if doubts.is_empty() and by_card.is_empty() and by_source.is_empty():
		return cards
	var out: Array = []
	for card in cards:
		if card.get("kind", "") == "report" and str(card.get("role", "")) == "warden":
			var t: float = (1.0 - clampf(float(doubts.get(card.id, 0.0)), 0.0, 1.0)) * float(by_card.get(card.id, 1.0)) * float(by_source.get(str(card.get("source", "")), 1.0))
			if t < 1.0:
				var copy: Dictionary = card.duplicate()
				copy["route_trust"] = clampf(t, 0.0, 1.0)
				out.append(copy)
				continue
		out.append(card)
	return out

## Another's Night Watch list is sound or broken as a whole (Michael, Nov 18): copies carry
## "broken_chance", the watcher's poison and Delusional priors that night
## (SourceDoubt.list_broken_chance). The movement model mixes the two (LiveActivity._list_mix).
static func _list_broken(view: Dictionary, cards: Array, listener: Dictionary) -> Array:
	var SourceDoubt = preload("res://workshop/source_doubt.gd")
	var out: Array = []
	# Counts take the mix slots the lists leave (SourceDoubt.LIST_MIX_MAX, shared), the latest
	# nights first, chosen among these judged cards only.
	var lists_mixed: int = cards.filter(func(c): return c.get("kind", "") == "report" and str(c.get("role", "")) == "nightwatch" and SourceDoubt.list_broken_chance(view, listener, c) > 0.0).size()
	var counts: Array = cards.filter(func(c): return c.get("kind", "") == "report" and str(c.get("role", "")) == "lamplighter" and SourceDoubt.count_mixable(view, listener, c))
	counts.sort_custom(func(a, b2): return int(a.get("night", -1)) > int(b2.get("night", -1)) or (int(a.get("night", -1)) == int(b2.get("night", -1)) and str(a.get("id", "")) < str(b2.get("id", ""))))
	var count_ids: Array = counts.slice(0, maxi(0, SourceDoubt.LIST_MIX_MAX - lists_mixed)).map(func(c): return str(c.get("id", "")))
	for card in cards:
		if str(card.get("id", "")) in count_ids:
			var mixed: Dictionary = card.duplicate()
			mixed["broken_chance"] = SourceDoubt.count_broken_chance(view, listener, card)
			mixed["count_mix"] = true
			out.append(mixed)
			continue
		if card.get("kind", "") == "report" and str(card.get("role", "")) == "nightwatch":
			var b: float = SourceDoubt.list_broken_chance(view, listener, card)
			if b > 0.0:
				var copy: Dictionary = card.duplicate()
				copy["broken_chance"] = b
				out.append(copy)
				continue
		out.append(card)
	return out

static func _has_role_card(cards: Array) -> bool:
	for card in cards:
		if _is_role_card(card):
			return true
	return false

static func _has_bluff_card(cards: Array) -> bool:
	for card in cards:
		if card.get("kind", "") in ["report", "claim"] and not card.get("quoted", false) and not card.get("inferred", false) and not card.get("testimony_only", false):
			return true
		if Solver.Roles.burden_code(card) > 0:
			return true
	return false

static func _bare_world_fits(view: Dictionary, personal: Dictionary, u_neutral: PackedFloat64Array = PackedFloat64Array()) -> PackedFloat64Array:
	var u_key: String = Solver._universe_key(view)
	var live: bool = Domain.live(view)
	var route_tl: Dictionary = view.get("timeline", {}) if not live else {}
	var ref: Array = [u_key, view.people, route_tl, view.get("live_activity", false), live, personal]
	var key: int = hash(ref)
	if cache_enabled and _bare_fits_cache.has(key) and _bare_fits_cache[key].ref == ref:
		return _bare_fits_cache[key].out
	var universe: Array = Solver.universe(view)
	var base_u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var out: PackedFloat64Array
	if personal.is_empty():
		out = Solver.Roles.fits_weights(view, universe, [], {}, {}, live, base_u_handle)
	else:
		var n_u: int = universe.size()
		out = PackedFloat64Array()
		out.resize(n_u)
		out.fill(0.0)
		var open_worlds: Array = []
		var open_u := PackedInt32Array()
		for i in range(n_u):
			if u_neutral[i] > 0.0:
				open_worlds.append(universe[i])
				open_u.append(i)
		if not open_worlds.is_empty():
			var sub_t: PackedFloat64Array = Solver.Roles.fits_weights(view, open_worlds, [], personal, {}, live, base_u_handle, open_u)
			for x in range(open_u.size()):
				out[open_u[x]] = sub_t[x]
	if cache_enabled:
		if _bare_fits_cache.size() >= 256:
			_bare_fits_cache.clear()
		_bare_fits_cache[key] = {"ref": ref, "out": out}
	return out

static func _slice_by_rep(u_arr: PackedFloat64Array, rep: PackedInt32Array) -> PackedFloat64Array:
	var nc: int = rep.size()
	var out := PackedFloat64Array()
	out.resize(nc)
	for c in range(nc):
		out[c] = u_arr[rep[c]]
	return out

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
	var live: bool = Domain.live(view)
	var role_cards: Array = cards.filter(_is_role_card) if (cache_enabled and live and not cards.is_empty()) else cards
	var personal = {"self": knowledge.get("self", ""), "own_role": knowledge.get("own_role", ""), "own_outings": knowledge.get("own_outings", {})}
	if not knowledge.get("public_roles", {}).is_empty():
		personal["public_roles"] = knowledge.public_roles
	var bare: bool = role_cards.is_empty() # the "before" side: no role-constraining case cards (see evaluate)
	var u_key: String = Solver._universe_key(view)
	var base_fit_ref: Array
	if bare:
		var route_tl: Dictionary = view.get("timeline", {}) if not live else {}
		base_fit_ref = [u_key, view.people, route_tl, view.get("live_activity", false), live, cc.rep, "bare"]
	else:
		var tl: Dictionary = view.get("timeline", {})
		if tl.has("events") and not role_cards.any(_is_movement_role_card):
			tl = tl.duplicate(false)
			tl["events"] = tl.events.filter(func(e): return str(e.get("kind", "")) not in SOFT_EVENTS)
		# A claimed burden's weight reads the listener's other cards (its timing), so it keys too.
		base_fit_ref = [u_key, view.people, tl, view.get("live_activity", false), live, cc.rep, role_cards,
			Solver.Roles.burden_claim_factors(view, role_cards) if live else []]
	var base_fit_key: int = hash(base_fit_ref)
	var neutral_ref: Array = [base_fit_ref, "neutral"]
	var neutral_key: int = hash(neutral_ref)
	var w_all := PackedFloat64Array()
	var neutral: PackedFloat64Array
	var u_neutral := PackedFloat64Array()
	if bare:
		u_neutral = _bare_world_fits(view, {})
	if cache_enabled and _fits_cache.has(neutral_key) and _fits_cache[neutral_key].ref == neutral_ref:
		neutral = _fits_cache[neutral_key].out
	else:
		if bare:
			neutral = _slice_by_rep(u_neutral, cc.rep)
		else:
			if live and _has_bluff_card(role_cards):
				var universe: Array = Solver.universe(view)
				var cc_reps_handle: int = _cc_reps_handle(u_key, universe, cc.rep)
				var reps: Array = []
				if cc_reps_handle < 0:
					for c in range(nc):
						reps.append(universe[cc.rep[c]])
				w_all = Solver.Roles.bluff_weights(view, reps, role_cards, cc_reps_handle, PackedInt32Array())
			neutral = _fits_over(view, cc, role_cards, {}, range(nc), w_all)
		if cache_enabled:
			if _fits_cache.size() > 4096:
				_fits_cache.clear()
			_fits_cache[neutral_key] = {"ref": neutral_ref.duplicate(true), "out": neutral}
	if personal.own_role == "" and personal.own_outings.is_empty() and personal.get("public_roles", {}).is_empty():
		return neutral
	var fits: PackedFloat64Array = _personal_fits(view, cc, role_cards, personal, neutral, neutral_key, neutral_ref, bare, base_fit_key, base_fit_ref, u_neutral, w_all)
	return fits

static var use_cc_reps_handle: bool = true

static func _cc_reps_handle(u_key: String, universe: Array, rep: PackedInt32Array) -> int:
	if not use_cc_reps_handle:
		return -1
	var base_u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var sub_key: String = "cc_reps:%d:%d" % [rep.size(), hash([u_key, rep])]
	return SolverBackend.get_sub_universe_handle(sub_key, base_u_handle, rep)

static func _personal_fits(view: Dictionary, cc: Dictionary, cards: Array, personal: Dictionary, neutral: PackedFloat64Array, neutral_key: int, neutral_ref: Array, bare: bool, base_fit_key: int, base_fit_ref: Array, u_neutral: PackedFloat64Array = PackedFloat64Array(), w_all: PackedFloat64Array = PackedFloat64Array()) -> PackedFloat64Array:
	var live: bool = Domain.live(view)
	var key: int = hash([base_fit_key, personal, live, bare])
	var ref: Array = [base_fit_ref, personal, live, bare]
	if cache_enabled and _fits_cache.has(key) and _fits_cache[key].ref == ref:
		return _fits_cache[key].out
	var out: PackedFloat64Array
	if bare:
		var u_pers: PackedFloat64Array = _bare_world_fits(view, personal, u_neutral)
		out = _slice_by_rep(u_pers, cc.rep)
	else:
		var open: Array = []
		for c in range(cc.team.size()):
			if neutral[c] > 0.0:
				open.append(c)
		if live and _has_bluff_card(cards) and w_all.is_empty():
			var u_key: String = Solver._universe_key(view)
			var universe: Array = Solver.universe(view)
			var cc_reps_handle: int = _cc_reps_handle(u_key, universe, cc.rep)
			var reps: Array = []
			if cc_reps_handle < 0:
				for c in range(cc.team.size()):
					reps.append(universe[cc.rep[c]])
			w_all = Solver.Roles.bluff_weights(view, reps, cards, cc_reps_handle, PackedInt32Array())
		out = _fits_over(view, cc, cards, personal, open, w_all)
	if cache_enabled:
		if _fits_cache.size() > 4096:
			_fits_cache.clear()
			_fits_cache[neutral_key] = {"ref": neutral_ref.duplicate(true), "out": neutral}
		_fits_cache[key] = {"ref": ref.duplicate(true), "out": out}
	return out

static func _fits_over(view: Dictionary, cc: Dictionary, cards: Array, knowledge: Dictionary, classes, w_all: PackedFloat64Array = PackedFloat64Array()) -> PackedFloat64Array:
	var out = PackedFloat64Array()
	out.resize(cc.team.size())
	out.fill(0.0)
	if classes.is_empty():
		return out
	var u_key: String = Solver._universe_key(view)
	var universe: Array = Solver.universe(view)
	var cc_reps_handle: int = _cc_reps_handle(u_key, universe, cc.rep)
	var reps: Array = []
	var which: Array = []
	var sub_idx := PackedInt32Array()
	var n_classes: int = classes.size()
	var full_cc: bool = n_classes == cc.rep.size()
	for k_i in range(n_classes):
		var c: int = int(classes[k_i])
		if cc_reps_handle < 0:
			reps.append(universe[cc.rep[c]])
		which.append(c)
		if full_cc and c != k_i:
			full_cc = false
	if not full_cc and cc_reps_handle >= 0:
		sub_idx.resize(n_classes)
		for k_i in range(n_classes):
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
		for x in range(n_classes):
			if t[x] == 0.0:
				if cc_reps_handle < 0:
					failed.append(reps[x])
				at.append(x)
				if cc_reps_handle >= 0:
					failed_cc_idx.append(int(which[x]))
		var sub: PackedByteArray = Solver.Roles.fits_table(view, failed, claims, knowledge, {}, true, cc_reps_handle, failed_cc_idx)
		declarations.resize(n_classes)
		declarations.fill(0)
		for y in range(at.size()):
			declarations[at[y]] = sub[y]
	var has_w_all: bool = not w_all.is_empty()
	var weights: PackedFloat64Array = PackedFloat64Array()
	if live and not has_w_all and _has_bluff_card(cards):
		weights = Solver.Roles.bluff_weights(view, reps, cards, cc_reps_handle, sub_idx)
	var has_weights: bool = not weights.is_empty()
	var relayed_seers: Array = cards.filter(func(card): return card.kind == "report" and card.get("role", "") == "seer" and card.get("testimony_only", false) and not card.get("quoted", false))
	# Counting readings a Marked person can sway (Solver.marked_counts): weighed by the chance
	# of the registration that fits, in worlds where its reader is good, healthy and sound
	# (Quill's Dowser check, Nov 21). Memoised by what the weight reads.
	var counting: Array = cards.filter(func(card): return Solver.marked_counts(card))
	var self_id: String = str(knowledge.get("self", ""))
	var mc_memo: Dictionary = {}
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
			var w_rep: Dictionary = reps[x] if cc_reps_handle < 0 else universe[cc.rep[which[x]]]
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
		if content > 0.0 and not counting.is_empty():
			var w_rep2: Dictionary = reps[x] if cc_reps_handle < 0 else universe[cc.rep[which[x]]]
			if int(w_rep2.get("marked", -1)) >= 0:
				for card in counting:
					var mk: Array = [card.get("id", ""), int(w_rep2.evil), int(w_rep2.get("converted", -1)), int(w_rep2.marked), str(w_rep2.get("modifier", "")), int(w_rep2.get("holders", 0))]
					if not mc_memo.has(mk):
						mc_memo[mk] = _marked_count_weight(view, w_rep2, card, self_id)
					content *= float(mc_memo[mk])
		var w_mult: float = w_all[which[x]] if has_w_all else (weights[x] if has_weights else 1.0)
		out[which[x]] = content * w_mult
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
	var has_of: bool = of.size() == class_of.size()
	for i in range(class_of.size()):
		var o: int = of[i] if has_of else 0
		if o < 0:
			out[i] = 0.0
			continue
		var k: int = class_of[i] * ns + o
		out[i] = w[k] / counts[k] if counts[k] > 0.0 else 0.0
	return out


## A counting reading's Marked weight in one world (Solver.marked_count_weight), only where its
## content is read: a good reader (Solver.source_valid), not the world's Delusional holder
## (unless it's the listener's own reading), and not under a fallen omen.
static func _marked_count_weight(view: Dictionary, world: Dictionary, card: Dictionary, self_id: String) -> float:
	if not Solver.source_valid(view, world, card):
		return 1.0
	var src: int = Solver.person_index(view, str(card.get("source", "")))
	var mod: String = str(world.get("modifier", ""))
	var holders: int = int(world.get("holders", 0))
	if src >= 0 and mod == "delusional" and (holders & (1 << src)) and str(card.get("source", "")) != self_id:
		return 1.0
	if mod == "ill_omened":
		for cid in card.get("omen_claimants", []):
			var ci: int = Solver.person_index(view, str(cid))
			if ci >= 0 and (holders & (1 << ci)):
				return 1.0
	return Solver.marked_count_weight(view, world, card)
