extends SceneTree
const Solver = preload("res://workshop/solver.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Protection = preload("res://workshop/live_protection.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Mind = preload("res://sim/mind.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_mechanics()
	_circumstantial()
	_live()
	print("Protection evidence: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", label)

func _view() -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "market" if id == "f" else "square"})
	return {"people": people, "cards": [], "day": 3, "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": {"events": []}, "world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}

func _veteran(night: int = 1) -> Dictionary:
	return {"id": "vet%d" % night, "kind": "report", "source": "a", "role": "veteran", "night": night, "data": {"attacked": night, "block": "market"}, "observed_at": {"day": night, "phase": "night"}}

func _mechanics() -> void:
	var view = _view()
	var world = {"evil": 96, "demon": 5, "marked": 4, "modifier": "marked", "holders": 16}
	var vet = _veteran()
	check(Solver.Roles.fits(view, world, [vet], {}), "Veteran approach matches candidate Demon route")
	world.demon = 6
	var routes: Array = Activity.demon_routes(view.people[6].home, view.people[0].home)
	var detour_weight = 0.0
	for route in routes:
		var approach: String = route.path[-2] if route.path.size() >= 2 else view.people[0].home
		if approach == vet.data.block:
			detour_weight += route.weight
	check(Solver.Roles.fits(view, world, [vet], {}) and detour_weight > 0 and detour_weight <= Activity.DEMON_DETOUR, "Veteran approach permits an otherwise incompatible home only through the small detour allowance")
	world.demon = 5
	check(not Solver.Roles.fits(view, world, [vet, _veteran(2)], {}), "one-use Veteran cannot have two healthy attack reports")
	view.timeline.events = [{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}}]
	check(not Solver.Roles.fits(view, world, [vet], {}), "survived attack conflicts with another Demon kill that night")
	check(Solver.Domain.gift_time(vet), "Veteran night-time report is in scope")
	vet.observed_at.phase = "morning"
	check(not Solver.Domain.gift_time(vet), "Veteran acquisition time must be a night")

func _circumstantial() -> void:
	var view = _view()
	var listener = Ghost.profile(view.people)
	var claim = {"id": "claim", "kind": "claim", "source": "a", "subject": "a", "role": "warden", "data": {}, "observed_at": {"day": 1, "phase": "morning"}}
	var quiet = {"id": "quiet", "kind": "quiet", "source": "player", "subject": "", "role": "", "night": 1, "ward": "", "observed_at": {"day": 1, "phase": "night"}}
	check(Protection.assess(view, [quiet], listener).is_empty(), "quiet night alone identifies no protector")
	var p = Protection.assess(view, [quiet, claim], listener)
	check(p.a.weight > 0 and p.a.weight < 0.06, "quiet night gives bounded credibility-scaled protection support")
	var baseline: float = p.a.weight
	var duplicate = quiet.duplicate(true)
	duplicate.id = "duplicate"
	check(Protection.assess(view, [quiet, duplicate, claim], listener).a.weight == baseline, "one quiet night cannot be counted twice")
	quiet.ward = "b"
	check(Protection.assess(view, [quiet, claim], listener).a.weight < baseline, "known player ward supplies a competing explanation")
	quiet.ward = ""
	var competing = claim.duplicate(true)
	competing.source = "b"
	competing.subject = "b"
	competing.role = "veteran"
	check(Protection.assess(view, [quiet, claim, competing], listener).a.weight < baseline, "competing protection claims share the quiet-night support")
	view.timeline.events = [{"kind": "knell", "subjects": [], "at": {"day": 1}}]
	check(Protection.assess(view, [quiet, claim], listener).a.weight < baseline, "knell weakens credit to an individual protector")
	view.timeline.events = []
	view.cards = [quiet, claim]
	var value = Solver.empty_case()
	value.cards = ["quiet", "claim"]
	value.conclusion = {"type": "good", "target": "a", "at": "Original alignment"}
	var result = Ghost.evaluate(view, value)
	check(result.proposal.effects.a.requested < 0, "quiet night and protection claim reduce suspicion")
	check(result.proposal.claims[0].note.contains("does not establish"), "feedback does not call quiet-night support proof")

func _live() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	var claimant = g.w.npcs[0]
	var listener = g.w.living_good().filter(func(n): return n != claimant)[0]
	listener.info_log = []
	listener.known_claims = {}
	listener.beliefs = []
	listener.ledger = {}
	listener.role = "seer"
	listener.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	listener.suspicion[claimant.id] = 0.5
	listener.npc_trust[claimant.id] = 0.6
	var q = g.add_card({"kind": "quiet", "source": "player", "subject": [], "night": 1, "day": 1, "phase": 3, "ward": "", "text": "No deaths on N1"})
	var c = g.add_card({"kind": "claim", "source": claimant.id, "subject": [claimant.id], "role": "warden", "day": 1, "phase": 0, "text": "I am Warden"})
	var eid = "quiet:1>" + claimant.id
	var effects: Array = []
	Mind._eff(effects, claimant.id, -0.15, "Quiet-night native protection credit")
	Mind.ledger_hear(g.w, listener, eid, effects, 1.0, [claimant.id, -1, "report"], {"kind": "proof"})
	var native: float = listener.suspicion[claimant.id]
	var board = Canvas.new(Live.view(g))
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "good", "target": claimant.id, "at": "Original alignment"}
	for number in [q, c]:
		board.connect_cards("e:" + Live.Evidence.normalize_card(g.board[number - 1]).id, root)
	var value = board.compile(root)
	check(Live.status(g, value).ready, "quiet-night case supports live capability")
	var preview = Ghost.live(Live.snapshot(g, value))
	check(preview.ready and preview.proposal.effects[claimant.id].requested < 0, "quiet-night ghost shows circumstantial exoneration")
	var filed = Live.file(g, value)
	g.set_workshop_effects(true)
	var response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
	check(response.get("workshop", false), "quiet-night case reaches shared presentation")
	check(listener.workshop_state.get("owned", {}).has(eid), "exact native quiet-night effect is owned instead of stacked")
	var before: Dictionary = listener.workshop_state.get("requested", {}).duplicate(true)
	response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
	check(response.get("repeated", false) and listener.workshop_state.get("requested", {}) == before, "quiet-night repeat is stable")
	g.set_workshop_effects(false)
	check(is_equal_approx(listener.suspicion[claimant.id], native), "disabling shared model restores native quiet-night credit")
	var veteran = g.add_card({"kind": "info", "source": claimant.id, "subject": [], "role": "veteran", "day": 1, "phase": 3, "data": {"attacked": 1, "block": "market"}, "text": "Veteran attack report"})
	var fresh = Canvas.new(Live.view(g))
	fresh.nodes[fresh.selected].conclusion.target = claimant.id
	fresh.connect_cards("e:" + Live.Evidence.normalize_card(g.board[veteran - 1]).id, fresh.selected)
	check(Live.status(g, fresh.compile(fresh.selected)).ready, "Veteran live report is supported")
	check(Ghost.live(Live.snapshot(g, fresh.compile(fresh.selected))).ready, "Veteran live report previews")
