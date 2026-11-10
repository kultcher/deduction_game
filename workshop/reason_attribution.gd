## Shared-model suspicion attribution for Phase 2a of the legacy retirement plan.
##
## Runs once per shared belief refresh on the listener's active suspects only, scoring
## held evidence through the shared model's own report tables, role constraints, movement
## likelihoods, reading challenges, and multi-card leave-one-out contradictions.
## Never consults referee truth or legacy `info_effects` / `night_sighting_scale`.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Solver = preload("res://workshop/solver.gd")
const Domain = preload("res://workshop/world_domain.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const History = preload("res://workshop/live_history.gd")
const Evidence = preload("res://workshop/live_evidence.gd")

const MIN_SUSPECT_REQUESTED: float = Tuning.Workshop.REASON_MIN_SUSPECT_REQUESTED
const MIN_ITEM_CONTRIB: float = Tuning.Workshop.REASON_MIN_ITEM_CONTRIB
const MAX_REASONS_PER_TARGET: int = Tuning.Workshop.REASON_MAX_PER_TARGET
## Skip the leave-one-out pass when single-card reasons already carry this share of the shift.
const LOO_COVERED_SHARE: float = Tuning.Workshop.REASON_LOO_COVERED_SHARE
## At most this many other people's cards are tested in the leave-one-out pass per suspect.
const LOO_MAX_OTHER_CARDS: int = Tuning.Workshop.REASON_LOO_MAX_OTHER_CARDS
const SPOKEN_KINDS: Array = ["report", "sighting", "alibi", "claim", "context", "testimony"]

static var _fits_cache: Dictionary = {}


static func attribute_refresh(
	view: Dictionary,
	scoped_case: Dictionary,
	attended: Array,
	held: Array,
	challenged: Dictionary,
	listener: Dictionary,
	eval_listener: Dictionary,
	ev: Dictionary,
	effects: Dictionary
) -> Dictionary:
	if not SolverBackend.profiling_enabled:
		return _attribute_refresh_impl(view, scoped_case, attended, held, challenged, listener, eval_listener, ev, effects)
	var _st: int = SolverBackend.begin_stage("reason_attribution")
	var _res: Dictionary = _attribute_refresh_impl(view, scoped_case, attended, held, challenged, listener, eval_listener, ev, effects)
	SolverBackend.end_stage(_st)
	return _res

static func _attribute_refresh_impl(
	view: Dictionary,
	scoped_case: Dictionary,
	attended: Array,
	held: Array,
	challenged: Dictionary,
	listener: Dictionary,
	eval_listener: Dictionary,
	ev: Dictionary,
	effects: Dictionary
) -> Dictionary:
	if ev.get("impossible", false):
		return {}
	var self_id: String = str(listener.get("id", ""))
	var suspect_ids: Array = []
	for person in view.get("people", []):
		var pid: String = str(person.get("id", ""))
		if pid == "" or pid == self_id or not effects.has(pid):
			continue
		var eff: Dictionary = effects[pid]
		var req: float = float(eff.get("requested", 0.0))
		var chg: float = float(eff.get("evil_change", 0.0))
		if req >= MIN_SUSPECT_REQUESTED or (req > 0.005 and chg >= 0.05):
			suspect_ids.append(pid)
	if suspect_ids.is_empty():
		return {}

	var knowledge: Dictionary = eval_listener.get("knowledge", {})
	var own_ids: Array = knowledge.get("own_reports", [])
	if own_ids.is_empty():
		own_ids = knowledge.get("attention_reports", [])
	var cc: Dictionary = CaseEval.compile(view, attended, scoped_case, [])
	var universe: Array = Solver.universe(view)
	var nc: int = cc.team.size()
	if nc == 0 or universe.is_empty():
		return {}
	var reps: Array = []
	for c_idx in range(nc):
		reps.append(universe[cc.rep[c_idx]])
	var team_prior: PackedFloat64Array = CaseEval._team_prior(view, eval_listener)
	var fits_before: PackedFloat64Array = CaseEval._class_fits(view, cc, [], knowledge)
	var base_w: PackedFloat64Array = PackedFloat64Array()
	base_w.resize(nc)
	for c_idx in range(nc):
		base_w[c_idx] = cc.count[c_idx] * team_prior[cc.team[c_idx]] * fits_before[c_idx]

	var discredited_cards: Dictionary = {}
	var lying_by_source: Dictionary = {}
	for ch in challenged.get("results", []):
		var cid: String = str(ch.get("card", ""))
		var mult: float = float(ch.get("multiplier", 1.0))
		var mode: String = str(ch.get("mode", ""))
		var agr: float = float(ch.get("agreement", 0.0))
		if mult <= 0.5 or (mode == "lying" and agr >= 0.6):
			discredited_cards[cid] = true
		if mode == "lying" and agr >= 0.6:
			var csrc: String = str(ch.get("source", ""))
			if csrc != "":
				if not lying_by_source.has(csrc):
					lying_by_source[csrc] = []
				lying_by_source[csrc].append(ch)

	var dull: float = Tuning.Workshop.HEADLINE_WEIGHT * (1.0 - clampf(float(listener.get("insight", 0.5)), 0.0, 1.0))
	var belief_scale: float = Tuning.Workshop.JURY_BELIEF_SCALE if bool(listener.get("per_card_source_trust", false)) else 1.0

	# Precompute full posterior weights, single-report class weights, and leave-one-out
	# class posteriors ONCE per refresh rather than repeating role-table solves per suspect.
	var errs: Array = []
	for r_card in cc.reports:
		errs.append(CaseEval.reading_error(view, r_card, eval_listener, own_ids))
	var fits_full: PackedFloat64Array = _apply_curse_good(view, cc, CaseEval._class_fits(view, cc, attended, knowledge), knowledge)
	var like_full: PackedFloat64Array = CaseEval._class_like(cc, errs, -1)
	var move_full: PackedFloat64Array = cc.move if cc.movement_ok else PackedFloat64Array()
	if not cc.movement_ok:
		move_full.resize(nc)
		move_full.fill(0.0)
	var test_full: PackedFloat64Array = CaseEval._test_like(view, cc, eval_listener, own_ids)

	var attended_map: Dictionary = {}
	for ac in attended:
		attended_map[str(ac.get("id", ""))] = true

	var single_report_pre: Dictionary = {}
	for card in attended:
		if card.get("quoted", false) or str(card.get("kind", "")) != "report":
			continue
		var sc_role: String = str(card.get("role", ""))
		if sc_role in ["nightwatch", "lamplighter"] or card.get("duty_only", false):
			continue
		var sc_id: String = str(card.get("id", ""))
		var r_tab: PackedByteArray = Solver.report_table(view, card)
		var v_tab: PackedByteArray = CaseEval._valid_table(view, card)
		var sc_err: float = CaseEval.reading_error(view, card, eval_listener, own_ids)
		var sc_q: float = CaseEval.chance_content(view, card)
		var f_one: PackedFloat64Array = _subset_fits(view, cc, [card], knowledge)
		var w_one: PackedFloat64Array = PackedFloat64Array()
		w_one.resize(nc)
		for c_idx in range(nc):
			var u_idx: int = cc.rep[c_idx]
			var st: int = 0 if r_tab[u_idx] == 1 else (1 if v_tab[u_idx] == 1 else 2)
			w_one[c_idx] = cc.count[c_idx] * team_prior[cc.team[c_idx]] * f_one[c_idx] * CaseEval._factor(st, sc_err, sc_q)
		single_report_pre[sc_id] = {"w_one": w_one, "err": sc_err}

	# Leave-one-out posteriors are computed lazily, once per card per refresh, and only
	# for suspects whose single-card reasons don't already explain the shift (each one
	# can re-solve role constraints, the dominant refresh cost).
	var loo_ctx: Dictionary = {"view": view, "cc": cc, "attended": attended, "knowledge": knowledge,
		"errs": errs, "team_prior": team_prior, "fits_full": fits_full, "like_full": like_full,
		"move_full": move_full, "test_full": test_full, "nc": nc, "memo": {}}

	var out: Dictionary = {}
	for pid in suspect_ids:
		var p_idx: int = Solver.person_index(view, pid)
		if p_idx < 0:
			continue
		var pr0: Dictionary = _person_probs(view, reps, base_w, p_idx)
		var items_by_id: Dictionary = {}

		# 1. Direct single-card report, claim, movement, trace, and challenge evaluation.
		for card in held:
			if card.get("quoted", false):
				continue
			var cid: String = str(card.get("id", ""))
			var ckind: String = str(card.get("kind", ""))
			var csrc: String = str(card.get("source", ""))

			if ckind == "report":
				var crole: String = str(card.get("role", ""))
				if crole == "nightwatch":
					var seen_list: Array = card.get("data", {}).get("seen", [])
					if csrc == pid and self_id != "" and self_id in seen_list:
						var own_outings: Dictionary = knowledge.get("own_outings", {})
						var nd_str: String = str(int(card.get("night", card.get("observed_at", {}).get("day", -1))))
						if own_outings.has(nd_str) and not bool(own_outings[nd_str]):
							var lie_txt: String = "%s claims to have seen me out at night, which is a lie" % Solver.person_name(view, pid)
							_put_item(items_by_id, {
								"card_id": cid, "card_kind": "report", "channel": "challenge_lie",
								"source": csrc, "relay_source": str(card.get("relay_source", "")),
								"role": crole, "night": int(card.get("night", -1)), "block": str(card.get("data", {}).get("block", "")),
								"contrib": 0.42, "strength": 0.90,
								"why_own": lie_txt, "why_public": lie_txt,
								"joint": false, "root_ids": [cid],
							})
							continue
					if not card.get("duty_only", false) and pid in seen_list and not discredited_cards.has(cid):
						var nw_item: Dictionary = _score_movement_sighting(view, attended, card, pid, p_idx, pr0, listener, self_id, belief_scale)
						if not nw_item.is_empty():
							_put_item(items_by_id, nw_item)
					continue
				if card.get("duty_only", false) or crole == "lamplighter":
					continue
				if discredited_cards.has(cid) and csrc != pid:
					continue
				if pid not in _mentions(card) and csrc != pid and crole not in ["surveyor", "veteran", "augur"]:
					continue
				if not attended_map.has(cid):
					# Unattended reports only contribute via _headline for lower-Insight listeners.
					if dull > 0.0 and csrc != pid and not (crole == "archivist" and C.ROLES.get(str(card.get("data", {}).get("role", "")), {}).get("align", "good") != "evil"):
						var u_hl: float = _headline_chance(card, pid)
						if u_hl > 0.0:
							var u_err: float = CaseEval.reading_error(view, card, eval_listener, own_ids)
							var u_hit: float = clampf(u_hl * (1.0 - u_err) * _card_trust(card, listener, bool(card.get("via_player_only", false))), 0.0, 1.0)
							if u_hit > pr0.evil:
								var u_contrib: float = dull * 0.45 * CaseEval.shift(pr0.evil, u_hit) * belief_scale
								if u_contrib >= MIN_ITEM_CONTRIB:
									var u_why: Array = _report_why_pair(view, card, pid, self_id)
									_put_item(items_by_id, {
										"card_id": cid, "card_kind": "report", "channel": "report",
										"source": csrc, "relay_source": str(card.get("relay_source", "")),
										"role": crole, "night": int(card.get("night", card.get("observed_at", {}).get("day", -1))),
										"block": str(card.get("block", "")), "contrib": u_contrib,
										"strength": clampf(0.80 * u_hl, 0.25, 0.85),
										"why_own": str(u_why[0]), "why_public": str(u_why[1]),
										"joint": false, "root_ids": [cid],
									})
					continue
				var rep_item: Dictionary = _score_single_report(view, cc, reps, team_prior, card, pid, p_idx, pr0, listener, eval_listener, own_ids, knowledge, self_id, dull, belief_scale, single_report_pre.get(cid, {}))
				if not rep_item.is_empty():
					_put_item(items_by_id, rep_item)

			elif ckind == "claim" and attended_map.has(cid):
				if csrc == pid:
					var clm_role: String = str(card.get("role", ""))
					var own_role: String = str(knowledge.get("own_role", ""))
					var hw: float = clampf(float(card.get("hearing_weight", 1.0)), 0.1, 1.0)
					if own_role != "" and clm_role == own_role and pid != self_id:
						_put_item(items_by_id, {
							"card_id": cid, "card_kind": "claim", "channel": "role_clash",
							"source": self_id, "relay_source": "", "role": own_role,
							"night": -1, "block": "",
							"contrib": 0.42 * hw, "strength": 0.88,
							"why_own": "they claimed my own gift, so they're lying",
							"why_public": "they claimed my own gift, so they're lying",
							"joint": false, "root_ids": [cid],
						})
					else:
						for other_c in held:
							if other_c.get("quoted", false) or str(other_c.get("id", "")) == cid:
								continue
							if str(other_c.get("kind", "")) in ["claim", "report"] and str(other_c.get("role", "")) == clm_role and str(other_c.get("source", "")) != pid:
								var osrc: String = str(other_c.get("source", ""))
								var pair_fits: PackedFloat64Array = _subset_fits(view, cc, [card, other_c], knowledge)
								var pair_w: PackedFloat64Array = PackedFloat64Array()
								pair_w.resize(nc)
								for c_idx in range(nc):
									pair_w[c_idx] = cc.count[c_idx] * team_prior[cc.team[c_idx]] * pair_fits[c_idx]
								var pr_pair: Dictionary = _person_probs(view, reps, pair_w, p_idx)
								var s_clash: float = CaseEval.shift(pr0.evil, pr_pair.evil)
								var c_clash: float = 0.45 * s_clash * belief_scale
								if c_clash >= MIN_ITEM_CONTRIB:
									var anchor_own: bool = (osrc == self_id)
									var why_r: String = "they claimed my own gift, so they're lying" if anchor_own else ("they claim a gift %s claims" % Solver.person_name(view, osrc))
									_put_item(items_by_id, {
										"card_id": str(other_c.get("id", cid)) if anchor_own else cid,
										"card_kind": str(other_c.get("kind", "claim")) if anchor_own else "claim",
										"channel": "role_clash",
										"source": self_id if anchor_own else osrc,
										"relay_source": "", "role": clm_role, "night": -1, "block": "",
										"contrib": c_clash, "strength": clampf(0.45 + 0.55 * s_clash, 0.40, 0.90),
										"why_own": why_r, "why_public": ("they claim a gift another townsperson claims" if anchor_own else why_r),
										"joint": true, "root_ids": [cid, str(other_c.get("id", ""))],
									})
									break

			elif ckind == "sighting" and attended_map.has(cid):
				var subjs: Array = card.get("subjects", [card.get("subject", "")])
				if int(card.get("night", -1)) >= 0 and pid in subjs:
					var mov_item: Dictionary = _score_movement_sighting(view, attended, card, pid, p_idx, pr0, listener, self_id, belief_scale)
					if not mov_item.is_empty():
						_put_item(items_by_id, mov_item)

			elif ckind == "trace" and attended_map.has(cid) and card.get("data", {}).has("family"):
				var tr_eval: Dictionary = LiveActivity.evaluate_trace_for_person(view, attended, card, pid)
				if str(tr_eval.get("state", "")) == "matches":
					var tr_reason: String = str(tr_eval.get("reason", ""))
					var tr_txt: String = ("a trace at the murder scene fits them (%s)" % tr_reason) if tr_reason != "" else "a trace at the murder scene fits them"
					_put_item(items_by_id, {
						"card_id": cid, "card_kind": "trace", "channel": "trace",
						"source": csrc, "relay_source": "", "role": "",
						"night": int(card.get("night", -1)), "block": str(card.get("data", {}).get("scene_block", card.get("block", ""))),
						"contrib": 0.14, "strength": 0.48,
						"why_own": tr_txt, "why_public": tr_txt,
						"joint": false, "root_ids": [cid],
					})

		if lying_by_source.has(pid):
			for ch in lying_by_source[pid]:
				var ch_cid: String = str(ch.get("card", ""))
				var ch_card: Dictionary = Solver.card_by_id(view, ch_cid)
				var ch_role: String = str(ch_card.get("role", ""))
				var agr_val: float = float(ch.get("agreement", 0.6))
				var ch_txt: String = ("their %s report doesn't hold up against the other evidence" % C.role_name(ch_role)) if ch_role != "" else "their account was caught in a lie"
				_put_item(items_by_id, {
					"card_id": ch_cid if ch_cid != "" else ("challenge:" + pid),
					"card_kind": str(ch_card.get("kind", "report")),
					"channel": "challenge_lie",
					"source": pid, "relay_source": "", "role": ch_role,
					"night": int(ch_card.get("night", -1)), "block": str(ch_card.get("block", "")),
					"contrib": maxf(0.12 * agr_val * belief_scale, 0.10),
					"strength": clampf(agr_val, 0.55, 0.95),
					"why_own": ch_txt, "why_public": ch_txt,
					"joint": false, "root_ids": [ch_cid] if ch_cid != "" else [],
				})

		# 2. Leave-one-out contradiction & joint-inference pass when the joint model moved `pid`
		#    substantially or when the listener's own card collides with `pid`'s account.
		var full_shift: float = float(effects[pid].get("evil_change", 0.0))
		var direct_cover: float = 0.0
		for it in items_by_id.values():
			direct_cover += float(it.get("contrib", 0.0))
		if full_shift >= Tuning.Workshop.REASON_LOO_MIN_SHIFT and direct_cover < LOO_COVERED_SHARE * full_shift * belief_scale:
			_augment_joint_leave_one_out(
				items_by_id, view, reps, attended, loo_ctx,
				pid, p_idx, pr0, full_shift, self_id, belief_scale
			)

		if not items_by_id.is_empty():
			var ranked: Array = items_by_id.values()
			ranked.sort_custom(func(a, b): return float(a.get("contrib", 0.0)) > float(b.get("contrib", 0.0)))
			out[pid] = ranked.slice(0, MAX_REASONS_PER_TARGET)
	return out


static func attach_owners(reasons: Dictionary, owners: Dictionary, public_good: Array = []) -> Dictionary:
	var out: Dictionary = {}
	for pid in reasons:
		if pid in public_good:
			continue
		var copy_list: Array = []
		for item in reasons[pid]:
			var icopy: Dictionary = item.duplicate(true)
			var cid: String = str(icopy.get("card_id", ""))
			icopy["owners"] = owners.get(cid, []).duplicate()
			copy_list.append(icopy)
		if not copy_list.is_empty():
			out[pid] = copy_list
	return out


static func append_circumstantial(
	reasons: Dictionary,
	incidents_by_target: Dictionary,
	hubs: Array,
	presentations: Dictionary
) -> void:
	for pid in incidents_by_target:
		var incs: Array = incidents_by_target[pid]
		if incs.is_empty():
			continue
		var any_public_hub: bool = false
		for h in hubs:
			if str(h.get("target", "")) != pid:
				continue
			var pkey: String = str(h.get("presentation_key", ""))
			if presentations.has(pkey) and str(presentations[pkey].get("venue", "private")) != "private":
				any_public_hub = true
			elif presentations.has(int(pkey)) and str(presentations[int(pkey)].get("venue", "private")) != "private":
				any_public_hub = true
		var list: Array = reasons.get(pid, [])
		for inc in incs:
			var app: float = float(inc.get("applied", 0.0))
			if app < Tuning.Workshop.REASON_CIRCUMSTANTIAL_MIN_APPLIED:
				continue
			var clause: String = _circumstantial_clause(str(inc.get("label", "")))
			if clause == "":
				continue
			list.append({
				"card_id": "workshop:circ:" + str(inc.get("key", pid)),
				"card_kind": "circumstantial",
				"channel": "circumstantial",
				"source": "player",
				"relay_source": "",
				"role": "",
				"night": -1,
				"block": "",
				"contrib": app,
				"strength": clampf(app * 8.0, 0.20, 0.55),
				"why_own": clause,
				"why_public": clause,
				"circ_visibility": "public" if any_public_hub else "shared_player",
				"joint": false,
				"root_ids": [],
				"owners": [],
			})
		if not list.is_empty():
			list.sort_custom(func(a, b): return float(a.get("contrib", 0.0)) > float(b.get("contrib", 0.0)))
			reasons[pid] = list.slice(0, MAX_REASONS_PER_TARGET)


static func append_elimination_fallbacks(
	reasons: Dictionary,
	requested: Dictionary,
	circ_requested: Dictionary,
	attended_ids: Array,
	view: Dictionary,
	self_id: String,
	public_good: Array = []
) -> void:
	var non_ctx_roots: Array = []
	for cid in attended_ids:
		var c: Dictionary = Solver.card_by_id(view, str(cid))
		if c.is_empty() or c.get("quoted", false):
			continue
		if str(c.get("kind", "")) == "context" and str(c.get("context_kind", "")) != "unattributed_report":
			continue
		non_ctx_roots.append(str(cid))
	for pid in requested:
		if pid == self_id or pid in public_good:
			continue
		if not reasons.get(pid, []).is_empty():
			continue
		var total_req: float = float(requested.get(pid, 0.0)) + float(circ_requested.get(pid, 0.0))
		if total_req < Tuning.Workshop.REASON_ELIMINATION_MIN_REQ:
			continue
		var txt: String = "the reports considered together point toward them" if not non_ctx_roots.is_empty() else "narrowing down who hasn't been cleared points toward them"
		reasons[pid] = [{
			"card_id": "workshop:joint:" + pid,
			"card_kind": "joint",
			"channel": "elimination",
			"source": "",
			"relay_source": "",
			"role": "",
			"night": -1,
			"block": "",
			"contrib": total_req,
			"strength": clampf(total_req * 1.4, 0.25, 0.70),
			"why_own": txt,
			"why_public": txt,
			"joint": true,
			"root_ids": non_ctx_roots.duplicate(),
			"owners": [],
		}]


## Public-only view built directly from `w` (`w.npcs` public identity/home/alive + `w.public_log`)
## so podium helpers (`_disclosed_items_against`, `_go_public`) can score newly spoken cards
## through the shared model without `Game` or legacy `reading_strength` / `night_sighting_scale`.
static func public_view_from_world(w) -> Dictionary:
	var people: Array = []
	for p in w.npcs:
		people.append({"id": p.id, "name": p.name, "home": p.home_block, "alive": p.alive})
	var pub_events: Array = []
	for ev in w.public_log:
		var item: Dictionary = {
			"kind": ev.kind,
			"subjects": ev.get("subjects", []).duplicate(),
			"by": ev.get("by", ""),
			"at": {"day": ev.day, "phase": "night" if ev.kind == "demon_death" else ("evening" if ev.kind in ["silenced", "vote"] else "unknown")},
		}
		if ev.kind in ["curse", "curse_lifted"] and ev.has("phase"):
			item["at"] = Evidence.stamp({"day": ev.day, "phase": ev.phase})
		pub_events.append(item)
	var now: Dictionary = {"day": w.day, "phase": "evening"}
	var hist: Dictionary = History.chronology(pub_events, people, now)
	var view: Dictionary = {
		"people": people,
		"cards": [],
		"evil_count": 1 + int(C.SETUPS.get(w.n_npcs, {"minions": 1}).minions),
		"alignment_epoch": "Current alignment" if hist.value.has("curse") else "Original alignment",
		"live_activity": true,
		"timeline": History.from_events(pub_events),
		"chronology": hist.value,
		"world_options": {
			"modifiers": C.SECRET_MOD_LIST.duplicate(),
			"roles": true,
			"identities": true,
		},
	}
	return view


static func score_disclosed_fact_in_world(w, defender_mind, fact: Dictionary, target_id: String) -> Dictionary:
	if not SolverBackend.profiling_enabled:
		return _score_disclosed_fact_in_world_impl(w, defender_mind, fact, target_id)
	var _st: int = SolverBackend.begin_stage("reason_attribution")
	var _res: Dictionary = _score_disclosed_fact_in_world_impl(w, defender_mind, fact, target_id)
	SolverBackend.end_stage(_st)
	return _res

static func _score_disclosed_fact_in_world_impl(w, defender_mind, fact: Dictionary, target_id: String) -> Dictionary:
	var view: Dictionary = public_view_from_world(w)
	var t_idx: int = Solver.person_index(view, target_id)
	if t_idx < 0:
		return {"contrib": 0.25, "strength": 0.30}
	var fkind: String = str(fact.get("kind", ""))
	if fkind == "sighting":
		var nd: int = int(fact.get("day", -1))
		var blk: String = str(fact.get("block", ""))
		if nd < 0 or blk == "":
			return {"contrib": 0.0, "strength": 0.0}
		var scard: Dictionary = {
			"id": "disclosed:sighting:%s:%d:%s" % [str(fact.get("source", "")), nd, blk],
			"kind": "sighting",
			"source": str(fact.get("source", "")),
			"subject": target_id,
			"subjects": [target_id],
			"night": nd,
			"block": blk,
			"observed_at": {"day": nd, "phase": "night"},
			"data": {},
		}
		var context_cards: Array = [scard]
		if defender_mind != null and defender_mind.claim_public and C.ROLES.get(defender_mind.claimed_role, {}).get("night_walk", false):
			context_cards.append({
				"id": "claim:%s:%s" % [target_id, defender_mind.claimed_role],
				"kind": "claim",
				"source": target_id,
				"role": defender_mind.claimed_role,
				"hearing_weight": 0.5,
				"observed_at": {"day": w.day, "phase": "evening"},
				"data": {},
			})
		var t_person: Dictionary = view.people[t_idx]
		var l_good: float = LiveActivity._likelihood(view, context_cards, t_person, "good")
		var l_minion: float = LiveActivity._likelihood(view, context_cards, t_person, "minion")
		var l_demon: float = LiveActivity._likelihood(view, context_cards, t_person, "demon")
		var d_share: float = 1.0 / float(maxi(1, view.evil_count))
		var l_evil: float = d_share * l_demon + (1.0 - d_share) * l_minion
		if l_evil <= l_good * 1.05:
			return {"contrib": 0.04, "strength": 0.15}
		var p0: float = float(view.evil_count) / float(maxi(1, view.people.size() - 1))
		var lr: float = l_evil / maxf(l_good, 1e-12)
		var p1: float = (p0 * lr) / ((1.0 - p0) + p0 * lr)
		var s_mov: float = CaseEval.shift(p0, p1)
		var d_ratio: float = l_demon / maxf(l_good, 1e-12)
		return {
			"contrib": clampf(0.45 * s_mov * Tuning.Workshop.JURY_BELIEF_SCALE, 0.05, 0.40),
			"strength": _strength_from_shift(s_mov, d_ratio, 0.0, false),
		}
	elif fkind == "info":
		return score_reading_entry_in_world(w, str(fact.get("source", "")), {"role": fact.get("role", ""), "day": int(fact.get("day", 0)), "phase": fact.get("phase", C.NIGHT), "data": fact.get("data", {})}, target_id)
	return {"contrib": 0.20, "strength": 0.30}


static func score_reading_entry_in_world(w, src_id: String, entry: Dictionary, target_id: String) -> Dictionary:
	if not SolverBackend.profiling_enabled:
		return _score_reading_entry_in_world_impl(w, src_id, entry, target_id)
	var _st: int = SolverBackend.begin_stage("reason_attribution")
	var _res: Dictionary = _score_reading_entry_in_world_impl(w, src_id, entry, target_id)
	SolverBackend.end_stage(_st)
	return _res

static func _score_reading_entry_in_world_impl(w, src_id: String, entry: Dictionary, target_id: String) -> Dictionary:
	var role: String = str(entry.get("role", ""))
	var data: Dictionary = entry.get("data", {})
	var nd: int = int(entry.get("day", 0))
	var view: Dictionary = public_view_from_world(w)
	var t_idx: int = Solver.person_index(view, target_id)
	if t_idx < 0:
		return {"contrib": 0.15, "strength": 0.30}
	if role == "nightwatch":
		if target_id in data.get("seen", []):
			return score_disclosed_fact_in_world(w, w.by_id.get(target_id), {"kind": "sighting", "source": src_id, "day": nd, "block": str(data.get("block", ""))}, target_id)
		return {"contrib": 0.0, "strength": 0.0}
	if role == "medium":
		var item: Dictionary = data.get("item", {})
		if str(item.get("type", "")) == "sighting" and str(item.get("who", "")) == target_id:
			return score_disclosed_fact_in_world(w, w.by_id.get(target_id), {"kind": "sighting", "source": src_id, "day": int(item.get("night", nd)), "block": str(item.get("block", ""))}, target_id)
		if str(item.get("type", "")) == "reading" and item.get("entry") is Dictionary:
			return score_reading_entry_in_world(w, str(data.get("dead", src_id)), item.entry, target_id)
		return {"contrib": 0.20, "strength": 0.45}
	var phase_name: String = "night"
	if entry.has("phase") and int(entry.get("phase", C.NIGHT)) != C.NIGHT:
		phase_name = str(C.PHASES[int(entry.phase)]).to_lower()
	var rcard: Dictionary = {
		"id": "probe:%s:%d:%s" % [src_id, nd, role],
		"kind": "report",
		"source": src_id,
		"role": role,
		"night": nd if phase_name == "night" or role in ["martyr", "sexton"] else -1,
		"observed_at": {"day": nd, "phase": phase_name},
		"data": data.duplicate(true),
		"subject": "",
		"subjects": [],
	}
	view.cards = [rcard]
	var empty_case: Dictionary = Solver.empty_case()
	empty_case.cards = [rcard.id]
	empty_case.conclusion = {"type": "evil", "target": target_id, "at": view.alignment_epoch}
	var neutral: Dictionary = CaseEval.neutral_listener(view)
	var cc: Dictionary = CaseEval.compile(view, [rcard], empty_case, [])
	var universe: Array = Solver.universe(view)
	var nc: int = cc.team.size()
	if nc == 0 or universe.is_empty():
		return {"contrib": 0.20, "strength": 0.35}
	var reps: Array = []
	for c_idx in range(nc):
		reps.append(universe[cc.rep[c_idx]])
	var team_prior: PackedFloat64Array = CaseEval._team_prior(view, neutral)
	var base_w: PackedFloat64Array = PackedFloat64Array()
	base_w.resize(nc)
	for c_idx in range(nc):
		base_w[c_idx] = cc.count[c_idx] * team_prior[cc.team[c_idx]]
	var pr0: Dictionary = _person_probs(view, reps, base_w, t_idx)
	var scored: Dictionary = _score_single_report(view, cc, reps, team_prior, rcard, target_id, t_idx, pr0, neutral, neutral, [], {}, "", 0.0, Tuning.Workshop.JURY_BELIEF_SCALE)
	if scored.is_empty():
		return {"contrib": 0.10, "strength": 0.25}
	return {"contrib": float(scored.contrib), "strength": float(scored.strength)}


static func _score_single_report(
	view: Dictionary,
	cc: Dictionary,
	reps: Array,
	team_prior: PackedFloat64Array,
	card: Dictionary,
	pid: String,
	p_idx: int,
	pr0: Dictionary,
	listener: Dictionary,
	eval_listener: Dictionary,
	own_ids: Array,
	knowledge: Dictionary,
	self_id: String,
	dull: float,
	belief_scale: float,
	precomputed: Dictionary = {}
) -> Dictionary:
	var err: float
	var w_one: PackedFloat64Array
	if precomputed.has("w_one"):
		w_one = precomputed["w_one"]
		err = float(precomputed["err"])
	else:
		var nc: int = reps.size()
		var r_tab: PackedByteArray = Solver.report_table(view, card)
		var v_tab: PackedByteArray = CaseEval._valid_table(view, card)
		err = CaseEval.reading_error(view, card, eval_listener, own_ids)
		var q: float = CaseEval.chance_content(view, card)
		var f_one: PackedFloat64Array = _subset_fits(view, cc, [card], knowledge)
		w_one = PackedFloat64Array()
		w_one.resize(nc)
		for c_idx in range(nc):
			var u_idx: int = cc.rep[c_idx]
			var st: int = 0 if r_tab[u_idx] == 1 else (1 if v_tab[u_idx] == 1 else 2)
			w_one[c_idx] = cc.count[c_idx] * team_prior[cc.team[c_idx]] * f_one[c_idx] * CaseEval._factor(st, err, q)
	var pr1: Dictionary = _person_probs(view, reps, w_one, p_idx)
	if pr1.total <= 1e-18:
		return {}
	var s_evil: float = CaseEval.shift(pr0.evil, pr1.evil)
	var csrc: String = str(card.get("source", ""))
	var crole: String = str(card.get("role", ""))
	var hl_p: float = 0.0
	var align_c: float = 0.45 * s_evil
	if csrc != pid and not (crole == "archivist" and C.ROLES.get(str(card.get("data", {}).get("role", "")), {}).get("align", "good") != "evil"):
		hl_p = _headline_chance(card, pid)
		if hl_p > 0.0:
			var credence: float = 1.0 - err
			var hit: float = clampf(hl_p * credence * _card_trust(card, listener, bool(card.get("via_player_only", false))), 0.0, 1.0)
			if hit > pr0.evil:
				var hl_sig: float = 0.45 * CaseEval.shift(pr0.evil, hit)
				if hl_sig > align_c:
					align_c += dull * (hl_sig - align_c)
	var contrib: float = align_c * belief_scale
	if contrib < MIN_ITEM_CONTRIB:
		return {}
	var d_ratio: float = (pr1.demon / maxf(1.0 - pr1.demon, 1e-6)) / maxf(pr0.demon / maxf(1.0 - pr0.demon, 1e-6), 1e-6)
	var strength: float = _strength_from_shift(s_evil, d_ratio, hl_p, csrc == pid and str(knowledge.get("own_role", "")) == crole)
	var cid: String = str(card.get("id", ""))
	var rsrc_rep: String = str(card.get("relay_source", ""))
	var eff_src: String = rsrc_rep if rsrc_rep != "" else csrc
	var eff_role: String = "medium" if rsrc_rep != "" else crole
	var eff_night: int = int(card.get("relay_observed_at", {}).get("day", card.get("night", -1))) if rsrc_rep != "" else int(card.get("night", card.get("observed_at", {}).get("day", -1)))
	var channel: String = "role_clash" if eff_src == pid else "report"
	var why_pair: Array = _report_why_pair(view, card, pid, self_id)
	return {
		"card_id": cid,
		"card_kind": "report",
		"channel": channel,
		"source": eff_src,
		"relay_source": rsrc_rep,
		"role": eff_role,
		"night": eff_night,
		"block": str(card.get("block", "")),
		"contrib": contrib,
		"strength": strength,
		"why_own": str(why_pair[0]),
		"why_public": str(why_pair[1]),
		"joint": false,
		"root_ids": [cid],
	}


static func _score_movement_sighting(
	view: Dictionary,
	attended: Array,
	card: Dictionary,
	pid: String,
	p_idx: int,
	pr0: Dictionary,
	listener: Dictionary,
	self_id: String,
	belief_scale: float
) -> Dictionary:
	if not LiveActivity.available(view):
		return {}
	var t_person: Dictionary = view.people[p_idx]
	var nd: int = int(card.get("night", card.get("observed_at", {}).get("day", -1)))
	var context_cards: Array = [card]
	var has_alibi: bool = false
	for ac in attended:
		if ac.get("quoted", false) and str(ac.get("kind", "")) != "alibi":
			continue
		var akind: String = str(ac.get("kind", ""))
		if akind in ["claim", "report"] and str(ac.get("source", "")) == pid and str(ac.get("id", "")) != str(card.get("id", "")):
			context_cards.append(ac)
		elif akind == "secret_claim" and str(ac.get("subject", "")) == pid:
			context_cards.append(ac)
		elif akind == "alibi" and str(ac.get("subject", "")) == pid and int(ac.get("night", -1)) == nd:
			context_cards.append(ac)
			has_alibi = true

	var l_good: float = LiveActivity._likelihood(view, context_cards, t_person, "good")
	var l_minion: float = LiveActivity._likelihood(view, context_cards, t_person, "minion")
	var l_demon: float = LiveActivity._likelihood(view, context_cards, t_person, "demon")
	var d_share: float = clampf(pr0.demon / maxf(pr0.evil, 1e-6), 0.25, 0.60)
	var l_evil: float = d_share * l_demon + (1.0 - d_share) * l_minion
	var ct: float = _card_trust(card, listener, bool(card.get("via_player_only", false)))

	var s_mov: float = 0.0
	if l_good <= 1e-12 and l_evil > 1e-12:
		s_mov = 0.85 * ct
	elif l_evil > l_good * 1.08:
		var lr_mov: float = 1.0 + ct * ((l_evil / maxf(l_good, 1e-12)) - 1.0)
		var p_post: float = (pr0.evil * lr_mov) / ((1.0 - pr0.evil) + pr0.evil * lr_mov)
		s_mov = CaseEval.shift(pr0.evil, p_post)
	else:
		return {}

	var contrib: float = 0.45 * s_mov * belief_scale
	if contrib < MIN_ITEM_CONTRIB:
		return {}
	var d_ratio_mov: float = 1.0 + ct * ((l_demon / maxf(l_good, 1e-12)) - 1.0) if l_good > 1e-12 else 6.0
	var strength: float = _strength_from_shift(s_mov, d_ratio_mov, 0.0, false)
	var cid: String = str(card.get("id", ""))
	var csrc: String = str(card.get("source", ""))
	var rsrc: String = str(card.get("relay_source", ""))
	var blk: String = str(card.get("data", {}).get("block", "")) if str(card.get("kind", "")) == "report" else str(card.get("block", ""))
	var why_pair: Array = _movement_why_pair(view, card, pid, self_id, blk, nd, has_alibi)
	return {
		"card_id": cid,
		"card_kind": "report" if rsrc != "" or str(card.get("kind", "")) == "report" else "sighting",
		"channel": "alibi_contradiction" if has_alibi else "movement_out",
		"source": rsrc if rsrc != "" else csrc,
		"relay_source": rsrc,
		"role": "medium" if rsrc != "" else str(card.get("role", "")),
		"night": nd,
		"block": blk,
		"contrib": contrib,
		"strength": strength,
		"why_own": str(why_pair[0]),
		"why_public": str(why_pair[1]),
		"joint": false,
		"root_ids": [cid],
	}


static func _augment_joint_leave_one_out(
	items_by_id: Dictionary,
	view: Dictionary,
	reps: Array,
	attended: Array,
	loo_ctx: Dictionary,
	pid: String,
	p_idx: int,
	pr0: Dictionary,
	full_shift: float,
	self_id: String,
	belief_scale: float
) -> void:
	var pid_cards: Array = []
	for ac in attended:
		if not ac.get("quoted", false) and (str(ac.get("source", "")) == pid or pid in _mentions(ac)):
			pid_cards.append(str(ac.get("id", "")))

	# A) Movement-level leave-one-out: e.g., complete Vigil / coverage ruling out `pid`'s claimed duty walk.
	if LiveActivity.available(view):
		var t_person: Dictionary = view.people[p_idx]
		var pid_duty_cards: Array = attended.filter(func(c): return not c.get("quoted", false) and str(c.get("source", "")) == pid and str(c.get("kind", "")) == "report" and str(c.get("role", "")) in ["nightwatch", "warden", "medium", "lamplighter"])
		if not pid_duty_cards.is_empty():
			var full_lg: float = LiveActivity._likelihood(view, attended, t_person, "good")
			var full_ld: float = LiveActivity._likelihood(view, attended, t_person, "demon")
			var full_lm: float = LiveActivity._likelihood(view, attended, t_person, "minion")
			if full_lg <= 1e-12 and (full_ld > 1e-12 or full_lm > 1e-12):
				for dcard in pid_duty_cards:
					var d_night: int = int(dcard.get("night", -1))
					for obs in attended:
						if obs.get("quoted", false) or str(obs.get("id", "")) == str(dcard.get("id", "")):
							continue
						if int(obs.get("night", -1)) != d_night or str(obs.get("kind", "")) not in ["sighting", "coverage", "alibi"]:
							continue
						var without_obs: Array = attended.filter(func(x): return str(x.get("id", "")) != str(obs.get("id", "")))
						if LiveActivity._likelihood(view, without_obs, t_person, "good") > 1e-9:
							var obs_id: String = str(obs.get("id", ""))
							var d_id: String = str(dcard.get("id", ""))
							var d_blk: String = str(dcard.get("data", {}).get("block", dcard.get("block", "")))
							var txt: String = "their claimed %s duty on %s contradicts who was actually seen there" % [C.role_name(str(dcard.get("role", ""))), C.block_name(d_blk) if d_blk in C.BLOCKS else "that block"]
							_put_item(items_by_id, {
								"card_id": obs_id if str(obs.get("source", "")) == self_id else d_id,
								"card_kind": str(obs.get("kind", "sighting")) if str(obs.get("source", "")) == self_id else "report",
								"channel": "joint_contradiction",
								"source": str(obs.get("source", "")),
								"relay_source": "",
								"role": str(dcard.get("role", "")),
								"night": d_night,
								"block": d_blk,
								"contrib": maxf(0.45 * full_shift * belief_scale, 0.25),
								"strength": clampf(0.55 + 0.40 * full_shift, 0.65, 0.96),
								"why_own": txt,
								"why_public": txt,
								"joint": true,
								"root_ids": [obs_id, d_id],
							})

	# B) Report / role-constraint leave-one-out across `attended` cards.
	# Test own cards first so an unshared firsthand reading (e.g. Hollis's Gravedigger vs. Odette's Archivist)
	# anchors the contradiction on the listener's own secret reading rather than the public claim alone.
	var candidates: Array = []
	for c in attended:
		if c.get("quoted", false) or str(c.get("kind", "")) not in ["report", "claim"]:
			continue
		var holder_src: String = str(c.get("relay_source", "")) if str(c.get("relay_source", "")) != "" else str(c.get("source", ""))
		if holder_src == self_id:
			candidates.append(c)
	# Other people's cards are tested only when they bear on `pid`: they mention them, or
	# concern a gift `pid` claims or reports with. Each test can re-solve role constraints,
	# so unrelated cards are skipped (purge 2a performance; same contradictions found).
	var pid_roles: Array = []
	for pc in attended:
		if not pc.get("quoted", false) and str(pc.get("source", "")) == pid and str(pc.get("kind", "")) in ["report", "claim"]:
			var pr_role: String = str(pc.get("role", ""))
			if pr_role != "" and pr_role not in pid_roles:
				pid_roles.append(pr_role)
	var others: Array = []
	for c in attended:
		if c.get("quoted", false) or str(c.get("kind", "")) not in ["report", "claim"]:
			continue
		var holder_src2: String = str(c.get("relay_source", "")) if str(c.get("relay_source", "")) != "" else str(c.get("source", ""))
		if holder_src2 == self_id or holder_src2 == pid:
			continue
		var c_role: String = str(c.get("role", ""))
		var c_data_role: String = str(c.get("data", {}).get("role", "")) if c.get("data", {}) is Dictionary else ""
		if pid in _mentions(c) or c_role in pid_roles or (c_data_role != "" and c_data_role in pid_roles):
			others.append(c)
	candidates.append_array(others.slice(0, LOO_MAX_OTHER_CARDS))

	var found_own_joint: bool = false
	for cand in candidates:
		var cid: String = str(cand.get("id", ""))
		var cand_rsrc: String = str(cand.get("relay_source", ""))
		var csrc: String = cand_rsrc if cand_rsrc != "" else str(cand.get("source", ""))
		if csrc != self_id and found_own_joint:
			break
		var crole: String = str(cand.get("role", ""))
		var post_wo: PackedFloat64Array = _loo_post(loo_ctx, cand)
		var pr_wo: Dictionary = _person_probs(view, reps, post_wo, p_idx)
		if pr_wo.total <= 1e-18:
			continue
		var shift_wo: float = CaseEval.shift(pr0.evil, pr_wo.evil)
		var drop: float = full_shift - shift_wo
		if drop < 0.08:
			continue
		var joint_contrib: float = 0.45 * drop * belief_scale
		if joint_contrib < MIN_ITEM_CONTRIB:
			continue

		if items_by_id.has(cid):
			var existing: Dictionary = items_by_id[cid]
			if joint_contrib > float(existing.get("contrib", 0.0)):
				existing["contrib"] = joint_contrib
				existing["strength"] = maxf(float(existing.get("strength", 0.3)), _strength_from_shift(drop, 1.0, 0.0, csrc == self_id))
			continue

		var roots: Array = [cid]
		for pc_id in pid_cards:
			if pc_id != cid and pc_id not in roots:
				roots.append(pc_id)
		if roots.size() == 1:
			for oc in attended:
				var oc_id: String = str(oc.get("id", ""))
				if not oc.get("quoted", false) and oc_id != cid and str(oc.get("kind", "")) in ["report", "claim"]:
					roots.append(oc_id)
		var has_pid_claim: bool = attended.any(func(o): return not o.get("quoted", false) and str(o.get("source", "")) == pid and str(o.get("kind", "")) in ["report", "claim"])
		var why_own: String
		var why_pub: String
		# What the reading says, when it's about someone else (Case 12926: a Confessor's
		# reading that cleared the man Nisha accused read as a bare "contradicts their account").
		var gist: String = _reading_gist(view, cand, pid, csrc)
		if csrc == self_id:
			found_own_joint = true
			if gist != "":
				why_own = ("my reading %s, and that doesn't square with their account" % gist) if has_pid_claim else ("my reading %s, and with the other reports that points at them" % gist)
			else:
				why_own = "my own reading contradicts their account" if has_pid_claim else "my own reading, taken with the other reports, points at them"
			if gist != "" and crole != "" and has_pid_claim:
				why_pub = "the %s reading %s, and that doesn't square with their account" % [C.role_name(crole), gist]
			else:
				why_pub = ("the %s report contradicts their account" % C.role_name(crole)) if has_pid_claim and crole != "" else "the reports considered together point toward them"
		else:
			var sname: String = Solver.person_name(view, csrc) if csrc != "player" else "the Demonologist"
			if gist != "" and crole != "":
				why_own = ("%s's %s reading %s, and that doesn't square with their account" % [sname, C.role_name(crole), gist]) if has_pid_claim else ("%s's %s reading %s, and with the other reports that points at them" % [sname, C.role_name(crole), gist])
			else:
				why_own = ("%s's %s report contradicts their account" % [sname, C.role_name(crole)]) if has_pid_claim and crole != "" else "the reports considered together point toward them"
			why_pub = why_own

		_put_item(items_by_id, {
			"card_id": cid,
			"card_kind": str(cand.get("kind", "report")),
			"channel": "joint_contradiction",
			"source": csrc,
			"relay_source": cand_rsrc,
			"role": "medium" if cand_rsrc != "" else crole,
			"night": int(cand.get("relay_observed_at", {}).get("day", cand.get("night", -1))) if cand_rsrc != "" else int(cand.get("night", cand.get("observed_at", {}).get("day", -1))),
			"block": str(cand.get("block", "")),
			"contrib": joint_contrib,
			"strength": _strength_from_shift(drop, 1.0, 0.0, csrc == self_id),
			"why_own": why_own,
			"why_public": why_pub,
			"joint": true,
			"root_ids": roots,
		})


## The class posterior without one report or claim (memoised per refresh).
static func _loo_post(ctx: Dictionary, cand: Dictionary) -> PackedFloat64Array:
	var l_cid: String = str(cand.get("id", ""))
	if ctx.memo.has(l_cid):
		return ctx.memo[l_cid]
	var cc: Dictionary = ctx.cc
	var attended: Array = ctx.attended
	var rep_idx: int = -1
	for j in range(cc.reports.size()):
		if str(cc.reports[j].get("id", "")) == l_cid:
			rep_idx = j
			break
	var like_wo: PackedFloat64Array = CaseEval._class_like(cc, ctx.errs, rep_idx) if rep_idx >= 0 else ctx.like_full
	var l_role: String = str(cand.get("role", ""))
	var needs_fits_recheck: bool = (
		str(cand.get("kind", "")) == "claim"
		or l_role in ["gravedigger", "archivist", "clerk", "seer", "martyr", "veteran", "chronicler", "augur", "magistrate", "surveyor", "executor", "registrar"]
		or attended.any(func(o): return not o.get("quoted", false) and str(o.get("id", "")) != l_cid and str(o.get("role", "")) == l_role)
	)
	var fits_wo: PackedFloat64Array = ctx.fits_full
	if needs_fits_recheck:
		fits_wo = _subset_fits(ctx.view, cc, attended.filter(func(o): return str(o.get("id", "")) != l_cid), ctx.knowledge)
	var post_wo: PackedFloat64Array = PackedFloat64Array()
	post_wo.resize(ctx.nc)
	for c_idx in range(ctx.nc):
		post_wo[c_idx] = cc.count[c_idx] * ctx.team_prior[cc.team[c_idx]] * fits_wo[c_idx] * like_wo[c_idx] * ctx.move_full[c_idx] * ctx.test_full[c_idx]
	ctx.memo[l_cid] = post_wo
	return post_wo



static func _subset_fits(view: Dictionary, cc: Dictionary, cards: Array, knowledge: Dictionary) -> PackedFloat64Array:
	var nc: int = cc.team.size()
	if not view.get("world_options", {}).get("roles", false):
		var ones: PackedFloat64Array = PackedFloat64Array()
		ones.resize(nc)
		ones.fill(1.0)
		return ones
	var card_sig: Array = []
	for c in cards:
		card_sig.append([c.get("id", ""), c.get("kind", ""), c.get("source", ""), c.get("role", ""), c.get("hearing_weight", 1.0), c.has("relay_source"), c.get("quoted", false)])
	var live: bool = Domain.live(view)
	var neutral_key: int = hash([cc.key, "ra_neutral", live, card_sig])
	if not _fits_cache.has(neutral_key):
		if _fits_cache.size() > 256:
			_fits_cache.clear()
		_fits_cache[neutral_key] = CaseEval._fits_over(view, cc, cards, {}, range(nc))
	var neutral: PackedFloat64Array = _fits_cache[neutral_key]
	var personal: Dictionary = {
		"self": knowledge.get("self", ""),
		"own_role": knowledge.get("own_role", ""),
		"own_outings": knowledge.get("own_outings", {}),
	}
	if not knowledge.get("public_roles", {}).is_empty():
		personal["public_roles"] = knowledge.public_roles
	var fits: PackedFloat64Array = neutral
	if personal.own_role != "" or not personal.own_outings.is_empty() or not personal.get("public_roles", {}).is_empty():
		var p_key: int = hash([cc.key, "ra_personal", live, card_sig, personal])
		if not _fits_cache.has(p_key):
			if _fits_cache.size() > 256:
				_fits_cache.clear()
				_fits_cache[neutral_key] = neutral
			var open: Array = []
			for c_idx in range(nc):
				if neutral[c_idx] > 0.0:
					open.append(c_idx)
			_fits_cache[p_key] = CaseEval._fits_over(view, cc, cards, personal, open)
		fits = _fits_cache[p_key]
	return _apply_curse_good(view, cc, fits, knowledge)


static func _apply_curse_good(view: Dictionary, cc: Dictionary, fits: PackedFloat64Array, knowledge: Dictionary) -> PackedFloat64Array:
	if not view.get("chronology", {}).has("curse"):
		return fits
	var copy_f: PackedFloat64Array = fits.duplicate()
	var worlds: Array = Solver.universe(view)
	for c_idx in range(copy_f.size()):
		var world: Dictionary = worlds[cc.rep[c_idx]]
		for person in knowledge.get("good", []):
			if TimeModel.evil_at(view, world, person, knowledge.get("good_epoch", view.alignment_epoch)):
				copy_f[c_idx] = 0.0
		for fact in knowledge.get("timed_good", []):
			if TimeModel.evil_at(view, world, fact.person, fact.at):
				copy_f[c_idx] = 0.0
	return copy_f


static func _person_probs(view: Dictionary, reps: Array, weights: PackedFloat64Array, p_idx: int) -> Dictionary:
	var total: float = 0.0
	var evil_sum: float = 0.0
	var demon_sum: float = 0.0
	var has_curse: bool = view.get("chronology", {}).has("curse")
	var epoch: String = str(view.get("alignment_epoch", "Original alignment"))
	var bit: int = 1 << p_idx
	for c_idx in range(reps.size()):
		var w: float = weights[c_idx]
		if w <= 0.0:
			continue
		total += w
		var world: Dictionary = reps[c_idx]
		var is_evil: bool = TimeModel.evil_index(view, world, p_idx, epoch) if has_curse else ((int(world.evil) & bit) != 0)
		if is_evil:
			evil_sum += w
		if int(world.get("demon", -1)) == p_idx:
			demon_sum += w
	if total <= 1e-18:
		return {"evil": 0.0, "demon": 0.0, "total": 0.0}
	return {"evil": evil_sum / total, "demon": demon_sum / total, "total": total}


static func _strength_from_shift(s_evil: float, d_ratio: float, headline_p: float, own_contradiction: bool) -> float:
	var log2_d: float = log(maxf(d_ratio, 1.0)) / log(2.0)
	var val: float = maxf(
		1.15 * s_evil,
		0.30 * log2_d + 0.45 * s_evil + 0.80 * headline_p
	)
	if own_contradiction:
		val = maxf(val, 0.55 + 0.45 * s_evil)
	return clampf(val, 0.15, 0.98)


static func _put_item(items_by_id: Dictionary, item: Dictionary) -> void:
	var cid: String = str(item.get("card_id", ""))
	if cid == "":
		return
	if not items_by_id.has(cid) or float(item.get("contrib", 0.0)) > float(items_by_id[cid].get("contrib", 0.0)):
		items_by_id[cid] = item


static func _report_why_pair(view: Dictionary, card: Dictionary, pid: String, self_id: String) -> Array:
	var csrc: String = str(card.get("source", ""))
	var crole: String = str(card.get("role", ""))
	var data: Dictionary = card.get("data", {}) if card.get("data", {}) is Dictionary else {}
	if csrc == pid:
		if crole == "executor" and data.has("role"):
			var ex_tid: String = str(data.get("target", ""))
			var ex_rid: String = str(data.get("role", ""))
			var ex_day: int = int(card.get("observed_at", {}).get("day", -1))
			if ex_tid != "" and view.has("timeline") and not preload("res://workshop/live_history.gd").died_before_morning(view, ex_tid, ex_day):
				var no_dt_txt: String = "%s claimed a post-death Executor reading on %s without a matching death" % [Solver.person_name(view, pid), Solver.person_name(view, ex_tid)]
				return [no_dt_txt, no_dt_txt]
			if ex_tid != "" and ex_rid != "":
				var ex_txt: String = "%s claimed %s was the %s, which doesn't fit the facts as I know them" % [Solver.person_name(view, pid), Solver.person_name(view, ex_tid), C.role_name(ex_rid)]
				return [ex_txt, ex_txt]
		if crole == "gravedigger":
			var ex_id: String = str(data.get("executed", ""))
			var r_id: String = str(data.get("role", ""))
			var gd_night: int = int(card.get("night", -1)) if int(card.get("night", -1)) >= 0 else int(card.get("observed_at", {}).get("day", -1))
			if ex_id != "" and view.has("timeline") and not preload("res://workshop/live_history.gd").executed(view, ex_id, gd_night):
				var no_ex_txt: String = "%s claimed a Gravedigger reading on %s when no such hanging happened" % [Solver.person_name(view, pid), Solver.person_name(view, ex_id)]
				return [no_ex_txt, no_ex_txt]
			if ex_id != "" and r_id != "":
				var gd_txt: String = "%s claimed %s was the %s, which doesn't fit the facts as I know them" % [Solver.person_name(view, pid), Solver.person_name(view, ex_id), C.role_name(r_id)]
				return [gd_txt, gd_txt]
		var imp_txt: String = "their %s report doesn't fit the facts as I know them" % C.role_name(crole)
		return [imp_txt, imp_txt]

	var own_src: bool = (csrc == self_id)
	var third_poss: String = ("the %s" % C.role_name(crole)) if own_src else ("%s's" % Solver.person_name(view, csrc))
	if card.has("relay_source"):
		var med_id: String = str(card.get("relay_source", ""))
		own_src = (med_id == self_id)
		third_poss = "the Medium's" if own_src else ("%s's" % Solver.person_name(view, med_id))
	var own_poss: String = "my own" if own_src else third_poss

	match crole:
		"seer":
			return [
				"%s sight said one of them is the demon" % own_poss,
				"%s sight said one of them is the demon" % third_poss,
			]
		"archivist":
			var a_role: String = C.role_name(str(data.get("role", "")))
			return [
				"%s records tie them to the %s" % [own_poss, a_role],
				"%s records tie them to the %s" % [third_poss, a_role],
			]
		"dowser":
			if data.has("count") and data.has("block"):
				var d_blk: String = C.block_name(str(data.get("block", "")))
				var d_n: int = int(data.get("count", 0))
				var d_what: String = "one evil soul" if d_n == 1 else "%d evil souls" % d_n
				return [
					"%s reading on %s found %s in a crowd that included them" % [own_poss, d_blk, d_what],
					"%s reading on %s found %s in a crowd that included them" % [third_poss, d_blk, d_what],
				]
			return [
				"%s reading pointed at that crowd" % own_poss,
				"%s reading pointed at that crowd" % third_poss,
			]
		"hearthwitch":
			return [
				"%s reading pointed at their neighbours" % own_poss,
				"%s reading pointed at their neighbours" % third_poss,
			]
		"surveyor":
			if data.has("block"):
				var s_blk: String = C.block_name(str(data.get("block", "square")))
				var s_what: String = "everyone living on %s is on the same side" % s_blk if bool(data.get("same", false)) else "the people living on %s aren't all on one side" % s_blk
				var lives_there: bool = view.get("people", []).any(func(p): return p.get("id", "") == pid and p.get("home", "") == str(data.get("block", "")))
				if not lives_there:
					# Someone off the block: the reading weighs on them through the other reports
					# it clashes with (an Archivist pair on that block, say), not through their home.
					return [
						"%s reading says %s, and taken with the other reports that points at them" % [own_poss, s_what],
						"%s reading says %s, and taken with the other reports that points at them" % [third_poss, s_what],
					]
				return [
					"%s reading says %s, and they live there" % [own_poss, s_what],
					"%s reading says %s, and they live there" % [third_poss, s_what],
				]
			return [
				"%s block count points toward their quarter" % own_poss,
				"%s block count points toward their quarter" % third_poss,
			]
		"chronicler":
			return [
				"%s chronicle placed a minion among those three" % own_poss,
				"%s chronicle placed a minion among those three" % third_poss,
			]
		"augur":
			return [
				"%s evening omen sensed the demon along that daytime path" % own_poss,
				"%s evening omen sensed the demon along that daytime path" % third_poss,
			]
		"magistrate":
			return [
				"%s reading on that day's first nomination pointed at them" % own_poss,
				"%s reading on that day's first nomination pointed at them" % third_poss,
			]
		"executor":
			var e_role: String = C.role_name(str(data.get("role", "")))
			return [
				"%s Executor reading named them the %s" % [own_poss, e_role],
				"%s Executor reading named them the %s" % [third_poss, e_role],
			]
		"registrar":
			return [
				"%s register check conflicted with their claim or matched a minion role" % own_poss,
				"%s register check conflicted with their claim or matched a minion role" % third_poss,
			]
		"martyr":
			var m_txt: String = "the Martyr lived when they went to the rope"
			return [m_txt, m_txt]
		"veteran":
			var v_blk: String = C.block_name(str(data.get("block", "")))
			var v_txt: String = "the demon came by way of %s, where they live" % v_blk
			return [v_txt, v_txt]
		_:
			return [
				"%s reading pointed at them" % own_poss,
				"%s reading pointed at them" % third_poss,
			]


static func _movement_why_pair(view: Dictionary, card: Dictionary, _pid: String, self_id: String, blk: String, nd: int, has_alibi: bool) -> Array:
	if has_alibi:
		var alibi_txt: String = "they claimed to stay home on %s, but were seen out at night" % C.night_name(nd)
		return [alibi_txt, alibi_txt]
	if card.has("relay_source"):
		var med_src: String = str(card.get("relay_source", ""))
		var dead_txt: String = "the dead saw them out at night"
		return ["my own Medium reading said the dead saw them out at night" if med_src == self_id else dead_txt, dead_txt]
	var csrc: String = str(card.get("source", ""))
	var near_death: bool = false
	for event in view.get("timeline", {}).get("events", []):
		if str(event.get("kind", "")) in ["demon_death", "demon_attack"] and int(event.get("at", {}).get("day", -1)) == nd:
			for v_id in event.get("subjects", []):
				var v_matches: Array = view.get("people", []).filter(func(p): return str(p.get("id", "")) == str(v_id))
				if not v_matches.is_empty() and str(v_matches[0].get("home", "")) == blk:
					near_death = true
	if str(card.get("kind", "")) == "report" and str(card.get("role", "")) == "nightwatch":
		var tail: String = " where someone was killed" if near_death else ""
		var pub_nw: String = ("the Night Watch saw them out at night%s" % tail) if csrc == self_id else ("%s saw them out at night%s" % [Solver.person_name(view, csrc), tail])
		var own_nw: String = ("my own watch saw them out at night%s" % tail) if csrc == self_id else pub_nw
		return [own_nw, pub_nw]
	if csrc == self_id:
		var blk_name: String = C.block_name(blk) if blk in C.BLOCKS else "the street"
		var own_sight: String = "I saw them out on %s on %s" % [blk_name, C.night_name(nd)]
		return [own_sight, own_sight]
	if csrc == "player":
		var p_blk: String = C.block_name(blk) if blk in C.BLOCKS else "the street"
		var p_txt: String = "the Demonologist saw them out on %s on %s" % [p_blk, C.night_name(nd)]
		return [p_txt, p_txt]
	var sname: String = Solver.person_name(view, csrc)
	if float(card.get("hearing_weight", 1.0)) < 0.99:
		var rumor_txt: String = "%s says they were out at night" % sname
		return [rumor_txt, rumor_txt]
	var tail2: String = " where someone was killed" if near_death else ""
	var wit_txt: String = "%s saw them out at night%s" % [sname, tail2]
	return [wit_txt, wit_txt]


static func _circumstantial_clause(label: String) -> String:
	var s: String = label.strip_edges().trim_suffix(".")
	if s == "":
		return ""
	if s.begins_with("Spoke with "):
		return "they " + s[0].to_lower() + s.substr(1)
	if s.begins_with("Seen "):
		return "they were " + s[0].to_lower() + s.substr(1)
	if s.begins_with("Close bond ") or s.begins_with("Known rivalry "):
		return "they have a " + s[0].to_lower() + s.substr(1)
	if s.begins_with("Nominated ") or s.begins_with("Voted "):
		return "they " + s[0].to_lower() + s.substr(1)
	if s.begins_with("Fearful refusal") or s.begins_with("Refusal "):
		return "they refused to share information"
	if s.begins_with("Guarded "):
		return "their demeanor has been guarded"
	return s[0].to_lower() + s.substr(1)


static func _headline_chance(card: Dictionary, person: String) -> float:
	var data = card.get("data", {})
	if not (data is Dictionary):
		return 0.0
	match str(card.get("role", "")):
		"seer":
			var spair: Array = data.get("pair", [])
			if bool(data.get("yes", false)) and person in spair:
				return Tuning.Workshop.HEADLINE_SEER / float(maxi(spair.size(), 1))
		"archivist":
			var apair: Array = data.get("pair", [])
			if person in apair:
				return Tuning.Workshop.HEADLINE_ARCHIVIST / float(maxi(apair.size(), 1))
		"dowser":
			var dgroup: Array = data.get("group", [])
			if person in dgroup and int(data.get("count", 0)) > 0:
				return Tuning.Workshop.HEADLINE_DOWSER * float(data.count) / float(maxi(dgroup.size(), 1))
		"chronicler":
			var ctrio: Array = data.get("trio", [])
			if person in ctrio:
				return Tuning.Workshop.HEADLINE_ARCHIVIST / float(maxi(ctrio.size(), 1))
		"magistrate":
			if not bool(data.get("same", true)) and person in [str(data.get("nominator", "")), str(data.get("nominee", ""))]:
				return Tuning.Workshop.HEADLINE_DOWSER * 0.5
		"registrar":
			if bool(data.get("yes", false)) and str(data.get("target", "")) == person and data.get("roles", []).any(func(r): return C.is_minion(str(r))):
				return Tuning.Workshop.HEADLINE_ARCHIVIST * 0.5
	return 0.0


static func _card_trust(card: Dictionary, listener: Dictionary, player_tells: bool) -> float:
	var me: String = str(listener.get("id", ""))
	var source: String = str(card.get("source", ""))
	var t: float = _trust_in(source, listener)
	var provenance = card.get("provenance", {})
	var via: String = str(provenance.get("via", "")) if provenance is Dictionary else ""
	var teller: String = str(card.get("relay_source", card.get("via", via)))
	if teller != "" and teller != source:
		t = 0.5 * (t + _trust_in(teller, listener))
	elif player_tells and source != me and source != "player" and listener.get("npc_trust", {}).has(source):
		t = 0.5 * (t + _trust_in("player", listener))
	return t


static func _trust_in(who: String, listener: Dictionary) -> float:
	if who == "" or who == str(listener.get("id", "")) or who == "town" or who == "evidence":
		return 1.0
	if who == "player":
		return clampf(float(listener.get("player_credibility", listener.get("trust", 0.5))), 0.0, 1.0)
	var trusts: Dictionary = listener.get("npc_trust", {})
	return clampf(float(trusts.get(who, 0.5)), 0.0, 1.0) if trusts.has(who) else 1.0


## A short gist of a reading about someone other than the accused ("cleared Fenwick",
## "named Fenwick as evil", "was about Fenwick"); "" when the reading is about the accused
## or names nobody else.
static func _reading_gist(view: Dictionary, card: Dictionary, pid: String, src: String) -> String:
	var data = card.get("data", {})
	if not data is Dictionary:
		return ""
	var target: String = str(data.get("target", ""))
	if target != "" and target != pid and target != src:
		var tname: String = Solver.person_name(view, target)
		if data.get("good") is bool:
			return ("cleared %s" % tname) if data.good else ("named %s as evil" % tname)
		return "was about %s" % tname
	var others: Array = _mentions(card).filter(func(x): return x is String and x != pid and x != src and x != "")
	if others.size() == 1:
		return "was about %s" % Solver.person_name(view, str(others[0]))
	return ""

static func _mentions(card: Dictionary) -> Array:
	var out: Array = []
	for key in ["subject", "subjects", "target", "who"]:
		var v = card.get(key)
		if v is Array:
			out.append_array(v)
		elif v is String and v != "":
			out.append(v)
	var data = card.get("data", {})
	if data is Dictionary:
		for key in ["pair", "group", "seen", "nbrs", "trio", "target", "chosen", "executed", "guarded", "nominator", "nominee"]:
			var v = data.get(key)
			if v is Array:
				out.append_array(v)
			elif v is String and v != "":
				out.append(v)
	return out
