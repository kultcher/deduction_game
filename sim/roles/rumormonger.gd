## Rumormonger role definition and simulation hooks.
##
## Shape: SECRET_PAIR (starts knowing that one of two people carries a particular secret).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "rumormonger"
	display_name = "Rumormonger"
	align = "good"
	kind = "info"
	tags = ["first_night_info"]
	first_night = true
	desc = "Starts knowing that one of two people carries a particular secret."
	shape = "SECRET_PAIR"
	cannot_hold_solo_secret = true


func clears(d: Dictionary) -> Array:
	return d.get("pair", [])


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	return "%s Rumormonger: %s in %s" % [src, content().secret_name(d.get("secret", "")), _names(d.get("pair", []), nm)]


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	var C = content()
	var broken: bool = n.gift_broken()
	var holders: Array = w.npcs.filter(func(m): return m != n and m.secret_mod != "")
	var ok: bool = true
	var pair: Array = []
	var sk: String = ""
	if holders.is_empty() or broken:
		var plain: Array = w.npcs.filter(func(m): return m != n and m.secret_mod == "")
		pair = w.shuffled(plain).slice(0, 2).map(func(m): return m.id)
		sk = w.pick(w.case_script.secrets)
		ok = false
	else:
		var h = w.pick(holders)
		sk = h.secret_mod
		var other = w.pick(w.npcs.filter(func(m): return m != n and m != h))
		pair = w.shuffled([h.id, other.id])
	return {
		"data": {"pair": pair, "secret": sk},
		"true": ok,
		"text": "I heard that one of %s is %s" % [w._names(pair), w._secret_phrase(sk)],
	}


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, mate, _asked: Array) -> Dictionary:
	if w.day != 0:
		return {}
	var C = content()
	# Michael, Nov 18: now and then it implies two good townsfolk may be Delusional, which
	# casts doubt on whatever gifts they later claim; otherwise covering a teammate is still
	# the better lie, since a wrong Rumormonger reading is very hard to catch out.
	var goods: Array = w.living_good().filter(func(x): return x != n)
	if "delusional" in w.case_script.secrets and goods.size() >= 2 and w.chance(Tuning.Evil.BLUFF_BLEND_PROB):
		var two: Array = w.shuffled(goods).slice(0, 2).map(func(x): return x.id)
		return {
			"entry": {"data": {"pair": two, "secret": "delusional"}, "text": "I heard that one of %s is %s" % [w._names(two), w._secret_phrase("delusional")]},
			"why": "implied that %s or %s, both good, might be Delusional, to cast doubt on their gifts" % [two[0], two[1]],
		}
	var other = w.pick(w.living_good().filter(func(x): return x.id != s))
	var pair: Array = w.shuffled([mate.id, other.id])
	var sk: String = w.pick(w.case_script.secrets)
	var why: String = "gave %s, a fellow evil, a harmless secret to own to" % mate.id
	var entry: Dictionary = {
		"data": {"pair": pair, "secret": sk},
		"text": "I heard that one of %s is %s" % [w._names(pair), w._secret_phrase(sk)],
	}
	return {"entry": entry, "why": why}


## The same secret on a pair with a bystander in one place (FabricationCheck: a better lie).
func bluff_alternatives(w, n, _plan: Dictionary, _s: String, _mate, entry: Dictionary) -> Array:
	var d: Dictionary = entry.get("data", {})
	var pair: Array = d.get("pair", [])
	var sk: String = str(d.get("secret", ""))
	var out: Array = []
	for i in range(pair.size()):
		for b in bluff_bystanders(w, n):
			if b in pair:
				continue
			var p2: Array = pair.duplicate()
			p2[i] = b
			out.append({"entry": {"data": {"pair": p2, "secret": sk}, "text": "I heard that one of %s is %s" % [w._names(p2), w._secret_phrase(sk)]}, "why": "names %s instead" % str(p2)})
	return cap_alternatives(w, out)
