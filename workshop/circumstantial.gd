## Stage 2 Circumstantial Evidence Hub evaluator.
## Pure portable inputs/outputs: reads the frozen post-Stage-1 snapshot once,
## judges associations and social framing using beliefs about OTHER people rather
## than the target's own suspicion, deduplicates incidents across active cases,
## and enforces +0.015 per incident and +0.045 per (listener, target).
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Solver = preload("res://workshop/solver.gd")
const TimeModel = preload("res://workshop/chronology.gd")

const INCIDENT_MAX = Tuning.Workshop.CIRCUMSTANTIAL_INCIDENT_MAX
const TARGET_CAP = Tuning.Workshop.CIRCUMSTANTIAL_TARGET_CAP
const GATE_REF = Tuning.Workshop.CIRCUMSTANTIAL_GATE_REF
const SMEAR_MIN = Tuning.Workshop.CIRCUMSTANTIAL_SMEAR_MIN
const SMEAR_MAX = Tuning.Workshop.CIRCUMSTANTIAL_SMEAR_MAX
const ACCUSATORY_TYPES = ["evil", "demon", "minion", "suspicious"]


static func _passive_survivor_floor(view: Dictionary, stage1_requested: Dictionary, listener_id: String, known_good: Array) -> float:
	var victims: Array = _demon_victims(view)
	var sil_map: Dictionary = _silenced_by_day(view, view.get("cards", []))
	var silenced_ids: Dictionary = {}
	for d in sil_map:
		for s in sil_map[d]:
			silenced_ids[s] = true
	var vals: Array = []
	for p in view.get("people", []):
		var pid: String = str(p.get("id", ""))
		if pid == "" or pid == listener_id or not p.get("alive", true):
			continue
		if pid in known_good or pid in victims or silenced_ids.has(pid):
			continue
		vals.append(float(stage1_requested.get(pid, 0.0)))
	if vals.is_empty():
		return 0.0
	var lo: float = vals[0]
	var hi: float = vals[0]
	for v in vals:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if vals.size() >= 2 and (hi - lo) < 0.002:
		return maxf(0.0, hi)
	return minf(maxf(0.0, lo), 0.06)


static func stage1_gate(specific_stage1: float, outside_suspicion: float) -> float:
	var s1: float = maxf(0.0, specific_stage1)
	var prior_above: float = maxf(0.0, outside_suspicion - 0.15)
	return clampf((s1 + 0.35 * prior_above) / GATE_REF, 0.0, 1.0)


static func _person_home(view: Dictionary, pid: String) -> String:
	for p in view.get("people", []):
		if p.id == pid:
			return p.get("home", "")
	return ""


static func _silenced_by_day(view: Dictionary, cards: Array) -> Dictionary:
	var by_day = {}
	for event in view.get("timeline", {}).get("events", []):
		if event.get("kind", "") == "silenced" and int(event.get("at", {}).get("day", -1)) >= 1:
			var d: int = int(event.at.day)
			if not by_day.has(d):
				by_day[d] = []
			for s in event.get("subjects", []):
				if s not in by_day[d]:
					by_day[d].append(s)
	for c in cards:
		if c.get("kind", "") == "context" and c.get("context_kind", "") == "silenced":
			var d2: int = int(c.get("observed_at", {}).get("day", c.get("night", -1)))
			if d2 >= 1 and c.get("subject", "") != "":
				if not by_day.has(d2):
					by_day[d2] = []
				if c.subject not in by_day[d2]:
					by_day[d2].append(c.subject)
	return by_day


static func _demon_victims(view: Dictionary) -> Array:
	var out: Array = []
	for event in view.get("timeline", {}).get("events", []):
		if event.get("kind", "") == "demon_death" and int(event.get("at", {}).get("day", -1)) >= 1:
			for s in event.get("subjects", []):
				if s not in out:
					out.append(s)
	return out


## Extract qualifying Stage-2 incidents for `target` from `hub_card_ids` in `view`.
## `post_stage1_susp` holds frozen post-Stage-1 suspicions; only OTHER people's
## suspicions are read when scoring associations, silencing proximity, or votes.
static func extract_hub_incidents(
	view: Dictionary,
	hub_card_ids: Array,
	target: String,
	post_stage1_susp: Dictionary,
	npc_trust: Dictionary,
	known_good: Array = [],
	disputes: Array = []
) -> Dictionary:
	var hub_cards: Array = []
	for cid in hub_card_ids:
		var found: Dictionary = Solver.card_by_id(view, cid)
		if not found.is_empty():
			hub_cards.append(found)
	var all_cards: Array = view.get("cards", [])
	var silenced_map: Dictionary = _silenced_by_day(view, all_cards)
	var victims: Array = _demon_victims(view)
	var incidents: Dictionary = {}
	var matched_cards: Dictionary = {}

	# Pre-index daytime/evening block sightings across view.cards for same-block silencing checks
	var block_presence: Dictionary = {}
	for c in all_cards:
		if c.get("kind", "") in ["location", "evening"] and c.get("block", "") != "":
			var cday: int = int(c.get("day", c.get("observed_at", {}).get("day", -1)))
			var cphase: String = str(c.get("observed_at", {}).get("phase", ""))
			if cday >= 1:
				var bkey = "%d:%s:%s" % [cday, cphase, c.block]
				if not block_presence.has(bkey):
					block_presence[bkey] = []
				for who in c.get("subjects", [c.get("subject", "")]):
					if who != "" and who not in block_presence[bkey]:
						block_presence[bkey].append(who)

	var disputed_alibis: Dictionary = {}
	for d in disputes:
		var ch_id: String = str(d.get("challenged", ""))
		if ch_id != "":
			disputed_alibis[ch_id] = true

	for c in hub_cards:
		var cid: String = c.id
		var kind: String = c.get("kind", "")
		var ctx: String = c.get("context_kind", "")
		var subjs: Array = c.get("subjects", [c.get("subject", "")]).filter(func(x): return x != "")

		# 1. Silenced card itself can pair with another hub card on that day
		if kind == "context" and ctx == "silenced":
			var s_day: int = int(c.get("observed_at", {}).get("day", c.get("night", -1)))
			if hub_cards.any(func(o): return o.get("kind", "") in ["location", "evening"] and int(o.get("day", o.get("observed_at", {}).get("day", -1))) == s_day and target in o.get("subjects", [o.get("subject", "")])):
				matched_cards[cid] = true

		# 2. Breathstealer daytime/evening proximity + Suspicious association
		if kind in ["location", "evening"] and target in subjs:
			var day_num: int = int(c.get("day", c.get("observed_at", {}).get("day", -1)))
			var phase_str: String = str(c.get("observed_at", {}).get("phase", ""))
			var blk: String = str(c.get("block", ""))
			for sv in silenced_map.get(day_num, []):
				if sv == target:
					continue
				var direct_pair: bool = sv in subjs
				var same_slot: bool = sv in block_presence.get("%d:%s:%s" % [day_num, phase_str, blk], [])
				var home_match: bool = blk != "" and blk == _person_home(view, sv)
				if direct_pair or same_slot or home_match:
					var sv_good: float = 1.0 if sv in known_good else clampf(1.0 - float(post_stage1_susp.get(sv, 0.1)), 0.1, 1.0)
					var prox_scale: float = 1.0 if direct_pair else (0.9 if same_slot else 0.8)
					var ikey = "breath_prox:%s:%d" % [target, day_num]
					var val: float = INCIDENT_MAX * prox_scale * sv_good
					if val > incidents.get(ikey, {}).get("raw", 0.0):
						incidents[ikey] = {
							"key": ikey,
							"family": "breathstealer_proximity",
							"raw": val,
							"label": "Seen near %s on Day %d before they were silenced" % [Solver.person_name(view, sv), day_num],
						}
					matched_cards[cid] = true
			if c.get("orig_kind", "") == "conversation" and subjs.size() == 2:
				var partner: String = subjs[0] if subjs[1] == target else subjs[1]
				var p_susp: float = float(post_stage1_susp.get(partner, 0.1))
				if partner != target and partner not in known_good and p_susp >= 0.32:
					var fit: float = clampf((p_susp - 0.28) / 0.35, 0.2, 1.0)
					var akey = "assoc:%s:%s" % [target, partner]
					var aval: float = INCIDENT_MAX * fit
					if aval > incidents.get(akey, {}).get("raw", 0.0):
						incidents[akey] = {
							"key": akey,
							"family": "suspicious_association",
							"raw": aval,
							"label": "Conferred privately with suspected %s" % Solver.person_name(view, partner),
						}
					matched_cards[cid] = true

		# 3. Profile bonds: friend of suspected person OR rival of murder victim
		if kind == "context" and ctx == "bond" and subjs.size() == 2 and target in subjs:
			var other: String = subjs[0] if subjs[1] == target else subjs[1]
			var bkind: String = str(c.get("data", {}).get("bond_kind", ""))
			if bkind == "friend":
				var o_susp: float = float(post_stage1_susp.get(other, 0.1))
				if other not in known_good and o_susp >= 0.32:
					var bfit: float = clampf((o_susp - 0.28) / 0.35, 0.2, 1.0)
					var bkey = "assoc:%s:%s" % [target, other]
					var bval: float = INCIDENT_MAX * bfit
					if bval > incidents.get(bkey, {}).get("raw", 0.0):
						incidents[bkey] = {
							"key": bkey,
							"family": "suspicious_association",
							"raw": bval,
							"label": "Close bond with suspected %s" % Solver.person_name(view, other),
						}
					matched_cards[cid] = true
			elif bkind == "rival" and other in victims:
				var v_good: float = clampf(1.0 - float(post_stage1_susp.get(other, 0.05)), 0.2, 1.0)
				var rkey = "victim_rival:%s:%s" % [target, other]
				var rval: float = INCIDENT_MAX * 0.9 * v_good
				if rval > incidents.get(rkey, {}).get("raw", 0.0):
					incidents[rkey] = {
						"key": rkey,
						"family": "victim_rivalry",
						"raw": rval,
						"label": "Known rivalry with murder victim %s" % Solver.person_name(view, other),
					}
				matched_cards[cid] = true

		# 4. Hostile vote or nomination against someone the listener trusts / knows is good
		if kind == "context" and ctx == "vote":
			var vdata: Dictionary = c.get("data", {})
			var nominee: String = str(vdata.get("nominee", ""))
			var nominator: String = str(vdata.get("nominator", ""))
			var yes_list: Array = vdata.get("yes", [])
			var vday: int = int(c.get("observed_at", {}).get("day", c.get("night", -1)))
			if nominee != "" and nominee != target and (nominator == target or target in yes_list):
				var nom_susp: float = float(post_stage1_susp.get(nominee, 0.1))
				var nom_trust: float = float(npc_trust.get(nominee, 0.5))
				if nominee in known_good or (nom_susp <= 0.28 and nom_trust >= 0.45):
					var role_w: float = 1.0 if nominator == target else 0.85
					var good_w: float = 1.0 if nominee in known_good else clampf((0.35 - nom_susp) / 0.25, 0.3, 1.0) * clampf(0.5 + 0.5 * nom_trust, 0.5, 1.0)
					var vkey = "hostile_vote:%s:%d:%s" % [target, vday, nominee]
					var vval: float = INCIDENT_MAX * role_w * good_w
					if vval > incidents.get(vkey, {}).get("raw", 0.0):
						incidents[vkey] = {
							"key": vkey,
							"family": "hostile_vote",
							"raw": vval,
							"label": "%s %s on Day %d" % ["Nominated" if nominator == target else "Voted to hang", Solver.person_name(view, nominee), vday],
						}
					matched_cards[cid] = true

		# 5. Demeanor / evasiveness tells (refusal, disputed alibi, or low-composure / high-privacy trait)
		if kind == "refusal" and c.get("subject", "") == target:
			var dkey = "demeanor_tell:" + target
			incidents[dkey] = {
				"key": dkey,
				"family": "demeanor_tell",
				"raw": INCIDENT_MAX,
				"label": "Evasive refusal to account for whereabouts",
			}
			matched_cards[cid] = true
		elif kind == "alibi" and c.get("subject", "") == target and (disputed_alibis.has(cid) or hub_cards.any(func(o): return o.get("kind", "") == "sighting" and o.get("night", -1) == c.get("night", -2) and target in o.get("subjects", [o.get("subject", "")]))):
			var dkey2 = "demeanor_tell:" + target
			incidents[dkey2] = {
				"key": dkey2,
				"family": "demeanor_tell",
				"raw": INCIDENT_MAX,
				"label": "Caught in a contradicted night alibi",
			}
			matched_cards[cid] = true
		elif kind == "context" and ctx == "trait" and c.get("subject", "") == target:
			var tr_name: String = str(c.get("data", {}).get("trait", ""))
			var tr_tier: String = str(c.get("data", {}).get("tier", ""))
			if (tr_name == "composure" and tr_tier == "low") or (tr_name == "privacy" and tr_tier == "high"):
				var dkey3 = "demeanor_tell:" + target
				var tval: float = INCIDENT_MAX * 0.8
				if tval > incidents.get(dkey3, {}).get("raw", 0.0):
					incidents[dkey3] = {
						"key": dkey3,
						"family": "demeanor_tell",
						"raw": tval,
						"label": "Guarded or easily rattled demeanor (%s: %s)" % [tr_name.capitalize(), tr_tier],
					}
				matched_cards[cid] = true

	# Logical Stage-1 cards wired through the hub (reports, traces, night sightings, home/work/haunt context for traces)
	# are valid Stage-1 material rather than smear padding when they bear on the case.
	var stage1_bearing: Dictionary = {}
	for c in hub_cards:
		if c.get("kind", "") in ["report", "trace", "sighting", "alibi", "coverage", "totem", "dropped", "claim", "secret_claim", "gift_hint"]:
			stage1_bearing[c.id] = true
		elif c.get("kind", "") == "context" and c.get("context_kind", "") in ["home", "work", "haunt"] and c.get("subject", "") == target and all_cards.any(func(tc): return tc.get("kind", "") == "trace"):
			stage1_bearing[c.id] = true

	var unmatched: Array = []
	for c in hub_cards:
		if not matched_cards.has(c.id) and not stage1_bearing.has(c.id):
			unmatched.append(c.id)

	return {
		"incidents": incidents,
		"matched_cards": matched_cards.keys(),
		"unmatched_cards": unmatched,
	}


## Evaluate the union of all active (non-withdrawn) Circumstantial Evidence hubs for one listener.
static func evaluate_union(
	view: Dictionary,
	hubs: Array,
	outside_suspicion: Dictionary,
	stage1_requested: Dictionary,
	post_stage1_susp: Dictionary,
	npc_trust: Dictionary,
	listener_trust: float,
	listener_id: String,
	public_good: Array = [],
	listener_knowledge: Dictionary = {},
	disputes: Array = []
) -> Dictionary:
	var requested: Dictionary = {}
	var by_target_incidents: Dictionary = {}
	if hubs.is_empty():
		return {"requested": requested, "incidents": by_target_incidents}

	var known_good: Array = public_good.duplicate()
	for g_id in listener_knowledge.get("good", []):
		if g_id not in known_good:
			known_good.append(g_id)

	var grouped: Dictionary = {}
	for hub in hubs:
		var t: String = str(hub.get("target", ""))
		var ptype: String = str(hub.get("type", "evil"))
		if t == "" or t == listener_id or ptype not in ACCUSATORY_TYPES:
			continue
		if t in known_good or TimeModel.known_good(view, listener_knowledge, t, view.get("alignment_epoch", "Original alignment")):
			continue
		if not grouped.has(t):
			grouped[t] = []
		for cid in hub.get("cards", []):
			if cid not in grouped[t]:
				grouped[t].append(cid)

	var passive_floor: float = _passive_survivor_floor(view, stage1_requested, listener_id, known_good)
	var trust_mult: float = clampf(0.5 + listener_trust, 0.5, 1.25)
	for t in grouped:
		var spec_s1: float = maxf(0.0, float(stage1_requested.get(t, 0.0)) - passive_floor)
		var gate: float = stage1_gate(spec_s1, float(outside_suspicion.get(t, 0.1)))
		if gate <= 0.0:
			requested[t] = 0.0
			by_target_incidents[t] = []
			continue
		var extracted: Dictionary = extract_hub_incidents(view, grouped[t], t, post_stage1_susp, npc_trust, known_good, disputes)
		var total = 0.0
		var items: Array = []
		var keys: Array = extracted.incidents.keys()
		keys.sort()
		for k in keys:
			var item: Dictionary = extracted.incidents[k]
			var delta: float = clampf(float(item.raw) * gate * trust_mult, 0.0, INCIDENT_MAX)
			if delta > 0.0:
				total += delta
				items.append({"key": k, "family": item.family, "applied": delta, "label": item.label})
		requested[t] = clampf(total, 0.0, TARGET_CAP)
		by_target_incidents[t] = items
	return {"requested": requested, "incidents": by_target_incidents}


## Preview helper for single-case evaluation (`Jury._consequences_eval` when `not refresh`).
static func evaluate_case(view: Dictionary, value: Dictionary, baseline: Dictionary, stage1_effects: Dictionary) -> Dictionary:
	var hubs: Array = value.get("circumstantial", [])
	if hubs.is_empty():
		return {"requested": {}, "incidents": {}}
	var s1_req: Dictionary = {}
	var post_s1: Dictionary = {}
	for pid in stage1_effects:
		var req: float = float(stage1_effects[pid].get("requested", 0.0))
		s1_req[pid] = req
		post_s1[pid] = clampf(float(baseline.suspicion.get(pid, 0.1)) + req, 0.0, 1.5)
	for p in view.get("people", []):
		if not post_s1.has(p.id):
			post_s1[p.id] = float(baseline.suspicion.get(p.id, 0.1))
	return evaluate_union(
		view,
		hubs,
		baseline.get("suspicion", {}),
		s1_req,
		post_s1,
		baseline.get("npc_trust", {}),
		float(baseline.get("trust", 0.5)),
		str(baseline.get("id", "")),
		[],
		baseline.get("knowledge", {}),
		value.get("disputes", [])
	)


## Deterministic smear backlash in [0.0, 0.015] when presenting an ungrounded circumstantial hub.
static func evaluate_smear_backlash(
	view: Dictionary,
	hubs: Array,
	outside_suspicion: Dictionary,
	stage1_requested: Dictionary,
	post_stage1_susp: Dictionary,
	npc_trust: Dictionary,
	listener_id: String,
	known_good: Array = [],
	disputes: Array = []
) -> Dictionary:
	if hubs.is_empty():
		return {"penalty": 0.0, "reason": ""}
	var passive_floor: float = _passive_survivor_floor(view, stage1_requested, listener_id, known_good)
	var penalty = 0.0
	var reason = ""
	for hub in hubs:
		var t: String = str(hub.get("target", ""))
		var ptype: String = str(hub.get("type", "evil"))
		if t == "" or ptype not in ACCUSATORY_TYPES:
			continue
		var s1: float = maxf(0.0, float(stage1_requested.get(t, 0.0)) - passive_floor)
		var gate: float = stage1_gate(s1, float(outside_suspicion.get(t, 0.1)))
		var extracted: Dictionary = extract_hub_incidents(view, hub.get("cards", []), t, post_stage1_susp, npc_trust, known_good, disputes)
		var unmatched_n: int = extracted.unmatched_cards.size()
		var inc_n: int = extracted.incidents.size()
		var friend_bonus: float = 0.005 if float(npc_trust.get(t, 0.5)) >= 0.65 or t == listener_id or t in known_good else 0.0
		if inc_n == 0 and unmatched_n > 0 and s1 < 0.02:
			penalty = maxf(penalty, clampf(SMEAR_MIN * float(unmatched_n) + friend_bonus, SMEAR_MIN, SMEAR_MAX))
			reason = "ungrounded_hub_padding"
		elif gate <= 0.0 and (inc_n > 0 or unmatched_n > 0):
			penalty = maxf(penalty, clampf(SMEAR_MIN + friend_bonus, SMEAR_MIN, SMEAR_MAX))
			reason = "vibes_without_stage1"
	return {"penalty": snappedf(penalty, 0.0001), "reason": reason}
