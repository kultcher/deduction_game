## Resolved-decision dialogue contracts and normal-game integration.
## godot --headless --path . --script res://tools/test_dialogue_decisions.gd
extends SceneTree

const Dialogue = preload("res://sim/dialogue.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Argue = preload("res://sim/argue.gd")
const C = preload("res://sim/content.gd")
var fails = 0

func _init() -> void:
	_continuity()
	_live()
	print("DECISION DIALOGUE FAILURES: %d" % fails)
	quit(1 if fails else 0)

func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		fails += 1

func _continuity() -> void:
	var memory = {}
	var d = {"kind": "argument", "key": "demon:edda", "claim": "Edda is the demon", "target_id": "edda", "accusing": true,
		"facts": ["reading:1"], "stance": "reject", "reason": "weak"}
	var original = d.duplicate(true)
	var first = Dialogue.decision("agnes", d, "player", memory)
	var repeat = Dialogue.decision("agnes", d, "player", memory)
	_check(d == original and first["cue"] == "reject" and repeat["cue"] == "repeat", "same evidence and assessment repeat without mutating the input")
	_check(Dialogue.decision("agnes", d, "town", memory)["cue"] == "reject", "a private reply is not a previous public reply")
	d["stance"] = "accept"
	d.erase("reason")
	_check(Dialogue.decision("agnes", d, "player", memory)["cue"] == "changed", "same evidence with a new assessment acknowledges revision")
	d["facts"].append("sighting:2")
	_check(Dialogue.decision("agnes", d, "player", memory)["cue"] == "new_evidence", "new evidence for the same conclusion is not dismissed as repetition")
	d["facts"] = ["reading:1"]
	_check(Dialogue.decision("agnes", d, "player", memory)["cue"] == "reframed", "removing a support is not called new evidence")
	var vote = {"kind": "vote", "target_id": "edda", "target": "Edda", "yes": false, "reason": "trust"}
	_check("I heard your case" in Dialogue.decision("agnes", vote, "town", memory)["text"], "a no vote acknowledges the previously accepted case")
	d["stance"] = "reject"
	Dialogue.decision("agnes", d, "town", memory)
	_check(not "I heard your case" in Dialogue.decision("agnes", vote, "town", memory)["text"], "latest rejection supersedes an older acceptance across audiences")
	var hidden = d.duplicate(true)
	hidden.merge({"alignment": "evil", "secret": "smuggling", "true_role": "demon"})
	_check(Dialogue.decision("bart", hidden, "town", {}) == Dialogue.decision("bart", d, "town", {}), "irrelevant hidden fields cannot alter presentation")
	var weird = {"kind": "nomination", "target": "{reason} 100%", "reason_text": "A quoted {target} remains literal."}
	var text: String = Dialogue.decision("bart", weird, "town", {})["text"]
	_check("{reason} 100%" in text and "quoted {target}" in text, "substituted content is not recursively treated as template code")
	_check(not Dialogue.decision("unwritten_character", vote, "town", {})["text"].is_empty(), "unauthored characters receive usable generic decision speech")

func _live() -> void:
	var g = Game.new()
	g.log_dir = "user://dialogue_decision_tests"
	g.new_case(4242, 10)
	var w = g.w
	w.day = 3
	var n = w.living_good()[0]
	var target = w.living().filter(func(x): return x != n)[0]
	# A deliberately weak, freeform argument: a claim alone does not establish evil.
	var k = g.add_card({"kind": "claim", "source": target.id, "subject": [target.id], "role": "surveyor", "text": "I am the Surveyor."})
	var dn = g.file_deduction({"type": "evil", "a": target.id}, [k])
	_check(dn > 0, "fixture can file a weak accusation")
	if dn <= 0:
		return
	var board_before = g.board.duplicate(true)
	var rng_before = w.rng.state
	var reply = Argue.evaluate(w, n, g.board[dn - 1], g.board, 1.0)
	_check(reply["dialogue"].get("reason", "") in ["weak", "quality", "source"], "a weak live argument gives a supported reason, not a fabricated role explanation")
	_check(w.rng.state == rng_before and g.board == board_before, "good argument speech does not consume RNG or alter evidence")
	var trace = g.add_card({"kind": "trace", "source": "evidence", "block": "market", "day": 2, "text": "Market trace."})
	var seen = g.add_card({"kind": "sighting", "source": "player", "subject": [target.id], "block": "market", "day": 2, "phase": C.EVENING, "text": "Seen on Market."})
	var options: Array = g.link_cards([trace, seen])["options"]
	var option: Dictionary = options.filter(func(o): return o["expl"]["conclusion"]["type"] == "demon")[0]
	var trace_ded = g.file_deduction(option["expl"]["conclusion"], option["match"]["cards"], option["match"], option["expl"]["id"])
	n.suspicion[target.id] = 0.0
	n.npc_trust[target.id] = 0.5
	var alternative = Argue.evaluate(w, n, g.board[trace_ded - 1], g.board, 1.0)
	_check(alternative["dialogue"].get("reason", "") == "alternative" and "someone else" in alternative["dialogue"].get("alternative", ""), "live trace reply names the alternative actually weighted by the evaluator")
	n.dialogue_memory.clear()
	n.silenced = true
	var silent = Argue.evaluate(w, n, g.board[dn - 1], g.board, 0.6)
	_check(silent["lines"].is_empty() and n.dialogue_memory.is_empty(), "silenced argument listeners express and remember no speech")
	n.silenced = false
	Argue.evaluate(w, n, g.board[dn - 1], g.board, 0.5, false)
	_check(n.dialogue_memory.is_empty(), "a silently evaluated meeting statement records no spoken position")
	# Test the normal command path, including one free repetition and subsequent cost.
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 3
	g.free_repeats = 0
	g.command("convince %d" % dn)
	_check(g.questions_left == 3 and g.free_repeats == 1, "already-heard argument is free once despite rewritten response")
	g.command("convince %d" % dn)
	_check(g.questions_left == 2, "a further repeat still costs a question")
	# Control the vote inputs, then use the real vote resolver.
	n.ledger.clear()
	n.suspicion.clear()
	n.suspicion[target.id] = 0.45
	n.npc_trust[target.id] = 1.0
	n.trust = 0.8
	n.spare_pref.clear()
	n.traits["confidence"] = 0.5
	w.begin_meeting()
	Dialogue.decision(n.id, {"kind": "argument", "key": "fixture", "facts": ["fixture"], "stance": "accept", "target_id": target.id, "accusing": true, "claim": target.name + " is evil"}, "player", n.dialogue_memory)
	var no = Mind.vote(w, n, target.id, "player", false, "", 0)
	_check(not no and "trust" in n.vote_speech["text"].to_lower(), "actual trust penalty explains a resolved no vote")
	_check("case against" in n.vote_speech["text"], "live vote connects acceptance to a different voting decision")
	n.npc_trust[target.id] = 0.5
	n.suspicion[target.id] = 0.4
	var yes = Mind.vote(w, n, target.id, "player", false, "accuse", 0)
	_check(yes and "accusation" in n.vote_speech["text"], "a pivotal player accusation explains a resolved yes vote")
	var other = w.living().filter(func(x): return x != n and x != target)[0]
	w.meeting["block"] = other.id
	n.suspicion[other.id] = 0.8
	_check(not Mind.vote(w, n, target.id, "player", false, "", 0) and other.name in n.vote_speech["text"], "existing-block preference names the actual competing nominee")
	n.silenced = true
	Mind.vote(w, n, target.id, "player", false, "", 0)
	_check(n.vote_speech.is_empty(), "silenced voters do not speak")
	n.silenced = false
	# Normal meeting command emits ordered replies consistent with the actual tally.
	w.begin_meeting()
	g.state = "meeting"
	g.command("nominate " + target.id)
	var cards_before = g.board.size()
	g.command("vote yes")
	var tally: Dictionary = w.meeting["results"][-1]
	var speeches: Array = tally["speeches"]
	_check(speeches.map(func(x): return x["speaker"]) == tally["order"].filter(func(x): return x != "player"), "vote speech follows the actual clockwise order")
	_check(g.last_events.filter(func(e): return e["k"] == "speech").size() == speeches.size(), "real game command delivers all vote explanations to the main log")
	_check(g.board.size() == cards_before + 1, "vote explanations create no extra evidence cards")
	for speech in speeches:
		var voter = w.by_id[speech["speaker"]]
		var is_yes = voter.id in tally["yes"]
		var expected = Dialogue.decision(voter.id, {"kind": "vote", "target": target.name, "yes": is_yes}, "town", {})["text"].split(".")[0]
		_check(speech["text"].begins_with(expected), "speech agrees with counted vote: " + voter.id)
	g.new_case(4242, 10)
	_check(g.w.npcs.all(func(x): return x.dialogue_memory.is_empty() and x.vote_speech.is_empty()), "new case resets both delivery history and vote presentation")
