## Martyr role definition and simulation hooks.
##
## Shape: NIGHT_EVENT (once per case, secretly chooses someone; if they are later
## executed while good, the Martyr dies in their place, or learns they were evil if
## they hang and the Martyr lives).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "martyr"
	display_name = "Martyr"
	align = "good"
	kind = "protect"
	desc = "Once per case, secretly chooses someone. If they are later executed while good, the Martyr dies in their place."
	shape = "NIGHT_EVENT"
	produces_readings = true
	marked_registers = true
	evening_or_night = true
	min_gift_day = 1


func gift_live_tonight(w, _n) -> bool:
	return w.day >= 1 # poison lasts through tomorrow's hanging


func score_public_claim(w, n, parts: Dictionary) -> void:
	super.score_public_claim(w, n, parts)
	if not n.is_evil() and n.martyr_target != "":
		parts["martyr_chosen"] = Tuning.Roles.MARTYR.claim_chosen_bonus # coming out as the Martyr protects their choice by deterrence


func score_vote_reluctance(_w, v, nominee: String, base: float, panic: float, parts: Dictionary) -> void:
	if v.martyr_target == nominee and not v.gift_broken():
		# They'd die in this one's place: reluctant, unless the case, the pressure or the
		# panic is overwhelming.
		var r: float = 0.6 - 0.4 * panic - 0.3 * v.pressure - 0.4 * maxf(0.0, base - 0.8)
		if r > 0.0:
			parts["martyr_reluctance"] = -snappedf(r, 0.01)


func implicated(d: Dictionary) -> Array:
	return [d["target"]] if d.get("evil", false) else []


func clears(d: Dictionary) -> Array:
	return [d["target"]] if d.get("chosen", false) else []


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	if d.get("evil", false):
		return "%s Martyr: %s was evil" % [src, nm.call(d.get("target", ""))]
	return "%s Martyr: chose %s" % [src, nm.call(d.get("target", ""))]


func reading_strength(d: Dictionary, _t_id: String) -> float:
	return Tuning.Roles.MARTYR.reading_strength_evil if d.get("evil", false) else 0.0


func info_effects(_w, listener, source, entry: Dictionary, weight: float, _fresh: bool, mind) -> Array:
	var effs: Array = []
	var d: Dictionary = entry["data"]
	var own: bool = source == listener
	var tag: String = "own info" if own else "heard %s's info (w=%.2f)" % [source.id, weight]
	if d.get("chosen", false) and d["target"] != listener.id:
		mind._eff(effs, d["target"], Tuning.Roles.MARTYR.eff_chosen_good, tag + ": the Martyr would die for them", "", not own)
	elif d.get("evil", false) and d["target"] != listener.id:
		mind._eff(effs, d["target"], Tuning.Roles.MARTYR.eff_hanged_evil, tag + ": hanged and the Martyr lived: evil", "", false)
	return effs


func pick_targets(w, mart, mind):
	var best: String = ""
	var best_t: float = 0.0
	for m in w.living():
		if m == mart:
			continue
		var t: float = mart.npc_trust.get(m.id, 0.5) - mind.susp(mart, m.id) * 0.5 + mart.protect_pref.get(m.id, 0.0) * 0.5
		if t > best_t:
			best_t = t
			best = m.id
	if best == "" or best_t < Tuning.Roles.MARTYR.pick_min_score:
		w.dlog.think(mart.id, "martyr_pick", "Martyr: nobody trusted enough yet (best %s at %.2f; needs 0.62)." % [best, best_t])
		return ""
	mart.martyr_target = best
	w.dlog.add("martyr_choice", mart.id, best, {"score": snappedf(best_t, 0.01)}, "%s (Martyr) secretly chooses %s." % [mart.name, w.by_id[best].name])
	w._add_info(mart, {
		"data": {"target": best, "chosen": true},
		"true": not mart.gift_broken(),
		"text": "I have given my life over for %s, should the town ever hang them" % w.by_id[best].name,
	})
	return best


var _last_reads_target: String = ""
var _last_reads_evil: bool = false


func can_substitute_execution(w, mart, target_id: String) -> bool:
	var mart_chosen: bool = mart != null and mart.martyr_target == target_id
	_last_reads_target = target_id if mart_chosen else ""
	_last_reads_evil = w.registers_evil(w.by_id[target_id]) if mart_chosen else false
	return mart_chosen and mart.id != target_id and not _last_reads_evil and not mart.gift_broken()


func on_substitute_execution(w, mart, saved, res: Dictionary, mind) -> void:
	mart.alive = false
	mart.death_day = w.day
	mart.death_cause = "martyr"
	mart.loc = "dead"
	w._bereave(mart)
	mart.gift_used = true
	w.executed_today = ""
	w.executions.append({
		"day": w.day,
		"id": mart.id,
		"saved": saved.id,
		"martyr": true,
		"nominator": res.get("by", ""),
		"yes": res.get("yes", []),
		"player_yes": res.get("player_yes", false),
		"player_nominated": res.get("by", "") == "player",
	})
	w.public_event("martyr", [mart.id, saved.id], mart.id)
	w.meeting["martyr"] = {"martyr": mart.id, "saved": saved.id}
	w.dlog.add("martyr", mart.id, saved.id, {}, "%s (Martyr) dies in %s's place at the gallows. Both proven good." % [mart.name, saved.name])
	for real in w.living():
		var l = real.shadow if real.is_evil() else real
		if l == null:
			continue
		var e: Array = []
		for pid in [mart.id, saved.id]:
			if pid != l.id:
				l.cleared[pid] = true
				mind._eff(e, pid, Tuning.Roles.MARTYR.substitute_clear_eff, "the Martyr died in %s's place: proven good" % saved.id)
		mind.ledger_hear(w, l, "martyr:%d" % w.day, e, 1.0, [], {"kind": "martyr", "day": w.day})
	w._check_parity()


func on_chosen_executed(w, mart, executed_npc) -> void:
	var mart_chosen: bool = mart != null and mart.martyr_target == executed_npc.id
	var reads_evil: bool = _last_reads_evil if _last_reads_target == executed_npc.id else (w.registers_evil(executed_npc) if mart_chosen else false)
	_last_reads_target = ""
	if mart_chosen and reads_evil and not mart.gift_broken():
		# Hanged, and the Martyr still stands: their chosen was evil.
		var info: Dictionary = {
			"data": {"target": executed_npc.id, "evil": true},
			"true": executed_npc.is_evil(),
			"text": "As the Martyr, I chose %s. They were hanged and I still stand: they must have been evil or my gift failed" % executed_npc.name,
		}
		if not executed_npc.is_evil():
			info["why"] = "Marked reads as evil"
		w._add_info(mart, info)


func generate_bluff_reading(w, n, plan: Dictionary, _s: String, mate, _asked: Array) -> Dictionary:
	if w.day == 0 or plan.has("martyr_bluff_" + n.id):
		return {}
	plan["martyr_bluff_" + n.id] = true
	var tgt = mate if mate != n else w.pick(w.living_good())
	var why: String = "'chooses' %s, vouching for them" % tgt.id
	var entry: Dictionary = {
		"data": {"target": tgt.id, "chosen": true},
		"text": "I have given my life over for %s, should the town ever hang them" % tgt.name,
	}
	return {"entry": entry, "why": why}
