## Checks for the Oct 2026 quick-fix pass: roads, home cards, natural night names,
## relayed readings in the third person, the evil Medium's hearth, the Warden's doors,
## Martyr reluctance, case-summary attribution, and the demon's occasional zag.
##   godot --headless --path . --script res://tools/test_fixes.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const C = preload("res://sim/content.gd")
const CaseMetrics = preload("res://game/case_metrics.gd")
const Argue = preload("res://sim/argue.gd")
const CardList = preload("res://ui/card_list.gd")

var fails = 0

func _init() -> void:
	_roads()
	_home_cards()
	_wording()
	_medium_bluff()
	_warden_doors()
	_martyr_reluctance()
	_summary()
	_zag()
	_no_gift_denial()
	_where_were_you()
	_haunts()
	_offers()
	_martyr_templates()
	_new_conclusions()
	_own_lies()
	_corroboration()
	_claim_backed_options()
	print("FIXES FAILURES: %d" % fails)
	quit(1 if fails else 0)

func _game(sd: int, size: int = 10):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _roads() -> void:
	var direct = true
	for a in C.BLOCKS:
		for b in C.BLOCKS:
			if a != b and C.route(a, b).size() != 2:
				direct = false
	_check(direct, "every block has its own road to every other (routes are home -> destination)")

func _home_cards() -> void:
	var g = _game(7101)
	var homes: Array = g.board.filter(func(c): return c["kind"] == "home")
	_check(homes.size() == g.w.npcs.size(), "one home card per resident at the start")
	_check(homes.all(func(c): return g.w.by_id[c["subject"][0]].home_block == c["block"]), "home cards say where each person really lives")
	var n = g.w.npcs[0]
	g.w.by_id[n.id].busy_with = ""
	var r = g._route_present(n, str(homes[0]["n"]))
	_check(r.has("flat"), "a home card can't be presented to anyone")

func _wording() -> void:
	_check(C.natural_nights("Fenwick says they were home on night 0.") == "Fenwick says they were home on the night before you arrived.", "night 0 reads as the night before you arrived")
	_check(C.natural_nights("night 10 and night 1") == "night 10 and night 1", "other nights are untouched")
	_check(C.third_person("I looked at Greta and Jory: one of them reads as the demon") == "they looked at Greta and Jory: one of them reads as the demon", "relayed readings are retold in the third person")
	var g = _game(7102)
	var bad = 0
	for c in g.board:
		if "night 0" in c.get("text", "") or "Night 0" in c.get("text", ""):
			bad += 1
	for i in range(6):
		g.command("wait")
	for c in g.board:
		if "night 0" in c.get("text", "") or "Night 0" in c.get("text", ""):
			bad += 1
	_check(bad == 0, "no card says 'night 0'")

## An evil Medium bluff's night story names the hearth of its fake reading, not where it was.
func _medium_bluff() -> void:
	var g = _game(7103)
	var w = g.w
	var ev = w.npcs.filter(func(x): return x.is_evil())[0]
	var dead = w.npcs.filter(func(x): return not x.is_evil() and x != ev and x.home_block != "docks")[0]
	dead.alive = false
	dead.death_day = 1
	ev.claimed_role = "medium"
	ev.claim_public = true
	ev.info_log.append({"day": 2, "role": "medium", "fake": true, "data": {"dead": dead.id, "item": {}}, "text": "x"})
	ev.history[w.time_key(2, C.NIGHT)] = "night:docks"
	w.day = 3
	var r = Mind.answer_night(w, ev, 2)
	var out: Array = r["facts"].filter(func(f): return f.get("duty_claim", false))
	_check(not out.is_empty() and out[0]["block"] == dead.home_block, "evil Medium claims the hearth's block (%s), not where they were (docks)" % dead.home_block)
	_check(r["lines"].any(func(l): return l is Dictionary and dead.name in l["text"]), "the Medium names whose hearth")
	# Fake readings visit each of the dead once, most recent first.
	var fresh = _game(7104)
	var w2 = fresh.w
	var mate = w2.npcs.filter(func(x): return x.is_evil())[0]
	w2.evil_plan["bluffs"][mate.id] = "medium"
	var goods: Array = w2.npcs.filter(func(x): return not x.is_evil())
	goods[0].alive = false
	goods[0].death_day = 1
	goods[1].alive = false
	goods[1].death_day = 2
	var seen: Array = []
	for d in [2, 3, 4]:
		w2.day = d
		Evil.make_fake_info(w2)
		for e in mate.info_log:
			if e.get("role", "") == "medium" and e.get("day", -1) == d:
				seen.append(e["data"]["dead"])
	_check(seen.size() >= 2 and seen[0] == goods[1].id and seen[1] == goods[0].id and seen.size() == 2, "fake Medium readings: most recent dead first, each once (%s)" % str(seen))

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

func _martyr_reluctance() -> void:
	var g = _game(7106)
	var w = g.w
	var m = w.npcs.filter(func(x): return not x.is_evil())[0]
	var t = w.npcs.filter(func(x): return not x.is_evil() and x != m)[0]
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

func _summary() -> void:
	var g = _game(7107)
	var w = g.w
	var mart = w.npcs.filter(func(x): return not x.is_evil())[0]
	var saved = w.npcs.filter(func(x): return not x.is_evil() and x != mart)[0]
	w.executions.append({"day": 2, "id": mart.id, "saved": saved.id, "martyr": true, "nominator": "player", "yes": [], "player_yes": false, "player_nominated": true})
	var first = w.demon_id
	var sc = w.npcs.filter(func(x): return x.is_evil() and x.id != first)[0]
	w.demon_id = sc.id   # as if a Scion had taken over
	var s = CaseMetrics.summarize(w, {"guesses": {first: {"guess": "demon", "confidence": 3}}}, false, g.board)
	var row: Dictionary = s["executions"][0]
	_check(row["id"] == saved.id and row.get("martyr_died", "") == mart.id and row["nominator"] == "player", "a Martyr's death is recorded against the nomination it answered")
	_check(s["executions_good"] == 1, "...and counts as a good death at the gallows")
	_check(s["demon_identified"], "naming the demon the case started with counts, after a Scion takes over")

func _zag() -> void:
	var zags = 0
	var nights = 0
	for sd in range(7200, 7260):
		var g = _game(sd)
		for i in range(3):
			Evil.choose_kill_target(g.w)
			nights += 1
		for e in g.w.dlog.entries:
			if e["type"] == "think" and e["data"].get("topic", "") == "kill_choice" and e["data"].get("zag", false):
				zags += 1
	_check(zags >= 1 and zags <= nights * 0.12, "the demon sometimes skips its top three (%d of %d choices)" % [zags, nights])

func _no_gift_denial() -> void:
	var denials = 0
	for sd in range(7300, 7320):
		var g = _game(sd)
		for n in g.w.npcs:
			n.trust = 0.0
			n.traits["privacy"] = 1.0
			var r = Mind.answer_gift(g.w, n)
			if r["facts"].any(func(f): return f["kind"] == "claim" and f.get("role", "") == "none"):
				denials += 1
	_check(denials == 0, "nobody denies having a gift (the knob is off)")

func _talk_to(g, n) -> void:
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 3
	g.free_repeats = 0
	g.talk_offered = false
	g.talk_approached = false
	g.loc = n.loc if C.LOCATIONS.has(n.loc) else "tavern"

func _where_were_you() -> void:
	var g = _game(7110)
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
	var t: String = r["lines"][0]["text"]
	_check(t.begins_with("Yesterday afternoon I was "), "a timeframe answer starts with where they were (%s)" % t)
	g.command("ask seen yesterday morning")
	_check(g.last_events.any(func(e): return e["k"] == "speech" and "Yesterday morning I was" in e["text"]), "'ask seen yesterday morning' works as a command")

func _haunts() -> void:
	var g = _game(7111)
	var w = g.w
	var t = w.npcs[1]
	_check(g.profile_data(t.id)["haunts"] == "", "nobody's haunts are known at the start")
	var told = false
	for n in w.npcs:
		if n == t:
			continue
		n.traits["gossip"] = 1.0
		n.trust = 1.0
		n.silenced = false
		for k in range(6):
			_talk_to(g, n)
			g.command("ask about " + t.id)
			if g.known_haunts.has(t.id):
				told = true
				break
		if told:
			break
	_check(told and g.known_haunts[t.id].all(func(x): return x in t.haunts), "asking a chatty, trusting person about someone can reveal their haunts")
	_check(g.board.any(func(c): return c["kind"] == "haunt" and c["subject"] == [t.id]), "a revealed haunt is a card")
	_check(g.profile_data(t.id)["haunts"] != "", "the profile shows haunts once you've been told")

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

func _templates_for(g, nums: Array) -> Array:
	return g.link_cards(nums)["result"]["matches"].map(func(m): return m["template"])

func _martyr_templates() -> void:
	var g = _game(7120)
	var w = g.w
	g.board = []
	g._card_keys = {}
	var ids: Array = w.npcs.map(func(n): return n.id)
	var a: String = ids[0]
	var b: String = ids[1]
	var c: String = ids[2]
	var d: String = ids[3]
	var km = g.add_card({"kind": "martyr", "subject": [a, b], "source": "player", "day": 3, "phase": C.EVENING, "text": "M died for B"})
	var kseer = g.add_card({"kind": "info", "subject": [b, c], "source": d, "day": 2, "role": "seer", "data": {"pair": [b, c], "yes": true}, "text": "D seer yes B,C"})
	var karch = g.add_card({"kind": "info", "subject": [a, b], "source": c, "day": 0, "role": "archivist", "data": {"pair": [a, b], "role": "revenant"}, "text": "C archivist A,B revenant"})
	_check("pair_elimination" in _templates_for(g, [kseer, km]), "a Martyr's save clears its nominee for pair elimination")
	_check("pair_both_good" in _templates_for(g, [karch, km]), "a pair reading naming two proven-good people is false")
	_check(not ("pair_elimination" in _templates_for(g, [karch, km])), "...and doesn't 'leave' one of them")
	var kgood = g.add_card({"kind": "deduction", "subject": [c], "source": "player", "conclusion": {"type": "good", "a": c}, "supports": [km], "text": "C is good"})
	_check("pair_elimination" in _templates_for(g, [kseer, kgood]), "a filed 'X is good' deduction works as a template input")
	var kchose = g.add_card({"kind": "info", "subject": [d, c], "source": d, "day": 1, "role": "martyr", "data": {"target": c, "chosen": true}, "text": "D chose C"})
	var kex = g.add_card({"kind": "execution", "subject": [c], "source": "player", "day": 4, "phase": C.EVENING, "alive_before": 6, "text": "C hanged"})
	var mm = g.link_cards([kchose, kex])["result"]["matches"].filter(func(m): return m["template"] == "martyr_no_save")
	_check(not mm.is_empty(), "the chosen hanged and the Martyr still standing is a template")
	if not mm.is_empty():
		var kinds: Array = mm[0]["explanations"].map(func(e): return e["conclusion"].get("type", ""))
		_check("evil" in kinds and "marked" in kinds and "lied" in kinds, "...offering evil, Marked, or the Martyr lied (%s)" % str(kinds))

func _new_conclusions() -> void:
	for pair in [["suspicious", "suspicious"], ["hiding a secret", "secret"], ["Marked", "marked"], ["the Seer's red herring", "red_herring"]]:
		_check(Argue.from_builder("x", "is", pair[0]).get("type", "") == pair[1], "typed: 'is %s'" % pair[0])
		_check(Argue.from_builder("x", "is", pair[1], -1, -1, true).get("type", "") == pair[1], "builder: %s" % pair[1])
	var sm = Argue.from_builder("x", "is", "a Sleepwalker")
	_check(sm.get("type", "") == "secret_mod" and sm.get("mod", "") == "sleepwalker", "typed: 'is a Sleepwalker'")
	var ev = Argue.from_builder("x", "is", "poisoner", -1, -1, true)
	_check(ev.get("type", "") == "role" and ev.get("role", "") == "poisoner", "evil roles can be concluded")
	var g = _game(7121)
	var w = g.w
	var t = w.npcs[0]
	var e: Array = Argue.effects_of(w, {"type": "role", "a": t.id, "role": "poisoner"}, [], "x")
	_check(e.any(func(x): return x[0] == t.id and x[1] > 0.0), "concluding someone is the Poisoner raises suspicion of them")
	var e2: Array = Argue.effects_of(w, {"type": "suspicious", "a": t.id}, [], "x")
	_check(e2.any(func(x): return x[0] == t.id and x[1] > 0.0 and x[1] <= 0.2), "'suspicious' is a small push")
	var e3: Array = Argue.effects_of(w, {"type": "marked", "a": t.id}, [], "x")
	_check(e3.any(func(x): return x[0] == t.id and x[1] < 0.0), "'Marked' speaks for them")

func _own_lies() -> void:
	var g = _game(7122)
	var w = g.w
	var n = w.living_good()[0]
	w.day = 3
	n.history[w.time_key(2, C.NIGHT)] = "night:" + n.home_block
	g.board = []
	g._card_keys = {}
	var lie = g.add_card({"kind": "alibi", "subject": [n.id], "home": true, "day": 2, "phase": C.NIGHT, "source": n.id, "block": n.home_block, "text": "N says home n2"})
	var seen = g.add_card({"kind": "sighting", "subject": [n.id], "block": n.home_block, "day": 2, "phase": C.NIGHT, "source": "player", "vigil": true, "text": "vigil saw N n2"})
	var dn = g.file_deduction({"type": "lied", "a": n.id, "card": lie}, [lie, seen])
	var t0 = n.trust
	n.traits["privacy"] = 0.0
	n.pressure = 1.0
	n.trust = 1.0
	var r = Argue.evaluate(w, n, g.board[dn - 1], g.board, 1.0)
	var line: String = r["lines"][0]["text"] if not r["lines"].is_empty() else ""
	_check(not ("I know it's false" in line), "caught in their own lie, they don't call it false (%s)" % line)
	_check("wasn't where I said" in line, "an open, pressed NPC owns up")
	# Later, telling you their walking gift, they own the lie.
	n.role = "lamplighter"
	n.lied_nights = [2]
	n.claim_public = false
	n.max_tier = 0
	var r2 = Mind.answer_gift(w, n, 3)
	var txt = " ".join(PackedStringArray(r2["lines"].filter(func(l): return l is Dictionary).map(func(l): return l["text"])))
	_check("I was out" in txt and "wasn't ready to tell you why" in txt, "disclosing the gift, they own the earlier lie (%s)" % txt)

func _corroboration() -> void:
	var g = _game(7130)
	var w = g.w
	g.board = []
	g._card_keys = {}
	g._fact_keys = {}
	var ids: Array = w.living().map(func(n): return n.id)
	var x: String = ids[0]
	var y: String = ids[1]
	var wit = w.by_id[ids[2]]
	var listener = w.by_id[ids[3]]
	var mine = g.add_card({"kind": "conversation", "subject": [x, y], "block": "square", "loc": "tavern", "day": 1, "phase": 0, "source": "player", "text": "You saw X and Y talking"})
	var theirs = g.add_card({"kind": "sighting", "subject": [x], "block": "square", "day": 1, "phase": 0, "source": wit.id, "text": "W saw X on the square"})
	_check(wit.id in g.board[mine - 1].get("corroborated_by", []) and "player" in g.board[theirs - 1].get("corroborated_by", []), "the same fact from you and a witness: each card names the other source")
	_check("also seen by" in CardList.line_for(g.board[mine - 1]), "the card list says who else saw it")
	_check("corroborated" in _templates_for(g, [mine, theirs]), "your sighting and a witness's link as corroboration")
	listener.trust = 0.0
	listener.suspicion[wit.id] = 0.0
	var plain = {"kind": "sighting", "subject": [x], "source": "player", "text": "x"}
	_check(Mind.word_factor(w, listener, g.board[mine - 1]) > Mind.word_factor(w, listener, plain), "a trusted witness lifts your word with someone who doesn't trust you")
	# A witness asked about a pair you saw yourself leaves it out and backs your card instead.
	var seen = g.seen_pairs()
	_check(not seen.is_empty(), "your own conversation cards are known as seen pairs")
	var n = w.by_id[ids[4]]
	n.traits["gossip"] = 1.0
	n.traits["insight"] = 1.0
	n.beliefs.append({"kind": "saw", "who": x, "loc": "tavern", "block": "square", "day": 1, "phase": 0, "how": "street", "with": y})
	w.day = 1
	w.phase = 1
	var r = Mind.answer_today(w, n, "morning", "", seen)
	var t: String = r["lines"][0]["text"]
	_check(not (w.by_id[x].name + " at") in t, "a pair you saw yourself isn't repeated to you (%s)" % t)
	_check(r["facts"].any(func(f): return f.get("silent", false)), "...but it's kept as silent backing")
	g._facts(r["facts"])
	_check(n.id in g.board[mine - 1].get("corroborated_by", []), "...which lands on your card")

func _claim_backed_options() -> void:
	var g = _game(7140)
	var w = g.w
	g.board = []
	g._card_keys = {}
	g._fact_keys = {}
	var ids: Array = w.living().map(func(n): return n.id)
	var f: String = ids[0]
	var nn: String = ids[1]
	var ag: String = ids[2]
	var kc = g.add_card({"kind": "claim", "subject": [f], "role": "lamplighter", "source": f, "text": "F claims Lamplighter"})
	var kr = g.add_card({"kind": "info", "subject": [f, nn], "source": ag, "day": 0, "role": "clerk", "data": {"pair": [f, nn], "role": "lamplighter"}, "text": "A clerk: F or N lamplighter"})
	var lk = g.link_cards([kc, kr])
	var labels: Array = lk["options"].map(func(o): return o["expl"]["label"])
	_check(not labels.any(func(x): return "misled" in x), "a corroboration doesn't offer 'the reader was misled' for filing (%s)" % str(labels))
	_check(labels.any(func(x): return "working together" in x), "...but offers 'both lying, working together'")
	_check(labels.any(func(x): return ("is the Lamplighter" in x) and ("lying" in x)), "...and words the other half plainly")
	var m: Dictionary = lk["result"]["matches"][0]
	_check(m["explanations"].any(func(e): return e.get("rival_only", false)), "the misled rival is still there for NPCs to weigh")

