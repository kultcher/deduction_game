## Exact binary sum-product. Eliminate one variable at a time, multiplying only
## factors that mention it. Independent sources never form a Cartesian product.
## A reverse pass gives every input-factor marginal, including zero-weight rows.
extends RefCounted

static var _program_entries: Array = []
static var _circuit_entries: Array = []
static var _handles_epoch: int = -1

static func _ensure_epoch() -> void:
	var b = SolverBackend._bridge()
	if b == null:
		return
	var ep: int = int(b.GetContextEpoch())
	if ep != _handles_epoch:
		_program_entries.clear()
		_circuit_entries.clear()
		_handles_epoch = ep

static func _lookup_program_handle(program: Dictionary) -> int:
	_ensure_epoch()
	for i in range(_program_entries.size() - 1, -1, -1):
		if is_same(_program_entries[i][0], program):
			return int(_program_entries[i][1])
	return -1

static func _store_program_handle(program: Dictionary, h: int) -> void:
	_ensure_epoch()
	if _program_entries.size() >= 64:
		_program_entries.clear()
	_program_entries.append([program, h])

static func lookup_circuit_handle(circuit_data: Dictionary) -> int:
	_ensure_epoch()
	for i in range(_circuit_entries.size() - 1, -1, -1):
		if is_same(_circuit_entries[i][0], circuit_data):
			return int(_circuit_entries[i][1])
	return -1

static func _store_circuit_handle(circuit_data: Dictionary, h: int) -> void:
	_ensure_epoch()
	if _circuit_entries.size() >= 64:
		_circuit_entries.clear()
	_circuit_entries.append([circuit_data, h])

static func pack_flat_program(program: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.append(int(program.inputs))
	out.append(int(program.peak))
	out.append(program.nodes.size())
	for node in program.nodes:
		out.append(node.scope.size())
		for v in node.scope:
			out.append(int(v))
	out.append(program.steps.size())
	for st in program.steps:
		out.append(int(st.output))
		out.append(int(st.size))
		out.append(st.inputs.size())
		for inp in st.inputs:
			out.append(int(inp))
		for mp in st.maps:
			out.append_array(mp)
	out.append(program.roots.size())
	for r in program.roots:
		out.append(int(r))
	return out

static func pack_flat_circuit(circuit_data: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.append(int(circuit_data.root))
	out.append(circuit_data.ops.size())
	for op in circuit_data.ops:
		var k: int = int(op[0])
		out.append(k)
		if k == 0:
			out.append(1 if float(op[1]) == 1.0 else 0)
			out.append(0)
		else:
			out.append(int(op[1]))
			out.append(int(op[2]))
	out.append(circuit_data.inputs.size())
	for inp in circuit_data.inputs:
		out.append(int(inp[0]))
		out.append(int(inp[1]))
		out.append(int(inp[2]))
	out.append(circuit_data.shapes.size())
	for sh in circuit_data.shapes:
		out.append(int(sh))
	return out

static func factor(scope: Array, values: Array) -> Dictionary:
	return {"scope": scope, "values": PackedFloat64Array(values)}

static func compile(scopes: Array) -> Dictionary:
	if not SolverBackend.profiling_enabled:
		return _compile_dispatch(scopes)
	var _st: int = SolverBackend.begin_stage("channel_sum_product")
	var _res: Dictionary = _compile_dispatch(scopes)
	SolverBackend.end_stage(_st)
	return _res

static func _compile_dispatch(scopes: Array) -> Dictionary:
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _compile_gd(scopes)
	var cs_pair: Array = _compile_cs(scopes)
	var cs_prog: Dictionary = cs_pair[0]
	var cs_h: int = int(cs_pair[1])
	if mode == SolverBackend.Mode.CSHARP:
		_store_program_handle(cs_prog, cs_h)
		return cs_prog
	var gd_prog: Dictionary = _compile_gd(scopes)
	var b = SolverBackend._bridge()
	b.VerifyScalarInt64("ChannelSumProduct.compile.peak", gd_prog.peak, cs_prog.peak)
	b.VerifyScalarInt64("ChannelSumProduct.compile.steps", gd_prog.steps.size(), cs_prog.steps.size())
	b.VerifyInt32Buffer("ChannelSumProduct.compile.flat", pack_flat_program(gd_prog), pack_flat_program(cs_prog))
	_store_program_handle(gd_prog, cs_h)
	return gd_prog

static func _compile_gd(scopes: Array) -> Dictionary:
	var nodes: Array = scopes.map(func(scope): return {"scope": scope.duplicate()})
	var active: Array = range(nodes.size())
	var steps: Array = []
	var peak = 1
	while active.any(func(i): return not nodes[i].scope.is_empty()):
		var choices = {}
		for i in active:
			for variable in nodes[i].scope:
				choices[variable] = true
		var selected = -1
		var best: Array = []
		for variable in choices:
			var joined: Array = []
			for i in active:
				if variable in nodes[i].scope:
					for other in nodes[i].scope:
						if other not in joined:
							joined.append(other)
			if selected < 0 or joined.size() < best.size():
				selected = variable
				best = joined
		var inputs: Array = active.filter(func(i): return selected in nodes[i].scope)
		best.erase(selected)
		best.sort()
		var joined: Array = best + [selected]
		var rows = 1 << joined.size()
		peak = maxi(peak, rows)
		var maps: Array = []
		for i in inputs:
			var mapping = PackedInt32Array()
			mapping.resize(rows)
			for row in range(rows):
				var index = 0
				for bit in range(nodes[i].scope.size()):
					index |= ((row >> joined.find(nodes[i].scope[bit])) & 1) << bit
				mapping[row] = index
			maps.append(mapping)
		var output = nodes.size()
		nodes.append({"scope": best})
		steps.append({"inputs": inputs, "maps": maps, "output": output, "size": rows / 2})
		active = active.filter(func(i): return i not in inputs)
		active.append(output)
	# All disconnected components now have scalar partitions.
	return {"nodes": nodes, "steps": steps, "roots": active, "inputs": scopes.size(), "peak": peak}

static func _compile_cs(scopes: Array) -> Array:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var n_in: int = scopes.size()
	var offsets := PackedInt32Array()
	offsets.resize(n_in + 1)
	var vars := PackedInt32Array()
	offsets[0] = 0
	for i in range(n_in):
		var sc: Array = scopes[i]
		for v in sc:
			vars.append(int(v))
		offsets[i + 1] = vars.size()
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("ChannelSumProduct.compile", pack_u)
	var raw: PackedInt32Array = SolverBackend._bridge().SumProductCompile(n_in, offsets, vars)
	var p: int = 0
	var h: int = raw[p]; p += 1
	var inputs_cnt: int = raw[p]; p += 1
	var peak: int = raw[p]; p += 1
	var n_nodes: int = raw[p]; p += 1
	var nodes: Array = []
	nodes.resize(n_nodes)
	for i in range(n_nodes):
		var slen: int = raw[p]; p += 1
		var sc_arr: Array = []
		sc_arr.resize(slen)
		for j in range(slen):
			sc_arr[j] = int(raw[p]); p += 1
		nodes[i] = {"scope": sc_arr}
	var n_steps: int = raw[p]; p += 1
	var steps: Array = []
	steps.resize(n_steps)
	for s in range(n_steps):
		var out_node: int = raw[p]; p += 1
		var sz: int = raw[p]; p += 1
		var in_cnt: int = raw[p]; p += 1
		var ins: Array = []
		ins.resize(in_cnt)
		for k in range(in_cnt):
			ins[k] = int(raw[p]); p += 1
		var maps: Array = []
		maps.resize(in_cnt)
		var m_len: int = sz * 2
		for k in range(in_cnt):
			maps[k] = raw.slice(p, p + m_len)
			p += m_len
		steps[s] = {"inputs": ins, "maps": maps, "output": out_node, "size": sz}
	var n_roots: int = raw[p]; p += 1
	var roots: Array = []
	roots.resize(n_roots)
	for r in range(n_roots):
		roots[r] = int(raw[p]); p += 1
	return [{"nodes": nodes, "steps": steps, "roots": roots, "inputs": inputs_cnt, "peak": peak}, h]

static func evaluate(program: Dictionary, values: Array, marginals: bool = true) -> Dictionary:
	if not SolverBackend.profiling_enabled:
		return _evaluate_dispatch(program, values, marginals)
	var _st: int = SolverBackend.begin_stage("channel_sum_product")
	var _res: Dictionary = _evaluate_dispatch(program, values, marginals)
	SolverBackend.end_stage(_st)
	return _res

static func _evaluate_dispatch(program: Dictionary, values: Array, marginals: bool) -> Dictionary:
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _evaluate_gd(program, values, marginals)
	var cs_res: Dictionary = _evaluate_cs(program, values, marginals)
	if mode == SolverBackend.Mode.CSHARP:
		return cs_res
	var gd_res: Dictionary = _evaluate_gd(program, values, marginals)
	var b = SolverBackend._bridge()
	b.VerifyScalarFloat64("ChannelSumProduct.evaluate.total", gd_res.total, cs_res.total, 0.0)
	if marginals:
		for i in range(gd_res.adjoints.size()):
			b.VerifyFloat64Buffer("ChannelSumProduct.evaluate.adj", gd_res.adjoints[i], cs_res.adjoints[i], 0.0)
	return gd_res

static func _evaluate_gd(program: Dictionary, values: Array, marginals: bool = true) -> Dictionary:
	var data: Array = values.duplicate()
	for step in program.steps:
		var output = PackedFloat64Array()
		output.resize(step.size)
		for row in range(step.size * 2):
			var product = 1.0
			for k in range(step.inputs.size()):
				product *= data[step.inputs[k]][step.maps[k][row]]
			output[row % step.size] += product
		data.append(output)
	var total = 1.0
	for i in program.roots:
		total *= data[i][0]
	if not marginals:
		return {"total": total}
	var adjoints: Array = []
	for table in data:
		var gradient = PackedFloat64Array()
		gradient.resize(table.size())
		adjoints.append(gradient)
	for i in program.roots:
		var derivative = 1.0
		for j in program.roots:
			if j != i:
				derivative *= data[j][0]
		adjoints[i][0] = derivative
	for s in range(program.steps.size() - 1, -1, -1):
		var step: Dictionary = program.steps[s]
		for row in range(step.size * 2):
			var gradient: float = adjoints[step.output][row % step.size]
			if gradient == 0.0:
				continue
			var nonzero = gradient
			var zeros = 0
			for k in range(step.inputs.size()):
				var weight: float = data[step.inputs[k]][step.maps[k][row]]
				if weight == 0.0:
					zeros += 1
				else:
					nonzero *= weight
			for k in range(step.inputs.size()):
				var i: int = step.inputs[k]
				var index: int = step.maps[k][row]
				var weight: float = data[i][index]
				if zeros == 0:
					adjoints[i][index] += nonzero / weight
				elif zeros == 1 and weight == 0.0:
					adjoints[i][index] += nonzero
	return {"total": total, "adjoints": adjoints}

static func _evaluate_cs(program: Dictionary, values: Array, marginals: bool) -> Dictionary:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var p_h: int = _lookup_program_handle(program)
	var fb_prog: PackedInt32Array = pack_flat_program(program) if p_h < 0 else PackedInt32Array()
	var n_in: int = values.size()
	var v_offsets := PackedInt32Array()
	v_offsets.resize(n_in + 1)
	var flat_vals := PackedFloat64Array()
	v_offsets[0] = 0
	for i in range(n_in):
		var tbl = values[i]
		if tbl is PackedFloat64Array:
			flat_vals.append_array(tbl)
		else:
			for x in tbl:
				flat_vals.append(float(x))
		v_offsets[i + 1] = flat_vals.size()
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("ChannelSumProduct.evaluate", pack_u)
	var raw: PackedFloat64Array = SolverBackend._bridge().SumProductEvaluate(p_h, fb_prog, v_offsets, flat_vals, marginals)
	if not marginals:
		return {"total": raw[0]}
	var adjoints: Array = []
	var cursor: int = 1
	for i in range(n_in):
		var sz: int = v_offsets[i + 1] - v_offsets[i]
		adjoints.append(raw.slice(cursor, cursor + sz))
		cursor += sz
	for st in program.steps:
		var sz: int = int(st.size)
		adjoints.append(raw.slice(cursor, cursor + sz))
		cursor += sz
	return {"total": raw[0], "adjoints": adjoints}

## Compile the elimination once into an arithmetic circuit. Folding structural
## zero/one gates avoids interpreting dense Boolean tables for every world.
## null entries are numerical inputs; marker factors must remain inputs so their
## derivatives retain the accepted-content masses.
static func circuit(program: Dictionary, constants: Array) -> Dictionary:
	if not SolverBackend.profiling_enabled:
		return _circuit_dispatch(program, constants)
	var _st: int = SolverBackend.begin_stage("channel_sum_product")
	var _res: Dictionary = _circuit_dispatch(program, constants)
	SolverBackend.end_stage(_st)
	return _res

static func _circuit_dispatch(program: Dictionary, constants: Array) -> Dictionary:
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _circuit_gd(program, constants)
	var cs_pair: Array = _circuit_cs(program, constants)
	var cs_cir: Dictionary = cs_pair[0]
	var cs_h: int = int(cs_pair[1])
	if mode == SolverBackend.Mode.CSHARP:
		_store_circuit_handle(cs_cir, cs_h)
		return cs_cir
	var gd_cir: Dictionary = _circuit_gd(program, constants)
	var b = SolverBackend._bridge()
	b.VerifyInt32Buffer("ChannelSumProduct.circuit.flat", pack_flat_circuit(gd_cir), pack_flat_circuit(cs_cir))
	_store_circuit_handle(gd_cir, cs_h)
	return gd_cir

static func _circuit_gd(program: Dictionary, constants: Array) -> Dictionary:
	var build = {"ops": [[0, 0.0], [0, 1.0]], "memo": {}, "inputs": []}
	var data: Array = []
	for i in range(program.inputs):
		var table = PackedInt32Array()
		for row in range(1 << program.nodes[i].scope.size()):
			if constants[i] != null:
				var value: float = constants[i][row]
				assert(value == 0.0 or value == 1.0)
				table.append(1 if value == 1.0 else 0)
			else:
				table.append(build.ops.size())
				build.inputs.append([i, row, build.ops.size()])
				build.ops.append([1, i, row])
		data.append(table)
	for step in program.steps:
		var output = PackedInt32Array()
		output.resize(step.size)
		for row in range(step.size * 2):
			var product = 1
			for k in range(step.inputs.size()):
				product = _op(build, 2, product, data[step.inputs[k]][step.maps[k][row]])
			output[row % step.size] = _op(build, 3, output[row % step.size], product)
		data.append(output)
	var root = 1
	for i in program.roots:
		root = _op(build, 2, root, data[i][0])
	return {"ops": build.ops, "inputs": build.inputs, "root": root, "shapes": range(program.inputs).map(func(i): return 1 << program.nodes[i].scope.size())}

static func _circuit_cs(program: Dictionary, constants: Array) -> Array:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var p_h: int = _lookup_program_handle(program)
	var fb_prog: PackedInt32Array = pack_flat_program(program) if p_h < 0 else PackedInt32Array()
	var n_in: int = int(program.inputs)
	var c_flags := PackedByteArray()
	c_flags.resize(n_in)
	var c_offsets := PackedInt32Array()
	c_offsets.resize(n_in + 1)
	var flat_consts := PackedFloat64Array()
	c_offsets[0] = 0
	for i in range(n_in):
		var c_entry = constants[i]
		if c_entry != null:
			c_flags[i] = 1
			if c_entry is PackedFloat64Array:
				flat_consts.append_array(c_entry)
			else:
				for x in c_entry:
					flat_consts.append(float(x))
		else:
			c_flags[i] = 0
		c_offsets[i + 1] = flat_consts.size()
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("ChannelSumProduct.circuit", pack_u)
	var raw: PackedInt32Array = SolverBackend._bridge().SumProductCircuit(p_h, fb_prog, c_flags, c_offsets, flat_consts)
	var p: int = 0
	var c_h: int = raw[p]; p += 1
	var root: int = raw[p]; p += 1
	var ops_len: int = raw[p]; p += 1
	var ops: Array = []
	ops.resize(ops_len)
	for i in range(ops_len):
		var kind: int = raw[p]
		var a: int = raw[p + 1]
		var b_val: int = raw[p + 2]
		p += 3
		if kind == 0:
			ops[i] = [0, 1.0 if a != 0 else 0.0]
		else:
			ops[i] = [kind, a, b_val]
	var ins_len: int = raw[p]; p += 1
	var inputs: Array = []
	inputs.resize(ins_len)
	for i in range(ins_len):
		inputs[i] = [int(raw[p]), int(raw[p + 1]), int(raw[p + 2])]
		p += 3
	var sh_len: int = raw[p]; p += 1
	var shapes: Array = []
	shapes.resize(sh_len)
	for i in range(sh_len):
		shapes[i] = int(raw[p]); p += 1
	return [{"ops": ops, "inputs": inputs, "root": root, "shapes": shapes}, c_h]

static func _op(build: Dictionary, kind: int, a: int, b: int) -> int:
	if kind == 2:
		if a == 0 or b == 0:
			return 0
		if a == 1 or b == 1:
			return b if a == 1 else a
	else:
		if a == 0 or b == 0:
			return b if a == 0 else a
	var key = [kind, mini(a, b), maxi(a, b)]
	if not build.memo.has(key):
		build.memo[key] = build.ops.size()
		build.ops.append(key)
	return build.memo[key]

static func run(circuit_data: Dictionary, values: Array, marginals: bool = true) -> Dictionary:
	if not SolverBackend.profiling_enabled:
		return _run_dispatch(circuit_data, values, marginals)
	var _st: int = SolverBackend.begin_stage("channel_sum_product")
	var _res: Dictionary = _run_dispatch(circuit_data, values, marginals)
	SolverBackend.end_stage(_st)
	return _res

static func _run_dispatch(circuit_data: Dictionary, values: Array, marginals: bool) -> Dictionary:
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _run_gd(circuit_data, values, marginals)
	var cs_res: Dictionary = _run_cs(circuit_data, values, marginals)
	if mode == SolverBackend.Mode.CSHARP:
		return cs_res
	var gd_res: Dictionary = _run_gd(circuit_data, values, marginals)
	var b = SolverBackend._bridge()
	b.VerifyScalarFloat64("ChannelSumProduct.run.total", gd_res.total, cs_res.total, 0.0)
	if marginals:
		for i in range(gd_res.adjoints.size()):
			b.VerifyFloat64Buffer("ChannelSumProduct.run.adj", gd_res.adjoints[i], cs_res.adjoints[i], 0.0)
	return gd_res

static func _run_gd(circuit_data: Dictionary, values: Array, marginals: bool = true) -> Dictionary:
	var registers = PackedFloat64Array()
	registers.resize(circuit_data.ops.size())
	registers[1] = 1.0
	for i in range(2, circuit_data.ops.size()):
		var op: Array = circuit_data.ops[i]
		match op[0]:
			1: registers[i] = values[op[1]][op[2]]
			2: registers[i] = registers[op[1]] * registers[op[2]]
			3: registers[i] = registers[op[1]] + registers[op[2]]
	var result = {"total": registers[circuit_data.root]}
	if not marginals:
		return result
	var derivative = PackedFloat64Array()
	derivative.resize(registers.size())
	derivative[circuit_data.root] = 1.0
	for i in range(registers.size() - 1, 1, -1):
		var op: Array = circuit_data.ops[i]
		var d: float = derivative[i]
		if op[0] == 2:
			derivative[op[1]] += d * registers[op[2]]
			derivative[op[2]] += d * registers[op[1]]
		elif op[0] == 3:
			derivative[op[1]] += d
			derivative[op[2]] += d
	var adjoints: Array = []
	for shape in circuit_data.shapes:
		var table = PackedFloat64Array()
		table.resize(shape)
		adjoints.append(table)
	for input in circuit_data.inputs:
		adjoints[input[0]][input[1]] = derivative[input[2]]
	result.adjoints = adjoints
	return result

static func _run_cs(circuit_data: Dictionary, values: Array, marginals: bool) -> Dictionary:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var c_h: int = lookup_circuit_handle(circuit_data)
	var fb_cir: PackedInt32Array = pack_flat_circuit(circuit_data) if c_h < 0 else PackedInt32Array()
	var n_in: int = circuit_data.shapes.size()
	var v_offsets := PackedInt32Array()
	v_offsets.resize(n_in + 1)
	var flat_vals := PackedFloat64Array()
	v_offsets[0] = 0
	for i in range(n_in):
		var tbl = values[i]
		if tbl is PackedFloat64Array:
			flat_vals.append_array(tbl)
		else:
			for x in tbl:
				flat_vals.append(float(x))
		v_offsets[i + 1] = flat_vals.size()
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("ChannelSumProduct.run", pack_u)
	var raw: PackedFloat64Array = SolverBackend._bridge().SumProductRun(c_h, fb_cir, v_offsets, flat_vals, marginals)
	if not marginals:
		return {"total": raw[0]}
	var adjoints: Array = []
	var cursor: int = 1
	for sh in circuit_data.shapes:
		var sz: int = int(sh)
		adjoints.append(raw.slice(cursor, cursor + sz))
		cursor += sz
	return {"total": raw[0], "adjoints": adjoints}
