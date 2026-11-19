## Small wording fixes from Steward's Nov 19 report: a counter-claim or a relayed reading
## isn't shown as an accusation (A8), and spoken slots capitalise only their first letter (A6).
##   godot --headless --path . --script res://tools/test_card_wording_fixes.gd
extends SceneTree
const CardModel = preload("res://game/card_model.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	var names = {"edda": "Edda", "kiran": "Kiran", "lian": "Lian"}
	var plain = {"kind": "accusation", "source": "edda", "subject": ["kiran"], "text": "Edda publicly accused Kiran."}
	check(CardModel.short_text(plain, names) == "Edda accused Kiran", "a plain accusation reads as one (%s)" % CardModel.short_text(plain, names))
	var counter = {"kind": "accusation", "source": "edda", "subject": ["kiran"], "hint": false,
		"text": "Edda says Kiran's claim of the Seer is false: it's their own gift."}
	check(CardModel.short_text(counter, names) == "Edda: Kiran's claim is false", "a counter-claim says so (%s)" % CardModel.short_text(counter, names))
	var relay = {"kind": "accusation", "source": "lian", "subject": ["kiran"], "relay": true, "role": "dowser",
		"text": "Lian says the Dowser (unnamed) told them: one evil among Kiran."}
	check(CardModel.short_text(relay, names) == "Lian relays a Dowser reading: Kiran", "a relayed reading says so (%s)" % CardModel.short_text(relay, names))
	check(MindMeeting._cap_first("yesterday afternoon") == "Yesterday afternoon", "only the first letter is capitalised")
	check(MindMeeting._cap_first("McAllister's") == "McAllister's" and MindMeeting._cap_first("") == "", "names and empty slots are left alone")
	print("Card wording fixes: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
