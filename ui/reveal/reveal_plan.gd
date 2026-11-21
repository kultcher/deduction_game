## The grim reveal's plan (stage 1: docs/design/grim_reveal.md section 3.3's timeline fallback).
## Builds, from the finished game's records, the order people are revealed in, each person's
## key moments, fakeouts, and the player's sealed guess against the truth. Reads the world;
## changes nothing. Stage 2 swaps the order for Lantern's event-graph walk; the step shape
## (Herald and Limner's pitch, Nov 21) stays the same.
extends RefCounted

const C = preload("res://sim/content.gd")
const World = preload("res://sim/world.gd")

## Wording: drafts awaiting Michael (Herald, Nov 21).
const LEAD_TIMELINE = "Here is how the town truly stood, one soul at a time."
const LEAD_FINAL_THREE = "It came down to the last three."
const ALIGN_GOOD = "Good"
const ALIGN_EVIL = "Evil"
const GUESS_LINE = "You guessed: %s"
const GUESS_GOOD = "Good"
const GUESS_EVIL = "Evil"
const MOMENT_CLAIM_TRUE = "Claimed to be the %s. True."
const MOMENT_CLAIM_FALSE = "Claimed to be the %s. A lie."
const MOMENT_DENIED_GIFT = "Said they had no gift. A lie."
const MOMENT_POISONED = "Poisoned on the %s. That reading was false."
const MOMENT_POISONED_MANY = "Poisoned on %d nights. Those readings were false."
const MOMENT_POISONED_QUIET = "Poisoned on the %s."
const MOMENT_DELUSIONAL = "Delusional: every reading was a fancy, and they never knew."
const MOMENT_MARKED = "Marked: gifts could read them as evil."
const MOMENT_FABRICATED = "Made up a reading on the %s."
const MOMENT_LIES = "Told %d lies."
const MOMENT_ONE_LIE = "Told one lie."
const MOMENT_KILLED = "Killed by the Demon on the %s."
const MOMENT_HANGED = "Hanged on the %s."
const MOMENT_MARTYR = "Died at the gallows in another's place on the %s."
const MOMENT_TURNED = "Turned evil by the Revenant's curse on the %s."

## Fakeouts (the pitch's Q4): eligible people, a chance tied to how strong the false belief
## was, at most two a reveal, never the first person, never two in a row.
const FAKE_MAX = 2
const FAKE_CHANCE_CLAIMED = 0.5     ## an evil person who claimed a gift
const FAKE_CHANCE_HANGED = 0.35     ## a good person the town hanged as evil
const FAKE_CHANCE_FINALE = 0.75     ## the last person of a final-three game
const MAX_MOMENTS = 2


## The whole plan: {"lead": {...}, "steps": [step...], "final_three": bool}.
## `verdict` maps person id to the player's sealed guess ("?", "good", "evil" or a role).
static func build(g, verdict: Dictionary) -> Dictionary:
	var w = g.w
	var order: Array = reveal_order(w)
	var final_three: bool = is_final_three(w)
	var steps: Array = []
	for id in order:
		steps.append(step_for(g, w.by_id[id], verdict))
	_place_fakeouts(w, steps, final_three)
	return {"lead": {"kind": "final_three" if final_three else "timeline",
			"text": LEAD_FINAL_THREE if final_three else LEAD_TIMELINE},
		"steps": steps, "final_three": final_three}


## Deaths and hangings in the order they happened, then the living in cast order, the Demon
## last. In a final-three game the last hanging goes last instead, since it decides the game.
static func reveal_order(w) -> Array:
	var order: Array = []
	for e in w.dlog.entries:
		if e["type"] in ["kill", "execution"] and w.by_id.has(e["target"]) and not (e["target"] in order):
			order.append(e["target"])
	for n in w.npcs:
		if not (n.id in order) and not n.alive:
			order.append(n.id)
	for n in w.npcs:
		if not (n.id in order):
			order.append(n.id)
	var last: String = last_hanged(w) if is_final_three(w) else ""
	var demons: Array = order.filter(func(id): return C.is_demon(w.by_id[id].role) and id != last)
	for id in demons:
		order.erase(id)
		order.append(id)
	if last != "":
		order.erase(last)
		order.append(last)
	return order


static func last_hanged(w) -> String:
	var last: String = ""
	for e in w.dlog.entries:
		if e["type"] == "execution":
			last = str(e["target"])
	return last


## A final-three game: it ended on a hanging with three or fewer alive before it.
static func is_final_three(w) -> bool:
	var last: String = last_hanged(w)
	if last == "" or not w.game_over:
		return false
	var n = w.by_id[last]
	return n.death_day == w.day and w.living().size() + 1 <= 3


## One person's step, in the shape Limner's RevealCard plays (ui/reveal/reveal_card.gd), plus
## the key-moment lines the overlay shows beneath it.
static func step_for(g, n, verdict: Dictionary) -> Dictionary:
	var w = g.w
	var sc = w.case_script
	var roles: Array = (sc.town + sc.minions + sc.demons) if sc != null else [n.role]
	if not (n.role in roles):
		roles.append(n.role)
	var guess: String = str(verdict.get(n.id, "?"))
	var step: Dictionary = {"npc": n.id, "name": n.name, "roles": roles, "role": n.role, "evil": n.is_evil(),
		"dead": not n.alive, "burden": C.secret_name(n.secret_mod) if n.secret_mod != "" else "",
		"fakeout_role": "", "align_text": ALIGN_EVIL if n.is_evil() else ALIGN_GOOD,
		"role_text": "Scion (promoted to Demon)" if n.id == w.scion_rose else C.role_name(n.role),
		"moments": key_moments(g, n)}
	if guess != "?" and guess != "":
		step["guess"] = GUESS_LINE % guess_text(guess)
		step["guess_correct"] = guess_correct(guess, n)
	else:
		step["guess"] = ""
	return step


static func guess_text(guess: String) -> String:
	if guess == "good":
		return GUESS_GOOD
	if guess == "evil":
		return GUESS_EVIL
	return C.role_name(guess)


## A role guess is right on the exact role; "good" or "evil" on the alignment. A Demon guess
## on a Scion promoted to Demon counts, as the role it ended as.
static func guess_correct(guess: String, n) -> bool:
	if guess == "good":
		return not n.is_evil()
	if guess == "evil":
		return n.is_evil()
	return guess == n.role


## Up to two key moments, the most telling first: what was false (a poisoning, a Delusional or
## Marked gift, a made-up reading, a lie about their gift), then a true claim, then how they died.
static func key_moments(g, n) -> Array:
	var w = g.w
	var out: Array = []
	var poisoned: Array = []
	var false_nights: Dictionary = {}
	var fabricated: int = -1
	var lies: int = 0
	for e in w.dlog.entries:
		if e["type"] == "poison" and e["target"] == n.id:
			poisoned.append(int(e["day"]))
		elif e["type"] == "info" and e["actor"] == n.id and not e["data"].get("true", true):
			false_nights[int(e["day"])] = true
		elif e["type"] == "fake_info" and e["actor"] == n.id and fabricated < 0:
			fabricated = int(e["day"])
		elif e["type"] == "think" and e["actor"] == n.id and e["data"].get("topic", "") == "lie":
			lies += 1
	# A poisoning matters most when it made a reading false; a night with no reading is a footnote.
	var misled: Array = poisoned.filter(func(k): return false_nights.has(k))
	var quiet: Array = poisoned.filter(func(k): return not false_nights.has(k))
	if n.turned or n.turned_day >= 0:
		out.append(MOMENT_TURNED % _day(n.turned_day))
	if n.secret_mod == "delusional":
		out.append(MOMENT_DELUSIONAL)
	if misled.size() == 1:
		out.append(MOMENT_POISONED % _night(misled[0]))
	elif misled.size() > 1:
		out.append(MOMENT_POISONED_MANY % misled.size())
	var told: bool = n.claim_public or n.max_tier >= 3
	if told and n.claimed_role == "none":
		out.append(MOMENT_DENIED_GIFT)   # everyone holds a role, so "no gift" is never true
	elif told and n.claimed_role != "" and n.claimed_role != "none" and n.claimed_role != n.role:
		out.append(MOMENT_CLAIM_FALSE % C.role_name(n.claimed_role))
	if fabricated >= 0:
		out.append(MOMENT_FABRICATED % _night(fabricated))
	if n.secret_mod == "marked":
		out.append(MOMENT_MARKED)
	if lies > 0 and out.size() < MAX_MOMENTS and n.is_evil():
		out.append(MOMENT_ONE_LIE if lies == 1 else MOMENT_LIES % lies)
	if told and n.claimed_role == n.role and out.size() < MAX_MOMENTS:
		out.append(MOMENT_CLAIM_TRUE % C.role_name(n.role))
	if quiet.size() > 0 and misled.is_empty() and out.size() < MAX_MOMENTS:
		out.append(MOMENT_POISONED_QUIET % _night(quiet[0]))
	if not n.alive and out.size() < MAX_MOMENTS:
		match n.death_cause:
			"demon":
				out.append(MOMENT_KILLED % _night(n.death_day))
			"martyr":
				# The Martyr dies in the nominee's place; nobody was hanged (Codex on #499).
				out.append(MOMENT_MARTYR % _day(n.death_day))
			_:
				out.append(MOMENT_HANGED % _day(n.death_day))
	return out.slice(0, MAX_MOMENTS)


## "first night" for "on the first night"; night 0 is the night before the player arrived.
static func _night(k: int) -> String:
	if k == 0:
		return "night before you arrived"
	return ("%s night" % C.ORDINALS[k - 1]) if k >= 1 and k <= C.ORDINALS.size() else "night %d" % k

static func _day(k: int) -> String:
	return ("%s day" % C.ORDINALS[k - 1]) if k >= 1 and k <= C.ORDINALS.size() else "day %d" % k


## Fakeouts, rolled on their own generator (seeded from the case), never the world's.
static func _place_fakeouts(w, steps: Array, final_three: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("grim_reveal:%d" % int(w.seed_value))
	var placed: int = 0
	var prev: bool = false
	var minions: Array = w.case_script.minions if w.case_script != null else []
	for i in range(steps.size()):
		var s: Dictionary = steps[i]
		var n = w.by_id[s.npc]
		var fake: String = ""
		var chance: float = 0.0
		if n.is_evil() and n.claimed_role != "" and n.claimed_role != "none" and n.claimed_role != n.role and (n.claim_public or n.max_tier >= 3):
			fake = n.claimed_role
			chance = FAKE_CHANCE_CLAIMED
		elif not n.is_evil() and n.death_cause == "executed" and not minions.is_empty():
			fake = minions[rng.randi() % minions.size()]
			chance = FAKE_CHANCE_HANGED
		if fake == "":
			prev = false
			continue
		if final_three and i == steps.size() - 1:
			chance = FAKE_CHANCE_FINALE
		var roll: float = rng.randf()
		if i == 0 or prev or placed >= FAKE_MAX or roll >= chance:
			prev = false
			continue
		s["fakeout_role"] = fake
		placed += 1
		prev = true
