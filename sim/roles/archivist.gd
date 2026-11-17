## Archivist role definition and simulation hooks.
##
## Shape: ROLE_IN_GROUP ({pair, role}) — starts knowing that one of two people is a
## particular minion.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "archivist"
	display_name = "Archivist"
	align = "good"
	kind = "info"
	tags = ["first_night_info", "evil_id"]
	first_night = true
	desc = "Starts knowing that one of two people is a particular minion."
	shape = "ROLE_IN_GROUP"
	role_group_key = "pair"
	role_target_pool = "minion"


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	return "%s Archivist: %s in %s" % [src, content().role_name(d.get("role", "poisoner")), _names(d.get("pair", []), nm)]


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	var broken: bool = n.gift_broken()
	var mid: String = w.pick(w.minion_ids)
	var mrole: String = w.by_id[mid].role
	var other = w.pick(w.npcs.filter(func(m): return m != n and m.id != mid))
	var pair: Array = w.shuffled([mid, other.id])
	var ok = true
	var C = content()
	if broken:
		var goods: Array = w.npcs.filter(func(m): return m != n and not m.is_evil())
		pair = w.shuffled(goods).slice(0, 2).map(func(m): return m.id)
		mrole = w.pick(w.case_script.minions)
		ok = false
	return {
		"data": {"pair": pair, "role": mrole},
		"true": ok,
		"text": "I learned that one of %s is the %s" % [w._names(pair), C.role_name(mrole)],
	}


func generate_bluff_reading(w, _n, _plan: Dictionary, s: String, _mate, _asked: Array) -> Dictionary:
	if w.day != 0:
		return {}
	var C = content()
	var other = w.pick(w.living_good().filter(func(x): return x.id != s))
	var pair: Array = w.shuffled([s, other.id])
	var mr: String = w.by_id[w.pick(w.minion_ids)].role
	var why = "names scapegoat %s as a possible %s" % [s, mr]
	var entry: Dictionary = {
		"data": {"pair": pair, "role": mr},
		"text": "I learned that one of %s is the %s" % [w._names(pair), C.role_name(mr)],
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(w, _n, dd, s: String, _sg, _d, _goods: Array, other: Callable, e: Dictionary, _demon_implicated: bool) -> Dictionary:
	var o4 = other.call([s])
	if o4 == null:
		return {}
	var C = content()
	var pair2: Array = w.shuffled([s, o4.id])
	var mr: String = w.pick(w.case_script.minions.filter(func(x): return x != "breathstealer" or w.living_with_role("breathstealer") != null))
	e["data"] = {"pair": pair2, "role": mr}
	e["text"] = "I learned that one of %s is the %s" % [w._names(pair2), C.role_name(mr)]
	return {"entry": e, "why": "the dead Archivist %s 'named' scapegoat %s as a minion" % [dd.id, s], "frames": true}


## The same role on a pair with a bystander in one place (FabricationCheck: a better lie).
func bluff_alternatives(w, n, _plan: Dictionary, _s: String, _mate, entry: Dictionary) -> Array:
	var d: Dictionary = entry.get("data", {})
	var pair: Array = d.get("pair", [])
	var role: String = str(d.get("role", ""))
	var out: Array = []
	for i in range(pair.size()):
		for b in bluff_bystanders(w, n):
			if b in pair:
				continue
			var p2: Array = pair.duplicate()
			p2[i] = b
			out.append({"entry": {"data": {"pair": p2, "role": role}, "text": "I learned that one of %s is the %s" % [w._names(p2), content().role_name(role)]}, "why": "names %s instead" % str(p2)})
	return cap_alternatives(w, out)
