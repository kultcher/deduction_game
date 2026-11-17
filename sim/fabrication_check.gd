## Evil fabrications check what's already public (BACKLOG [decided], from playtest 26532).
##
## Before an evil member's made-up reading joins what it can tell, it asks how the town would
## read it beside the readings already shared: a neutral listener on the public record (the
## shared judge's `CaseEval.evaluate`), with and without the fabrication. If the fabrication
## lifts the town's chance that the liar or a teammate is evil by more than a margin, a roll
## scaled by Insight decides whether the liar notices. Noticed, it thinks of a better lie:
## its bluff rule's other plausible readings (`RoleDef.bluff_alternatives`), keeping one
## that points at nobody on the team and still pushes the scapegoat (Michael, Nov 17). With
## none, it holds the reading back a day and checks it again before telling it. Unnoticed, the self-incriminating reading goes out as before: careless liars
## still slip, and the player can catch them.
##
## Every outcome is logged (`think`, topic `lie`), and stored on the entry as `vet` for the
## measurement tools.
##
## Scope: report-shaped readings only. Night Watch and Medium fabrications become sighting
## cards in the judge and aren't checked (or used as public context) here.
extends RefCounted

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const ReasonAttribution = preload("res://workshop/reason_attribution.gd")

const SKIP_ROLES: Array = ["nightwatch", "medium"]

static var enabled: bool = true


## A reading entry as a public report card (the shape ReasonAttribution's probe card uses).
static func _card(src_id: String, e: Dictionary, idx: int) -> Dictionary:
	var role: String = str(e.get("role", ""))
	var nd: int = int(e.get("day", 0))
	var phase_name: String = "night"
	if e.has("phase") and int(e.get("phase", C.NIGHT)) != C.NIGHT:
		phase_name = str(C.PHASES[int(e.phase)]).to_lower()
	return {
		"id": "fabcheck:%s:%d:%s:%d" % [src_id, nd, role, idx],
		"kind": "report",
		"source": src_id,
		"role": role,
		"night": nd if phase_name == "night" or role in ["martyr", "sexton"] else -1,
		"observed_at": {"day": nd, "phase": phase_name},
		"data": e.get("data", {}).duplicate(true),
		"subject": "",
		"subjects": [],
	}


## Every reading shared so far, as cards.
static func public_cards(w) -> Array:
	var out: Array = []
	for p in w.npcs:
		for i in range(p.info_log.size()):
			var e: Dictionary = p.info_log[i]
			if not e.get("shared", false) or e.get("disowned", false) or str(e.get("role", "")) in SKIP_ROLES:
				continue
			out.append(_card(p.id, e, i))
	return out


static func _posteriors(view: Dictionary, cards: Array, ids: Array) -> Dictionary:
	view.cards = cards
	var cs: Dictionary = Solver.empty_case()
	cs.cards = cards.map(func(c): return c.id)
	cs.conclusion = {"type": "evil", "target": ids[0], "at": view.alignment_epoch}
	var ev: Dictionary = CaseEval.evaluate(view, cs, CaseEval.neutral_listener(view))
	if ev.get("impossible", false):
		return {}
	var out: Dictionary = {}
	for id in ids:
		out[id] = float(ev.get("people", {}).get(id, {}).get("posterior", 0.0))
	return out


## How far `entry`, told by `n`, would lift the town's chance that each of evil's living
## members is evil: {"lift", "who", "before", "after"}, or {} if it can't be judged.
static func assess(w, n, entry: Dictionary, extra: Array = []) -> Dictionary:
	if str(entry.get("role", "")) in SKIP_ROLES:
		return {}
	var team: Array = w.evil_team().filter(func(m): return m.alive).map(func(m): return m.id)
	if not (n.id in team):
		team.append(n.id)
	var ids: Array = team.duplicate()
	for x in extra:
		if x != "" and w.by_id.has(x) and not (x in ids):
			ids.append(x)
	var view: Dictionary = ReasonAttribution.public_view_from_world(w)
	var cards: Array = public_cards(w)
	var before: Dictionary = _posteriors(view, cards, ids)
	var with_fake: Array = cards.duplicate()
	with_fake.append(_card(n.id, entry, -1))
	var after: Dictionary = _posteriors(ReasonAttribution.public_view_from_world(w), with_fake, ids)
	if before.is_empty() or after.is_empty():
		# The fabrication can't stand beside the public record at all: the town would see a
		# liar. Count it as the largest lift on the teller.
		return {"lift": 1.0, "who": n.id, "before": before, "after": after, "impossible": true}
	var lift: float = -INF
	var who: String = ""
	for id in team:
		var d: float = float(after.get(id, 0.0)) - float(before.get(id, 0.0))
		if d > lift:
			lift = d
			who = id
	return {"lift": snappedf(lift, 0.001), "who": who, "before": before, "after": after}


## Vet a fresh fabrication. `alternatives` returns the bluff rule's other plausible
## readings ([{"entry", "why"}], already stamped); `scapegoat` is evil's chosen target.
## Returns {"entry", "outcome": "ok"|"slipped"|"reworked"|"held", "why": the chosen
## alternative's reason or ""}. A held entry is the caller's to keep back a day.
static func vet(w, n, entry: Dictionary, alternatives: Callable, scapegoat: String = "") -> Dictionary:
	if not enabled:
		return {"entry": entry, "outcome": "ok", "why": ""}
	var tune = Tuning.Evil
	var a: Dictionary = assess(w, n, entry)
	if a.is_empty() or float(a.lift) <= tune.FABRICATION_CHECK_MARGIN:
		entry["vet"] = {"outcome": "ok", "lift": a.get("lift", 0.0)}
		return {"entry": entry, "outcome": "ok", "why": ""}
	var insight: float = float(n.traits.get("insight", 0.5))
	var p_notice: float = tune.FABRICATION_NOTICE_BASE + tune.FABRICATION_NOTICE_INSIGHT * insight
	var noticed: bool = w.decision_roll(n, "notice_self_incrimination", p_notice, {"insight": insight, "lift": a.lift, "who": a.who})
	if not noticed:
		entry["vet"] = {"outcome": "slipped", "lift": a.lift, "who": a.who}
		w.dlog.think(n.id, "lie", "Evil: doesn't notice that its %s reading points the town at %s (+%.2f)." % [entry.get("role", "?"), a.who, a.lift], {"lie": true})
		return {"entry": entry, "outcome": "slipped", "why": ""}
	# A better lie: of the rule's other readings, those that point at nobody on the team; of
	# those, the one that still pushes the scapegoat hardest.
	var best: Dictionary = {}
	var best_push: float = -INF
	for alt in alternatives.call():
		var e2: Dictionary = alt.get("entry", {})
		if e2.is_empty():
			continue
		var b: Dictionary = assess(w, n, e2, [scapegoat])
		if b.is_empty() or b.get("impossible", false) or float(b.lift) > tune.FABRICATION_CHECK_MARGIN:
			continue
		var push: float = 0.0
		if scapegoat != "" and b.after.has(scapegoat):
			push = float(b.after[scapegoat]) - float(b.before.get(scapegoat, 0.0))
		if push > best_push:
			best_push = push
			best = {"entry": e2, "why": str(alt.get("why", "")), "lift": float(b.lift)}
	if not best.is_empty():
		var chosen: Dictionary = best.entry
		chosen["vet"] = {"outcome": "reworked", "lift": a.lift, "who": a.who, "new_lift": best.lift, "pushes_scapegoat": snappedf(best_push, 0.001)}
		w.dlog.think(n.id, "lie", "Evil: its %s reading would point the town at %s (+%.2f); tells a better lie instead: %s." % [entry.get("role", "?"), a.who, a.lift, best.why], {"lie": true})
		return {"entry": chosen, "outcome": "reworked", "why": best.why}
	entry["vet"] = {"outcome": "held", "lift": a.lift, "who": a.who}
	w.dlog.think(n.id, "lie", "Evil: its %s reading would point the town at %s (+%.2f), and no safer one fits; holds it back a day." % [entry.get("role", "?"), a.who, a.lift], {"lie": true})
	return {"entry": entry, "outcome": "held", "why": ""}
