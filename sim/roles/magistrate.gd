## Magistrate role definition and simulation hooks.
##
## Each night (from night 1), learns whether the first non-player, non-Magistrate
## nominator that day shared an alignment with the person they nominated. If no such
## nomination happened that day, no reading is produced.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "magistrate"
	display_name = "Magistrate"
	align = "good"
	kind = "info"
	tags = ["ongoing_info", "evil_id"]
	desc = "Each night, learns whether the first townsperson (other than you or the Magistrate) to nominate that day shared an alignment with their nominee."
	shape = "MAGISTRATE_NOM"
	marked_registers = true
	min_gift_day = 1


func gift_live_tonight(w, n) -> bool:
	if w.day < min_gift_day:
		return false
	return not first_eligible_nomination(w, w.day, n.id).is_empty()


func implicated(d: Dictionary) -> Array:
	if not bool(d.get("same", true)):
		var out: Array = []
		for k in ["nominator", "nominee"]:
			var v: String = str(d.get(k, ""))
			if v != "" and v not in out:
				out.append(v)
		return out
	return []


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	var a: String = nm.call(str(d.get("nominator", "")))
	var b: String = nm.call(str(d.get("nominee", "")))
	return "%s Magistrate: %s -> %s (%s)" % [src, a, b, "same" if bool(d.get("same", false)) else "different"]


func _spoken_text(w, nominator: String, nominee: String, same: bool) -> String:
	var a_name: String = w.by_id[nominator].name if w.by_id.has(nominator) else nominator
	var b_name: String = w.by_id[nominee].name if w.by_id.has(nominee) else nominee
	if same:
		return "I weighed the first town nomination and learned that %s and %s shared an alignment" % [a_name, b_name]
	return "I weighed the first town nomination and learned that %s and %s did not share an alignment" % [a_name, b_name]


static func first_eligible_nomination(w, day_num: int, magistrate_id: String) -> Dictionary:
	for ev in w.public_log:
		if int(ev.get("day", -1)) != day_num or str(ev.get("kind", "")) != "nomination":
			continue
		var by: String = str(ev.get("by", ""))
		var subs: Array = ev.get("subjects", [])
		var nominee: String = str(subs[0]) if not subs.is_empty() else ""
		if by == "" or by == "player" or by == magistrate_id or nominee == "" or nominee == by:
			continue
		if w.by_id.has(by) and w.by_id.has(nominee):
			return {"nominator": by, "nominee": nominee}
	return {}


## Alignment at the time the nomination was made during today's meeting (before any
## end-of-meeting execution or Revenant curse activation on today's ballot).
func _evil_at_nomination(w, m) -> bool:
	if not m.is_evil():
		return false
	if m.turned and int(m.turned_day) >= w.day:
		return false
	return true


func _registers_evil_at_nomination(w, m) -> bool:
	if _evil_at_nomination(w, m):
		return true
	return m.secret_mod == "marked" and w.chance(Tuning.Setup.MARKED_EVIL_CHANCE)


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	if w.day < min_gift_day:
		return {}
	var nom: Dictionary = first_eligible_nomination(w, w.day, n.id)
	if nom.is_empty():
		return {}
	var a = w.by_id[nom["nominator"]]
	var b = w.by_id[nom["nominee"]]
	var reg_a: bool = _registers_evil_at_nomination(w, a)
	var reg_b: bool = _registers_evil_at_nomination(w, b)
	var same: bool = (reg_a == reg_b)
	var truth_same: bool = (_evil_at_nomination(w, a) == _evil_at_nomination(w, b))
	var mwhy: String = ""
	if n.gift_broken():
		same = not truth_same
	elif same != truth_same:
		mwhy = "a Marked soul read as evil"
	return {
		"data": {"nominator": a.id, "nominee": b.id, "same": same},
		"true": same == truth_same,
		"why": mwhy,
		"text": _spoken_text(w, a.id, b.id, same),
	}


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, _mate, _asked: Array) -> Dictionary:
	if w.day < min_gift_day:
		return {}
	var nom: Dictionary = first_eligible_nomination(w, w.day, n.id)
	if nom.is_empty():
		return {}
	var a = w.by_id[nom["nominator"]]
	var b = w.by_id[nom["nominee"]]
	var a_ev: bool = _evil_at_nomination(w, a)
	var b_ev: bool = _evil_at_nomination(w, b)
	var same: bool = true
	var why: String = ""
	if a_ev != b_ev:
		# One is evil and one is good: claiming 'same' hides the split (or ties evil to a good townsperson).
		same = true
		why = "masks alignment split between %s and %s" % [a.id, b.id]
	elif not a_ev and not b_ev and (a.id == s or b.id == s):
		# Both good, one is the scapegoat: claiming 'different' casts one of the two as evil!
		same = false
		why = "claims alignment clash involving scapegoat %s (%s -> %s)" % [s, a.id, b.id]
	elif a_ev and b_ev:
		same = false
		why = "distances teammates %s and %s after a bus nomination" % [a.id, b.id]
	else:
		same = w.chance(0.6)
		why = "reports %s -> %s same=%s" % [a.id, b.id, str(same)]
	return {
		"entry": {"data": {"nominator": a.id, "nominee": b.id, "same": same}, "text": _spoken_text(w, a.id, b.id, same)},
		"why": why,
	}


func fake_medium_reading(w, _n, dd, s: String, _sg, _d, _goods: Array, _other: Callable, e: Dictionary, _demon_implicated: bool) -> Dictionary:
	var r_day: int = int(e.get("day", -1))
	if r_day < min_gift_day:
		return {}
	var nom: Dictionary = first_eligible_nomination(w, r_day, dd.id)
	if nom.is_empty():
		return {}
	var a_id: String = nom["nominator"]
	var b_id: String = nom["nominee"]
	var frames_sg: bool = (a_id == s or b_id == s)
	var same: bool = false if frames_sg else true
	e["data"] = {"nominator": a_id, "nominee": b_id, "same": same}
	e["text"] = _spoken_text(w, a_id, b_id, same)
	return {"entry": e, "why": "the dead Magistrate %s weighed %s -> %s (same=%s)" % [dd.id, a_id, b_id, str(same)], "frames": frames_sg}
