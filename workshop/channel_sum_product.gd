## Exact binary sum-product. Eliminate one variable at a time, multiplying only
## factors that mention it. Independent sources never form a Cartesian product.
## A reverse pass gives every input-factor marginal, including zero-weight rows.
extends RefCounted

static func factor(scope: Array, values: Array) -> Dictionary:
	return {"scope": scope, "values": PackedFloat64Array(values)}

static func compile(scopes: Array) -> Dictionary:
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

static func evaluate(program: Dictionary, values: Array, marginals: bool = true) -> Dictionary:
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

## Compile the elimination once into an arithmetic circuit. Folding structural
## zero/one gates avoids interpreting dense Boolean tables for every world.
## null entries are numerical inputs; marker factors must remain inputs so their
## derivatives retain the accepted-content masses.
static func circuit(program: Dictionary, constants: Array) -> Dictionary:
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
