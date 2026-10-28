## godot --headless --path . --script res://tools/dialogue_preview.gd
extends SceneTree

const Dialogue = preload("res://sim/dialogue.gd")
const Fixtures = preload("res://tools/dialogue_scenarios.gd")
const C = preload("res://sim/content.gd")

func _init() -> void:
	for scenario in Fixtures.SCENARIOS:
		print("\n--- %s ---" % scenario["title"])
		print("Approved statement: " + scenario["statement"])
		for id in Fixtures.IDS:
			var context: Dictionary = scenario["context"].duplicate(true)
			context.merge({"trust": 0.6, "pressure": 0.0, "audience": "player"})
			var cast: Dictionary = C.CAST.filter(func(c): return c["id"] == id)[0]
			var memory = {}
			Fixtures.prime(id, scenario, context["audience"], memory)
			var result = Dialogue.compose(id, scenario, context, memory)
			print("%s: %s" % [cast["name"], result["text"]])
	for scenario in Fixtures.FLOW_SCENARIOS:
		print("\n--- %s ---" % scenario.title)
		for id in Fixtures.IDS:
			var context: Dictionary = scenario.get("context", {}).duplicate(true)
			var parts = Dialogue.compose_turn(id, Fixtures.flow_parts(id, scenario), context, {}, scenario.get("preceded", false))
			var spoken: Array = parts.map(func(p): return p.text)
			if scenario.has("lead_in"): spoken.push_front(scenario.lead_in)
			print("%s: %s" % [id.capitalize(), " ".join(PackedStringArray(spoken))])
	print("\n--- Same fact, listener memory ---")
	var memory = {}
	for audience in ["player", "player", "town", "agnes"]:
		var result = Dialogue.compose("bart", Fixtures.SCENARIOS[0], {"audience": audience}, memory)
		print("To %s [%s]: %s" % [audience, result["cue"], result["text"]])
	var sketches = preload("res://tools/dialogue_voice_sketches.gd").read()
	print("\n--- Voice calibration: editorial drafts, not live voices ---")
	for scenario in sketches.scenarios:
		print("\n%s | Player: %s\nApproved meaning: %s" % [scenario.title, scenario.prompt, scenario.statement])
		for cast in C.CAST:
			print("%s: %s" % [cast.name, sketches.voices[cast.id][scenario.key]])
	quit()
