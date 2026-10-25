extends SceneTree
const Sum = preload("res://workshop/channel_sum_product.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var scopes = [[0], [1], [0, 1], [0], [1]]
	var values = [PackedFloat64Array([0.2, 0.8]), PackedFloat64Array([0.3, 0.7]), PackedFloat64Array([1, 1, 1, 0]), PackedFloat64Array([1, 1]), PackedFloat64Array([1, 1])]
	var program = Sum.compile(scopes)
	var result = Sum.evaluate(program, values)
	check(is_equal_approx(result.total, 0.44), "exclusive truthful claims sum over their legal honesty alternatives")
	check(is_equal_approx(result.adjoints[3][1], 0.24) and is_equal_approx(result.adjoints[4][1], 0.14), "reverse pass gives both accepted-content masses in one evaluation")
	var circuit = Sum.circuit(program, [null, null, values[2], null, null])
	var fast = Sum.run(circuit, values)
	check(is_equal_approx(fast.total, result.total) and range(2).all(func(i): return is_equal_approx(fast.adjoints[3][i], result.adjoints[3][i]) and is_equal_approx(fast.adjoints[4][i], result.adjoints[4][i])), "folded arithmetic circuit preserves partition and both query marginals")
	values[0] = PackedFloat64Array([0, 1])
	result = Sum.evaluate(program, values)
	check(is_equal_approx(result.total, 0.3) and is_equal_approx(result.adjoints[3][1], 0.3) and result.adjoints[4][1] == 0, "certain and impossible rows retain exact marginals")
	fast = Sum.run(circuit, values)
	check(is_equal_approx(fast.total, result.total) and fast.adjoints[3] == result.adjoints[3] and fast.adjoints[4] == result.adjoints[4], "circuit derivatives remain exact at zero inputs without dividing by probabilities")
	scopes = []
	values = []
	for i in range(30):
		scopes.append([i])
		values.append(PackedFloat64Array([0.2, 0.8]))
	program = Sum.compile(scopes)
	check(program.peak == 2 and program.steps.size() == 30 and is_equal_approx(Sum.evaluate(program, values).total, 1.0), "thirty independent sources integrate linearly without enumerating their joint states")
	print("Channel sum-product: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
