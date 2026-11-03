## Board helpers for `tools/autoplay.gd` (case building itself is tools/analyst.gd).
## Uses ONLY player-visible board and profile receipts (`WorkshopCanvas.view(g)`), never hidden truth.
extends RefCounted

const Gifts = preload("res://sim/gifts.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const Circumstantial = preload("res://workshop/circumstantial.gd")

static func unprobed_trace_for(g, npc_id: String, probed_traces: Dictionary) -> int:
	for i in range(g.board.size() - 1, -1, -1):
		var c: Dictionary = g.board[i]
		if c.get("kind", "") == "trace" and c.get("trace_family", "") != "" and not c.get("deleted", false):
			var key = "%s:%d" % [npc_id, c["n"]]
			if not probed_traces.has(key):
				return c["n"]
	return 0

static func select_circumstantial_cards(view: Dictionary, all_cards: Array, target_id: String, sc: Dictionary, disputes: Array) -> Array:
	var candidate_ids: Array = []
	var silenced_by_day: Dictionary = {}
	for ev in view.get("timeline", {}).get("events", []):
		if ev.get("kind", "") == "silenced":
			var ev_day: int = int(ev.get("at", {}).get("day", -1))
			if ev_day >= 1:
				if not silenced_by_day.has(ev_day):
					silenced_by_day[ev_day] = []
				for s in ev.get("subjects", []):
					if s not in silenced_by_day[ev_day]:
						silenced_by_day[ev_day].append(s)
	for c in all_cards:
		if c.get("kind", "") == "context" and c.get("context_kind", "") == "silenced":
			var s_day: int = int(c.get("observed_at", {}).get("day", c.get("night", -1)))
			var s_subj: String = str(c.get("subject", ""))
			if s_day >= 1 and s_subj != "":
				if not silenced_by_day.has(s_day):
					silenced_by_day[s_day] = []
				if s_subj not in silenced_by_day[s_day]:
					silenced_by_day[s_day].append(s_subj)
	var block_presence: Dictionary = {}
	for c in all_cards:
		if c.get("kind", "") in ["location", "evening"] and c.get("block", "") != "":
			var bday: int = int(c.get("day", c.get("observed_at", {}).get("day", -1)))
			var bphase: String = str(c.get("observed_at", {}).get("phase", ""))
			if bday >= 1 and bphase != "":
				var bkey = "%d:%s:%s" % [bday, bphase, c.block]
				if not block_presence.has(bkey):
					block_presence[bkey] = []
				for who in c.get("subjects", [c.get("subject", "")]):
					if who != "" and who not in block_presence[bkey]:
						block_presence[bkey].append(who)
	for c in all_cards:
		if c.get("profile_receipt", false):
			continue
		var ckind: String = c.get("kind", "")
		var ctx: String = c.get("context_kind", "")
		var subjs: Array = c.get("subjects", [c.get("subject", "")]).filter(func(x): return x != "")
		var cday: int = int(c.get("day", c.get("observed_at", {}).get("day", c.get("night", -1))))
		if ckind == "context" and ctx == "silenced" and target_id not in subjs:
			var s_victim: String = subjs[0] if not subjs.is_empty() else ""
			var has_prox: bool = s_victim != "" and all_cards.any(func(o):
				if o.get("kind", "") not in ["location", "evening"]:
					return false
				var oday: int = int(o.get("day", o.get("observed_at", {}).get("day", -2)))
				var ophase: String = str(o.get("observed_at", {}).get("phase", ""))
				var oblk: String = str(o.get("block", ""))
				var osubjs: Array = o.get("subjects", [o.get("subject", "")])
				if oday != cday or target_id not in osubjs:
					return false
				return s_victim in osubjs or (oblk != "" and ophase != "" and s_victim in block_presence.get("%d:%s:%s" % [oday, ophase, oblk], [])))
			if has_prox and c.id not in candidate_ids:
				candidate_ids.append(c.id)
		elif ckind in ["location", "evening"] and target_id in subjs:
			var phase_str: String = str(c.get("observed_at", {}).get("phase", ""))
			var blk: String = str(c.get("block", ""))
			var matched_loc: bool = false
			for sv in silenced_by_day.get(cday, []):
				if sv == target_id:
					continue
				var direct_pair: bool = sv in subjs
				var same_slot: bool = blk != "" and phase_str != "" and sv in block_presence.get("%d:%s:%s" % [cday, phase_str, blk], [])
				if direct_pair or same_slot:
					matched_loc = true
					break
			if not matched_loc and c.get("orig_kind", "") == "conversation":
				for other in subjs:
					if other != target_id and sc.get(other, 0.0) >= 0.7:
						matched_loc = true
						break
			if matched_loc and c.id not in candidate_ids:
				candidate_ids.append(c.id)
		elif ckind == "context" and ctx == "vote":
			var vdata: Dictionary = c.get("data", {})
			var nom: String = str(vdata.get("nominee", ""))
			var yes_list: Array = vdata.get("yes", [])
			var by_who: String = str(vdata.get("nominator", vdata.get("by", "")))
			if nom != "" and nom != target_id and sc.get(nom, 0.0) <= -0.15 and (by_who == target_id or target_id in yes_list):
				if c.id not in candidate_ids:
					candidate_ids.append(c.id)
		elif ckind == "refusal" and target_id in subjs:
			if c.id not in candidate_ids:
				candidate_ids.append(c.id)
	var check_ids: Array = candidate_ids.duplicate()
	for f in ["bonds", "personality"]:
		for rid in view.get("profile_facets", {}).get(target_id, {}).get(f, {}).get("receipt_ids", []):
			if rid not in check_ids:
				check_ids.append(rid)
	if check_ids.is_empty():
		return []
	var est_susp: Dictionary = {}
	var est_trust: Dictionary = {}
	for p in view.get("people", []):
		est_susp[p.id] = clampf(0.20 + 0.25 * sc.get(p.id, 0.0), 0.05, 0.85)
		est_trust[p.id] = 0.60 if sc.get(p.id, 0.0) <= -0.15 else 0.50
	var extracted: Dictionary = Circumstantial.extract_hub_incidents(view, check_ids, target_id, est_susp, est_trust, [], disputes)
	if extracted.get("incidents", {}).is_empty():
		return []
	return candidate_ids
