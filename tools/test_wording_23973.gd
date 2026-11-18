## Wording fixes from playtest 23973 (Coroner's review, docs/playtests/23973.md; Michael, Nov 17):
## - a reply that says the case clashes with what the listener knows, yet still moved them,
##   follows with "still, it moves me" (present_clashes_moved), not "Fits what I know"
##   (Bart: "Doesn't square with what I've got... Fits what I know.");
## - the same after "those accounts clash";
## - a "they're lying" that stands without "Then", and a past-tense one for a dead accuser,
##   exist in every voice (defence_lying_alone, defence_lied; Beadle routes them);
## - Nisha's "my own model" is "my own reckoning".
extends SceneTree
const Game = preload("res://game/game.gd")
const Presentations = preload("res://sim/dialogue_presentations.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const Voices = preload("res://sim/dialogue_voices.gd")
var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7350, 10)
	var w = g.w
	var target = w.demon()
	for listener in w.npcs:
		if listener == target or not Dialogue.has_voice(listener.id):
			continue
		var v: Dictionary = Voices.VOICES[listener.id]
		var moved: String = str(v.get("present_clashes_moved", "")).replace("{target}", target.name)
		var fits: String = str(v.get("present_accept_open", "")).replace("{target}", target.name)
		# The case clashes with what they hold (no version of events fits), but moved them.
		var clash: Dictionary = {"agreement": 0.6, "stance": "accept", "path_kind": "reading", "assessment": {"status": "ok"},
			"case_eval": {"consistent": true, "impossible": false, "posterior": 0.7, "movement": [], "rivals": []},
			"reasoning": {"status": "unresolved", "support_exhausted": true, "support_tested": 0, "considered": ["c1"], "ignored": [], "ignored_lines": [],
				"private_checks": {"fatal": false, "objections": [], "rejected": []}}}
		var r: Dictionary = Presentations.render_workshop_reply(w, listener, {"type": "evil", "a": target.id, "at": "Original alignment"},
			[target.id], clash, {"people": [], "listener": {}}, {"selected": ["c1"]}, "accept", false, false, "canonical", {})
		var t: String = str(r.get("text", ""))
		check(moved != "" and moved in t and not (fits in t), "%s: after 'it clashes with what I know', still moved, not 'fits what I know': %s" % [listener.id, t])
		# Those accounts clash with each other, and it moved them.
		var inc: Dictionary = clash.duplicate(true)
		inc.reasoning.status = "inconsistent"
		r = Presentations.render_workshop_reply(w, listener, {"type": "evil", "a": target.id, "at": "Original alignment"},
			[target.id], inc, {"people": [], "listener": {}}, {"selected": ["c1"]}, "accept", false, false, "canonical", {})
		t = str(r.get("text", ""))
		check(moved in t and not (fits in t), "%s: after 'those accounts clash', the same: %s" % [listener.id, t])
		# A case for someone's innocence: the neutral line, since some voices' lean toward
		# suspicion ("it weighs with me against {target}"; Codex, #219).
		var who = w.living_good()[0] if w.living_good()[0] != listener else w.living_good()[1]
		r = Presentations.render_workshop_reply(w, listener, {"type": "good", "a": who.id, "at": "Original alignment"},
			[who.id], clash, {"people": [], "listener": {}}, {"selected": ["c1"]}, "accept", false, false, "canonical", {})
		t = str(r.get("text", ""))
		check(("Still, it changes how I see %s." % who.name) in t and not (str(v.get("present_accept_open", "")).replace("{target}", who.name) in t),
			"%s: a clash in a case for innocence ends on the neutral line: %s" % [listener.id, t])
		for key in ["defence_lying_alone", "defence_lied"]:
			var line: String = str(v.get(key, ""))
			check(line != "" and "{source}" in line and not line.begins_with("Then"), "%s/%s stands on its own: %s" % [listener.id, key, line])
		check(not (" is lying" in str(v.get("defence_lied", ""))), "%s/defence_lied is in the past tense" % listener.id)
	check(not ("model" in str(Voices.VOICES["nisha"].get("meeting_agree_accuse", ""))), "Nisha's agreement doesn't say 'my own model'")
	print("Wording 23973: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
