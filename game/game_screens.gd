## Text/CLI info screens, player theory/prediction snapshots, post-case outcome
## summaries, debug overlays, and townsfolk profile data assembly for `Game`.
##
## Extracted from `game/game.gd`; `Game` retains thin forwarding methods so all
## UI panels (`ui/`) and test suites can continue calling `g.<fn>(...)` unchanged.
extends RefCounted

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const World = preload("res://sim/world.gd")
const Mind = preload("res://sim/mind.gd")
const Deduction = preload("res://sim/deduction.gd")
const Evil = preload("res://sim/evil.gd")
const CaseMetrics = preload("res://game/case_metrics.gd")


static func _intro(g) -> void:
	g._narr("THE DEMONOLOGIST  (case #%d)" % g.w.seed_value)
	g._narr("You arrive in the village of Hollowmere at dawn. A demon wears the skin of one of its people,")
	g._narr("and %s serve%s it. Find the host and see them hanged before the town falls." % ["a minion" if g.w.minion_ids.size() == 1 else "%d minions" % g.w.minion_ids.size(), "s" if g.w.minion_ids.size() == 1 else ""])
	g._narr("")
	g._screen(_cast(g))
	g._narr("")
	g._narr("Type 'roles' for the gifts that may be in play, 'help' for commands.")


static func _help(g) -> String:
	return """Commands
  Anytime : look | map | cast | profile <name> | board [filter] | timeline [filter] | roles | tools | help | log | fallbacks
            filters: person, block, location, kind, class, d2 / n1, or any text
  Case    : build cases in the Case Workshop; present them at the meeting
            hide <#> | unhide <#> | showhidden | delete <#> (your own deductions only)
            note <name> <text> | guess <name> <role|evil|good> [1-4] | theory
  Day     : go <place | block | person>   (then one free move within the same block)
            then one action: talk <name> | search | gossip (tavern, evening) | records (town hall, morning/afternoon, 3/case) | wait
  Talking : ask gift | ask night | ask seen <today | morning | afternoon | evening | yesterday [phase]>
            ask are <gift> | ask about <name> (haunts and recent sightings) | bye
            ask about <gift> ("Have you heard of a ...?")
            ask check <name> [<name>] (comma or and also accepted) | ask guard <name> | ask watch <block>
              (ask someone who disclosed that gift to use it on these targets tonight)
            apologise <number> (repair a grievance; enter apologise alone to list them)
            yes | no (answer a pending request for confidence or protection; promising is free)
            offer ward | offer vigil  (promise your ward on their door, or a vigil on their block, tonight;
              costs no question; keep it and they'll trust you more, break it and they'll trust you less)
            present <card#> [for|against <name>]   (uses a question) - about them: you press them
              to answer it; a deduction: you argue it; a card about someone else: a case against
              them ('for' to speak up for them). Shortcuts: press, convince, tell, defend
            present <ward or scorched-sigil card#> (show that receipt privately or at the meeting)
  Meeting : present <deduction#> (once) | nominate <name> | wait | done (close, once the town is quiet)
  Voting  : defend [card#] | accuse [card#] (one statement) | clemency (once per case) | vote yes | vote no
  Approach: someone may ask for a word at the start of a phase: accept (uses the phase) | decline
  Night   : ward <name> (once per case) | vigil <block> | sleep
Each day phase (morning, afternoon, evening) allows one action. A conversation allows 3 questions.
Your vote counts too: with ten living townsfolk there are 11 voters, including you.
Workers can always be found at work during their shift. Others may be busy talking with each other.
Nominations go one at a time: the highest vote that reaches %d (half the voters) puts someone on the
block; a later nomination needs more votes to replace them, and a tie clears the block.
You win when the demon's host is executed. You lose if only two townsfolk remain or day %d ends.""" % [g.w.vote_threshold(), g.w.max_days]


static func _look(g) -> void:
	match g.state:
		"day":
			if g.moved:
				g._observe()
			else:
				g._phase_header()
		"talk":
			g._narr("You are talking with %s (%d questions left)." % [g.talk_with.name, g.questions_left])
		"meeting":
			var b: String = g.w.meeting["block"]
			g._narr("The town meeting. On the block: %s." % ("%s (%d votes)" % [g.w.by_id[b].name, g.w.meeting["block_count"]] if b != "" else "nobody"))
		"nomination":
			g._show_nomination()
		"night":
			g._narr(g._night_homes())
			g._narr("Night falls. %svigil <block> | sleep" % ("ward <name> | " if g.w.tools["ward"] > 0 else ""))
		_:
			g._narr("The case is over.")


## Public workers are already visible on the map: preserve that observation per phase.
static func _card_workers(g) -> void:
	if g.w.phase == C.NIGHT:
		return
	var facts: Array = []
	for n in g.w.living():
		if not n.working or n.at_home() or n.loc != n.work or not g.can_see(n):
			continue
		var fact = {"kind": "sighting", "subject": [n.id], "block": g.w.loc_block(n.loc), "loc": n.loc,
			"day": g.w.day, "phase": g.w.phase, "source": "player", "work_sighting": true,
			"text": "You saw %s working at %s, day %d %s." % [n.name, g.w.loc_name(n.loc), g.w.day, g.w.phase_name()]}
		if not g._fact_keys.has(Mind.fact_id(fact)):
			facts.append(fact)
	g._facts(facts)


## Conversations visible on the town view become cards (who was talking with whom, where).
static func _card_conversations(g) -> void:
	var done = {}
	var facts: Array = []
	for n in g.w.living():
		if n.busy_with == "" or done.has(n.id) or n.at_home():
			continue
		var m = g.w.by_id[n.busy_with]
		done[m.id] = true
		facts.append({"kind": "conversation", "subject": [n.id, m.id], "block": g.w.loc_block(n.loc), "loc": n.loc, "day": g.w.day, "phase": g.w.phase,
			"source": "player", "text": "You saw %s and %s talking at %s, day %d %s." % [n.name, m.name, g.w.loc_name(n.loc), g.w.day, g.w.phase_name()]})
		# Each of them also gets their own sighting card: "who talked to whom" is its own
		# (circumstantial) evidence, "who was where" is the location (playtest triage 1.7).
		# Same fact id as a sighting from visiting the spot, so the two merge.
		for x in [n, m]:
			facts.append({"kind": "sighting", "subject": [x.id], "block": g.w.loc_block(x.loc), "loc": x.loc, "day": g.w.day, "phase": g.w.phase,
				"source": "player", "text": "You saw %s at %s, day %d %s." % [x.name, g.w.loc_name(x.loc), g.w.day, g.w.phase_name()]})
	if not facts.is_empty():
		g._facts(facts)


## Current-phase view of the town: workers and conversations from anywhere; anyone else
## only on the player's own block (once they've chosen where to go).
static func _map(g) -> String:
	var out = PackedStringArray()
	out.append("Around town this %s:" % g.w.phase_name().to_lower())
	var at_home: Array = []
	var unseen = 0
	for b in C.BLOCKS:
		var parts: Array = []
		var done = {}
		for n in g.w.living():
			if done.has(n.id) or g.w.loc_block(n.loc) != b or n.at_home():
				continue
			if not g.can_see(n):
				unseen += 1
				continue
			if n.busy_with != "":
				var m = g.w.by_id[n.busy_with]
				done[m.id] = true
				parts.append("%s & %s talking at %s" % [n.name, m.name, g.w.loc_name(n.loc).trim_prefix("the ")])
			elif n.working:
				parts.append("%s working at %s" % [n.name, g.w.loc_name(n.loc).trim_prefix("the ")])
			else:
				parts.append(n.name)
		var places: Array = g.w.locations_on(b).map(func(l): return g.w.loc_name(l).trim_prefix("the "))
		var more: Array = []
		for l in g.w.locations_on(b):
			var u = g.unseen_at(l)
			if u > 0:
				more.append("%d more at %s" % [u, g.w.loc_name(l).trim_prefix("the ")])
		if not more.is_empty():
			parts.append("(" + ", ".join(PackedStringArray(more)) + ")")
		out.append("  %-12s (%s): %s" % [C.block_name(b), ", ".join(PackedStringArray(places)),
			"; ".join(PackedStringArray(parts)) if not parts.is_empty() else "-"])
	for n in g.w.living():
		if n.at_home():
			if g.can_see(n):
				at_home.append(n.name)
			else:
				unseen += 1
	if not at_home.is_empty():
		out.append("  At home nearby (you can call on them): " + ", ".join(PackedStringArray(at_home)))
	if unseen > 0:
		out.append("  Total out of sight: %d (includes the anonymous counts above and anyone at home)." % unseen)
	return "\n".join(out)


static func _cast(g) -> String:
	var out = PackedStringArray()
	out.append("The townsfolk:")
	for n in g.w.npcs:
		var status = "" if n.alive else "  [%s]" % _death_text(n)
		var claim = ""
		if n.claim_public:
			claim = "  claims: %s" % C.role_name(n.claimed_role)
		elif n.max_tier >= 3:
			claim = "  told you: %s" % C.role_name(n.claimed_role)
		elif n.max_tier == 2:
			claim = "  hinted: %s" % C.package_of(g.w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role).replace("_", " ")
		elif n.claimed_role == "none":
			claim = "  told you: no gift"
		out.append("  %-12s %-13s works %s at %s; lives on %s.%s%s" % [n.name, n.occupation, C.phase_list(n.work_phases),
			g.w.loc_name(n.work), C.block_name(n.home_block), status, claim])
	return "\n".join(out)


static func _profile(g, token: String) -> String:
	var n = g.find_npc(token, true)
	if n == null:
		return "Profile of whom?"
	var out = PackedStringArray()
	out.append("%s the %s: %s." % [n.name, n.occupation, n.blurb])
	out.append("Works %s at %s; off work, %s; lives on %s.%s" % [C.phase_list(n.work_phases), g.w.loc_name(n.work), ("often at " + g.known_haunt_names(n.id)) if g.known_haunt_names(n.id) != "" else "nobody's told you where", C.block_name(n.home_block),
		"" if n.alive else " %s%s." % [_death_text(n)[0].to_upper(), _death_text(n).substr(1)]])
	var tl = PackedStringArray()
	for t in C.TRAITS:
		tl.append("%s: %s" % [t.capitalize(), n.revealed_traits.get(t, "?")])
	out.append("Traits: " + ", ".join(tl))
	var cl = _claim_text(g, n)
	if cl != "":
		out.append(cl.substr(0, 1).to_upper() + cl.substr(1))
	for x in named_in(g, n.id):
		out.append("Readings say: " + x)
	if g.guesses.has(n.id):
		var gg: Dictionary = g.guesses[n.id]
		out.append("Your guess: %s (%s)" % [C.role_name(gg["guess"]) if C.ROLES.has(gg["guess"]) else gg["guess"], C.CONFIDENCE[clampi(int(gg["confidence"]), 1, 4) - 1]])
		if gg.get("secret", "?") != "?":
			out.append("Your secret guess: %s (%s)" % ["None" if gg["secret"] == "none" else C.secret_name(gg["secret"]), C.CONFIDENCE[clampi(int(gg.get("secret_conf", 2)), 1, 4) - 1]])
	if g.notes.get(n.id, "") != "":
		out.append("Your note: " + g.notes[n.id])
	var cards: Array = g.filter_cards(n.id)
	if cards.is_empty():
		out.append("No cards on your board involve them yet.")
	else:
		out.append("Cards:")
		for c in cards:
			out.append("  #%-3d [%s] %s" % [c["n"], c["kind"], c["text"]])
	return "\n".join(out)


static func _script(g) -> String:
	var out = PackedStringArray()
	out.append("Gifts that may be in play (not all will be):")
	var sc = g.w.case_script
	for r in sc.town:
		out.append("  %-12s %s" % [C.role_name(r), C.ROLES[r]["desc"]])
	var fams = PackedStringArray()
	for pk in C.HINT_PACKAGES:
		fams.append("%s (%s)" % [C.HINT_PACKAGES[pk]["name"], ", ".join(PackedStringArray(C.HINT_PACKAGES[pk]["roles"].filter(func(r): return r in sc.town).map(func(r): return C.role_name(r))))])
	out.append("Hint families: " + "; ".join(fams) + ".")
	out.append("Evil: the Demon, and %d of these minions:" % g.w.minion_ids.size())
	for r in sc.demons:
		out.append("  %-12s %s" % [C.role_name(r), C.ROLES[r]["desc"]])
	out.append(C.DEMON_NIGHT_RULE)
	for r in sc.minions:
		out.append("  %-12s %s" % [C.role_name(r), C.ROLES[r]["desc"]])
	out.append("Secrets (one in play, laid on a townsfolk on top of their gift):")
	for k in sc.secrets:
		out.append("  %-12s %s" % [C.secret_name(k), C.SECRET_MODS[k]["desc"]])
	return "\n".join(out)


static func _tools(g) -> String:
	return "Your tools: Ward (shield one person from the demon for a night) x%d; Clemency (spare a nominee) x%d; Vigil (watch a block at night) unlimited." % [g.w.tools["ward"], g.w.tools["clemency"]]


static func _board(g, filter: String) -> String:
	if g.board.is_empty():
		return "Your case board is empty."
	var out = PackedStringArray()
	for c in g.filter_cards(filter):
		out.append("#%-3d [%s/%s] %s" % [c["n"], c["kind"], c.get("class", "?"), c["text"]])
	if out.is_empty():
		return "No cards match."
	return "\n".join(out)


static func _ending(g) -> void:
	g._headline("ending", "Victory" if g.w.winner == "good" else "Defeat", g.w.end_reason)
	var frozen: Dictionary = g.prediction_snapshots[-1] if not g.prediction_snapshots.is_empty() else {}
	g.case_summary = CaseMetrics.summarize(g.w, frozen, g.prediction_spoiled, g.board, g.prediction_snapshots)
	g.case_summary["present_fallbacks"] = g.fallback_count
	g.case_summary["legacy_fallbacks"] = g.shared_fallbacks.size()
	g.w.dlog.add("case_summary", "world", "", g.case_summary, "Frozen pre-outcome identification, town survival, and execution attribution.")
	if g.w.winner == "good":
		g._narr("*** VICTORY ***  " + g.w.end_reason)
	else:
		g._narr("*** DEFEAT ***  " + g.w.end_reason)
	g._narr(_outcome_text(g))
	g._narr("")
	g._screen(_grimoire(g))
	g._narr("")
	g._narr(_write_logs(g))


static func _grimoire(g) -> String:
	var out = PackedStringArray()
	out.append("THE GRIMOIRE")
	for n in g.w.npcs:
		var lies: int = g.w.dlog.entries.filter(func(e): return e["actor"] == n.id and e["type"] == "think" and e["data"].get("topic", "") == "lie").size()
		var poisoned: Array = g.w.dlog.entries.filter(func(e): return e["type"] == "poison" and e["target"] == n.id).map(func(e): return str(e["day"]))
		var extra = PackedStringArray()
		var role_label: String = C.role_name(n.role)
		if n.id == g.w.scion_rose:
			role_label = "Scion (promoted to Demon)"
		if n.turned or g.w.dlog.entries.any(func(e): return e["type"] == "turned" and e["target"] == n.id):
			# Show who the Revenant turned, even once the curse lifted (playtest triage 1.5).
			var tday: int = n.turned_day
			for e in g.w.dlog.entries:
				if e["type"] == "turned" and e["target"] == n.id:
					tday = int(e["day"])
			extra.append("turned evil by the Revenant on day %d%s" % [tday, "" if n.turned else ", freed when the totem burned"])
		if n.is_evil() and not n.turned and g.w.evil_plan.get("bluffs", {}).has(n.id):
			extra.append("bluffed %s" % C.role_name(g.w.evil_plan["bluffs"][n.id]))
		if n.id == g.w.evil_plan.get("scapegoat", ""):
			extra.append("evil's scapegoat")
		if not n.secret.is_empty():
			extra.append("secret: " + n.secret["text"])
		if n.secret_mod != "":
			extra.append("secret modifier: " + C.secret_name(n.secret_mod))
		if not poisoned.is_empty():
			extra.append("poisoned nights " + ",".join(PackedStringArray(poisoned)))
		if n.red_herring != "":
			extra.append("red herring was " + g.w.by_id[n.red_herring].name)
		if lies > 0:
			extra.append("%d lies" % lies)
		var traits = PackedStringArray()
		for t in C.TRAITS:
			traits.append("%s %s" % [t.substr(0, 4), C.tier(n.traits[t])])
		out.append("  %-12s %-11s %-5s %s" % [n.name, role_label, n.alignment.to_upper(), "; ".join(extra)])
		out.append("  %-12s traits: %s; rapport %.2f, credibility %.2f" % ["", ", ".join(traits), n.trust, n.credibility])
	out.append("Demon temperament: %s." % g.w.evil_plan["mood"])
	out.append("Type 'grimoire lies' to see every lie and false reading with its reason, or 'grimoire talk' for who told whom what.")
	return "\n".join(out)


## Hindsight: every piece of information NPCs passed to each other, and the evil team's
## private conferences, day by day.
static func _exchanges(g) -> String:
	var out = PackedStringArray()
	out.append("WHO TOLD WHOM")
	var day = -1
	var count = 0
	for e in g.w.dlog.entries:
		if not (e["type"] in ["npc_share", "evil_share"]):
			continue
		if e["day"] != day:
			day = e["day"]
			out.append("Day %d" % day)
		var lie = e["data"].get("lie", false)
		out.append("  %-9s %s%s" % [e["phase"], e["reason"].replace("  [LIE]", ""), "   [LIE]" if lie else ""])
		count += 1
	if count == 0:
		out.append("  (Nobody passed anything on.)")
	return "\n".join(out)


## Hindsight reveal: every lie told and every false reading, with its reason.
static func _lies(g) -> String:
	var out = PackedStringArray()
	out.append("EVERY LIE AND FALSE READING")
	for e in g.w.dlog.entries:
		var topic: String = e["data"].get("topic", "")
		if e["type"] == "think" and topic == "lie":
			out.append("  D%d %-9s %-12s %s" % [e["day"], e["phase"], g.w.by_id[e["actor"]].name, e["reason"]])
		elif e["type"] == "info" and not e["data"].get("true", true):
			out.append("  N%d %-9s %-12s false reading: %s (%s)" % [e["day"], "", g.w.by_id[e["actor"]].name, e["data"]["text"], World.false_reading_reason(e["data"])])
		elif e["type"] == "fake_info":
			out.append("  N%d %-9s %-12s fabricated: %s (%s)" % [e["day"], "", g.w.by_id[e["actor"]].name, e["data"]["text"], World.false_reading_reason(e["data"].merged({"fake": true}))])
	return "\n".join(out)


static func _write_logs(g) -> String:
	var base = "case_%d" % g.w.seed_value
	g.w.trace_capture("export", true)
	g.log_paths = g.w.dlog.write_files(g.log_dir, base)
	g._trace_export_pending = true
	var shown: Array = g.log_paths.map(func(p): return ProjectSettings.globalize_path(p))
	return "Dev log written: %s" % ", ".join(PackedStringArray(shown))


static func set_note(g, id: String, text: String) -> void:
	g.notes[id] = text


static func set_guess(g, id: String, guess: String, confidence: int) -> bool:
	g.last_error = ""
	if g.w.game_over:
		g.last_error = "The case is closed. Your pre-outcome theory is frozen."
		return false
	if not g.w.by_id.has(id) or not (guess in C.ROLES or guess in ["?", "good", "evil"]):
		g.last_error = "Choose a known person and a role, good, evil, or ?."
		return false
	var before = g.guesses.duplicate(true)
	# These are nominations for two unique identities, not a list of alternate suspects.
	# One demon is in play, whatever its type: a demon guess replaces any other.
	if C.is_demon(guess) or C.is_minion(guess):
		for old_id in (CaseMetrics.demon_guesses(g.guesses) if C.is_demon(guess) else CaseMetrics.named_guesses(g.guesses, guess)):
			if old_id != id:
				g.guesses[old_id]["guess"] = "?"
				g.guesses[old_id]["confidence"] = 1
	var entry: Dictionary = g.guesses.get(id, {}).duplicate()
	entry["guess"] = guess
	entry["confidence"] = clampi(confidence, 1, 4)
	g.guesses[id] = entry
	if before == g.guesses:
		return true
	var revision = {"revision": g.guess_history.size() + 1, "day": g.w.day, "phase": g.w.phase_name(), "state": g.state,
		"who": id, "guess": guess, "confidence": clampi(confidence, 1, 4), "before": before,
		"guesses": g.guesses.duplicate(true), "notes": g.notes.duplicate(true)}
	g.guess_history.append(revision)
	g.w.set_log_time()
	g.w.dlog.add("player_guess", "player", id, revision, "Private theory revised; no truth feedback.")
	return true


## Your guess at someone's secret ("?" unknown, "none", or a secret on the script), with
## how sure you are (1..4). Kept beside the role guess, in the same theory history.
static func set_secret_guess(g, id: String, secret: String, confidence: int) -> bool:
	g.last_error = ""
	if g.w.game_over or not g.w.by_id.has(id) or not (secret in ["?", "none"] or secret in C.SECRET_MOD_LIST):
		g.last_error = "Choose a known person and a secret, none, or ?."
		return false
	var before = g.guesses.duplicate(true)
	var entry: Dictionary = g.guesses.get(id, {"guess": "?", "confidence": 2}).duplicate()
	entry["secret"] = secret
	entry["secret_conf"] = clampi(confidence, 1, 4)
	g.guesses[id] = entry
	if before == g.guesses:
		return true
	var revision = {"revision": g.guess_history.size() + 1, "day": g.w.day, "phase": g.w.phase_name(), "state": g.state,
		"who": id, "secret": secret, "confidence": entry["secret_conf"], "before": before,
		"guesses": g.guesses.duplicate(true), "notes": g.notes.duplicate(true)}
	g.guess_history.append(revision)
	g.w.set_log_time()
	g.w.dlog.add("player_guess", "player", id, revision, "Private secret guess revised; no truth feedback.")
	return true


static func capture_prediction(g, reason: String, extra: Dictionary = {}) -> Dictionary:
	var snapshot = {"id": g.prediction_snapshots.size() + 1, "day": g.w.day, "phase": g.w.phase_name(), "state": g.state,
		"reason": reason, "revision": g.guess_history.size(), "guesses": g.guesses.duplicate(true), "notes": g.notes.duplicate(true),
		"spoiled": g.prediction_spoiled, "context": extra.duplicate(true)}
	g.prediction_snapshots.append(snapshot)
	g.w.set_log_time()
	g.w.dlog.add("prediction_snapshot", "player", "", snapshot, "Private theory frozen before resolving an outcome.")
	return snapshot


static func theory_status(g) -> String:
	var parts: Array = []
	var dids = CaseMetrics.demon_guesses(g.guesses)
	parts.append("Demon: %s" % (g.w.by_id[dids[0]].name if dids.size() == 1 else "not recorded"))
	var mids = CaseMetrics.minion_guesses(g.guesses)
	parts.append("Minion%s: %s" % ["" if g.w.minion_ids.size() == 1 else "s", ", ".join(PackedStringArray(mids.map(func(i): return "%s (%s)" % [g.w.by_id[i].name, C.role_name(g.guesses[i]["guess"])]))) if not mids.is_empty() else "not recorded"])
	return ("Final theory — " if g.w.game_over else "Your private theory — ") + "; ".join(PackedStringArray(parts))


static func _outcome_text(g) -> String:
	var lines = PackedStringArray()
	if g.case_summary["prediction_spoiled"]:
		lines.append("Identification unscored: the hidden grimoire was opened during this case.")
	else:
		for role in ["demon", "minion"]:
			var ids: Array = g.case_summary[role + "_guesses"]
			var result = "not recorded" if ids.is_empty() else "correct" if g.case_summary[role + "_identified"] else "incorrect"
			lines.append("%s identified: %s." % [role.capitalize(), result])
		if g.case_summary["identified_but_lost"]:
			lines.append("You identified the demon, but could not save the town in time.")
		elif g.case_summary["town_saved"] and not g.case_summary["demon_identified"]:
			lines.append("The town survived, though your final theory did not identify the demon.")
	lines.append("Innocent townsfolk surviving: %d/%d. Wrongful executions: %d (%d backed, %d opposed, %d mixed)." %
		[g.case_summary["good_surviving"], g.case_summary["good_initial"], g.case_summary["executions_good"],
		g.case_summary["wrongful_backed"], g.case_summary["wrongful_opposed"], g.case_summary["wrongful_mixed"]])
	# What evidence against the demon existed (descriptive, not a verdict on your play).
	var ob: Array = g.case_summary.get("demon_evidence_on_board", [])
	var rc: Array = g.case_summary.get("demon_evidence_reachable", [])
	if not g.case_summary["town_saved"]:
		if not ob.is_empty():
			lines.append("Evidence pointing at the demon was on your board: #%s." % ", #".join(PackedStringArray(ob.map(func(x): return str(x)))))
		elif not rc.is_empty():
			lines.append("Evidence pointing at the demon existed but never reached your board: %s." % "; ".join(PackedStringArray(rc.slice(0, 4))))
		else:
			lines.append("No true evidence pointed at the demon this case.")
	return "\n".join(lines)


## Debug overlay: reveal what NPCs privately make of cards and people. Turning it on during
## a case marks identification as unscored (like opening the grimoire).
static func set_debug_overlay(g, on: bool) -> void:
	g.debug_overlay = on
	g.decision_feed.enabled = on
	if on and g.w != null and not g.w.game_over and not g.prediction_spoiled:
		g.prediction_spoiled = true
		g.w.dlog.add("prediction_spoiled", "player", "", {}, "Turned on the debug overlay during the case; identification credit disabled.")


## Summary of how a value varies across good NPCs: "avg 0.46 · high 0.60 (A) · low 0.30 (H)".
static func _spread(g, vals: Dictionary) -> String:
	if vals.is_empty():
		return "—"
	var tot = 0.0
	var hi_id = ""
	var lo_id = ""
	for id in vals:
		tot += vals[id]
		if hi_id == "" or vals[id] > vals[hi_id]:
			hi_id = id
		if lo_id == "" or vals[id] < vals[lo_id]:
			lo_id = id
	return "avg %.2f · high %.2f (%s) · low %.2f (%s)" % [tot / vals.size(), vals[hi_id], g.w.by_id[hi_id].name.substr(0, 1),
		vals[lo_id], g.w.by_id[lo_id].name.substr(0, 1)]


## A card's current influence on each good NPC who has heard the claim behind it (the share
## of its full weight it carries for them). Readings and your arguments map cleanly; other
## cards only if an NPC holds the same fact. Returns "" when nobody's record matches.
static func debug_card_text(g, card: Dictionary) -> String:
	var eid = ""
	if card.get("kind", "") == "deduction":
		eid = "arg:" + Deduction.conclusion_key(Deduction.normalize(card["conclusion"].duplicate()))
	else:
		eid = Mind.fact_id(card)
	var vals = {}
	var listeners = g.w.living_good()
	for n in listeners:
		if n.ledger.has(eid):
			vals[n.id] = n.ledger[eid].get("eff", n.ledger[eid]["weight"])
	if vals.is_empty():
		return ""
	return "influence %s · heard by %d of %d" % [_spread(g, vals), vals.size(), listeners.size()]


## How the town (good NPCs) credits and suspects this person.
static func debug_npc_text(g, id: String) -> String:
	var hon = {}
	var sus = {}
	for n in g.w.living_good():
		if n.id == id:
			continue
		var sd: Dictionary = n.workshop_state.get("source_doubt", {})
		var s_pen: float = clampf(Tuning.Mind.HONESTY_K * maxf(0.0, Mind.susp(n, id) - 0.1), 0.0, Tuning.Mind.HONESTY_CAP) if not Mind.demon_victim(g.w, id) else 0.0
		hon[n.id] = clampf(1.0 - maxf(float(sd.get(id + ":*", 0.0)), s_pen), 0.0, 1.0)
		sus[n.id] = Mind.susp(n, id)
	var n0 = g.w.by_id[id]
	var town = {}
	for n in g.w.living_good():
		if n.id != id and n.consensus_pressure.get(id, 0.0) > 0.0:
			town[n.id] = n.consensus_pressure[id]
	var trust_line = "Trust in you: %.2f%s" % [n0.trust, (" (capped at %.2f)" % n0.trust_cap) if n0.trust_cap < 1.0 else ""]
	if n0.is_evil():
		trust_line += " (evil: acted, not felt)"
	var out = "%s · Pressure: %.2f\nCredited by others: %s\nSuspected by others: %s" % [trust_line, n0.pressure, _spread(g, hon), _spread(g, sus)]
	if not town.is_empty():
		out += "\nSeparate social pressure from public accusations: %s" % _spread(g, town)
	if n0.is_evil() and n0.shadow != null:
		# The shadow self: what this evil NPC would believe if it were the good townsperson it
		# pretends to be (its public acts default to this; see docs/shadow_self_plan.md).
		var sh = {}
		for k in n0.shadow.suspicion:
			if g.w.by_id.has(k) and g.w.by_id[k].alive:
				sh[k] = Mind.susp(n0.shadow, k)
		var top: Array = sh.keys()
		top.sort_custom(func(a, b): return sh[a] > sh[b])
		var parts = PackedStringArray(top.slice(0, 4).map(func(k): return "%s %.2f" % [g.w.by_id[k].name, sh[k]]))
		var exp_parts: Dictionary = Evil.exposure(g.w, n0)
		var ex = 0.0
		for k in exp_parts:
			ex += exp_parts[k]
		out += "\nIf good (as the %s): suspects %s · exposure %.2f, caution %.2f" % [C.role_name(n0.shadow.role) if n0.shadow.role != "" else "townsperson", ", ".join(parts), ex, Evil.caution(g.w, n0)]
	return out


## What readings on your board say this person might be ("possible: the Warden, per
## Dorian's Clerk reading, with Constance").
static func named_in(g, id: String) -> Array:
	var out: Array = []
	for c in g.board:
		if c["kind"] != "info" or c.get("deleted", false) or not g.w.by_id.has(c.get("source", "")):
			continue
		var d: Dictionary = c.get("data", {})
		if c["source"] == id:
			continue
		var role_id: String = c.get("role", "")
		var src: String = g.w.by_id[c["source"]].name
		if role_id == "chronicler":
			var trio: Array = d.get("trio", [])
			if id in trio:
				var others_t: Array = trio.filter(func(x): return x != id).map(func(x): return g.w.by_id[x].name if g.w.by_id.has(x) else x)
				out.append("possibly townsfolk, secret-holder, or minion (#%d: %s's Chronicler reading, night %d, with %s)" % [
					c["n"], src, c.get("day", 3), " and ".join(PackedStringArray(others_t))])
			continue
		if role_id == "magistrate":
			var nom_pair: Array = [str(d.get("nominator", "")), str(d.get("nominee", ""))]
			if id in nom_pair:
				var partner_id: String = nom_pair[1] if nom_pair[0] == id else nom_pair[0]
				var partner_nm: String = g.w.by_id[partner_id].name if g.w.by_id.has(partner_id) else partner_id
				var rel_txt: String = "same alignment as %s" % partner_nm if d.get("same", false) else "different alignment from %s" % partner_nm
				out.append("%s (#%d: %s's Magistrate reading, night %d)" % [rel_txt, c["n"], src, c.get("day", 1)])
			continue
		if role_id == "executor":
			if str(d.get("target", "")) == id:
				if d.has("role"):
					out.append("learned upon death to be the %s (#%d: %s's Executor reading, day %d)" % [C.role_name(str(d.get("role", ""))), c["n"], src, c.get("day", 1)])
				else:
					out.append("named as Executor charge (#%d: %s's Executor reading, night 0)" % [c["n"], src])
			continue
		if role_id == "registrar":
			if str(d.get("target", "")) == id:
				var rnames: String = ", ".join(PackedStringArray(d.get("roles", []).map(func(r): return C.role_name(str(r)))))
				var rtxt: String = ("holds one of %s" if bool(d.get("yes", false)) else "holds none of %s") % rnames
				out.append("%s (#%d: %s's Registrar reading, night %d)" % [rtxt, c["n"], src, c.get("day", 1)])
			continue
		var pair: Array = d.get("pair", [])
		if not (id in pair):
			continue
		var other = ""
		for x in pair:
			if x != id:
				other = g.w.by_id[x].name if g.w.by_id.has(x) else x
		var what = ""
		match role_id:
			"clerk":
				what = "the " + C.role_name(d.get("role", ""))
			"archivist":
				what = "the " + C.role_name(d.get("role", "poisoner"))
			"rumormonger":
				what = C.secret_name(d.get("secret", "")) + " (a secret)"
			"seer":
				what = "the demon" if d.get("yes", false) else "not the demon (cleared)"
		if what == "":
			continue
		var lead = "" if what.begins_with("not") else "possibly "
		out.append("%s%s (#%d: %s's %s reading, night %d%s)" % [lead, what, c["n"], src, C.role_name(role_id), c.get("day", 0),
			(", with " + other) if other != "" else ""])
	return out


static func _death_text(n) -> String:
	match n.death_cause:
		"demon":
			return "killed by the demon, night %d" % n.death_day
		"martyr":
			return "died in another's place at the gallows, day %d" % n.death_day
	return "executed, day %d" % n.death_day


static func _claim_text(g, n) -> String:
	if n.claim_public:
		return "claims (public): " + C.role_name(n.claimed_role)
	elif n.max_tier >= 3:
		return "told you: " + C.role_name(n.claimed_role)
	elif n.max_tier == 2:
		return "hinted: " + C.package_of(g.w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role).replace("_", " ")
	elif n.claimed_role == "none":
		return "told you: no gift"
	return ""


static func profile_data(g, id: String) -> Dictionary:
	var n = g.w.by_id[id]
	var claim = _claim_text(g, n)
	var status = "alive" if n.alive else _death_text(n)
	if n.alive and n.withdrawn_since != "" and g.w.by_id.has(n.withdrawn_since):
		status = "alive; withdrawn since %s's death" % g.w.by_id[n.withdrawn_since].name
	# Discovery still gates each trait; the visual uses its actual score once learned.
	var traits = {}
	for key in n.revealed_traits:
		if n.traits.has(key):
			traits[key] = n.traits[key]
	return {"id": id, "name": n.name, "occupation": n.occupation, "blurb": n.blurb, "work": "%s at %s" % [C.phase_list(n.work_phases), g.w.loc_name(n.work)],
		"haunts": g.known_haunt_names(id), "relationships": g.known_relationship_notes(id),
		"home": C.block_name(n.home_block), "status": status, "traits": traits, "claim": claim,
		"guess": g.guesses.get(id, {}), "note": g.notes.get(id, ""), "cards": g.filter_cards(id).map(func(c): return c["n"]),
		"named": named_in(g, id)}
