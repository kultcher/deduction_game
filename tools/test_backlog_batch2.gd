## Focused regressions for the ten approved Oct-25 backlog decisions.
extends SceneTree
const Game = preload("res://game/game.gd")
const Speech = preload("res://tools/speech.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const Evil = preload("res://sim/evil.gd")
const C = preload("res://sim/content.gd")
const Argue = preload("res://sim/argue.gd")
var checks = 0
var fails = 0
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	_walker_wording()
	_medium_hearths()
	_neutral_opinion()
	_distrust()
	_relationships()
	_role_guess_warning()
	_trace_subjects()
	print("Batch 2: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
func fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch2_tests"
	g.new_case(4242, 10)
	return g
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)
func _walker_wording() -> void:
	var g = fresh()
	var n = g.w.minion()
	var target = g.w.living_good()[0]
	for person in g.w.npcs:
		person.info_log = []
	g.w.evil_plan.fake_sightings = {n.id + ":3": {"who": target.id, "block": "market", "day": 3, "how": "window"}}
	var original = JSON.stringify(g.w.evil_plan.fake_sightings)
	for role in ["nightwatch", "warden", "lamplighter", "medium", "seer"]:
		n.claimed_role = role
		var expected_rng = RandomNumberGenerator.new()
		expected_rng.state = g.w.rng.state
		expected_rng.randi_range(0, 0) # The existing single-option w.pick call.
		var why = Evil.bluff_reason(g.w, n, target)
		check("night 3" in why, "every fake-sighting reason names its stored night")
		check(("duty" in why and not "window" in why) if role != "seer" else "window" in why, "claimed walking duties and window claims have distinct wording")
		check(g.w.rng.state == expected_rng.state and JSON.stringify(g.w.evil_plan.fake_sightings) == original, "wording preserves the existing choice RNG and cached frame")

func _medium_hearths() -> void:
	var g = fresh()
	var w = g.w
	var goods: Array = w.living_good()
	var m = goods[0]
	var older = goods[1]
	var recent = goods[2]
	var executed = goods[3]
	check(w._medium_choice(m) == "", "no Medium visit before any Demon death")
	for victim in [older, recent, executed]:
		victim.alive = false
		victim.beliefs = []
		victim.suspicion = {}
		victim.info_log = []
		victim.warden_log = {}
	older.death_cause = "demon"
	older.death_day = 1
	recent.death_cause = "demon"
	recent.death_day = 2
	executed.death_cause = "executed"
	executed.death_day = 9
	check([w._medium_choice(m), w._medium_choice(m), w._medium_choice(m)] == [recent.id, older.id, recent.id], "only Demon victims are visited; exhausted hearths revisit the newest")
	check(m.medium_visited.size() == 2, "revisits do not duplicate the visited set")
	recent.info_log = [{"role": "seer", "day": 1, "shared": false, "text": "first", "data": {}}, {"role": "seer", "day": 2, "shared": false, "text": "second", "data": {}}]
	var first = w._medium_item(m, recent, false)
	var second = w._medium_item(m, recent, false)
	check(first.type == "reading" and second.type == "reading" and first.entry.text == "first" and second.entry.text == "second", "a revisited hearth can reveal another untold reading")
	check(w._medium_item(m, recent, false).type == "nothing" and w._medium_item(m, older, false).type == "nothing", "exhausted and empty hearths report nothing new")
	var fake = w.minion()
	w.evil_plan.bluffs = {fake.id: "medium"}
	w.evil_plan.scapegoat = goods[4].id
	var state = w.rng.state
	check(Evil._fake_medium_item(w, fake, executed, goods[4].id).is_empty() and w.rng.state == state, "fake reports reject executed hearths without a random choice")
	var visited: Array = []
	for day in [3, 4, 5]:
		w.day = day
		Evil.make_fake_info(w)
		var entries: Array = fake.info_log.filter(func(e): return e.role == "medium" and e.day == day)
		check(entries.size() == 1, "the fake Medium produces one report on a visit/revisit")
		if entries.size() == 1:
			visited.append(entries[0].data.dead)
	check(visited == [recent.id, older.id, recent.id], "fake hearth sequence matches real eligibility and revisits")

func _neutral_opinion() -> void:
	var g = fresh()
	var w = g.w
	var n = w.living_good()[0]
	var t = w.living_good()[1]
	n.traits.gossip = 1.0
	n.traits.insight = 1.0
	n.npc_trust[t.id] = 0.5
	n.workshop_state = {}
	# Find both outcomes of the original roll, then exercise the boundary with
	# identical RNG states. Wording must not alter the draw, level or facts.
	var calm_state: int = 0
	var off_state: int = 0
	var probe = RandomNumberGenerator.new()
	for seed_value in range(1, 100):
		probe.seed = seed_value
		var before: int = probe.state
		if probe.randf() >= 0.2:
			calm_state = before
		else:
			off_state = before
		if calm_state != 0 and off_state != 0:
			break
	for alignment in ["good", "evil"]:
		n.alignment = alignment
		w.evil_plan.scapegoat = w.living_good().back().id
		if n.is_evil():
			Mind.shadow_run(w, n, func(sh): sh.workshop_state = {})
		for level in [0.34, 0.35, 0.44]:
			n.suspicion[t.id] = level
			if n.is_evil():
				n.shadow.suspicion[t.id] = level
			for state in [calm_state, off_state]:
				n.pressed_today = 0
				n.dialogue_memory = {}
				w.rng.state = state
				probe.state = state
				probe.randf()
				var reply = Mind.answer_opinion(w, n, t)
				var text: String = reply.lines[0].text
				check(w.rng.state == probe.state, "neutral wording preserves the original opinion RNG")
				check(Mind.susp(n, t.id) == level, "neutral wording preserves the underlying level")
				if state == off_state:
					check("something's off" in text and reply.facts.size() == 1, "existing suspicious-roll outcome is unchanged")
				else:
					check(("seems all right" in text) if level < 0.35 else (("don't really know %s" % t.name.to_lower()) in text.to_lower() or ("do not really know %s" % t.name.to_lower()) in text.to_lower()), "neutral boundary uses the approved wording for either alignment")
					check(reply.facts.is_empty(), "a neutral or reassuring opinion creates no incriminating fact")

func _distrust() -> void:
	var g = fresh()
	var w = g.w
	var t = w.living_good()[1]
	for n in [w.living_good()[0], w.minion()]:
		n.trust = 0.9
		n.trust_cap = 1.0
		Mind.set_trust(w, n, 0.8, "the Demonologist guessed my gift wrong (seer; 1 wrong so far)")
		Mind.set_trust(w, n, 0.6, "the Demonologist broke their word (ward)")
		Mind.set_trust(w, n, 0.59, "the Demonologist nominated me")
		Mind.set_trust(w, n, 0.1, "private hidden role or alignment reason")
		check(n.distrust_memory.action == "You broke your promise to me.", "largest actual, quotable loss is remembered for both alignments")
		n.traits.gossip = 0.0
		n.pressed_today = 0
		var reply = Mind.answer_opinion(w, n, t)
		check(not reply.lines.is_empty(), "low-gossip townsfolk still answer opinion questions")
		n.traits.privacy = 1.0
		n.max_tier = 0
		n.claim_public = false
		n.pressed_today = 0
		var gift = Mind.answer_gift(w, n)
		check(gift.lines.size() == 2 and "promise" in gift.lines[1].text, "a gift refusal explains the strongest remembered action")
		n.pressed_today = 0
		gift = Mind.answer_gift(w, n)
		check(gift.lines.size() == 1, "a second refusal does not repeat the daily explanation")
		w.day += 1
		n.pressed_today = 0
		gift = Mind.answer_gift(w, n)
		check(gift.lines.size() == 2 and "promise" in gift.lines[1].text, "a gift refusal may explain again the next day")
		n.distrust_memory = {}
		n.distrust_explained_day = -1
		n.pressed_today = 0
		n.secret_mod = ""
		n.secret = {}
		n.claimed_role = ""
		n.beliefs = []
		n.history[w.time_key(1, C.NIGHT)] = "night:market"
		n.traits.confidence = 0.0
		var stonewalled = false
		for seed_value in range(1, 50):
			n.distrust_explained_day = -1
			n.pressed_today = 0
			w.rng.seed = seed_value
			var night = Mind.answer_night(w, n, 1)
			if night.facts.any(func(f): return f.kind == "refusal"):
				stonewalled = true
				check(night.lines.any(func(line): return line is Dictionary and line.get("statement", line.text) == "You're an outsider, I'm not sure I can trust you." and "outsider" in line.text.to_lower() and "trust you" in line.text.to_lower()), "a whereabouts refusal uses the safe outsider fallback")
				break
		check(stonewalled, "whereabouts fixture exercises a refusal for both alignments")
		var lines: Array = []
		n.trust = 0.35
		n.distrust_explained_day = -1
		Mind._append_distrust(w, n, lines)
		check(lines.is_empty() and n.distrust_explained_day == -1, "the low-trust boundary is strictly below 0.35")
		# A clamped request to lose 0.8 from 0.1 must record only 0.1 lost.
		n.trust = 0.1
		Mind.set_trust(w, n, -0.7, "the Demonologist nominated me")
		check(is_equal_approx(n.distrust_memory.loss, 0.1), "memory measures actual clamped trust loss")

func _relationships() -> void:
	var g = fresh()
	var w = g.w
	var people: Array = w.living_good()
	var source = people[0]
	var a = people[1]
	var b = people[2]
	var c = people[3]
	var hidden_lover = people[4]
	check(not w.town_relationships.is_empty() and g.known_relationships.is_empty(), "rolled bonds exist but start undiscovered")
	w.town_relationships = [{"kind": "friend", "people": [a.id, b.id]}, {"kind": "rival", "people": [a.id, c.id]}]
	# Secret modifiers can add a friendship after public bonds were captured.
	a.friends.append(hidden_lover.id)
	a.lover = hidden_lover.id
	hidden_lover.lover = a.id
	a.secret_mod = "lovers"
	source.traits.gossip = 1.0
	source.trust = 1.0
	var probe = RandomNumberGenerator.new()
	var reveal_state: int = 0
	var skip_state: int = 0
	for seed_value in range(1, 100):
		probe.seed = seed_value
		var before = probe.state
		var roll = probe.randf()
		if roll < 0.9 * 0.4:
			reveal_state = before
		elif roll >= 0.9:
			skip_state = before
		if reveal_state != 0 and skip_state != 0:
			break
	var r = {"lines": [], "facts": []}
	w.rng.state = skip_state
	g._maybe_tell_relationships(source, a, r)
	check(g.known_relationships.is_empty() and r.lines.is_empty(), "haunt-equivalent chance can withhold relationship notes")
	w.rng.state = reveal_state
	probe.state = reveal_state
	probe.randf()
	var board_before = JSON.stringify(g.board)
	g._maybe_tell_relationships(source, a, r)
	check(g.known_relationships.size() == 2 and w.rng.state == probe.state, "haunt-equivalent all-notes roll reveals both public bonds with one draw")
	check(r.facts.is_empty() and JSON.stringify(g.board) == board_before, "relationship learning creates profile notes and no evidence")
	var notes: Array = g.profile_data(a.id).relationships
	check(notes.size() == 2 and notes.all(func(text): return text.begins_with(source.name + " says ")), "profile notes retain their attributed source")
	check(g.profile_data(b.id).relationships.size() == 1 and g.profile_data(c.id).relationships.size() == 1, "a learned bond appears on both participants' profiles")
	check(g.profile_data(hidden_lover.id).relationships.is_empty() and not hidden_lover.name in str(notes), "a secret-added Lover friendship is not disclosed")
	var state = w.rng.state
	g._maybe_tell_relationships(source, b, r)
	g._maybe_tell_relationships(source, a, r)
	check(r.lines.size() == 2 and w.rng.state == state, "reverse and repeated questions cannot rediscover a known bond")
	g.new_case(4242, 10)
	check(g.known_relationships.is_empty(), "a new case resets learned relationship notes")
	# Re-run only public setup, then apply a secret modifier: the snapshot must
	# retain exactly the rolled bonds despite subsequent secret friendship edits.
	var public_before = JSON.stringify(g.w.town_relationships)
	g.w.npcs[0].friends.append(g.w.npcs[1].id)
	check(JSON.stringify(g.w.town_relationships) == public_before, "public setup bonds do not alias secret-modifiable friendship arrays")

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

func _trace_subjects() -> void:
	var g = fresh()
	var a: String = g.w.npcs[0].id
	var b: String = g.w.npcs[1].id
	var conversation = {"n": 1, "kind": "conversation", "source": "player", "subject": [a, b], "block": "square", "day": 1, "phase": C.EVENING}
	var trace = {"n": 2, "kind": "trace", "source": "evidence", "subject": [], "block": "square", "day": 1, "phase": C.NIGHT}
	var rng = g.w.rng.state
	for cards in [[conversation, trace], [trace, conversation], [conversation, trace, conversation]]:
		var matches: Array = Argue.check(g.w, cards).matches.filter(func(m): return m.template == "trace_match")
		check(matches.size() == 2 and matches.any(func(m): return m.subject == a) and matches.any(func(m): return m.subject == b), "a trace links both conversation participants, once each, irrespective of input order or repeated receipt")
		check(matches.all(func(m): return m.cards == [1, 2] and m.explanations.size() == 2 and m.explanations[0].id == 1 and m.explanations[1].id == 2), "per-person matches retain original supports and rival explanations")
	check(g.w.rng.state == rng, "subject-aware native dedup uses no randomness")
