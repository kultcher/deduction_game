## Does a reading confirm what the listener knows or strongly believes? (Michael, Nov 19:
## "Trust from readings that confirm what I know or strongly believe"; Lantern owns this test,
## Beadle the trust it earns.) A cutoff and tiers, not a scale:
##   "known"     the reading holds in every world the listener's own knowledge allows (its
##               own readings, role and alignment): a hard fact. Source "fact".
##   "moderate"  the listener's own chance the reading is right is at least
##               Tuning.Trust.READING_CONFIRM_MODERATE. Source "belief".
##   "small"     at least READING_CONFIRM_SMALL. Source "belief".
##   "none"      below that, or a reading this can't read (not a tabled report).
## "Right" is the better of two readings of the reading, both read from the listener's view:
## - its content holds (CaseEval's "holds" question: a Seer's "yes" is right if the Demon is
##   in the pair, a Gravedigger's role if that's who it was);
## - what it says about alignment holds: everyone it points toward evil is evil, and
##   everyone it speaks for is good (Gifts.implicated and clears, for a reading naming one
##   person toward evil). So "Edda was the Poisoner" confirms a listener who strongly
##   believes Edda is evil (Michael's example), though "the Poisoner exactly" is less sure.
## The belief side reads the listener's own chances that each person is evil (`chances`: its
## last connections refresh, the belief it acts on) for what the reading says about alignment,
## and asks its content with no cards, so the worlds are weighed by its standing view alone
## (CaseEval's team prior, which follows its suspicions only loosely: a suspicion of 0.97 weighs
## a world about as a chance of 0.7 would, so the alignment side reads the chances instead).
## The fact side asks with only its own readings, at a neutral prior, so a world is ruled out
## only by what it knows: its own readings are the prepared listener's personally received
## ones (Shared.prepare moves them into the union and keeps their ids as attention_reports).
## A reading whose content no world can fail (a count the table doesn't check, such as a
## Lamplighter's, or one true however the town is dealt) says nothing a liar couldn't, so its
## content confirms nothing; only what it says about alignment can.
## Call it before the reading is applied. Reads only; changes nothing.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const Gifts = preload("res://sim/gifts.gd")

## The chance this close to 1 counts as certain.
const CERTAIN = 1e-9

## {"tier", "agreement" (the listener's chance the reading is right, 0..1), "source" ("fact",
## "belief" or "")}. `view` and `listener`: a prepared evaluation's (Shared.prepare), with
## the reading among the view's cards.
## `chances`: {person id: the listener's chance they're evil}, from its last refresh
## (proposal.connections.posterior). Without it the alignment side asks CaseEval too.
static func assess(view: Dictionary, card: Dictionary, listener: Dictionary, chances: Dictionary = {}) -> Dictionary:
	var none: Dictionary = {"tier": "none", "agreement": 0.0, "source": ""}
	if card.is_empty() or str(card.get("kind", "")) != "report" or not Solver.tabled(card):
		return none
	if not view.get("cards", []).any(func(c): return str(c.get("id", "")) == str(card.get("id", ""))):
		return none
	var self_id: String = str(listener.get("id", listener.get("knowledge", {}).get("self", "")))
	if str(card.get("source", "")) == self_id:
		return none  # its own reading confirms nothing about its teller
	# The fact side: its own readings only, at a neutral prior.
	var knowledge: Dictionary = listener.get("knowledge", {})
	var own: Array = []
	for id in knowledge.get("own_reports", []) + knowledge.get("attention_reports", []):
		if str(id) != str(card.id) and not (str(id) in own) and view.cards.any(func(c): return str(c.get("id", "")) == str(id)):
			own.append(str(id))
	var heard: Dictionary = listener.duplicate(true)
	heard["knowledge"] = knowledge.duplicate(true)
	heard.knowledge["own_reports"] = own.duplicate()  # CaseEval weighs these on both sides
	var neutral: Dictionary = heard.duplicate(true)
	neutral["suspicion"] = {}
	var known: float = _right(view, card, neutral, own, {})
	if known >= 1.0 - CERTAIN:
		return {"tier": "known", "agreement": 1.0, "source": "fact"}
	# The belief side: no cards, the listener's own standing view.
	var agree: float = _right(view, card, heard, [], chances)
	var tier: String = "moderate" if agree >= Tuning.Trust.READING_CONFIRM_MODERATE else ("small" if agree >= Tuning.Trust.READING_CONFIRM_SMALL else "none")
	return {"tier": tier, "agreement": agree, "source": "belief" if tier != "none" else ""}

## The listener's chance the reading is right (the better of its content and its alignment),
## from `cards` and the listener's prior.
static func _right(view: Dictionary, card: Dictionary, listener: Dictionary, cards: Array, chances: Dictionary) -> float:
	var epoch = view.get("alignment_epoch", "")
	var holds: float = 0.0
	if _checked(view, card):
		var question: Dictionary = Solver.empty_case()
		question.cards = cards.duplicate()
		question.conclusion = {"type": "holds", "report": str(card.id), "target": str(card.get("source", "")), "at": epoch}
		var ev: Dictionary = CaseEval.evaluate(view, question, listener)
		if ev.get("impossible", false):
			return 0.0
		holds = clampf(float(ev.get("posterior", 0.0)), 0.0, 1.0)
	var entry: Dictionary = {"role": str(card.get("role", "")), "data": card.get("data", {})}
	var accused: Array = Gifts.implicated(entry)
	var cleared: Array = Gifts.clears(entry)
	if accused.size() > 1 or (accused.is_empty() and cleared.is_empty()):
		return holds  # a group pointed at (one of them, or a count): its content says it
	# Alignment: everyone named toward evil evil and everyone spoken for good, jointly.
	var self_id: String = str(listener.get("id", listener.get("knowledge", {}).get("self", "")))
	if not chances.is_empty():
		var j: float = 1.0
		for p in accused:
			j *= 0.0 if str(p) == self_id else clampf(float(chances.get(str(p), 0.0)), 0.0, 1.0)
		for p in cleared:
			j *= 1.0 if str(p) == self_id else clampf(1.0 - float(chances.get(str(p), 1.0)), 0.0, 1.0)
		return maxf(holds, j)
	var align: Dictionary = Solver.empty_case()
	align.cards = cards.duplicate()
	var parts: Array = []
	for p in accused:
		parts.append({"type": "evil", "target": str(p), "at": epoch})
	for p in cleared:
		parts.append({"type": "good", "target": str(p), "at": epoch})
	var joint: float = 1.0
	for part in parts:
		# One question each, multiplied: an approximation of the joint chance (CaseEval asks
		# about one person at a time). Exact for a reading that names one person, the case
		# Michael's example is about.
		align.conclusion = part
		var e: Dictionary = CaseEval.evaluate(view, align, listener)
		if e.get("impossible", false):
			return holds
		joint *= clampf(float(e.get("posterior", 0.0)), 0.0, 1.0)
	return maxf(holds, joint)

## Whether some world could make the reading's content wrong. One that holds in every world
## (unchecked, or true however the town is dealt) can't confirm anything by its content.
static func _checked(view: Dictionary, card: Dictionary) -> bool:
	var mask: PackedByteArray = Solver.reading_holds_table(view, card)
	for b in mask:
		if b == 0:
			return true
	return false
