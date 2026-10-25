extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Protection = preload("res://workshop/live_protection.gd")
var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _init() -> void:
	var g = Game.new()
	g.new_case(692, 10)
	g.w.dlog.detailed = false
	g.w.day = 2
	var goods: Array = g.w.living_good()
	var guard = goods[0]
	var resident = goods[1]
	var observer = goods[2]
	var raw = {"kind": "sighting", "source": guard.id, "subject": [guard.id], "block": resident.home_block, "guard_claim": resident.id, "day": 1, "phase": 3, "text": "Guarded this door."}
	var number = g.add_card(raw)
	var filed = g.file_deduction({"type": "evil", "a": resident.id}, [number], {}, 0, true)
	var prepared = Live.Assess.prepare(g.workshop_snapshot([filed], observer.id))
	var id: String = Live.Evidence.normalize_card(raw).id
	var card = Solver.card_by_id(prepared.view, id)
	check(prepared.ready and card.kind == "report" and card.role == "warden" and card.data.target == resident.id, "guard statement becomes a structured Warden receipt")
	check(card.block == resident.home_block and prepared.view.get("live_activity", false), "public door and night reach the movement model")
	var quiet = {"id": "quiet", "kind": "quiet", "night": 1, "ward": ""}
	var support = Protection.assess(prepared.view, [card, quiet], prepared.listener)
	check(support.has(guard.id) and support[guard.id].weight > 0 and support[guard.id].weight < 0.1, "matching quiet night gives bounded protection support")
	quiet.night = 2
	check(Protection.assess(prepared.view, [card, quiet], prepared.listener).is_empty(), "a guard at another night's door is not credited for this quiet night")
	var view: Dictionary = prepared.view.duplicate(true)
	view.timeline = Live.Assess.History.from_events([{"kind": "demon_death", "subjects": [resident.id], "at": {"day": 1, "phase": "night"}}])
	var table: PackedByteArray = Solver.report_table(view, card)
	check(table.count(1) == 0, "a healthy accepted guard cannot protect the publicly killed door on that night")
	check(not Eval.evaluate(view, prepared.case, prepared.listener).impossible, "false or impaired protection remains possible rather than voiding the case")
	var malformed = raw.duplicate(true)
	malformed.guard_claim = guard.id
	check(Live.Assess.activity_card(Live.Evidence.normalize_card(malformed), g.workshop_snapshot([], observer.id)).is_empty(), "a self-guard is rejected")
	guard.warden_log = {"1": resident.id}
	var own = g.workshop_snapshot([], guard.id)
	check(own.private_evidence.has(id), "own guard memory shares the public statement's exact identity")
	var other = g.workshop_snapshot([], observer.id)
	check(not other.private_evidence.has(id), "another person's private guard target is not exported")
	print("Warden mechanics: %d checks; failures: %d" % [checks, fails])
	quit(1 if fails else 0)
