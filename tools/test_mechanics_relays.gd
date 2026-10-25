extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Solver = preload("res://workshop/solver.gd")
const Eval = preload("res://workshop/case_eval.gd")
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
	var goods: Array = g.w.living_good()
	var listener = goods[0]
	var original = goods[1]
	var teller = goods[2]
	listener.info_log = []
	listener.known_claims = {}
	listener.ledger = {}
	listener.beliefs = []
	listener.role = "surveyor"
	var entry = {"role": "surveyor", "day": 0, "phase": 3, "data": {"count": 2}, "text": "An unnamed Surveyor counted two.", "shared": false}
	Mind.apply_info(g.w, listener, original, entry, 0.3, teller.id, true)
	var plan = Shared.prepare(g.workshop_snapshot([], listener.id), {}, listener.ledger)
	var cards: Array = plan.prepared.view.cards
	check(plan.ready and cards.size() == 1 and cards[0].source == teller.id and cards[0].get("testimony_only", false), "unnamed reading is an account by the known teller")
	check(plan.prepared.listener.reading_reliability[cards[0].id] <= Assess.C.RELAY_WEIGHT and plan.prepared.listener.reading_reliability[cards[0].id] > 0.0, "account keeps the existing reduced relay weight")
	var result = Eval.evaluate(plan.prepared.view, plan.prepared.case, plan.prepared.listener)
	check(not result.impossible, "a teller recounting the listener's gift does not claim that unique gift")
	var table: PackedByteArray = Solver.valid_table(plan.prepared.view, cards[0])
	var worlds: Array = Solver.universe(plan.prepared.view)
	var ti: int = Solver.person_index(plan.prepared.view, teller.id)
	var correct = true
	for i in range(worlds.size()):
		correct = correct and (table[i] != 0) == ((worlds[i].evil & (1 << ti)) == 0)
	check(correct, "testimony depends on teller alignment, not a guessed original or teller impairment")
	var before: Dictionary = plan.prepared.duplicate(true)
	original.role = "demon"
	original.alignment = "evil"
	plan = Shared.prepare(g.workshop_snapshot([], listener.id), {}, listener.ledger)
	check(plan.prepared == before, "changing hidden original role/alignment cannot alter the prepared assessment")
	var medium = Shared.Evidence.normalize_card({"kind": "info", "role": "medium", "source": teller.id, "day": 2, "phase": 3, "subject": [], "data": {"dead": original.id, "item": {"type": "reading", "entry": entry}}, "text": "Unverified Medium account"})
	var snapshot = g.workshop_snapshot([], listener.id)
	var weak: Dictionary = Assess.testimony_card(medium, snapshot)
	check(weak.get("testimony_only", false) and weak.source == teller.id and not weak.has("relay_source"), "unverified Medium original does not manufacture a verified transmission")
	medium.content.data.item.entry.erase("day")
	var context = Assess.testimony_card(medium, snapshot)
	check(context.kind == "context" and context.context_note != "", "missing original observation time is stated context, not a fabricated dated fact")
	medium.content.data.item.entry = {"role": "psychologist", "day": 1, "phase": 3, "data": {"subject": original.id, "trusts": listener.id, "suspects": teller.id}}
	check(Assess.testimony_card(medium, snapshot).kind == "context", "a relayed Psychologist opinion remains context")
	print("Relay mechanics: %d checks; failures: %d" % [checks, fails])
	quit(1 if fails else 0)
