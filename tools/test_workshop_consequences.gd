## Pre-Slice-4 acceptance checks: claim assessment and collateral consequences.
extends SceneTree
const Session = preload("res://workshop/session.gd")
const Model = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")
var checks = 0
var fails = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = Session.new(692)
	var view: Dictionary = session.scenario.public_view
	var listener: Dictionary = session.baseline[3].duplicate(true)
	for id in listener.suspicion:
		listener.suspicion[id] = 0.0 if id == listener.id else 0.1
		listener.npc_trust[id] = 0.5
	var board = Model.new(view)
	var root: String = board.selected
	var hollis = board.add_premise("hollis", "evil", Vector2.ZERO)
	board.connect_cards(hollis, root)
	for id in ["survey", "rumor", "dowse"]:
		board.connect_cards("e:" + id, hollis)
	var c = board.compile(root)
	check(session.validate_case(c) == "", "compiled claims, scopes and dependencies validate")
	var heard_by = listener.duplicate(true)
	var first = Jury.evaluate(view, c, heard_by)
	print("Reading effects: " + str(_effects(first)))
	check(first.effects.hollis.applied > 0 and first.effects.lian.applied > 0, "Hollis and unclaimed Lian become more suspicious under a Constance headline")
	check(first.effects.hollis.applied > first.effects.constance.applied and first.shared_assessment.compatible == 2, "established Hollis implication is stronger than the unresolved Constance accusation")
	var h = _claim(first, hollis)
	var main = _claim(first, root)
	check(h.status == "entailed_in_attention" and main.status == "rival_found", "intermediate Hollis implication and unresolved parent are assessed separately")
	check(first.response.contains("Hollis") and first.response.contains("does not by itself settle"), "spoken response distinguishes Hollis's implication from Constance's uncertainty")
	check(h.links.size() == 1 and h.links[0].alternative_remains, "Hollis-to-Constance connection exposes the surviving alternative")
	check(first.effects[listener.id].applied == 0, "collateral effects cannot override private good alignment")
	check(first.effects.bart.requested < 0, "credible readings can also exonerate their source")
	var already_known = Solver.empty_case()
	already_known.cards = session.baseline[0].knowledge.own_reports.duplicate()
	var own_read = Jury.evaluate(view, already_known, session.baseline[0].duplicate(true))
	check(own_read.effects.values().all(func(e): return is_zero_approx(e.requested)), "presenting only an already-known personal reading creates no fresh collateral evidence")
	var privately_impossible = c.duplicate(true)
	privately_impossible.positions[listener.id] = "evil"
	var rejected_world = Jury.evaluate(view, privately_impossible, listener.duplicate(true))
	check(rejected_world.effects.values().all(func(e): return is_zero_approx(e.requested)), "a proposed world contradicting private good knowledge cannot generate collateral persuasion")
	var repeated = Jury.evaluate(view, c, heard_by, {"venue": "meeting"})
	check(repeated.repeated and repeated.effects.values().all(func(e): return is_zero_approx(e.delta)), "repeating at another venue adds no effect on ANY character")
	var flat = Model.new(view)
	for id in ["survey", "rumor", "dowse"]:
		flat.connect_cards("e:" + id, flat.selected)
	var direct = Jury.evaluate(view, flat.compile(flat.selected), listener.duplicate(true))
	check(_effects(first) == _effects(direct), "an intermediate wrapper changes explanations, not the effect of identical original evidence")
	board.connect_cards("e:rumor", root)
	var shared = Jury.evaluate(view, board.compile(root), listener.duplicate(true))
	check(_effects(shared) == _effects(first), "Merrin cited directly and through Hollis still contributes once")
	var duplicate = board.add_premise("hollis", "evil", Vector2.ZERO)
	for id in ["survey", "rumor", "dowse"]:
		board.connect_cards("e:" + id, duplicate)
	board.connect_cards(duplicate, root)
	var duplicated = Jury.evaluate(view, board.compile(root), listener.duplicate(true))
	check(_effects(duplicated) == _effects(first), "duplicating a complete derivation cannot multiply collateral effects")
	check(_claim(duplicated, hollis).links[0].exclusive_cards.is_empty(), "counterfactual link check retains support available through another branch")
	board.nodes[duplicate].conclusion.target = "agnes"
	var mislabeled = Jury.evaluate(view, board.compile(root), listener.duplicate(true))
	check(_effects(mislabeled) == _effects(first), "mislabeling an intermediate claim does not manufacture alignment evidence")
	var reverse_lines = c.duplicate(true)
	reverse_lines.cards.reverse()
	reverse_lines.lines.reverse()
	check(_effects(Jury.evaluate(view, reverse_lines, listener.duplicate(true))) == _effects(first), "evidence and reasoning-line order do not alter the vector")
	check(_claim(mislabeled, duplicate).stance == "reject" and _claim(mislabeled, duplicate).links[0].note.contains("do not accept"), "NPC explicitly disputes a mistaken intermediate claim and its connection")
	var naked = Model.new(view)
	var unsupported = naked.add_premise("hollis", "evil", Vector2.ZERO)
	naked.connect_cards(unsupported, naked.selected)
	var unsubstantiated = Jury.evaluate(view, naked.compile(naked.selected), listener.duplicate(true))
	check(unsubstantiated.effects.values().all(func(e): return is_zero_approx(e.requested)), "a bare linked accusation supplies no belief change")
	check(_claim(unsubstantiated, unsupported).note.contains("No attended evidence"), "unsupported intermediate accusation is identified")
	var misquoted_view = view.duplicate(true)
	Solver.card_by_id(misquoted_view, "watch1").data.seen.append("bart")
	var bad_watch = Solver.empty_case()
	bad_watch.cards = ["watch1"]
	var firsthand = Jury.evaluate(misquoted_view, bad_watch, session.baseline[0].duplicate(true))
	check(firsthand.effects.constance.pattern_signal == 0 and firsthand.effects.values().all(func(e): return is_zero_approx(e.requested)), "a firsthand-rejected report cannot supply collateral outing suspicion about someone else")
	var nested = Model.new(view)
	var group = nested.add_premise("constance", "support", Vector2.ZERO)
	var nested_h = nested.add_premise("hollis", "evil", Vector2.ZERO)
	nested.connect_cards(nested_h, group)
	nested.connect_cards(group, nested.selected)
	for id in ["survey", "rumor", "dowse"]:
		nested.connect_cards("e:" + id, nested_h)
	var nested_case = nested.compile(nested.selected)
	check(session.validate_case(nested_case) == "" and _effects(Jury.evaluate(view, nested_case, listener.duplicate(true))) == _effects(first), "claim-less grouping preserves nested claims and shared evidential weight")
	var combined = Model.new(view)
	combined.mockup()
	var complete = Jury.evaluate(view, combined.compile(combined.selected), listener.duplicate(true))
	var suspicious: String = combined.nodes.keys().filter(func(id): return combined.nodes[id].kind == "premise" and combined.nodes[id].conclusion.get("type") == "suspicious")[0]
	check(_claim(complete, suspicious).note.contains("circumstantial") and complete.effects.constance.applied > first.effects.constance.applied, "contradiction through a suspiciousness claim strengthens Constance's case")
	check(complete.effects.hollis.applied > 0 and complete.shared_assessment.compatible == 2, "converging alibi branch preserves Hollis's effect and both Constance/Nisha worlds")
	var ce: Dictionary = complete.effects.constance
	check(is_equal_approx(ce.requested, maxf(absf(ce.alignment_signal), ce.pattern_signal) * (0.5 + listener.trust) * (1.4 - 0.8 * listener.confidence)), "overlapping contradiction/pattern routes use one envelope, not two added awards")
	# Every person must be assessed from the same source suspicion / prior snapshot.
	var reordered = view.duplicate(true)
	reordered.people.reverse()
	var order_result = Jury.evaluate(reordered, c, listener.duplicate(true))
	check(_effects(order_result) == _effects(first), "person iteration order cannot cause within-presentation feedback")
	var bare_h = c.duplicate(true)
	bare_h.erase("arguments")
	bare_h.erase("argument_root")
	bare_h.conclusion.target = "hollis"
	check(_effects(Jury.evaluate(view, bare_h, listener.duplicate(true))) == _effects(first), "changing the headline does not create a second award for already implicated Hollis")
	var removed = Solver.empty_case()
	var withdrawn = Jury.evaluate(view, removed, heard_by)
	check(heard_by.suspicion == listener.suspicion and withdrawn.effects.hollis.delta < 0, "removing the case retracts the ENTIRE vector, including untargeted characters")
	var saturated = listener.duplicate(true)
	saturated.suspicion.hollis = 1.49
	var original_suspicion = saturated.suspicion.duplicate(true)
	var capped = Jury.evaluate(view, c, saturated)
	check(capped.effects.hollis.after <= 1.5 and capped.effects.hollis.applied <= capped.effects.hollis.requested, "ledger records the actual clamped effect on each person")
	Jury.evaluate(view, removed, saturated)
	check(saturated.suspicion == original_suspicion, "retraction after saturation restores every original belief")
	for insight in [0.1, 0.5, 0.9]:
		var bounded = listener.duplicate(true)
		bounded.reasoning_mode = "bounded"
		bounded.insight = insight
		var a = Jury.evaluate(view, c, bounded)
		var b = Jury.evaluate(view, c, bounded, {"venue": "nomination"})
		check(b.effects.values().all(func(e): return is_zero_approx(e.delta)), "all effects are repeat-stable at Insight %.1f" % insight)
		check(a.effects.values().all(func(e): return e.cards == a.reasoning.considered), "collateral assessments share the headline attention window at Insight %.1f" % insight)
		var fresh = listener.duplicate(true)
		fresh.reasoning_mode = "bounded"
		fresh.insight = insight
		check(_effects(a) == _effects(Jury.evaluate(view, flat.compile(flat.selected), fresh)), "direct/grouped reading evidence has equal effects at Insight %.1f" % insight)
	var persistent = listener.duplicate(true)
	persistent.confidence_mode = "persistence"
	persistent.reasoning_mode = "bounded"
	persistent.insight = 0.9
	Jury.evaluate(view, c, persistent)
	var stable_theory = Jury.evaluate(view, c, persistent)
	check(stable_theory.effects.values().all(func(e): return is_zero_approx(e.delta)), "confidence persistence cannot incrementally reinforce collateral effects on repeat")
	# Missed movement evidence must not leak through an intermediate assessment.
	var low = listener.duplicate(true)
	low.reasoning_mode = "bounded"
	low.insight = 0.1
	var low_result = Jury.evaluate(view, combined.compile(combined.selected), low)
	if "alibi1" not in low_result.reasoning.considered or "vigil1" not in low_result.reasoning.considered:
		check(_claim(low_result, suspicious).cards.size() < 2 and low_result.effects.constance.pattern_signal == 0, "an unattended contradiction cannot produce a collateral pattern effect")
	# Replay trusts original evidence/settings, not exported deltas.
	session.case_data = combined.compile(combined.selected)
	session.present(false)
	session.present(true, "meeting")
	session.baseline[3].suspicion.hollis += 0.1
	session.listeners[3].suspicion.hollis += 0.1
	session.present(true)
	var saved = JSON.parse_string(JSON.stringify(session.export_data()))
	var restored = Session.new(101)
	var error = restored.restore(saved)
	if restored.last_results != session.last_results:
		_diff(restored.last_results, session.last_results, "results")
	if restored.listeners != session.listeners:
		_diff(restored.listeners, session.listeners, "listeners")
	check(error == "" and restored.last_results == session.last_results and restored.listeners == session.listeners, "multi-person effects, claims and edited social inputs replay exactly: " + error)
	saved.history[0].results[0].effects.hollis.applied = 999
	check(restored.restore(saved) == "" and restored.last_results == session.last_results, "stored consequence values cannot inject NPC beliefs")
	var malformed = JSON.parse_string(JSON.stringify(session.export_data()))
	malformed.case.arguments[0].parents = [malformed.case.arguments[0].id]
	var unchanged = restored.export_data()
	check(restored.restore(malformed) != "" and restored.export_data() == unchanged, "invalid argument graph is rejected atomically")
	var obsolete = JSON.parse_string(JSON.stringify(session.export_data()))
	obsolete.format = "demonologist-case-workshop-3"
	check(restored.restore(obsolete).contains("Version 5"), "old model histories are not silently replayed with different persuasion semantics")
	await _ui()
	print("Workshop consequences: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _ui() -> void:
	var scene = load("res://ui/case_workshop.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.find_child("LoadMockup", true, false).pressed.emit()
	scene._present()
	var label = scene.find_child("CaseEffects_3", true, false)
	check(label != null and label.text.contains("Hollis"), "actual jury window displays collateral Hollis suspicion")
	var claims = scene.find_child("CaseClaims_3", true, false)
	check(claims != null and claims.get_child_count() >= 6, "actual jury window exposes intermediate claim assessments and connections")
	scene.queue_free()
	await process_frame

func _effects(result: Dictionary) -> Dictionary:
	var effects = {}
	for id in result.effects:
		effects[id] = result.effects[id].applied
	return effects

func _claim(result: Dictionary, id: String) -> Dictionary:
	return result.claims.filter(func(c): return c.id == id)[0]

func check(okay: bool, label: String) -> void:
	checks += 1
	if okay:
		print("PASS: " + label)
	else:
		fails += 1
		push_error("FAIL: " + label)

func _diff(a, b, path: String) -> void:
	if a == b:
		return
	if a is Dictionary and b is Dictionary:
		for key in a:
			if b.has(key):
				_diff(a[key], b[key], path + "." + str(key))
	elif a is Array and b is Array and a.size() == b.size():
		for i in range(a.size()):
			_diff(a[i], b[i], path + "." + str(i))
	else:
		print("DIFF %s: %s vs %s" % [path, str(a), str(b)])
