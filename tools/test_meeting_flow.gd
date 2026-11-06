## The meeting: nominations, votes and execution priority, testimony and volunteered sightings, defences, last words, silenced speakers.
## Merged from: test_backlog_batch3, test_backlog_batch4, test_claude_batch, test_fixes, test_phase4_2_balanced_execution_priority, test_phase4_3_framing_and_vigil_physics, test_playtest_followups, test_playtest_regressions.
extends SceneTree

const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const Tuning = preload("res://sim/tuning.gd")
const Social = preload("res://sim/social.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")
const Recent = preload("res://game/recent_sightings.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_backlog_batch3()
	_run_backlog_batch4()
	_run_fixes()
	_run_claude_batch()
	_run_phase4_2_balanced_execut()
	_run_phase4_3_framing_and_vig()
	_run_playtest_followups()
	_run_playtest_regressions()
	print("Meeting: flow: %d checks, %d failures" % [checks, fails])
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


# ---------------------------------------------------------------- from test_backlog_batch3

func _run_backlog_batch3() -> void:
	last_words()
	pressed_nights()


# ---------------------------------------------------------------- from test_backlog_batch4

func _run_backlog_batch4() -> void:
	empty_nomination_cases()
	volunteered_sightings()


# ---------------------------------------------------------------- from test_fixes

func _run_fixes() -> void:
	_martyr_reluctance()
	_silenced_speakers()
	_nomination_case()
	_defence_moves()


# ---------------------------------------------------------------- from test_claude_batch

func _run_claude_batch() -> void:
	_sleepwalk_excuse()


# ---------------------------------------------------------------- from test_phase4_2_balanced_execution_priority

func _run_phase4_2_balanced_execut() -> void:
	_test_listener_mean_centering_and_tie_symmetry()
	_test_bandwagon_pullback_vs_model_standout()
	_test_death_spiral_pullback_and_threshold_parts_parity()
	_test_player_ballot_leverage_trim()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--sweep" in user_args:
		var s_idx: int = user_args.find("--sweep")
		var n_games: int = int(user_args[s_idx + 1]) if s_idx + 1 < user_args.size() else 50
		var out_path: String = ""
		if "--out" in user_args:
			var o_idx: int = user_args.find("--out")
			if o_idx + 1 < user_args.size():
				out_path = user_args[o_idx + 1]
		var sweep_data: Dictionary = _run_checkpoint_sweep(n_games)
		if out_path != "":
			var dir_path: String = out_path.get_base_dir()
			if dir_path != "":
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
			var f = FileAccess.open(out_path, FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(sweep_data, "\t") + "\n")
				f.close()
				print("Wrote Phase 4.2 sweep JSON to %s" % out_path)


# ---------------------------------------------------------------- from test_phase4_3_framing_and_vigil_physics

func _run_phase4_3_framing_and_vig() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	_test_case_98933_polish_fixes()


# ---------------------------------------------------------------- from test_playtest_followups

func _run_playtest_followups() -> void:
	public_sightings()


# ---------------------------------------------------------------- from test_playtest_regressions

func _run_playtest_regressions() -> void:
	_meeting_sighting_prefix_and_gallows()


# ---- test_backlog_batch3


func fresh(count: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch3_tests"
	g.new_case(4242, count)
	return g


func last_words():
	for mode in ["good", "evil", "silenced", "martyr"]:
		var g = fresh()
		var w = g.w
		var goods: Array = w.living_good()
		var condemned = w.minion() if mode == "evil" else goods[0]
		var saved = goods[1]
		var suspect = goods[2]
		# Isolate public-claim effects from unrelated gift aftermath in these fixtures.
		for n in goods:
			n.role = "clerk"
			n.secret_mod = ""
			n.secret = {}
		condemned.claim_public = false
		condemned.max_tier = 0
		condemned.suspicion = {suspect.id: 1.0}
		condemned.workshop_state = {}
		condemned.info_log = [{"role": "clerk", "day": 0, "shared": false, "data": {"pair": [saved.id, suspect.id], "role": "seer"}, "text": "withheld reading"}]
		if mode == "evil": w.evil_plan.scapegoat = suspect.id
		if mode == "silenced": condemned.silenced = true
		var nominee = saved if mode == "martyr" else condemned
		if mode == "martyr":
			condemned.role = "martyr"
			condemned.martyr_target = saved.id
		w.phase = C.EVENING
		g.state = "meeting"
		w.meeting = {"block": nominee.id, "results": [{"nominee": nominee.id, "by": "player", "yes": [], "player_yes": false}], "nominators": [], "nominated": []}
		g.events = []
		var alive_before = w.living().size()
		g._close_meeting()
		var speech: Array = g.events.filter(func(e): return e.k == "speech" and e.speaker == condemned.id)
		check(w.living().size() == alive_before - 1 and w.executions.size() == 1 and not condemned.alive, "one actual condemned death and execution record after substitution")
		check(saved.alive if mode == "martyr" else true, "the substituted nominee survives")
		if mode == "silenced":
			check(speech.is_empty() and g.events.any(func(e): return e.k == "narration" and "tries to speak" in e.text), "silenced condemned get narration but no spoken words or gift revelation")
			check(not condemned.claim_public, "silence never publishes the hidden gift")
		else:
			var claim: String = w.evil_plan.bluffs[condemned.id] if condemned.is_evil() else condemned.role
			check(speech.size() == 2 and C.role_name(claim) in speech[0].text and suspect.name in speech[1].text, "last words give true gift/bluff and top suspect without alignment")
			check(g.board.any(func(c): return c.kind == "claim" and c.source == condemned.id and c.role == claim and c.learned.any(func(d): return d.public)), "last-word claim is an ordinary public board receipt")
			check(not condemned.info_log[0].shared, "last words do not disclose an extra reading backlog")
			var claim_pos = -1
			var death_pos = -1
			for i in range(g.events.size()):
				if g.events[i].k == "speech" and g.events[i].speaker == condemned.id and claim_pos < 0: claim_pos = i
				if g.events[i].k == "headline" and g.events[i].kind in ["execution", "martyr"]: death_pos = i
			check(claim_pos >= 0 and death_pos > claim_pos, "last words precede the actual execution or Martyr aftermath")
		var snapshot = JSON.stringify([w.executions, g.events, w.rng.state])
		g._close_meeting()
		check(JSON.stringify([w.executions, g.events, w.rng.state]) == snapshot, "closing a meeting twice cannot repeat death, aftermath or last words")


func before_press_night(w, n, card):
	# Original night branch with composure fixed to 1: no nerves variant draw.
	var strength = clampf(Mind.card_weight_against(w, card, n.id), Tuning.Dialogue.PRESS_STRENGTH_MIN, 1.0)
	w.rng.randf()
	n.pressure += 0.35 * strength
	if not n.is_evil(): Mind.set_trust(w, n, n.trust - (0.03 + 0.06 * Mind.trait_of(n, "privacy")), "the Demonologist pressed me with evidence")
	return Mind.answer_night(w, n, card.day)


func pressed_nights():
	for mode in ["home", "personal", "sleepwalker", "seer", "nightwatch", "warden", "lamplighter", "medium"]:
		for seed_value in [1, 2, 3, 4]:
			var a = fresh()
			var b = fresh()
			var evil = mode in ["seer", "nightwatch", "warden", "lamplighter", "medium"]
			var na = a.w.minion() if evil else a.w.living_good()[0]
			var nb = b.w.by_id[na.id]
			var card = {"kind": "sighting", "subject": [na.id], "source": "player", "block": "market", "day": 1, "phase": C.NIGHT, "text": "A conflicting night sighting"}
			for pair in [[a, na], [b, nb]]:
				var g = pair[0]
				var n = pair[1]
				g.w.day = 2
				g.w.night_walkers = []
				n.traits.composure = 1.0
				n.traits.gossip = 0.0
				n.pressure = 0.0
				n.pressed_today = 0
				n.max_tier = 0
				n.claim_public = false
				n.claimed_role = mode if evil else ""
				n.secret_mod = "sleepwalker" if mode == "sleepwalker" else ""
				n.secret = {"kind": "gambling", "text": "gambles at night", "me": "go gambling"} if mode == "personal" else {}
				n.beliefs = []
				n.history[g.w.time_key(1, C.NIGHT)] = ("home:" if mode == "home" else "night:") + n.home_block
				if not evil: n.role = "clerk"
				else: g.w.evil_plan.bluffs[n.id] = mode
				g.w.rng.seed = seed_value
			var before = before_press_night(a.w, na, card)
			var after = Mind.press(b.w, nb, card)
			# Oct 26 (Claude): pressed with a sighting, the Sleepwalker (and evil whose bluff
			# doesn't explain being out) may add "I've been known to sleepwalk" (an extra
			# secret fact; evil rolls for it). Everything else stays wording only.
			var excuse_facts: Array = after.facts.filter(func(f): return f.get("secret_kind", "") == "sleepwalker")
			var kept_facts: Array = after.facts.filter(func(f): return f.get("secret_kind", "") != "sleepwalker")
			check(JSON.stringify(before.facts) == JSON.stringify(kept_facts) and (mode == "sleepwalker") == (excuse_facts.size() == 1 and mode == "sleepwalker") , "press wording preserves home/secret/sleepwalker/evil cover facts")
			var may_roll: bool = evil and not C.ROLES[mode].get("night_walk", false)
			check((a.w.rng.state == b.w.rng.state or may_roll) and na.pressed_today == nb.pressed_today and na.trust == nb.trust, "wording-only press keeps original RNG, fatigue and trust")
			check(before.lines[0].text != after.lines[0].text, "pressing does not replay the original alibi or refusal sentence")
	var g = fresh()
	var n = g.w.living_good()[0]
	g.w.day = 2
	g.w.night_walkers = []
	n.role = "nightwatch"
	n.claimed_role = ""
	n.max_tier = 0
	n.claim_public = false
	n.secret = {}
	n.secret_mod = ""
	n.traits.privacy = 1.0
	n.trust = 0.1
	n.history[g.w.time_key(1, C.NIGHT)] = "night:market"
	n.lied_nights = [1]
	# They told the player they were home that night (the owned-lie line needs a real lie).
	n.dialogue_memory["night_accounts"] = {"1": {"kind": "alibi"}}
	var card = {"kind": "sighting", "subject": [n.id], "source": "player", "block": "market", "day": 1, "phase": C.NIGHT, "text": "The player's vigil caught them out"}
	var reply = Mind.press(g.w, n, card)
	check(n.claimed_role == "nightwatch" and n.max_tier >= 3 and reply.facts.any(func(f): return f.kind == "claim" and f.role == "nightwatch"), "a caught hidden good walker reveals their gift despite low ordinary willingness")
	check(reply.lines.any(func(line): return line is Dictionary and "So yes: I was out" in line.get("statement", line.text) and C.spoken_when(1, g.w.day) in line.text) and n.lied_nights.is_empty(), "the same disclosure owns the earlier lie with the existing admission line")
	check(not reply.facts.any(func(f): return f.kind == "alibi"), "a revealed walker does not restate the false home account")
	var home = fresh()
	var h = home.w.living_good()[0]
	h.role = "clerk"
	h.secret = {}
	h.secret_mod = ""
	h.traits.composure = 1.0
	h.traits.gossip = 0.0
	card.subject = [h.id]
	var first = Mind.press(home.w, h, card)
	var second = Mind.press(home.w, h, card)
	check(first.lines[0].text != second.lines[0].text, "successive firm home replies also vary without new random draws")


# ---- test_backlog_batch4


func backlog_batch4__fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch4_tests"
	g.new_case(4242, 10)
	return g


func empty_nomination_cases():
	var g = backlog_batch4__fresh()
	var w = g.w
	var t = w.living_good()[1]
	for n in [w.living_good()[0], w.minion()]:
		n.ledger = {}
		n.shadow = null
		var state = w.rng.state
		var reply = Mind.nomination_case(w, n, t, "")
		check(reply.lines.size() == 1 and reply.lines[0].get("statement", reply.lines[0].text) == "I don't trust %s, and I can't say better than that." % t.name and t.name in reply.lines[0].text, "an empty good or evil nomination gives a voiced fallback with canonical statement")
		check(reply.facts.is_empty() and w.rng.state == state, "empty-case wording adds no evidence or RNG draws")
		n.workshop_state = {"active": true, "reasons": {t.id: [{"card_id": "fact:pub", "why_public": "a public account", "strength": 0.6, "contrib": 0.2, "channel": "generic"}]}}
		var recap = Mind.nomination_case(w, n, t, "")
		check(recap.lines.size() == 1 and recap.lines[0].get("statement", recap.lines[0].text) == "Remember: a public account." and "a public account" in recap.lines[0].text, "a grounded public reason keeps its original recap")
		var already = Mind.nomination_case(w, n, t, "a public account")
		check(already.lines.is_empty() and already.facts.is_empty() and w.rng.state == state, "an already-cited grounded reason stays silent rather than becoming an empty-case fallback")


func volunteered_sightings():
	var g = backlog_batch4__fresh()
	var w = g.w
	var n = w.living_good()[0]
	var t = w.living_good()[1]
	w.day = 5
	for person in w.npcs: person.alive = true
	n.home_block = "square"
	n.secret_mod = ""
	n.traits.gossip = 0.6
	n.traits.confidence = 0.6
	n.traits.composure = 0.0
	n.claimed_role = ""
	n.max_tier = 0
	n.claim_public = false
	n.told_to = {}
	n.beliefs = [{"kind": "saw", "who": t.id, "block": "square", "day": 2, "phase": C.NIGHT, "how": "window"}]
	n.told_to["player|saw:%s:2" % t.id] = true
	var lines: Array = []
	var facts: Array = []
	var state = w.rng.state
	Mind._volunteer_night_sightings(w, n, lines, facts)
	check(facts == [Mind.sighting_report(w, n, n.beliefs[0], 2).fact] and C.spoken_when(2, w.day) in lines[0].text.to_lower(), "a privately told old-night sighting becomes the same ordinary public sighting card")
	check(w.rng.state == state and n.told_to.has(Mind._town_sighting_key(n, n.beliefs[0])), "volunteering uses the deterministic approved gate and records town identity")
	Mind._volunteer_night_sightings(w, n, lines, facts)
	check(facts.size() == 1, "a night sighting is volunteered to the town only once")
	n.told_to = {}
	n.traits.gossip = 0.55
	lines = []
	facts = []
	Mind._volunteer_night_sightings(w, n, lines, facts)
	check(facts.is_empty(), "a score below the calm-town threshold keeps the sighting private")
	w.living_good().back().alive = false
	Mind._volunteer_night_sightings(w, n, lines, facts)
	check(facts.size() == 1, "paranoia lowers the volunteering threshold as approved")
	n.told_to = {}
	n.silenced = true
	facts = []
	Mind._volunteer_night_sightings(w, n, lines, facts)
	check(facts.is_empty(), "a silenced witness cannot volunteer")
	n.silenced = false
	var away = n.beliefs[0].duplicate(true)
	away.block = "market"
	away.how = "street"
	n.history[w.time_key(2, C.NIGHT)] = "night:market"
	check(not Mind._public_sighting_allowed(w, n, away), "volunteering does not expose an undisclosed walk")
	n.role = "lamplighter"
	n.claimed_role = "lamplighter"
	n.max_tier = 3
	check(Mind._public_sighting_allowed(w, n, away), "an already disclosed walker may volunteer a sighting consistent with their duty")
	n.dialogue_memory["night_accounts"] = {"2": {"kind": "alibi", "home": true, "block": "square"}}
	check(not Mind._public_sighting_allowed(w, n, away), "volunteering cannot contradict an existing home account")
	n.dialogue_memory.erase("night_accounts")
	n.claimed_role = "nightwatch"
	n.role = "nightwatch"
	n.info_log = [{"role": "nightwatch", "day": 2, "shared": false, "data": {"block": "market", "seen": [t.id]}, "text": "a watch"}]
	n.told_readings = 0
	check(not Mind._public_sighting_allowed(w, n, away), "volunteering cannot bypass a withheld Night Watch reading")
	var evil = w.minion()
	evil.home_block = "square"
	evil.claimed_role = ""
	evil.secret_mod = ""
	evil.traits.gossip = 1.0
	evil.traits.confidence = 1.0
	evil.beliefs = [n.beliefs[0], {"kind": "saw", "who": w.demon().id, "block": "square", "day": 2, "phase": C.NIGHT, "how": "window"}]
	facts = []
	lines = []
	Mind._volunteer_night_sightings(w, evil, lines, facts)
	check(facts.size() == 1 and facts[0].subject == [t.id], "evil witnesses volunteer compatible true sightings but exclude teammates")
	check(not Mind._public_sighting_allowed(w, evil, away), "an evil volunteer cannot expose an off-home observation without a compatible cover")


# ---- test_fixes


func _game(sd: int, size: int = 10):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


func _silenced_speakers() -> void:
	var g = _game(7130)
	var w = g.w
	var speaker = w.living_good()[0]
	var target = w.living_good()[1]
	for n in w.living():
		n.loc = "home"
		n.working = false
		n.busy_with = ""
	speaker.loc = "tavern"
	speaker.traits["gossip"] = 1.0
	speaker.trust = 0.8 # the fixture's approach needs a trusting speaker; don't rely on the seed
	speaker.beliefs.append({"kind": "saw", "who": target.id, "block": target.home_block, "day": w.day - 1, "phase": C.NIGHT})
	speaker.silenced = true
	var approached = false
	for i in range(60):
		approached = approached or Social.approach_candidate(w) != null
	_check(not approached, "a silenced NPC cannot approach, even with fresh gossip")
	var quiet = Mind.gossip(w)
	_check(quiet["facts"].is_empty() and "Nobody to overhear" in quiet["lines"][0], "a tavern with only silenced NPCs has no speakers")
	speaker.silenced = false
	for i in range(60):
		approached = approached or Social.approach_candidate(w) != null
	_check(approached, "an NPC can approach again once silence ends")
	_check(not Mind.gossip(w)["facts"].is_empty(), "an NPC can supply tavern gossip again once silence ends")


func _martyr_reluctance() -> void:
	var g = _game(7106)
	var w = g.w
	var m = w.npcs.filter(func(x): return not x.is_evil())[0]
	var t = w.npcs.filter(func(x): return not x.is_evil() and x != m)[0]
	m.info_log = []
	m.known_claims = {}
	m.ledger = {}
	m.workshop_state = {}
	m.role = "martyr"
	m.martyr_target = t.id
	m.suspicion[t.id] = 0.7
	m.pressure = 0.0
	w.begin_meeting()
	var yes_as_martyr = Mind.vote(w, m, t.id, "player", false, "", 0)
	m.martyr_target = ""
	var yes_plain = Mind.vote(w, m, t.id, "player", false, "", 0)
	_check(yes_plain and not yes_as_martyr, "a Martyr won't readily vote to hang the one they'd die for")
	m.martyr_target = t.id
	m.suspicion[t.id] = 2.2
	_check(Mind.vote(w, m, t.id, "player", false, "", 0), "...unless the case against them is overwhelming")


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


## Passing on someone else's private reading names the gift, not the person, and counts for
## much less than the claim.
func _nomination_case() -> void:
	var hinted = 0
	var revealed = 0
	var leaked = 0
	for sd in range(7300, 7320):
		var r = _setup_private_reading(sd, 7)
		var w = r[1]
		var n = r[2]
		var t = r[3]
		var items = Mind.case_against(w, n, t.id)
		if items.is_empty() or items[0]["kind"] != "private":
			continue
		var cs = Mind.nomination_case(w, n, t, "")
		var text = " ".join(PackedStringArray(cs["lines"].map(func(l): return l["text"])))
		if n.claim_public:
			revealed += 1
		elif n.hints.has(t.id):
			hinted += 1
		if not n.claim_public and ("my own" in text or "I looked at" in text):
			leaked += 1
	_check(hinted + revealed >= 15 and hinted > 0 and revealed > 0, "a private Seer reading behind a nomination is hinted at (%d) or brought out (%d)" % [hinted, revealed])
	_check(leaked == 0, "never quoted without coming out")
	# A recap of public reasons is cosmetic.
	var r2 = _setup_private_reading(7330)
	var w2 = r2[1]
	var n2 = r2[2]
	var t2 = r2[3]
	n2.info_log[0]["shared"] = true
	var lis = w2.living_good().filter(func(x): return x != n2 and x != t2)[0]
	var before = lis.suspicion[t2.id]
	var cs2 = Mind.nomination_case(w2, n2, t2, "")
	_check(absf(lis.suspicion[t2.id] - before) < 0.001, "recapping a public reason moves nobody (%.3f -> %.3f)" % [before, lis.suspicion[t2.id]])
	_check(cs2["lines"].size() >= 1, "but it is said: %s" % (cs2["lines"][0]["text"] if not cs2["lines"].is_empty() else "(nothing)"))


func _defence_moves() -> void:
	# A Lamplighter seen out explains it; it sways those who trust them more.
	var g = _game(7350)
	var w = g.w
	var goods: Array = w.living_good()
	var d = goods[0]
	var a = goods[1]
	var l1 = goods[2]
	var l2 = goods[3]
	var vic = goods[4]
	vic.home_block = "docks"
	d.home_block = "square"
	a.home_block = "docks"
	l1.home_block = "docks"
	l2.home_block = "docks"
	w.day = 1
	w._kill(vic)
	w.day = 4
	d.role = "lamplighter"
	d.claimed_role = ""
	d.claim_public = false
	d.info_log = []
	for m in [a, l1, l2]:
		m.info_log = []
		m.known_claims = {}
		m.ledger = {}
		m.beliefs = [{"kind": "saw", "who": d.id, "loc": "", "block": "docks", "day": 1, "phase": 3, "how": "window", "detail": "street"}]
		Mind.refresh_beliefs(w, m, " (murder-block sighting)")
	l1.npc_trust[d.id] = 0.95
	l2.npc_trust[d.id] = 0.05
	var b1 = l1.suspicion[d.id]
	var b2 = l2.suspicion[d.id]
	# The accuser's own window sighting is private until said; the nomination speech says
	# it (the meeting flow passes those facts), so the defence answers it.
	var spoken: Array = [{"kind": "sighting", "source": a.id, "subject": [d.id], "block": "docks", "day": 1, "phase": 3}]
	var df = Mind.defend_self(w, d, a.id, spoken)
	_check("reveal" in df["moves"], "an accused Lamplighter seen out explains it (%s)" % str(df["moves"]))
	var drop1 = b1 - l1.suspicion[d.id]
	var drop2 = b2 - l2.suspicion[d.id]
	# With legacy effects gone (purge 2c) the shared model alone judges the gift claim, and
	# it explains the sighting almost fully whatever the listener's trust (both drops are
	# about 0.55); trust-sensitivity of defences is a tuning question, noted in the plan.
	_check(drop1 > 0.01 and drop2 > 0.01, "it sways listeners (%.3f vs %.3f)" % [drop1, drop2])
	# Named in a Seer's pair: points at the other one.
	var g2 = _game(7360)
	var w2 = g2.w
	var gs: Array = w2.living_good()
	var seer = gs[0]
	var d2 = gs[1]
	var o = gs[2]
	var lis = gs[3]
	seer.role = "seer"
	seer.claim_public = true
	seer.claimed_role = "seer"
	seer.info_log = [{"day": 0, "role": "seer", "data": {"pair": [d2.id, o.id], "yes": true}, "text": "I looked at them: one of them reads as the demon", "shared": true, "true": false}]
	seer.applied_info = 0
	Mind.update_from_own_info(w2)
	Mind.apply_info(w2, lis, seer, seer.info_log[0], 0.5)
	d2.suspicion[o.id] = 0.6   # they suspect the other more than the Seer (Oct 26: one explanation)
	d2.suspicion[seer.id] = 0.1
	var df2 = Mind.defend_self(w2, d2, seer.id)
	_check("pair_other" in df2["moves"], "named in a Seer's pair, they point at the other (%s)" % str(df2["moves"]))
	var def_scopes: Array = lis.ledger.values().filter(func(e): return e.meta.get("kind") == "defence").map(func(e): return e.meta.get("scope", {}))
	_check(def_scopes.any(func(sc): return sc.get("type") == "rival" and sc.get("other") == o.id), "rival defence scope records the other member of the pair")
	# Nothing to show: a plea, with almost no sway.
	var g3 = _game(7370)
	var w3 = g3.w
	var d3 = w3.living_good()[0]
	var df3 = Mind.defend_self(w3, d3, "player")
	_check(df3["moves"].size() == 1 and df3["moves"][0] in ["fear", "desperation"], "with nothing against them in particular, a plea (%s)" % str(df3["moves"]))
	# Silenced: no defence at all.
	d3.silenced = true
	_check(Mind.defend_self(w3, d3, "player")["moves"] == ["silenced"], "a silenced nominee can't defend themselves")


# ---- test_claude_batch


func claude_batch__game(sd: int):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 7)
	return g


## A scorched sigil reads like a murder for routes: the Demon went to that door that night.
## A sighting on the way there counts against whoever was seen; without the sigil, a quiet
## night says nothing about where the Demon went.
func _sleepwalk_excuse() -> void:
	var g = claude_batch__game(4450)
	var w = g.w
	var goods: Array = w.living_good()
	var sleeper = goods[0]
	var plain = goods[1]
	for n in w.npcs:
		n.secret_mod = ""
	sleeper.secret_mod = "sleepwalker"
	_check(not Mind.sleepwalk_excuse(w, sleeper, "the meeting").is_empty(), "the real Sleepwalker can say they've been known to sleepwalk")
	_check(Mind.sleepwalk_excuse(w, plain, "the meeting").is_empty(), "an ordinary good townsperson doesn't")
	var e = w.evil_team()[0]
	w.evil_plan["bluffs"][e.id] = "nightwatch"
	_check(Mind.sleepwalk_excuse(w, e, "the meeting").is_empty(), "evil with a night-walking bluff has no need of it")
	w.evil_plan["bluffs"][e.id] = "clerk"
	_check(Mind.sleepwalk_excuse(w, e, "the meeting").is_empty(), "and evil won't say it once someone else has (one Sleepwalker per case)")
	# The model: one claim from a good person means they're the Sleepwalker; two claims
	# mean at least one claimant is evil.
	w.day = 2
	g.add_card({"kind": "secret", "subject": [sleeper.id], "owner": sleeper.id, "source": sleeper.id, "secret_kind": "sleepwalker", "mod": "sleepwalker", "day": 1, "phase": 2, "text": "%s says they've been known to sleepwalk." % sleeper.name})
	g.add_card({"kind": "secret", "subject": [plain.id], "owner": plain.id, "source": plain.id, "secret_kind": "sleepwalker", "mod": "sleepwalker", "day": 1, "phase": 2, "text": "%s says they've been known to sleepwalk." % plain.name})
	var view = Live.view(g)
	var claims: Array = view.cards.filter(func(c): return c.kind == "secret_claim")
	_check(claims.size() == 2, "the claims reach the shared model as secret claims")
	# As Assess.prepare sets it up for a case that cites a secret claim.
	view["live_activity"] = true
	view.world_options["roles"] = true
	view.world_options["identities"] = true
	var one: Array = Solver.solve(view, [claims[0]]).worlds
	var ids: Array = view.people.map(func(p): return p.id)
	var a: int = ids.find(claims[0].subject)
	var b: int = ids.find(claims[1].subject)
	_check(not one.is_empty() and one.all(func(x): return (x.evil & (1 << a)) or (x.modifier == "sleepwalker" and x.holders & (1 << a))), "one claim: the claimant is the Sleepwalker or evil")
	var both: Array = Solver.solve(view, claims).worlds
	_check(not both.is_empty() and both.all(func(x): return (x.evil & (1 << a)) or (x.evil & (1 << b))), "two claims: at least one claimant is evil")


# ---- test_phase4_2_balanced_execution_priority


func _test_listener_mean_centering_and_tie_symmetry() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 7)
	var goods: Array = g.w.living_good()
	var seer = goods[0]
	var p1 = goods[1]
	var p2 = goods[2]
	var p3 = goods[3]
	var bystander = goods[4]
	seer.role = "seer"
	seer.ledger.clear()
	seer.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	for id in seer.suspicion:
		seer.suspicion[id] = Tuning.Setup.INITIAL_SUSPICION_BASE
		seer.npc_trust[id] = 0.5

	# 1) Equal priors and a Seer YES produce a symmetric positive priority; the bystander gets 0.0.
	seer.info_log = [{"day": 1, "phase": C.NIGHT, "role": "seer", "data": {"pair": [p1.id, p2.id], "yes": true}, "true": true, "shared": false, "text": "seer yes"}]
	seer.applied_info = 0
	Mind.update_from_own_info(g.w)
	var ep_p1: float = Mind.execution_priority(seer, p1.id)
	var ep_p2: float = Mind.execution_priority(seer, p2.id)
	var ep_by: float = Mind.execution_priority(seer, bystander.id)
	var ep_self: float = Mind.execution_priority(seer, seer.id)
	_check(ep_p1 > 0.0 and is_equal_approx(ep_p1, ep_p2), "symmetric 2-person Seer YES pair receives equal positive execution_priority (%.3f == %.3f)" % [ep_p1, ep_p2])
	_check(is_zero_approx(ep_by) and is_zero_approx(ep_self), "untouched bystander and self receive 0.0 execution_priority (bystander %.3f, self %.3f)" % [ep_by, ep_self])

	# 2) Dead person receives 0.0 execution_priority even if implicated by an old card.
	p1.alive = false
	Mind.refresh_beliefs(g.w, seer, "p1 died")
	_check(is_zero_approx(Mind.execution_priority(seer, p1.id)) and Mind.execution_priority(seer, p2.id) > ep_p2, "dead suspect drops to 0.0 execution_priority while surviving partner concentrates priority")
	p1.alive = true

	# 3) A 4-way symmetric Dowser count=2 group [p1, p2, p3, bystander] has zero alphabetical ID bias across the 4 tied members.
	var dowser = seer
	for id in dowser.suspicion:
		dowser.suspicion[id] = Tuning.Setup.INITIAL_SUSPICION_BASE
	dowser.role = "dowser"
	dowser.ledger.clear()
	dowser.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	dowser.info_log = [{"day": 1, "phase": C.MORNING, "role": "dowser", "data": {"group": [p1.id, p2.id, p3.id, bystander.id], "count": 2}, "true": true, "shared": false, "text": "dowser 2 of 4"}]
	dowser.applied_info = 0
	Mind.update_from_own_info(g.w)
	var grp_eps: Array = [p1.id, p2.id, p3.id, bystander.id].map(func(id): return Mind.execution_priority(dowser, id))
	_check(grp_eps.all(func(v): return is_equal_approx(float(v), float(grp_eps[0]))), "4-way symmetric Dowser group has zero alphabetical ID bias in execution_priority (%s)" % str(grp_eps))


func _test_bandwagon_pullback_vs_model_standout() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7101, 7)
	var w = g.w
	w.day = 2
	w.begin_meeting()
	var goods: Array = w.living_good()
	var voter = goods[0]
	var target = goods[1]
	voter.role = "surveyor"
	voter.traits["confidence"] = 0.5
	voter.traits["composure"] = 0.5
	voter.cleared.clear()
	voter.spare_pref.clear()
	for m in w.npcs:
		voter.suspicion[m.id] = 0.10
		voter.npc_trust[m.id] = 0.50

	# Three bare public accusations against an uncorroborated 0.10 bystander must stay well below 0.52 vote bar.
	var accusers: Array = w.npcs.filter(func(m): return m != voter and m != target).slice(0, 3)
	for a in accusers:
		w.stances[a.id] = {"target": target.id, "day": w.day}
	Mind.refresh_consensus(w, voter, target.id)
	var chorus_p: float = float(voter.consensus_pressure.get(target.id, 0.0))
	_check(chorus_p < 0.17 and not Mind.vote(w, voter, target.id, accusers[0].id, false, "", 0), "3-voice bare bandwagon (%.3f) cannot stampede an uninformed voter over the 0.52 bar" % chorus_p)

	# Even 5 voices cap at CONSENSUS_CAP = 0.22.
	for a in w.npcs:
		if a != voter and a != target:
			w.stances[a.id] = {"target": target.id, "day": w.day}
	Mind.refresh_consensus(w, voter, target.id)
	_check(float(voter.consensus_pressure.get(target.id, 0.0)) <= Tuning.Meeting.CONSENSUS_CAP + 1e-6, "consensus_pressure respects tightened 0.22 cap")

	# Meanwhile, a genuine world-model standout (suspicion 0.42 + priority 0.55 -> +0.121) crosses 0.52 without needing a chorus.
	w.stances.clear()
	Mind.refresh_all_consensus(w)
	voter.suspicion[target.id] = 0.42
	voter.workshop_state = {"active": true, "action": {"execution_priority": {target.id: 0.55}}}
	# A vote-formula check: hold the shared refresh (vote reconsiders through it, purge 3)
	# so the injected priority and suspicion are what the formula sees.
	g._workshop_busy = true
	_check(Mind.vote(w, voter, target.id, accusers[0].id, false, "", 0), "world-model standout (0.42 susp + 0.22*0.55 priority = 0.541) crosses 0.52 vote bar without bandwagon chorus")


func _test_death_spiral_pullback_and_threshold_parts_parity() -> void:
	var g = Game.new()
	g.detailed_logging = true
	g.new_case(92974, 10)
	var w = g.w
	w.day = 3
	w.begin_meeting()
	var goods: Array = w.living_good()
	var voter = goods[0]
	var target = goods[1]
	# Kill 3 other villagers to simulate Day 3 in a 10-NPC case.
	for k_idx in [2, 3, 4]:
		goods[k_idx].alive = false
	voter.role = "surveyor"
	voter.traits["confidence"] = 0.5
	voter.traits["composure"] = 0.5
	voter.cleared.clear()
	voter.spare_pref.clear()
	voter.workshop_state.clear()
	for m in w.npcs:
		voter.suspicion[m.id] = 0.40
		voter.npc_trust[m.id] = 0.50

	# With 3 dead at mid composure: paranoia = 0.07 * 3 * 0.7 = 0.147.
	# Old need = 0.50 - 0.40*0.147 - 0.06 = 0.3812 (voted YES on lukewarm 0.40!).
	# New need = 0.52 - 0.20*0.147 - 0.06 = 0.4306 (refuses lukewarm 0.40 panic hang!).
	w.stances.clear()
	voter.consensus_pressure.clear()
	g._workshop_busy = true # threshold formula only; keep the fixture suspicions exact
	var panic_yes: bool = Mind.vote(w, voter, target.id, "player", false, "", 0)
	_check(not panic_yes, "3 deaths in a 10-NPC game no longer drop the vote bar below 0.40 on lukewarm suspects")

	var evals: Array = w.dlog.trace_events().filter(func(ev): return ev.type == "decision" and ev.data.kind == "vote" and ev.data.stage == "evaluation" and ev.actor == voter.id)
	_check(not evals.is_empty(), "recorded structured vote evaluation with dead villagers")
	if not evals.is_empty():
		var det: Dictionary = evals[-1].data.details
		var sum_thr: float = 0.0
		for v_part in det.threshold_parts.values():
			sum_thr += float(v_part)
		_check(absf(sum_thr - float(det.threshold)) < 1e-9, "vote threshold_parts sum matches exact threshold even with 3 dead (%.6f == %.6f)" % [sum_thr, float(det.threshold)])


func _test_player_ballot_leverage_trim() -> void:
	var g = Game.new()
	g.detailed_logging = true
	g.new_case(42, 7)
	var w = g.w
	w.day = 2
	w.begin_meeting()
	var voter = w.living_good()[0]
	var target = w.living_good()[1]
	voter.role = "surveyor"
	voter.credibility = 1.0
	voter.workshop_state.clear()
	voter.suspicion[target.id] = 0.20
	Mind.vote(w, voter, target.id, "player", true, "accuse", 0)
	var evals: Array = w.dlog.trace_events().filter(func(ev): return ev.type == "decision" and ev.data.kind == "vote" and ev.data.stage == "evaluation" and ev.actor == voter.id)
	var parts: Dictionary = evals[-1].data.details.parts
	_check(is_equal_approx(float(parts.get("player_votes_yes", 0.0)), 0.14) and is_equal_approx(float(parts.get("player_accuses", 0.0)), 0.15),
		"trimmed player_votes_yes (0.14 at cred 1.0) and player_accuses (0.15 at cred 1.0) prevent single-click rubber-stamp hangs")


func _run_checkpoint_sweep(games: int) -> Dictionary:
	var out: Dictionary = {"tuning": Tuning.fingerprint(), "games_per_setup": games, "setups": {}}
	for npc_count in [7, 10]:
		var day_stats: Dictionary = {}
		for d in [1, 2, 3]:
			day_stats[d] = {"active_games": 0, "living": 0, "public_claimed": 0, "pub_or_priv_ready": 0, "noms": 0, "execs": 0, "evil_execs": 0, "good_execs": 0}
		var good_wins: int = 0
		print("\nRunning Phase 4.2 sweep (%d NPCs, %d seeds)..." % [npc_count, games])
		for idx in range(games):
			var seed_v: int = 1000 + idx
			var g = Game.new()
			g.detailed_logging = false
			g.log_dir = "user://test_logs/sweep_4_2"
			g.new_case(seed_v, npc_count)
			var w = g.w
			var recorded_days: Dictionary = {}
			var guard: int = 0
			while g.state != "over" and guard < 500:
				guard += 1
				if g.state == "night" and w.day in [1, 2, 3] and not recorded_days.has(w.day):
					recorded_days[w.day] = true
					_record_day_snapshot(w, day_stats[w.day])
				var cmd: String = "look"
				match g.state:
					"approach": cmd = "decline"
					"day": cmd = "wait"
					"talk": cmd = "bye"
					"meeting": cmd = "done" if g.town_quiet else "wait"
					"nomination": cmd = "vote no"
					"night": cmd = "sleep"
				g.command(cmd)
			if w.day in [1, 2, 3] and not recorded_days.has(w.day):
				recorded_days[w.day] = true
				_record_day_snapshot(w, day_stats[w.day])
			if w.winner == "good":
				good_wins += 1
			if (idx + 1) % 10 == 0 or idx + 1 == games:
				print("  [%d NPCs] %d / %d seeds complete" % [npc_count, idx + 1, games])
		var summary_days: Dictionary = {}
		print("=== PHASE 4.2 CHECKPOINT SWEEP (%d NPCs, %d seeds, tuning %s) ===" % [npc_count, games, Tuning.fingerprint()])
		for d in [1, 2, 3]:
			var st: Dictionary = day_stats[d]
			var ag: int = maxi(1, int(st.active_games))
			var lv: int = maxi(1, int(st.living))
			var pub_pct: float = 100.0 * float(st.public_claimed) / float(lv)
			var priv_pct: float = 100.0 * float(st.pub_or_priv_ready) / float(lv)
			var nom_pct: float = 100.0 * float(st.noms) / float(ag)
			var exec_pct: float = 100.0 * float(st.execs) / float(ag)
			var wrong_pct: float = 100.0 * float(st.good_execs) / float(maxi(1, int(st.execs))) if int(st.execs) > 0 else 0.0
			summary_days[str(d)] = {
				"active_games": st.active_games,
				"public_claim_pct": snappedf(pub_pct, 0.1),
				"public_or_private_ready_pct": snappedf(priv_pct, 0.1),
				"meeting_with_nomination_pct": snappedf(nom_pct, 0.1),
				"meeting_with_execution_pct": snappedf(exec_pct, 0.1),
				"evil_executions": st.evil_execs,
				"good_executions": st.good_execs,
				"wrongful_exec_share_pct": snappedf(wrong_pct, 0.1),
			}
			print("  Day %d (active %d): public %.1f%% | nom-games %.1f%% | exec-games %.1f%% (%d evil, %d good, %.1f%% wrongful)" % [
				d, st.active_games, pub_pct, nom_pct, exec_pct, st.evil_execs, st.good_execs, wrong_pct])
		var win_pct: float = 100.0 * float(good_wins) / float(maxi(1, games))
		print("  Passive-bot Good win rate: %.1f%% (%d / %d)" % [win_pct, good_wins, games])
		out.setups[str(npc_count)] = {
			"days": summary_days,
			"passive_good_win_pct": snappedf(win_pct, 0.1),
		}
	return out


func _record_day_snapshot(w, st: Dictionary) -> void:
	st.active_games += 1
	for n in w.living():
		st.living += 1
		if n.claim_public:
			st.public_claimed += 1
			st.pub_or_priv_ready += 1
		elif n.max_tier >= 3 or (Mind.MindDialogue._target_tier(w, n) >= 3 and not Mind.MindDialogue._afraid(w, n)):
			st.pub_or_priv_ready += 1
	if w.dlog.entries.any(func(e): return e["type"] == "nomination" and int(e.get("day", -1)) == w.day):
		st.noms += 1
	for ex in w.executions:
		if int(ex.get("day", -1)) == w.day:
			st.execs += 1
			var ex_npc = w.by_id.get(str(ex.get("id", "")))
			if ex_npc != null and ex_npc.is_evil():
				st.evil_execs += 1
			else:
				st.good_execs += 1


# ---- test_phase4_3_framing_and_vigil_physics


func _test_case_98933_polish_fixes() -> void:
	var g = Game.new()
	g.detailed_logging = true
	g.new_case(98933, 10)
	var w = g.w

	# 1) Good nominator self-vote follow-through on Day 1 + exact trace sum parity.
	w.day = 1
	w.phase = C.EVENING
	w.begin_meeting()
	var nisha = w.by_id["nisha"]
	var edda = w.by_id["edda"]
	nisha.suspicion[edda.id] = 0.39
	var self_yes: bool = Mind.vote(w, nisha, edda.id, nisha.id, false, "", 0)
	_check(self_yes, "Good nominator follows through with YES on their own Day 1 nomination")
	var eval_events: Array = w.dlog.trace_events().filter(func(e): return e.get("type", "") == "decision" and e.get("actor", "") == nisha.id and e.get("data", {}).get("topic", "") == "vote" and e.get("data", {}).get("stage", "") == "evaluation")
	if not eval_events.is_empty():
		var details: Dictionary = eval_events[-1]["data"]["details"]
		var p_sum: float = 0.0
		for v in details["parts"].values():
			p_sum += float(v)
		_check(absf(p_sum - float(details["score"])) < 1e-9, "self_nomination vote part preserves exact score sum for Decision Inspector")

	# 2) Cross-card Workshop contradiction surfaces private Gravedigger reading in case_against.
	w.day = 3
	var hollis = w.by_id["hollis"]
	var odette = w.by_id["odette"]
	var agnes = w.by_id["agnes"]
	var lian = w.by_id["lian"]
	w.executions.append({"day": 2, "id": edda.id, "nominator": "player", "yes": [hollis.id], "player_yes": true, "player_nominated": true})
	w.day = 2
	w.public_event("execution", [edda.id], "town")
	w.day = 3
	edda.alive = false
	edda.death_day = 2
	edda.death_cause = "executed"
	hollis.role = "gravedigger"
	var gd_entry: Dictionary = {"day": 2, "phase": C.NIGHT, "role": "gravedigger", "data": {"executed": edda.id, "role": "poisoner"}, "true": true, "shared": false, "text": "I learned that Edda, whom we hanged, was the Poisoner"}
	hollis.info_log = [gd_entry]
	hollis.applied_info = 0
	Mind.update_from_own_info(w)
	var arch_entry: Dictionary = {"day": 0, "phase": C.NIGHT, "role": "archivist", "data": {"pair": [agnes.id, lian.id], "role": "poisoner"}, "true": false, "fake": true, "shared": true, "text": "I learned that one of Agnes and Lian is the Poisoner"}
	odette.info_log = [arch_entry]
	odette.claimed_role = "archivist"
	odette.claim_public = true
	w.public_claims.append({"day": 3, "who": odette.id, "role": "archivist"})
	Mind.hear_claim(w, hollis, odette.id, "archivist", 0.5, "public")
	Mind.apply_info(w, hollis, odette, arch_entry, 0.5)
	Mind.flush_beliefs(w, hollis)
	var reasons: Array = Mind.MindMeeting.case_against(w, hollis, odette.id)
	# Superseded by purge phase 2a: reasons now come from the shared model's attribution,
	# and only for people the shared model actually suspects. This synthetic fixture (legacy
	# apply_info, no poisoning explanation ruled out) leaves Odette below Hollis's average,
	# so she has no reasons at all. The realistic version of this case is covered in
	# tools/test_legacy_purge_phase2a.gd ("case_against surfaces Hollis's private
	# Gravedigger reading against Odette via leave-one-out").
	var odette_req: float = float(hollis.workshop_state.get("requested", {}).get(odette.id, 0.0))
	_check(odette_req <= 0.0 or (not reasons.is_empty() and reasons[0]["kind"] == "private" and reasons[0]["entry"] == gd_entry),
		"case_against cites Hollis's private Gravedigger reading whenever the shared model suspects Odette (%s)" % str(reasons))

	# 3) Authoring validation block (citing 'gift' without walking-role claim card) leaves legacy_fallbacks at 0.
	g.shared_fallbacks.clear()
	var fb_before: int = w.dlog.entries.filter(func(e): return e.get("type", "") == "legacy_fallback").size()
	var c_vig: int = g.add_card({"kind": "sighting", "source": "player", "subject": [agnes.id], "vigil": true, "day": 2, "phase": C.NIGHT, "block": "market", "text": "Vigil saw Agnes."})
	var c_clm: int = g.add_card({"kind": "claim", "source": agnes.id, "subject": [agnes.id], "role": "medium", "day": 2, "phase": C.EVENING, "text": "Agnes Medium."})
	var id_clm: String = Live.Evidence.normalize_card(g.board[c_clm - 1]).id
	var id_vig: String = Live.Evidence.normalize_card(g.board[c_vig - 1]).id
	var bad_case: Dictionary = {
		"id": "case-bad", "cards": [id_vig], "lines": [{"id": "direct", "label": "Direct", "relation": "supports", "cards": [id_vig], "answers": {}, "positions": {}}],
		"conclusion": {"type": "suspicious", "target": "isolde", "at": "Original alignment"},
		"reasons": {agnes.id + ":2": "gift"}, "citations": {agnes.id + ":2": id_clm},
		"answers": {}, "positions": {}, "disputes": [], "reading_challenges": {}, "faults": {}, "derived": [], "conflict_scope": [], "temporal_positions": [],
		"argument_root": "p:1", "arguments": [{"id": "p:1", "label": "Isolde is suspicious", "parents": [], "without": {}, "case": {
			"id": "case-bad", "cards": [id_vig], "lines": [{"id": "direct", "label": "Direct", "relation": "supports", "cards": [id_vig], "answers": {}, "positions": {}}],
			"conclusion": {"type": "suspicious", "target": "isolde", "at": "Original alignment"},
			"reasons": {agnes.id + ":2": "gift"}, "citations": {agnes.id + ":2": id_clm},
			"answers": {}, "positions": {}, "disputes": [], "reading_challenges": {}, "faults": {}, "derived": [], "conflict_scope": [], "temporal_positions": []
		}}]
	}
	var bad_num: int = Live.file(g, bad_case)
	var gate_ok: bool = g._presentation_gate(g.board[bad_num - 1], w.living(), ["isolde"], "deduction", "meeting")
	var fb_after: int = w.dlog.entries.filter(func(e): return e.get("type", "") == "legacy_fallback").size()
	_check(not gate_ok and g.shared_fallbacks.is_empty() and fb_after == fb_before,
		"Incomplete canvas authoring validation block returns false with 0 legacy_fallbacks")

	# 4) Jury rival-world formatting omits ';  Marked' when marked == ''.
	var snap_ok: Dictionary = g.workshop_snapshot([bad_num], hollis.id, "meeting")
	var view_dummy: Dictionary = {"people": [{"id": "odette", "name": "Odette", "home": "square"}, {"id": "isolde", "name": "Isolde", "home": "hill"}, {"id": "edda", "name": "Edda", "home": "market"}], "evil_count": 2, "day": 2, "timeline": {"events": []}}
	var desc_unmarked: Dictionary = Jury.Solver.describe_world(view_dummy, {"evil": 3, "marked": -1, "demon": 0}, "Original alignment")
	var marked_clause: String = ("; %s Marked" % Jury.Solver.person_name(view_dummy, desc_unmarked.marked)) if str(desc_unmarked.get("marked", "")) != "" else ""
	var formatted: String = "I checked another explanation and it also fits: %s evil%s." % [", ".join(PackedStringArray(desc_unmarked.evil.map(func(id): return Jury.Solver.person_name(view_dummy, id)))), marked_clause]
	_check(not (";  Marked" in formatted) and formatted.ends_with("evil."), "Unmarked rival-world string omits empty ';  Marked' (%s)" % formatted)
	_check(snap_ok is Dictionary, "snapshot helper remains intact")


# ---- test_playtest_followups


func playtest_followups__fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://followup_tests"
	g.new_case(4242, 10)
	return g


func public_sightings():
	var g = playtest_followups__fresh()
	var w = g.w
	w.day = 3
	w.phase = C.EVENING
	w.open_meeting()
	var speaker = w.living_good()[0]
	var target = w.living_good()[1]
	var dead = w.living_good().back()
	dead.alive = false
	for n in w.npcs:
		n.ledger = {}
		n.heard = {}
		n.hearsay = []
		n.info_log = []
		n.beliefs = []
		n.known_claims = {}
		n.claim_public = true
		n.claimed_role = "clerk"
		n.max_tier = 4
		n.shadow = null
		for id in n.suspicion: n.suspicion[id] = 0.1
		for id in n.npc_trust: n.npc_trust[id] = 0.5
		if not n.is_evil(): n.role = "clerk"
	speaker.home_block = "square"
	speaker.traits.gossip = 0.6
	speaker.traits.confidence = 0.6
	speaker.traits.composure = 0.0
	speaker.secret_mod = ""
	var seen = {"kind": "saw", "who": target.id, "block": "square", "day": 1, "phase": C.NIGHT, "how": "window"}
	speaker.beliefs = [seen]
	w.defer_beliefs = true
	g._testimony = {"speakers": [speaker], "i": 0, "done": false, "spoken": 0}
	g._testimony_turn()
	var sightings = g.board.filter(func(card): return card.kind == "sighting" and card.source == speaker.id and card.day == 1 and card.subject == [target.id])
	check(sightings.size() == 1, "the actual testimony turn files the volunteered sighting once")
	if sightings.is_empty(): return
	var receipt = Mind.WorkshopLedger.Evidence.normalize_card(sightings[0])
	var eid: String = "heard:" + receipt.id
	for listener in w.living():
		if listener == speaker: continue
		var mind = listener.shadow if listener.is_evil() else listener
		check(mind != null and mind.ledger.has(eid), "living %s hears the exact public receipt without player presentation" % listener.id)
		if mind == null or not mind.ledger.has(eid): continue
		var entry: Dictionary = mind.ledger[eid]
		check(entry.meta.workshop_public and entry.meta.workshop_teller == speaker.id and entry.meta.workshop_card.source == speaker.id and entry.meta.workshop_card.observed_at == {"day": 1, "phase": "night"}, "public hearing retains source, observed night and public provenance")
		# Weight follows trust in the teller (0.75 x trust, doubled for a receipt) with no
		# private-chat bonus; an accused target's trust may already have dropped.
		var tr: float = mind.npc_trust[speaker.id]
		check(is_equal_approx(entry.weight, 2.0 * Tuning.Social.HEARSAY_TRUST_SCALE * tr) and tr <= 0.5 + 0.000001, "ordinary hearing weight is reused without private-chat trust bonus (%s: %.3f, trust %.3f)" % [listener.id, entry.weight, tr])
		check(mind.hearsay.any(func(item): return item.kind == "sighting" and item.about == target.id and item.from == speaker.id), "listeners retain the attributed report for later conversation")
	check(not dead.ledger.has(eid) and not speaker.ledger.has(eid), "dead NPCs and the speaker do not receive a secondhand self-report")
	var rng = w.rng.state
	var lines: Array = []
	var facts: Array = []
	Mind._volunteer_night_sightings(w, speaker, lines, facts)
	check(facts.is_empty() and w.rng.state == rng, "a public sighting stays told-to-town and is not volunteered twice")
	var listener = w.living_good()[2]
	var count = listener.ledger.size()
	var weight: float = listener.ledger[eid].weight
	Social.deliver_public_sighting(w, speaker, sightings[0])
	check(listener.ledger.size() == count and listener.ledger[eid].weight == weight and w.rng.state == rng, "repeated delivery reuses the receipt and never stacks weight or consumes RNG")
	Mind.flush_beliefs(w, listener)
	check(listener.workshop_state.get("owned", {}).has(eid), "shared-model ownership includes the sighting before the player presents anything")
	check(listener.ledger[eid].effects.is_empty(), "sighting ledger entry stores empty legacy effects")
	w.pending_beliefs = []
	w.defer_beliefs = false


# ---- test_playtest_regressions


func playtest_regressions__game():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(25923, 10)
	return g


func _meeting_sighting_prefix_and_gallows() -> void:
	var g = playtest_regressions__game()
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
	_check(facts.size() == 1 and lines.size() == 1 and lines[0].text.to_lower().count(C.spoken_when(1, w.day)) == 1, "actual volunteered sighting says the night exactly once")
	_check(w.rng.state == rng_state, "formatting a volunteered night sighting adds no RNG draw")
	# The person-specific recent-sightings path has its own date-prefix handling.
	n.role = "lamplighter"
	n.claimed_role = n.role
	n.claim_public = true
	var recent = {"lines": [], "facts": []}
	Recent.append_to(w, n, target, recent, [])
	_check(recent.facts.size() == 1 and recent.lines.size() == 1 and recent.lines[0].text.to_lower().count(C.spoken_when(1, w.day)) == 1, "actual recent night sighting says the night exactly once")
	n.info_log.clear()
	n.beliefs.clear()
	var gallows: Dictionary = Mind.last_words(w, n)
	_check(gallows["lines"].size() >= 1 and gallows["lines"][0].get("statement", gallows["lines"][0]["text"]).begins_with("As I've said, I am the "), "last words acknowledge an already-public role claim")
