## Sexton role definition and simulation hooks.
##
## Shape: NIGHT_EVENT (once per case on Night 1 or later, may toll the church bell
## at the start of night: performs a Lamplighter walk through all blocks and completely
## suppresses all minion powers until the next night begins). Silent announcement,
## but claimable in dialogue.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "sexton"
	display_name = "Sexton"
	align = "good"
	kind = "protect"
	tags = ["protection", "night_walker"]
	night_walk = false # only walks on the night the bell is tolled
	desc = "Once per case (not night 0), at the start of night, may toll the church bell and walk through every parish: all minion abilities are suppressed until the next night."
	shape = "NIGHT_EVENT"
	evening_or_night = true
	min_gift_day = 1


func gift_live_tonight(_w, _n) -> bool:
	return false


func try_toll(w, sx, mind) -> bool:
	if sx == null or sx.is_evil() or sx.gift_used or w.day < 1:
		return false
	var few_left: float = Tuning.Roles.SEXTON.toll_few_left if w.living().size() <= 4 else 0.0
	var dead_cnt: float = Tuning.Roles.SEXTON.toll_per_dead * w.npcs.filter(func(m): return not m.alive).size()
	var has_exec_today: float = 0.35 if w.executed_today != "" else 0.0
	var toll: bool = mind.decide(w, sx, "sexton_toll", {
		"few_left": few_left,
		"deaths": dead_cnt,
		"executed_today": has_exec_today,
		"base": -0.2,
	}, "Toll the church bell tonight to suppress all minions?")
	if not toll:
		return false
	sx.gift_used = true
	w.sexton_tolled_night = w.day
	# The walk itself happens in World._night_movement (which resets the night's walkers),
	# on any toll night, whether or not a broken gift makes the bell work.
	if sx.gift_broken():
		w.dlog.add("sexton_toll", sx.id, "", {"works": false}, "%s tolls the church bell, but their gift is broken: minions are not suppressed." % sx.name)
		return false
	w.sexton_suppression_night = w.day
	w.dlog.add("sexton_toll", sx.id, "", {"works": true}, "%s tolls the church bell: all minion abilities are suppressed until next night." % sx.name)
	w._add_info(sx, {"data": {"night": w.day}, "true": true, "text": "I tolled the church bell on night %d" % w.day}, true)
	return true
