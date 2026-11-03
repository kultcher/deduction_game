## The analyst bot's reasoning (legacy purge phase 4c, docs/legacy_retirement_plan.md).
## A neutral test juror reads the player's board through the shared model (the same
## CaseEval the town uses) and gives every person a posterior chance of being evil. The
## bot ranks, nominates, votes and builds Workshop cases from that, so it measures the
## game's ceiling: a near-ideal reader of what the player has seen. `insight` < 1.0
## makes it miss cards at random (seeded by the bot's own RNG, never the world's).
##
## Uses only player-visible receipts (WorkshopCanvas.view), never hidden truth.
extends RefCounted

const CanvasModel = preload("res://workshop/canvas_model.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")

## Board evidence the juror reads (per WorkshopCanvas.view card kinds).
const EVIDENCE_KINDS = ["report", "death", "context", "sighting", "alibi", "trace", "claim", "coverage", "dropped", "location", "evening"]
## Most cards a built case uses, and how many candidates it weighs.
const MAX_CASE_CARDS = 8
const MAX_CANDIDATES = 12
## A card joins a case only if it raises the juror's likelihood ratio by this factor.
const MIN_LR_GAIN = 1.03
## A case is presented only if the juror rates it at least this strong (as the old bot).
const MIN_CASE_LR = 1.45
const HUB_CASE_LR = 1.55
const PROFILE_FACETS = ["home_work", "haunts", "bonds"]


## Per-game memory: which cards the juror has accepted into its picture, which it set
## aside (they clash with what it already accepted, or the model can't read them), and
## which it never noticed (insight). Also counts juror evaluations, for timing.
static func new_state(insight: float) -> Dictionary:
	return {"insight": clampf(insight, 0.0, 1.0), "accepted": [], "rejected": {}, "missed": {}, "seen": {},
		"evals": 0, "eval_ms": 0, "cache_key": "", "posterior": {}}


## Posterior P(evil) per living-or-dead person id from everything the juror accepts on
## the board. Cards are taken in board order; one that would make the picture impossible
## (a lie colliding with what's already accepted) is set aside.
static func belief(g, state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var view: Dictionary = WorkshopCanvas.view(g)
	var cards: Array = view.get("cards", []).filter(func(c): return not c.get("profile_receipt", false) and c.get("kind", "") in EVIDENCE_KINDS)
	var present: Dictionary = {}
	for c in cards:
		present[c.id] = true
	state.accepted = state.accepted.filter(func(id): return present.has(id))
	var target: String = _any_person(view)
	if target == "":
		return {}
	var profiles: Dictionary = _profile_people(view)
	for c in cards:
		var cid: String = c.id
		if state.seen.has(cid):
			continue
		state.seen[cid] = true
		if state.insight < 1.0 and rng.randf() >= state.insight:
			state.missed[cid] = true
			continue
		var trial: Dictionary = evaluate(g, view, state.accepted + [cid], profiles, target, state)
		if trial.get("ready", false) and not trial.get("impossible", true):
			state.accepted.append(cid)
		else:
			state.rejected[cid] = "impossible" if trial.get("ready", false) else "unreadable"
	var key: String = JSON.stringify([state.accepted, profiles])
	if key == state.cache_key:
		return state.posterior
	var out: Dictionary = {}
	if not state.accepted.is_empty():
		var full: Dictionary = evaluate(g, view, state.accepted, profiles, target, state)
		if full.get("ready", false) and not full.get("impossible", true):
			for id in full.people:
				out[id] = float(full.people[id].posterior)
	if out.is_empty():
		for p in view.get("people", []):
			out[p.id] = 0.0
	state.cache_key = key
	state.posterior = out
	return out


## One juror evaluation: the given cards (and profile facets) under "target is evil".
## Returns {ready, impossible, lr, people, compiled}.
static func evaluate(g, view: Dictionary, ids: Array, profiles: Dictionary, target: String, state: Dictionary, conclusion: String = "evil") -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var model = CanvasModel.new(view)
	var root: String = model.selected
	model.nodes[root].conclusion = {"type": conclusion, "target": target, "at": view.alignment_epoch}
	for cid in ids:
		var node: String = "e:" + str(cid)
		if model.nodes.has(node) and not model.nodes[node].has("merged"):
			model.connect_cards(node, root)
	for pid in profiles:
		var pnode: String = model.add_profile_info(pid, profiles[pid])
		model.connect_cards(pnode, root)
	var compiled: Dictionary = model.compile(root)
	if compiled.get("cards", []).is_empty():
		return {"ready": false}
	var input = WorkshopCanvas.snapshot(g, compiled)
	input.private_evidence = []
	input.evidence = input.evidence.filter(func(e): return e.id in input.selected)
	input.listener = {"id": "ghost", "name": "Analyst", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "source_doubt": {}, "own_gift": "", "legacy_evidence": []}
	var prepared = Assess.prepare(input)
	state.evals += 1
	if not prepared.ready:
		state.eval_ms += Time.get_ticks_msec() - started
		return {"ready": false}
	var ev: Dictionary = CaseEval.evaluate(prepared.view, prepared.case)
	state.eval_ms += Time.get_ticks_msec() - started
	return {"ready": true, "impossible": ev.impossible, "lr": float(ev.get("lr", 1.0)), "people": ev.get("people", {}), "compiled": compiled}


## Build and file a Workshop case that `target_id` is evil: weigh each accepted card that
## bears on them alone, then add them strongest first while each raises the juror's
## strength, up to MAX_CASE_CARDS. Attach a Circumstantial hub when the case is strong
## enough (as the previous bot did). Returns {card, used_hub}.
static func build_case(g, state: Dictionary, target_id: String, posterior: Dictionary, include_hub: bool,
		filed_sigs: Dictionary, last_by_target: Dictionary) -> Dictionary:
	var Bot = preload("res://tools/autoplay_workshop.gd")
	var view: Dictionary = WorkshopCanvas.view(g)
	var by_id: Dictionary = {}
	for c in view.get("cards", []):
		by_id[c.id] = c
	var candidates: Array = []
	for cid in state.accepted:
		if by_id.has(cid) and _bears_on(view, by_id[cid], target_id):
			candidates.append(cid)
	if candidates.is_empty():
		return {"card": 0, "used_hub": false}
	var facets: Dictionary = _profile_people(view)
	var target_facets: Dictionary = {}
	if facets.has(target_id):
		target_facets[target_id] = facets[target_id]
	var singles: Array = []
	for cid in candidates.slice(0, MAX_CANDIDATES):
		var one: Dictionary = evaluate(g, view, [cid], target_facets if by_id[cid].kind == "trace" else {}, target_id, state)
		if one.get("ready", false) and not one.get("impossible", true):
			singles.append([cid, one.lr])
	singles.sort_custom(func(a, b): return a[1] > b[1] if a[1] != b[1] else str(a[0]) < str(b[0]))
	var chosen: Array = []
	var cur_lr: float = 1.0
	var best: Dictionary = {}
	for pair in singles:
		if chosen.size() >= MAX_CASE_CARDS:
			break
		var trial_ids: Array = chosen + [pair[0]]
		var uses_trace: bool = trial_ids.any(func(id): return by_id[id].kind == "trace")
		var trial: Dictionary = evaluate(g, view, trial_ids, target_facets if uses_trace else {}, target_id, state)
		if trial.get("ready", false) and not trial.get("impossible", true) and trial.lr > cur_lr * MIN_LR_GAIN:
			chosen = trial_ids
			cur_lr = trial.lr
			best = trial
	if chosen.is_empty() or cur_lr < MIN_CASE_LR:
		return {"card": 0, "used_hub": false}
	# Rebuild the chosen case as a canvas the game can file (with an optional hub).
	var model = CanvasModel.new(view)
	var root: String = model.selected
	model.nodes[root].conclusion = {"type": "evil", "target": target_id, "at": view.alignment_epoch}
	for cid in chosen:
		var node: String = "e:" + str(cid)
		if model.nodes.has(node) and not model.nodes[node].has("merged"):
			model.connect_cards(node, root)
	if chosen.any(func(id): return by_id[id].kind == "trace") and target_facets.has(target_id):
		model.connect_cards(model.add_profile_info(target_id, target_facets[target_id]), root)
	var stage1: Dictionary = model.compile(root)
	var attached_hub = false
	if include_hub and cur_lr >= HUB_CASE_LR:
		var hub_ids: Array = Bot.select_circumstantial_cards(view, view.get("cards", []), target_id, posterior, stage1.get("disputes", []))
		if not hub_ids.is_empty():
			var hub: String = model.add_circumstantial_hub()
			for hcid in hub_ids:
				var hn: String = "e:" + str(hcid)
				if model.nodes.has(hn) and not model.nodes[hn].has("merged"):
					model.connect_cards(hn, hub)
			model.connect_cards(hub, root)
			attached_hub = true
	var final_compiled: Dictionary = model.compile(root)
	var sig: String = JSON.stringify([target_id, final_compiled.cards, final_compiled.get("circumstantial", [])])
	if filed_sigs.has(sig):
		return {"card": 0, "used_hub": false}
	var check: Dictionary = WorkshopCanvas.status(g, final_compiled)
	if check.get("blocked", true) or not check.get("audience_ready", false):
		return {"card": 0, "used_hub": false}
	var filed: int = WorkshopCanvas.file(g, final_compiled, int(last_by_target.get(target_id, 0)))
	if filed <= 0:
		return {"card": 0, "used_hub": false}
	filed_sigs[sig] = filed
	last_by_target[target_id] = filed
	return {"card": filed, "used_hub": attached_hub and not final_compiled.get("circumstantial", []).is_empty()}


## Does a juror card bear on this person: about them, a reading naming them, a death, or a
## trace or night card at a scene they fit?
static func _bears_on(view: Dictionary, c: Dictionary, pid: String) -> bool:
	var kind: String = c.get("kind", "")
	if kind == "death" or (kind == "context" and c.get("context_kind", "") == "death"):
		return true
	if pid in c.get("subjects", []) or c.get("subject", "") == pid:
		return true
	var d: Dictionary = c.get("data", {})
	if pid in d.get("pair", []) or pid in d.get("group", []) or pid in d.get("seen", []):
		return true
	if kind == "trace":
		return LiveActivity.evaluate_trace_for_person(view, view.get("cards", []), c, pid).state == "matches"
	return false


## Profile facets the player has unlocked, per person (traces need homes and haunts).
static func _profile_people(view: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var facets_map: Dictionary = view.get("profile_facets", {})
	for pid in facets_map:
		var unlocked: Array = []
		for f in PROFILE_FACETS:
			if facets_map[pid].get(f, {}).get("unlocked", false):
				unlocked.append(f)
		if not unlocked.is_empty():
			out[pid] = unlocked
	return out


static func _any_person(view: Dictionary) -> String:
	for p in view.get("people", []):
		if p.get("alive", true):
			return p.id
	return ""
