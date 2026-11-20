## The Demon's kill score for a publicly claimed gift, role by role (Michael, Nov 20):
## info gifts 3.0, the Lamplighter and Psychologist 2.0, a claimed Warden 3.0, a Sexton
## 2.0 while its bell is unrung; one shared +1.0 for the identifiers (Seer, Augur, Dowser,
## Confessor); the Registrar's own +0.75; spent one-shots (the Chronicler after night 3,
## the Executor once its person is dead) and first-night gifts after the first night score 0.
extends SceneTree
const Game = preload("res://game/game.gd")
const Evil = preload("res://sim/evil.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_table()
	_sexton_after_bell()
	_chronicler_spent()
	_executor_spent()
	_unclaimed()
	print("Kill score by role: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(day: int = 2):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	g.w.day = day
	return g

## The claim's worth: the claim itself, the identifier bonus and any per-role extra.
func _claim_score(w, n) -> float:
	var parts: Dictionary = Evil._public_threat(w, n)
	var total: float = 0.0
	for k in ["info_claim", "gift_claim", "identifier", "registrar"]:
		total += float(parts.get(k, 0.0))
	return total

func _claimant(g, role: String):
	var n = g.w.living_good()[0]
	n.claimed_role = role
	n.claim_public = true
	n.info_log = []
	return n

func _table() -> void:
	var expect: Dictionary = {"seer": 4.0, "augur": 4.0, "dowser": 4.0, "confessor": 4.0, "registrar": 3.75,
		"nightwatch": 3.0, "monitor": 3.0, "medium": 3.0, "magistrate": 3.0, "gravedigger": 3.0,
		"lamplighter": 2.0, "psychologist": 2.0, "warden": 3.0, "sexton": 2.0, "martyr": 0.0, "veteran": 0.0}
	var wrong: Array = []
	for role in expect:
		var g = _game()
		var n = _claimant(g, role)
		var got: float = _claim_score(g.w, n)
		if not is_equal_approx(got, expect[role]):
			wrong.append("%s %.2f (want %.2f)" % [role, got, expect[role]])
	_check(wrong.is_empty(), "each claimed gift scores Michael's value %s" % (", ".join(PackedStringArray(wrong)) if not wrong.is_empty() else ""))

func _sexton_after_bell() -> void:
	var g = _game()
	var n = _claimant(g, "sexton")
	g.w.evil_plan["bell_believed"] = 1
	_check(is_zero_approx(_claim_score(g.w, n)), "a Sexton whose bell evil has heard of scores nothing")

func _chronicler_spent() -> void:
	var g = _game(3)
	var n = _claimant(g, "chronicler")
	_check(is_equal_approx(_claim_score(g.w, n), 3.0), "the Chronicler scores 3.0 up to night 3")
	g.w.day = 4
	_check(is_zero_approx(_claim_score(g.w, n)), "the Chronicler scores nothing after night 3")

func _executor_spent() -> void:
	var g = _game()
	var n = _claimant(g, "executor")
	var t = g.w.living_good()[1]
	n.executor_target = t.id
	n.executor_resolved = false
	_check(is_equal_approx(_claim_score(g.w, n), 3.0), "the Executor scores 3.0 while its person lives")
	t.alive = false
	_check(is_zero_approx(_claim_score(g.w, n)), "the Executor scores nothing once its person is dead")

func _unclaimed() -> void:
	var g = _game()
	var n = _claimant(g, "seer")
	n.claim_public = false
	_check(is_zero_approx(_claim_score(g.w, n)), "an unclaimed gift scores nothing for its claim")
