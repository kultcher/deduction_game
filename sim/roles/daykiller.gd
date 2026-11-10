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


const PUBLIC: Array = ["tavern", "well", "chapel", "bakery", "wharf", "smithy", "mill", "graveyard"]


## The good townsperson the Hexer most wants dead: the biggest public threat.
static func preferred_target(w, evil):
	var best = null
	var best_s: float = -1.0
	for n in w.living_good():
		var s: float = 0.0
		var parts: Dictionary = evil._public_threat(w, n)
		for k in parts:
			s += float(parts[k])
		if s > best_s:
			best_s = s
			best = n
	return best


## Where the Hexer spends a free phase (world.start_phase; `idle` is its ordinary choice).
## It may go where its preferred target is working; and on an evening it hasn't hexed yet it
## goes out to a public place with good regulars rather than staying home (Nov 10).
func free_location(w, dk, idle: String, evil) -> String:
	var C = content()
	if dk.role != id or not dk.alive or dk.hex_day == w.day or w.day < 1:
		return idle
	var target = preferred_target(w, evil)
	if target != null and w.phase in target.work_phases and target.work in PUBLIC:
		if w.decision_roll(dk, "hex_seek_target", Tuning.Roles.HEXER.seek_target_chance, {"target": target.id}, target.work):
			return target.work
	if w.phase == C.EVENING and (not idle in PUBLIC or regulars(w, idle).is_empty()):
		var best: String = ""
		var best_n: int = 0
		var prefer: Array = ([target.work] + target.haunts) if target != null else []
		for l in prefer + PUBLIC:
			if not l in PUBLIC:
				continue
			var n_regs: int = regulars(w, l).size() + (2 if l in prefer else 0)
			if regulars(w, l).size() > 0 and n_regs > best_n:
				best_n = n_regs
				best = l
		if best != "":
			w.dlog.think(dk.id, "hex_go_out", "Hasn't hexed today: goes out to %s for the evening." % C.loc_name(best))
			return best
	return idle


## The Hexer's day gift runs at the end of each day phase (hex_decision), once the
## Demonologist's place is known; nothing happens at the start.
func run_day_gift(_w, _dk, _mind, _evil) -> void:
	pass


## Once a day, in a public place, the Hexer may hex where it stands. Likelier as the day goes
## on (it marks by the evening if it can), keener on a busy place with threats in it, and
## wary of its own workplace, and of the Demonologist watching with too few others about.
func hex_decision(w, dk, evil) -> void:
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
	var cover: int = w.living().filter(func(m): return m.id != dk.id and m.loc == dk.loc).size()
	var watched: bool = w.phase != C.EVENING and w.phase_player_loc == dk.loc and cover < int(Tuning.Roles.HEXER.cover_needed)
	if watched:
		p -= Tuning.Roles.HEXER.watched_penalty
	if w.phase == C.EVENING:
		p = maxf(p, Tuning.Roles.HEXER.evening_floor)
	if not w.decision_roll(dk, "hex_this_phase", clampf(p, 0.0, 1.0), {"regulars": regs.size(), "threat": threat, "watched": watched, "cover": cover}, dk.loc):
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
