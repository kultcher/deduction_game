## Pure combinatorics & pigeonhole trace-chain solver over player-known receipts.
## Never reads hidden NPC roles, alignments, or undiscovered haunts: inspects only
## `WorkshopCanvas.view(g)` (`view.people`, `view.cards`, `view.profile_facets`, `view.timeline`).
extends RefCounted

const C = preload("res://sim/content.gd")
const Solver = preload("res://workshop/solver.gd")


## Build the N-column by (1 or 2)-row murder-night trace matrix and Scion execution dividers.
static func build_matrix(view: Dictionary) -> Dictionary:
	var by_night: Dictionary = {}
	for card in view.get("cards", []):
		if card.get("kind", "") != "trace" or card.get("quoted", false):
			continue
		var d: Dictionary = card.get("data", {})
		if str(d.get("family", "")) != "locations":
			continue
		var night: int = int(card.get("night", card.get("observed_at", {}).get("day", -1)))
		if night < 1:
			continue
		var locs: Array = d.get("locs", []).duplicate()
		if locs.is_empty():
			continue
		if not by_night.has(night):
			by_night[night] = []
		var loc_names: Array = locs.map(func(l): return C.LOCATIONS.get(l, {}).get("name", str(l)))
		var short_names: Array = locs.map(func(l): return _short_loc_name(str(l)))
		by_night[night].append({
			"id": str(card.id),
			"night": night,
			"slot": int(d.get("slot", by_night[night].size())),
			"scene": str(d.get("scene", "")),
			"scene_block": str(d.get("scene_block", card.get("block", ""))),
			"victim_id": str(d.get("victim", "")),
			"victim_name": Solver.person_name(view, str(d.get("victim", ""))) if str(d.get("victim", "")) != "" else "",
			"subtype": str(d.get("subtype", "scent" if locs.size() >= 3 else "token")),
			"item_label": str(d.get("item_label", "")),
			"locs": locs,
			"loc_names": loc_names,
			"short_locs": short_names,
			"scene_trace_count": maxi(1, int(d.get("scene_trace_count", 1))),
			"text": str(card.get("text", "")),
		})
	var nights: Array = by_night.keys()
	nights.sort()
	var columns: Array = []
	var max_rows: int = 1
	for night in nights:
		var rows: Array = by_night[night]
		rows.sort_custom(func(a, b): return int(a.slot) < int(b.slot) if int(a.slot) != int(b.slot) else str(a.id) < str(b.id))
		if rows.size() > 1:
			max_rows = 2
		var first: Dictionary = rows[0]
		columns.append({
			"night": int(night),
			"scene": first.scene,
			"scene_block": first.scene_block,
			"victim_id": first.victim_id,
			"victim_name": first.victim_name,
			"rows": rows.slice(0, 2),
		})
	var scion_dividers: Array = _compute_scion_dividers(view, nights)
	return {
		"columns": columns,
		"nights": nights,
		"max_rows": max_rows,
		"scion_dividers": scion_dividers,
	}


static func _short_loc_name(loc_id: String) -> String:
	var titles = {
		"bakery": "Bakery",
		"chapel": "Chapel",
		"graveyard": "Graveyard",
		"mill": "Mill",
		"smithy": "Smithy",
		"tavern": "Tavern",
		"well": "Well",
		"wharf": "Wharf",
	}
	return titles.get(loc_id, C.LOCATIONS.get(loc_id, {}).get("name", loc_id.capitalize()))


## Detect public executions where >= 5 townsfolk were alive beforehand (so a Scion could
## promote before that evening's Night `exec_day` kill).
static func _compute_scion_dividers(view: Dictionary, nights: Array) -> Array:
	var events: Array = view.get("timeline", {}).get("events", [])
	if events.is_empty():
		return []
	# In World._scion_rises, `alive_before` counts living NPCs right before execution (`>= 5`).
	var npc_total: int = view.get("people", []).size()
	var dead_ids: Dictionary = {}
	var potential_handoffs: Array = []
	for ev in events:
		var kind: String = str(ev.get("kind", ""))
		var ev_day: int = int(ev.get("at", {}).get("day", -1))
		if kind == "execution" and ev_day >= 1:
			var alive_before: int = npc_total - dead_ids.size()
			var subjs: Array = ev.get("subjects", [])
			var who: String = str(subjs[0]) if not subjs.is_empty() else ""
			if alive_before >= 5 and who != "":
				potential_handoffs.append({
					"exec_day": ev_day,
					"executed_id": who,
					"executed_name": Solver.person_name(view, who),
					"alive_before": alive_before,
				})
			for s in subjs:
				dead_ids[str(s)] = true
		elif kind in ["demon_death", "martyr"]:
			if kind == "martyr":
				var by_id: String = str(ev.get("by", ""))
				if by_id != "":
					dead_ids[by_id] = true
			else:
				for s2 in ev.get("subjects", []):
					dead_ids[str(s2)] = true
	var dividers: Array = []
	for i in range(nights.size() - 1):
		var n_left: int = int(nights[i])
		var n_right: int = int(nights[i + 1])
		for h in potential_handoffs:
			# Execution on Day D Evening falls between Night (D - 1) and Night D (`n_left < D <= n_right`).
			if n_left < int(h.exec_day) and int(h.exec_day) <= n_right:
				dividers.append({
					"after_night": n_left,
					"before_night": n_right,
					"exec_day": int(h.exec_day),
					"executed_id": h.executed_id,
					"executed_name": h.executed_name,
				})
	return dividers


## Extract discovered work + haunt locations for every townsperson strictly from `view.cards`.
static func discovered_profiles(view: Dictionary) -> Dictionary:
	var profiles: Dictionary = {}
	for p in view.get("people", []):
		var pid: String = str(p.get("id", ""))
		profiles[pid] = {
			"id": pid,
			"name": str(p.get("name", pid)),
			"alive": bool(p.get("alive", true)),
			"work_loc": "",
			"known_haunts": [],
			"known_locs": [],
			"known_count": 0,
			"unknown_slots": 3,
			"full_profile": false,
		}
	for c in view.get("cards", []):
		if c.get("quoted", false) or c.get("kind", "") != "context":
			continue
		var pid: String = str(c.get("subject", ""))
		if not profiles.has(pid):
			continue
		var entry: Dictionary = profiles[pid]
		var ctx: String = str(c.get("context_kind", ""))
		if ctx == "work":
			var wloc: String = str(c.get("data", {}).get("loc", ""))
			if wloc != "":
				entry.work_loc = wloc
		elif ctx == "haunt":
			for hl in c.get("data", {}).get("locs", [c.get("data", {}).get("loc", "")]):
				var hstr: String = str(hl)
				if hstr != "" and hstr not in entry.known_haunts and entry.known_haunts.size() < 2:
					entry.known_haunts.append(hstr)
	for pid in profiles:
		var entry: Dictionary = profiles[pid]
		var klocs: Array = []
		if entry.work_loc != "":
			klocs.append(entry.work_loc)
		for hl in entry.known_haunts:
			if hl not in klocs:
				klocs.append(hl)
		var kcount: int = (1 if entry.work_loc != "" else 0) + mini(entry.known_haunts.size(), 2)
		entry.known_locs = klocs
		entry.known_count = kcount
		entry.unknown_slots = maxi(0, 3 - kcount)
		entry.full_profile = (kcount >= 3)
	return profiles


static func _death_records(view: Dictionary) -> Dictionary:
	var murdered: Dictionary = {}
	var executed: Dictionary = {}
	for ev in view.get("timeline", {}).get("events", []):
		var kind: String = str(ev.get("kind", ""))
		var d: int = int(ev.get("at", {}).get("day", -1))
		if kind == "demon_death":
			for s in ev.get("subjects", []):
				murdered[str(s)] = d
		elif kind == "martyr":
			var by_who: String = str(ev.get("by", ""))
			if by_who != "":
				murdered[by_who] = d
		elif kind == "execution":
			for s2 in ev.get("subjects", []):
				executed[str(s2)] = d
	return {"murdered": murdered, "executed": executed}


## Exact hitting-set check: given `unknown_slots` in {0, 1, 2} and a list of unmet trace
## location sets, determine whether a subset of size <= `unknown_slots` outside `known_locs`
## can intersect every unmet trace, and return candidate bridge locations.
static func _hitting_set_check(known_locs: Array, unknown_slots: int, unmet_traces: Array) -> Dictionary:
	if unmet_traces.is_empty():
		return {"possible": true, "bridge_locs": []}
	if unknown_slots <= 0:
		return {"possible": false, "bridge_locs": []}
	var pool: Array = []
	for loc_id in C.LOCATIONS.keys():
		if loc_id not in known_locs:
			pool.append(loc_id)
	# First check if a single unknown haunt can satisfy all unmet traces at once.
	var single_hits: Array = []
	for cand in pool:
		if unmet_traces.all(func(tr): return cand in tr.locs):
			single_hits.append(cand)
	if not single_hits.is_empty():
		return {"possible": true, "bridge_locs": single_hits}
	if unknown_slots == 1:
		return {"possible": false, "bridge_locs": []}
	# unknown_slots >= 2: check whether any pair (cand_a, cand_b) covers all unmet traces.
	var pair_locs: Dictionary = {}
	for i in range(pool.size()):
		for j in range(i + 1, pool.size()):
			var a: String = pool[i]
			var b: String = pool[j]
			if unmet_traces.all(func(tr): return (a in tr.locs) or (b in tr.locs)):
				pair_locs[a] = true
				pair_locs[b] = true
	var bridges: Array = pair_locs.keys()
	bridges.sort()
	return {"possible": not bridges.is_empty(), "bridge_locs": bridges}


## Normalize `selected_by_night` ({night_or_str: card_id}) against `matrix` so stale/missing IDs drop out.
static func normalize_selection(matrix: Dictionary, selected_by_night: Dictionary) -> Dictionary:
	var clean: Dictionary = {}
	for col in matrix.get("columns", []):
		var n_int: int = int(col.night)
		var picked: String = ""
		if selected_by_night.has(n_int):
			picked = str(selected_by_night[n_int])
		elif selected_by_night.has(str(n_int)):
			picked = str(selected_by_night[str(n_int)])
		if picked != "" and col.rows.any(func(r): return str(r.id) == picked):
			clean[n_int] = picked
	return clean


## Evaluate all townsfolk against `selected_by_night`, returning structured portrait states & counts.
static func evaluate_selection(view: Dictionary, selected_by_night: Dictionary) -> Dictionary:
	var matrix: Dictionary = build_matrix(view)
	var clean_sel: Dictionary = normalize_selection(matrix, selected_by_night)
	var selected_traces: Array = []
	for col in matrix.columns:
		var n_int: int = int(col.night)
		if clean_sel.has(n_int):
			for r in col.rows:
				if str(r.id) == clean_sel[n_int]:
					selected_traces.append(r)
					break

	var profiles: Dictionary = discovered_profiles(view)
	var deaths: Dictionary = _death_records(view)
	var murdered_map: Dictionary = deaths.murdered
	var executed_map: Dictionary = deaths.executed

	var suspects: Array = []
	var executed_entries: Array = []
	var excluded_victims: Array = []
	var matches_ids: Array = []
	var unknown_ids: Array = []
	var contradicts_ids: Array = []

	for p in view.get("people", []):
		var pid: String = str(p.get("id", ""))
		var prof: Dictionary = profiles[pid]
		if murdered_map.has(pid):
			excluded_victims.append({
				"id": pid,
				"name": prof.name,
				"death_night": int(murdered_map[pid]),
			})
			continue

		var is_executed: bool = executed_map.has(pid)
		var exec_day: int = int(executed_map.get(pid, -1))
		var fit: String = "idle"
		var reason: String = ""
		var per_night: Array = []
		var bridge_locs: Array = []

		if not selected_traces.is_empty():
			# An executed person was dead on `night >= exec_day`, so they cannot be the single killer of post-hanging nights.
			var post_exec_selected: bool = is_executed and selected_traces.any(func(tr): return int(tr.night) >= exec_day)
			if post_exec_selected:
				fit = "contradicts"
				reason = "Cannot fit all selected nights as one killer: executed on Day %d before a selected later murder night." % exec_day
			else:
				var unmet: Array = []
				for tr in selected_traces:
					var hit_locs: Array = prof.known_locs.filter(func(l): return l in tr.locs)
					if not hit_locs.is_empty():
						var hit_names: Array = hit_locs.map(func(l): return _short_loc_name(str(l)))
						per_night.append("N%d: fits (%s)" % [int(tr.night), ", ".join(PackedStringArray(hit_names))])
					else:
						unmet.append(tr)
						per_night.append("N%d: no known match yet (%s)" % [int(tr.night), ", ".join(PackedStringArray(tr.short_locs))])
				if unmet.is_empty():
					fit = "matches"
					reason = "Known locations fit all %d selected night(s)." % selected_traces.size()
				else:
					var hs: Dictionary = _hitting_set_check(prof.known_locs, int(prof.unknown_slots), unmet)
					if hs.possible:
						fit = "unknown"
						bridge_locs = hs.bridge_locs
						var bnames: Array = bridge_locs.map(func(l): return _short_loc_name(str(l)))
						reason = "Could fit if an unknown haunt is %s." % "/".join(PackedStringArray(bnames.slice(0, 4)))
					else:
						fit = "contradicts"
						if prof.full_profile:
							reason = "Does not fit the selection: workplace and both haunts miss at least one selected trace."
						else:
							reason = "Does not fit the selection: %d remaining unknown haunt slot(s) cannot cover all missed traces at once." % int(prof.unknown_slots)

			if fit == "matches":
				matches_ids.append(pid)
			elif fit == "unknown":
				unknown_ids.append(pid)
			elif fit == "contradicts":
				contradicts_ids.append(pid)

		var entry = {
			"id": pid,
			"name": prof.name,
			"alive": prof.alive and not is_executed,
			"executed": is_executed,
			"exec_day": exec_day,
			"work_loc": prof.work_loc,
			"known_haunts": prof.known_haunts,
			"known_locs": prof.known_locs,
			"known_count": int(prof.known_count),
			"unknown_slots": int(prof.unknown_slots),
			"full_profile": bool(prof.full_profile),
			"grayscale": not bool(prof.full_profile),
			"fit": fit,
			"reason": reason,
			"per_night": per_night,
			"bridge_locs": bridge_locs,
		}
		if is_executed:
			executed_entries.append(entry)
		else:
			suspects.append(entry)

	return {
		"matrix": matrix,
		"selected_by_night": clean_sel,
		"selected_traces": selected_traces,
		"suspects": suspects,
		"executed": executed_entries,
		"all_entries": suspects + executed_entries,
		"excluded_victims": excluded_victims,
		"matches_ids": matches_ids,
		"unknown_ids": unknown_ids,
		"contradicts_ids": contradicts_ids,
	}


## Resolve all Workshop receipt IDs bundled by a committed `trace_chain` node:
## - `trace_ids`: the player's selected trace receipt ID per toggled night;
## - `sibling_trace_ids`: unselected sister trace(s) from 2-trace scenes on those nights (so joint walker subtraction works automatically when sightings are linked);
## - `death_ids`: public `death` context cards for those murder nights if on the board;
## - `receipt_ids`: all currently unlocked `home_work` + `haunts` profile receipts across the cast.
static func bundle_for_workshop(view: Dictionary, selected_by_night: Dictionary) -> Dictionary:
	var matrix: Dictionary = build_matrix(view)
	var clean_sel: Dictionary = normalize_selection(matrix, selected_by_night)
	var trace_ids: Array = []
	var sibling_ids: Array = []
	var nights: Array = []
	for col in matrix.columns:
		var n_int: int = int(col.night)
		if not clean_sel.has(n_int):
			continue
		nights.append(n_int)
		var picked_id: String = str(clean_sel[n_int])
		if picked_id not in trace_ids:
			trace_ids.append(picked_id)
		for r in col.rows:
			var rid: String = str(r.id)
			if rid != picked_id and rid not in sibling_ids:
				sibling_ids.append(rid)

	var death_ids: Array = []
	for c in view.get("cards", []):
		if c.get("kind", "") == "context" and c.get("context_kind", "") == "death":
			var dnight: int = int(c.get("night", c.get("observed_at", {}).get("day", -1)))
			if dnight in nights and str(c.id) not in death_ids:
				death_ids.append(str(c.id))

	var profile_receipt_ids: Array = []
	var pfacets: Dictionary = view.get("profile_facets", {})
	for pid in pfacets:
		for facet in ["home_work", "haunts"]:
			var fdata: Dictionary = pfacets[pid].get(facet, {})
			if fdata.get("unlocked", false):
				for prid in fdata.get("receipt_ids", []):
					if prid not in profile_receipt_ids:
						profile_receipt_ids.append(prid)
	if profile_receipt_ids.is_empty():
		for c in view.get("cards", []):
			if c.get("kind", "") == "context" and c.get("context_kind", "") in ["home", "work", "haunt"]:
				if str(c.id) not in profile_receipt_ids:
					profile_receipt_ids.append(str(c.id))

	var serialized_map: Dictionary = {}
	for n_int in nights:
		serialized_map[str(n_int)] = clean_sel[n_int]

	return {
		"selected_by_night": serialized_map,
		"nights": nights,
		"trace_ids": trace_ids,
		"sibling_trace_ids": sibling_ids,
		"death_ids": death_ids,
		"receipt_ids": profile_receipt_ids,
	}
