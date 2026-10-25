## Public event-time bookkeeping only. Never inspect referee roles or death causes.
extends RefCounted

static func from_events(events: Array) -> Dictionary:
	var result = {"executions": {}, "deaths": {}, "death_ticks": {}, "events": events.duplicate(true)}
	for event in events:
		var day: int = event.get("at", {}).get("day", -1)
		if day < 0:
			continue
		if event.kind == "execution":
			result.executions[str(day)] = event.subjects.duplicate()
		for person in event.get("subjects", []):
			if event.kind in ["execution", "demon_death"] or (event.kind == "martyr" and person == event.get("by", "")):
				# A Demon victim was alive for that night's readings and movement.
				var before_night: int = day + 1 if event.kind == "demon_death" else day
				result.deaths[person] = mini(result.deaths.get(person, before_night), before_night)
				var tick: int = day * 4 + (3 if event.kind == "demon_death" else 2)
				result.death_ticks[person] = mini(result.death_ticks.get(person, tick), tick)
	return result

static func alive_at_night(view: Dictionary, person: String, night: int) -> bool:
	return night < view.get("timeline", {}).get("deaths", {}).get(person, 2147483647)

static func executed(view: Dictionary, person: String, night: int) -> bool:
	return person in view.get("timeline", {}).get("executions", {}).get(str(night), [])

static func observer_alive(view: Dictionary, person: String, stamp: Dictionary) -> bool:
	var tick: int = int(stamp.get("day", -1)) * 4 + {"morning": 0, "afternoon": 1, "evening": 2, "night": 3}.get(stamp.get("phase"), 3)
	return tick <= view.get("timeline", {}).get("death_ticks", {}).get(person, 2147483647)

## One publicly activated Revenant curse. Eligibility is public voting/alive history,
## never the referee's chosen victim or the current (possibly later) alive roster.
static func chronology(events: Array, people: Array, now: Dictionary) -> Dictionary:
	var curses: Array = events.filter(func(e): return e.kind == "curse")
	if curses.is_empty():
		return {"value": {}, "issues": []}
	var unique = {}
	for event in curses:
		unique[str([event.at, event.get("by", ""), event.subjects])] = event
	if unique.size() != 1:
		return {"value": {}, "issues": ["Multiple curse boundaries need a separate history adapter."]}
	var event: Dictionary = unique.values()[0]
	var executed: String = event.get("by", "")
	var time = preload("res://workshop/chronology.gd")
	var start: int = time.tick(event.at)
	var ids: Array = people.map(func(p): return p.id)
	var votes: Array = events.filter(func(e): return e.kind == "vote" and e.at.day == event.at.day and e.get("data", {}).get("nominee") == executed and e.data.get("outcome") == "on_block")
	if executed not in ids or event.at.day < 1 or event.at.phase != "evening" or votes.is_empty() or not events.any(func(e): return e.kind == "execution" and e.at.day == event.at.day and executed in e.subjects):
		return {"value": {}, "issues": ["Curse history needs its public execution, dated activation and successful execution vote."]}
	var timeline = from_events(events)
	var alive: Array = ids.filter(func(id): return timeline.death_ticks.get(id, 2147483647) > start)
	var yes: Array = votes[-1].data.get("yes", []).filter(func(id): return id in alive and id != executed)
	if yes.is_empty():
		return {"value": {}, "issues": ["The public curse vote has no eligible living turnee."]}
	var finish = 2147483647
	for lifted in events.filter(func(e): return e.kind == "curse_lifted"):
		if lifted.at.get("phase", "unknown") == "unknown":
			return {"value": {}, "issues": ["Curse restoration needs its public observation time."]}
		if time.tick(lifted.at) >= start:
			finish = mini(finish, time.tick(lifted.at))
	var epochs = {"Original alignment": 0, "Current alignment": time.tick(now), "before curse": start - 1, "during curse": start}
	if finish < 2147483647:
		epochs["after restoration"] = finish
	return {"value": {"epochs": epochs, "curse": {"executed": executed, "yes_voters": yes, "alive": alive, "from": start, "until": finish}}, "issues": []}
