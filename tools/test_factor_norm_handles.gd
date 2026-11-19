## A movement factor's compiled handle is shared only between uses on the same scale
## (LiveActivity._ensure_factor_handle, Lantern, Nov 19). A mixed list's or count's broken
## branch is scored on the sound branch's scale (the kernel's SetListNorm writes it into the
## broken branch's compiled factor). Before the fix the handle was keyed by content alone, so
## a broken branch identical to a factor used on its own rewrote that factor's scale, and
## whichever mix attached last decided how it scored: beliefs depended on judgement order,
## and the caches changed them (Quill's seed-900 cache parity, the Lamplighter fix (b)).
##   godot --headless --path . --script res://tools/test_factor_norm_handles.gd
extends SceneTree

const LiveActivity = preload("res://workshop/live_activity.gd")
const Caches = preload("res://workshop/caches.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1


func _initialize() -> void:
	call_deferred("_run")


func _profiles(goods: Array) -> Array:
	return goods.map(func(gv): return {"good": float(gv), "minion": 0.3, "demon": 0.2})


## A plain factor (`plain`), and a mixed one whose broken branch has the same content
## (a broken count that says nothing leaves the case's factor without it).
func _factors() -> Dictionary:
	var plain: Dictionary = {"profiles": _profiles([0.5, 0.4, 0.6])}
	var sound: Dictionary = {"profiles": _profiles([0.9, 0.2, 0.7])}
	var top: Dictionary = sound.duplicate(false)
	top["list_mix"] = {"watcher": 0, "broken": 0.5, "scale": 1.0, "cursed": false, "next": sound,
		"alt": plain.duplicate(true), "key": "test-mix"}
	return {"plain": plain, "top": top}


func _run() -> void:
	# Person 1 evil, person 0 (the mix's teller) good: the mix weighs both branches.
	var world: Dictionary = {"evil": 1 << 1, "demon": 1}
	Caches.clear_all()
	var f: Dictionary = _factors()
	var alone: float = LiveActivity.score(world, f.plain)
	var mixed: float = LiveActivity.score(world, f.top)
	var after: float = LiveActivity.score(world, f.plain)
	# A fresh copy of the plain factor, so no shortcut hands back the same object.
	var after_copy: float = LiveActivity.score(world, f.plain.duplicate(true))
	_check(is_equal_approx(alone, after) and is_equal_approx(alone, after_copy),
		"a factor scores the same before and after a mix whose broken branch shares its content (%.6f, %.6f, %.6f)" % [alone, after, after_copy])

	# Order: the mix judged first, then the plain factor, scores as the other order.
	LiveActivity._factor_handles.clear()
	LiveActivity._mru_factor = null
	var g: Dictionary = _factors()
	var mixed_first: float = LiveActivity.score(world, g.top)
	var alone_second: float = LiveActivity.score(world, g.plain)
	_check(is_equal_approx(mixed_first, mixed) and is_equal_approx(alone_second, alone),
		"the scores don't depend on which was judged first (mix %.6f vs %.6f, plain %.6f vs %.6f)" % [mixed_first, mixed, alone_second, alone])

	# The broken branch really is normed (the test would pass vacuously if it weren't): its
	# score inside the mix differs from the plain factor's own scale.
	_check(not is_equal_approx(mixed, LiveActivity.score(world, f.top.list_mix.next)),
		"the mix weighs its broken branch (it scores differently from its sound branch alone)")

	print("%d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
