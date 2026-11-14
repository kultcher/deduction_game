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


const PUBLIC: Array = ["tavern", "well", "chapel", "bakery", "wharf", "smithy", "mill", "graveyard"]


## Whom it most wants silenced: the biggest public threat it may silence today.
static func preferred_target(w, bs, evil):
	var best = null
	var best_s: float = -1.0
	for n in w.living_good():
		if n.id == bs.breath_last or n.silenced or n.silence_pending >= 0:
			continue
		var s: float = evil.intel_threat(bs, n.id) + evil.public_hostility(w, n)
		var parts: Dictionary = evil._public_threat(w, n)
		for k in parts:
			s += float(parts[k])
		if s > best_s:
			best_s = s
			best = n
	return best


## Where it spends a free phase (world.start_phase; `idle` is its ordinary choice). It hunts
## (Nov 14): it may go where its preferred target is working, and otherwise, until it has
## silenced today, it goes out to the public place on whose block the most good people are,
## rather than home or somewhere empty.
func free_location(w, bs, idle: String, evil) -> String:
	if not bs.alive or not bs.is_evil() or bs.breath_day == w.day or w.day < 1 or w.is_minion_suppressed():
		return idle
	var target = preferred_target(w, bs, evil)
	if target != null and w.phase in target.work_phases and target.work in PUBLIC:
		if w.decision_roll(bs, "breath_seek_target", Tuning.Roles.BREATHSTEALER.seek_target_chance, {"target": target.id}, target.work):
			return target.work
	# Only people it may silence today count: not yesterday's, not anyone silenced already.
	var good_on: Dictionary = {}
	for m in w.living_good():
		if m.id == bs.breath_last or m.silenced or m.silence_pending >= 0:
			continue
		if w.phase in m.work_phases and m.work in PUBLIC:  # (placed later in this loop, so read the schedule)
			var blk: String = w.loc_block(m.work)
			good_on[blk] = int(good_on.get(blk, 0)) + 1
	var here: int = int(good_on.get(w.loc_block(idle), 0)) if idle in PUBLIC else 0
	if here > 0:
		return idle
	var best: String = ""
	var best_n: int = 0
	for l in PUBLIC:
		var n: int = int(good_on.get(w.loc_block(l), 0))
		if n > best_n:
			best_n = n
			best = l
	if best != "":
		w.dlog.think(bs.id, "breath_go_out", "Hunting: goes to %s, where good people are working." % content().loc_name(best))
		return best
	if w.phase == content().EVENING and not idle in PUBLIC:
		# Few work evenings; the idle crowd is at the tavern (World._choose_idle_location).
		w.dlog.think(bs.id, "breath_go_out", "Hunting: goes to the tavern for the evening crowd.")
		return "tavern"
	return idle


## The Breathstealer picks whom to silence, among the good on its block (not the same
## person twice running). Likelier as the day goes on; the most dangerous voice first.
func breath_target(w, bs, evil) -> String:
	# Both the Breathstealer and their target must be out in a public place on the
	# same block (Case 22485: no stealing breath from or inside a private house).
	if bs.at_home():
		return ""
	var b: String = w.loc_block(bs.loc)
	var cands: Array = w.living_good().filter(func(m): return m.id != bs.breath_last and m.silence_pending < 0 and not m.silenced \
		and not m.at_home() and w.loc_block(m.loc) == b)
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
		parts["noise"] = snappedf(noise_draw * Tuning.Roles.BREATHSTEALER.noise, 0.01)
		var total = 0.0
		for k in parts:
			total += parts[k]
		if w.dlog.live_feed != null and w.dlog.live_feed.enabled:
			observed[n.id] = {"score": total, "raw_draw": noise_draw, "noise": parts["noise"], "parts": parts.duplicate()}
		scores[n.id] = snappedf(total, 0.01)
		if total > best_s:
			best_s = total
			best = n.id
	w.observe_ranked(bs, "silence_ranking", observed, best, Tuning.Roles.BREATHSTEALER.noise)
	var p: float = Tuning.Roles.BREATHSTEALER.phase_probs_high[w.phase] if best_s > Tuning.Roles.BREATHSTEALER.high_score_threshold else Tuning.Roles.BREATHSTEALER.phase_probs_low[w.phase]
	# A crowd is cover: with enough others in the same place, anyone could have done it.
	var crowd: int = w.living().filter(func(m): return m.id != bs.id and m.loc == bs.loc).size()
	if crowd >= Tuning.Roles.BREATHSTEALER.crowd_size:
		p = minf(1.0, p + Tuning.Roles.BREATHSTEALER.crowd_bonus)
	if not w.decision_roll(bs, "silence_this_phase", p, {"best_target_score": best_s, "crowd": crowd}, best):
		w.dlog.think(bs.id, "breath_choice", "Breathstealer holds off this phase (best %s, %.2f)." % [best, best_s], {"scores": scores})
		return ""
	w.dlog.think(bs.id, "breath_choice", "Breathstealer silences %s (score %.2f)." % [best, best_s], {"scores": scores})
	return best


func run_day_gift(w, bs, _mind, evil) -> void:
	if not bs.is_evil() or bs.breath_day == w.day:
		return
	if w.is_minion_suppressed():
		return  # the Sexton's bell: no silencing until the next night
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
