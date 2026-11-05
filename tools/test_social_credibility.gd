## Trust and credibility: rapport, NPC-to-NPC trust, stance from belief, gossip and rumour pacing, the shared ledger's weights.
## Merged from: test_backlog_batch2, test_claude_batch, test_fixes, test_phase2_bug_sweep, test_phase3_credibility_and_trust, test_phase4_1_reveal_and_rumor_pacing, test_phase4_3_framing_and_vigil_physics, test_playtest_followups, test_playtest_regressions, test_social_phase2.
extends SceneTree

const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const Presentation = preload("res://game/workshop_presentation.gd")
const Jury = preload("res://workshop/jury.gd")
const Credibility = preload("res://game/credibility.gd")
const Tuning = preload("res://sim/tuning.gd")
const Social = preload("res://sim/social.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_backlog_batch2()
	_run_fixes()
	_run_claude_batch()
	_run_phase2_bug_sweep()
	_run_phase3_credibility_and_t()
	_run_phase4_1_reveal_and_rumo()
	_run_phase4_3_framing_and_vig()
	_run_playtest_followups()
	_run_playtest_regressions()
	_run_social_phase2()
	print("Social: trust and credibility: %d checks, %d failures" % [checks, fails])
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
	_neutral_opinion()
	_distrust()
	_relationships()


# ---------------------------------------------------------------- from test_fixes

func _run_fixes() -> void:
	_offers()


# ---------------------------------------------------------------- from test_claude_batch

func _run_claude_batch() -> void:
	_stance_from_belief()
	_victims_were_sincere()


# ---------------------------------------------------------------- from test_phase2_bug_sweep

func _run_phase2_bug_sweep() -> void:
	_test_2_1_no_gossip_cutoffs()
	_test_2_3_gravedigger_credence_gate()
	_test_2_4_warden_credit_alternatives()


# ---------------------------------------------------------------- from test_phase3_credibility_and_trust

func _run_phase3_credibility_and_t() -> void:
	_test_3_1_delta_confidence_and_proof_retraction_overrides()
	_test_3_2_per_card_source_trust_non_dilution_and_non_laundering()
	_test_3_2_headline_context_aware_repeat_grouping()
	_test_3_3_non_circular_credibility_dawn_and_tiered_weights()


# ---------------------------------------------------------------- from test_phase4_1_reveal_and_rumor_pacing

func _run_phase4_1_reveal_and_rumo() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	_test_knob3_zero_walker_daytime_rumor_fuel()


# ---------------------------------------------------------------- from test_phase4_3_framing_and_vigil_physics

func _run_phase4_3_framing_and_vig() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	_test_single_witness_provenance_and_discount_collapse()


# ---------------------------------------------------------------- from test_playtest_followups

func _run_playtest_followups() -> void:
	spoken_relationships()


# ---------------------------------------------------------------- from test_playtest_regressions

func _run_playtest_regressions() -> void:
	_support_self()
	_public_hearsay_and_self_gossip()


# ---------------------------------------------------------------- from test_social_phase2

func _run_social_phase2() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(4, 10)
	var w = g.w
	var n = w.living_good()[0]
	# Disclosure mood: one sample per NPC per day, no world RNG.
	var state = w.rng.state
	var t1 = MindDialogue._target_tier(w, n)
	var t2 = MindDialogue._target_tier(w, n)
	_check(t1 == t2 and w.rng.state == state, "asking twice the same day gets the same disclosure mood and draws no RNG")
	# Secret-keeping gratitude shrinks.
	n.secret_known = true
	n.secret_spread = false
	n.trust = 0.3
	Mind.end_of_day_trust(w)
	var first: float = n.trust - 0.3
	var mid: float = n.trust
	Mind.end_of_day_trust(w)
	var second: float = n.trust - mid
	_check(first > 0.0 and absf(second - first * Tuning.Trust.SECRET_KEPT_DECAY) < 0.001, "the second night's secret-keeping gain is half the first (%.3f, %.3f)" % [first, second])
	# Gossip bond.
	var l = w.living_good()[1]
	var s = w.living_good()[2]
	var friend = w.living_good()[3]
	l.npc_trust[friend.id] = 0.8
	l.suspicion[s.id] = 0.1
	_check(Social.gossip_bond(l, s, {"kind": "opinion", "about": friend.id}) < 0.0, "running down someone the listener trusts costs the teller")
	_check(Social.gossip_bond(l, s, {"kind": "sighting", "about": w.living_good()[4].id}) > 0.0, "a believed share builds trust in the teller")
	l.suspicion[s.id] = 0.7
	_check(is_zero_approx(Social.gossip_bond(l, s, {"kind": "sighting", "about": w.living_good()[4].id})), "a share from a suspected teller builds nothing")
	# Grief only for a friend the mourner didn't believe evil.
	var ex = w.living_good()[5]
	var mourner = w.living_good()[6]
	mourner.npc_trust[ex.id] = 0.9
	mourner.trust = 0.6
	mourner.suspicion[ex.id] = 0.8
	w._grief(ex, {"by": "player", "yes": []})
	_check(is_equal_approx(mourner.trust, 0.6), "no grief over a friend the mourner believed evil")
	mourner.suspicion[ex.id] = 0.1
	w._grief(ex, {"by": "player", "yes": []})
	_check(mourner.trust < 0.6, "grief over a friend the mourner believed good")
	# Directional Confidence.
	var c: float = 1.4 - 0.8 * 0.9
	_check(is_equal_approx(Jury._directional(c, -0.1, 0.3, false), c), "a confident listener resists clearing someone they lean against")
	_check(is_equal_approx(Jury._directional(c, 0.1, 0.3, false), 1.0), "reinforcing evidence comes through at full strength")
	_check(is_equal_approx(Jury._directional(c, 0.1, 0.01, false), 1.0), "fresh evidence about someone with no lean comes through at full strength")


# ---- test_backlog_batch2


func fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch2_tests"
	g.new_case(4242, 10)
	return g


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


func _offers() -> void:
	var g = _game(7112)
	var w = g.w
	var a = w.living()[0]
	var b = w.living()[1]
	_talk_to(g, a)
	var t0 = a.trust
	g.command("offer vigil")
	_check(a.trust > t0 and g.questions_left == 3, "offering a vigil earns a little trust and costs no question")
	_talk_to(g, b)
	g.command("offer ward")
	var tb = b.trust
	var ta = a.trust
	g.state = "night"
	g.command("ward " + b.id)   # kept the ward, not the vigil
	_check(b.trust > tb, "keeping your word raises trust")
	_check(a.trust < ta - 0.1, "breaking your word costs a lot of trust")
	_check(g.offer.is_empty(), "promises are settled with the night")


# ---- test_claude_batch


func claude_batch__game(sd: int):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 7)
	return g


## One story per evil member per night: a made-up sighting repeats that night's fake watch
## report, never someone else (Constance, 54875).
func _stance_from_belief() -> void:
	_check(Presentation.belief_stance("evil", 0.2, 0.3) == "accept", "a 0.10 rise toward 'evil' is acceptance")
	_check(Presentation.belief_stance("evil", 0.2, 0.23) == "partial", "a 0.03 rise is partial")
	_check(Presentation.belief_stance("evil", 0.2, 0.2) == "reject", "no movement is no")
	_check(Presentation.belief_stance("good", 0.4, 0.3) == "accept", "for 'good', suspicion falling is acceptance")
	var g = claude_batch__game(4401)
	var n = g.w.living_good()[0]
	var t = g.w.living_good()[1]
	n.suspicion[t.id] = 0.32
	var couldnt = "I could not follow your explanation through within what I considered. That does not prove it wrong."
	var said: String = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "reject", couldnt)
	_check(said.begins_with(couldnt) and said.ends_with("Even so, it does change how I see %s." % t.name), "couldn't follow, but moved: the reason stays and the stance follows the belief (%s)" % said)
	n.suspicion[t.id] = 0.2
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "accept", "Taken together, those reports convince me.")
	_check(said == "It holds together, but it doesn't change my mind about %s." % t.name, "convinced in words but unmoved: says so (%s)" % said)
	n.suspicion[t.id] = 0.8
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.8, "accept", "Taken together, those reports convince me. If anything, it points me toward Agnes.")
	_check(said == "If anything, it points me toward Agnes. I'd already come to that about %s." % t.name, "already convinced: says so and keeps the other reasons (%s)" % said)
	n.suspicion[t.id] = 0.3
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "accept", "Taken together, those reports convince me.")
	_check(said == "Taken together, those reports convince me.", "when words and belief agree, the reply is unchanged")
	n.suspicion[t.id] = 0.2
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "accept", "Taken together, those reports convince me.", true)
	_check(said == "I'd already taken that into account.", "a retold case they'd already weighed: says so (%s)" % said)
	said = Presentation._belief_stance_text(g, n, "conflict", t.id, 0.2, "accept", "Those accounts cannot all be accurate.")
	_check(said == "Those accounts cannot all be accurate.", "conflicts are left alone")


## A gift reading against an alibi offers both explanations: the alibi is false (as
## linked) or the report is (a suspected lie). One person's own report against their own
## "I was home" links the same way (54875).
func _victims_were_sincere() -> void:
	var g = claude_batch__game(4431)
	var w = g.w
	var goods: Array = w.living_good()
	var listener = goods[0]
	var victim = goods[1]
	Mind.ledger_hear(w, listener, "arg:lie:" + victim.id, [], 1.0, [], {"kind": "arg", "conclusion": {"type": "lied", "a": victim.id, "night": 1}})
	# The argument says they lied on night 1, so it is that night's word it discounts
	# (source_doubt keys a dated lie to its night).
	var alive_rel: float = Mind.reliability(listener, victim.id, 1, "reading")
	victim.alive = false
	victim.death_cause = "demon"
	w.public_event("demon_death", [victim.id], "")
	Mind.ledger_hear(w, listener, "demon_death:" + victim.id, [], 1.0, [], {"kind": "demon_death", "victim": victim.id})
	var dead_rel: float = Mind.reliability(listener, victim.id, 1, "reading")
	_check(alive_rel < 1.0 and is_equal_approx(dead_rel, 1.0), "a caught-lie argument discounts someone's word (%.2f) until the Demon kills them (%.2f)" % [alive_rel, dead_rel])


# ---- test_phase2_bug_sweep


func _test_2_1_no_gossip_cutoffs() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(92974, 7)
	var n = g.w.living_good()[0]
	var other = g.w.living_good()[1]
	n.traits["gossip"] = 0.05
	n.pressure = 0.0
	n.trust = 0.75
	var op: Dictionary = Mind.answer_opinion(g.w, n, other)
	var statements: Array = op["lines"].map(func(l): return l.get("statement", l.get("text", "")) if l is Dictionary else str(l))
	_check(not statements.any(func(s): return "not my place to say" in s), "low-gossip NPC answers direct opinion question without a 0.20 cutoff")

	# Tavern gossip overhearing also works for low-gossip speakers holding a night sighting.
	for m in g.w.living():
		m.loc = "home"
	n.loc = "tavern"
	n.beliefs = [{"kind": "saw", "who": other.id, "block": "square", "day": 1, "phase": C.NIGHT}]
	n.told_to.clear()
	g.w.day = 2
	var gos: Dictionary = Mind.gossip(g.w)
	_check(gos["facts"].any(func(f): return f.get("kind", "") == "sighting"), "low-gossip speaker in tavern still shares recent night sighting")


func _test_2_3_gravedigger_credence_gate() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var goods: Array = g.w.living_good()
	var listener = goods[0]
	var ex_villager = goods[1]
	var fake_gd = g.w.demon()
	ex_villager.alive = false
	ex_villager.death_day = 1
	ex_villager.death_cause = "executed"
	g.w.executions.append({"day": 1, "id": ex_villager.id, "nominator": "player", "yes": [], "player_yes": true, "player_nominated": true})
	listener.suspicion[fake_gd.id] = 0.55
	listener.friends = [ex_villager.id]
	var trust_before: float = listener.trust
	var entry = {"day": 1, "role": "gravedigger", "data": {"executed": ex_villager.id, "role": "surveyor"}, "fake": true, "shared": true, "text": "Was Surveyor"}
	g.w.on_execution_reading_heard(listener, fake_gd, entry, 1.0)
	_check(is_equal_approx(listener.trust, trust_before), "suspected Gravedigger claim never docks player Rapport")

	# Trusted Gravedigger still does not dock personal Rapport when executed Good villager was not a friend/lover.
	listener.suspicion[fake_gd.id] = 0.05
	listener.npc_trust[fake_gd.id] = 0.75
	listener.friends = []
	listener.lover = ""
	g.w.on_execution_reading_heard(listener, fake_gd, entry, 1.0)
	_check(is_equal_approx(listener.trust, trust_before), "non-friend execution accuracy stays in Credibility.dawn rather than personal Rapport")


func _test_2_4_warden_credit_alternatives() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(4242, 10)
	var w = g.w
	var warden = w.living_good()[0]
	var target = w.living_good()[1]
	var vet_claimant = w.living_good()[2]
	warden.role = "warden"
	w.day = 2
	warden.warden_saves.clear()
	w.public_claims.append({"who": vet_claimant.id, "role": "veteran", "day": 2})
	w._warden_credit(warden, target.id)
	_check(warden.warden_saves.has("2") and is_equal_approx(warden.warden_saves["2"].belief, 0.5), "living public Veteran claim halves Warden quiet-night save belief")

	warden.warden_saves.clear()
	w.player_ward = warden.id
	w._warden_credit(warden, target.id)
	_check(not warden.warden_saves.has("2"), "public Veteran claim plus known player ward lowers Warden save belief below threshold (1/3 < 0.5)")


# ---- test_phase3_credibility_and_trust


func _test_3_1_delta_confidence_and_proof_retraction_overrides() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97931, 10)
	var goods: Array = g.w.living_good()
	var high_conf = goods[0]
	var low_conf = goods[1]
	var seer_src = goods[2]
	var clear_src = goods[3]
	var suspect = goods[4]
	var other = goods[5]

	for listener in [high_conf, low_conf]:
		listener.role = "warden"
		listener.info_log = []
		listener.applied_info = 0
		listener.ledger.clear()
		listener.workshop_state.clear()
		listener.traits.insight = 0.85
		for id in listener.suspicion:
			listener.suspicion[id] = Tuning.Setup.INITIAL_SUSPICION_BASE
		for id in listener.npc_trust:
			listener.npc_trust[id] = 0.85
	high_conf.traits.confidence = 0.95
	low_conf.traits.confidence = 0.10

	# Day 1: present an accusing Dowser report against `suspect` to both listeners.
	var c_evil: int = g.add_card({
		"kind": "info", "source": seer_src.id, "role": "dowser",
		"day": 1, "phase": 0, "data": {"group": [suspect.id], "count": 1},
		"text": "%s dowser 1/1 on %s" % [seer_src.id, suspect.id],
	})
	var ded_evil: int = g.file_deduction({"type": "evil", "a": suspect.id}, [c_evil])
	g._evaluate_deduction(high_conf, g.board[ded_evil - 1], 1.0, false)
	g._evaluate_deduction(low_conf, g.board[ded_evil - 1], 1.0, false)
	var d1_req_hi: float = float(high_conf.workshop_state.requested.get(suspect.id, 0.0))
	var d1_req_lo: float = float(low_conf.workshop_state.requested.get(suspect.id, 0.0))
	_check(d1_req_hi > 0.10 and is_equal_approx(d1_req_hi, d1_req_lo),
		"Day 1 fresh evidence lands equally on high- and low-Confidence listeners before dawn commitment (%.4f vs %.4f)" % [d1_req_hi, d1_req_lo])

	# Simulate Night 1 dawn freeze (same logic as Game._resolve_night).
	for listener in [high_conf, low_conf]:
		listener.workshop_state["committed_lean"] = Mind.suspicion_view(listener).duplicate(true)
		listener.workshop_state["committed_requested"] = listener.workshop_state.get("requested", {}).duplicate(true)
	g.w.day = 2

	# Day 2: introduce competing clearing Dowser report on `suspect` from a second source.
	var c_clear: int = g.add_card({
		"kind": "info", "source": clear_src.id, "role": "dowser",
		"day": 2, "phase": 0, "data": {"group": [suspect.id], "count": 0},
		"text": "%s dowser 0/1 on %s" % [clear_src.id, suspect.id],
	})
	var ded_clear: int = g.file_deduction({"type": "good", "a": suspect.id}, [c_clear])
	g._evaluate_deduction(high_conf, g.board[ded_clear - 1], 1.0, false)
	g._evaluate_deduction(low_conf, g.board[ded_clear - 1], 1.0, false)
	var d2_req_hi: float = float(high_conf.workshop_state.requested.get(suspect.id, 0.0))
	var d2_req_lo: float = float(low_conf.workshop_state.requested.get(suspect.id, 0.0))
	_check(d2_req_hi > d2_req_lo + 0.01,
		"Day 2 contrary evidence damps delta on high-Confidence listener (%.4f vs %.4f)" % [d2_req_hi, d2_req_lo])

	# A profile receipt can remain held without providing standalone guilt evidence.
	var home: int = g.add_card({"kind": "home", "source": "town", "subject": [suspect.id], "block": suspect.home_block, "text": "Known home of " + suspect.id})
	var profile_case: int = g.file_deduction({"type": "evil", "a": suspect.id}, [home])
	g._evaluate_deduction(high_conf, g.board[profile_case - 1], 1.0, false)
	# Sole-case retraction override: retracting both presentations snaps requested to 0.0 with zero phantom residue!
	g.workshop_retract(ded_evil, high_conf.id)
	g.workshop_retract(ded_clear, high_conf.id)
	_check(is_zero_approx(float(high_conf.workshop_state.get("requested", {}).get(suspect.id, 0.0))),
		"withdrawing all supporting presentations snaps requested to exact 0.0 despite prior committed_requested")

	# Hard public proof override: Martyr proof clears stubborn high-Confidence listener immediately to 0.0 suspicion.
	g._evaluate_deduction(high_conf, g.board[ded_evil - 1], 1.0, false)
	high_conf.workshop_state["committed_lean"] = Mind.suspicion_view(high_conf).duplicate(true)
	high_conf.workshop_state["committed_requested"] = high_conf.workshop_state.get("requested", {}).duplicate(true)
	g.w.public_log.append({"day": 2, "kind": "martyr", "subjects": [suspect.id, other.id], "by": other.id})
	Mind.refresh_beliefs(g.w, high_conf, "public Martyr proof")
	_check(is_zero_approx(float(high_conf.suspicion.get(suspect.id, 1.0))),
		"public Martyr proof overrides high-Confidence committed_requested and clears target to 0.0")


func _test_3_2_per_card_source_trust_non_dilution_and_non_laundering() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(92974, 7)
	var goods: Array = g.w.living_good()
	var seer = goods[0]
	var rumor_teller = goods[1]
	var suspect = goods[2]
	var partner = goods[3]
	var extra = goods[4]

	seer.role = "seer"
	seer.info_log = [{"day": 1, "role": "seer", "data": {"pair": [suspect.id, partner.id], "yes": true}, "true": true, "shared": false, "text": "own seer yes"}]
	seer.applied_info = 0
	seer.ledger.clear()
	seer.workshop_state.clear()
	seer.npc_trust[rumor_teller.id] = 0.15
	Mind.update_from_own_info(g.w)
	var base_req: float = float(seer.workshop_state.requested.get(suspect.id, 0.0))
	_check(base_req > 0.0, "firsthand Seer YES reading produces positive requested shift (%.4f)" % base_req)

	# Rumor non-dilution: hearing a 0.15-trust rumor implicating `suspect` must NEVER weaken `seer`'s firsthand belief!
	var rumor_entry = {"day": 1, "phase": 0, "role": "dowser", "data": {"group": [suspect.id, extra.id], "count": 1}, "text": "untrusted dowser rumor"}
	Mind.apply_info(g.w, seer, rumor_teller, rumor_entry, 0.5)
	var after_rumor_req: float = float(seer.workshop_state.requested.get(suspect.id, 0.0))
	_check(after_rumor_req >= base_req - 0.0001,
		"adding a 0.15-trust corroborating rumor never dilutes a 1.0-trust firsthand reading (%.4f -> %.4f)" % [base_req, after_rumor_req])

	# Rumor non-laundering: compare a 0.10-trust source vs a 0.95-trust source on the same heard reading.
	var listener_lo = goods[4]
	var listener_hi = goods[5] if goods.size() > 5 else g.w.npcs.filter(func(p): return p not in [seer, rumor_teller, suspect, partner, listener_lo])[0]
	for l in [listener_lo, listener_hi]:
		l.alignment = "good"
		l.role = "warden"
		l.info_log = []
		l.applied_info = 0
		l.ledger.clear()
		l.workshop_state.clear()
		l.traits.insight = 0.8
	listener_lo.npc_trust[rumor_teller.id] = 0.10
	listener_hi.npc_trust[rumor_teller.id] = 0.95
	var single_rumor = {"day": 1, "phase": 0, "role": "dowser", "data": {"group": [suspect.id], "count": 1}, "text": "single dowser"}
	Mind.apply_info(g.w, listener_lo, rumor_teller, single_rumor, 0.5)
	Mind.apply_info(g.w, listener_hi, rumor_teller, single_rumor, 0.5)
	var lo_req: float = float(listener_lo.workshop_state.requested.get(suspect.id, 0.0))
	var hi_req: float = float(listener_hi.workshop_state.requested.get(suspect.id, 0.0))
	_check(hi_req > lo_req + 0.04,
		"per-card npc_trust scales heard report strength monotonically without laundering low-trust rumors (lo %.4f vs hi %.4f)" % [lo_req, hi_req])

	# Presenting the exact report already independently heard must not endorse it twice.
	var known_card: Dictionary = single_rumor.duplicate(true)
	known_card.merge({"kind": "info", "source": rumor_teller.id, "subject": [suspect.id]})
	var known_num: int = g.add_card(known_card)
	var repeated_case: int = g.file_deduction({"type": "evil", "a": suspect.id}, [known_num])
	listener_lo.credibility = 0.9
	g._evaluate_deduction(listener_lo, g.board[repeated_case - 1], 1.0, false)
	var endorsed_req: float = float(listener_lo.workshop_state.requested.get(suspect.id, 0.0))
	_check(is_equal_approx(lo_req, endorsed_req), "player endorsement cannot boost an independently heard low-trust report")
	listener_lo.credibility = 0.1
	Mind.refresh_beliefs(g.w, listener_lo, "player credibility changed")
	_check(is_equal_approx(endorsed_req, float(listener_lo.workshop_state.requested.get(suspect.id, 0.0))), "player credibility changes do not reweight independently heard reports")


func _test_3_2_headline_context_aware_repeat_grouping() -> void:
	var view: Dictionary = {
		"people": [{"id": "a"}, {"id": "b"}, {"id": "s1"}, {"id": "s2"}],
		"timeline": {"executions": {}},
	}
	var listener: Dictionary = {
		"id": "l", "trust": 0.8, "player_credibility": 0.8,
		"npc_trust": {"s1": 0.9, "s2": 0.9},
		"knowledge": {"own_reports": []},
	}
	var eval_listener: Dictionary = {
		"id": "l", "reading_reliability": {"c1": 0.95, "c2": 0.95, "c3": 0.95},
		"knowledge": {"own_reports": []},
	}
	var c1: Dictionary = {"id": "c1", "kind": "report", "source": "s1", "role": "seer", "night": 1,
		"observed_at": {"day": 1, "phase": "night"}, "data": {"pair": ["a", "b"], "yes": true}}
	var c2_same_seer: Dictionary = {"id": "c2", "kind": "report", "source": "s1", "role": "seer", "night": 2,
		"observed_at": {"day": 2, "phase": "night"}, "data": {"pair": ["b", "a"], "yes": true}}
	var c3_second_seer: Dictionary = {"id": "c3", "kind": "report", "source": "s2", "role": "seer", "night": 2,
		"observed_at": {"day": 2, "phase": "night"}, "data": {"pair": ["a", "b"], "yes": true}}

	var h_single: float = Jury._headline(view, [c1], "a", 0.25, listener, eval_listener, false)
	var h_repeat: float = Jury._headline(view, [c1, c2_same_seer], "a", 0.25, listener, eval_listener, false)
	var h_two_sources: float = Jury._headline(view, [c1, c3_second_seer], "a", 0.25, listener, eval_listener, false)
	_check(h_repeat > h_single and (h_repeat - h_single) < 0.35 * (h_two_sources - h_single),
		"same-Seer same-epoch repeat gets only diminishing confirmation bump while two distinct claimants combine fully (%.4f, %.4f, %.4f)" % [h_single, h_repeat, h_two_sources])

	# Across a Day 2 execution (potential Scion promotion), Night 1 and Night 2 checks belong to distinct epochs!
	var view_exec: Dictionary = view.duplicate(true)
	view_exec.timeline.executions = {2: "x"}
	var h_post_exec: float = Jury._headline(view_exec, [c1, c2_same_seer], "a", 0.25, listener, eval_listener, false)
	_check(h_post_exec > h_repeat + 0.02,
		"checks separated by a public execution land in distinct scion_epochs and are not collapsed as stale repeats (%.4f vs %.4f)" % [h_post_exec, h_repeat])


func _test_3_3_non_circular_credibility_dawn_and_tiered_weights() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var goods: Array = g.w.living_good()
	var uninformed = goods[0]
	var suspect = goods[1]
	var innocent = goods[2]
	var witness = goods[3]

	# Clear uninformed listener's private gifts so they genuinely hold zero independent evidence on `suspect`.
	uninformed.role = "warden"
	uninformed.info_log = []
	uninformed.applied_info = 0
	uninformed.ledger.clear()
	uninformed.workshop_state.clear()
	Mind.refresh_beliefs(g.w, uninformed, "clean uninformed baseline")

	# 1) Detective Penalty check: player records an accusation on `suspect` before `uninformed` knows anything.
	uninformed.credibility = 0.5
	Credibility.record(uninformed, "evil", suspect.id, 1, Tuning.Trust.CRED_WEIGHT_FORMAL)
	Credibility.dawn(g)
	_check(is_equal_approx(uninformed.credibility, 0.5),
		"uninformed villager abstains at Dawn with zero Detective Penalty (credibility stays %.3f)" % uninformed.credibility)

	# 2) Self-validation circularity check: player presents a cherry-picked case to `uninformed`;
	# `uninformed` still has zero *independent* evidence, so Dawn must NOT self-validate the player's own case!
	var cherry: int = g.add_card({
		"kind": "info", "source": witness.id, "role": "dowser",
		"day": 1, "phase": 0, "data": {"group": [innocent.id], "count": 1},
		"text": "cherry-picked report",
	})
	var ded_cherry: int = g.file_deduction({"type": "evil", "a": innocent.id}, [cherry])
	g._evaluate_deduction(uninformed, g.board[ded_cherry - 1], 1.0, false)
	Credibility.dawn(g)
	_check(is_equal_approx(uninformed.credibility, 0.5),
		"player-presented case never circularly self-validates at Dawn without independent corroboration (credibility %.3f)" % uninformed.credibility)

	# 3) Independent corroboration vindicates the player: `uninformed` independently hears `witness`'s reading!
	uninformed.claim_record = {}
	uninformed.credibility = 0.5
	Credibility.record(uninformed, "evil", innocent.id, 1, Tuning.Trust.CRED_WEIGHT_FORMAL)
	Mind.apply_info(g.w, uninformed, witness, {"day": 1, "phase": 0, "role": "dowser", "data": {"group": [innocent.id], "count": 1}, "text": "independent dowser"}, 0.5)
	Credibility.dawn(g)
	_check(uninformed.credibility > 0.52,
		"independent corroboration moves posterior past CRED_CORROBORATION_MIN and raises Credibility at Dawn (%.3f)" % uninformed.credibility)

	# 4) Tiered claim weights: 1.0 formal deduction/nomination outweighs 0.35 casual statement,
	# and a same-direction 0.35 statement never downgrades an existing 1.0 formal claim!
	var victim = goods[4]
	g.w.public_event("demon_death", [victim.id], "town")
	g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "day": 1, "phase": C.NIGHT, "night": 1, "block": victim.home_block, "text": "Death"})
	Mind.refresh_beliefs(g.w, uninformed, "public demon death")

	uninformed.claim_record = {}
	uninformed.credibility = 0.5
	Credibility.record(uninformed, "evil", innocent.id, 1, Tuning.Trust.CRED_WEIGHT_FORMAL)
	Credibility.record(uninformed, "evil", innocent.id, 1, Tuning.Trust.CRED_WEIGHT_STATEMENT)
	_check(is_equal_approx(float(uninformed.claim_record[innocent.id].weight), Tuning.Trust.CRED_WEIGHT_FORMAL),
		"same-direction casual statement never downgrades existing formal 1.0 claim weight")

	var c_equal_test: float
	uninformed.claim_record = {
		innocent.id: {"type": "evil", "day": 1, "weight": Tuning.Trust.CRED_WEIGHT_FORMAL},
		victim.id: {"type": "evil", "day": 1, "weight": Tuning.Trust.CRED_WEIGHT_FORMAL},
	}
	uninformed.credibility = 0.5
	Credibility.dawn(g)
	c_equal_test = uninformed.credibility

	uninformed.claim_record = {
		innocent.id: {"type": "evil", "day": 1, "weight": Tuning.Trust.CRED_WEIGHT_FORMAL},
		victim.id: {"type": "evil", "day": 1, "weight": Tuning.Trust.CRED_WEIGHT_STATEMENT},
	}
	uninformed.credibility = 0.5
	Credibility.dawn(g)
	_check(uninformed.credibility > c_equal_test + 0.03,
		"0.35 casual statement mistake docks Credibility substantially less than a 1.0 formal claim mistake (%.3f vs %.3f)" % [uninformed.credibility, c_equal_test])


# ---- test_phase4_1_reveal_and_rumor_pacing


func _test_knob3_zero_walker_daytime_rumor_fuel() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var speaker = goods[0]
	var listener = goods[1]
	var third = goods[2]

	# Strip all night sightings, private gifts, secrets, and strong (>= 0.5) opinions to mimic a zero-walker Revenant+Scion drought.
	for p in [speaker, listener]:
		p.role = "veteran"
		p.info_log = []
		p.applied_info = 0
		p.secret = {}
		p.known_secrets = {}
		p.hearsay = []
		p.player_cases = []
		p.beliefs = []
		p.told_to = {}
		p.ledger.clear()
		for id in p.suspicion:
			p.suspicion[id] = 0.20

	w.day = 2
	w.phase = C.MORNING
	speaker.traits["gossip"] = 0.85
	# Routines alone cannot become observations, including when memories are stale.
	for memory in [[], [{"kind": "saw", "who": third.id, "loc": "bakery", "block": w.loc_block("bakery"), "day": 0, "phase": C.MORNING}]]:
		speaker.beliefs = memory
		var invented: bool = false
		for _attempt in range(30):
			var candidate = Social._pick_item(w, speaker, listener)
			invented = invented or (candidate != null and candidate.kind == "day_sighting")
		_check(not invented, "missing or stale observations never generate a sighting from work/haunt routines")
	speaker.beliefs = []
	third.work = "bakery"
	speaker.beliefs.append({"kind": "saw", "who": third.id, "loc": "bakery", "block": w.loc_block("bakery"), "day": 2, "phase": C.MORNING})

	# Seeing someone at their workplace establishes presence, not that they worked.
	var witnessed: Dictionary = {}
	for _attempt in range(30):
		var candidate = Social._pick_item(w, speaker, listener)
		if candidate != null and candidate.kind == "day_sighting":
			witnessed = candidate
			break
	_check(not witnessed.is_empty() and witnessed.about == third.id and witnessed.loc == "bakery" and witnessed.day == 2 and witnessed.phase == C.MORNING, "daytime rumor preserves the witnessed person, location and time")
	var wording: String = Social._describe(w, speaker, witnessed) if not witnessed.is_empty() else ""
	_check("was seen at" in wording and not "working" in wording and not "keeping to" in wording, "a witnessed visit does not invent work or habitual activity")
	var ledger_before: String = JSON.stringify(listener.ledger)
	var trust_before: float = float(listener.npc_trust.get(speaker.id, 0.5))
	var shares_before: int = w.dlog.entries.filter(func(e): return e["type"] == "npc_share").size()

	var delivered_count: int = 0
	for _i in range(25):
		speaker.told_to.clear()
		var picked = Social._pick_item(w, speaker, listener)
		if picked != null:
			_check(picked["kind"] in ["day_sighting", "unease"], "zero-walker pick produces daytime sighting or unease item (%s)" % str(picked["kind"]))
			Social._deliver(w, speaker, listener, picked)
			delivered_count += 1
			break

	var shares_after: int = w.dlog.entries.filter(func(e): return e["type"] == "npc_share").size()
	var trust_after: float = float(listener.npc_trust.get(speaker.id, 0.5))
	_check(delivered_count == 1 and shares_after == shares_before + 1,
		"Social._pick_item and _deliver emit npc_share in a zero-walker drought")
	_check(trust_after > trust_before,
		"believed daytime work/haunt share builds positive gossip_bond (%.3f -> %.3f)" % [trust_before, trust_after])
	_check(JSON.stringify(listener.ledger) == ledger_before,
		"daytime work/haunt share adds zero alignment suspicion entries to listener.ledger")

	if not witnessed.is_empty():
		Social._deliver(w, speaker, listener, witnessed)
	var repeated: bool = false
	for _attempt in range(30):
		var candidate = Social._pick_item(w, speaker, listener)
		repeated = repeated or (candidate != null and candidate.kind == "day_sighting")
	_check(not repeated, "an already shared observation cannot trigger an invented routine replacement")

	w.phase = C.AFTERNOON
	speaker.beliefs = [{"kind": "saw", "who": third.id, "loc": "", "block": "hill", "day": 2, "phase": C.AFTERNOON}]
	var block_only: Dictionary = {}
	for _attempt in range(30):
		var candidate = Social._pick_item(w, speaker, listener)
		if candidate != null and candidate.kind == "day_sighting":
			block_only = candidate
			break
	_check(not block_only.is_empty() and block_only.loc == "" and block_only.block == "hill" and "during the day" in Social._describe(w, speaker, block_only), "a block-only observation never acquires a workplace or haunt location")


# ---- test_phase4_3_framing_and_vigil_physics


func _test_single_witness_provenance_and_discount_collapse() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(44814, 10)
	var w = g.w
	w.day = 2
	var planter = w.evil_team()[0]
	var goods: Array = w.living_good()
	var gossip_b = goods[0]
	var gossip_d = goods[1]
	var listener_c = goods[2]
	var target = goods[3]
	for n in [gossip_b, gossip_d, listener_c]:
		n.info_log = []
		n.known_claims = {}
		n.ledger = {}
		n.beliefs = []
		n.hearsay = []
		n.discounted = {}
		n.npc_trust[planter.id] = 0.55
	listener_c.npc_trust[gossip_b.id] = 0.85
	listener_c.npc_trust[gossip_d.id] = 0.85

	var direct_sight = {"kind": "sighting", "about": target.id, "block": "market", "day": 1, "from": planter.id, "key": "sighting:%s:1" % target.id, "lie": true}
	Social._deliver(w, planter, gossip_b, direct_sight)
	Social._deliver(w, planter, gossip_d, direct_sight)

	var relay_from_b = direct_sight.duplicate(true)
	relay_from_b["relay"] = true
	relay_from_b["key"] = "relay:" + direct_sight["key"]
	Social._deliver(w, gossip_b, listener_c, relay_from_b)
	var susp_after_one_relay: float = Mind.susp(listener_c, target.id)
	var sight_keys: Array = listener_c.ledger.keys().filter(func(k): return str(k).begins_with("heard:"))
	_check(sight_keys.size() == 1, "relayed sighting creates a single ledger entry on listener C")
	var eid: String = sight_keys[0]
	_check(listener_c.ledger[eid].get("rel", ["?"])[0] == planter.id,
		"relayed sighting preserves original witness A in rel[0] (%s), never relayer B (%s)" % [str(listener_c.ledger[eid].get("rel", ["?"])[0]), gossip_b.id])

	# Second Good gossip D relays the exact same sighting from A -> must NOT duplicate or stack!
	var relay_from_d = relay_from_b.duplicate(true)
	Social._deliver(w, gossip_d, listener_c, relay_from_d)
	var receipt_id: String = listener_c.ledger[eid].meta.workshop_card.id
	_check(listener_c.workshop_state.facts.count(receipt_id) == 1 and absf(Mind.susp(listener_c, target.id) - susp_after_one_relay) < 0.005,
		"second relayer recounting planter A's sighting produces 1 receipt.id and zero stacked suspicion")

	# Catching/discounting original planter A collapses hearing_weight on listener C despite high trust in B & D!
	Mind.refresh_beliefs(w, listener_c, " (planter caught)")
	listener_c.workshop_state["source_doubt"][planter.id + ":*"] = 1.0
	var plan = Shared.prepare(g.workshop_snapshot([], listener_c.id), {}, listener_c.ledger)
	var card_after: Dictionary = plan.prepared.view.cards.filter(func(c): return c.id == receipt_id)[0]
	_check(is_zero_approx(float(card_after.get("hearing_weight", 1.0))),
		"discounting original witness A collapses relayed sighting hearing_weight to 0.0 (got %.4f)" % float(card_after.get("hearing_weight", 1.0)))


# ---- test_playtest_followups


func playtest_followups__fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://followup_tests"
	g.new_case(4242, 10)
	return g


func spoken_relationships():
	var g = playtest_followups__fresh()
	var w = g.w
	var n = w.living_good()[0]
	var t = w.living_good()[1]
	g.known_relationships = {}
	n.npc_trust[t.id] = 0.9
	n.suspicion[t.id] = 0.0
	var reply = Mind.answer_opinion(w, n, t)
	var rng = w.rng.state
	var cards = JSON.stringify(g.board)
	g._lines(reply.lines)
	check(g.known_relationships.size() == 1 and g.known_relationship_notes(n.id) == g.known_relationship_notes(t.id), "explicit closeness in an opinion populates both profiles")
	var note: Dictionary = g.known_relationships.values()[0]
	check(note.kind == "friend" and note.source == n.id and str(note.text).contains(n.name), "spoken friendship remains an attributed claim")
	g._lines(reply.lines)
	check(g.known_relationships.size() == 1 and w.rng.state == rng and JSON.stringify(g.board) == cards, "repeated disclosure neither duplicates notes nor adds cards, beliefs or RNG")
	g.known_relationships = {}
	t.alive = false
	var line = Mind.say(n, "%s is my friend. You'll need more than that." % t.name)
	line["relationship"] = {"kind": "friend", "people": [n.id, t.id]}
	g._line(line)
	check(not g.known_relationship_notes(t.id).is_empty(), "an explicit bond to a dead NPC can still be learned")
	g.known_relationships = {}
	g._line(Mind.say(n, "I have my doubts about %s." % t.name))
	check(g.known_relationships.is_empty(), "distrust is not silently promoted to a rival relationship")
	for kind in ["friend", "rival"]:
		g.known_relationships = {"existing": {"kind": kind, "people": [t.id, n.id], "source": n.id, "text": "Earlier attributed disclosure"}}
		line.relationship = {"kind": kind, "people": [n.id, t.id]}
		g._line(line)
		check(g.known_relationships.size() == 1 and g.known_relationships.existing.text == "Earlier attributed disclosure", "existing attributed bonds deduplicate independently of pair order")


# ---- test_playtest_regressions


func playtest_regressions__game():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(25923, 10)
	return g


func _support_self() -> void:
	var g = playtest_regressions__game()
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


func _public_hearsay_and_self_gossip() -> void:
	var g = playtest_regressions__game()
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
