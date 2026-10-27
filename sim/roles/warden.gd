## Warden role definition and simulation hooks.
##
## Shape: NIGHT_EVENT (protective night walker; guards one door each night, logs
## guarded targets in `n.warden_log`, and reports guarded doors when asked about its gift
## or night whereabouts).
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "warden"
	display_name = "Warden"
	align = "good"
	kind = "protect"
	night_walk = true
	desc = "Each night, guards one other person's door against the demon."
	shape = "NIGHT_EVENT"
	can_cause_quiet_night = true
	quiet_night_effect = -0.15
	request_agree_line = "Very well. I'll stand at %s's door tonight."


## Pick whom the Warden guards tonight (trusted info claimants, trusted people).
func pick_targets(w, n, mind):
	var asked: Array = mind.requested_targets(w, n, "warden")
	if not asked.is_empty() and w.by_id[asked[0]].alive:
		w.dlog.think(n.id, "warden_pick", "Guards whom the Demonologist asked.", {"pick": asked[0]})
		return asked[0]
	var best = ""
	var best_s = -99.0
	var scores = {}
	var observed = {}
	for m in w.living():
		if m == n:
			continue
		var noise_draw: float = w.rng.randf()
		var noise: float = noise_draw * 0.3
		var s: float = noise
		if m.claim_public and m.claimed_role in mind.C.INFO_ROLES:
			s += 1.0 - mind.susp(n, m.id)
		s += (n.npc_trust.get(m.id, 0.5) - 0.5) * 0.8
		s -= mind.susp(n, m.id) * 0.5
		s += n.protect_pref.get(m.id, 0.0) * 1.2
		if w.dlog.live_feed != null and w.dlog.live_feed.enabled:
			observed[m.id] = {
				"score": s,
				"raw_draw": noise_draw,
				"noise": noise,
				"parts": {"target_score_before_noise": s - noise},
				"inputs": {
					"target_trust": n.npc_trust.get(m.id, 0.5),
					"target_suspicion": mind.susp(n, m.id),
					"protection_preference": n.protect_pref.get(m.id, 0.0),
					"target_info_claim": m.claim_public and m.claimed_role in mind.C.INFO_ROLES,
				},
			}
		scores[m.id] = snappedf(s, 0.01)
		if s > best_s:
			best_s = s
			best = m.id
	w.observe_ranked(n, "warden_target", observed, best, 0.3)
	w.dlog.think(n.id, "warden_pick", "Protects whoever scores highest (trusted info claimants, trusted people).", {"scores": scores, "pick": best})
	return best


func score_gift_request(_w, n, targets: Array, _top: String, parts: Dictionary, mind) -> void:
	var t: String = targets[0]
	parts["cares_for_them"] = (n.npc_trust.get(t, 0.5) - 0.5) * 1.0
	parts["suspects_them"] = -mind.susp(n, t) * 1.0


func on_evil_agreed_request(w, n, asked: Array) -> void:
	if not asked.is_empty():
		n.warden_log[str(w.day)] = asked[0]


func has_gift_outing(n, night: int) -> bool:
	return n.warden_log.has(str(night))


func public_sighting_allowed(w, n, b: Dictionary) -> bool:
	var guarded: String = n.warden_log.get(str(b.day), "")
	return w.by_id.has(guarded) and w.by_id[guarded].home_block == b.block


## Whose door a Warden (or an evil Warden bluff) says they guarded on night `nd`.
## A bluff invents one on the block they were really on (or anyone, if they stayed in),
## once per night, so the story stays the same however often they're asked.
func warden_door(w, n, nd: int) -> String:
	if n.warden_log.has(str(nd)) or not n.is_evil():
		return n.warden_log.get(str(nd), "")
	var hist: String = n.history.get(w.time_key(nd, 3), "home:" + n.home_block)
	var was_out: bool = hist.begins_with("night:")
	var block: String = hist.split(":")[1] if ":" in hist else n.home_block
	var cands: Array = w.living().filter(func(m): return m != n and (not was_out or m.home_block == block))
	if cands.is_empty():
		cands = w.living().filter(func(m): return m != n)
	var guarded: String = w.decision_pick(n, "bluffed_guard_door", cands).id if not cands.is_empty() else ""
	n.warden_log[str(nd)] = guarded
	w.dlog.think(n.id, "lie", "Evil bluffing Warden: claims to have guarded %s on night %d." % [guarded, nd], {"lie": true})
	return guarded


func guard_fact(w, n, nd: int, guarded: String, block_name_fn: Callable) -> Dictionary:
	var gb: String = w.by_id[guarded].home_block
	return {
		"kind": "sighting",
		"subject": [n.id],
		"block": gb,
		"day": nd,
		"phase": 3,
		"source": n.id,
		"guard_claim": guarded,
		"text": "%s says they guarded %s's door (on %s) on night %d." % [n.name, w.by_id[guarded].name, block_name_fn.call(gb), nd],
	}


func answer_gift_custom(w, n, first_time: bool, tier: int, lines: Array, facts: Array, mind, night_name_fn: Callable, block_name_fn: Callable) -> Dictionary:
	var doors: Array = []
	for nd in range(0, w.day):
		var gd: String = warden_door(w, n, nd)
		if gd != "" and w.by_id.has(gd):
			doors.append("%s at %s's door" % [night_name_fn.call(nd), w.by_id[gd].name])
			facts.append(guard_fact(w, n, nd, gd, block_name_fn))
	if not doors.is_empty():
		if not first_time:
			lines.pop_front() # Skip reconfirmation when there is work to report.
		var said: String = "; ".join(PackedStringArray(doors))
		lines.append(mind.say(n, "I keep watch over one door each night: %s." % (said[0].to_upper() + said.substr(1))))
		n.max_tier = maxi(n.max_tier, tier)
		return {"lines": lines, "facts": facts}
	return {}


func night_duty_alibi(w, n, nd: int, was_out: bool, _block: String, mind, block_name_fn: Callable) -> Dictionary:
	if not ((n.claim_public or n.max_tier >= 3) and ((n.role == "warden" and was_out) or n.is_evil())):
		return {}
	var guarded: String = warden_door(w, n, nd)
	if guarded != "" and w.by_id.has(guarded):
		var gb: String = w.by_id[guarded].home_block
		return {
			"handled": true,
			"line": mind.say(n, "Standing guard at %s's door, as my gift asks." % w.by_id[guarded].name),
			"fact": guard_fact(w, n, nd, guarded, block_name_fn),
			"vantage": gb,
			"how": "street",
		}
	return {
		"handled": true,
		"line": mind.say(n, "At home all night, same as any honest soul."),
		"fact": mind._alibi_home(n, nd),
		"vantage": n.home_block,
		"how": "window",
	}
