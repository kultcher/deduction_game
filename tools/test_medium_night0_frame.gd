## An evil Medium's relay about the first victim never frames on night 0 (BACKLOG [decided],
## Lantern Nov 13). The Demon never walks night 0, so "the dead saw the scapegoat out" then
## would lower suspicion of the scapegoat; the frame is told on the night they died instead.
## A later victim's frame keeps "their last night".
extends SceneTree
const Game = preload("res://game/game.gd")
const Evil = preload("res://sim/evil.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)
		print("FAIL: " + label)

func _init() -> void:
	_frames(1, 1)   # first victim, killed the first night: frame on night 1, not 0
	_frames(3, 2)   # a later victim: their last night, as before
	print("Medium night-0 frame: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## Victim killed on night `death_day`; every frame of the scapegoat must name `want_night`.
func _frames(death_day: int, want_night: int) -> void:
	var frames: int = 0
	for sd in range(1, 61):
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(4242, 10)
		var w = g.w
		var n = w.minion()
		var s: String = w.evil_plan["scapegoat"]
		var dd = w.living_good().filter(func(x): return x.id != s and x.home_block != w.by_id[s].home_block)[0]
		dd.alive = false
		dd.death_cause = "demon"
		dd.death_day = death_day
		dd.claim_public = false
		w.day = death_day + 1
		w.evil_plan["medium_frames"] = 0
		w.rng.seed = sd
		var r: Dictionary = Evil._fake_medium_item(w, n, dd, s)
		var it: Dictionary = r.get("item", {})
		if str(it.get("type", "")) == "sighting" and str(it.get("who", "")) == s:
			frames += 1
			_check(int(it.get("night", -1)) == want_night, "victim of night %d: the scapegoat frame names night %d (got %d)" % [death_day, want_night, int(it.get("night", -1))])
	print("  victim of night %d: %d frames of the scapegoat in 60 draws" % [death_day, frames])
	_check(frames > 0, "victim of night %d: the frame comes up at all" % death_day)
