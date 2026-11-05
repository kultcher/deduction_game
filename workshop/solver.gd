## Small exhaustive constraint solver. Receives public evidence only, never hidden truth.
## Counts measure compatible assignments, NOT posterior probabilities.
extends RefCounted
const C = preload("res://sim/content.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Roles = preload("res://workshop/role_constraints.gd")
const History = preload("res://workshop/live_history.gd")
const Activity = preload("res://workshop/live_activity.gd")

const Graph = preload("res://workshop/case_graph.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Profiler = preload("res://workshop/profiler.gd")
static var universes: Dictionary = {}
static var report_matches: Dictionary = {}
static var movement_cache: Dictionary = {}
static var solve_cache: Dictionary = {}
static var conflict_cache: Dictionary = {}
static var reuse_solves = true # Offline parity checks can bypass memoization.
static var _cached_people = null
static var _cached_ids: Array = []
static var _cached_idx: Dictionary = {}
static var _cached_block_masks: Dictionary = {}
static var _cached_cards_ref = null
static var _cached_cards_size: int = 0
static var _cached_card_idx: Dictionary = {}

static func _ensure_people(view: Dictionary) -> void:
	if view.people == _cached_people:
		return
	_cached_people = view.people.duplicate(true)
	_cached_ids = []
	_cached_idx = {}
	_cached_block_masks = {}
	for i in range(view.people.size()):
		var p: Dictionary = view.people[i]
		_cached_idx[p.id] = i
		_cached_ids.append(p.id)
		_cached_block_masks[p.home] = _cached_block_masks.get(p.home, 0) | (1 << i)

static func person_index(view: Dictionary, id: String) -> int:
	_ensure_people(view)
	return _cached_idx.get(id, -1)

static func person_ids(view: Dictionary) -> Array:
	_ensure_people(view)
	return _cached_ids

static func empty_case() -> Dictionary:
	return {"id": "case-1", "version": 1, "cards": [], "positions": {}, "answers": {}, "reasons": {},
		"citations": {}, "conflict_scope": [], "challenges": {}, "reading_challenges": {}, "derived": [], "lines": [], "disputes": [], "faults": {}, "temporal_positions": [],
		"conclusion": {"type": "evil", "target": "constance", "at": "opening through day 3"}}

static func card_by_id(view: Dictionary, id: String) -> Dictionary:
	var cards_arr: Array = view.cards
	var sz: int = cards_arr.size()
	if not is_same(cards_arr, _cached_cards_ref) or sz < _cached_cards_size:
		_cached_cards_ref = cards_arr
		_cached_cards_size = sz
		_cached_card_idx.clear()
		for i in range(sz):
			var cid: String = str(cards_arr[i].get("id", ""))
			if not _cached_card_idx.has(cid):
				_cached_card_idx[cid] = i
	elif sz > _cached_cards_size:
		for i in range(_cached_cards_size, sz):
			var cid: String = str(cards_arr[i].get("id", ""))
			if not _cached_card_idx.has(cid):
				_cached_card_idx[cid] = i
		_cached_cards_size = sz
	if _cached_card_idx.has(id):
		var hit_i: int = int(_cached_card_idx[id])
		if hit_i >= 0 and hit_i < sz and cards_arr[hit_i].get("id", "") == id:
			return cards_arr[hit_i]
	for i in range(sz):
		var card: Dictionary = cards_arr[i]
		if card.get("id", "") == id:
			_cached_card_idx[id] = i
			return card
	return {}

static func _curse_active_at(view: Dictionary, at) -> bool:
	var chrono: Dictionary = view.get("chronology", {})
	if not chrono.has("curse"):
		return false
	var curse: Dictionary = chrono.curse
	if curse.is_empty():
		return false
	var time: int = TimeModel.tick(at) if at is Dictionary else int(chrono.get("epochs", {}).get(at, -1))
	return time >= int(curse.from) and time < int(curse.until)

static func _position_code(pos: String) -> int:
	match pos:
		"evil":
			return 1
		"demon":
			return 2
		"minion":
			return 3
		"marked":
			return 4
		"unmarked":
			return 5
		_:
			return 0

static func _secret_mod_code(mod_name: String) -> int:
	match mod_name:
		"delusional":
			return 0
		"marked":
			return 1
		"lovers":
			return 2
		"sleepwalker":
			return 3
		"muddler":
			return 4
		_:
			return -99

static func selected(view: Dictionary, case_data: Dictionary) -> Array:
	# Semantic identity is independent of wrapper id and presentation venue.
	var cards: Array = []
	var keys: Array = []
	for id in case_data.cards:
		var card = card_by_id(view, id)
		if not card.is_empty() and semantic_key(card) not in keys:
			if id in case_data.get("quoted_cards", []):
				card = card.duplicate(true)
				card["quoted"] = true
			cards.append(card)
			keys.append(semantic_key(card))
	return cards

static func semantic_key(card: Dictionary) -> String:
	if card.has("fact_id"):
		return card.fact_id
	var data: Dictionary = card.get("data", {}).duplicate(true)
	for key in ["pair", "group", "seen", "trio"]:
		if data.has(key):
			data[key].sort()
	return JSON.stringify([card.get("kind"), card.get("source"), card.get("role"), card.get("observed_at"), data, card.get("subject"), card.get("block")])

static func analyze(view: Dictionary, case_data: Dictionary, knowledge: Dictionary = {}, include_conflicts: bool = true) -> Dictionary:
	case_data = Graph.compile_case(view, case_data)
	var cards = selected(view, case_data)
	if case_data.conclusion.type == "conflict":
		cards = cards.filter(func(c): return c.id in Graph.roots(case_data, case_data.conflict_scope) or c.id in knowledge.get("own_reports", []))
	var base = solve(view, cards, {}, {}, knowledge)
	var proposed_cards = TimeModel.hypothetical_cards(view, case_data, cards)
	var positions: Dictionary = case_data.positions.duplicate(true)
	var challenge_errors: Array = []
	for id in case_data.get("reading_challenges", {}):
		var mode: String = case_data.reading_challenges[id].get("mode", "")
		if mode in ["misled", "lying"]:
			var source: String = card_by_id(view, id).get("source", "")
			var assumed: String = "good" if mode == "misled" else "evil"
			var allowed: Array = ["good", "marked"] if mode == "misled" else ["evil", "demon", "minion"]
			if positions.get(source, assumed) not in allowed:
				challenge_errors.append("The selected reader alignment conflicts with the %s explanation." % mode.capitalize())
			else:
				positions[source] = positions.get(source, assumed)
	for pcard in cards:
		if pcard.get("kind") == "report" and pcard.get("role", "") == "psychologist" and not case_data.get("reading_challenges", {}).has(pcard.id):
			var pdata: Dictionary = pcard.get("data", {}) if pcard.get("data") is Dictionary else {}
			if str(pdata.get("mode", "")) == "pair" and pdata.get("statements") is Array and pdata.statements.size() == 2:
				var pans: Dictionary = case_data.get("answers", {}).get(pcard.id, {})
				var fslot: String = str(pans.get("false_slot", ""))
				var fwhy: String = str(pans.get("false_reason", ""))
				if fslot in ["0", "1"] and fwhy in ["misled", "lying"]:
					var st_sel: Dictionary = pdata.statements[int(fslot)]
					var t_src: String = str(st_sel.get("source", ""))
					if t_src != "":
						var p_assumed: String = "good" if fwhy == "misled" else "evil"
						var p_allowed: Array = ["good", "marked"] if fwhy == "misled" else ["evil", "demon", "minion"]
						if positions.get(t_src, p_assumed) not in p_allowed:
							challenge_errors.append("The selected speaker alignment conflicts with the Psychologist %s explanation." % fwhy.capitalize())
						else:
							positions[t_src] = positions.get(t_src, p_assumed)
	var proposed = solve(view, proposed_cards, positions, case_data.answers, knowledge, case_data.conclusion.at, case_data.get("temporal_positions", []))
	var errors = validate_answers(view, case_data) + case_data.get("graph_errors", [])
	errors.append_array(challenge_errors)
	var conclusion: Dictionary = case_data.conclusion
	if conclusion.type in ["evil", "good", "marked"] and not proposed.worlds.is_empty() and not proposed.worlds.any(func(w): return holds(view, w, conclusion)):
		errors.append("The conclusion contradicts every world allowed by these premises and choices.")
	var n = 0
	var alternative = {}
	for world in base.worlds:
		if holds(view, world, conclusion):
			n += 1
		elif alternative.is_empty():
			alternative = describe_world(view, world, conclusion.at)
	var status = "incomplete"
	if not errors.is_empty() or proposed.worlds.is_empty() or not proposed.movement_ok:
		status = "conflicting"
	elif proposed.worlds.size() == 1:
		status = "coherent"
	var entailment = "possible"
	if base.worlds.is_empty() or not base.movement_ok:
		entailment = "conflicting"
	elif conclusion.type == "conflict":
		entailment = "unsupported"
	elif n == base.worlds.size():
		entailment = "forced"
	elif n == 0:
		entailment = "unsupported"
	if conclusion.type == "conflict" and (base.worlds.is_empty() or not base.movement_ok):
		entailment = "forced"
	var conflicts: Array = []
	if include_conflicts and (base.worlds.is_empty() or not base.movement_ok):
		conflicts = minimal_conflicts(view, cards, knowledge)
	return {"status": status, "entailment": entailment, "compatible": base.worlds.size(), "supporting": n, "hypothetically_released": cards.filter(func(c): return c not in proposed_cards).map(func(c): return c.id),
		"proposed": proposed.worlds.size(), "alternative": alternative, "errors": errors,
		"movement": proposed.movement, "movement_ok": proposed.movement_ok,
		"assumptions": assumption_labels(view, cards), "unresolved": unresolved(view, proposed.worlds), "conflicts": conflicts}

static func minimal_conflicts(view: Dictionary, cards: Array, knowledge: Dictionary = {}) -> Array:
	var inputs = [_query_view(view), cards, _query_knowledge(knowledge)]
	var key = hash(inputs)
	if reuse_solves and conflict_cache.has(key) and conflict_cache[key].inputs == inputs:
		return conflict_cache[key].result
	# Shrink one conflict, then explore excluding each member to discover other cores.
	# This avoids enumerating every unrelated subset for a simple alibi conflict.
	var has_th: bool = cards.any(func(c): return c.kind == "town_hall")
	var conflict_kinds: Array = ["report", "claim", "town_hall", "sighting", "alibi", "totem", "dropped"] if has_th else ["report", "sighting", "alibi", "totem", "dropped"]
	cards = cards.filter(func(c): return c.kind in conflict_kinds)
	var result: Array = []
	_find_conflicts(view, cards, knowledge, result, {})
	if reuse_solves:
		if conflict_cache.size() >= 128:
			conflict_cache.erase(conflict_cache.keys()[0])
		conflict_cache[key] = {"inputs": inputs.duplicate(true), "result": result}
	return result

static func _find_conflicts(view: Dictionary, cards: Array, knowledge: Dictionary, result: Array, visited: Dictionary) -> void:
	var ids: Array = cards.map(func(c): return c.id)
	var key = str(ids)
	if visited.has(key):
		return
	visited[key] = true
	var solved = solve(view, cards, {}, {}, knowledge)
	if not solved.worlds.is_empty() and solved.movement_ok:
		return
	var core = cards.duplicate()
	for card in cards:
		var trial = core.filter(func(c): return c.id != card.id)
		var tested = solve(view, trial, {}, {}, knowledge)
		if tested.worlds.is_empty() or not tested.movement_ok:
			core = trial
	var conflict: Array = core.map(func(c): return c.id)
	if not result.has(conflict):
		result.append(conflict)
	for card in core:
		_find_conflicts(view, cards.filter(func(c): return c.id != card.id), knowledge, result, visited)

static func solve(view: Dictionary, cards: Array, positions: Dictionary = {}, answers: Dictionary = {}, knowledge: Dictionary = {}, epoch: String = "", temporal_positions: Array = []) -> Dictionary:
	var span = Profiler.open("constraint_solve")
	# Bounded search, per-person theories and diagnostic explanations repeatedly ask
	# exactly the same question. Cache complete public inputs, including chronology
	# and private knowledge; never a partial key that could reuse an older night.
	var inputs = [_query_view(view), cards, positions, answers, _query_knowledge(knowledge), epoch, temporal_positions]
	var key = hash(inputs)
	if reuse_solves and solve_cache.has(key) and solve_cache[key].inputs == inputs:
		Profiler.count("solve_cache_hit")
		var cached: Dictionary = solve_cache[key].result
		Profiler.close(span)
		return cached
	var st: int = SolverBackend.begin_stage("world_domain") if SolverBackend.profiling_enabled else -1
	var result = _solve(view, cards, positions, answers, knowledge, epoch, temporal_positions)
	if st >= 0:
		SolverBackend.end_stage(st)
	if reuse_solves:
		if solve_cache.size() >= 1024:
			solve_cache.erase(solve_cache.keys()[0])
		solve_cache[key] = {"inputs": inputs.duplicate(true), "result": result}
	Profiler.close(span)
	return result

## The explicit cards argument already contains the selected receipts. Unselected
## library cards and attention bookkeeping are not inputs to _solve, roles or routes;
## retaining them in keys prevented identical scoped/union questions from sharing.
static func _query_view(view: Dictionary) -> Dictionary:
	var result = view.duplicate()
	result.erase("cards")
	return result

static func _query_knowledge(knowledge: Dictionary) -> Dictionary:
	var result = knowledge.duplicate()
	result.erase("own_reports")
	result.erase("attention_reports")
	return result

## Every legal world for this view (cached). Shared by the solve and by CaseEval.
static func universe(view: Dictionary) -> Array:
	return universes[_universe_key(view)] if universes.has(_universe_key(view)) else _build_universe(view)

static func _universe_key(view: Dictionary) -> String:
	return str([person_ids(view), view.evil_count, view.get("chronology", {}), view.get("world_options", {})])

static func _build_universe(view: Dictionary) -> Array:
	var ids: Array = person_ids(view)
	var key = _universe_key(view)
	if universes.size() >= 16:
		universes.clear()
	var all_worlds: Array = []
	if Domain.live(view):
		all_worlds = Domain.worlds(view)
		if view.get("chronology", {}).has("curse"):
			var expanded: Array = []
			for world in all_worlds:
				for candidate in TimeModel.expand(view, world):
					candidate["__i"] = expanded.size()
					expanded.append(candidate)
			all_worlds = expanded
	else:
		for evil in range(1 << ids.size()):
			if popcount(evil) == view.evil_count:
				for marked in range(ids.size()):
					if not evil & (1 << marked):
						all_worlds.append_array(TimeModel.expand(view, {"evil": evil, "marked": marked}))
	universes[key] = all_worlds
	return all_worlds

## For one report (or curse event) card: a byte per universe world, 1 where the card's
## content holds as a healthy reading from a good source (cached by exact inputs).
## marked: answered "registered because Marked" (Dowser and Surveyor answers only).
static func report_table(view: Dictionary, card: Dictionary, positive: Array = [], positive_blocks: Array = [], marked: Array = []) -> PackedByteArray:
	if not SolverBackend.profiling_enabled:
		return _report_table_dispatch(view, card, positive, positive_blocks, marked)
	var st: int = SolverBackend.begin_stage("world_domain")
	var out: PackedByteArray = _report_table_dispatch(view, card, positive, positive_blocks, marked)
	SolverBackend.end_stage(st)
	return out

static func _report_table_dispatch(view: Dictionary, card: Dictionary, positive: Array, positive_blocks: Array, marked: Array) -> PackedByteArray:
	var universe_key = _universe_key(view)
	var u_worlds: Array = universe(view)
	positive = positive.duplicate()
	positive.sort()
	positive_blocks = positive_blocks.duplicate()
	positive_blocks.sort()
	marked = marked.duplicate()
	marked.sort()
	# Homes affect Surveyor blocks; kind/event distinguish public process cards.
	# Hashes accelerate lookup, but exact snapshots guard collisions and edits.
	var inputs = [universe_key, view.people, view.get("timeline", {}), card.kind, card.get("event", ""), card.get("source", ""),
		card.get("role", ""), card.get("observed_at", {}), card.get("data", {}), positive, positive_blocks, card.get("duty_only", false)]
	if not marked.is_empty():
		inputs.append(marked)
	if card.get("testimony_only", false):
		inputs.append([true, card.get("reported_at")])
	var key = hash(inputs)
	if not report_matches.has(key) or report_matches[key].inputs != inputs:
		if report_matches.size() > 512:
			report_matches.clear()
		var accepted: PackedByteArray = _report_table_cs(view, universe_key, u_worlds, card, positive, positive_blocks, marked)
		report_matches[key] = {"inputs": inputs.duplicate(true), "accepted": accepted}
	return report_matches[key].accepted

static func _report_table_cs(view: Dictionary, universe_key: String, u_worlds: Array, card: Dictionary, positive: Array, positive_blocks: Array, marked: Array) -> PackedByteArray:
	_ensure_people(view)
	var u_handle: int = SolverBackend.get_universe_handle(universe_key, u_worlds)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(u_worlds) if u_handle < 0 else PackedInt64Array()
	var n_people: int = _cached_ids.size()
	var is_live: bool = Domain.live(view)
	var c_kind: String = str(card.get("kind", ""))
	var kind_code: int = 1 if c_kind == "report" else (2 if (c_kind == "event" and card.get("event", "") == "curse") else 0)
	var testimony_only: bool = bool(card.get("testimony_only", false))
	var src_str: String = str(card.get("source", ""))
	var src_idx: int = person_index(view, src_str)
	var obs_at = card.get("observed_at", {})
	var gift_and_alive_ok: bool = true
	if kind_code == 1 and is_live and not testimony_only:
		gift_and_alive_ok = Domain._gift_time_gd(card) and History.observer_alive(view, src_str, obs_at)
	var role_str: String = str(card.get("role", ""))
	var conv_stmt: bool = _curse_active_at(view, TimeModel.statement_time(card)) if testimony_only else false
	var conv_obs: bool = _curse_active_at(view, {"day": int(obs_at.get("day", -1)), "phase": "afternoon"}) if role_str == "magistrate" else _curse_active_at(view, obs_at)

	var has_ans_pos: bool = not positive.is_empty()
	var ans_pos_mask: int = 0
	var ans_pos_unknown: bool = false
	for id in positive:
		var pi: int = person_index(view, str(id))
		if pi < 0:
			ans_pos_unknown = true
		else:
			ans_pos_mask |= (1 << pi)

	var req_marked := PackedInt32Array()
	req_marked.resize(marked.size())
	for mi in range(marked.size()):
		req_marked[mi] = person_index(view, str(marked[mi]))

	var chosen_block_masks := PackedInt32Array()
	var chosen_blocks_invalid: bool = false
	for blk in positive_blocks:
		if not _cached_block_masks.has(blk):
			chosen_blocks_invalid = true
		else:
			chosen_block_masks.append(int(_cached_block_masks[blk]))

	var all_block_masks := PackedInt32Array()
	var bm_vals: Array = _cached_block_masks.values()
	all_block_masks.resize(bm_vals.size())
	for bi in range(bm_vals.size()):
		all_block_masks[bi] = int(bm_vals[bi])

	var rdef = C.role_def(role_str)
	var data: Dictionary = card.get("data", {}) if card.get("data", {}) is Dictionary else {}
	var content_mode: int = 0
	var pair_or_group_mask: int = 0
	var target_or_secret: int = 0

	if kind_code == 1:
		var pre_fail: bool = false
		if role_str == "gravedigger" and view.has("timeline"):
			var gd_n: int = int(card.night) if int(card.get("night", -1)) >= 0 else int(obs_at.get("day", -1))
			if not History.executed(view, str(data.get("executed", "")), gd_n):
				pre_fail = true
		if not pre_fail and role_str == "executor":
			var ex_t_idx: int = person_index(view, str(data.get("target", "")))
			if ex_t_idx < 0 or (not testimony_only and src_idx >= 0 and ex_t_idx == src_idx):
				pre_fail = true
			elif data.has("role") and not bool(data.get("assigned", false)):
				if not C.ROLES.has(str(data.get("role", ""))) or (view.has("timeline") and not History.died_before_morning(view, str(data.get("target", "")), int(obs_at.get("day", -1)))):
					pre_fail = true
			elif not (bool(data.get("assigned", false)) and not data.has("role")):
				pre_fail = true
		if not pre_fail and role_str == "registrar":
			if not Roles._registrar_roles_ok(data.get("roles")):
				pre_fail = true
			elif data.has("target") or data.has("yes"):
				var rg_t_idx: int = person_index(view, str(data.get("target", "")))
				if not (data.has("target") and data.get("yes") is bool) or rg_t_idx < 0 or (not testimony_only and src_idx >= 0 and rg_t_idx == src_idx):
					pre_fail = true
		if not pre_fail and role_str == "magistrate":
			if not _magistrate_nomination_ok(view, card, not testimony_only):
				pre_fail = true
		if not pre_fail and role_str == "warden":
			var obs_day: int = int(obs_at.get("day", -1))
			var w_tgt: String = str(data.get("target", ""))
			if view.get("timeline", {}).get("events", []).any(func(ev): return ev.kind == "demon_death" and ev.at.day == obs_day and w_tgt in ev.subjects):
				pre_fail = true
				content_mode = 1  # the guarded door was killed that night: never a healthy reading
			elif bool(data.get("saved", false)):
				content_mode = 2
				target_or_secret = person_index(view, w_tgt)
			else:
				content_mode = 0
		elif pre_fail:
			content_mode = 1
		else:
			var handled: bool = false
			if is_live:
				if role_str == "medium" and bool(card.get("duty_only", false)):
					var dblock: String = str(data.get("block", ""))
					var m_night: int = int(card.get("night", -1))
					var has_corpse: bool = view.people.any(func(p): return p.home == dblock and not History.alive_at_night(view, p.id, m_night))
					content_mode = 0 if has_corpse else 1
					handled = true
				elif rdef != null and rdef.shape == "NIGHT_ROUTE":
					var nr_night: int = int(card.get("night", -1))
					if data.get("seen", []).any(func(sid): return not History.alive_at_night(view, sid, nr_night)):
						content_mode = 1
						handled = true
				elif role_str == "rumormonger":
					content_mode = 3
					for pid in data.get("pair", []):
						var p_i: int = person_index(view, str(pid))
						if p_i >= 0:
							pair_or_group_mask |= (1 << p_i)
					target_or_secret = _secret_mod_code(str(data.get("secret", "")))
					handled = true
			if not handled:
				if role_str == "rumormonger":
					content_mode = 4
					for pid in data.get("pair", []):
						var p_i: int = person_index(view, str(pid))
						if p_i >= 0:
							pair_or_group_mask |= (1 << p_i)
				elif role_str == "chronicler":
					var trio_arr = data.get("trio", [])
					var trio_m: int = 0
					var trio_ok: bool = trio_arr is Array and trio_arr.size() == 3
					if trio_ok:
						for pid in trio_arr:
							var p_i: int = person_index(view, str(pid))
							if p_i < 0 or (trio_m & (1 << p_i)) != 0:
								trio_ok = false
							else:
								trio_m |= (1 << p_i)
					if not trio_ok or (not testimony_only and src_idx >= 0 and (trio_m & (1 << src_idx)) != 0):
						content_mode = 1
					else:
						content_mode = 8
						pair_or_group_mask = trio_m
				elif role_str == "augur":
					content_mode = 9
					target_or_secret = 1 if bool(data.get("yes", false)) else 0
				elif role_str == "magistrate":
					var a_i: int = person_index(view, str(data.get("nominator", "")))
					var b_i: int = person_index(view, str(data.get("nominee", "")))
					content_mode = 7
					pair_or_group_mask = ((1 << a_i) if a_i >= 0 else 0) | ((1 << b_i) if b_i >= 0 else 0)
					target_or_secret = 1 if bool(data.get("same", false)) else 0
				else:
					var is_site_group: bool = rdef != null and rdef.shape == "ROLE_AT_SITE" and rdef.site_mode == "group_count" and rdef.site_group_key == "group"
					var is_surveyor: bool = rdef != null and rdef.shape == "GROUP_COUNT" and rdef.count_mode == "blocks"
					if is_site_group:
						content_mode = 5
						for pid in data.get(rdef.site_group_key, []):
							var p_i: int = person_index(view, str(pid))
							if p_i >= 0:
								pair_or_group_mask |= (1 << p_i)
						target_or_secret = int(data.get("count", 0))
					elif is_surveyor and data.has("block") and data.has("same"):
						var blk_s: String = str(data.get("block", ""))
						var b_mask_s: int = int(_cached_block_masks.get(blk_s, 0))
						if not _cached_block_masks.has(blk_s) or popcount(b_mask_s) < 2 or (not testimony_only and src_idx >= 0 and (b_mask_s & (1 << src_idx)) != 0):
							content_mode = 1
						else:
							content_mode = 7
							pair_or_group_mask = b_mask_s
							target_or_secret = 1 if bool(data.get("same", false)) else 0
					elif is_surveyor:
						content_mode = 6
						target_or_secret = int(data.get("count", 0))
					else:
						content_mode = 0
					if role_str not in CONTENT_ROLES and not testimony_only:
						content_mode = 0

	var pre_testim_fail: bool = false
	var testim_shape: int = 0
	var marked_reg: bool = false
	var testim_mask: int = 0
	var testim_secret_code: int = -99

	if testimony_only and kind_code == 1:
		if content_mode == 1:
			pre_testim_fail = true
		if role_str == "gravedigger" and view.has("timeline"):
			var gd_nt: int = int(card.night) if int(card.get("night", -1)) >= 0 else int(obs_at.get("day", -1))
			if not History.executed(view, str(data.get("executed", "")), gd_nt):
				pre_testim_fail = true
		var pair_t: int = 0
		for pid in data.get("pair", []):
			var p_i: int = person_index(view, str(pid))
			if p_i >= 0:
				pair_t |= (1 << p_i)
		if rdef != null and rdef.shape == "ROLE_IN_GROUP":
			if rdef.role_group_key == "pair":
				testim_mask = pair_t
			else:
				var g_i: int = person_index(view, str(data.get(rdef.role_group_key, "")))
				testim_mask = (1 << g_i) if g_i >= 0 else 0
			match rdef.role_target_pool:
				"good":
					testim_shape = 1
				"minion":
					testim_shape = 2
				_:
					var named_align: String = str(C.ROLES.get(str(data.get("role", "")), {}).get("align", ""))
					testim_shape = 3 if named_align == "evil" else 4
					marked_reg = bool(rdef.marked_registers)
		elif rdef != null and rdef.shape == "PING":
			testim_mask = pair_t
			testim_shape = 5 if bool(data.get("yes", false)) else 6
		elif rdef != null and rdef.shape == "SECRET_PAIR":
			testim_mask = pair_t
			testim_secret_code = _secret_mod_code(str(data.get("secret", "")))
			testim_shape = 7
		elif role_str == "executor":
			var ex_ti: int = person_index(view, str(data.get("target", "")))
			if ex_ti < 0:
				pre_testim_fail = true
			elif data.has("role") and not bool(data.get("assigned", false)):
				testim_mask = 1 << ex_ti
				var ex_align: String = str(C.ROLES.get(str(data.get("role", "")), {}).get("align", ""))
				testim_shape = 3 if ex_align == "evil" else 4
				marked_reg = true
			else:
				testim_shape = 0
		elif role_str == "registrar":
			if data.has("target"):
				var rg_ti: int = person_index(view, str(data.get("target", "")))
				if rg_ti < 0:
					pre_testim_fail = true
				elif bool(data.get("yes", false)):
					testim_mask = 1 << rg_ti
					var rg_has_min: bool = data.get("roles", []).any(func(r): return C.is_minion(str(r)))
					testim_shape = 6 if rg_has_min else 4
				else:
					testim_shape = 0
			else:
				testim_shape = 0
		else:
			testim_shape = 0

	var spec := PackedInt32Array([
		kind_code,
		1 if testimony_only else 0,
		src_idx,
		1 if gift_and_alive_ok else 0,
		1 if conv_stmt else 0,
		1 if conv_obs else 0,
		content_mode,
		pair_or_group_mask,
		target_or_secret,
		1 if has_ans_pos else 0,
		ans_pos_mask,
		1 if ans_pos_unknown else 0,
		1 if chosen_blocks_invalid else 0,
		1 if pre_testim_fail else 0,
		testim_shape,
		1 if marked_reg else 0,
		testim_mask,
		testim_secret_code,
	])
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("Solver.report_table", pack_u)
	return SolverBackend._bridge().SolverReportTable(u_handle, fallback, n_people, is_live, spec, req_marked, chosen_block_masks, all_block_masks)

## A world's key without the demon's identity. Report contents and source validity
## never read it, so worlds differing only there share one answer. -1: no key.
static func content_sig(view: Dictionary, world: Dictionary) -> int:
	if world.has("converted"):
		return int(world.get("__i", -1)) # Source validity now depends on the turnee.
	if not world.has("__key"):
		return -1
	if world.has("demon"):
		return int(world.__key) / (view.people.size() + 1)
	return int(world.__key)

## Roles whose report content can fail in a world (the rest only need a valid source).
const CONTENT_ROLES = ["surveyor", "dowser", "rumormonger", "nightwatch", "warden", "medium", "gravedigger", "chronicler", "augur", "magistrate", "executor", "registrar"]

static var _bits: Dictionary = {}

## Per universe: each world's evil bits and Delusional holders' bits, and whether any
## world has a conversion history (fixture curse worlds).
static func world_bits(view: Dictionary) -> Dictionary:
	var key = _universe_key(view)
	if _bits.has(key):
		return _bits[key]
	if _bits.size() > 16:
		_bits.clear()
	var st: int = SolverBackend.begin_stage("world_domain") if SolverBackend.profiling_enabled else -1
	var u_worlds: Array = universe(view)
	var out: Dictionary = _world_bits_cs(key, u_worlds)
	if st >= 0:
		SolverBackend.end_stage(st)
	_bits[key] = out
	return out

static func _world_bits_cs(u_key: String, u_worlds: Array) -> Dictionary:
	var u_handle: int = SolverBackend.get_universe_handle(u_key, u_worlds)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(u_worlds) if u_handle < 0 else PackedInt64Array()
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("Solver.world_bits", pack_u)
	var raw: PackedInt64Array = SolverBackend._bridge().SolverWorldBits(u_handle, fallback)
	var n: int = u_worlds.size()
	return {
		"evil": raw.slice(1, 1 + n),
		"deluded": raw.slice(1 + n, 1 + 2 * n),
		"plain": raw[0] != 0,
	}

## source_valid for every world of the universe.
static func valid_table(view: Dictionary, card: Dictionary) -> PackedByteArray:
	if not SolverBackend.profiling_enabled:
		return _valid_table_dispatch(view, card)
	var st: int = SolverBackend.begin_stage("world_domain")
	var out: PackedByteArray = _valid_table_dispatch(view, card)
	SolverBackend.end_stage(st)
	return out

static func _valid_table_dispatch(view: Dictionary, card: Dictionary) -> PackedByteArray:
	var u_key: String = _universe_key(view)
	var u_worlds: Array = universe(view)
	return _valid_table_cs(view, u_key, u_worlds, card)

static func _valid_table_cs(view: Dictionary, u_key: String, u_worlds: Array, card: Dictionary) -> PackedByteArray:
	var u_handle: int = SolverBackend.get_universe_handle(u_key, u_worlds)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(u_worlds) if u_handle < 0 else PackedInt64Array()
	var n_people: int = person_ids(view).size()
	var is_live: bool = Domain.live(view)
	var kind_code: int = 1 if card.get("kind", "") == "report" else 0
	var testimony_only: bool = bool(card.get("testimony_only", false))
	var src_str: String = str(card.get("source", ""))
	var src_idx: int = person_index(view, src_str)
	var obs_at = card.get("observed_at", {})
	var gift_ok: bool = true
	if kind_code == 1 and is_live and not testimony_only:
		gift_ok = Domain._gift_time_gd(card) and History.observer_alive(view, src_str, obs_at)
	var conv_check: bool = _curse_active_at(view, TimeModel.statement_time(card) if testimony_only else obs_at)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("Solver.valid_table", pack_u)
	return SolverBackend._bridge().SolverValidTable(u_handle, fallback, n_people, is_live, kind_code, testimony_only, src_idx, gift_ok, conv_check)

static var _sig_groups: Dictionary = {}

## Per universe: worlds grouped by content_sig (dense ids, one representative each).
## Worlds without a key get a group of their own.
static func sig_groups(view: Dictionary) -> Dictionary:
	var key = _universe_key(view)
	if _sig_groups.has(key):
		return _sig_groups[key]
	if _sig_groups.size() > 16:
		_sig_groups.clear()
	var st: int = SolverBackend.begin_stage("world_domain") if SolverBackend.profiling_enabled else -1
	var u_worlds: Array = universe(view)
	var out: Dictionary = _sig_groups_cs(view, key, u_worlds)
	if st >= 0:
		SolverBackend.end_stage(st)
	_sig_groups[key] = out
	return out

static func _sig_groups_cs(view: Dictionary, u_key: String, u_worlds: Array) -> Dictionary:
	var u_handle: int = SolverBackend.get_universe_handle(u_key, u_worlds)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(u_worlds) if u_handle < 0 else PackedInt64Array()
	var n_people: int = person_ids(view).size()
	var is_live: bool = Domain.live(view)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("Solver.sig_groups", pack_u)
	var raw: PackedInt32Array = SolverBackend._bridge().SolverSigGroups(u_handle, fallback, n_people, is_live)
	var r_len: int = raw[0]
	return {
		"rep": raw.slice(1, 1 + r_len),
		"of": raw.slice(1 + r_len),
	}

## Whether a card is constrained by a report table (reports, and the curse event).
static func tabled(card: Dictionary) -> bool:
	return card.kind == "report" or (card.kind == "event" and card.get("event") == "curse")

## The source-side conditions of _report_holds: a good, healthy source able to read then.
## Where this fails, the report says nothing about the world (CaseEval: likelihood q).
static func source_valid(view: Dictionary, world: Dictionary, card: Dictionary) -> bool:
	if card.kind != "report":
		return true
	if card.get("testimony_only", false):
		return not TimeModel.evil_at(view, world, card.source, TimeModel.statement_time(card))
	if TimeModel.evil_at(view, world, card.source, card.observed_at):
		return false
	if Domain.live(view):
		if not Domain.healthy(view, world, card.source) or not Domain.gift_time(card):
			return false
		if not History.observer_alive(view, card.source, card.observed_at):
			return false
	return true

static func _solve(view: Dictionary, cards: Array, positions: Dictionary = {}, answers: Dictionary = {}, knowledge: Dictionary = {}, epoch: String = "", temporal_positions: Array = []) -> Dictionary:
	if not positions.is_empty() or not temporal_positions.is_empty():
		# Candidate theories differ only in position filters. Reports, roles and routes
		# do not read those filters, so compute their common surviving worlds once.
		var base = solve(view, cards, {}, answers, knowledge, epoch)
		return {"worlds": _positions(view, base.worlds, positions, epoch, temporal_positions),
			"movement": base.movement, "movement_ok": base.movement_ok}
	var u_key: String = _universe_key(view)
	var u_worlds: Array = universe(view)
	var tables: Array = []
	for card in cards:
		if not tabled(card):
			continue
		tables.append(report_table(view, card, answers.get(card.id, {}).get("positive", []), answers.get(card.id, {}).get("blocks", []), answers.get(card.id, {}).get("marked", [])))

	var claims_ok: bool = not Domain.live(view) or Domain.claims_compatible(cards, knowledge)
	var worlds: Array = []
	var surviving_indices := PackedInt32Array()
	var u_handle: int = SolverBackend.get_universe_handle(u_key, u_worlds)

	if claims_ok:
		surviving_indices = _filter_candidates_cs(view, u_worlds, u_handle, tables, positions, knowledge, epoch, temporal_positions)
		worlds.resize(surviving_indices.size())
		for k_i in range(surviving_indices.size()):
			worlds[k_i] = u_worlds[surviving_indices[k_i]]

	var movement_cards: Array = cards.filter(func(c): return c.kind in ["sighting", "alibi"] or (c.kind == "report" and c.get("role", "") in ["nightwatch", "lamplighter"]))
	if view.get("world_options", {}).get("roles", false) and not worlds.is_empty():
		# One role table for the surviving worlds (same answers as fits per world).
		var fit: PackedByteArray = Roles.fits_table(view, worlds, cards, knowledge, answers, false, u_handle, surviving_indices)
		var kept: Array = []
		for i in range(worlds.size()):
			if fit[i] == 1:
				kept.append(worlds[i])
		worlds = kept
	if not worlds.is_empty():
		var active_fids: Dictionary = {}
		for c_act in cards:
			if not c_act.get("quoted", false):
				active_fids[str(c_act.get("fact_id", c_act.id))] = true
				active_fids[str(c_act.id)] = true
		for ac in cards:
			if ac.kind == "report" and ac.get("role", "") == "augur" and not ac.get("quoted", false) and not ac.get("testimony_only", false):
				var aspec: Dictionary = augur_day_spec(view, cards, ac, answers.get(ac.id, {}))
				if aspec.has_day_evidence or aspec.picked_idx >= 0:
					worlds = worlds.filter(func(w): return not source_valid(view, w, ac) or augur_world_outcome_prob(w, aspec) > 0.0)
			elif ac.kind == "report" and ac.get("role", "") == "psychologist" and not ac.get("quoted", false) and not ac.get("testimony_only", false):
				var pdata_s: Dictionary = ac.get("data", {}) if ac.get("data") is Dictionary else {}
				if str(pdata_s.get("mode", "")) == "pair" and pdata_s.get("statements") is Array and pdata_s.statements.size() == 2:
					var fid0: String = str(pdata_s.statements[0].get("fact_id", ""))
					var fid1: String = str(pdata_s.statements[1].get("fact_id", ""))
					if fid0 != "" and fid1 != "" and active_fids.has(fid0) and active_fids.has(fid1):
						worlds = worlds.filter(func(w): return not source_valid(view, w, ac))
					var pans_s: Dictionary = answers.get(ac.id, {})
					if str(pans_s.get("false_slot", "")) in ["0", "1"] and str(pans_s.get("false_reason", "")) == "misled":
						var st_m: Dictionary = pdata_s.statements[int(str(pans_s.get("false_slot", "0")))]
						if str(st_m.get("kind", "")) == "alibi" and Domain.live(view) and "sleepwalker" in view.get("world_options", {}).get("modifiers", []):
							var sw_idx: int = person_index(view, str(st_m.get("source", "")))
							if sw_idx >= 0:
								worlds = worlds.filter(func(w): return w.get("modifier", "") == "sleepwalker" and (int(w.get("holders", 0)) & (1 << sw_idx)) != 0)
	var movement = movement_for(view, cards if view.get("live_activity", false) else movement_cards, answers, knowledge)
	return {"worlds": worlds, "movement": movement.nights, "movement_ok": movement.okay}

static func _filter_candidates_cs(view: Dictionary, u_worlds: Array, u_handle: int, tables: Array, positions: Dictionary, knowledge: Dictionary, epoch: String, temporal_positions: Array) -> PackedInt32Array:
	var n: int = u_worlds.size()
	if n == 0:
		return PackedInt32Array()
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(u_worlds) if u_handle < 0 else PackedInt64Array()
	var has_curse: bool = view.get("chronology", {}).has("curse")
	var must_be_good: int = 0
	var must_be_evil: int = 0
	var marked_req: int = -2
	var pos_specs := PackedInt32Array()
	var eff_epoch = view.get("alignment_epoch", "") if epoch == "" else epoch
	var conv_eff_epoch: bool = _curse_active_at(view, eff_epoch)

	if not has_curse and temporal_positions.is_empty():
		for id in knowledge.get("good", []):
			var idx: int = person_index(view, str(id))
			if idx >= 0:
				must_be_good |= (1 << idx)
		for id in positions:
			var idx: int = person_index(view, str(id))
			var pv: String = str(positions[id])
			if idx < 0:
				if pv in ["evil", "marked", "unmarked"]:
					return PackedInt32Array()
				continue
			if pv == "good":
				must_be_good |= (1 << idx)
			elif pv == "evil":
				must_be_evil |= (1 << idx)
			elif pv == "marked":
				if marked_req >= 0 and marked_req != idx:
					return PackedInt32Array()
				marked_req = idx
			else:
				pos_specs.append(idx)
				pos_specs.append(_position_code(pv))
				pos_specs.append(1 if conv_eff_epoch else 0)
	else:
		var good_ep = knowledge.get("good_epoch", epoch)
		var eff_good_ep = view.get("alignment_epoch", "") if good_ep == "" else good_ep
		var conv_good_ep: bool = _curse_active_at(view, eff_good_ep)
		for id in knowledge.get("good", []):
			pos_specs.append(person_index(view, str(id)))
			pos_specs.append(0)
			pos_specs.append(1 if conv_good_ep else 0)
		for id in positions:
			pos_specs.append(person_index(view, str(id)))
			pos_specs.append(_position_code(str(positions[id])))
			pos_specs.append(1 if conv_eff_epoch else 0)
		for assignment in temporal_positions:
			var conv_assn: bool = _curse_active_at(view, assignment.at)
			for id in assignment.positions:
				pos_specs.append(person_index(view, str(id)))
				pos_specs.append(_position_code(str(assignment.positions[id])))
				pos_specs.append(1 if conv_assn else 0)

	var tg_specs := PackedInt32Array()
	for fact in knowledge.get("timed_good", []):
		tg_specs.append(person_index(view, str(fact.person)))
		tg_specs.append(1 if _curse_active_at(view, fact.at) else 0)

	var t_count: int = tables.size()
	var flat_tables := PackedByteArray()
	if t_count == 1:
		flat_tables = tables[0]
	elif t_count > 1:
		for tab in tables:
			flat_tables.append_array(tab)

	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("Solver.filter_candidates", pack_u)
	return SolverBackend._bridge().SolverFilterCandidates(u_handle, fallback, t_count, flat_tables, must_be_good, must_be_evil, marked_req, pos_specs, tg_specs)

static func _positions(view: Dictionary, worlds: Array, positions: Dictionary, epoch: String, temporal: Array) -> Array:
	if worlds.is_empty():
		return []
	if worlds.size() < 64:
		return _positions_gd(view, worlds, positions, epoch, temporal)  # small sets: cheaper than a crossing
	var cs_kept_idx: PackedInt32Array = _positions_cs_indices(view, worlds, positions, epoch, temporal)
	var cs_worlds: Array = []
	cs_worlds.resize(cs_kept_idx.size())
	for k_i in range(cs_kept_idx.size()):
		cs_worlds[k_i] = worlds[cs_kept_idx[k_i]]
	return cs_worlds

static func _positions_gd(view: Dictionary, worlds: Array, positions: Dictionary, epoch: String, temporal: Array) -> Array:
	if view.get("chronology", {}).has("curse") or not temporal.is_empty():
		for id in positions:
			worlds = worlds.filter(func(w): return position_holds(view, w, id, positions[id], epoch))
		for assignment in temporal:
			for id in assignment.positions:
				worlds = worlds.filter(func(w): return position_holds(view, w, id, assignment.positions[id], assignment.at))
		return worlds
	var good = 0
	var evil = 0
	var marked = -2
	var other: Array = []
	for id in positions:
		var index = person_index(view, id)
		if index < 0:
			if positions[id] in ["evil", "marked", "unmarked"]:
				return []
			continue
		match positions[id]:
			"good": good |= 1 << index
			"evil": evil |= 1 << index
			"marked":
				if marked >= 0 and marked != index:
					return []
				marked = index
			_: other.append(id)
	worlds = worlds.filter(func(w): return not (w.evil & good) and (w.evil & evil) == evil and (marked < 0 or w.marked == marked))
	for id in other:
		worlds = worlds.filter(func(w): return position_holds(view, w, id, positions[id], epoch))
	return worlds

static func _positions_cs_indices(view: Dictionary, worlds: Array, positions: Dictionary, epoch: String, temporal: Array) -> PackedInt32Array:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var u_key: String = _universe_key(view)
	var u_worlds: Array = universe(view)
	var u_handle: int = SolverBackend.get_universe_handle(u_key, u_worlds)
	var sub_idx := PackedInt32Array()
	var fallback := PackedInt64Array()
	var can_index: bool = u_handle >= 0 and worlds.all(func(w): return w.has("__i"))
	if can_index:
		sub_idx.resize(worlds.size())
		for i in range(worlds.size()):
			sub_idx[i] = int(worlds[i]["__i"])
	else:
		u_handle = -1
		fallback = SolverBackend.pack_worlds(worlds)

	var has_curse: bool = view.get("chronology", {}).has("curse")
	var must_good: int = 0
	var must_evil: int = 0
	var marked_req: int = -2
	var pos_specs := PackedInt32Array()
	var eff_epoch = view.get("alignment_epoch", "") if epoch == "" else epoch
	var conv_eff: bool = _curse_active_at(view, eff_epoch)

	if has_curse or not temporal.is_empty():
		for id in positions:
			pos_specs.append(person_index(view, str(id)))
			pos_specs.append(_position_code(str(positions[id])))
			pos_specs.append(1 if conv_eff else 0)
		for assignment in temporal:
			var conv_a: bool = _curse_active_at(view, assignment.at)
			for id in assignment.positions:
				pos_specs.append(person_index(view, str(id)))
				pos_specs.append(_position_code(str(assignment.positions[id])))
				pos_specs.append(1 if conv_a else 0)
	else:
		for id in positions:
			var idx: int = person_index(view, str(id))
			var pv: String = str(positions[id])
			if idx < 0:
				if pv in ["evil", "marked", "unmarked"]:
					return PackedInt32Array()
				continue
			match pv:
				"good":
					must_good |= (1 << idx)
				"evil":
					must_evil |= (1 << idx)
				"marked":
					if marked_req >= 0 and marked_req != idx:
						return PackedInt32Array()
					marked_req = idx
				_:
					pos_specs.append(idx)
					pos_specs.append(_position_code(pv))
					pos_specs.append(1 if conv_eff else 0)

	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("Solver.filter_positions", pack_u)
	return SolverBackend._bridge().SolverFilterPositions(u_handle, sub_idx, fallback, must_good, must_evil, marked_req, pos_specs)

static func movement_for(view: Dictionary, cards: Array, answers: Dictionary = {}, knowledge: Dictionary = {}) -> Dictionary:
	if Activity.available(view):
		return Activity.routes(view, cards, answers, knowledge)
	var ids: Array = view.people.map(func(p): return p.id)
	var movement_cards: Array = cards.filter(func(c): return c.kind in ["sighting", "alibi"] or (c.kind == "report" and c.get("role", "") in ["nightwatch", "lamplighter"]))
	var movement_key = JSON.stringify([ids, movement_cards, answers, knowledge])
	if not movement_cache.has(movement_key):
		if movement_cache.size() > 256:
			movement_cache.clear()
		movement_cache[movement_key] = _movement(view, movement_cards, answers, knowledge)
	return movement_cache[movement_key]

static func popcount(bits: int) -> int:
	var count = 0
	while bits:
		bits &= bits - 1
		count += 1
	return count

static func position_holds(view: Dictionary, world: Dictionary, id: String, position: String, epoch: String = "") -> bool:
	if position in ["demon", "minion"]:
		var i: int = person_index(view, id)
		return i >= 0 and (world.get("demon", -1) == i if position == "demon" else ((world.evil & (1 << i)) != 0 and world.get("demon", -1) != i))
	if position in ["marked", "unmarked"]:
		var index: int = person_index(view, id)
		if index < 0:
			return false
		return world.marked == index if position == "marked" else world.marked != index
	var evil: bool = TimeModel.evil_at(view, world, id, view.alignment_epoch if epoch == "" else epoch)
	return evil if position == "evil" else not evil

static func _report_holds(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	_ensure_people(view)
	if card.kind == "event" and card.get("event") == "curse":
		return answer.get("positive", []).is_empty() or view.people[world.get("converted", -1)].id in answer.positive
	if card.kind != "report":
		return true
	if card.get("testimony_only", false):
		return source_valid(view, world, card) and _testimony_content(view, world, card)
	# An accepted healthy gift assumes a good source at the reading's time.
	return source_valid(view, world, card) and _report_content(view, world, card, answer)

## Cheap compatibility of the recounted content, with no anonymous role holder.
## This is weak testimony, not a faithful original reading or a role proof.
static func _testimony_content(view: Dictionary, world: Dictionary, card: Dictionary) -> bool:
	_ensure_people(view)
	var data: Dictionary = card.data
	var pair = 0
	for person in data.get("pair", []):
		pair |= 1 << person_index(view, person)
	var evil: int = world.evil
	if world.has("converted") and TimeModel.evil_index(view, world, world.converted, card.observed_at):
		evil |= 1 << int(world.converted)
	if card.role == "gravedigger" and view.has("timeline"):
		var gd_night_t: int = card.night if int(card.get("night", -1)) >= 0 else int(card.get("observed_at", {}).get("day", -1))
		if not History.executed(view, str(data.get("executed", "")), gd_night_t):
			return false
	var rdef = C.role_def(card.role)
	if rdef != null and rdef.shape == "ROLE_IN_GROUP":
		var group_mask: int = pair if rdef.role_group_key == "pair" else (1 << person_index(view, data.get(rdef.role_group_key, "")))
		match rdef.role_target_pool:
			"good":
				return (group_mask & ~world.evil) != 0
			"minion":
				return (group_mask & world.evil & ~(1 << int(world.get("demon", -1)))) != 0
			_:
				var reads_evil: bool = (world.evil & group_mask) != 0 or (rdef.marked_registers and world.marked >= 0 and (group_mask & (1 << world.marked)) != 0)
				return reads_evil if Domain.C.ROLES.get(data.role, {}).get("align") == "evil" else (world.evil & group_mask) == 0
	if rdef != null and rdef.shape == "PING":
		var demon: bool = world.get("demon", -1) >= 0 and (pair & (1 << int(world.demon))) != 0
		return demon or (pair & ~evil) != 0 if data.yes else not demon
	if rdef != null and rdef.shape == "SECRET_PAIR":
		return world.get("modifier", "marked") == data.secret and (int(world.get("holders", 1 << world.marked)) & pair) != 0
	if card.role == "executor":
		var ex_ti_gd: int = person_index(view, str(data.get("target", "")))
		if ex_ti_gd < 0:
			return false
		if data.has("role") and not bool(data.get("assigned", false)):
			if not C.ROLES.has(str(data.get("role", ""))) or (view.has("timeline") and not History.died_before_morning(view, str(data.get("target", "")), int(card.get("observed_at", {}).get("day", -1)))):
				return false
			var ex_mask_gd: int = 1 << ex_ti_gd
			var ex_reads_ev: bool = (world.evil & ex_mask_gd) != 0 or (world.marked >= 0 and world.marked == ex_ti_gd)
			return ex_reads_ev if Domain.C.ROLES.get(str(data.get("role", "")), {}).get("align") == "evil" else (world.evil & ex_mask_gd) == 0
		return bool(data.get("assigned", false)) and not data.has("role")
	if card.role == "registrar":
		if not Roles._registrar_roles_ok(data.get("roles")):
			return false
		if not data.has("target") and not data.has("yes"):
			return true
		if not (data.has("target") and data.get("yes") is bool):
			return false
		var rg_ti_gd: int = person_index(view, str(data.get("target", "")))
		if rg_ti_gd < 0:
			return false
		if bool(data.get("yes", false)):
			var rg_has_min_gd: bool = data.get("roles", []).any(func(r): return C.is_minion(str(r)))
			if rg_has_min_gd:
				return not (world.get("demon", -1) >= 0 and int(world.demon) == rg_ti_gd)
			return (world.evil & (1 << rg_ti_gd)) == 0
		return true
	return _report_content_impl(view, world, card, {}, true)

static func _magistrate_nomination_ok(view: Dictionary, card: Dictionary, check_source: bool) -> bool:
	_ensure_people(view)
	var d: Dictionary = card.get("data", {}) if card.get("data", {}) is Dictionary else {}
	var nom_a: String = str(d.get("nominator", ""))
	var nom_b: String = str(d.get("nominee", ""))
	var a_i: int = person_index(view, nom_a)
	var b_i: int = person_index(view, nom_b)
	if a_i < 0 or b_i < 0 or a_i == b_i:
		return false
	var src: String = str(card.get("source", ""))
	if check_source and nom_a == src:
		return false
	if not view.has("timeline"):
		return true
	var obs_day: int = int(card.get("observed_at", {}).get("day", -1))
	var events: Array = view.get("timeline", {}).get("events", [])
	var has_day_record: bool = events.any(func(ev): return int(ev.get("at", {}).get("day", -1)) == obs_day and ev.get("kind", "") in ["nomination", "meeting"])
	if not has_day_record:
		return true
	if check_source:
		for ev in events:
			if ev.get("kind", "") != "nomination" or int(ev.get("at", {}).get("day", -1)) != obs_day:
				continue
			var by: String = str(ev.get("by", ""))
			var subs: Array = ev.get("subjects", [])
			var tgt: String = str(subs[0]) if not subs.is_empty() else ""
			if by == "" or by == "player" or by == src or tgt == "" or tgt == by:
				continue
			if person_index(view, by) >= 0 and person_index(view, tgt) >= 0:
				return by == nom_a and tgt == nom_b
		return false
	# Testimony-only (unnamed Magistrate): valid if some non-nominator townsperson sees (nom_a, nom_b) first.
	for cand in _cached_ids:
		if cand == nom_a:
			continue
		var matched: bool = false
		var seen_first: bool = false
		for ev in events:
			if ev.get("kind", "") != "nomination" or int(ev.get("at", {}).get("day", -1)) != obs_day:
				continue
			var by2: String = str(ev.get("by", ""))
			var subs2: Array = ev.get("subjects", [])
			var tgt2: String = str(subs2[0]) if not subs2.is_empty() else ""
			if by2 == "" or by2 == "player" or by2 == cand or tgt2 == "" or tgt2 == by2:
				continue
			if person_index(view, by2) >= 0 and person_index(view, tgt2) >= 0:
				seen_first = true
				matched = (by2 == nom_a and tgt2 == nom_b)
				break
		if seen_first and matched:
			return true
	return false

static func augur_slot_prob(codes: int, idx: int) -> float:
	if idx < 0:
		return 0.0
	match (codes >> (idx * 2)) & 3:
		0:
			return 0.0
		1:
			return 0.1875
		2:
			return 0.25
		_:
			return 1.0

static func augur_day_spec(view: Dictionary, cards: Array, augur_card: Dictionary, answer: Dictionary = {}) -> Dictionary:
	_ensure_people(view)
	var ids: Array = _cached_ids
	var n: int = ids.size()
	var src: String = str(augur_card.get("source", ""))
	var src_idx: int = person_index(view, src)
	var day_num: int = int(augur_card.get("observed_at", {}).get("day", -1))
	var yes: bool = bool(augur_card.get("data", {}).get("yes", false))
	var pos_arr: Array = answer.get("positive", [])
	var picked_idx: int = person_index(view, str(pos_arr[0])) if not pos_arr.is_empty() else -1
	var slot_codes: Array = [0, 0]
	var has_day_evidence: bool = false
	var phases: Array = ["morning", "afternoon"]
	for s_i in range(2):
		var ph_name: String = phases[s_i]
		var known_blk: Array = []
		var alive_slot: Array = []
		known_blk.resize(n)
		alive_slot.resize(n)
		for j in range(n):
			alive_slot[j] = History.observer_alive(view, ids[j], {"day": day_num, "phase": ph_name})
			known_blk[j] = ""
		for c in cards:
			if c.get("quoted", false):
				continue
			var ck: String = str(c.get("kind", ""))
			if ck == "location" and int(c.get("day", c.get("observed_at", {}).get("day", -1))) == day_num and str(c.get("observed_at", {}).get("phase", "")) == ph_name:
				var blk: String = str(c.get("block", ""))
				if blk in C.BLOCKS:
					for who in c.get("subjects", [c.get("subject", "")]):
						var w_i: int = person_index(view, str(who))
						if w_i >= 0 and alive_slot[w_i]:
							if known_blk[w_i] == "":
								known_blk[w_i] = blk
							elif known_blk[w_i] != blk:
								known_blk[w_i] = "?"
			elif ck == "context" and str(c.get("context_kind", "")) == "work":
				var subj_i: int = person_index(view, str(c.get("subject", "")))
				if subj_i >= 0 and alive_slot[subj_i] and s_i in c.get("data", {}).get("work_phases", []):
					var wloc: String = str(c.get("data", {}).get("loc", ""))
					var wblk: String = str(c.get("block", C.loc_block(wloc) if wloc in C.LOCATIONS else ""))
					if wblk in C.BLOCKS:
						if known_blk[subj_i] == "":
							known_blk[subj_i] = wblk
						elif known_blk[subj_i] != wblk:
							known_blk[subj_i] = "?"
		for j in range(n):
			if known_blk[j] == "?":
				known_blk[j] = ""
			elif known_blk[j] != "":
				has_day_evidence = true
		var aug_blk: String = known_blk[src_idx] if (src_idx >= 0 and src_idx < n) else ""
		var packed_s: int = 0
		for j in range(n):
			var code: int = 0
			if j == src_idx or not alive_slot[j]:
				code = 0
			elif aug_blk != "" and known_blk[j] != "":
				code = 3 if known_blk[j] == aug_blk else 0
			elif aug_blk != "" or known_blk[j] != "":
				code = 2
			else:
				code = 1
			if j != src_idx and code != 1:
				has_day_evidence = true
			packed_s |= (code << (j * 2))
		slot_codes[s_i] = packed_s
	var p_ref: float = (87.0 / 256.0) if yes else (169.0 / 256.0)
	return {
		"src_idx": src_idx,
		"day": day_num,
		"yes": yes,
		"picked_idx": picked_idx,
		"slot0_codes": int(slot_codes[0]),
		"slot1_codes": int(slot_codes[1]),
		"has_day_evidence": has_day_evidence,
		"p_ref": p_ref,
	}

static func augur_world_outcome_prob(world: Dictionary, spec: Dictionary) -> float:
	var src_idx: int = int(spec.src_idx)
	var d_idx: int = int(world.get("demon", -1))
	if src_idx >= 0 and d_idx == src_idx:
		return 0.0
	var picked_idx: int = int(spec.get("picked_idx", -1))
	if picked_idx >= 0:
		if augur_slot_prob(int(spec.slot0_codes), picked_idx) <= 0.0 and augur_slot_prob(int(spec.slot1_codes), picked_idx) <= 0.0:
			return 0.0
	var m_idx: int = int(world.get("marked", -1))
	var dp0: float = augur_slot_prob(int(spec.slot0_codes), d_idx)
	var dp1: float = augur_slot_prob(int(spec.slot1_codes), d_idx)
	var mp0: float = augur_slot_prob(int(spec.slot0_codes), m_idx) if (m_idx >= 0 and m_idx != src_idx) else 0.0
	var mp1: float = augur_slot_prob(int(spec.slot1_codes), m_idx) if (m_idx >= 0 and m_idx != src_idx) else 0.0
	var trig0: float = 1.0 - (1.0 - dp0) * (1.0 - 0.5 * mp0)
	var trig1: float = 1.0 - (1.0 - dp1) * (1.0 - 0.5 * mp1)
	var p_yes: float = 1.0 - (1.0 - trig0) * (1.0 - trig1)
	return p_yes if bool(spec.yes) else (1.0 - p_yes)

## What a report says, given a valid source (see source_valid): does it hold here?
static func _report_content(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	return _report_content_impl(view, world, card, answer, false)

static func _report_content_impl(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary, from_testimony: bool) -> bool:
	_ensure_people(view)
	if card.role == "gravedigger" and view.has("timeline"):
		var gd_night: int = card.night if int(card.get("night", -1)) >= 0 else int(card.get("observed_at", {}).get("day", -1))
		if not History.executed(view, str(card.data.get("executed", "")), gd_night):
			return false
	if card.role == "executor":
		var ex_t_impl: int = person_index(view, str(card.data.get("target", "")))
		var ex_s_impl: int = -1 if from_testimony else person_index(view, str(card.get("source", "")))
		if ex_t_impl < 0 or (ex_s_impl >= 0 and ex_t_impl == ex_s_impl):
			return false
		if card.data.has("role") and not bool(card.data.get("assigned", false)):
			if not C.ROLES.has(str(card.data.get("role", ""))) or (view.has("timeline") and not History.died_before_morning(view, str(card.data.get("target", "")), int(card.get("observed_at", {}).get("day", -1)))):
				return false
			return true
		return bool(card.data.get("assigned", false)) and not card.data.has("role")
	if card.role == "registrar":
		if not Roles._registrar_roles_ok(card.data.get("roles")):
			return false
		if card.data.has("target") or card.data.has("yes"):
			var rg_t_impl: int = person_index(view, str(card.data.get("target", "")))
			var rg_s_impl: int = -1 if from_testimony else person_index(view, str(card.get("source", "")))
			if not (card.data.has("target") and card.data.get("yes") is bool) or rg_t_impl < 0 or (rg_s_impl >= 0 and rg_t_impl == rg_s_impl):
				return false
		return true
	if card.role == "magistrate":
		if not _magistrate_nomination_ok(view, card, not from_testimony):
			return false
	if card.role == "warden":
		if view.get("timeline", {}).get("events", []).any(func(event): return event.kind == "demon_death" and event.at.day == card.observed_at.day and card.data.target in event.subjects):
			return false
		# A claimed save (the quiet night was the Demon turned away from this door) holds
		# only where the target is good: the Demon goes for the good (Oct 30).
		if card.data.get("saved", false):
			var ti: int = person_index(view, card.data.target)
			return ti < 0 or (int(world.evil) & (1 << ti)) == 0
		return true
	var rdef = C.role_def(card.role)
	if Domain.live(view):
		if card.role == "medium" and card.get("duty_only", false):
			var dblock: String = str(card.data.get("block", ""))
			var has_corpse: bool = view.people.any(func(p): return p.home == dblock and not History.alive_at_night(view, p.id, card.night))
			return has_corpse
		if rdef != null and rdef.shape == "NIGHT_ROUTE" and card.data.get("seen", []).any(func(id): return not History.alive_at_night(view, id, card.night)):
			return false
		if card.role == "rumormonger":
			return Domain.rumor(view, world, card, answer)
	var d: Dictionary = card.data
	if card.role == "rumormonger":
		var marked: int = world.marked
		var marked_id: String = _cached_ids[marked] if marked >= 0 and marked < _cached_ids.size() else ""
		return marked_id in d.pair and (answer.get("positive", []).is_empty() or marked_id in answer.positive)
	if card.role == "chronicler":
		if not answer.get("blocks", []).is_empty() or not answer.get("marked", []).is_empty():
			return false
		var trio_arr = d.get("trio", [])
		if not (trio_arr is Array) or trio_arr.size() != 3:
			return false
		var trio_mask: int = 0
		for pid in trio_arr:
			var p_i: int = person_index(view, str(pid))
			if p_i < 0 or (trio_mask & (1 << p_i)) != 0:
				return false
			trio_mask |= (1 << p_i)
		var c_src_idx: int = -1 if from_testimony else person_index(view, str(card.get("source", "")))
		if c_src_idx >= 0 and (trio_mask & (1 << c_src_idx)) != 0:
			return false
		if Domain.live(view) and c_src_idx >= 0 and (int(world.get("holders", 0)) & ~(1 << c_src_idx)) == 0:
			return false
		var all_m: int = (1 << _cached_ids.size()) - 1
		var d_i: int = int(world.get("demon", -1))
		var d_bit: int = (1 << d_i) if d_i >= 0 else 0
		var minion_m: int = int(world.evil) & ~d_bit
		var secret_m: int = (int(world.get("holders", 0)) & ~int(world.evil)) if Domain.live(view) else (((1 << int(world.marked)) if int(world.marked) >= 0 else 0) & ~int(world.evil))
		var folk_m: int = all_m & ~int(world.evil) & ~secret_m
		if (trio_mask & minion_m) == 0 or (trio_mask & secret_m) == 0 or (trio_mask & folk_m) == 0:
			return false
		var c_pos: Array = answer.get("positive", [])
		if not c_pos.is_empty():
			var c_ans_m: int = 0
			for pid in c_pos:
				var ap_i: int = person_index(view, str(pid))
				if ap_i < 0:
					return false
				c_ans_m |= (1 << ap_i)
			if (c_ans_m & trio_mask) != c_ans_m or (c_ans_m & minion_m) != c_ans_m:
				return false
		return true
	if card.role == "augur":
		if not answer.get("blocks", []).is_empty() or not answer.get("marked", []).is_empty():
			return false
		var a_src_idx: int = -1 if from_testimony else person_index(view, str(card.get("source", "")))
		var a_demon: int = int(world.get("demon", -1))
		if a_src_idx >= 0 and a_demon == a_src_idx:
			return false
		var a_pos: Array = answer.get("positive", [])
		if not a_pos.is_empty():
			if not bool(d.get("yes", false)):
				return false
			var a_ans_m: int = 0
			for pid in a_pos:
				var ap_i2: int = person_index(view, str(pid))
				if ap_i2 < 0 or (a_src_idx >= 0 and ap_i2 == a_src_idx):
					return false
				a_ans_m |= (1 << ap_i2)
			var reg_d_m: int = (((1 << a_demon) if a_demon >= 0 else 0) if world.has("demon") else int(world.evil)) | ((1 << int(world.marked)) if int(world.marked) >= 0 else 0)
			if (a_ans_m & reg_d_m) != a_ans_m:
				return false
		return true
	var is_parity_surveyor: bool = card.role == "surveyor" and d.has("block") and d.has("same")
	if is_parity_surveyor or card.role == "magistrate":
		if not answer.get("blocks", []).is_empty():
			return false
		var p_group_m: int = 0
		if is_parity_surveyor:
			var blk_id: String = str(d.get("block", ""))
			if not _cached_block_masks.has(blk_id):
				return false
			p_group_m = int(_cached_block_masks[blk_id])
			var s_src_i: int = -1 if from_testimony else person_index(view, str(card.get("source", "")))
			if popcount(p_group_m) < 2 or (s_src_i >= 0 and (p_group_m & (1 << s_src_i)) != 0):
				return false
		else:
			var ma_i: int = person_index(view, str(d.get("nominator", "")))
			var mb_i: int = person_index(view, str(d.get("nominee", "")))
			if ma_i < 0 or mb_i < 0 or ma_i == mb_i:
				return false
			p_group_m = (1 << ma_i) | (1 << mb_i)
		var p_ans_pos: Array = answer.get("positive", [])
		var p_ans_m: int = 0
		for pid in p_ans_pos:
			var pi_p: int = person_index(view, str(pid))
			if pi_p < 0 or (p_group_m & (1 << pi_p)) == 0:
				return false
			p_ans_m |= (1 << pi_p)
		var p_req_marked: Array = answer.get("marked", [])
		for mid in p_req_marked:
			var mi_p: int = person_index(view, str(mid))
			if mi_p != int(world.marked) or (p_group_m & (1 << mi_p)) == 0:
				return false
		var p_evil_bits: int = int(world.evil)
		if world.has("converted") and int(world.converted) >= 0:
			var p_stamp = {"day": int(card.observed_at.get("day", -1)), "phase": "afternoon"} if card.role == "magistrate" else card.observed_at
			if TimeModel.evil_index(view, world, int(world.converted), p_stamp):
				p_evil_bits |= (1 << int(world.converted))
		var grp_sz: int = popcount(p_group_m)
		var want_same: bool = bool(d.get("same", false))
		for mark_reads in ([true] if not p_req_marked.is_empty() else [false, true]):
			var pos_m: int = p_evil_bits | ((1 << int(world.marked)) if (mark_reads and int(world.marked) >= 0) else 0)
			if not p_ans_pos.is_empty() and (pos_m & p_ans_m) != p_ans_m:
				continue
			var cnt_p: int = popcount(pos_m & p_group_m)
			var is_same_p: bool = (cnt_p == 0 or cnt_p == grp_sz)
			if is_same_p == want_same:
				return true
		return false
	var is_site_group: bool = rdef != null and rdef.shape == "ROLE_AT_SITE" and rdef.site_mode == "group_count" and rdef.site_group_key == "group"
	var is_surveyor: bool = rdef != null and rdef.shape == "GROUP_COUNT" and rdef.count_mode == "blocks"
	if not is_site_group and not is_surveyor:
		return true
	# A Marked person may register either way, independently for each reading.
	var evil_bits: int = world.evil
	if world.has("converted") and world.converted >= 0:
		if TimeModel.evil_index(view, world, world.converted, card.observed_at):
			evil_bits |= (1 << world.converted)
	var ans_pos = answer.get("positive", [])
	var ans_mask: int = 0
	for id in ans_pos:
		var index = person_index(view, id)
		if index < 0:
			return false
		ans_mask |= 1 << index
	var group_mask: int = 0
	if is_site_group:
		for id in d.get(rdef.site_group_key, []):
			group_mask |= (1 << person_index(view, id))
	var target_count: int = d.count
	_ensure_people(view)
	var b_masks: Array = _cached_block_masks.values()
	var chosen_blocks: Array = answer.get("blocks", [])
	if not is_surveyor and not chosen_blocks.is_empty():
		return false
	for block in chosen_blocks:
		if not _cached_block_masks.has(block):
			return false
	# "Registered because Marked": that person is the Marked one and read as evil.
	var required_marked: Array = answer.get("marked", [])
	for id in required_marked:
		if person_index(view, id) != world.marked:
			return false
	for mark_reads in ([true] if not required_marked.is_empty() else [false, true]):
		var pos_mask: int = evil_bits | ((1 << world.marked) if (mark_reads and world.marked >= 0) else 0)
		if (pos_mask & ans_mask) != ans_mask:
			continue
		if not chosen_blocks.all(func(block): return bool(pos_mask & _cached_block_masks[block])):
			continue
		var count: int = 0
		if is_surveyor:
			for b in b_masks:
				if (pos_mask & b) != 0:
					count += 1
		else:
			count = popcount(pos_mask & group_mask)
		if count == target_count:
			return true
	return false

static func _movement(view: Dictionary, cards: Array, answers: Dictionary, knowledge: Dictionary = {}) -> Dictionary:
	return _movement_cs(view, cards, answers, knowledge)

static func _movement_cs(view: Dictionary, cards: Array, answers: Dictionary, knowledge: Dictionary) -> Dictionary:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var ids: Array = person_ids(view)
	var n_people: int = ids.size()
	var own: String = str(knowledge.get("self", ""))
	var own_idx: int = person_index(view, own)
	var own_outings: Dictionary = knowledge.get("own_outings", {})
	# Keep each night as the cards give it: the GDScript twin keys `nights` by str(night),
	# which is "1.0" for JSON-loaded (float) nights. Only the C# spec gets int(night).
	var observed_nights: Array = []
	var night_keys: Dictionary = {}
	for card in cards:
		if card.get("night", -1) >= 0 and card.night not in observed_nights:
			observed_nights.append(card.night)
			night_keys[int(card.night)] = str(card.night)

	var night_specs := PackedInt32Array()
	var card_specs := PackedInt32Array()
	var card_cursor: int = 0

	for night in observed_nights:
		var relevant: Array = cards.filter(func(c): return not c.get("quoted", false) and c.get("night", -1) == night and (c.kind in ["sighting", "alibi"] or c.get("role", "") in ["nightwatch", "lamplighter"]))
		if relevant.is_empty():
			continue
		var n_str: String = str(night)
		var own_state: int = -1
		if own_idx >= 0 and own_outings.has(n_str):
			own_state = 1 if bool(own_outings[n_str]) else 0
		night_specs.append(int(night))
		night_specs.append(own_state)
		night_specs.append(card_cursor)
		night_specs.append(relevant.size())

		for card in relevant:
			var kind_code: int = 1
			var req_list: Array = []
			var alibi_idx: int = -1
			var lamp_src: int = -1
			var lamp_cnt: int = 0
			if card.kind == "sighting":
				req_list = card.get("subjects", [card.get("subject", "")])
			elif card.kind == "alibi":
				kind_code = 2
				alibi_idx = person_index(view, str(card.get("subject", "")))
				if alibi_idx < 0:
					# In GDScript 1 << -1 is 0 so mask & 0 == 0 (never invalidates).
					alibi_idx = -1
			elif card.get("role", "") == "nightwatch":
				var src_s: String = str(card.get("source", ""))
				req_list = [src_s] if bool(card.get("duty_only", false)) else (card.get("data", {}).get("seen", []) + [src_s])
			elif card.get("role", "") == "lamplighter":
				var src_s: String = str(card.get("source", ""))
				req_list = [src_s] + answers.get(card.get("id", ""), {}).get("positive", [])
				if not bool(card.get("duty_only", false)):
					kind_code = 3
					lamp_src = person_index(view, src_s)
					lamp_cnt = int(card.get("data", {}).get("count", 0))
			var req_mask: int = 0
			var has_invalid_req: bool = false
			for req_id in req_list:
				var ri: int = person_index(view, str(req_id))
				if ri < 0:
					has_invalid_req = true
				else:
					req_mask |= (1 << ri)
			card_specs.append(kind_code)
			card_specs.append(req_mask)
			card_specs.append(1 if has_invalid_req else 0)
			card_specs.append(alibi_idx)
			card_specs.append(lamp_src)
			card_specs.append(lamp_cnt)
			card_cursor += 1

	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("Solver._movement", pack_u)
	var raw: PackedInt32Array = SolverBackend._bridge().SolverFixtureMovement(n_people, own_idx, night_specs, card_specs)
	var nights: Dictionary = {}
	var p: int = 1
	while p + 2 < raw.size():
		var night: int = raw[p]
		var compat: int = raw[p + 1]
		var f_mask: int = raw[p + 2]
		p += 3
		var forced: Array = []
		if compat > 0:
			for i in range(n_people):
				if (f_mask & (1 << i)) != 0:
					forced.append(ids[i])
		nights[night_keys.get(night, str(night))] = {"compatible": compat, "forced_out": forced}
	return {"okay": raw[0] != 0, "nights": nights}

static func holds(view: Dictionary, world: Dictionary, conclusion: Dictionary) -> bool:
	var index: int = person_index(view, conclusion.target)
	if index < 0:
		return false
	match conclusion.type:
		"demon", "minion": return position_holds(view, world, conclusion.target, conclusion.type, conclusion.at)
		"notdemon": return not position_holds(view, world, conclusion.target, "demon", conclusion.at)
		"evil", "suspicious": return TimeModel.evil_index(view, world, index, conclusion.at)
		"good": return not TimeModel.evil_index(view, world, index, conclusion.at)
		"marked": return world.marked == index
		"secret_mod": return world.get("modifier", "marked") == conclusion.get("mod", "") and (int(world.get("holders", 1 << world.marked)) & (1 << index)) != 0
		"role", "notrole":
			# A declaration question, not an extra hidden role assignment: the live
			# adapter requires a cited matching claim. Good declarations are binding;
			# the existing joint role table weighs whether those claims fit together.
			var claimed: bool = not TimeModel.evil_index(view, world, index, conclusion.at)
			return claimed if conclusion.type == "role" else not claimed
		"lied", "truthful":
			# Existing challenge semantics: evil-reader versus honest-reader
			# explanations. Impairment is not deliberate dishonesty.
			var evil: bool = TimeModel.evil_index(view, world, index, conclusion.get("question_at", conclusion.at))
			return evil if conclusion.type == "lied" else not evil
		"misled", "unreliable":
			var table: PackedByteArray = question_table(view, conclusion)
			var i: int = world.get("__i", -1)
			if i < 0:
				i = universe(view).find(world)
			return i >= 0 and i < table.size() and table[i] != 0
	return false

static var question_cache: Dictionary = {}

static func question_inputs(view: Dictionary, conclusion: Dictionary) -> Array:
	return [conclusion, card_by_id(view, conclusion.get("report", ""))] if conclusion.get("type") in ["misled", "unreliable"] else [conclusion]

## Existing report truth and role tables answer reading questions without adding
## honesty/source states to the world domain.
static func question_table(view: Dictionary, conclusion: Dictionary) -> PackedByteArray:
	if not SolverBackend.profiling_enabled:
		return _question_table_dispatch(view, conclusion)
	var st: int = SolverBackend.begin_stage("world_domain")
	var out: PackedByteArray = _question_table_dispatch(view, conclusion)
	SolverBackend.end_stage(st)
	return out

static func _question_table_dispatch(view: Dictionary, conclusion: Dictionary) -> PackedByteArray:
	var u_key: String = _universe_key(view)
	var input = [u_key, view.people, view.get("timeline", {}), view.get("live_activity", false), question_inputs(view, conclusion)]
	var key = hash(input)
	if question_cache.has(key) and question_cache[key].input == input:
		return question_cache[key].table
	var worlds: Array = universe(view)
	var report = card_by_id(view, conclusion.get("report", ""))
	var out := PackedByteArray()
	out.resize(worlds.size())
	if report.get("kind") == "report":
		var u_handle: int = SolverBackend.get_universe_handle(u_key, worlds)
		var accepted: PackedByteArray = report_table(view, report)
		var roles: PackedByteArray = Roles.fits_table(view, worlds, [report], {}, {}, false, u_handle)
		out = _question_table_cs(view, worlds, u_handle, conclusion, report, accepted, roles)
	if question_cache.size() >= 128:
		question_cache.clear()
	question_cache[key] = {"input": input.duplicate(true), "table": out}
	return out

static func _question_table_cs(view: Dictionary, worlds: Array, u_handle: int, conclusion: Dictionary, report: Dictionary, accepted: PackedByteArray, roles: PackedByteArray) -> PackedByteArray:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(worlds) if u_handle < 0 else PackedInt64Array()
	var is_misled: bool = conclusion.get("type", "") == "misled"
	var is_seer_yes: bool = report.get("role", "") == "seer" and bool(report.get("data", {}).get("yes", false))
	var pair_mask: int = 0
	var pair_has_minus_one: bool = false
	for pid in report.get("data", {}).get("pair", []):
		var pi: int = person_index(view, str(pid))
		if pi < 0:
			pair_has_minus_one = true
		else:
			pair_mask |= (1 << pi)
	var src_idx: int = person_index(view, str(report.get("source", "")))
	var conv_obs: bool = _curse_active_at(view, report.get("observed_at", {}))
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("Solver.question_table", pack_u)
	return SolverBackend._bridge().SolverQuestionTable(u_handle, fallback, accepted, roles, is_misled, is_seer_yes, pair_mask, pair_has_minus_one, src_idx, conv_obs)

static func describe_world(view: Dictionary, world: Dictionary, epoch: String = "") -> Dictionary:
	var ids: Array = person_ids(view)
	var result = {"evil": ids.filter(func(id): return TimeModel.evil_at(view, world, id, view.alignment_epoch if epoch == "" else epoch)), "marked": ids[world.marked] if world.marked >= 0 else ""}
	if Domain.live(view):
		result["modifier"] = world.modifier
		if world.has("demon"):
			result["demon"] = ids[world.demon]
		result["holders"] = ids.filter(func(id): return world.holders & (1 << ids.find(id)))
	if world.has("converted"):
		result["converted"] = ids[world.converted]
	return result

static func unresolved(view: Dictionary, worlds: Array) -> Array:
	var result: Array = []
	if worlds.is_empty():
		return result
	# A person is unresolved when they are evil in some worlds and good in others.
	var all_mask: int = (1 << view.people.size()) - 1
	var any_evil: int = 0
	var any_good: int = 0
	for w in worlds:
		any_evil |= w.evil
		any_good |= ~w.evil & all_mask
		if any_evil & any_good == all_mask:
			break
	for i in range(view.people.size()):
		if any_evil & any_good & (1 << i):
			result.append(view.people[i].id)
	return result

static func assumption_labels(view: Dictionary, cards: Array) -> Array:
	var result: Array = []
	for card in cards:
		if card.kind == "report":
			result.append("%s: %s held %s, was good and healthy at %s %s, and reported honestly." % [card.id, person_name(view, card.source), card.role, card.observed_at.phase, card.observed_at.day])
		elif card.kind == "alibi":
			result.append("%s: challenge the home alibi using the linked observation; falsity is conditional on that observation, and does not prove intent or evil." % card.id if card.get("quoted", false) else "%s: accept the home alibi as accurate." % card.id)
	return result

static func validate_answers(view: Dictionary, case_data: Dictionary) -> Array:
	var errors: Array = []
	for id in case_data.answers:
		if id not in case_data.cards:
			continue
		var card = card_by_id(view, id)
		var positive: Array = case_data.answers[id].get("positive", [])
		var chosen_blocks: Array = case_data.answers[id].get("blocks", [])
		var role_v: String = str(card.get("role", ""))
		var cdata: Dictionary = card.get("data", {}) if card.get("data", {}) is Dictionary else {}
		var is_parity_surv: bool = role_v == "surveyor" and cdata.has("block")
		var surv_res: Array = view.people.filter(func(p): return p.home == cdata.get("block", "")).map(func(p): return p.id) if is_parity_surv else []
		var maximum: int = 10
		if role_v in ["seer", "augur"]:
			maximum = 0 if cdata.get("yes") == false else 1
		elif role_v in ["rumormonger", "clerk", "archivist", "chronicler"]:
			maximum = 1
		elif role_v == "magistrate":
			maximum = 2 if bool(cdata.get("same", false)) else 1
		elif is_parity_surv:
			maximum = surv_res.size() if bool(cdata.get("same", false)) else maxi(1, surv_res.size() - 1)
		else:
			maximum = int(cdata.get("count", 10))
		if positive.size() + chosen_blocks.size() > maximum:
			errors.append("%s: there are more answers than positive slots." % id)
		var unique: Array = []
		for person in positive:
			if person not in view.people.map(func(p): return p.id):
				errors.append("%s: choose a known person." % id)
				continue
			if person in unique:
				errors.append("%s: the same person fills two slots." % id)
			unique.append(person)
		var cdef = C.role_def(role_v)
		if cdef != null and cdef.shape == "ROLE_AT_SITE" and cdef.site_mode == "group_count" and not positive.all(func(p): return p in cdata.get(cdef.site_group_key, [])):
			errors.append("%s: choose people in this reading's group." % id)
		if role_v in ["clerk", "archivist", "seer"] and not positive.all(func(p): return p in cdata.get("pair", [])):
			errors.append("%s: choose a person in this reading's pair." % id)
		if role_v == "chronicler" and not positive.all(func(p): return p in cdata.get("trio", [])):
			errors.append("%s: choose someone in this reading's trio." % id)
		if role_v == "magistrate" and not positive.all(func(p): return p in [cdata.get("nominator", ""), cdata.get("nominee", "")]):
			errors.append("%s: choose someone named in this nomination." % id)
		if role_v == "augur" and card.get("source", "") in positive:
			errors.append("%s: the Augur cannot cross paths with themselves." % id)
		if is_parity_surv and not positive.all(func(p): return p in surv_res):
			errors.append("%s: choose residents living on %s." % [id, C.block_name(str(cdata.get("block", "")))])
		if role_v == "psychologist":
			var f_slot_v: String = str(case_data.answers[id].get("false_slot", ""))
			var f_why_v: String = str(case_data.answers[id].get("false_reason", ""))
			if f_slot_v not in ["", "0", "1", "both"]:
				errors.append("%s: invalid Psychologist statement choice." % id)
			if f_why_v not in ["", "lying", "misled"]:
				errors.append("%s: invalid Psychologist explanation." % id)
			if f_slot_v in ["0", "1"] and f_why_v == "misled" and cdata.get("statements") is Array and cdata.statements.size() == 2:
				if str(cdata.statements[int(f_slot_v)].get("kind", "")) == "sighting":
					errors.append("%s: a direct night sighting cannot be misled; choose Lying or leave the cause unresolved." % id)
		if role_v == "seer" and case_data.answers[id].get("registration", "") not in ["", "demon", "marked", "red_herring"]:
			errors.append("%s: choose a valid registration explanation." % id)
		if cdef != null and cdef.shape == "GROUP_COUNT" and cdef.count_mode == "walkers" and card.source in positive:
			errors.append("%s: the count excludes the Lamplighter." % id)
		if cdef != null and cdef.shape == "GROUP_COUNT" and cdef.count_mode == "blocks" and not is_parity_surv:
			var blocks: Array = []
			for block in chosen_blocks:
				if block not in C.BLOCKS:
					errors.append("%s: choose a known block." % id)
				if block in blocks:
					errors.append("%s: each slot needs a different block." % id)
				blocks.append(block)
			for person in positive:
				var matches: Array = view.people.filter(func(p): return p.id == person)
				if matches.is_empty():
					continue
				var home: String = matches[0].home
				if home in blocks:
					errors.append("%s: each slot needs a different block." % id)
				blocks.append(home)
		elif not chosen_blocks.is_empty():
			errors.append("%s: only block-count Surveyor answers can name blocks." % id)
		if role_v == "rumormonger" and not positive.all(func(p): return p in cdata.get("pair", [])):
			errors.append("%s: choose someone in the named pair." % id)
		if card.get("kind", "") == "town_hall":
			var th_pick: String = str(case_data.answers[id].get("in_play_role", ""))
			if th_pick != "" and th_pick not in card.get("data", {}).get("roles", []):
				errors.append("%s: choose one of the two roles named in this Town Hall record." % id)
			if not positive.is_empty():
				errors.append("%s: Town Hall records select a role, not a person." % id)
	return errors

static func person_name(view: Dictionary, id: String) -> String:
	for p in view.people:
		if p.id == id:
			return p.name
	return id
