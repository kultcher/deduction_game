## Scion role definition and metadata.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "scion"
	display_name = "Scion"
	align = "evil"
	kind = "evil"
	minion = true
	desc = "If the demon is executed while five or more are alive, the Scion becomes the demon."
	shape = "NONE"
