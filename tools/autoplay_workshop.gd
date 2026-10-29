## Reusable Workshop case-building and trace/profile scoring helpers for `tools/autoplay.gd`.
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

## Fold structured crime-scene traces and player-known profile receipts into heuristic scores.
static func apply_trace_and_profile_scores(g, sc: Dictionary) -> void:
	var has_struct_trace: bool = g.board.any(func(c): return c.get("kind", "") == "trace" and c.get("trace_family", "") != "" and not c.get("deleted", false))
	if not has_struct_trace:
		return
	var view: Dictionary = WorkshopCanvas.view(g)
	var all_cards: Array = view.get("cards", [])
	var scenes: Dictionary = {}
	for c in all_cards:
		if c.get("kind", "") == "trace" and c.get("data", {}).has("family"):
			var sid: String = str(c.data.get("scene", c.id))
			if not scenes.has(sid):
				scenes[sid] = []
			scenes[sid].append(c)
	for sid in scenes:
		var group: Array = scenes[sid]
		var total_scene: int = int(group[0].data.get("scene_trace_count", group.size()))
		var victim_id: String = str(group[0].data.get("victim", ""))
		for p in g.w.living():
			if p.id == victim_id or not sc.has(p.id):
				continue
			if group.size() >= 2:
				var e0: String = LiveActivity.evaluate_trace_for_person(view, all_cards, group[0], p.id).state
				var e1: String = LiveActivity.evaluate_trace_for_person(view, all_cards, group[1], p.id).state
				if e0 == "matches" or e1 == "matches":
					sc[p.id] += 0.22
				elif e0 == "contradicts" and e1 == "contradicts":
					sc[p.id] -= 0.24
			else:
				var ev: String = LiveActivity.evaluate_trace_for_person(view, all_cards, group[0], p.id).state
				var mult: float = 0.55 if total_scene >= 2 else 1.0
				if ev == "matches":
					sc[p.id] += 0.34 * mult
				elif ev == "contradicts":
					sc[p.id] -= 0.22 * mult

## Assemble and file a Workshop case (Stage 1 reports + traces + Profile Info + optional Stage 2
## Circumstantial Hub) against the top suspect using only player-visible receipts.
## Returns {"card": int, "used_hub": bool}.
static func build_and_file_case(g, sc: Dictionary, include_hub: bool, filed_sigs: Dictionary, last_by_target: Dictionary) -> Dictionary:
	var candidates: Array = g.w.living().filter(func(n): return sc.get(n.id, 0.0) >= 0.45)
	candidates.sort_custom(func(a, b): return sc[a.id] > sc[b.id] if not is_equal_approx(sc[a.id], sc[b.id]) else a.id < b.id)
	if candidates.is_empty():
		return {"card": 0, "used_hub": false}
	var view: Dictionary = WorkshopCanvas.view(g)
	var all_cards: Array = view.get("cards", [])
	var facets_map: Dictionary = view.get("profile_facets", {})
	for target in candidates.slice(0, 2):
		var model = CanvasModel.new(view)
		var root_id: String = model.selected
		model.nodes[root_id].conclusion = {"type": "evil", "target": target.id, "at": view.alignment_epoch}
		var stage1_ids: Array = []
		var profile_people: Dictionary = {}
		var night_sightings_by_day: Dictionary = {}
		var night_alibis_by_day: Dictionary = {}
		for c in all_cards:
			if c.get("profile_receipt", false):
				continue
			var cid: String = c.id
			var ckind: String = c.get("kind", "")
			var subjs: Array = c.get("subjects", [])
			if ckind == "death":
				stage1_ids.append(cid)
			elif ckind == "report":
				var role: String = c.get("role", "")
				var d: Dictionary = c.get("data", {})
				if target.id in subjs or target.id in d.get("pair", []) or (role in ["hearthwitch", "dowser"] and int(d.get("count", 0)) > 0 and target.id in Gifts.group_of(d)):
					stage1_ids.append(cid)
			elif ckind == "sighting" and c.get("observed_at", {}).get("phase", "") == "night" and target.id in subjs:
				stage1_ids.append(cid)
				night_sightings_by_day[int(c.get("night", -1))] = cid
			elif ckind == "alibi" and c.get("observed_at", {}).get("phase", "") == "night" and target.id in subjs:
				night_alibis_by_day[int(c.get("night", -1))] = cid
		var scenes: Dictionary = {}
		for c in all_cards:
			if c.get("kind", "") == "trace" and c.get("data", {}).has("family"):
				var sid: String = str(c.data.get("scene", c.id))
				if not scenes.has(sid):
					scenes[sid] = []
				scenes[sid].append(c)
		for sid in scenes:
			var group: Array = scenes[sid]
			var fits_scene = false
			for tc in group:
				if LiveActivity.evaluate_trace_for_person(view, all_cards, tc, target.id).state == "matches":
					fits_scene = true
			if not fits_scene:
				continue
			profile_people[target.id] = ["home_work", "haunts", "bonds"]
			for tc in group:
				if tc.id not in stage1_ids:
					stage1_ids.append(tc.id)
			var s_night: int = int(group[0].get("night", -1))
			var s_block: String = str(group[0].data.get("scene_block", ""))
			for c in all_cards:
				if c.get("profile_receipt", false):
					continue
				if int(c.get("night", -2)) == s_night and c.get("block", "") == s_block:
					if c.get("kind", "") == "sighting" or (c.get("kind", "") == "report" and c.get("role", "") == "nightwatch"):
						if c.id not in stage1_ids:
							stage1_ids.append(c.id)
						for wk_id in c.get("subjects", []):
							if wk_id != "" and wk_id != target.id:
								profile_people[wk_id] = ["home_work", "haunts"]
		for nd in night_sightings_by_day:
			if night_alibis_by_day.has(nd):
				var al_id: String = night_alibis_by_day[nd]
				var sg_id: String = night_sightings_by_day[nd]
				if model.nodes.has("e:" + al_id) and model.nodes.has("e:" + sg_id):
					model.connect_cards("e:" + al_id, "e:" + sg_id)
					for k in model.nodes:
						if model.nodes[k].kind == "contradiction" and sg_id in model.nodes[k].get("dispute", {}).get("reports", []):
							model.connect_cards(k, root_id)
		for cid in stage1_ids:
			if model.nodes.has("e:" + cid) and not model.nodes["e:" + cid].has("merged"):
				model.connect_cards("e:" + cid, root_id)
		for pid in profile_people:
			var unlocked: Array = []
			for f in profile_people[pid]:
				if facets_map.get(pid, {}).get(f, {}).get("unlocked", false):
					unlocked.append(f)
			if not unlocked.is_empty():
				var pnode: String = model.add_profile_info(pid, unlocked)
				model.connect_cards(pnode, root_id)
		var s1_compiled: Dictionary = model.compile(root_id)
		if s1_compiled.cards.is_empty():
			continue
		var s1_juror: Dictionary = WorkshopCanvas.test_juror(g, s1_compiled)
		if not s1_juror.get("ready", false) or s1_juror.get("impossible", false) or float(s1_juror.get("lr", 1.0)) < 1.45 or str(s1_juror.get("raises", "")) != "":
			continue
		var attached_hub: bool = false
		if include_hub and float(s1_juror.get("lr", 1.0)) >= 1.55:
			var hub_card_ids: Array = select_circumstantial_cards(view, all_cards, target.id, sc, s1_compiled.get("disputes", []))
			if not hub_card_ids.is_empty():
				var hub_id: String = model.add_circumstantial_hub()
				for hcid in hub_card_ids:
					if model.nodes.has("e:" + hcid) and not model.nodes["e:" + hcid].has("merged"):
						model.connect_cards("e:" + hcid, hub_id)
				var extra_facets: Array = []
				for f in ["bonds", "personality"]:
					if facets_map.get(target.id, {}).get(f, {}).get("unlocked", false):
						extra_facets.append(f)
				if not extra_facets.is_empty():
					var tp_node: String = model.add_profile_info(target.id, extra_facets)
					model.connect_cards(tp_node, hub_id)
				model.connect_cards(hub_id, root_id)
				attached_hub = true
		var final_compiled: Dictionary = model.compile(root_id)
		var sig: String = JSON.stringify([target.id, final_compiled.cards, final_compiled.get("circumstantial", [])])
		if filed_sigs.has(sig):
			continue
		var st_check: Dictionary = WorkshopCanvas.status(g, final_compiled)
		if st_check.get("blocked", true) or not st_check.get("audience_ready", false):
			continue
		var prev_num: int = int(last_by_target.get(target.id, 0))
		var filed_num: int = WorkshopCanvas.file(g, final_compiled, prev_num)
		if filed_num > 0:
			filed_sigs[sig] = filed_num
			last_by_target[target.id] = filed_num
			return {"card": filed_num, "used_hub": attached_hub and not final_compiled.get("circumstantial", []).is_empty()}
	return {"card": 0, "used_hub": false}

static func select_circumstantial_cards(view: Dictionary, all_cards: Array, target_id: String, sc: Dictionary, disputes: Array) -> Array:
	var candidate_ids: Array = []
	var silenced_days: Dictionary = {}
	for ev in view.get("timeline", []):
		if ev.get("kind", "") == "silenced":
			for s in ev.get("subjects", []):
				silenced_days["%s:%d" % [s, int(ev.get("day", -1))]] = true
	for c in all_cards:
		if c.get("profile_receipt", false):
			continue
		var ckind: String = c.get("kind", "")
		var subjs: Array = c.get("subjects", [])
		var cday: int = int(c.get("observed_at", {}).get("day", -1))
		if ckind == "silenced" and target_id not in subjs:
			var v_id: String = subjs[0] if not subjs.is_empty() else ""
			var has_prox: bool = all_cards.any(func(o): return o.get("kind", "") == "conversation" and int(o.get("observed_at", {}).get("day", -2)) == cday and target_id in o.get("subjects", []) and v_id in o.get("subjects", []))
			if has_prox:
				candidate_ids.append(c.id)
		elif ckind == "conversation" and target_id in subjs:
			for other in subjs:
				if other == target_id:
					continue
				if silenced_days.has("%s:%d" % [other, cday]) or sc.get(other, 0.0) >= 0.7:
					if c.id not in candidate_ids:
						candidate_ids.append(c.id)
		elif ckind == "vote" and target_id in subjs:
			var nom: String = str(c.get("data", {}).get("nominee", ""))
			var yes_list: Array = c.get("data", {}).get("yes", [])
			var by_who: String = str(c.get("data", {}).get("nominator", c.get("data", {}).get("by", "")))
			if nom != "" and nom != target_id and sc.get(nom, 0.0) <= -0.15 and (by_who == target_id or target_id in yes_list):
				candidate_ids.append(c.id)
		elif ckind == "refusal" and target_id in subjs:
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
