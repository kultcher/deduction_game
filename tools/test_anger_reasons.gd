## Anger reasons (Michael, Nov 19). When distrust makes an NPC refuse, it says why: the
## grievance the player has repaired least, in its own voice (anger_<id>), in place of the
## generic refusal line. An apologised incident is passed over; with no grievance a line
## covers, the old refusal line stays.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const Voices = preload("res://sim/dialogue_voices.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_ids()
	_voiced()
	print("Anger reasons: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _ids() -> void:
	var cases = {
		"the Demonologist nominated me": "nominated_me",
		"the Demonologist voted to hang me": "voted_to_hang_me",
		"the Demonologist overruled my nomination": "overruled_my_nomination",
		"the Demonologist spared ab, whom I suspect": "spared_my_suspect",
		"the Demonologist pressed me with evidence": "pressed_with_evidence",
		"the Demonologist pressed me before the town without cause": "pressed_before_town",
		"pressed with 4 questions today": "too_many_questions",
		"the Demonologist guessed my gift wrong (clerk; 2 wrong so far)": "guessed_my_gift_wrong",
		"the Demonologist broke my confidence (card #3) at the meeting": "broke_my_confidence",
		"the Demonologist spread my secret": "spread_my_secret",
		"the Demonologist broke their word (ward)": "broke_your_word",
		"the presented reports argue against the claim": "argued_against_me",
		"the doubted reading holds up": "argued_against_me",
		"the Demonologist padded a case with thin circumstantial smears": "padded_case",
		"grief: the Demonologist nominated ab": "nominated_my_friend",
		"grief: the Demonologist voted to hang ab": "hanged_my_friend",
		"player accused ab": "accused_my_friend",
		"the Demonologist backed hanging ab, an innocent friend": "backed_hanging",
		"the Demonologist spared ab, whom I trust": "",
		"a civil conversation with the Demonologist": ""}
	var seen: Dictionary = {}
	var ok: bool = true
	for why in cases:
		var got: String = Mind.anger_id(why)
		if got != cases[why]:
			ok = false
			print("  %s -> %s (expected %s)" % [why, got, cases[why]])
		if got != "":
			seen[got] = true
	_check(ok, "each known player action maps to its anger reason, and nothing else does")
	_check(seen.size() == 17, "all 17 reasons are reachable (%d)" % seen.size())
	var missing: Array = []
	for id in seen:
		for v in Voices.VOICES:
			if not Voices.VOICES[v].has("anger_" + id):
				missing.append("%s/%s" % [v, id])
	_check(missing.is_empty(), "every voice has a line for every reason %s" % [missing])

func _case():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	g.w.day = 2
	return g

func _refusal(w, n) -> Dictionary:
	n.distrust_explained_day = -1
	var lines: Array = []
	Mind._append_distrust(w, n, lines)
	return lines[0] if lines.size() == 1 else {}

func _voiced() -> void:
	var g = _case()
	var w = g.w
	var n = w.living_good()[0]
	var friend = w.living_good()[1]
	n.trust = 0.9
	Mind.set_trust(w, n, n.trust - 0.3, "the Demonologist nominated me")
	w.day = 3
	Mind.set_trust(w, n, n.trust - 0.15, "the Demonologist pressed me with evidence")
	n.trust = 0.05
	var line: Dictionary = _refusal(w, n)
	var want: String = Voices.VOICES[n.id]["anger_nominated_me"].replace("{day}", "second day")
	_check(line.get("text", "") == want or line.get("text", "").begins_with(want.substr(0, 12)), "the refusal names the grievance repaired least, in the NPC's voice (\"%s\")" % line.get("text", ""))
	_check("{" not in str(line.get("text", "")), "every slot in the line is filled")
	_check(str(line.get("statement", "")).begins_with("I don't trust you."), "its statement keeps the plain refusal")
	n.grievances[0]["repaired"] = 0.2
	line = _refusal(w, n)
	_check(str(line.get("statement", "")) == "I don't trust you. You pressed me with evidence.", "once the nomination is mostly repaired, the larger standing grievance speaks")
	n.grievances[1]["apologised"] = true
	line = _refusal(w, n)
	_check(str(line.get("statement", "")) == "I don't trust you. You nominated me.", "an apologised incident is passed over")
	# A line that names someone names them.
	n.grievances.clear()
	w.day = 2
	Mind.set_trust(w, n, 0.9, "test")
	Mind.set_trust(w, n, 0.5, "the Demonologist overruled my nomination")
	Mind.tag_grievance(w, n, "the Demonologist overruled my nomination", {"subject": friend.id})
	n.trust = 0.05
	line = _refusal(w, n)
	_check(friend.name in str(line.get("text", "")), "an overruled nomination names the nominee (\"%s\")" % line.get("text", ""))
	n.grievances.clear()
	Mind.set_trust(w, n, 0.9, "test")
	Mind.set_trust(w, n, 0.5, "the Demonologist broke their word (vigil)")
	n.trust = 0.05
	line = _refusal(w, n)
	_check("vigil" in str(line.get("text", "")) and "{" not in str(line.get("text", "")), "a broken promise names what was promised (\"%s\")" % line.get("text", ""))
	# No grievance a line covers: the old refusal.
	n.grievances.clear()
	n.distrust_memory = {}
	n.trust = 0.05
	line = _refusal(w, n)
	_check(str(line.get("statement", "")) == "You're an outsider, I'm not sure I can trust you.", "with no grievance, the outsider line stays")
	# Above the threshold nothing is said.
	n.trust = Tuning.Trust.DISTRUST_EXPLAIN_THRESHOLD + 0.1
	_check(_refusal(w, n).is_empty(), "a trusting NPC says no distrust line at all")
