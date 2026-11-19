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
	tags = ["protection", "execution"]
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
		var r: float = Tuning.Roles.MARTYR.reluctance_base - Tuning.Roles.MARTYR.reluctance_panic_scale * panic - Tuning.Roles.MARTYR.reluctance_pressure_scale * v.pressure - Tuning.Roles.MARTYR.reluctance_susp_scale * maxf(0.0, base - Tuning.Roles.MARTYR.reluctance_susp_pivot)
		if r > 0.0:
			parts["martyr_reluctance"] = -snappedf(r, 0.01)


func implicated(d: Dictionary) -> Array:
	return [d["target"]] if d.get("evil", false) else []


func clears(d: Dictionary) -> Array:
	return [d["target"]] if d.get("chosen", false) else []


func short_text(d: Dictionary, _src: String, nm: Callable) -> String:
	if d.get("evil", false):
		return "%s: evil" % nm.call(d.get("target", ""))
	return "Chose %s" % nm.call(d.get("target", ""))


func pick_targets(w, mart, mind):
	var best: String = ""
	var best_t: float = 0.0
	for m in w.living():
		if m == mart:
			continue
		var t: float = mart.npc_trust.get(m.id, 0.5) - mind.susp(mart, m.id) * Tuning.Roles.MARTYR.pick_susp_scale + mart.protect_pref.get(m.id, 0.0) * Tuning.Roles.MARTYR.pick_pref_scale
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
		for pid in [mart.id, saved.id]:
			if pid != l.id:
				l.cleared[pid] = true
		mind.ledger_hear(w, l, "martyr:%d" % w.day, [], 1.0, [], {"kind": "martyr", "day": w.day})
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
			info["why"] = "a Marked soul reads as evil"
		w._add_info(mart, info)


## A liar bluffing Martyr whose made-up choice has just hanged: a true Martyr would have
## died in their place, and this one stands, so it tells the town they must have been evil
## (the reading a true Martyr gets when its chosen hangs and it lives).
func on_bluff_chosen_executed(w, executed_npc) -> void:
	for m in w.evil_team():
		if not m.alive or m == executed_npc:
			continue
		# The choice as it will be told (a better lie may have changed it), and only once.
		if not m.info_log.any(func(e): return e.get("fake", false) and e.get("role", "") == "martyr" and bool(e.get("data", {}).get("chosen", false)) and str(e["data"].get("target", "")) == executed_npc.id):
			continue
		if m.info_log.any(func(e): return e.get("fake", false) and e.get("role", "") == "martyr" and e.get("data", {}).has("evil")):
			continue
		var why: String = "said %s, hanged and good, must have been evil, since its made-up Martyr gift didn't take them" % executed_npc.id
		var entry: Dictionary = {
			"day": w.day, "phase": content().EVENING, "role": "martyr", "shared": false, "true": false, "fake": true,
			"why": "evil fabrication: " + load("res://sim/evil.gd").named(w, why),
			"data": {"target": executed_npc.id, "evil": true},
			"text": "As the Martyr, I chose %s. They were hanged and I still stand: they must have been evil or my gift failed" % executed_npc.name,
		}
		m.info_log.append(entry)
		w.dlog.add("fake_info", m.id, "", entry, "%s (evil, bluffing martyr) prepares: %s [%s]" % [m.name, entry["text"], why])


func generate_bluff_reading(w, n, plan: Dictionary, _s: String, mate, _asked: Array) -> Dictionary:
	if w.day == 0 or plan.has("martyr_bluff_" + n.id):
		return {}
	plan["martyr_bluff_" + n.id] = true
	# Michael, Nov 18: choosing a teammate has almost no upside. A liar chooses a good soul,
	# ideally one already under heat and likely to hang: when they're hanged and its gift
	# "doesn't fire", it can say they must have been evil (on_bluff_chosen_executed).
	var tgt = load("res://sim/evil.gd").hottest_good(w, [n.id])
	if tgt == null:
		tgt = mate
	var why: String = "chose %s, a good soul under suspicion, to cast doubt on them should they hang" % tgt.id
	var entry: Dictionary = {
		"data": {"target": tgt.id, "chosen": true},
		"text": "I have given my life over for %s, should the town ever hang them" % tgt.name,
	}
	return {"entry": entry, "why": why}


## Gives its life over for a bystander instead (FabricationCheck: a better lie).
func bluff_alternatives(w, n, _plan: Dictionary, _s: String, _mate, entry: Dictionary) -> Array:
	var d: Dictionary = entry.get("data", {})
	if not d.has("chosen"):
		return []
	var cur: String = str(d.get("target", ""))
	var out: Array = []
	for b in bluff_bystanders(w, n):
		if b == cur:
			continue
		out.append({"entry": {"data": {"target": b, "chosen": true}, "text": "I have given my life over for %s, should the town ever hang them" % w.by_id[b].name}, "why": "'chooses' %s instead" % b})
	return cap_alternatives(w, out)
