## Poisoner role definition and metadata.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "poisoner"
	display_name = "Poisoner"
	align = "evil"
	kind = "evil"
	minion = true
	night_walk = true
	desc = "Each night, poisons one person; their gift fails or lies until the next night."
	shape = "NONE"
