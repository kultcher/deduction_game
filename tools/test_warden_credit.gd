## Warden credit for quiet nights (Oct 30, docs/social_trust_pass.md phase 3).
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Caches = preload("res://workshop/caches.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _game():
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
	return Shared.evaluate(plan, outside, n.discounted).effects if plan.ready else {}

func _init():
	var g = _game()
	_check(g != null, "a fixture seed has a good Warden")
	if g == null:
		quit(1)
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
	var g2 = _game()
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
	print("Warden credit: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
