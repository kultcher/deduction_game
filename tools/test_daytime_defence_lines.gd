## The daytime-whereabouts defence's voice lines (wording settled by Michael, Nov 17;
## docs/DIALOGUE_DESIGN.md §8.1). Every voice renders all three with the documented
## slots and leaves no slot unfilled; the stand-only pointed lines (Greta, Odette) are
## never what a private defence gets.
extends SceneTree
const Dialogue = preload("res://sim/dialogue.gd")
const Voices = preload("res://sim/dialogue_voices.gd")
var checks = 0
var fails = 0

const SLOTS = {"place": "the mill", "Place": "The mill", "when": "this morning", "When": "This morning",
	"others": "Agnes and Hollis", "suspect": "Kiran"}
const FALLBACK = {
	"defence_day_others": "I was at {place} {when}, and so were {others}. Ask any of them what they saw.",
	"defence_day_alone": "I was at {place} {when}. Being seen in the open is no crime.",
	"defence_day_others_pointed": "I was at {place} {when}. So was {suspect}, if it's company you're weighing.",
}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		print("FAIL " + label)
		fails += 1

func _render(id: String, key: String) -> String:
	var fb: String = FALLBACK.get(key, FALLBACK["defence_day_others_pointed"])
	for k in SLOTS:
		fb = fb.replace("{" + k + "}", SLOTS[k])
	return Dialogue.voice_line(id, key, fb, SLOTS)

func _init() -> void:
	for id in Voices.VOICES:
		for key in FALLBACK:
			var text: String = _render(id, key)
			check(not "{" in text and not "}" in text, "%s %s: no slot left: %s" % [id, key, text])
			check("mill" in text, "%s %s: names the place: %s" % [id, key, text])
		var stand: String = Voices.VOICES[id].get("defence_day_others_pointed_stand", "")
		var private: String = _render(id, "defence_day_others_pointed")
		check(not ("only me you" in private or "only one of us" in private), "%s: the private pointed line never assumes a meeting: %s" % [id, private])
		check("Kiran" in private, "%s: the private pointed line names the suspect: %s" % [id, private])
		if stand != "":
			var s: String = _render(id, "defence_day_others_pointed_stand")
			check(not "{" in s and "Kiran" in s, "%s: the stand-only line renders: %s" % [id, s])
	check(Voices.VOICES["greta"].has("defence_day_others_pointed_stand") and Voices.VOICES["odette"].has("defence_day_others_pointed_stand"), "Greta's and Odette's stand-only lines are kept apart")
	print("Daytime defence lines: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
