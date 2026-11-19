## Excuses for a caught "I was home" (Michael, Nov 19, Quill's form; Beadle's caught-out ladder
## supplies the excuse facts). While an excuse stands, that night's own "home" alibi reads as a
## good person's at Workshop.EXCUSED_OWN_ALIBI_OUT instead of GOOD_OWN_ALIBI_OUT, so the lie
## softens a little; a contradicted excuse counts as a second caught lie at
## Workshop.CONTRADICTED_EXCUSE_WEIGHT of the first (SourceDoubt). And a person's own "I was
## out" is read as what it says: before, it lost its `home` flag on the way into the judge's
## view and read as another "I was home".
##   godot --headless --path . --script res://tools/test_caught_lie_softening.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_views()
	_softer()
	_contradicted_doubt()
	print("Caught-lie softening: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _game() -> Dictionary:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(5, 7)
	g.w.day = 3
	var x = g.w.living_good()[0]
	var other: String = "market" if x.home_block != "market" else "docks"
	return {"g": g, "x": x, "other": other}


func _card(view: Dictionary, text: String) -> Dictionary:
	for c in view.cards:
		if str(c.get("text", "")) == text:
			return c
	return {}


func _views() -> void:
	var f: Dictionary = _game()
	var g = f.g
	var x = f.x
	g.add_card({"kind": "alibi", "subject": [x.id], "source": x.id, "day": 1, "phase": C.NIGHT, "home": true, "block": x.home_block, "text": "HOME1"})
	g.add_card({"kind": "alibi", "subject": [x.id], "source": x.id, "day": 2, "phase": C.NIGHT, "home": true, "block": x.home_block, "text": "HOME2"})
	g.add_card({"kind": "alibi", "subject": [x.id], "source": x.id, "day": 2, "phase": C.NIGHT, "home": false, "block": f.other, "text": "OUT2"})
	g.add_card({"kind": "alibi", "subject": [x.id], "source": x.id, "day": 1, "phase": C.NIGHT, "home": false, "block": "", "excuse": "admit", "excuses_night": 1, "text": "ADMIT1"})
	var view: Dictionary = Live.view(g)
	var out2: Dictionary = _card(view, "OUT2")
	check(str(out2.get("kind", "")) == "sighting" and out2.get("admitted", false) and str(out2.get("block", "")) == f.other,
		"a person's own \"I was out\" reaches the judge as their own sighting of themselves out, not a home claim (%s)" % str(out2.get("kind", "")))
	check(is_equal_approx(float(_card(view, "HOME1").get("out_rate", -1.0)), Tuning.Workshop.EXCUSED_OWN_ALIBI_OUT),
		"an excuse for night 1 softens that night's own \"home\" alibi (out-rate %s)" % str(_card(view, "HOME1").get("out_rate", "none")))
	check(not _card(view, "HOME2").has("out_rate"), "a night with no excuse keeps the ordinary out-rate")
	# A claimed watch with no watch report, once the night is past: contradicted.
	var h: Dictionary = _game()
	var g2 = h.g
	var y = h.x
	g2.add_card({"kind": "alibi", "subject": [y.id], "source": y.id, "day": 1, "phase": C.NIGHT, "home": true, "block": y.home_block, "text": "HOMEY"})
	g2.add_card({"kind": "alibi", "subject": [y.id], "source": y.id, "day": 1, "phase": C.NIGHT, "home": false, "block": h.other, "watch_claim": true,
		"excuse": "duty", "excuses_night": 1, "duty_role": "nightwatch", "text": "WATCHY"})
	var view2: Dictionary = Live.view(g2)
	check(_card(view2, "HOMEY").get("excuse_contradicted", false) and not _card(view2, "HOMEY").has("out_rate"),
		"a claimed watch with no watch report, once the night is past, contradicts the excuse")


## The case "X is evil" on the player's sighting of X out against X's "I was home", with and
## without X's "Fine, I was out" excuse: softer with it.
func _softer() -> void:
	var f: Dictionary = _game()
	var g = f.g
	var x = f.x
	var home: int = g.add_card({"kind": "alibi", "subject": [x.id], "source": x.id, "day": 1, "phase": C.NIGHT, "home": true, "block": x.home_block, "text": "HOMEX"})
	var seen: int = g.add_card({"kind": "sighting", "subject": [x.id], "source": "player", "day": 1, "phase": C.NIGHT, "block": f.other, "text": "SEENX"})
	var plain: Dictionary = Live.shape_reading(g, _case(g, x.id, ["HOMEX", "SEENX"]))
	# A case is judged on its own cards, so the excuse counts where the case cites it (a
	# listener's own view holds every card it has heard).
	g.add_card({"kind": "alibi", "subject": [x.id], "source": x.id, "day": 1, "phase": C.NIGHT, "home": false, "block": "", "excuse": "admit", "excuses_night": 1, "text": "ADMITX"})
	var excused: Dictionary = Live.shape_reading(g, _case(g, x.id, ["HOMEX", "SEENX", "ADMITX"]))
	check(plain.get("ready", false) and excused.get("ready", false) and float(excused.lr) < float(plain.lr),
		"with \"Fine, I was out\" standing, the caught lie weighs less against them (x%.3f against x%.3f)" % [float(excused.get("lr", 0.0)), float(plain.get("lr", 0.0))])


func _case(g, target: String, texts: Array) -> Dictionary:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var p: String = model.add_premise(target, "evil", Vector2(0, 0))
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and str(Solver.card_by_id(view, nd.card).get("text", "")) in texts:
			model.connect_cards(id, p)
	return model.compile(p)


## SourceDoubt: a contradicted excuse adds a second caught lie at half weight.
func _contradicted_doubt() -> void:
	var night: float = Tuning.Workshop.DOUBT_CAUGHT_ALIBI_NIGHT
	var general: float = Tuning.Workshop.DOUBT_CAUGHT_ALIBI_GENERAL
	var w2: float = Tuning.Workshop.CONTRADICTED_EXCUSE_WEIGHT
	var plain: Dictionary = _doubt(false)
	var twice: Dictionary = _doubt(true)
	check(is_equal_approx(float(plain.get("x:1", 0.0)), night), "a caught lie alone: the night's doubt as before (%.3f)" % float(plain.get("x:1", 0.0)))
	check(is_equal_approx(float(twice.get("x:1", 0.0)), 1.0 - (1.0 - night) * (1.0 - w2 * night)) and is_equal_approx(float(twice.get("x:*", 0.0)), 1.0 - (1.0 - general) * (1.0 - w2 * general)),
		"its excuse contradicted: a second caught lie at half weight (%.3f that night, %.3f in general)" % [float(twice.get("x:1", 0.0)), float(twice.get("x:*", 0.0))])


func _doubt(contradicted: bool) -> Dictionary:
	var people: Array = []
	for id in ["l", "x", "a", "b", "c", "d", "e"]:
		people.append({"id": id, "name": id, "home": "square"})
	var home: Dictionary = {"id": "home", "kind": "alibi", "source": "x", "subject": "x", "subjects": ["x"], "night": 1, "block": "square", "observed_at": {"day": 1, "phase": "night"}, "data": {}}
	if contradicted:
		home["excuse_contradicted"] = true
	var cards: Array = [
		{"id": "seen", "kind": "sighting", "source": "l", "subject": "x", "subjects": ["x"], "night": 1, "block": "docks", "observed_at": {"day": 1, "phase": "night"}},
		home]
	var plan: Dictionary = {"ready": true, "input": {"public_events": []}, "owned": {}, "owners": {},
		"prepared": {"view": {"people": people, "cards": cards, "evil_count": 2},
			"listener": {"id": "l", "knowledge": {"self": "l"}, "suspicion": {"x": 0.3}, "npc_trust": {}}}}
	return SourceDoubt.derive(plan).get("pre_eval", {})
