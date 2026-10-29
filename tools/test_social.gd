## Tests for town consensus, the Poisoner/Demon team play, visibility, role guessing, night
## sighting wording, and the demon's vote.
##   godot --headless --path . --script res://tools/test_social.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Social = preload("res://sim/social.gd")
const C = preload("res://sim/content.gd")

var fails = 0

func _init() -> void:
	_test_consensus_capped()
	_test_consensus_fades()
	_test_agree_line()
	_test_poison_spent_gift()
	_test_veteran_combo()
	_test_visibility()
	_test_role_fishing()
	_test_window_wording()
	_test_fake_sighting_vantage()
	_test_demon_tie_vote()
	_test_fake_watch_story()
	_test_ask_seen()
	_test_back_out()
	_test_haunts_and_counts()
	print("FAILURES: %d" % fails)
	quit()

func _game(sd: int):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd)
	return g

func _goods_except(w, ids: Array) -> Array:
	return w.living_good().filter(func(x): return not (x.id in ids))

## Five accusers against T: the listener's social action pressure stays under the cap, and the
## same five accusing again the next meeting adds nothing more.
func _test_consensus_capped() -> void:
	var g = _game(7101)
	var w = g.w
	var goods: Array = w.living_good()
	var L = goods[0]
	var T = w.npcs.filter(func(x): return x != L)[0]
	var before = L.suspicion.duplicate(true)
	for a in w.npcs:
		if a != L and a != T:
			w.stances[a.id] = {"target": T.id, "day": w.day}
	Mind.refresh_consensus(w, L, T.id)
	var once: float = L.consensus_pressure[T.id]
	Mind.refresh_consensus(w, L, T.id)
	var twice: float = L.consensus_pressure[T.id]
	print("consensus from %d voices: +%.2f, refreshed: +%.2f" % [w.stances.size(), once, twice])
	_check(once > 0.1 and once <= Mind.CONSENSUS_CAP * 1.5 + 0.001, "a chorus adds a bounded amount")
	_check(absf(once - twice) < 0.001, "re-accusing doesn't stack")
	_check(L.suspicion == before, "a chorus changes no evidence belief")

func _test_consensus_fades() -> void:
	var g = _game(7102)
	var w = g.w
	var L = w.living_good()[0]
	var others: Array = w.npcs.filter(func(x): return x != L)
	var T = others[0]
	w.stances[others[1].id] = {"target": T.id, "day": w.day}
	Mind.refresh_consensus(w, L, T.id)
	var now: float = L.consensus_pressure[T.id]
	w.day += 2
	Mind.refresh_consensus(w, L, T.id)
	var later: float = L.consensus_pressure[T.id]
	print("one voice: %.3f now, %.3f two days on" % [now, later])
	_check(later < now * 0.5, "an old accusation counts for less")

## The second person to accuse the same target agrees rather than restating.
func _test_agree_line() -> void:
	var g = _game(7103)
	var w = g.w
	w.day = 2
	w.meeting = {"block": "", "block_count": 0, "nominated": [], "nominators": [], "results": [], "pending": {}, "accusations": []}
	var goods: Array = w.living_good()
	var T = goods[2]
	var lines: Array = []
	for a in [goods[0], goods[1]]:
		a.suspicion[T.id] = 1.5
		a.sus_why[T.id] = "%s's sight said one of them is the demon" % goods[3].name
		var acc = null
		for i in range(30):
			acc = Mind._public_accusation(w, a)
			if acc != null:
				break
		lines.append(str(acc["line"].get("statement", acc["line"]["text"])).trim_prefix("[PH] ") if acc != null else "")
	print("  1: %s\n  2: %s" % lines)
	_check(lines[0].begins_with("I don't trust"), "first accuser states the grounds")
	_check(lines[1].begins_with("I agree with %s" % goods[0].name) and not ("sight said" in lines[1]), "second accuser agrees without restating")

## After night 0, a publicly claimed Archivist's gift is spent: the Poisoner looks elsewhere.
func _test_poison_spent_gift() -> void:
	var g = _game(7104)
	var w = g.w
	w.minion().role = "poisoner"  # (the script has four minions now; this test needs the Poisoner)
	w.day = 2
	var goods: Array = w.living_good()
	var A = goods[0]
	A.claimed_role = "archivist"
	A.claim_public = true
	w.public_claims.append({"day": 1, "who": A.id, "role": "archivist"})
	_check(not Evil.gift_live_tonight(w, A), "a first-night gift is spent after night 0")
	var hits = 0
	for i in range(20):
		if Evil.choose_poison_target(w) == A.id:
			hits += 1
	print("spent Archivist poisoned %d/20" % hits)
	_check(hits <= 2, "the Poisoner rarely wastes poison on a spent gift")

## A publicly claimed Veteran: the demon asks for poison first, and the kill lands.
func _test_veteran_combo() -> void:
	var killed = 0
	var asked = 0
	for sd in range(7110, 7130):
		var g = _game(sd)
		var w = g.w
		w.minion().role = "poisoner"
		w.day = 2
		var vet = null
		for n in w.living_good():
			if n.role == "veteran":
				vet = n
		if vet == null:
			vet = w.living_good()[0]
			vet.role = "veteran"
		vet.claimed_role = "veteran"
		vet.claim_public = true
		w.public_claims.append({"day": 1, "who": vet.id, "role": "veteran"})
		# Make them the obvious target.
		Evil.add_intel(w, w.demon(), "threat", vet.id, 6.0, "test")
		var kt = Evil.choose_kill_target(w)
		if kt != vet.id:
			continue
		asked += 1
		var pt = Evil.choose_poison_target(w, kt)
		if pt == vet.id:
			killed += 1
	print("Veteran targeted in %d cases; poisoned first in %d" % [asked, killed])
	_check(asked > 0 and killed == asked, "the Poisoner poisons the Veteran the demon is going for")

## Off your block, only people at work or talking are visible; on it, everyone there.
func _test_visibility() -> void:
	var g = _game(7105)
	var w = g.w
	var wanderer = null
	for n in w.living():
		if not n.working and n.busy_with == "" and not n.at_home():
			wanderer = n
	if wanderer == null:
		wanderer = w.living()[0]
		wanderer.working = false
		wanderer.busy_with = ""
		wanderer.loc = C.LOCATIONS.keys()[0]
	g.moved = false
	_check(not g.can_see(wanderer), "a wanderer is out of sight before you choose a block")
	_check(g._resolve_go(wanderer.id) == "", "you can't walk straight to someone you can't see")
	for n in w.living():
		if n.working and not n.at_home():
			_check(g.can_see(n), "someone at work is always visible")
			break
	g.moved = true
	g.loc = wanderer.loc
	_check(g.can_see(wanderer), "on their block, you see them")

## "Heard of a <gift>?" is a question about the town and costs nothing; "are you the
## <gift>?" guesses wrong at a growing trust cost, with a non-answer that doesn't eliminate.
func _test_role_fishing() -> void:
	var g = _game(7106)
	var w = g.w
	var n = w.living_good()[0]
	var t0 = n.trust
	var wrong: Array = C.GOOD_ROLES.filter(func(r): return r != n.role)
	Social.answer_about_role(w, n, wrong[0])
	Social.answer_about_role(w, n, wrong[1])
	var t1 = n.trust
	var r1 = Social.answer_is_role(w, n, wrong[0])
	Social.answer_is_role(w, n, wrong[1])
	var t3 = n.trust
	print("trust %.2f -> %.2f after asking about two gifts, %.2f after two wrong guesses" % [t0, t1, t3])
	print("  wrong guess: %s" % r1["lines"][0]["text"])
	_check(absf(t1 - t0) < 0.001, "asking who holds a gift costs nothing")
	_check(t3 < t1 - 0.04, "wrong guesses at their gift cost trust")
	# A holder who won't own up says the same thing.
	var m = w.living_good()[1]
	m.trust = 0.0
	m.traits["privacy"] = 1.0
	m.role_guesses = 1  # no first-right-guess bonus: this holder is simply unwilling
	var r2 = Social.answer_is_role(w, m, m.role)
	_check(r2["facts"].is_empty() and r2["lines"][0].get("statement", r2["lines"][0]["text"]) == "What my gift is, I'll keep to myself.", "an unwilling holder gives the same non-answer")

## At home, a sighting is told from the window; a neighbour seen staying in is an alibi.
func _test_window_wording() -> void:
	var g = _game(7107)
	var w = g.w
	var goods: Array = w.living_good()
	var o = goods[0]
	var x = goods[1]
	var r1 = Mind.sighting_report(w, o, {"kind": "saw", "who": x.id, "block": o.home_block, "how": "window", "detail": "street"}, 1)
	var r2 = Mind.sighting_report(w, o, {"kind": "stayed_in", "who": x.id, "block": o.home_block, "how": "window"}, 1)
	print("  %s\n  %s" % [r1["line"]["text"], r2["line"]["text"]])
	_check(r1["line"]["text"].trim_prefix("[PH] ").begins_with("From my window"), "a sighting from home says so")
	_check(r2["fact"]["kind"] == "alibi" and r2["fact"]["subject"] == [x.id] and r2["fact"]["source"] == o.id, "a neighbour staying in becomes a witness alibi card")

## Evil's invented sighting is told from where they say they were.
func _test_fake_sighting_vantage() -> void:
	var made = 0
	var bad = 0
	for sd in range(7140, 7160):
		var g = _game(sd)
		var w = g.w
		Evil.ensure_scapegoat(w)
		for m in [w.demon(), w.minion()]:
			var f = Evil.fake_night_sighting(w, m, 1, m.home_block, "window")
			if f != null:
				made += 1
				if f["block"] != m.home_block:
					bad += 1
			# Asked again from somewhere else, the same night: no story.
			if f != null and Evil.fake_night_sighting(w, m, 1, "nowhere", "street") != null:
				bad += 1
	print("fake sightings made: %d, inconsistent: %d" % [made, bad])
	_check(made > 0 and bad == 0, "fabricated sightings fit the liar's own story")

## On the block, the demon votes for its own minion only to tie and clear the block (or when
## it would pass anyway), never on a mistaken "it will pass anyway".
func _test_demon_tie_vote() -> void:
	var g = _game(7108)
	var w = g.w
	var d = w.demon()
	var m = w.minion()
	var thr = w.vote_threshold()
	w.meeting = {"block": d.id, "block_count": thr, "nominated": [d.id], "nominators": [], "results": [], "pending": {}}
	var ties = 0
	for i in range(30):
		if Evil.evil_vote(w, d, m.id, thr - 1, false):
			ties += 1
	var wrong = 0
	for i in range(30):
		if Evil.evil_vote(w, d, m.id, thr - 2, false):
			wrong += 1
	print("demon on the block votes to tie: %d/30; with no tie possible: %d/30" % [ties, wrong])
	_check(ties > 0, "the demon sometimes ties the count to clear the block")
	_check(wrong == 0, "no yes vote when it neither ties nor passes")

## A false Night Watch says they saw exactly who their made-up watch report names.
func _test_fake_watch_story() -> void:
	var bad = 0
	var tried = 0
	for sd in range(7170, 7190):
		var g = _game(sd)
		var w = g.w
		var m = w.minion()
		var goods: Array = w.living_good()
		w.day = 2
		m.claimed_role = "nightwatch"
		m.max_tier = 3
		w.evil_plan["fake_watch"]["1"] = "hill"
		m.info_log.append({"day": 1, "role": "nightwatch", "fake": true, "shared": false, "true": false,
			"data": {"block": "hill", "seen": [goods[0].id]}, "text": "I watched Chapel Hill: I saw %s pass by" % goods[0].name})
		m.traits["gossip"] = 0.9
		# Undisclosed, the watch result is withheld (never contradicted)...
		var held = Mind.answer_night(w, m, 1)
		var held_txt = " ".join(PackedStringArray(held["lines"].map(func(l): return l["text"])))
		if not ("not ready to share" in held_txt) or "I saw nobody" in held_txt:
			bad += 1
			print("  withheld wrongly: ", held_txt)
		# ...and once told, the night story names exactly who the report names.
		m.told_readings = m.info_log.size()
		# Exercise the willing branch here; batch 4 separately checks the 95% refusal rate.
		w.rng.seed = 1
		var r = Mind.answer_night(w, m, 1)
		var txt = " ".join(PackedStringArray(r["lines"].map(func(l): return l["text"])))
		tried += 1
		if not (goods[0].name in txt) or "I saw nobody" in txt:
			bad += 1
			print("  inconsistent: ", txt)
	_check(bad == 0, "a false Night Watch's night story matches their fake report (%d cases)" % tried)

## "Ask today" leaves out people you can see beside you; "ask seen <time>" narrows it.
func _test_ask_seen() -> void:
	var g = _game(7300)
	var w = g.w
	var n = w.living_good()[0]
	var x = w.living_good()[1]
	var y = w.living_good()[2]
	w.player_loc = "tavern"
	x.loc = "tavern"
	y.loc = "smithy"
	n.traits["gossip"] = 1.0
	n.beliefs = [
		{"kind": "saw", "who": x.id, "loc": "tavern", "block": "square", "day": 1, "phase": 0, "with": ""},
		{"kind": "saw", "who": y.id, "loc": "smithy", "block": "market", "day": 1, "phase": 0, "with": ""}]
	var r1 = Mind.answer_today(w, n, "", "tavern")
	var t1 = r1["lines"][0]["text"]
	_check(not (x.name in t1) and y.name in t1, "people beside you this phase are left out (%s)" % t1)
	n.beliefs.append({"kind": "saw", "who": x.id, "loc": "well", "block": "square", "day": 0, "phase": 2, "with": ""})
	w.day = 1
	var r2 = Mind.answer_today(w, n, "yesterday", "tavern")
	_check(x.name in r2["lines"][0]["text"] and not (y.name in r2["lines"][0]["text"]), "ask seen yesterday reaches back a day")
	var r3 = Mind.answer_today(w, n, "morning", "")
	_check(y.name in r3["lines"][0]["text"], "ask seen morning names who was seen this morning")

## Leaving a conversation before asking anything costs no time.
func _test_back_out() -> void:
	var g = _game(7301)
	var w = g.w
	var t = null
	for n in w.living():
		if not n.at_home() and n.busy_with == "" and g.can_see(n):
			t = n
			break
	g.command("go " + t.id)
	g.command("talk " + t.id)
	var ph = w.phase
	g.command("bye")
	_check(g.state == "day" and w.phase == ph and g.talk_with == null, "backing out with no questions keeps the phase")
	g.command("talk " + t.id)
	g.command("ask gift")
	g.command("bye")
	_check(w.phase != ph or g.state != "talk", "leaving after a question spends the phase")

## Habits and "someone's there" counts.
func _test_haunts_and_counts() -> void:
	var g = _game(7302)
	var w = g.w
	_check(w.npcs.all(func(n): return n.haunts.size() == 2 and not (n.work in n.haunts)), "everyone has two haunts, not their workplace")
	var total = 0
	for l in C.LOCATIONS:
		total += g.unseen_at(l)
	var hidden = w.living().filter(func(n): return not n.at_home() and not g.can_see(n) and C.LOCATIONS.has(n.loc)).size()
	_check(total == hidden, "unseen counts add up to everyone out of sight (%d)" % total)

func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1
