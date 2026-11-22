## Chance of content and premise masks: how likely a reading is by chance, which worlds a
## source can read in healthily, and which worlds a premise holds in (split from
## `workshop/case_eval.gd`; part of CaseEval's inheritance chain).
extends "res://workshop/case_eval_base.gd"

static func _concl_type_code(c_type: String) -> int:
	match c_type:
		"evil", "suspicious":
			return 0
		"good":
			return 1
		"notrole":
			return 2
		"lied":
			return 3
		"truthful":
			return 4
		"demon":
			return 5
		"notdemon":
			return 7
		"marked":
			return 8
		"secret_mod":
			return 9
		_:
			return 10

## Chance of this report's content arising by chance: roughly one over the number of
## different things the gift could have said.
static func _healthy_modifier_worlds_per_team(g: int, mods: Array) -> float:
	var w_h: float = 0.0
	if "marked" in mods:
		w_h += float(g)
	if "delusional" in mods:
		w_h += float(maxi(0, g - 1))
	return w_h

static func _chance_rumormonger(view: Dictionary, d: Dictionary) -> float:
	var n: int = view.get("people", []).size()
	var e: int = clampi(int(view.get("evil_count", 2)), 1, maxi(1, n - 1))
	var g: int = n - e
	if n <= 2 or g <= 1:
		return 0.25
	if not Domain.live(view):
		return 0.5
	var pair_sz: int = clampi(int(d.get("pair", []).size()), 1, n - 1)
	var mods: Array = view.get("world_options", {}).get("modifiers", ["marked"])
	var w_h: float = _healthy_modifier_worlds_per_team(g, mods)
	if w_h <= 0.0:
		return 0.25
	var sec: String = str(d.get("secret", "marked"))
	if sec not in mods:
		return clampf(1.0 / w_h, 0.01, 0.5)
	var exp_solo: float = float(pair_sz) * float(g - 1) / float(n - 1)
	return clampf(exp_solo / w_h, 0.01, 0.5)

static func _chance_chronicler(view: Dictionary) -> float:
	var n: int = view.get("people", []).size()
	var e: int = clampi(int(view.get("evil_count", 2)), 1, maxi(1, n - 1))
	var g: int = n - e
	if n < 4 or g < 3 or e < 2:
		return 0.15
	var c_n1_3: float = float((n - 1) * (n - 2) * (n - 3)) / 6.0
	if not Domain.live(view):
		return 0.25
	var mods: Array = view.get("world_options", {}).get("modifiers", ["marked"])
	var w_h: float = _healthy_modifier_worlds_per_team(g, mods)
	if w_h <= 0.0:
		return 0.15
	var solo_worlds: float = 0.0
	for m_kind in ["marked", "delusional"]:
		if m_kind in mods:
			solo_worlds += float(g - 1)
	var trios_one_sec: float = float((e - 1) * (g - 2))
	var exp_holds: float = (solo_worlds * trios_one_sec) / c_n1_3
	return clampf(exp_holds / w_h, 0.01, 0.5)

## The chance that a source who can't give a healthy reading (evil, poisoned, Delusional)
## would still say this: the share of possible worlds in which the reported content holds.
## A bluffer says something that fits, so content the worlds can't check (a Lamplighter's
## count, a relay from the dead) is free to fake and earns the source no credit; content
## that holds in few worlds (a Seer "yes", a Dowser count) is hard to fake by chance.
## Kept on the per-shape constants:
## - the Chronicler and the Rumormonger, which have exact prior hold rates (the share is
##   unweighted, and those two depend on the secret's priors);
## - readings checked somewhere other than the report table (ROLE_CONTENT_FIXED): readings
##   about roles (the role constraints) and night sightings (the movement model: a Night
##   Watch's list, a Warden's door, a Veteran's road), and the Seer (its red herring is a
##   weight in the role constraints, so the table holds wherever any good soul is in the
##   pair), so the table can't say how often a bluff fits. The Lamplighter's count isn't
##   checked anywhere, so it takes the share.
## - cards with no report table.
const ROLE_CONTENT_FIXED = ["archivist", "clerk", "executor", "gravedigger", "registrar", "monitor", "martyr",
	"nightwatch", "warden", "veteran", "seer"]

static func chance_content(view: Dictionary, card: Dictionary) -> float:
	# The player's own word "X holds secret S" (SharedLedger._add_player_words) names X
	# because the player is arguing about X, so when the player is wrong it still lands on
	# X: its chance of arising is 1, and the word is worth the player's credibility alone
	# (1 / error on the odds), not a boost from how rarely the secret would be named by
	# chance. Michael, Nov 22 (option b').
	if card.get("player_word", false):
		return 1.0
	var role_id: String = str(card.get("role", ""))
	if role_id in ROLE_CONTENT_FIXED:
		return _chance_content_fixed(view, card)
	if role_id == "chronicler":
		return _chance_chronicler(view)
	var rdef = Solver.C.role_def(role_id)
	if rdef != null and rdef.shape == "SECRET_PAIR":
		return _chance_rumormonger(view, card.get("data", {}))
	if card.get("kind", "") == "report":
		# Among worlds where the source could read healthily (the table only holds there).
		var tab: PackedByteArray = Solver.report_table(view, card)
		var valid: PackedByteArray = _valid_table(view, card)
		if not tab.is_empty() and valid.size() == tab.size():
			var n_valid: int = valid.count(1)
			if n_valid > 0:
				var n_hold: int = 0
				for i in range(tab.size()):
					if tab[i] == 1 and valid[i] == 1:
						n_hold += 1
				return clampf(float(n_hold) / float(n_valid), Tuning.Workshop.CHANCE_CONTENT_FLOOR, 1.0)
	return _chance_content_fixed(view, card)

## The per-shape estimates used before Nov 5 (kept for cards without a report table).
static func _chance_content_fixed(view: Dictionary, card: Dictionary) -> float:
	var d: Dictionary = card.get("data", {})
	var role_id: String = str(card.get("role", ""))
	if role_id == "chronicler":
		return _chance_chronicler(view)
	if role_id in ["augur", "magistrate", "monitor", "confessor"]:
		return 0.5
	var rdef = Solver.C.role_def(role_id)
	if rdef != null:
		if rdef.shape == "SECRET_PAIR":
			return _chance_rumormonger(view, d)
		if rdef.shape == "ROLE_AT_SITE" and rdef.site_mode == "group_count":
			return 1.0 / float(d.get("group", []).size() + 1)
		if rdef.shape == "GROUP_COUNT":
			if rdef.count_mode == "blocks":
				if d.has("block"):
					return 0.5
				var blocks = {}
				for p in view.people:
					blocks[p.home] = true
				return 1.0 / float(blocks.size() + 1)
			if rdef.count_mode == "walkers":
				return 1.0 / float(view.people.size())
		if rdef.shape == "NIGHT_ROUTE":
			return 0.25
	return 0.5

static var _valid_cache: Dictionary = {}

## Per world: can this card's source give a healthy reading? (cached per card and universe)
static func _valid_table(view: Dictionary, card: Dictionary) -> PackedByteArray:
	var ref: Array = [Solver._universe_key(view), card.kind, card.get("source", ""), card.get("observed_at", {}), card.get("role", ""), view.get("timeline", {}), card.get("testimony_only", false), card.get("reported_at"), card.get("duty_only", false), card.get("omen_claimants", [])]
	var key: int = hash(ref)
	if _valid_cache.has(key) and _valid_cache[key].ref == ref:
		return _valid_cache[key].out
	if _valid_cache.size() > 512:
		_valid_cache.clear()
	var out: PackedByteArray = Solver.valid_table(view, card)
	_valid_cache[key] = {"ref": ref.duplicate(true), "out": out}
	return out

static var _index_cache: Dictionary = {}

## Per universe: the distinct evil teams, and which team each world has (cached).
static func _index(view: Dictionary) -> Dictionary:
	var key = Solver._universe_key(view)
	if _index_cache.has(key):
		return _index_cache[key]
	if _index_cache.size() > 16:
		_index_cache.clear()
	var universe: Array = Solver.universe(view)
	var out: Dictionary = _index_cs(view, key, universe)
	_index_cache[key] = out
	return out

static func _index_cs(view: Dictionary, u_key: String, universe: Array) -> Dictionary:
	var u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(universe) if u_handle < 0 else PackedInt64Array()
	var curr_conv: bool = Solver._curse_active_at(view, "Current alignment")
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("CaseEval._index", pack_u)
	var raw: PackedInt32Array = SolverBackend._bridge().CaseEvalTeamIndex(u_handle, fallback, curr_conv)
	var t_len: int = raw[0]
	var teams: Array = []
	teams.resize(t_len)
	for i in range(t_len):
		teams[i] = int(raw[1 + i])
	return {"teams": teams, "team_of": raw.slice(1 + t_len)}

## Uniform prior over legal worlds, with no private knowledge: the reference listener.
static func neutral_listener(view: Dictionary) -> Dictionary:
	return {"id": "", "suspicion": {}, "knowledge": {}, "reading_reliability": {}}

static var _premise_cache: Dictionary = {}

## The conclusion carries any readings that refute "was the Demon when hanged" (`refuters`,
## Solver.with_hanged_refuters), so the key below (question_inputs holds the conclusion) keys
## on them too.
static func _premise_mask(view: Dictionary, conclusion: Dictionary) -> PackedByteArray:
	var ref: Array = [Solver._universe_key(view), Solver.question_inputs(view, conclusion), view.get("timeline", {})]
	var key: int = hash(ref)
	if _premise_cache.has(key) and _premise_cache[key].ref == ref:
		return _premise_cache[key].out
	if _premise_cache.size() > 256:
		_premise_cache.clear()
	var out: PackedByteArray = _build_premise_mask(view, conclusion)
	_premise_cache[key] = {"ref": ref.duplicate(true), "out": out}
	return out

static func _build_premise_mask(view: Dictionary, conclusion: Dictionary) -> PackedByteArray:
	if conclusion.type in ["misled", "unreliable"]:
		return Solver.question_table(view, conclusion)
	if conclusion.type == "holds":
		return _holds_mask(view, Solver.card_by_id(view, str(conclusion.get("report", ""))))
	if conclusion.type == "turned":
		# The soul the Revenant's curse turned (Solver.holds): one byte per world.
		var t_idx: int = Solver.person_index(view, str(conclusion.get("target", "")))
		var t_worlds: Array = Solver.universe(view)
		var t_out := PackedByteArray()
		t_out.resize(t_worlds.size())
		for i in range(t_worlds.size()):
			t_out[i] = 1 if t_idx >= 0 and int(t_worlds[i].get("converted", -1)) == t_idx else 0
		return t_out
	var h_ctx: Dictionary = Solver.hanged_context(view, str(conclusion.get("target", "")), conclusion.get("refuters", [])) if conclusion.type in ["demon", "notdemon"] else {}
	if not h_ctx.is_empty():
		# Someone already hanged: "was the Demon when hanged" (Solver.hanged_demon), the
		# Scion's succession included. One byte per world, in GDScript.
		var h_worlds: Array = Solver.universe(view)
		var h_out := PackedByteArray()
		h_out.resize(h_worlds.size())
		var want: int = 1 if conclusion.type == "demon" else 0
		for i in range(h_worlds.size()):
			h_out[i] = 1 if Solver.hanged_demon_in(h_worlds[i], h_ctx) == want else 0
		return h_out
	if conclusion.type == "inconsistent":
		# The source's readings can't all hold: not every one of them fits the world.
		var n_w: int = Solver.universe(view).size()
		var all_hold := PackedByteArray()
		all_hold.resize(n_w)
		all_hold.fill(1)
		for rid in conclusion.get("reports", []):
			var m: PackedByteArray = _holds_mask(view, Solver.card_by_id(view, str(rid)))
			for i in range(n_w):
				if m[i] == 0:
					all_hold[i] = 0
		var out := PackedByteArray()
		out.resize(n_w)
		for i in range(n_w):
			out[i] = 1 - all_hold[i]
		return out
	var u_key: String = Solver._universe_key(view)
	var universe: Array = Solver.universe(view)
	return _build_premise_mask_cs(view, u_key, universe, conclusion)

## Premises step 3: "the reading's content holds" as a question, for graded challenges:
## content only, whoever the source is (graded_challenge weighs the source and the
## reading's error separately), the same mask before and after the evidence.
static func _holds_mask(view: Dictionary, report: Dictionary) -> PackedByteArray:
	return Solver.reading_holds_table(view, report)

static func _build_premise_mask_cs(view: Dictionary, u_key: String, universe: Array, conclusion: Dictionary) -> PackedByteArray:
	var u_handle: int = SolverBackend.get_universe_handle(u_key, universe)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback: PackedInt64Array = SolverBackend.pack_worlds(universe) if u_handle < 0 else PackedInt64Array()
	var is_live: bool = Domain.live(view)
	var c_type: String = str(conclusion.get("type", ""))
	var c_code: int = _concl_type_code(c_type)
	var target_idx: int = Solver.person_index(view, str(conclusion.get("target", "")))
	var sec_mod: int = Solver._secret_mod_code(str(conclusion.get("mod", "")))
	var check_at = conclusion.get("question_at", conclusion.get("at", "")) if c_type in ["lied", "truthful"] else (view.get("alignment_epoch", "") if str(conclusion.get("at", "")) == "" and c_type in ["demon", "notdemon"] else conclusion.get("at", ""))
	var conv_evil: bool = Solver._curse_active_at(view, check_at)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("Solver.premise_mask", pack_u)
	return SolverBackend._bridge().SolverPremiseMask(u_handle, fallback, is_live, c_code, target_idx, sec_mod, conv_evil)

## The chance a reading is wrong despite a good, healthy source, for this listener:
## their reliability for it (impairment, a doubted route, a challenge they accept),
## starting from DEFAULT_ERR, or OWN_ERR for their own reading. A reading their own
## knowledge disowns says nothing.
static func reading_error(view: Dictionary, card: Dictionary, listener: Dictionary, own_ids: Array = []) -> float:
	var rel: Dictionary = listener.get("reading_reliability", {})
	var r = 1.0
	for key in [card.get("accuracy_origin", ""), Solver.semantic_key(card), card.get("fact_id", ""), card.id]:
		if key != "" and rel.has(key):
			r = float(rel[key])
			break
	if (card.has("relay_source") or card.has("route_origin")) and rel.has(card.id) and card.get("accuracy_origin", "") != card.id:
		r *= float(rel[card.id])  # the hearing route itself
	r *= float(listener.get("challenge_reports", {}).get(card.id, 1.0)) * float(listener.get("challenge_sources", {}).get(card.get("source", ""), 1.0))
	if card.kind == "report" and TimeModel.disowned(view, card, listener.get("knowledge", {}).get("known_events", [])):
		r = 0.0
	var base_err: float = OWN_ERR if card.id in own_ids else DEFAULT_ERR
	return clampf(1.0 - clampf(r, 0.0, 1.0) * (1.0 - base_err), OWN_ERR, 1.0)
