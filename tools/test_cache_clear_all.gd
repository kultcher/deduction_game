## WorkshopCaches.clear_all() drops every static memo the shared model keeps, so one case's
## results can't leak into the next in the same session (audit Nov 27, Part 4 item 5). Two
## cases in one process reuse a card id for different readings: case B must answer as it does
## fresh, and each listed cache must be empty after clear_all.
##   godot --headless --path . --script res://tools/test_cache_clear_all.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Caches = preload("res://workshop/caches.gd")
const RoleConstraints = preload("res://workshop/role_constraints.gd")
const SharedLedger = preload("res://workshop/shared_ledger.gd")

var checks: int = 0
var fails: int = 0
var people: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _view(cards: Array) -> Dictionary:
	return {"people": people, "evil_count": 2, "alignment_epoch": "Original alignment", "cards": cards,
		"world_options": {"modifiers": ["delusional", "marked", "ill_omened", "unrequited"], "roles": true, "identities": true, "bluffs": true}}

## A Seer reading under one id; only its content differs between the two cases.
func _seer(pair: Array, yes: bool) -> Dictionary:
	return {"id": "r1", "kind": "report", "role": "seer", "source": people[0].id, "observed_at": {"day": 1, "phase": "night"},
		"reported_at": {"day": 2, "phase": "morning"}, "night": 1, "data": {"pair": pair, "yes": yes}, "text": "seer"}

func _init() -> void:
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var who: int = 1
	# Case A: a Seer "yes" naming person 1, which points at them being evil.
	var a: Dictionary = _seer([people[1].id, people[2].id], true)
	# Case B: the same id, now a "no" on person 1, which doesn't.
	var b: Dictionary = _seer([people[1].id, people[2].id], false)
	Caches.clear_all()
	var b_fresh: bool = RoleConstraints.names_evil(_view([b]), b, who)
	Caches.clear_all()
	var a_ans: bool = RoleConstraints.names_evil(_view([a]), a, who)
	check(a_ans and not b_fresh, "the two readings differ: a yes names them evil (%s), a no doesn't (%s)" % [a_ans, b_fresh])
	# A new case clears the caches, as Game.new_case does.
	Caches.clear_all()
	var b_after: bool = RoleConstraints.names_evil(_view([b]), b, who)
	check(b_after == b_fresh, "after case A, case B's reading under the same id answers as it does fresh (%s, fresh %s)" % [b_after, b_fresh])
	# Even without a clear, the memo keys on the card's content, so the reused id doesn't collide.
	RoleConstraints.names_evil(_view([a]), a, who)
	check(RoleConstraints.names_evil(_view([b]), b, who) == b_fresh, "the names-evil memo keys on the card's content, not its id alone")
	# Fill the listed caches, then clear.
	var cs = Solver.empty_case()
	cs.cards = ["r1"]
	cs.conclusion = {"type": "evil", "target": people[1].id, "at": "Original alignment"}
	var v: Dictionary = _view([a])
	v["own_burden"] = {"self": people[3].id, "kind": ""}
	CaseEval.evaluate(v, cs, {"id": people[3].id, "knowledge": {"self": people[3].id, "good": [people[3].id]}})
	RoleConstraints._deal_share(v, 1, "marked")
	SharedLedger.last_reason_ctx = {"x": 1}
	SharedLedger.last_adjusted = {"x": 1}
	Caches.clear_all()
	check(RoleConstraints._names_evil_cache.is_empty(), "clear_all empties RoleConstraints._names_evil_cache")
	check(RoleConstraints._burden_share_cache.is_empty(), "clear_all empties RoleConstraints._burden_share_cache")
	check(CaseEval._own_delusion_weight_cache.is_empty(), "clear_all empties CaseEval._own_delusion_weight_cache")
	check(SharedLedger.last_reason_ctx.is_empty() and SharedLedger.last_adjusted.is_empty(), "clear_all empties SharedLedger.last_reason_ctx and last_adjusted")
	print("Cache clear_all: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
