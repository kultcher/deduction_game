## Revenant role definition and simulation hooks.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "revenant"
	display_name = "Revenant"
	align = "evil"
	kind = "evil"
	minion = true
	day = true
	desc = "Hides a totem somewhere each day it has none in play. If hanged while a totem is hidden, a good soul who voted for it turns evil until the totem is found."
	shape = "NONE"


## Whether the Revenant hides its totem here and now (it will by evening).
func place_totem_now(w, rv) -> bool:
	return w.decision_roll(rv, "place_totem_now", Tuning.Roles.REVENANT.place_totem_probs[w.phase])


func run_day_gift(w, rv, _mind, _evil) -> void:
	var C = content()
	if not rv.is_evil() or not w.totem.is_empty() or w.totem_at_dawn or not C.LOCATIONS.has(rv.loc):
		return
	if place_totem_now(w, rv):
		w.totem = {"loc": rv.loc, "day": w.day, "owner": rv.id, "material": rv.home_block}
		w.dlog.add("totem", rv.id, "", w.totem, "%s hides a totem at %s." % [rv.name, C.loc_name(rv.loc)])


func on_executed(w, rv, res: Dictionary, mind) -> void:
	if w.totem.is_empty():
		w.dlog.add("curse_fizzles", rv.id, "", {}, "The Revenant hangs with no totem in play: no curse.")
		return
	if rv.gift_broken():
		w.dlog.add("curse_fizzles", rv.id, "", {}, "The Revenant was poisoned: the curse fails.")
		return
	var cands: Array = res.get("yes", []).map(func(i): return w.by_id[i]).filter(func(m): return m.alive and not m.is_evil())
	if cands.is_empty():
		w.dlog.add("curse_fizzles", rv.id, "", {}, "No good soul voted to hang the Revenant: the curse finds nobody.")
		return
	var v = w.pick(cands)
	w.turn_evil(v, "the Revenant's curse")
	w.curse = {"victim": v.id, "day": w.day, "totem": w.totem.duplicate()}
	# Someone who voted to hang it has turned: each good yes-voter is a little suspect to the rest.
	var voters: Array = res.get("yes", []).filter(func(i): return w.by_id[i].alive)
	for l in w.living_good():
		var e: Array = []
		for i in voters:
			if i != l.id:
				mind._eff(e, i, Tuning.Roles.REVENANT.curse_voter_eff, "voted to hang the Revenant; the curse turned one of those voters")
		if not e.is_empty():
			mind.ledger_hear(w, l, "curse:%d" % w.day, e, 1.0, [], {"kind": "event"})
	w.public_event("curse", [rv.id], rv.id)
	w.meeting["curse"] = true


func should_evil_vote_to_hang(w, nom_n, v) -> bool:
	return nom_n.is_evil() and not w.totem.is_empty() and w.decision_roll(v, "vote_revenant_curse", Tuning.Roles.REVENANT.evil_vote_hang_prob, {}, nom_n.id)
