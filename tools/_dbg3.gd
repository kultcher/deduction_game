extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
func _init():
	for sd in [37291, 42, 54875, 900]:
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(sd, 7)
		var guard: int = 0
		while g.state != "over" and g.w.day < 4 and guard < 250:
			guard += 1
			match g.state:
				"approach": g.command("decline")
				"day": g.command("wait")
				"meeting": g.command("done" if g.town_quiet else "wait")
				"talk": g.command("bye")
				"nomination": g.command("vote no")
				"night": g.command("sleep")
				_: break
		print("SEED %d state %s day %d guard %d fallbacks %d" % [sd, g.state, g.w.day, guard, g.shared_fallbacks.size()])
		for f in g.shared_fallbacks.slice(0, 3):
			print("  FB ", f.get("listener"), " ", f.get("point"), " ", f.get("issues"))
		for p in g.w.living_good():
			if not p.workshop_state.get("active", false):
				print("  INACTIVE ", p.id, " ", p.workshop_state.get("issues"))
			var before: Dictionary = p.suspicion.duplicate(true)
			Mind.refresh_beliefs(g.w, p, " (idem)")
			for k in before:
				if absf(float(before[k]) - float(p.suspicion.get(k, -9))) > 0.000001:
					print("  NONIDEM ", p.id, " ", k, " ", before[k], " -> ", p.suspicion.get(k))
	quit(0)
