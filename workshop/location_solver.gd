## The location solver (docs/demon_types_plan.md, "Whereabouts"): cross-references people and
## day phases for one question and sorts everyone into fits / unknown / ruled out, the way the
## trace solver sorts people against traces. It reads only what the viewer holds (`view`): the
## Demonologist's watches and day logs, sightings on cards, public work hours and known haunts.
## Unknown stays unknown: nothing is backfilled beyond the schedule model's odds
## (workshop/day_presence.gd), which is the same model the town reasons with.
##
## Questions:
##   {"kind": "kill", "day": N, "victim": id}     who was at the victim's regular places on day N
##                                                 (a day-walking demon hexes one of them)
##   {"kind": "silence", "day": N, "victim": id}  who was out on the victim's block with them on day N
##   {"kind": "place", "day": N, "loc": L}         who was at L on day N
##
## A Whereabouts node cites the day's log (one card) plus any NPC-reported sightings that day
## that bear on the answer, so a listener hears the watch roster in one piece.
extends RefCounted

const C = preload("res://sim/content.gd")
const DayPresence = preload("res://workshop/day_presence.gd")

const PHASES: Array = ["morning", "afternoon", "evening"]
const CERTAIN: float = 0.999


## The questions the viewer's record supports: each demon death and silencing, newest first.
static func questions(view: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for e in view.get("timeline", {}).get("events", []):
		var kind: String = str(e.get("kind", ""))
		var d: int = int(e.get("at", {}).get("day", -1))
		if d < 1 or kind not in ["demon_death", "silenced"]:
			continue
		for v in e.get("subjects", []):
			var q: Dictionary = {"kind": "kill" if kind == "demon_death" else "silence", "day": d, "victim": str(v)}
			var k: String = key(q)
			if not seen.has(k):
				seen[k] = true
				out.append(q)
	out.sort_custom(func(a, b): return a.day > b.day if a.day != b.day else key(a) < key(b))
	return out


static func key(q: Dictionary) -> String:
	return "%s:%d:%s" % [str(q.get("kind", "")), int(q.get("day", -1)), str(q.get("victim", q.get("loc", "")))]


static func label(view: Dictionary, q: Dictionary) -> String:
	var vname: String = _name(view, str(q.get("victim", "")))
	match str(q.get("kind", "")):
		"kill":
			return "Night %d: %s's death (who was at their places on day %d)" % [int(q.day), vname, int(q.day)]
		"silence":
			return "Day %d: %s silenced (who was out near them)" % [int(q.day), vname]
		"place":
			return "Day %d: who was at %s" % [int(q.day), _loc_name(str(q.get("loc", "")))]
	return "?"


## The places a question is about: the kill victim's workplace and known haunts, or one place.
static func places(view: Dictionary, q: Dictionary, cards: Array = []) -> Dictionary:
	var all_cards: Array = cards if not cards.is_empty() else view.get("cards", [])
	if str(q.get("kind", "")) == "place":
		return {"locs": [str(q.get("loc", ""))], "unknown_haunts": 0}
	if str(q.get("kind", "")) != "kill":
		return {"locs": [], "unknown_haunts": 0}
	var v: String = str(q.get("victim", ""))
	var locs: Array = []
	for p in view.get("people", []):
		if p.id == v and str(p.get("work", "")) in DayPresence.PLACES:
			locs.append(str(p.work))
	var haunts: Array = []
	for c in all_cards:
		if c.get("kind", "") == "context" and c.get("context_kind", "") == "haunt" and str(c.get("subject", "")) == v:
			for l in c.get("data", {}).get("locs", []):
				if l in DayPresence.PLACES and l not in haunts:
					haunts.append(str(l))
	for l in view.get("regular_haunts", {}).get(v, []):
		if l in DayPresence.PLACES and l not in haunts:
			haunts.append(str(l))
	for l in haunts:
		if l not in locs:
			locs.append(l)
	return {"locs": locs, "unknown_haunts": maxi(0, 2 - haunts.size())}


## The answer: one row per person (the victim left out), each with a cell per day phase and a
## verdict, plus the receipts a Whereabouts node cites.
static func evaluate(view: Dictionary, q: Dictionary, cards: Array = []) -> Dictionary:
	var all_cards: Array = cards if not cards.is_empty() else view.get("cards", [])
	var day: int = int(q.get("day", -1))
	var kind: String = str(q.get("kind", ""))
	var victim: String = str(q.get("victim", ""))
	var pl: Dictionary = places(view, q, all_cards)
	var table: Dictionary = DayPresence.build(view, all_cards)
	var prior: Dictionary = DayPresence.build_prior(view, all_cards) if kind == "silence" else {}
	# Death ticks (day * 4 + phase): a Demon victim of the night before the day is gone by
	# its morning, while someone hanged that day was still about until the meeting.
	var death_ticks: Dictionary = view.get("timeline", {}).get("death_ticks", {})
	var phase_watch: Dictionary = {}
	for wt in DayPresence.watches(view, all_cards):
		if int(wt.get("day", -1)) == day:
			phase_watch[str(wt.get("phase", ""))] = wt
	var rows: Array = []
	var groups: Dictionary = {"fits": [], "unknown": [], "ruled_out": []}
	var report_ids: Array = []
	for p in view.get("people", []):
		var pid: String = str(p.id)
		if pid == victim:
			continue
		if death_ticks.has(pid) and int(death_ticks[pid]) < day * 4:
			continue  # dead before the day in question
		var cells: Array = []
		var best: float = 0.0
		var miss: float = 1.0
		var best_cell: int = -1
		for ph in range(3):
			var cell: Dictionary = _cell(view, all_cards, phase_watch, p, day, ph)
			var prob: float = 0.0
			if kind == "silence":
				# A hunting Breathstealer (Nov 14): free, it could have reached the victim; on
				# shift or seen elsewhere, it couldn't (DayPresence.hunt_block).
				prob = DayPresence.hunt_block(table, pid, victim, day, ph, prior)
			else:
				for l in pl.locs:
					prob += DayPresence.at(table, pid, day, ph, l)
			prob = clampf(prob, 0.0, 1.0)
			cell["p"] = prob
			cells.append(cell)
			miss *= 1.0 - prob
			if prob > best:
				best = prob
				best_cell = ph
			if cell.get("report_id", "") != "" and prob > 0.0 and cell.report_id not in report_ids:
				report_ids.append(cell.report_id)
		var p_any: float = 1.0 - miss
		var verdict: String = "unknown"
		var reason: String = ""
		if best >= CERTAIN:
			verdict = "fits"
			reason = "%s: %s" % [PHASES[best_cell].capitalize(), cells[best_cell].text]
		elif best_cell >= 0 and cells[best_cell].state == "reported" and best >= 0.5 and _report_near(table, cells[best_cell], kind, victim, day, best_cell):
			verdict = "fits"
			reason = "%s: %s" % [PHASES[best_cell].capitalize(), cells[best_cell].text]
		elif p_any <= 1e-9:
			verdict = "ruled_out"
			reason = "accounted for elsewhere all day"
		else:
			reason = "could have been there (%d%%)" % int(round(p_any * 100.0))
		groups[verdict].append(pid)
		rows.append({"id": pid, "name": str(p.get("name", pid)), "alive": bool(p.get("alive", true)),
			"cells": cells, "p": p_any, "verdict": verdict, "reason": reason})
	var order: Dictionary = {"fits": 0, "unknown": 1, "ruled_out": 2}
	rows.sort_custom(func(a, b):
		if a.verdict != b.verdict:
			return order[a.verdict] < order[b.verdict]
		if not is_equal_approx(a.p, b.p):
			return a.p > b.p
		return a.name < b.name)
	var log_ids: Array = []
	var log: Dictionary = day_log(all_cards, day)
	if not log.is_empty():
		log_ids.append(str(log.id))
	report_ids.sort()
	return {"question": q.duplicate(true), "label": label(view, q), "day": day, "places": pl.locs,
		"unknown_haunts": int(pl.unknown_haunts), "watched_phases": phase_watch.keys(),
		"rows": rows, "fits": groups.fits, "unknown": groups.unknown, "ruled_out": groups.ruled_out,
		"log_ids": log_ids, "report_ids": report_ids}


## For a silencing, a reported sighting only makes someone fit when it puts them on a block
## the victim could have been on that phase: the hunting reach alone mustn't (Codex on #157).
static func _report_near(table: Dictionary, cell: Dictionary, kind: String, victim: String, day: int, ph: int) -> bool:
	if kind != "silence":
		return true
	var blk: String = str(cell.get("block", ""))
	var l: String = str(cell.get("loc", ""))
	if blk == "" and C.LOCATIONS.has(l):
		blk = str(C.LOCATIONS[l].block)
	return blk != "" and DayPresence.on_block(table, victim, day, ph, blk) > 0.0


## The day's latest log among the cards (the one holding the most watches).
static func day_log(cards: Array, day: int) -> Dictionary:
	var best: Dictionary = {}
	for c in cards:
		if c.get("kind", "") != "watch_log" or int(c.get("data", {}).get("day", -1)) != day:
			continue
		if best.is_empty() or c.data.get("watches", []).size() > best.data.get("watches", []).size():
			best = c
	return best


## What's known of one person in one phase, strongest first: seen by the Demonologist (a watch
## roster or their own sighting), reported by someone, at work by the public schedule, or free.
static func _cell(view: Dictionary, cards: Array, phase_watch: Dictionary, person: Dictionary, day: int, ph: int) -> Dictionary:
	var pid: String = str(person.id)
	var pname: String = PHASES[ph]
	if phase_watch.has(pname):
		var wt: Dictionary = phase_watch[pname]
		for l in wt.get("at", {}):
			if pid in wt.at[l]:
				return {"state": "seen", "loc": str(l), "text": "seen at " + _loc_name(str(l))}
	for c in cards:
		if c.get("kind", "") not in ["location", "evening"] or c.get("source", "") != "player" or c.get("quoted", false):
			continue
		if int(c.get("day", -1)) == day and DayPresence.phase_index(c.get("observed_at", {}).get("phase", "")) == ph and pid in c.get("subjects", [c.get("subject", "")]):
			var l: String = str(c.get("loc", ""))
			if l.begins_with("home"):
				return {"state": "seen", "loc": "home", "text": "seen at home"}
			if l != "":
				return {"state": "seen", "loc": l, "text": "seen at " + _loc_name(l)}
	for c in cards:
		if c.get("kind", "") not in ["location", "evening"] or c.get("source", "") in ["player", ""] or c.get("quoted", false):
			continue
		if int(c.get("day", -1)) == day and DayPresence.phase_index(c.get("observed_at", {}).get("phase", "")) == ph and pid in c.get("subjects", [c.get("subject", "")]):
			var l2: String = str(c.get("loc", ""))
			var where: String = _loc_name(l2) if l2 != "" else C.block_name(str(c.get("block", "")))
			return {"state": "reported", "loc": l2, "block": str(c.get("block", "")), "source": str(c.source), "report_id": str(c.get("id", "")),
				"text": "%s says at %s" % [_name(view, str(c.source)), where]}
	if phase_watch.has(pname):
		var blk: String = str(phase_watch[pname].get("block", ""))
		var work_w: String = str(person.get("work", ""))
		if _works(person, ph) and C.LOCATIONS.has(work_w) and C.LOCATIONS[work_w].block != blk:
			return {"state": "work", "loc": work_w, "text": "at work at " + _loc_name(work_w) + ", not on " + C.block_name(blk)}
		return {"state": "absent", "block": blk, "text": "not on " + C.block_name(blk)}
	var work: String = str(person.get("work", ""))
	if _works(person, ph) and C.LOCATIONS.has(work):
		return {"state": "work", "loc": work, "text": "at work at " + _loc_name(work)}
	return {"state": "free", "text": "free time"}


static func _works(person: Dictionary, ph: int) -> bool:
	for x in person.get("work_phases", []):
		if (x is int or x is float) and int(x) == ph:
			return true
		if x is String and x.to_lower() == PHASES[ph]:
			return true
	return false


static func _name(view: Dictionary, pid: String) -> String:
	for p in view.get("people", []):
		if p.id == pid:
			return str(p.get("name", pid))
	return pid


static func _loc_name(l: String) -> String:
	return str(C.LOCATIONS.get(l, {}).get("name", l))
