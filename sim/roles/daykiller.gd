## The Hexer: a demon that kills without walking (docs/demon_types_plan.md, step 3).
## By day it hexes a public place it's standing in; that night a random good regular of the
## place (someone who works there or haunts it) dies at home, wards and the Warden checked as
## usual. The draw ignores wards. It never night-walks; the kill still leaves a trace.
extends "res://sim/role_def.gd"

func _init() -> void:
	id = "daykiller"
	display_name = "Hexer"
	align = "evil"
	kind = "evil"
	day = true
	status = "experimental"
	desc = "Never walks by night. Once a day it hexes a public place it's in; that night one good soul who works or idles there dies."
	shape = "NONE"


## The good regulars of a place: living good NPCs who work there or haunt it.
static func regulars(w, loc: String) -> Array:
	return w.living_good().filter(func(n): return n.work == loc or loc in n.haunts)


## Once a day, in a public place, the Hexer may hex where it stands. Likelier as the day goes
## on (it marks by the evening if it can), keener on a busy place with threats in it, and
## wary of its own workplace.
func run_day_gift(w, dk, _mind, evil) -> void:
	var C = content()
	if dk.role != id or not dk.alive or not dk.is_evil() or dk.hex_day == w.day or w.day < 1:
		return
	if dk.at_home() or not C.LOCATIONS.has(dk.loc):
		return
	var regs: Array = regulars(w, dk.loc)
	if regs.is_empty():
		return
	var threat: float = 0.0
	for n in regs:
		var parts: Dictionary = evil._public_threat(w, n)
		for k in parts:
			threat += float(parts[k])
	threat /= float(regs.size())
	var p: float = Tuning.Roles.HEXER.phase_probs[w.phase]
	p += Tuning.Roles.HEXER.threat_slope * threat + Tuning.Roles.HEXER.busy_slope * float(regs.size() - 1)
	if dk.loc == dk.work:
		p -= Tuning.Roles.HEXER.own_work_penalty
	if w.phase == C.EVENING:
		p = maxf(p, Tuning.Roles.HEXER.evening_floor)
	if not w.decision_roll(dk, "hex_this_phase", clampf(p, 0.0, 1.0), {"regulars": regs.size(), "threat": threat}, dk.loc):
		return
	dk.hex_day = w.day
	dk.hex_loc = dk.loc
	w.dlog.add("hex", dk.id, "", {"loc": dk.loc, "regulars": regs.map(func(n): return n.id)},
		"%s hexes %s: tonight one of its good regulars dies." % [dk.name, C.loc_name(dk.loc)])


## Tonight's victim: a random good regular of today's hexed place, wards ignored. "" when
## nothing was hexed today or nobody's left to draw.
func night_victim(w, dk) -> String:
	var C = content()
	if dk == null or not dk.alive or dk.hex_day != w.day or dk.hex_loc == "":
		return ""
	var regs: Array = regulars(w, dk.hex_loc)
	if regs.is_empty():
		w.dlog.add("hex_empty", dk.id, "", {"loc": dk.hex_loc}, "The hex on %s finds no one." % C.loc_name(dk.hex_loc))
		return ""
	var v = w.pick(regs)
	w.dlog.add("hex_victim", dk.id, v.id, {"loc": dk.hex_loc, "drawn_from": regs.map(func(n): return n.id)},
		"The hex on %s falls on %s." % [C.loc_name(dk.hex_loc), v.name])
	return v.id
