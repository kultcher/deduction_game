## Player-facing game layer: command interpreter, case board, structured output.
##
## Every command produces a list of structured events in `last_events`
## ({k: kind, ...}); `command()` also returns them rendered as text. A future UI can read
## the events and the board directly instead of parsing text.
## Event kinds: header, narration, speech {speaker, name, text}, card {n}, prompt, error, screen.
extends RefCounted

const C = preload("res://sim/content.gd")
const World = preload("res://sim/world.gd")
const Mind = preload("res://sim/mind.gd")

var w
var state = "day"          # day | talk | meeting | nomination | night | over
var moved = false          # has the player chosen a location this phase
var free_move_used = false
var loc = ""
var talk_with = null
var questions_left = 0
var board: Array = []
var _card_keys = {}
var player_done = false    # player has closed their nominations for today
var statement_used = false # player's one statement on the pending nomination
var log_dir = "user://logs"
var log_paths: Array = []
var debug = false
var events: Array = []
var last_events: Array = []

# ---------------------------------------------------------------- events

func _ev(e: Dictionary) -> void:
	events.append(e)

func _hdr(t: String) -> void:
	_ev({"k": "header", "text": t})

func _narr(t: String) -> void:
	_ev({"k": "narration", "text": t})

func _prompt(t: String) -> void:
	_ev({"k": "prompt", "text": t})

func _err(t: String) -> void:
	_ev({"k": "error", "text": t})

func _screen(t: String) -> void:
	_ev({"k": "screen", "text": t})

func _line(x) -> void:
	if x is Dictionary:
		_ev({"k": "speech", "speaker": x["speaker"], "name": x["name"], "text": x["text"]})
	else:
		_narr(str(x))

func _lines(arr: Array) -> void:
	for x in arr:
		_line(x)

func _facts(facts: Array) -> void:
	for f in facts:
		_ev({"k": "card", "n": add_card(f)})

static func render(evs: Array) -> String:
	var lines = PackedStringArray()
	var pending: Array = []
	for e in evs:
		if e["k"] == "card":
			if not (e["n"] in pending):
				pending.append(e["n"])
			continue
		if not pending.is_empty():
			var tag = "  [case board: #%s]" % ", #".join(PackedStringArray(pending.map(func(x): return str(x))))
			if lines.is_empty():
				lines.append(tag.strip_edges())
			else:
				lines[lines.size() - 1] = lines[lines.size() - 1] + tag
			pending = []
		match e["k"]:
			"header":
				if not lines.is_empty():
					lines.append("")
				lines.append("=== %s ===" % e["text"])
			"speech":
				lines.append("%s: \"%s\"" % [e["name"], e["text"]])
			_:
				lines.append(e["text"])
	if not pending.is_empty():
		var tag2 = "  [case board: #%s]" % ", #".join(PackedStringArray(pending.map(func(x): return str(x))))
		if lines.is_empty():
			lines.append(tag2.strip_edges())
		else:
			lines[lines.size() - 1] = lines[lines.size() - 1] + tag2
	return "\n".join(lines)

# ---------------------------------------------------------------- lifecycle

func new_case(seed_in: int, npc_count: int = 7) -> String:
	w = World.new()
	w.setup(seed_in, npc_count)
	state = "day"
	moved = false
	events = []
	_intro()
	_morning_report()
	return _finish_command("new_case", "")

func command(line: String) -> String:
	var text = line.strip_edges()
	if text == "":
		return ""
	events = []
	_dispatch(text)
	if w.game_over and state != "over":
		state = "over"
		_ending()
	return _finish_command("command", text)

func _finish_command(kind: String, cmd: String) -> String:
	last_events = events.duplicate()
	var out = render(events)
	if w != null:
		w.set_log_time()
		w.dlog.add("player_" + kind, "player", "", {"cmd": cmd, "output": out})
	return out

# ---------------------------------------------------------------- parsing helpers

func find_npc(token: String, include_dead = false):
	var t = token.to_lower().strip_edges()
	if t == "":
		return null
	for n in w.npcs:
		if (n.alive or include_dead) and (n.id == t or n.name.to_lower() == t):
			return n
	for n in w.npcs:
		if (n.alive or include_dead) and (n.id.begins_with(t) or n.name.to_lower().begins_with(t)):
			return n
	return null

func find_location(token: String) -> String:
	var t = token.to_lower().strip_edges().trim_prefix("the ")
	if t == "":
		return ""
	for l in w.all_locations():
		if l == t:
			return l
	for l in w.all_locations():
		var nm: String = w.loc_name(l).to_lower()
		if l.begins_with(t) or t in nm:
			return l
	var victim = find_npc(t, true)
	if victim and not victim.alive and w.scenes.has("scene_" + victim.id):
		return "scene_" + victim.id
	return ""

func find_block(token: String) -> String:
	var t = token.to_lower().strip_edges().trim_prefix("the ")
	if t == "":
		return ""
	for b in C.BLOCKS:
		if b == t or b.begins_with(t) or t in C.block_name(b).to_lower():
			return b
	return ""

func add_card(fact: Dictionary) -> int:
	var key: String = fact.get("text", "")
	if _card_keys.has(key):
		return _card_keys[key]
	var card = fact.duplicate()
	card["n"] = board.size() + 1
	if not card.has("day"):
		card["day"] = w.day
	if not card.has("class"):
		card["class"] = Mind.evidence_class(card)
	board.append(card)
	_card_keys[key] = card["n"]
	return card["n"]

# ---------------------------------------------------------------- dispatch

func _dispatch(text: String) -> void:
	var parts = text.split(" ", false)
	var verb = parts[0].to_lower()
	var rest = " ".join(parts.slice(1))
	match verb:
		"help", "?", "h":
			_screen(_help())
			return
		"look", "l":
			_look()
			return
		"map", "m", "town":
			_screen(_map())
			return
		"cast", "people", "who":
			_screen(_cast())
			return
		"board", "notes", "b":
			_screen(_board(rest))
			return
		"profile", "p":
			_screen(_profile(rest))
			return
		"roles", "script":
			_screen(_script())
			return
		"tools":
			_screen(_tools())
			return
		"log":
			_narr(_write_logs())
			return
		"grimoire":
			if debug or state == "over":
				_screen(_lies() if rest.strip_edges().to_lower() == "lies" else _grimoire())
			else:
				_err("The grimoire is sealed until the case ends.")
			return
	if state == "over":
		_err("The case is closed. Type 'grimoire' (or 'grimoire lies') for the full reveal, or start a new case.")
		return
	match state:
		"day":
			_day_command(verb, rest)
		"talk":
			_talk_command(verb, rest)
		"meeting":
			_meeting_command(verb, rest)
		"nomination":
			_nomination_command(verb, rest)
		"night":
			_night_command(verb, rest)

# ---------------------------------------------------------------- day

func _resolve_go(target: String) -> String:
	var l = find_location(target)
	if l != "":
		return l
	var b = find_block(target)
	if b != "":
		return _best_location_on(b)
	var n = find_npc(target)
	if n != null:
		# Exact spot known if they're working, in a visible conversation, or nearby.
		if n.working or n.busy_with != "" or (moved and w.loc_block(n.loc) == w.loc_block(loc)):
			return n.loc
		if not n.at_home():
			return _best_location_on(w.loc_block(n.loc))
	return ""

func _best_location_on(b: String) -> String:
	var locs: Array = w.locations_on(b)
	for l in locs:
		for n in w.npcs_at(l):
			if n.working:
				return l
	return locs[0]

func _day_command(verb: String, rest: String) -> void:
	match verb:
		"go", "visit", "g":
			var sought = find_npc(rest) if find_location(rest) == "" and find_block(rest) == "" else null
			var l = _resolve_go(rest)
			if l == "":
				var n = find_npc(rest)
				if n != null and n.at_home():
					_err("%s is at home this %s." % [n.name, w.phase_name().to_lower()])
				else:
					_err("Where? Try 'map' for places (a location, a block, or a person).")
				return
			if moved:
				if l == loc:
					_err("You're already here.")
				elif free_move_used:
					_err("You've already moved once this %s. Talk, search, or wait." % w.phase_name().to_lower())
				elif w.loc_block(l) != w.loc_block(loc):
					_err("You can only move within %s now (one free move per phase)." % C.block_name(w.loc_block(loc)))
				else:
					free_move_used = true
					loc = l
					w.player_loc = l
					w.dlog.add("player_move", "player", "", {"loc": l, "free_move": true})
					_observe()
				return
			moved = true
			free_move_used = false
			loc = l
			w.player_loc = l
			w.dlog.add("player_move", "player", "", {"loc": l})
			_observe()
			if sought != null and sought.loc != l and w.loc_block(sought.loc) == w.loc_block(l):
				_narr("%s isn't here, but you spot them at %s. ('talk %s' walks you over, using your free move.)" %
					[sought.name, w.loc_name(sought.loc), sought.name.to_lower()])
		"talk", "t":
			if not moved:
				_err("First choose where to spend this phase ('go <place>').")
				return
			var n = find_npc(rest)
			if n == null:
				_err("Talk to whom?")
				return
			if n.loc != loc:
				if not n.at_home() and w.loc_block(n.loc) == w.loc_block(loc) and not free_move_used:
					free_move_used = true
					loc = n.loc
					w.player_loc = loc
					w.dlog.add("player_move", "player", "", {"loc": loc, "free_move": true, "via": "talk"})
					_narr("You walk over to %s." % w.loc_name(loc))
				elif not n.at_home() and w.loc_block(n.loc) == w.loc_block(loc):
					_err("%s is at %s, and you've already used your free move this %s." % [n.name, w.loc_name(n.loc), w.phase_name().to_lower()])
					return
				else:
					_err("%s isn't here." % n.name)
					return
			if n.busy_with != "":
				_err("%s is deep in conversation with %s." % [n.name, w.by_id[n.busy_with].name])
				return
			talk_with = n
			questions_left = 3
			state = "talk"
			w.dlog.add("player_talk", "player", n.id, {"trust": snappedf(n.trust, 0.01)})
			var cue = Mind.greeting_cue(w, n)
			if cue != "":
				_narr(cue)
			_narr("You draw %s aside. (3 questions: ask gift | ask night | ask today | ask about <name> | tell <suspect> <card#> | bye)" % n.name)
		"search", "s":
			if not moved:
				_err("First choose where to spend this phase ('go <place>').")
				return
			_search()
			_end_phase("")
		"gossip":
			if not moved:
				_err("First choose where to spend this phase ('go <place>').")
				return
			if loc != "tavern":
				_err("You can only listen for gossip at the tavern.")
				return
			var r: Dictionary = Mind.gossip(w)
			_lines(r["lines"])
			_facts(r["facts"])
			_end_phase("")
		"wait", "rest", "pass":
			_narr("You let the %s pass." % w.phase_name().to_lower())
			_end_phase("")
		_:
			_err("You can't do that now. Type 'help'.")

func _who_here(l: String) -> String:
	var here: Array = w.npcs_at(l)
	var parts: Array = []
	var done = {}
	for n in here:
		if done.has(n.id):
			continue
		if n.busy_with != "":
			var m = w.by_id[n.busy_with]
			done[m.id] = true
			parts.append("%s and %s (deep in conversation)" % [n.name, m.name])
		elif n.working:
			parts.append("%s the %s (working)" % [n.name, n.occupation])
		else:
			parts.append("%s the %s" % [n.name, n.occupation])
	return ", ".join(PackedStringArray(parts))

func _observe() -> void:
	var l = loc
	_narr("You spend the %s at %s (%s)." % [w.phase_name().to_lower(), w.loc_name(l), C.block_name(w.loc_block(l))])
	var here: Array = w.npcs_at(l)
	if here.is_empty():
		_narr("Nobody is here.")
	else:
		_narr("Present: " + _who_here(l) + ".")
		_facts([{"kind": "sighting", "subject": here.map(func(n): return n.id), "block": w.loc_block(l),
			"loc": l, "day": w.day, "phase": w.phase, "source": "player",
			"text": "You saw %s at %s, day %d %s." % [", ".join(PackedStringArray(here.map(func(n): return n.name))), w.loc_name(l), w.day, w.phase_name()]}])
	for other in w.locations_on(w.loc_block(l)):
		if other == l:
			continue
		var there: Array = w.npcs_at(other)
		if not there.is_empty():
			_narr("Nearby, at %s: %s." % [w.loc_name(other), _who_here(other)])
	if w.scenes.has(l):
		_narr("This is where %s was killed. ('search' to examine it.)" % w.by_id[w.scenes[l]["victim"]].name)
	var acts = "Actions: talk <name> | search%s | wait" % (" | gossip" if l == "tavern" else "")
	if not free_move_used:
		acts += "   (or 'go <place>' once more within %s)" % C.block_name(w.loc_block(l))
	_prompt(acts)

func _search() -> void:
	var l = loc
	if w.scenes.has(l):
		var sc: Dictionary = w.scenes[l]
		if sc["searched"]:
			_narr("You go over the scene again. Nothing new.")
			return
		sc["searched"] = true
		var tb: String = sc["trace_block"]
		_narr("Near the body you find %s. Whoever did this most likely spent the evening on %s." % [C.BLOCKS[tb]["trace"], C.block_name(tb)])
		w.dlog.add("player_search", "player", sc["victim"], {"trace_block": tb, "trace_true": sc["trace_true"]}, sc["why"])
		_facts([{"kind": "trace", "subject": [], "block": tb, "source": "evidence", "day": w.day,
			"text": "Trace at %s's death scene: the killer most likely spent the evening of day %d on %s." %
				[w.by_id[sc["victim"]].name, w.day - 1, C.block_name(tb)]}])
		return
	w.dlog.add("player_search", "player", "", {"loc": l}, "Nothing to find at an ordinary location.")
	_narr("You search %s carefully. Nothing out of place: nobody has hidden anything here." % w.loc_name(l))

func _end_phase(talked_id: String) -> void:
	moved = false
	free_move_used = false
	loc = ""
	w.player_loc = ""
	if w.end_day_phase(talked_id):
		_phase_header()
	else:
		_start_meeting()

func _phase_header() -> void:
	_hdr("Day %d, %s" % [w.day, w.phase_name()])
	_screen(_map())
	_prompt("Where will you spend the %s? ('go <place | block | person>')" % w.phase_name().to_lower())

# ---------------------------------------------------------------- conversation

func _talk_command(verb: String, rest: String) -> void:
	var n = talk_with
	var r = {}
	match verb:
		"ask", "a":
			var p = rest.split(" ", false)
			var topic = p[0].to_lower() if p.size() > 0 else ""
			match topic:
				"gift", "role", "info", "learned":
					r = Mind.answer_gift(w, n)
				"night", "lastnight":
					r = Mind.answer_night(w, n)
				"today", "seen":
					r = Mind.answer_today(w, n)
				"about", "opinion":
					var t = find_npc(" ".join(p.slice(1)), true)
					if t == null:
						_err("Ask about whom?")
						return
					if t == n:
						_narr("%s gives you a flat look." % n.name)
						return
					r = Mind.answer_opinion(w, n, t)
				_:
					_err("Ask about: gift | night | today | about <name>")
					return
		"tell", "accuse":
			var p = rest.split(" ", false)
			if p.size() < 2:
				_err("Usage: tell <suspect> <card#>  (see 'board')")
				return
			var s = find_npc(p[0])
			var num = p[p.size() - 1].trim_prefix("#").to_int()
			if s == null:
				_err("Who is suspicious?")
				return
			if s == n:
				_err("Accusing %s to their own face? Try someone else." % n.name)
				return
			if num < 1 or num > board.size():
				_err("No such card on your board.")
				return
			r = Mind.hear_accusation(w, n, s, board[num - 1])
		"bye", "leave", "done":
			_narr("You leave %s to their business." % n.name)
			_close_conversation()
			return
		_:
			_err("In conversation: ask gift | ask night | ask today | ask about <name> | tell <suspect> <card#> | bye")
			return
	questions_left -= 1
	_lines(r["lines"])
	_facts(r["facts"])
	if questions_left <= 0:
		_narr("%s has other things to do." % n.name)
		_close_conversation()
	else:
		_prompt("(%d question%s left)" % [questions_left, "" if questions_left == 1 else "s"])

func _close_conversation() -> void:
	var n = talk_with
	for t in Mind.end_conversation(w, n):
		_narr(t)
	state = "day"
	talk_with = null
	_end_phase(n.id)

# ---------------------------------------------------------------- meeting

func _start_meeting() -> void:
	state = "meeting"
	player_done = false
	_hdr("Day %d: the town meeting" % w.day)
	var testimony: Array = w.begin_meeting()
	if testimony.is_empty():
		_narr("Nobody has much to say tonight.")
	for t in testimony:
		_lines(t["lines"])
		_facts(t["facts"])
	_narr("")
	_prompt("Nominations are open (%d votes needed of %d). 'nominate <name>', 'wait' to let the town speak, or 'done' to close your nominations." %
		[w.vote_threshold(), w.voter_count()])

func _meeting_command(verb: String, rest: String) -> void:
	match verb:
		"nominate", "nom":
			if player_done:
				_err("You've closed your nominations for today.")
				return
			var n = find_npc(rest)
			if n == null:
				_err("Nominate whom?")
				return
			var why = w.can_nominate("player", n.id)
			if why != "":
				_err(why)
				return
			w.open_nomination("player", n.id)
			_narr("You stand and nominate %s." % n.name)
			_show_nomination()
		"wait":
			if not _next_npc_nomination():
				_narr("No one else rises to nominate.")
				if w.meeting["block"] == "" and not player_done:
					_prompt("'nominate <name>' or 'done'.")
				elif not player_done:
					_prompt("'nominate <name>' or 'done' to close the meeting.")
				else:
					_close_meeting()
		"done", "pass", "close":
			player_done = true
			if not _next_npc_nomination():
				_close_meeting()
		_:
			_err("At the meeting: nominate <name> | wait | done")

func _next_npc_nomination() -> bool:
	var nm = Mind.next_nomination(w)
	if nm == null:
		return false
	w.open_nomination(nm["by"], nm["nominee"], nm["reason"])
	_line(nm["speech"])
	_show_nomination()
	return true

func _show_nomination() -> void:
	state = "nomination"
	statement_used = false
	var nm: Dictionary = w.meeting["pending"]
	var t = w.by_id[nm["nominee"]]
	_line(Mind.defence_line(w, t))
	var blk = ""
	if w.meeting["block"] != "":
		blk = " %s is on the block with %d votes." % [w.by_id[w.meeting["block"]].name, w.meeting["block_count"]]
	var opts = "'vote yes' or 'vote no'"
	opts += ". Before voting you may 'defend' or 'accuse' (one statement)"
	if w.tools["clemency"] > 0 and nm["by"] != "player":
		opts += ", or use 'clemency' to spare them"
	_prompt("Vote on %s (%d needed).%s %s." % [t.name, w.vote_threshold(), blk, opts])

func _nomination_command(verb: String, rest: String) -> void:
	var nm: Dictionary = w.meeting["pending"]
	var t = w.by_id[nm["nominee"]]
	var r = rest.strip_edges().to_lower()
	match verb:
		"defend", "accuse":
			if statement_used:
				_err("You've already spoken on this nomination.")
				return
			statement_used = true
			nm["statement"] = verb
			if verb == "defend":
				_narr("You speak in %s's defence." % t.name)
				Mind.set_trust(w, t, t.trust + 0.06, "the Demonologist defended me")
				if nm["by"] != "player":
					var nb = w.by_id[nm["by"]]
					Mind.set_trust(w, nb, nb.trust - 0.04, "the Demonologist spoke against my nomination")
			else:
				_narr("You add your voice against %s." % t.name)
				Mind.set_trust(w, t, t.trust - 0.08, "the Demonologist spoke against me")
			w.dlog.add("player_statement", "player", t.id, {"statement": verb})
			_prompt("'vote yes' or 'vote no'.")
		"clemency":
			if w.tools["clemency"] <= 0:
				_err("You have no Clemency left.")
				return
			if nm["by"] == "player":
				_err("You can't spare someone from your own nomination.")
				return
			w.clemency()
			_narr("You raise your hand and invoke Clemency. %s is spared; the nomination is struck." % t.name)
			_after_vote()
		"vote", "yes", "no", "y", "n":
			var yes = verb in ["yes", "y"] or (verb == "vote" and r in ["yes", "y", "aye"])
			var no = verb in ["no", "n"] or (verb == "vote" and r in ["no", "n", "nay"])
			if not yes and not no:
				_err("'vote yes' or 'vote no'.")
				return
			var res: Dictionary = w.vote_pending(yes)
			var yes_names: Array = res["yes"].map(func(i): return w.by_id[i].name)
			if res["player_yes"]:
				yes_names.append("you")
			_narr("Votes to execute %s: %d of %d (%s)." % [t.name, res["count"], w.voter_count(),
				", ".join(PackedStringArray(yes_names)) if not yes_names.is_empty() else "nobody"])
			var subj: Array = res["yes"].duplicate()
			subj.append(t.id)
			_facts([{"kind": "vote", "subject": subj, "source": "player",
				"text": "Day %d vote on %s (nominated by %s): for = %s." % [w.day, t.name,
					"you" if res["by"] == "player" else w.by_id[res["by"]].name, ", ".join(PackedStringArray(yes_names)) if not yes_names.is_empty() else "nobody"]}])
			match res["outcome"]:
				"on_block":
					_narr("%s is now on the block." % t.name)
				"tie":
					_narr("That ties the count on the block. Nobody is on the block now.")
				"short_of_block":
					if res["block"] != "":
						_narr("Not enough to take the block from %s." % w.by_id[res["block"]].name)
					else:
						_narr("Not enough to beat the earlier tie (%d votes)." % res["block_count"])
				_:
					_narr("The nomination fails.")
			_after_vote()
		_:
			_err("On this nomination: defend | accuse | %svote yes | vote no" % ("clemency | " if w.tools["clemency"] > 0 else ""))

func _after_vote() -> void:
	state = "meeting"
	if player_done:
		if not _next_npc_nomination():
			_close_meeting()
		return
	_prompt("'nominate <name>', 'wait' for the town, or 'done'.")

func _close_meeting() -> void:
	var ex = w.end_meeting()
	if ex != "":
		var n = w.by_id[ex]
		_narr("The meeting closes. %s is hanged at dusk." % n.name)
		_facts([{"kind": "execution", "subject": [ex], "source": "player", "text": "%s was executed on day %d." % [n.name, w.day]}])
	else:
		_narr("The meeting closes with nobody on the block. Nobody is executed.")
	if w.game_over:
		return
	for m in w.living():
		if w.rng.randf() < 0.35 * (1.0 - m.traits["composure"]):
			var t = Mind.reveal_trait(w, m)
			if t != "":
				_narr(t)
	state = "night"
	_hdr("Night %d" % w.day)
	var opts = "'vigil <block>' (watch a block)"
	if w.tools["ward"] > 0:
		opts = "'ward <name>' (shield them from the demon, once per case), " + opts
	_prompt("Choose your night work: %s, or 'sleep'." % opts)

# ---------------------------------------------------------------- night

func _night_command(verb: String, rest: String) -> void:
	match verb:
		"ward", "protect":
			if w.tools["ward"] <= 0:
				_err("You've already used your Ward.")
				return
			var n = find_npc(rest)
			if n == null:
				_err("Ward whom?")
				return
			w.tools["ward"] -= 1
			w.player_ward = n.id
			w.player_vigil = ""
			_narr("You chalk a warding sigil on %s's door." % n.name)
			_resolve_night()
		"vigil", "watch":
			var b = find_block(rest)
			if b == "":
				_err("Watch which block? (square, market, docks, hill)")
				return
			w.player_vigil = b
			_narr("You keep a cold vigil on %s." % C.block_name(b))
			_resolve_night()
		"sleep", "wait", "pass":
			w.player_vigil = ""
			_narr("You sleep uneasily.")
			_resolve_night()
		_:
			_err("At night: %svigil <block> | sleep" % ("ward <name> | " if w.tools["ward"] > 0 else ""))

func _resolve_night() -> void:
	var vig: String = w.player_vigil
	w.resolve_night()
	if vig != "":
		if w.player_vigil_seen.is_empty():
			_narr("Nobody moves through %s all night." % C.block_name(vig))
			_facts([{"kind": "vigil", "subject": [], "block": vig, "source": "player", "day": w.day, "phase": C.NIGHT,
				"text": "Night %d vigil on %s: nobody moved." % [w.day, C.block_name(vig)]}])
		else:
			var names: Array = w.player_vigil_seen.map(func(i): return w.by_id[i].name)
			_narr("During your vigil you see %s moving through %s." % [", ".join(PackedStringArray(names)), C.block_name(vig)])
			_facts([{"kind": "sighting", "subject": w.player_vigil_seen.duplicate(), "block": vig, "source": "player",
				"day": w.day, "phase": C.NIGHT, "text": "Night %d vigil: you saw %s on %s." % [w.day, ", ".join(PackedStringArray(names)), C.block_name(vig)]}])
	w.player_vigil = ""
	if w.game_over:
		return
	w.start_new_day()
	if w.game_over:
		return
	state = "day"
	moved = false
	_morning_report()

func _morning_report() -> void:
	_hdr("Day %d, Morning" % w.day)
	if w.day > 1 or not w.deaths_last_night.is_empty():
		if w.deaths_last_night.is_empty():
			_narr("Dawn breaks. Nobody died in the night.")
		for id in w.deaths_last_night:
			var v = w.by_id[id]
			_narr("Dawn breaks over a body: %s the %s was killed in the night. Their cottage on %s is now a crime scene." %
				[v.name, v.occupation, C.block_name(v.home_block)])
			_facts([{"kind": "death", "subject": [id], "block": v.home_block, "source": "player",
				"text": "%s was killed by the demon on night %d (home on %s)." % [v.name, w.day - 1, C.block_name(v.home_block)]}])
	_screen(_map())
	_prompt("%d townsfolk remain. Where will you spend the morning? ('go <place | block | person>', 'help')" % w.living().size())

# ---------------------------------------------------------------- info screens

func _intro() -> void:
	_narr("THE DEMONOLOGIST  (case #%d)" % w.seed_value)
	_narr("You arrive in the village of Hollowmere at dawn. A demon wears the skin of one of its people,")
	_narr("and a Poisoner serves it. Find the host and see them hanged before the town falls.")
	_narr("")
	_screen(_cast())
	_narr("")
	_narr("Type 'roles' for the gifts that may be in play, 'help' for commands.")

func _help() -> String:
	return """Commands
  Anytime : look | map | cast | profile <name> | board [filter] | roles | tools | help | log
  Day     : go <place | block | person>   (then one free move within the same block)
            then one action: talk <name> | search | gossip (tavern) | wait
  Talking : ask gift | ask night | ask today | ask about <name>
            tell <suspect> <card#>   (make a case using a card from your board)
            bye
  Meeting : nominate <name> | wait (let the town nominate) | done (close your nominations)
  Voting  : defend | accuse (one statement) | clemency (once per case) | vote yes | vote no
  Night   : ward <name> (once per case) | vigil <block> | sleep
Each day phase (morning, afternoon, evening) allows one action. A conversation allows 3 questions.
Workers can always be found at work during their shift. Others may be busy talking with each other.
Nominations go one at a time: the highest vote that reaches %d (half the voters) puts someone on the
block; a later nomination needs more votes to replace them, and a tie clears the block.
You win when the demon's host is executed. You lose if only two townsfolk remain or day %d ends.""" % [w.vote_threshold(), w.max_days]

func _look() -> void:
	match state:
		"day":
			if moved:
				_observe()
			else:
				_phase_header()
		"talk":
			_narr("You are talking with %s (%d questions left)." % [talk_with.name, questions_left])
		"meeting":
			var b: String = w.meeting["block"]
			_narr("The town meeting. On the block: %s." % ("%s (%d votes)" % [w.by_id[b].name, w.meeting["block_count"]] if b != "" else "nobody"))
		"nomination":
			_show_nomination()
		"night":
			_narr("Night falls. %svigil <block> | sleep" % ("ward <name> | " if w.tools["ward"] > 0 else ""))
		_:
			_narr("The case is over.")

## Current-phase view of the town: workers and conversations exactly; others by block.
func _map() -> String:
	var out = PackedStringArray()
	out.append("Around town this %s:" % w.phase_name().to_lower())
	var at_home: Array = []
	for b in C.BLOCKS:
		var parts: Array = []
		var done = {}
		for n in w.living():
			if done.has(n.id) or w.loc_block(n.loc) != b or n.at_home():
				continue
			if n.busy_with != "":
				var m = w.by_id[n.busy_with]
				done[m.id] = true
				parts.append("%s & %s talking at %s" % [n.name, m.name, w.loc_name(n.loc).trim_prefix("the ")])
			elif n.working:
				parts.append("%s working at %s" % [n.name, w.loc_name(n.loc).trim_prefix("the ")])
			else:
				parts.append(n.name)
		var places: Array = w.locations_on(b).map(func(l): return w.loc_name(l).trim_prefix("the "))
		out.append("  %-12s (%s): %s" % [C.block_name(b), ", ".join(PackedStringArray(places)),
			"; ".join(PackedStringArray(parts)) if not parts.is_empty() else "-"])
	for n in w.living():
		if n.at_home():
			at_home.append(n.name)
	if not at_home.is_empty():
		out.append("  At home: " + ", ".join(PackedStringArray(at_home)))
	return "\n".join(out)

func _cast() -> String:
	var out = PackedStringArray()
	out.append("The townsfolk:")
	for n in w.npcs:
		var status = "" if n.alive else ("  [killed night %d]" % n.death_day if n.death_cause == "demon" else "  [executed day %d]" % n.death_day)
		var claim = ""
		if n.claim_public:
			claim = "  claims: %s" % C.role_name(n.claimed_role)
		elif n.max_tier >= 3:
			claim = "  told you: %s" % C.role_name(n.claimed_role)
		elif n.max_tier == 2:
			claim = "  hinted: %s" % C.package_of(w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role).replace("_", " ")
		elif n.claimed_role == "none":
			claim = "  told you: no gift"
		out.append("  %-12s %-13s works %s at %s; lives on %s.%s%s" % [n.name, n.occupation, C.phase_list(n.work_phases),
			w.loc_name(n.work), C.block_name(n.home_block), status, claim])
	return "\n".join(out)

func _profile(token: String) -> String:
	var n = find_npc(token, true)
	if n == null:
		return "Profile of whom?"
	var out = PackedStringArray()
	out.append("%s the %s: %s." % [n.name, n.occupation, n.blurb])
	out.append("Works %s at %s; lives on %s.%s" % [C.phase_list(n.work_phases), w.loc_name(n.work), C.block_name(n.home_block),
		"" if n.alive else (" Killed by the demon on night %d." % n.death_day if n.death_cause == "demon" else " Executed on day %d." % n.death_day)])
	var tl = PackedStringArray()
	for t in C.TRAITS:
		tl.append("%s: %s" % [t.capitalize(), n.revealed_traits.get(t, "?")])
	out.append("Traits: " + ", ".join(tl))
	var cards: Array = board.filter(func(c): return n.id in c.get("subject", []) or c.get("source", "") == n.id)
	if cards.is_empty():
		out.append("No cards on your board involve them yet.")
	else:
		out.append("Cards:")
		for c in cards:
			out.append("  #%-3d [%s] %s" % [c["n"], c["kind"], c["text"]])
	return "\n".join(out)

func _script() -> String:
	var out = PackedStringArray()
	out.append("Gifts that may be in play (not all will be):")
	for r in C.GOOD_ROLES:
		out.append("  %-12s %s" % [C.role_name(r), C.ROLES[r]["desc"]])
	out.append("Hint families: night sight (Seer, Hearthwitch, Night Watch); names (Gravedigger, Archivist, Clerk); shelter (Warden, Veteran).")
	out.append("Evil (always in play): ")
	out.append("  %-12s %s" % ["Demon", C.ROLES["demon"]["desc"]])
	out.append("  %-12s %s" % ["Poisoner", C.ROLES["poisoner"]["desc"]])
	return "\n".join(out)

func _tools() -> String:
	return "Your tools: Ward (shield one person from the demon for a night) x%d; Clemency (spare a nominee) x%d; Vigil (watch a block at night) unlimited." % [w.tools["ward"], w.tools["clemency"]]

func _board(filter: String) -> String:
	if board.is_empty():
		return "Your case board is empty."
	var out = PackedStringArray()
	var f = filter.strip_edges().to_lower()
	for c in board:
		if f != "" and c["kind"] != f and c.get("class", "") != f:
			var subj_names: Array = c.get("subject", []).map(func(i): return w.by_id[i].name.to_lower())
			if not (f in subj_names) and not f in c["text"].to_lower():
				continue
		out.append("#%-3d [%s/%s] %s" % [c["n"], c["kind"], c.get("class", "?"), c["text"]])
	if out.is_empty():
		return "No cards match."
	return "\n".join(out)

func _ending() -> void:
	if w.winner == "good":
		_narr("*** VICTORY ***  " + w.end_reason)
	else:
		_narr("*** DEFEAT ***  " + w.end_reason)
	_narr("")
	_screen(_grimoire())
	_narr("")
	_narr(_write_logs())

func _grimoire() -> String:
	var out = PackedStringArray()
	out.append("THE GRIMOIRE")
	for n in w.npcs:
		var lies: int = w.dlog.entries.filter(func(e): return e["actor"] == n.id and e["type"] == "think" and e["data"].get("topic", "") == "lie").size()
		var poisoned: Array = w.dlog.entries.filter(func(e): return e["type"] == "poison" and e["target"] == n.id).map(func(e): return str(e["day"]))
		var extra = PackedStringArray()
		if n.is_evil():
			extra.append("bluffed %s" % C.role_name(w.evil_plan["bluffs"][n.id]))
		if n.id == w.evil_plan.get("scapegoat", ""):
			extra.append("evil's scapegoat")
		if not n.secret.is_empty():
			extra.append("secret: " + n.secret["text"])
		if not poisoned.is_empty():
			extra.append("poisoned nights " + ",".join(PackedStringArray(poisoned)))
		if n.red_herring != "":
			extra.append("red herring was " + w.by_id[n.red_herring].name)
		if lies > 0:
			extra.append("%d lies" % lies)
		var traits = PackedStringArray()
		for t in C.TRAITS:
			traits.append("%s %s" % [t.substr(0, 4), C.tier(n.traits[t])])
		out.append("  %-12s %-11s %-5s %s" % [n.name, C.role_name(n.role), n.alignment.to_upper(), "; ".join(extra)])
		out.append("  %-12s traits: %s; trust in you %.2f" % ["", ", ".join(traits), n.trust])
	out.append("Demon temperament: %s." % w.evil_plan["mood"])
	out.append("Type 'grimoire lies' to see every lie and false reading with its reason.")
	return "\n".join(out)

## Hindsight reveal: every lie told and every false reading, with its reason.
func _lies() -> String:
	var out = PackedStringArray()
	out.append("EVERY LIE AND FALSE READING")
	for e in w.dlog.entries:
		var topic: String = e["data"].get("topic", "")
		if e["type"] == "think" and topic == "lie":
			out.append("  D%d %-9s %-12s %s" % [e["day"], e["phase"], w.by_id[e["actor"]].name, e["reason"]])
		elif e["type"] == "info" and not e["data"].get("true", true):
			out.append("  N%d %-9s %-12s false reading: %s (%s)" % [e["day"], "", w.by_id[e["actor"]].name, e["data"]["text"], e["data"].get("why", "?")])
		elif e["type"] == "fake_info":
			out.append("  N%d %-9s %-12s fabricated: %s (%s)" % [e["day"], "", w.by_id[e["actor"]].name, e["data"]["text"], e["data"].get("why", "")])
	return "\n".join(out)

func _write_logs() -> String:
	var base = "case_%d" % w.seed_value
	log_paths = w.dlog.write_files(log_dir, base)
	var shown: Array = log_paths.map(func(p): return ProjectSettings.globalize_path(p))
	return "Dev log written: %s" % ", ".join(PackedStringArray(shown))
