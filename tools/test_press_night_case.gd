## Michael, Nov 18 (verification of 78148's "a whereabouts contradiction gets an irrelevant
## gift refusal"): a case pressed in private that rests on night evidence is about that
## night, whatever it concludes. A "suspicious" case built from an alibi or a vigil used to
## fall through to the gift answer. Checked on MindDialogue.press with hand-made cases.
extends SceneTree
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	for t in ["suspicious", "evil", "lied"]:
		_night_case(t)
	_day_case_still_gift()
	print("Press night case: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _setup():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(13910, 10)
	var w = g.w
	w.day = 2
	var n = w.living_good()[0]
	n.secret = {}
	n.secret_mod = ""
	return [g, n]

func _night_case(ctype: String) -> void:
	var gn = _setup()
	var w = gn[0].w
	var n = gn[1]
	var alibi = {"kind": "alibi", "subject": [n.id], "source": n.id, "day": 1, "phase": C.NIGHT, "home": true, "text": "I stayed home."}
	var vigil = {"kind": "vigil", "subject": [n.id], "source": "player", "day": 1, "phase": C.NIGHT, "text": "You watched them leave."}
	var case = {"kind": "deduction", "conclusion": {"type": ctype, "a": n.id}, "subject": [n.id], "support_cards": [alibi, vigil], "text": "A case"}
	var r: Dictionary = MindDialogue.press(w, n, case)
	_check(str(r.get("dialogue_exchange", {}).get("action", "")) == "challenge_night",
		"a \"%s\" case resting on the first night is answered about that night (%s)" % [ctype, str(r.get("dialogue_exchange", {}))])

func _day_case_still_gift() -> void:
	var gn = _setup()
	var w = gn[0].w
	var n = gn[1]
	var reading = {"kind": "info", "subject": [n.id], "source": w.living_good()[1].id, "role": "seer", "day": 1, "data": {"pair": [n.id, w.living_good()[2].id], "yes": true}, "text": "One of them"}
	var case = {"kind": "deduction", "conclusion": {"type": "suspicious", "a": n.id}, "subject": [n.id], "support_cards": [reading], "text": "A case"}
	var r: Dictionary = MindDialogue.press(w, n, case)
	_check(str(r.get("dialogue_exchange", {}).get("action", "")) == "challenge_gift" and not r.get("lines", []).is_empty(), "a case with no night evidence still goes to the gift answer (%s; Steward Nov 19 E1a: not just 'not the night one')" % str(r.get("dialogue_exchange", {})))
