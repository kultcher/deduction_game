## Sheltering gifts (hint package 'shelter'): Warden and Veteran (the Martyr is with the dead).
## Merged from: test_mechanics_warden, test_roster, test_warden_credit, test_workshop_protection.
extends SceneTree

const Game = preload("res://game/game.gd")
const World = preload("res://sim/world.gd")
const C = preload("res://sim/content.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Mind = preload("res://sim/mind.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
const Protection = preload("res://workshop/live_protection.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Caches = preload("res://workshop/caches.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_roster()
	_run_workshop_protection()
	_run_mechanics_warden()
	_run_warden_credit()
	_run_warden_night0()
	print("Roles: shelter: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## One shared check helper (the merged suites used both names).
func check(ok: bool, label: String) -> void:
	_count(ok, label)


func _check(ok: bool, label: String) -> void:
	_count(ok, label)


func _count(ok: bool, label: String) -> void:
	checks += 1
	_checks += 1
	if not ok:
		fails += 1
		failures += 1
		_fails += 1
		printerr("FAIL: " + label)


# ---------------------------------------------------------------- from test_roster

func _run_roster() -> void:
	_test_veteran()


# ---------------------------------------------------------------- from test_workshop_protection

func _run_workshop_protection() -> void:
	_mechanics()
	_circumstantial()
	_live()


# ---------------------------------------------------------------- from test_mechanics_warden

func _run_mechanics_warden() -> void:
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
	var filed = g.file_deduction({"type": "evil", "a": resident.id}, [number], true)
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


# ---------------------------------------------------------------- from test_warden_credit

func _run_warden_credit() -> void:
	var g = warden_credit__game()
	_check(g != null, "a fixture seed has a good Warden")
	if g == null:
		return
	var w = g.w
	var warden = w.npc_with_role("warden")
	var target = w.living_good().filter(func(m): return m != warden)[0]
	w.day = 1
	warden.warden_log["1"] = target.id
	warden.npc_trust[target.id] = 0.7
	Caches.clear_all()
	var before: Dictionary = _own_effects(g, warden)
	var trust_before: float = warden.npc_trust[target.id]
	target.suspicion[warden.id] = 0.1  # the protectee believes the Warden (tell_save warms only then)
	var protectee_trust: float = target.npc_trust.get(warden.id, 0.5)
	w._warden_credit(warden, target.id)
	_check(warden.warden_saves.has("1") and is_equal_approx(warden.warden_saves["1"].belief, 1.0), "a quiet night with no other known protector is taken as the Warden's save")
	_check(warden.npc_trust[target.id] > trust_before, "the Warden warms to the person the Demon went for")
	_check(target.known_claims.has(warden.id) and target.npc_trust.get(warden.id, 0.5) > protectee_trust, "a trusted protectee is told, and warms to the Warden")
	_check(target.ledger.keys().any(func(k): return str(k).begins_with("heard:")), "the protectee holds the guard statement as testimony")
	Caches.clear_all()
	var after: Dictionary = _own_effects(g, warden)
	if before.has(target.id) and after.has(target.id):
		print("  Warden's P(target evil): %.3f -> %.3f" % [before[target.id].posterior, after[target.id].posterior])
		_check(after[target.id].posterior < before[target.id].posterior, "in the Warden's own view the save makes the protectee likelier good")
	var fact: Dictionary = preload("res://sim/content.gd").role_def("warden").guard_fact(w, warden, 1, target.id, func(b): return b)
	_check(fact.get("save_claim", false) and "turned it away" in fact.text, "the guard statement carries the save")
	# A living public Veteran claim halves the belief; still at the threshold.
	var g2 = warden_credit__game()
	var w2 = g2.w
	var warden2 = w2.npc_with_role("warden")
	var target2 = w2.living_good().filter(func(m): return m != warden2)[0]
	var vet = w2.living().filter(func(m): return m != warden2 and m != target2)[0]
	w2.public_claims.append({"who": vet.id, "role": "veteran", "day": 1})
	w2.public_claims.append({"who": w2.living().filter(func(m): return m not in [warden2, target2, vet])[0].id, "role": "veteran", "day": 1})
	w2.day = 1
	warden2.warden_log["1"] = target2.id
	w2._warden_credit(warden2, target2.id)
	_check(not warden2.warden_saves.has("1"), "with two other claimed protectors the Warden doesn't take the credit")


# ---- test_roster


## Pure World setup for multi-hundred-seed role/home/bluff distribution checks.
func _game(sd: int, size: int = 7):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


func _give(w, n, role: String) -> void:
	var holder = w.npc_with_role(role)
	if holder != null and holder != n:
		holder.role = n.role
	n.role = role


func _test_veteran() -> void:
	var w = _game(9150).w
	var v = w.living_good()[0]
	_give(w, v, "veteran")
	v.secret_mod = ""
	v.poisoned = false
	w.day = 1
	_check(w.attack_outcome(v, {}) == "veteran", "the Veteran's first attack fails")
	w.demon().night_path = C.route(w.demon().home_block, v.home_block)
	w._veteran_survives(v)
	var e: Dictionary = v.info_log.back()
	var path: Array = w.demon().night_path
	var expect: String = path[path.size() - 2] if path.size() >= 2 else v.home_block
	_check(v.vet_used and e["data"]["block"] == expect, "the Veteran survives once and learns the attacker's last block")
	var v2 = w.living_good()[1]
	_check(w.attack_outcome(v, {}) == "killed", "a second attack kills them")


# ---- test_workshop_protection


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
	Mind.ledger_hear(g.w, listener, eid, [], 1.0, [claimant.id, -1, "report"], {"kind": "proof"})
	var outside_base: float = listener.suspicion[claimant.id]
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
	var response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
	check(response.get("workshop", false), "quiet-night case reaches shared presentation")
	check(listener.workshop_state.get("owned", {}).has(eid) and listener.ledger[eid].effects.is_empty(), "quiet-night receipt is owned with empty legacy effects")
	var before: Dictionary = listener.workshop_state.get("requested", {}).duplicate(true)
	response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
	check(response.get("repeated", false) and listener.workshop_state.get("requested", {}) == before, "quiet-night repeat is stable")
	g.workshop_retract(filed, listener.id)
	check(is_equal_approx(listener.suspicion[claimant.id], outside_base), "withdrawing the argument restores the outside baseline")
	var veteran = g.add_card({"kind": "info", "source": claimant.id, "subject": [], "role": "veteran", "day": 1, "phase": 3, "data": {"attacked": 1, "block": "market"}, "text": "Veteran attack report"})
	var fresh = Canvas.new(Live.view(g))
	fresh.nodes[fresh.selected].conclusion.target = claimant.id
	fresh.connect_cards("e:" + Live.Evidence.normalize_card(g.board[veteran - 1]).id, fresh.selected)
	check(Live.status(g, fresh.compile(fresh.selected)).ready, "Veteran live report is supported")
	check(Ghost.live(Live.snapshot(g, fresh.compile(fresh.selected))).ready, "Veteran live report previews")


# ---- test_warden_credit


func warden_credit__game():
	for sd in range(1, 60):
		var g = Game.new()
		g.log_dir = "user://test_logs"
		g.new_case(sd, 10)
		var warden = g.w.npc_with_role("warden")
		if warden != null and not warden.is_evil():
			return g
	return null


func _own_effects(g, n) -> Dictionary:
	var st = n.workshop_state
	var outside: Dictionary = st.get("outside", n.suspicion).duplicate(true)
	var input = Bridge.capture(g, [], n.id, "private", n)
	input.listener.suspicion = outside.duplicate(true)
	var plan = Shared.prepare(input, st.get("presentations", {}), n.ledger, st.get("withdrawn", {}), st.get("attention_focus", []))
	return Shared.evaluate(plan, outside, st.get("source_doubt", {})).effects if plan.ready else {}


## The Warden doesn't guard on night 0 (no kill to stop yet; Michael, Nov 13), and an evil
## Warden bluffer doesn't invent a night-0 door.
func _run_warden_night0() -> void:
	var guarded_night0 := false
	for sd in [692, 42, 900, 54875, 98933]:
		var g = Game.new()
		g.new_case(sd, 10)
		var holder = g.w.npc_with_role("warden")
		if holder == null:
			continue
		if holder.warden_log.has("0") or g.w.dlog.entries.any(func(e): return e["type"] == "protect"):
			guarded_night0 = true
	check(not guarded_night0, "no Warden guards a door on night 0")
	var g2 = Game.new()
	g2.new_case(692, 10)
	var evil = g2.w.living().filter(func(n): return n.is_evil())[0]
	evil.warden_log = {}
	check(C.role_def("warden").warden_door(g2.w, evil, 0) == "" and not evil.warden_log.has("0"), "an evil Warden bluff names no night-0 door")
	check(C.role_def("warden").warden_door(g2.w, evil, 1) != "", "but does name one for night 1")
