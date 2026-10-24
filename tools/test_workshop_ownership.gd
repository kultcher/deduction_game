extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Scenario = preload("res://workshop/scenario.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var g = Game.new()
	g.workshop_effects = false # Explicit legacy baseline before testing migration.
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.suspicion = {}
		for other in g.w.npcs:
			if other != p:
				p.suspicion[other.id] = 0.3
	var n = g.w.living_good()[0]
	n.role = "warden"
	var source = g.w.npcs.filter(func(p): return p != n)[0]
	var target = g.w.npcs.filter(func(p): return p != n and p != source)[0]
	var entry = {"day": 1, "phase": 0, "role": "dowser", "data": {"group": [target.id, source.id], "count": 2}}
	var card = g.add_card({"kind": "info", "source": source.id, "day": 1, "phase": 0, "role": "dowser", "data": entry.data, "text": "Two evil pings"})
	var ded = g.file_deduction({"type": "evil", "a": target.id}, [card])
	var native_before = n.suspicion.duplicate(true)
	Mind.apply_info(g.w, n, source, entry, 0.5)
	var eid = Mind.info_eid(source.id, entry)
	check(n.ledger[eid].meta.workshop_receipts.size() == 1, "raw reading records its exact original receipt")
	var native = n.suspicion.duplicate(true)
	g.set_workshop_effects(true)
	check(n.workshop_state.active and n.workshop_state.owned.has(eid), "supported raw readings acquire a shared owner")
	check(n.ledger[eid].applied.values().all(func(v): return is_zero_approx(v)), "legacy reading suspicion is retracted before joint effects apply")
	check(_close(n.workshop_state.outside, native_before), "migration recovers the independent baseline")
	var once = n.suspicion.duplicate(true)
	Mind.recompute_beliefs(g.w, n, "repeat")
	check(_close(once, n.suspicion), "unchanged reassessment cannot feed its accusation into credibility")
	g._evaluate_deduction(n, g.board[ded - 1], 1.0, false)
	var presented = n.suspicion.duplicate(true)
	check(n.workshop_state.active, "a supported deduction keeps joint ownership active")
	check(n.workshop_state.facts.size() == 1, "a raw reading and its case share one original fact")
	# Trust rewards and pressure remain native social effects. Hold social inputs
	# fixed while checking ownership across repetition and venues.
	var fixed_trust = n.trust
	for venue in ["meeting", "nomination", "private"]:
		g._evaluate_deduction(n, g.board[ded - 1], 0.5, false, venue)
		n.trust = fixed_trust
		Mind.recompute_beliefs(g.w, n, "fixed social inputs")
	check(_close(presented, n.suspicion), "repeating the same evidence across venues does not stack")
	var other_ded = g.file_deduction({"type": "evil", "a": source.id}, [card])
	g._evaluate_deduction(n, g.board[other_ded - 1], 0.6, false, "meeting")
	n.trust = fixed_trust
	Mind.recompute_beliefs(g.w, n, "shared roots")
	check(_close(presented, n.suspicion), "a second case sharing the report adds no second award")
	check(n.workshop_state.owners.values()[0].size() >= 3, "shared provenance retains raw and both case paths")
	g.workshop_retract(ded, n.id)
	check(n.workshop_state.active and n.workshop_state.facts.size() == 1, "withdrawing one case preserves another endorsement and independently learned evidence")
	g.workshop_retract(other_ded, n.id)
	check(n.workshop_state.active and n.workshop_state.facts.size() == 1, "withdrawing both cases still retains the independently learned report")
	check(_close(presented, n.suspicion), "intermediate claim labels never create extra evidence bonuses")
	var before_doubt = n.workshop_state.requested.duplicate(true)
	Mind.ledger_hear(g.w, n, "test:doubt", [["disc:" + source.id + ":1", 0.8, false, "uncertain interval", ""]], 1.0)
	check(n.workshop_state.active and n.discounted.get(source.id + ":1", 0.0) > 0.7, "interval doubt reaches the shared assessor automatically")
	check(absf(n.workshop_state.requested.get(target.id, 0.0)) < absf(before_doubt.get(target.id, 0.0)), "doubting the reading retracts its joint consequences")
	n.ledger["test:doubt"].weight = 0.0
	Mind.recompute_beliefs(g.w, n, "doubt removed")
	check(_close(before_doubt, n.workshop_state.requested), "removing interval doubt restores the former vector")
	g.set_workshop_effects(false)
	var restored_native = n.suspicion.duplicate(true)
	g.set_workshop_effects(true)
	Mind.adjust(g.w, n, target.id, 0.12, "independent suspicion", "", false)
	g.set_workshop_effects(false)
	check(not n.workshop_state.active and n.workshop_state.owned.is_empty(), "disabling shared effects retracts ownership and restores legacy entries")
	check(is_equal_approx(n.suspicion[target.id], restored_native[target.id] + 0.12), "retraction preserves a later independent suspicion change alongside all restored native arguments")
	check(n.ledger[eid].applied.values().any(func(v): return v > 0), "disabled mode restores original native reading effects")
	# Clean standalone presentation: no independent learned route.
	n.ledger = {}
	n.workshop_state = {}
	n.suspicion = native_before.duplicate(true)
	g.set_workshop_effects(true)
	g._evaluate_deduction(n, g.board[ded - 1], 1.0, false)
	check(n.workshop_state.active and n.workshop_state.facts.size() == 1, "player-only evidence can acquire one owner")
	g.workshop_retract(ded, n.id)
	check(n.workshop_state.active and n.workshop_state.facts.is_empty(), "withdrawing the sole endorsement removes its exclusive evidence")
	check(_close(n.suspicion, native_before), "sole-case retraction withdraws the old argument effect too")
	# Clamp boundary belongs to the new layer, not its independent baseline.
	g._evaluate_deduction(n, g.board[ded - 1], 1.0, false)
	Mind.adjust(g.w, n, target.id, 2.0, "independent saturation", "", false)
	# The shared layer's own vector sits on top of the independent baseline, clamped:
	# the independent change stays reversible even above the displayed upper bound.
	check(n.workshop_state.outside[target.id] > 1.5 and is_equal_approx(Mind.susp(n, target.id), 1.5), "independent totals remain unclamped while displayed suspicion saturates")
	var saturated_baseline: float = n.workshop_state.outside[target.id]
	g.workshop_retract(ded, n.id)
	check(is_equal_approx(n.suspicion[target.id], saturated_baseline), "shared retraction preserves the entire independent total")
	# Unsupported chronology must restore one model rather than retain a second layer.
	n.suspicion = native_before.duplicate(true)
	n.ledger = {}
	n.workshop_state = {"enabled": true}
	Mind.apply_info(g.w, n, source, entry, 0.5)
	check(n.workshop_state.active, "supported raw reading reactivates from a clean state")
	g.w.public_log.append({"day": 1, "kind": "curse", "subjects": [target.id], "by": "town"})
	Mind.recompute_beliefs(g.w, n, "unsupported transition")
	check(not n.workshop_state.active and n.workshop_state.owned.is_empty(), "conversion chronology retracts joint ownership and falls back completely")
	check(_close(n.suspicion, native), "conversion fallback restores the native reading effect")
	g.w.public_log.clear()
	# Distinct originals have exact native keys; old coarse records stay ambiguous.
	var variant = entry.duplicate(true)
	variant.data.count = 1
	Mind.apply_info(g.w, n, source, variant, 0.5)
	var variant_eid = Mind.info_eid(source.id, variant)
	check(n.workshop_state.active and eid != variant_eid and n.workshop_state.owned.has(eid) and n.workshop_state.owned.has(variant_eid), "different original readings sharing source/day/role acquire separate exact owners")
	var old_ledger = n.ledger.duplicate(true)
	var old = old_ledger[eid]
	var coarse = "info:%s:%d:%s" % [source.id, entry.day, entry.role]
	old.eid = coarse
	old.meta.workshop_receipts.merge(old_ledger[variant_eid].meta.workshop_receipts)
	old_ledger.erase(eid)
	old_ledger.erase(variant_eid)
	old_ledger[coarse] = old
	var ambiguous = Shared.prepare(g.workshop_snapshot([], n.id), {}, old_ledger)
	check(not ambiguous.ready and ambiguous.issues.any(func(issue): return "Unresolved original reading identity" in issue), "an ambiguous old coarse record still requires explicit fallback")
	# A ghost is neither a particular NPC nor an oracle over hidden truth.
	var before_ghost = _state(g)
	var ghost = g.workshop_ghost_preview(ded)
	check(ghost.ready and ghost.proposal.effects.size() == 7, "neutral live preview assesses every townsperson")
	check(_state(g) == before_ghost, "ghost preview mutates no game, private belief or random state")
	for p in g.w.npcs:
		p.secret_mod = "marked"
		p.poisoned = true
		p.trust = 0.0
		p.suspicion = {}
	var changed = g.workshop_ghost_preview(ded)
	check(ghost.proposal.effects == changed.proposal.effects, "ghost ignores hidden truth and all actual NPC social inputs")
	var profile = Ghost.profile(g.workshop_snapshot([ded]).people)
	check(profile.knowledge.self == "" and profile.knowledge.good.is_empty() and profile.knowledge.own_role == "", "ghost manufactures no self-good or own-role certainty")
	var scenario = Scenario.generate(692)
	var canvas = Canvas.new(scenario.public_view)
	canvas.mockup()
	var fixture_case = canvas.compile(canvas.selected)
	var frozen = JSON.stringify([scenario, fixture_case])
	var preview = Ghost.evaluate(scenario.public_view, fixture_case)
	check(preview.ready and preview.proposal.claims.size() >= 2, "fixture preview retains intermediate claim assessments")
	check(frozen == JSON.stringify([scenario, fixture_case]), "fixture preview leaves the case and mock jury untouched")
	_advanced()
	print("Workshop ownership: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _advanced() -> void:
	for size in [7, 10]:
		var g = Game.new()
		g.workshop_effects = false # Explicit legacy baseline before testing migration.
		g.detailed_logging = false
		g.new_case(692, size)
		for person in g.w.npcs:
			person.info_log = []
			person.known_claims = {}
			person.beliefs = []
			person.ledger = {}
			for id in person.suspicion:
				person.suspicion[id] = 0.3
		var n = g.w.living_good()[0]
		n.role = "warden"
		var source = g.w.npcs.filter(func(p): return p != n)[0]
		var target = g.w.npcs.filter(func(p): return p != n and p != source)[0]
		var card = g.add_card({"kind": "info", "source": source.id, "day": 1, "phase": 0, "role": "dowser", "data": {"group": [source.id, target.id], "count": 2}, "text": "First report"})
		var ded = g.file_deduction({"type": "evil", "a": target.id}, [card])
		g.set_workshop_effects(true)
		g._evaluate_deduction(n, g.board[ded - 1], 1.0, false)
		check(n.workshop_state.active, "%d-person town supports a shared presentation" % size)
		var previous_fact: String = n.workshop_state.facts[0]
		var other = g.add_card({"kind": "info", "source": source.id, "day": 2, "phase": 0, "role": "dowser", "data": {"group": [source.id, target.id], "count": 0}, "text": "Later report"})
		g.board[ded - 1].supports = [other]
		g._evaluate_deduction(n, g.board[ded - 1], 1.0, false)
		check(n.workshop_state.active and n.workshop_state.facts.size() == 1 and previous_fact not in n.workshop_state.facts and n.workshop_state.facts[0] == Shared.Evidence.normalize_card(g.board[other - 1]).id, "re-presenting a revised case replaces its exclusive old evidence in a %d-person town even when bounded conviction is unresolved" % size)
		# The report itself can also be learned independently after presentation.
		Mind.apply_info(g.w, n, source, {"day": 2, "phase": 0, "role": "dowser", "data": g.board[other - 1].data}, 0.6)
		check(n.workshop_state.active and n.workshop_state.facts.size() == 1, "later independent learning joins the same shared fact")
		var pref = [["pref:spare:" + target.id, 0.25, false, "preserved preference", ""], ["role:" + target.id + ":medium", 0.3, false, "preserved role", ""]]
		var raw = n.ledger[Mind.info_eid(source.id, {"day": 2, "phase": 0, "role": "dowser", "data": g.board[other - 1].data})]
		raw.effects.append_array(pref)
		Mind.recompute_beliefs(g.w, n, "non-suspicion ownership")
		check(n.spare_pref.get(target.id, 0.0) > 0 and n.believed_roles.get(target.id) == "medium", "shared ownership preserves native preferences and role belief effects")
		var raw_vector = n.workshop_state.requested.duplicate(true)
		n.trust = 0.0
		Mind.recompute_beliefs(g.w, n, "player trust falls")
		check(_close(raw_vector, n.workshop_state.requested), "independently learned readings do not depend on player trust")
		# An overlapping old card presentation cannot be certified from a coarse ref.
		Mind.ledger_hear(g.w, n, "test:mixed-tell", [[target.id, 0.1, false, "old testimony", ""]], 0.5, [source.id, 2, "reading"], {"kind": "tell"})
		check(not n.workshop_state.active and n.workshop_state.owned.is_empty(), "uncertified card overlap restores the complete native model")
		check(n.workshop_state.issues.any(func(s): return "testimony" in s), "overlap fallback exposes the missing ownership adapter")
		if size == 7:
			var evil = g.w.npcs.filter(func(p): return p.is_evil())[0]
			var real_suspicion = evil.suspicion.duplicate(true)
			Mind.shadow_run(g.w, evil, func(sh):
				sh.info_log = []
				sh.known_claims = {}
				sh.ledger = {}
				sh.role = "warden"
				for id in sh.suspicion:
					sh.suspicion[id] = 0.3)
			g._evaluate_deduction(evil, g.board[ded - 1], 0.6, false)
			check(evil.suspicion == real_suspicion, "enabled inference never modifies the real evil mind")
			check(evil.shadow.workshop_state.get("enabled", false), "evil presentation routes shared state to the good cover")
			var input = g.workshop_snapshot([ded], n.id)
			var uncertified = n.ledger.duplicate(true)
			uncertified.erase("test:mixed-tell")
			for e in uncertified.values():
				if e.get("meta", {}).get("kind") == "arg":
					for j in e.get("justs", []):
						j.erase("workshop_cases")
			uncertified["arg:old"] = {"eid": "arg:old", "weight": 0.2, "effects": [[target.id, 0.2, false, "old argument", ""]],
				"rel": [], "applied": {}, "meta": {"kind": "arg", "workshop_conclusion": "evil"},
				"justs": [{"supports": [[source.id, 2, "reading"]]}]}
			var plan = Shared.prepare(input, {str(ded): input}, uncertified)
			check(not plan.ready and plan.owned.is_empty() and plan.issues.any(func(s): return "uncertified argument" in s), "old arguments without exact per-path provenance cannot be adopted")
			# Ownership boundaries do not inherit the native display-noise cutoff.
			g.set_workshop_effects(false)
			n.ledger = {}
			n.workshop_state = {}
			for id in n.suspicion:
				n.suspicion[id] = 0.3
			Mind.apply_info(g.w, n, source, {"day": 2, "phase": 0, "role": "dowser", "data": g.board[other - 1].data}, 0.6)
			var small = n.ledger.values()[0]
			for key in small.applied:
				var index: int = key
				var who: String = small.effects[index][0]
				n.suspicion[who] -= small.applied[key]
				n.suspicion[who] += 0.001
				small.applied[key] = 0.001
			g.set_workshop_effects(true)
			check(n.workshop_state.active and small.applied.values().all(func(v): return is_zero_approx(v)), "ownership retracts even sub-threshold native remnants exactly")
			Mind.adjust(g.w, n, target.id, -3.0, "lower-bound regression", "", false)
			var unclamped_plan = Shared.prepare(g.workshop_snapshot([], n.id), {}, n.ledger)
			check(unclamped_plan.ready and is_zero_approx(Mind.susp(n, target.id)), "lower-bound totals no longer block reversible ownership")
			var wide_input = g.workshop_snapshot([ded], n.id)
			for i in range(9):
				var added = Shared.reading(source.id, {"day": i + 3, "phase": 0, "role": "dowser", "data": {"group": [target.id], "count": 1}})
				wide_input.evidence.append(added)
				wide_input.private_evidence.append(added.id)
			# CaseEval has no 64-state budget: a wide union is assessed whole, never truncated.
			var wide_plan = Shared.prepare(wide_input, {}, n.ledger)
			check(wide_plan.ready and wide_plan.facts.size() >= 10, "wide unions are assessed whole without truncating supplied reports")
			# A conversion can be restored before any conversation creates a cover.
			g.w.turn_evil(n, "test conversion")
			g.w.public_event("curse", ["town"], "")
			g.w.curse = {"victim": n.id, "day": 1}
			g.set_workshop_effects(false)
			check(n.shadow == null and n.workshop_state.get("active", false), "toggling while turned preserves the dormant reversible good layer")
			g.w.free_turned()
			check(not n.is_evil() and not n.workshop_state.get("active", false) and n.workshop_state.owned.is_empty(), "restoration without a cover retracts dormant shared ownership")
			check(n.suspicion.values().all(func(value): return value <= 0.250001), "ownership restores native effects before the restoration suspicion cap")

func _state(g) -> String:
	var rows: Array = []
	for n in g.w.npcs:
		rows.append([n.suspicion, n.ledger, n.workshop_state, n.trust])
	return JSON.stringify([g.w.rng.state, g.w.day, g.w.phase, g.board, rows])

func _close(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	return a.keys().all(func(key): return b.has(key) and absf(float(a[key]) - float(b[key])) < 0.000001)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
