## Regression and acceptance suite for Legacy Purge Phase 2c (`docs/legacy_retirement_plan.md`):
##   1. Receipt-only `ledger_hear` (`effects == []` and no `applied` dict across all receipt kinds)
##   2. Deletion of role `info_effects` across all 12 role files and legacy Mind doubt/honesty/hearing helpers
##   3. Preservation of Seer `cleared` via `RoleDef.on_reading_heard`, metadata preferences/role beliefs, and `answer_opinion` word doubt
##   4. Multi-day shared-mode stability through Day 4 on fixed seeds with zero fallbacks and empty ledger effects
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Social = preload("res://sim/social.gd")
const RoleDef = preload("res://sim/role_def.gd")
const C = preload("res://sim/content.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")

var _checks: int = 0
var _fails: int = 0

func _check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)

func _init() -> void:
	_test_deleted_legacy_surfaces()
	_test_receipt_only_ledger_entries()
	_test_seer_cleared_and_metadata_preferences()
	_test_shared_mode_multi_day_stability()
	print("\nPhase 2c purge suite: %d / %d passed (%d failed)" % [_checks - _fails, _checks, _fails])
	quit(1 if _fails > 0 else 0)

func _test_deleted_legacy_surfaces() -> void:
	var base_def = RoleDef.new()
	_check(not base_def.has_method("info_effects") and base_def.has_method("on_reading_heard"),
		"RoleDef replaces legacy info_effects with on_reading_heard")
	var roles_clean: bool = true
	for role_id in C.ROLES:
		var rdef = C.role_def(role_id)
		if rdef != null and rdef.has_method("info_effects"):
			roles_clean = false
	_check(roles_clean, "no role script in sim/roles/ defines legacy info_effects")
	var mind_inst = Mind.new()
	var removed_helpers: Array = ["_eff", "_info_effects", "_night_doubt", "_honesty", "_claimants", "_expand", "_final_weight", "_support_factor", "_ledger_apply", "word_factor", "_tell_meta"]
	_check(removed_helpers.all(func(fn): return not mind_inst.has_method(fn)),
		"Mind deletes legacy _eff, _info_effects, _night_doubt, _honesty, _claimants, word_factor, and _ledger_apply")

func _test_receipt_only_ledger_entries() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://test_phase2c_logs"
	g.new_case(900, 10)
	var w = g.w
	var goods: Array = w.living_good()
	var listener = goods[0]
	var speaker = goods[1]
	var walker = goods[2]
	var victim = goods[3]
	var saved = goods[4]
	var martyr = goods[5]

	victim.home_block = "docks"
	walker.home_block = "square"
	speaker.home_block = "docks"
	w.day = 1
	w._kill(victim)
	w.day = 2

	# 1. Role claim + rival own_role counter + reading
	listener.role = "seer"
	listener.claimed_role = "seer"
	listener.claim_public = true
	Mind.hear_claim(w, listener, listener.id, "seer", 1.5, "own")
	Mind.hear_claim(w, listener, speaker.id, "seer", 0.5, "public")
	var rival_card: Dictionary = {"kind": "claim", "source": speaker.id, "subject": [speaker.id], "role": "seer", "day": 2, "phase": 0, "text": "I claim Seer."}
	Mind.press(w, listener, rival_card)
	var dowse_entry: Dictionary = {"day": 1, "phase": 0, "role": "dowser", "data": {"group": [walker.id, saved.id], "count": 1}, "shared": true, "text": "1 evil in pair"}
	Mind.apply_info(w, listener, speaker, dowse_entry, 0.5)

	# 2. Whispered sighting relay + relayed case
	Social._deliver(w, speaker, listener, {"kind": "sighting", "about": walker.id, "from": speaker.id, "block": "docks", "day": 1, "key": "sight:1"})
	var cnum: int = g.add_card({"kind": "info", "source": speaker.id, "role": "dowser", "day": 1, "phase": 0, "data": dowse_entry.data, "text": "1 evil in pair"})
	var dnum: int = g.file_deduction({"type": "evil", "a": walker.id}, [cnum])
	Social._deliver(w, speaker, listener, {"kind": "case", "about": walker.id, "from": speaker.id, "card": g.board[dnum - 1], "key": "case:1"})

	# 3. Workshop deduction presentation must NOT park native arg:* / arg:workshop:* entries
	var board = Canvas.new(Live.view(g))
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "evil", "target": walker.id, "at": "Original alignment"}
	board.connect_cards("e:" + Live.Evidence.normalize_card(g.board[cnum - 1]).id, root)
	var filed: int = Live.file(g, board.compile(root))
	var pres_res: Dictionary = g._evaluate_deduction(listener, g.board[filed - 1], 1.0, false)
	_check(pres_res.get("workshop", false) and not listener.ledger.has("arg:workshop:%d" % filed),
		"Workshop deduction presentation no longer parks a native Argue._apply ledger entry")

	# 4. Direct card presentation records receipt-only workshop:tell:* entry
	var def_res: Dictionary = Mind.hear_defence(w, listener, saved, g.board[cnum - 1])
	_check(def_res.get("workshop", false) and listener.ledger.keys().any(func(k): return str(k).begins_with("workshop:tell:")),
		"direct card defence records workshop:tell receipt")

	# 5. Public silence + quiet night + Martyr proof + Revenant curse + nomination defence
	saved.claimed_role = "warden"
	saved.claim_public = true
	w.public_claims.append({"day": 1, "who": saved.id, "role": "warden"})
	w._quiet_night()
	walker.silence_pending = 2
	w.begin_meeting()
	MindMeeting.defend_self(w, walker, "player")

	martyr.role = "martyr"
	martyr.martyr_target = saved.id
	C.role_def("martyr").on_substitute_execution(w, martyr, saved, {"by": "player", "yes": [], "player_yes": false}, Mind)

	var rev = w.minions()[0]
	rev.role = "revenant"
	w.totem = {"loc": "well", "day": 2, "owner": rev.id, "material": rev.home_block}
	rev.alive = false
	rev.death_day = 2
	rev.death_cause = "executed"
	w.public_event("execution", [rev.id], "town")
	w.executions.append({"day": 2, "id": rev.id, "nominator": "player", "yes": [walker.id, saved.id], "no": [], "player_yes": true, "player_nominated": true})
	C.role_def("revenant").on_executed(w, rev, {"yes": [walker.id, saved.id]}, Mind)

	var all_empty: bool = true
	var any_applied_key: bool = false
	for p in w.npcs:
		for m in [p, p.shadow]:
			if m == null:
				continue
			for e in m.ledger.values():
				if not e.get("effects", []).is_empty():
					all_empty = false
				if e.has("applied"):
					any_applied_key = true
	_check(all_empty and not any_applied_key and listener.ledger.size() >= 8,
		"all ledger entries across claims, readings, counters, relays, presentations, defences, and public events store empty effects and no applied dict")
	_check(listener.workshop_state.get("owned", {}).has("martyr:2") and listener.workshop_state.get("owned", {}).has("curse:2") and listener.workshop_state.get("owned", {}).has("quiet:2>" + saved.id),
		"SharedLedger and LiveProtection certify martyr:, curse:, and quiet: ownership with empty ledger effects")

func _test_seer_cleared_and_metadata_preferences() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(4242, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var seer = goods[0]
	var a = goods[1]
	var b = goods[2]
	var c = goods[3]
	seer.role = "seer"
	seer.cleared = {}
	var no_entry: Dictionary = {"day": 1, "phase": C.NIGHT, "role": "seer", "data": {"pair": [a.id, b.id], "yes": false}, "text": "Neither is the Demon"}
	var yes_entry: Dictionary = {"day": 2, "phase": C.NIGHT, "role": "seer", "data": {"pair": [b.id, c.id], "yes": true}, "text": "One is the Demon"}
	Mind.apply_info(w, seer, seer, no_entry, 1.0)
	Mind.apply_info(w, seer, seer, yes_entry, 1.0)
	Mind.apply_info(w, a, seer, no_entry, 0.5)
	_check(seer.cleared.has(a.id) and seer.cleared.has(b.id) and not seer.cleared.has(c.id) and not a.cleared.has(b.id),
		"RoleDef.on_reading_heard marks cleared subjects only on a Seer's own fresh NO reading")

	# Metadata-derived believed_roles, protect_pref, and spare_pref
	Mind.hear_claim(w, seer, a.id, "warden", 0.5, "public")
	Mind.ledger_hear(w, seer, "arg:protect:" + a.id, [], 0.5, [], {"kind": "arg", "conclusion": {"type": "protect", "a": a.id}})
	Mind.ledger_hear(w, seer, "arg:spare:" + b.id, [], 0.4, [], {"kind": "arg", "conclusion": {"type": "spare", "a": b.id}})
	_check(seer.believed_roles.get(a.id, "") == "warden" and seer.protect_pref.get(a.id, 0.0) > 0.0 and seer.spare_pref.get(b.id, 0.0) > 0.0,
		"refresh_beliefs derives believed_roles, protect_pref, and spare_pref from ledger metadata without effects arrays")

	# answer_opinion word-doubt caveat reads reliability / source_doubt without n.honesty
	seer.suspicion[c.id] = 0.2
	seer.honesty = {}
	seer.dialogue_memory = {}
	seer.workshop_state["source_doubt"] = {c.id + ":*": 0.6}
	var op: Dictionary = Mind.answer_opinion(w, seer, c)
	_check("faith" in str(op.lines[0].get("statement", "")) and seer.honesty.is_empty(),
		"answer_opinion emits word-doubt caveat from source_doubt/reliability with empty n.honesty")

func _test_shared_mode_multi_day_stability() -> void:
	for sd in [37291, 42, 54875, 900]:
		var g = Game.new()
		g.detailed_logging = false
		g.log_dir = "user://test_phase2c_logs"
		g.new_case(sd, 10)
		for step in range(120):
			if g.w.day >= 4 and g.state == "day":
				break
			if g.w.game_over:
				break
			match g.state:
				"night":
					g.command("sleep")
				"meeting":
					g.command("done")
					g.command("wait")
				"nomination":
					g.command("vote no")
					g.command("wait")
				"approach":
					g.command("decline")
				_:
					g.command("wait")
		var w = g.w
		var empty_effects_ok: bool = true
		var legacy_dicts_empty: bool = true
		var refresh_stable: bool = true
		var rng_before: int = w.rng.state
		for p in w.living():
			var m = p.shadow if p.is_evil() else p
			if m == null:
				continue
			if not m.discounted.is_empty() or not m.honesty.is_empty():
				legacy_dicts_empty = false
			for e in m.ledger.values():
				if not e.get("effects", []).is_empty() or e.has("applied"):
					empty_effects_ok = false
			var before_s: Dictionary = m.suspicion.duplicate(true)
			Mind.refresh_beliefs(w, m, " (idempotency check)")
			for k in before_s:
				if absf(float(before_s[k]) - float(m.suspicion.get(k, -99.0))) > 0.000001:
					refresh_stable = false
		_check(g.shared_fallbacks.is_empty() and empty_effects_ok and legacy_dicts_empty and refresh_stable and w.rng.state == rng_before,
			"seed %d reaches Day %d with 0 fallbacks, empty ledger effects, empty discounted/honesty, and RNG-free idempotent refreshes" % [sd, w.day])
