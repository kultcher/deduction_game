## Sexton role definition and simulation hooks.
##
## Shape: NIGHT_EVENT (once per case on Night 1 or later, may toll the church bell
## at the start of night: performs a Lamplighter walk through all blocks and completely
## suppresses all minion powers until the next night begins). Silent announcement,
## but claimable in dialogue.
extends "res://sim/role_def.gd"


func _init() -> void:
	id = "sexton"
	display_name = "Sexton"
	align = "good"
	kind = "protect"
	tags = ["protection"]  # not a night_walker for the deal's band: it walks once per case, on the toll night
	night_walk = false # only walks on the night the bell is tolled
	desc = "Once per case (not night 0), at the start of night, may toll the church bell and walk through every parish: all minion abilities are suppressed until the next night."
	shape = "NIGHT_EVENT"
	evening_or_night = true
	min_gift_day = 1


func gift_live_tonight(_w, _n) -> bool:
	return false


func try_toll(w, sx, mind) -> bool:
	if sx == null or sx.is_evil() or sx.gift_used or w.day < 1:
		return false
	var few_left: float = Tuning.Roles.SEXTON.toll_few_left if w.living().size() <= 4 else 0.0
	var dead_cnt: float = Tuning.Roles.SEXTON.toll_per_dead * w.npcs.filter(func(m): return not m.alive).size()
	var has_exec_today: float = 0.35 if w.executed_today != "" else 0.0
	var toll: bool = mind.decide(w, sx, "sexton_toll", {
		"few_left": few_left,
		"deaths": dead_cnt,
		"executed_today": has_exec_today,
		"base": -0.2,
	}, "Toll the church bell tonight to suppress all minions?")
	if not toll:
		return false
	sx.gift_used = true
	w.sexton_tolled_night = w.day
	# The walk itself happens in World._night_movement (which resets the night's walkers),
	# on any toll night, whether or not a broken gift makes the bell work.
	if sx.gift_broken():
		w.dlog.add("sexton_toll", sx.id, "", {"works": false}, "%s tolls the church bell, but their gift is broken: minions are not suppressed." % sx.name)
		return false
	w.sexton_suppression_night = w.day
	w.dlog.add("sexton_toll", sx.id, "", {"works": true}, "%s tolls the church bell: all minion abilities are suppressed until next night." % sx.name)
	# No time in the text: whoever speaks it adds when (C.spoken_when), relative to the day.
	w._add_info(sx, {"data": {"night": w.day}, "true": true, "text": "I tolled the church bell"})
	return true


# ------------------------------------------------------------ telling of the toll
# The toll is not public knowledge. The Sexton keeps it to themself while the bell holds
# (the toll night and the day after), and is open about it from the morning after that.
# Under pressure (pressed with a sighting, nominated, called to the podium) they tell early.

## True once the toll night's suppression has run its course (from the morning of the
## second day after the toll).
static func toll_window_over(w) -> bool:
	return w.sexton_tolled_night >= 0 and w.day >= w.sexton_tolled_night + 2


func _tolled_on(w, n, nd: int) -> bool:
	return n != null and n.role == "sexton" and not n.is_evil() and n.gift_used and nd == w.sexton_tolled_night


## Asked where they were on a night they were out: "reveal" (tell of the toll and the
## gift), "withhold" (refuse to say; never a lie) or "" (not this role's business).
func honest_outing(w, n, nd: int, mind, public: bool) -> String:
	if not _tolled_on(w, n, nd):
		return ""
	if toll_window_over(w) or n.claimed_role == "sexton":
		return "reveal"
	var T: Dictionary = Tuning.Roles.SEXTON
	var parts: Dictionary = {"base": T.reveal_early_base, "pressure": n.pressure * T.reveal_early_pressure}
	if n.id in w.meeting.get("nominated", []) or str(w.meeting.get("block", "")) == n.id:
		parts["nominated"] = T.reveal_early_nominated
	if public:
		parts["podium"] = T.reveal_early_podium
	else:
		parts["trust"] = (n.trust - 0.5) * T.reveal_early_trust
	var tell: bool = mind.decide(w, n, "sexton_reveal_early", parts,
		"Asked about the toll night while the bell still holds: tell of the toll now?")
	return "reveal" if tell else "withhold"


func uses_night_duty_alibi(w, n, nd: int, was_out: bool) -> bool:
	return was_out and _tolled_on(w, n, nd) and n.claimed_role == "sexton"


func night_duty_alibi(w, n, nd: int, was_out: bool, block: String, mind, block_name_fn: Callable) -> Dictionary:
	if not uses_night_duty_alibi(w, n, nd, was_out):
		return {}
	var C = content()
	var when: String = C.spoken_when(nd, w.day)
	return {
		"handled": true,
		"line": mind.say_voiced(n, "duty_sexton", "I was out %s. I tolled the church bell and walked every parish after it." % when, {"when": when}),
		"fact": {
			"kind": "sighting",
			"subject": [n.id],
			"block": block,
			"day": nd,
			"phase": 3,
			"source": n.id,
			"duty_claim": true,
			"duty": "sexton",
			"text": "%s says they tolled the church bell on night %d and walked every parish (they were out)." % [n.name, nd],
		},
		"vantage": block,
		"how": "street",
	}


func pressed_night_line(_w, _n, _fact: Dictionary, _night: int, when: String, alternate: bool, _block_name_fn: Callable) -> String:
	return ("The bell still accounts for my being out %s." if alternate else "I was out tolling the bell %s. That hasn't changed.") % when


func pressed_night_slots(_w, _n, _fact: Dictionary, _night: int, when: String, _block_name_fn: Callable) -> Dictionary:
	return {"when": when}


## At the meeting: keep quiet while the bell holds, be open once it has worn off.
func score_public_claim(w, n, parts: Dictionary) -> void:
	super.score_public_claim(w, n, parts)
	if n.role != "sexton" or n.is_evil() or not n.gift_used or w.sexton_tolled_night < 0:
		return
	if toll_window_over(w):
		parts["toll_over"] = Tuning.Roles.SEXTON.claim_after_toll
	else:
		parts["toll_wait"] = -Tuning.Roles.SEXTON.claim_wait


## Going public, the Sexton tells of the toll. Evil now believes the bell rang that night
## (whether or not a broken gift made it work), and plays the suppression accordingly.
func on_public_claim(w, n, lines: Array, facts: Array, mind) -> void:
	_tell_toll(w, n, lines, facts, mind)


## Already out as the Sexton when the bell was tolled: tell of it once it has worn off
## (the same timing as going public after a toll). Codex review of PR #69.
func may_share_reading(w, n, _entry: Dictionary) -> bool:
	return n.is_evil() or n.dialogue_memory.get("toll_told_public", false) or toll_window_over(w)


func on_public_update(w, n, lines: Array, facts: Array, mind) -> void:
	if toll_window_over(w):
		_tell_toll(w, n, lines, facts, mind)


func on_public_duty_account(w, n, nd: int) -> void:
	if _tolled_on(w, n, nd):
		w.evil_plan["bell_believed"] = w.sexton_tolled_night
		n.dialogue_memory["toll_told_public"] = true


func _tell_toll(w, n, lines: Array, facts: Array, mind) -> void:
	if n.role != "sexton" or n.is_evil() or not n.gift_used or w.sexton_tolled_night < 0:
		return
	w.evil_plan["bell_believed"] = w.sexton_tolled_night
	if n.dialogue_memory.get("toll_told_public", false):
		return
	n.dialogue_memory["toll_told_public"] = true
	var nd: int = w.sexton_tolled_night
	var C = content()
	var when: String = C.spoken_when(nd, w.day)
	lines.append(mind.say_voiced(n, "sexton_toll_public", "I tolled the church bell %s. No minion's work held from then until the next nightfall." % when, {"when": when}))
	var where: String = n.history.get(w.time_key(nd, C.NIGHT), "home:" + n.home_block)
	facts.append({"kind": "sighting", "subject": [n.id], "block": where.substr(where.find(":") + 1), "day": nd, "phase": 3,
		"source": n.id, "duty_claim": true, "duty": "sexton", "public": true,
		"text": "%s says they tolled the church bell on night %d: minion powers suppressed until the next night." % [n.name, nd]})
