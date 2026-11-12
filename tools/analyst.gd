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
## Cross-check cases (belief-model plan, Phase 5): a pair whose joint strength beats the
## two cards alone by this much in log-odds (the connections core threshold) seeds a case.
const CROSS_MIN = 0.4
## Most cross-check pairs weighed per case.
const MAX_CROSS_PAIRS = 24
## Group readings a partner can complete by clearing another member.
const GROUP_ROLES = ["dowser", "archivist", "seer", "clerk", "registrar", "chronicler", "rumormonger"]
const PROFILE_FACETS = ["home_work", "haunts", "bonds"]
const WALK_CLAIMS = ["lamplighter", "nightwatch", "medium", "warden", "sexton"]


## Per-game memory: which cards the juror has accepted into its picture, which it set
## aside (they clash with what it already accepted, or the model can't read them), and
## which it never noticed (insight). Also counts juror evaluations, for timing.
static func new_state(insight: float) -> Dictionary:
	# (crosscheck: Phase 5 cross-check pairs; off with autoplay --no-crosscheck.)
	return {"insight": clampf(insight, 0.0, 1.0), "accepted": [], "rejected": {}, "missed": {}, "seen": {},
		"evals": 0, "eval_ms": 0, "cache_key": "", "posterior": {}, "crosscheck": true}


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
	# Profile receipts aren't in `accepted`, and `profiles` names only facets: key on the
	# facets' receipt ids too, so a newly learned haunt or home re-reads the board. The
	# declared demon type changes the movement model, so it's in the key as well.
	var key: String = JSON.stringify([state.accepted, profiles, _profile_receipts(view, profiles), str(g.w.declared_demon_type)])
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
	return {"ready": true, "impossible": ev.impossible, "lr": float(ev.get("lr", 1.0)), "posterior": float(ev.get("posterior", 0.0)), "people": ev.get("people", {}), "compiled": compiled}


## P(`pid` is the Demon) from the cards the juror accepts (meeting plan M4: the bot's Demon
## guess). 0 when the board can't be read.
static func demon_posterior(g, state: Dictionary, pid: String) -> float:
	if state.accepted.is_empty():
		return 0.0
	var view: Dictionary = WorkshopCanvas.view(g)
	var ev: Dictionary = evaluate(g, view, state.accepted, _profile_people(view), pid, state, "demon")
	if not ev.get("ready", false) or ev.get("impossible", true):
		return 0.0
	return float(ev.get("posterior", 0.0))


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
		if by_id.has(cid) and _bears_on(view, by_id[cid], target_id, state.get("exclusion_cards", true)):
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
	# Phase 5: seed with the strongest cross-check pair, whose partner card needn't name the
	# target (a reading clearing another member of a group the target is in; that night's
	# Lamplighter count beside a sighting of them). The greedy pass below never finds those,
	# since it only weighs cards that bear on the target.
	var cross: Dictionary = {}
	if state.get("crosscheck", true):
		cross = _best_cross_pair(g, view, by_id, state, target_id, singles)
		if not cross.is_empty():
			chosen = cross.ids.duplicate()
			cur_lr = float(cross.lr)
	for pair in singles:
		if pair[0] in chosen:
			continue
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
		return {"card": 0, "used_hub": false, "cross": false}
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
		var hub_ids: Array = Bot.select_circumstantial_cards(view, view.get("cards", []), target_id, signed_lean(posterior), stage1.get("disputes", []))
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
	return {"card": filed, "used_hub": attached_hub and not final_compiled.get("circumstantial", []).is_empty(),
		"cross": not cross.is_empty() and cross.ids.all(func(id): return id in final_compiled.cards)}


## The strongest cross-check pair for a case that `target_id` is evil: an accepted card
## that bears on them (an anchor) and an accepted partner that doesn't, whose joint strength
## beats the two alone by CROSS_MIN in log-odds. Partners: for a group reading naming the
## target, any reading naming another member of the group; for a night sighting of the
## target, that night's Lamplighter count. {} if none qualifies.
static func _best_cross_pair(g, view: Dictionary, by_id: Dictionary, state: Dictionary, target_id: String, singles: Array) -> Dictionary:
	var solo: Dictionary = {}
	for s in singles:
		solo[s[0]] = float(s[1])
	var pairs: Array = []
	for a in solo.keys():
		var ca: Dictionary = by_id[a]
		var d: Dictionary = ca.get("data", {}) if ca.get("data") is Dictionary else {}
		var group: Array = d.get("group", d.get("pair", []))
		if ca.get("kind", "") == "report" and target_id in group and group.size() >= 2:
			for p in state.accepted:
				if p == a or solo.has(p) or not by_id.has(p) or by_id[p].get("kind", "") != "report":
					continue
				if group.any(func(y): return y != target_id and _bears_on(view, by_id[p], y, false)):
					pairs.append([a, p])
		if ca.get("kind", "") == "sighting" and int(ca.get("night", -1)) >= 0:
			for p in state.accepted:
				var cp: Dictionary = by_id.get(p, {})
				if p != a and not solo.has(p) and cp.get("kind", "") == "report" and str(cp.get("role", "")) == "lamplighter" and int(cp.get("night", -2)) == int(ca.night):
					pairs.append([a, p])
	var best: Dictionary = {}
	var best_lr: float = 0.0
	var top_single: float = solo.values().max() if not solo.is_empty() else 1.0
	for pr in pairs.slice(0, MAX_CROSS_PAIRS):
		var alone: Dictionary = evaluate(g, view, [pr[1]], {}, target_id, state)
		var joint: Dictionary = evaluate(g, view, pr, {}, target_id, state)
		if not (alone.get("ready", false) and joint.get("ready", false)) or joint.get("impossible", true):
			continue
		var lr_a: float = maxf(solo[pr[0]], 1e-9)
		var lr_p: float = maxf(float(alone.get("lr", 1.0)), 1e-9)
		var lr_j: float = maxf(float(joint.lr), 1e-9)
		var interaction: float = log(lr_j) - log(lr_a) - log(lr_p)
		if interaction >= CROSS_MIN and lr_j > top_single and lr_j > best_lr:
			best_lr = lr_j
			best = {"ids": pr, "lr": lr_j, "interaction": interaction}
	return best


## Bayes factor of a Hexer over a walking Demon on everything the juror accepts: each
## possible world's unnormalised weight (prior x readings x movement x tests) summed with the
## town's mix set to Hexer, over the same sum set to walker. 1 when it can't be read.
## Used by the bot's demon-type declaration (Phase 5; game/demon_declaration.gd).
static func demon_type_odds(g, state: Dictionary) -> float:
	if state.accepted.is_empty():
		return 1.0
	var view: Dictionary = WorkshopCanvas.view(g)
	var model = CanvasModel.new(view)
	var root: String = model.selected
	model.nodes[root].conclusion = {"type": "evil", "target": _any_person(view), "at": view.alignment_epoch}
	for cid in state.accepted:
		var node: String = "e:" + str(cid)
		if model.nodes.has(node) and not model.nodes[node].has("merged"):
			model.connect_cards(node, root)
	var profiles: Dictionary = _profile_people(view)
	for pid in profiles:
		model.connect_cards(model.add_profile_info(pid, profiles[pid]), root)
	var compiled: Dictionary = model.compile(root)
	if compiled.get("cards", []).is_empty():
		return 1.0
	var input = WorkshopCanvas.snapshot(g, compiled)
	input.private_evidence = []
	input.evidence = input.evidence.filter(func(e): return e.id in input.selected)
	input.listener = {"id": "ghost", "name": "Analyst", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "source_doubt": {}, "own_gift": "", "legacy_evidence": []}
	# The movement factor is built in Assess.prepare from the snapshot's rules, so the
	# town's mix is set there (as the game's bridge does), once per kind.
	var sums: Dictionary = {}
	for kind in ["walker", "hexer"]:
		var inp: Dictionary = input.duplicate(true)
		inp.rules["declared_demon"] = kind
		var prepared = Assess.prepare(inp)
		state.evals += 1
		if not prepared.ready:
			return 1.0
		CaseEval.captured = []
		CaseEval.capture_worlds = true
		CaseEval.evaluate(prepared.view, prepared.case)
		CaseEval.capture_worlds = false
		var s: float = 0.0
		if not CaseEval.captured.is_empty():
			for x in CaseEval.captured[0].worlds:
				s += float(x)
		CaseEval.captured = []
		sums[kind] = s
	if sums.walker <= 0.0 or sums.hexer <= 0.0:
		return 1.0 if sums.walker <= 0.0 and sums.hexer <= 0.0 else (1e6 if sums.walker <= 0.0 else 1e-6)
	return sums.hexer / sums.walker


## The hub selector reads a signed lean (-1 cleared .. +1 damned, 0 = no shift). Map each
## posterior against the board's average belief: below average scales to -1 at zero,
## above scales to +1 at certainty.
static func signed_lean(posterior: Dictionary) -> Dictionary:
	if posterior.is_empty():
		return {}
	var mean: float = 0.0
	for id in posterior:
		mean += float(posterior[id])
	mean = clampf(mean / posterior.size(), 0.01, 0.99)
	var out: Dictionary = {}
	for id in posterior:
		var p: float = float(posterior[id])
		out[id] = (p - mean) / (1.0 - mean) if p >= mean else (p - mean) / mean
	return out


## Does a juror card bear on this person: about them, a reading naming them, a death, or a
## trace or night card at a scene they fit?
static func _bears_on(view: Dictionary, c: Dictionary, pid: String, exclusion: bool = true) -> bool:
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
	# Exclusion cards (meeting plan M4): an empty vigil, or a complete vigil list that leaves
	# them out, bears on a claimed walker the vigil should have seen. The greedy builder
	# still keeps it only if it raises the case's strength.
	if exclusion and (kind == "coverage" or (kind == "sighting" and c.get("complete", false))) and pid not in c.get("excluded", []):
		return view.get("cards", []).any(func(x): return x.get("kind", "") == "claim" and str(x.get("subject", x.get("source", ""))) == pid and str(x.get("role", "")) in WALK_CLAIMS)
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


## The receipt ids behind each unlocked facet the juror uses, per person.
static func _profile_receipts(view: Dictionary, profiles: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var facets_map: Dictionary = view.get("profile_facets", {})
	for pid in profiles:
		var ids: Array = []
		for f in profiles[pid]:
			ids.append(facets_map.get(pid, {}).get(f, {}).get("receipt_ids", []))
		out[pid] = ids
	return out


static func _any_person(view: Dictionary) -> String:
	for p in view.get("people", []):
		if p.get("alive", true):
			return p.id
	return ""
