## Case 12926 (a Hexer playtest): the Muddler is a fair gossip, and a reading about someone
## else is named when it's the reason for an accusation.
##   godot --headless --path . --script res://tools/test_playtest_12926.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Tuning = preload("res://sim/tuning.gd")
const RA = preload("res://workshop/reason_attribution.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var low_ok: bool = true
	var dealt: int = 0
	for seed in range(7000, 7012):
		var sc = ScriptDef.default_script()
		sc.secrets = ["delusional", "marked", "lovers", "muddler"]
		sc.forced = sc.forced + ["muddler"]
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(seed, 7, sc)
		for n in g.w.npcs:
			if n.secret_mod == "muddler":
				dealt += 1
				low_ok = low_ok and float(n.traits.gossip) >= Tuning.Setup.MUDDLER_GOSSIP_FLOOR
	_check(dealt == 12, "the forced Muddler is dealt every case (%d)" % dealt)
	_check(low_ok, "every Muddler is at least a fair gossip")

	var view: Dictionary = {"people": [{"id": "hollis", "name": "Hollis"}, {"id": "fenwick", "name": "Fenwick"}, {"id": "nisha", "name": "Nisha"}]}
	var reading: Dictionary = {"id": "r1", "kind": "report", "source": "hollis", "role": "confessor", "data": {"good": true, "target": "fenwick"}}
	_check(RA._reading_gist(view, reading, "nisha", "hollis") == "cleared Fenwick", "a Confessor reading that cleared someone else says so")
	reading.data.good = false
	_check(RA._reading_gist(view, reading, "nisha", "hollis") == "named Fenwick as evil", "and one that condemned them")
	reading.data.target = "nisha"
	_check(RA._reading_gist(view, reading, "nisha", "hollis") == "", "a reading about the accused keeps the plain wording")
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
