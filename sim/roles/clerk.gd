## Clerk role definition and simulation hooks.
##
## Shape: ROLE_IN_GROUP ({pair, role}) — starts knowing that one of two people holds a
## particular good gift.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "clerk"
	display_name = "Clerk"
	align = "good"
	kind = "info"
	tags = ["first_night_info"]
	first_night = true
	desc = "Starts knowing that one of two people holds a particular gift."
	shape = "ROLE_IN_GROUP"
	role_group_key = "pair"
	role_target_pool = "good"


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	return "%s Clerk: %s in %s" % [src, content().role_name(d.get("role", "")), _names(d.get("pair", []), nm)]


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	var broken: bool = n.gift_broken()
	var targets: Array = w.npcs.filter(func(m): return m != n and not m.is_evil())
	var t = w.pick(targets)
	var other = w.pick(w.npcs.filter(func(m): return m != n and m != t))
	var role: String = t.role
	var ok = true
	if broken:
		var C = content()
		role = w.pick(w.case_script.town.filter(func(x): return x != t.role and x != other.role and x != "clerk"))
		ok = false
	var pair: Array = w.shuffled([t.id, other.id])
	return {
		"data": {"pair": pair, "role": role},
		"true": ok,
		"text": "I learned that one of %s is the %s" % [w._names(pair), content().role_name(role)],
	}


func generate_bluff_reading(w, n, plan: Dictionary, _s: String, mate, _asked: Array) -> Dictionary:
	if w.day != 0:
		return {}
	var C = content()
	# Michael, Nov 18: a Scion or Demon may blend in instead, by "confirming" a good
	# townsperson who claimed early. Nobody has claimed yet on the first night, so it is told
	# as a cover now and changed, if still untold, once a good townsperson has claimed
	# (Evil.blend_clerk_readings). Its telling isn't held back for it.
	if load("res://sim/evil.gd").blends_in(w, n) and w.chance(Tuning.Evil.BLUFF_BLEND_PROB):
		plan["clerk_blend_" + n.id] = true
	var other = w.pick(w.living_good())
	var role: String = plan["bluffs"].get(mate.id, w.pick(w.case_script.town))
	var pair: Array = w.shuffled([mate.id, other.id])
	var why = "vouched for %s, a fellow evil, as the %s" % [mate.id, content().role_name(role)]
	var entry: Dictionary = {
		"data": {"pair": pair, "role": role},
		"text": "I learned that one of %s is the %s" % [w._names(pair), C.role_name(role)],
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(w, n, dd, _s: String, _sg, _d, _goods: Array, other: Callable, e: Dictionary, _demon_implicated: bool) -> Dictionary:
	# Back a teammate's bluff.
	var C = content()
	var team_mates: Array = w.evil_team().filter(func(x): return x != n and x.alive)
	var claimed: Array = team_mates.filter(func(x): return x.claim_public and C.ROLES.get(x.claimed_role, {}).get("align", "") == "good")
	if claimed.is_empty():
		return {}
	var m = w.pick(claimed)
	var o3 = other.call([])
	if o3 == null:
		return {}
	var pair: Array = w.shuffled([m.id, o3.id])
	e["data"] = {"pair": pair, "role": m.claimed_role}
	e["text"] = "I learned that one of %s is the %s" % [w._names(pair), C.role_name(m.claimed_role)]
	return {"entry": e, "why": "made up a reading from the late Clerk %s that backed the claim of %s, a fellow evil" % [dd.id, m.id], "frames": false}


## The same role on a pair with a bystander in one place (FabricationCheck: a better lie).
func bluff_alternatives(w, n, _plan: Dictionary, _s: String, _mate, entry: Dictionary) -> Array:
	var d: Dictionary = entry.get("data", {})
	var pair: Array = d.get("pair", [])
	var out: Array = []
	for i in range(pair.size()):
		for b in bluff_bystanders(w, n):
			if b in pair:
				continue
			var p2: Array = pair.duplicate()
			p2[i] = b
			out.append({"entry": {"data": {"pair": p2, "role": d.get("role", "")}, "text": "I learned that one of %s is the %s" % [w._names(p2), content().role_name(str(d.get("role", "")))]}, "why": "names %s instead" % str(p2)})
	return cap_alternatives(w, out)
