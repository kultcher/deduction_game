## The evidence ledger: what each mind has heard, weighed and acted on (split from
## `sim/mind.gd`; part of Mind's inheritance chain).
extends "res://sim/mind_cases.gd"


# ---------------------------------------------------------------- evidence ledger
## Each good NPC keeps a ledger of the evidence and arguments they've taken in, keyed by the
## underlying fact (not by who relayed it, or which card or deduction wrapped it).
## An entry's contribution = its effects x weight x current reliability of its source.
## When weight or reliability changes, only the difference is applied, so suspicion is
## always "social base + what the evidence currently says". Social effects (vibes,
## nominations, grudges, claims) stay as direct adjustments.
##
## A role claim reaches a listener and enters their ledger as a receipt with its hearing
## weight (used by the shared model and metadata-derived role beliefs). how: public | relayed |
## own | told.
static func hear_claim(w, l, who: String, role: String, weight: float, how: String, original: Dictionary = {}) -> void:
	if l.is_evil():
		shadow_run(w, l, func(sh): hear_claim(w, sh, who, role, weight, how, original))
		return
	if not C.ROLES.has(role) or C.ROLES[role]["align"] != "good" or not w.by_id.has(who):
		return
	var rn = C.role_name(role)
	var nm: String = w.by_id[who].name
	var eid: String = claim_eid(who, role)
	var receipt: Dictionary = original if not original.is_empty() else l.ledger.get(eid, {}).get("meta", {}).get("workshop_card", {})
	if receipt.is_empty():
		receipt = WorkshopLedger.Evidence.normalize_card({"kind": "claim", "source": who, "subject": [who], "role": role, "day": w.day, "phase": w.phase, "text": "%s claims the %s." % [nm, rn]})
	ledger_hear(w, l, eid, [], weight, [who, -1, "role"], {"kind": "role_claim", "how": how, "role": role, "who": who, "workshop_card": receipt})

static func claim_eid(who: String, role: String) -> String:
	return "claim:%s:%s" % [who, role]

## How much this listener credits who's claim to role (0 = never heard it).
static func claim_credence(n, who: String, role: String) -> float:
	var eid: String = claim_eid(who, role)
	if n.workshop_state.get("owned", {}).has(eid):
		return 0.0 # Shared role testimony owns the claim's evidence weight.
	var e = n.ledger.get(eid)
	return e.get("eff", 0.0) if e != null else 0.0

## What a card rests on, as [source, night, kind] (kind: reading | report | evidence).
static func support_ref(card: Dictionary) -> Array:
	var src: String = card.get("source", "")
	if src in ["", "player", "evidence"]:
		return ["", -1, "evidence"]
	if card.get("kind", "") == "info":
		return [src, card.get("day", -1), "reading"]
	return [src, card.get("day", -1) if card.get("phase", -1) == C.NIGHT else -1, "report"]

## A stable identity for the fact behind a board card.
static func fact_id(card: Dictionary) -> String:
	var prefix: String = "rumour|" if card.get("tavern_gossip", false) else ""
	return prefix + _raw_fact_id(card)

static func _raw_fact_id(card: Dictionary) -> String:
	var k: String = card.get("kind", "")
	var subj: Array = card.get("subject", []).duplicate()
	subj.sort()
	var ss = ",".join(PackedStringArray(subj))
	match k:
		"info":
			return WorkshopLedger.Evidence.reading_key(WorkshopLedger.Evidence.normalize_card(card))
		"sighting", "vigil", "alibi", "secret":
			return "%s:%s:%s:%d:%d:%s" % [k, card.get("source", ""), ss, card.get("day", -1), card.get("phase", -1), card.get("block", "")]
		"home":
			return "home:%s:%s" % [ss, card.get("block", "")]
		"work":
			return "work:%s:%s" % [ss, card.get("loc", "")]
		"haunt":
			return "haunt:%s:%s" % [ss, ",".join(PackedStringArray(card.get("locs", [card.get("loc", "")])))]
		"trait":
			return "trait:%s:%s:%s:%s" % [ss, card.get("trait", ""), card.get("tier", ""), "bereaved" if card.get("withdrawn", false) else "base"]
		"bond":
			return "bond:%s:%s" % [card.get("bond_kind", ""), ss]
		"trace":
			if card.get("scene", "") != "" and (card.has("trace_slot") or card.get("trace_family", "") != ""):
				return "trace:%s:%d" % [card.get("scene", ""), int(card.get("trace_slot", 0))]
			return "trace:%s:%d" % [card.get("block", ""), card.get("day", -1)]
		"claim":
			return "claim:%s:%s" % [card.get("source", ""), card.get("role", "")]
		"town_hall":
			var th_roles: Array = card.get("roles", []).duplicate()
			th_roles.sort()
			return "town_hall:" + ",".join(PackedStringArray(th_roles))
		"death", "execution":
			return "%s:%s" % [k, ss]
	return "card:" + card.get("text", "")

## Kinds of claim (what someone says): "reading" (a gift's result: poison can break it),
## "report" (ordinary testimony: a sighting, an alibi, an opinion; poison doesn't touch it).
## A claim's rel = [source, night, kind]; night -1 = no particular night.
static func _rel(e: Dictionary) -> Array:
	var r: Array = e["rel"]
	if r.is_empty():
		return ["", -1, "evidence"]
	return [r[0], r[1], r[2] if r.size() > 2 else "reading"]

## Doubt about one particular reading (only gift readings; never testimony).
static func _night_factor(disc: Dictionary, src: String, night: int, kind: String) -> float:
	if src == "" or kind != "reading":
		return 1.0
	return 1.0 - maxf(disc.get("%s:%d" % [src, night], 0.0), disc.get(src + ":*", 0.0))

## How much this NPC currently credits a claim (1 = fully), derived from shared-model
## `workshop_state.source_doubt`. A good NPC never doubts their own sincerity, though
## they can accept that their own reading on a particular night was poisoned.
static func reliability(n, src: String, night: int, kind: String = "reading") -> float:
	if src == "":
		return 1.0
	var sd: Dictionary = n.workshop_state.get("source_doubt", {})
	if kind == "reading":
		return clampf(_night_factor(sd, src, night, kind), 0.0, 1.0)
	if src != n.id:
		return clampf(1.0 - float(sd.get(src + ":*", 0.0)), 0.0, 1.0)
	return 1.0

static func night_reliability(n, src: String, night: int) -> float:
	return _night_factor(n.workshop_state.get("source_doubt", {}), src, night, "reading")

## Take in a claim, evidence or an argument. Hearing the same thing again only raises its
## weight to the stronger hearing; it never stacks. `effects` is always empty in Phase 2c+:
## ledger entries hold receipts, metadata and hearing weights read by the shared model.
static func ledger_hear(w, n, eid: String, _effects: Array = [], weight: float = 1.0, rel: Array = [], meta: Dictionary = {}) -> Dictionary:
	if n.is_evil():
		# The shadow hears it; the real evil mind still takes nothing from it.
		shadow_run(w, n, func(sh): ledger_hear(w, sh, eid, [], weight, rel, meta))
		return {"fresh": false, "gain": 0.0, "times": 0}
	var fresh = not n.ledger.has(eid)
	if fresh:
		n.ledger[eid] = {"eid": eid, "effects": [], "weight": 0.0, "rel": rel, "meta": {}, "day": w.day, "times": 0}
	var e: Dictionary = n.ledger[eid]
	e["effects"] = []
	var times: int = e["times"]
	e["times"] = times + 1
	var old_w: float = e["weight"]
	for k in meta:
		if k in ["base", "agreement"]:
			e["meta"][k] = maxf(float(e["meta"].get(k, -1.0)), float(meta[k]))
		elif k != "supports":
			e["meta"][k] = meta[k]
	if meta.has("supports"):
		var sup: Array = meta["supports"].duplicate()
		sup.sort()
		var key = str(sup)
		var js: Array = e.get("justs", [])
		var found = false
		for jj in js:
			if jj["key"] == key:
				jj["weight"] = maxf(jj["weight"], weight)
				jj["base"] = maxf(jj["base"], meta.get("base", 0.0))
				if meta.has("workshop_roots"):
					# A coarse support key may hide different original receipts. Keep
					# every proof; never let a later supported path certify a mixed one.
					jj["workshop_roots"] = _merge_workshop_roots(jj.get("workshop_roots", {}), meta.workshop_roots)
					if not jj.has("workshop_cases"):
						jj["workshop_uncertified"] = true
						jj["workshop_cases"] = {}
					jj.workshop_cases[meta.get("workshop_case", "0")] = meta.workshop_roots.duplicate(true)
				found = true
		if not found:
			js.append({"key": key, "weight": weight, "base": meta.get("base", 0.0), "supports": sup})
			if meta.has("workshop_roots"):
				js[-1]["workshop_roots"] = meta.workshop_roots.duplicate(true)
				js[-1]["workshop_cases"] = {meta.get("workshop_case", "0"): meta.workshop_roots.duplicate(true)}
		e["justs"] = js
	if weight > old_w:
		e["weight"] = weight
	if not e["meta"].has("w0"):
		e["meta"]["w0"] = e["weight"]
	refresh_beliefs(w, n, "")
	return {"fresh": fresh, "gain": maxf(0.0, weight - old_w), "times": times}

static func _merge_workshop_roots(old: Dictionary, value: Dictionary) -> Dictionary:
	var result = {"complete": old.get("complete", false) and value.get("complete", false), "receipts": old.get("receipts", {}).duplicate(true)}
	result.receipts.merge(value.get("receipts", {}))
	return result

## Refresh an NPC's beliefs via the shared Workshop model over the flat outside baseline,
## then derive metadata-backed social preferences and role beliefs.
static func refresh_beliefs(w, n, note: String) -> void:
	if w.defer_beliefs:
		if not w.pending_beliefs.any(func(p): return is_same(p[0], n)):
			w.pending_beliefs.append([n, note])
		return
	var span = WorkshopLedgerProfiler.open("belief_refresh")
	_refresh_beliefs(w, n, note)
	WorkshopLedgerProfiler.close(span)

## Run deferred refreshes: every pending mind, or only `only` (a speaker about to act).
static func flush_beliefs(w, only = null) -> void:
	var keep: Array = []
	var run: Array = []
	for p in w.pending_beliefs:
		if only == null or is_same(p[0], only):
			run.append(p)
		else:
			keep.append(p)
	w.pending_beliefs = keep
	var was: bool = w.defer_beliefs
	w.defer_beliefs = false
	for p in run:
		var m = p[0]
		if m.is_shadow and not is_same(w.dlog, w.shadow_log):
			var saved_rng = w.rng
			var saved_log = w.dlog
			w.rng = m.shadow_rng
			w.shadow_log.set_time(saved_log.day, saved_log.phase)
			w.dlog = w.shadow_log
			refresh_beliefs(w, m, p[1])
			w.rng = saved_rng
			w.dlog = saved_log
		else:
			refresh_beliefs(w, m, p[1])
	w.defer_beliefs = was

static func _refresh_beliefs(w, n, note: String) -> void:
	if n.is_evil():
		shadow_run(w, n, func(sh): refresh_beliefs(w, sh, note))
		return
	if w.workshop_refresh.is_valid():
		w.workshop_refresh.call(n)
	_refresh_ledger_preferences(w, n)
	_mind().prune_resentments(w, n)
	w.dlog.capture_npc(n, "belief_recompute" + note)

static func _entry_support_factor(n, e: Dictionary, sup: Array) -> float:
	if sup.is_empty():
		return 1.0
	var c_meta: Dictionary = e.get("meta", {}).get("conclusion", {})
	var own_doubt_src: String = str(c_meta.get("a", "")) if str(c_meta.get("type", "")) in ["lied", "misled", "unreliable"] else ""
	var own_doubt_night: int = int(c_meta.get("night", -1))
	var total = 0.0
	var count = 0
	for sp in sup:
		var src: String = sp[0]
		var night: int = sp[1]
		var kind: String = sp[2] if sp.size() > 2 else "reading"
		if kind == "reading" and own_doubt_src != "" and src == own_doubt_src and (own_doubt_night < 0 or own_doubt_night == night):
			continue
		count += 1
		total += reliability(n, src, night, kind)
	return total / count if count > 0 else 1.0

static func _refresh_ledger_preferences(w, n) -> void:
	var rev_roles: Dictionary = {}
	for k in n.believed_roles:
		if n.believed_roles[k] == "revenant":
			rev_roles[k] = "revenant"
	n.protect_pref = {}
	n.spare_pref = {}
	n.believed_roles = rev_roles
	for e in n.ledger.values():
		var meta: Dictionary = e.get("meta", {})
		var kind: String = str(meta.get("kind", ""))
		var kg: float = Tuning.Mind.DEMON_VICTIM_CLAIM_BOOST if kind == "role_claim" and str(meta.get("how", "")) != "own" and _mind().demon_victim(w, str(meta.get("who", ""))) else 1.0
		var js: Array = e.get("justs", [])
		var w_eff: float = float(e.get("weight", 0.0))
		if not js.is_empty():
			w_eff = 0.0
			for jj in js:
				w_eff = maxf(w_eff, float(jj.get("weight", 0.0)) * _entry_support_factor(n, e, jj.get("supports", [])))
		var rp: Array = _rel(e)
		var eff: float = w_eff * kg * reliability(n, rp[0], rp[1], rp[2])
		e["eff"] = eff
		if kind == "role_claim":
			var who: String = str(meta.get("who", ""))
			var role: String = str(meta.get("role", ""))
			if who != "" and role != "" and eff >= Tuning.Mind.BELIEVED_ROLE_MIN_EFF and n.believed_roles.get(who, "") != "revenant":
				n.believed_roles[who] = role
		elif kind == "arg":
			# A presentation-backed argument (a deduction cited to accuse or defend) is heard
			# at its agreement: the same acceptance gate as presented premises below applies
			# (Codex review of PR #92). Other social arguments are unaffected.
			# Gate on the agreement itself, not the stored weight (which folds in the venue and
			# trust: maintenance 2026-11-07 A2). Entries from before the agreement was stored
			# fall back to the weight.
			var arg_agreement: float = float(meta.get("agreement", -1.0))
			if arg_agreement < 0.0:
				arg_agreement = float(e.get("weight", 0.0))
			if meta.has("workshop_case") and arg_agreement < Tuning.Workshop.PREMISE_PREF_MIN_AGREEMENT:
				continue
			_apply_conclusion_pref(n, meta.get("conclusion", {}), eff)
	var withdrawn: Dictionary = n.workshop_state.get("withdrawn", {})
	var agreements: Dictionary = n.workshop_state.get("presentation_agreement", {})
	for p_key in n.workshop_state.get("presentations", {}):
		if withdrawn.has(p_key):
			continue
		# Premises pass step 1: only a premise the listener accepted steers their protect
		# and believed-role preferences. Not judged yet (mid-presentation) counts as not
		# accepted; the presentation re-runs this once its agreement is recorded.
		if float(agreements.get(p_key, 0.0)) < Tuning.Workshop.PREMISE_PREF_MIN_AGREEMENT:
			continue
		var snap: Dictionary = n.workshop_state.presentations[p_key]
		var root_num: int = int(snap.get("root", -999))
		for arg in snap.get("arguments", []):
			if int(arg.get("board_number", -998)) == root_num:
				_apply_conclusion_pref(n, arg.get("conclusion", {}), 0.35 * (0.5 + n.trust))

static func _apply_conclusion_pref(n, c: Dictionary, eff: float) -> void:
	if c.is_empty() or eff <= 0.002:
		return
	var ctype: String = str(c.get("type", ""))
	var target_id: String = str(c.get("a", c.get("target", "")))
	if target_id == "":
		return
	match ctype:
		"good":
			n.protect_pref[target_id] = maxf(n.protect_pref.get(target_id, 0.0), 0.5 * eff)

## Re-weigh what the player has argued, in light of current trust. Firsthand knowledge and
## the evidence itself don't change; how much the player's word counts does. Confidence
## sets how far they move at once. Called when trust shifts noticeably and before votes.
static func reconsider(w, n, why: String) -> void:
	if n.is_evil():
		shadow_run(w, n, func(sh): reconsider(w, sh, why))
		return
	if absf(n.trust - n.trust_at_reconsider) < Tuning.Mind.RECONSIDER_MIN_SHIFT:
		refresh_beliefs(w, n, " (shared evidence reconsidered: %s)" % why)
		return
	n.trust_at_reconsider = n.trust
	var rate = 1.0 - Tuning.Mind.RECONSIDER_CONFIDENCE_DAMP * _mind().trait_of(n, "confidence")
	for e in n.ledger.values():
		var m: Dictionary = e["meta"]
		if not m.has("base"):
			continue
		var cur: float = e["weight"]
		var nw = cur
		var js: Array = e.get("justs", [])
		if js.is_empty():
			var want: float = m["base"] * (0.5 + n.credibility)
			if absf(want - cur) < Tuning.Mind.RECONSIDER_ENTRY_MIN_DELTA:
				continue
			nw = cur + (want - cur) * rate
		else:
			nw = 0.0
			for jj in js:
				var wj: float = jj["base"] * (0.5 + n.credibility)
				jj["weight"] = jj["weight"] + (wj - jj["weight"]) * rate
				nw = maxf(nw, jj["weight"])
			if absf(nw - cur) < Tuning.Mind.RECONSIDER_ENTRY_MIN_DELTA:
				continue
		e["weight"] = nw
		w.dlog.think(n.id, "reconsider", "Re-weighs '%s': %.2f -> %.2f (trust %.2f, %s)." % [m.get("text", e["eid"]), cur, nw, n.trust, why],
			{"eid": e["eid"], "from": snappedf(cur, 0.01), "to": snappedf(nw, 0.01)})
		var w0: float = m.get("w0", cur)
		if m.get("kind", "") == "arg" and nw >= maxf(w0 * 1.35, w0 + 0.05) and not m.get("remarked", false) and m.get("said", "") != "":
			m["remarked"] = true
			n.remarks.append(m["said"])
	refresh_beliefs(w, n, " (reconsidered: %s)" % why)

## Apply one ability result (own or heard) to a listener's suspicion, through their ledger:
## hearing the same reading again (directly, relayed, at the meeting) never stacks.
## `public`: told before the whole town (a late relay), so the receipt is public grounds
## even though the source's own statement was private.
static func apply_info(w, listener, source, entry: Dictionary, weight: float, via: String = "", anonymous: bool = false, public: bool = false) -> void:
	if weight <= 0.01:
		return
	if listener.is_evil():
		shadow_run(w, listener, func(sh): apply_info(w, sh, source, entry, weight, via, anonymous, public))
		return
	var receipt = WorkshopLedger.reading(source.id, entry, via)
	var eid = WorkshopLedger.reading_key(receipt)
	var fresh = not listener.ledger.has(eid)
	var rdef = C.role_def(entry.get("role", ""))
	if rdef != null:
		rdef.on_reading_heard(listener, source, entry, fresh)
	var receipts: Dictionary = listener.ledger.get(eid, {}).get("meta", {}).get("workshop_receipts", {}).duplicate(true)
	if anonymous:
		receipt = WorkshopLedger.reading(source.id, entry, via, true)
	receipt["heard_in_public"] = anonymous or public or entry.get("shared", false) or receipts.get(receipt.id, {}).get("heard_in_public", false)
	var paths: Array = receipts.get(receipt.id, {}).get("provenance_paths", []).duplicate(true)
	if (via != "" or anonymous or not paths.is_empty()) and receipt.provenance not in paths:
		paths.append(receipt.provenance.duplicate(true))
	receipt.provenance_paths = paths
	receipts[receipt.id] = receipt
	ledger_hear(w, listener, eid, [], weight, [source.id, entry["day"], "reading"], {"kind": "reading", "workshop_receipts": receipts})
	if fresh and source != listener and weight > 0.2:
		w.on_execution_reading_heard(listener, source, entry, weight)

static func info_eid(src: String, entry: Dictionary) -> String:
	return WorkshopLedger.reading_key(WorkshopLedger.reading(src, entry))

static func update_from_own_info(w) -> void:
	for n in w.evil_team():
		if n.alive:
			_shadow_own_info(w, n)
	for n in w.living_good():
		while n.applied_info < n.info_log.size():
			var e: Dictionary = n.info_log[n.applied_info]
			n.applied_info += 1
			apply_info(w, n, n, e, 1.0)

## How much a reading heard first-hand from its giver counts, before credibility. The
## giver's credibility is applied live by the ledger (it changes as evidence comes in).
static func heard_weight(listener, speaker) -> float:
	return Tuning.Mind.HEARD_READING_WEIGHT
