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
	var known = {"kind": "argument", "key": "lied:isolde", "facts": ["x"], "stance": "accept", "already": true, "claim": "Isolde lied"}
	_check("already" in Dialogue.decision("unwritten_character", known, "player", {})["text"], "an accepted argument that moved nothing says they'd come to it already")
	known["already"] = false
	_check(not "already" in Dialogue.decision("unwritten_character", known, "player", {})["text"], "a persuasive accepted argument doesn't")
	var hidden = d.duplicate(true)
	hidden.merge({"alignment": "evil", "secret": "smuggling", "true_role": "demon"})
	_check(Dialogue.decision("bart", hidden, "town", {}) == Dialogue.decision("bart", d, "town", {}), "irrelevant hidden fields cannot alter presentation")
	var weird = {"kind": "nomination", "target": "{reason} 100%", "reason_text": "A quoted {target} remains literal."}
	var text: String = Dialogue.decision("bart", weird, "town", {})["text"]
	_check("{reason} 100%" in text and "quoted {target}" in text, "substituted content is not recursively treated as template code")
	_check(not Dialogue.decision("unwritten_character", {"kind": "nomination", "target": "Edda"}, "town", {})["text"].is_empty(), "unauthored characters receive usable generic decision speech")

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
	_check(reply["dialogue"].get("reason", "") in ["weak", "quality", "source"] or (reply.get("workshop", false) and not reply.assessment.response.is_empty() and not reply.dialogue.has("role")), "a weak live argument gives a supported reason, not a fabricated role explanation")
	_check(w.rng.state == rng_before and g.board == board_before, "good argument speech does not consume RNG or alter evidence")
	var trace = g.add_card({"kind": "trace", "source": "evidence", "block": "market", "day": 2, "text": "Market trace."})
	var seen = g.add_card({"kind": "sighting", "source": "player", "subject": [target.id], "block": "market", "day": 2, "phase": C.EVENING, "text": "Seen on Market."})
	var options: Array = g.link_cards([trace, seen])["options"]
	var option: Dictionary = options.filter(func(o): return o["expl"]["conclusion"]["type"] == "demon")[0]
	var trace_ded = g.file_deduction(option["expl"]["conclusion"], option["match"]["cards"], option["match"], option["expl"]["id"])
	n.suspicion[target.id] = 0.0
	n.npc_trust[target.id] = 0.5
	var alternative = Argue.evaluate(w, n, g.board[trace_ded - 1], g.board, 1.0)
	if alternative.get("blocked", false):
		# This fixture's trace card is incomplete; since Oct 25 that is rejected with a
		# named reason instead of being judged by the legacy rules.
		_check(" ".join(PackedStringArray(alternative.get("lines", []))).to_lower().contains("trace"), "an incomplete trace card is rejected with a named reason")
	else:
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
	# Voting is silent: a real vote command adds no speech.
	w.begin_meeting()
	g.state = "meeting"
	g.command("nominate " + target.id)
	g.command("vote yes")
	_check(g.last_events.filter(func(e): return e["k"] == "speech").is_empty(), "votes are counted without vote speeches")
	g.new_case(4242, 10)
	_check(g.w.npcs.all(func(x): return x.dialogue_memory.is_empty()), "new case resets delivery history")
