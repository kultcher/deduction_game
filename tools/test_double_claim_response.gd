## The town's response to a double claim (Michael, Nov 19; BACKLOG "More rebuttals after a
## caught lie"):
##   - the true holder counterclaims at its first chance, whatever its usual reticence,
##     when someone else claims its gift publicly or it hears of such a claim;
##   - evil whose planned bluff is claimed first, before it has claimed anything, switches to
##     a spare from evil's bluff list, with a logged reason; not once a fake reading of the
##     old bluff has been told;
##   - an unclaimed Minion (never the Demon or a Scion) may claim a gift it has just heard
##     claimed, a deliberate double claim, at MINION_DOUBLE_CLAIM_CHANCE scaled down by heat;
##   - pressed in private with another NPC's sighting, a confident NPC may call the witness a
##     liar (a line only).
extends SceneTree
const Game = preload("res://game/game.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const MindPress = preload("res://sim/mind_press.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_holder()
	_switch()
	_double_claim()
	_witness_lying()
	_bluff_change_clean()
	_playtest_nov22()
	print("Double claim response: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	g.w.day = 2
	g.w.begin_meeting()
	return g

func _unclaimed(n) -> void:
	n.claim_public = false
	n.claimed_role = ""
	n.known_claims = {}
	n.protect_lock = true
	n.traits.privacy = 1.0
	n.pressure = 0.0

func _holder() -> void:
	var g = _game()
	var w = g.w
	var holder = w.living_good()[0]
	var rival = w.living_good()[1]
	_unclaimed(holder)
	rival.claim_public = true
	rival.claimed_role = holder.role
	_check(MindMeeting._public_claim_decision(w, holder) == holder.role, "a public claim of my gift: the true holder counterclaims at once, despite a promise to the player and high Privacy")
	rival.claim_public = false
	rival.claimed_role = ""
	_check(MindMeeting.rival_claimants(w, holder, holder.role).is_empty(), "no rival once the claim is gone")
	holder.known_claims[rival.id] = {"role": holder.role, "readings": [], "via": w.living_good()[2].id}
	_check(MindMeeting._public_claim_decision(w, holder) == holder.role, "heard of the claim elsewhere: it counterclaims at the meeting")

func _switch() -> void:
	var g = _game()
	var w = g.w
	var e = w.minion()
	_unclaimed(e)
	# Its own bluff, from the list, and the rest of the list free.
	for id in w.evil_plan.bluffs:
		w.evil_plan.bluffs[id] = "clerk"
	w.evil_plan.bluffs[e.id] = str(w.bluffs[0])
	var bluff: String = str(w.evil_plan.bluffs[e.id])
	var rival = w.living_good()[0]
	rival.claim_public = true
	rival.claimed_role = bluff
	var spares: Array = w.bluffs.filter(func(r): return r not in w.evil_plan.bluffs.values())
	if spares.is_empty():
		_check(false, "this deal has a spare bluff to switch to")
		return
	e.info_log = e.info_log.filter(func(x): return not x.get("fake", false))
	e.info_log.append({"role": bluff, "day": 1, "fake": true, "shared": true, "data": {}, "text": "told"})
	_check(not MindMeeting.switch_taken_bluff(w, e), "a fake reading of the bluff already told: no switch")
	e.info_log = e.info_log.filter(func(x): return not x.get("fake", false))
	_check(MindMeeting.switch_taken_bluff(w, e), "its planned bluff claimed first: it switches")
	var now: String = str(w.evil_plan.bluffs[e.id])
	_check(now != bluff and now in w.bluffs and w.evil_plan.bluffs.values().count(now) == 1, "to a spare from the bluff list no teammate uses (%s -> %s)" % [bluff, now])
	_check(w.dlog.entries.any(func(x): return str(x.get("type", "")) == "think" and str(x.get("data", {}).get("topic", "")) == "bluff_switch" and "bluff taken" in str(x.get("data", {}).get("why", ""))),
		"the switch is logged with its reason")

func _double_claim() -> void:
	# Gates first: never the Demon, a Scion or one that has claimed.
	var g = _game()
	var w = g.w
	var rival = w.living_good()[0]
	var role: String = rival.role
	var demon = w.by_id[w.demon_id]
	_unclaimed(demon)
	var seen_demon := false
	for k in 200:
		w.seed_value = k
		if MindMeeting.choose_double_claim(w, demon, rival, role):
			seen_demon = true
	_check(not seen_demon, "never the Demon")
	# A Minion, cold: it sometimes takes the double claim, at about the set chance.
	var m = w.minion()
	w.public_log = w.public_log.filter(func(x): return not (m.id in x.get("subjects", [])))
	var hits: int = 0
	for k in 400:
		_unclaimed(m)
		m.dialogue_memory.erase("double_claim")
		m.info_log = m.info_log.filter(func(x): return not (x.get("fake", false) and x.get("shared", false)))
		w.seed_value = 1000 + k
		if MindMeeting.choose_double_claim(w, m, rival, role):
			hits += 1
	var rate: float = hits / 400.0
	_check(absf(rate - Tuning.Evil.MINION_DOUBLE_CLAIM_CHANCE) < 0.05, "a cold Minion double-claims at about the set chance (%.3f)" % rate)
	var chose := false
	for k in 400:
		_unclaimed(m)
		m.dialogue_memory.erase("double_claim")
		w.seed_value = 9000 + k
		if MindMeeting.choose_double_claim(w, m, rival, role):
			chose = true
			break
	_check(chose and str(w.evil_plan.bluffs[m.id]) == role and MindMeeting._public_claim_decision(w, m) == role, "having chosen it, it claims the rival's gift at the meeting")
	# Rolled once per game (Michael, Nov 20): with the seed fixed, a Minion not looking to
	# double-claim never does, however many claims it hears.
	var never_seed: int = -1
	for k in 400:
		w.seed_value = 20000 + k
		_unclaimed(m)
		m.dialogue_memory.erase("double_claim")
		if not MindMeeting.choose_double_claim(w, m, rival, role):
			never_seed = 20000 + k
			break
	var acted := false
	for other in w.living_good():
		for d in [1, 2, 3]:
			w.seed_value = never_seed
			w.day = d
			_unclaimed(m)
			m.dialogue_memory.erase("double_claim")
			if MindMeeting.choose_double_claim(w, m, other, other.role):
				acted = true
	w.day = 2
	_check(never_seed >= 0 and not acted, "a Minion not looking to double-claim this game never does, whoever claims and whenever")
	# Hot: implicated before the town, it doesn't risk it.
	for i in 12:
		w.public_log.append({"kind": "accusation", "subjects": [m.id], "day": w.day, "by": rival.id})
	var hot: int = 0
	for k in 200:
		_unclaimed(m)
		m.dialogue_memory.erase("double_claim")
		w.seed_value = 5000 + k
		if MindMeeting.choose_double_claim(w, m, rival, role):
			hot += 1
	_check(hot == 0, "fully implicated before the town, it never double-claims (%d)" % hot)
	# Its draw is its own: choosing (or not) leaves the world's random stream where it was.
	_unclaimed(m)
	w.public_log = w.public_log.filter(func(x): return not (m.id in x.get("subjects", [])))
	var state = w.rng.state
	MindMeeting.choose_double_claim(w, m, rival, role)
	_check(w.rng.state == state, "the double-claim roll draws nothing from the world's stream")

## Pressed in private with another NPC's sighting (Michael, Nov 19): "<witness> is lying
## about seeing me", Confidence over the meeting's gate; a good NPC only if it was home.
func _witness_lying() -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good()[0]
	var witness = w.living_good()[1]
	n.traits.confidence = 0.9
	n.claim_public = false
	n.claimed_role = ""
	n.secret = {}
	n.secret_mod = ""
	n.history[w.time_key(1, C.NIGHT)] = "home:" + n.home_block
	var card = {"kind": "sighting", "subject": [n.id], "source": witness.id, "block": "market", "day": 1, "phase": C.NIGHT, "text": "%s saw them on the Market." % witness.name}
	var r: Dictionary = MindPress.press(w, n, card)
	var said: String = " ".join(PackedStringArray(r.lines.map(func(l): return str(l.get("statement", l.get("text", ""))) if l is Dictionary else str(l))))
	_check(("%s is lying about seeing me." % witness.name) in said, "confident and truly home: calls the witness a liar (%s)" % said)
	var g2 = _game()
	var n2 = g2.w.living_good()[0]
	n2.traits.confidence = 0.2
	n2.history[g2.w.time_key(1, C.NIGHT)] = "home:" + n2.home_block
	var card2 = card.duplicate(true)
	card2["source"] = g2.w.living_good()[1].id
	var r2: Dictionary = MindPress.press(g2.w, n2, card2)
	_check(not r2.lines.any(func(l): return l is Dictionary and "lying about seeing me" in str(l.get("statement", ""))), "unconfident: it only stands by its account")

## Changing a bluff leaves nothing of the old one behind (Codex on #390): no fabrication of it
## in the log or held back a day, the shadow (the good self) takes the new gift, drops the old
## readings, and its reading cursor still points at the next unseen entry. A Revenant-turned
## townsperson, evil but not a Minion, never double-claims or switches.
func _bluff_change_clean() -> void:
	var g = _game()
	var w = g.w
	var m = w.minion()
	_unclaimed(m)
	var old: String = str(w.bluffs[0])
	for id in w.evil_plan.bluffs:
		w.evil_plan.bluffs[id] = "clerk"
	w.evil_plan.bluffs[m.id] = old
	m.info_log = m.info_log.filter(func(x): return not x.get("fake", false))
	m.info_log.append({"role": old, "day": 0, "fake": true, "shared": false, "data": {}, "text": "old, seen by the shadow"})
	m.held_fakes = [{"entry": {"role": old, "day": 1, "fake": true, "data": {}, "text": "old, held"}, "until": w.day}]
	Mind._shadow_own_info(w, m)
	var cursor_before: int = int(m.shadow_seen.get("fake", 0))
	var rival = w.living_good()[0]
	rival.claim_public = true
	rival.claimed_role = old
	_check(MindMeeting.switch_taken_bluff(w, m), "the switch happens with an untold fabrication of the old bluff")
	var now: String = str(w.evil_plan.bluffs[m.id])
	_check(not m.info_log.any(func(x): return x.get("fake", false) and x.get("role", "") == old) and not m.held_fakes.any(func(h): return h.entry.role == old),
		"no fabrication of the old bluff is left, in the log or held back")
	_check(m.shadow != null and m.shadow.role == now and not m.shadow.info_log.any(func(x): return x.get("fake", false) and x.get("role", "") == old),
		"the shadow takes the new gift (%s) and drops the old readings" % (m.shadow.role if m.shadow != null else "none"))
	_check(int(m.shadow_seen.get("fake", -1)) == cursor_before - 1 and int(m.shadow_seen.get("fake", -1)) <= m.info_log.size(),
		"the shadow's cursor moves back past the removed reading (%d -> %d)" % [cursor_before, int(m.shadow_seen.get("fake", -1))])
	# A new fabrication after the change reaches the shadow.
	m.info_log.append({"role": now, "day": 1, "fake": true, "shared": false, "data": {}, "text": "new"})
	Mind._shadow_own_info(w, m)
	_check(m.shadow.info_log.any(func(x): return x.get("fake", false) and x.get("role", "") == now), "a fabrication of the new gift reaches the shadow")
	# A turned townsperson is no Minion.
	var t = w.living_good()[2]
	t.turned = true
	t.alignment = "evil"
	_unclaimed(t)
	var any := false
	for k in 200:
		w.seed_value = 7000 + k
		if MindMeeting.choose_double_claim(w, t, rival, old):
			any = true
	_check(not any and not MindMeeting.switch_taken_bluff(w, t), "a Revenant-turned townsperson never double-claims or switches")

## Michael's playtest, Nov 22: a Poisoner double-claimed its own ally's bluffed gift, hanging
## the ally; and, its bluff switched to a first-night gift on day 1, had no reading to give.
func _playtest_nov22() -> void:
	var g = _game()
	var w = g.w
	var m = w.minion()
	var ally = w.npcs.filter(func(x): return x.is_evil() and x != m)[0]
	var role: String = "archivist"
	var acted := false
	for k in 400:
		_unclaimed(m)
		m.dialogue_memory.erase("double_claim")
		m.info_log = m.info_log.filter(func(x): return not (x.get("fake", false) and x.get("shared", false)))
		w.seed_value = 1000 + k
		if MindMeeting.choose_double_claim(w, m, ally, role):
			acted = true
	_check(not acted, "a Minion never double-claims a teammate's claim")
	# Nor once it has privately told someone another gift (playtest 51795).
	var good_rival = w.living_good()[0]
	var listener = w.living_good()[1]
	var told := false
	for k in 400:
		_unclaimed(m)
		m.dialogue_memory.erase("double_claim")
		listener.known_claims[m.id] = {"role": "registrar" if good_rival.role != "registrar" else "clerk", "readings": [], "via": m.id}
		w.seed_value = 3000 + k
		if MindMeeting.choose_double_claim(w, m, good_rival, good_rival.role):
			told = true
	listener.known_claims.erase(m.id)
	_check(not told, "nor once it has told someone in private that it holds another gift")
	# A late switch to a first-night gift still gets that night's reading.
	var good = w.living_good()[0]
	m.info_log = m.info_log.filter(func(x): return not x.get("fake", false))
	var before: String = str(w.evil_plan["bluffs"].get(m.id, ""))
	MindMeeting._change_bluff(w, m, before, role)
	var fakes: Array = m.info_log.filter(func(x): return x.get("fake", false) and str(x.get("role", "")) == role)
	_check(fakes.size() == 1 and int(fakes[0].get("day", -1)) == 0, "switched to the Archivist on day %d, it has a first-night Archivist reading to tell" % w.day)
	MindMeeting._change_bluff(w, m, role, role)
	_check(m.info_log.filter(func(x): return x.get("fake", false) and str(x.get("role", "")) == role).size() <= 1, "and never more than one")
