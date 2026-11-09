## Recency (premises pass, after step 3; docs/premises_plan.md "Recency as built"): attention
## drifts the way a real town's does. Nothing here changes how much a card weighs, only
## whether a bounded mind is looking at it.
##
## - The topic of the day: who the town nominated, accused, argued about or defended
##   lately, shared by everyone; it halves each day.
## - Card age: a card fades from a bounded mind's attention by days since they learned it
##   or last heard it brought up; lower Insight drifts faster.
## - Calling attention back: presenting or citing a card resets its age for that listener.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")

## The town's topic: person id -> 0..1, from public nominations and accusations, the
## player's meeting arguments and the latest defences. Each day's acts add up, the total is
## capped at 1, and what is left halves every following day: a busy day saturates a person
## for that day only, never for longer (Codex review on #96).
static func topic(w) -> Dictionary:
	var weights: Dictionary = Tuning.Workshop.RECENCY_TOPIC_EVENTS
	var by_day: Dictionary = {} # person -> {day -> summed weight}
	var add := func(person: String, weight: float, day: int) -> void:
		if person == "" or day > w.day or weight <= 0.0:
			return
		if not by_day.has(person):
			by_day[person] = {}
		by_day[person][day] = float(by_day[person].get(day, 0.0)) + weight
	for e in w.public_log:
		var kind: String = str(e.get("kind", ""))
		if weights.has(kind):
			for person in e.get("subjects", []):
				add.call(str(person), float(weights[kind]), int(e.get("day", w.day)))
	for entry in w.meeting_arguments:
		add.call(str(entry.get("target", "")), float(weights.get("argued", 0.0)), int(entry.get("day", w.day)))
	for supporter in w.defences:
		var d: Dictionary = w.defences[supporter]
		add.call(str(d.get("target", "")), float(weights.get("defence", 0.0)), int(d.get("day", w.day)))
	var out: Dictionary = {}
	var daily: float = Tuning.Workshop.RECENCY_TOPIC_DAILY
	for person in by_day:
		var days: Array = by_day[person].keys()
		days.sort()
		var value: float = 0.0
		var last: int = int(days[0])
		for day in days:
			value = minf(1.0, value * pow(daily, float(int(day) - last)) + float(by_day[person][day]))
			last = int(day)
		value *= pow(daily, float(w.day - last))
		if value >= 0.01:
			out[person] = value
	return out

## What attention needs from the listener: today, the town's topic and this listener's
## card refresh days.
static func snapshot(w, n) -> Dictionary:
	return {"today": w.day, "topic": topic(w), "card_refresh": n.workshop_state.get("card_refresh", {}).duplicate()}

## Presenting or citing cards to a listener brings them back to mind (their age resets).
static func refresh_cards(w, n, ids: Array) -> void:
	if not n.workshop_state.has("card_refresh"):
		n.workshop_state["card_refresh"] = {}
	for id in ids:
		n.workshop_state.card_refresh[str(id)] = w.day

## The recency part of a card's attention salience, from the listener's recency snapshot.
## Age: days since the later of learning it and its last refresh, times a daily fade that
## runs from RECENCY_DECAY_LOW (Insight 0) to RECENCY_DECAY_HIGH (Insight 1), capped. Topic:
## the strongest topic weight among the people the card names or comes from.
static func salience(card: Dictionary, people: Array, recency: Dictionary, insight: float) -> float:
	if recency.is_empty():
		return 0.0
	var today: int = int(recency.get("today", 0))
	var learned: int = _day(card.get("learned_at", null), _day(card.get("observed_at", null), today))
	var refreshed: int = int(recency.get("card_refresh", {}).get(str(card.get("id", "")), -1))
	var age: int = maxi(0, today - maxi(learned, refreshed))
	var fade: float = lerpf(Tuning.Workshop.RECENCY_DECAY_LOW, Tuning.Workshop.RECENCY_DECAY_HIGH, clampf(insight, 0.0, 1.0))
	var score: float = -minf(Tuning.Workshop.RECENCY_AGE_CAP, float(age) * fade)
	var topic: Dictionary = recency.get("topic", {})
	var strongest: float = 0.0
	for person in people + [str(card.get("source", ""))]:
		strongest = maxf(strongest, float(topic.get(str(person), 0.0)))
	return score + Tuning.Workshop.RECENCY_TOPIC_WEIGHT * strongest

static func _day(at, fallback: int) -> int:
	if at is Dictionary and str(at.get("day", "?")).is_valid_int():
		return int(at.day)
	return fallback
