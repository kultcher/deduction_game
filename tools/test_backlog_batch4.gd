## Playtest 37291 follow-ups, seven items per review set.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const C = preload("res://sim/content.gd")
var checks = 0
var fails = 0
func _init():
	call_deferred("run")
func fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch4_tests"
	g.new_case(4242, 10)
	return g
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)
func run():
	refusal_privacy()
	repeated_refusals()
	hint_options()
	await readings_ask()
	compact_answers()
	print("Batch 4: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
func refusal_privacy():
	var g = fresh()
	var w = g.w
	var n = w.minion()
	var target = w.living_good()[0]
	n.home_block = "square"
	n.history[w.time_key(1, C.NIGHT)] = "night:market"
	n.claimed_role = ""
	n.claim_public = false
	n.info_log = []
	n.secret_mod = ""
	n.traits.gossip = 1.0
	n.traits.confidence = 0.0
	n.traits.privacy = 1.0
	n.traits.composure = 0.0
	n.trust = 0.5
	n.npc_trust[target.id] = 0.5
	w.day = 2
	var blocked = false
	var slipped = false
	var pressed = false
	for seed_value in range(1, 90):
		n.pressure = 0.0
		n.pressed_today = 0
		n.dialogue_memory = {}
		n.beliefs = [{"kind": "saw", "who": target.id, "block": "market", "day": 1, "phase": C.NIGHT, "how": "street"}]
		w.rng.seed = seed_value
		var probe = RandomNumberGenerator.new()
		probe.state = w.rng.state
		probe.randf() # Existing lie/stonewall decision.
		var reply = Mind.answer_night(w, n, 1)
		if not reply.facts.any(func(f): return f.kind == "refusal"): continue
		probe.randf() # One new slip roll for the selected non-home observation.
		check(w.rng.state == probe.state, "refusal adds only the required slip draw")
		var observations: Array = reply.facts.filter(func(f): return f.kind == "sighting")
		if observations.is_empty():
			blocked = true
			check(not str(reply.lines).contains(target.name), "a withheld whereabouts answer does not leak its non-home sighting")
		else:
			slipped = true
			check(reply.lines.any(func(line): return line is Dictionary and "not that I was there" in line.text), "an escaped sighting is explicitly worded as a slip")
		if not pressed:
			n.pressure = 0.0
			n.pressed_today = 0
			n.dialogue_memory = {}
			w.rng.seed = seed_value
			var card = {"kind": "sighting", "subject": [n.id], "source": "player", "day": 1, "phase": C.NIGHT, "block": "market", "text": "A sighting to press with"}
			var answer = Mind.press(w, n, card)
			if answer.facts.any(func(f): return f.kind == "refusal"):
				pressed = true
				check(answer.lines[0].text in ["That sighting doesn't give you the right to demand my whereabouts.", "I've nothing more to say about that night."] or "sighting" in answer.lines[0].text, "pressed-night rewriting still targets the first refusal line")
		if blocked and slipped and pressed: break
	check(blocked and slipped and pressed, "privacy fixture covers withholding, slips and pressed refusals")
	# Own-street observations don't reveal an extra location or require a new roll.
	for seed_value in range(1, 50):
		n.pressed_today = 0
		n.pressure = 0.0
		n.beliefs = [{"kind": "saw", "who": target.id, "block": "square", "day": 1, "phase": C.NIGHT, "how": "window"}]
		w.rng.seed = seed_value
		var probe = RandomNumberGenerator.new()
		probe.state = w.rng.state
		probe.randf()
		var reply = Mind.answer_night(w, n, 1)
		if reply.facts.any(func(f): return f.kind == "refusal"):
			check(reply.facts.any(func(f): return f.kind == "sighting" and f.block == "square") and w.rng.state == probe.state, "a home-street report remains available without a new random draw")
			break
	# Claimed-walker fake watch reports retain their original branch and RNG.
	n.claimed_role = "nightwatch"
	n.max_tier = 3
	n.beliefs = []
	n.info_log = [{"role": "nightwatch", "day": 1, "shared": true, "fake": true, "data": {"block": "market", "seen": [target.id]}, "text": "A cached watch"}]
	w.evil_plan.fake_watch["1"] = "market"
	n.pressed_today = 0
	var state = w.rng.state
	var watch = Mind.answer_night(w, n, 1)
	check(watch.facts.any(func(f): return f.kind == "sighting" and target.id in f.subject and f.block == "market") and w.rng.state == state, "claimed Night Watch cover remains intact without refusal filtering or extra RNG")

	# Even an existing fake watch payload is filtered if THIS answer stonewalls.
	w.evil_plan.fake_watch.erase("1")
	var filtered_watch = false
	for seed_value in range(1, 60):
		n.pressed_today = 0
		n.pressure = 0.0
		w.rng.seed = seed_value
		var reply = Mind.answer_night(w, n, 1)
		if reply.facts.any(func(f): return f.kind == "refusal"):
			filtered_watch = true
			check(not reply.facts.any(func(f): return f.kind == "sighting") or reply.lines.any(func(line): return line is Dictionary and "not that I was there" in line.text), "a refusal cannot bypass privacy through the fake-watch report path")
			break
	check(filtered_watch, "fixture exercises a refusing fake-watch path")
	n.claimed_role = ""
	n.info_log = []
	n.traits.gossip = 0.0
	n.beliefs = [{"kind": "saw", "who": target.id, "block": "market", "day": 1, "phase": C.NIGHT, "how": "street"}]
	for seed_value in range(1, 60):
		n.pressed_today = 0
		n.pressure = 0.0
		w.rng.seed = seed_value
		var probe = RandomNumberGenerator.new()
		probe.state = w.rng.state
		probe.randf()
		var reply = Mind.answer_night(w, n, 1)
		if reply.facts.any(func(f): return f.kind == "refusal"):
			check(w.rng.state == probe.state and not reply.facts.any(func(f): return f.kind == "sighting"), "gossip-zero refusals do not roll slips for sightings they won't share")
			break
	var sleeper = w.living_good()[1]
	sleeper.role = "clerk"
	sleeper.secret_mod = "sleepwalker"
	sleeper.claimed_role = ""
	sleeper.history[w.time_key(1, C.NIGHT)] = "night:market"
	sleeper.beliefs = []
	sleeper.traits.gossip = 0.0
	sleeper.pressed_today = 0
	state = w.rng.state
	var unaware = Mind.answer_night(w, sleeper, 1)
	check(unaware.facts.any(func(f): return f.kind == "alibi" and f.home) and w.rng.state == state, "an unaware Sleepwalker retains their unchanged home-account branch and RNG")

func talk_fixture(g, n):
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 3
	g.free_repeats = 0
	n.role = "warden"
	n.max_tier = 0
	n.claimed_role = ""
	n.claim_public = false
	n.silenced = false
	n.traits.privacy = 1.0
	n.traits.composure = 1.0
	n.trust = 0.5
	n.trust_cap = 1.0
	n.pressure = 0.0
	n.request_day = g.w.day # Keep requests as a separately tested path.
	Mind.Dialogue.begin_conversation(n.dialogue_memory)
func repeated_refusals():
	var a = fresh()
	var b = fresh()
	var na = a.w.living_good()[0]
	var nb = b.w.by_id[na.id]
	talk_fixture(a, na)
	talk_fixture(b, nb)
	na.pressed_today = 3
	nb.pressed_today = 3
	var first = a.command("ask gift")
	Mind.answer_gift(b.w, nb)
	var second = a.command("ask gift")
	Mind.answer_gift(b.w, nb)
	check(a.questions_left == 2 and a.free_repeats == 1 and "No question used" in second, "second identical gift refusal uses the existing one free-repeat slot")
	check(first != second and "You've had my answer" in second or "still afraid" in second, "the repeated gift refusal has a different line")
	check(na.pressed_today == nb.pressed_today and na.trust == nb.trust and a.w.rng.state == b.w.rng.state, "the free slot does not waive NPC fatigue/trust or alter disclosure RNG")
	a.command("ask gift")
	check(a.questions_left == 1 and a.free_repeats == 1, "later repeats cost a question after the single free repeat")
	Mind.Dialogue.begin_conversation(na.dialogue_memory)
	a.questions_left = 3
	a.free_repeats = 0
	a.command("ask gift")
	check(a.questions_left == 2 and a.free_repeats == 0, "refusal repeat memory resets for a new conversation")
	var g = fresh()
	var n = g.w.living_good()[0]
	talk_fixture(g, n)
	n.pressed_today = 0
	n.role_guesses = 0
	g.command("ask are seer")
	var warning = g.command("ask are seer")
	check(g.questions_left == 2 and n.role_guesses == 2 and "grasping at straws" in warning, "same wrong-role refusal saves the slot while preserving the second-guess warning and counter")
	check(is_equal_approx(n.trust, 0.44), "both original wrong-guess trust costs still apply")
	g.command("ask are medium")
	check(g.questions_left == 1, "a different role question is not an identical refusal")
	var request = {"request": {"kind": "confidence"}, "refusal_ask": "gift", "refusal_line": 0, "lines": [Mind.say(n, "Promise first")], "facts": []}
	var original = JSON.stringify(request)
	g._repeat_refusal(n, request)
	check(JSON.stringify(request) == original, "confidence/protection requests never enter refusal-repeat handling")

func hint_options():
	var g = fresh()
	var n = g.w.living_good()[0]
	var t = g.w.living_good()[1]
	n.hints = {}
	check(not Mind.has_live_hint(g.w, n) and not "ask why" in g._talk_options(n) and not "ask why" in g._help(), "generic help and conversation options omit ask why without a live hint")
	n.hints[t.id] = {"day": g.w.day}
	check(Mind.has_live_hint(g.w, n) and "ask why" in g._talk_options(n), "conversation advertises ask why for a living hinted target")
	t.alive = false
	check(not Mind.has_live_hint(g.w, n) and not "ask why" in g._talk_options(n), "a dead hinted target does not advertise ask why")
	var state = g.w.rng.state
	var first = Mind.answer_hint(g.w, n)
	var second = Mind.answer_hint(g.w, n)
	check(first.lines[0].text != second.lines[0].text and first.facts.is_empty() and second.facts.is_empty(), "no-target hint replies vary without producing cards")
	check(g.w.rng.state == state, "varied no-target hint wording adds no RNG draws")

func readings_ask():
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	root.add_child(scene)
	var g = fresh()
	scene.g = g
	var n = g.w.living_good()[0]
	talk_fixture(g, n)
	for status in [0, 1, 2]:
		n.max_tier = 3 if status == 1 else 0
		n.claim_public = status == 2
		scene._refresh_actions()
		await process_frame
		var buttons = scene.actions.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion())
		var text: String = buttons[0].text
		check(("readings" in text) == (status != 0), "gift action label follows private or public disclosure")
		scene._ask_gift_picker(buttons[0])
		var choices = scene.popup.find_children("*", "Button", true, false)
		check(choices.any(func(b): return b.text == ("about their readings" if status != 0 else "about their gift")), "gift picker keeps its ask-gift command behind the matching readings label")
		scene.popup.hide()
	for evil in [false, true]:
		n = g.w.minion() if evil else g.w.living_good()[0]
		n.role = "seer" if not evil else n.role
		if evil: g.w.evil_plan.bluffs[n.id] = "seer"
		n.max_tier = 3
		n.claimed_role = "seer"
		n.claim_public = false
		n.info_log = [{"role": "seer", "day": 0, "shared": false, "text": "neither was the Demon", "data": {"pair": [g.w.npcs[-1].id, g.w.npcs[-2].id], "yes": false}}]
		var reply = Mind.answer_gift(g.w, n, 4)
		check(reply.facts.any(func(f): return f.kind == "claim") and reply.facts.any(func(f): return f.kind == "info") and not reply.lines.any(func(line): return "As you know" in line.text), "known good or evil gift gives readings and claim card without reconfirmation")
		n.info_log = []
		reply = Mind.answer_gift(g.w, n, 4)
		check(reply.lines.any(func(line): return "As you know" in line.text) and reply.lines.any(func(line): return "anything yet" in line.text), "empty reading history retains the gift confirmation")
	n = g.w.living_good()[0]
	n.role = "warden"
	n.claimed_role = "warden"
	n.max_tier = 3
	n.warden_log = {"0": g.w.npcs[-1].id}
	var guarded = Mind.answer_gift(g.w, n, 4)
	check(guarded.facts.any(func(f): return f.has("guard_claim")) and not guarded.lines.any(func(line): return "As you know" in line.text), "known Warden reports doors without reconfirmation")
	n.max_tier = 0
	n.claim_public = false
	var first = Mind.answer_gift(g.w, n, 4)
	check(first.lines.any(func(line): return "Warden" in line.text), "first gift disclosure still names the gift even with work to report")
	for i in range(3): await process_frame
	scene.free()

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
	var state = w.rng.state
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
	check(day.lines.size() == 1 and (others[1].name + " and " + others[0].name) in day.lines[0].text and "well" in day.lines[0].text, "day sightings group people by place while retaining other places")
	n.role = "seer"
	n.claimed_role = "seer"
	n.max_tier = 3
	n.info_log = []
	for nd in [0, 1]:
		n.info_log.append({"role": "seer", "day": nd, "shared": true, "text": "neither was the Demon", "data": {"pair": [others[0].id, others[1].id], "yes": false}})
	var gift = Mind.answer_gift(w, n, 4)
	var infos = gift.facts.filter(func(f): return f.kind == "info")
	check(gift.lines.size() == 1 and infos == n.info_log.map(func(e): return Mind.info_fact(w, n, e)), "private readings occupy one line but preserve each full reading card")
	check("The night before you arrived" in gift.lines[0].text and "Last night" in gift.lines[0].text, "condensed readings retain their separate dates")
	var reply = {"lines": [Mind.say(n, "An opinion.")], "facts": []}
	n.beliefs = []
	for ph in [C.MORNING, C.AFTERNOON]:
		n.beliefs.append({"kind": "saw", "who": others[0].id, "loc": "well", "block": "square", "day": 2, "phase": ph})
	preload("res://game/recent_sightings.gd").append_to(w, n, others[0], reply, [])
	check(reply.lines.size() == 2 and reply.facts.size() == 2 and "morning" in reply.lines[1].text and "afternoon" in reply.lines[1].text, "opinion followup sightings share a line without losing either dated card")
