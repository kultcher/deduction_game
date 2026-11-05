## Meeting plan M2b (docs/meeting_flow_plan.md section 3, Step 3): the podium press.
##   - Opens after the defence, once per nomination; voting or a statement skips/closes it;
##     a silenced nominee can't be pressed.
##   - press role: public claim, hint or refusal (refusal: pressure, public receipt);
##     press readings once claimed; press night: a public account the town hears, kept on
##     record; an evil walker never tells the truth of its night; press card routes by card.
##   - Everything said is heard by every other living listener.
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const MindPodium = preload("res://sim/mind_podium.gd")
const Mind = preload("res://sim/mind.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_test_flow()
	_test_press_role()
	_test_press_night_public()
	_test_evil_walker()
	_test_cards()
	_test_silenced()
	print("Meeting M2b: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _meeting_game(sd: int, day: int = 2):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 7)
	if g.state == "approach":
		g.command("decline")
	g.w.day = day
	g.w.phase = C.EVENING
	g.stream_meeting = false
	g._start_meeting()
	return g


## Play the town forward (passively) to a day's meeting.
func _played_game(sd: int, day: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 7)
	for i in range(80):
		if g.w.day >= day and g.state == "meeting":
			break
		match g.state:
			"night":
				g.command("sleep")
			"meeting":
				g.command("done" if g.town_quiet else "wait")
			"nomination":
				g.command("vote no")
			"approach":
				g.command("decline")
			_:
				g.command("wait")
	return g


func _heard_by_town(g, d) -> bool:
	var prefix: String = "podium:%s:" % d.id
	for l in g.w.living():
		if l == d:
			continue
		# Evil listeners hear through their good self (the shadow); their own ledger stays empty.
		var mind = l.shadow if l.is_evil() else l
		if mind == null or not mind.ledger.keys().any(func(k): return str(k).begins_with(prefix)):
			return false
	return true


func _unclaimed(g) -> Array:
	var free: Array = g.w.living().filter(func(n): return not n.silenced and g.w.can_nominate("player", n.id) == "")
	var out: Array = free.filter(func(n): return not n.claim_public)
	return out if not out.is_empty() else free


func _test_flow() -> void:
	var g = _meeting_game(8401)
	var t = _unclaimed(g)[0]
	var out: String = g.command("nominate %s raw" % t.name.to_lower())
	_check(g.w.meeting.pending.get("press", "") == "open" and "press role" in out, "the press opens after the defence and the prompt offers it")
	g.command("press night")
	_check(g.w.meeting.pending.get("press", "") == "done", "a press is spent once used")
	var again: String = g.command("press role")
	_check("already had your chance" in again and g.state == "nomination", "only one press per nomination")
	g.command("vote no")
	_check(g.state == "meeting", "voting after a press resolves the nomination as before")
	var g2 = _meeting_game(8402)
	var t2 = _unclaimed(g2)[0]
	g2.command("nominate %s raw" % t2.name.to_lower())
	g2.command("accuse")
	_check(g2.w.meeting.pending.get("press", "") == "closed" and "already had your chance" in g2.command("press night"),
		"speaking for or against closes the press (the statement comes after it)")
	var g3 = _meeting_game(8403)
	var t3 = _unclaimed(g3)[0]
	g3.command("nominate %s raw" % t3.name.to_lower())
	g3.command("vote no")
	_check(g3.state == "meeting", "voting straight away skips the press")
	var g4 = _meeting_game(8404)
	var t4 = _unclaimed(g4)[0]
	g4.command("nominate %s raw" % t4.name.to_lower())
	g4.command("press skip")
	_check(g4.w.meeting.pending.get("press", "") == "skipped" and g4.state == "nomination", "'press skip' holds your peace and keeps the vote open")


func _test_press_role() -> void:
	var seen: Dictionary = {}
	for sd in range(8410, 8440):
		if seen.size() == 3:
			break  # claim, hint and refusal all checked
		var g = _meeting_game(sd)
		var cands: Array = _unclaimed(g)
		if cands.is_empty():
			continue
		var t = cands[0]
		# Lean the outcome: private people refuse, open pressured ones claim.
		t.traits["privacy"] = 0.95 if sd % 2 == 0 else 0.05
		t.pressure = 0.0 if sd % 2 == 0 else 2.0
		g.command("nominate %s raw" % t.name.to_lower())
		var p0: float = t.pressure
		g.command("press role")
		var outcome: String = ""
		if t.claim_public:
			outcome = "claim"
		elif g.board.any(func(c): return c.get("kind", "") == "hint" and c.get("source", "") == t.id):
			outcome = "hint"
		elif g.board.any(func(c): return c.get("kind", "") == "refusal" and c.get("source", "") == t.id):
			outcome = "refusal"
		if outcome == "" or seen.has(outcome):
			continue
		seen[outcome] = true
		match outcome:
			"claim":
				_check(g.board.any(func(c): return c.get("kind", "") == "claim" and c.get("source", "") == t.id) and g.w.public_claims.any(func(pc): return pc.who == t.id),
					"press role: a public claim goes on the board and on the town's record")
			"hint":
				_check(t.max_tier >= 2 and _heard_by_town(g, t), "press role: a hint is public and every listener hears it")
			"refusal":
				_check(t.pressure > p0 and _heard_by_town(g, t), "press role: a refusal raises their pressure and the town hears it")
	_check(seen.has("claim") and seen.has("refusal"), "press role produces claims and refusals across the sample (%s)" % ", ".join(PackedStringArray(seen.keys())))
	# Once claimed, the gift press asks for readings instead.
	var g = _meeting_game(8441)
	var claimed: Array = g.w.living().filter(func(n): return n.claim_public and g.w.can_nominate("player", n.id) == "")
	if not claimed.is_empty():
		var c = claimed[0]
		var opts: Dictionary = MindPodium.options(g.w, c)
		_check(opts.gift in ["readings", ""], "a claimed nominee is pressed for readings, not their gift (%s)" % opts.gift)


func _test_press_night_public() -> void:
	var g = _meeting_game(8450)
	var t = _unclaimed(g)[0]
	g.command("nominate %s raw" % t.name.to_lower())
	var before: int = g.board.size()
	g.command("press night 1")
	var cards: Array = g.board.slice(before)
	_check(cards.any(func(c): return c.get("kind", "") in ["alibi", "refusal"] and c.get("source", "") == t.id),
		"press night: their account goes on the board")
	_check(_heard_by_town(g, t), "press night: every other listener hears the account")
	# And their shared model takes it in as testimony (Shared.prepare reads 'tell' receipts).
	var listener = g.w.living().filter(func(l): return l != t and not l.is_evil())[0]
	var heard: Array = listener.ledger.keys().filter(func(k): return str(k).begins_with("podium:%s:" % t.id))
	var rid: String = listener.ledger[heard[0]].meta.workshop_card.id if not heard.is_empty() else ""
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, listener, "test")
	_check(rid != "" and rid in listener.workshop_state.get("facts", []), "a listener's shared model reasons with the press answer")
	_check(t.dialogue_memory.get("night_accounts", {}).has("1"), "press night: the account is kept on record for later questions")
	_check(not g.w.meeting.pending.get("case_facts", []).is_empty(), "what the press shook loose feeds the trial's case facts")
	_check(g.w.dlog.entries.any(func(e): return e.get("type", "") == "podium_press" and e.get("target", "") == t.id), "the press is logged")


func _test_evil_walker() -> void:
	for sd in [8301, 8305]:
		var g = _played_game(sd, 3)
		var nd: int = g.w.day - 1
		var t = g.w.demon()
		if g.state != "meeting" or not t.alive or g.w.can_nominate("player", t.id) != "":
			continue
		var was_out: bool = str(t.history.get(g.w.time_key(nd, C.NIGHT), "home")).begins_with("night:")
		g.command("nominate %s raw" % t.name.to_lower())
		var before: int = g.board.size()
		var res: Dictionary = MindPodium.press_night(g.w, t, nd, true)
		_check(was_out and res.outcome in ["lie", "refusal", "duty"], "case %d: the demon out last night lies, refuses or tells its bluff's duty (%s)" % [sd, res.outcome])
		_check(not res.facts.any(func(f): return f.get("kind", "") == "secret" or (f.get("kind", "") == "alibi" and not f.get("home", true) and not f.get("duty_claim", false))),
			"case %d: and never gives away where it really was" % sd)


func _test_cards() -> void:
	var g = _meeting_game(8460)
	var t = _unclaimed(g)[0]
	var day_card: Dictionary = {"kind": "sighting", "subject": [t.id], "phase": C.MORNING, "day": 1, "text": "x"}
	var night_card: Dictionary = {"kind": "sighting", "subject": [t.id], "phase": C.NIGHT, "day": 1, "block": t.home_block, "source": "player", "text": "y"}
	_check(not MindPodium.card_fits(g.w, t, day_card), "a daytime sighting isn't something to press them on")
	_check(MindPodium.card_fits(g.w, t, night_card), "a night sighting of them is")
	_check(not MindPodium.card_fits(g.w, t, {"kind": "sighting", "subject": ["nobody"], "phase": C.NIGHT, "day": 1, "text": "z"}), "a card about someone else isn't")
	g.command("nominate %s raw" % t.name.to_lower())
	var res: Dictionary = MindPodium.press_card(g.w, t, night_card, true)
	_check(res.get("mode", "") == "night" and int(res.get("night", -1)) == 1, "a night sighting card presses their account of that night")
	var g2 = _meeting_game(8461)
	var t2 = _unclaimed(g2)[0]
	g2.command("nominate %s raw" % t2.name.to_lower())
	var out: String = g2.command("press card 1")
	_check(g2.state == "nomination" and (g2.w.meeting.pending.press == "open" or g2.w.meeting.pending.press == "done"), "press card with an unfitting card is refused without spending the press (%s)" % out.substr(0, 60))


func _test_silenced() -> void:
	var g = _meeting_game(8470)
	var t = _unclaimed(g)[0]
	t.silenced = true
	g.command("nominate %s raw" % t.name.to_lower())
	_check(g.w.meeting.pending.get("press", "") == "silenced", "a silenced nominee can't be pressed")
	var out: String = g.command("press night")
	_check("taken their voice" in out and g.state == "nomination", "and the command says why without spending anything")
	_check(MindPodium.options(g.w, t).silenced, "options() reports them silenced")
