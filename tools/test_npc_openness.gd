## NPCs more open with each other (Nov 5): several items per chat, trusted readings,
## the dead's readings passed on, and told to the town at the meeting.
extends SceneTree
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)
		print("FAIL: " + label)

func _init() -> void:
	_trusted_reading_weight()
	_items_per_chat()
	_dead_reading_relay()
	_late_relay_at_meeting()
	_no_self_agreement()
	print("NPC openness: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(13910, 10)
	return g

func _trusted_reading_weight() -> void:
	var g = _game()
	var s = g.w.living_good()[0]
	var stranger: float = Social._reading_weight(s, 0.5, 0.5)
	var friend: float = Social._reading_weight(s, 0.5, 0.75)
	_check(friend > stranger * 2.5, "a friend gets readings far more readily (%.2f vs %.2f)" % [friend, stranger])
	_check(is_equal_approx(Social._reading_weight(s, 0.5, 0.6) - Social._reading_weight(s, 0.5, 0.59), (0.5 * 1.2 * 2.0) * 0.01), "no trusted extra at or below the pivot")

func _items_per_chat() -> void:
	# Low trust: one item at most from each side; high trust: up to three.
	for bond in [0.4, 0.9]:
		var g = _game()
		var w = g.w
		var a = w.living_good()[0]
		var b = w.living_good()[1]
		a.npc_trust[b.id] = bond
		b.npc_trust[a.id] = bond
		a.traits["gossip"] = 1.0
		a.traits["privacy"] = 0.0
		w.day = 2
		for i in range(4):
			a.beliefs.append({"kind": "saw", "who": w.living()[2 + i].id, "loc": "", "block": "docks", "day": 1, "phase": 3, "how": "window"})
		Social.converse(w, a, b, "test")
		var told: int = w.dlog.entries.filter(func(e): return e["type"] == "npc_share" and e["actor"] == a.id and e["target"] == b.id).size()
		if bond < 0.5:
			_check(told <= 1, "a low-trust chat passes on one thing at most (%d)" % told)
		else:
			_check(told >= 2 and told <= Tuning.Social.SHARE_EXTRA_ITEM_BOND.size(), "a trusting chat can pass on several (%d)" % told)

func _dead_reading_relay() -> void:
	var g = _game()
	var w = g.w
	var goods: Array = w.living_good()
	var s = goods[0]
	var l = goods[1]
	var dead = goods[2]
	var entry = {"day": 0, "role": "seer", "data": {"pair": [goods[3].id, goods[4].id], "yes": true}, "text": "I learned that one of them is the Demon", "true": true}
	# The dead told s privately (old hearsay, not among the latest four).
	s.hearsay = [{"kind": "reading", "entry": entry, "from": dead.id, "about": "", "key": "reading:0:seer", "via": dead.id, "public": false}]
	for i in range(5):
		s.hearsay.append({"kind": "alibi", "about": goods[5].id, "from": goods[5].id, "key": "alibi:x:%d" % i, "public": false, "day": 0, "block": "docks"})
	s.npc_trust[dead.id] = 0.9
	w._kill(dead)
	var found := false
	for i in range(30):
		var item = Social._pick_item(w, s, l)
		if item != null and item.get("late", false):
			found = true
			break
	_check(found, "a dead person's private reading is offered for relay, even when it's old hearsay")

func _late_relay_at_meeting() -> void:
	var g = _game()
	var w = g.w
	var goods: Array = w.living_good()
	var n = goods[0]
	var dead = goods[1]
	var entry = {"day": 0, "role": "seer", "data": {"pair": [goods[2].id, goods[3].id], "yes": false}, "text": "I learned that neither of them is the Demon.", "true": true}
	n.known_claims[dead.id] = {"role": "seer", "readings": [entry], "via": dead.id, "first_claimed_day": 0}
	n.npc_trust[dead.id] = 1.0
	n.traits["privacy"] = 0.0
	dead.claim_public = false
	w._kill(dead)
	var lines: Array = []
	var facts: Array = []
	for i in range(20):
		MindMeeting._late_relay(w, n, lines, facts)
		if not facts.is_empty():
			break
	_check(not facts.is_empty(), "a trusting friend tells the town the dead's reading")
	if facts.is_empty():
		return
	_check(facts[0].get("source", "") == dead.id and facts[0].get("via", "") == n.id, "the card is the dead's reading, via the teller")
	_check("Before" in str(lines[0].get("statement", "")) and dead.name in str(lines[0].get("statement", "")), "the line names the dead")
	_check(not str(lines[0].get("statement", "")).contains(".."), "no doubled full stop")
	var again: Array = []
	MindMeeting._late_relay(w, n, again, [])
	_check(again.is_empty(), "told once")

func _no_self_agreement() -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good()[0]
	var t = w.living_good()[1]
	w.meeting["accusations"] = [{"by": n.id, "target": t.id}]
	n.suspicion[t.id] = 1.2
	n.traits["confidence"] = 1.0
	for i in range(20):
		var r = MindMeeting._public_accusation(w, n)
		if r != null:
			_check(not ("%s" % n.name in str(r.line.get("statement", "")).split(" about ")[0] and "agree" in str(r.line.get("statement", ""))), "no agreeing with yourself: %s" % r.line.get("statement", ""))
			return
