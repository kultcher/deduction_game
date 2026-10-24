## The live adapter must preserve semantics and remain independent of hidden causes.
extends SceneTree
const Game = preload("res://game/game.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const C = preload("res://sim/content.gd")
const DevLog = preload("res://sim/devlog.gd")
var checks = 0
var fails = 0

func _init() -> void:
	for size in [7, 10]:
		for seed_value in [692, 4242, 7813]:
			_live(seed_value, size)
	_receipts()
	print("Workshop live adapter: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _live(seed_value: int, size: int) -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_value, size)
	var n = g.w.living_good()[0]
	var other = g.w.npcs.filter(func(p): return p.id != n.id)[0]
	g.w.day = 3
	g.w.phase = C.AFTERNOON
	n.info_log.append({"day": 1, "role": "surveyor", "data": {"count": 3}, "true": false, "why": "HIDDEN_CAUSE", "text": "Three blocks."})
	var read = g.add_card({"kind": "info", "source": n.id, "subject": [], "day": 1, "role": "surveyor", "data": {"count": 3, "why": "HIDDEN_CAUSE"}, "text": "Three blocks."})
	var private_read = {"day": 2, "role": "seer", "data": {"pair": [n.id, other.id], "yes": true}, "text": "PRIVATE_READING"}
	other.info_log.append(private_read)
	var sight = g.add_card({"kind": "sighting", "source": "player", "subject": [other.id], "day": 1, "phase": C.NIGHT, "block": "market", "text": "Saw them out."})
	var alibi = g.add_card({"kind": "alibi", "source": other.id, "subject": [other.id], "day": 1, "phase": C.NIGHT, "home": true, "text": "They said home."})
	var deduction = g.file_deduction({"type": "evil", "a": other.id}, [sight, alibi, read])
	var before = _state(g)
	var snapshot = g.workshop_snapshot([deduction], n.id)
	check(before == _state(g), "capture leaves world, NPCs, RNG and log unchanged (%d/%d)" % [seed_value, size])
	check(snapshot.selected.size() == 3 and snapshot.arguments.size() == 1, "deductions recursively preserve original evidence and claim")
	check(snapshot.rules.initial_evil_count == (2 if size == 7 else 3), "evil count comes from public setup rules")
	check(snapshot.rules.modifier_options.size() == 4 and not snapshot.assessment_ready, "unsupported modifier worlds are retained and gate assessment")
	var serialized = JSON.stringify(snapshot)
	check("HIDDEN_CAUSE" not in serialized and "PRIVATE_READING" not in serialized and "poisoned" not in serialized, "unheard readings and hidden causes never cross the boundary")
	var reading: Dictionary = snapshot.evidence.filter(func(e): return e.kind == "info")[0]
	check(reading.observed_at == {"day": 1, "phase": "night"} and reading.learned_at.day == 3, "observation and learning times stay distinct")
	check(reading.id in snapshot.private_evidence and snapshot.evidence.filter(func(e): return e.id == reading.id).size() == 1, "own reading and presented copy share one fact")
	var outing: Array = snapshot.evidence.filter(func(e): return e.kind in ["sighting", "alibi"])
	check(outing[0].incident_ids == outing[1].incident_ids and outing[0].id != outing[1].id, "conflicting testimony shares an incident without merging witnesses")
	check(snapshot.issues.any(func(i): return i.code == "modifier_alternatives") and snapshot.issues.any(func(i): return i.code == "live_movement"), "missing capabilities are explicit")
	var detached = g.workshop_snapshot([deduction], n.id)
	detached.listener.suspicion[other.id] = 100
	detached.arguments[0].supports.clear()
	detached.evidence[0].content.subjects.clear()
	check(before == _state(g), "editing captured inputs cannot mutate live state through shared references")
	# Hidden-role mutations must not change the public snapshot or this listener's mind.
	for person in g.w.npcs:
		person.poisoned = not person.poisoned
		person.secret_mod = "delusional"
		if person != n: # Their own gift is permitted private knowledge, not referee data.
			person.role = "poisoner"
		person.intel["secret"] = "HIDDEN_INTEL"
	g.w.demon_id = other.id
	g.w.curse = {"victim": n.id, "day": 1}
	g.w.night_walkers = [{"id": other.id, "why": "HIDDEN_WALK"}]
	check(snapshot == g.workshop_snapshot([deduction], n.id), "referee roles, actual health, secret and curse victim are not inference inputs")
	var evil = g.w.npcs.filter(func(p): return p.is_evil())[0]
	if evil.shadow != null:
		var cover_before = _state(g)
		var cover = g.workshop_snapshot([read], evil.id)
		check(cover.listener.suspicion == preload("res://sim/mind.gd").suspicion_view(evil.shadow) and "HIDDEN_INTEL" not in JSON.stringify(cover), "evil assessment receives only its existing cover mind")
		check(cover_before == _state(g), "cover capture does not create or sync shadows")
	check(g.workshop_snapshot([99999], n.id).issues.any(func(i): return i.code == "missing_card"), "absent evidence is reported")
	check(g.workshop_snapshot([read], "missing").issues.any(func(i): return i.code == "unknown_listener"), "missing listener is reported")
	var cyclic = g.board[deduction - 1]
	cyclic.supports.append(deduction)
	check(g.workshop_snapshot([deduction], n.id).issues.any(func(i): return i.code == "cyclic_argument"), "cyclic claims cannot silently disappear")

func _receipts() -> void:
	var report = {"kind": "info", "source": "bart", "role": "dowser", "day": 2, "phase": 1,
		"data": {"group": ["merrin", "hollis"], "count": 1}, "via": "merrin",
		"learned": [{"day": 4, "phase": 0, "via": "merrin", "public": false}]}
	var normalized = Evidence.normalize_card(report)
	check(normalized.reported_at == null and normalized.learned_at.day == 4, "relay learning does not invent the original report time")
	var changed = report.duplicate(true)
	changed.via = "odette"
	changed.text = "Another wording."
	check(normalized.id == Evidence.normalize_card(changed).id, "relay and wording do not manufacture another original fact")
	changed.data.group.reverse()
	check(normalized.id == Evidence.normalize_card(changed).id, "unordered reading groups have stable identities")
	changed.data.count = 0
	check(normalized.id != Evidence.normalize_card(changed).id, "changed contents are a distinct assertion even when legacy reading keys match")
	changed = report.duplicate(true)
	changed.phase = 2
	check(normalized.id != Evidence.normalize_card(changed).id, "same-day readings at different times remain distinct")
	check(Evidence.normalize_card({"kind": "mystery"}).issues.has("evidence_kind_unsupported"), "unknown evidence remains visible and marked unsupported")

func _state(g) -> Dictionary:
	var people = []
	for n in g.w.npcs:
		people.append({"real": DevLog.npc_state(n), "history": n.history.duplicate(true),
			"intel": n.intel.duplicate(true), "shadow": DevLog.npc_state(n.shadow) if n.shadow != null else {},
			"shadow_seen": n.shadow_seen.duplicate(true), "shadow_rng": n.shadow.shadow_rng.state if n.shadow != null else 0})
	return {"people": people, "rng": g.w.rng.state, "board": g.board.duplicate(true),
		"log": g.w.dlog.entries.duplicate(true), "day": g.w.day, "phase": g.w.phase, "state": g.state}

func check(okay: bool, label: String) -> void:
	checks += 1
	if not okay:
		fails += 1
		push_error("FAIL: " + label)
