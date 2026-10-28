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
	marked_registers = true


func gift_live_tonight(w, _n) -> bool:
	return w.day >= 1 # poison lasts through tomorrow's hanging


func implicated(d: Dictionary) -> Array:
	return [d["target"]] if d.get("evil", false) else []


func clears(d: Dictionary) -> Array:
	return [d["target"]] if d.get("chosen", false) else []


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	if d.get("evil", false):
		return "%s Martyr: %s was evil" % [src, nm.call(d.get("target", ""))]
	return "%s Martyr: chose %s" % [src, nm.call(d.get("target", ""))]


func reading_strength(d: Dictionary, _t_id: String) -> float:
	return 0.9 if d.get("evil", false) else 0.0


func info_effects(_w, listener, source, entry: Dictionary, weight: float, _fresh: bool, mind) -> Array:
	var effs: Array = []
	var d: Dictionary = entry["data"]
	var own: bool = source == listener
	var tag: String = "own info" if own else "heard %s's info (w=%.2f)" % [source.id, weight]
	if d.get("chosen", false) and d["target"] != listener.id:
		mind._eff(effs, d["target"], -0.2, tag + ": the Martyr would die for them", "", not own)
	elif d.get("evil", false) and d["target"] != listener.id:
		mind._eff(effs, d["target"], 1.0, tag + ": hanged and the Martyr lived: evil", "", false)
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
	if best == "" or best_t < 0.62:
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
