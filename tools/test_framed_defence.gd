## A good defender sighted on a night they spent at home (evil's frame) gives their account
## of that night, and never "I was out because I'm the <gift>" or a secret confessed to explain
## an outing that didn't happen. Playtest 30987 (Nov 11): the good Medium Dorian, framed by
## Merrin's fake Chapel Hill sighting, said "I was only out at night because I'm the Medium!"
## and then, pressed, "I was at home all last night".
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const C = preload("res://sim/content.gd")
var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	for size in [7, 10]:
		_case(size, "medium", {}, false)
		_case(size, "medium", {}, true)
		_case(size, "clerk", {"kind": "lover", "text": "was meeting someone", "me": "was meeting someone"}, false)
		_case(size, "clerk", {"kind": "lover", "text": "was meeting someone", "me": "was meeting someone"}, true)
	print("Framed defence: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(size: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7350, size)
	g.w.day = 4
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener == null:
				continue
			listener.info_log = []
			listener.ledger = {}
			listener.beliefs = []
			listener.known_claims = {}
			listener.cleared = {}
			for id in listener.suspicion:
				listener.suspicion[id] = 0.1
	return g

## `role`: a night-walking gift (Medium) or not (Clerk, with a secret that could explain an
## outing). `was_out`: true = an honest sighting (they explain it as before), false = a frame.
func _case(size: int, role: String, secret: Dictionary, was_out: bool) -> void:
	var g = _game(size)
	var w = g.w
	var goods: Array = w.living_good()
	var d = goods[0]
	var accuser = goods[1]
	d.role = role
	d.claimed_role = role
	d.claim_public = true
	d.secret = secret.duplicate()
	d.secret_mod = ""
	d.secret_known = false
	d.history[w.time_key(1, C.NIGHT)] = "night:hill" if was_out else "home:" + d.home_block
	var spoken: Array = [{"kind": "sighting", "source": accuser.id, "subject": [d.id], "block": "hill", "day": 1, "phase": C.NIGHT}]
	var items: Array = MindMeeting._disclosed_items_against(w, d, accuser, spoken)
	var out_items: Array = items.filter(func(x): return x.get("channel", "") == "movement_out")
	var label: String = "%d NPCs, %s%s, %s:" % [size, role, " with a secret" if not secret.is_empty() else "", "really out" if was_out else "framed (home)"]
	check(not out_items.is_empty(), label + " the spoken sighting reaches the defence")
	check(MindMeeting.framed_night_of(w, d, out_items) == (-1 if was_out else 1), label + " framed_night_of names night 1 only for a frame")
	# Force the reveal and confession decisions to go ahead, so only the frame check can stop them.
	d.traits.privacy = 0.0
	var res: Dictionary = Mind.defend_self(w, d, accuser.id, spoken)
	var text: String = " ".join(PackedStringArray(res.lines.map(func(l): return str(l.get("text", "")))))
	if was_out:
		check(not "dispute_night" in res.moves, label + " no night account offered for a real outing")
	else:
		check(not "reveal" in res.moves and not "secret" in res.moves, label + " no outing explained (%s)" % [res.moves])
		check("dispute_night" in res.moves, label + " gives their account of night 1")
		check(res.facts.any(func(f): return f.get("kind", "") == "alibi" and f.get("home", false) and int(f.get("day", -1)) == 1), label + " the account is a home alibi for night 1")
		check(not ("I was out" in text or "only out at night" in text), label + " never says they were out: " + text)
	# The evil bluffer keeps every option: their outing story is a lie either way.
	var e = w.npcs.filter(func(n): return n.is_evil())[0]
	e.history[w.time_key(1, C.NIGHT)] = "home:" + e.home_block
	var e_items: Array = MindMeeting._disclosed_items_against(w, e, accuser, [{"kind": "sighting", "source": accuser.id, "subject": [e.id], "block": "hill", "day": 1, "phase": C.NIGHT}])
	check(MindMeeting.framed_night_of(w, e, e_items.filter(func(x): return x.get("channel", "") == "movement_out")) == -1, label + " evil defenders are never treated as framed")
