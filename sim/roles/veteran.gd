## Veteran role definition and simulation hooks.
##
## Shape: NIGHT_EVENT (the first time the demon attacks the Veteran, they survive and
## learn the last block the attacker came through).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "veteran"
	display_name = "Veteran"
	align = "good"
	kind = "passive"
	desc = "The first time the demon attacks the Veteran, they survive and learn the last block the attacker came through."
	shape = "NIGHT_EVENT"
	produces_readings = true
	can_cause_quiet_night = true
	quiet_night_effect = -0.06
	hard_to_kill = true


func gift_live_tonight(_w, _n) -> bool:
	return false # only worth it as part of an attack (see poison_for_kill)


func short_text(d: Dictionary, src: String, _nm: Callable) -> String:
	return "%s Veteran: attacked, from %s" % [src, content().block_name(d.get("block", ""))]


func info_effects(w, listener, source, entry: Dictionary, weight: float, _fresh: bool, mind) -> Array:
	var effs: Array = []
	var d: Dictionary = entry["data"]
	var own: bool = source == listener
	var tag: String = "own info" if own else "heard %s's info (w=%.2f)" % [source.id, weight]
	# The demon came by way of that block: a little toward those who live there.
	for m in w.living():
		if m != listener and m != source and m.home_block == d.get("block", ""):
			mind._eff(effs, m.id, 0.12, tag + ": the demon came by way of their block",
				"the demon came by way of %s, where they live" % content().block_name(d["block"]), not own)
	return effs


func survives_demon_attack(v) -> bool:
	return not v.is_evil() and not v.gift_broken() and not v.vet_used


func on_survive_attack(w, v) -> void:
	v.vet_used = true
	var path: Array = w.demon().night_path
	var from: String = path[path.size() - 2] if path.size() >= 2 else v.home_block
	w._add_info(v, {
		"data": {"attacked": w.day, "block": from},
		"true": true,
		"text": "the demon came for me on night %d and I lived; it came by way of %s" % [w.day, content().block_name(from)],
	})
