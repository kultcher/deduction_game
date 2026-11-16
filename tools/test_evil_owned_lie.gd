## An evil walker's owned lie follows its disclosure (BACKLOG section 1, from 54875).
## A good walker caught out by a sighting reveals its gift and owns the earlier "home"
## story. Evil with a planned walking bluff does the same, so neither the reveal nor the
## owned-lie line is a tell; nights its bluffed duty wouldn't cover keep the old story.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)
		print("FAIL: " + label)

func _init() -> void:
	for bluff in ["warden", "lamplighter", "confessor"]:
		_pressed_backs_into_bluff(bluff)
	_nightwatch_owns_only_watched_nights()
	_non_walking_bluff_keeps_cover()
	_good_walker_unchanged()
	print("Evil owned lie: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(seed_v: int = 54875, size: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, size)
	return g

func _joined(r: Dictionary) -> String:
	return " ".join(PackedStringArray(r.get("lines", []).map(func(l): return str(l.get("statement", l.get("text", ""))) if l is Dictionary else str(l))))

## Evil, out on night 1 for its own work, with a planned walking bluff not yet named.
func _setup(g, bluff: String):
	var w = g.w
	var n = w.minion()
	w.day = 2
	w.night_walkers = []
	w.evil_plan.bluffs[n.id] = bluff
	n.claimed_role = ""
	n.claim_public = false
	n.max_tier = 0
	n.secret = {}
	n.secret_mod = ""
	n.traits.privacy = 1.0
	n.trust = 0.1
	n.lied_nights = []
	n.history[w.time_key(1, C.NIGHT)] = "night:market"
	return n

func _sighting(n, nd: int = 1) -> Dictionary:
	return {"kind": "sighting", "subject": [n.id], "source": "player", "block": "market", "day": nd, "phase": C.NIGHT, "text": "The player's vigil caught them out"}

func _pressed_backs_into_bluff(bluff: String) -> void:
	var g = _game()
	var n = _setup(g, bluff)
	# They told the player they were home that night.
	n.dialogue_memory["night_accounts"] = {"1": {"kind": "alibi", "home": true, "source": n.id}}
	n.lied_nights = [1]
	var reply = Mind.press(g.w, n, _sighting(n))
	var said: String = _joined(reply)
	_check(n.claimed_role == bluff and n.max_tier >= 3 and reply.facts.any(func(f): return f.kind == "claim" and f.role == bluff),
		"%s bluff: caught out, evil names its planned walking bluff (%s)" % [bluff, said])
	_check("whatever I told you" in said, "%s bluff: the reveal owns the earlier home story (%s)" % [bluff, said])
	_check(n.lied_nights.is_empty(), "%s bluff: owned nights are cleared" % bluff)
	_check(not reply.facts.any(func(f): return f.kind == "alibi" and f.get("home", false)), "%s bluff: no fresh home account" % bluff)
	# Asked again, the duty story stands: no "home" for that night.
	var again = MindDialogue.answer_night(g.w, n, 1)
	_check(not again.facts.any(func(f): return f.kind == "alibi" and f.get("home", false)), "%s bluff: asked again, tells the duty, not home (%s)" % [bluff, _joined(again)])

## A Night Watch bluff's duty covers only the nights it made a watch report for.
func _nightwatch_owns_only_watched_nights() -> void:
	var g = _game()
	var w = g.w
	var n = _setup(g, "nightwatch")
	n.history[w.time_key(0, C.NIGHT)] = "night:docks"
	w.evil_plan.fake_watch = {"1": "market"}
	n.dialogue_memory["night_accounts"] = {"0": {"kind": "alibi", "home": true, "source": n.id}, "1": {"kind": "alibi", "home": true, "source": n.id}}
	n.lied_nights = [0, 1]
	var r = MindDialogue.answer_gift(w, n, 3)
	var said: String = _joined(r)
	_check(n.claimed_role == "nightwatch", "Night Watch bluff named")
	_check("whatever I told you" in said and C.spoken_when(1, w.day) in said, "owns the watched night (%s)" % said)
	_check(not (C.spoken_when(0, w.day) in said), "doesn't own an unwatched night (%s)" % said)
	_check(n.lied_nights == [0], "the unwatched night keeps its story (%s)" % str(n.lied_nights))
	# Pressed on the unwatched night before naming anything, it doesn't back into the bluff.
	var g2 = _game()
	var n2 = _setup(g2, "nightwatch")
	g2.w.evil_plan.fake_watch = {}
	_check(not MindDialogue._bluff_outing(g2.w, n2, 1), "no watch report that night: no gift outing to back into")

func _non_walking_bluff_keeps_cover() -> void:
	var g = _game()
	var n = _setup(g, "seer")
	_check(not MindDialogue._bluff_outing(g.w, n, 1), "a Seer bluff doesn't explain a night out")
	n.lied_nights = [1]
	n.dialogue_memory["night_accounts"] = {"1": {"kind": "alibi", "home": true, "source": n.id}}
	var r = MindDialogue.answer_gift(g.w, n, 3)
	_check(not ("whatever I told you" in _joined(r)), "naming a non-walking bluff owns nothing")
	_check(n.lied_nights == [1], "the lie stays on record")

func _good_walker_unchanged() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	g.w.day = 2
	g.w.night_walkers = []
	n.role = "warden"
	n.claimed_role = ""
	n.claim_public = false
	n.max_tier = 0
	n.secret = {}
	n.secret_mod = ""
	n.lied_nights = [1]
	n.history[g.w.time_key(1, C.NIGHT)] = "night:market"
	n.dialogue_memory["night_accounts"] = {"1": {"kind": "alibi"}}
	_check(not MindDialogue._bluff_outing(g.w, n, 1), "a good NPC never takes the evil path")
	var reply = Mind.press(g.w, n, _sighting(n))
	_check(n.claimed_role == "warden" and "whatever I told you" in _joined(reply) and n.lied_nights.is_empty(), "good walker: reveal and owned lie as before")
