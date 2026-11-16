## The test juror hears the public gift claims of the people a case's cards name (triage
## 5.5, playtests 44542 and 97626: a Registrar reading alone was x1.3 because the juror
## didn't know its subject had claimed Dowser). Private claims stay out.
extends SceneTree

const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Caches = preload("res://workshop/caches.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	LiveActivity.cache.clear()
	Caches.clear_all()
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
	g.w.day = 2
	var p: Array = g.w.npcs
	var reading: int = g.add_card({"kind": "info", "source": p[2].id, "role": "seer", "day": 1, "phase": 3,
		"data": {"pair": [p[3].id, p[4].id], "yes": true}, "text": "%s seer day 1: one of %s and %s is evil" % [p[2].id, p[3].id, p[4].id]})
	var was: String = g.state
	g.state = "meeting"  # said at a meeting: a public disclosure
	var public_claim: int = g.add_card({"kind": "claim", "subject": [p[3].id], "source": p[3].id, "role": "dowser", "day": 1, "phase": 3, "text": "%s claims to be the Dowser." % p[3].name})
	g.state = was
	var private_claim: int = g.add_card({"kind": "claim", "subject": [p[4].id], "source": p[4].id, "role": "clerk", "day": 1, "phase": 1, "private": true, "text": "%s told you privately they are the Clerk." % p[4].name})
	g.state = "meeting"
	var other_claim: int = g.add_card({"kind": "claim", "subject": [p[5].id], "source": p[5].id, "role": "warden", "day": 1, "phase": 3,
		"text": "%s claims to be the Warden." % p[5].name})
	g.state = was
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(p[3].id, "evil", Vector2(400, 40))
	var text: String = g.board[reading - 1].text
	var node: String = ""
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and Solver.card_by_id(view, nd.card).get("text", "") == text:
			node = id
	model.connect_cards(node, premise)
	var value: Dictionary = model.compile(premise)
	check(value.get("cards", []).size() == 1, "(fixture) the case holds the one reading")
	var heard_claims: Array = Live.public_claims_for(g, value)
	check(public_claim in heard_claims, "the public claim of someone the reading names is heard (%s)" % str(heard_claims))
	check(private_claim not in heard_claims, "a private claim isn't")
	check(other_claim not in heard_claims, "nor the claim of someone the case doesn't name")
	var r: Dictionary = Live.test_juror(g, value)
	check(r.get("ready", false), "the juror still runs (%s)" % str(r.get("issues", [])))
	# And it weighs them: the reading's teller and its subject both publicly claim the Seer,
	# so one of them is lying, and the reading itself names the subject.
	g.state = "meeting"
	g.add_card({"kind": "claim", "subject": [p[2].id], "source": p[2].id, "role": "seer", "day": 1, "phase": 3, "text": "%s claims to be the Seer." % p[2].name})
	g.add_card({"kind": "claim", "subject": [p[3].id], "source": p[3].id, "role": "seer", "day": 2, "phase": 3, "text": "%s claims to be the Seer too." % p[3].name})
	g.state = was
	var heard: Dictionary = Live.test_juror(g, value)
	var deaf: Dictionary = Live.test_juror(g, value, false)
	check(heard.get("ready", false) and deaf.get("ready", false) and float(heard.lr) > float(deaf.lr), "the claims change the juror's verdict: x%.2f with them, x%.2f without" % [float(heard.get("lr", 0.0)), float(deaf.get("lr", 0.0))])
	print("Juror claims: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
