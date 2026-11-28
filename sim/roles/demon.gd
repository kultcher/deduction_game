## Demon role definition and metadata.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "demon"
	display_name = "Demon"
	align = "evil"
	kind = "evil"
	desc = "Kills one person each night (not the night before you arrived), walking to their block to do it."
	shape = "NONE"
