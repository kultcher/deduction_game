## Psychologist role definition and simulation hooks.
##
## Reworked for Chunk 4: Each night from Night 1 (`min_gift_day = 1`), evaluates the
## eligible statements (gift readings, night sightings, and night home alibis; never
## bare role claims or opinions) that the Psychologist heard directly that day in
## public or private conversation:
##   - 0 eligible statements heard -> produces no reading (`{}`).
##   - >= 1 eligible statements heard and 0 lies/misreads -> reports `mode == "none_false"`
##     ("none of the statements I heard on day D were a lie or misread"), linkable in the
##     Workshop to bolster Day-D evidence and challengeable if contradicted.
##   - >= 1 lie/misread and >= 2 eligible statements heard -> reports `mode == "pair"`
##     naming two statements heard that day, at least one of which was a lie or misread.
## Legacy `{"subject", "trusts", "suspects"}` payloads remain supported in `short_text`
## and `LiveAssessment` so existing fixture tests stay backward-compatible.
extends "res://sim/role_def.gd"

const Evidence = preload("res://workshop/live_evidence.gd")


static func _c():
	return load("res://sim/content.gd")


func _init() -> void:
	id = "psychologist"
	display_name = "Psychologist"
	align = "good"
	kind = "info"
	min_gift_day = 1
	tags = ["ongoing_info", "evil_id"]
	desc = "Each night (not the first), learns either two statements they heard directly that day (at least one of which was a lie or misreading), or that none of the eligible statements they heard that day were false."
	shape = "PSYCH_STATEMENTS"
	conversation_nudge = Tuning.Roles.PSYCHOLOGIST.conversation_nudge


func short_text(d: Dictionary, src: String, nm: Callable) -> String:
	if d.has("subject"):
		return "%s Psychologist: %s trusts %s, suspects %s" % [src, nm.call(d.get("subject", "")), nm.call(d.get("trusts", "")), nm.call(d.get("suspects", ""))]
	var mode: String = str(d.get("mode", ""))
	var dh: int = int(d.get("day_heard", 1))
	if mode == "none_false":
		return "%s Psychologist: no false statements heard (D%d)" % [src, dh]
	if mode == "pair":
		var stmts: Array = d.get("statements", [])
		if stmts.size() == 2:
			return "%s Psychologist (D%d): >=1 false (%s / %s)" % [src, dh, nm.call(str(stmts[0].get("source", ""))), nm.call(str(stmts[1].get("source", "")))]
	return "%s Psychologist" % src


static func build_statement_record(w, speaker_id: String, raw_fact: Dictionary, is_false: bool, false_why: String = "", summary_clause: String = "") -> Dictionary:
	var norm: Dictionary = Evidence.normalize_card(raw_fact)
	var kind_s: String = str(raw_fact.get("kind", ""))
	var obs_day: int = int(raw_fact.get("day", w.day))
	var obs_phase: int = int(raw_fact.get("phase", 3 if kind_s == "info" else -1))
	var clause: String = summary_clause
	if clause == "":
		clause = _default_summary(w, speaker_id, raw_fact)
	var pub_stmt: Dictionary = {
		"fact_id": str(norm.get("id", "")),
		"kind": kind_s,
		"source": speaker_id,
		"subject": raw_fact.get("subject", []).duplicate(),
		"day": obs_day,
		"phase": obs_phase,
		"role": str(raw_fact.get("role", "")),
		"data": raw_fact.get("data", {}).duplicate(true) if raw_fact.get("data") is Dictionary else {},
		"block": str(raw_fact.get("block", "")),
		"home": bool(raw_fact.get("home", false)),
		"summary": clause,
		"text": str(raw_fact.get("text", "")),
	}
	return {
		"day_heard": w.day,
		"fact_id": pub_stmt["fact_id"],
		"is_false": is_false,
		"false_why": false_why,
		"public_stmt": pub_stmt,
		"card_fact": raw_fact.duplicate(true),
	}


static func _default_summary(w, speaker_id: String, raw_fact: Dictionary) -> String:
	var C = _c()
	var spk_name: String = w.by_id[speaker_id].name if w.by_id.has(speaker_id) else speaker_id
	var k: String = str(raw_fact.get("kind", ""))
	if k == "info":
		var rn: String = C.role_name(str(raw_fact.get("role", ""))) if raw_fact.get("role", "") != "" else "gift"
		return "%s's %s reading (night %d)" % [spk_name, rn, int(raw_fact.get("day", 0))]
	if k == "sighting":
		var who_id: String = str(raw_fact.get("subject", [""])[0])
		var who_nm: String = w.by_id[who_id].name if w.by_id.has(who_id) else who_id
		return "%s saying they saw %s on %s (night %d)" % [spk_name, who_nm, C.block_name(str(raw_fact.get("block", ""))), int(raw_fact.get("day", 1))]
	if k == "alibi":
		return "%s saying they stayed home on %s (night %d)" % [spk_name, C.block_name(str(raw_fact.get("block", ""))), int(raw_fact.get("day", 1))]
	return "%s's statement" % spk_name


static func record_heard(w, listener, speaker_id: String, raw_fact: Dictionary, is_false: bool, false_why: String = "", summary_clause: String = "") -> void:
	var C = _c()
	if listener == null or speaker_id == "" or speaker_id == listener.id:
		return
	var k: String = str(raw_fact.get("kind", ""))
	if k not in ["info", "sighting", "alibi"]:
		return
	if k == "info":
		var rname: String = str(raw_fact.get("role", ""))
		if rname == "" or (rname == "medium" and raw_fact.get("data", {}).get("item", {}).get("type", "") == "suspicion"):
			return
		if raw_fact.get("data", {}).has("subject") and rname == "psychologist":
			return
	elif k == "sighting":
		if int(raw_fact.get("phase", -1)) != C.NIGHT:
			return
	elif k == "alibi":
		if not bool(raw_fact.get("home", false)) or int(raw_fact.get("phase", -1)) != C.NIGHT:
			return
	var rec: Dictionary = build_statement_record(w, speaker_id, raw_fact, is_false, false_why, summary_clause)
	var fid: String = str(rec.get("fact_id", ""))
	if fid == "":
		return
	for prev in listener.heard_statements:
		if int(prev.get("day_heard", -1)) == w.day and str(prev.get("fact_id", "")) == fid:
			return
	listener.heard_statements.append(rec)


static func companion_facts(w, psych_npc, entry: Dictionary, via_override: String = "") -> Array:
	var out: Array = []
	if str(entry.get("role", "")) != "psychologist":
		return out
	var d: Dictionary = entry.get("data", {})
	if str(d.get("mode", "")) != "pair":
		return out
	var via_id: String = via_override if via_override != "" else psych_npc.id
	var via_nm: String = w.by_id[via_id].name if w.by_id.has(via_id) else via_id
	for st in d.get("statements", []):
		if not (st is Dictionary):
			continue
		var k: String = str(st.get("kind", ""))
		var src_id: String = str(st.get("source", ""))
		if k not in ["info", "sighting", "alibi"] or not w.by_id.has(src_id):
			continue
		var f: Dictionary = {
			"kind": k,
			"source": src_id,
			"subject": st.get("subject", []).duplicate(),
			"day": int(st.get("day", 1)),
			"via": via_id,
			"text": str(st.get("text", "")),
		}
		if int(st.get("phase", -1)) >= 0:
			f["phase"] = int(st.get("phase", -1))
		if k == "info":
			f["role"] = str(st.get("role", ""))
			f["data"] = st.get("data", {}).duplicate(true)
		elif k == "sighting":
			f["block"] = str(st.get("block", ""))
		elif k == "alibi":
			f["block"] = str(st.get("block", ""))
			f["home"] = true
		if f["text"] == "":
			f["text"] = _default_summary(w, src_id, f)
		if not str(f["text"]).begins_with("Via "):
			f["text"] = "Via %s: %s" % [via_nm, str(f["text"])]
		out.append(f)
	return out


static func _pair_reading_dict(day_heard: int, a: Dictionary, b: Dictionary, is_true: bool, why_false: String = "") -> Dictionary:
	var pa: Dictionary = a["public_stmt"].duplicate(true)
	var pb: Dictionary = b["public_stmt"].duplicate(true)
	var out: Dictionary = {
		"data": {
			"mode": "pair",
			"day_heard": day_heard,
			"statements": [pa, pb],
		},
		"true": is_true,
		"text": "I learned that at least one of these two statements from day %d was a lie or misreading: %s; or %s" % [day_heard, str(pa.get("summary", "")), str(pb.get("summary", ""))],
	}
	if not is_true and why_false != "":
		out["why"] = why_false
	return out


static func _none_false_dict(day_heard: int, is_true: bool, why_false: String = "") -> Dictionary:
	var out: Dictionary = {
		"data": {
			"mode": "none_false",
			"day_heard": day_heard,
		},
		"true": is_true,
		"text": "none of the information I heard on day %d was a lie or misread" % day_heard,
	}
	if not is_true and why_false != "":
		out["why"] = why_false
	return out


func generate_reading(w, n, _ctx: Dictionary, _mind) -> Dictionary:
	if w.day < 1:
		return {}
	var todays: Array = n.heard_statements.filter(func(x): return int(x.get("day_heard", -1)) == w.day)
	if todays.is_empty():
		return {}
	var falses: Array = todays.filter(func(x): return bool(x.get("is_false", false)))
	var trues: Array = todays.filter(func(x): return not bool(x.get("is_false", false)))
	var broken: bool = n.gift_broken()
	if not broken:
		if falses.is_empty():
			return _none_false_dict(w.day, true)
		if todays.size() < 2:
			return {}
		var chosen_f: Dictionary = w.pick(falses)
		var others: Array = todays.filter(func(x): return str(x.get("fact_id", "")) != str(chosen_f.get("fact_id", "")))
		if others.is_empty():
			return {}
		var chosen_other: Dictionary = w.pick(others)
		var pair_arr: Array = w.shuffled([chosen_f, chosen_other])
		return _pair_reading_dict(w.day, pair_arr[0], pair_arr[1], true)
	# Broken (Poisoned or Delusional): can report two true statements, two lies, or a false "none_false".
	var b_why: String = "poisoned" if n.poisoned else "delusional"
	if not falses.is_empty() and (todays.size() < 2 or w.chance(0.4)):
		return _none_false_dict(w.day, false, b_why)
	if trues.size() >= 2 and (falses.is_empty() or w.chance(0.65)):
		var sh_t: Array = w.shuffled(trues)
		return _pair_reading_dict(w.day, sh_t[0], sh_t[1], false, b_why)
	if todays.size() >= 2:
		var sh_all: Array = w.shuffled(todays)
		var has_f: bool = bool(sh_all[0].get("is_false", false)) or bool(sh_all[1].get("is_false", false))
		return _pair_reading_dict(w.day, sh_all[0], sh_all[1], has_f, "" if has_f else b_why)
	return {}


func generate_bluff_reading(w, n, _plan: Dictionary, s: String, _mate, _asked: Array) -> Dictionary:
	if w.day < 1:
		return {}
	var todays: Array = n.heard_statements.filter(func(x): return int(x.get("day_heard", -1)) == w.day)
	var by_sg: Array = todays.filter(func(x): return str(x.get("public_stmt", {}).get("source", "")) == s)
	var non_evil: Array = todays.filter(func(x):
		var src_id: String = str(x.get("public_stmt", {}).get("source", ""))
		return w.by_id.has(src_id) and not w.by_id[src_id].is_evil())
	if not by_sg.is_empty() and todays.size() >= 2:
		var first_s: Dictionary = w.pick(by_sg)
		var pool_other: Array = non_evil.filter(func(x): return str(x.get("fact_id", "")) != str(first_s.get("fact_id", "")))
		if pool_other.is_empty():
			pool_other = todays.filter(func(x): return str(x.get("fact_id", "")) != str(first_s.get("fact_id", "")))
		if not pool_other.is_empty():
			var second_s: Dictionary = w.pick(pool_other)
			var pair_b: Array = w.shuffled([first_s, second_s])
			var entry_b: Dictionary = _pair_reading_dict(w.day, pair_b[0], pair_b[1], false, "evil fabrication")
			entry_b.erase("true")
			entry_b.erase("why")
			return {"entry": entry_b, "why": "pairs scapegoat %s's statement as a suspected lie" % s}
	if non_evil.size() >= 2 and w.chance(0.6):
		var sh_ne: Array = w.shuffled(non_evil)
		var entry_ne: Dictionary = _pair_reading_dict(w.day, sh_ne[0], sh_ne[1], false, "evil fabrication")
		entry_ne.erase("true")
		entry_ne.erase("why")
		return {"entry": entry_ne, "why": "casts doubt on two townsfolk statements from day %d" % w.day}
	if not todays.is_empty():
		var entry_nf: Dictionary = _none_false_dict(w.day, false, "evil fabrication")
		entry_nf.erase("true")
		entry_nf.erase("why")
		return {"entry": entry_nf, "why": "vouches that day %d statements contained no lies" % w.day}
	return {}


func fake_medium_reading(w, _n, dd, s: String, _sg, _d, _goods: Array, _other: Callable, e: Dictionary, _demon_implicated: bool) -> Dictionary:
	var dh: int = maxi(1, int(e.get("day", 1)))
	e["data"] = {"mode": "none_false", "day_heard": dh}
	e["text"] = "none of the information I heard on day %d was a lie or misread" % dh
	return {"entry": e, "why": "the dead Psychologist %s vouched for day %d statements (protecting cover vs %s)" % [dd.id, dh, s], "frames": false}
