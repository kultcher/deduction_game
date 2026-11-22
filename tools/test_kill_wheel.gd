## The night kill wheel (ui/fx/kill_wheel.gd) and the execution mark (ui/fx/execution_mark.gd),
## Limner Nov 22, from Michael's brief:
##   - the wheel stops with the victim's slice under the dagger, whatever the town's size;
##   - `landed`, `struck` and `finished` come once each, in order; skip_to_end() sends any
##     not yet sent, once;
##   - a kill leaves a red X on the victim, with no flash or shake left over; the fakeout
##     leaves no X and the dagger gone off screen;
##   - the isolated portrait moves without jumps;
##   - reduced motion shows no wheel, no spin and no shake, and is quicker;
##   - the execution mark greys the portrait, lands its X, and gives back the portrait's own
##     scale and rotation after its jolt.
## Headless: checks the timeline and the nodes, not pixels (tools/kill_wheel_capture.gd
## records the look).
##   godot --headless --path . --script res://tools/test_kill_wheel.gd
extends SceneTree

const KillWheel = preload("res://ui/fx/kill_wheel.gd")
const ExecutionMark = preload("res://ui/fx/execution_mark.gd")
const PortraitFx = preload("res://ui/portrait_fx.gd")

const TOWN = ["agnes", "bart", "constance", "dorian", "edda", "fenwick", "greta", "kiran", "lian", "odette"]

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


func _people(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({"id": TOWN[i], "name": TOWN[i].capitalize(), "color": Color(0.5 + 0.05 * i, 0.4, 0.6)})
	return out


## Plays to the end in 1/30 s ticks; returns when each signal fired.
func _run_step(w, step: Dictionary) -> Dictionary:
	var got = {"landed": [], "struck": [], "finished": []}
	var on_l = func(): got.landed.append(w.t)
	var on_s = func(): got.struck.append(w.t)
	var on_f = func(): got.finished.append(w.t)
	w.landed.connect(on_l)
	w.struck.connect(on_s)
	w.finished.connect(on_f)
	w.play(step)
	var guard = 0
	while w.playing and guard < 600:
		w.advance(1.0 / 30.0)
		guard += 1
	w.landed.disconnect(on_l)
	w.struck.disconnect(on_s)
	w.finished.disconnect(on_f)
	return got


static func _wrap(a: float) -> float:
	return fposmod(a + PI, TAU) - PI


func _run() -> void:
	var w = KillWheel.new()
	w.size = Vector2(900, 900)
	root.add_child(w)
	await process_frame
	w.set_process(false)

	# A kill.
	var got = _run_step(w, {"people": _people(10), "victim": "greta", "kill": true})
	_check(got.landed.size() == 1 and got.struck.size() == 1 and got.finished.size() == 1, "landed, struck and finished each fire once")
	_check(got.landed[0] < got.struck[0] and got.struck[0] <= got.finished[0], "in order: landed, struck, finished")
	_check(w.ends_at() >= 4.0 and w.ends_at() <= 5.5, "a kill takes about 5 s (%.2f s)" % w.ends_at())
	_check(w.landed_at() >= 2.0, "the spin comes first: it lands at %.2f s" % w.landed_at())
	_check(w.mark.visible and w.mark.p1 >= 1.0 and w.mark.p2 >= 1.0, "a kill leaves the red X drawn in full")
	_check(is_zero_approx(w.flash.color.a) and w.stage.position == Vector2.ZERO, "no flash or shake left over")
	_check(w.frame.modulate.a < 0.01, "the wheel has gone")
	var others_gone = true
	for i in range(w.slices.size()):
		if i != w.victim_index and w.slices[i].modulate.a > 0.01:
			others_gone = false
	_check(others_gone, "only the victim's slice is left")
	_check(w.slices[w.victim_index].name == "Slice_greta", "the slice left is the victim's")
	_check(w.slices.all(func(s): return s.face.rotation == 0.0), "the portraits turn with the wheel, not counter to it (Michael)")
	_check(is_zero_approx(w.slices[w.victim_index].rotation), "and the victim's ends upright")
	_check(w.focus_centre().distance_to(w.size / 2.0) < 2.0, "the victim ends in the middle")

	# The wheel stops with the victim under the dagger, for any town size and victim.
	var worst = 0.0
	for n in [3, 7, 10]:
		for vi in range(n):
			w.play({"people": _people(n), "victim": TOWN[vi], "kill": true})
			var a = _wrap(w.wheel_rotation(w.landed_at()) + vi * TAU / n)
			worst = maxf(worst, absf(a))
	_check(worst < 0.001, "the victim's slice stops under the dagger (worst %.4f rad, 3, 7 and 10 people)" % worst)
	w.play({"people": _people(10), "victim": "edda", "kill": true})
	_check(absf(w.wheel_rotation(0.3) - w.wheel_rotation(w.landed_at())) > TAU * 2.0, "it turns more than twice before stopping")
	# A second kill picks up where the first stopped (Herald's ask).
	var first_end: float = w.end_angle()
	w.play({"people": _people(9), "victim": "bart", "kill": true, "start_angle": first_end})
	_check(absf(_wrap(w.wheel_rotation(0.0) - first_end)) < 0.001, "a second spin starts where the first stopped")
	_check(absf(_wrap(w.wheel_rotation(w.landed_at()) + 1 * TAU / 9)) < 0.001 and absf(w.wheel_rotation(0.3) - w.wheel_rotation(w.landed_at())) > TAU * 2.0,
		"and still turns more than twice and lands on its victim")

	# The isolated portrait moves without jumps.
	w.play({"people": _people(10), "victim": "kiran", "kill": false})
	var prev = null
	var jump = 0.0
	var at = 0.0
	w.t = w.landed_at()
	while w.t < w.ends_at():
		w._apply()
		var c = w.focus_centre()
		if prev != null and c.distance_to(prev) > jump:
			jump = c.distance_to(prev)
			at = w.t
		prev = c
		w.t += 0.01
	_check(jump < 20.0, "after landing, the victim's portrait never jumps (biggest step %.1f px at %.2f s)" % [jump, at])

	# The fakeout.
	got = _run_step(w, {"people": _people(10), "victim": "kiran", "kill": false})
	_check(got.landed.size() == 1 and got.struck.size() == 1 and got.finished.size() == 1, "no kill: each signal fires once")
	_check(not w.mark.visible, "no kill leaves no X")
	_check(is_zero_approx(w.flash.color.a), "no kill doesn't flash")
	_check(w.dagger.position.y > w.size.y, "the dagger has tumbled off screen")
	_check(w.focus_centre().distance_to(w.size / 2.0) < 2.0, "the harmless pick is left in the middle")

	# Skipping.
	var counts = {"landed": 0, "struck": 0, "finished": 0}
	var on_l = func(): counts.landed += 1
	var on_s = func(): counts.struck += 1
	var on_f = func(): counts.finished += 1
	w.landed.connect(on_l)
	w.struck.connect(on_s)
	w.finished.connect(on_f)
	w.play({"people": _people(10), "victim": "lian", "kill": true})
	w.advance(1.0)
	w.skip_to_end()
	w.skip_to_end()
	w.advance(1.0)
	_check(counts.landed == 1 and counts.struck == 1 and counts.finished == 1, "skip_to_end sends each signal once")
	_check(not w.playing and w.mark.visible, "after a skip it has stopped, X drawn")
	w.landed.disconnect(on_l)
	w.struck.disconnect(on_s)
	w.finished.disconnect(on_f)

	# A `finished` handler that starts the next kill: the next one plays (Codex).
	var chained = {"started": false}
	var chain = func():
		if not chained.started:
			chained.started = true
			w.play({"people": _people(9), "victim": "bart", "kill": true, "start_angle": w.end_angle()})
	w.finished.connect(chain)
	w.play({"people": _people(10), "victim": "lian", "kill": true})
	w.skip_to_end()
	w.finished.disconnect(chain)
	_check(chained.started and w.playing and w.t == 0.0, "a finished handler that starts the next kill leaves it playing")
	w.advance(0.5)
	_check(w.t > 0.4, "and it runs")
	w.skip_to_end()

	# Reduced motion.
	w.reduced_motion = true
	w.play({"people": _people(10), "victim": "greta", "kill": true})
	var calm = true
	var wheel_seen = false
	while w.playing:
		w.advance(1.0 / 30.0)
		if w.stage.position != Vector2.ZERO:
			calm = false
		if w.frame.modulate.a > 0.0:
			wheel_seen = true
	_check(calm, "reduced motion: no shake")
	_check(not wheel_seen, "reduced motion: no wheel")
	_check(w.ends_at() < 2.5, "reduced motion is quicker (%.2f s)" % w.ends_at())
	_check(w.mark.visible and w.mark.modulate.a > 0.99, "reduced motion: the X is shown")
	got = _run_step(w, {"people": _people(10), "victim": "kiran", "kill": false})
	_check(got.finished.size() == 1 and not w.mark.visible and not w.dagger.visible, "reduced motion, no kill: no X, and the dagger fades away")
	w.reduced_motion = false

	# Resizing re-lays it out.
	w.play({"people": _people(10), "victim": "greta", "kill": true})
	w.skip_to_end()
	w.size = Vector2(500, 500)
	await process_frame
	_check(w.focus_centre().distance_to(w.size / 2.0) < 2.0, "it lays out again when resized")
	w.queue_free()

	# The execution mark.
	var face = TextureRect.new()
	face.size = Vector2(200, 200)
	face.scale = Vector2.ONE * 1.07   # a hover lift, say
	root.add_child(face)
	await process_frame
	var m = ExecutionMark.play(face)
	m.set_process(false)
	var fired = {"landed": 0, "finished": 0}
	m.landed.connect(func(): fired.landed += 1)
	m.finished.connect(func(): fired.finished += 1)
	var jolted = false
	while m.playing:
		m.advance(1.0 / 30.0)
		if face.rotation != 0.0:
			jolted = true
	_check(fired.landed == 1 and fired.finished == 1, "the execution mark: landed and finished once each")
	_check(m.ends_at() <= 1.2, "the execution mark is quick (%.2f s)" % m.ends_at())
	_check(jolted, "the portrait jolts as the X lands")
	_check(is_zero_approx(face.rotation) and face.scale.is_equal_approx(Vector2.ONE * 1.07), "and gets its own scale and rotation back")
	_check(m.cross.visible and m.cross.scale.is_equal_approx(Vector2.ONE), "the blue X has landed at its size")
	_check(is_equal_approx(float(face.material.get_shader_parameter("grey")), 1.0), "the portrait is grey")
	# Replacing a mark mid-jolt leaves the portrait its own scale and turn (Codex).
	var mj = ExecutionMark.play(face)
	mj.set_process(false)
	mj.advance(0.55)
	var jolting_now = face.rotation != 0.0 or not face.scale.is_equal_approx(Vector2.ONE * 1.07)
	var m_after = ExecutionMark.play(face)
	m_after.set_process(false)
	m_after.skip_to_end()
	_check(jolting_now and is_zero_approx(face.rotation) and face.scale.is_equal_approx(Vector2.ONE * 1.07), "replacing a mark mid-jolt gives the portrait its own scale and turn back")
	var m2 = ExecutionMark.play(face)
	_check(face.get_children().filter(func(c): return c.name == "ExecutionMark" and not c.is_queued_for_deletion()).size() == 1, "marking again replaces the mark")
	m2.skip_to_end()
	face.queue_free()

	var face2 = TextureRect.new()
	face2.size = Vector2(200, 200)
	root.add_child(face2)
	await process_frame
	var m3 = ExecutionMark.play(face2, true)
	m3.set_process(false)
	var still = true
	while m3.playing:
		m3.advance(1.0 / 30.0)
		if face2.rotation != 0.0 or face2.scale != Vector2.ONE:
			still = false
	_check(still and m3.cross.visible and m3.cross.modulate.a > 0.99, "reduced motion: the X fades in, no jolt")
	face2.queue_free()

	await process_frame
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
