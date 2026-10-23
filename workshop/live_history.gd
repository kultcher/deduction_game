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
