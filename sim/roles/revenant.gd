## Revenant role definition and metadata.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "revenant"
	display_name = "Revenant"
	align = "evil"
	kind = "evil"
	minion = true
	day = true
	desc = "Hides a totem somewhere each day it has none in play. If hanged while a totem is hidden, a good soul who voted for it turns evil until the totem is found."
	shape = "NONE"
