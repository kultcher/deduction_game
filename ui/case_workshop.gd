## The Workshop's shared UI helpers (labels, buttons, options, the card question pane): the base of
## ui/case_workshop_canvas.gd and so of the live Workshop (ui/live_case_workshop.gd). Its old
## standalone list-experiment scene was retired on Nov 20.
extends Control

const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const C = preload("res://sim/content.gd")
const WorkshopSkin = preload("res://ui/theme.gd")

## What the Workshop is working on: the view its cards and people come from, and the case the
## board compiles to. The live Workshop fills both (ui/live_case_workshop.gd). It was a fixture
## Session (workshop/session.gd), built from seed 692 on every open and then overwritten.
class WorkshopState:
	var scenario: Dictionary = {"public_view": {"people": [], "cards": []}}
	var case_data: Dictionary = Solver.empty_case()

var session = WorkshopState.new()
var case_box: VBoxContainer
var status: Label
var focus_card = "survey"
var active_line = ""

func _label(parent: Node, text_value: String, size_value: int = 17, color: String = "text") -> Label:
	var label = Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", WorkshopSkin.color(color))
	parent.add_child(label)
	return label

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _option(parent: Node, labels: Array) -> OptionButton:
	var option = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.clip_text = true
	for label in labels:
		option.add_item(str(label))
	parent.add_child(option)
	return option

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _box(parent: Node) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", WorkshopSkin.flat(WorkshopSkin.color("panel_alt"), Color.TRANSPARENT, 0, 6, 12))
	parent.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box

func _question(card: Dictionary) -> void:
	var box = _box(case_box)
	_label(box, "Answer this card", 20, "accent")
	_label(box, card.text, 17)
	_label(box, "Observed %s %s Â· reported day %s Â· learned day %s" % [card.observed_at.phase, card.observed_at.day, card.reported_at.day, card.learned_at.day], 14, "muted")
	if card.kind == "event" and card.get("event") == "curse":
		_label(box, "Who became evil when the Revenant was executed? This answer is a dated hypothesis, not proof of their identity.", 16)
		var current = _active_choices()
		var candidates: Array = card.data.eligible
		var choice = _option(box, ["? Unknown converted voter"] + candidates.map(func(id): return _name(id)))
		choice.name = "ConvertedVoter"
		var selected: Array = current.answers.get(card.id, {}).get("positive", [])
		choice.select(0 if selected.is_empty() else candidates.find(selected[0]) + 1)
		choice.item_selected.connect(func(i):
			current.answers[card.id] = {"positive": [] if i == 0 else [candidates[i - 1]]}
			_edit())
	if card.kind == "claim":
		_label(box, "An implicit role assertion from %s; accepting the claim does not accept the reading." % card.get("origin", "testimony") if card.get("implicit", false) else "This is a role claim, not proof that the gift works.", 15, "muted")
	if not _card_available(card):
		_button(box, "Use in this line" if active_line != "" else "Use this card", func():
			if card.id not in session.case_data.cards:
				session.case_data.cards.append(card.id)
			if active_line != "":
				_active_choices().cards.append(card.id)
			_edit())
		_label(box, "Answers on a card outside this case or line have no effect.", 14, "muted")
	var role: String = card.get("role", "")
	if card.kind == "secret_claim":
		_label(box, "This claims a private errand that could explain an outing. It does not prove innocence, a particular secret modifier, or that the person was out.", 16, "muted")
	elif card.kind == "context" and card.get("context_kind", "") == "psychologist":
		_label(box, "This reports whom someone trusts and suspects. Those opinions do not establish anyone's alignment.", 16, "muted")
	elif card.kind == "report" and role == "psychologist":
		var p_mode_q: String = str(card.data.get("mode", ""))
		if p_mode_q == "none_false":
			_label(box, "No eligible statements heard directly by the Psychologist on day %d were false or misread. Link alongside day-%d evidence to bolster it, or right-click to challenge if day-%d statements contradict each other." % [int(card.data.get("day_heard", 1)), int(card.data.get("day_heard", 1)), int(card.data.get("day_heard", 1))], 16)
		elif p_mode_q == "pair" and card.data.get("statements") is Array and card.data.statements.size() == 2:
			var current_p = _active_choices()
			var ans_p: Dictionary = current_p.answers.get(card.id, {})
			var stmts_q: Array = card.data.statements
			_label(box, "At least one of these two statements from day %d was a lie or misreading. Specify which one (and why) to factor it directly into the solver:" % int(card.data.get("day_heard", 1)), 16)
			var slot_vals: Array = ["", "0", "1", "both"]
			var slot_opt = _option(box, ["? Either statement could be false", "Statement 1: " + str(stmts_q[0].get("summary", "")), "Statement 2: " + str(stmts_q[1].get("summary", "")), "Both statements are false"])
			slot_opt.select(maxi(0, slot_vals.find(str(ans_p.get("false_slot", "")))))
			slot_opt.item_selected.connect(func(idx_s):
				var upd: Dictionary = current_p.answers.get(card.id, {}).duplicate(true)
				if idx_s <= 0:
					upd.erase("false_slot")
					upd.erase("false_reason")
				else:
					upd["false_slot"] = slot_vals[idx_s]
					if slot_vals[idx_s] == "both" or (str(upd.get("false_reason", "")) == "misled" and str(stmts_q[mini(idx_s - 1, 1)].get("kind", "")) == "sighting"):
						upd.erase("false_reason")
				current_p.answers[card.id] = upd
				_edit())
			var cur_fs: String = str(ans_p.get("false_slot", ""))
			if cur_fs in ["0", "1"]:
				var why_vals: Array = ["", "lying", "misled"]
				var why_opt = _option(box, ["? Unresolved cause (lied or misled)", "Source was lying (evil)", "Source was misled (poisoned, Delusional, Marked, Red Herring, or Sleepwalker)"])
				why_opt.set_item_disabled(2, str(stmts_q[int(cur_fs)].get("kind", "")) == "sighting")
				why_opt.select(maxi(0, why_vals.find(str(ans_p.get("false_reason", "")))))
				why_opt.item_selected.connect(func(idx_w):
					var upd2: Dictionary = current_p.answers.get(card.id, {}).duplicate(true)
					if idx_w <= 0:
						upd2.erase("false_reason")
					else:
						upd2["false_reason"] = why_vals[idx_w]
					current_p.answers[card.id] = upd2
					_edit())
	elif card.kind == "report" and role in ["surveyor", "dowser", "rumormonger", "lamplighter", "clerk", "archivist", "seer", "chronicler", "magistrate", "augur"]:
		var is_p_surv: bool = role == "surveyor" and card.data.has("block")
		var prompt: String = {
			"surveyor": ("All residents on %s registered the same alignment." % C.block_name(str(card.data.get("block", ""))) if card.data.get("same", false) else "Who on %s registered as evil (or Marked)?" % C.block_name(str(card.data.get("block", "")))) if is_p_surv else "Which blocks or residents account for the positives? A positive may be evil or Marked.",
			"dowser": "Who registered as evil in this reading? Marked is a possible explanation.",
			"rumormonger": "Which person is Marked in your explanation?",
			"lamplighter": "Who were the other people out? The Lamplighter is excluded.",
			"clerk": "If this reading is accurate, who holds the named good gift?",
			"archivist": "If this reading is accurate, who holds the named minion gift?",
			"seer": "What explains this Demon reading? A negative reading does not clear minions.",
			"chronicler": "If this reading is accurate, who in the trio was the Minion at case start?",
			"magistrate": "Both nominess shared an alignment registration." if card.data.get("same", false) else "Which of the two registered as evil (or Marked)?",
			"augur": "Link daytime sightings or work receipts from this day to weigh public crossings. Optional: pick who crossed paths with the Augur." if card.data.get("yes", false) else "Link daytime sightings or work receipts from this day to clear anyone who shared a public block with the Augur.",
		}[role]
		if role == "rumormonger":
			prompt = "Which person has the named secret (%s) in your explanation?" % card.data.get("secret", "marked")
		_label(box, prompt, 16)
		var count: int = 0
		if role in ["seer", "augur"]:
			count = 1 if card.data.get("yes", false) else 0
		elif role in ["rumormonger", "clerk", "archivist", "chronicler"]:
			count = 1
		elif role == "magistrate":
			count = 0 if card.data.get("same", false) else 1
		elif is_p_surv:
			var s_res_c: int = session.scenario.public_view.people.filter(func(p): return p.home == card.data.get("block", "")).size()
			count = 0 if card.data.get("same", false) else maxi(1, s_res_c - 1)
		else:
			count = int(card.data.get("count", 0))
		var current = _active_choices()
		var answer: Dictionary = current.answers.get(card.id, {})
		var fallback_slots: Array = answer.get("positive", []).duplicate()
		for block in answer.get("blocks", []):
			fallback_slots.append("block:" + str(block))
		if role == "surveyor" and not is_p_surv and count == 4:
			var by_block = {}
			for choice in fallback_slots:
				if str(choice).begins_with("block:"):
					by_block[str(choice).trim_prefix("block:")] = choice
				else:
					for person in session.scenario.public_view.people:
						if person.id == choice:
							by_block[person.home] = choice
			fallback_slots = C.BLOCKS.keys().map(func(block): return by_block.get(block, ""))
		var slots: Array = answer.get("slots", fallback_slots)
		for i in range(count):
			var choices: Array = session.scenario.public_view.people.map(func(p): return p.id)
			if role in ["rumormonger", "clerk", "archivist", "seer"]:
				choices = card.data.pair
			elif role == "chronicler":
				choices = card.data.get("trio", [])
			elif role == "magistrate":
				choices = [card.data.get("nominator", ""), card.data.get("nominee", "")]
			elif is_p_surv:
				choices = session.scenario.public_view.people.filter(func(p): return p.home == card.data.get("block", "")).map(func(p): return p.id)
			elif role == "surveyor":
				if count == 4:
					var block: String = C.BLOCKS.keys()[i]
					_label(box, C.block_name(block), 15, "muted")
					choices = ["block:" + block] + session.scenario.public_view.people.filter(func(p): return p.home == block).map(func(p): return p.id)
				else:
					choices = C.BLOCKS.keys().map(func(block): return "block:" + block) + choices
			elif role == "dowser":
				choices = card.data.group
			elif role in ["lamplighter", "augur"]:
				choices = choices.filter(func(id): return id != card.source)
			var slot = _option(box, ["? Unresolved slot %d" % (i + 1)] + choices.map(func(id): return "Someone on " + C.block_name(str(id).trim_prefix("block:")) if str(id).begins_with("block:") else _name(id)))
			slot.name = "Answer_%s_%d" % [card.id, i]
			if i < slots.size() and slots[i] in choices:
				slot.select(choices.find(slots[i]) + 1)
			slot.item_selected.connect(func(index):
				var values: Array = current.answers.get(card.id, {}).get("slots", []).duplicate()
				values.resize(count)
				values[i] = "" if index == 0 else choices[index - 1]
				var chosen: Array = values.filter(func(v): return v is String and v != "")
				if chosen.size() != _unique(chosen).size():
					status.text = "That answer already fills a slot. Leave this slot unknown or choose another."
					_refresh_case()
					return
				var updated: Dictionary = current.answers.get(card.id, {}).duplicate(true)
				var positive: Array = chosen.filter(func(v): return not v.begins_with("block:"))
				updated.merge({"slots": values, "positive": positive}, true)
				if role == "surveyor" and not is_p_surv:
					updated["blocks"] = chosen.filter(func(v): return v.begins_with("block:")).map(func(v): return v.trim_prefix("block:"))
				current.answers[card.id] = updated
				_edit())
		if role in ["surveyor", "dowser"]:
			_label(box, _identity_hint(), 15, "muted")
		if role == "seer" and card.data.yes:
			var reasons: Array = ["", "demon", "red_herring", "marked"] if _marked_answers() else ["", "demon", "red_herring"]
			var reason = _option(box, ["? Any valid explanation", "Demon", "Red Herring", "Marked"] if _marked_answers() else ["? Any valid explanation", "Demon", "Red Herring"])
			reason.select(reasons.find(answer.get("registration", "")))
			reason.item_selected.connect(func(i):
				var updated: Dictionary = current.answers.get(card.id, {}).duplicate(true)
				updated["registration"] = reasons[i]
				current.answers[card.id] = updated
				_edit())
	elif (card.kind == "report" and role == "nightwatch") or card.kind == "sighting":
		_label(box, "Why were they out? An unanswered reason is allowed. A gift explanation needs supporting testimony.", 16)
		var current = _active_choices()
		var seen: Array = card.data.seen if role == "nightwatch" else card.get("subjects", [card.subject])
		for id in seen:
			_label(box, _name(id), 16)
			var key = "%s:%d" % [id, card.night]
			var labels: Array = ["? Unexplained", "Night gift â€” choose supporting claim", "Possibly evil activity"]
			var reasons = ["unexplained", "gift", "evil"]
			if session.scenario.public_view.get("live_activity", false):
				labels.append("Private errand â€” choose supporting claim")
				reasons.append("secret")
			var option = _option(box, labels)
			option.select(reasons.find(current.reasons.get(key, "unexplained")))
			option.item_selected.connect(func(i):
				current.reasons[key] = reasons[i]
				_edit())
			if current.reasons.get(key, "unexplained") in ["gift", "secret"]:
				var private_errand: bool = current.reasons[key] == "secret"
				var claims: Array = session.scenario.public_view.cards.filter(func(c): return c.kind == ("secret_claim" if private_errand else "claim") and c.subject == id)
				var claim_labels: Array = claims.map(func(c): return "%s Â· %s Â· day %s" % [_name(c.subject), C.role_name(c.role), c.acquired_day])
				# The live editor fills the citation itself from the board (premises step 2):
				# its first entry is "automatic", and declining is an explicit choice.
				var lead: Array = ["Automatic: the claim on the board", "No supporting claim"] if _auto_claims() else ["? No supporting claim"]
				var citation = _option(box, lead + claim_labels)
				citation.name = "Citation_%s_%d" % [id, card.night]
				var cited_now: String = str(current.citations.get(key, ""))
				if _auto_claims() and cited_now == "none":
					citation.select(1)
				else:
					citation.select(claims.map(func(c): return c.id).find(cited_now) + lead.size() if claims.any(func(c): return c.id == cited_now) else 0)
				citation.item_selected.connect(func(i):
					if i == 0:
						current.citations.erase(key)
					elif _auto_claims() and i == 1:
						current.citations[key] = "none"
					else:
						current.citations[key] = claims[i - lead.size()].id
					_edit())
				var support = Graph.valid_citation(session.scenario.public_view, current, id, card.night)
				if private_errand:
					support = claims.filter(func(c): return c.id == current.citations.get(key, ""))[0] if claims.any(func(c): return c.id == current.citations.get(key, "")) else {}
				_label(box, "Cited: %s. This could explain the outing; accuracy and activity are still assumptions." % support.text if not support.is_empty() else "No applicable walking-gift claim is cited; this explanation receives no discount.", 14, "muted")
	elif card.kind == "report" and role in ["warden", "gravedigger", "veteran", "martyr", "sexton", "executor", "registrar", "monitor", "confessor"]:
		var explanation: String = {
			"warden": "This claims a guard at the named door on that night. Movement, public deaths and quiet nights weigh it together; a quiet night alone does not prove a successful protection.",
			"gravedigger": "This names the executed person's role at that execution. An evil-role result can also come from a good Marked person. No additional answer is required.",
			"veteran": "This claims the first survived Demon attack and its approach block. It can constrain the attacker's route if the report is sound. No additional answer is required.",
			"martyr": "This records a claimed choice; choosing someone does not establish that they are good. Comparing an earlier promise with a later hanging still needs a dated outcome adapter." if card.data.get("chosen", false) else "This claims the chosen person was hanged without substitution. If the gift was healthy, they registered evil; Marked remains an explanation.",
			"sexton": "A healthy toll suppresses all minion abilities until the next night. Townsfolk gifts continue. Hearing or claiming the bell alone does not establish that the gift worked.",
			"executor": "Records the Executor's case-start charge; consistency requires any later death reading from this Executor to name the same person." if card.data.get("assigned", false) else "Names the deceased charge's role the morning after they died. An evil-role result can also come from a good Marked person. No additional answer is required.",
			"registrar": "Lists the three script roles on this Registrar's slate; at least one is in play if the Registrar is good and healthy." if not card.data.has("target") else "Checks whether the named person holds one of the three roles on the slate (Marked can falsely match a minion role on the slate). No additional answer is required.",
			"monitor": "Learns the role of someone who walked abroad on their home block, or that no one walked by their house (Marked can register as an evil role). No additional answer is required.",
			"confessor": "Confirms whether the visited person is good. An 'I forgot' reading indicates they were evil (or Marked), or that the reading was corrupted. No additional answer is required."
		}[role]
		_label(box, explanation, 16, "muted")
	else:
		_label(box, "This statement can support an explanation or conflict with another report. No additional answer is required.", 16, "muted")

func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value not in result:
			result.append(value)
	return result

func _name(id: String) -> String:
	return Solver.person_name(session.scenario.public_view, id)

func _names(ids: Array) -> String:
	return ", ".join(PackedStringArray(ids.map(func(id): return _name(id)))) if not ids.is_empty() else "none"

func _report(id: String) -> Dictionary:
	return Solver.card_by_id(session.scenario.public_view, id)

# ---- Declared for the shared helpers above; the live Workshop's classes override them.

## The answers and cards being edited (ui/case_workshop_canvas.gd).
func _active_choices() -> Dictionary:
	return {}

## Whether a card is on the case being edited (ui/case_workshop_canvas.gd).
func _card_available(_card: Dictionary) -> bool:
	return false

## Apply an edit and refresh (ui/live_case_workshop.gd).
func _edit() -> void:
	pass

## Rebuild the case pane (ui/live_case_workshop.gd).
func _refresh_case() -> void:
	pass

## A hint about the identity premise being edited (ui/live_case_workshop.gd).
func _identity_hint() -> String:
	return ""

## Whether the case's script allows Marked answers (ui/live_case_workshop.gd).
func _marked_answers() -> bool:
	return false

## Whether role claims on the board support readings automatically (ui/live_case_workshop.gd).
func _auto_claims() -> bool:
	return false
