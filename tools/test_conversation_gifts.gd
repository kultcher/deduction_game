## Private conversation about gifts: disclosure tiers and mood, refusals, hints and their follow-ups, repeat questions, protection and secrecy requests.
## Merged from: test_backlog_batch2, test_backlog_batch3, test_backlog_batch4, test_fixes, test_phase2_bug_sweep, test_phase4_1_reveal_and_rumor_pacing, test_playtest_followups.
extends SceneTree

const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
const Speech = preload("res://tools/speech.gd")
const Evil = preload("res://sim/evil.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_backlog_batch2()
	_run_backlog_batch3()
	await _run_backlog_batch4()
	_run_fixes()
	_run_phase2_bug_sweep()
	_run_phase4_1_reveal_and_rumo()
	_run_playtest_followups()
	print("Conversation: gifts: %d checks, %d failures" % [checks, fails])
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


# ---------------------------------------------------------------- from test_backlog_batch2

func _run_backlog_batch2() -> void:
	_role_guess_warning()


# ---------------------------------------------------------------- from test_backlog_batch3

func _run_backlog_batch3() -> void:
	repeated_role_gift()
	private_gift_terms()


# ---------------------------------------------------------------- from test_backlog_batch4

func _run_backlog_batch4() -> void:
	refusal_privacy()
	repeated_refusals()
	hint_options()
	await readings_ask()
	confidence_public_notice()
	seer_space_targets()


# ---------------------------------------------------------------- from test_fixes

func _run_fixes() -> void:
	_warden_doors()
	_no_gift_denial()
	_own_gift_refusal()
	_accuse_tiers()
	_hint_followup()


# ---------------------------------------------------------------- from test_phase2_bug_sweep

func _run_phase2_bug_sweep() -> void:
	_test_2_2_keep_request_fatigue_and_protect_lock()


# ---------------------------------------------------------------- from test_phase4_1_reveal_and_rumor_pacing

func _run_phase4_1_reveal_and_rumo() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	_test_knob1_tapered_role_reluctance_and_day_slope()
	_test_knob2_reactive_reveal_pivot_and_fear_paranoia_fix()


# ---------------------------------------------------------------- from test_playtest_followups

func _run_playtest_followups() -> void:
	approach_fatigue()


# ---- test_backlog_batch2


func fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch2_tests"
	g.new_case(4242, 10)
	return g


func _role_guess_warning() -> void:
	var g = fresh()
	for n in [g.w.living_good()[0], g.w.minion()]:
		var mine: String = g.w.evil_plan.bluffs[n.id] if n.is_evil() else n.role
		var wrong: String = "seer" if mine != "seer" else "warden"
		n.trust = 0.8
		n.trust_cap = 1.0
		n.max_tier = 0
		n.claim_public = false
		n.role_guesses = 0
		for i in range(1, 4):
			n.pressed_today = 0 # Isolate the existing per-wrong-guess cost.
			var before: float = n.trust
			var state = g.w.rng.state
			var reply = Social.answer_is_role(g.w, n, wrong)
			var expected = "What my gift is, I'll keep to myself." if i == 1 else ("You're grasping at straws, and I'm running out of patience." if i == 2 else "Why do you keep asking me that?")
			check(reply.lines[0].get("statement", reply.lines[0].text) == expected and reply.lines[0].text != "" and reply.facts.is_empty(), "first/second/third guess cadence is noncommittal for both alignments")
			check(n.role_guesses == i and is_equal_approx(before - n.trust, 0.02 * i), "warning preserves the wrong-guess counter and existing cost")
			check(g.w.rng.state == state, "wrong-guess wording introduces no random choice")


# ---- test_backlog_batch3


func backlog_batch3__fresh(count: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch3_tests"
	g.new_case(4242, count)
	return g


func repeated_role_gift():
	for evil in [false, true]:
		for public in [false, true]:
			var a = backlog_batch3__fresh()
			var b = backlog_batch3__fresh()
			var na = a.w.minion() if evil else a.w.living_good()[0]
			var nb = b.w.by_id[na.id]
			for pair in [[a, na], [b, nb]]:
				var g = pair[0]
				var n = pair[1]
				g.w.day = 3
				n.max_tier = 3
				n.claim_public = public
				n.claimed_role = "seer"
				if evil: g.w.evil_plan.bluffs[n.id] = "seer"
				else: n.role = "seer"
				n.trust = 0.9
				n.traits.privacy = 0.0
				n.pressed_today = 3
				n.role_guesses = 2
				var others: Array = g.w.npcs.filter(func(x): return x != n).map(func(x): return x.id)
				n.info_log = [{"role": "seer", "day": 1, "data": {"pair": others.slice(0, 2), "yes": false}, "text": "neither was the Demon", "shared": false}]
			var direct = Mind.answer_gift(a.w, na)
			var repeated = Social.answer_is_role(b.w, nb, "seer")
			check(JSON.stringify(direct) == JSON.stringify(repeated), "already disclosed matching role question gives exactly the ask-gift response")
			check(na.pressed_today == nb.pressed_today and na.trust == nb.trust and a.w.rng.state == b.w.rng.state and nb.role_guesses == 2, "matching question preserves gift cost/fatigue/RNG and is never a wrong guess")
			check(repeated.facts.any(func(f): return f.kind == "info"), "willing matching-role answers include previously withheld readings")


func private_gift_terms():
	var g = backlog_batch3__fresh()
	for n in [g.w.living_good()[0], g.w.minion()]:
		for role in [C.START_ROLES[0], "seer", "warden", "martyr"]:
			if n.is_evil(): g.w.evil_plan.bluffs[n.id] = role
			else: n.role = role
			n.traits.privacy = 0.5
			n.traits.composure = 0.5
			n.trust = 0.5
			n.pressure = 0.0
			n.martyr_target = g.w.npcs.back().id
			for day in [1, 2, 3]:
				g.w.day = day
				# Since Oct 30 the jitter is a fixed daily sample (+-OPENNESS_JITTER), no RNG draw.
				var rng_before = g.w.rng.state
				var jitter: float = (preload("res://sim/mind_dialogue.gd")._day_roll(n.id, day, 0x0BE7) - 0.5) * 2.0 * preload("res://sim/tuning.gd").Dialogue.OPENNESS_JITTER
				var openness = 0.5 + 0.5 * 1.2 + 0.1 * (day - 1) - 0.72 + jitter
				if C.ROLES[role].kind != "info":
					var hide_pen: float = -0.50 if day <= 1 else (-0.30 if day == 2 else -0.10)
					if role == "warden": hide_pen = minf(hide_pen, -0.35)
					openness += hide_pen
				if role in ["seer", "hearthwitch", "nightwatch", "lamplighter", "medium", "psychologist", "dowser"]:
					openness += (-0.45 if day <= 1 else (-0.20 if day == 2 else 0.0))
				elif role in C.START_ROLES: openness += 0.3
				var expected = 4 if openness > 0.75 else (3 if openness > 0.45 else (2 if openness > 0.15 else 1))
				check(Mind._target_tier(g.w, n) == expected, "private tier applies only the approved gift terms under public-roll conditions")
				check(g.w.rng.state == rng_before, "gift-type tuning draws no RNG for the jitter")


# ---- test_backlog_batch4


func backlog_batch4__fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch4_tests"
	g.new_case(4242, 10)
	return g


func refusal_privacy():
	var g = backlog_batch4__fresh()
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
		if probe.randf() < 0.25: probe.randf() # Approved willingness roll only after a successful privacy slip.
		check(w.rng.state == probe.state, "refusal adds only the required privacy and eligible-report willingness draws")
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
				check(answer.lines[0].get("statement", answer.lines[0].text.trim_prefix("[PH] ")) in ["That sighting doesn't give you the right to demand my whereabouts.", "I've nothing more to say about that night."] or "sighting" in answer.lines[0].text, "pressed-night rewriting still targets the first refusal line")
		if blocked and slipped and pressed: break
	check(blocked and slipped and pressed, "privacy fixture covers withholding, slips and pressed refusals")
	# Own-street observations don't reveal an extra location or require a new roll.
	for seed_value in range(1, 50):
		n.dialogue_memory = {}
		n.pressed_today = 0
		n.pressure = 0.0
		n.beliefs = [{"kind": "saw", "who": target.id, "block": "square", "day": 1, "phase": C.NIGHT, "how": "window"}]
		w.rng.seed = seed_value
		var probe = RandomNumberGenerator.new()
		probe.state = w.rng.state
		probe.randf()
		var reply = Mind.answer_night(w, n, 1)
		if reply.facts.any(func(f): return f.kind == "refusal"):
			if probe.randf() >= 0.95: continue
			check(reply.facts.any(func(f): return f.kind == "sighting" and f.block == "square") and w.rng.state == probe.state, "a home-street report needs only the approved willingness roll, not a privacy roll")
			break
	# Claimed-walker fake watch reports retain their original branch and RNG.
	n.claimed_role = "nightwatch"
	n.max_tier = 3
	n.beliefs = []
	n.info_log = [{"role": "nightwatch", "day": 1, "shared": true, "fake": true, "data": {"block": "market", "seen": [target.id]}, "text": "A cached watch"}]
	w.evil_plan.fake_watch["1"] = "market"
	n.pressed_today = 0
	w.rng.state = willing_state()
	var watch_probe = RandomNumberGenerator.new()
	watch_probe.state = w.rng.state
	watch_probe.randf()
	var state = watch_probe.state
	var watch = Mind.answer_night(w, n, 1)
	check(watch.facts.any(func(f): return f.kind == "sighting" and target.id in f.subject and f.block == "market") and w.rng.state == state, "claimed Night Watch cover remains intact with only its approved willingness roll")

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
		n.dialogue_memory = {}
		n.pressed_today = 0
		n.pressure = 0.0
		w.rng.seed = seed_value
		var probe = RandomNumberGenerator.new()
		probe.state = w.rng.state
		probe.randf()
		var reply = Mind.answer_night(w, n, 1)
		if reply.facts.any(func(f): return f.kind == "refusal"):
			if probe.randf() < 0.25: probe.randf()
			check(w.rng.state == probe.state and (not reply.facts.any(func(f): return f.kind == "sighting") or reply.lines.any(func(line): return "not that I was there" in line.text)), "low Gossip no longer vetoes direct answers, but the existing privacy slip gate still applies")
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
	var a = backlog_batch4__fresh()
	var b = backlog_batch4__fresh()
	var na = a.w.living_good()[0]
	var nb = b.w.by_id[na.id]
	talk_fixture(a, na)
	talk_fixture(b, nb)
	na.pressed_today = 3
	nb.pressed_today = 3
	var first = a.command("ask gift")
	Mind.answer_gift(b.w, nb)
	var second = a.command("ask gift")
	var second_speeches: Array = a.last_events.filter(func(e): return e.get("k", "") == "speech" and e.get("speaker", "") == na.id)
	var second_said: String = Speech.said(second_speeches[0]) if not second_speeches.is_empty() else second
	Mind.answer_gift(b.w, nb)
	check(a.questions_left == 2 and a.free_repeats == 1 and "No question used" in second, "second identical gift refusal uses the existing one free-repeat slot")
	check(first != second and ("You've had my answer" in second_said or "puts a target on my back" in second_said), "the repeated gift refusal has a different line")
	check(na.pressed_today == nb.pressed_today and na.trust == nb.trust and a.w.rng.state == b.w.rng.state, "the free slot does not waive NPC fatigue/trust or alter disclosure RNG")
	a.command("ask gift")
	check(a.questions_left == 1 and a.free_repeats == 1, "later repeats cost a question after the single free repeat")
	Mind.Dialogue.begin_conversation(na.dialogue_memory)
	a.questions_left = 3
	a.free_repeats = 0
	a.command("ask gift")
	check(a.questions_left == 2 and a.free_repeats == 0, "refusal repeat memory resets for a new conversation")
	var g = backlog_batch4__fresh()
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
	var g = backlog_batch4__fresh()
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
	var g = backlog_batch4__fresh()
	scene.g = g
	var n = g.w.living_good()[0]
	talk_fixture(g, n)
	for status in [0, 1, 2]:
		n.max_tier = 3 if status == 1 else 0
		n.claim_public = status == 2
		scene._refresh_actions()
		await process_frame
		# Find the gift ask by its label, not its position: since the daytime conversation
		# view (Oct 28) the talk actions sit in its controls, behind a "Look at the map" toggle.
		var pool: Array = scene.actions.get_children() + scene.conversation_view.controls.get_children()
		var buttons = pool.filter(func(b): return b is Button and not b.is_queued_for_deletion() and (b.text.begins_with("Ask about their readings") or b.text.ends_with("'s gift…  ▸")))
		var text: String = buttons[0].text if not buttons.is_empty() else ""
		check(("readings" in text) == (status != 0) and text != "", "gift action label follows private or public disclosure")
		if buttons.is_empty():
			continue
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
		check(reply.facts.any(func(f): return f.kind == "claim") and reply.facts.any(func(f): return f.kind == "info") and not reply.lines.any(func(line): return "As you know" in line.get("statement", line.text)), "known good or evil gift gives readings and claim card without reconfirmation")
		n.info_log = []
		reply = Mind.answer_gift(g.w, n, 4)
		check(reply.lines.any(func(line): return "As you know" in line.get("statement", line.text)) and reply.lines.any(func(line): return "anything yet" in line.get("statement", line.text)), "empty reading history retains the gift confirmation")
	n = g.w.living_good()[0]
	n.role = "warden"
	n.claimed_role = "warden"
	n.max_tier = 3
	n.warden_log = {"0": g.w.npcs[-1].id}
	var guarded = Mind.answer_gift(g.w, n, 4)
	check(guarded.facts.any(func(f): return f.has("guard_claim")) and not guarded.lines.any(func(line): return "As you know" in line.get("statement", line.text)), "known Warden reports doors without reconfirmation")
	n.max_tier = 0
	n.claim_public = false
	var first = Mind.answer_gift(g.w, n, 4)
	check(first.lines.any(func(line): return "Warden" in line.text), "first gift disclosure still names the gift even with work to report")
	for i in range(3): await process_frame
	scene.free()


func confidence_public_notice():
	var a = backlog_batch4__fresh()
	var b = backlog_batch4__fresh()
	var na = a.w.living_good()[0]
	var nb = b.w.by_id[na.id]
	na.request_day = -1
	na.trust = 0.9
	na.traits.composure = 0.0
	var asked = false
	for seed_value in range(1, 100):
		a.w.rng.seed = seed_value
		var rq = Mind._confidence_request(a.w, na, 3, {})
		if not rq.is_empty():
			asked = true
			break
	check(asked and na.dialogue_memory.get("confidence_requested", false), "a spoken confidence request records that the NPC asked for privacy")
	for n in [na, nb]:
		n.role = "clerk"
		n.info_log = []
		n.claim_public = false
		n.claimed_role = "clerk"
		Mind.Dialogue.begin_conversation(n.dialogue_memory)
	var lines: Array = []
	var facts: Array = []
	var original_lines: Array = []
	var original_facts: Array = []
	b.w.rng.state = a.w.rng.state
	Mind._public_disclosure(a.w, na, lines, facts)
	Mind._go_public(b.w, nb, original_lines, original_facts)
	check(lines[0].get("statement", lines[0].text) == "I've decided the town should hear it." and lines.slice(1) == original_lines, "the public notice precedes the unchanged original claim")
	check(facts == original_facts and a.w.rng.state == b.w.rng.state, "confidence release adds no cards or RNG draws")
	var count = lines.size()
	Mind._public_disclosure(a.w, na, lines, facts)
	check(lines.size() == count, "later public refreshes do not repeat the confidence notice")
	a.confidences[999] = na.id
	var trust = na.trust
	a._break_confidences([999])
	check(na.trust == trust and not a.confidences.has(999), "the existing public-claim exemption still releases the player's confidence")
	var g = backlog_batch4__fresh()
	var n = g.w.living_good()[0]
	g.w.day = 20
	n.role = "clerk"
	n.info_log = []
	n.claim_public = false
	n.traits.privacy = 0.0
	n.dialogue_memory["confidence_requested"] = true
	var st = {"speakers": [n], "i": 0, "done": false}
	var turn = Mind.testimony_step(g.w, st)
	check(n.claim_public and turn.lines.any(func(line): return line.get("statement", line.text) == "I've decided the town should hear it."), "confidence release arrives within the speaker's streamed testimony step")


func willing_state() -> int:
	var probe = RandomNumberGenerator.new()
	for seed_value in range(1, 100):
		probe.seed = seed_value
		var state = probe.state
		if probe.randf() < 0.95: return state
	return 0


func seer_space_targets():
	var control_rng = -1
	var control_response = {}
	var control_request = {}
	for separator in [", ", " ", " and "]:
		var g = backlog_batch4__fresh()
		var n = g.w.living_good()[0]
		n.role = "seer"
		n.claimed_role = "seer"
		n.max_tier = 3
		n.trust = 1.0
		var others = g.w.living().filter(func(m): return m != n)
		g.w.rng.seed = 9102
		var r = g._gift_request(n, "check", others[0].id + separator + others[1].id)
		if separator == ", ":
			control_rng = g.w.rng.state
			control_response = r
			control_request = n.gift_request.duplicate(true)
		else:
			check(r == control_response and n.gift_request == control_request and g.w.rng.state == control_rng, "Seer request separator preserves targets, response and exact draw: " + separator)
		var rng = g.w.rng.state
		check(g._gift_request(n, "check", "unknown_name " + others[0].id).is_empty() and g.w.rng.state == rng, "invalid Seer names are rejected before any roll")


# ---- test_fixes


func _game(sd: int, size: int = 10):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


func _warden_doors() -> void:
	var g = _game(7105)
	var w = g.w
	var wd = w.npcs.filter(func(x): return not x.is_evil())[0]
	wd.role = "warden"
	wd.claimed_role = "warden"
	wd.claim_public = true
	var t1 = w.npcs.filter(func(x): return x != wd)[0]
	var t2 = w.npcs.filter(func(x): return x != wd)[1]
	wd.warden_log = {"1": t1.id, "2": t2.id}
	w.day = 3
	var r = Mind.answer_gift(w, wd, 3)
	var text = " ".join(PackedStringArray(r["lines"].filter(func(l): return l is Dictionary).map(func(l): return l["text"])))
	_check(t1.name in text and t2.name in text, "asked about their gift, a Warden says whose doors they guarded")
	_check(r["facts"].filter(func(f): return f.has("guard_claim")).size() == 2, "each guarded door is a card")
	# An evil Warden bluff tells the same story every time.
	var ev = w.npcs.filter(func(x): return x.is_evil())[0]
	ev.history[w.time_key(1, C.NIGHT)] = "home:" + ev.home_block
	var a = Mind.warden_door(w, ev, 1)
	var b = Mind.warden_door(w, ev, 1)
	_check(a != "" and a == b, "an evil Warden bluff names the same door each time it's asked")


func _own_gift_refusal() -> void:
	var declined = 0
	for sd in range(7310, 7330):
		var g = _game(sd, 7)
		var n = g.w.living_good()[0]
		n.role = "seer"
		n.claimed_role = ""
		n.claim_public = false
		n.max_tier = 0
		n.trust = 0.0
		n.traits.gossip = 1.0
		n.known_claims = {}
		g.w.public_claims = []
		var response = Social.answer_about_role(g.w, n, "seer")
		if response.facts.is_empty():
			declined += 1
			_check(response.lines.size() == 1 and response.lines[0].get("statement", response.lines[0].text) == "That's not for me to say.", "a holder declining their own gift refuses instead of claiming ignorance")
			_check(not n.claim_public and n.max_tier < 3, "the refusal does not disclose the holder's role")
	_check(declined > 0, "the own-gift fixture exercises declined disclosure")


func _no_gift_denial() -> void:
	var denials = 0
	# The knob is a constant; a few towns show it holds.
	for sd in range(7300, 7303):
		var g = _game(sd, 7)
		for n in g.w.npcs:
			n.trust = 0.0
			n.traits["privacy"] = 1.0
			var r = Mind.answer_gift(g.w, n)
			if r["facts"].any(func(f): return f["kind"] == "claim" and f.get("role", "") == "none"):
				denials += 1
	_check(denials == 0, "nobody denies having a gift (the knob is off)")


func _setup_private_reading(sd: int, size: int = 10):
	var g = _game(sd, size)
	var w = g.w
	var good: Array = w.living_good()
	var n = good[0]
	var t = good[1]
	var x = good[2]
	n.role = "seer"
	n.claimed_role = ""
	n.claim_public = false
	# Their own gift is part of what they know: replace the dealt role's own claim and
	# reading too, or the shared model sees a Seer reading in another gift's hands.
	n.ledger = {}
	Mind.hear_claim(w, n, n.id, "seer", 1.5, "own")
	n.info_log = [{"day": 0, "role": "seer", "data": {"pair": [t.id, x.id], "yes": true},
		"text": "I learned that one of %s and %s is the demon" % [t.name, x.name], "shared": false, "true": false, "why": "test"}]
	n.applied_info = 0
	n.told_readings = 0
	Mind.update_from_own_info(w)
	return [g, w, n, t]


## Asking a hinter why: they may decline; if they tell, it's in confidence, and using it at
## the meeting costs their trust.
func _accuse_tiers() -> void:
	# Reluctant: private, keeps-giving gift, afraid-ish, early: mostly hints, never silent here.
	var r = _setup_private_reading(7210)
	var w = r[1]
	var n = r[2]
	var t = r[3]
	n.traits["privacy"] = 1.0
	n.traits["confidence"] = 0.2
	w.day = 1
	var counts = {"hint": 0, "reveal": 0, "generic": 0}
	for i in range(60):
		counts[Mind._accuse_tier(w, n, t, 0.8)["tier"]] += 1
	_check(counts["hint"] > counts["reveal"] and counts["generic"] == 0, "a private, reluctant Seer mostly hints (%s)" % str(counts))
	# Bold, late, few left: mostly reveals.
	n.traits["privacy"] = 0.1
	n.traits["confidence"] = 0.9
	w.day = 5
	counts = {"hint": 0, "reveal": 0, "generic": 0}
	for i in range(60):
		counts[Mind._accuse_tier(w, n, t, 1.1)["tier"]] += 1
	_check(counts["reveal"] > counts["hint"], "a bold Seer late in the game mostly reveals (%s)" % str(counts))
	# Reveal brings the gift and the reading out, as cards.
	var lines: Array = []
	var facts: Array = []
	Mind._go_public(w, n, lines, facts)
	_check(n.claim_public and n.info_log[0]["shared"], "going public claims the gift and shares the reading")
	_check(facts.any(func(f): return f["kind"] == "claim") and facts.any(func(f): return f["kind"] == "info"), "both become cards")
	# No private reason: a bare accusation.
	n.info_log = []
	n.ledger = {}
	Mind.refresh_beliefs(w, n, " (clear own reading)")
	_check(Mind._accuse_tier(w, n, t, 0.9)["tier"] == "generic", "with no reason to protect, a generic accusation")


## Meeting-flow step 1: the nominator's case hints at or reveals a private reading, never
## quotes it; recapping public reasons changes nobody's mind.
func _hint_followup() -> void:
	var r = _setup_private_reading(7220)
	var g = r[0]
	var w = r[1]
	var n = r[2]
	var t = r[3]
	n.hints[t.id] = {"day": w.day, "src": ""}
	n.trust = 0.05
	n.traits["privacy"] = 1.0
	var declined = 0
	for i in range(20):
		n.hints[t.id] = {"day": w.day, "src": ""}
		n.max_tier = 0
		n.told_readings = 0
		n.claimed_role = ""
		n.trust = 0.05
		var a = Mind.answer_hint(w, n)
		if a["facts"].is_empty():
			declined += 1
	n.hints[t.id] = {"day": w.day, "src": ""}
	n.max_tier = 0
	n.told_readings = 0
	n.claimed_role = ""
	_check(declined >= 15, "a guarded, distrustful hinter mostly keeps it back (%d/20)" % declined)
	n.trust = 0.95
	n.traits["privacy"] = 0.0
	var told = {}
	for i in range(20):
		told = Mind.answer_hint(w, n)
		if not told["facts"].is_empty():
			break
	_check(not told["facts"].is_empty(), "a trusting hinter tells you why")
	_check(told["facts"].all(func(f): return f.get("confidential", "") == n.id or f.get("source", "") != n.id), "and asks you to keep it quiet (cards marked confidential)")
	_check(not n.hints.has(t.id), "the hint is answered")
	var before = g.board.size()
	g._facts(told["facts"])
	_check(g.confidences.size() >= 1 and g.board.size() > before, "the confidential cards are on the board and remembered")
	var tr = n.trust
	g._break_confidences(g.confidences.keys())
	_check(n.trust < tr - 0.04 and g.confidences.is_empty(), "using them at the meeting breaks your word (trust %.2f -> %.2f)" % [tr, n.trust])
	# Evil's free bluff hint: nothing to show for it, so it declines.
	var e = w.evil_team()[0]
	e.hints[t.id] = {"day": w.day, "src": ""}
	e.info_log = e.info_log.filter(func(x): return not (t.id in Mind.implicated(x)))
	var ea = Mind.answer_hint(w, e)
	_check(ea["facts"].is_empty() and e.hints.has(t.id), "evil with nothing behind its hint declines to back it up")


# ---- test_phase2_bug_sweep


func _test_2_2_keep_request_fatigue_and_protect_lock() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var n = g.w.living_good()[0]
	n.role = "seer"
	n.claimed_role = ""
	n.claim_public = false
	n.max_tier = 0
	n.pressed_today = 3
	n.trust = 0.60
	var before_trust: float = n.trust
	var res: Dictionary = Mind.keep_request(g.w, n, 4)
	_check(n.pressed_today == 3, "accepting Question-3 secrecy deal does not increment pressed_today to 4")
	_check(is_equal_approx(n.trust, before_trust + 0.03) and not res["facts"].is_empty(), "accepting secrecy deal grants +0.03 gift-share rapport without fatigue drop")

	# Hard protect_lock blocks voluntary public claim unless nominated, high pressure, or <= 4 alive.
	n.claim_public = false
	n.protect_lock = true
	n.pressure = 0.2
	n.traits["privacy"] = 0.0
	g.w.day = 3
	g.w.meeting = {"nominated": []}
	_check(Mind._public_claim_decision(g.w, n) == "", "protect_lock hard-blocks voluntary public claim above 4 living")


# ---- test_phase4_1_reveal_and_rumor_pacing


func _test_knob1_tapered_role_reluctance_and_day_slope() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var w = g.w
	var dummy = w.living_good()[0]

	# Ongoing info taper: -0.45 (D1) -> -0.20 (D2) -> absent/0.0 (D3+)
	var seer_def = C.role_def("seer")
	w.day = 1
	var p_d1: Dictionary = {}
	seer_def.score_public_claim(w, dummy, p_d1)
	w.day = 2
	var p_d2: Dictionary = {}
	seer_def.score_public_claim(w, dummy, p_d2)
	w.day = 3
	var p_d3: Dictionary = {}
	seer_def.score_public_claim(w, dummy, p_d3)
	_check(
		is_equal_approx(float(p_d1.get("gift_keeps_giving", 0.0)), -0.45)
		and is_equal_approx(float(p_d2.get("gift_keeps_giving", 0.0)), -0.20)
		and not p_d3.has("gift_keeps_giving"),
		"Ongoing info reluctance tapers cleanly (-0.45 D1, -0.20 D2, 0.0 D3)"
	)

	# Non-Warden utility taper (Veteran): -0.50 (D1) -> -0.30 (D2) -> -0.10 (D3+)
	var vet_def = C.role_def("veteran")
	w.day = 1
	var v_d1: Dictionary = {}
	vet_def.score_public_claim(w, dummy, v_d1)
	w.day = 2
	var v_d2: Dictionary = {}
	vet_def.score_public_claim(w, dummy, v_d2)
	w.day = 3
	var v_d3: Dictionary = {}
	vet_def.score_public_claim(w, dummy, v_d3)
	_check(
		is_equal_approx(float(v_d1.get("hides_from_demon", 0.0)), -0.50)
		and is_equal_approx(float(v_d2.get("hides_from_demon", 0.0)), -0.30)
		and is_equal_approx(float(v_d3.get("hides_from_demon", 0.0)), -0.10),
		"Utility role hides_from_demon tapers (-0.50 D1, -0.30 D2, -0.10 D3)"
	)

	# Warden retains -0.35 floor on D2 and D3+
	var warden_def = C.role_def("warden")
	w.day = 1
	var wd_d1: Dictionary = {}
	warden_def.score_public_claim(w, dummy, wd_d1)
	w.day = 2
	var wd_d2: Dictionary = {}
	warden_def.score_public_claim(w, dummy, wd_d2)
	w.day = 3
	var wd_d3: Dictionary = {}
	warden_def.score_public_claim(w, dummy, wd_d3)
	_check(
		is_equal_approx(float(wd_d1.get("hides_from_demon", 0.0)), -0.50)
		and is_equal_approx(float(wd_d2.get("hides_from_demon", 0.0)), -0.35)
		and is_equal_approx(float(wd_d3.get("hides_from_demon", 0.0)), -0.35),
		"Warden retains -0.35 floor on Day 2 and Day 3+ (-0.50 D1, -0.35 D2, -0.35 D3)"
	)

	# Monte Carlo check: public claim rate rises substantially from Day 1 to Day 2 to Day 3.
	dummy.role = "veteran"
	dummy.claim_public = false
	dummy.protect_lock = false
	dummy.pressure = 0.1
	dummy.traits["privacy"] = 0.45
	w.meeting = {"nominated": []}
	var counts: Dictionary = {1: 0, 2: 0, 3: 0}
	for d in [1, 2, 3]:
		w.day = d
		for _i in range(250):
			if Mind._public_claim_decision(w, dummy) != "":
				counts[d] += 1
	_check(counts[1] < counts[2] and counts[2] < counts[3] and counts[3] >= 120,
		"Public claim probability climbs across Days 1-3 (%d -> %d -> %d / 250)" % [counts[1], counts[2], counts[3]])


func _test_knob2_reactive_reveal_pivot_and_fear_paranoia_fix() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(92974, 10)
	var w = g.w
	var goods: Array = w.living_good()
	var seer = goods[0]
	var suspect = goods[1]
	var partner = goods[2]

	# Fear-paranoia fix: killing townsfolk (raising paranoia) must NEVER lower fear_chance!
	seer.traits["composure"] = 0.35
	seer.pressure = 0.0
	seer.fear_eased = false
	var fear_zero_dead: float = Mind.fear_chance(w, seer)
	goods[3].alive = false
	goods[4].alive = false
	goods[5].alive = false
	var fear_three_dead: float = Mind.fear_chance(w, seer)
	_check(is_equal_approx(fear_zero_dead, fear_three_dead) and fear_three_dead >= fear_zero_dead,
		"fear_chance no longer drops as deaths raise paranoia (0 dead %.3f vs 3 dead %.3f)" % [fear_zero_dead, fear_three_dead])
	goods[3].alive = true
	goods[4].alive = true
	goods[5].alive = true

	# Reactive reveal pivot: at Bayesian ping suspicion s2 = 0.54, Seer reveals on a healthy share of accusations.
	seer.role = "seer"
	seer.claim_public = false
	seer.claimed_role = ""
	seer.traits["privacy"] = 0.45
	seer.traits["confidence"] = 0.55
	seer.traits["composure"] = 0.75
	seer.ledger.clear()
	seer.workshop_state.clear()
	seer.info_log = [{"day": 1, "role": "seer", "data": {"pair": [suspect.id, partner.id], "yes": true}, "true": true, "shared": false, "text": "between %s and %s, one reads as the Demon" % [suspect.name, partner.name]}]
	seer.applied_info = 0
	Mind.update_from_own_info(w)
	w.day = 2
	var reveals: int = 0
	for _i in range(200):
		var res: Dictionary = Mind._accuse_tier_impl(w, seer, suspect, 0.54)
		if res.get("tier", "") == "reveal":
			reveals += 1
	_check(reveals >= 70,
		"Seer with 0.54 Bayesian ping suspicion chooses reveal_to_accuse regularly (%d / 200)" % reveals)


# ---- test_playtest_followups


func playtest_followups__fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://followup_tests"
	g.new_case(4242, 10)
	return g


func approach_fixture(g, evil: bool):
	var n = g.w.minion() if evil else g.w.living_good()[0]
	g.w.day = 3
	n.loc = n.work
	n.busy_with = ""
	n.silenced = false
	n.trust = 0.5
	n.claim_public = false
	n.claimed_role = ""
	n.max_tier = 0
	n.info_log = []
	n.role_guesses = 2
	if evil: g.w.evil_plan.bluffs[n.id] = "clerk"
	else: n.role = "clerk"
	g.state = "approach"
	return n


func approach_fatigue():
	for agenda in ["news", "gossip", "frame", "protect"]:
		var a = playtest_followups__fresh()
		var b = playtest_followups__fresh()
		var n = approach_fixture(a, agenda == "frame")
		var control = approach_fixture(b, agenda == "frame")
		n.pressed_today = 8
		control.pressed_today = 0
		a.approach = {"npc": n, "agenda": agenda, "what": "ward"}
		b.approach = {"npc": control, "agenda": agenda, "what": "ward"}
		var rng = a.w.rng.state
		a._approach_command("accept", "")
		b._approach_command("accept", "")
		check(n.pressed_today == 0 and n.trust == control.trust, "accepted %s approach starts with no accumulated question fatigue" % agenda)
		check(a.w.rng.state == b.w.rng.state and n.role_guesses == 2, "approach reset changes neither existing rolls nor wrong guesses")
		var before = n.trust
		for i in range(3): Mind.on_question(a.w, n)
		check(n.trust == before, "three follow-up questions are free of old fatigue")
		Mind.on_question(a.w, n)
		check(n.trust < before, "new fatigue still applies after the playtest_followups__fresh allowance")
	var g = playtest_followups__fresh()
	var n = approach_fixture(g, false)
	n.pressed_today = 8
	g.approach = {"npc": n, "agenda": "news"}
	g._approach_command("decline", "")
	check(n.pressed_today == 8, "declining a news approach does not reset fatigue")
	g.state = "approach"
	g.approach = {"npc": n, "agenda": "protect", "what": "ward"}
	g._approach_command("decline", "")
	check(n.pressed_today == 8, "declining a protection request does not reset fatigue")
	g.state = "day"
	g.divulge_due = [n.id]
	var before = n.trust
	var divulged = g._maybe_divulge()
	check(divulged and n.pressed_today == 0, "promised free disclosure itself resets fatigue before its opening answer (delivered %s, fatigue %d)" % [divulged, n.pressed_today])
	check(n.trust >= before, "promised disclosure adds no old question-fatigue trust penalty")
	g._approach_command("accept", "")
	check(g.questions_left == 3 and n.pressed_today == 0, "continuing a promised disclosure has a playtest_followups__fresh question allowance")
