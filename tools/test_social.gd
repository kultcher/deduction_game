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
	print("FAILURES: %d" % fails)
	quit()

func _game(sd: int):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd)
	return g

func _goods_except(w, ids: Array) -> Array:
	return w.living_good().filter(func(x): return not (x.id in ids))

## Five accusers against T: the listener's added suspicion stays under the cap, and the
## same five accusing again the next meeting adds nothing more.
func _test_consensus_capped() -> void:
	var g = _game(7101)
	var w = g.w
	var goods: Array = w.living_good()
	var L = goods[0]
	var T = w.npcs.filter(func(x): return x != L)[0]
	var before = Mind.susp(L, T.id)
	for a in w.npcs:
		if a != L and a != T:
			w.stances[a.id] = {"target": T.id, "day": w.day}
	Mind.refresh_consensus(w, L, T.id)
	var once = Mind.susp(L, T.id) - before
	Mind.refresh_consensus(w, L, T.id)
	var twice = Mind.susp(L, T.id) - before
	print("consensus from %d voices: +%.2f, refreshed: +%.2f" % [w.stances.size(), once, twice])
	_check(once > 0.1 and once <= Mind.CONSENSUS_CAP * 1.5 + 0.001, "a chorus adds a bounded amount")
	_check(absf(once - twice) < 0.001, "re-accusing doesn't stack")

func _test_consensus_fades() -> void:
	var g = _game(7102)
	var w = g.w
	var L = w.living_good()[0]
	var others: Array = w.npcs.filter(func(x): return x != L)
	var T = others[0]
	w.stances[others[1].id] = {"target": T.id, "day": w.day}
	Mind.refresh_consensus(w, L, T.id)
	var now: float = L.consensus_applied[T.id]
	w.day += 2
	Mind.refresh_consensus(w, L, T.id)
	var later: float = L.consensus_applied[T.id]
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
		lines.append(acc["line"]["text"] if acc != null else "")
	print("  1: %s\n  2: %s" % lines)
	_check(lines[0].begins_with("I don't trust"), "first accuser states the grounds")
	_check(lines[1].begins_with("I agree with %s" % goods[0].name) and not ("sight said" in lines[1]), "second accuser agrees without restating")

## After night 0, a publicly claimed Archivist's gift is spent: the Poisoner looks elsewhere.
func _test_poison_spent_gift() -> void:
	var g = _game(7104)
	var w = g.w
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

## Running down the list of gifts with the same person costs trust; the first question is free.
func _test_role_fishing() -> void:
	var g = _game(7106)
	var w = g.w
	var n = w.living_good()[0]
	var t0 = n.trust
	var wrong: Array = C.GOOD_ROLES.filter(func(r): return r != n.role)
	Social.answer_about_role(w, n, wrong[0])
	var t1 = n.trust
	Social.answer_about_role(w, n, wrong[1])
	Social.answer_about_role(w, n, wrong[2])
	var t3 = n.trust
	print("trust %.2f -> %.2f after one wrong gift, %.2f after three" % [t0, t1, t3])
	_check(absf(t1 - t0) < 0.001, "one question about a gift is free")
	_check(t3 < t1 - 0.05, "fishing through gifts costs trust")

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
	_check(r1["line"]["text"].begins_with("From my window"), "a sighting from home says so")
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

func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1
