## Rumormonger role definition and simulation hooks.
##
## Shape: SECRET_PAIR (starts knowing that one of two people carries a particular secret).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "rumormonger"
	display_name = "Rumormonger"
	align = "good"
	kind = "info"
	first_night = true
	desc = "Starts knowing that one of two people carries a particular secret."
	shape = "SECRET_PAIR"


func clears(d: Dictionary) -> Array:
	return d.get("pair", [])


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	return "%s Rumormonger: %s in %s" % [src, content().secret_name(d.get("secret", "")), _names(d.get("pair", []), nm)]


func info_effects(_w, listener, source, entry: Dictionary, weight: float, _fresh: bool, mind) -> Array:
	var effs: Array = []
	var d: Dictionary = entry["data"]
	var own: bool = source == listener
	var tag: String = "own info" if own else "heard %s's info (w=%.2f)" % [source.id, weight]
	# Secret-holders are good, so "one of these two carries a secret" speaks for both a little.
	for i in d["pair"]:
		if i != listener.id:
			mind._eff(effs, i, -0.12, tag + ": rumormonger pair probably good", "", not own)
	return effs


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
		sk = w.pick(C.SECRET_MOD_LIST)
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


func generate_bluff_reading(w, _n, _plan: Dictionary, s: String, mate, _asked: Array) -> Dictionary:
	if w.day != 0:
		return {}
	var C = content()
	var other = w.pick(w.living_good().filter(func(x): return x.id != s))
	var pair: Array = w.shuffled([mate.id, other.id])
	var sk: String = w.pick(C.SECRET_MOD_LIST)
	var why: String = "lends teammate %s a harmless secret" % mate.id
	var entry: Dictionary = {
		"data": {"pair": pair, "secret": sk},
		"text": "I heard that one of %s is %s" % [w._names(pair), w._secret_phrase(sk)],
	}
	return {"entry": entry, "why": why}
