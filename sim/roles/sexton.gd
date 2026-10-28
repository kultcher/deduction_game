## Sexton role definition and simulation hooks.
##
## Shape: NIGHT_EVENT (once per case, with fewer than five alive, may toll the death
## knell in the evening so no gift that needs walking abroad works that night).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "sexton"
	display_name = "Sexton"
	align = "good"
	kind = "protect"
	desc = "Once per case, with fewer than five alive, may toll the death knell in the evening: that night, no gift that needs walking abroad works."
	shape = "NIGHT_EVENT"
	evening_or_night = true
	min_gift_day = 1


func gift_live_tonight(_w, _n) -> bool:
	return false # the knell is tolled in the evening, after tonight's poison has worn off


func try_knell(w, sx, mind) -> bool:
	if sx == null or sx.is_evil() or sx.gift_used or w.day < 1 or w.living().size() >= 5:
		return false
	var toll: bool = mind.decide(w, sx, "sexton_toll", {
		"few_left": 0.35,
		"deaths": 0.1 * w.npcs.filter(func(m): return not m.alive).size(),
		"base": 0.0,
	}, "Toll the death knell tonight (fewer than five alive)?")
	if not toll:
		return false
	sx.gift_used = true
	w.knell_night = w.day
	w.public_event("knell", [sx.id], sx.id)
	if sx.gift_broken():
		w.dlog.add("knell", sx.id, "", {"works": false}, "%s tolls the death knell, but their gift is broken: nothing stops tonight." % sx.name)
		w.knell_night = -1
		return false
	w.dlog.add("knell", sx.id, "", {"works": true}, "%s tolls the death knell: no gift that walks abroad works tonight." % sx.name)
	w._add_info(sx, {"data": {"night": w.day}, "true": true, "text": "I tolled the death knell on night %d" % w.day}, true)
	return true
