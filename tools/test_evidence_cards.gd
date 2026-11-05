## Evidence on the board: cards and their provenance, corroboration, sightings and vigils, wards, traces, dropped items, false-reading causes.
## Merged from: test_backlog_batch3, test_backlog_batch4, test_fixes, test_playtest_followups, test_playtest_regressions.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const CardList = preload("res://ui/card_list.gd")
const Mind = preload("res://sim/mind.gd")
const Speech = preload("res://tools/speech.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Live = preload("res://game/workshop_canvas.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await _run_backlog_batch3()
	_run_backlog_batch4()
	_run_fixes()
	_run_playtest_followups()
	_run_playtest_regressions()
	print("Evidence: cards: %d checks, %d failures" % [checks, fails])
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
	await ward_warnings()
	totem_signpost()
	ward_evidence()
	bot_options()


# ---------------------------------------------------------------- from test_backlog_batch4

func _run_backlog_batch4() -> void:
	false_reading_causes()
	dropped_item_search()


# ---------------------------------------------------------------- from test_fixes

func _run_fixes() -> void:
	_roads()
	_home_cards()
	_haunts()
	_corroboration()
	_victim_trace()
	_cite_provenance()
	_relay_unnamed()


# ---------------------------------------------------------------- from test_playtest_followups

func _run_playtest_followups() -> void:
	ward_promise()


# ---------------------------------------------------------------- from test_playtest_regressions

func _run_playtest_regressions() -> void:
	_public_sighting()
	_vigil_destination_only()
	_multi_subject_vigil_no_collateral_note()


# ---- test_backlog_batch3


func fresh(count: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch3_tests"
	g.new_case(4242, count)
	return g


func ward_warnings():
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	root.add_child(scene)
	var g = scene.g
	var person = g.w.living_good()[0]
	g.events = []
	g._offer_command(person, "ward")
	check(g.w.tools.ward == 1 and g.offer.ward == person.id and Game.render(g.events).contains("Promising does not spend your ward; keeping the promise does"), "ward promises explain the limit and do not consume the tool")
	g.state = "night"
	scene._ward_target = person.id
	scene._refresh_actions()
	await process_frame
	var buttons: Array = scene.actions.get_children().filter(func(n): return n is Button and "ward" in n.text.to_lower())
	check(buttons.size() >= 3 and buttons.all(func(b): return "1 left, once per case" in b.text), "every direct-night Ward button displays the remaining limit")
	var dialog = scene._confirm_ward(person.id)
	check(dialog.dialog_text == "This spends your only ward. Ward %s?" % person.name and g.w.tools.ward == 1, "direct UI warding asks for confirmation before spending")
	dialog.canceled.emit()
	await process_frame
	check(g.w.tools.ward == 1 and g.state == "night", "canceling a ward confirmation spends nothing")
	var output = g.command("ward " + person.id)
	check(g.w.tools.ward == 0 and g.ward_log.has(1) and "You chalk a warding sigil" in output, "typed ward commands go straight through and consume exactly one use")
	for i in range(3): await process_frame
	scene.free()


func totem_signpost():
	var g = fresh()
	g.w.totem = {"loc": "well", "material": "market", "day": 1, "owner": g.w.minion().id}
	g.events = []
	var rng = g.w.rng.state
	g.loc = "well"
	g._search()
	check(g.board.any(func(c): return c.kind == "totem" and "will seek a new hiding place" in c.text), "totem-burned receipt warns of a new hiding place")
	check(g.events.any(func(e): return e.k == "headline" and e.kind == "totem" and "will seek a new hiding place" in e.subtitle), "totem warning also appears as a headline")
	check(g.w.totem.is_empty() and g.w.rng.state == rng, "totem signpost preserves burn behavior and RNG")


func ward_evidence():
	var g = fresh()
	var target = g.w.living_good()[0]
	for n in g.w.living_good():
		n.role = "clerk"
		n.secret_mod = ""
		if n != target:
			for i in range(20): g.w.evil_plan.failed.append(n.id)
	g.state = "night"
	g.command("ward " + target.id)
	var spent: Array = g.board.filter(func(c): return c.kind == "ward")
	var sigils: Array = g.board.filter(func(c): return c.kind == "scorched_sigil")
	check(spent.size() == 1 and spent[0].target == target.id and spent[0].loc == "home_" + target.id and spent[0].night == 1, "spending a ward records protectee, door and night")
	check(g.w.ward_saves.any(func(save): return save.target == target.id and save.night == 1) and sigils.size() == 1, "an actual blocked attack leaves one scorched-sigil card next morning")
	if sigils.is_empty(): return
	var sigil: Dictionary = sigils[0]
	check(sigil.private and not sigil.learned.any(func(d): return d.public), "the newly found sigil is player-only")
	var other = g.w.minion()
	for n in g.w.living():
		n.trust_cap = 1.0
		n.trust = 0.3
	g.state = "talk"
	g.talk_with = other
	g.questions_left = 3
	other.silenced = true
	var deliveries = g.workshop_deliveries.size()
	g.command("present %d" % sigil.n)
	check(is_equal_approx(other.trust, 0.35) and g.questions_left == 2, "private showing rewards even an evil/silenced listener and costs one question")
	g.command("present %d" % sigil.n)
	check(is_equal_approx(other.trust, 0.35), "repeated private showing cannot reward the same listener twice")
	g.state = "meeting"
	g.presented_today = false
	g.command("present %d" % sigil.n)
	check(is_equal_approx(target.trust, 0.5) and is_equal_approx(other.trust, 0.35), "meeting showing grants protectee +0.20 total and skips previously rewarded listeners")
	check(g.w.living().all(func(n): return n == target or is_equal_approx(n.trust, 0.35)), "every other living NPC receives +0.05 irrespective of alignment")
	check(g.presented_today and sigil.learned.any(func(d): return d.public) and not sigil.private, "meeting showing consumes the normal floor and makes the receipt public")
	check(g.workshop_deliveries.size() == deliveries, "showing protection context does not invent a shared-model adapter")
	var second = g.add_card({"kind": "scorched_sigil", "subject": [other.id], "source": "evidence", "target": other.id, "text": "Another distinct sigil", "private": true})
	other.trust = 0.49
	other.trust_cap = 0.5
	g._show_ward_context(g.board[second - 1], [other])
	check(is_equal_approx(other.trust, 0.5), "sigil trust honors existing caps")
	g.new_case(4242, 10)
	check(g.sigil_heard.is_empty(), "new cases reset per-sigil reward ownership")


func bot_options():
	var Bot = preload("res://tools/autoplay.gd")
	var g = fresh()
	var n = g.w.living_good()[0]
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 2
	n.max_tier = 3
	n.claimed_role = "seer"
	var used = {}
	check(Bot.new_talk_option(g, used) == "offer ward", "bot offers an available ward to a known info claimant")
	g.offer = {"ward": n.id}
	check(Bot.new_night_option(g) == "ward " + n.id, "bot keeps its ward promise before ordinary night choices")
	check(Bot.new_talk_option(g, used).begins_with("ask check "), "bot requests a disclosed Seer's gift")
	check(Bot.new_talk_option(g, used) == "", "bot does not repeat a free offer or gift request")
	g.questions_left = 1
	check(Bot.new_talk_option(g, used).begins_with("ask about "), "bot asks about another person to learn haunts, traits and relationships")
	g.pending_request = {"kind": "confidence"}
	check(Bot.new_talk_option(g, used) == "yes" and Bot.new_action_kind(g, "yes") == "answer_confidence", "bot answers and counts confidence requests")
	g.pending_request = {"kind": "protect", "what": "ward"}
	check(Bot.new_talk_option(g, used) == "no", "bot answers protection requests without promising a second incompatible action")
	g.offer = {}
	check(Bot.new_talk_option(g, used) == "yes" and Bot.new_action_kind(g, "yes") == "answer_protection", "bot accepts and counts feasible protection requests")
	g.pending_request = {}
	n.grievances = [{"apologised": false}]
	check(Bot.new_talk_option(g, {}) == "apologise 1", "bot apologises for a player-visible grievance")
	n.grievances = []
	n.max_tier = 0
	n.claim_public = false
	check(Bot.new_talk_option(g, {}) == "offer vigil", "hidden role assignments do not influence the bot's protection offer")
	g.offer = {"vigil": {n.id: n.home_block}}
	check(Bot.new_night_option(g) == "vigil " + n.home_block, "bot keeps a vigil promise")
	for role in ["warden", "nightwatch"]:
		n.claimed_role = role
		n.max_tier = 3
		g.questions_left = 2
		var command = Bot.new_talk_option(g, {})
		check(command.begins_with("ask guard " if role == "warden" else "ask watch "), "bot covers each other supported gift request")
		check(Bot.new_action_kind(g, command) == ("request_guard" if role == "warden" else "request_watch"), "run-summary classification counts each gift action")


# ---- test_backlog_batch4


func backlog_batch4__fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch4_tests"
	g.new_case(4242, 10)
	return g


func false_reading_causes():
	var g = backlog_batch4__fresh()
	var n = g.w.living_good()[0]
	n.role = "medium"
	n.secret_mod = ""
	n.poisoned = false
	var rng = g.w.rng.state
	for explicit in ["red herring Agnes", "Marked reads as evil", "evil fabrication: cover"]:
		var entry = {"text": "diagnostic false result", "data": {}, "true": false, "why": explicit}
		g.w._add_info(n, entry)
		check(n.info_log[-1].why == explicit and g.w.dlog.entries[-1].data.why == explicit, "stored and exported false reading preserve explicit cause: " + explicit)
	for impaired in ["poisoned", "delusional"]:
		n.poisoned = impaired == "poisoned"
		n.secret_mod = "delusional" if impaired == "delusional" else ""
		g.w._add_info(n, {"text": "diagnostic false result", "data": {}, "true": false})
		check(n.info_log[-1].why == impaired, "current impairment is recorded at creation: " + impaired)
	n.secret_mod = ""
	n.poisoned = false
	g.w._add_info(n, {"text": "relayed fake", "data": {"item": {"type": "reading", "lie": true, "entry": {"fake": true, "why": "evil fabrication: cover"}}}, "true": false})
	check("evil fabrication relayed from the dead" in n.info_log[-1].why and "cover" in n.info_log[-1].why, "healthy Medium records the fabricated relay's provenance")
	g.w._add_info(n, {"text": "unknown false path", "data": {}, "true": false, "why": "?"})
	check(n.info_log[-1].why.begins_with("fallback:") and not n.info_log[-1]["true"], "unrecorded cause is explicit fallback without changing truth status")
	g.w.dlog.add("info", n.id, "", {"text": "old missing reason", "true": false, "why": "?"})
	g.w.dlog.add("fake_info", n.id, "", {"text": "old fake reason"})
	var output = g._lies()
	check(not "(?)" in output and "cause was not recorded" in output and "old fake reason (evil fabrication)" in output, "lies summary handles older missing causes without inventing past impairment")
	check(g.w.rng.state == rng, "diagnostic cause annotation consumes no random draws")


func dropped_item_search():
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/playtest_37291_drop.json"))
	var event: Dictionary = fixture.event
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch4_tests"
	g.new_case(fixture.case.seed, fixture.case.npcs)
	var owner = g.w.by_id[event.actor]
	var item = {"night": event.data.night, "material": event.data.material, "owner": owner.id, "who": owner.id, "why": "hunting Jory"}
	g.w.dropped = {event.data.loc: [item]}
	g.w.totem = {}
	g.loc = "mill"
	g.events = []
	var rng = g.w.rng.state
	g._search()
	check(g.w.dropped.has("wharf") and not g.board.any(func(c): return c.get("dropped", false)), "searching the mill does not consume the wharf's personal item")
	check(g.w.rng.state == rng, "searching for a stored drop has no discovery roll")
	g.state = "day"
	g.moved = false
	g.command("go wharf")
	var found = g.command("search")
	var cards = g.board.filter(func(c): return c.get("dropped", false) and c.get("source", "") == "evidence")
	check(found.contains("something of " + owner.name) and cards.size() == 1, "ordinary go/search finds Fenwick's original wharf personal item")
	check(cards[0].subject == [owner.id] and cards[0].loc == "wharf" and cards[0].day == 3 and cards[0].phase == C.NIGHT, "found item produces the existing dated owner sighting card")
	check(not g.w.dropped.has("wharf"), "all stored drops at the searched location are consumed")
	g.loc = "wharf"
	g.events = []
	rng = g.w.rng.state
	g._search()
	check(g.board.filter(func(c): return c.get("dropped", false)).size() == 1 and g.w.rng.state == rng, "searching again cannot duplicate the item and adds no random draw")
	owner.alive = false
	g.w.dropped["wharf"] = [item.duplicate(true)]
	g._search()
	check(not g.w.dropped.has("wharf"), "an owner's death does not make an unfound stored item inaccessible")


# ---- test_fixes


func _game(sd: int, size: int = 10):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


func _victim_trace() -> void:
	var victim_excluded = true
	var demon_always_matches = true
	var extra_passer_spawned = false
	for seed_v in range(7140, 7160):
		var g = _game(seed_v, 7)
		var w = g.w
		var victim = w.living_good()[0]
		var d = w.demon()
		w.night_walkers = [{"id": victim.id, "block": victim.home_block, "path": [victim.home_block], "why": "keeping watch"}]
		w._kill(victim)
		var sc1: Dictionary = w.scenes["scene_" + victim.id]
		victim_excluded = victim_excluded and sc1["traces"].size() == 1 and (victim.id not in sc1.get("passer_ids", []))
		demon_always_matches = demon_always_matches and w.actor_fits_trace_truth(d, sc1["traces"][0])
		var next_victim = w.living_good()[0]
		var passer = w.living_good()[1]
		w.night_walkers = [{"id": passer.id, "block": next_victim.home_block, "path": [next_victim.home_block], "why": "passing by"}]
		w._kill(next_victim)
		var sc2: Dictionary = w.scenes["scene_" + next_victim.id]
		demon_always_matches = demon_always_matches and sc2["traces"].any(func(t): return w.actor_fits_trace_truth(d, t))
		if sc2["traces"].size() == 2 and sc2["traces"].any(func(t): return w.actor_fits_trace_truth(passer, t)):
			extra_passer_spawned = true
	_check(victim_excluded, "a victim's own night walk never spawns a second passer trace at their cottage")
	_check(demon_always_matches and extra_passer_spawned, "Demon trace is always present and eligible passers can add a second trace")


func _roads() -> void:
	var direct = true
	for a in C.BLOCKS:
		for b in C.BLOCKS:
			if a != b and C.route(a, b).size() != 2:
				direct = false
	_check(direct, "every block has its own road to every other (routes are home -> destination)")


func _home_cards() -> void:
	var g = _game(7101)
	var board_homes: Array = g.board.filter(func(c): return c["kind"] == "home")
	var homes: Array = g.profile_receipts.filter(func(c): return c["kind"] == "home")
	var works: Array = g.profile_receipts.filter(func(c): return c["kind"] == "work")
	_check(board_homes.is_empty(), "main case board starts free of home-card clutter")
	_check(homes.size() == g.w.npcs.size() and works.size() == g.w.npcs.size(), "one hidden home and work profile receipt per resident at the start")
	_check(homes.all(func(c): return g.w.by_id[c["subject"][0]].home_block == c["block"]), "home profile receipts say where each person really lives")


func _talk_to(g, n) -> void:
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 3
	g.free_repeats = 0
	g.talk_offered = false
	g.talk_approached = false
	g.loc = n.loc if C.LOCATIONS.has(n.loc) else "tavern"


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
	_check(g.profile_receipts.any(func(c): return c["kind"] == "haunt" and c["subject"] == [t.id]) and not g.board.any(func(c): return c["kind"] == "haunt"), "a revealed haunt creates a hidden profile receipt without cluttering the main board")
	_check(g.profile_data(t.id)["haunts"] != "", "the profile shows haunts once you've been told")


## A reason is citable only to an audience that already has it (Oct 19 provenance fix).
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
	var plain = {"kind": "sighting", "subject": [x], "source": "player", "text": "x"}
	_check(not g.board[mine - 1].get("corroborated_by", []).is_empty() and plain.get("corroborated_by", []).is_empty(), "corroborated card records its independent witness while an uncorroborated card stays bare")
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
	var t: String = Speech.said(r["lines"][0])
	_check(not (w.by_id[x].name + " at") in t, "a pair you saw yourself isn't repeated to you (%s)" % t)
	_check(r["facts"].any(func(f): return f.get("silent", false)), "...but it's kept as silent backing")
	g._facts(r["facts"])
	_check(n.id in g.board[mine - 1].get("corroborated_by", []), "...which lands on your card")


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


func _cite_provenance() -> void:
	var r = _setup_private_reading(7200)
	var w = r[1]
	var n = r[2]
	var t = r[3]
	var rs = Mind.reason_status(w, n, t.id)
	_check(str(rs.get("eid", "")).begins_with("info:%s:" % n.id), "the reason records its source: their own reading (%s)" % str(rs.get("eid", "")))
	_check(rs["kind"] == "private" and rs["strength"] > 0.8, "an unshared Seer yes is a private, strong reason")
	_check(Mind.citable_reason(w, n, t.id, "town") == "" and Mind.citable_reason(w, n, t.id, "player") == "", "a private reason can't be cited to anyone")
	n.told_readings = 1
	_check(Mind.reason_status(w, n, t.id)["kind"] == "player", "told to the player privately: the player's to hear")
	_check(Mind.citable_reason(w, n, t.id, "player") != "" and Mind.citable_reason(w, n, t.id, "town") == "", "citable to the player, not the town")
	n.info_log[0]["shared"] = true
	_check(Mind.citable_reason(w, n, t.id, "town") != "", "once shared at the meeting, citable to the town")


## Meeting-flow step 2: the nominee's defence moves.
func _relay_unnamed() -> void:
	var r = _setup_private_reading(7340)
	var w = r[1]
	var seer = r[2]
	var t = r[3]
	var n = w.living_good().filter(func(x): return x != seer and x != t)[0]
	Mind.apply_info(w, n, seer, seer.info_log[0], 1.0)
	var rs = Mind.reason_status(w, n, t.id)
	# Shared-model sizes (purge 2c): one relayed Seer ping moves the listener only a little
	# (the pair may hold the red herring), often below the citable cut. What matters is
	# that it is never a reason the listener can cite as their own or the town's.
	_check(rs["kind"] in ["relay", "none"], "a reading heard in private is a relay, not citable (%s)" % rs["kind"])
	_check(Mind.citable_reason(w, n, t.id, "town") == "", "it can't be quoted as is")
	var lis = w.living_good().filter(func(x): return x != seer and x != t and x != n)[0]
	var before = lis.suspicion[t.id]
	var lines: Array = []
	var facts: Array = []
	Mind.relay_reading(w, n, seer, seer.info_log[0], lines, facts)
	var text = lines[0]["text"]
	_check("the Seer" in text and not (seer.name in text), "the gift is named, the person isn't: %s" % text)
	var relayed = lis.suspicion[t.id] - before
	var lis2 = w.living_good().filter(func(x): return x != seer and x != t and x != n and x != lis)[0]
	var b2 = lis2.suspicion[t.id]
	Mind.apply_info(w, lis2, seer, seer.info_log[0], Mind.heard_weight(lis2, seer))
	var direct = lis2.suspicion[t.id] - b2
	_check(relayed < direct * 0.6, "much weaker than hearing it from the Seer (%.3f vs %.3f)" % [relayed, direct])


# ---- test_playtest_followups


func playtest_followups__fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://followup_tests"
	g.new_case(4242, 10)
	return g


func ward_promise():
	var g = playtest_followups__fresh()
	var w = g.w
	var n = w.living_good()[0]
	var neighbour = w.living_good()[1]
	n.home_block = "square"
	neighbour.home_block = "square"
	w.player_vigil = "market"
	w.day = 2
	for person in [n, neighbour]: person.trust = 0.5
	g.offer = {"vigil": {n.id: "square", neighbour.id: "square"}}
	g.protect_pending[n.id] = true
	g.ward_log[w.day] = n.id
	var rng = w.rng.state
	g._settle_offers()
	check(is_equal_approx(n.trust, 0.56) and n.fear_eased and n.id in g.divulge_due, "a ward on the promised person's door keeps their vigil promise and promised disclosure")
	check(is_equal_approx(neighbour.trust, 0.35) and not neighbour.fear_eased, "a ward does not fulfil another resident's vigil promise")
	check(g.offer.is_empty() and g.protect_pending.is_empty() and w.rng.state == rng, "settlement clears obligations without RNG draws")
	g._settle_offers()
	check(is_equal_approx(n.trust, 0.56), "settlement rewards only once")
	n.trust = 0.5
	g.offer = {"ward": n.id, "vigil": {n.id: "square"}}
	g._settle_offers()
	check(is_equal_approx(n.trust, 0.56), "a ward satisfying both offers to one NPC does not pay twice")
	n.trust = 0.5
	g.offer = {"vigil": {n.id: "square"}}
	g.ward_log = {w.day - 1: n.id}
	g._settle_offers()
	check(is_equal_approx(n.trust, 0.35), "yesterday's ward does not keep tonight's promise")
	n.trust = 0.5
	w.player_vigil = "square"
	g.offer = {"vigil": {n.id: "square"}}
	g._settle_offers()
	check(is_equal_approx(n.trust, 0.56), "ordinary promised vigils retain their reward")


# ---- test_playtest_regressions


func playtest_regressions__game():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(25923, 10)
	return g


func _public_sighting() -> void:
	var g = playtest_regressions__game()
	var w = g.w
	var n = w.by_id["isolde"]
	var target = w.by_id["merrin"]
	var b = {"kind": "saw", "who": target.id, "day": 1, "phase": C.NIGHT, "block": n.home_block, "how": "window", "detail": "street"}
	w.evil_plan["fake_sightings"][n.id + ":1"] = b
	var lines: Array = []
	var facts: Array = []
	w.day = 2
	w.meeting = {"accusations": []}
	w.evil_plan["scapegoat"] = target.id
	n.traits["insight"] = 1.0
	n.traits["confidence"] = 1.0
	n.pressure = 10.0
	Mind._public_accusation(w, n, lines, facts)
	_check(facts.size() == 1 and facts[0]["subject"] == [target.id] and facts[0]["source"] == n.id and facts[0]["day"] == 1, "a publicly cited fake sighting becomes usable, attributed evidence")
	var before: int = g.board.size()
	g._facts(facts)
	g._facts(facts)
	_check(g.board.size() == before + 1, "repeating the same public sighting does not duplicate its card")


func _vigil_destination_only() -> void:
	var g = playtest_regressions__game()
	var w = g.w
	var a = w.npcs[0]
	var b = w.npcs[1]
	var lamp = w.npcs[2]
	a.home_block = "docks"
	b.home_block = "market"
	lamp.home_block = "square"
	w.night_walkers = [
		{"id": a.id, "block": "hill", "path": ["docks", "hill"], "why": "leaving docks for hill"},
		{"id": b.id, "block": "docks", "path": ["market", "docks"], "why": "arriving on docks"},
		{"id": lamp.id, "block": "square", "path": C.BLOCKS.keys(), "why": "walking the lamp route"},
	]
	w.player_vigil = "docks"
	w._night_sightings()
	_check(not (a.id in w.player_vigil_seen) and (b.id in w.player_vigil_seen) and (lamp.id in w.player_vigil_seen),
		"player vigil spots destination visitors and the Lamplighter, not residents leaving for another block")
	var watch_def = C.role_def("nightwatch")
	var watch_reading: Dictionary = watch_def.generate_reading(w, w.npcs[3], {"watch_block": "docks"}, Mind)
	_check(a.id in watch_reading["data"]["seen"] and b.id in watch_reading["data"]["seen"],
		"Night Watch still sees both departing residents and arriving visitors on the watched block")


func _multi_subject_vigil_no_collateral_note() -> void:
	var g = playtest_regressions__game()
	var w = g.w
	var target = w.demon()
	var bystander = w.living_good()[0]
	var victim = w.living_good()[1]
	target.home_block = "docks"
	bystander.home_block = "market"
	victim.home_block = "hill"
	g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1, "block": "hill", "text": "Killed on hill"})
	var vig = g.add_card({"kind": "sighting", "source": "player", "subject": [target.id, bystander.id], "day": 1, "phase": C.NIGHT, "block": "docks", "vigil": true, "text": "Night 1 vigil: saw both on the Docks."})
	var view: Dictionary = Live.view(g)
	var m = Canvas.new(view)
	var p = m.add_premise(target.id, "evil", Vector2.ZERO)
	m.connect_cards("e:" + Live.Evidence.normalize_card(g.board[vig - 1]).id, p)
	var listener = w.living_good()[2]
	var eval_res: Dictionary = preload("res://workshop/jury.gd").evaluate(view, m.compile(p), {"id": listener.id, "name": listener.name, "trust": 0.5, "confidence": 0.5, "insight": 0.9, "reasoning_mode": "bounded", "suspicion": {}, "npc_trust": {}, "reading_reliability": {}, "theories": {}, "ledger": {}, "case_memory": {}, "knowledge": {"self": listener.id, "good": [listener.id], "own_role": listener.role, "own_reports": [], "own_outings": {}}})
	_check(not eval_res.get("response", "").is_empty() and not eval_res.response.contains(bystander.name + "'s sighting"), "multi-subject vigil card produces a response without Seen elsewhere notes for unrelated bystanders")
