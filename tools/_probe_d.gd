extends SceneTree
const Game = preload("res://game/game.gd")
func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(900, 7)
	var guard = 0
	var t0 = Time.get_ticks_msec()
	while g.state != "over" and g.w.day < 4 and guard < 300:
		guard += 1
		var st = g.state; var d = g.w.day
		var t1 = Time.get_ticks_msec()
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
		var dt = Time.get_ticks_msec() - t1
		if dt > 3000: print("SLOW day ", d, " ", st, " ", dt, " ms")
	print("DONE ", Time.get_ticks_msec() - t0, " ms day ", g.w.day, " state ", g.state)
	quit()
