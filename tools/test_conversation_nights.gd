## Private conversation about nights: whereabouts, night accounts kept consistent under pressure, privately told sightings, withheld readings.
## Merged from: test_backlog_batch4, test_claude_batch, test_fixes, test_playtest_regressions.
extends SceneTree

const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
const Speech = preload("res://tools/speech.gd")
const Game = preload("res://game/game.gd")
const Evil = preload("res://sim/evil.gd")
const Recent = preload("res://game/recent_sightings.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_backlog_batch4()
	_run_fixes()
	_run_claude_batch()
	_run_playtest_regressions()
	print("Conversation: nights: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## One shared check helper (the merged suites used both names).
func check(ok: bool, label: String) -> void:
	_count(ok, label)


func _check(ok: bool, label: String) -> void:
	_count(ok, label)


func _count(ok: bool, label: String) -> void:
	checks += 1
	_checks += 1
	if not ok:
		fails += 1
		failures += 1
		_fails += 1
		printerr("FAIL: " + label)


# ---------------------------------------------------------------- from test_backlog_batch4

func _run_backlog_batch4() -> void:
	compact_answers()
	co_present_sightings()
	direct_night_willingness()


# ---------------------------------------------------------------- from test_fixes

func _run_fixes() -> void:
	_where_were_you()


# ---------------------------------------------------------------- from test_claude_batch

func _run_claude_batch() -> void:
	_one_night_story()


# ---------------------------------------------------------------- from test_playtest_regressions

func _run_playtest_regressions() -> void:
	_whereabouts()
	_secrets()
	_watch_disclosure()
	_consistent_night_account_on_press()


# ---- test_backlog_batch4


func fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch4_tests"
	g.new_case(4242, 10)
	return g


func compact_answers():
	var g = fresh()
	var w = g.w
	var n = w.living_good()[0]
	var others = w.npcs.filter(func(t): return t != n)
	n.role = "clerk"
	n.secret = {}
	n.secret_mod = ""
	n.claimed_role = ""
	n.home_block = "square"
	n.traits.gossip = 1.0
	n.traits.insight = 1.0
	n.pressure = 0.0
	w.day = 2
	n.history[w.time_key(1, C.NIGHT)] = "home:square"
	n.beliefs = []
	var expected: Array = [Mind._alibi_home(n, 1)]
	for i in range(4):
		var b = {"kind": "saw" if i < 2 else "stayed_in", "who": others[i].id, "block": "square", "day": 1, "phase": C.NIGHT, "how": "window"}
		n.beliefs.append(b)
		expected.append(Mind.sighting_report(w, n, b, 1).fact)
	w.rng.state = willing_state()
	var night_probe = RandomNumberGenerator.new()
	night_probe.state = w.rng.state
	night_probe.randf()
	var state = night_probe.state
	var night = Mind.answer_night(w, n, 1)
	check(night.facts == expected and w.rng.state == state, "condensed night replies preserve every original fact and RNG state")
	check(night.lines.size() == 3 and night.lines[1].text.contains(others[0].name + " and " + others[1].name) and night.lines[2].text.contains(others[2].name + " and " + others[3].name), "night observations merge names and keep one line per kind")
	n.loc = "tavern"
	w.phase = C.AFTERNOON
	n.beliefs = []
	for i in range(3):
		n.beliefs.append({"kind": "saw", "who": others[i].id, "loc": "smithy" if i < 2 else "well", "block": "market" if i < 2 else "square", "day": 2, "phase": C.MORNING, "with": ""})
	var day = Mind.answer_today(w, n, "morning")
	check(day.facts.size() == 3 and day.facts.all(func(f): return f.kind == "sighting" and f.day == 2 and f.phase == C.MORNING), "day condensation retains all selected sighting cards")
	check(day.lines.size() == 1 and others.slice(0, 3).all(func(person): return person.name in day.lines[0].text) and "well" in day.lines[0].text and "smith" in day.lines[0].text and "this morning" in day.lines[0].text, "day narration keeps each selected person, place and time in one line")
	n.role = "seer"
	n.claimed_role = "seer"
	n.max_tier = 3
	n.info_log = []
	for nd in [0, 1]:
		n.info_log.append({"role": "seer", "day": nd, "shared": true, "text": "neither was the Demon", "data": {"pair": [others[0].id, others[1].id], "yes": false}})
	var gift = Mind.answer_gift(w, n, 4)
	var infos = gift.facts.filter(func(f): return f.kind == "info")
	check(gift.lines.size() == 1 and infos == n.info_log.map(func(e): return Mind.info_fact(w, n, e)), "private readings occupy one line but preserve each full reading card")
	check("The night before you arrived" in Speech.said(gift.lines[0]) and "Last night" in Speech.said(gift.lines[0]), "condensed readings retain their separate dates")
	var reply = {"lines": [Mind.say(n, "An opinion.")], "facts": []}
	n.beliefs = []
	for ph in [C.MORNING, C.AFTERNOON]:
		n.beliefs.append({"kind": "saw", "who": others[0].id, "loc": "well", "block": "square", "day": 2, "phase": ph})
	preload("res://game/recent_sightings.gd").append_to(w, n, others[0], reply, [])
	check(reply.lines.size() == 2 and reply.facts.size() == 2 and "morning" in reply.lines[1].text and "afternoon" in reply.lines[1].text, "opinion followup sightings share a line without losing either dated card")


func co_present_sightings():
	var g = fresh()
	var w = g.w
	var n = w.living_good()[0]
	var a = w.living_good()[1]
	var b = w.living_good()[2]
	var c = w.living_good()[3]
	w.day = 2
	w.phase = C.AFTERNOON
	w.player_loc = "tavern"
	n.loc = "tavern"
	a.loc = "tavern"
	b.loc = "well" # Same block, different place.
	c.loc = "smithy"
	n.traits.gossip = 1.0
	n.traits.insight = 1.0
	n.pressure = 0.0
	n.beliefs = [
		{"kind": "saw", "who": a.id, "day": 2, "phase": C.MORNING, "loc": "well", "block": "square", "with": ""},
		{"kind": "saw", "who": a.id, "day": 2, "phase": C.AFTERNOON, "loc": "tavern", "block": "square", "with": ""},
		{"kind": "saw", "who": b.id, "day": 2, "phase": C.AFTERNOON, "loc": "well", "block": "square", "with": ""},
		{"kind": "saw", "who": c.id, "day": 2, "phase": C.AFTERNOON, "loc": "smithy", "block": "market", "with": a.id}]
	var state = w.rng.state
	var day = Mind.answer_today(w, n, "", w.player_loc)
	check(not day.facts.any(func(f): return a.id in f.subject and f.phase == C.AFTERNOON), "current sightings and conversation partners beside the player are omitted")
	check(day.facts.any(func(f): return f.subject == [a.id] and f.phase == C.MORNING), "an older sighting of a person beside the player survives")
	check(day.facts.any(func(f): return f.subject == [b.id]) and day.facts.any(func(f): return f.subject == [c.id]), "same-block other places and independent sightings of a conversation partner survive")
	check(w.rng.state == state, "co-presence filtering adds no RNG draws")
	var reply = {"lines": [], "facts": []}
	preload("res://game/recent_sightings.gd").append_to(w, n, a, reply, [])
	check(reply.facts.size() == 1 and reply.facts[0].phase == C.MORNING, "person-specific followups omit only the current co-present sighting")
	reply = {"lines": [], "facts": []}
	preload("res://game/recent_sightings.gd").append_to(w, n, b, reply, [])
	check(reply.facts.size() == 1 and reply.facts[0].subject == [b.id], "person-specific followups retain a same-block sighting elsewhere")


func willing_state() -> int:
	var probe = RandomNumberGenerator.new()
	for seed_value in range(1, 100):
		probe.seed = seed_value
		var state = probe.state
		if probe.randf() < 0.95: return state
	return 0


func direct_night_willingness():
	var g = fresh()
	var w = g.w
	var n = w.living_good()[0]
	var t = w.living_good()[1]
	w.day = 3
	n.role = "clerk"
	n.secret_mod = ""
	n.claimed_role = ""
	n.home_block = "square"
	n.history[w.time_key(2, C.NIGHT)] = "home:square"
	n.traits.gossip = 0.0
	n.npc_trust[t.id] = 0.95
	n.beliefs = [{"kind": "saw", "who": t.id, "block": "square", "day": 2, "phase": C.NIGHT, "how": "window"}]
	var told = 0
	var withheld = 0
	var probe = RandomNumberGenerator.new()
	for seed_value in range(1, 201):
		n.pressed_today = 0
		n.pressure = 0.0
		w.rng.seed = seed_value
		probe.state = w.rng.state
		var expected = probe.randf() < 0.95
		var reply = Mind.answer_night(w, n, 2)
		var shared = reply.facts.any(func(f): return f.kind == "sighting" and f.subject == [t.id])
		check(shared == expected and w.rng.state == probe.state, "an eligible direct answer uses exactly the approved 95 percent willingness draw")
		if shared: told += 1
		else:
			withheld += 1
			check(reply.lines.any(func(line): return "not ready to discuss" in str(line.get("statement", line.text)) and line.text != ""), "unwilling direct answers refuse instead of falsely claiming to have seen nobody")
	check(told > 180 and withheld > 0 and n.told_to.has("player|saw:%s:2" % t.id), "near-certain direct sharing still has a refusal outcome and records player telling")
	n.beliefs = []
	for person in w.npcs.filter(func(other): return other != n).slice(0, 6):
		n.npc_trust[person.id] = 0.95
		n.beliefs.append({"kind": "saw", "who": person.id, "block": "square", "day": 2, "phase": C.NIGHT, "how": "window"})
	n.pressure = 0.0
	n.pressed_today = 0
	w.rng.state = willing_state()
	var all = Mind.answer_night(w, n, 2)
	check(all.facts.filter(func(f): return f.kind == "sighting").size() == 6, "approved direct willingness replaces both the Gossip count/cutoff and trusted-friend omission")


# ---- test_fixes


func _game(sd: int, size: int = 10):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


func _talk_to(g, n) -> void:
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 3
	g.free_repeats = 0
	g.talk_offered = false
	g.talk_approached = false
	g.loc = n.loc if C.LOCATIONS.has(n.loc) else "tavern"


func _where_were_you() -> void:
	var g = _game(7110, 7)
	for i in range(40):
		if g.w.day >= 2 and g.state == "day":
			break
		match g.state:
			"night":
				g.command("sleep")
			"meeting", "nomination":
				g.command("done" if g.state == "meeting" else "vote no")
				g.command("wait")
			"approach":
				g.command("decline")
			_:
				g.command("wait")
	var w = g.w
	var n = w.living()[0]
	n.traits["gossip"] = 0.9
	_talk_to(g, n)
	var r = Mind.answer_today(w, n, "yesterday afternoon")
	var t: String = Speech.said(r["lines"][0])
	_check(t.begins_with("Yesterday afternoon I was "), "a timeframe answer starts with where they were (%s)" % t)
	g.command("ask seen yesterday morning")
	_check(g.last_events.any(func(e): return e["k"] == "speech" and "Yesterday morning I was" in Speech.said(e)), "'ask seen yesterday morning' works as a command")


# ---- test_claude_batch


func claude_batch__game(sd: int):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 7)
	return g


func _one_night_story() -> void:
	var same = 0
	var other_block_quiet = 0
	var tried = 0
	for sd in range(4410, 4430):
		var g = claude_batch__game(sd)
		var w = g.w
		var m = w.minion()
		var goods: Array = w.living_good()
		var x = goods[0]
		var block: String = m.home_block
		m.info_log.append({"day": 1, "role": "nightwatch", "fake": true, "shared": false, "true": false,
			"data": {"block": block, "seen": [x.id]}, "text": "I watched it: I saw %s pass by" % x.name})
		w.day = 2
		tried += 1
		var r = Evil.fake_night_sighting(w, m, 1)
		if r != null and r["who"] == x.id:
			same += 1
		var away: String = C_other(block)
		if Evil.fake_night_sighting(w, m, 1, away, "street") == null:
			other_block_quiet += 1
	_check(same == tried, "a window sighting repeats the member's own watch report for that night (%d/%d)" % [same, tried])
	_check(other_block_quiet == tried, "and nothing is invented on another block")


## A Demon victim was good: evidence against them stops discounting their word.
func C_other(block: String) -> String:
	for b in preload("res://sim/content.gd").BLOCKS:
		if b != block:
			return b
	return block


# ---- test_playtest_regressions


func playtest_regressions__game():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(25923, 10)
	return g


func _whereabouts() -> void:
	var g = playtest_regressions__game()
	var w = g.w
	var n = w.living_good()[0]
	w.day = 2
	n.history[w.time_key(1, C.EVENING)] = "wharf"
	n.traits["gossip"] = 0.0
	n.pressure = 0.0
	var r = Mind.answer_today(w, n, "yesterday evening")
	var own: Array = r["facts"].filter(func(c): return c.get("self_report", false))
	_check(own.size() == 1 and own[0]["subject"] == [n.id] and own[0]["source"] == n.id and own[0]["block"] == "docks", "a reticent speaker's stated whereabouts still produce attributed evidence")


func _secrets() -> void:
	var g = playtest_regressions__game()
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


func _watch_disclosure() -> void:
	var g = playtest_regressions__game()
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


func _consistent_night_account_on_press() -> void:
	var g = playtest_regressions__game()
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
