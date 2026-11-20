## Private sharing grows over the days (Michael, Nov 19): each day past day 1, an NPC who
## hasn't claimed a gift publicly brings up its gift and its own readings more often in
## private talk with another NPC (`Social._pick_item`, `Tuning.Social.SHARE_UNCLAIMED_DAY_BOOST`).
##   - day 1: no boost;
##   - day 3: the gift topic's and the readings' weights are 1 + 2 x boost times day 1's;
##   - an NPC who has claimed publicly gets no boost on its readings;
##   - evil's bluffed gift and fake readings get the same boost (Seneschal's call, Nov 19).
extends SceneTree

const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const Feed = preload("res://sim/decision_feed.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_cases()
	print("Private share boost: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.00001


## The weights `s` gives each candidate when talking to `l` today (from the decision feed).
func _weights(w, f, s, l) -> Dictionary:
	var state = w.rng.state
	f.clear()
	Social._pick_item(w, s, l)
	w.rng.state = state
	for r in f.records:
		if str(r.get("kind", "")) == "npc_share":
			return r.get("details", {}).get("weights", {})
	return {}


func _first_key(wts: Dictionary, prefix: String) -> String:
	for k in wts:
		if str(k).begins_with(prefix) and float(wts[k]) > 0.0:
			return str(k)
	return ""


## Quiet everything else `s` might say, so only its gift and its readings are drawn.
func _prime(s, l, reading: Dictionary) -> void:
	s.npc_trust[l.id] = 0.7
	s.traits["privacy"] = 0.3
	s.traits["gossip"] = 0.0
	s.claim_public = false
	s.protect_lock = false
	s.pressure = 0.0
	s.info_log = [reading]
	s.secret = {}
	s.hearsay = []
	s.player_cases = []
	s.beliefs = []
	s.told_to = {}
	l.known_claims = {}


func _cases() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7301, 10)
	var w = g.w
	var f = Feed.new()
	f.enabled = true
	w.attach_decision_feed(f)
	var boost: float = 1.0 + 2.0 * Tuning.Social.SHARE_UNCLAIMED_DAY_BOOST

	# A good NPC with a reading to share.
	var goods: Array = w.living_good()
	var s = null
	var reading: Dictionary = {}
	for n in goods:
		for e in n.info_log:
			s = n
			reading = e.duplicate(true)
			break
		if s != null:
			break
	if s == null:
		_check(false, "a good NPC with a night-0 reading in this deal")
		return
	var l = goods[0] if goods[0] != s else goods[1]
	reading["shared"] = false
	_prime(s, l, reading)
	w.day = 1
	var w1: Dictionary = _weights(w, f, s, l)
	var rk: String = _first_key(w1, "reading:")
	var tk: String = "gift_topic:" + s.id
	_check(rk != "" and w1.has(tk), "day 1: the reading and the gift topic are both drawn (%s)" % str(w1.keys()))
	w.day = 3
	var w3: Dictionary = _weights(w, f, s, l)
	_check(float(w1.get(rk, 0.0)) > 0.0 and _near(float(w3.get(rk, 0.0)), float(w1.get(rk, 0.0)) * boost), "day 3: the reading's weight is boosted (%.3f -> %.3f)" % [float(w1.get(rk, 0.0)), float(w3.get(rk, 0.0))])
	_check(float(w1.get(tk, 0.0)) > 0.0 and _near(float(w3.get(tk, 0.0)), float(w1.get(tk, 0.0)) * boost), "day 3: the gift topic's weight is boosted (%.3f -> %.3f)" % [float(w1.get(tk, 0.0)), float(w3.get(tk, 0.0))])
	_check(float(w1.get("nothing", 0.0)) > 0.0 and _near(float(w3.get("nothing", 0.0)), float(w1.get("nothing", 0.0))), "the weather's weight is unchanged")
	# Claimed publicly: no boost, and no gift topic.
	s.claim_public = true
	var wc: Dictionary = _weights(w, f, s, l)
	_check(rk != "" and _near(float(wc.get(rk, 0.0)), float(w1.get(rk, 0.0))) and not wc.has(tk), "claimed publicly: no boost on its readings, and no gift topic")

	# Evil: the bluffed gift and a fake reading get the same boost.
	var e = null
	for n in w.evil_team():
		if Social._my_role(w, n) != "":
			e = n
			break
	if e == null:
		_check(false, "an evil NPC with a bluff in this deal")
		return
	var fake: Dictionary = reading.duplicate(true)
	fake["fake"] = true
	fake["shared"] = false
	var el = goods[0] if goods[0] != s else goods[1]
	_prime(e, el, fake)
	w.day = 1
	var e1: Dictionary = _weights(w, f, e, el)
	var erk: String = _first_key(e1, "reading:")
	var etk: String = "gift_topic:" + e.id
	w.day = 3
	var e3: Dictionary = _weights(w, f, e, el)
	_check(erk != "" and _near(float(e3.get(erk, 0.0)), float(e1.get(erk, 0.0)) * boost), "evil: a fake reading is boosted the same (%.3f -> %.3f)" % [float(e1.get(erk, 0.0)), float(e3.get(erk, 0.0))])
	_check(float(e1.get(etk, 0.0)) > 0.0 and _near(float(e3.get(etk, 0.0)), float(e1.get(etk, 0.0)) * boost), "evil: the bluffed gift topic is boosted the same")
