## Restricted live comparison. Pure inputs/outputs; no simulation objects or effects.
extends RefCounted
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")
const Domain = preload("res://workshop/world_domain.gd")
const LedgerAudit = preload("res://workshop/ledger_audit.gd")
const C = preload("res://sim/content.gd")
const ROLES = ["surveyor", "rumormonger", "dowser", "clerk", "archivist", "seer", "nightwatch", "gravedigger", "veteran", "lamplighter", "medium", "martyr", "sexton", "psychologist"]
const Evidence = preload("res://workshop/live_evidence.gd")
const History = preload("res://workshop/live_history.gd")
const CONCLUSIONS = ["evil", "good", "marked", "suspicious", "conflict", "demon", "minion"]

## mixture_budget: apply the old 2^u mixture's 64-state gate, on the legacy engine only
## (CaseEval has no such limit, so no listener falls back to native rules over it).
static func prepare(snapshot: Dictionary, mixture_budget: bool = true) -> Dictionary:
	var result = {"ready": false, "issues": [], "view": {}, "case": {}, "listener": {},
		"scope": "Conditional report comparison with legal original alignment/modifier worlds and public event timing. Accepting a report assumes a good, correctly claimed, healthy source. Live movement and traces use experimental activity priors; quiet nights supply bounded circumstantial support. Medium relays retain separate original and transmission credibility. Alignment-transition histories remain unsupported. Venue is recorded; proposed effects use the unscaled Workshop response."}
	if snapshot.get("format") != "demonologist-live-evidence-1":
		result.issues.append("Unknown live evidence format.")
		return result
	if snapshot.listener.is_empty():
		result.issues.append("Select a listener with an available good or cover mind.")
	if snapshot.people.size() not in [7, 10]:
		result.issues.append("Only seven- and ten-person live setups are profiled.")
	for issue in snapshot.issues:
		if issue.code in ["missing_card", "cyclic_argument", "argument_depth", "unknown_listener", "cover_unavailable", "invalid_venue"]:
			result.issues.append(issue.code + ": " + issue.detail)
	if snapshot.public_events.any(func(e): return e.kind in ["curse", "curse_lifted"]):
		result.issues.append("This live case has alignment-transition history that needs a temporal adapter.")
	var needed: Array = snapshot.selected.duplicate()
	for id in snapshot.private_evidence:
		if id not in needed:
			needed.append(id)
	var cards: Array = []
	for e in snapshot.evidence:
		if e.id not in needed:
			continue
		if e.kind in ["opinion", "accusation"]:
			result.issues.append("An %s is not evidence. Cite the supporting observations or readings." % e.kind)
			continue
		if e.kind == "info" and e.content.get("anonymous", false):
			result.issues.append("The anonymous %s reading has no identified original source. A named acknowledgement is needed before shared assessment." % C.role_name(e.content.get("role", "")))
			continue
		if e.kind == "claim" and e.content.get("role") in C.GOOD_ROLES and e.source in snapshot.people.map(func(p): return p.id) and e.subjects == [e.source]:
			cards.append({"id": e.id, "fact_id": e.fact_id, "kind": "claim", "source": e.source,
				"subject": e.source, "role": e.content.role, "data": {}, "observed_at": e.observed_at, "text": e.text})
			continue
		if e.id not in snapshot.selected and e.kind == "sighting":
			continue # Own sightings enter only through a separately learned owner.
		if e.id not in snapshot.selected and e.kind == "info" and e.content.get("role", "") not in ROLES:
			continue # Independent unsupported readings keep their native baseline owner.
		if e.kind == "info" and e.content.get("role") == "medium":
			if e.content.get("data", {}).get("item", {}).get("type") == "suspicion":
				if e.id in snapshot.selected:
					result.issues.append("A relayed opinion is not evidence. Cite the deceased person's supporting observations or readings.")
				continue
			var relay = medium_card(e, snapshot)
			if relay.is_empty():
				if e.id not in snapshot.selected:
					continue # Independent unsupported knowledge keeps its native owner.
				result.issues.append("Medium relay needs supported original evidence, an original observation time, and a publicly deceased source. Nested Medium chains and opinions remain unsupported.")
			else:
				cards.append(relay)
			continue
		var activity = activity_card(e, snapshot)
		if not activity.is_empty():
			cards.append(activity)
			continue
		if e.kind != "info" or e.content.get("role", "") not in ROLES:
			if e.kind in ["home", "haunt", "conversation", "sighting", "alibi", "totem", "dropped", "trace", "vigil", "quiet", "death", "execution", "martyr", "knell", "secret", "silenced", "refusal", "hint", "vote"]:
				result.issues.append("Incomplete or invalid %s card (%s)." % [e.kind, e.id])
			else:
				result.issues.append("The %s card%s isn't supported yet (%s)." % [e.kind, " (" + str(e.content.get("role")) + ")" if e.content.has("role") else "", e.id])
			continue
		var data: Dictionary = e.content.data
		var ids: Array = snapshot.people.map(func(p): return p.id)
		var role: String = e.content.role
		var valid = reading_valid(e, ids, snapshot.rules.modifier_options)
		if not valid:
			result.issues.append("Incomplete or invalid reading payload: " + e.id)
			continue
		cards.append({"id": e.id, "fact_id": e.fact_id, "kind": "report", "source": e.source, "role": role,
			"data": data.duplicate(true), "night": e.observed_at.day if e.observed_at.phase == "night" or role in ["martyr", "sexton"] else -1,
			"observed_at": e.observed_at, "reported_at": e.reported_at, "learned_at": e.learned_at,
			"acquired_day": e.learned_at.day if e.learned_at != null else e.observed_at.day,
			"provenance": e.provenance, "text": e.text})
	# A direct copy and a Medium relay share original health but have separate
	# hearing routes. Keep health keys apart from receipt ids before route weighting.
	var relayed_origins: Array = cards.filter(func(c): return c.has("relay_source")).map(func(c): return c.logical_origin)
	for card in cards:
		if card.has("relay_source"):
			card.accuracy_origin = "health:" + card.logical_origin
		elif card.kind == "report" and card.id in relayed_origins:
			card["logical_origin"] = card.id
			card["accuracy_origin"] = "health:" + card.id
			card["route_origin"] = card.id
	if not cards.any(func(c): return c.id in snapshot.selected):
		result.issues.append("No supported reading is presented.")
	if Jury.engine == "legacy" and (cards.size() > 8 or snapshot.arguments.size() > 6):
		result.issues.append("This comparison exceeds the initial eight-reading / six-claim workload budget.")
	# Supported questions concern original alignment. Advancing the day must not
	# silently create a fresh theory and discard yesterday's commitment.
	var epoch: String = "Original alignment"
	var view = {"seed": 0, "day": snapshot.now.day, "people": snapshot.people.duplicate(true), "cards": cards,
		"evil_count": snapshot.rules.initial_evil_count, "alignment_epoch": epoch, "history": [],
		"world_options": {"modifiers": snapshot.rules.modifier_options.duplicate()}, "scope": result.scope,
		"timeline": History.from_events(snapshot.public_events)}
	if cards.any(func(c): return c.has("relay_source") or c.kind in ["sighting", "alibi", "coverage", "evening", "trace", "dropped", "quiet", "event", "secret_claim"] or c.get("role") in ["nightwatch", "veteran", "lamplighter", "sexton", "martyr"]):
		view["live_activity"] = true
		view.world_options["roles"] = true
		view.world_options["identities"] = true
	for card in cards:
		if card.kind == "report" and card.get("role") == "gravedigger" and not History.executed(view, card.data.executed, card.night):
			result.issues.append("Gravedigger report needs a matching public execution on the reported night.")
		if card.kind == "report" and card.get("role") == "martyr" and card.data.get("chosen", false) and cards.any(func(other): return other.kind == "execution" and other.subject == card.data.target and Solver.TimeModel.tick(other.observed_at) > Solver.TimeModel.tick(card.observed_at)):
			result.issues.append("A prior Martyr promise versus a later execution needs a dated outcome/health adapter. The new evaluator does not yet infer failure from that pair; existing rules handle the case.")
	if cards.any(func(c): return c.has("relay_source") or c.kind in ["claim", "totem"] or c.get("role", "") in ["clerk", "archivist", "seer", "gravedigger", "nightwatch"]):
		view.world_options["roles"] = true
	if cards.any(func(c): return c.kind == "totem" or c.get("role", "") in ["archivist", "seer", "gravedigger"]) or snapshot.arguments.any(func(a): return a.conclusion.get("type") in ["demon", "minion"] or a.get("workshop_case", {}).get("arguments", []).any(func(q): return q.case.conclusion.type in ["demon", "minion"])):
		view.world_options["identities"] = true
		view.world_options["roles"] = true
	var root: Dictionary = snapshot.arguments.filter(func(a): return a.board_number == snapshot.root)[0] if snapshot.arguments.any(func(a): return a.board_number == snapshot.root) else {}
	if root.is_empty():
		result.issues.append("Select a filed deduction as the comparison's headline claim.")
	else:
		for argument in snapshot.arguments:
			if not argument.has("workshop_case"):
				continue
			var scope = snapshot.duplicate(false)
			scope.selected = _argument_roots(snapshot, argument.board_number)
			result.issues.append_array(canvas_issues(argument.workshop_case, scope))
			for dispute in argument.workshop_case.get("disputes", []):
				if not Solver.Graph.valid_dispute(view, dispute):
					result.issues.append("Invalid or unsupported disputes: cite a home alibi and a sighting of that person on the same night.")
			for id in argument.workshop_case.get("reading_challenges", {}):
				var challenge = argument.workshop_case.reading_challenges[id]
				if not preload("res://workshop/reading_challenges.gd").valid(view, id, challenge) or id not in argument.workshop_case.cards or not challenge.get("supports", []).all(func(s): return s in argument.workshop_case.cards):
					result.issues.append("Invalid reading challenge or missing grounds.")
		var value = _case(snapshot, root, epoch, [], result.issues)
		value["arguments"] = []
		for argument in snapshot.arguments:
			var scoped = _case(snapshot, argument, epoch, [], result.issues)
			var inputs: Array = []
			var direct: Array = argument.supports.filter(func(number): return snapshot.board_map.has(str(number))).map(func(number): return snapshot.board_map[str(number)])
			if not direct.is_empty():
				inputs.append({"id": "direct:%d" % argument.board_number, "cards": direct})
			for child in snapshot.arguments.filter(func(a): return a.board_number in argument.supports):
				inputs.append({"id": "argument:%d" % child.board_number, "cards": _case(snapshot, child, epoch, [], result.issues).cards})
			value.arguments.append({"id": "argument:%d" % argument.board_number, "label": "Filed claim #%d" % argument.board_number,
				"case": scoped, "inputs": inputs, "parents": snapshot.arguments.filter(func(a): return argument.board_number in a.supports).map(func(a): return "argument:%d" % a.board_number)})
		for argument in snapshot.arguments:
			if argument.has("workshop_case") and argument.board_number != root.board_number:
				_append_canvas_arguments(value.arguments, argument)
		result.case = value
		if root.has("workshop_case"):
			result.case = root.workshop_case.duplicate(true)
			result.case.id = "live:" + snapshot.case_id
			result.view = view
			view.alignment_epoch = "Original alignment"
		for argument in snapshot.arguments:
			var conclusion = argument.conclusion
			if conclusion.get("type") not in CONCLUSIONS or _target(conclusion) not in snapshot.people.map(func(p): return p.id):
				result.issues.append("Unsupported claim: " + str(conclusion.get("type", "unknown")))
		if not snapshot.listener.is_empty():
			result.listener = _listener(snapshot, cards)
			if not result.listener.knowledge.get("public_roles", {}).is_empty():
				view.world_options["roles"] = true
			var uncertain = cards.filter(func(c): return c.source != snapshot.listener.id).map(func(c): return c.source)
			var sources = {}
			for source in uncertain:
				sources[source] = true
			var discounts: int = result.listener.reading_reliability.values().filter(func(v): return v > 0 and v < 1).size()
			var dimensions: int = Jury.Support.dimensions(cards, result.listener, result.case.get("reading_challenges", {})) if view.world_options.get("roles", false) or not result.case.get("reading_challenges", {}).is_empty() else sources.size() + discounts
			if mixture_budget and Jury.engine == "legacy" and dimensions > 6:
				result.issues.append("This comparison exceeds the initial 64-state credibility budget.")
	result.view = view
	result.ready = result.issues.is_empty()
	return result

## Live activity receipts keep their exact original identity. Old trace cards without
## a structured scene cannot be reconstructed from prose or hidden scene records.
static func activity_card(e: Dictionary, snapshot: Dictionary) -> Dictionary:
	var ids: Array = snapshot.people.map(func(p): return p.id)
	var block: String = e.content.get("block", "")
	var night: int = e.observed_at.day
	var card = {"id": e.id, "fact_id": e.fact_id, "source": e.source, "text": e.text,
		"subject": e.subjects[0] if not e.subjects.is_empty() else "", "subjects": e.subjects.duplicate(),
		"night": night, "observed_at": e.observed_at, "block": block, "role": "", "data": {}}
	if e.kind == "hint" and e.source in ids and e.subjects == [e.source] and night >= 0 and e.observed_at.phase != "unknown" and e.content.get("package", "") in C.HINT_PACKAGES:
		var roles: Array = C.HINT_PACKAGES[e.content.package].roles
		var stated = e.content.get("roles", roles)
		if not stated is Array or stated.size() != roles.size() or not stated.all(func(role): return role in roles) or not roles.all(func(role): return role in stated):
			return {}
		card["kind"] = "gift_hint"
		card["night"] = -1 # A family hint does not identify a role or prove activity.
		card["data"] = {"package": e.content.package, "roles": roles.duplicate()}
		return card
	if e.kind == "refusal" and e.source in ids and e.subjects == [e.source] and night >= 0 and e.observed_at.phase != "unknown":
		if not e.content.get("fear", false) is bool or not e.content.get("withheld", false) is bool or (e.content.get("role", "") != "" and e.content.role not in C.ROLES):
			return {}
		card["kind"] = "refusal"
		card["night"] = -1 # Refusing whereabouts is not an admission of an outing.
		card["data"] = {"fear": e.content.get("fear", false), "withheld": e.content.get("withheld", false), "role": e.content.get("role", "")}
		return card
	if e.kind == "info" and e.content.get("role", "") == "psychologist" and reading_valid(e, ids, snapshot.rules.modifier_options):
		card["kind"] = "context"
		card["context_kind"] = "psychologist"
		card["role"] = "psychologist"
		card["data"] = e.content.data.duplicate(true)
		return card # Opinions are context, even when the gift reports them accurately.
	if e.kind == "secret" and e.source in ids and e.subjects.size() == 1 and e.subjects[0] in ids and e.content.get("owner", "") == e.subjects[0]:
		if e.content.get("secret_kind", "") not in C.SECRETS.map(func(secret): return secret.kind) + ["lover"] or e.observed_at.day < 0 or e.observed_at.phase == "unknown" or (block != "" and block not in C.BLOCKS):
			return {}
		card["kind"] = "secret_claim"
		card["night"] = -1 # Confessing an explanation does not prove an outing.
		card["applies"] = {"from": night if e.observed_at.phase == "night" else 0, "through": night if e.observed_at.phase == "night" else snapshot.now.day}
		card["data"] = {"secret_kind": e.content.secret_kind}
		return card
	if e.kind in ["home", "haunt"] and e.subjects.size() == 1 and e.subjects[0] in ids:
		if e.kind == "home" and (block not in C.BLOCKS or snapshot.people.filter(func(p): return p.id == e.subjects[0])[0].home != block):
			return {}
		if e.kind == "haunt" and (not e.content.get("locs") is Array or e.content.locs.is_empty() or not e.content.locs.all(func(loc): return loc in C.LOCATIONS)):
			return {}
		card["kind"] = "context"
		card["context_kind"] = e.kind
		card["data"] = e.content.duplicate(true)
		return card # Public homes / reported haunts describe routes, not guilt.
	if night < 0:
		return {}
	if e.kind == "vote" and e.source == "player" and e.observed_at.phase == "evening" and night >= 1:
		var content: Dictionary = e.content
		if content.get("nominee", "") not in ids or content.get("by", "") not in ids + ["player"] or not content.get("yes") is Array or not content.get("no") is Array or not content.get("player_yes") is bool:
			return {}
		var voters: Array = content.yes + content.no
		if voters.is_empty() or not _group_valid(voters, ids) or content.get("count") != content.yes.size() + (1 if content.player_yes else 0) or not _count_valid(content.get("threshold"), ids.size() + 1) or content.threshold < 1 or content.get("outcome", "") not in ["fails", "on_block", "tie", "short_of_block"]:
			return {}
		var subjects: Array = []
		for person in content.yes + [content.nominee]:
			if person not in subjects:
				subjects.append(person)
		if not e.subjects.all(func(person): return person in subjects) or not subjects.all(func(person): return person in e.subjects):
			return {}
		if not snapshot.public_events.any(func(event): return event.kind == "vote" and event.at.day == night and event.get("data", {}).get("nominee") == content.nominee and event.get("data", {}).get("nominator") == content.by and event.get("data", {}).get("yes") == content.yes and event.get("data", {}).get("no") == content.no and event.get("data", {}).get("player_yes") == content.player_yes and event.get("data", {}).get("count") == content.count and event.get("data", {}).get("threshold") == content.threshold and event.get("data", {}).get("outcome") == content.outcome):
			return {}
		card["kind"] = "context"
		card["context_kind"] = "vote"
		card["data"] = {"nominee": content.nominee, "nominator": content.by, "yes": content.yes.duplicate(), "no": content.no.duplicate(), "player_yes": content.player_yes, "count": content.count, "threshold": content.threshold, "outcome": content.outcome}
		return card # Public procedure, not guilt by association or majority vote.
	if e.kind == "silenced" and e.source == "player" and e.observed_at.phase == "evening" and night >= 1 and e.subjects.size() == 1 and e.subjects[0] in ids:
		if not snapshot.public_events.any(func(event): return event.kind == "silenced" and event.at.day == night and e.subjects[0] in event.subjects):
			return {}
		card["kind"] = "context"
		card["context_kind"] = "silenced"
		return card # The public event supplies its one finite factor, even uncited.
	if e.kind == "death" and e.source == "player" and e.observed_at.phase == "night" and night >= 1 and e.subjects.size() == 1 and e.subjects[0] in ids:
		if block != "" and block != snapshot.people.filter(func(p): return p.id == e.subjects[0])[0].home:
			return {}
		if not snapshot.public_events.any(func(event): return event.kind == "demon_death" and event.at == e.observed_at and e.subjects[0] in event.subjects):
			return {}
		# The public event already informs chronology and the listener's view.
		# Citing its card retains that receipt without awarding it a second time.
		card["kind"] = "context"
		card["context_kind"] = "death"
		return card
	if e.kind == "totem" and e.source == "evidence" and block in C.BLOCKS:
		card["kind"] = "totem"
		card["data"] = {"candidates": snapshot.people.filter(func(p): return p.home == block).map(func(p): return p.id)}
		return card if not card.data.candidates.is_empty() else {}
	if e.kind == "dropped" and e.source == "evidence" and e.observed_at.phase == "night" and block in C.BLOCKS and e.content.get("material") in C.BLOCKS:
		card["kind"] = "dropped"
		card["data"] = {"material": e.content.material}
		return card
	if e.kind in ["sighting", "conversation"] and e.observed_at.phase in ["morning", "afternoon", "evening"] and not e.subjects.is_empty() and e.subjects.all(func(id): return id in ids) and block in C.BLOCKS:
		if e.kind == "conversation" and e.subjects.size() != 2:
			return {}
		if e.content.get("loc", "") in C.LOCATIONS and C.LOCATIONS[e.content.loc].block != block:
			return {}
		card["kind"] = "evening" if e.observed_at.phase == "evening" else "location"
		card["night"] = night if card.kind == "evening" else -1
		return card
	if e.kind in ["sighting", "alibi"] and not e.subjects.is_empty() and e.subjects.all(func(id): return id in ids):
		if e.observed_at.phase == "night" or (e.kind == "sighting" and e.observed_at.phase == "evening" and block in C.BLOCKS):
			card["kind"] = "evening" if e.observed_at.phase == "evening" else e.kind
			if e.kind == "sighting" and e.source == "player" and e.content.get("vigil", false) and e.observed_at.phase == "night":
				card["complete"] = true
				card["excluded"] = []
				for event in snapshot.public_events:
					if event.kind == "demon_death" and event.at.day == night:
						card.excluded.append_array(event.subjects)
			if e.content.has("guard_claim"):
				if e.content.guard_claim not in ids or e.subjects != [e.source] or snapshot.people.filter(func(p): return p.id == e.content.guard_claim)[0].home != block:
					return {}
				card["guard_claim"] = e.content.guard_claim
			if e.content.get("dropped", false) and e.source == "evidence" and e.subjects.size() == 1:
				card["item_drop"] = true
			return card
	if e.kind == "quiet" and e.source == "player" and e.observed_at.phase == "night" and night >= 1:
		card["kind"] = "quiet"
		card["ward"] = e.content.get("ward", "")
		return card
	if e.kind in ["execution", "martyr", "knell"] and e.source == "player" and e.observed_at.phase == "evening" and night >= 1:
		if e.kind == "execution" and e.subjects.size() == 1 and e.subjects[0] in ids:
			card["kind"] = "execution"
			return card
		if e.kind == "martyr" and e.subjects.size() == 2 and e.subjects[0] != e.subjects[1] and e.subjects.all(func(person): return person in ids):
			if e.content.get("martyr") not in e.subjects or e.content.get("saved") not in e.subjects or e.content.martyr == e.content.saved or not snapshot.public_events.any(func(event): return event.kind == "martyr" and event.at.day == night and event.get("by") == e.content.martyr and e.content.saved in event.subjects):
				return {}
			card["kind"] = "event"
			card["event"] = "martyr"
			card["data"] = {"martyr": e.content.martyr, "saved": e.content.saved}
			return card
		if e.kind == "knell":
			card["kind"] = "event"
			card["event"] = "knell"
			return card
	if e.kind == "vigil" and e.observed_at.phase == "night" and block in C.BLOCKS and e.source == "player" and e.subjects.is_empty():
		card["kind"] = "coverage"
		card["excluded"] = []
		for event in snapshot.public_events:
			if event.kind == "demon_death" and event.at.day == night:
				card.excluded.append_array(event.subjects)
		return card
	if e.kind == "trace" and e.source == "evidence" and e.content.get("crime_night") == night and e.content.get("material") in C.BLOCKS and e.content.get("scene_block") in C.BLOCKS and e.content.get("victim") in ids and e.content.get("scene", "") != "":
		if snapshot.public_events.any(func(event): return event.kind == "demon_death" and event.at.day == night and e.content.victim in event.subjects) and snapshot.people.filter(func(p): return p.id == e.content.victim)[0].home == e.content.scene_block:
			card["kind"] = "trace"
			card["data"] = {"material": e.content.material, "scene_block": e.content.scene_block, "victim": e.content.victim, "scene": e.content.scene}
			return card
	return {}

static func medium_card(e: Dictionary, snapshot: Dictionary) -> Dictionary:
	if e.kind != "info" or e.content.get("role") != "medium" or e.source not in snapshot.people.map(func(p): return p.id) or e.observed_at.phase != "night":
		return {}
	var data: Dictionary = e.content.data
	var dead: String = data.get("dead", "")
	if dead not in snapshot.people.map(func(p): return p.id) or History.alive_at_night({"timeline": History.from_events(snapshot.public_events)}, dead, e.observed_at.day):
		return {}
	var item: Dictionary = data.get("item", {})
	var raw: Dictionary = {"source": dead, "subject": [], "text": e.text}
	if item.get("type") == "reading" and item.get("entry") is Dictionary:
		var entry: Dictionary = item.entry
		if entry.get("role") not in ROLES or entry.role == "medium" or not entry.get("day") is int and not entry.get("day") is float:
			return {}
		raw.merge({"kind": "info", "role": entry.role, "day": int(entry.day), "phase": entry.get("phase", 3), "data": entry.get("data", {}), "text": entry.get("text", "")}, true)
	elif item.get("type") in ["sighting", "home", "guard"] and (item.get("night") is int or item.get("night") is float):
		raw.merge({"kind": "alibi" if item.type == "home" else "sighting", "day": int(item.night), "phase": 3}, true)
		if item.type == "sighting":
			raw.subject = [item.get("who", "")]
			raw["block"] = item.get("block", "")
		else:
			raw.subject = [dead]
			var resident: String = item.get("who", "") if item.type == "guard" else dead
			if resident not in snapshot.people.map(func(p): return p.id):
				return {}
			raw["block"] = snapshot.people.filter(func(p): return p.id == resident)[0].home
			if item.type == "guard":
				raw["guard_claim"] = resident
	else:
		return {}
	var original = Evidence.normalize_card(raw)
	if Solver.TimeModel.tick(original.observed_at) >= Solver.TimeModel.tick(e.observed_at):
		return {}
	if not History.observer_alive({"timeline": History.from_events(snapshot.public_events)}, dead, original.observed_at):
		return {}
	var card: Dictionary
	if raw.kind == "info":
		if not reading_valid(original, snapshot.people.map(func(p): return p.id), snapshot.rules.modifier_options) or not Domain.gift_time({"role": raw.role, "observed_at": original.observed_at}):
			return {}
		if raw.role == "psychologist":
			var context = activity_card(original, snapshot)
			context.merge({"id": e.id, "fact_id": e.fact_id, "source": e.source, "role": "", "text": e.text,
				"original_source": dead, "original_role": raw.role, "provenance": e.provenance.duplicate(true)}, true)
			return context # Relay fidelity supplies no alignment likelihood for an opinion.
		card = {"kind": "report", "source": dead, "role": raw.role, "data": raw.data, "subject": "", "subjects": original.subjects,
			"night": original.observed_at.day if original.observed_at.phase == "night" or raw.role in ["martyr", "sexton"] else -1, "observed_at": original.observed_at, "reported_at": original.observed_at}
	else:
		card = activity_card(original, snapshot)
		if card.is_empty():
			return {}
	card.merge({"id": e.id, "fact_id": e.id, "logical_origin": original.id, "accuracy_origin": original.id,
		"relay_source": e.source, "relay_observed_at": e.observed_at, "relay_role": "medium", "text": e.text,
		"learned_at": e.learned_at if e.learned_at != null else e.observed_at, "acquired_day": e.observed_at.day}, true)
	return card

## Explicit capability gate: no graph feature may silently disappear when the
## restricted live evaluator replaces the native argument path.
static func canvas_issues(value: Dictionary, snapshot: Dictionary) -> Array:
	var issues: Array = []
	if value.cards != snapshot.selected and not (value.cards.size() == snapshot.selected.size() and value.cards.all(func(id): return id in snapshot.selected)):
		issues.append("Canvas roots differ from the original evidence receipts.")
	for field in ["faults", "temporal_positions", "derived", "challenges"]:
		if not value.get(field, {}).is_empty():
			issues.append("Not yet handled by the live evaluator: " + field + ".")
	for key in value.get("reasons", {}):
		if not value.reasons[key] is String or value.reasons[key] not in ["unexplained", "gift", "evil", "secret"]:
			issues.append("Unsupported reasons: " + str(value.reasons[key]))
	for key in value.get("citations", {}):
		if not value.citations[key] is String:
			issues.append("Invalid activity citations: choose a supported claim.")
			continue
		var cited: Array = snapshot.evidence.filter(func(e): return e.id == value.citations[key] and e.kind in ["claim", "secret"])
		var valid: bool = not cited.is_empty() and value.citations[key] in value.cards
		if valid and cited[0].kind == "secret":
			var context = activity_card(cited[0], snapshot)
			var parts: PackedStringArray = str(key).split(":")
			valid = not context.is_empty() and parts.size() == 2 and parts[0] == context.subject and parts[1].is_valid_int() and int(parts[1]) >= context.applies.from and int(parts[1]) <= context.applies.through
		elif valid:
			valid = C.ROLES.get(cited[0].content.get("role", ""), {}).get("night_walk", false) and str(key).begins_with(cited[0].source + ":")
		if not valid:
			issues.append("Activity citations need an included walking-role or applicable secret claim for that person.")
	var claims: Array = [value] + value.get("arguments", []).map(func(a): return a.case)
	if claims.size() > 7:
		issues.append("Canvas exceeds the initial six-claim budget.")
	for argument in value.get("arguments", []):
		if argument.id == value.get("argument_root") or argument.case.conclusion.type != "conflict":
			continue
		# The shared owner can distinguish quoted roots, but the scoped response's
		# attention still excludes them. Flag the missing joint interpretation.
		if argument.case.get("disputes", []).is_empty():
			issues.append("Embedded conflict questions need a live quoted-evidence assessment adapter; present the conflict as its own headline to use the new evaluator.")
	var fields: Array = Solver.empty_case().keys() + ["arguments", "argument_root"]
	for claim in claims:
		for field in claim:
			if field not in fields:
				issues.append("Unrecognized canvas feature needs a live adapter: " + str(field) + ".")
		if claim.conclusion.get("type") not in CONCLUSIONS or claim.conclusion.get("target") not in snapshot.people.map(func(p): return p.id) or claim.conclusion.get("at") != "Original alignment":
			issues.append("Unsupported canvas claim or alignment time.")
		for line in claim.get("lines", []):
			if line.get("relation", "supports") not in ["supports", "quotes"] or line.has("test_factor"):
				issues.append("This reasoning-line relationship/factor has no live adapter.")
	for receipt in snapshot.evidence:
		if receipt.id in snapshot.selected and receipt.kind == "info" and receipt.content.get("role") in ROLES:
			if not Domain.gift_time({"role": receipt.content.role, "observed_at": receipt.observed_at}):
				issues.append("Reading time is outside the live adapter's supported gift interval: " + receipt.content.role + ".")
	return issues

static func evaluate(snapshot: Dictionary) -> Dictionary:
	var started = Time.get_ticks_msec()
	var prepared = prepare(snapshot)
	var result = {"ready": prepared.ready, "issues": prepared.issues, "scope": prepared.scope,
		"format": "demonologist-live-comparison-1", "listener": snapshot.get("listener", {}).get("id", ""),
		"proposal": {}, "elapsed_ms": 0}
	result["ledger_audit"] = LedgerAudit.inspect(snapshot)
	if not result.ledger_audit.aliases.is_empty():
		result.ready = false
		result.issues.append("Several statements share an unresolved original reading identity; numeric comparison is deferred.")
	if result.ready:
		result.proposal = Jury.evaluate(prepared.view, prepared.case, prepared.listener, {"venue": snapshot.venue})
		result["world_count"] = Domain.worlds(prepared.view).size()
	result.elapsed_ms = Time.get_ticks_msec() - started
	return result

## Original board receipts, independently of a stored canvas's claimed root list.
static func _argument_roots(snapshot: Dictionary, number: int, path: Array = []) -> Array:
	if number in path:
		return []
	if snapshot.board_map.has(str(number)):
		return [snapshot.board_map[str(number)]]
	var found: Array = snapshot.arguments.filter(func(a): return a.board_number == number)
	var result: Array = []
	if not found.is_empty():
		for support in found[0].supports:
			for id in _argument_roots(snapshot, support, path + [number]):
				if id not in result:
					result.append(id)
	return result

static func _canvas_argument_id(argument: Dictionary, id: String) -> String:
	return "argument:%d" % argument.board_number if id == argument.workshop_case.get("argument_root", "") else "canvas:%d:%s" % [argument.board_number, id]

static func _has_canvas(snapshot: Dictionary, number: int, path: Array = []) -> bool:
	if number in path:
		return false
	var found: Array = snapshot.arguments.filter(func(a): return a.board_number == number)
	return not found.is_empty() and (found[0].has("workshop_case") or found[0].supports.any(func(child): return _has_canvas(snapshot, child, path + [number])))

static func _append_canvas_arguments(into: Array, argument: Dictionary) -> void:
	for inner in argument.workshop_case.get("arguments", []):
		if inner.id == argument.workshop_case.get("argument_root", ""):
			continue # The enclosing filed question already represents this premise.
		var claim: Dictionary = inner.duplicate(true)
		claim.id = _canvas_argument_id(argument, inner.id)
		claim.parents = inner.parents.map(func(id): return _canvas_argument_id(argument, id))
		if inner.has("without"):
			claim.without = {}
			for parent in inner.without:
				claim.without[_canvas_argument_id(argument, parent)] = inner.without[parent].duplicate()
		into.append(claim)

static func _case(snapshot: Dictionary, argument: Dictionary, epoch: String, path: Array, issues: Array = []) -> Dictionary:
	if argument.has("workshop_case"):
		return argument.workshop_case.duplicate(true)
	var result = Solver.empty_case()
	result.id = "live:" + snapshot.case_id
	result.conclusion = {"type": argument.conclusion.get("type", "unsupported"), "target": _target(argument.conclusion), "at": epoch}
	if argument.board_number in path:
		return result
	var direct: Array = []
	for number in argument.supports:
		if snapshot.board_map.has(str(number)):
			var id: String = snapshot.board_map[str(number)]
			if snapshot.evidence.any(func(e): return e.id == id):
				if id not in result.cards:
					result.cards.append(id)
				direct.append(id)
		else:
			var child: Array = snapshot.arguments.filter(func(a): return a.board_number == number)
			if child.is_empty():
				continue
			var sub = _case(snapshot, child[0], epoch, path + [argument.board_number], issues)
			result.cards.append_array(sub.cards.filter(func(id): return id not in result.cards))
			result.lines.append({"id": "argument:%d" % number, "label": "Supporting claim", "relation": "supports",
				"conclusion": sub.conclusion, "cards": sub.cards, "answers": sub.answers.duplicate(true), "positions": sub.positions.duplicate(true),
				"reasons": sub.reasons.duplicate(true), "citations": sub.citations.duplicate(true), "faults": sub.faults.duplicate(true)})
			if sub.conclusion.type == "conflict":
				result.lines[-1].relation = "quotes"
				continue
			if not _has_canvas(snapshot, number):
				continue # Preserve the existing shape of native-only argument trees.
			for line in sub.lines:
				var nested: Dictionary = line.duplicate(true)
				nested.id = "argument:%d/%s" % [number, line.id]
				result.lines.append(nested)
			for dispute in sub.disputes:
				if dispute not in result.disputes:
					result.disputes.append(dispute.duplicate(true))
			for id in sub.reading_challenges:
				if result.reading_challenges.has(id) and result.reading_challenges[id] != sub.reading_challenges[id]:
					issues.append("Supporting cases give incompatible challenges to " + id + ".")
				result.reading_challenges[id] = sub.reading_challenges[id].duplicate(true)
	if not direct.is_empty():
		# A quoted child may contain the same report as a direct endorsed path.
		# Preserve both routes so quoting cannot erase that independent endorsement.
		result.lines.append({"id": "direct:%d" % argument.board_number, "label": "Direct reports", "relation": "supports",
			"cards": direct, "answers": {}, "positions": {}, "reasons": {}})
	if result.conclusion.type == "conflict":
		result.conflict_scope = result.cards.duplicate()
	return result

static func _listener(snapshot: Dictionary, cards: Array) -> Dictionary:
	var src: Dictionary = snapshot.listener
	var reliability = {}
	var good: Array = [src.id]
	var public_roles = {}
	for receipt in preload("res://workshop/public_evidence.gd").martyr_receipts(snapshot.public_events, snapshot.people.map(func(p): return p.id)):
		public_roles[receipt.content.martyr] = "martyr"
		for person in receipt.subjects:
			if person not in good:
				good.append(person)
	for card in cards:
		reliability[card.id] = 1.0 - maxf(src.discounted.get("%s:%d" % [card.source, card.observed_at.day], 0.0), src.discounted.get(card.source + ":*", 0.0)) if card.kind == "report" else 1.0
		if card.has("route_origin"):
			reliability[card.accuracy_origin] = reliability[card.id]
			reliability[card.id] = 1.0
		if card.has("relay_source"):
			reliability[card.accuracy_origin] = reliability[card.id]
			reliability[card.id] = 1.0 - maxf(src.discounted.get("%s:%d" % [card.relay_source, card.relay_observed_at.day], 0.0), src.discounted.get(card.relay_source + ":*", 0.0))
	var result = {"id": src.id, "name": src.name, "trust": src.trust, "confidence": src.confidence,
		"insight": src.insight, "reasoning_mode": src.get("reasoning_mode", "full"),
		"confidence_mode": src.get("confidence_mode", "scale"), "theories": src.get("theories", {}).duplicate(true),
		"npc_trust": src.npc_trust.duplicate(true), "suspicion": src.suspicion.duplicate(true),
		"reading_reliability": reliability, "knowledge": {"self": src.id, "good": good, "own_role": src.own_gift, "public_roles": public_roles,
			"own_reports": cards.filter(func(c): return c.id in snapshot.private_evidence).map(func(c): return c.id),
			"attention_reports": cards.filter(func(c): return c.id in snapshot.private_evidence and (c.source == src.id or c.get("relay_source") == src.id)).map(func(c): return c.id), "own_outings": src.get("own_outings", {}).duplicate(true)},
		"ledger": {}, "case_memory": {}}
	if public_roles.is_empty():
		result.knowledge.erase("public_roles")
	return result

static func _target(conclusion: Dictionary) -> String:
	return conclusion.get("a", "") if conclusion.get("a", "") != "" else str(conclusion.get("group", [""])[0]) if not conclusion.get("group", []).is_empty() else ""

static func _count_valid(value, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= maximum and int(value) == value

static func reading_valid(receipt: Dictionary, ids: Array, modifiers: Array) -> bool:
	if receipt.kind != "info" or receipt.content.get("role") not in ROLES or receipt.source not in ids or receipt.observed_at.day < 0 or receipt.observed_at.phase == "unknown":
		return false
	var data: Dictionary = receipt.content.data
	match receipt.content.role:
		"psychologist":
			return receipt.observed_at.phase == "night" and receipt.observed_at.day >= 1 and data.get("subject") in ids and data.subject != receipt.source and data.get("trusts") in ids and data.trusts != data.subject and data.get("suspects") in ids and data.suspects != data.subject
		"surveyor":
			return _count_valid(data.get("count"), 4)
		"nightwatch":
			return data.get("block") in C.BLOCKS and data.get("seen") is Array and (data.seen.is_empty() or _group_valid(data.seen, ids)) and receipt.source not in data.seen
		"gravedigger":
			return data.get("executed") in ids and data.executed != receipt.source and data.get("role") in C.ROLES
		"veteran":
			return _count_valid(data.get("attacked"), receipt.observed_at.day) and data.attacked == receipt.observed_at.day and data.attacked >= 1 and data.get("block") in C.BLOCKS
		"lamplighter":
			return _count_valid(data.get("count"), ids.size() - 1)
		"martyr":
			return data.get("target") in ids and data.target != receipt.source and ((data.get("chosen") == true and not data.get("evil", false)) or (data.get("evil") == true and not data.get("chosen", false)))
		"sexton":
			return _count_valid(data.get("night"), receipt.observed_at.day) and data.night == receipt.observed_at.day and data.night >= 1
		"dowser":
			return _group_valid(data.get("group"), ids) and _count_valid(data.get("count"), data.get("group", []).size())
		"clerk", "archivist", "seer":
			if not _group_valid(data.get("pair"), ids) or data.pair.size() != 2 or receipt.source in data.pair:
				return false
			if receipt.content.role == "seer":
				return data.get("yes") is bool
			return data.get("role") in (C.GOOD_ROLES if receipt.content.role == "clerk" else C.MINION_ROLES)
		_:
			return _group_valid(data.get("pair"), ids) and data.get("pair", []).size() == 2 and data.get("secret") in modifiers

static func _group_valid(value, ids: Array) -> bool:
	if not value is Array or value.is_empty():
		return false
	var unique = {}
	for id in value:
		if id not in ids or unique.has(id):
			return false
		unique[id] = true
	return true
