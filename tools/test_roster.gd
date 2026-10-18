## Tests for the roster: setup sizes and protections, secret modifiers, and each new
## gift's mechanics (Martyr, Revenant, Scion, Sexton, Veteran, Breathstealer, Dowser,
## Medium, Psychologist, Lamplighter, Marked, Delusional, Sleepwalker, Lovers).
##   godot --headless --path . --script res://tools/test_roster.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const C = preload("res://sim/content.gd")
const Argue = preload("res://sim/argue.gd")

var fails = 0

func _init() -> void:
	_test_setup(7)
	_test_setup(10)
	_test_martyr_save()
	_test_martyr_evil()
	_test_revenant_curse()
	_test_revenant_fizzle()
	_test_totem_once_per_day()
	_test_scion()
	_test_sexton()
	_test_veteran()
	_test_breathstealer()
	_test_dowser()
	_test_medium_priority()
	_test_psychologist()
	_test_lamplighter()
	_test_marked_and_delusional()
	_test_sleepwalker()
	_test_lovers()
	_test_night_suspicion()
	_test_spent_gift_kills()
	_test_templates()
	_test_homes_and_bluffs()
	_test_seer_insight()
	print("FAILURES: %d" % fails)
	quit()

func _game(sd: int, size: int = 7):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g

## Give a good NPC a role (swapping with whoever holds it, so roles stay unique).
func _give(w, n, role: String) -> void:
	var holder = w.npc_with_role(role)
	if holder != null and holder != n:
		holder.role = n.role
	n.role = role

func _test_setup(size: int) -> void:
	var bad: Array = []
	var mods = {}
	for sd in range(9000, 9060):
		var w = _game(sd, size).w
		var cfg: Dictionary = C.SETUPS[size]
		var roles: Array = w.npcs.map(func(n): return n.role)
		var town: Array = roles.filter(func(r): return r in C.GOOD_ROLES)
		var mins: Array = roles.filter(func(r): return C.is_minion(r))
		var uniq = {}
		for r in roles:
			uniq[r] = true
		var holders: Array = w.npcs.filter(func(n): return n.secret_mod != "")
		var kinds = {}
		for h in holders:
			kinds[h.secret_mod] = true
		var ok = w.npcs.size() == size and town.size() == cfg["town"] and mins.size() == cfg["minions"] \
			and roles.count("demon") == 1 and uniq.size() == size \
			and town.filter(func(r): return r in C.START_ROLES).size() >= 2 \
			and town.filter(func(r): return r in C.IDENTIFIER_ROLES).size() >= 1 \
			and kinds.size() == 1 and holders.all(func(h): return not h.is_evil()) \
			and holders.size() == (2 if kinds.has("lovers") else 1)
		for k in kinds:
			mods[k] = true
		if not ok:
			bad.append(sd)
	print("%d-player setups: bad seeds %s; secrets seen %s" % [size, str(bad), str(mods.keys())])
	_check(bad.is_empty(), "%d-player setup: right counts, unique roles, 2+ start gifts, an identifier, one secret on the good" % size)
	_check(mods.size() == 4, "%d-player: all four secrets turn up" % size)

func _test_martyr_save() -> void:
	var w = _game(9100).w
	w.day = 2
	var goods: Array = w.living_good()
	var mart = goods[0]
	var target = goods[1]
	_give(w, mart, "martyr")
	mart.secret_mod = ""
	mart.poisoned = false
	mart.martyr_target = target.id
	w.begin_meeting()
	w.execute(target.id, {"by": "player", "yes": [], "player_yes": true})
	_check(target.alive and not mart.alive and mart.death_cause == "martyr", "the Martyr dies in a good target's place")
	var l = w.living_good().filter(func(x): return x != target)[0]
	_check(l.cleared.has(target.id) and l.cleared.has(mart.id) and Mind.susp(l, target.id) < 0.05, "the town knows both are good")
	_check(not w.game_over or w.winner != "good", "the case goes on")

func _test_martyr_evil() -> void:
	var w = _game(9101).w
	w.day = 2
	var mart = w.living_good()[0]
	_give(w, mart, "martyr")
	mart.secret_mod = ""
	mart.poisoned = false
	var ev = w.minions()[0]
	mart.martyr_target = ev.id
	w.begin_meeting()
	w.execute(ev.id, {"by": "player", "yes": [], "player_yes": true})
	var last: Dictionary = mart.info_log.back() if not mart.info_log.is_empty() else {}
	_check(not ev.alive and mart.alive and last.get("data", {}).get("evil", false), "an evil target hangs; the surviving Martyr learns they were evil")

func _revenant_world(sd: int):
	var w = _game(sd).w
	w.day = 2
	var rv = w.minions()[0]
	rv.role = "revenant"
	return w

func _test_revenant_curse() -> void:
	var w = _revenant_world(9110)
	var rv = w.minions()[0]
	w.totem = {"loc": "well", "day": 2, "owner": rv.id, "material": rv.home_block}
	var voter = w.living_good()[0]
	voter.info_log.append({"day": 1, "role": voter.role, "data": {}, "text": "real", "shared": true, "true": true})
	w.begin_meeting()
	w.execute(rv.id, {"by": "player", "yes": [voter.id], "player_yes": true})
	_check(voter.is_evil() and voter.turned and w.public_log.any(func(e): return e["kind"] == "curse"), "a hanged Revenant with a totem turns a good yes-voter, and the town is warned")
	_check(w.evil_plan["bluffs"].get(voter.id, "") == voter.role, "the turned keep claiming their own gift")
	voter.info_log.append({"day": 2, "role": voter.role, "data": {}, "text": "lie", "shared": false, "fake": true, "true": false})
	var t = w.find_totem("well")
	_check(not t.is_empty() and t["freed"] == voter.id and not voter.is_evil() and voter.intel.is_empty(), "finding the totem frees them, forgetting their team")
	_check(voter.info_log.back().get("disowned", false) and not voter.info_log[0].get("disowned", false), "they no longer stand by what they said while turned")

func _test_revenant_fizzle() -> void:
	var w = _revenant_world(9111)
	var rv = w.minions()[0]
	var voter = w.living_good()[0]
	w.begin_meeting()
	w.execute(rv.id, {"by": "player", "yes": [voter.id], "player_yes": true})
	_check(not voter.is_evil() and w.curse.is_empty(), "no totem in play: no curse")

func _test_totem_once_per_day() -> void:
	var placed_after_find = 0
	var placed_next_day = 0
	for sd in range(9120, 9140):
		var w = _revenant_world(sd)
		var rv = w.minions()[0]
		w.totem = {"loc": "well", "day": 1, "owner": rv.id, "material": rv.home_block}
		w.phase = C.MORNING
		w.start_phase()                      # a totem at dawn
		w.find_totem("well")                 # found in the morning
		for p in [C.AFTERNOON, C.EVENING]:
			w.phase = p
			rv.loc = "tavern"
			w._day_gifts()
		if not w.totem.is_empty():
			placed_after_find += 1
		w.day = 3
		w.phase = C.MORNING
		w.start_phase()
		for p in [C.MORNING, C.AFTERNOON, C.EVENING]:
			w.phase = p
			rv.loc = "tavern"
			w._day_gifts()
		if not w.totem.is_empty():
			placed_next_day += 1
	print("totem re-hidden the same day: %d/20; the next day: %d/20" % [placed_after_find, placed_next_day])
	_check(placed_after_find == 0 and placed_next_day == 20, "a found totem can only be replaced the next day")

func _test_scion() -> void:
	var w = _game(9130).w
	w.day = 2
	var sc = w.minions()[0]
	sc.role = "scion"
	var d = w.demon()
	w.begin_meeting()
	w.execute(d.id, {"by": "player", "yes": [], "player_yes": true})
	_check(not w.game_over and w.demon_id == sc.id and sc.role == "demon", "the demon hangs with 5+ alive: the Scion becomes the demon")
	var w2 = _game(9131).w
	w2.day = 4
	var sc2 = w2.minions()[0]
	sc2.role = "scion"
	var goods: Array = w2.living_good()
	for i in range(goods.size() - 2):
		goods[i].alive = false
	w2.begin_meeting()
	w2.execute(w2.demon_id, {"by": "player", "yes": [], "player_yes": true})
	_check(w2.game_over and w2.winner == "good", "with fewer than five alive, hanging the demon wins")

func _test_sexton() -> void:
	var tolled = 0
	var killed_on_knell = 0
	for sd in range(9140, 9160):
		var w = _game(sd).w
		var sx = w.living_good()[0]
		_give(w, sx, "sexton")
		w.day = 3
		var goods: Array = w.living_good().filter(func(x): return x != sx)
		goods[0].alive = false
		goods[1].alive = false
		goods[2].alive = false
		w.resolve_night()
		if w.knell_night == 3:
			tolled += 1
			if not w.deaths_last_night.is_empty() or not w.night_walkers.filter(func(wk): return wk["why"].begins_with("hunting")).is_empty():
				killed_on_knell += 1
	print("knell tolled in %d/20; demon still walked in %d" % [tolled, killed_on_knell])
	_check(tolled > 0 and killed_on_knell == 0, "the Sexton's knell stops the demon's walk")

func _test_veteran() -> void:
	var w = _game(9150).w
	var v = w.living_good()[0]
	_give(w, v, "veteran")
	v.secret_mod = ""
	v.poisoned = false
	w.day = 1
	_check(w.attack_outcome(v, {}) == "veteran", "the Veteran's first attack fails")
	w.demon().night_path = C.route(w.demon().home_block, v.home_block)
	w._veteran_survives(v)
	var e: Dictionary = v.info_log.back()
	var path: Array = w.demon().night_path
	var expect: String = path[path.size() - 2] if path.size() >= 2 else v.home_block
	_check(v.vet_used and e["data"]["block"] == expect, "the Veteran survives once and learns the attacker's last block")
	var v2 = w.living_good()[1]
	_check(w.attack_outcome(v, {}) == "killed", "a second attack kills them")

func _test_breathstealer() -> void:
	var w = _game(9160).w
	w.day = 2
	var bs = w.minions()[0]
	bs.role = "breathstealer"
	var t = w.living_good()[0]
	t.silence_pending = 2
	var testimony: Array = w.begin_meeting()
	_check(t.silenced and testimony.all(func(x): return x["who"] != t.id), "a silenced person says nothing at the meeting")
	_check(Mind.defence_line(w, t).get("silent", false), "...not even in their own defence")
	bs.breath_last = t.id
	var picked_again = 0
	for i in range(30):
		t.silenced = false
		t.silence_pending = -1
		bs.loc = t.loc
		if Evil.breath_target(w, bs) == t.id:
			picked_again += 1
	_check(picked_again == 0, "never the same person twice running")
	w.day = 3
	w.phase = C.EVENING
	t.silenced = true
	t.silence_day = 2
	w.start_phase()
	_check(not t.silenced, "the silence lifts the next evening")

func _test_dowser() -> void:
	var got = 0
	var right = 0
	for sd in range(9170, 9190):
		var w = _game(sd).w
		var dw = w.living_good()[0]
		_give(w, dw, "dowser")
		dw.secret_mod = ""
		dw.poisoned = false
		dw.dowsed_day = -1
		w.phase = C.MORNING
		dw.loc = "tavern"
		var others: Array = w.living().filter(func(m): return m != dw)
		others[0].loc = "well"
		others[1].loc = "tavern"
		others[0].busy_with = ""
		var before = dw.info_log.size()
		w._day_gifts()
		if dw.info_log.size() > before:
			got += 1
			var e: Dictionary = dw.info_log.back()
			if e["true"] or e.get("why", "") != "":
				right += 1
			if e["data"]["group"].size() < 2:
				right -= 100
			if got == 1:
				print("  ", e["text"])
	_check(got == 20 and right == 20, "the Dowser reads their block the first time two or more are there")

func _test_medium_priority() -> void:
	var w = _game(9180).w
	var m = w.living_good()[0]
	_give(w, m, "medium")
	var dead = w.living_good()[1]
	dead.alive = false
	dead.death_day = 1
	dead.death_cause = "demon"
	dead.info_log = []
	dead.beliefs = []
	dead.info_log.append({"day": 0, "role": "seer", "data": {"pair": [w.demon_id, m.id], "yes": true}, "text": "I looked: one is the demon", "shared": false, "true": true})
	dead.beliefs.append({"kind": "saw", "who": w.demon_id, "loc": "", "block": "hill", "day": 1, "phase": C.NIGHT})
	var it1 = w._medium_item(m, dead, false)
	var it2 = w._medium_item(m, dead, false)
	_check(it1["type"] == "reading" and it2["type"] == "sighting", "the Medium hears unshared readings first, then night sightings")

func _test_psychologist() -> void:
	var mate_trusted = 0
	var tries = 0
	for sd in range(9190, 9210):
		var w = _game(sd, 10).w
		var d = w.demon()
		tries += 1
		if w._psych_read(d)["trusts"] in w.minion_ids:
			mate_trusted += 1
	print("demon's most trusted is a minion: %d/%d" % [mate_trusted, tries])
	_check(mate_trusted >= tries / 2, "evil mostly trust each other (the Psychologist can see it)")

func _test_lamplighter() -> void:
	var ok = 0
	for sd in range(9200, 9220):
		var w = _game(sd).w
		var lp = w.living_good()[0]
		_give(w, lp, "lamplighter")
		lp.secret_mod = ""
		w.day = 1
		w.resolve_night()
		if not lp.alive:
			ok += 1  # killed in the night: no reading
			continue
		for e in lp.info_log:
			if e["role"] == "lamplighter" and e["day"] == 1:
				var others = w.night_walkers.filter(func(wk): return wk["id"] != lp.id).size()
				if e["data"]["count"] == others or not e["true"]:
					ok += 1
	_check(ok == 20, "the Lamplighter counts the others out (unless their gift is broken)")

func _test_marked_and_delusional() -> void:
	var w = _game(9210).w
	var mk = w.living_good()[0]
	mk.secret_mod = "marked"
	var ev = 0
	for i in range(200):
		if w.registers_evil(mk):
			ev += 1
	print("Marked read as evil %d/200" % ev)
	_check(ev > 60 and ev < 140, "the Marked read as evil about half the time")
	var dl = w.living_good()[1]
	dl.secret_mod = "delusional"
	_check(dl.gift_broken(), "the Delusional's gift is broken")

func _test_sleepwalker() -> void:
	var w = _game(9220).w
	var sw = w.living_good()[0]
	sw.secret_mod = "sleepwalker"
	w.day = 1
	w.resolve_night()
	var out: bool = sw.history[w.time_key(1, C.NIGHT)].begins_with("night:")
	w.day = 2
	var r = Mind.answer_night(w, sw, 1)
	var txt = " ".join(PackedStringArray(r["lines"].map(func(l): return l["text"])))
	_check(out and "home" in txt.to_lower(), "the Sleepwalker walks, and honestly says they were home")

func _test_lovers() -> void:
	var together = 0
	for sd in range(9230, 9250):
		var w = _game(sd).w
		var goods: Array = w.living_good()
		var a = goods[0]
		var b = goods[1]
		for n in w.npcs:
			n.secret_mod = ""
			n.lover = ""
		a.secret_mod = "lovers"
		b.secret_mod = "lovers"
		a.lover = b.id
		b.lover = a.id
		a.secret = {"kind": "lover", "with": b.id, "dest": b.home_block, "text": "slips out to meet %s in secret" % b.name}
		b.secret = {"kind": "lover", "with": a.id, "dest": a.home_block, "text": "slips out to meet %s in secret" % a.name}
		w.day = 1
		w._night_movement("", "", null, "")
		if a.out_last_night and b.out_last_night and a.night_block == b.night_block:
			together += 1
	_check(together == 20, "the Secret Lovers meet in the same place each night")

## Being out at night counts in full only near a death; an openly claimed walking gift
## is discounted.
func _test_night_suspicion() -> void:
	var w = _game(9260).w
	var l = w.living_good()[0]
	var x = w.living_good()[1]
	w.scenes["scene_test"] = {"name": "t", "block": "docks", "victim": "", "day": 1, "trace_block": "docks", "trace_true": true, "why": "", "searched": false}
	var near = Mind.night_sighting_scale(w, l, x.id, "docks", 1)
	var far = Mind.night_sighting_scale(w, l, x.id, "hill", 1)
	x.claimed_role = "lamplighter"
	x.claim_public = true
	Mind.hear_claim(w, l, x.id, "lamplighter", 0.5, "public")
	var claimed = Mind.night_sighting_scale(w, l, x.id, "docks", 1)
	print("night sighting scale: near a death %.2f, elsewhere %.2f, near a death but an open Lamplighter %.2f" % [near, far, claimed])
	_check(near == 1.0 and far < 0.2 and claimed < near, "night sightings count near deaths, and less for open walkers")
	var sw_out = 0
	for sd in range(9270, 9290):
		var w2 = _game(sd).w
		var sw = w2.living_good()[0]
		for n in w2.npcs:
			n.secret_mod = ""
		sw.secret_mod = "sleepwalker"
		w2.day = 1
		w2._night_movement("", "", null, "")
		if sw.out_last_night:
			sw_out += 1
	print("Sleepwalker out %d/20 nights" % sw_out)
	_check(sw_out > 3 and sw_out < 17, "the Sleepwalker walks on some nights, not all")

## Start-knowledge gifts already spent are worth less to kill than live ones.
func _test_spent_gift_kills() -> void:
	var spent_picked = 0
	var tries = 0
	for sd in range(9300, 9330):
		var w = _game(sd).w
		var goods: Array = w.living_good()
		var a = goods[0]
		var b = goods[1]
		_give(w, a, "archivist")
		_give(w, b, "seer")
		for pr in [[a, "archivist"], [b, "seer"]]:
			pr[0].claimed_role = pr[1]
			pr[0].claim_public = true
			w.public_claims.append({"day": 1, "who": pr[0].id, "role": pr[1]})
		w.day = 2
		var kt = Evil.choose_kill_target(w)
		if kt in [a.id, b.id]:
			tries += 1
			if kt == a.id:
				spent_picked += 1
	print("between a spent Archivist and a live Seer, the demon took the Archivist %d/%d" % [spent_picked, tries])
	_check(tries > 0 and spent_picked * 3 < tries, "the demon prefers a gift that keeps reporting")

func _templates_of(g, nums: Array) -> Array:
	return g.link_cards(nums)["result"]["matches"].map(func(m): return m["template"])

func _test_templates() -> void:
	var g = _game(9400, 10)
	var w = g.w
	var ids: Array = w.npcs.map(func(n): return n.id)
	var s1 = ids[0]
	var s2 = ids[1]
	var x = ids[2]
	var y = ids[3]
	var z = ids[4]
	var k1 = g.add_card({"kind": "info", "role": "seer", "source": s1, "day": 0, "subject": [y, x], "data": {"pair": [y, x], "yes": true}, "text": "seer 1"})
	var k2 = g.add_card({"kind": "info", "role": "seer", "source": s1, "day": 1, "subject": [x, z], "data": {"pair": [x, z], "yes": true}, "text": "seer 2"})
	var t = _templates_of(g, [k1, k2])
	_check("overlap" in t, "two Seer yeses sharing one person -> overlap (got %s)" % str(t))
	var k3 = g.add_card({"kind": "info", "role": "dowser", "source": s2, "day": 1, "phase": 1, "subject": [x, y, z], "data": {"group": [x, y, z], "count": 1, "block": "docks"}, "text": "dowser 1"})
	var k4 = g.add_card({"kind": "info", "role": "dowser", "source": s2, "day": 2, "phase": 0, "subject": [y, z, s1], "data": {"group": [y, z, s1], "count": 0, "block": "docks"}, "text": "dowser 0"})
	t = _templates_of(g, [k3, k4])
	_check("group_elimination" in t, "a clean crowd clears all but one of a dirty one -> group elimination (got %s)" % str(t))
	var k5 = g.add_card({"kind": "claim", "role": "archivist", "source": z, "subject": [z], "text": "z claims archivist"})
	var k6 = g.add_card({"kind": "refusal", "source": z, "subject": [z], "withheld": true, "role": "archivist", "text": "z withholds"})
	t = _templates_of(g, [k5, k6])
	_check("withholding" in t, "claims an information gift but won't share -> withholding (got %s)" % str(t))
	var k7 = g.add_card({"kind": "execution", "subject": [x], "source": "player", "day": 2, "phase": C.EVENING, "alive_before": 9, "text": "x hanged"})
	var res = g.link_cards([k1, k7])["result"]["matches"]
	var scion_expl = false
	for m in res:
		if m["template"] == "pair_elimination":
			for e in m["explanations"]:
				if "Scion" in e["label"]:
					scion_expl = true
	_check(scion_expl, "with five or more alive, 'hanged, so not the demon' allows for a Scion")

func _test_homes_and_bluffs() -> void:
	var bad = 0
	for sd in range(9500, 9520):
		for size in [7, 10]:
			var w = _game(sd, size).w
			var counts = {}
			for n in w.npcs:
				counts[n.home_block] = counts.get(n.home_block, 0) + 1
			var vals: Array = counts.values()
			if vals.size() < 4 or vals.max() - vals.min() > 1:
				bad += 1
	_check(bad == 0, "homes are spread evenly across the blocks")
	var over = 0
	var total = 0
	for sd in range(9520, 9900):
		var w2 = _game(sd, 10).w
		for m in w2.evil_team():
			for e in m.info_log:
				if e.get("fake", false) and e["role"] == "surveyor":
					total += 1
					if e["data"]["count"] > w2.evil_team().size():
						over += 1
	print("fake Surveyor counts too high for the team: %d/%d" % [over, total])
	_check(total > 0 and over * 4 < total, "fake Surveyor counts are mostly plausible")

func _test_seer_insight() -> void:
	var hits = {"sharp": 0, "dull": 0}
	for sd in range(9600, 9640):
		for kind in ["sharp", "dull"]:
			var w = _game(sd).w
			var sr = w.living_good()[0]
			_give(w, sr, "seer")
			sr.traits["insight"] = 0.95 if kind == "sharp" else 0.05
			w.day = 2
			var top = Mind.ranked_suspects(w, sr)[0]
			if top.id in Mind.seer_picks(w, sr):
				hits[kind] += 1
	print("Seer re-checks the top suspect: sharp %d/40, dull %d/40" % [hits["sharp"], hits["dull"]])
	_check(hits["sharp"] > hits["dull"] + 8, "a sharp Seer drills into their top suspect more than a dull one")

func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS ", what)
	else:
		fails += 1
		print("FAIL ", what)
