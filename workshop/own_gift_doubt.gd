## "Was my gift turned?" from the NPC's own readings clashing with what else it holds (Michael,
## Nov 19, approving Lantern's measurement). For each night of a good NPC's own gift readings,
## the judge's chance that the reading was wrong: CaseEval's "holds" question on the reading,
## with every card the listener's connections refresh held, the reading among them. For one's
## own reading, wrong means the gift failed, since the NPC knows it told it truly. The poison
## and Delusional self-doubt (SourceDoubt.derive) are its starting point, inside the judge, as
## the reading's honest doubt; the clash does the rest. So a reading that fits the rest stays
## near 0, and one that fights what the NPC otherwise believes can rise well past the prior.
## Measured Nov 19 (seeds 3032-3095, ten NPCs, the day-4 meeting; 104 nights in 39 games): at
## Tuning.Workshop.SELF_DOUBT_TRIGGER (0.30) it fired on 13 nights in 10 games, for 6 of 9
## false readings and 4 of 86 true ones; 78 of the 104 nights sat below their prior.
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


## Each reader's chance of being the Delusional, from one judgement over the cards the refresh
## held (shared Delusion doubt, Michael, Nov 22; for Quill): {"own": the listener's own, or -1
## with no gift reading of its own held or no Delusional on the script, "of": {reader id: chance}
## for each other person whose reading it holds}. One CaseEval evaluation with its worlds kept
## (CaseEval.capture_worlds), summed by who holds the secret in each.
static func delusion(view: Dictionary, listener: Dictionary, held: Array) -> Dictionary:
	var out: Dictionary = {"own": -1.0, "of": {}}
	if not "delusional" in view.get("world_options", {}).get("modifiers", []):
		return out
	var self_id: String = str(listener.get("id", listener.get("knowledge", {}).get("self", "")))
	var readers: Dictionary = {}
	for c in view.get("cards", []):
		if str(c.get("kind", "")) != "report" or c.get("quoted", false) or not (str(c.get("id", "")) in held):
			continue
		var src: String = str(c.get("relay_source", "")) if str(c.get("relay_source", "")) == self_id else str(c.get("source", ""))
		var idx: int = Solver.person_index(view, src)
		if idx >= 0:
			readers[src] = idx
	if readers.is_empty():
		return out
	var q: Dictionary = Solver.empty_case()
	q.cards = held.duplicate()
	q.conclusion = {"type": "secret_mod", "mod": "delusional", "target": self_id if readers.has(self_id) else str(readers.keys()[0]), "at": view.get("alignment_epoch", "")}
	var was: bool = CaseEval.capture_worlds
	CaseEval.capture_worlds = true
	CaseEval.captured = []
	var ev: Dictionary = CaseEval.evaluate(view, q, listener)
	CaseEval.capture_worlds = was
	var cap: Array = CaseEval.captured
	CaseEval.captured = []
	if ev.get("impossible", false) or cap.is_empty():
		return out
	var post: PackedFloat64Array = cap[-1].worlds
	var universe: Array = Solver.universe(view)
	var total: float = 0.0
	var by: Dictionary = {}
	for i in range(mini(post.size(), universe.size())):
		var m: float = post[i]
		if m <= 0.0:
			continue
		total += m
		var w: Dictionary = universe[i]
		if str(w.get("modifier", "")) != "delusional":
			continue
		var h: int = int(w.get("holders", 0))
		for src in readers:
			if h & (1 << int(readers[src])) and int(w.get("marked", -1)) != int(readers[src]):
				by[src] = float(by.get(src, 0.0)) + m
	if total <= 0.0:
		return out
	for src in readers:
		var pv: float = float(by.get(src, 0.0)) / total
		if src == self_id:
			out.own = pv
		else:
			out.of[src] = pv
	return out

## The refresh's inputs, kept on the NPC (as metadata, outside its saved state) until asked.
static func stage(n, view: Dictionary, listener: Dictionary, held: Array) -> void:
	n.set_meta(META, {"view": view, "listener": listener, "held": held})

static func clear(n) -> void:
	if n.has_meta(META):
		n.remove_meta(META)

## The NPC's {"own", "of"} Delusion chances (delusion) from its last applied refresh, asked of
## the judge the first time: the lazy twin of workshop_state.own_delusion and delusion_of, for
## when WorkshopOwnership.delusion_exposed is off (it costs a judgement per refresh).
static func delusion_of_npc(n) -> Dictionary:
	if not n.has_meta(META):
		return {"own": -1.0, "of": {}}
	var staged: Dictionary = n.get_meta(META)
	if not staged.has("delusion"):
		staged["delusion"] = delusion(staged.view, staged.listener, staged.held)
	return staged.delusion.duplicate(true)

## The NPC's {night: doubt} from its last applied refresh, asked of the judge the first time.
static func of(n) -> Dictionary:
	if not n.has_meta(META):
		return {}
	var staged: Dictionary = n.get_meta(META)
	if not staged.has("result"):
		staged["result"] = posterior(staged.view, staged.listener, staged.held)
	return staged.result.duplicate()

const META = "own_gift_doubt"

## Whether some world could make the reading's content wrong (Solver.reading_holds_table has
## a world it fails in). One that holds in every world says nothing the judge can weigh.
static func checked(view: Dictionary, card: Dictionary) -> bool:
	for b in Solver.reading_holds_table(view, card):
		if b == 0:
			return true
	return false
