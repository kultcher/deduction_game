## An unnamed night sighting, or daytime meeting (Michael, Nov 28: passing information on hides its source). When
## an NPC tells the player "someone saw X on the Docks last night" without naming the witness,
## the card is the teller's account:
## - the fact keeps who told it, never who saw it;
## - the Workshop weighs it as the teller's testimony at relay weight, without placing the
##   teller there;
## - the board draws it as "someone told you", not as the player's own sighting;
## - a case on it is ready (how it compares with a named witness's is Lantern's to settle).
##   godot --headless --path . --script res://tools/test_anonymous_sighting.gd
extends SceneTree
const Game = preload("res://game/game.gd")
const GameBoard = preload("res://game/game_board.gd")
const CardModel = preload("res://game/card_model.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const C = preload("res://sim/content.gd")
var checks := 0
var fails := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: " + label)

func _init() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(1, 10)
	g.w.day = 2
	var goods: Array = g.w.living_good()
	var subject = goods[0]
	var teller = goods[1]
	var witness = goods[2]
	var block: String = "docks" if subject.home_block != "docks" else "market"
	var anon_n: int = GameBoard.add_card(g, {"kind": "sighting", "subject": [subject.id], "block": block, "source": "", "via": teller.id, "anonymous": true,
		"day": 1, "phase": C.NIGHT, "text": "%s says someone saw %s on the %s on night 1." % [teller.name, subject.name, block]})
	var anon: Dictionary = g.board[anon_n - 1]
	var norm: Dictionary = Evidence.normalize_card(anon)
	check(str(norm.content.get("source", "x")) == "" and norm.content.get("anonymous", false) and str(norm.content.get("teller", "")) == teller.id,
		"the fact keeps the teller and no witness (%s)" % str(norm.content))
	# The board: someone told you, not your own sighting.
	var marks: Array = CardModel.place_markers(anon)
	check(not marks.is_empty() and marks.all(func(m): return str(m.get("mark", "")) == "hollow"), "the board draws it as told to you (%s)" % str(marks.map(func(m): return m.get("mark", ""))))
	# The Workshop: the teller's testimony, at relay weight.
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var p_anon: String = model.add_premise(subject.id, "evil", Vector2(400, 40))
	_link(model, view, p_anon, anon.text)
	var value_anon: Dictionary = model.compile(p_anon)
	var r_anon: Dictionary = Live.test_juror(g, value_anon)
	check(r_anon.get("ready", false), "a case on the unnamed sighting is ready (%s)" % str(r_anon.get("issues", [])))
	var told: Dictionary = {}
	for e in Live.view(g).get("cards", []):
		if str(e.get("text", "")) == anon.text:
			told = e
	check(not told.is_empty() and str(told.get("source", "")) == teller.id and told.get("testimony_only", false), "the Workshop card is the teller's testimony (%s)" % str({"source": told.get("source", ""), "testimony_only": told.get("testimony_only", false)}))
	check(not told.get("private_relay", false) and is_equal_approx(float(told.get("hearing_weight", 1.0)), C.RELAY_WEIGHT), "told at the meeting, it's heard at relay weight, not as a private relay (%s)" % str(told.get("hearing_weight", "none")))
	# Passed on in private (hearing: "private"): the ledger's private hearsay weight stands,
	# so the card is marked a private relay (Lantern's listener skips its relay discount).
	# A different block from the meeting's sighting: the same person, place and night would be
	# one observation, merged with it.
	var block2: String = "hill" if block != "hill" and subject.home_block != "hill" else "square"
	var priv_n: int = GameBoard.add_card(g, {"kind": "sighting", "subject": [subject.id], "block": block2, "source": "", "via": teller.id, "anonymous": true, "hearing": "private",
		"day": 1, "phase": C.NIGHT, "text": "%s tells you privately someone saw %s on the %s on night 1." % [teller.name, subject.name, block2]})
	var priv_read_n: int = GameBoard.add_card(g, {"kind": "info", "role": "seer", "source": witness.id, "via": teller.id, "anonymous": true, "hearing": "private",
		"day": 1, "phase": C.NIGHT, "data": {"pair": [subject.id, witness.id], "yes": true}, "text": "%s tells you privately that someone's Seer saw the Demon in %s or %s." % [teller.name, subject.name, witness.name]})
	var pv: Dictionary = Live.view(g)
	var p_sight: Dictionary = {}
	var p_read: Dictionary = {}
	for e in pv.get("cards", []):
		if str(e.get("text", "")) == g.board[priv_n - 1].text:
			p_sight = e
		if str(e.get("text", "")) == g.board[priv_read_n - 1].text:
			p_read = e
	check(p_sight.get("private_relay", false) and not p_sight.has("hearing_weight"), "a sighting passed on in private is a private relay, with no relay weight of its own (%s)" % str(p_sight.keys()))
	check(p_read.get("private_relay", false) and str(p_read.get("source", "")) == teller.id, "and so is a reading passed on in private, told by the teller (%s)" % str({"source": p_read.get("source", ""), "private_relay": p_read.get("private_relay", false)}))
	# A daytime meeting passed on unnamed ("X told me they saw A and B talking at the well";
	# Beadle's "ask about"): the same treatment.
	var other = goods[3]
	var convo_n: int = GameBoard.add_card(g, {"kind": "conversation", "subject": [subject.id, other.id], "block": block, "loc": "", "source": witness.id, "via": teller.id, "anonymous": true,
		"day": 1, "phase": C.AFTERNOON, "text": "%s says someone saw %s and %s talking on the %s on day 1." % [teller.name, subject.name, other.name, block]})
	var convo: Dictionary = g.board[convo_n - 1]
	var cnorm: Dictionary = Evidence.normalize_card(convo)
	check(str(cnorm.content.get("source", "x")) == "" and str(cnorm.content.get("teller", "")) == teller.id, "an unnamed meeting keeps the teller and no witness (%s)" % str(cnorm.content))
	check(CardModel.place_markers(convo).all(func(m): return str(m.get("mark", "")) == "hollow"), "and is drawn as told to you, not as a meeting you saw")
	var c_card: Dictionary = {}
	for e in Live.view(g).get("cards", []):
		if str(e.get("text", "")) == convo.text:
			c_card = e
	check(not c_card.is_empty() and str(c_card.get("source", "")) == teller.id and c_card.get("testimony_only", false), "the Workshop card is the teller's testimony (%s)" % str({"source": c_card.get("source", ""), "testimony_only": c_card.get("testimony_only", false)}))
	# The same sighting from a named witness, on a fresh deal, counts for more.
	var g2 = Game.new()
	g2.log_dir = "user://test_logs"
	g2.new_case(1, 10)
	g2.w.day = 2
	var named_n: int = GameBoard.add_card(g2, {"kind": "sighting", "subject": [subject.id], "block": block, "source": witness.id,
		"day": 1, "phase": C.NIGHT, "text": "Night 1: %s saw %s on the %s." % [witness.name, subject.name, block]})
	var view2: Dictionary = Live.view(g2)
	var model2 = CanvasModel.new(view2)
	model2.contradiction_links = true
	model2.marked_answers = false
	var p_named: String = model2.add_premise(subject.id, "evil", Vector2(400, 40))
	_link(model2, view2, p_named, g2.board[named_n - 1].text)
	var r_named: Dictionary = Live.test_juror(g2, model2.compile(p_named))
	print("unnamed x%.3f, named x%.3f" % [float(r_anon.get("lr", 0.0)), float(r_named.get("lr", 0.0))])
	# How the two compare is Lantern's to settle (asked Nov 28): a named witness's sighting also
	# places the witness out that night, which weakens it, and an unnamed one places no one. This
	# only checks both are weighed.
	check(r_named.get("ready", false) and float(r_anon.get("lr", 0.0)) > 0.0 and float(r_named.get("lr", 0.0)) > 0.0, "both the named and the unnamed sighting are weighed (x%.3f, x%.3f)" % [float(r_anon.get("lr", 0.0)), float(r_named.get("lr", 0.0))])
	print("Anonymous sighting: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _link(model, view: Dictionary, premise: String, text: String) -> void:
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence":
			for c in view.cards:
				if c.id == nd.card and str(c.get("text", "")) == text:
					model.connect_cards(id, premise)
