## Withheld readings, NPC side (docs/design/withheld_readings.md; Michael, Nov 22 and 28):
##   - asking in private: a good NPC that heard someone claim an information gift a day or more
##     ago, with no reading heard since, sometimes asks for it (Tuning.Social.ASK_PRIVATE_*),
##     once per pair per day; never for a claim made today, a reading already heard, or a gift
##     that reads only after a hanging; never an evil asker;
##   - the answer goes to the asker alone: shared, or held back (deferred with a reason, or
##     deflected); a bluffer with a made-up reading answers;
##   - pressing at the meeting: a confident good NPC presses a suspected public claimant that
##     has gone a day without a reading (Tuning.Meeting.PRESS_WITHHELD_*), once per meeting;
##   - every refusal, the Demonologist's "Call on" included, is on w.withheld_refusals in the
##     shape agreed with Lantern, and gets shared_at when the reading comes out.
##   godot --headless --path . --script res://tools/test_withheld_asks.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Withheld = preload("res://sim/mind_withheld.gd")
const MindCallOn = preload("res://sim/mind_call_on.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Gifts = preload("res://sim/gifts.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _world(sd: int, day: int = 2):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 10)
	g.w.day = day
	return g.w

## A good first-night reader with an unshared reading, and a good asker who heard its claim
## on day 1. [] when the deal has none.
func _pair(w) -> Array:
	var c = null
	for m in w.living_good():
		if C.has_role_def(m.role) and C.role_def(m.role).first_night and m.info_log.any(func(e): return not e.get("shared", false) and str(e.get("role", "")) == m.role):
			c = m
			break
	if c == null:
		return []
	var a = w.living_good().filter(func(m): return m != c)[0]
	a.known_claims[c.id] = {"role": c.role, "readings": [], "via": c.id, "first_claimed_day": 1}
	return [a, c]

func _closed(n) -> void:
	n.traits["privacy"] = 1.0
	n.pressure = 0.0

func _shape_ok(r: Dictionary) -> bool:
	return r.get("claim") is Dictionary and r.claim.has("day") and r.claim.has("role") and r.get("tick") is int and r.get("day") is int \
		and r.get("venue", "") in ["private", "meeting"] and r.get("kind", "") in ["deferred", "deflected"] and r.get("reason", "x") in ["friend", "burden", "distrust", ""] \
		and r.get("known_to") is Array and not r.has("shared_at")

func _init() -> void:
	_private_asks()
	_private_answers()
	_meeting_press()
	_call_on_record()
	print("Withheld asks: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _private_asks() -> void:
	var asked := 0
	var tries := 0
	var twice := false
	var expect := 0.0
	for sd in range(8000, 8080):
		var w = _world(sd)
		var p: Array = _pair(w)
		if p.is_empty():
			continue
		tries += 1
		var a = p[0]
		expect += Tuning.Social.ASK_PRIVATE_BASE + Tuning.Social.ASK_PRIVATE_WARY * clampf(a.suspicion.get(p[1].id, 0.0), 0.0, 1.0) + Tuning.Social.ASK_PRIVATE_INSIGHT * float(a.traits.get("insight", 0.5))
		if Withheld.maybe_ask_private(w, a, p[1]):
			asked += 1
			twice = twice or Withheld.maybe_ask_private(w, a, p[1])
	print("private asks: %d of %d owed pairs (expected about %.1f)" % [asked, tries, expect])
	_check(tries >= 20 and asked > 0 and asked < tries, "a good NPC sometimes asks a claimant for the reading its gift owes")
	_check(absf(asked - expect) <= maxf(6.0, expect * 0.6), "at about the approved rate")
	_check(not twice, "at most once per pair per day")
	# Not owed: claimed today, a reading already heard, a gift that reads after a hanging, an evil asker.
	var bad := false
	var cases := 0
	for sd in range(8000, 8030):
		var w = _world(sd)
		var p: Array = _pair(w)
		if p.is_empty():
			continue
		cases += 1
		var a = p[0]
		var c = p[1]
		a.known_claims[c.id]["first_claimed_day"] = w.day
		bad = bad or not Withheld.private_claim(w, a, c).is_empty()
		a.known_claims[c.id]["first_claimed_day"] = 1
		a.known_claims[c.id]["readings"] = [c.info_log[0]]
		bad = bad or not Withheld.private_claim(w, a, c).is_empty()
		a.known_claims[c.id] = {"role": "gravedigger", "readings": [], "via": c.id, "first_claimed_day": 1}
		bad = bad or not Withheld.private_claim(w, a, c).is_empty()
		var e = w.evil_team()[0]
		e.known_claims[c.id] = {"role": c.role, "readings": [], "via": c.id, "first_claimed_day": 1}
		bad = bad or not Withheld.private_claim(w, e, c).is_empty()
	_check(cases >= 10 and not bad, "never for a claim made today, a reading already heard, a Gravedigger's claim, or by an evil asker")

func _private_answers() -> void:
	var refused := 0
	var shape := true
	var later_shared := 0
	var shared_open := 0
	var cases := 0
	for sd in range(8100, 8140):
		var w = _world(sd)
		var p: Array = _pair(w)
		if p.is_empty():
			continue
		var a = p[0]
		var c = p[1]
		cases += 1
		_closed(c)
		c.npc_trust[a.id] = 0.0
		var claim: Dictionary = Withheld.private_claim(w, a, c)
		var r0: Dictionary = Withheld.answer_private(w, c, a, claim)
		if r0.outcome in ["deferred", "deflected"]:
			refused += 1
			var rec: Dictionary = w.withheld_refusals[-1]
			shape = shape and _shape_ok(rec) and rec.venue == "private" and rec.known_to == [a.id] and rec.asker == a.id and rec.claimant == c.id and rec.claim.role == c.role
			if r0.outcome == "deferred":
				shape = shape and rec.reason != ""
			# Open now: it tells the asker, and the refusal gets shared_at.
			c.traits["privacy"] = 0.0
			c.npc_trust[a.id] = 1.0
			c.pressure = 1.0
			var r1: Dictionary = Withheld.answer_private(w, c, a, claim)
			if r1.outcome == "shared":
				shared_open += 1
				later_shared += int(rec.has("shared_at") and rec.shared_at is int and not a.known_claims[c.id]["readings"].is_empty())
	print("closed claimants refused %d of %d; then answered %d (shared_at set %d)" % [refused, cases, shared_open, later_shared])
	_check(cases >= 10 and refused * 10 >= cases * 7, "a closed claimant that distrusts the asker mostly holds back")
	_check(shape, "each private refusal is on the record: the asker alone knows of it, with its claim, kind and reason")
	_check(shared_open >= 5 and later_shared == shared_open, "the reading told later reaches the asker, and the refusal gets shared_at")
	# A bluffer with a made-up reading answers.
	var bluffs := 0
	var answered := 0
	for sd in range(8200, 8240):
		var w = _world(sd)
		for e in w.evil_team():
			var role: String = str(w.evil_plan["bluffs"].get(e.id, ""))
			if role == "" or not C.has_role_def(role) or not C.role_def(role).first_night:
				continue
			var a = w.living_good()[0]
			a.known_claims[e.id] = {"role": role, "readings": [], "via": e.id, "first_claimed_day": 1}
			var claim: Dictionary = Withheld.private_claim(w, a, e)
			if claim.is_empty():
				continue
			bluffs += 1
			answered += int(Withheld.answer_private(w, e, a, claim).outcome == "shared")
			break
	print("bluffers asked: %d, answered with the made-up reading: %d" % [bluffs, answered])
	_check(bluffs >= 5 and answered * 10 >= bluffs * 8, "a bluffer with a made-up reading answers")

## A public claimant on day 1 that gave no reading, a confident presser that suspects it.
func _press_setup(w) -> Array:
	var c = null
	for m in w.living_good():
		if C.has_role_def(m.role) and C.role_def(m.role).first_night:
			c = m
			break
	if c == null:
		return []
	c.claim_public = true
	c.claimed_role = c.role
	w.public_claims.append({"day": 1, "who": c.id, "role": c.role})
	for e in c.info_log:
		e["shared"] = false
	var n = w.living_good().filter(func(m): return m != c)[0]
	n.traits["confidence"] = 1.0
	n.suspicion[c.id] = 0.6
	w.meeting = {"block": "", "block_count": 0, "nominated": [], "nominators": [], "results": [], "pending": {}}
	return [n, c]

func _meeting_press() -> void:
	var pressed := 0
	var tries := 0
	var twice := false
	var lines_ok := true
	var rec_ok := true
	var refusals := 0
	for sd in range(8300, 8380):
		var w = _world(sd)
		var p: Array = _press_setup(w)
		if p.is_empty():
			continue
		tries += 1
		var n = p[0]
		var c = p[1]
		_closed(c)
		c.trust = 0.0
		c.npc_trust[n.id] = 0.0
		c.traits["composure"] = 1.0
		var lines: Array = []
		var facts: Array = []
		var before: int = w.withheld_refusals.size()
		if Withheld.meeting_press(w, n, lines, facts):
			pressed += 1
			lines_ok = lines_ok and lines.size() >= 2 and str(lines[0].get("speaker", "")) == n.id and lines.slice(1).all(func(l): return str(l.get("speaker", "")) == c.id)
			var m2 = w.living_good().filter(func(m): return m != n and m != c)[0]
			m2.traits["confidence"] = 1.0
			m2.suspicion[c.id] = 0.6
			twice = twice or Withheld.meeting_press(w, m2, [], [])
	var want: float = Tuning.Meeting.PRESS_WITHHELD_SCALE
	print("meeting presses: %d of %d (approved chance at full confidence %.2f)" % [pressed, tries, want])
	_check(tries >= 30 and pressed > 0 and absf(float(pressed) / tries - want) < 0.15, "a confident NPC sometimes presses a suspected claimant that gave no reading, at about the approved rate")
	_check(lines_ok, "the press is spoken by the presser, the answer by the claimant")
	_check(not twice, "at most once per meeting")
	# A public claimant holds a reading back only for a reason, here an Unrequited's: it names
	# the one they love (burdens prototype). Pressed, it refuses, and that's on the record.
	for sd in range(8300, 8500):
		var w = _world(sd)
		var p: Array = _press_setup(w)
		if p.is_empty():
			continue
		var n = p[0]
		var c = p[1]
		if not MindCallOn._untold_sightings(w, c).is_empty() or not MindCallOn._untold_late(w, c).is_empty():
			continue
		var bel: String = ""
		for e in c.info_log:
			var who: Array = Gifts.implicated(e)
			if not who.is_empty() and who.size() <= 2 and not (c.id in who):
				bel = str(who[0])
				break
		if bel == "":
			continue
		c.secret_mod = "unrequited"
		c.beloved = bel
		n.traits["confidence"] = 1.0
		var before: int = w.withheld_refusals.size()
		var k: int = 0
		while k < 20 and not Withheld.meeting_press(w, n, [], []):
			k += 1
		if w.withheld_refusals.size() > before:
			refusals += 1
			var rec: Dictionary = w.withheld_refusals[-1]
			rec_ok = rec_ok and _shape_ok(rec) and rec.venue == "meeting" and rec.known_to == ["public"] and rec.asker == n.id and rec.claimant == c.id
	print("Unrequited claimants pressed, refusals recorded: %d" % refusals)
	_check(refusals >= 3 and rec_ok, "a refusal at the meeting is on the record as public, with the presser as the asker")
	# Not when not confident enough, not suspected enough, or once a reading is out.
	var bad := false
	for sd in range(8300, 8330):
		var w = _world(sd)
		var p: Array = _press_setup(w)
		if p.is_empty():
			continue
		p[0].traits["confidence"] = Tuning.Meeting.PRESS_WITHHELD_CONFIDENCE_MIN - 0.05
		bad = bad or Withheld.meeting_press(w, p[0], [], [])
		p[0].traits["confidence"] = 1.0
		p[0].suspicion[p[1].id] = Tuning.Meeting.GOOD_ACCUSE_MIN_SUSP - 0.05
		bad = bad or Withheld.meeting_press(w, p[0], [], [])
	_check(not bad, "never below the confidence floor, or short of the accusing level of suspicion")

func _call_on_record() -> void:
	var recs := 0
	var ok := true
	var shared_ok := 0
	for sd in range(8400, 8440):
		var w = _world(sd)
		var c = null
		for m in w.living_good():
			if not m.claim_public and m.info_log.any(func(e): return not e.get("shared", false)):
				c = m
				break
		if c == null:
			continue
		_closed(c)
		c.traits["composure"] = 1.0
		c.traits["confidence"] = 0.0
		c.traits["gossip"] = 0.0
		c.trust = 0.0
		var r: Dictionary = MindCallOn.respond(w, c)
		if not r.outcome in ["deferred", "deflected"]:
			continue
		recs += 1
		var rec: Dictionary = w.withheld_refusals[-1]
		ok = ok and _shape_ok(rec) and rec.asker == "player" and rec.venue == "meeting" and rec.known_to == ["public"]
		# The reading comes out before the town: the refusal gets shared_at.
		c.claim_public = true
		c.claimed_role = c.role
		MindMeeting._public_disclosure(w, c, [], [])
		shared_ok += int(rec.has("shared_at") or c.info_log.filter(func(e): return e.get("shared", false) and str(e.get("role", "")) == rec.claim.role and int(e.get("day", -1)) == rec.claim.day).is_empty())
	print("Call on refusals recorded: %d; shared_at after going public: %d" % [recs, shared_ok])
	_check(recs >= 5 and ok, "a refusal of the Demonologist's Call on is on the record, asker \"player\"")
	_check(shared_ok == recs, "when the reading comes out before the town, the refusal gets shared_at")
