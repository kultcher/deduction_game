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
	# Names nested in a reading's data count too (a Psychologist's statements; Codex on #159).
	var named_deep: Dictionary = {}
	Live._collect_people(g, {"statements": [{"speaker": p[5].id, "subject": [p[6].id]}]}, named_deep)
	check(named_deep.has(p[5].id) and named_deep.has(p[6].id), "people named inside nested statements are found (%s)" % str(named_deep.keys()))
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
	var why: Dictionary = preload("res://game/workshop_why.gd").test_juror(g, value)
	var why_cards: Array = why.get("cards", why.get("evidence", []))
	check(why.get("ready", false) and str(why.get("text", "")).length() > 0 and Live.juror_case(g, value).case.cards.size() > value.cards.size(), "the \"why\" readout explains the same claim-aware case the badge judges (Codex on #159)")
	check(heard.get("ready", false) and deaf.get("ready", false) and float(heard.lr) > float(deaf.lr), "the claims change the juror's verdict: x%.2f with them, x%.2f without" % [float(heard.get("lr", 0.0)), float(deaf.get("lr", 0.0))])
	# Triage 5.4: a challenge applies. Judged as if it holds, the challenged reading is set aside.
	var dowser: int = g.add_card({"kind": "info", "source": p[5].id, "role": "dowser", "day": 1, "phase": 1,
		"data": {"group": [p[4].id], "count": 0}, "text": "%s dowser day 1: no evil in %s" % [p[5].id, p[4].id]})
	var view2: Dictionary = Live.view(g)
	var m2 = CanvasModel.new(view2)
	m2.contradiction_links = true
	m2.marked_answers = false
	var prem2: String = m2.add_premise(p[3].id, "evil", Vector2(400, 40))
	for number in [reading, dowser]:
		var want: String = g.board[number - 1].text
		for id in m2.nodes:
			if m2.nodes[id].kind == "evidence" and Solver.card_by_id(view2, m2.nodes[id].card).get("text", "") == want:
				m2.connect_cards(id, prem2)
	var both: Dictionary = m2.compile(prem2)
	var seer_id: String = ""
	for id in both.cards:
		if Solver.card_by_id(view2, id).get("role", "") == "seer":
			seer_id = id
	var challenged: Dictionary = both.duplicate(true)
	challenged["reading_challenges"] = {seer_id: {"mode": "impaired", "supports": []}}
	var plain_r: Dictionary = Live.test_juror(g, both, false)
	var chal_r: Dictionary = Live.test_juror(g, challenged, false)
	check(seer_id != "" and chal_r.get("set_aside", []) == [seer_id], "a challenged reading is set aside (%s)" % str(chal_r.get("set_aside", [])))
	check(float(chal_r.get("lr", 0.0)) != float(plain_r.get("lr", 0.0)) and "challenge holds" in str(chal_r.get("reason", "")), "and the verdict changes, saying so (x%.2f against x%.2f; %s)" % [float(chal_r.get("lr", 0.0)), float(plain_r.get("lr", 0.0)), str(chal_r.get("reason", ""))])
	print("Juror claims: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
