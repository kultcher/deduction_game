## The nominee's defence: whereabouts, readings and disclosures it answers with
## (split from `sim/mind_meeting.gd`).
extends "res://sim/mind_meeting_base.gd"


# ---------------------------------------------------------------- the defence

## The nominee answers (meeting-flow plan, step 2). One or two moves, chosen from what's
## against them and what they have:
##   reveal    a night-walking gift explains being out: claim it and share readings
##             (normal claim effects), plus an excuse for the sightings;
##   secret    a good NPC's personal reason for being out, confessed;
##   red_herring / pair_other / misled / lying   against a reading that names them;
##   fear / desperation   when there's nothing else ("I know I'm not evil").
## Each underlying defence has one stable ledger identity, independently of the
## day it is repeated. A challenge to a different original reading is distinct.
## weighed by the listener's regard for the defender and the defender's credibility, so
## it rises and falls with them. Only a reveal carries real weight; the rest sway little.
## Evil defends as the good townsperson it pretends to be: its bluff stands in for its gift,
## and it has no secret to confess. Returns {lines, facts, moves}.
static func _reading_known_to_defender(d, src_id: String, rd: Dictionary, disclosed_facts: Array) -> bool:
	if rd.get("shared", false):
		return true
	for f in disclosed_facts:
		if f.get("kind", "") == "info" and f.get("source", "") == src_id and f.get("role", "") == rd.get("role", "") and int(f.get("day", -2)) == int(rd.get("day", -1)):
			return true
	var d_mind = d.shadow if d.is_evil() and d.shadow != null else d
	if d_mind.known_claims.has(src_id) and rd in d_mind.known_claims[src_id].get("readings", []):
		return true
	var eid: String = info_eid(src_id, rd)
	if not d_mind.ledger.has(eid):
		return false
	var receipts: Dictionary = d_mind.ledger[eid].get("meta", {}).get("workshop_receipts", {})
	if receipts.is_empty():
		return true
	return receipts.values().any(func(r): return not r.get("content", {}).get("anonymous", false))

## The answer to a case resting on a daytime sighting (2d): {line, facts}, or {} when the heaviest
## item against them (of those the player's case cites, when it's a filed case) isn't one. The
## place and time are their own whereabouts that phase; the others named are everyone else there
## then, from the public whereabouts, two or three of them. If one of those is someone the
## defender suspects (a good defender's own suspicion at the nomination floor; for evil, the town's
## view), they point at them instead. Only at a nomination: the "_stand" lines.
static func _day_whereabouts_defence(w, d, items: Array, case_backed: bool) -> Dictionary:
	var pool: Array = items.filter(func(x): return (not case_backed) or x.get("in_case", false))
	if pool.is_empty():
		return {}
	pool.sort_custom(func(a, b): return float(a.get("contrib", 0.0)) > float(b.get("contrib", 0.0)))
	var top: Dictionary = pool[0]
	if str(top.get("channel", "")) != "whereabouts_day":
		return {}
	var ep: PackedStringArray = str(top.get("eid", "")).split(":")
	if ep.size() < 6:
		return {}
	var sd: int = int(ep[3])
	var sp: int = int(ep[4])
	var at: String = str(d.history.get(w.time_key(sd, sp), ""))
	if at == "" or at.begins_with("home") or at.begins_with("night") or at == "dead":
		return {}
	# Who it can name: the living who were there (no use asking the dead; Steward Nov 19 A6), and
	# for an evil defender not its own teammates, whom it won't point at or call as witnesses
	# (Steward A5: that would be a tell). Leaving them out is no lie: it never says it was alone.
	var present: Array = []
	var others_there: int = 0
	for x in w.npcs:
		if x != d and str(x.history.get(w.time_key(sd, sp), "")) == at:
			others_there += 1
			if x.alive and not (d.is_evil() and x.is_evil()):
				present.append(x)
	var place: String = w.loc_name(at)
	var when: String = _day_when(w, sd, sp)
	var slots: Dictionary = {"place": place, "when": when, "Place": _first_upper(place), "When": _first_upper(when)}
	var line: Dictionary
	var named: Array = []  # who the spoken line names (Codex on #318: the cards follow the words)
	if present.is_empty():
		line = say_voiced(d, "defence_day_alone", "I was at %s %s. Being seen in the open is no crime." % [place, when], slots)
	else:
		var suspect = null
		for x in present:
			var heat: float = Evil.town_view(w, x) if d.is_evil() else susp(d, x.id)
			if heat >= Tuning.Meeting.NOMINATION_FLOOR and (suspect == null or heat > (Evil.town_view(w, suspect) if d.is_evil() else susp(d, suspect.id))):
				suspect = x
		if suspect != null:
			slots["suspect"] = suspect.name
			named = [suspect]
			line = say_voiced(d, "defence_day_others_pointed_stand", "I was at %s %s. So was %s, if it's company you're weighing." % [place, when, suspect.name], slots)
		else:
			named = present.slice(0, 3)
			var names: Array = named.map(func(x): return x.name)
			if names.size() == 1:
				# One companion: its own singular line (the {others} lines are two or three names).
				slots["other"] = names[0]
				line = say_voiced(d, "defence_day_other_one", "I was at %s %s, and so was %s. Ask them what they saw." % [place, when, names[0]], slots)
			else:
				var others: String = ", ".join(PackedStringArray(names.slice(0, names.size() - 1))) + " and " + names[-1]
				slots["others"] = others
				line = say_voiced(d, "defence_day_others", "I was at %s %s, and so were %s. Ask any of them what they saw." % [place, when, others], slots)
	var facts: Array = [{"kind": "sighting", "subject": [d.id], "source": d.id, "loc": at, "block": w.loc_block(at), "day": sd, "phase": sp, "self_report": true,
		"text": "%s says they were at %s, day %d %s." % [d.name, place, sd, C.PHASES[sp]]}]
	for x in named:
		facts.append({"kind": "sighting", "subject": [x.id], "source": d.id, "loc": at, "block": w.loc_block(at), "day": sd, "phase": sp,
			"text": "%s says %s was at %s too, day %d %s." % [d.name, x.name, place, sd, C.PHASES[sp]]})
	w.dlog.think(d.id, "defence", "Answers a case resting on where they were %s: %s, with %d others there." % [when, place, others_there])
	return {"line": line, "facts": facts}

## A slot's sentence-start form: only the first letter raised ("Yesterday afternoon", not
## String.capitalize()'s "Yesterday Afternoon"; Steward Nov 19 A6).
static func _first_upper(t: String) -> String:
	return t if t.is_empty() else t.substr(0, 1).to_upper() + t.substr(1)

## "this morning", "yesterday afternoon", "the first evening": a day phase, as said on w.day.
static func _day_when(w, sd: int, sp: int) -> String:
	var ph: String = C.PHASES[sp].to_lower()
	if sd == w.day:
		return "this " + ph
	if sd == w.day - 1:
		return "yesterday " + ph
	return "the %s %s" % [C.ORDINALS[clampi(sd - 1, 0, C.ORDINALS.size() - 1)], ph]

## The night a good defender was framed on: every sighting against them names a night
## they (honestly) spent at home. -1 if evil, if any sighting is of a real outing, or if
## no sighting names a night. Anyone recorded as out is not framed.
## The group a reading says holds evil, for "it's another of us": a count over a group or
## site, a role found within a group, a Chronicler's three, or a Surveyor's mixed block. Not a pair (its own defence),
## and not a Night Watch list, whose people were each seen, not grouped.
static func _reading_group(w, rd: Dictionary) -> Array:
	var rdef = C.role_def(str(rd.get("role", "")))
	if rdef == null:
		return []
	var dd: Dictionary = rd.get("data", {})
	if str(rd.get("role", "")) == "medium":
		# A relay is read as the reading it carries: a relayed Night Watch list stays a list
		# of sightings (Codex on #249).
		var it: Dictionary = dd.get("item", {})
		return _reading_group(w, it.get("entry", {})) if str(it.get("type", "")) == "reading" else []
	if str(rd.get("role", "")) == "surveyor":
		# "Not all of them share an alignment": the block's residents (89077's Chapel Hill).
		if dd.has("block") and not bool(dd.get("same", true)):
			var blk: String = str(dd["block"])
			return w.npcs.filter(func(m): return m.home_block == blk).map(func(m): return m.id)
		return []
	if str(rd.get("role", "")) != "chronicler" and not (str(rdef.get("shape")) in ["GROUP_COUNT", "ROLE_AT_SITE", "ROLE_IN_GROUP"]):
		return []
	var g: Array = Gifts.implicated(rd)
	# A count as large as the group leaves no one in it innocent, so no "another of us"
	# (Codex on #249).
	if dd.has("count") and int(dd.get("count", 0)) >= g.size():
		return []
	return g if g.size() >= 2 else []

static func framed_night_of(w, d, out_items: Array) -> int:
	if d.is_evil():
		return -1
	var best: int = -1
	var best_contrib: float = -INF
	for x in out_items:
		var p: PackedStringArray = str(x.get("eid", "")).split(":")
		if p.size() < 5 or p[0] != "sighting":
			continue
		var nd: int = int(p[3])
		var where: String = str(d.history.get(w.time_key(nd, C.NIGHT), "home:"))
		if where.begins_with("night:"):
			return -1
		if float(x.get("contrib", 0.0)) > best_contrib:
			best_contrib = float(x.get("contrib", 0.0))
			best = nd
	return best

static func _disclosed_items_against(w, d, accuser, disclosed_facts: Array) -> Array:
	var out: Array = []
	var seen_eids: Dictionary = {}
	var case_eids: Dictionary = {}
	var d_mind = d.shadow if d.is_evil() and d.shadow != null else d
	if accuser != null:
		for it in _nomination().case_against(w, accuser, d.id, 6):
			if it.get("own_sighting", false):
				var sight_spoken: bool = bool(it.get("own_sighting_disclosed", false)) or disclosed_facts.any(func(f): return f.get("kind", "") == "sighting" and f.get("source", "") == accuser.id and d.id in f.get("subject", []))
				if sight_spoken:
					out.append(it)
					seen_eids[it["eid"]] = true
			elif it["eid"].begins_with("info:"):
				var p: PackedStringArray = str(it["eid"]).split(":")
				var sn = w.by_id.get(p[1]) if p.size() >= 2 else null
				if sn != null and not it["entry"].is_empty() and _reading_known_to_defender(d, sn.id, it["entry"], disclosed_facts):
					out.append(it)
					seen_eids[it["eid"]] = true
			elif it["kind"] == "public" or d_mind.ledger.has(it["eid"]):
				out.append(it)
				seen_eids[it["eid"]] = true
	for f in disclosed_facts:
		# Against them by name, or by the group it points at (a Surveyor's block names no one).
		if f.get("kind", "") == "info" and (d.id in f.get("subject", []) or d.id in _reading_group(w, f)):
			var src_id: String = str(f.get("source", ""))
			var sn2 = w.by_id.get(src_id)
			if sn2 == null or sn2 == d:
				continue
			for en in sn2.info_log:
				if en.get("role", "") == f.get("role", "") and int(en.get("day", -1)) == int(f.get("day", -2)):
					var eid2: String = info_eid(src_id, en)
					case_eids[eid2] = true
					if not seen_eids.has(eid2):
						var r_score: Dictionary = ReasonAttribution.score_reading_entry_in_world(w, src_id, en, d.id)
						out.append({"eid": eid2, "why": "their reading pointed at me", "contrib": float(r_score["contrib"]), "kind": "public", "strength": float(r_score["strength"]), "entry": en, "channel": "report"})
						seen_eids[eid2] = true
		elif f.get("kind", "") == "sighting" and d.id in f.get("subject", []):
			var s_eid: String = "sighting:%s:%s:%d:%s" % [str(f.get("source", "")), d.id, int(f.get("day", -1)), str(f.get("block", ""))]
			# A sighting by day (where they were in the morning, afternoon or evening) is
			# not a night outing: the defence mustn't answer it as "where I was last night"
			# (playtest 26532: Isolde, on a case about day-1 whereabouts). It keeps its own
			# id, so it can't stand for the night of the same number either.
			var by_day: bool = int(f.get("phase", C.NIGHT)) != C.NIGHT
			if by_day:
				s_eid = "sighting_day:%s:%s:%d:%d:%s" % [str(f.get("source", "")), d.id, int(f.get("day", -1)), int(f.get("phase", -1)), str(f.get("block", ""))]
			# Only the form it was seen in is in the case (Steward A5, Nov 17: the night form went
			# in first, so a day sighting still marked the night of the same number).
			case_eids[s_eid] = true
			if not seen_eids.has(s_eid):
				var s_score: Dictionary = ReasonAttribution.score_disclosed_fact_in_world(w, d_mind, f, d.id)
				if by_day:
					out.append({"eid": s_eid, "why": "where I was by day", "contrib": float(s_score["contrib"]), "kind": "public", "strength": float(s_score["strength"]), "entry": {}, "channel": "whereabouts_day"})
				else:
					out.append({"eid": s_eid, "why": "seen out at night", "contrib": float(s_score["contrib"]), "kind": "public", "strength": float(s_score["strength"]), "entry": {}, "channel": "movement_out"})
				seen_eids[s_eid] = true
	# Mark what the player's case actually cites, so the defence's "your case rests on"
	# names one of those, not the heaviest thing anyone holds against them (97626).
	for it in out:
		if case_eids.has(str(it.get("eid", ""))):
			it["in_case"] = true
	return out

# ---------------------------------------------------------------- night-sighting rebuttals

## "I was seen out, but no one died that night" / "the death was on another block" (BACKLOG
## "Explicit night-sighting rebuttals", Michael): an argument from the public death record,
## said in the defender's own words. Speech only: it carries no weight and changes no belief,
## since the judge already reasons from the same record (LiveActivity._profile_paths sends the
## Demon straight to a victim's home on a death night, by `demon_routes`: from its home block to the victim's).
## Returns {} or {"variant": "other_block"|"no_death", "night": nd, "cites": {...}}.
##   other_block: a public Demon death on night nd, and `block` (where they were seen) is neither
##     the defender's own home block nor any victim's home block, so had they been the Demon
##     they could not have been seen there (people move straight from block to block; the
##     judge's outing for that person).
##   no_death: nobody died on night nd (the morning's public "quiet night"), and the defender
##     knows of nothing that could have turned the Demon away that night.
## Night 0 never (the Demon doesn't kill then, so a quiet night 0 argues nothing). Only public
## or held knowledge: deaths and quiet nights are announced; a thwart counts only when the
## defender could know of it (a public Warden or Veteran claim, a ward the player showed them or
## the town, a Warden telling them of a save, or their own protective gift). It never says what
## isn't so: if they were truly out on their own or a victim's block, there is no other_block (good or evil alike),
## so evil only ever says it when it's true as stated.
static func night_route_rebuttal(w, d, nd: int, block: String) -> Dictionary:
	if nd < 1 or nd >= w.day:
		return {}
	var deaths: Array = w.public_log.filter(func(e): return str(e.get("kind", "")) == "demon_death" and int(e.get("day", -1)) == nd and not e.get("subjects", []).is_empty())
	if not deaths.is_empty():
		if block == "":
			return {}
		var victims: Array = []
		var on_route: Array = []
		for e in deaths:
			var v = w.by_id.get(str(e["subjects"][0]))
			if v == null:
				return {}
			for b in C.route(d.home_block, v.home_block):
				if not (b in on_route):
					on_route.append(b)
			victims.append(v.id)
		if block in on_route:
			return {}
		# "I was never on {block}" must be true of the night they spent at home too: a defender
		# who lives on a victim's block was on it, out or not (Codex on #415).
		for vid in victims:
			if w.by_id[vid].home_block == d.home_block:
				return {}
		# True as stated: they weren't really out on their own or a victim's block themselves.
		var where: String = str(d.history.get(w.time_key(nd, C.NIGHT), ""))
		if where.begins_with("night:") and w.loc_block(where) in on_route:
			return {}
		var first = w.by_id[victims[0]]
		return {"variant": "other_block", "night": nd, "cites": {"deaths": victims, "victim_block": first.home_block, "route": on_route, "sighting_block": block}}
	if not w.dlog.entries.any(func(e): return e["type"] == "quiet_night" and int(e["data"].get("night", -1)) == nd):
		return {}
	if knows_of_thwart(w, d, nd):
		return {}
	return {"variant": "no_death", "night": nd, "cites": {"quiet_night": nd}}

## Whether the defender could know of something that turned the Demon away on night nd: only
## public or held signals, never why the night was really quiet.
static func knows_of_thwart(w, d, nd: int) -> bool:
	for pc in w.public_claims:
		var qdef = C.role_def(str(pc.get("role", ""))) if C.has_role_def(str(pc.get("role", ""))) else null
		if qdef != null and qdef.can_cause_quiet_night:
			return true
	if not d.is_evil() and C.has_role_def(d.role) and C.role_def(d.role).can_cause_quiet_night:
		return true
	for e in w.dlog.entries:
		match str(e["type"]):
			"player_ward_context":
				if int(e["data"].get("night", -1)) == nd and (e["data"].get("public", false) or d.id in e["data"].get("listeners", [])):
					return true
			"warden_tells_save":
				if str(e["target"]) == d.id and int(e["data"].get("night", -1)) == nd:
					return true
			"protect":
				if int(e["day"]) == nd and str(e["actor"]) == "player" and str(e["target"]) == d.id:
					return true
	return false

## The rebuttal's line, for the town (meeting and podium) or the Demonologist alone, in the
## speaker's voice (defence_night_* / private_night_*; Michael, Nov 20). In block terms: people
## move from block to block, there are no roads.
static func rebuttal_line(w, d, reb: Dictionary, private: bool = false) -> Dictionary:
	var nd: int = int(reb["night"])
	var when: String = C.spoken_when(nd, w.day)
	if str(reb["variant"]) == "other_block":
		var bname: String = C.block_name(str(reb["cites"]["victim_block"]))
		return say_voiced(d, "private_night_other_block" if private else "defence_night_other_block",
			"Someone died on %s that night; I was never on %s." % [bname, bname], {"block": bname, "when": when})
	return say_voiced(d, "private_night_no_death" if private else "defence_night_no_death",
		"I was seen out %s, but no one died that night." % when, {"when": when})

## Whether the rebuttal fits the account the defender has given of that night (Codex on #415).
## "No one died" opens "I was seen out", so it needs an account that owns the outing: an
## admitted walk, a confessed errand or a duty that took them out. After a home alibi, a
## refusal or no account at all it would retract what they said, so it isn't said. "Another
## block" ("I was never on {block}") must not retract an account either: not after one that
## puts them on a victim's block, nor after a duty that walks every block (the lamp route, the
## Sexton's toll), whatever they really did (Codex on #415).
static func rebuttal_fits_account(w, d, reb: Dictionary) -> bool:
	if reb.is_empty():
		return false
	var acct: Dictionary = d.dialogue_memory.get("night_accounts", {}).get(str(int(reb["night"])), {})
	if str(reb["variant"]) != "no_death":
		if str(acct.get("duty", "")) in ["lamplighter", "sexton"]:
			return false
		var victim_blocks: Array = reb["cites"].get("deaths", []).map(func(v): return w.by_id[v].home_block if w.by_id.has(v) else "")
		return not (str(acct.get("block", "")) in victim_blocks)
	if acct.is_empty() or str(acct.get("kind", "")) == "refusal":
		return false
	return not (str(acct.get("kind", "")) == "alibi" and bool(acct.get("home", false)))

## The logged reason (every argument has one; evil's is true but misleading).
static func note_rebuttal(w, d, reb: Dictionary, where: String) -> void:
	var what: String = "a death on another block" if str(reb["variant"]) == "other_block" else "no one died"
	if d.is_evil():
		w.dlog.think(d.id, "rebuttal", "%s: answers the sighting on night %d with %s. True but misleading: it says nothing of what they did that night." % [where, int(reb["night"]), what], reb.merged({"evil": true}))
	else:
		w.dlog.think(d.id, "rebuttal", "%s: answers the sighting on night %d with %s, from the public record." % [where, int(reb["night"]), what], reb.merged({"evil": false}))

static func rebuttal_scope(reb: Dictionary, sighting_eid: String) -> Dictionary:
	return {"type": "rebuttal", "variant": str(reb["variant"]), "night": int(reb["night"]), "sighting": sighting_eid, "cites": reb["cites"].duplicate(true)}

## The town hears a rebuttal said outside defend_self (the podium): the same speech-only
## defence entry, weightless.
static func hear_rebuttal(w, d, scope: Dictionary) -> void:
	var identity: String = "def:%s:%s:%s" % [d.id, scope.type, JSON.stringify(WorkshopLedger.Evidence.canonical(scope)).sha256_text()]
	for l in w.living():
		if l == d:
			continue
		ledger_hear(w, l, identity, [], 0.0, [d.id, -1, "report"], {"kind": "defence", "move": "rebuttal", "scope": scope.duplicate(true), "hearing_scale": 0.0})

## The night sighting a defence answers: the case's hinge (as 2c reads it), else the framed
## night's sighting, else the heaviest night sighting against them. {} when none.
static func _rebuttal_target(hinge: Dictionary, framed_night: int, out_items: Array) -> Dictionary:
	if str(hinge.get("channel", "")) == "movement_out" and str(hinge.get("eid", "")).begins_with("sighting:"):
		return hinge
	var best: Dictionary = {}
	for x in out_items:
		var p: PackedStringArray = str(x.get("eid", "")).split(":")
		if p.size() < 5 or p[0] != "sighting":
			continue
		if framed_night >= 0 and int(p[3]) != framed_night:
			continue
		if best.is_empty() or float(x.get("contrib", 0.0)) > float(best.get("contrib", 0.0)):
			best = x
	return best

static func defend_self(w, d, nominator_id: String, disclosed_facts: Array = []) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	var moves: Array = []
	if d.silenced:
		return {"lines": [{"speaker": d.id, "name": d.name, "text": "...", "silent": true}], "facts": [], "moves": ["silenced"]}
	# Ill-Omened (burdens prototype): the nominee cites the omen before anything else. Only
	# this restatement arms it (Michael, Nov 20).
	var omen: Dictionary = Burdens.omen_at_nomination(w, d)
	if not omen.is_empty():
		lines.append(omen["line"])
		facts.append(omen["fact"])
		moves.append("ill_omened")
	var accuser = w.by_id.get(nominator_id) if nominator_id != "player" else null
	if accuser == null:
		var best = 0.0
		for m in w.living():
			if m != d and susp(m, d.id) > best:
				best = susp(m, d.id)
				accuser = m
	var items: Array = _disclosed_items_against(w, d, accuser, disclosed_facts)
	# Against the player's filed case, go after the card it depends on: the heaviest item
	# against them (the reading challenged below, or the night disputed in step 2c).
	var case_backed: bool = nominator_id == "player" and int(w.meeting.get("pending", {}).get("case_card", 0)) > 0
	var hinge: Dictionary = {}
	if case_backed and not items.is_empty():
		items.sort_custom(func(a, b): return float(a.get("contrib", 0.0)) > float(b.get("contrib", 0.0)))
		# Only what a defence can answer: a reading or a night. Where they were by day has
		# no answer of its own here, so the hinge is the next thing the case cites.
		var cited: Array = items.filter(func(x): return x.get("in_case", false) and x.get("channel", "") != "whereabouts_day")
		if not cited.is_empty():
			hinge = cited[0]
	var role: String = w.evil_plan["bluffs"].get(d.id, "") if d.is_evil() else d.role
	var out_items: Array = items.filter(func(x): return x.get("channel", "") != "whereabouts_day" and (x.get("channel", "") in ["movement_out", "alibi_contradiction"] or "out" in x["why"] or "night" in x["why"]))
	var out_weight = 0.0
	for x in out_items:
		out_weight += x["contrib"]
	# A good defender sighted on a night they spent at home (a frame) has no outing to
	# explain: they give their account of that night (2c), not "I was out because..."
	var framed_night: int = framed_night_of(w, d, out_items)
	var move_strengths = {}
	var move_scales = {}
	var defence_scopes = {}
	# The case rests on where they were by day (2d below): that answer comes first, before any
	# night account a weaker or uncited item could prompt (Codex on #318).
	var day_def: Dictionary = _day_whereabouts_defence(w, d, items, case_backed)
	var day_first: bool = not day_def.is_empty()
	# The night-sighting rebuttal (BACKLOG "Explicit night-sighting rebuttals", Michael): the
	# cheap answer to the same night, from the public death record. Speech only, added to
	# whatever else they say, never instead of it: no weight, and it gates none of the moves
	# below (it joins the moves list only at the end). Deterministic, no roll.
	var reb: Dictionary = {}
	var reb_eid: String = ""
	var reb_target: Dictionary = {} if day_first else _rebuttal_target(hinge, framed_night, out_items)
	if not reb_target.is_empty():
		reb_eid = str(reb_target.eid)
		var rp: PackedStringArray = reb_eid.split(":")
		reb = night_route_rebuttal(w, d, int(rp[3]), rp[4] if rp.size() >= 5 else "")
	var reb_at: int = lines.size()  # said before any gift reveal or confession
	var reb_after_account: int = -1  # or just after their account of that same night
	# 1. A gift that walks at night explains being seen out.
	if not day_first and not out_items.is_empty() and framed_night < 0 and C.ROLES.get(role, {}).get("night_walk", false):
		var parts = {"facing_the_rope": C.DEFENCE_ROPE, "strength": maxf(0.2, out_weight)}
		var safety: float = _meeting().block_safety(w, d)
		if safety > 0.0:
			parts["block_safety"] = -safety * Tuning.Meeting.BLOCK_SAFETY_DEFENCE_RELIEF
		for k in _meeting().reveal_cost(w, d):
			parts["cost_" + k] = -_meeting().reveal_cost(w, d)[k]
		if d.claim_public or decide(w, d, "defence_reveal", parts, "Explain being out with my gift (%s)?" % role):
			if not d.claim_public:
				_meeting()._public_disclosure(w, d, lines, facts)
			lines.append(say_voiced(d, "defence_reveal", "I was out because I'm the %s. That's what you saw." % C.role_name(role), {"role": C.role_name(role)}))
			moves.append("reveal")
			move_strengths["reveal"] = minf(Tuning.Meeting.DEFENCE_REVEAL_CAP, out_weight)
			move_scales["reveal"] = 1.0
			defence_scopes["reveal"] = {"type": "gift_claim", "role": role}
	# 2. A personal secret explains it (good only: evil has nothing true to confess).
	if not day_first and moves.is_empty() and not out_items.is_empty() and framed_night < 0 and not d.is_evil() and not d.secret.is_empty():
		var confess_parts = {"facing_the_rope": 0.5, "privacy": (0.4 - trait_of(d, "privacy")) * 1.0}
		var confess_safety: float = _meeting().block_safety(w, d)
		if confess_safety > 0.0:
			confess_parts["block_safety"] = -confess_safety * Tuning.Meeting.BLOCK_SAFETY_DEFENCE_RELIEF
			w.dlog.think(d.id, "defence", "Weighs holding back: %s is already on the block (%d votes)." % [str(w.meeting.get("block", "")), int(w.meeting.get("block_count", 0))])
		if decide(w, d, "defence_confess", confess_parts, "Confess my secret to explain being out?"):
			d.secret_known = true
			lines.append(say_voiced(d, "confess_secret_public", "I wasn't out for anything wicked. I %s." % d.secret.get("me", d.secret.get("text", "")), {"secret": d.secret.get("me", d.secret.get("text", ""))}))
			Burdens.reveal_cost(w, d, w.living())
			facts.append(Burdens.with_errand(w, d, {"kind": "secret", "subject": [d.id], "owner": d.id, "source": d.id,
				"secret_kind": d.secret.get("kind", ""), "text": "%s confessed at the meeting why they were out: %s %s." % [d.name, d.name, d.secret.get("text", "")]}))
			moves.append("secret")
			move_strengths["secret"] = minf(Tuning.Meeting.DEFENCE_SECRET_CAP, out_weight)
			move_scales["secret"] = 1.0
			defence_scopes["secret"] = {"type": "secret_claim", "owner": d.id, "kind": d.secret.get("kind", "")}
	# 2c. The case hangs on a night sighting their gift or a confession hasn't explained,
	# or they were framed with one: they give their account of that night, before the town
	# (the podium press's answer).
	var hinge_night: bool = str(hinge.get("channel", "")) == "movement_out" and str(hinge.get("eid", "")).begins_with("sighting:")
	if not day_first and moves.is_empty() and (hinge_night or framed_night >= 0):
		var hnd: int = framed_night
		if hinge_night:
			var hp: PackedStringArray = str(hinge.eid).split(":")
			hnd = int(hp[3]) if hp.size() >= 4 else -1
		if hnd >= 0 and hnd < w.day:
			lines.append(say_voiced(d, "defence_case_hinge_night", "Your case rests on where I was %s, so hear it from me." % C.spoken_when(hnd, w.day), {"when": C.spoken_when(hnd, w.day)}))
			var acct: Dictionary = load("res://sim/mind_podium.gd").press_night(w, d, hnd, true)
			lines.append_array(acct.get("lines", []))
			facts.append_array(acct.get("facts", []))
			if not reb.is_empty() and int(reb["night"]) == hnd:
				reb_after_account = lines.size()
			moves.append("dispute_night")
			move_strengths["dispute_night"] = 1.0
			move_scales["dispute_night"] = absf(float(Tuning.Meeting.DEFENCE_PLEA_RELIEF))
			defence_scopes["dispute_night"] = {"type": "plea"}
	# 2d. The case rests on where they were by day (BACKLOG "A defence's answer to a
	# daytime-whereabouts case", Michael, Nov 16 and 19): they say where they were and who else
	# was there, from the public whereabouts (true for good and evil alike: no lie, Nov 19).
	if moves.is_empty() and day_first:
		lines.append(day_def["line"])
		facts.append_array(day_def["facts"])
		moves.append("day_whereabouts")
		move_strengths["day_whereabouts"] = 1.0
		move_scales["day_whereabouts"] = absf(float(Tuning.Meeting.DEFENCE_PLEA_RELIEF))
		defence_scopes["day_whereabouts"] = {"type": "plea"}
	# 3. Against a reading that names them (against a filed case, the one it rests on).
	if moves.size() < 2:
		var rd = {}
		var src_id = ""
		for x in items:
			# Against the player's filed case, only a reading the case cites: one it doesn't
			# use isn't the accusation (89077: Constance calling Kiran a liar over his
			# Psychologist reading).
			if case_backed and not x.get("in_case", false):
				continue
			if x["eid"].begins_with("info:"):
				var parts2 = x["eid"].split(":")
				var sn = w.by_id.get(parts2[1])
				if sn == null or sn == d:
					continue
				for en in sn.info_log:
					if info_eid(sn.id, en) == x["eid"] and _reading_known_to_defender(d, sn.id, en, disclosed_facts):
						rd = en
						src_id = sn.id
				if not rd.is_empty():
					break
		# A reading that calls them evil, answered by Marked (burdens prototype): a real holder's
		# forced reveal, or evil's bluff. It explains the reading, so no "they're lying" follows.
		var burden_ans: Dictionary = Burdens.answer_evil_reading(w, d, rd, true) if not rd.is_empty() else {}
		if not burden_ans.is_empty():
			lines.append(burden_ans["line"])
			if not burden_ans["fact"].is_empty():
				facts.append(burden_ans["fact"])
			moves.append("marked")
			move_strengths["marked"] = 1.0
			move_scales["marked"] = absf(float(Tuning.Meeting.DEFENCE_MISLED_RELIEF))
			defence_scopes["marked"] = {"type": "secret_claim", "owner": d.id, "kind": "marked"}
			rd = {}
		if not rd.is_empty():
			var dd: Dictionary = rd.get("data", {})
			var pair: Array = dd.get("pair", [])
			var src = w.by_id[src_id]
			# The hinge line, and its index: a "Then X is lying" after it needs the denial
			# spelled out, or the "Then" follows nothing (playtest triage 2.2).
			var hinge_at: int = -1
			if case_backed and str(hinge.get("eid", "")) == info_eid(src_id, rd):
				hinge_at = lines.size()
				lines.append(say_voiced(d, "defence_case_hinge_reading", "Your whole case rests on %s's reading." % src.name, {"source": src.name}))
			var rdef_rd = C.role_def(rd.get("role", ""))
			var custom_def: Dictionary = rdef_rd.try_reading_defence(w, d, src, src_id, rd, _mind(), WorkshopLedger) if rdef_rd != null else {}
			if custom_def.get("handled", false):
				var mv_name: String = custom_def["move"]
				lines.append(custom_def["line"])
				moves.append(mv_name)
				move_strengths[mv_name] = 1.0
				move_scales[mv_name] = float(custom_def.get("hearing_scale", 0.05))
				defence_scopes[mv_name] = custom_def["scope"]
			elif pair.size() == 2 and d.id in pair:
				# One incident, one hearing: "it's the other one" accepts the reading, "the
				# reading is wrong" rejects it, so never both. Point at the other only when
				# that's what they believe (good: they suspect the other at least as much as
				# the source; evil: the other isn't a teammate); otherwise challenge it below.
				var other: String = pair[0] if pair[1] == d.id else pair[1]
				var fits: bool = (not Evil.is_teammate(w, d, other)) if d.is_evil() else susp(d, other) >= susp(d, src_id)
				if fits and w.by_id.has(other) and w.by_id[other].alive:
					var other_name: String = w.by_id[other].name
					lines.append(say_voiced(d, "defence_pair_other", "One of the two, %s said. It isn't me, so look at %s." % [src.name, other_name], {"source": src.name, "other": other_name}))
					moves.append("pair_other")
					move_strengths["pair_other"] = 1.0
					move_scales["pair_other"] = Tuning.Meeting.DEFENCE_PAIR_OTHER_DELTA
					defence_scopes["pair_other"] = {"type": "rival", "source": src_id, "other": other}
			elif d.id in _reading_group(w, rd):
				# "It's another of us" (89077, Coroner finding 1; Michael, Nov 17): the pair
				# defence for a reading over a group, naming the others where they're few.
				var others: Array = _reading_group(w, rd).filter(func(x): return x != d.id and w.by_id.has(x) and w.by_id[x].alive)
				var pointed: Array = others.filter(func(x): return not Evil.is_teammate(w, d, x)) if d.is_evil() else others
				var fits_g: bool = not pointed.is_empty() and (d.is_evil() or pointed.any(func(x): return susp(d, x) >= susp(d, src_id)))
				if fits_g:
					# Named when there are one or two others (a group of three at most) and none is
					# a teammate it would be shielding; otherwise "the others" (a small call).
					if others.size() <= 2 and pointed.size() == others.size():
						var named_s: String = w._names(pointed)
						lines.append(say_voiced(d, "defence_group_named", "%s's reading points at one of us. It isn't me, so look at %s." % [src.name, named_s], {"source": src.name, "others": named_s}))
					else:
						lines.append(say_voiced(d, "defence_group_others", "%s's reading points at one of several of us. It isn't me, so look among the rest." % src.name, {"source": src.name}))
					moves.append("group_other")
					move_strengths["group_other"] = 1.0
					move_scales["group_other"] = Tuning.Meeting.DEFENCE_PAIR_OTHER_DELTA
					defence_scopes["group_other"] = {"type": "rival", "source": src_id, "others": pointed}
			# A good defender who knows the sighting is true (they were out that night) owns it and gives their account,
			# rather than calling the watcher a liar (Case 12926: Nisha, the Sexton, out
			# tolling the bell, called Fenwick's and Hollis's sightings fabricated).
			var saw_me_true: bool = false
			if not d.is_evil() and bool(rd.get("true", false)) and d.id in dd.get("seen", []):
				var nd_s: int = int(rd.get("day", -1))
				saw_me_true = nd_s >= 0 and str(d.history.get(w.time_key(nd_s, C.NIGHT), "")).begins_with("night:")
				if saw_me_true and moves.size() < 2 and not ("dispute_night" in moves):
					lines.append(say_voiced(d, "defence_true_sighting", "%s saw true: I was out that night. Hear why from me." % src.name, {"source": src.name}))
					var acct_s: Dictionary = load("res://sim/mind_podium.gd").press_night(w, d, nd_s, true, true)
					lines.append_array(acct_s.get("lines", []))
					facts.append_array(acct_s.get("facts", []))
					if not reb.is_empty() and int(reb["night"]) == nd_s:
						reb_after_account = lines.size()
					moves.append("dispute_night")
					move_strengths["dispute_night"] = 1.0
					move_scales["dispute_night"] = absf(float(Tuning.Meeting.DEFENCE_PLEA_RELIEF))
					defence_scopes["dispute_night"] = {"type": "plea"}
			if not saw_me_true and moves.size() < 2 and not ("red_herring" in moves) and not ("pair_other" in moves) and not ("group_other" in moves):
				if hinge_at >= 0:
					lines[hinge_at] = say_voiced(d, "defence_case_hinge_reading_wrong", "Your whole case rests on %s's reading, and that reading is wrong." % src.name, {"source": src.name})
				if trait_of(d, "confidence") > 0.6:
					var lie_key: String = "lying:" + src_id
					if _meeting()._said_by_other(w, d, lie_key) != "":
						lines.append(say_voiced(d, "defence_lying_echo", "%s again? Then %s is lying about me too." % [src.name, src.name], {"source": src.name}))
					elif not src.alive:
						# Past tense for a source who has since died (23973: Kiran, killed the night before).
						lines.append(say_voiced(d, "defence_lied", "%s lied, and you should ask yourselves why." % src.name, {"source": src.name}))
					elif hinge_at >= 0:
						# "Then" follows the hinge line's "and that reading is wrong".
						lines.append(say_voiced(d, "defence_lying", "Then %s is lying, and you should ask yourselves why." % src.name, {"source": src.name}))
					else:
						# Nothing before it says the reading is wrong (the hinge was their night, or
						# there was no case): the line stands on its own (23973: Merrin's alibi, then
						# "Then Kiran speaks with the serpent's own tongue!").
						lines.append(say_voiced(d, "defence_lying_alone", "%s is lying, and you should ask yourselves why." % src.name, {"source": src.name}))
					_meeting()._note_said(w, d, lie_key)
					moves.append("lying")
					move_strengths["lying"] = 1.0
					move_scales["lying"] = maxf(absf(float(Tuning.Meeting.DEFENCE_LYING_RELIEF)), absf(float(C.DEFENCE_LIE_BLOWBACK)))
					defence_scopes["lying"] = {"type": "challenge", "mode": "lying", "reading": WorkshopLedger.reading(src_id, rd).id}
				else:
					lines.append(say_voiced(d, "defence_misled", "%s's gift could have been turned. It's happened before." % src.name, {"source": src.name}))
					moves.append("misled")
					move_strengths["misled"] = 1.0
					move_scales["misled"] = absf(float(Tuning.Meeting.DEFENCE_MISLED_RELIEF))
					defence_scopes["misled"] = {"type": "challenge", "mode": "misled", "reading": WorkshopLedger.reading(src_id, rd).id}
	# 4. Nothing to show: fear, or the desperation play.
	if moves.is_empty():
		if _afraid(w, d) and not d.claim_public:
			lines.append(say_voiced(d, "defence_fear_plea", "If I say what I am, I'll be dead by morning. But I'm not what you think."))
			moves.append("fear")
		else:
			lines.append(say_voiced(d, "defence_desperation", "I don't know what's going on, but I know I'm not evil."))
			moves.append("desperation")
		move_strengths[moves[0]] = 1.0
		move_scales[moves[0]] = absf(float(Tuning.Meeting.DEFENCE_PLEA_RELIEF))
		defence_scopes[moves[0]] = {"type": "plea"}
	if rebuttal_fits_account(w, d, reb):
		lines.insert(reb_after_account if reb_after_account >= 0 else reb_at, rebuttal_line(w, d, reb))
		note_rebuttal(w, d, reb, "At the meeting")
		moves.append("rebuttal")
		move_strengths["rebuttal"] = 0.0  # speech: no weight
		move_scales["rebuttal"] = 0.0
		defence_scopes["rebuttal"] = rebuttal_scope(reb, reb_eid)
	for mv in move_strengths:
		var scope: Dictionary = defence_scopes[mv]
		var identity: String = "def:%s:%s:%s" % [d.id, scope.type, JSON.stringify(WorkshopLedger.Evidence.canonical(scope)).sha256_text()]
		var strength: float = float(move_strengths[mv])
		for l in w.living():
			if l == d:
				continue
			var meta = {"kind": "defence", "move": mv, "scope": scope.duplicate(true), "hearing_scale": float(move_scales.get(mv, 1.0))}
			if scope.type == "gift_claim":
				meta["workshop_card"] = WorkshopLedger.Evidence.normalize_card({"kind": "claim", "source": d.id, "subject": [d.id], "role": scope.role, "day": w.day, "phase": w.phase, "text": "Walking-gift defence."})
			elif scope.type == "secret_claim":
				meta["workshop_card"] = WorkshopLedger.Evidence.normalize_card({"kind": "secret", "source": d.id, "subject": [d.id], "owner": d.id, "secret_kind": scope.kind, "day": w.day, "phase": w.phase, "text": "Confessed errand defence."})
			if l.ledger.get(identity, {}).get("meta", {}).has("workshop_card"):
				meta["workshop_card"] = l.ledger[identity].meta.workshop_card
			ledger_hear(w, l, identity, [], strength * (0.5 + 0.5 * l.npc_trust.get(d.id, 0.5)),
				[d.id, -1, "report"], meta)
	w.dlog.think(d.id, "defence", "Defends against %s: %s." % [nominator_id, ", ".join(PackedStringArray(moves))], {"moves": moves, "evil": d.is_evil()})
	return {"lines": lines, "facts": facts, "moves": moves}

static func defence_line(w, n) -> Dictionary:
	if n.silenced:
		return {"speaker": n.id, "name": n.name, "text": "...", "silent": true}
	var c = trait_of(n, "confidence")
	var fallback = "You've got the wrong person."
	if c > 0.66:
		fallback = "This is madness, and you all know it."
	elif c < 0.34:
		fallback = "P-please. I've done nothing."
	return say_voiced(n, "defence_line", fallback)
