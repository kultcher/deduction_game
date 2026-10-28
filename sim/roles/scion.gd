## Scion role definition and simulation hooks.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "scion"
	display_name = "Scion"
	align = "evil"
	kind = "evil"
	minion = true
	desc = "If the demon is executed while five or more are alive, the Scion becomes the demon."
	shape = "NONE"


func can_promote_to_demon(sc, alive_before: int) -> bool:
	return sc != null and alive_before >= 5 and not sc.gift_broken()


func promote_to_demon(w, sc) -> void:
	var old: String = w.demon_id
	sc.role = "demon"
	w.demon_id = sc.id
	w.scion_rose = sc.id
	w.minion_ids.erase(sc.id)
	if w.minion_id == sc.id and not w.minion_ids.is_empty():
		w.minion_id = w.minion_ids[0]
	w.dlog.add("scion", sc.id, old, {}, "The demon is hanged, but %s, the Scion, becomes the demon." % sc.name)
	w._check_parity()
