## What each kind of card on the Workshop canvas shows, laid out: its rows, faces, fields
## and tooltips, and its height. The view draws from these (ui/workshop_canvas_view.gd).
## Split from that file (Tier 2, Nov 20); each takes the canvas view as `m`.
extends RefCounted

const CanvasSkin = preload("res://ui/theme.gd")
const Solver = preload("res://workshop/solver.gd")
const C = preload("res://sim/content.gd")
const TraceSolver = preload("res://workshop/trace_solver.gd")
const LocationSolver = preload("res://workshop/location_solver.gd")

static func chain_traces(m, id: String) -> Array:
	return TraceSolver.evaluate_selection(m.model.view, m.model.nodes[id].get("selected_by_night", {})).get("selected_traces", [])

static func chain_trace_text(m, tr: Dictionary) -> String:
	var shared: String = " (one of two traces at this scene)" if int(tr.get("scene_trace_count", 1)) >= 2 else ""
	return "Night %d%s: %s" % [int(tr.get("night", 0)), shared, str(tr.get("text", ""))]

static func unsupported(m, card: Dictionary) -> bool:
	return card.get("unweighable", false) or card.get("off_board", false)

static func time_text(m, card: Dictionary) -> String:
	var at: Dictionary = card.get("observed_at", {})
	if at.is_empty():
		return ""
	var phase: String = str(at.get("phase", ""))
	if phase == "night":
		return "N%d" % int(at.get("day", 0))
	return "D%d %s" % [int(at.get("day", 0)), phase.substr(0, 1).to_upper() + phase.substr(1, 2)]

static func people_home(m, block: String) -> Array:
	return m.model.view.people.filter(func(p): return p.get("home", "") == block).map(func(p): return p.id)

## What the card asks and how its answer is drawn, in card-local world units:
## {h, els: [{t: face|tile|chip|label, ...}], details: bool}. Shared by sizing and drawing.
static func evidence_layout(m, id: String) -> Dictionary:
	var node: Dictionary = m.model.nodes[id]
	var card: Dictionary = m._evidence_card(id)
	var els: Array = []
	var y: float = 50.0
	# The fewest words on the card; the full sentence is in the hover (Michael, Nov 18).
	var all_lines: Array = m._lines(str(card.get("short", card.get("text", ""))), m.WIDTH - 32, 14)
	var text_lines: Array = all_lines.slice(0, 3)
	if all_lines.size() > 3:
		var last: String = text_lines[2]
		while last != "" and m.font.get_string_size(last + " …", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > m.WIDTH - 32:
			last = last.substr(0, last.length() - 1).strip_edges(false, true)
		text_lines[2] = last + " …"
	y += text_lines.size() * 18.0 + 6.0
	var details = false
	if node.kind == "modifier":
		y += 4.0
		var x: float = 16.0
		var side: String = str(node.get("attribution", ""))
		if card.has("relay_source"):
			# A Medium's relay: which side is challenged, then how (Quill, Nov 17).
			for s in ["transmission", "original"]:
				els.append({"t": "chip", "rect": Rect2(16.0, y, m.WIDTH - 32.0, 26), "text": m.model.RELAY_SIDE_TEXT[s], "on": side == s, "disabled": false, "field": "side:" + s,
					"tip": {"transmission": "The Medium heard the dead correctly but passed it on wrong: a lie, or a failed gift.", "original": "The Medium passed it on faithfully, but the dead person's own reading was wrong."}[s]})
				y += 32.0
			y += 4.0
		# One honest-mistake label for "misled" and "failed gift" (Nov 18), named and tipped
		# in ReadingChallenges.
		var RCh = preload("res://workshop/reading_challenges.gd")
		for mode in [RCh.HONEST, "lying", "unlikely"]:
			var label: String = {"lying": "Lying", RCh.HONEST: RCh.HONEST_LABEL, "unlikely": "Unlikely"}[mode]
			var w: float = 84.0
			var disabled: bool = (mode == "unlikely" and (card.get("role", "") != "surveyor" or not card.get("data", {}).has("count"))) \
				or (side == "transmission" and mode not in preload("res://workshop/reading_challenges.gd").TRANSMISSION_MODES) \
				or (mode == RCh.HONEST and not RCh.honest_allowed(m.model.view, card, side))
			els.append({"t": "chip", "rect": Rect2(x, y, w, 26), "text": label, "on": preload("res://workshop/reading_challenges.gd").canonical(node.mode) == mode, "disabled": disabled, "field": "mode:" + mode,
				"tip": {"lying": "The reader is lying about this result.", RCh.HONEST: RCh.HONEST_TIP, "unlikely": "The reading is possible but unlikely as stated (Surveyor counts)."}[mode]})
			x += w + 8.0
		y += 36.0
		return {"h": y + 44.0, "els": els, "text": text_lines, "details": false}
	var answer: Dictionary = node.answers.get(card.get("id", ""), {})
	var positive: Array = answer.get("positive", [])
	var marked: Array = answer.get("marked", [])
	var role: String = card.get("role", "")
	if card.kind == "report" and role in m.PAIR_ROLES and card.get("data", {}).has("pair"):
		var pair: Array = card.data.pair
		var subject: String = ""
		var icon = null
		if role == "seer":
			subject = "Yes: the Demon is in this pair" if card.data.get("yes", false) else "No: no Demon in this pair"
		elif role == "clerk" or role == "archivist":
			subject = "One of them is the " + C.role_name(card.data.get("role", ""))
			icon = CanvasSkin.tex("ui/roles/" + card.data.get("role", ""), 0.05)
		else:
			subject = "One of them is " + C.secret_name(card.data.get("secret", "marked"))
			icon = CanvasSkin.tex("ui/roles/" + card.data.get("secret", "marked"), 0.05)
		els.append({"t": "label", "at": Vector2(16 + (26 if icon != null else 0), y + 14), "text": subject, "icon": icon})
		y += 26.0
		var answerable: bool = role != "seer" or card.data.get("yes", false)
		var x0: float = m.WIDTH / 2.0 - (pair.size() - 1) * m.FACE_STEP * 0.75
		for i in range(pair.size()):
			var p: String = pair[i]
			els.append({"t": "face", "p": p, "at": Vector2(x0 + i * m.FACE_STEP * 1.5, y + m.FACE_R + 2), "r": m.FACE_R,
				"state": "on" if p in positive else "", "field": "pick:" + p if answerable else "",
				"tip": Solver.person_name(m.model.view, p) + (": click to say this one explains the reading" if answerable else "")})
		y += m.FACE_R * 2 + 22.0
		if role == "seer" and card.data.get("yes", false):
			var x: float = 16.0
			for reg in ([["", "Any"], ["demon", "Demon"], ["red_herring", "Red Herring"], ["marked", "Marked"]] if m.model.marked_answers else [["", "Any"], ["demon", "Demon"], ["red_herring", "Red Herring"]]):
				var w: float = 58.0 if reg[0] == "" else (64.0 if reg[0] != "red_herring" else 96.0)
				els.append({"t": "chip", "rect": Rect2(x, y, w, 24), "text": reg[1], "on": answer.get("registration", "") == reg[0], "field": "reg:" + reg[0],
					"tip": "Why the Seer got a yes: " + {"": "any valid explanation", "demon": "the Demon is the one you picked", "red_herring": "the one you picked is the Red Herring", "marked": "the one you picked is Marked"}[reg[0]]})
				x += w + 6.0
			y += 32.0
	elif card.kind == "report" and role in ["dowser", "lamplighter"]:
		var group: Array = card.data.get("group", []) if role == "dowser" else m.model.view.people.map(func(p): return p.id).filter(func(p): return p != card.source)
		var count: int = int(card.data.get("count", 0))
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": ("%d evil among them" % count) if role == "dowser" else ("%d others out that night" % count)})
		y += 26.0
		var per_row: int = 5
		for i in range(group.size()):
			var p: String = group[i]
			var state: String = ("marked" if p in marked else "on") if p in positive else ""
			els.append({"t": "face", "p": p, "at": Vector2(36 + (i % per_row) * m.FACE_STEP, y + m.FACE_R + 2 + (i / per_row) * (m.FACE_R * 2 + 16)), "r": m.FACE_R, "state": state,
				"field": "pick:" + p, "tip": Solver.person_name(m.model.view, p) + (": click to mark as registering evil" + again_clause(m) if role == "dowser" else ": click to say they were out")})
		y += ceili(group.size() / float(per_row)) * (m.FACE_R * 2 + 16) + 8.0
	elif card.kind == "report" and role == "surveyor" and card.get("data", {}).has("block"):
		var s_blk: String = str(card.data.get("block", ""))
		var s_same: bool = bool(card.data.get("same", false))
		var s_residents: Array = people_home(m, s_blk)
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": "%s: %s" % [C.block_name(s_blk), "all share alignment" if s_same else "mixed alignments"]})
		y += 26.0
		var sx0: float = m.WIDTH / 2.0 - (s_residents.size() - 1) * m.FACE_STEP * 0.5
		for i in range(s_residents.size()):
			var p: String = s_residents[i]
			var st_s: String = ("marked" if p in marked else "on") if p in positive else ""
			els.append({"t": "face", "p": p, "at": Vector2(sx0 + i * m.FACE_STEP, y + m.FACE_R + 2), "r": m.FACE_R, "state": st_s,
				"field": "" if s_same else ("pick:" + p),
				"tip": Solver.person_name(m.model.view, p) + (" lives on " + C.block_name(s_blk) if s_same else ": click to mark as registering evil" + again_clause(m))})
		y += m.FACE_R * 2 + 16.0
	elif card.kind == "report" and role == "surveyor":
		var count: int = int(card.data.get("count", 0))
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": "%d of 4 blocks have an evil resident" % count})
		y += 26.0
		var blocks: Array = answer.get("blocks", [])
		var keys: Array = C.BLOCKS.keys()
		for i in range(keys.size()):
			var b: String = keys[i]
			var residents: Array = people_home(m, b)
			var chosen: bool = b in blocks or residents.any(func(p): return p in positive)
			var tile = Rect2(12 + (i % 2) * 140, y + (i / 2) * 84, 134, 78)
			els.append({"t": "tile", "rect": tile, "text": C.block_name(b), "on": chosen, "field": "block:" + b,
				"tip": C.block_name(b) + ": click to say an evil (or Marked) resident lives here"})
			for j in range(residents.size()):
				var p: String = residents[j]
				els.append({"t": "face", "p": p, "at": tile.position + Vector2(22 + j * 36, 52), "r": 14.0,
					"state": ("marked" if p in marked else "on") if p in positive else "", "field": "resident:" + p,
					"tip": Solver.person_name(m.model.view, p) + ": click to name them as the reason" + again_clause(m)})
		y += 172.0
	elif card.kind == "report" and role == "chronicler":
		var trio: Array = card.get("data", {}).get("trio", [])
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": "Case start: 1 folk, 1 burden, 1 Minion"})
		y += 26.0
		var cx0: float = m.WIDTH / 2.0 - (trio.size() - 1) * m.FACE_STEP * 0.6
		for i in range(trio.size()):
			var p: String = trio[i]
			els.append({"t": "face", "p": p, "at": Vector2(cx0 + i * m.FACE_STEP * 1.2, y + m.FACE_R + 2), "r": m.FACE_R,
				"state": "on" if p in positive else "", "field": "pick:" + p,
				"tip": Solver.person_name(m.model.view, p) + ": click to say they were the Minion at case start"})
		y += m.FACE_R * 2 + 16.0
	elif card.kind == "report" and role == "magistrate":
		var m_same: bool = bool(card.get("data", {}).get("same", false))
		var m_pair: Array = [str(card.get("data", {}).get("nominator", "")), str(card.get("data", {}).get("nominee", ""))]
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": "Nomination: same alignment" if m_same else "Nomination: different alignments"})
		y += 26.0
		var mx0: float = m.WIDTH / 2.0 - m.FACE_STEP * 0.75
		for i in range(m_pair.size()):
			var p: String = m_pair[i]
			if p == "":
				continue
			var st_m: String = ("marked" if p in marked else "on") if p in positive else ""
			els.append({"t": "face", "p": p, "at": Vector2(mx0 + i * m.FACE_STEP * 1.5, y + m.FACE_R + 2), "r": m.FACE_R,
				"state": st_m, "field": "" if m_same else ("pick:" + p),
				"tip": Solver.person_name(m.model.view, p) + ("" if m_same else ": click to mark as registering evil" + again_clause(m))})
		y += m.FACE_R * 2 + 16.0
	elif card.kind == "report" and role == "augur":
		var a_yes: bool = bool(card.get("data", {}).get("yes", false))
		var a_day: int = int(card.get("observed_at", {}).get("day", 1))
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": ("Yes: crossed Demon in public (D%d)" % a_day) if a_yes else ("No public Demon crossing (D%d)" % a_day)})
		y += 26.0
		# Who you saw around the Augur that day (triage 5.10); the reading itself names nobody.
		var a_seen: String = preload("res://game/workshop_canvas.gd").augur_sightings(m.model.view, card)
		if a_seen != "":
			els.append({"t": "label", "at": Vector2(16, y + 12), "text": "(" + a_seen + ")", "fs": 13, "tip": a_seen + "\nFrom your own sightings on the Augur's block that morning and afternoon."})
			y += 22.0
		details = true
	elif (card.kind == "report" and role == "nightwatch") or (card.kind == "sighting" and card.get("night", -1) >= 0):
		var seen: Array = card.data.get("seen", []) if role == "nightwatch" else card.get("subjects", [card.get("subject", "")])
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": "Why were they out?" if not seen.is_empty() else "Nobody seen"})
		y += 26.0
		for i in range(seen.size()):
			var p: String = seen[i]
			if p == "":
				continue
			var reason: String = node.reasons.get("%s:%d" % [p, card.get("night", -1)], "unexplained")
			els.append({"t": "face", "p": p, "at": Vector2(36 + (i % 5) * m.FACE_STEP, y + m.FACE_R + 2 + (i / 5) * (m.FACE_R * 2 + 28)), "r": m.FACE_R,
				"state": "reason:" + reason, "field": "why:" + p, "tip": Solver.person_name(m.model.view, p) + ": click to say why they were out"})
		y += maxf(1.0, ceili(seen.size() / 5.0)) * (m.FACE_R * 2 + 28) + 6.0
	elif card.kind == "town_hall":
		var th_roles: Array = card.get("data", {}).get("roles", [])
		var th_pick: String = str(answer.get("in_play_role", ""))
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": "Exactly 1 in play (optional: pick which):"})
		y += 26.0
		for i in range(th_roles.size()):
			var r_id: String = str(th_roles[i])
			var chip_r = Rect2(14 + i * 140, y, 132, 30)
			els.append({"t": "chip", "rect": chip_r, "text": C.role_name(r_id), "on": th_pick == r_id,
				"field": "th_role:" + r_id,
				"tip": C.role_name(r_id) + ": click to specify this role is the one in town (click again for either)"})
		y += 38.0
	elif card.kind == "event" and card.get("event") == "curse":
		var eligible: Array = card.get("data", {}).get("eligible", [])
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": "Who turned?"})
		y += 26.0
		for i in range(eligible.size()):
			var p: String = eligible[i]
			els.append({"t": "face", "p": p, "at": Vector2(36 + (i % 5) * m.FACE_STEP, y + m.FACE_R + 2 + (i / 5) * (m.FACE_R * 2 + 16)), "r": m.FACE_R,
				"state": "on" if p in positive else "", "field": "pick:" + p, "tip": Solver.person_name(m.model.view, p) + ": click if you think they turned"})
		y += ceili(eligible.size() / 5.0) * (m.FACE_R * 2 + 16) + 8.0
	elif card.kind == "report" and role == "executor":
		var ex_t: String = Solver.person_name(m.model.view, str(card.data.get("target", "")))
		var ex_lbl: String = ("Charge: %s" % ex_t) if card.data.get("assigned", false) else ("%s was %s" % [ex_t, C.role_name(str(card.data.get("role", "")))])
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": ex_lbl})
		y += 26.0
		details = true
	elif card.kind == "report" and role == "monitor":
		var b_name: String = C.block_name(str(card.data.get("block", "")))
		var mon_lbl: String = ""
		if bool(card.data.get("walked", false)):
			mon_lbl = "Abroad on %s: %s" % [b_name, C.role_name(str(card.data.get("role", "")))]
		else:
			mon_lbl = "No one walked on %s" % b_name
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": mon_lbl})
		y += 26.0
		details = true
	elif card.kind == "report" and role == "confessor":
		var conf_lbl: String = ""
		if bool(card.data.get("forgot", false)):
			conf_lbl = "Target: forgot who they visited"
		else:
			var tgt_nm: String = Solver.person_name(m.model.view, str(card.data.get("target", "")))
			conf_lbl = "Visited %s: confirmed Good" % tgt_nm
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": conf_lbl})
		y += 26.0
		details = true
	elif card.kind == "report" and role == "registrar":
		var r_list: String = ", ".join(PackedStringArray(card.data.get("roles", []).map(func(r): return C.role_name(str(r)))))
		var reg_lbl: String = ("Slate: %s" % r_list) if not card.data.has("target") else ("%s in [%s]: %s" % [Solver.person_name(m.model.view, str(card.data.get("target", ""))), r_list, "Yes" if bool(card.data.get("yes", false)) else "No"])
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": reg_lbl})
		y += 26.0
		details = true
	elif card.kind == "report" and role == "psychologist":
		var p_mode_ui: String = str(card.data.get("mode", ""))
		var p_dh_ui: int = int(card.data.get("day_heard", card.get("observed_at", {}).get("day", 1)))
		if p_mode_ui == "none_false":
			els.append({"t": "label", "at": Vector2(16, y + 14), "text": "Day %d: no false statements heard" % p_dh_ui})
			y += 26.0
			details = true
		elif p_mode_ui == "pair" and card.data.get("statements") is Array and card.data.statements.size() == 2:
			var stmts_ui: Array = card.data.statements
			for si in range(2):
				var st_u: Dictionary = stmts_ui[si]
				var sum_u: String = str(st_u.get("summary", Solver.person_name(m.model.view, str(st_u.get("source", "")))))
				if sum_u.length() > 38:
					sum_u = sum_u.substr(0, 35) + "…"
				els.append({"t": "label", "at": Vector2(16, y + 14), "text": "%d. %s" % [si + 1, sum_u]})
				y += 21.0
			y += 4.0
			var cur_ps_ui: String = str(answer.get("false_slot", ""))
			var cur_pw_ui: String = str(answer.get("false_reason", ""))
			var px: float = 14.0
			for opt in [["", "Either"], ["0", "Stmt 1"], ["1", "Stmt 2"], ["both", "Both"]]:
				var cw_p: float = 64.0 if opt[0] != "both" else 58.0
				els.append({"t": "chip", "rect": Rect2(px, y, cw_p, 25), "text": opt[1], "on": cur_ps_ui == opt[0], "field": "psych_pick:" + opt[0],
					"tip": "Which statement was false or misread: " + opt[1]})
				px += cw_p + 5.0
			y += 31.0
			if cur_ps_ui in ["0", "1"]:
				var picked_st: Dictionary = stmts_ui[int(cur_ps_ui)]
				var sight_dis: bool = str(picked_st.get("kind", "")) == "sighting"
				var wx: float = 14.0
				for wopt in [["", "Any cause"], ["lying", "Source lied"], ["misled", "Source misled"]]:
					var ww: float = 78.0 if wopt[0] == "" else (88.0 if wopt[0] == "lying" else 98.0)
					var dis_w: bool = wopt[0] == "misled" and sight_dis
					els.append({"t": "chip", "rect": Rect2(wx, y, ww, 25), "text": wopt[1], "on": cur_pw_ui == wopt[0], "disabled": dis_w, "field": "psych_why:" + wopt[0],
						"tip": "Direct night sightings cannot be misled." if dis_w else ("Why the statement was wrong: " + wopt[1])})
					wx += ww + 5.0
				y += 31.0
			details = true
	else:
		details = card.kind == "report" and role in ["warden", "gravedigger", "veteran", "martyr", "sexton"]
	return {"h": y + 44.0, "els": els, "text": text_lines, "details": details}

static func profile_layout(m, id: String) -> Dictionary:
	var node: Dictionary = m.model.nodes[id]
	var person: String = node.get("person", "")
	var info: Dictionary = m.model.view.get("profile_facets", {}).get(person, {})
	var selected_facets: Array = node.get("facets", [])
	var els: Array = []
	var y: float = 52.0
	var chip_specs = [
		["home_work", "Home & Work", Rect2(14, y, 132, 26)],
		["haunts", "Haunts", Rect2(154, y, 132, 26)],
		["personality", "Personality", Rect2(14, y + 32, 132, 26)],
		["bonds", "Bonds", Rect2(154, y + 32, 132, 26)],
	]
	for spec in chip_specs:
		var key: String = spec[0]
		var fdata: Dictionary = info.get(key, {})
		var unlocked: bool = info.is_empty() or fdata.get("unlocked", false)
		els.append({"t": "chip", "rect": spec[2], "text": spec[1], "on": key in selected_facets,
			"disabled": not unlocked, "field": "facet:" + key,
			"tip": fdata.get("summary", spec[1]) + ("" if unlocked else " (not learned yet)")})
	y += 68.0
	var summaries: Array = []
	for key in m.model.PROFILE_FACETS:
		if key in selected_facets:
			var summary: String = info.get(key, {}).get("summary", m.model.PROFILE_FACET_NAMES[key])
			for line in m._lines(summary, m.WIDTH - 32, 13).slice(0, 2):
				summaries.append(line)
	if summaries.is_empty():
		summaries.append("Select at least one category above.")
	y += summaries.size() * 17.0 + 6.0
	var latest_ids: Array = m.model._resolve_profile_receipts(person, selected_facets)
	if not info.is_empty() and latest_ids != node.get("receipt_ids", []):
		els.append({"t": "chip", "rect": Rect2(14, y, m.WIDTH - 28, 24), "text": "+ Include newly learned details", "on": false, "disabled": false, "field": "sync_profile",
			"tip": "New profile details were learned after this card was added. Click to include them in this draft."})
		y += 30.0
	return {"h": y + 44.0, "els": els, "summaries": summaries}

static func circumstantial_layout(m, id: String) -> Dictionary:
	var incoming: Array = m.model.links.filter(func(e): return e.to == id and m.model.nodes.has(e.from)).map(func(e): return e.from)
	var lines: Array = []
	if incoming.is_empty():
		lines.append("Link sightings, conversations, votes, or profile bonds/traits here.")
		lines.append("Then link this hub into an accusatory Premise.")
	else:
		for src_id in incoming.slice(0, 3):
			lines.append("• " + m.model.title(src_id))
		if incoming.size() > 3:
			lines.append("+ %d more linked item(s)" % (incoming.size() - 3))
	var wrapped: Array = []
	for row in lines:
		for ln in m._lines(row, m.WIDTH - 32, 13).slice(0, 2):
			wrapped.append(ln)
	var h: float = 54.0 + wrapped.size() * 17.0 + 48.0
	return {"h": h, "lines": wrapped, "incoming_count": incoming.size()}

static func trace_chain_layout(m, id: String) -> Dictionary:
	var node: Dictionary = m.model.nodes[id]
	var sel_map: Dictionary = node.get("selected_by_night", {})
	var ev: Dictionary = TraceSolver.evaluate_selection(m.model.view, sel_map)
	var lines: Array = []
	var div_nights: Dictionary = {}
	for d in ev.matrix.get("scion_dividers", []):
		div_nights[int(d.after_night)] = d
	var sel_traces: Array = ev.get("selected_traces", [])
	for i in range(sel_traces.size()):
		var tr: Dictionary = sel_traces[i]
		var two_tag: String = " [1/2]" if int(tr.scene_trace_count) >= 2 else ""
		lines.append("N%d%s: %s" % [int(tr.night), two_tag, " · ".join(PackedStringArray(tr.short_locs))])
		if i < sel_traces.size() - 1 and div_nights.has(int(tr.night)):
			var dv: Dictionary = div_nights[int(tr.night)]
			lines.append("  [Day %d hanging: %s]" % [int(dv.exec_day), str(dv.executed_name)])
	var fit_names: Array = []
	for pid in ev.get("matches_ids", []).slice(0, 4):
		fit_names.append(Solver.person_name(m.model.view, pid))
	var unk_count: int = ev.get("unknown_ids", []).size()
	lines.append("Fits: " + (", ".join(PackedStringArray(fit_names)) if not fit_names.is_empty() else "none confirmed") + (" · %d ?" % unk_count if unk_count > 0 else ""))
	var wrapped: Array = []
	for row in lines:
		for ln in m._lines(row, m.WIDTH - 32, 13).slice(0, 2):
			wrapped.append(ln)
	var y: float = 52.0 + wrapped.size() * 17.0 + 6.0
	var els: Array = []
	var latest_bundle: Dictionary = TraceSolver.bundle_for_workshop(m.model.view, sel_map)
	if latest_bundle.receipt_ids != node.get("receipt_ids", []):
		els.append({"t": "chip", "rect": Rect2(14, y, m.WIDTH - 28, 24), "text": "+ Sync newly learned haunts", "on": false, "disabled": false, "field": "sync_trace_chain",
			"tip": "New haunt receipts were learned after committing this Trace Chain. Click to bundle them."})
		y += 30.0
	return {"h": y + 44.0, "lines": wrapped, "els": els, "fit_count": ev.get("matches_ids", []).size(), "unk_count": unk_count}

## A Whereabouts card (workshop/location_solver.gd): the question, who fits, and a sync chip
## when a later watch or report has grown the day's record.
static func whereabouts_layout(m, id: String) -> Dictionary:
	var node: Dictionary = m.model.nodes[id]
	var res: Dictionary = LocationSolver.evaluate(m.model.view, node.get("question", {}))
	var lines: Array = []
	var q: Dictionary = node.get("question", {})
	if str(q.get("kind", "")) == "silence":
		lines.append("Out on %s's block with them" % Solver.person_name(m.model.view, str(q.get("victim", ""))))
	else:
		var names: Array = res.get("places", []).map(func(l): return C.loc_name(l))
		lines.append("At: " + (", ".join(PackedStringArray(names)) if not names.is_empty() else "no known places"))
	var watched: Array = res.get("watched_phases", [])
	lines.append("Your record: " + (", ".join(PackedStringArray(watched)) if not watched.is_empty() else "no watches") + (" · %d told" % res.report_ids.size() if not res.report_ids.is_empty() else ""))
	var fit_names: Array = res.get("fits", []).slice(0, 4).map(func(pid): return Solver.person_name(m.model.view, pid))
	lines.append("Fits: " + (", ".join(PackedStringArray(fit_names)) if not fit_names.is_empty() else "none confirmed") + (" · %d ?" % res.unknown.size() if not res.unknown.is_empty() else "") + (" · %d ruled out" % res.ruled_out.size() if not res.ruled_out.is_empty() else ""))
	var wrapped: Array = []
	for row in lines:
		for ln in m._lines(row, m.WIDTH - 32, 13).slice(0, 2):
			wrapped.append(ln)
	var y: float = 52.0 + wrapped.size() * 17.0 + 6.0
	var els: Array = []
	if res.log_ids != node.get("log_ids", []) or res.report_ids != node.get("report_ids", []):
		els.append({"t": "chip", "rect": Rect2(14, y, m.WIDTH - 28, 24), "text": "+ Sync the day's newer record", "on": false, "disabled": false, "field": "sync_whereabouts",
			"tip": "You've watched or been told more about this day since committing. Click to cite the fuller record."})
		y += 30.0
	return {"h": y + 44.0, "lines": wrapped, "els": els, "fit_count": res.fits.size(), "unk_count": res.unknown.size()}

## The end of a face's tip: whether another click says "registered as Marked" (off in the
## live editor, premises step 2).
static func again_clause(m) -> String:
	return "; again for \"registered as Marked\"; again to clear" if m.model.marked_answers else "; again to clear"
