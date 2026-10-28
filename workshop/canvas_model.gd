## Editable presentation graph. Layout never supplies evidence or increases its weight.
extends RefCounted
const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const C = preload("res://sim/content.gd")
var view: Dictionary
var nodes: Dictionary = {}
var links: Array = []
var selected = ""
var version = 1
var serial = 0

func _init(public_view: Dictionary) -> void:
	view = public_view
	reset()

func reset() -> void:
	nodes.clear()
	links.clear()
	serial = 0
	version += 1
	for i in range(view.cards.size()):
		var card: Dictionary = view.cards[i]
		nodes["e:" + card.id] = {"id": "e:" + card.id, "kind": "evidence", "card": card.id,
			"at": [60.0 + (i % 4) * 320.0, 400.0 + (i / 4) * 300.0], "answers": {}, "reasons": {}, "citations": {}}
	selected = add_premise(_default_target(), "evil", Vector2(540, 50))

func _default_target() -> String:
	return "constance" if view.people.any(func(p): return p.id == "constance") else view.people[0].id

## A premise with no person or claim yet: the player fills it in on the card.
func add_blank_premise(at: Vector2) -> String:
	var id: String = add_premise("", "support", at)
	nodes[id]["draft"] = true
	return id

func add_premise(target: String, type: String, at: Vector2) -> String:
	serial += 1
	var id = "p:%d" % serial
	while nodes.has(id):
		serial += 1
		id = "p:%d" % serial
	nodes[id] = {"id": id, "kind": "premise", "at": [at.x, at.y], "positions": {},
		"conclusion": {} if type == "support" else {"type": type, "target": target, "at": view.alignment_epoch}}
	version += 1
	return id

func ancestors(id: String, seen: Array = []) -> Array:
	var result: Array = seen.duplicate()
	if id in result or not nodes.has(id):
		return result
	result.append(id)
	for edge in links:
		if edge.to == id:
			result = ancestors(edge.from, result)
	for child in nodes[id].get("children", []):
		result = ancestors(child, result)
	return result

func _reaches(from: String, to: String, seen: Array = []) -> bool:
	if from == to:
		return true
	if from in seen:
		return false
	seen = seen + [from]
	return links.any(func(edge): return edge.from == from and _reaches(edge.to, to, seen))

func connect_cards(from: String, to: String) -> String:
	if not nodes.has(from) or not nodes.has(to) or from == to or nodes[from].has("merged") or nodes[to].has("merged"):
		return "Choose two different visible cards."
	if nodes[from].kind == "premise" and nodes[to].kind != "premise":
		var swap = from
		from = to
		to = swap
	var a: Dictionary = nodes[from]
	var b: Dictionary = nodes[to]
	if a.kind == "evidence" and b.kind == "evidence":
		for pair in [[a, b], [b, a]]:
			var dispute = {"reports": [pair[0].card, pair[1].card], "challenged": pair[0].card, "preferred": pair[1].card}
			if Graph.valid_dispute(view, dispute):
				_merge(from, to, dispute)
				return ""
	if _reaches(to, from):
		return "That link would create a circular argument."
	if links.any(func(edge): return edge.from == from and edge.to == to):
		return "These cards are already linked."
	var relation = "supports"
	if a.kind == "evidence" and b.kind == "evidence":
		relation = "read_together"
		if _gift_link(a, b):
			relation = "explains_outing"
	links.append({"from": from, "to": to, "kind": relation})
	version += 1
	return ""

func add_modifier(id: String, mode: String) -> String:
	if not nodes.has(id) or nodes[id].kind != "evidence":
		return "Select a reading card."
	var report = Solver.card_by_id(view, nodes[id].card)
	if report.kind != "report" or report.has("relay_source") or report.get("testimony_only", false) or mode not in ["misled", "lying", "unlikely"] or (mode == "unlikely" and report.role != "surveyor"):
		return "This modifier is not supported for that evidence type."
	for node in nodes.values():
		if node.kind == "modifier" and node.card == report.id:
			node.mode = mode
			selected = node.id
			version += 1
			return ""
	serial += 1
	var key = "m:%d" % serial
	while nodes.has(key):
		serial += 1
		key = "m:%d" % serial
	var prior: Array = links.filter(func(e): return e.from == id).duplicate(true)
	for edge in links:
		if edge.from == id:
			edge.from = key
	nodes[key] = {"id": key, "kind": "modifier", "card": report.id, "mode": mode,
		"at": [nodes[id].at[0] + 320, nodes[id].at[1]], "prior_links": prior}
	links.append({"from": id, "to": key, "kind": "supports"})
	selected = key
	version += 1
	return ""

func remove_modifier(id: String) -> void:
	if not nodes.has(id) or nodes[id].kind != "modifier":
		return
	var reading: String = "e:" + nodes[id].card
	var incoming: Array = links.filter(func(e): return e.to == id).map(func(e): return e.from)
	var outgoing: Array = links.filter(func(e): return e.from == id).map(func(e): return e.to)
	links = links.filter(func(e): return e.from != id and e.to != id)
	nodes.erase(id)
	for source in incoming:
		for target in outgoing:
			if source != target and not links.any(func(e): return e.from == source and e.to == target):
				links.append({"from": source, "to": target, "kind": "supports"})
	selected = reading
	version += 1

func _gift_link(a: Dictionary, b: Dictionary) -> bool:
	if a.kind != "evidence" or b.kind != "evidence":
		return false
	var claim = Solver.card_by_id(view, a.card)
	var observation = Solver.card_by_id(view, b.card)
	if claim.kind != "claim" or observation.get("night", -1) < 1 or not (observation.kind == "sighting" or (observation.kind == "report" and observation.role == "nightwatch")):
		return false
	var choices = {"citations": {"%s:%d" % [claim.subject, observation.night]: claim.id}}
	return claim.subject in observation.get("data", {}).get("seen", [observation.get("subject", "")]) and not Graph.valid_citation(view, choices, claim.subject, observation.night).is_empty()

func _merge(a: String, b: String, dispute: Dictionary) -> void:
	serial += 1
	var id = "c:%d" % serial
	while nodes.has(id):
		serial += 1
		id = "c:%d" % serial
	var x = (float(nodes[a].at[0]) + float(nodes[b].at[0])) / 2.0
	var y = (float(nodes[a].at[1]) + float(nodes[b].at[1])) / 2.0
	var prior: Array = links.filter(func(edge): return edge.from in [a, b] or edge.to in [a, b]).duplicate(true)
	links = links.filter(func(edge): return edge.from not in [a, b] and edge.to not in [a, b])
	nodes[id] = {"id": id, "kind": "contradiction", "at": [x, y], "children": [a, b], "dispute": dispute, "prior_links": prior}
	nodes[a]["merged"] = id
	nodes[b]["merged"] = id
	var linked_premise = ""
	for edge in prior:
		var source: String = id if edge.from in [a, b] else edge.from
		var destination: String = id if edge.to in [a, b] else edge.to
		if source == destination:
			continue
		if nodes.get(source, {}).get("kind", "") == "premise" and nodes.get(destination, {}).get("kind", "") != "premise":
			var swap = source
			source = destination
			destination = swap
		var kind: String = "supports" if (source == id or destination == id) and (nodes.get(source, {}).get("kind", "") == "premise" or nodes.get(destination, {}).get("kind", "") == "premise") else edge.kind
		if not _reaches(destination, source) and not links.any(func(e): return e.from == source and e.to == destination):
			links.append({"from": source, "to": destination, "kind": kind})
			if source == id and nodes.get(destination, {}).get("kind", "") == "premise" and linked_premise == "":
				linked_premise = destination
	selected = linked_premise if linked_premise != "" else id
	version += 1

func unmerge(id: String) -> void:
	if not nodes.has(id) or nodes[id].kind != "contradiction":
		return
	var group: Dictionary = nodes[id]
	var outgoing: Array = links.filter(func(edge): return edge.from == id)
	links = links.filter(func(edge): return edge.from != id and edge.to != id)
	for child in group.children:
		nodes[child].erase("merged")
	nodes.erase(id)
	for edge in group.prior_links:
		if not links.has(edge):
			links.append(edge)
	for edge in outgoing:
		for child in group.children:
			if not links.any(func(e): return e.from == child and e.to == edge.to):
				links.append({"from": child, "to": edge.to, "kind": "supports"})
	selected = group.children[0]
	version += 1

## A contradiction whose observation is a gift report (a claim, not something you saw)
## can be read the other way: the report is the false one. True when that's on offer.
func report_doubtable(id: String) -> bool:
	if not nodes.has(id) or nodes[id].kind != "contradiction":
		return false
	var report = Solver.card_by_id(view, nodes[id].dispute.preferred)
	return report.get("kind", "") == "report" and not report.has("relay_source") and not report.get("testimony_only", false)

## The other explanation for an alibi against a gift report: the report is false. Splits
## the contradiction back into its two cards and puts a "suspected lie" on the report,
## keeping the links. Returns "" or why not.
func doubt_report(id: String) -> String:
	if not report_doubtable(id):
		return "Only a gift report can be doubted this way."
	var preferred: String = nodes[id].dispute.preferred
	var report_node = ""
	for child in nodes[id].children:
		if nodes[child].card == preferred:
			report_node = child
	unmerge(id)
	return add_modifier(report_node, "lying")

func unlink(from: String, to: String) -> void:
	links = links.filter(func(edge): return edge.from != from or edge.to != to)
	version += 1

## Take an evidence card off the canvas, with its modifiers and links. The original
## card stays on the case board; only this canvas copy goes.
func remove_evidence(id: String) -> void:
	if not nodes.has(id) or nodes[id].kind != "evidence" or nodes[id].has("merged"):
		return
	for key in nodes.keys().filter(func(k): return nodes[k].kind == "modifier" and nodes[k].card == nodes[id].card):
		remove_modifier(key)
	links = links.filter(func(edge): return edge.from != id and edge.to != id)
	for node in nodes.values():
		if node.kind in ["contradiction", "modifier"]:
			node.prior_links = node.get("prior_links", []).filter(func(edge): return edge.from != id and edge.to != id)
	nodes.erase(id)
	if selected == id or not nodes.has(selected):
		var premises: Array = nodes.keys().filter(func(key): return nodes[key].kind == "premise")
		selected = premises[0] if not premises.is_empty() else (nodes.keys()[0] if not nodes.is_empty() else "")
	version += 1

func remove_premise(id: String) -> void:
	if not nodes.has(id) or nodes[id].kind != "premise":
		return
	links = links.filter(func(edge): return edge.from != id and edge.to != id)
	nodes.erase(id)
	for node in nodes.values():
		if node.kind == "contradiction":
			node.prior_links = node.prior_links.filter(func(edge): return edge.from != id and edge.to != id)
	var remaining: Array = nodes.keys().filter(func(key): return nodes[key].kind == "premise" and not nodes[key].conclusion.is_empty())
	selected = add_blank_premise(Vector2(540, 50)) if remaining.is_empty() else remaining[0]
	version += 1

func compile(root: String, include_arguments: bool = true) -> Dictionary:
	var result = Solver.empty_case()
	result.version = version
	if not nodes.has(root) or nodes[root].kind != "premise" or nodes[root].conclusion.is_empty():
		return result
	result.conclusion = nodes[root].conclusion.duplicate(true)
	result.positions = nodes[root].positions.duplicate(true)
	result.faults = nodes[root].get("faults", {}).duplicate(true)
	var all = ancestors(root)
	var direct: Array = []
	for edge in links:
		if edge.to != root:
			continue
		if nodes[edge.from].kind == "premise":
			var branch = ancestors(edge.from)
			var line = {"id": edge.from, "label": title(edge.from), "relation": "supports", "cards": _evidence(branch), "positions": {}, "answers": {}, "assumption_sets": []}
			for id in branch:
				if nodes[id].kind == "premise":
					if nodes[id].conclusion.get("at", result.conclusion.at) == result.conclusion.at:
						line.assumption_sets.append(nodes[id].positions.duplicate(true))
			if not nodes[edge.from].conclusion.is_empty():
				line["conclusion"] = nodes[edge.from].conclusion.duplicate(true)
				if line.conclusion.type == "conflict":
					line.relation = "quotes"
			result.lines.append(line)
		else:
			direct.append_array(ancestors(edge.from))
	if not direct.is_empty():
		result.lines.append({"id": "direct", "label": "Direct supporting evidence", "relation": "supports", "cards": _evidence(direct), "positions": {}, "answers": {}})
	result.cards = _evidence(all)
	for id in all:
		var node: Dictionary = nodes[id]
		if node.kind == "evidence":
			result.answers.merge(node.answers.duplicate(true), true)
			if not node.has("merged"):
				result.reasons.merge(node.reasons.duplicate(true), true)
				result.citations.merge(node.citations.duplicate(true), true)
			else:
				for key in node.reasons:
					var reason: String = node.reasons[key]
					var cited: String = node.citations.get(key, "")
					if reason == "evil" or (reason in ["gift", "secret"] and cited in result.cards):
						result.reasons[key] = reason
						if cited != "":
							result.citations[key] = cited
			result.faults = Graph.combine_faults(result.faults, node.get("faults", {}))
		elif node.kind == "contradiction":
			result.disputes.append(node.dispute.duplicate(true))
		elif node.kind == "modifier":
			result.reading_challenges[node.card] = {"mode": node.mode, "supports": _evidence(ancestors(id)).filter(func(card): return card != node.card)}
		elif node.kind == "premise" and node.conclusion.get("type") == "conflict":
			var reports: Array = _evidence(ancestors(id))
			for home in reports:
				for out in reports:
					var dispute = {"reports": [home, out], "challenged": home, "preferred": out}
					if Graph.valid_dispute(view, dispute) and not result.disputes.has(dispute):
						result.disputes.append(dispute)
		if node.kind == "premise" and not node.positions.is_empty() and node.conclusion.get("at", result.conclusion.at) != result.conclusion.at:
			result.temporal_positions.append({"at": node.conclusion.at, "positions": node.positions.duplicate(true)})
	for edge in links:
		if edge.kind == "explains_outing" and edge.from in all and edge.to in all and nodes[edge.from].has("card") and nodes[edge.to].has("card"):
			var claim = Solver.card_by_id(view, nodes[edge.from].card)
			var observation = Solver.card_by_id(view, nodes[edge.to].card)
			var key = "%s:%d" % [claim.subject, observation.night]
			if not result.reasons.has(key):
				result.reasons[key] = "gift"
				result.citations[key] = claim.id
	if result.conclusion.type == "conflict":
		result.conflict_scope = result.cards.duplicate()
		result.disputes = [] # Ask whether contents conflict; do not resolve one first.
	if include_arguments:
		result["argument_root"] = root
		result["arguments"] = []
		for id in all:
			if nodes[id].kind != "premise" or nodes[id].conclusion.is_empty():
				continue
			var parents: Array = _argument_parents(id, all)
			parents.sort()
			var without = {}
			for parent in parents:
				without[parent] = _evidence(_ancestors_without(parent, id))
			result.arguments.append({"id": id, "label": title(id), "parents": parents, "without": without, "case": compile(id, false)})
		result.arguments.sort_custom(func(a, b): return a.id < b.id)
	return result

func _argument_parents(id: String, included: Array, seen: Array = []) -> Array:
	if id in seen:
		return []
	var visited = seen + [id]
	var result: Array = []
	for edge in links:
		if edge.from != id or edge.to not in included:
			continue
		if nodes[edge.to].kind == "premise" and not nodes[edge.to].conclusion.is_empty():
			if edge.to not in result:
				result.append(edge.to)
		else:
			for parent in _argument_parents(edge.to, included, visited):
				if parent not in result:
					result.append(parent)
	return result

func _ancestors_without(id: String, excluded: String, seen: Array = []) -> Array:
	if id == excluded or id in seen:
		return seen
	var result = seen + [id]
	for edge in links:
		if edge.to == id:
			result = _ancestors_without(edge.from, excluded, result)
	for child in nodes[id].get("children", []):
		result = _ancestors_without(child, excluded, result)
	return result

func _evidence(ids: Array) -> Array:
	var result: Array = []
	for id in ids:
		if nodes[id].kind == "evidence" and nodes[id].card not in result:
			result.append(nodes[id].card)
	result.sort()
	return result

## How each premise type reads after the person's name (the Workshop's claim menu).
const PREMISE_TEXT = {"evil": "is evil", "suspicious": "is suspicious", "good": "is good", "marked": "is Marked",
	"conflict": "these reports conflict", "demon": "is the Demon", "minion": "is a Minion",
	"notdemon": "is not the Demon", "secret_mod": "has a secret modifier", "role": "holds their claimed gift",
	"notrole": "is bluffing their claimed gift", "lied": "lied about a reading", "truthful": "told the truth about a reading",
	"misled": "was misled by a reading", "unreliable": "gave an unreliable reading"}

func title(id: String) -> String:
	var node: Dictionary = nodes[id]
	if node.kind == "premise":
		if node.get("draft", false):
			return "New premise"
		if node.conclusion.is_empty():
			return "Supporting evidence"
		if node.conclusion.type == "conflict":
			return "These reports conflict"
		return "%s %s" % [Solver.person_name(view, node.conclusion.target), PREMISE_TEXT.get(node.conclusion.type, "is " + node.conclusion.type)]
	if node.kind == "contradiction":
		return "Contradicted home alibi"
	if node.kind == "modifier":
		return {"misled": "Misled reading", "lying": "Suspected lie", "unlikely": "Unlikely reading"}[node.mode]
	var card = Solver.card_by_id(view, node.card)
	if card.has("relay_source"):
		return "Medium relay · " + (C.role_name(card.role) if card.get("role", "") != "" else card.kind.capitalize())
	if card.kind == "event":
		return "Public Martyr substitution" if card.get("event") == "martyr" else "Public death knell"
	return {"alibi": "Home alibi", "sighting": "Sighting", "claim": "Role claim"}.get(card.kind, C.role_name(card.role) if card.get("role", "") != "" else card.kind.capitalize())

func mockup() -> void:
	reset()
	var main: String = selected
	nodes[main].at = [600.0, 30.0]
	var hollis = add_premise("hollis", "evil", Vector2(250, 300))
	var suspicious = add_premise("constance", "suspicious", Vector2(1000, 300))
	for spec in [["survey", 80, 600], ["dowse", 420, 600], ["rumor", 250, 940], ["vigil1", 920, 620], ["alibi1", 1250, 620]]:
		nodes["e:" + spec[0]].at = [float(spec[1]), float(spec[2])]
	var spare = 0
	for id in nodes:
		if nodes[id].kind == "evidence" and nodes[id].card not in ["survey", "dowse", "rumor", "vigil1", "alibi1"]:
			nodes[id].at = [60.0 + (spare % 4) * 340.0, 1320.0 + (spare / 4) * 300.0]
			spare += 1
	for pair in [["e:rumor", "e:survey"], ["e:rumor", "e:dowse"], ["e:survey", hollis], ["e:dowse", hollis], [hollis, main], [suspicious, main]]:
		connect_cards(pair[0], pair[1])
	connect_cards("e:vigil1", "e:alibi1")
	var contradiction = selected
	nodes[contradiction].at = [1000.0, 650.0]
	connect_cards(contradiction, suspicious)
	selected = main

func export_data() -> Dictionary:
	return {"nodes": nodes.duplicate(true), "links": links.duplicate(true), "selected": selected, "version": version, "serial": serial}

func restore(value, session) -> String:
	if not value is Dictionary or not value.get("nodes") is Dictionary or value.nodes.size() > 48 or not value.get("links") is Array or value.links.size() > 160 or not value.get("selected") is String:
		return "Invalid canvas."
	for field in ["version", "serial"]:
		if not value.get(field) is float and not value.get(field) is int:
			return "Invalid canvas version."
		if not is_finite(float(value[field])) or float(value[field]) != float(int(value[field])) or value[field] < 1 or value[field] > 1000000:
			return "Invalid canvas version."
	var candidate = get_script().new(view)
	candidate.nodes = value.nodes.duplicate(true)
	candidate.links = []
	candidate.version = int(value.version)
	candidate.serial = int(value.serial)
	candidate.selected = value.selected
	var evidence: Array = []
	for id in candidate.nodes:
		var n = candidate.nodes[id]
		if not id is String or not n is Dictionary or n.get("id") != id or n.get("kind") not in ["evidence", "premise", "contradiction", "modifier"] or not n.get("at") is Array or n.at.size() != 2 or not n.at.all(func(x): return (x is float or x is int) and is_finite(float(x)) and absf(float(x)) <= 100000):
			return "Invalid canvas card or position."
		if n.kind == "evidence":
			if not n.get("card") is String or n.card in evidence or Solver.card_by_id(view, n.card).is_empty() or not n.get("answers") is Dictionary or not n.get("reasons") is Dictionary or not n.get("citations") is Dictionary:
				return "Invalid evidence copy."
			evidence.append(n.card)
			var choices = Solver.empty_case()
			choices.conclusion.at = view.alignment_epoch
			choices.cards = [n.card]
			choices.answers = n.answers
			choices.reasons = n.reasons
			choices.citations = n.citations
			choices.faults = n.get("faults", {})
			if session.validate_case(choices) != "" or not n.answers.keys().all(func(key): return key == n.card):
				return "Invalid canvas answers."
		elif n.kind == "premise":
			if not n.get("conclusion") is Dictionary or not n.get("positions") is Dictionary:
				return "Invalid premise."
			var choices = Solver.empty_case()
			choices.conclusion.at = view.alignment_epoch
			choices.positions = n.positions
			if not n.conclusion.is_empty():
				choices.conclusion = n.conclusion
			if session.validate_case(choices) != "":
				return "Invalid premise choices."
		elif n.kind == "modifier":
			if not preload("res://workshop/reading_challenges.gd").valid(view, n.get("card", ""), {"mode": n.get("mode"), "supports": []}):
				return "Invalid reading modifier."
		elif not Graph.valid_dispute(view, n.get("dispute")) or not n.get("children") is Array or n.children.size() != 2 or not n.get("prior_links") is Array or n.prior_links.size() > 160:
			return "Invalid contradiction provenance."
	for id in candidate.nodes:
		var n: Dictionary = candidate.nodes[id]
		if n.has("merged") and (not candidate.nodes.has(n.merged) or candidate.nodes[n.merged].kind != "contradiction" or id not in candidate.nodes[n.merged].children):
			return "Invalid merged card."
		if n.kind == "contradiction":
			if n.children[0] == n.children[1] or not n.children.all(func(child): return candidate.nodes.has(child) and candidate.nodes[child].kind == "evidence" and candidate.nodes[child].get("merged") == id) or n.children.map(func(child): return candidate.nodes[child].card).any(func(card): return card not in n.dispute.reports):
				return "Invalid contradiction roots."
			for edge in n.prior_links:
				if not edge is Dictionary or not candidate.nodes.has(edge.get("from")) or not candidate.nodes.has(edge.get("to")) or edge.get("kind") not in ["supports", "read_together", "explains_outing"] or (edge.from not in n.children and edge.to not in n.children) or edge.from == edge.to:
					return "Invalid original contradiction links."
	for edge in value.links:
		if not edge is Dictionary or not candidate.nodes.has(edge.get("from")) or not candidate.nodes.has(edge.get("to")) or edge.get("kind") not in ["supports", "read_together", "explains_outing"] or candidate.nodes[edge.from].has("merged") or candidate.nodes[edge.to].has("merged") or candidate._reaches(edge.to, edge.from):
			return "Invalid or circular canvas link."
		if edge.kind == "explains_outing":
			if not candidate._gift_link(candidate.nodes[edge.from], candidate.nodes[edge.to]):
				return "Invalid gift explanation."
		candidate.links.append(edge.duplicate(true))
	if not candidate.nodes.has(candidate.selected):
		return "Invalid selected card."
	nodes = candidate.nodes
	links = candidate.links
	selected = candidate.selected
	version = candidate.version
	serial = candidate.serial
	return ""

## One click on an evidence card's answer, as a pure update of that card's answer:
## kind "pick" (a face), "block" / "resident" (Surveyor), "reg" (Seer registration).
## Dowser and Surveyor faces cycle ? -> registered -> registered as Marked -> ?.
func apply_answer(card: Dictionary, previous: Dictionary, kind: String, value: String) -> Dictionary:
	var answer: Dictionary = previous.duplicate(true)
	var positive: Array = answer.get("positive", []).duplicate()
	var marked: Array = answer.get("marked", []).duplicate()
	var role: String = card.get("role", "")
	var count: int = 1
	if card.kind == "report" and role in ["dowser", "lamplighter", "surveyor"]:
		count = int(card.data.get("count", 0))
	match kind:
		"reg":
			answer["registration"] = value
		"pick":
			if role == "dowser":
				# ? -> registered (evil or Marked) -> registered as Marked -> ?
				if value not in positive:
					if positive.size() < count:
						positive.append(value)
				elif value not in marked:
					marked = [value]
				else:
					positive.erase(value)
					marked.erase(value)
			elif value in positive:
				positive.erase(value)
			elif positive.size() < count:
				positive.append(value)
			elif count == 1:
				positive = [value]
			answer["slots"] = positive.duplicate()
		"block", "resident":
			var blocks: Array = answer.get("blocks", []).duplicate()
			var block: String = value
			if kind == "resident":
				for person in view.people:
					if person.id == value:
						block = person.home
			var residents: Array = view.people.filter(func(p): return p.home == block).map(func(p): return p.id)
			var used: int = blocks.size() + positive.size()
			if kind == "block":
				if block in blocks:
					blocks.erase(block)
				elif residents.any(func(p): return p in positive):
					for p in residents:
						positive.erase(p)
						marked.erase(p)
				elif used < count:
					blocks.append(block)
			elif value in positive:
				if value not in marked:
					marked = [value]
				else:
					positive.erase(value)
					marked.erase(value)
			else:
				var had_block: bool = block in blocks or residents.any(func(p): return p in positive)
				blocks.erase(block)
				for p in residents:
					positive.erase(p)
					marked.erase(p)
				if had_block or blocks.size() + positive.size() < count:
					positive.append(value)
			answer["blocks"] = blocks
			var keys: Array = C.BLOCKS.keys()
			if count == 4:
				answer["slots"] = keys.map(func(b): return ("block:" + b) if b in blocks else _first_of(positive, view.people.filter(func(p): return p.home == b).map(func(p): return p.id)))
			else:
				answer["slots"] = blocks.map(func(b): return "block:" + b) + positive
	marked = marked.filter(func(p): return p in positive)
	answer["positive"] = positive
	if marked.is_empty():
		answer.erase("marked")
	else:
		answer["marked"] = marked
	return answer


func _first_of(values: Array, candidates: Array) -> String:
	for v in values:
		if v in candidates:
			return v
	return ""
