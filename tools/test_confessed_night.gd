## A night's errand, once confessed, stays confessed (Quill, Nov 20, seed 701). Asked about
## that night again, in private or at the podium, a good NPC tells the same confession: never
## a refusal or a home lie after owning it. After a confession before the town, the private
## retelling uses the podium's words, with no plea to keep it quiet.
extends SceneTree
const Game = preload("res://game/game.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const MindPodium = preload("res://sim/mind_podium.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_private_after_public()
	_private_after_private()
	_podium_after_public()
	_not_confessed()
	print("Confessed night: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(seed_offset: int = 0):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875 + seed_offset, 10)
	g.w.day = 2
	g.w.night_walkers = []
	return g

## A good NPC with an errand, out on night 1, and as unwilling to confess as it gets.
func _setup(g):
	var n = g.w.living_good()[0]
	n.role = "seer"
	n.claimed_role = ""
	n.claim_public = false
	n.max_tier = 0
	n.secret = {"kind": "errand", "text": "was fetching a tonic for a sick aunt", "me": "was fetching a tonic for my sick aunt"}
	n.secret_mod = ""
	n.secret_known = false
	n.lied_nights = []
	n.trust = 0.0
	n.pressure = 0.0
	n.traits["privacy"] = 1.0
	n.history[g.w.time_key(1, C.NIGHT)] = "night:market"
	n.dialogue_memory["night_accounts"] = {}
	return n

func _confessed(n, public: bool) -> void:
	n.secret_known = true
	n.dialogue_memory["night_accounts"] = {"1": {"kind": "secret", "subject": [n.id], "owner": n.id, "source": n.id, "block": "market",
		"day": 1, "phase": C.NIGHT, "secret_kind": "errand", "public": public}}

func _kinds(facts: Array) -> Array:
	return facts.map(func(f): return str(f.get("kind", "")))

func _text(res: Dictionary) -> String:
	return " ".join(res.get("lines", []).map(func(l): return str(l.get("text", l)) if l is Dictionary else str(l)))

func _private_after_public() -> void:
	for i in 10:
		var g = _game(i)
		var n = _setup(g)
		_confessed(n, true)
		var res: Dictionary = MindDialogue.answer_night(g.w, n, 1)
		var kinds: Array = _kinds(res["facts"])
		if not ("secret" in kinds) or "refusal" in kinds or 1 in n.lied_nights:
			_check(false, "after a confession before the town, asked in private, tells it again (try %d: %s)" % [i, kinds])
			return
		if "keep it quiet" in _text(res):
			_check(false, "no plea to keep quiet what the town already heard (try %d)" % i)
			return
	_check(true, "after a confession before the town, asked in private, tells it again, never a refusal or a lie")
	_check(true, "no plea to keep quiet what the town already heard")

func _private_after_private() -> void:
	var g = _game()
	var n = _setup(g)
	_confessed(n, false)
	var res: Dictionary = MindDialogue.answer_night(g.w, n, 1)
	var kinds: Array = _kinds(res["facts"])
	_check("secret" in kinds and not ("refusal" in kinds), "confessed to you before, asked again, tells it again")

func _podium_after_public() -> void:
	for i in 10:
		var g = _game(i)
		var n = _setup(g)
		_confessed(n, true)
		var res: Dictionary = MindPodium.press_night(g.w, n, 1, true)
		if str(res.get("outcome", "")) != "confess" or 1 in n.lied_nights:
			_check(false, "pressed again at the podium, confesses again (try %d: %s)" % [i, res.get("outcome", "")])
			return
	_check(true, "pressed again at the podium, confesses again, never a refusal or a lie")

func _not_confessed() -> void:
	# Control: with nothing confessed, this unwilling NPC hides the night (the draw still decides).
	var hid: int = 0
	for s in 6:
		var g = _game(s)
		var n = _setup(g)
		var kinds: Array = _kinds(MindDialogue.answer_night(g.w, n, 1)["facts"])
		if not ("secret" in kinds):
			hid += 1
	_check(hid > 0, "with nothing confessed, an unwilling NPC can still keep the errand (%d of 6 hid it)" % hid)
