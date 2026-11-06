## Voiced Workshop case-presentation composer and Good/Evil parity renderer.
## Pure presentation layer: consumes already-resolved Workshop assessments or approved
## Evil stance descriptors, never accesses hidden world truth for Good listeners, and
## never consumes gameplay RNG.
extends RefCounted

const C = preload("res://sim/content.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const Solver = preload("res://workshop/solver.gd")

const ACCUSING_TYPES = ["evil", "demon", "minion", "lied", "notrole", "suspicious", "unreliable"]
## Premises the "seen elsewhere / the traces" movement notes can speak to: whether someone is
## on the killer's side. Role, secret, Marked and misled premises don't.
const MOVEMENT_NOTE_TYPES = ["evil", "demon", "minion", "suspicious", "good", "notdemon"]
const MARKED_PING_ROLES = ["seer", "dowser", "clerk", "gravedigger", "hearthwitch", "surveyor", "augur", "magistrate", "executor", "registrar"]

const FALSE_SELF_EXPRESSIONS = {
	"bart": "harsh", "constance": "harsh", "dorian": "concerned", "edda": "harsh",
	"fenwick": "harsh", "greta": "harsh", "hollis": "harsh", "isolde": "concerned",
	"jory": "harsh", "kiran": "harsh", "lian": "harsh", "merrin": "harsh",
	"nisha": "harsh", "odette": "harsh",
}

const SELF_SUPPORT_WARM = {
	"agnes": "warm", "dorian": "warm", "edda": "warm", "fenwick": "warm",
	"isolde": "warm", "jory": "warm", "merrin": "warm",
}


static func _target_label(w, targets: Array, fallback_subject: String) -> String:
	if targets.size() > 1:
		var names: Array = []
		for tid in targets:
			if w.by_id.has(tid):
				names.append(w.by_id[tid].name)
		if not names.is_empty():
			return " and ".join(PackedStringArray(names))
	if targets.size() == 1 and w.by_id.has(targets[0]):
		return w.by_id[targets[0]].name
	if fallback_subject != "" and w.by_id.has(fallback_subject):
		return w.by_id[fallback_subject].name
	return "that"


static func _card_mentions_person(card: Dictionary, pid: String) -> bool:
	for k in ["subject", "subjects", "target", "who"]:
		var v = card.get(k)
		if v is Array and pid in v:
			return true
		if v is String and v == pid:
			return true
	var d = card.get("data", {})
	if d is Dictionary:
		for k in ["pair", "group", "seen", "nbrs", "trio", "target", "chosen", "executed", "guarded", "nominator", "nominee"]:
			var v = d.get(k)
			if v is Array and pid in v:
				return true
			if v is String and v == pid:
				return true
	return false


static func _is_marked_relevant(marked_id: String, root_conclusion: Dictionary, snapshot: Dictionary, reasoning: Dictionary) -> bool:
	if marked_id == "":
		return false
	if str(root_conclusion.get("type", "")) == "marked" or str(root_conclusion.get("a", "")) == marked_id:
		return true
	var considered: Array = reasoning.get("considered", snapshot.get("selected", []))
	for card in snapshot.get("evidence", []):
		if not (card is Dictionary):
			continue
		if str(card.get("id", "")) not in considered:
			continue
		if str(card.get("kind", "")) == "report" and str(card.get("role", "")) in MARKED_PING_ROLES:
			if _card_mentions_person(card, marked_id):
				return true
	return false


## The listener's own standout suspects, if any: the top living suspect (not the listener,
## not `exclude`) when they clear OWN_STANDOUT_MIN and lead the third by OWN_STANDOUT_GAP;
## the second too when it clears the same bar. Empty when suspicion is flat.
const OWN_STANDOUT_MIN = 0.25
const OWN_STANDOUT_GAP = 0.08
static func _own_standouts(w, listener_id: String, suspicion_map: Dictionary, exclude: Array = []) -> Dictionary:
	var ids: Array = []
	for p in w.living():
		if p.id != listener_id and not p.id in exclude:
			ids.append(p.id)
	var sv = func(id): return clampf(float(suspicion_map.get(id, 0.1)), 0.0, 1.5)
	ids.sort_custom(func(a, b): return sv.call(a) > sv.call(b) if not is_equal_approx(sv.call(a), sv.call(b)) else a < b)
	if ids.is_empty():
		return {"demon_id": "", "accomplice_id": ""}
	var third: float = sv.call(ids[2]) if ids.size() > 2 else 0.0
	var second: float = sv.call(ids[1]) if ids.size() > 1 else 0.0
	var top: float = sv.call(ids[0])
	if top < OWN_STANDOUT_MIN or top - maxf(second if second < OWN_STANDOUT_MIN else third, 0.0) < OWN_STANDOUT_GAP:
		return {"demon_id": "", "accomplice_id": ""}
	var acc: String = ids[1] if ids.size() > 1 and second >= OWN_STANDOUT_MIN and second - third >= OWN_STANDOUT_GAP else ""
	return {"demon_id": ids[0], "accomplice_id": acc}

## Extract at most two suspects from a rival world (top Demon + single highest-suspicion #2 evil).
## Never names a third evil member; promotes a living evil successor if the starting Demon died.
static func _pick_rival_pair(w, listener_id: String, suspicion_map: Dictionary, alt: Dictionary, epoch: String) -> Dictionary:
	var evil_ids: Array = []
	for eid in alt.get("evil", []):
		var s_id: String = str(eid)
		if s_id != "" and s_id != listener_id and w.by_id.has(s_id):
			evil_ids.append(s_id)
	var demon_id: String = str(alt.get("demon", ""))
	if demon_id == listener_id or not w.by_id.has(demon_id):
		demon_id = ""
	if demon_id != "" and epoch == "now" and not w.by_id[demon_id].alive:
		var living_evil: Array = evil_ids.filter(func(cid): return w.by_id[cid].alive)
		if not living_evil.is_empty():
			living_evil.sort_custom(func(a, b):
				var sa: float = float(suspicion_map.get(a, 0.1))
				var sb: float = float(suspicion_map.get(b, 0.1))
				return sa > sb if not is_equal_approx(sa, sb) else a < b
			)
			demon_id = living_evil[0]
	if demon_id == "" and not evil_ids.is_empty():
		var ranked_all: Array = evil_ids.duplicate()
		ranked_all.sort_custom(func(a, b):
			var sa: float = float(suspicion_map.get(a, 0.1))
			var sb: float = float(suspicion_map.get(b, 0.1))
			return sa > sb if not is_equal_approx(sa, sb) else a < b
		)
		demon_id = ranked_all[0]
	# A "now" claim names living people only: a dead starting Demon is no accomplice.
	var rest_evil: Array = evil_ids.filter(func(cid): return cid != demon_id and (epoch != "now" or w.by_id[cid].alive))
	rest_evil.sort_custom(func(a, b):
		var sa: float = float(suspicion_map.get(a, 0.1))
		var sb: float = float(suspicion_map.get(b, 0.1))
		return sa > sb if not is_equal_approx(sa, sb) else a < b
	)
	var accomplice_id: String = rest_evil[0] if not rest_evil.is_empty() else ""
	return {"demon_id": demon_id, "accomplice_id": accomplice_id}


static func _append_movement_notes(w, listener_id: String, ctype: String, stance_subject: String, ev: Dictionary, parts: Array, used_circumstantial: bool, allow_lean: bool) -> void:
	var mov: Array = ev.get("movement", [])
	if mov.is_empty():
		return
	var has_alibi_challenge: bool = mov.any(func(lbl): return str(lbl).begins_with("Challenged home alibi"))
	var has_move_trace: bool = mov.any(func(lbl): return str(lbl).begins_with("Movement / trace"))
	if has_alibi_challenge and not used_circumstantial:
		parts.append(Dialogue.voice_line(listener_id, "present_circumstantial_only", "If the linked observation is accurate, the home alibi is false; that remains circumstantial."))
	elif allow_lean and has_move_trace and not used_circumstantial:
		parts.append(Dialogue.voice_line(listener_id, "present_move_trace_lean", "The routes and scene traces favor that reading, though as circumstantial support rather than proof."))
	var target_prefix: String = (w.by_id[stance_subject].name + "'s ") if (stance_subject != "" and w.by_id.has(stance_subject)) else ""
	var re_seen := RegEx.new()
	re_seen.compile("^Seen elsewhere:\\s+(.+?)'s sighting on night (\\d+)")
	var re_role := RegEx.new()
	re_role.compile("^Scattered sightings:\\s+(.+?)'s movements fit the claimed (.+?) gift\\.")
	for raw_note in mov:
		var note: String = str(raw_note)
		if note.begins_with("Seen elsewhere:") and ctype != "minion":
			if target_prefix == "" or note.contains(": " + target_prefix):
				var m_seen: RegExMatch = re_seen.search(note)
				if m_seen != null:
					# Spoken nights are "last night" / "on the second night", never a number.
					parts.append(Dialogue.voice_line(listener_id, "present_seen_elsewhere", note, {
						"subject": m_seen.get_string(1),
						"night": m_seen.get_string(2),
						"when": C.spoken_when(int(m_seen.get_string(2)), int(w.day)),
					}))
		elif note.begins_with("Scattered sightings:"):
			if target_prefix == "" or note.contains(": " + target_prefix):
				var m_role: RegExMatch = re_role.search(note)
				if m_role != null:
					parts.append(Dialogue.voice_line(listener_id, "present_role_fit", note, {
						"subject": m_role.get_string(1),
						"role": m_role.get_string(2),
					}))


static func _attach_expression(listener_id: String, line: Dictionary, cue_key: String) -> Dictionary:
	if not Dialogue.has_voice(listener_id):
		return line
	var expr: String = ""
	if cue_key == "present_false_self":
		expr = str(FALSE_SELF_EXPRESSIONS.get(listener_id, ""))
	elif cue_key == "self_support_thanks":
		expr = str(SELF_SUPPORT_WARM.get(listener_id, ""))
	if expr != "":
		line["expression"] = expr
		line["expression_strength"] = 1 if expr == "warm" else 2
	return line


static func render_repeat(n, from_meeting: bool, canonical: String, tic_memory: Dictionary) -> Dictionary:
	var key: String = "present_repeat_meeting" if from_meeting else "present_repeat_private"
	var voiced: String = Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, key, canonical), tic_memory)
	return {"speaker": n.id, "name": n.name, "text": voiced, "statement": canonical}


static func render_self_support(n, variant: String, canonical: String, tic_memory: Dictionary) -> Dictionary:
	var key_map = {
		"thanks": "self_support_thanks",
		"weak": "self_support_weak",
		"repeat": "self_support_repeat",
	}
	var key: String = str(key_map.get(variant, "self_support_thanks"))
	var voiced: String = Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, key, canonical), tic_memory)
	var line: Dictionary = {"speaker": n.id, "name": n.name, "text": voiced, "statement": canonical}
	return _attach_expression(n.id, line, key)


## Compose the full spoken presentation reaction for a Workshop assessment.
static func render_workshop_reply(w, listener, root_conclusion: Dictionary, targets: Array, assessment: Dictionary, view: Dictionary, snapshot: Dictionary, believed_stance: String, already_aligned: bool, nothing_new: bool, canonical: String, tic_memory: Dictionary) -> Dictionary:
	if not Dialogue.has_voice(listener.id):
		return {"speaker": listener.id, "name": listener.name, "text": canonical, "statement": canonical}
	var ctype: String = str(root_conclusion.get("type", ""))
	var stance_subject: String = str(root_conclusion.get("a", ""))
	var target_label: String = _target_label(w, targets, stance_subject)
	var reasoning: Dictionary = assessment.get("reasoning", {})
	var private_checks: Dictionary = reasoning.get("private_checks", {})
	var ev: Dictionary = assessment.get("case_eval", {})
	var status: String = str(reasoning.get("status", ""))
	var path_kind: String = str(assessment.get("path_kind", "reading"))
	var agreement: float = float(assessment.get("agreement", 0.0))
	var bounded: bool = str(view.get("listener", {}).get("reasoning_mode", listener.workshop_state.get("reasoning_mode", "bounded"))) == "bounded"

	var parts: Array = []
	var primary_key: String = ""
	var used_circumstantial: bool = false
	var allow_lean: bool = true

	if bool(private_checks.get("fatal", false)):
		var obj0: String = str(private_checks.get("objections", [""])[0]) if not private_checks.get("objections", []).is_empty() else ""
		var about_me: bool = (stance_subject == listener.id and ctype in ACCUSING_TYPES) or "about me" in obj0
		primary_key = "present_false_self" if about_me else "present_false_known"
		parts.append(Dialogue.voice_line(listener.id, primary_key, canonical))
		allow_lean = false
	elif ctype == "conflict":
		primary_key = "present_conflict_found" if agreement > 0.0 else "present_conflict_none"
		parts.append(Dialogue.voice_line(listener.id, primary_key, canonical))
		allow_lean = false
	elif path_kind == "pattern" and agreement > 0.0:
		primary_key = "present_circumstantial_only"
		parts.append(Dialogue.voice_line(listener.id, primary_key, canonical))
		used_circumstantial = true
		allow_lean = false
		if ctype in ["evil", "demon", "minion", "good", "marked"] and believed_stance in ["accept", "partial"]:
			var follow_k: String = "present_accept_open" if believed_stance == "accept" else "present_partial"
			parts.append(Dialogue.voice_line(listener.id, follow_k, canonical, {"target": target_label}))
	elif path_kind == "conditional":
		primary_key = "present_conditional"
		parts.append(Dialogue.voice_line(listener.id, primary_key, canonical))
		allow_lean = false
	elif bool(ev.get("impossible", false)):
		primary_key = "present_false_known"
		parts.append(Dialogue.voice_line(listener.id, primary_key, canonical))
		allow_lean = false
	elif (status == "inconsistent") if bounded else ((not bool(ev.get("consistent", true)) or str(assessment.get("assessment", {}).get("status", "")) == "conflicting") and believed_stance == "reject"):
		primary_key = "present_conflict_weighing"
		parts.append(Dialogue.voice_line(listener.id, primary_key, canonical))
		allow_lean = false
		if believed_stance in ["accept", "partial"]:
			var inc_follow: String = "present_accept_open" if believed_stance == "accept" else "present_partial"
			parts.append(Dialogue.voice_line(listener.id, inc_follow, "", {"target": target_label}))
	elif status == "rival_found" and reasoning.get("rival") is Dictionary and not reasoning.rival.is_empty():
		var epoch: String = str(root_conclusion.get("at", "now"))
		var alt: Dictionary = Solver.describe_world(view, reasoning.rival, epoch)
		# These lines say "my stronger suspicion remains...": the names must be the
		# listener's own standouts, not the rival world's (playtest 13910: nine listeners
		# all named the same rival-world Demon from near-flat suspicions).
		var pair: Dictionary = _own_standouts(w, listener.id, listener.suspicion, [stance_subject])
		var demon_id: String = str(pair.get("demon_id", ""))
		var acc_id: String = str(pair.get("accomplice_id", ""))
		if believed_stance == "reject" and already_aligned:
			primary_key = "present_already"
			parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"target": target_label}))
		elif demon_id == "":
			# Nobody stands out: the rival only shows the case isn't decisive.
			primary_key = "present_accept_open" if believed_stance == "accept" else ("present_partial" if believed_stance == "partial" else "present_alt_open")
			parts.append(Dialogue.voice_line(listener.id, primary_key, "Other explanations fit as well as yours; it doesn't settle it for me." if primary_key == "present_alt_open" else canonical, {"target": target_label}))
		elif demon_id != "" and w.by_id.has(demon_id):
			var d_name: String = w.by_id[demon_id].name
			if acc_id != "" and w.by_id.has(acc_id):
				var a_name: String = w.by_id[acc_id].name
				match believed_stance:
					"accept":
						primary_key = "present_alt_accept"
						parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"demon": d_name, "accomplice": a_name, "target": target_label}))
					"partial":
						primary_key = "present_alt_partial"
						parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"demon": d_name, "accomplice": a_name, "target": target_label}))
					_:
						primary_key = "present_alt_reject"
						parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"demon": d_name, "accomplice": a_name}))
			else:
				match believed_stance:
					"accept":
						primary_key = "present_alt_accept_solo"
						parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"demon": d_name, "target": target_label}))
					"partial":
						primary_key = "present_alt_partial_solo"
						parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"demon": d_name, "target": target_label}))
					_:
						primary_key = "present_alt_reject_solo"
						parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"demon": d_name}))
			var marked_id: String = str(alt.get("marked", ""))
			if marked_id != "" and marked_id != listener.id and w.by_id.has(marked_id) and _is_marked_relevant(marked_id, root_conclusion, snapshot, reasoning):
				parts.append(Dialogue.voice_line(listener.id, "present_alt_marked", "", {"marked": w.by_id[marked_id].name}))
		else:
			primary_key = "present_accept_open" if believed_stance == "accept" else ("present_partial" if believed_stance == "partial" else "present_unmoved")
			parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"target": target_label}))
	elif bounded and status not in ["provisional", "entailed_in_attention", "rival_found", "inconsistent", "counterexample_found", ""]:
		primary_key = "present_lost_thread"
		parts.append(Dialogue.voice_line(listener.id, primary_key, canonical))
		if believed_stance in ["accept", "partial"]:
			var b_key: String = "present_accept_open" if believed_stance == "accept" else "present_partial"
			parts.append(Dialogue.voice_line(listener.id, b_key, "", {"target": target_label}))
	elif agreement <= -0.2 or (status == "counterexample_found" and bool(reasoning.get("support_exhausted", false))):
		var rivals: Array = ev.get("rivals", [])
		var rival_id: String = ""
		if believed_stance != "accept" and not rivals.is_empty() and rivals[0] is Dictionary:
			if float(rivals[0].get("shift", 0.0)) > 0.2 and float(rivals[0].get("posterior", 0.0)) > 0.5:
				var cand_r: String = str(rivals[0].get("id", ""))
				if cand_r != "" and cand_r != listener.id and w.by_id.has(cand_r):
					rival_id = cand_r
		if rival_id != "":
			primary_key = "present_points_elsewhere"
			parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"target": target_label, "rival": w.by_id[rival_id].name}))
		elif believed_stance == "accept":
			primary_key = "present_accept_open"
			parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"target": target_label}))
		elif believed_stance == "partial":
			primary_key = "present_partial"
			parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"target": target_label}))
		else:
			primary_key = "present_weighs_against"
			parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"target": target_label}))
	else:
		match believed_stance:
			"accept":
				var solid: bool = status == "entailed_in_attention" or int(reasoning.get("rivals_tested", 0)) > 3 or (not bounded and float(ev.get("posterior", 0.0)) >= 0.9)
				if solid:
					primary_key = "present_accept_solid"
					parts.append(Dialogue.voice_line(listener.id, primary_key, canonical))
				else:
					primary_key = "present_accept_open"
					parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"target": target_label}))
			"partial":
				primary_key = "present_partial"
				parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"target": target_label}))
			_:
				if already_aligned or (nothing_new and str(assessment.get("stance", "")) == "accept"):
					primary_key = "present_already"
					parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"target": target_label}))
				else:
					primary_key = "present_unmoved"
					parts.append(Dialogue.voice_line(listener.id, primary_key, canonical, {"target": target_label}))

	if bounded and primary_key not in ["present_lost_thread", "present_false_self", "present_false_known", "present_conflict_found", "present_conflict_none"]:
		var ignored_arr: Array = reasoning.get("ignored", [])
		var pres_rep: Array = snapshot.get("selected", []) if snapshot.has("selected") else view.get("listener", {}).get("knowledge", {}).get("presented_reports", [])
		var ignored_presented: bool = ignored_arr.any(func(id): return id in pres_rep)
		if ignored_presented or not reasoning.get("ignored_lines", []).is_empty():
			parts.append(Dialogue.voice_line(listener.id, "present_partial_attention", ""))

	# The movement notes ("seen elsewhere, so not the killer", "the traces incline me") only
	# fit premises about whether someone is the killer's side (premises pass step 1; playtest
	# issue #5: "Dorian is the Warden" drew a killer clause).
	if primary_key not in ["present_false_self", "present_false_known", "present_conflict_found", "present_conflict_none", "present_conditional"] and ctype in MOVEMENT_NOTE_TYPES:
		_append_movement_notes(w, listener.id, ctype, stance_subject, ev, parts, used_circumstantial, allow_lean)

	var joined: String = " ".join(PackedStringArray(parts.filter(func(s): return str(s).strip_edges() != "")))
	if joined == "":
		joined = canonical
	joined = Dialogue.apply_tics(listener.id, joined, tic_memory)
	var line: Dictionary = {"speaker": listener.id, "name": listener.name, "text": joined, "statement": canonical}
	return _attach_expression(listener.id, line, primary_key)


## Render an Evil listener's presentation reaction when overriding their good-shadow or
## answering about themselves, using the exact same Batch 5 voice pool as Good listeners.
static func render_evil_override(w, n, conclusion: Dictionary, stance: String, already: bool, repeated: bool, audience: String, canonical: String, tic_memory: Dictionary) -> Dictionary:
	if not Dialogue.has_voice(n.id):
		return {"speaker": n.id, "name": n.name, "text": canonical, "statement": canonical}
	if repeated:
		return render_repeat(n, audience == "town", canonical, tic_memory)
	var ctype: String = str(conclusion.get("type", ""))
	var target_id: String = str(conclusion.get("a", ""))
	if target_id == n.id:
		if ctype in ACCUSING_TYPES:
			var self_def: String = Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, "present_false_self", canonical), tic_memory)
			return _attach_expression(n.id, {"speaker": n.id, "name": n.name, "text": self_def, "statement": canonical}, "present_false_self")
		return render_self_support(n, "thanks", canonical, tic_memory)
	if ctype == "conflict":
		var ck: String = "present_conflict_found" if stance != "reject" else "present_conflict_none"
		var cv: String = Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, ck, canonical), tic_memory)
		return {"speaker": n.id, "name": n.name, "text": cv, "statement": canonical}
	var target_label: String = w.by_id[target_id].name if (target_id != "" and w.by_id.has(target_id)) else "that"
	var key: String = "present_unmoved"
	var slots: Dictionary = {"target": target_label}
	if already:
		key = "present_already"
	elif stance == "accept":
		key = "present_accept_open"
	elif stance == "partial":
		key = "present_partial"
	else:
		# Deterministic non-RNG variation: when rejecting an accusation against a teammate,
		# Evil may cite its non-evil scapegoat as top Demon suspect (+ #2 non-evil suspect).
		var sg_id: String = str(w.evil_plan.get("scapegoat", ""))
		var h: int = absi(hash(n.id + "|evil_pres|" + ctype + "|" + target_id + "|" + str(w.day)))
		if ctype in ["evil", "demon", "minion", "suspicious"] and sg_id != "" and sg_id != target_id and sg_id != n.id and w.by_id.has(sg_id) and w.by_id[sg_id].alive and not w.by_id[sg_id].is_evil() and (h % 2 == 0):
			var non_evil_others: Array = []
			var sh_susp: Dictionary = n.shadow.suspicion if n.shadow != null else n.suspicion
			for p in w.living():
				if p.id != n.id and p.id != sg_id and p.id != target_id and not p.is_evil():
					non_evil_others.append(p.id)
			non_evil_others.sort_custom(func(a, b):
				var sa: float = float(sh_susp.get(a, 0.1))
				var sb: float = float(sh_susp.get(b, 0.1))
				return sa > sb if not is_equal_approx(sa, sb) else a < b
			)
			if not non_evil_others.is_empty():
				key = "present_alt_reject"
				slots = {"demon": w.by_id[sg_id].name, "accomplice": w.by_id[non_evil_others[0]].name}
			else:
				key = "present_alt_reject_solo"
				slots = {"demon": w.by_id[sg_id].name}
	var text: String = Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, key, canonical, slots), tic_memory)
	return _attach_expression(n.id, {"speaker": n.id, "name": n.name, "text": text, "statement": canonical}, key)
