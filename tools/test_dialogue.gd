## Contract/integration checks: content, knowledge boundaries, memory, RNG and preview UI.
## godot --headless --path . --script res://tools/test_dialogue.gd
extends SceneTree

const Dialogue = preload("res://sim/dialogue.gd")
const Fixtures = preload("res://tools/dialogue_scenarios.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
var fails = 0

func _init() -> void:
	_contracts()
	_memory()
	_flow()
	_exchange()
	_live()
	call_deferred("_lab")

func _contracts() -> void:
	for scenario in Fixtures.SCENARIOS:
		var distinct = {}
		for id in Fixtures.IDS:
			var original = scenario.duplicate(true)
			var result = Dialogue.compose(id, scenario, scenario["context"], {})
			distinct[result["text"]] = true
			_check(result["statement"] == scenario["statement"] and scenario == original, "%s/%s retains the approved statement and input" % [id, scenario["kind"]])
			if scenario["kind"] in ["report", "doubted", "friend"]:
				_check(scenario["statement"] in result["text"], "evidence-bearing sentence survives verbatim")
			elif scenario["kind"] == "revise":
				_check(scenario["argument"] in result["text"], "reconsideration names the exact argument")
			_check(not "{" in result["text"], "no unresolved template slots")
		_check(distinct.size() == 3, "three distinct voices for " + scenario["kind"])
	var unknown = {}
	_check(Dialogue.compose("edda", Fixtures.SCENARIOS[0], {}, unknown)["text"] == Fixtures.SCENARIOS[0]["statement"] and unknown.is_empty(), "unimplemented characters keep their original wording and memory")
	for i in range(1, 5):
		var scenario: Dictionary = Fixtures.SCENARIOS[i]
		var memory = {}
		_check(Dialogue.compose("agnes", scenario, {}, memory)["text"] == scenario["statement"] and memory.is_empty(), "no invented context for " + scenario["kind"])
	var quoted = {"kind": "report", "statement": "Greta told me 'I saw Jory'; I did not see him myself.", "event_id": "hearsay"}
	var output = Dialogue.compose("bart", quoted, {"trust": 0.1}, {})
	_check(quoted["statement"] in output["text"] and output["cue"] == "guarded", "low trust changes delivery, never hearsay into eyewitness evidence")
	_check(Dialogue.compose("bart", quoted, {"pressure": 1.0}, {})["cue"] == "pressure", "actual pressure can select a strained delivery")
	var private_line = Dialogue.compose("bart", quoted, {"request_privacy": true}, {})["text"]
	var public_line = Dialogue.compose("bart", quoted, {"request_privacy": true, "audience": "town"}, {})["text"]
	_check("Between us." in private_line and not "Between us." in public_line, "private request never leaks into meeting speech")
	var lie_context = {"true": false, "alignment": "evil", "secret": "smuggling"}
	_check(Dialogue.compose("bart", quoted, lie_context, {})["text"] == Dialogue.compose("bart", quoted, {}, {})["text"], "irrelevant hidden truth cannot affect wording")

func _memory() -> void:
	var memory = {}
	var scenario: Dictionary = Fixtures.SCENARIOS[0].duplicate(true)
	var first = Dialogue.compose("agnes", scenario, {"audience": "player"}, memory)
	var repeat = Dialogue.compose("agnes", scenario, {"audience": "player"}, memory)
	_check(not first["repeated"] and repeat["repeated"] and repeat["cue"] == "repeat", "a delivered account can be recognized on repetition")
	_check(not Dialogue.compose("agnes", scenario, {"audience": "jory"}, memory)["repeated"], "another listener has not already heard it")
	_check(not Dialogue.compose("agnes", scenario, {"audience": "town"}, memory)["repeated"], "private disclosure does not imply public disclosure")
	scenario["statement"] = "On night 2, neither Edda nor Jory read as the demon."
	_check(not Dialogue.compose("agnes", scenario, {}, memory)["repeated"], "a changed account is never called the same answer")
	_check(not Dialogue.compose("agnes", Fixtures.SCENARIOS[0], {}, {})["repeated"], "fresh case memory starts empty")

func _flow() -> void:
	for scenario in Fixtures.FLOW_SCENARIOS:
		for id in Fixtures.IDS:
			var memory = {}
			var baseline = scenario["parts"].duplicate(true)
			var parts = Dialogue.compose_turn(id, scenario["parts"], {"audience": "player"}, memory, scenario.get("preceded", false))
			_check(parts.size() == baseline.size() and baseline == scenario["parts"], "turn keeps all approved utterances and source descriptors unchanged")
			for i in range(parts.size()):
				_check(parts[i]["statement"] == baseline[i]["statement"] and baseline[i]["statement"] in parts[i]["text"], "flow never alters an approved fact or fabricated report")
				if i > 0 or scenario.get("preceded", false):
					_check(not parts[i]["text"].begins_with(Dialogue.Voices.VOICES[id]["report"][0]) and not parts[i]["text"].begins_with(Dialogue.Voices.VOICES[id]["report"][1]), "continuations suppress new report openings")
			var next = Dialogue.compose_turn(id, scenario["parts"], {"audience": "player"}, memory, scenario.get("preceded", false))
			_check(next.all(func(p): return p["repeated"]), "turn delivery retains per-event repetition tracking")
	var unknown_memory = {}
	var fallback = Dialogue.compose_turn("edda", Fixtures.FLOW_SCENARIOS[0]["parts"], {}, unknown_memory, true)
	_check(fallback.all(func(p): return p["text"] == p["statement"]) and unknown_memory.is_empty(), "unvoiced characters keep literal statements and no dialogue memory")
	var partial = Fixtures.FLOW_SCENARIOS[1]["parts"]
	var ctx = {"audience": "player", "request_privacy": true}
	var memory = {}
	var private_parts = Dialogue.compose_turn("agnes", partial, ctx, memory)
	_check(private_parts.filter(func(p): return "Please keep this between us." in p["text"]).size() == 1, "privacy request occurs once, at the end of a turn")
	var public_parts = Dialogue.compose_turn("agnes", partial, {"audience": "town", "request_privacy": true}, {})
	_check(public_parts.all(func(p): return not "Please keep this between us." in p["text"]), "public turn never requests private confidence")
	var fixture: Dictionary = Fixtures.FLOW_SCENARIOS[0]
	var truthful = Dialogue.compose_turn("bart", fixture["parts"], {"audience": "player", "true": true}, {}, true)
	var fabricated = Dialogue.compose_turn("bart", fixture["parts"], {"audience": "player", "true": false, "alignment": "evil"}, {}, true)
	_check(truthful == fabricated, "flow presentation cannot distinguish real from fabricated accounts")

func _exchange() -> void:
	for id in Fixtures.IDS:
		var memory = {}
		Dialogue.begin_conversation(memory)
		Dialogue.record_exchange(memory, "challenge_gift", id)
		var cue = Dialogue.exchange_cue(memory, "gift", id)
		var line = Dialogue.gift_reveal(id, "Seer", cue)
		_check(cue == "gift_after_challenge" and "Seer" in line and line != "" and not "{" in line, "gift reveal follows a prior relevant challenge in %s's own voice" % id)
		Dialogue.record_exchange(memory, "gift", id)
		_check(Dialogue.exchange_cue(memory, "gift", id) == "", "a second gift question is not treated as a new concession")
		Dialogue.record_exchange(memory, "accusation", "edda")
		cue = Dialogue.exchange_cue(memory, "opinion", "edda")
		var approved = "I have my doubts about Edda."
		var presented = Dialogue.contextualize(id, approved, cue, "Edda")
		_check(cue == "opinion_after_accusation" and approved in presented and presented != approved, "opinion refers to the immediately preceding accusation without changing stance")
		_check(Dialogue.exchange_cue(memory, "opinion", "jory") == "", "unrelated target does not inherit accusation context")
		Dialogue.record_exchange(memory, "opinion", "edda")
		cue = Dialogue.exchange_cue(memory, "opinion", "edda")
		_check(cue == "opinion_again" and approved in Dialogue.contextualize(id, approved, cue, "Edda"), "repeat question acknowledges prior exchange without asserting an unchanged belief")
		Dialogue.record_exchange(memory, "other")
		_check(Dialogue.exchange_cue(memory, "opinion", "edda") == "", "intervening action breaks conversational adjacency")
		memory["seen"] = {"historic": true}
		Dialogue.begin_conversation(memory)
		_check(Dialogue.exchange_cue(memory, "gift", id) == "" and Dialogue.exchange_cue(memory, "opinion", "edda") == "" and memory["seen"].has("historic"), "new talk forgets adjacency, not earlier evidence disclosures")
		_check(Dialogue.contextualize(id, approved, "opinion_after_accusation", "Edda") == presented, "wording is deterministic without game RNG")
		var refused = Dialogue.repeated_opinion_refusal(id, "Edda", "opinion_again", "It's not my place to say.")
		_check(refused != "It's not my place to say." and "Edda" in refused and not "{" in refused, "repeated refusal remains a refusal with a voice-specific line")
	var fallback = {}
	Dialogue.begin_conversation(fallback)
	Dialogue.record_exchange(fallback, "accusation", "edda")
	_check(Dialogue.contextualize("fenwick", "I suspect Edda.", Dialogue.exchange_cue(fallback, "opinion", "edda"), "Edda") == "I suspect Edda.", "other NPCs retain unvoiced fallback")
	var missing = {}
	Dialogue.record_exchange(missing, "accusation", "edda")
	_check(missing.is_empty(), "unscoped scripted speech cannot create phantom conversation history")

func _live() -> void:
	var g = Game.new()
	g.log_dir = "user://dialogue_tests"
	_case_with(g, ["agnes", "edda"])
	var w = g.w
	w.day = 3
	var n = w.by_id["agnes"]
	var target = w.by_id["edda"]
	var entry = {"day": 2, "role": "seer", "data": {"pair": ["edda", "jory"], "yes": true}, "text": "I looked at Edda and Jory: one of them reads as the demon", "true": true}
	var fact = Mind.info_fact(w, n, entry).duplicate(true)
	var before = w.rng.state
	var line = Mind.info_line(w, n, entry)
	_check("Last night, " + entry["text"] + "." in line["text"], "live reading retains its exact report and time")
	_check(before == w.rng.state and fact == Mind.info_fact(w, n, entry), "rendering consumes no game RNG and changes no evidence")
	n.dialogue_memory.clear()
	n.alignment = "evil"
	n.role = "demon"
	entry["true"] = false
	entry["fake"] = true
	_check(Mind.info_line(w, n, entry) == line, "the identical fabricated reading has the identical voice")
	n.alignment = "good"
	n.role = "clerk"
	n.traits["gossip"] = 0.9
	n.npc_trust[target.id] = 0.9
	n.suspicion[target.id] = 0.6
	var opinion = Mind.answer_opinion(w, n, target)
	_check("I have my doubts about Edda." in opinion["lines"][0]["text"] and "fond of Edda" in opinion["lines"][0]["text"], "live friendship acknowledges affection without erasing suspicion")
	_check(opinion["facts"].size() == 1 and opinion["facts"][0]["text"] == "Agnes distrusts Edda.", "friend dialogue retains the original opinion fact")
	n.npc_trust[target.id] = 0.5
	var neutral = Mind.answer_opinion(w, n, target)["lines"][0]["text"]
	_check(not "fond" in neutral and not "matters to me" in neutral, "no invented friendship")
	n.claimed_role = "seer"
	n.claim_public = true
	var challenge = {"kind": "claim", "source": target.id, "subject": [n.id], "role": "seer", "text": "Edda claims Seer."}
	var pressed = Mind.press(w, n, challenge)
	var speeches: Array = pressed["lines"].filter(func(x): return x is Dictionary)
	_check(speeches[0]["text"].begins_with("All right, let's talk it through.") and "Edda is lying." in speeches[0]["text"], "a real challenge uses the authored response without changing its claim")
	_check(pressed.get("dialogue_exchange", {}).get("action", "") == "challenge_gift", "live rival-role confrontation explicitly marks a gift challenge")
	n.claim_public = false
	n.claimed_role = "clerk"
	n.traits["privacy"] = 1.0
	n.traits["confidence"] = 0.0
	n.trust = 0.0
	n.pressure = 0.0
	n.secret = {"kind": "debt", "text": "owe Fenwick money"}
	n.history[w.time_key(2, C.NIGHT)] = "night:hill"
	var refusal_seen = false
	for i in range(30):
		var answer = Mind.answer_night(w, n, 2)
		if answer["facts"].any(func(f): return f["kind"] == "refusal"):
			refusal_seen = true
			_check(not "Fenwick" in answer["lines"][0]["text"] and not "hill" in answer["lines"][0]["text"], "real concealment does not leak the secret or hidden location")
			break
	_check(refusal_seen, "live whereabouts refusal reaches the composer")
	n.remarks = ["your argument about the night 2 reading"]
	n.loc = "tavern"
	n.busy_with = ""
	g.loc = "tavern"
	g.moved = true
	g.state = "day"
	g.command("talk agnes")
	_check(g.last_events.any(func(e): return e["k"] == "speech" and "I've been thinking about your argument" in e["text"]), "queued belief revision is expressed through the real conversation entry point")
	_check(n.remarks.is_empty(), "the existing remark is consumed once")
	# An actual player action records its listener and target, then the next
	# question can be contextualized without altering suspicion or evidence.
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 3
	g.free_repeats = 0
	n.silenced = false
	n.traits["gossip"] = 0.9
	Mind.Dialogue.begin_conversation(n.dialogue_memory)
	var claim_card: int = g.add_card({"kind": "claim", "source": target.id, "subject": [target.id],
		"role": "clerk", "text": "Edda claimed Clerk."})
	g.command("tell edda %d" % claim_card)
	_check(n.dialogue_memory.get("conversation", {}).get("last_action", "") == "accusation" and
		n.dialogue_memory.get("conversation", {}).get("last_subject", "") == target.id,
		"live conversation records the spoken accusation target")
	g.command("ask about edda")
	_check(g.last_events.any(func(ev): return ev.get("k", "") == "speech" and
		"About that concern you raised over Edda:" in str(ev.get("text", ""))),
		"live opinion answers the previous accusation with relevant context")
	_check(n.dialogue_memory.get("conversation", {}).get("last_action", "") == "opinion",
		"live dialogue records the last completed answer")
	g.command("ask about edda")
	_check(g.last_events.any(func(ev): return ev.get("k", "") == "speech" and
		"You're still wondering about Edda" in str(ev.get("text", ""))),
		"same-person followup is different from restarting the topic")

	var readings = [entry, entry.duplicate(true)]
	readings[1]["day"] = 1
	readings[1]["text"] = "my sight was unclear"
	n.dialogue_memory.clear()
	var grouped = Mind.info_lines(w, n, readings, "player", true)
	_check(grouped.size() == 2 and "Last night, " + entry["text"] + "." in grouped[0]["text"] and "On night 1, my sight was unclear." in grouped[1]["text"], "live grouped readings retain content and ordering")
	_check(not "Here's what I can tell you" in grouped[0]["text"] and not "Here, let me put it plainly" in grouped[1]["text"], "live uninterrupted role disclosure avoids fresh reading introductions")
	n.dialogue_memory.clear()
	Mind.Dialogue.begin_conversation(n.dialogue_memory)
	Mind.Dialogue.record_exchange(n.dialogue_memory, "challenge_gift", n.id)
	n.max_tier = 0
	n.claim_public = false
	var conceded: Dictionary = Mind.answer_gift(w, n, 3)
	_check(conceded["lines"][0]["text"].begins_with("All right. You've been pressing me about this") and
		"I'm the Clerk." in conceded["lines"][0]["text"], "real newly authorized gift disclosure acknowledges the previous challenge")
	_check(conceded["facts"].any(func(f): return f.get("kind", "") == "claim" and f.get("role", "") == "clerk"), "contextual first reveal still creates the same approved role claim")
	_case_with(g, ["agnes"])
	_check(g.w.by_id["agnes"].dialogue_memory.is_empty(), "starting a new case discards prior dialogue memory")

## The cast is drawn from a larger pool each case: find a seed that deals these people.
func _case_with(g, ids: Array) -> void:
	for sd in range(8251, 8451):
		g.new_case(sd, 10)
		if ids.all(func(i): return g.w.by_id.has(i)):
			return
	_check(false, "found a case with %s" % str(ids))

func _lab() -> void:
	var lab = load("res://ui/dialogue_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	_check(lab.last_results.size() == 3 and lab.memories["agnes"].is_empty(), "comparison scene shows all voices without recording previews")
	lab._refresh(true)
	lab._refresh(true)
	_check(lab.last_results["agnes"]["repeated"], "Speak/ask again records listener history")
	lab.audience_opt.select(1)
	lab._refresh(false)
	_check(not lab.last_results["agnes"]["repeated"], "comparison audience control isolates history")
	for i in range(Fixtures.SCENARIOS.size()):
		lab.scenario_opt.select(i)
		lab._refresh(false)
		_check(lab.last_results["bart"]["intent"] == Fixtures.SCENARIOS[i]["kind"], "comparison renders scenario %d" % i)
	var flow_start: int = Fixtures.SCENARIOS.size()
	for i in range(Fixtures.FLOW_SCENARIOS.size()):
		lab.scenario_opt.select(flow_start + i)
		lab._refresh(false)
		_check(lab.last_results["bart"]["parts"].size() == Fixtures.FLOW_SCENARIOS[i]["parts"].size(), "workshop renders full speaker turn %d" % i)
	var exchange_start: int = flow_start + Fixtures.FLOW_SCENARIOS.size()
	for i in range(Fixtures.EXCHANGE_SCENARIOS.size()):
		lab.scenario_opt.select(exchange_start + i)
		lab._refresh(false)
		_check(lab.last_results["bart"]["intent"] == "exchange" and not lab.last_results["bart"]["cue"].is_empty(), "workshop renders across-exchange continuity %d" % i)
	lab.scenario_opt.select(exchange_start + 1)
	lab._refresh(false)
	_check(lab.memories["agnes"].get("conversation", {}).is_empty(), "contextual workshop preview does not record primed prior speech")
	lab._refresh(true)
	_check(lab.memories["agnes"].get("conversation", {}).get("last_action", "") == "opinion", "delivered workshop exchange records the actual current answer")
	lab._refresh(false)
	_check(lab.last_results["agnes"]["cue"] == "opinion_again", "second preview continues after the first delivered opinion")
	lab.reset_memory()
	_check(lab.memories["agnes"].is_empty(), "reset clears delivery memory")
	lab.queue_free()
	await process_frame
	print("DIALOGUE FAILURES: %d" % fails)
	quit(1 if fails else 0)

func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		fails += 1
