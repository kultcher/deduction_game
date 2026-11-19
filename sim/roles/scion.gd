## Scion role definition and simulation hooks.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "scion"
	display_name = "Scion"
	align = "evil"
	kind = "evil"
	tags = ["execution"]
	minion = true
	desc = "If the Demon is executed while five or more are alive, the Scion becomes the Demon."
	shape = "NONE"


func can_promote_to_demon(sc, alive_before: int, w = null) -> bool:
	if w != null and w.is_minion_suppressed():
		return false
	return sc != null and alive_before >= 5 and not sc.gift_broken()


func promote_to_demon(w, sc) -> void:
	var old: String = w.demon_id
	# The Scion takes over the dead demon's type (a Hexer's heir hexes too).
	sc.role = w.by_id[old].role if w.by_id.has(old) and content().is_demon(w.by_id[old].role) else "demon"
	w.demon_id = sc.id
	w.scion_rose = sc.id
	w.minion_ids.erase(sc.id)
	if w.minion_id == sc.id and not w.minion_ids.is_empty():
		w.minion_id = w.minion_ids[0]
	w.dlog.add("scion", sc.id, old, {}, "The Demon is hanged, but %s, the Scion, becomes the Demon." % sc.name)
	w._check_parity()
