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
			var result = Dialogue.compose(id, scenario, context, {})
			print("%s: %s" % [cast["name"], result["text"]])
	print("\n--- Same fact, listener memory ---")
	var memory = {}
	for audience in ["player", "player", "town", "agnes"]:
		var result = Dialogue.compose("bart", Fixtures.SCENARIOS[0], {"audience": audience}, memory)
		print("To %s [%s]: %s" % [audience, result["cue"], result["text"]])
	quit()
