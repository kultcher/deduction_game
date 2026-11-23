## The live Workshop's premise and card-answer editors: the premise card's fields and their
## pop-up menus, filling a premise in, and the reading-challenge and reason controls on a
## card. Split from ui/live_case_workshop.gd (Tier 2, Nov 20); each takes the editor as `m`.
extends RefCounted

const Live = preload("res://game/workshop_canvas.gd")

static func premise_details(m, node: Dictionary) -> void:
	var conclusion: Dictionary = node.get("conclusion", {})
	if not conclusion.is_empty() and m.board.view.get("chronology", {}).has("curse") and conclusion.get("type") in m.EPOCH_TYPES:
		var epochs: Array = m.board.view.chronology.epochs.keys()
		var epoch = m._option(m.case_box, epochs)
		epoch.select(epochs.find(conclusion.at))
		epoch.item_selected.connect(func(i): conclusion.at = epochs[i]; m._edit())
	if conclusion.get("type") == "secret_mod":
		# Only the hidden burden (burdens rework): a known one is argued through its claim.
		var kinds: Array = Live.Assess.HIDDEN_BURDENS
		var choice = m._option(m.case_box, kinds.map(func(kind): return Live.Assess.C.secret_name(kind)))
		if not conclusion.has("mod"):
			conclusion["mod"] = kinds[0]
		choice.select(kinds.find(conclusion.mod))
		choice.item_selected.connect(func(i): conclusion.mod = kinds[i]; m._edit())
	if conclusion.get("type") == "notrole":
		var roles: Array = Live.Assess.C.GOOD_ROLES
		var choice = m._option(m.case_box, roles.map(func(role): return Live.Assess.C.role_name(role)))
		if not conclusion.has("role"):
			var claims: Array = m.board.view.cards.filter(func(card): return card.source == conclusion.target and card.get("role", "") in roles)
			conclusion["role"] = claims[0].role if not claims.is_empty() else roles[0]
		choice.select(roles.find(conclusion.role))
		choice.item_selected.connect(func(i): conclusion.role = roles[i]; m._edit())
		m._label(m.case_box, "Judges this person's included gift declaration. It does not assign an unclaimed role.", 16)
	if conclusion.get("type") in ["lied", "truthful", "misled", "unreliable"]:
		var reports: Array = m.board.view.cards.filter(func(card): return card.kind == "report" and card.source == conclusion.target and not card.has("relay_source") and not card.get("testimony_only", false))
		var choice = m._option(m.case_box, ["Choose the report being questioned"] + reports.map(func(card): return card.text))
		choice.select(1 + reports.find(reports.filter(func(card): return card.id == conclusion.get("report", ""))[0]) if reports.any(func(card): return card.id == conclusion.get("report", "")) else 0)
		choice.item_selected.connect(func(i):
			if i == 0:
				conclusion.erase("report")
			else:
				conclusion["report"] = reports[i - 1].id
			m._edit())
		m._label(m.case_box, "Link that original report and the grounds for questioning it. Lying and impairment remain different explanations.", 16)

# ------------------------------------------------------------ premises on the card

## Add a premise. Blank unless a claim type was preselected (scripted callers).
static func add_premise(m) -> void:
	if m.board.nodes.values().filter(func(n): return n.kind == "premise").size() >= 12:
		m.status.text = "A case board holds up to twelve premises."
		return
	var at: Vector2 = (m.canvas.size / 2.0 - m.canvas.pan) / m.canvas.zoom - Vector2(150, 110)
	if m.premise_type.selected >= 0:
		var people: Array = m.session.scenario.public_view.people
		var target: String = people[maxi(m.premise_person.selected, 0)].id
		m.board.selected = m.board.add_premise(target, (m.premise_types() + ["support"])[m.premise_type.selected], at)
		if not m.board.nodes[m.board.selected].conclusion.is_empty():
			m.case_root = m.board.selected
	else:
		m.board.selected = m.board.add_blank_premise(at)
	m._session_changed()

## Choose one field of a premise: "person", "type", "role", "mod", "report", "epoch".
static func set_premise_field(m, id: String, field: String, value) -> void:
	if not m.board.nodes.has(id) or m.board.nodes[id].kind != "premise":
		return
	var node: Dictionary = m.board.nodes[id]
	if node.get("draft", false):
		var pick: Dictionary = node.get("pick", {})
		if field == "person":
			pick["target"] = value
		elif field == "type":
			pick["type"] = value
		node["pick"] = pick
		var type: String = pick.get("type", "")
		if type == "support":
			node.erase("draft")
			node.erase("pick")
			node.conclusion = {}
		elif type != "" and pick.has("target"):
			node.erase("draft")
			node.erase("pick")
			node.conclusion = {"type": type, "target": pick.get("target", m.board._default_target()), "at": m.board.view.alignment_epoch}
			default_detail(m, node)
			m.case_root = id
	elif field == "type" and value == "support":
		node.conclusion = {}
	elif field == "type":
		var target: String = node.conclusion.get("target", m.board._default_target())
		node.conclusion = {"type": value, "target": target, "at": node.conclusion.get("at", m.board.view.alignment_epoch) if value in m.EPOCH_TYPES else m.board.view.alignment_epoch}
		default_detail(m, node)
		m.case_root = id
	elif field == "person":
		if node.conclusion.is_empty():
			return
		node.conclusion.target = value
		node.conclusion.erase("report")
		default_detail(m, node)
	elif field == "epoch":
		node.conclusion.at = value
	elif field in ["role", "mod", "report", "cause"]:
		node.conclusion[field] = value
	m.board.selected = id
	m._edit()

## Opened from the nomination flow, the Workshop starts the case for you (Michael, Nov 19): the
## blank premise becomes "<target> is <type>". An existing premise saying just that is
## selected instead; with no blank premise, a new one is added in view. Returns its id.
static func prefill_premise(m, target: String, type: String = "evil") -> String:
	if m.board == null:
		return ""
	for id in m.board.nodes:
		var node: Dictionary = m.board.nodes[id]
		# The same claim about the same alignment: after a curse, a premise about someone's
		# original alignment isn't the one to reuse (Codex, #370).
		var c: Dictionary = node.get("conclusion", {})
		if node.kind == "premise" and str(c.get("type", "")) == type and str(c.get("target", "")) == target \
				and (not (type in m.EPOCH_TYPES) or str(c.get("at", m.board.view.alignment_epoch)) == str(m.board.view.alignment_epoch)):
			m.board.selected = id
			m.case_root = id
			m.canvas.centre_on([id])
			m._edit()
			return id
	var blank: String = ""
	for id in m.board.nodes:
		var node: Dictionary = m.board.nodes[id]
		if node.kind == "premise" and node.get("draft", false) and node.get("pick", {}).is_empty():
			blank = id
			break
	if blank == "":
		var at: Vector2 = (m.canvas.size / 2.0 - m.canvas.pan) / m.canvas.zoom - Vector2(150, 110)
		blank = m.board.add_blank_premise(at)
	set_premise_field(m, blank, "person", target)
	set_premise_field(m, blank, "type", type)
	m.canvas.centre_on([blank])
	return blank

static func default_detail(m, node: Dictionary) -> void:
	var conclusion: Dictionary = node.conclusion
	match conclusion.get("type", ""):
		"notrole":
			if not conclusion.has("role"):
				var roles: Array = m.C.GOOD_ROLES
				var claims: Array = m.board.view.cards.filter(func(card): return card.source == conclusion.target and card.get("role", "") in roles)
				conclusion["role"] = claims[0].role if not claims.is_empty() else roles[0]
		"secret_mod":
			if not conclusion.has("mod"):
				conclusion["mod"] = Live.Assess.HIDDEN_BURDENS[0]
		"inconsistent":
			if not conclusion.has("cause"):
				conclusion["cause"] = "any"

static func reports_for(m, person: String) -> Array:
	return m.board.view.cards.filter(func(card): return card.kind == "report" and card.source == person and not card.has("relay_source") and not card.get("testimony_only", false))

## The premise's third field, when its claim needs one (or the time, in curse games).
static func detail_label(m, node: Dictionary) -> Dictionary:
	var conclusion: Dictionary = node.get("conclusion", {})
	if node.get("draft", false) or conclusion.is_empty():
		return {}
	match conclusion.type:
		"notrole":
			return {"field": "role", "text": m.C.role_name(conclusion.get("role", "")), "icon": m.WorkshopSkin.tex("ui/roles/" + conclusion.get("role", ""), 0.06),
				"tip": "The gift this premise is about. It judges the person's own declaration; it doesn't assign an unclaimed role."}
		"secret_mod":
			return {"field": "mod", "text": m.C.secret_name(conclusion.get("mod", "")), "icon": m.WorkshopSkin.tex("ui/roles/" + conclusion.get("mod", ""), 0.06),
				"tip": "Which hidden burden you're arguing they hold, unknown even to them."}
		"inconsistent":
			return {"field": "cause", "text": m.INCONSISTENT_CAUSE_NAMES.get(conclusion.get("cause", "any"), "Any cause"),
				"tip": "Link two or more of their readings. The cause decides the blame: a lie raises suspicion of them, poisoning points at whoever was out that night, Delusional clears them."}
		"lied", "truthful", "misled", "unreliable":
			var report: Dictionary = {}
			for card in reports_for(m, conclusion.target):
				if card.id == conclusion.get("report", ""):
					report = card
			return {"field": "report", "text": report.text if not report.is_empty() else "Choose the reading", "missing": report.is_empty(),
				"icon": m.WorkshopSkin.tex("ui/roles/" + report.role, 0.06) if not report.is_empty() and report.has("role") else null,
				"tip": "The reading this premise questions. Link that reading and your grounds to the premise. Lying and impairment are different explanations."}
	if m.board.view.get("chronology", {}).has("curse") and conclusion.type in m.EPOCH_TYPES:
		return {"field": "epoch", "text": "When: " + str(conclusion.at), "tip": "Which time this premise is about (before, during or after the curse)."}
	return {}

static func field_popup(m, id: String, field: String) -> void:
	var node: Dictionary = m.board.nodes[id]
	if node.kind == "trace_chain":
		if field == "sync_trace_chain":
			m.board.sync_trace_chain(id)
			m._edit()
		return
	if node.kind == "whereabouts":
		if field == "sync_whereabouts":
			m.board.sync_whereabouts(id)
			m._edit()
		return
	if node.kind == "profile_info":
		if field == "profile_person":
			m.board.selected = id
			m.field_menu.clear()
			var p_values: Array = []
			for person in m.board.view.people:
				var face = m.WorkshopSkin.tex("art/portraits/" + person.id, 0.08)
				var dead: bool = m.g != null and m.g.w.by_id.has(person.id) and not m.g.w.by_id[person.id].alive
				var p_text: String = person.name + (" (dead)" if dead else "")
				if face != null:
					m.field_menu.add_icon_item(face, p_text, p_values.size())
				else:
					m.field_menu.add_item(p_text, p_values.size())
				p_values.append(person.id)
			m._field_target = {"id": id, "field": "profile_person", "values": p_values}
			m._sync()
			m.canvas.queue_redraw()
			m.field_menu.position = Vector2i(m.get_viewport().get_mouse_position())
			m.field_menu.reset_size()
			m.field_menu.popup()
		elif field.begins_with("facet:"):
			m.board.toggle_profile_facet(id, field.trim_prefix("facet:"))
			m._edit()
		elif field == "sync_profile":
			m.board.sync_profile_node(id)
			m._edit()
		return
	if node.kind != "premise":
		set_evidence_field(m, id, field)
		return
	m.board.selected = id
	m.field_menu.clear()
	var values: Array = []
	match field:
		"person":
			for person in m.board.view.people:
				var face = m.WorkshopSkin.tex("art/portraits/" + person.id, 0.08)
				var dead: bool = m.g != null and m.g.w.by_id.has(person.id) and not m.g.w.by_id[person.id].alive
				var text: String = person.name + (" (dead)" if dead else "")
				if face != null:
					m.field_menu.add_icon_item(face, text, values.size())
				else:
					m.field_menu.add_item(text, values.size())
				values.append(person.id)
		"type":
			# "Was turned by the curse" only once a curse has fallen, or where already chosen.
			var cursed: bool = m.board.view.get("chronology", {}).has("curse")
			# A hanged person's Demon premise is in the past tense, and only where a Scion
			# could have risen (CanvasModel.premise_offered; Michael, Nov 19).
			# A draft holds its person in `pick` until both fields are chosen (Codex on #305).
			var p_target: String = str(node.get("pick", {}).get("target", "")) if node.get("draft", false) else str(node.get("conclusion", {}).get("target", ""))
			var types: Array = m.premise_types().filter(func(t): return (t != "turned" or cursed or str(node.get("conclusion", {}).get("type", "")) == "turned") and m.board.premise_offered(t, p_target))
			for i in range(types.size()):
				m.field_menu.add_item(m.board.premise_text(types[i], p_target), values.size())
				var hanged_demon: bool = types[i] == "demon" and m.board.premise_text(types[i], p_target) == m.board.HANGED_DEMON_TEXT
				if hanged_demon:
					m.field_menu.set_item_tooltip(m.field_menu.item_count - 1, m.board.HANGED_DEMON_HINT)
				elif m.PREMISE_TYPE_HINTS.has(types[i]):
					m.field_menu.set_item_tooltip(m.field_menu.item_count - 1, m.PREMISE_TYPE_HINTS[types[i]])
				values.append(types[i])
		"role":
			for role in m.C.GOOD_ROLES:
				var icon = m.WorkshopSkin.tex("ui/roles/" + role, 0.06)
				if icon != null:
					m.field_menu.add_icon_item(icon, m.C.role_name(role), values.size())
				else:
					m.field_menu.add_item(m.C.role_name(role), values.size())
				values.append(role)
		"mod":
			for kind in m.C.SECRET_MOD_LIST:
				m.field_menu.add_item(m.C.secret_name(kind), values.size())
				values.append(kind)
		"cause":
			for cause in m.INCONSISTENT_CAUSES:
				m.field_menu.add_item(m.INCONSISTENT_CAUSE_NAMES[cause], values.size())
				values.append(cause)
		"report":
			for card in reports_for(m, node.conclusion.get("target", "")):
				m.field_menu.add_item(card.text, values.size())
				values.append(card.id)
			if values.is_empty():
				m.field_menu.add_item("No readings from this person on the canvas yet", 999)
				m.field_menu.set_item_disabled(0, true)
		"epoch":
			for epoch in m.board.view.chronology.epochs.keys():
				m.field_menu.add_item(str(epoch), values.size())
				values.append(epoch)
	m._field_target = {"id": id, "field": field, "values": values}
	m._sync()
	m.canvas.queue_redraw()
	m.field_menu.position = Vector2i(m.get_viewport().get_mouse_position())
	m.field_menu.reset_size()
	m.field_menu.popup()

static func field_chosen(m, index: int) -> void:
	if m._field_target.is_empty() or index < 0 or index >= m._field_target.values.size():
		return
	var target: Dictionary = m._field_target
	m._field_target = {}
	if target.field == "new_profile_person":
		m.add_profile_info(target.values[index], "home_work")
		return
	if target.field == "profile_person":
		m.board.set_profile_person(target.id, target.values[index])
		m._edit()
		return
	if target.field == "why":
		var node: Dictionary = m.board.nodes[target.id]
		var choice: Array = target.values[index]
		node.reasons[target.key] = choice[0]
		if choice[1] != "":
			node.citations[target.key] = choice[1]
		else:
			node.citations.erase(target.key)
		m.board.selected = target.id
		m._edit()
		return
	set_premise_field(m, target.id, target.field, target.values[index])

# ------------------------------------------------------------ answers on evidence cards

## A click on an evidence card's answer: "pick:<id>", "block:<b>", "resident:<id>",
## "reg:<reason>", "why:<id>" (opens a menu), "mode:<challenge>".
static func set_evidence_field(m, id: String, field: String) -> void:
	var node: Dictionary = m.board.nodes[id]
	var card: Dictionary = m._report(node.card)
	var kind: String = field.get_slice(":", 0)
	var value: String = field.substr(kind.length() + 1)
	m.board.selected = id
	if kind == "mode":
		var passing_on: bool = str(node.get("attribution", "")) == "transmission"
		if node.kind == "modifier" and not (value == "unlikely" and (card.get("role", "") != "surveyor" or not card.get("data", {}).has("count"))) \
				and not (passing_on and value not in preload("res://workshop/reading_challenges.gd").TRANSMISSION_MODES):
			node.mode = value
			m._edit()
		return
	if kind == "side":
		# A Medium relay's challenged side. The passing-on takes only a lie or a failed gift,
		# so a mode about the reading itself becomes a lie.
		if node.kind == "modifier" and card.has("relay_source") and value in preload("res://workshop/reading_challenges.gd").RELAY_ATTRIBUTIONS:
			node["attribution"] = value
			if value == "transmission" and node.mode not in preload("res://workshop/reading_challenges.gd").TRANSMISSION_MODES:
				node.mode = "lying"
			m._edit()
		return
	if kind == "why":
		reason_menu(m, id, card, value)
		return
	node.answers[card.id] = m.board.apply_answer(card, node.answers.get(card.id, {}), kind, value)
	m._edit()

## Why someone seen at night was out: unexplained, a walking gift (citing their
## claim), an evil errand, or love (citing their own Unrequited claim). The private errand
## retired with the Burdens rework (Michael, Q22).
## The walker reason an Unrequited claim gives (Michael, Nov 21: approved).
const UNREQUITED_REASON = "For love (their Unrequited claim)"
## The canvas tag for that reason, was "errand" (Michael, Nov 21: approved).
const UNREQUITED_TAG = "love"

static func reason_menu(m, id: String, card: Dictionary, person: String) -> void:
	m.field_menu.clear()
	var key: String = "%s:%d" % [person, card.get("night", -1)]
	var options: Array = [["unexplained", ""]]
	m.field_menu.add_item("? Unexplained", 0)
	for claim in m.board.view.cards.filter(func(c): return c.kind == "claim" and c.subject == person):
		m.field_menu.add_item("Out on their gift: " + m.C.role_name(claim.role) + " claim", options.size())
		options.append(["gift", claim.id])
	m.field_menu.add_item("Evil errand", options.size())
	options.append(["evil", ""])
	if m.board.view.get("live_activity", false):
		for claim in m.board.view.cards.filter(func(c): return c.kind == "secret_claim" and c.subject == person and str(c.get("data", {}).get("secret_kind", "")) == "unrequited"):
			m.field_menu.add_item(UNREQUITED_REASON, options.size())
			options.append(["secret", claim.id])
	m._field_target = {"id": id, "field": "why", "values": options, "key": key}
	m.field_menu.position = Vector2i(m.get_viewport().get_mouse_position())
	m.field_menu.reset_size()
	m.field_menu.popup()
