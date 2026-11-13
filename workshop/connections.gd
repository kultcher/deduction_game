## The connections belief model (Phase 6; Project doc
## `claude/belief-model-direction-2026-11-10.md`, "Phase 6 spec"). Behind a switch that is
## off by default: with it off nothing here runs, and the game behaves exactly as before.
##
## The idea: the limit on an NPC moves from which cards it reads to which cards it weighs
## together. Every card it holds counts, at the value it has alone; cards are only weighed
## together where a connection says so (built-in pairings, the NPC's own core, stored
## cases). Those connections arrive in later steps; this file starts with the single values
## and the normalising.
##
##   judge       today's shared evaluator (CaseEval over the possible worlds) run on a chosen
##               set of the held cards: everyone's chance of being evil given just that set
##   prior       the listener's standing suspicion and what it knows about itself, before
##               any evidence: the judge's "before" side, the same as today's
##   baseline    the judge on no cards: the prior plus the public record (deaths, executions),
##               which is in every run
##   lean        how far a set moves a person from the baseline, in log-odds, so leans add
##   normalising one common shift afterwards, so the chances of being evil still sum to what
##               the baseline's do (the script's evil count): "A for sure, then B or C",
##               never four people at 70% in a two-evil town
##
## Pure: the prepared view, case and listener in; chances and a breakdown out. It reads no
## game state and keeps no memory yet (caching is a later step).
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")

## The switch. It starts from the Tuning value; tests, autoplay and sweeps set it for a run
## (`--connections`), so paired cells come from one build.
static var enabled: bool = Tuning.Workshop.CONNECTIONS

## A chance is held inside [CLIP, 1 - CLIP] before it becomes log-odds.
const CLIP: float = Tuning.Workshop.CONNECTIONS_CLIP
## A person the baseline already puts this close to 0 or 1 is settled (the public record,
## the listener's own knowledge): cards don't move them.
const FIXED: float = Tuning.Workshop.CONNECTIONS_FIXED

const LIST_KEYS: Array = ["lines", "derived", "arguments", "circumstantial", "temporal_positions", "disputes", "test_factors", "conflict_scope"]
const MAP_KEYS: Array = ["positions", "answers", "reasons", "citations", "faults", "challenges", "reading_challenges"]


## The listener's whole-evidence case stripped to a bare "these cards" case: no lines,
## answers or challenges, and no cards yet. `target` only names the question CaseEval is
## asked; everyone's chance comes back whichever person it is.
static func template(case_data: Dictionary, target: String) -> Dictionary:
	var out: Dictionary = case_data.duplicate(true)
	for key in LIST_KEYS:
		out[key] = []
	for key in MAP_KEYS:
		out[key] = {}
	out.cards = []
	out.conclusion = {"type": "evil", "target": target, "at": case_data.get("conclusion", {}).get("at", "Original alignment")}
	return out


## The template with a set of held card ids (sorted, so one set is always one case).
static func case_for(template_case: Dictionary, ids: Array) -> Dictionary:
	var sorted: Array = ids.duplicate()
	sorted.sort()
	var out: Dictionary = template_case.duplicate(true)
	out.cards = sorted
	return out


## The judge on a set of held cards.
static func judge(view: Dictionary, template_case: Dictionary, listener: Dictionary, ids: Array) -> Dictionary:
	return CaseEval.evaluate(view, case_for(template_case, ids), listener)


static func logit(p: float, clip: float = CLIP) -> float:
	var q: float = clampf(p, clip, 1.0 - clip)
	return log(q / (1.0 - q))


static func chance(log_odds: float) -> float:
	return 1.0 / (1.0 + exp(-log_odds))


## The one shift, in log-odds, that makes the chances behind `scores` sum to `target`.
static func common_shift(scores: Array, target: float) -> float:
	var lo := -30.0
	var hi := 30.0
	for step in range(60):
		var mid: float = (lo + hi) / 2.0
		var s := 0.0
		for score in scores:
			s += 1.0 / (1.0 + exp(-(float(score) + mid)))
		if s > target:
			hi = mid
		else:
			lo = mid
	return (lo + hi) / 2.0


## One belief refresh under connections: everyone's chance of being evil from the cards in
## `held` (ids, the listener's held cards with the ones it rejects from its own knowledge
## already taken out). `listener` is the evaluator's listener (Jury._eval_listener) with no
## challenges applied.
## Returns {"prior", "baseline", "posterior": {id: chance}, "shift": log-odds,
## "impossible": bool, "items": [{"key", "cards", "lean": {id: log-odds}}], "judgements": int}.
static func refresh(view: Dictionary, case_data: Dictionary, listener: Dictionary, held: Array) -> Dictionary:
	var self_id: String = str(listener.get("id", ""))
	var others: Array = Solver.person_ids(view).filter(func(p): return p != self_id)
	if others.is_empty():
		return {"prior": {}, "baseline": {}, "posterior": {}, "shift": 0.0, "impossible": false, "items": [], "judgements": 0}
	var bare: Dictionary = template(case_data, others[0])
	var base: Dictionary = judge(view, bare, listener, [])
	var judgements: int = 1
	var prior: Dictionary = {}
	var baseline: Dictionary = {}
	var total: Dictionary = {}
	for p in others:
		prior[p] = float(base.people.get(p, {}).get("prior", 0.0))
		baseline[p] = float(base.people.get(p, {}).get("posterior", 0.0))
		total[p] = 0.0
	if base.get("impossible", false):
		# Nothing fits what the listener already knows: no card can be read against it.
		return {"prior": prior, "baseline": baseline, "posterior": prior.duplicate(), "shift": 0.0, "impossible": true, "items": [], "judgements": judgements}
	var items: Array = []
	var ids: Array = held.duplicate()
	ids.sort()
	for id in ids:
		var ev: Dictionary = judge(view, bare, listener, [id])
		judgements += 1
		var entry: Dictionary = {"key": id, "cards": [id], "lean": {}}
		if ev.get("impossible", false):
			# A card no world allows says nothing about anyone on its own.
			entry["impossible"] = true
			items.append(entry)
			continue
		for p in others:
			var moved: float = logit(float(ev.people.get(p, {}).get("posterior", baseline[p]))) - logit(baseline[p])
			if not is_zero_approx(moved):
				entry.lean[p] = moved
				total[p] += moved
		items.append(entry)
	# Normalise: the people still in question keep the sum the baseline gave them.
	var free: Array = others.filter(func(p): return baseline[p] > FIXED and baseline[p] < 1.0 - FIXED)
	var target := 0.0
	var scores: Array = []
	for p in free:
		target += baseline[p]
		scores.append(logit(baseline[p]) + total[p])
	var shift: float = common_shift(scores, target) if not free.is_empty() else 0.0
	var posterior: Dictionary = {}
	for p in others:
		posterior[p] = baseline[p]
	for i in range(free.size()):
		posterior[free[i]] = chance(float(scores[i]) + shift)
	return {"prior": prior, "baseline": baseline, "posterior": posterior, "shift": shift, "impossible": false, "items": items, "judgements": judgements}


## Today's evaluation with everyone's chances replaced by the connections result, so the
## code after it (belief to suspicion, who to hang first, reasons) reads the new chances.
static func overlay(ev: Dictionary, result: Dictionary) -> Dictionary:
	var out: Dictionary = ev.duplicate(true)
	out["impossible"] = bool(result.get("impossible", false))
	var people: Dictionary = out.get("people", {})
	for p in result.posterior:
		people[p] = {"prior": result.prior[p], "posterior": result.posterior[p]}
	out["people"] = people
	return out


## A short form of the breakdown for the dev log: each item and the largest lean it gives.
static func summary(result: Dictionary) -> Dictionary:
	var items: Array = []
	for it in result.get("items", []):
		var top: String = ""
		var size: float = 0.0
		for p in it.lean:
			if absf(float(it.lean[p])) > absf(size):
				size = float(it.lean[p])
				top = p
		items.append({"key": it.key, "cards": it.cards.size(), "on": top, "lean": snappedf(size, 0.001)})
	return {"items": items, "judgements": int(result.get("judgements", 0)), "shift": snappedf(float(result.get("shift", 0.0)), 0.001)}
