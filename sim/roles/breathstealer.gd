## Breathstealer role definition and simulation hooks.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "breathstealer"
	display_name = "Breathstealer"
	align = "evil"
	kind = "evil"
	minion = true
	day = true
	desc = "Once a day, silences someone on the same block, from that evening's meeting until the next evening. Silenced people can still vote."
	shape = "NONE"


## The Breathstealer picks whom to silence, among the good on its block (not the same
## person twice running). Likelier as the day goes on; the most dangerous voice first.
func breath_target(w, bs, evil) -> String:
	# The Breathstealer must be out in a public place; the target can be anywhere on the
	# same block (Case 22485: no stealing breath from inside one's own house).
	if bs.at_home():
		return ""
	var b: String = w.loc_block(bs.loc)
	var cands: Array = w.living_good().filter(func(m): return m.id != bs.breath_last and m.silence_pending < 0 and not m.silenced \
		and (m.home_block if m.at_home() else w.loc_block(m.loc)) == b)
	if cands.is_empty():
		return ""
	var best = ""
	var best_s = -99.0
	var scores = {}
	var observed = {}
	for n in cands:
		var parts: Dictionary = evil._public_threat(w, n)
		var hostile: float = evil.public_hostility(w, n)
		if hostile > 0.0:
			parts["publicly_against_us"] = hostile
		var known: float = evil.intel_threat(bs, n.id)
		if known > 0.0:
			parts["known_threat"] = known
		var noise_draw: float = w.rng.randf()
		parts["noise"] = snappedf(noise_draw * 1.0, 0.01)
		var total = 0.0
		for k in parts:
			total += parts[k]
		if w.dlog.live_feed != null and w.dlog.live_feed.enabled:
			observed[n.id] = {"score": total, "raw_draw": noise_draw, "noise": parts["noise"], "parts": parts.duplicate()}
		scores[n.id] = snappedf(total, 0.01)
		if total > best_s:
			best_s = total
			best = n.id
	w.observe_ranked(bs, "silence_ranking", observed, best, 1.0)
	var p: float = [0.3, 0.5, 1.0][w.phase] if best_s > 1.0 else [0.15, 0.3, 0.7][w.phase]
	if not w.decision_roll(bs, "silence_this_phase", p, {"best_target_score": best_s}, best):
		w.dlog.think(bs.id, "breath_choice", "Breathstealer holds off this phase (best %s, %.2f)." % [best, best_s], {"scores": scores})
		return ""
	w.dlog.think(bs.id, "breath_choice", "Breathstealer silences %s (score %.2f)." % [best, best_s], {"scores": scores})
	return best


func run_day_gift(w, bs, _mind, evil) -> void:
	if not bs.is_evil() or bs.breath_day == w.day:
		return
	var tgt: String = breath_target(w, bs, evil)
	if tgt == "":
		return
	bs.breath_day = w.day
	bs.breath_last = tgt
	if bs.gift_broken():
		w.dlog.add("breath_failed", bs.id, tgt, {}, "%s tries to steal %s's breath, but is poisoned." % [bs.name, w.by_id[tgt].name])
	else:
		w.by_id[tgt].silence_pending = w.day
		w.dlog.add("breath", bs.id, tgt, {"loc": bs.loc}, "%s steals %s's breath: silent from this evening's meeting." % [bs.name, w.by_id[tgt].name])
