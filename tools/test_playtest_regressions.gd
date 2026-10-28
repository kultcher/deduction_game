## Regressions from cases 61251 and 25923.
## godot --headless --path . --script res://tools/test_playtest_regressions.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Argue = preload("res://sim/argue.gd")
const Recent = preload("res://game/recent_sightings.gd")
const C = preload("res://sim/content.gd")
const Social = preload("res://sim/social.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Live = preload("res://game/workshop_canvas.gd")
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
	_vigil_destination_only()
	_medium_fake_dead_reading_fallback()
	_consistent_night_account_on_press()
	_multi_subject_vigil_no_collateral_note()
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
	var b = {"kind": "saw", "who": target.id, "day": 1, "phase": C.NIGHT, "block": n.home_block, "how": "window", "detail": "street"}
	var lines: Array = []
	var facts: Array = []
	n.secret_mod = ""
	n.silenced = false
	n.traits.gossip = 1.0
	n.traits.confidence = 1.0
	n.beliefs = [b]
	n.told_to.clear()
	w.day = 2
	w.phase = C.MORNING
	var rng_state = w.rng.state
	Mind._volunteer_night_sightings(w, n, lines, facts)
	_check(facts.size() == 1 and lines.size() == 1 and lines[0].text.count("night 1") == 1, "actual volunteered sighting says the night exactly once")
	_check(w.rng.state == rng_state, "formatting a volunteered night sighting adds no RNG draw")
	# The person-specific recent-sightings path has its own date-prefix handling.
	n.role = "lamplighter"
	n.claimed_role = n.role
	n.claim_public = true
	var recent = {"lines": [], "facts": []}
	Recent.append_to(w, n, target, recent, [])
	_check(recent.facts.size() == 1 and recent.lines.size() == 1 and recent.lines[0].text.count("night 1") == 1, "actual recent night sighting says the night exactly once")
	n.info_log.clear()
	n.beliefs.clear()
	var gallows: Dictionary = Mind.last_words(w, n)
	_check(gallows["lines"].size() >= 1 and gallows["lines"][0]["text"].begins_with("As I've said, I am the "), "last words acknowledge an already-public role claim")

func _public_hearsay_and_self_gossip() -> void:
	var g = _game()
	var w = g.w
	var s = w.living_good()[0]
	var l = w.living_good()[1]
	var target = w.living_good()[2]
	l.hearsay.clear()
	l.known_secrets.clear()
	l.told_to.clear()
	var fact = {"kind": "sighting", "source": s.id, "subject": [target.id], "day": 1, "phase": C.NIGHT, "block": "docks", "text": "A public night sighting."}
	var rng_state = w.rng.state
	Social.deliver_public_sighting(w, s, fact)
	_check(not l.hearsay.is_empty() and l.hearsay.all(func(h): return h.get("public", false)), "public delivery creates nonempty hearsay marked public")
	_check(Social._gossip_items(w, l).is_empty(), "public meeting sightings are excluded from player gossip")
	_check(w.rng.state == rng_state, "public sighting delivery adds no RNG draw")
	var private_report = l.hearsay[0].duplicate(true)
	private_report["public"] = false
	l.hearsay = [private_report]
	_check(not Social._gossip_items(w, l).is_empty(), "an undisclosed private sighting remains available for gossip")
	s.told_to["player|saw:%s:1" % target.id] = true
	_check(Social._gossip_items(w, l).is_empty(), "the source's already-disclosed sighting is not gossip news")
	private_report.about = l.id
	_check(Social._gossip_items(w, l).is_empty(), "a private sighting about the teller is not self-incriminating gossip")


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
	var view: Dictionary = Live.view(g)
	var alibi: String = "e:" + Live.Evidence.normalize_card(g.board[c_alibi - 1]).id
	var sight: String = "e:" + Live.Evidence.normalize_card(g.board[c_sight - 1]).id
	var m1 = Canvas.new(view)
	var p1 = m1.add_premise(target.id, "evil", Vector2.ZERO)
	m1.connect_cards(alibi, sight)
	var merged1: String = m1.selected
	m1.connect_cards(merged1, p1)
	var comp1 = m1.compile(p1)
	var m2 = Canvas.new(view)
	var p2 = m2.add_premise(target.id, "evil", Vector2.ZERO)
	m2.connect_cards(alibi, p2)
	m2.connect_cards(sight, p2)
	var err = m2.connect_cards(alibi, sight)
	var comp2 = m2.compile(p2)
	_check(err == "" and m2.selected == p2, "merging two cards already linked to a premise succeeds and keeps the premise selected")
	_check(comp1.cards == comp2.cards and comp1.disputes.size() == 1 and comp1.disputes == comp2.disputes and comp1.reasons == comp2.reasons, "merge-before-link and merge-after-link preserve the same evidence and interpretation")

func _vigil_destination_only() -> void:
	var g = _game()
	var w = g.w
	var a = w.npcs[0]
	var b = w.npcs[1]
	var lamp = w.npcs[2]
	a.home_block = "docks"
	b.home_block = "market"
	lamp.home_block = "square"
	w.night_walkers = [
		{"id": a.id, "block": "hill", "path": ["docks", "hill"], "why": "leaving docks for hill"},
		{"id": b.id, "block": "docks", "path": ["market", "docks"], "why": "arriving on docks"},
		{"id": lamp.id, "block": "square", "path": C.BLOCKS.keys(), "why": "walking the lamp route"},
	]
	w.player_vigil = "docks"
	w._night_sightings()
	_check(not (a.id in w.player_vigil_seen) and (b.id in w.player_vigil_seen) and (lamp.id in w.player_vigil_seen),
		"player vigil spots destination visitors and the Lamplighter, not residents leaving for another block")
	var watch_def = C.role_def("nightwatch")
	var watch_reading: Dictionary = watch_def.generate_reading(w, w.npcs[3], {"watch_block": "docks"}, Mind)
	_check(a.id in watch_reading["data"]["seen"] and b.id in watch_reading["data"]["seen"],
		"Night Watch still sees both departing residents and arriving visitors on the watched block")

func _medium_fake_dead_reading_fallback() -> void:
	var g = _game()
	var w = g.w
	var evil_npc = w.demon()
	var dd = w.living_good()[0]
	var sg = w.living_good()[1]
	w.evil_plan["scapegoat"] = sg.id
	var ok = true
	for role in ["surveyor", "rumormonger", "lamplighter", "veteran", "martyr"]:
		var res: Dictionary = Mind.Evil._fake_dead_reading(w, evil_npc, dd, role, sg.id, 1)
		if not res.is_empty():
			ok = false
	_check(ok, "Evil._fake_dead_reading safely returns {} for roles without custom fabricated Medium relays")

func _consistent_night_account_on_press() -> void:
	var g = _game()
	var w = g.w
	var evil_npc = w.demon()
	w.day = 2
	evil_npc.claimed_role = ""
	evil_npc.history[w.time_key(1, C.NIGHT)] = "night:docks"
	var card = {"kind": "sighting", "subject": [evil_npc.id], "source": "player", "block": "docks", "day": 1, "phase": C.NIGHT, "text": "Seen on the Docks."}
	evil_npc.traits["confidence"] = 1.0
	evil_npc.traits["privacy"] = 0.0
	evil_npc.dialogue_memory.clear()
	var r1 = Mind.answer_night(w, evil_npc, 1)
	evil_npc.traits["confidence"] = 0.0
	evil_npc.traits["privacy"] = 1.0
	var p1 = Mind.press(w, evil_npc, card)
	_check(r1["facts"][0]["kind"] == "alibi" and p1["facts"][0]["kind"] == "alibi", "an NPC who gave a home alibi on ask night stands by it when pressed instead of flipping to a refusal")
	evil_npc.dialogue_memory.clear()
	var r2 = Mind.answer_night(w, evil_npc, 1)
	evil_npc.traits["confidence"] = 1.0
	evil_npc.traits["privacy"] = 0.0
	var p2 = Mind.press(w, evil_npc, card)
	_check(r2["facts"][0]["kind"] == "refusal" and p2["facts"][0]["kind"] == "refusal", "an NPC who refused whereabouts on ask night stands by the refusal when pressed instead of claiming a prior home account")

func _multi_subject_vigil_no_collateral_note() -> void:
	var g = _game()
	var w = g.w
	var target = w.demon()
	var bystander = w.living_good()[0]
	var victim = w.living_good()[1]
	target.home_block = "docks"
	bystander.home_block = "market"
	victim.home_block = "hill"
	g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1, "block": "hill", "text": "Killed on hill"})
	var vig = g.add_card({"kind": "sighting", "source": "player", "subject": [target.id, bystander.id], "day": 1, "phase": C.NIGHT, "block": "docks", "vigil": true, "text": "Night 1 vigil: saw both on the Docks."})
	var view: Dictionary = Live.view(g)
	var m = Canvas.new(view)
	var p = m.add_premise(target.id, "evil", Vector2.ZERO)
	m.connect_cards("e:" + Live.Evidence.normalize_card(g.board[vig - 1]).id, p)
	var listener = w.living_good()[2]
	var eval_res: Dictionary = preload("res://workshop/jury.gd").evaluate(view, m.compile(p), {"id": listener.id, "name": listener.name, "trust": 0.5, "confidence": 0.5, "insight": 0.9, "reasoning_mode": "bounded", "suspicion": {}, "npc_trust": {}, "reading_reliability": {}, "theories": {}, "ledger": {}, "case_memory": {}, "knowledge": {"self": listener.id, "good": [listener.id], "own_role": listener.role, "own_reports": [], "own_outings": {}}})
	_check(not eval_res.get("response", "").is_empty() and not eval_res.response.contains(bystander.name + "'s sighting"), "multi-subject vigil card produces a response without Seen elsewhere notes for unrelated bystanders")
