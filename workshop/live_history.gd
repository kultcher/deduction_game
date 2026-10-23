## Public event-time bookkeeping only. Never inspect referee roles or death causes.
extends RefCounted

static func from_events(events: Array) -> Dictionary:
	var result = {"executions": {}, "deaths": {}, "events": events.duplicate(true)}
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
	return result

static func alive_at_night(view: Dictionary, person: String, night: int) -> bool:
	return night < view.get("timeline", {}).get("deaths", {}).get(person, 2147483647)

static func executed(view: Dictionary, person: String, night: int) -> bool:
	return person in view.get("timeline", {}).get("executions", {}).get(str(night), [])
