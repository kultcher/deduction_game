## Brute role definition and simulation hooks.
##
## A violent minion who hunts in place of the Demon while alive. The Demon stays
## home and leaves no traces while the Brute hunts. The Brute drops two physical traces
## per hunt. Identifies strictly as a Minion (not a Demon). When executed or suppressed
## by the Sexton, the Demon hunts as normal.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "brute"
	display_name = "Brute"
	align = "evil"
	kind = "evil"
	tags = ["minion", "night_walker"]
	minion = true
	night_walk = true
	desc = "While you are alive, you hunt and kill in place of the demon (dropping two traces); the demon stays home. You register as a minion, not the demon."
	shape = "NONE"


func is_active_hunter(w, brute) -> bool:
	return brute != null and brute.alive and not brute.gift_broken() and not w.is_minion_suppressed()
