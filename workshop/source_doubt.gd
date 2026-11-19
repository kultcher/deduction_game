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

const Tuning = preload("res://sim/tuning.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const C = preload("res://sim/content.gd")
const Solver = preload("res://workshop/solver.gd")
const PublicEvidence = preload("res://workshop/public_evidence.gd")
const ReadingChallenges = preload("res://workshop/reading_challenges.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const History = preload("res://workshop/live_history.gd")

## Measurement switch (on in play): a good listener's small doubt that its own gift is
## Delusional (DELUSIONAL_SELF_DOUBT, derive). Tests turn it off to compare.
static var delusional_self_doubt: bool = true


## The poison self-doubt (off for measuring and for tests of other doubt).
static var poison_self_doubt: bool = true

## Measurement switch (on in play): the player's "failed gift" call as testimony (derive,
## "Poisoned, not lying", option C).
static var player_failed_gift: bool = true

## How far a listener takes the player's word that a reading was a failed gift: one witness
## as accurate as the listener's trust in the player (c), against the chance the gift was
## poisoned that night (prior): prior.c / (prior.c + (1 - prior)(1 - c)). At c = 0.5 the call
## changes nothing; below it, it never lowers a doubt (the caller takes the max).
static func witness_doubt(prior: float, c: float) -> float:
	var num: float = prior * c
	var den: float = num + (1.0 - prior) * (1.0 - c)
	return num / den if den > 1e-12 else 0.0

static func lookup(source_doubt: Dictionary, src: String, night: int = -1, kind: String = "reading") -> float:
	if src == "":
		return 0.0
	var star: float = clampf(float(source_doubt.get(src + ":*", 0.0)), 0.0, 1.0)
	if kind != "reading" or night < 0:
		return star
	return clampf(maxf(float(source_doubt.get("%s:%d" % [src, night], 0.0)), star), 0.0, 1.0)


static func derive(plan: Dictionary, ledger: Dictionary = {}, seed_doubt: Dictionary = {}) -> Dictionary:
	if not plan.get("ready", false) or not plan.has("prepared"):
		return {"pre_eval": seed_doubt.duplicate(true), "full": seed_doubt.duplicate(true), "settled_sincere": {}, "honest": {}}
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
	# Honest-error doubt only, by "src:night" or "src:*": a reading the listener thinks was
	# wrong though its teller was sincere (a poisoned Night Watch, a misled or unreliable
	# argument). Caught lies and lying arguments stay out, and so do reading challenges: under
	# the connections model a challenge acts only inside its own case. CaseEval._doubted_role_fits
	# reads it (through reading_doubt).
	var honest: Dictionary = {}
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
			if ckind == "report" and crole in ["gravedigger", "executor"] and card.get("data", {}).has("role"):
				var ex_self: String = str(card.get("data", {}).get("executed" if crole == "gravedigger" else "target", ""))
				var role_self: String = str(card.get("data", {}).get("role", ""))
				var obs_day_self: int = int(card.get("observed_at", {}).get("day", cnight))
				var self_missing_exec: bool = view.has("timeline") and (not History.executed(view, ex_self, cnight) if crole == "gravedigger" else not History.died_before_morning(view, ex_self, obs_day_self))
				if not self_missing_exec and ex_self != "" and C.ROLES.has(role_self):
					if C.ROLES[role_self]["align"] == "evil":
						pre_eval[ex_self + ":*"] = 1.0
					elif not proven_revenants.has(ex_self):
						settled_sincere[ex_self] = true
			continue
		if own_role != "" and ckind in ["claim", "report"] and crole == own_role and not settled_sincere.has(csrc):
			pre_eval[csrc + ":*"] = 1.0
		if ckind == "report" and crole == "nightwatch" and self_id != "" and self_id in card.get("data", {}).get("seen", []):
			var nd_key: String = str(cnight)
			if own_outings.has(nd_key) and not bool(own_outings[nd_key]) and not settled_sincere.has(csrc) and list_broken_chance(view, listener, card) <= 0.0:
				# A Night Watch list can be wrong without a lie (a poisoned watch): that night's
				# report is void, and the source is doubted in general, not written off. Only
				# where the list can't be weighed as sound or broken as a whole (a script with
				# neither Poisoner nor Delusional): otherwise the movement model mixes the two
				# (LiveActivity._list_mix) and the kept list counts against its watcher by fit.
				var nw_key: String = "%s:%d" % [csrc, cnight]
				pre_eval[nw_key] = 1.0
				honest[nw_key] = 1.0
				pre_eval[csrc + ":*"] = maxf(float(pre_eval.get(csrc + ":*", 0.0)), Tuning.Workshop.DOUBT_FALSE_NW_GENERAL)
		if ckind == "report" and crole in ["gravedigger", "executor"] and card.get("data", {}).has("role"):
			var ex_id: String = str(card.get("data", {}).get("executed" if crole == "gravedigger" else "target", ""))
			var ex_role: String = str(card.get("data", {}).get("role", ""))
			var obs_day_e: int = int(card.get("observed_at", {}).get("day", cnight))
			var missing_exec: bool = view.has("timeline") and (not History.executed(view, ex_id, cnight) if crole == "gravedigger" else not History.died_before_morning(view, ex_id, obs_day_e))
			if (missing_exec or (proven_revenants.has(ex_id) and ex_role != "revenant")) and not settled_sincere.has(csrc):
				pre_eval[csrc + ":*"] = 1.0
		if ckind == "alibi" and cnight >= 0:
			for subj in card.get("subjects", [card.get("subject", "")]):
				var s_id: String = str(subj)
				if s_id != "" and own_saw.has("%s:%d" % [s_id, cnight]) and not sleepwalkers.has(s_id) and not settled_sincere.has(s_id):
					var nk_a: String = "%s:%d" % [s_id, cnight]
					pre_eval[nk_a] = maxf(float(pre_eval.get(nk_a, 0.0)), Tuning.Workshop.DOUBT_CAUGHT_ALIBI_NIGHT)
					pre_eval[s_id + ":*"] = maxf(float(pre_eval.get(s_id + ":*", 0.0)), Tuning.Workshop.DOUBT_CAUGHT_ALIBI_GENERAL)

	# A teller's own word that its gift may have been turned (BACKLOG "Saying 'my gift may
	# have been turned'", Michael, Nov 17-18), before pass 2 so a retracted Gravedigger reading
	# proves only as much as it is still credited (Codex on #245).
	var gift_doubt: Dictionary = _gift_self_doubt(pub_events, self_id, listener.get("suspicion", {}))
	# The player's "failed gift" calls (option C, _player_failed_gift) go in at the same points,
	# before the Gravedigger proofs and again after the sincere-teller pass, so a verdict called
	# poisoned doesn't keep proving at full strength (Codex on #270).
	var failed_gift: Dictionary = _player_failed_gift(view, listener, cards, self_id)
	for fg_key in failed_gift:
		gift_doubt[fg_key] = maxf(float(gift_doubt.get(fg_key, 0.0)), float(failed_gift[fg_key]))
	for sd_key in gift_doubt:
		pre_eval[sd_key] = maxf(float(pre_eval.get(sd_key, 0.0)), float(gift_doubt[sd_key]))
		honest[sd_key] = maxf(float(honest.get(sd_key, 0.0)), float(gift_doubt[sd_key]))

	# Pass 2: Gravedigger execution proofs from non-discredited other sources.
	var npc_trust: Dictionary = listener.get("npc_trust", {})
	for card in cards:
		var grole: String = str(card.get("role", ""))
		if card.get("quoted", false) or str(card.get("kind", "")) != "report" or grole not in ["gravedigger", "executor"] or not card.get("data", {}).has("role"):
			continue
		var gsrc: String = str(card.get("source", ""))
		if gsrc in ["", self_id, "player", "evidence", "town"]:
			continue
		if float(pre_eval.get(gsrc + ":*", 0.0)) >= Tuning.Workshop.DOUBT_GD_MAX_SOURCE_DOUBT:
			continue
		var ex2: String = str(card.get("data", {}).get("executed" if grole == "gravedigger" else "target", ""))
		var role2: String = str(card.get("data", {}).get("role", ""))
		if ex2 == "" or not C.ROLES.has(role2) or proven_revenants.has(ex2):
			continue
		# A reading the listener already doubts (misled that night, or the source in
		# general) proves only as much as they still credit it.
		var g_night: int = int(card.get("night", card.get("observed_at", {}).get("day", -1)))
		var g_doubt: float = maxf(float(pre_eval.get(gsrc + ":*", 0.0)), float(pre_eval.get("%s:%d" % [gsrc, g_night], 0.0)))
		g_doubt = maxf(g_doubt, _arg_doubt(ledger, owned_map, gsrc, g_night))
		var g_trust: float = clampf(float(npc_trust.get(gsrc, 0.5)), 0.0, 1.0) * (1.0 - clampf(g_doubt, 0.0, 1.0))
		if C.ROLES[role2]["align"] == "evil" and g_trust >= Tuning.Workshop.DOUBT_GD_EVIL_TRUST_MIN:
			pre_eval[ex2 + ":*"] = maxf(float(pre_eval.get(ex2 + ":*", 0.0)), clampf(Tuning.Workshop.DOUBT_GD_EVIL_SCALE * g_trust, 0.0, 0.95))
		elif C.ROLES[role2]["align"] == "good" and g_trust >= Tuning.Workshop.DOUBT_GD_GOOD_TRUST_MIN:
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
			var d_val: float = (Tuning.Workshop.DOUBT_ARG_MISLED_SCALE if ctype == "misled" else Tuning.Workshop.DOUBT_ARG_UNRELIABLE_SCALE) * wgt
			pre_eval[k_arg] = minf(maxf(float(pre_eval.get(k_arg, 0.0)), d_val), Tuning.Workshop.DOUBT_ARG_CAP)
			honest[k_arg] = minf(maxf(float(honest.get(k_arg, 0.0)), d_val), Tuning.Workshop.DOUBT_ARG_CAP)
		elif ctype == "lied" and not settled_sincere.has(ca):
			var cn2: int = int(conc.get("night", -1))
			var k_lied: String = "%s:%s" % [ca, str(cn2) if cn2 >= 0 else "*"]
			pre_eval[k_lied] = minf(maxf(float(pre_eval.get(k_lied, 0.0)), Tuning.Workshop.DOUBT_ARG_UNRELIABLE_SCALE * wgt), Tuning.Workshop.DOUBT_ARG_CAP)
		elif ctype == "secret_mod" and str(conc.get("mod", "")) == "delusional":
			pre_eval[ca + ":*"] = minf(maxf(float(pre_eval.get(ca + ":*", 0.0)), Tuning.Workshop.DOUBT_ARG_DELUSIONAL_SCALE * wgt), Tuning.Workshop.DOUBT_ARG_CAP)

	for s_good in settled_sincere:
		if not seed_doubt.has(s_good + ":*"):
			pre_eval.erase(s_good + ":*")

	# A teller's own word that its gift may have been turned, put back after the sincere-
	# teller pass on purpose: a teller known to be sincere can still have a broken gift.
	for sd_key in gift_doubt:
		pre_eval[sd_key] = maxf(float(pre_eval.get(sd_key, 0.0)), float(gift_doubt[sd_key]))
		honest[sd_key] = maxf(float(honest.get(sd_key, 0.0)), float(gift_doubt[sd_key]))

	# "Is my gift Delusional?" (Michael, Nov 17). With the secret on the script a good
	# listener's own gift might give it wrong readings without it knowing, so each night of
	# its own readings carries a small honest doubt (DELUSIONAL_SELF_DOUBT), the way its home
	# nights carry the Sleepwalker's. Honest, so it reaches both the role check and the
	# readings' weight (measured Nov 17: a Clerk's, Seer's or Archivist's reading softens
	# through its weight, a Dowser's, Surveyor's or Warden's through the role check), never a
	# charge of lying. Its sightings and alibis aren't gift readings. A Medium's gift results
	# carry the dead person as source and the Medium as relay_source; they're keyed, as any
	# relay's reliability is, by the Medium and the night it heard them. Another Medium's
	# relayed copy of the listener's reading isn't the listener's gift, so it's left alone.
	var delusional_by_key: Dictionary = {}
	if delusional_self_doubt and self_id != "" and "delusional" in view.get("world_options", {}).get("modifiers", []) and not knowledge.get("not_delusional", false) and could_hold_secret(str(knowledge.get("own_role", "")), "delusional"):
		var d_self: float = Tuning.Workshop.DELUSIONAL_SELF_DOUBT
		for c in cards:
			if c.get("quoted", false):
				continue
			var n_self: int = -1
			if str(c.get("relay_source", "")) == self_id:
				n_self = int(c.get("relay_observed_at", {}).get("day", -1))
			elif str(c.get("kind", "")) == "report" and str(c.get("source", "")) == self_id and not c.has("relay_source"):
				n_self = int(c.get("observed_at", {}).get("day", c.get("night", -1)))
			if n_self < 0:
				continue
			var k_self: String = "%s:%d" % [self_id, n_self]
			delusional_by_key[k_self] = d_self
			pre_eval[k_self] = maxf(float(pre_eval.get(k_self, 0.0)), d_self)
			honest[k_self] = maxf(float(honest.get(k_self, 0.0)), d_self)

	# "Was my reading poisoned?" (Michael, Nov 17-18, with Quill). With a Poisoner possible, each
	# of the listener's own readings carries the chance that a Poisoner picked it that night
	# (ReadingChallenges.poison_chance: zero with no Poisoner on the script or one known dead)
	# as an honest doubt. Only the prior: the judge then weighs the reading as genuine or
	# broken by how well each fits the rest, so a reading that fits shrugs it off and one that
	# fights everything else gives way, more so against a trusted teller. Honest, so it reaches
	# the role check and the readings' weight, never a charge of lying. Where the Delusional
	# self-doubt also holds for that night, the two are independent ways the gift can fail:
	# 1 - (1 - poison)(1 - delusional), as the Night Watch's broken chance (Michael, Nov 18).
	if poison_self_doubt and self_id != "" and ReadingChallenges.poisoner_possible(view):
		# A reading can't vouch for its own gift: poison_chance takes an own Gravedigger
		# reading's role as known, so a poisoned one naming a hanged good person as the
		# Poisoner would rule poison out for itself. That reading's own doubt is asked without
		# it (Codex on #232). For the listener's other readings it stands: that night only one
		# person is poisoned, and later nights need the reading wrong as well, about as
		# unlikely as the poisoning itself, so believing one's own reading is near enough
		# (Quill, Nov 18).
		var own_ids: Array = listener.get("knowledge", {}).get("own_reports", [])
		for c in cards:
			if c.get("quoted", false):
				continue
			var k_night: int = -1
			var p_night: int = -1
			if str(c.get("relay_source", "")) == self_id:
				# The listener's own Medium transmission: the dead person is the card's source and
				# the Medium its relay (LiveAssessment.medium_card). The gift works at night, so
				# the poison night is the night it heard them, keyed as the relay's reliability is
				# (Codex on #232; the Delusional pass above does the same).
				k_night = int(c.get("relay_observed_at", {}).get("day", -1))
				p_night = k_night
			elif str(c.get("kind", "")) == "report" and str(c.get("source", "")) == self_id and not c.has("relay_source"):
				k_night = int(c.get("observed_at", {}).get("day", c.get("night", -1)))
				# The night a Poisoner would have acted: a night reading's own, or for any reading
				# by day (a Martyr's or Sexton's evening one too, whose card carries the coming
				# night) the night before, whose poison still holds (Codex on #232).
				p_night = k_night if str(c.get("observed_at", {}).get("phase", "")) == "night" else k_night - 1
			if k_night < 0:
				continue
			# A Registrar's night-0 register can't be poisoned, only made wrong by Delusional
			# (sim/roles/registrar.gd: a blind first-night poison must not brick every later
			# check). It keeps any Delusional doubt (Codex on #232).
			if str(c.get("role", "")) == "registrar" and k_night == 0 and not c.has("relay_source"):
				continue
			var asker: Dictionary = listener
			if str(c.get("role", "")) == "gravedigger" and str(c.get("id", "")) in own_ids:
				asker = listener.duplicate(false)
				var k_without: Dictionary = listener.get("knowledge", {}).duplicate(false)
				k_without["own_reports"] = own_ids.filter(func(id): return str(id) != str(c.id))
				asker["knowledge"] = k_without
			var pi: float = ReadingChallenges.poison_chance(view, asker, p_night)
			if pi <= 0.0:
				continue
			var k_p: String = "%s:%d" % [self_id, k_night]
			var broken: float = 1.0 - (1.0 - pi) * (1.0 - float(delusional_by_key.get(k_p, 0.0)))
			pre_eval[k_p] = maxf(float(pre_eval.get(k_p, 0.0)), broken)
			honest[k_p] = maxf(float(honest.get(k_p, 0.0)), broken)

	var full_doubt: Dictionary = pre_eval.duplicate(true)
	var rc_case: Dictionary = prepared.get("case", {})
	if not rc_case.get("reading_challenges", {}).is_empty():
		var challenged: Dictionary = ReadingChallenges.assess(view, rc_case, listener, cards)
		for r in challenged.get("results", []):
			var r_cid: String = str(r.get("card", ""))
			var r_card: Dictionary = Solver.card_by_id(view, r_cid)
			var r_src: String = str(r.get("source", ""))
			# A challenge names its own night: a relay's passing-on is the Medium's night.
			var r_night: int = int(r.get("night", r_card.get("night", r_card.get("observed_at", {}).get("day", -1))))
			var mult: float = float(r.get("multiplier", 1.0))
			if r_src != "" and r_night >= 0 and mult < 1.0:
				var nk_rc: String = "%s:%d" % [r_src, r_night]
				full_doubt[nk_rc] = maxf(float(full_doubt.get(nk_rc, 0.0)), clampf(1.0 - mult, 0.0, 0.95))
			if str(r.get("mode", "")) == "lying" and float(r.get("agreement", 0.0)) >= Tuning.Workshop.DOUBT_CHALLENGE_LYING_MIN_AGR and r_src != "" and not settled_sincere.has(r_src):
				var agr: float = float(r.get("agreement", 0.0))
				var src_pen: float = clampf(1.0 - float(challenged.get("sources", {}).get(r_src, 1.0)), 0.0, 1.0)
				if agr >= Tuning.Workshop.DOUBT_CHALLENGE_STRONG_AGR:
					src_pen = maxf(src_pen, clampf(agr, 0.0, 0.95))
				full_doubt[r_src + ":*"] = maxf(float(full_doubt.get(r_src + ":*", 0.0)), src_pen)

	return {"pre_eval": pre_eval, "full": full_doubt, "settled_sincere": settled_sincere, "honest": honest}


## Honest doubt from public `self_doubt` events, "teller:*": a teller who said its gift may
## have been turned, at an unreliable argument's scale, as far as the listener believes it
## (1 - its suspicion of the teller). The listener's own line is its own business.
static func _gift_self_doubt(pub_events: Array, self_id: String, susp_map: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for ev in pub_events:
		if str(ev.get("kind", "")) != "self_doubt":
			continue
		var t_id: String = str(ev.get("by", ""))
		if t_id == "" or t_id == self_id:
			continue
		var believe: float = clampf(1.0 - float(susp_map.get(t_id, 0.0)), 0.0, 1.0)
		var sd_val: float = minf(Tuning.Workshop.DOUBT_ARG_UNRELIABLE_SCALE * believe, Tuning.Workshop.DOUBT_ARG_CAP)
		if sd_val > 0.0:
			out[t_id + ":*"] = maxf(float(out.get(t_id + ":*", 0.0)), sd_val)
	return out


## Night or general doubt about `src` from unowned template arguments (the same values
## pass 3 writes), so pass 2 can weigh a Gravedigger proof the listener already doubts.
static func _arg_doubt(ledger: Dictionary, owned_map: Dictionary, src: String, night: int) -> float:
	var out: float = 0.0
	for eid in ledger:
		if owned_map.has(eid):
			continue
		var entry: Dictionary = ledger[eid]
		var wgt: float = clampf(float(entry.get("weight", 0.0)), 0.0, 1.0)
		var meta: Dictionary = entry.get("meta", {})
		if wgt <= 0.01 or str(meta.get("kind", "")) != "arg" or not (meta.get("conclusion") is Dictionary):
			continue
		var conc: Dictionary = meta.conclusion
		if str(conc.get("a", "")) != src:
			continue
		var cn: int = int(conc.get("night", -1))
		if cn >= 0 and cn != night:
			continue
		match str(conc.get("type", "")):
			"misled":
				out = maxf(out, minf(0.8 * wgt, 0.9))
			"unreliable", "lied":
				out = maxf(out, minf(0.5 * wgt, 0.9))
	return out


## The listener's honest doubt about its own readings, by night: {night: doubt}, from the
## honest map's "<self>:<night>" keys (the poison self-doubt, Connections._poison_doubt, and
## the Delusional self-doubt). A self key "<self>:*" counts as night -1.
static func own_doubt(self_id: String, honest: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if self_id == "":
		return out
	for k in honest:
		var key: String = str(k)
		if not key.begins_with(self_id + ":"):
			continue
		var rest: String = key.substr(self_id.length() + 1)
		var night: int = -1 if rest == "*" else int(rest)
		out[night] = maxf(float(out.get(night, 0.0)), float(honest[k]))
	return out


## An NPC's current doubt about each night of its own readings ({night: doubt}), as its last
## applied refresh left it: the judge's chance that night's own reading was wrong, from its
## clash with everything else the NPC holds, starting from the poison and Delusional prior
## (OwnGiftDoubt.posterior; Michael, Nov 19). For dialogue ("something seems off about my
## readings") and tools. A night whose readings the judge can't check has no entry.
static func self_doubt(n) -> Dictionary:
	# Loaded here, not preloaded: OwnGiftDoubt asks CaseEval, which preloads this script.
	return load("res://workshop/own_gift_doubt.gd").of(n)

## The prior the judge starts from: the poison and Delusional self-doubt alone, by night
## (own_doubt of the honest doubt SourceDoubt.derive gives the NPC's own readings).
static func self_doubt_prior(n) -> Dictionary:
	return n.workshop_state.get("self_doubt_prior", {}).duplicate()

## The nights, earliest first, on which the NPC doubts its own gift: its self_doubt at or above
## Tuning.Workshop.SELF_DOUBT_TRIGGER (Michael, Nov 19).
static func doubts_own_gift(n) -> Array:
	var d: Dictionary = self_doubt(n)
	var out: Array = d.keys().filter(func(k): return float(d[k]) >= Tuning.Workshop.SELF_DOUBT_TRIGGER)
	out.sort()
	return out

## Whether the deal's placement rules (ScriptDef.PLACEMENT_RULES) let a holder of `role`
## carry `secret`: a Chronicler or Rumormonger never holds the Delusional secret, so knowing
## its own gift rules out doubting itself that way. An unknown role could hold it.
## Diagnostics: off, every Night Watch list is scored name by name again, and one that
## wrongly names the listener is set aside and its night void (tests and tools only).
static var list_mix_enabled: bool = true

## The chance another's Night Watch list was broken that night, as a whole (BACKLOG "A Night
## Watch list that wrongly names the listener", Michael, Nov 18): the watcher's poison and
## Delusional priors, as independent ways the gift can fail, 1 - (1 - poison)(1 - delusional).
## No new number: the poison chance (ReadingChallenges.poison_chance, read with the night's
## outings) and the Delusional prior the listener applies to its own gift. Zero for the
## listener's own list, a quoted or duty-only card, a script with neither secret, or a view
## the live movement model doesn't read (`live_activity` off: the Workshop sandbox, whose
## movement factors never mix the list, so a kept list would be scored name by name and
## clear its watcher); there a list that wrongly names the listener stays set aside, and its
## night void, as before.
## At most this many lists in a view are mixed (the latest nights first): the movement
## factor is built once for every subset of them left out. A list beyond them gets no broken
## chance, so it keeps the old fallback (set aside and its night void when it wrongly names
## the listener) rather than being scored name by name (Codex on #273).
const LIST_MIX_MAX = 2

static func list_broken_chance(view: Dictionary, listener: Dictionary, card: Dictionary) -> float:
	var b: float = _list_broken_base(view, listener, card)
	if b <= 0.0:
		return 0.0
	var mixable: Array = view.get("cards", []).filter(func(c): return str(c.get("role", "")) == "nightwatch" and _list_broken_base(view, listener, c) > 0.0)
	mixable.sort_custom(func(a, b2): return int(a.get("night", -1)) > int(b2.get("night", -1)) or (int(a.get("night", -1)) == int(b2.get("night", -1)) and str(a.get("id", "")) < str(b2.get("id", ""))))
	var keep: Array = mixable.slice(0, LIST_MIX_MAX).map(func(c): return str(c.get("id", "")))
	if not view.get("cards", []).any(func(c): return str(c.get("id", "")) == str(card.get("id", ""))):
		return b
	return b if str(card.get("id", "")) in keep else 0.0

static func _list_broken_base(view: Dictionary, listener: Dictionary, card: Dictionary) -> float:
	if not list_mix_enabled or not view.get("live_activity", false) or str(card.get("kind", "")) != "report" or str(card.get("role", "")) != "nightwatch" or card.get("quoted", false) or card.get("duty_only", false):
		return 0.0
	var src: String = str(card.get("source", ""))
	var me: String = str(listener.get("id", listener.get("knowledge", {}).get("self", "")))
	if src == "" or src == me or src in ["player", "evidence", "town"]:
		return 0.0
	var night: int = int(card.get("night", card.get("observed_at", {}).get("day", -1)))
	var poison: float = ReadingChallenges.poison_chance(view, listener, night, src)
	var delusional: float = Tuning.Workshop.DELUSIONAL_SELF_DOUBT if "delusional" in view.get("world_options", {}).get("modifiers", []) and could_hold_secret("nightwatch", "delusional") else 0.0
	return 1.0 - (1.0 - poison) * (1.0 - delusional)

static func could_hold_secret(role: String, secret: String) -> bool:
	if role == "" or not C.has_role_def(role):
		return true
	var def = C.role_def(role)
	for rule in ScriptDef.PLACEMENT_RULES:
		if secret in rule.get("except", []) or (rule.has("only") and secret not in rule.only):
			continue
		if bool(def.get(str(rule.not_on_flag))):
			return false
	return true

## The player's "failed gift" calls as honest doubt, {"teller:night": doubt}: see derive.
## "Poisoned, not lying" (Michael, Nov 18, option C; docs/design/poisoned_not_lying.md): a
## "failed gift" challenge in one of the player's presented cases is the player's word that
## R's reading that night was poisoned, not a lie. The player is the expert, so the listener
## takes the call at its credibility in the player: a doubt from FAILED_GIFT_DOUBT_LOW at the
## lowest credibility to FAILED_GIFT_DOUBT_HIGH at the highest, in a straight line (Michael,
## Nov 18), or, where that is more, the call weighed as one witness as accurate as its trust
## in the player against the chance R was poisoned that night (ReadingChallenges.poison_chance
## with R as the reader, so an unexplained outing near R's home still strengthens a call;
## Quill). Honest doubt, so the clash reads as a broken gift rather than a lie, and
## whatever the reading held up moves to whoever the rest of the evidence favours; nothing
## spreads it on purpose. The one honest-mistake label (Michael, Nov 18, via Seneschal):
## "misled" is the same call, and it counts with no Poisoner possible too, at the
## credibility doubt alone (no poison chance to weigh). A wrong call costs the player
## through the track record ("R is good", Quill, game/credibility.gd), nothing more.
## The doubt a "failed gift" call carries by the listener's credibility in the player, before
## the one-witness weighing: FAILED_GIFT_DOUBT_LOW at Trust.CRED_MIN rising in a straight line
## to FAILED_GIFT_DOUBT_HIGH at Trust.CRED_MAX (clamped outside them).
static func call_doubt(c: float) -> float:
	var t: float = clampf((c - Tuning.Trust.CRED_MIN) / (Tuning.Trust.CRED_MAX - Tuning.Trust.CRED_MIN), 0.0, 1.0)
	return lerpf(Tuning.Workshop.FAILED_GIFT_DOUBT_LOW, Tuning.Workshop.FAILED_GIFT_DOUBT_HIGH, t)

static func _player_failed_gift(view: Dictionary, listener: Dictionary, cards: Array, self_id: String) -> Dictionary:
	var out: Dictionary = {}
	if not player_failed_gift:
		return out
	var poison_possible: bool = ReadingChallenges.poisoner_possible(view)
	var c_player: float = clampf(float(listener.get("player_credibility", listener.get("trust", 0.5))), 0.0, 1.0)
	var by_id: Dictionary = {}
	for card in cards:
		by_id[str(card.get("id", ""))] = card
	for cs in listener.get("connections", {}).get("cases", []):
		if str(cs.get("presenter", "")) != "player":
			continue
		var chs: Dictionary = cs.get("challenges", {})
		for rid in chs:
			var ch = chs[rid]
			if not ch is Dictionary or ReadingChallenges.canonical(ch.get("mode", "")) != ReadingChallenges.HONEST:
				continue
			var rc: Dictionary = by_id.get(str(rid), {})
			if rc.is_empty() or str(rc.get("kind", "")) != "report" or rc.get("quoted", false):
				continue
			# Only where some cause the script allows could have fooled this gift (Nov 18): with
			# none, a Mistaken call would wash a lie at no cost to the teller.
			if not ReadingChallenges.honest_allowed(view, rc, str(ch.get("attribution", ""))):
				continue
			# Whose gift: a challenge on a relayed reading names its side (ReadingChallenges.
			# RELAY_ATTRIBUTIONS). Its transmission is the Medium's, keyed as the relay's
			# reliability is; the original, and any unrelayed reading, is the teller's, by the
			# reading's day (Codex on #270).
			var transmission: bool = rc.has("relay_source") and str(ch.get("attribution", "")) == "transmission"
			var r_id: String = str(rc.get("relay_source", "")) if transmission else str(rc.get("source", ""))
			var r_day: int = int(rc.get("relay_observed_at", {}).get("day", -1)) if transmission else int(rc.get("observed_at", {}).get("day", rc.get("night", -1)))
			if r_id == "" or r_id == self_id or r_day < 0:
				continue
			# A Registrar's night-0 register can't be poisoned (sim/roles/registrar.gd), so a
			# call on it carries no poison chance, only the call; a Medium's transmission of it
			# can be poisoned (Codex on #270).
			var by_night: bool = transmission or str(rc.get("observed_at", {}).get("phase", "")) == "night"
			var r_night: int = r_day if by_night else r_day - 1
			var no_poison: bool = not poison_possible or (not transmission and str(rc.get("role", "")) == "registrar" and r_day == 0)
			var prior: float = 0.0 if no_poison else ReadingChallenges.poison_chance(view, listener, r_night, r_id)
			var w_doubt: float = maxf(call_doubt(c_player), witness_doubt(prior, c_player))
			var k_r: String = "%s:%d" % [r_id, r_day]
			out[k_r] = maxf(float(out.get(k_r, 0.0)), w_doubt)
	return out
