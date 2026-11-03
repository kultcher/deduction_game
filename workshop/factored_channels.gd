## Production channel likelihoods: Boolean evidence gates plus exact sum-product.
## Only interacting role/route predicates share factors. There is no enumeration
## of the Cartesian product of source states, and no source is dropped to repair
## a contradiction. channel_likelihood.gd remains the independent exhaustive oracle.
extends RefCounted
const Channels = preload("res://workshop/evidence_channels.gd")
const Sum = preload("res://workshop/channel_sum_product.gd")
const Solver = preload("res://workshop/solver.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Movement = preload("res://workshop/movement_model.gd")
const Public = preload("res://workshop/public_evidence.gd")
const Speech = preload("res://workshop/speech_evidence.gd")
static var cache = {}

static func assess(view: Dictionary, cards: Array, knowledge: Dictionary, rates: Dictionary, q: Dictionary, baseline_ids: Array = [], representatives: PackedInt32Array = PackedInt32Array(), multiplicity: PackedFloat64Array = PackedFloat64Array(), include_public: bool = true) -> Dictionary:
	if not SolverBackend.profiling_enabled:
		return _assess_impl(view, cards, knowledge, rates, q, baseline_ids, representatives, multiplicity, include_public)
	var _st: int = SolverBackend.begin_stage("channel_sum_product")
	var _res: Dictionary = _assess_impl(view, cards, knowledge, rates, q, baseline_ids, representatives, multiplicity, include_public)
	SolverBackend.end_stage(_st)
	return _res

static func _assess_impl(view: Dictionary, cards: Array, knowledge: Dictionary, rates: Dictionary, q: Dictionary, baseline_ids: Array = [], representatives: PackedInt32Array = PackedInt32Array(), multiplicity: PackedFloat64Array = PackedFloat64Array(), include_public: bool = true) -> Dictionary:
	var start = Time.get_ticks_usec()
	var input = [Solver._query_view(view), cards, Solver._query_knowledge(knowledge), include_public]
	var key = hash(input)
	if not cache.has(key) or cache[key].input != input:
		if cache.size() >= 32:
			cache.clear()
		cache[key] = {"input": input.duplicate(true), "graph": _compile(view, cards, knowledge, include_public)}
	var graph: Dictionary = cache[key].graph
	var compile_us = Time.get_ticks_usec() - start
	var result = {"base": PackedFloat64Array(), "post": PackedFloat64Array(), "held": {}, "acceptance": {}, "consistent": false,
		"issues": graph.issues, "states": 0, "peak_rows": graph.get("program", {}).get("peak", 0)}
	if not graph.issues.is_empty():
		return result

	var universe: Array = Solver.universe(view)
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		result = _assess_worlds_gd(view, graph, universe, rates, q, representatives, multiplicity, compile_us)
	elif mode == SolverBackend.Mode.CSHARP:
		result = _assess_worlds_cs(view, graph, universe, rates, q, representatives, multiplicity, compile_us)
	else:
		result = _assess_worlds_gd(view, graph, universe, rates, q, representatives, multiplicity, compile_us)
		var cs_res: Dictionary = _assess_worlds_cs(view, graph, universe, rates, q, representatives, multiplicity, compile_us)
		var b = SolverBackend._bridge()
		b.VerifyScalarInt64("FactoredChannels.assess.states", result.states, cs_res.states)
		b.VerifyScalarBool("FactoredChannels.assess.consistent", result.consistent, cs_res.consistent)
		b.VerifyFloat64Buffer("FactoredChannels.assess.post", result.post, cs_res.post, 0.0)
		for id in graph.markers:
			b.VerifyFloat64Buffer("FactoredChannels.assess.held", result.held[id], cs_res.held[id], 0.0)
			b.VerifyScalarFloat64("FactoredChannels.assess.acceptance", float(result.acceptance[id]), float(cs_res.acceptance[id]), 0.0)

	if not include_public:
		result.base = result.post.duplicate()
	else:
		var prior = assess(view, cards.filter(func(card): return card.id in baseline_ids), knowledge, rates, q, [], representatives, multiplicity, false)
		result.base = prior.post
	return result

static func _assess_worlds_gd(view: Dictionary, graph: Dictionary, universe: Array, rates: Dictionary, q: Dictionary, representatives: PackedInt32Array, multiplicity: PackedFloat64Array, compile_us: int) -> Dictionary:
	var value_us = 0
	var sum_us = 0
	var result = {"base": PackedFloat64Array(), "post": PackedFloat64Array(), "held": {}, "acceptance": {}, "consistent": false,
		"issues": graph.issues, "states": 0, "peak_rows": graph.get("program", {}).get("peak", 0)}
	var size: int = universe.size() if representatives.is_empty() else representatives.size()
	result.post.resize(size)
	for id in graph.markers:
		var held = PackedFloat64Array()
		held.resize(size)
		result.held[id] = held
	var memo = {}
	for slot in range(size):
		var index: int = slot if representatives.is_empty() else representatives[slot]
		var world: Dictionary = universe[index]
		var value_start = Time.get_ticks_usec()
		var values: Array = []
		for factor in graph.factors:
			values.append(_values(view, graph, factor, world, index, rates, q))
		var signature = hash(values)
		value_us += Time.get_ticks_usec() - value_start
		var sum_start = Time.get_ticks_usec()
		if not memo.has(signature) or memo[signature].values != values:
			memo[signature] = {"values": values, "result": Sum._run_gd(graph.circuit, values)}
		var summed: Dictionary = memo[signature].result
		sum_us += Time.get_ticks_usec() - sum_start
		result.post[slot] = summed.total
		for id in graph.markers:
			var marker: int = graph.markers[id]
			result.held[id][slot] = summed.adjoints[marker][0 if graph.factors[marker].scope.is_empty() else 1]
		if not result.consistent and summed.total > 0.0:
			result.consistent = _all_hold(view, graph, world, index)
	result.states = memo.size()
	result["timing_us"] = {"compile": compile_us, "values": value_us, "sum": sum_us}
	var total = 0.0
	for slot in range(size):
		total += result.post[slot] * (1.0 if multiplicity.is_empty() else multiplicity[slot])
	for id in graph.markers:
		var mass = 0.0
		for slot in range(size):
			mass += result.held[id][slot] * (1.0 if multiplicity.is_empty() else multiplicity[slot])
		result.acceptance[id] = mass / total if total > 0.0 else 0.0
	return result

static func _assess_worlds_cs(view: Dictionary, graph: Dictionary, universe: Array, rates: Dictionary, q: Dictionary, representatives: PackedInt32Array, multiplicity: PackedFloat64Array, compile_us: int) -> Dictionary:
	var value_start: int = Time.get_ticks_usec()
	var u_key: String = Solver._universe_key(view)
	var u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(universe) if u_handle < 0 else PackedInt64Array()
	var n_people: int = view.people.size()
	var size: int = universe.size() if representatives.is_empty() else representatives.size()
	var has_reps: bool = not representatives.is_empty()

	# Pre-populate conditional factor.rows for any missing coarse signatures across the evaluated slice:
	for factor in graph.factors:
		var fk: String = str(factor.kind)
		if fk in ["static", "prior", "chance", "report", "knowledge", "public"]:
			continue
		if fk in ["forced_lamp", "route_counts", "fixture_movement"]:
			if not factor.rows.has(0):
				var w0: Dictionary = universe[representatives[0] if has_reps and size > 0 else 0]
				_values(view, graph, factor, w0, representatives[0] if has_reps and size > 0 else 0, rates, q)
			continue
		if fk == "activity":
			var p_idx: int = Solver.person_index(view, str(factor.person.id))
			for slot in range(size):
				if factor.rows.size() >= 3:
					break
				var idx: int = representatives[slot] if has_reps else slot
				var w: Dictionary = universe[idx]
				var sig: int = 2 if w.get("demon", -1) == p_idx else (1 if w.evil & (1 << p_idx) else 0)
				if not factor.rows.has(sig):
					_values(view, graph, factor, w, idx, rates, q)
			continue
		if fk == "roles":
			var walkers: int = 0
			for wid in factor.get("walker_ids", []):
				var wi: int = Solver.person_index(view, str(wid))
				if wi >= 0:
					walkers |= (1 << wi)
			var mediums: int = 0
			for mid in factor.get("relay_ids", []):
				var mi: int = Solver.person_index(view, str(mid))
				if mi >= 0:
					mediums |= (1 << mi)
			var masks: PackedInt64Array = Solver.Roles.coarse_masks(n_people, universe, bool(factor.seer), mediums, walkers, u_handle)
			for slot in range(size):
				var idx: int = representatives[slot] if has_reps else slot
				var sig: int = masks[idx]
				if not factor.rows.has(sig):
					_values(view, graph, factor, universe[idx], idx, rates, q)
			continue
		if fk == "speech":
			for slot in range(size):
				var idx: int = representatives[slot] if has_reps else slot
				var w: Dictionary = universe[idx]
				var sig: int = int(w.evil) * (n_people + 1) + int(w.get("demon", -1)) + 1
				if not factor.rows.has(sig):
					_values(view, graph, factor, w, idx, rates, q)

	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var factor_specs := PackedInt32Array()
	var factor_doubles := PackedFloat64Array()
	var flat_byte_tables := PackedByteArray()
	var table_count: int = 0
	var public_specs := PackedInt32Array()
	var public_ratios := PackedFloat64Array()
	var cond_sigs := PackedInt64Array()
	var cond_offsets := PackedInt32Array([0])
	var flat_cond_rows := PackedFloat64Array()

	var n_factors: int = graph.factors.size()
	factor_specs.resize(n_factors * 6)

	for fi in range(n_factors):
		var factor: Dictionary = graph.factors[fi]
		var fk: String = str(factor.kind)
		var off: int = fi * 6
		var k_code: int = 0
		var p_a: int = 0
		var p_b: int = 0
		var p_c: int = 0
		var c_start: int = 0
		var c_count: int = 0

		match fk:
			"static":
				k_code = 0
				p_b = factor_doubles.size()
				var sv: PackedFloat64Array = factor.values
				factor_doubles.append_array(sv)
				p_c = sv.size()
			"prior":
				var rate = rates[factor.channel.key]
				if rate is Dictionary:
					k_code = 2
					p_a = Solver.person_index(view, str(factor.channel.source))
					p_b = factor_doubles.size()
					factor_doubles.append(float(rate.healthy))
					factor_doubles.append(float(rate.impaired))
				else:
					k_code = 1
					p_b = factor_doubles.size()
					factor_doubles.append(float(rate))
			"chance":
				k_code = 3
				p_a = 1 if not factor.scope.is_empty() else 0
				p_b = factor_doubles.size()
				factor_doubles.append(float(q.get(factor.origin, q.get(factor.card.id, 1.0))))
			"report":
				k_code = 4
				p_a = 1 if not factor.scope.is_empty() else 0
				p_b = table_count
				flat_byte_tables.append_array(factor.table)
				table_count += 1
			"knowledge":
				k_code = 5
				p_b = table_count
				flat_byte_tables.append_array(factor.table)
				table_count += 1
			"public":
				k_code = 6
				for pf in factor.factors:
					public_specs.append(Solver.person_index(view, str(pf.target)))
					var pf_ep = pf.get("epoch", view.get("alignment_epoch", ""))
					public_specs.append(1 if Solver._curse_active_at(view, pf_ep) else 0)
					public_ratios.append(pow(2.0, float(pf.log2_ratio)))
			"forced_lamp", "route_counts", "fixture_movement":
				k_code = 7
				c_start = cond_sigs.size()
				for sig_k in factor.rows:
					cond_sigs.append(int(sig_k))
					flat_cond_rows.append_array(factor.rows[sig_k])
					cond_offsets.append(flat_cond_rows.size())
					c_count += 1
			"activity":
				k_code = 8
				p_a = Solver.person_index(view, str(factor.person.id))
				c_start = cond_sigs.size()
				for sig_k in factor.rows:
					cond_sigs.append(int(sig_k))
					flat_cond_rows.append_array(factor.rows[sig_k])
					cond_offsets.append(flat_cond_rows.size())
					c_count += 1
			"roles":
				k_code = 9
				p_a = 1 if bool(factor.seer) else 0
				for mid in factor.get("relay_ids", []):
					var mi: int = Solver.person_index(view, str(mid))
					if mi >= 0:
						p_b |= (1 << mi)
				for wid in factor.get("walker_ids", []):
					var wi: int = Solver.person_index(view, str(wid))
					if wi >= 0:
						p_c |= (1 << wi)
				c_start = cond_sigs.size()
				for sig_k in factor.rows:
					cond_sigs.append(int(sig_k))
					flat_cond_rows.append_array(factor.rows[sig_k])
					cond_offsets.append(flat_cond_rows.size())
					c_count += 1
			"speech":
				k_code = 10
				c_start = cond_sigs.size()
				for sig_k in factor.rows:
					cond_sigs.append(int(sig_k))
					flat_cond_rows.append_array(factor.rows[sig_k])
					cond_offsets.append(flat_cond_rows.size())
					c_count += 1

		factor_specs[off] = k_code
		factor_specs[off + 1] = p_a
		factor_specs[off + 2] = p_b
		factor_specs[off + 3] = p_c
		factor_specs[off + 4] = c_start
		factor_specs[off + 5] = c_count

	var marker_ids: Array = graph.markers.keys()
	var n_markers: int = marker_ids.size()
	var m_factors := PackedInt32Array()
	var m_rows := PackedInt32Array()
	m_factors.resize(n_markers)
	m_rows.resize(n_markers)
	for mi in range(n_markers):
		var mf_idx: int = int(graph.markers[marker_ids[mi]])
		m_factors[mi] = mf_idx
		m_rows[mi] = 0 if graph.factors[mf_idx].scope.is_empty() else 1

	var cir_h: int = Sum.lookup_circuit_handle(graph.circuit)
	var fb_cir: PackedInt32Array = Sum.pack_flat_circuit(graph.circuit) if cir_h < 0 else PackedInt32Array()
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	var value_us: int = Time.get_ticks_usec() - value_start
	var sum_start: int = Time.get_ticks_usec()
	SolverBackend.record_boundary_call("FactoredChannels.assess_batch", pack_u)
	var raw: PackedFloat64Array = SolverBackend._bridge().FactoredAssessBatch(
		u_handle, fallback, n_people, representatives, multiplicity,
		cir_h, fb_cir, factor_specs, factor_doubles, universe.size(), flat_byte_tables,
		public_specs, public_ratios, cond_sigs, cond_offsets, flat_cond_rows, m_factors, m_rows
	)
	var sum_us: int = Time.get_ticks_usec() - sum_start

	var states_cnt: int = int(raw[0])
	var post: PackedFloat64Array = raw.slice(1, 1 + size)
	var held_dict: Dictionary = {}
	var acc_dict: Dictionary = {}
	var h_base: int = 1 + size
	var a_base: int = 1 + size + n_markers * size
	for mi in range(n_markers):
		var mid = marker_ids[mi]
		held_dict[mid] = raw.slice(h_base + mi * size, h_base + (mi + 1) * size)
		acc_dict[mid] = raw[a_base + mi]

	var consistent: bool = false
	for slot in range(size):
		if post[slot] > 0.0:
			var idx: int = representatives[slot] if has_reps else slot
			if _all_hold(view, graph, universe[idx], idx):
				consistent = true
				break

	return {
		"base": PackedFloat64Array(),
		"post": post,
		"held": held_dict,
		"acceptance": acc_dict,
		"consistent": consistent,
		"issues": graph.issues,
		"states": states_cnt,
		"peak_rows": graph.get("program", {}).get("peak", 0),
		"timing_us": {"compile": compile_us, "values": value_us, "sum": sum_us},
	}

static func _compile(view: Dictionary, cards: Array, knowledge: Dictionary, include_public: bool) -> Dictionary:
	var plan = Channels.compile(view, cards)
	var graph = {"issues": plan.issues, "channels": plan.channels, "next": plan.channels.size(), "factors": [], "gates": {}, "facts": [], "originals": {}, "markers": {}, "knowledge": knowledge}
	if not graph.issues.is_empty():
		return graph
	for i in range(plan.channels.size()):
		_add(graph, [i], {"kind": "prior", "channel": plan.channels[i]})
	var bodies = {}
	for statement in plan.statements:
		var card: Dictionary = statement.card
		if card.get("quoted", false):
			_fact(bodies, card, -1)
			continue
		var content = _and(graph, statement.content)
		graph.markers[card.id] = _add(graph, [content] if content >= 0 else [], {"kind": "static", "values": PackedFloat64Array([1, 1]) if content >= 0 else PackedFloat64Array([1]), "query": true})
		_fact(bodies, statement.body, content)
		if card.kind == "report":
			_claim(bodies, graph, card.source, card.role, card.observed_at, statement.identity)
			if not graph.originals.has(statement.origin):
				graph.originals[statement.origin] = {"routes": [], "card": card}
			graph.originals[statement.origin].routes.append(content)
		if card.has("relay_source"):
			_claim(bodies, graph, card.relay_source, "medium", card.relay_observed_at, statement.relay_identity)
			_fact(bodies, {"kind": "context", "source": card.source, "relay_source": card.relay_source, "relay_observed_at": card.relay_observed_at}, _and(graph, statement.relay_content))
	for body in bodies.values():
		var card: Dictionary = body.card
		card["id"] = "predicate:" + str(graph.facts.size())
		card["fact_id"] = card.id
		graph.facts.append({"card": card, "variable": _or(graph, body.routes)})
	for origin in graph.originals:
		var item: Dictionary = graph.originals[origin]
		var variable = _or(graph, item.routes)
		_add(graph, [variable] if variable >= 0 else [], {"kind": "chance", "origin": origin, "card": item.card})
	for fact in graph.facts:
		if Solver.tabled(fact.card):
			_add(graph, _scope([fact]), {"kind": "report", "fact": fact, "table": Solver.report_table(view, fact.card)})
	_movement(view, graph)
	_roles(view, graph)
	var allowed = PackedByteArray()
	allowed.resize(Solver.universe(view).size())
	for world in Solver.solve(view, [], {}, {}, knowledge).worlds:
		allowed[world.__i if world.has("__i") else Solver.universe(view).find(world)] = 1
	_add(graph, [], {"kind": "knowledge", "table": allowed})
	var public_factors: Array = Public.factors(view)
	if include_public and not public_factors.is_empty():
		_add(graph, [], {"kind": "public", "factors": public_factors})
	var speech: Array = graph.facts.filter(func(f): return f.card.kind == "gift_hint")
	if not speech.is_empty():
		_conditional(graph, speech, "speech")
	graph.program = Sum.compile(graph.factors.map(func(factor): return factor.scope))
	graph.circuit = Sum.circuit(graph.program, graph.factors.map(func(f): return f.values if f.kind == "static" and not f.get("query", false) else null))
	return graph

static func _add(graph: Dictionary, scope: Array, data: Dictionary) -> int:
	data["scope"] = scope
	graph.factors.append(data)
	return graph.factors.size() - 1

static func _and(graph: Dictionary, variables: Array) -> int:
	var unique: Array = []
	for variable in variables:
		if variable == -2:
			return -2
		if variable >= 0 and variable not in unique:
			unique.append(variable)
	if unique.is_empty():
		return -1
	var output: int = unique[0]
	for i in range(1, unique.size()):
		output = _gate(graph, output, unique[i], false)
	return output

static func _or(graph: Dictionary, variables: Array) -> int:
	if -1 in variables:
		return -1
	var unique: Array = []
	for variable in variables:
		if variable >= 0 and variable not in unique:
			unique.append(variable)
	if unique.is_empty():
		return -2
	var output: int = unique[0]
	for i in range(1, unique.size()):
		output = _gate(graph, output, unique[i], true)
	return output

static func _gate(graph: Dictionary, a: int, b: int, either: bool) -> int:
	var key = str([mini(a, b), maxi(a, b), either])
	if graph.gates.has(key):
		return graph.gates[key]
	var output: int = graph.next
	graph.next += 1
	var values = PackedFloat64Array()
	values.resize(8)
	for row in range(8):
		var holds: bool = (row & 1 != 0 or row & 2 != 0) if either else (row & 3 == 3)
		values[row] = 1.0 if holds == (row & 4 != 0) else 0.0
	_add(graph, [a, b, output], {"kind": "static", "values": values})
	graph.gates[key] = output
	return output

static func _fact(bodies: Dictionary, card: Dictionary, variable: int) -> void:
	var body = card.duplicate(true)
	body.erase("id")
	body.erase("fact_id")
	var key = Evidence.canonical(body)
	if not bodies.has(key):
		bodies[key] = {"card": body, "routes": []}
	bodies[key].routes.append(variable)

static func _claim(bodies: Dictionary, graph: Dictionary, source: String, role: String, at: Dictionary, dependencies: Array) -> void:
	# Timing remains in reports. A truthful identity is one constraint even when
	# repeated tomorrow or embedded in several accurate/inaccurate readings.
	_fact(bodies, {"kind": "claim", "source": source, "role": role, "data": {}}, _and(graph, dependencies))

static func _scope(facts: Array) -> Array:
	var result: Array = []
	for fact in facts:
		if fact.variable >= 0 and fact.variable not in result:
			result.append(fact.variable)
	result.sort()
	return result

static func _selected(facts: Array, scope: Array, row: int) -> Array:
	return facts.filter(func(f): return f.variable == -1 or (f.variable >= 0 and row & (1 << scope.find(f.variable)))).map(func(f): return f.card)

static func _conditional(graph: Dictionary, facts: Array, kind: String, extra: Dictionary = {}) -> Dictionary:
	var cards: Array = facts.map(func(f): return f.card)
	var factor = {"kind": kind, "facts": facts, "rows": {}, "seer": Solver.Roles.seer_flag(cards),
		"relay_ids": cards.filter(func(c): return c.has("relay_source") and not c.get("quoted", false)).map(func(c): return c.relay_source),
		"walker_ids": cards.filter(func(c): return c.get("kind", "") == "secret_claim" and c.get("data", {}).get("secret_kind", "") == "sleepwalker" and not c.get("quoted", false)).map(func(c): return c.subject)}
	factor.merge(extra)
	_add(graph, _scope(facts), factor)
	return factor

## Each role-completion component only touches predicates that can constrain the
## same gift or the same holder. Hall matching stays exact inside that component;
## separate gifts/sources integrate independently.
static func _roles(view: Dictionary, graph: Dictionary) -> void:
	var facts: Array = graph.facts.filter(func(f): return _role_keys(f.card).size() > 0)
	var components: Array = []
	for fact in facts:
		var keys = _role_keys(fact.card)
		var combined: Array = [fact]
		var merged = true
		while merged:
			merged = false
			for i in range(components.size() - 1, -1, -1):
				if components[i].keys.any(func(k): return k in keys):
					combined.append_array(components[i].facts)
					for k in components[i].keys:
						if k not in keys:
							keys.append(k)
					components.remove_at(i)
					merged = true
		components.append({"facts": combined, "keys": keys})
	for component in components:
		_conditional(graph, component.facts, "roles")

static func _role_keys(card: Dictionary) -> Array:
	if card.get("quoted", false):
		return []
	var result: Array = []
	if card.kind == "claim" or (card.kind == "report" and card.role in ["seer", "clerk", "archivist", "gravedigger", "veteran", "martyr", "sexton", "nightwatch", "lamplighter", "medium"]):
		result = ["gift:" + card.role, "holder:" + card.source]
		if card.kind == "report" and card.role in ["clerk", "archivist", "gravedigger"]:
			result.append("gift:" + card.data.role)
			for person in card.data.get("pair", [card.data.get("executed", "")]):
				result.append("holder:" + person)
		if card.kind == "report" and card.role == "sexton":
			result.append("night-walk")
	elif card.kind == "totem":
		result = ["gift:revenant"] + card.data.candidates.map(func(id): return "holder:" + id)
	elif card.kind == "event" and card.get("event") == "martyr":
		result = ["gift:martyr", "holder:" + card.data.martyr]
	if card.has("relay_source"):
		result.append_array(["gift:medium", "holder:" + card.relay_source, "night-walk"])
	if card.kind == "report" and card.role in ["nightwatch", "lamplighter", "medium"]:
		result.append("night-walk")
	return result

static func _movement(view: Dictionary, graph: Dictionary) -> void:
	if not graph.facts.any(func(f): return not Activity.relevant([f.card]).is_empty() or f.card.has("relay_source")):
		return
	var movement_facts: Array = graph.facts.filter(func(f): return Activity.movement_inputs(view, [f.card], {}, true)[0].size() > 0 or f.card.kind == "claim")
	if not Activity.available(view):
		_conditional(graph, movement_facts, "fixture_movement")
		return
	var coupled: bool = movement_facts.any(func(f): return f.card.kind == "dropped" or f.card.get("item_drop", false) or f.card.get("role") == "lamplighter" and f.card.kind == "report" and not f.card.get("duty_only", false))
	if coupled:
		_conditional(graph, movement_facts, "route_counts")
	for person in view.people:
		var local: Array = movement_facts if coupled else movement_facts.filter(func(f): return _affects(f.card, person.id))
		if local.is_empty():
			continue
		_conditional(graph, local, "activity", {"person": person, "coupled": coupled})
		var scope = _scope(local)
		var variable: int = graph.next
		graph.next += 1
		_conditional(graph, local, "forced_lamp", {"person": person, "output": variable})
		graph.factors[-1].scope = scope + [variable]
		var table = _values(view, graph, graph.factors[-1], Solver.universe(view)[0], 0, {}, {})
		if range(1 << scope.size(), table.size()).any(func(i): return table[i] > 0.0):
			graph.facts.append({"card": {"id": "inferred-lamp:" + person.id, "kind": "claim", "source": person.id, "role": "lamplighter", "data": {}}, "variable": variable})
		else:
			graph.factors.pop_back() # Always-false inference integrates out, with no coupling.

static func _affects(card: Dictionary, person: String) -> bool:
	if card.get("quoted", false) and card.kind != "alibi":
		return false
	if card.has("relay_source"):
		return card.relay_source == person
	if card.kind == "claim":
		return card.get("source", "") == person
	if card.kind == "report":
		return (card.role == "nightwatch" and (not card.get("duty_only", false) or card.get("source", "") == person)) or (card.role in ["lamplighter", "veteran", "medium"] and card.get("source", "") == person)
	if card.kind in ["coverage", "trace"]:
		return true
	if card.kind == "sighting":
		return card.get("complete", false) or person in card.get("subjects", [card.get("subject", "")])
	if card.kind == "evening":
		return person in card.get("subjects", [card.get("subject", "")])
	return card.get("subject", "") == person

static func _values(view: Dictionary, graph: Dictionary, factor: Dictionary, world: Dictionary, index: int, rates: Dictionary, q: Dictionary) -> PackedFloat64Array:
	if factor.kind == "static":
		return factor.values
	if factor.kind == "prior":
		var rate = rates[factor.channel.key]
		var p: float = float(rate.healthy if Solver.Domain.healthy(view, world, factor.channel.source) else rate.impaired) if rate is Dictionary else float(rate)
		return PackedFloat64Array([1.0 - p, p])
	if factor.kind == "chance":
		var chance: float = float(q.get(factor.origin, q.get(factor.card.id, 1.0)))
		return PackedFloat64Array([chance, 1.0]) if not factor.scope.is_empty() else PackedFloat64Array([1.0])
	if factor.kind == "report":
		var holds: float = float(factor.table[index])
		return PackedFloat64Array([1.0, holds]) if not factor.scope.is_empty() else PackedFloat64Array([holds])
	if factor.kind == "knowledge":
		return PackedFloat64Array([float(factor.table[index])])
	if factor.kind == "public":
		var weight = 1.0
		for f in factor.factors:
			if Solver.TimeModel.evil_at(view, world, f.target, f.get("epoch", view.alignment_epoch)):
				weight *= pow(2.0, float(f.log2_ratio))
		return PackedFloat64Array([weight])
	var walkers: int = 0
	if factor.kind == "roles" and not factor.get("walker_ids", []).is_empty():
		for id in factor.walker_ids:
			var i: int = Solver.person_index(view, id)
			if i >= 0:
				walkers |= 1 << i
	var mediums: int = 0
	if factor.kind == "roles" and not factor.get("relay_ids", []).is_empty():
		for id in factor.relay_ids:
			var i: int = Solver.person_index(view, id)
			if i >= 0:
				mediums |= 1 << i
	var signature: int = Solver.Roles.coarse_mask(view.people.size(), world, factor.seer, mediums, walkers) if factor.kind == "roles" else (int(world.evil) * (view.people.size() + 1) + int(world.get("demon", -1)) + 1)
	if factor.kind in ["forced_lamp", "route_counts", "fixture_movement"]:
		signature = 0
	if factor.kind == "activity":
		var person_index = Solver.person_index(view, factor.person.id)
		signature = 2 if world.get("demon", -1) == person_index else (1 if world.evil & (1 << person_index) else 0)
	if factor.rows.has(signature):
		return factor.rows[signature]
	var values = PackedFloat64Array()
	values.resize(1 << factor.scope.size())
	var plain = view.duplicate()
	plain.live_activity = false # Routes have their own factors; don't add a global gate.
	var scope: Array = factor.scope.filter(func(v): return v != factor.get("output", -10))
	for row in range(1 << scope.size()):
		var selected = _selected(factor.facts, scope, row)
		var weight = 1.0
		match factor.kind:
			"roles":
				weight = 1.0 if (not Solver.Domain.live(view) or Solver.Domain.claims_compatible(selected, graph.knowledge)) and Solver.Roles.fits(plain, world, selected, graph.knowledge) else 0.0
			"fixture_movement":
				weight = 1.0 if Solver.movement_for(view, selected, {}, graph.knowledge).okay else 0.0
				for f in Movement.factors(view, selected, {}):
					if Solver.TimeModel.evil_at(view, world, f.target, f.get("epoch", view.alignment_epoch)):
						weight *= pow(2.0, float(f.log2_ratio))
			"route_counts":
				weight = 1.0 if Activity.routes(view, selected, {}, graph.knowledge).okay else 0.0
			"activity", "forced_lamp":
				var nights = {}
				for card in Activity.relevant(selected):
					if card.get("night", -1) >= 0 and card.kind not in ["evening", "trace"]:
						nights[str(card.night)] = true
				for card in selected:
					if card.has("relay_source") and not card.get("quoted", false):
						nights[str(card.relay_observed_at.day)] = true
				var forced_lamp = false
				var checked = selected.duplicate()
				var okay = true
				var counts = Activity.routes(view, selected, {}, {}, false) if factor.get("coupled", false) else {}
				for night in nights:
					var paths = Activity._paths(view, factor.person, int(night), selected, graph.knowledge)
					okay = okay and not paths.is_empty()
					forced_lamp = forced_lamp or not paths.is_empty() and paths.all(func(path): return path.size() == 4)
					# Likelihood inference must use the same fallible-report routes as Activity.factors.
					var likelihood_paths = Activity._paths(view, factor.person, int(night), selected, {}, false)
					var out: bool = factor.person.id in counts.get("nights", {}).get(night, {}).get("forced_out", []) if not counts.is_empty() else not likelihood_paths.is_empty() and likelihood_paths.all(func(path): return not path.is_empty())
					if out:
						checked.append({"id": "inferred-out:%s:%s" % [factor.person.id, night], "kind": "sighting", "source": "evidence", "subject": factor.person.id, "subjects": [factor.person.id], "block": "", "night": int(night)})
				if factor.kind == "forced_lamp":
					values[row + ((1 << scope.size()) if forced_lamp else 0)] = 1.0
					continue
				var type: String = "demon" if world.get("demon", -1) == Solver.person_index(view, factor.person.id) else ("minion" if world.evil & (1 << Solver.person_index(view, factor.person.id)) else "good")
				weight = 1.0 if okay else 0.0
				if not Activity.relevant(selected).is_empty():
					weight *= maxf(Activity._likelihood(view, checked, factor.person, type), 1e-30) / maxf(Activity._likelihood(view, checked, factor.person, "good"), 1e-30)
			"speech":
				for f in Speech.factors(selected):
					if Solver.TimeModel.evil_at(view, world, f.target, f.get("epoch", view.alignment_epoch)):
						weight *= pow(2.0, float(f.log2_ratio))
		values[row] = weight
	factor.rows[signature] = values
	return values

static func _all_hold(view: Dictionary, graph: Dictionary, world: Dictionary, index: int) -> bool:
	# Diagnostic only, once a positive world is found; rates never enter this check.
	var cards: Array = graph.facts.filter(func(f): return not f.card.id.begins_with("inferred-lamp:")).map(func(f): return f.card)
	return cards.filter(func(c): return Solver.tabled(c)).all(func(c): return Solver.report_table(view, c)[index] == 1) and (not Solver.Domain.live(view) or Solver.Domain.claims_compatible(cards, graph.knowledge)) and Solver.Roles.fits(view, world, cards, graph.knowledge) and Solver.movement_for(view, cards, {}, graph.knowledge).okay
