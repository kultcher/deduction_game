## Opt-in synchronous spans. Exclusive time avoids double-counting nested stages.
## No world/NPC references, RNG calls, timing thresholds or inference decisions.
extends RefCounted
static var enabled = false
static var stack: Array = []
static var rows: Dictionary = {}
static var counters: Dictionary = {}
static var started = 0

static func start() -> void:
	stack = []
	rows = {}
	counters = {}
	started = Time.get_ticks_usec()
	enabled = true

static func open(stage: String, listener: String = "") -> int:
	if not enabled:
		return -1
	if listener == "" and not stack.is_empty():
		listener = stack[-1].listener
	var path: String = stage if stack.is_empty() else stack[-1].path + "/" + stage
	stack.append({"stage": stage, "path": path, "listener": listener, "at": Time.get_ticks_usec(), "children": 0})
	return stack.size() - 1

static func close(token: int) -> void:
	if token < 0:
		return
	assert(token == stack.size() - 1, "Unbalanced profiling spans")
	var span: Dictionary = stack.pop_back()
	var elapsed: int = Time.get_ticks_usec() - span.at
	if not stack.is_empty():
		stack[-1].children += elapsed
	var key: String = span.listener + "|" + span.path
	if not rows.has(key):
		rows[key] = {"listener": span.listener, "stage": span.stage, "path": span.path, "calls": 0, "total_us": 0, "self_us": 0}
	rows[key].calls += 1
	rows[key].total_us += elapsed
	rows[key].self_us += elapsed - span.children

static func count(label: String, amount: int = 1) -> void:
	if not enabled:
		return
	var listener: String = stack[-1].listener if not stack.is_empty() else ""
	var path: String = stack[-1].path if not stack.is_empty() else ""
	var key = listener + "|" + path + "|" + label
	counters[key] = counters.get(key, 0) + amount

static func finish() -> Dictionary:
	assert(stack.is_empty(), "Profiling ended inside a span")
	enabled = false
	return {"format": "workshop-profile-1", "elapsed_us": Time.get_ticks_usec() - started,
		"rows": rows.values().duplicate(true), "counters": counters.duplicate(true)}
