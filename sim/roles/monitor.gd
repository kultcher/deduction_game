## Monitor role definition and simulation hooks.
##
## Shape: MONITOR (each night from Night 1, learns the role of one person who walked
## abroad on their home block, or that no one walked by their house). Home-block only
## (night_walk: false). Never receives window street sightings.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "monitor"
	display_name = "Monitor"
	align = "good"
	kind = "info"
	tags = ["ongoing_info", "role_id"]
	min_gift_day = 1
	night_walk = false
	marked_registers = true
	desc = "Each night (not the first), learns the role of one person who walked abroad on their home block, or that no one walked by their house. Never receives window night sightings."
	shape = "MONITOR"


func is_valid_gift_time(observed_at: Dictionary) -> bool:
	return int(observed_at.get("day", -1)) >= min_gift_day and str(observed_at.get("phase", "")) == "night"


func is_ongoing_info() -> bool:
	return true


func short_text(d: Dictionary, src: String, _nm: Callable) -> String:
	var C = content()
	var bname: String = C.block_name(str(d.get("block", "")))
	if bool(d.get("walked", false)):
		return "%s Monitor: %s on %s" % [src, C.role_name(str(d.get("role", ""))), bname]
	return "%s Monitor: none on %s" % [src, bname]


func _spoken_text(block: String, walked: bool, role: String) -> String:
	var C = content()
	var bname: String = C.block_name(block)
	if walked:
		return "I learned that a %s was abroad on %s" % [C.role_name(role), bname]
	return "no one walked by my house"


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	if w.day < min_gift_day:
		return {}
	var C = content()
	var blk: String = n.home_block
	var broken: bool = n.gift_broken()
	var active_script_roles: Array = (w.case_script.town + w.case_script.minions + w.case_script.demons) if (w.case_script != null and not w.case_script.town.is_empty()) else (C.GOOD_ROLES + C.EVIL_ROLES)

	# Living night walkers whose path crossed Monitor's home block (excluding self)
	var walkers: Array = []
	for wk in w.night_walkers:
		if wk["id"] != n.id and blk in wk.get("path", [wk["block"]]):
			var wn = w.by_id.get(wk["id"])
			if wn != null and wn.alive:
				walkers.append(wn)

	var true_walked: bool = not walkers.is_empty()
	var true_role: String = ""      # what the gift reads (a Marked soul may read as evil)
	var real_role: String = ""      # who actually walked by
	var marked_triggered: bool = false
	if true_walked:
		var chosen = w.pick(walkers)
		true_role = chosen.role
		real_role = chosen.role
		# One roll, as everywhere else (World.registers_evil already rolls the Marked chance).
		if chosen.secret_mod == "marked" and not chosen.is_evil() and w.registers_evil(chosen):
			var evil_script: Array = (w.case_script.demons + w.case_script.minions) if (w.case_script != null and not w.case_script.minions.is_empty()) else C.EVIL_ROLES
			true_role = str(w.pick(evil_script))
			marked_triggered = true

	var walked: bool = true_walked
	var role: String = true_role
	var why: String = ""

	if broken:
		var b_why: String = "poisoned" if n.poisoned else "delusional"
		why = b_why
		if not true_walked:
			walked = true
			role = str(w.pick(active_script_roles))
		else:
			if w.chance(0.4):
				walked = false
				role = ""
			else:
				walked = true
				var other_roles: Array = active_script_roles.filter(func(r): return r != true_role)
				role = str(w.pick(other_roles)) if not other_roles.is_empty() else str(w.pick(active_script_roles))
	elif marked_triggered:
		why = "a Marked soul read as evil"

	var data: Dictionary = {"block": blk, "walked": walked}
	if walked and role != "":
		data["role"] = role

	# Measured against who really walked by: a Marked misreading is false (as the Dowser's is).
	var is_true: bool = (walked == true_walked) and (not walked or role == real_role)
	var entry: Dictionary = {
		"data": data,
		"true": is_true,
		"text": _spoken_text(blk, walked, role),
	}
	if why != "":
		entry["why"] = why
	return entry


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, mate, _asked: Array) -> Dictionary:
	if w.day < min_gift_day:
		return {}
	var C = content()
	var blk: String = n.home_block
	var active_script_roles: Array = (w.case_script.town + w.case_script.minions + w.case_script.demons) if (w.case_script != null and not w.case_script.town.is_empty()) else (C.GOOD_ROLES + C.EVIL_ROLES)
	var sg = w.by_id.get(s)
	var why: String = ""
	var walked: bool = false
	var role: String = ""

	if sg != null and sg.alive and w.chance(0.6):
		walked = true
		role = sg.role if w.chance(0.5) else str(w.pick(active_script_roles))
		why = "claims a %s was abroad on %s (framing scapegoat %s)" % [role, blk, s]
	elif mate != null and mate != n and mate.alive and w.chance(0.4):
		walked = false
		why = "claims no one walked on %s (covering teammate %s)" % [blk, mate.id]
	else:
		walked = w.chance(0.5)
		if walked:
			role = str(w.pick(active_script_roles))
			why = "reports %s abroad on %s" % [role, blk]
		else:
			why = "reports no one walked on %s" % blk

	var data: Dictionary = {"block": blk, "walked": walked}
	if walked and role != "":
		data["role"] = role
	var entry: Dictionary = {
		"data": data,
		"text": _spoken_text(blk, walked, role),
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(w, _n, dd, s: String, sg, _d, _goods: Array, _other: Callable, e: Dictionary, _demon_implicated: bool) -> Dictionary:
	var C = content()
	var blk: String = dd.home_block
	var active_script_roles: Array = (w.case_script.town + w.case_script.minions + w.case_script.demons) if (w.case_script != null and not w.case_script.town.is_empty()) else (C.GOOD_ROLES + C.EVIL_ROLES)
	var role: String = sg.role if (sg != null and w.chance(0.6)) else str(w.pick(active_script_roles))
	e["data"] = {"block": blk, "walked": true, "role": role}
	e["text"] = _spoken_text(blk, true, role)
	return {"entry": e, "why": "the dead Monitor %s reported a %s was abroad on %s (framing %s)" % [dd.id, role, blk, s], "frames": true}


func check_public_sighting_pregate(_w, _n, b: Dictionary, _mind) -> int:
	if str(b.get("how", "")) == "window":
		return -1
	return 0


func override_night_sightings(_w, n, nd: int, reported: Array = []) -> Dictionary:
	if not n.is_evil():
		return {}
	# Evil bluffing Monitor: the night asked about only, already cleared of teammates and
	# of anything seen from where they say they weren't; and never a window sighting.
	var filtered: Array = reported.filter(func(b): return b.get("kind") == "saw" and int(b.get("day", -1)) == nd and str(b.get("how", "")) != "window")
	return {"handled": true, "reported": filtered}
