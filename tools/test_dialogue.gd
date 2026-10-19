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
