## Shared-model source and interval doubt (`workshop_state.source_doubt`).
##
## Replaces legacy `n.discounted` and `n.honesty` in shared mode without reading
## legacy `effects`, `_night_doubt`, or `_honesty`. Derived strictly from:
##   1. `ReadingChallenges.assess` report multipliers (`source:night`) and lying source penalties (`source:*`),
##   2. Caught lies and impossible claims in the listener's view (unique gift clash, false Night Watch
##      sighting of a home-staying listener, firsthand-contradicted night alibis, impossible Gravedigger
##      claims on a public Revenant),
##   3. Public proofs (Revenant curse, trusted/own Gravedigger execution readings, Martyr/Demon-victim sincerity),
##   4. Unowned template deduction metadata (`meta.conclusion` + `weight`, never `effects`) until Phase 4.
extends RefCounted

const C = preload("res://sim/content.gd")
const Solver = preload("res://workshop/solver.gd")
const PublicEvidence = preload("res://workshop/public_evidence.gd")
const ReadingChallenges = preload("res://workshop/reading_challenges.gd")
const TimeModel = preload("res://workshop/chronology.gd")


static func lookup(source_doubt: Dictionary, src: String, night: int = -1, kind: String = "reading") -> float:
	if src == "":
		return 0.0
	var star: float = clampf(float(source_doubt.get(src + ":*", 0.0)), 0.0, 1.0)
	if kind != "reading" or night < 0:
		return star
	return clampf(maxf(float(source_doubt.get("%s:%d" % [src, night], 0.0)), star), 0.0, 1.0)


static func derive(plan: Dictionary, ledger: Dictionary = {}, seed_doubt: Dictionary = {}) -> Dictionary:
	if not plan.get("ready", false) or not plan.has("prepared"):
		return {"pre_eval": seed_doubt.duplicate(true), "full": seed_doubt.duplicate(true), "settled_sincere": {}}
	var prepared: Dictionary = plan.prepared
	var view: Dictionary = prepared.get("view", {})
	var listener: Dictionary = prepared.get("listener", {})
	var knowledge: Dictionary = listener.get("knowledge", {})
	var self_id: String = str(listener.get("id", ""))
	var cards: Array = view.get("cards", [])
	var input_snap: Dictionary = plan.get("input", {})
	var pub_events: Array = input_snap.get("public_events", [])
	var all_ids: Array = view.get("people", []).map(func(p): return str(p.get("id", "")))
	var owned_map: Dictionary = plan.get("owned", {})
	var owners_by_card: Dictionary = plan.get("owners", {})

	var settled_sincere: Dictionary = {}
	if self_id != "":
		settled_sincere[self_id] = true
	var public_good: Array = PublicEvidence.known_good(pub_events, all_ids)
	var has_curse: bool = view.get("chronology", {}).has("curse")
	var curse_active: bool = false
	if has_curse:
		var curse: Dictionary = view.chronology.curse
		curse_active = TimeModel.tick(input_snap.get("now", {"day": 1, "phase": "morning"})) < int(curse.get("until", 0))
		var proofs: Array = PublicEvidence.martyr_receipts(pub_events, all_ids)
		public_good = public_good.filter(func(person): return not curse_active or person not in curse.get("yes_voters", []) or proofs.any(func(proof): return person in proof.subjects and TimeModel.tick(proof.observed_at) >= int(curse.get("from", 0))))
	for pg in public_good:
		settled_sincere[str(pg)] = true
	if not has_curse:
		for dv in PublicEvidence.demon_victims(pub_events, all_ids):
			settled_sincere[str(dv)] = true

	var pre_eval: Dictionary = seed_doubt.duplicate(true)
	var proven_revenants: Dictionary = {}
	var curse_exec: String = str(view.get("chronology", {}).get("curse", {}).get("executed", ""))
	if curse_exec != "":
		proven_revenants[curse_exec] = true
		pre_eval[curse_exec + ":*"] = 1.0
	for ev in pub_events:
		if str(ev.get("kind", "")) == "curse":
			for subj in ev.get("subjects", []):
				var sid: String = str(subj)
				if sid != "":
					proven_revenants[sid] = true
					pre_eval[sid + ":*"] = 1.0

	var own_role: String = str(knowledge.get("own_role", ""))
	var own_outings: Dictionary = knowledge.get("own_outings", {})
	var own_saw: Dictionary = {}
	var sleepwalkers: Dictionary = {}
	for card in cards:
		if card.get("quoted", false):
			continue
		var ck: String = str(card.get("kind", ""))
		if ck == "sighting" and str(card.get("source", "")) == self_id:
			var c_owners: Array = owners_by_card.get(str(card.get("id", "")), ["learned"])
			if "learned" in c_owners:
				var sn: int = int(card.get("night", card.get("observed_at", {}).get("day", -1)))
				if sn >= 0:
					for who in card.get("subjects", [card.get("subject", "")]):
						if str(who) != "":
							own_saw["%s:%d" % [str(who), sn]] = true
		elif ck in ["secret_claim", "secret"] and str(card.get("data", {}).get("secret_kind", card.get("secret_kind", ""))) == "sleepwalker":
			var sw_owner: String = str(card.get("source", card.get("subject", "")))
			if sw_owner != "":
				sleepwalkers[sw_owner] = true

	# Pass 1: direct caught lies (own role clash, false sighting of listener, impossible Revenant Gravedigger).
	for card in cards:
		if card.get("quoted", false):
			continue
		var csrc: String = str(card.get("source", ""))
		var ckind: String = str(card.get("kind", ""))
		var crole: String = str(card.get("role", ""))
		var cnight: int = int(card.get("night", card.get("observed_at", {}).get("day", -1)))
		if csrc == "" or csrc in ["player", "evidence", "town"]:
			continue
		if csrc == self_id:
			if ckind == "report" and crole == "gravedigger":
				var ex_self: String = str(card.get("data", {}).get("executed", ""))
				var role_self: String = str(card.get("data", {}).get("role", ""))
				if ex_self != "" and C.ROLES.has(role_self):
					if C.ROLES[role_self]["align"] == "evil":
						pre_eval[ex_self + ":*"] = 1.0
					elif not proven_revenants.has(ex_self):
						settled_sincere[ex_self] = true
			continue
		if own_role != "" and ckind in ["claim", "report"] and crole == own_role and not settled_sincere.has(csrc):
			pre_eval[csrc + ":*"] = 1.0
		if ckind == "report" and crole == "nightwatch" and self_id != "" and self_id in card.get("data", {}).get("seen", []):
			var nd_key: String = str(cnight)
			if own_outings.has(nd_key) and not bool(own_outings[nd_key]) and not settled_sincere.has(csrc):
				# A Night Watch list can be wrong without a lie (a poisoned watch): that night's
				# report is void, and the source is doubted in general, not written off.
				var nw_key: String = "%s:%d" % [csrc, cnight]
				pre_eval[nw_key] = 1.0
				pre_eval[csrc + ":*"] = maxf(float(pre_eval.get(csrc + ":*", 0.0)), 0.5)
		if ckind == "report" and crole == "gravedigger":
			var ex_id: String = str(card.get("data", {}).get("executed", ""))
			var ex_role: String = str(card.get("data", {}).get("role", ""))
			if proven_revenants.has(ex_id) and ex_role != "revenant" and not settled_sincere.has(csrc):
				pre_eval[csrc + ":*"] = 1.0
		if ckind == "alibi" and cnight >= 0:
			for subj in card.get("subjects", [card.get("subject", "")]):
				var s_id: String = str(subj)
				if s_id != "" and own_saw.has("%s:%d" % [s_id, cnight]) and not sleepwalkers.has(s_id) and not settled_sincere.has(s_id):
					var nk_a: String = "%s:%d" % [s_id, cnight]
					pre_eval[nk_a] = maxf(float(pre_eval.get(nk_a, 0.0)), 0.75)
					pre_eval[s_id + ":*"] = maxf(float(pre_eval.get(s_id + ":*", 0.0)), 0.55)

	# Pass 2: Gravedigger execution proofs from non-discredited other sources.
	var npc_trust: Dictionary = listener.get("npc_trust", {})
	for card in cards:
		if card.get("quoted", false) or str(card.get("kind", "")) != "report" or str(card.get("role", "")) != "gravedigger":
			continue
		var gsrc: String = str(card.get("source", ""))
		if gsrc in ["", self_id, "player", "evidence", "town"]:
			continue
		if float(pre_eval.get(gsrc + ":*", 0.0)) >= 0.5:
			continue
		var ex2: String = str(card.get("data", {}).get("executed", ""))
		var role2: String = str(card.get("data", {}).get("role", ""))
		if ex2 == "" or not C.ROLES.has(role2) or proven_revenants.has(ex2):
			continue
		var g_trust: float = clampf(float(npc_trust.get(gsrc, 0.5)), 0.0, 1.0)
		if C.ROLES[role2]["align"] == "evil" and g_trust >= 0.45:
			pre_eval[ex2 + ":*"] = maxf(float(pre_eval.get(ex2 + ":*", 0.0)), clampf(0.85 * g_trust, 0.0, 0.95))
		elif C.ROLES[role2]["align"] == "good" and g_trust >= 0.60:
			settled_sincere[ex2] = true

	# Pass 3: Unowned template deduction metadata (`meta.conclusion` + `weight`; never `effects`).
	for eid in ledger:
		if owned_map.has(eid):
			continue
		var entry: Dictionary = ledger[eid]
		var wgt: float = clampf(float(entry.get("weight", 0.0)), 0.0, 1.0)
		if wgt <= 0.01:
			continue
		var meta: Dictionary = entry.get("meta", {})
		if str(meta.get("kind", "")) != "arg" or not (meta.get("conclusion") is Dictionary):
			continue
		var conc: Dictionary = meta.conclusion
		var ctype: String = str(conc.get("type", ""))
		var ca: String = str(conc.get("a", ""))
		if ca == "":
			continue
		if ctype in ["misled", "unreliable"]:
			var cn: int = int(conc.get("night", -1))
			var k_arg: String = "%s:%s" % [ca, str(cn) if cn >= 0 else "*"]
			var d_val: float = (0.8 if ctype == "misled" else 0.5) * wgt
			pre_eval[k_arg] = minf(maxf(float(pre_eval.get(k_arg, 0.0)), d_val), 0.9)
		elif ctype == "lied" and not settled_sincere.has(ca):
			var cn2: int = int(conc.get("night", -1))
			var k_lied: String = "%s:%s" % [ca, str(cn2) if cn2 >= 0 else "*"]
			pre_eval[k_lied] = minf(maxf(float(pre_eval.get(k_lied, 0.0)), 0.5 * wgt), 0.9)
		elif ctype == "secret_mod" and str(conc.get("mod", "")) == "delusional":
			pre_eval[ca + ":*"] = minf(maxf(float(pre_eval.get(ca + ":*", 0.0)), 0.7 * wgt), 0.9)

	for s_good in settled_sincere:
		if not seed_doubt.has(s_good + ":*"):
			pre_eval.erase(s_good + ":*")

	var full_doubt: Dictionary = pre_eval.duplicate(true)
	var rc_case: Dictionary = prepared.get("case", {})
	if not rc_case.get("reading_challenges", {}).is_empty():
		var challenged: Dictionary = ReadingChallenges.assess(view, rc_case, listener, cards)
		for r in challenged.get("results", []):
			var r_cid: String = str(r.get("card", ""))
			var r_card: Dictionary = Solver.card_by_id(view, r_cid)
			var r_src: String = str(r.get("source", ""))
			var r_night: int = int(r_card.get("night", r_card.get("observed_at", {}).get("day", -1)))
			var mult: float = float(r.get("multiplier", 1.0))
			if r_src != "" and r_night >= 0 and mult < 1.0:
				var nk_rc: String = "%s:%d" % [r_src, r_night]
				full_doubt[nk_rc] = maxf(float(full_doubt.get(nk_rc, 0.0)), clampf(1.0 - mult, 0.0, 0.95))
			if str(r.get("mode", "")) == "lying" and float(r.get("agreement", 0.0)) >= 0.6 and r_src != "" and not settled_sincere.has(r_src):
				var agr: float = float(r.get("agreement", 0.0))
				var src_pen: float = clampf(1.0 - float(challenged.get("sources", {}).get(r_src, 1.0)), 0.0, 1.0)
				if agr >= 0.75:
					src_pen = maxf(src_pen, clampf(agr, 0.0, 0.95))
				full_doubt[r_src + ":*"] = maxf(float(full_doubt.get(r_src + ":*", 0.0)), src_pen)

	return {"pre_eval": pre_eval, "full": full_doubt, "settled_sincere": settled_sincere}
