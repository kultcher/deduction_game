## Top Demon candidates: who an NPC thinks is the Demon, given they're evil (Lantern, Nov 22,
## for Beadle's Seer, which looks for the Demon rather than for evil). From one judgement over
## every card the NPC's last connections refresh held (the inputs OwnGiftDoubt.stage keeps),
## with its worlds kept (CaseEval.capture_worlds) and summed by each world's Demon.
##
## Why a ratio from the joint judgement, not the connections chances themselves: the
## connections model assembles each person's evil chance from separate items, and has no
## "who is the Demon" to assemble. Among the worlds where someone is evil, who leads the team
## is what the joint judgement weighs well: a Seer's "yes" on a pair, a "no" clearing one,
## a Gravedigger or Executor naming a Minion's role. So the joint sum gives P(Demon | evil),
## and a caller wanting P(Demon) multiplies it by the NPC's own evil chance for that person
## (demon_chance), so the two never tell different stories about who is evil.
##
## Lazy: nothing in play asks it yet, and asking costs one judgement, kept until the next
## refresh. Reads only.
extends RefCounted

const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const OwnGiftDoubt = preload("res://workshop/own_gift_doubt.gd")

## {person id: {"demon": P(Demon), "evil": P(evil), "given_evil": P(Demon | evil)}} for
## everyone but the listener, from the joint judgement over `held`. {} when nothing fits.
## "given_evil" is 0 for someone evil in no world.
static func of(view: Dictionary, listener: Dictionary, held: Array) -> Dictionary:
	var self_id: String = str(listener.get("id", listener.get("knowledge", {}).get("self", "")))
	var ids: Array = Solver.person_ids(view)
	var others: Array = ids.filter(func(p): return p != self_id)
	if others.is_empty():
		return {}
	var q: Dictionary = Solver.empty_case()
	q.cards = held.duplicate()
	q.conclusion = {"type": "evil", "target": str(others[0]), "at": view.get("alignment_epoch", "")}
	var was: bool = CaseEval.capture_worlds
	var was_cap: Array = CaseEval.captured
	CaseEval.capture_worlds = true
	CaseEval.captured = []
	var ev: Dictionary = CaseEval.evaluate(view, q, listener)
	var cap: Array = CaseEval.captured
	CaseEval.capture_worlds = was
	CaseEval.captured = was_cap
	if ev.get("impossible", false) or cap.is_empty():
		return {}
	var post: PackedFloat64Array = cap[-1].worlds
	var universe: Array = Solver.universe(view)
	var n_people: int = ids.size()
	var demon_w := PackedFloat64Array()
	var evil_w := PackedFloat64Array()
	demon_w.resize(n_people)
	evil_w.resize(n_people)
	demon_w.fill(0.0)
	evil_w.fill(0.0)
	var total: float = 0.0
	for i in range(mini(post.size(), universe.size())):
		var m: float = post[i]
		if m <= 0.0:
			continue
		total += m
		var w: Dictionary = universe[i]
		var d: int = int(w.get("demon", -1))
		if d >= 0 and d < n_people:
			demon_w[d] += m
		var evil: int = int(w.get("evil", 0))
		var j: int = 0
		while evil and j < n_people:
			if evil & 1:
				evil_w[j] += m
			evil >>= 1
			j += 1
	if total <= 0.0:
		return {}
	var out: Dictionary = {}
	for j in range(n_people):
		var pid: String = str(ids[j])
		if pid == self_id:
			continue
		var pd: float = demon_w[j] / total
		var pe: float = evil_w[j] / total
		out[pid] = {"demon": pd, "evil": pe, "given_evil": clampf(pd / pe, 0.0, 1.0) if pe > 0.0 else 0.0}
	return out

## The NPC's candidates from its last connections refresh, asked of the judge the first time
## and kept until the next refresh (OwnGiftDoubt.stage replaces the staged inputs). {} with no
## staged refresh.
static func of_npc(n) -> Dictionary:
	if not n.has_meta(OwnGiftDoubt.META):
		return {}
	var staged: Dictionary = n.get_meta(OwnGiftDoubt.META)
	if not staged.has("demon"):
		staged["demon"] = of(staged.view, staged.listener, staged.held)
	return staged.demon.duplicate(true)

## {person id: P(Demon | evil)} for the NPC: what Beadle's Seer reads.
static func given_evil_of_npc(n) -> Dictionary:
	var out: Dictionary = {}
	var all: Dictionary = of_npc(n)
	for pid in all:
		out[pid] = float(all[pid].given_evil)
	return out

## P(`pid` is the Demon) for the NPC, on its own evil chance for them: P(Demon | evil) from the
## joint judgement times `evil_chance` (the NPC's belief, e.g. its suspicion's evil chance).
static func demon_chance(n, pid: String, evil_chance: float) -> float:
	var all: Dictionary = of_npc(n)
	if not all.has(pid):
		return 0.0
	return clampf(float(all[pid].given_evil) * evil_chance, 0.0, 1.0)
