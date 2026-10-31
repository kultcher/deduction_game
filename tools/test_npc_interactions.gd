## NPC interactions (Oct 25 batch): personality through others, Lovers' grief, confidences
## as an NPC request, protection requests (and the Demon's vigil rule), apologies, and
## asking someone to use their gift a particular way tonight.
##   godot --headless --path . --script res://tools/test_npc_interactions.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Social = preload("res://sim/social.gd")
const C = preload("res://sim/content.gd")

var fails = 0
var checks = 0

func _init() -> void:
	_traits_through_others()
	_lovers_grieve()
	_confidence_request()
	_protection_kinds()
	_protection_flow()
	_protection_slows_going_public()
	_apologies()
	_gift_requests()
	_evil_gift_requests()
	print("NPC interactions: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(sd: int, size: int = 10):
	var g = Game.new()
	g.workshop_effects = false
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _talk_to(g, n) -> void:
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 3
	g.free_repeats = 0
	g.talk_offered = false
	g.talk_approached = false
	g.pending_request = {}
	g.loc = n.loc if C.LOCATIONS.has(n.loc) else "tavern"

func _goods(w) -> Array:
	return w.living_good()

func _traits_through_others() -> void:
	var g = _game(8101)
	var w = g.w
	var n = _goods(w)[0]
	var t = _goods(w)[1]
	n.traits["gossip"] = 1.0
	n.trust = 1.0
	n.friends = []
	n.rivals = []
	var learned = false
	var text_ok = true
	for i in range(40):
		var r = {"lines": [], "facts": []}
		g._maybe_tell_trait(n, t, r)
		if r.has("narration"):
			learned = true
			var key: String = t.revealed_traits.keys()[t.revealed_traits.size() - 1]
			text_ok = text_ok and key in Game.OBSERVABLE_TRAITS and r["narration"][0].contains(t.name)
	_check(learned, "asked about someone, a gossipy talker sometimes says what they're like")
	_check(text_ok, "a non-friend only tells observable traits, with a narration note")
	_check(t.revealed_traits.size() <= Game.OBSERVABLE_TRAITS.size(), "no duplicate reveals")
	var quiet = _goods(w)[2]
	quiet.traits["gossip"] = 0.0
	quiet.pressure = 0.0
	var before = t.revealed_traits.size()
	for i in range(20):
		g._maybe_tell_trait(quiet, _goods(w)[3], {"lines": [], "facts": []})
	_check(not _goods(w)[3].revealed_traits.is_empty() and t.revealed_traits.size() == before, "low Gossip still permits occasional trait sharing without changing another person's profile")

func _lovers_grieve() -> void:
	var g = _game(8102)
	var w = g.w
	var a = _goods(w)[0]
	var b = _goods(w)[1]
	a.secret_mod = "lovers"
	b.secret_mod = "lovers"
	a.lover = b.id
	b.lover = a.id
	var comp: float = b.traits["composure"]
	a.alive = false
	w._bereave(a)
	_check(b.traits["privacy"] == 1.0 and b.traits["gossip"] == 0.0, "a Lover's death leaves the survivor withdrawn (Privacy max, Gossip none)")
	_check(is_equal_approx(b.traits["composure"], minf(1.0, comp + 0.3)), "and more composed")
	_check(b.withdrawn_since == a.id, "remembered as withdrawn since that death")
	var prof: Dictionary = g.profile_data(b.id)
	_check(str(prof).contains("withdrawn since"), "the profile shows it")
	var c = _goods(w)[2]
	var d = _goods(w)[3]
	d.alive = false
	var pc: float = c.traits["privacy"]
	w._bereave(d)
	_check(c.traits["privacy"] == pc and c.withdrawn_since == "", "only Lovers grieve this way")

func _confidence_request() -> void:
	var g = _game(8103)
	var w = g.w
	var n = _goods(w)[0]
	n.trust = 0.9
	n.traits["composure"] = 0.0
	n.claim_public = false
	var rq: Dictionary = {}
	for i in range(60):
		n.request_day = -1
		rq = Mind._confidence_request(w, n, 3, {"kind": "refusal", "subject": [n.id], "source": n.id, "text": "x"})
		if not rq.is_empty():
			break
	_check(rq.get("kind", "") == "confidence", "a nervous, trusting NPC may ask you to keep their answer quiet")
	_check(Mind._confidence_request(w, n, 3, {}).is_empty(), "at most one request a day")
	_talk_to(g, n)
	g.pending_request = rq
	var q: int = g.questions_left
	g.command("yes")
	_check(g.questions_left == q, "answering the request is free")
	_check(g.confidences.values().has(n.id), "cards from that answer are confidential")
	var num = g.confidences.keys()[0]
	var tr: float = n.trust
	g._break_confidences([num])
	var expected: float = 0.05 + 0.2 * n.traits["privacy"]
	_check(absf((tr - n.trust) - expected) < 0.011, "using one at the meeting costs 0.05 + 0.2 x Privacy (%.2f)" % expected)
	# No: the refusal they'd have given, still free; anything else is also no.
	var m = _goods(w)[1]
	_talk_to(g, m)
	g.pending_request = {"kind": "confidence", "npc": m.id, "tier": 3,
		"decline": {"lines": [Mind.say(m, "Then it stays with me.")], "facts": [{"kind": "refusal", "subject": [m.id], "source": m.id, "private": true, "text": "%s refused." % m.name}]}}
	var cards: int = g.board.size()
	g.command("no")
	_check(g.questions_left == 3 and g.board.size() == cards + 1 and g.pending_request.is_empty(), "declining is free and records the refusal")
	g.pending_request = {"kind": "confidence", "npc": m.id, "tier": 3, "decline": {"lines": [], "facts": []}}
	g.command("ask night")
	_check(g.pending_request.is_empty() and g.questions_left == 2, "any other command declines and goes ahead")
	# A going-public NPC's confidence lapses.
	g.confidences[999] = n.id
	n.claim_public = true
	var tr2: float = n.trust
	g._break_confidences([999])
	_check(n.trust == tr2, "the promise lapses once they've gone public")

func _protection_kinds() -> void:
	var g = _game(8104)
	var w = g.w
	var good = _goods(w)[0]
	_check(Mind.protection_kind(w, good) == "vigil", "the good ask for a vigil")
	var demon = w.by_id[w.demon_id]
	var saved: String = w.evil_plan["bluffs"].get(demon.id, "")
	w.evil_plan["bluffs"][demon.id] = "seer"
	_check(Mind.protection_kind(w, demon) == "ward", "the Demon bluffing a stay-at-home gift asks for the ward, never a vigil")
	w.tools["ward"] = 0
	_check(Mind.protection_kind(w, demon) == "", "and asks for nothing once the ward is spent")
	w.evil_plan["bluffs"][demon.id] = "nightwatch"
	_check(Mind.protection_kind(w, demon) == "vigil", "a Demon bluffing a night-walking gift may ask for a vigil")
	w.evil_plan["bluffs"][demon.id] = saved
	w.tools["ward"] = 1

func _protection_flow() -> void:
	var told_now = 0
	var deferred = 0
	var divulged = 0
	var eased = 0
	var broke_ok = 0
	for sd in range(8110, 8130):
		var g = _game(sd)
		var w = g.w
		var n = _goods(w)[0]
		n.trust = 0.6
		n.claim_public = false
		n.max_tier = 0
		_talk_to(g, n)
		g.pending_request = {"kind": "protect", "npc": n.id, "what": "vigil", "decline": {"lines": [], "facts": []}}
		g.command("yes")
		if not g.offer.get("vigil", {}).has(n.id):
			continue
		if g.protect_pending.has(n.id):
			deferred += 1
			_check(n.protect_lock, "a deferred disclosure locks in their promise")
			var keep: bool = sd % 2 == 0
			g.state = "night"
			if keep:
				g.command("vigil " + n.home_block)
				if n.fear_eased and n.id in g.divulge_due:
					eased += 1
					g.state = "day"
					n.loc = "tavern"
					n.working = false
					n.busy_with = ""
					var cards: int = g.board.size()
					if g._maybe_divulge():
						var claimed: bool = g.board.slice(cards).any(func(c): return c["kind"] == "claim" and n.id in c["subject"])
						if claimed and g.state == "approach" and g.approach["agenda"] == "divulge" and not n.protect_lock:
							divulged += 1
			else:
				g.command("sleep")
				if not n.fear_eased and not n.protect_lock and g.divulge_due.is_empty():
					broke_ok += 1
		else:
			told_now += 1
	_check(told_now + deferred >= 15, "yes to a protection request becomes the usual promise (%d of 20)" % (told_now + deferred))
	_check(told_now > 0 and deferred > 0, "trust x Composure decides whether they tell now (%d) or after you keep your word (%d)" % [told_now, deferred])
	_check(eased > 0 and divulged == eased, "kept: fear eased, and next day they come and tell their gift for free (%d/%d)" % [divulged, eased])
	_check(broke_ok > 0, "broken: no disclosure, and the fear returns")
	# The fear term halves (the roll is per person and day, so count across people).
	var afraid_plain = 0
	var afraid_eased = 0
	for sd in range(8131, 8151):
		var w2 = _game(sd).w
		for a in w2.living():
			a.traits["composure"] = 0.0
			a.fear_eased = false
			afraid_plain += int(Mind._afraid(w2, a))
			a.fear_eased = true
			afraid_eased += int(Mind._afraid(w2, a))
	_check(afraid_eased < afraid_plain * 0.75, "a kept promise makes them less afraid (%d -> %d people)" % [afraid_plain, afraid_eased])

func _protection_slows_going_public() -> void:
	var g = _game(8140)
	var w = g.w
	var n = _goods(w)[0]
	n.traits["privacy"] = 0.3
	n.pressure = 0.2
	w.day = 2
	var free = 0
	var locked = 0
	var nominated = 0
	for i in range(300):
		n.protect_lock = false
		free += int(Mind._public_claim_decision(w, n) != "")
		n.protect_lock = true
		locked += int(Mind._public_claim_decision(w, n) != "")
	w.meeting["nominated"] = [n.id]
	for i in range(300):
		nominated += int(Mind._public_claim_decision(w, n) != "")
	w.meeting["nominated"] = []
	_check(locked < free * 0.8, "a pending promise makes going public harder (%d -> %d of 300)" % [free, locked])
	_check(nominated > locked, "unless they're nominated (%d)" % nominated)

func _apologies() -> void:
	var g = _game(8150)
	var w = g.w
	var n = _goods(w)[0]
	n.trust = 0.8
	n.trust_cap = 1.0
	Mind.set_trust(w, n, n.trust - 0.08, "the Demonologist guessed my gift wrong (seer; 1 wrong so far)")
	_check(Mind.open_grievances(n).size() == 1, "a trust drop is remembered as an incident")
	_talk_to(g, n)
	var t0: float = n.trust
	g.command("apologise 1")
	_check(absf((n.trust - t0) - 0.04) < 0.006, "apologising for a minor incident repairs half (%.3f)" % (n.trust - t0))
	_check(g.questions_left == 2, "an apology uses a question")
	_check(Mind.open_grievances(n).is_empty(), "once per incident")
	var t1: float = n.trust
	g.command("apologise 1")
	_check(n.trust == t1 and g.questions_left == 2, "nothing left to apologise for: no effect, no question")
	Mind.set_trust(w, n, n.trust - 0.16, "the Demonologist broke their word (vigil)")
	var t2: float = n.trust
	Mind.apologise(w, n, 0)
	_check(absf((n.trust - t2) - 0.04) < 0.006, "a serious incident: a quarter back")
	# Evidence against them: a sharp listener forgives less.
	var sharp = _goods(w)[1]
	var dull = _goods(w)[2]
	for x in [sharp, dull]:
		x.trust = 0.8
		x.trust_cap = 1.0
		Mind.set_trust(w, x, x.trust - 0.08, "the Demonologist pressed me with evidence")
	sharp.traits["insight"] = 1.0
	dull.traits["insight"] = 0.2
	var s0: float = sharp.trust
	var d0: float = dull.trust
	Mind.apologise(w, sharp, 0)
	Mind.apologise(w, dull, 0)
	_check(sharp.trust - s0 < dull.trust - d0, "a high-Insight NPC forgives less when you acted on evidence")
	# Caps hold.
	var capped = _goods(w)[3]
	capped.trust = 0.5
	capped.trust_cap = 1.0
	Mind.set_trust(w, capped, 0.4, "the Demonologist spoke against me")
	capped.trust_cap = 0.4
	Mind.apologise(w, capped, 0)
	_check(capped.trust <= 0.4, "an apology never lifts trust past a cap")
	# Same kind of incident the same day is one incident.
	var p = _goods(w)[4]
	p.trust = 0.9
	Mind.set_trust(w, p, 0.85, "pressed with 4 questions today")
	Mind.set_trust(w, p, 0.8, "pressed with 5 questions today")
	_check(Mind.open_grievances(p).size() == 1, "repeated pressing on one day is one incident")

func _gift_requests() -> void:
	var g = _game(8160)
	var w = g.w
	var n = _goods(w)[0]
	var others: Array = w.living().filter(func(m): return m != n)
	n.role = "seer"
	n.claimed_role = "seer"
	n.max_tier = 3
	n.trust = 1.0
	_talk_to(g, n)
	g.command("ask check %s, %s" % [others[0].id, others[1].id])
	_check(g.questions_left == 2, "asking someone to use their gift costs a question")
	_check(Mind.requested_targets(w, n, "seer") == [others[0].id, others[1].id], "a trusting Seer agrees")
	_check(Mind.seer_picks(w, n) == [others[0].id, others[1].id], "and looks there tonight")
	w.day += 1
	_check(Mind.requested_targets(w, n, "seer").is_empty(), "for that night only")
	w.day -= 1
	var cold = _goods(w)[1]
	cold.role = "warden"
	cold.claimed_role = "warden"
	cold.max_tier = 3
	cold.trust = 0.0
	var agreed = 0
	for i in range(20):
		cold.gift_request = {}
		var r: Dictionary = Mind.consider_gift_request(w, cold, "warden", [others[2].id])
		agreed += int(r["agreed"])
	_check(agreed < 6, "a distrustful Warden mostly refuses (%d of 20)" % agreed)
	cold.trust = 1.0
	cold.gift_request = {}
	var ok = false
	for i in range(10):
		if Mind.consider_gift_request(w, cold, "warden", [others[2].id])["agreed"]:
			ok = true
			break
	_check(ok and Mind.warden_target(w, cold) == others[2].id, "an agreed Warden guards whom you asked")
	var watch = _goods(w)[2]
	watch.role = "nightwatch"
	watch.claimed_role = "nightwatch"
	watch.max_tier = 3
	watch.trust = 1.0
	var blk: String = C.BLOCKS.keys()[0]
	for i in range(10):
		if Mind.consider_gift_request(w, watch, "nightwatch", [blk])["agreed"]:
			break
	_check(Mind.watch_block(w, watch) == blk, "an agreed Night Watch watches the block you asked")
	var stranger = _goods(w)[3]
	_talk_to(g, stranger)
	stranger.max_tier = 0
	g.command("ask guard " + others[0].id)
	_check(g.questions_left == 3, "you can only ask someone who told you their gift (no question spent)")

func _evil_gift_requests() -> void:
	var g = _game(8170)
	var w = g.w
	var e = w.evil_team()[0]
	w.evil_plan["bluffs"][e.id] = "seer"
	var goods: Array = w.living_good().map(func(x): return x.id)
	e.gift_request = {"night": w.day, "role": "seer", "targets": [goods[0], goods[1]]}
	var before: int = e.info_log.size()
	Evil.make_fake_info(w)
	var made: Array = e.info_log.slice(before).filter(func(x): return x.get("role", "") == "seer")
	_check(not made.is_empty() and made[0]["data"]["pair"].has(goods[0]) and made[0]["data"]["pair"].has(goods[1]), "an evil Seer bluff fakes a reading on the pair you asked for")
	var s: String = w.evil_plan["scapegoat"]
	_check(made.is_empty() or made[0]["data"]["yes"] == (s in made[0]["data"]["pair"]), "and only says 'yes' to frame its scapegoat")
	w.evil_plan["bluffs"][e.id] = "warden"
	e.gift_request = {"night": w.day, "role": "warden", "targets": [goods[2]]}
	Evil.make_fake_info(w)
	_check(Mind.warden_door(w, e, w.day) == goods[2], "an evil Warden bluff names the door you asked it to guard")
