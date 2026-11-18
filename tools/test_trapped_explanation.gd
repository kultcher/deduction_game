## "Fine, I was out", then why (Michael, Nov 18): a good NPC whose home alibi a case catches
## gives its honest reason if open enough (the day's disclosure tier, 2 or more): its secret
## errand, or the gift that took it out. Tier 1, evil, or no honest reason: the line stands
## alone. Setup as test_workshop_presentation's _trapped_group_response.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const Presentation = preload("res://game/workshop_presentation.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const LiveCanvas = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_helper()
	_presented(true)
	_presented(false)
	_walking_gift()
	print("Trapped explanation: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9503, 10)
	return g

func _out(g, n) -> String:
	var block: String = "market" if n.home_block != "market" else "docks"
	n.history[g.w.time_key(1, 3)] = "night:" + block
	return block

func _helper() -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good().filter(func(x): return not preload("res://sim/content.gd").ROLES[x.role].get("night_walk", false))[0]
	_out(g, n)
	n.secret = {"kind": "errand", "text": "tends a sick aunt", "me": "was tending my sick aunt"}
	var r: Dictionary = MindDialogue.trapped_explanation(w, n, 1)
	_check(r.get("lines", []).size() == 1 and r.get("facts", []).any(func(f): return f.get("kind", "") == "secret"), "a good NPC with a secret errand explains the night (%s)" % str(r.get("lines", [])))
	# Asked about the night again (the confession roll aside): the owned account stands, not
	# the home alibi it replaced (Codex on #261).
	n.dialogue_memory["night_accounts"] = {"1": {"kind": "alibi", "home": true, "source": n.id, "subject": [n.id], "day": 1, "phase": 3}}
	n.secret = {"kind": "errand", "text": "tends a sick aunt", "me": "was tending my sick aunt"}
	MindDialogue.trapped_explanation(w, n, 1)
	n.secret = {}
	var again: Dictionary = MindDialogue.answer_night(w, n, 1)
	var home_again: bool = again.get("facts", []).any(func(f): return f.get("kind", "") == "alibi" and bool(f.get("home", false)))
	var out_again: bool = again.get("facts", []).any(func(f): return f.get("kind", "") == "alibi" and not bool(f.get("home", true)))
	_check(out_again and not home_again, "asked again after explaining, it keeps to being out, not home (%s)" % str(again.get("facts", []).map(func(f): return f.get("text", ""))))
	n.secret = {}
	n.dialogue_memory["night_accounts"] = {}
	_check(MindDialogue.trapped_explanation(w, n, 1).is_empty(), "with no honest reason to give, nothing follows")
	var e = w.evil_team()[0]
	_out(g, e)
	_check(MindDialogue.trapped_explanation(w, e, 1).is_empty(), "an evil NPC never explains its night")

func _presented(open: bool) -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good().filter(func(x): return not preload("res://sim/content.gd").ROLES[x.role].get("night_walk", false))[0]
	n.secret = {"kind": "errand", "text": "tends a sick aunt", "me": "was tending my sick aunt"}
	n.secret_mod = ""
	n.traits.privacy = 0.0 if open else 1.0
	n.traits.composure = 0.0 if open else 1.0
	n.trust = 1.0 if open else 0.0
	n.pressure = 1.0 if open else 0.0
	var block: String = _out(g, n)
	var others = w.npcs.filter(func(p): return p != n)
	var alibi = g.add_card({"kind": "alibi", "subject": [n.id], "source": n.id, "day": 1, "phase": 3, "home": true, "text": "I stayed home."})
	var sight = g.add_card({"kind": "sighting", "subject": [n.id], "source": "player", "day": 1, "phase": 3, "block": block, "text": "Seen away from home."})
	var canvas = Canvas.new(LiveCanvas.view(g))
	var root: String = canvas.add_premise(n.id, "evil", Vector2.ZERO)
	var a: String = "e:" + Evidence.normalize_card(g.board[alibi - 1]).id
	var b: String = "e:" + Evidence.normalize_card(g.board[sight - 1]).id
	canvas.connect_cards(a, b)
	canvas.connect_cards(canvas.selected, root)
	var number: int = LiveCanvas.file(g, canvas.compile(root))
	if number <= 0:
		_check(false, "the case can be filed")
		return
	var tier: int = Mind._target_tier(w, n)
	var result: Dictionary = Presentation.present(g, n, g.board[number - 1], [others[0].id], "accuse", "private", true)
	var lines: Array = result.get("lines", [])
	var first: String = str(lines[0].get("statement", "")) if not lines.is_empty() else ""
	_check(first.begins_with("Fine, I was out."), "the case catches the home alibi: 'Fine, I was out' (%s)" % first)
	if open:
		_check(tier >= 2 and lines.size() == 2 and result.get("facts", []).any(func(f): return f.get("kind", "") == "secret"), "an open NPC (tier %d) then explains the night (%d lines)" % [tier, lines.size()])
	else:
		_check(tier == 1 and lines.size() == 1, "a closed one (tier %d) leaves it at that (%d lines)" % [tier, lines.size()])


## Codex on #261: a good Night Watch, Warden or Lamplighter with no secret, out on its gift,
## explains the night too (the gift answer, as a direct press would give it).
func _walking_gift() -> void:
	var g = _game()
	var w = g.w
	var C = preload("res://sim/content.gd")
	var n = w.living_good()[0]
	n.role = "nightwatch"
	n.claimed_role = ""
	n.claim_public = false
	n.max_tier = 0
	n.secret = {}
	n.secret_mod = ""
	_out(g, n)
	var r: Dictionary = MindDialogue.trapped_explanation(w, n, 1)
	_check(not r.get("lines", []).is_empty(), "a good Night Watch out on its gift explains the night (%s)" % str(r.get("lines", []).map(func(l): return l.get("statement", "") if l is Dictionary else str(l))))
