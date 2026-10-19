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
