## Psychologist role definition and simulation hooks.
##
## Shape: SOCIAL_PAIR (each night, picks someone they talked with that day and learns
## whom that person trusts and suspects most).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "psychologist"
	display_name = "Psychologist"
	align = "good"
	kind = "info"
	desc = "Each night, picks someone they talked with that day and learns whom that person trusts and suspects most."
	shape = "SOCIAL_PAIR"
	conversation_nudge = 0.5


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	return "%s Psychologist: %s trusts %s, suspects %s" % [src, nm.call(d.get("subject", "")), nm.call(d.get("trusts", "")), nm.call(d.get("suspects", ""))]


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	var broken: bool = n.gift_broken()
	var talked: Array = n.talked_today.filter(func(i): return w.by_id[i].alive and i != n.id)
	if talked.is_empty():
		return {}
	var subj = w.by_id[w.pick(talked)]
	var res: Dictionary = w._psych_read(subj)
	var ok: bool = true
	if broken:
		var others: Array = w.living().filter(func(m): return m != subj).map(func(m): return m.id)
		res = {"trusts": w.pick(others), "suspects": w.pick(others)}
		ok = false
	return {
		"data": {"subject": subj.id, "trusts": res["trusts"], "suspects": res["suspects"]},
		"true": ok,
		"text": "I read %s: they trust %s most, and suspect %s most" % [subj.name, w.by_id[res["trusts"]].name, w.by_id[res["suspects"]].name],
	}


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, _mate, _asked: Array) -> Dictionary:
	var talked: Array = n.talked_today.filter(func(i): return w.by_id[i].alive and i != s)
	if talked.is_empty() or not w.by_id[s].alive:
		return {}
	var subj: String = talked[w.rng.randi_range(0, talked.size() - 1)]
	var tr = w.pick(w.living().filter(func(x): return x.id != subj and x.id != s))
	if tr == null:
		return {}
	var why: String = "says %s suspects scapegoat %s most" % [subj, s]
	var entry: Dictionary = {
		"data": {"subject": subj, "trusts": tr.id, "suspects": s},
		"text": "I read %s: they trust %s most, and suspect %s most" % [w.by_id[subj].name, tr.name, w.by_id[s].name],
	}
	return {"entry": entry, "why": why}


func fake_medium_reading(w, n, dd, s: String, _sg, _d, _goods: Array, other: Callable, e: Dictionary, _demon_implicated: bool) -> Dictionary:
	var team_mates: Array = w.evil_team().filter(func(x): return x != n and x.alive)
	var subj = other.call([s])
	var tr = w.pick(team_mates) if not team_mates.is_empty() else null
	if subj == null or tr == null:
		return {}
	var sus_id: String = s if w.chance(0.6) else (other.call([subj.id]).id if other.call([subj.id]) != null else s)
	e["data"] = {"subject": subj.id, "trusts": tr.id, "suspects": sus_id}
	e["text"] = "I read %s: they trust %s most, and suspect %s most" % [subj.name, tr.name, w.by_id[sus_id].name]
	return {"entry": e, "why": "the dead Psychologist %s 'read' trust in %s" % [dd.id, tr.id], "frames": true}
