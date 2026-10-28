## Regressions from cases 61251 and 25923.
## godot --headless --path . --script res://tools/test_playtest_regressions.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Argue = preload("res://sim/argue.gd")
const Recent = preload("res://game/recent_sightings.gd")
const C = preload("res://sim/content.gd")
var fails = 0

func _init() -> void:
	_support_self()
	_whereabouts()
	_secrets()
	_watch_disclosure()
	_public_sighting()
	_survival()
	_own_role()
	_meeting_sighting_prefix_and_gallows()
	_public_hearsay_and_self_gossip()
	_approach_ui_visibility()
	_workshop_merge_order_of_operations()
	print("PLAYTEST REGRESSION FAILURES: %d" % fails)
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(25923, 10)
	return g

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _support_self() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	var num = g.add_card({"kind": "claim", "subject": [n.id], "source": n.id, "role": n.role, "text": "A gift claim."})
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 3
	var before: float = n.trust
	var pressure: float = n.pressure
	g.command("present %d for %s" % [num, n.id])
	_check(n.trust > before and n.pressure == pressure, "supporting the listener's claim builds rapport without pressing them")
	before = n.trust
	g.command("present %d for %s" % [num, n.id])
	_check(n.trust == before, "repeated support cannot farm trust")
	_check(g._route_present(n, "%d against %s" % [num, n.id])["verb"] == "press", "speaking against the listener still challenges them")
	var deduction = g.add_card({"kind": "deduction", "subject": [n.id], "source": "player", "conclusion": {"type": "notdemon", "a": n.id}, "text": "I believe they are not the Demon."})
	_check(g._route_present(n, "%d for %s" % [deduction, n.id])["verb"] == "defend", "explicit support with a deduction is also routed as a defence")
	before = n.trust
	g.command("present %d for %s" % [deduction, n.id])
	_check(n.trust > before, "supportive deductions about the listener can build rapport")

func _whereabouts() -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good()[0]
	w.day = 2
	n.history[w.time_key(1, C.EVENING)] = "wharf"
	n.traits["gossip"] = 0.0
	n.pressure = 0.0
	var r = Mind.answer_today(w, n, "yesterday evening")
	var own: Array = r["facts"].filter(func(c): return c.get("self_report", false))
	_check(own.size() == 1 and own[0]["subject"] == [n.id] and own[0]["source"] == n.id and own[0]["block"] == "docks", "a reticent speaker's stated whereabouts still produce attributed evidence")
	var a = g.add_card(own[0])
	var b = g.add_card({"kind": "trace", "block": "docks", "day": 1, "source": "evidence", "text": "Docks trace."})
	_check(Argue.check(w, [g.board[a - 1], g.board[b - 1]])["matches"].any(func(m): return m["template"] == "trace_match"), "the speaker's evening account can be linked to a trace")

func _secrets() -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good()[0]
	var other = w.living_good()[1]
	w.day = 2
	n.secret = {"kind": "lover", "with": other.id, "text": "slips out to meet a lover", "me": "slip out to meet a lover"}
	n.history[w.time_key(1, C.NIGHT)] = "night:hill"
	n.claimed_role = ""
	n.trust = 1.0
	n.traits["privacy"] = 0.0
	n.pressure = 3.0
	var r = Mind.answer_night(w, n, 1)
	var secrets: Array = r["facts"].filter(func(c): return c["kind"] == "secret")
	_check(secrets.size() == 1 and secrets[0].get("mod", "") == "lovers", "a Lover's confession records the disclosed secret type")
	if secrets.is_empty():
		return
	var a = g.add_card(secrets[0])
	var b = g.add_card({"kind": "sighting", "subject": [n.id], "source": "player", "day": 1, "phase": C.NIGHT, "block": "hill", "text": "Seen out."})
	var matches: Array = Argue.check(w, [g.board[a - 1], g.board[b - 1]])["matches"]
	_check(matches.any(func(m): return m["template"] == "secret_explains_movement"), "a confession provides a possible defence of night movement")
	_check(not Argue.assertions(g.board[a - 1]).any(func(s): return s["t"] == "proven_good"), "a confession is not a proven alignment")
	var marked = {"n": 999, "kind": "secret", "subject": [n.id], "owner": n.id, "source": n.id, "mod": "marked"}
	var read = {"n": 1000, "kind": "info", "subject": [n.id, other.id], "source": other.id, "role": "seer", "day": 1, "data": {"pair": [n.id, other.id], "yes": true}}
	_check(Argue.check(w, [marked, read])["matches"].any(func(m): return m["template"] == "marked_explains_reading"), "a reported Marked secret can explain an evil ping without proving innocence")
	read["role"] = "nightwatch"
	read["data"] = {"block": "hill", "seen": [n.id]}
	_check(not Argue.check(w, [marked, read])["matches"].any(func(m): return m["template"] == "marked_explains_reading"), "Marked does not excuse a Night Watch's physical sighting")

func _watch_disclosure() -> void:
	var g = _game()
	var w = g.w
	var n = w.by_id["isolde"]
	var target = w.living_good()[0]
	w.day = 3
	w.phase = C.MORNING
	n.claimed_role = "nightwatch"
	w.evil_plan["bluffs"][n.id] = "nightwatch"
	n.max_tier = 3
	n.trust = 0.1
	n.traits["privacy"] = 1.0
	n.traits["gossip"] = 1.0
	n.info_log = [{"day": 1, "role": "nightwatch", "data": {"block": "hill", "seen": []}, "fake": true, "shared": true, "text": "I watched Chapel Hill: nobody stirred"},
		{"day": 2, "role": "nightwatch", "data": {"block": "hill", "seen": [target.id]}, "fake": true, "shared": false, "text": "I watched Chapel Hill"}]
	n.told_readings = 1
	w.evil_plan["fake_watch"]["2"] = "hill"
	Mind.answer_gift(w, n, 3)
	var r = Mind.answer_night(w, n, 2)
	_check(not r["facts"].any(func(c): return target.id in c.get("subject", [])), "asking whereabouts cannot bypass a withheld Night Watch reading")
	_check(Recent._night_candidates(w, n, target, []).is_empty(), "a person-specific follow-up cannot bypass the same withheld reading")
	n.info_log[1]["shared"] = true
	r = Mind.answer_night(w, n, 2)
	_check(r["facts"].any(func(c): return target.id in c.get("subject", [])), "an already public watch report can still be repeated")

func _public_sighting() -> void:
	var g = _game()
	var w = g.w
	var n = w.by_id["isolde"]
	var target = w.by_id["merrin"]
	var b = {"kind": "saw", "who": target.id, "day": 1, "phase": C.NIGHT, "block": n.home_block, "how": "window", "detail": "street"}
	w.evil_plan["fake_sightings"][n.id + ":1"] = b
	var lines: Array = []
	var facts: Array = []
	w.day = 2
	w.meeting = {"accusations": []}
	w.evil_plan["scapegoat"] = target.id
	n.traits["insight"] = 1.0
	n.traits["confidence"] = 1.0
	n.pressure = 10.0
	Mind._public_accusation(w, n, lines, facts)
	_check(facts.size() == 1 and facts[0]["subject"] == [target.id] and facts[0]["source"] == n.id and facts[0]["day"] == 1, "a publicly cited fake sighting becomes usable, attributed evidence")
	var before: int = g.board.size()
	g._facts(facts)
	g._facts(facts)
	_check(g.board.size() == before + 1, "repeating the same public sighting does not duplicate its card")

func _survival() -> void:
	var g = _game()
	var w = g.w
	var n = w.by_id["isolde"]
	var demon = w.demon()
	w.day = 5
	w.begin_meeting()
	n.pressure = 10.0
	w.meeting["nominated"].append(n.id)
	Mind.shadow_run(w, n, func(sh): Mind.adjust(w, sh, demon.id, 5.0, "a persuasive public case"))
	var shadow_vote = Mind.shadow_eval(w, n, func(sh): return Mind.vote(w, sh, demon.id, "player", false, "", 0))
	_check(shadow_vote == true, "regression setup: the good shadow wants to execute the demon")
	_check(not Mind.vote(w, n, demon.id, "player", false, "", 0), "an early evil vote cannot sacrifice the demon to maintain cover")
	var nomination = Mind._evil_nomination(w, n, w.meeting, "")
	_check(nomination == null or nomination["nominee"] != demon.id, "even an exposed minion refuses its shadow's demon nomination")
	# A plausible Warden alibi is allowed to name a teammate.
	for other in w.npcs:
		if other != n and other != demon:
			other.alive = false
	n.warden_log.clear()
	n.history[w.time_key(4, C.NIGHT)] = "home:" + n.home_block
	_check(Mind.warden_door(w, n, 4) == demon.id, "a claimed protection target is not a guaranteed non-teammate")

func _own_role() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	n.role = "warden"
	var e = Argue._clear(g.w, n.id, {"type": "role", "role": "lamplighter"}, "They were the Lamplighter")
	_check(Argue._expl_weight(g.w, n, e) == 0.0, "a Warden cannot explain their own movements by being the Lamplighter")
	var other = g.w.living_good()[1]
	_check(Argue._expl_weight(g.w, other, e) > 0.0, "that private knowledge does not leak to another listener")
	n.home_block = "hill"
	n.history[g.w.time_key(1, C.NIGHT)] = "night:docks"
	var on_way: String = C.route(n.home_block, "docks")[0]
	_check(Argue._knows_false(g.w, n, {"t": "out", "who": n.id, "night": 1, "block": on_way}) == -1, "own knowledge recognizes sightings along the route, not just the destination")

func _meeting_sighting_prefix_and_gallows() -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good()[0]
	var target = w.living_good()[1]
	var b = {"kind": "saw", "who": target.id, "day": 1, "phase": C.NIGHT, "block": "docks", "how": "visit", "detail": "street"}
	var report = Mind.sighting_report(w, n, b, 1)
	var lines: Array = []
	var facts: Array = []
	n.beliefs.append(b)
	w.day = 2
	Mind._public_disclosure(w, n, lines, facts, false)
	_check(not lines.any(func(l): return "On night 1: On night 1" in l.get("text", "")), "meeting sighting disclosure does not duplicate On night X prefix")
	n.claim_public = true
	n.claimed_role = n.role
	n.info_log.clear()
	n.beliefs.clear()
	var gallows: Dictionary = Mind.gallows_speech(w, n)
	_check(gallows["lines"].size() >= 1 and gallows["lines"][0]["text"].begins_with("As I've said, I am the "), "gallows speech acknowledges an already-public role claim")

func _public_hearsay_and_self_gossip() -> void:
	var g = _game()
	var w = g.w
	var s = w.living_good()[0]
	var l = w.living_good()[1]
	var b = {"kind": "saw", "who": l.id, "day": 1, "phase": C.NIGHT, "block": "docks", "how": "window", "detail": "street"}
	Mind.Social.deliver_public_sighting(w, s, b)
	_check(l.hearsay.all(func(h): return h.get("public", false)), "publicly delivered meeting sightings are marked public in listener hearsay")
	_check(Mind.Social._gossip_items(w, l).is_empty(), "NPCs do not approach to gossip about public meeting sightings or sightings of themselves")

func _approach_ui_visibility() -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good()[0]
	n.loc = "chapel"
	n.working = false
	n.busy_with = ""
	g.moved = false
	g.state = "approach"
	g.approach = {"npc": n, "agenda": "gossip"}
	g.approached_id = n.id
	g.approached_loc = n.loc
	_check(not g.can_see(n) and g.can_see_ui(n), "approaching NPC is visible in UI without breaking simulation can_see")
	g.command("decline")
	_check(g.state == "day" and g.can_see_ui(n), "declined approach NPC remains visible at their stated location for that phase")

func _workshop_merge_order_of_operations() -> void:
	var g = _game()
	var target = g.w.demon()
	var c_alibi = g.add_card({"kind": "alibi", "subject": [target.id], "source": target.id, "day": 2, "phase": C.NIGHT, "claimed": "home:" + target.home_block, "text": "%s says they stayed home on night 2." % target.name})
	var c_sight = g.add_card({"kind": "sighting", "subject": [target.id], "source": "player", "day": 2, "phase": C.NIGHT, "block": "docks", "text": "You saw %s on the Docks on night 2." % target.name})
	var CM = load("res://workshop/canvas_model.gd")
	var m1 = CM.new(g)
	var p1 = m1.add_premise({"type": "evil", "a": target.id}, Vector2.ZERO)
	var a1 = m1.add_evidence("c%d" % c_alibi, Vector2.ZERO)
	var s1 = m1.add_evidence("c%d" % c_sight, Vector2.ZERO)
	m1.connect_cards(a1, s1)
	var merged1 = m1.selected
	m1.connect_cards(merged1, p1)
	var comp1 = m1.compile(p1)
	var m2 = CM.new(g)
	var p2 = m2.add_premise({"type": "evil", "a": target.id}, Vector2.ZERO)
	var a2 = m2.add_evidence("c%d" % c_alibi, Vector2.ZERO)
	var s2 = m2.add_evidence("c%d" % c_sight, Vector2.ZERO)
	m2.connect_cards(a2, p2)
	m2.connect_cards(s2, p2)
	var err = m2.connect_cards(a2, s2)
	var comp2 = m2.compile(p2)
	_check(err == "" and m2.selected == p2, "merging two cards already linked to a premise succeeds and keeps the premise selected")
	_check(comp1.disputes.size() == 1 and comp2.disputes.size() == 1 and comp1.reasons == comp2.reasons, "merging after linking to a premise compiles identically to merging before linking")
