## Breathstealer role definition and metadata.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "breathstealer"
	display_name = "Breathstealer"
	align = "evil"
	kind = "evil"
	minion = true
	day = true
	desc = "Once a day, silences someone on the same block, from that evening's meeting until the next evening. Silenced people can still vote."
	shape = "NONE"
