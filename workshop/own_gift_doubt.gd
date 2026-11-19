## "Was my gift turned?" from the NPC's own readings clashing with what else it holds (Michael,
## Nov 19, approving Lantern's measurement). For each night of a good NPC's own gift readings,
## the judge's chance that the reading was wrong: CaseEval's "holds" question on the reading,
## with every card the listener's connections refresh held, the reading among them. For one's
## own reading, wrong means the gift failed, since the NPC knows it told it truly. The poison
## and Delusional self-doubt (SourceDoubt.derive) are its starting point, inside the judge, as
## the reading's honest doubt; the clash does the rest. So a reading that fits the rest stays
## near 0, and one that fights what the NPC otherwise believes can rise well past the prior.
## Measured Nov 19 (42 ten-NPC games, seeds 3032-3095, the day-4 meeting): at
## Tuning.Workshop.SELF_DOUBT_TRIGGER (0.30) it reached about 4 in 10 false readings and about
## 1 in 17 true ones, about once in 5 games.
## Readings whose content the "holds" question doesn't check (a reading that holds in every
## world: a Warden's quiet night, a Lamplighter's count, a Night Watch list, a Psychologist's
## or Sexton's reading) carry no entry, nor does a Medium's relayed transmission (a sighting,
## not a report): their clash is weighed through movement, or not at all. Reads only.
extends RefCounted

const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")

## {night: the judge's chance that the listener's own reading that night was wrong}, the
## highest of that night's readings. `view` and `listener`: a prepared evaluation's (the
## weigher Jury._eval_listener builds); `held`: the card ids the connections refresh held.
static func posterior(view: Dictionary, listener: Dictionary, held: Array) -> Dictionary:
	var out: Dictionary = {}
	var self_id: String = str(listener.get("id", listener.get("knowledge", {}).get("self", "")))
	if self_id == "":
		return out
	for c in view.get("cards", []):
		if str(c.get("kind", "")) != "report" or str(c.get("source", "")) != self_id or c.has("relay_source") \
				or c.get("quoted", false) or c.get("duty_only", false) or not (str(c.get("id", "")) in held):
			continue
		if not checked(view, c):
			continue
		var night: int = int(c.get("observed_at", {}).get("day", c.get("night", -1)))
		if night < 0:
			continue
		var q: Dictionary = Solver.empty_case()
		q.cards = held.duplicate()
		q.conclusion = {"type": "holds", "report": str(c.id), "target": self_id, "at": view.get("alignment_epoch", "")}
		var ev: Dictionary = CaseEval.evaluate(view, q, listener)
		if ev.get("impossible", false):
			continue
		var wrong: float = clampf(1.0 - float(ev.get("posterior", 1.0)), 0.0, 1.0)
		out[night] = maxf(float(out.get(night, 0.0)), wrong)
	return out


## Whether some world could make the reading's content wrong (Solver.reading_holds_table has
## a world it fails in). One that holds in every world says nothing the judge can weigh.
static func checked(view: Dictionary, card: Dictionary) -> bool:
	for b in Solver.reading_holds_table(view, card):
		if b == 0:
			return true
	return false
