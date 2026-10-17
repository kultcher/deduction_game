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
const Social = preload("res://sim/social.gd")
const Argue = preload("res://sim/argue.gd")
const CaseMetrics = preload("res://game/case_metrics.gd")

var w
var state = "day"          # day | approach | talk | meeting | nomination | night | over
var approach = {}          # pending approach: {npc, agenda}
var moved = false          # has the player chosen a location this phase
var free_move_used = false
var loc = ""
var talk_with = null
var questions_left = 0
var board: Array = []
var _card_keys = {}
var town_quiet = false     # the town has had its say since the last nomination (allows 'done')
var statement_used = false # player's one statement on the pending nomination
var presented_today = false # player has had the meeting floor today
var last_link = {}          # result of the last 'link' (for 'conclude <number>')
var notes = {}              # npc id -> player's note
var guesses = {}            # npc id -> {guess, confidence 1..3}
var guess_history: Array = []
var prediction_snapshots: Array = []
var prediction_spoiled = false
var case_summary: Dictionary = {}
var show_hidden = false     # include cards the player has hidden
var ward_log = {}           # night -> who you warded
var last_error = ""         # why the last file_deduction was refused
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
	board = []
	_card_keys = {}
	notes = {}
	guesses = {}
	guess_history = []
	prediction_snapshots = []
	prediction_spoiled = false
	case_summary = {}
	last_link = {}
	log_paths = []
	ward_log = {}
	show_hidden = false
	last_error = ""
	w = World.new()
	w.setup(seed_in, npc_count)
	state = "day"
	moved = false
	events = []
	_intro()
	_morning_report()
	_maybe_approach()
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

func find_role(token: String) -> String:
	var t = token.to_lower().strip_edges().trim_prefix("the ")
	if t == "":
		return ""
	for r in C.ROLES:
		if r == t or C.ROLES[r]["name"].to_lower() == t:
			return r
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
		"board", "b":
			_screen(_board(rest))
			return
		"timeline", "tl":
			_screen(_timeline(rest))
			return
		"link":
			_link_command(rest)
			return
		"hide", "unhide":
			_narr(hide_card(rest.strip_edges().trim_prefix("#").to_int(), verb == "hide"))
			return
		"delete":
			_narr(delete_deduction(rest.strip_edges().trim_prefix("#").to_int()))
			return
		"showhidden":
			show_hidden = not show_hidden
			_narr("Hidden cards are now %s." % ("shown" if show_hidden else "hidden"))
			return
		"conclude", "deduce":
			_conclude_command(rest)
			return
		"note":
			var p0 = rest.split(" ", false)
			var nn = find_npc(p0[0], true) if p0.size() > 0 else null
			if nn == null:
				_err("Usage: note <name> <text>")
			else:
				set_note(nn.id, " ".join(p0.slice(1)))
				_narr("Noted.")
			return
		"guess":
			var p1 = rest.split(" ", false)
			var gn = find_npc(p1[0], true) if p1.size() > 1 else null
			if gn == null:
				_err("Usage: guess <name> <role | evil | good | ?> [1-3]")
			else:
				var conf = p1[p1.size() - 1].to_int() if p1.size() > 2 and p1[p1.size() - 1].is_valid_int() else 2
				var gtext = " ".join(p1.slice(1, p1.size() - 1 if p1.size() > 2 and p1[p1.size() - 1].is_valid_int() else p1.size()))
				var role = find_role(gtext)
				if set_guess(gn.id, role if role != "" else gtext.to_lower(), conf):
					_narr(theory_status())
				else:
					_err(last_error)
			return
		"theory":
			_screen(theory_status())
			if not w.game_over:
				_prompt("Record privately with 'guess <name> demon [1-3]' and 'guess <name> poisoner [1-3]', or use a profile's Your guess. This costs no time and gives no correctness feedback.")
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
				if not w.game_over:
					prediction_spoiled = true
					w.dlog.add("prediction_spoiled", "player", "", {}, "Opened the hidden grimoire before the case ended; identification credit disabled.")
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
		"approach":
			_approach_command(verb, rest)
		"talk":
			_talk_command(verb, rest)
		"meeting":
			_meeting_command(verb, rest)
		"nomination":
			_nomination_command(verb, rest)
		"night":
			_night_command(verb, rest)

# ---------------------------------------------------------------- day

## Who the player can see at a location (a home shows only its owner, if in).
func _present(l: String) -> Array:
	if l.begins_with("home_"):
		var o = w.by_id.get(l.substr(5))
		return [o] if o != null and o.alive and o.at_home() else []
	return w.npcs_at(l)

func _resolve_go(target: String) -> String:
	var l = find_location(target)
	if l != "":
		return l
	var b = find_block(target)
	if b != "":
		return _best_location_on(b)
	var n = find_npc(target)
	if n != null:
		# Go straight to them: anyone out on a block can be seen from either location there,
		# so walking to their exact spot reveals nothing you wouldn't see on arrival.
		if n.at_home():
			return "home_" + n.id
		return n.loc
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
			if sought != null and not sought.at_home() and sought.loc != l and w.loc_block(sought.loc) == w.loc_block(l):
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
			var at_their_home = loc == "home_" + n.id and n.at_home()
			if n.loc != loc and not at_their_home:
				if n.at_home():
					_err("%s is at home (on %s) this %s. 'go %s' to call on them." % [n.name, C.block_name(n.home_block),
						w.phase_name().to_lower(), n.name.to_lower()])
					return
				if w.loc_block(n.loc) == w.loc_block(loc) and not free_move_used:
					free_move_used = true
					loc = n.loc
					w.player_loc = loc
					w.dlog.add("player_move", "player", "", {"loc": loc, "free_move": true, "via": "talk"})
					_narr("You walk over to %s." % w.loc_name(loc))
				elif w.loc_block(n.loc) == w.loc_block(loc):
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
			if not n.remarks.is_empty() and not n.is_evil():
				var said: String = n.remarks.pop_front()
				w.dlog.think(n.id, "reconsider", "Tells the player they've come round to %s." % said)
				_lines([Mind.say(n, "I didn't put much stock in %s. After all that's happened since... perhaps I should have." % said)])
			_narr("You draw %s aside. (3 questions: ask gift | ask night | ask today | ask about <name or gift> | present <card#> [for|against <name>] | bye)" % n.name)
		"search", "s":
			if not moved:
				_err("First choose where to spend this phase ('go <place>').")
				return
			if loc.begins_with("home_"):
				_err("You can't search someone's home from their doorstep.")
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
	var here: Array = _present(l)
	if l.begins_with("home_"):
		if here.is_empty():
			_narr("You knock, but nobody answers.")
		else:
			_narr("You knock, and %s opens the door." % here[0].name)
			_facts([{"kind": "sighting", "subject": [here[0].id], "block": w.loc_block(l), "loc": l, "day": w.day, "phase": w.phase,
				"source": "player", "text": "You found %s at home, day %d %s." % [here[0].name, w.day, w.phase_name()]}])
	elif here.is_empty():
		_narr("Nobody is here.")
	elif not l.begins_with("home_"):
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
			_facts([{"kind": "sighting", "subject": there.map(func(x): return x.id), "block": w.loc_block(other), "loc": other, "day": w.day,
				"phase": w.phase, "source": "player", "text": "You saw %s nearby at %s, day %d %s." %
				[", ".join(PackedStringArray(there.map(func(x): return x.name))), w.loc_name(other), w.day, w.phase_name()]}])
	if w.scenes.has(l):
		_narr("This is where %s was killed. ('search' to examine it.)" % w.by_id[w.scenes[l]["victim"]].name)
	var acts = "Actions: talk <name> | search%s | wait" % (" | gossip" if l == "tavern" else "")
	if l.begins_with("home_"):
		acts = "Actions: talk <name> | wait"
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
		_narr("Near the body you find %s. Whoever did this most likely spent the evening of day %d on %s." % [C.BLOCKS[tb]["trace"], sc["day"], C.block_name(tb)])
		w.dlog.add("player_search", "player", sc["victim"], {"trace_block": tb, "trace_true": sc["trace_true"]}, sc["why"])
		_facts([{"kind": "trace", "subject": [], "block": tb, "source": "evidence", "day": sc["day"], "phase": C.EVENING,
			"text": "Trace at %s's death scene: the killer most likely spent the evening of day %d on %s." %
				[w.by_id[sc["victim"]].name, sc["day"], C.block_name(tb)]}])
		return
	if l.begins_with("home_"):
		_narr("You can't search someone's home from their doorstep.")
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
		_maybe_approach()
	else:
		_start_meeting()

# ---------------------------------------------------------------- approaches

func _maybe_approach() -> void:
	var c = Social.approach_candidate(w)
	if c == null:
		return
	approach = c
	state = "approach"
	var n = c["npc"]
	w.dlog.add("approach", n.id, "player", {"agenda": c["agenda"]})
	_narr("%s the %s approaches you. \"Demonologist, a word?\"" % [n.name, n.occupation])
	_prompt("'accept' (talk now; it uses this phase's action) or 'decline'.")

func _approach_command(verb: String, rest: String) -> void:
	var n = approach["npc"]
	match verb:
		"accept", "yes", "y", "talk":
			state = "talk"
			moved = true
			free_move_used = true
			loc = n.loc
			w.player_loc = loc
			talk_with = n
			questions_left = 3
			w.dlog.add("player_talk", "player", n.id, {"trust": snappedf(n.trust, 0.01), "approach": approach["agenda"]})
			_narr("You step aside with %s at %s." % [n.name, w.loc_name(loc)])
			var r: Dictionary = Social.approach_open(w, n, approach["agenda"])
			_lines(r["lines"])
			_facts(r["facts"])
			_prompt("(3 questions: ask gift | ask night | ask today | ask about <name or role> | present <card#> [for|against <name>] | bye)")
		"decline", "no", "n":
			state = "day"
			w.dlog.add("approach_declined", "player", n.id)
			_narr("You excuse yourself. %s shrugs and goes about their day." % n.name)
			_prompt("Where will you spend the %s? ('go <place | block | person>')" % w.phase_name().to_lower())
		_:
			# Any other action means declining; carry on with it.
			state = "day"
			w.dlog.add("approach_declined", "player", n.id, {"implicit": true})
			_narr("You wave %s off for now." % n.name)
			_day_command(verb, rest)

func _phase_header() -> void:
	_hdr("Day %d, %s" % [w.day, w.phase_name()])
	_screen(_map())
	_card_conversations()
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
					var target = " ".join(p.slice(1))
					var role = find_role(target)
					var t = null if role != "" else find_npc(target, true)
					if role != "":
						r = Social.answer_about_role(w, n, role)
					elif t == null:
						_err("Ask about whom (a person or a gift)?")
						return
					elif t == n:
						_narr("%s gives you a flat look." % n.name)
						return
					else:
						r = Mind.answer_opinion(w, n, t)
				_:
					_err("Ask about: gift | night | today | about <name or gift>")
					return
		"present", "show", "case":
			var pr = _route_present(n, rest)
			if pr.has("error"):
				_err(pr["error"])
				return
			_narr("(%s)" % pr["note"])
			_talk_command(pr["verb"], pr["rest"])
			return
		"convince", "argue":
			var num0 = rest.strip_edges().trim_prefix("#").to_int()
			if num0 < 1 or num0 > board.size() or board[num0 - 1]["kind"] != "deduction" or board[num0 - 1].get("deleted", false):
				_err("Convince them of which deduction? ('convince <card#>'; to cite a plain card use 'tell <suspect> <card#>')")
				return
			_secrets_used(board[num0 - 1])
			r = Argue.evaluate(w, n, board[num0 - 1], board, 1.0)
			r["facts"] = []
			Mind.on_question(w, n)
		"press", "confront":
			var num1 = rest.strip_edges().trim_prefix("#").to_int()
			if num1 < 1 or num1 > board.size() or board[num1 - 1].get("deleted", false):
				_err("Press them with which card? ('press <card#>': a card or deduction about them)")
				return
			var pc: Dictionary = board[num1 - 1].duplicate()
			if pc["kind"] == "deduction":
				pc["support_cards"] = board.filter(func(x): return x["n"] in pc["supports"])
				_secrets_used(pc)
			r = Mind.press(w, n, pc)
		"defend", "vouch":
			var pd = rest.split(" ", false)
			var sd = find_npc(pd[0]) if pd.size() >= 2 else null
			var numd = pd[pd.size() - 1].trim_prefix("#").to_int() if pd.size() >= 2 else 0
			if sd == null or numd < 1 or numd > board.size() or board[numd - 1].get("deleted", false):
				_err("Usage: present <card#> for <name>")
				return
			r = Mind.hear_defence(w, n, sd, board[numd - 1])
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
				_err("To confront %s with a card about them, use 'press <card#>'." % n.name)
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
			_err("In conversation: ask gift | ask night | ask today | ask about <name or gift> | present <card#> [for|against <name>] | bye")
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
	town_quiet = false
	presented_today = false
	_hdr("Day %d: the town meeting" % w.day)
	var testimony: Array = w.begin_meeting()
	if testimony.is_empty():
		_narr("Nobody has much to say tonight.")
	for t in testimony:
		_lines(t["lines"])
		_facts(t["facts"])
	_narr("")
	_narr(theory_status())
	_prompt("Before voting, record or update your private demon guess in a profile or with 'guess <name> demon'. A case can end at this meeting; guessing is optional and costs no time.")
	_prompt("Nominations are open (%d votes needed of %d). 'present <deduction#>' to take the floor (once), 'nominate <name>', or 'wait' to let the town speak." %
		[w.vote_threshold(), w.voter_count()])

func _meeting_command(verb: String, rest: String) -> void:
	match verb:
		"present":
			_present_deduction(rest)
		"nominate", "nom":
			var n = find_npc(rest)
			if n == null:
				_err("Nominate whom?")
				return
			var why = w.can_nominate("player", n.id)
			if why != "":
				_err(why)
				return
			w.open_nomination("player", n.id)
			town_quiet = false
			_narr("You stand and nominate %s." % n.name)
			_show_nomination()
		"wait":
			if not _next_npc_nomination():
				town_quiet = true
				_narr("No one else rises to nominate.")
				if "player" in w.meeting["nominators"]:
					_prompt("'done' to close the meeting.")
				else:
					_prompt("'nominate <name>', or 'done' to close the meeting.")
		"done", "pass", "close":
			if not town_quiet:
				_err("Let the town have its say first ('wait').")
				return
			_close_meeting()
		_:
			_err("At the meeting: present <deduction#> (once) | nominate <name> | wait | done")

func _next_npc_nomination() -> bool:
	var nm = Mind.next_nomination(w)
	if nm == null:
		return false
	w.open_nomination(nm["by"], nm["nominee"], nm["reason"])
	town_quiet = false
	_line(nm["speech"])
	_show_nomination()
	return true

func _show_nomination() -> void:
	state = "nomination"
	statement_used = false
	var nm: Dictionary = w.meeting["pending"]
	var t = w.by_id[nm["nominee"]]
	_line(Mind.defence_line(w, t))
	if CaseMetrics.named_guesses(guesses, "demon").is_empty():
		_prompt("No demon guess recorded. You can still 'guess <name> demon' before voting, or save Your guess in a profile.")
	var blk = ""
	if w.meeting["block"] != "":
		blk = " %s is on the block with %d votes." % [w.by_id[w.meeting["block"]].name, w.meeting["block_count"]]
	var opts = "'vote yes' or 'vote no'"
	opts += ". Before voting you may 'defend' or 'accuse', optionally citing a card (one statement)"
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
			var card = {}
			if r != "":
				var num = r.trim_prefix("#").to_int()
				if num < 1 or num > board.size():
					_err("No such card on your board. ('%s' alone, or '%s <card#>')" % [verb, verb])
					return
				card = board[num - 1]
			statement_used = true
			nm["statement"] = verb
			if not card.is_empty():
				_narr("You lay card #%d before the town: %s" % [card["n"], card["text"]])
				if card["kind"] == "deduction":
					_secrets_used(card)
					for v in w.living():
						if v != t:
							Argue.evaluate(w, v, card, board, 0.5)
				else:
					Mind.public_case(w, t, card, verb)
			if verb == "defend":
				_narr("You speak in %s's defence." % t.name)
				Mind.set_trust(w, t, t.trust + 0.06, "the Demonologist defended me")
				if nm["by"] != "player":
					var nb = w.by_id[nm["by"]]
					Mind.set_trust(w, nb, nb.trust - 0.04, "the Demonologist spoke against my nomination")
			else:
				_narr("You add your voice against %s." % t.name)
				Mind.set_trust(w, t, t.trust - 0.08, "the Demonologist spoke against me")
			w.dlog.add("player_statement", "player", t.id, {"statement": verb, "card": card.get("n", 0)})
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
			capture_prediction("before_vote", {"nominee": t.id, "player_yes": yes})
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
	_prompt("%s'wait' for the town." % ("" if "player" in w.meeting["nominators"] else "'nominate <name>', or "))

func _close_meeting() -> void:
	var frozen = capture_prediction("before_execution", {"on_block": w.meeting["block"]})
	if w.meeting["block"] != "":
		w.dlog.add("player_execution_context", "player", w.meeting["block"], {"prediction_id": frozen["id"],
			"known_cards": board.filter(func(c): return not c.get("deleted", false)).map(func(c): return c["n"])},
			"Evidence and private theory available before execution; no automatic judgement of whether a mistake was reasonable.")
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
			ward_log[w.day] = n.id
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
	capture_prediction("before_night")
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
				"day": w.day, "phase": C.NIGHT, "vigil": true, "text": "Night %d vigil: you saw %s on %s." % [w.day, ", ".join(PackedStringArray(names)), C.block_name(vig)]}])
	w.player_vigil = ""
	if w.game_over:
		return
	w.start_new_day()
	if w.game_over:
		return
	state = "day"
	moved = false
	_morning_report()
	_maybe_approach()

func _morning_report() -> void:
	_hdr("Day %d, Morning" % w.day)
	if w.day > 1 or not w.deaths_last_night.is_empty():
		if w.deaths_last_night.is_empty():
			_narr("Dawn breaks. Nobody died in the night.")
			var nq = w.day - 1
			if nq >= 1:
				var wd: String = ward_log.get(nq, "")
				_facts([{"kind": "quiet", "subject": [], "night": nq, "day": nq, "phase": C.NIGHT, "source": "player", "ward": wd,
					"text": "Nobody died on night %d%s." % [nq, (" (you had warded %s)" % w.by_id[wd].name) if wd != "" else ""]}])
		for id in w.deaths_last_night:
			var v = w.by_id[id]
			_narr("Dawn breaks over a body: %s the %s was killed in the night. Their cottage on %s is now a crime scene." %
				[v.name, v.occupation, C.block_name(v.home_block)])
			_facts([{"kind": "death", "subject": [id], "block": v.home_block, "source": "player", "night": w.day - 1,
				"text": "%s was killed by the demon on night %d (home on %s)." % [v.name, w.day - 1, C.block_name(v.home_block)]}])
	_screen(_map())
	_card_conversations()
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
  Anytime : look | map | cast | profile <name> | board [filter] | timeline [filter] | roles | tools | help | log
            filters: person, block, location, kind, class, d2 / n1, or any text
  Case    : link <card#> <card#> [card#]  (check for a contradiction)
            conclude <number>  (file an explanation from your last link)
            conclude <name> <is | is not | should be> <status> [night N] [because <card#> ...]
              status: good, evil, the demon, a gift (seer...), lying, misled, misled or lying;
                      should be protected / spared
              misled = not lying, but their information was wrong (poisoned or mistaken)
            hide <#> | unhide <#> | showhidden | delete <#> (your own deductions only)
            note <name> <text> | guess <name> <role|evil|good> [1-3] | theory
  Day     : go <place | block | person>   (then one free move within the same block)
            then one action: talk <name> | search | gossip (tavern) | wait
  Talking : ask gift | ask night | ask today | ask about <name or gift> | bye
            present <card#> [for|against <name>]   (uses a question) - about them: you press them
              to answer it; a deduction: you argue it; a card about someone else: a case against
              them ('for' to speak up for them). Shortcuts: press, convince, tell, defend
  Meeting : present <deduction#> (once) | nominate <name> | wait | done (close, once the town is quiet)
  Voting  : defend [card#] | accuse [card#] (one statement) | clemency (once per case) | vote yes | vote no
  Approach: someone may ask for a word at the start of a phase: accept (uses the phase) | decline
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

## Conversations visible on the town view become cards (who was talking with whom, where).
func _card_conversations() -> void:
	var done = {}
	var facts: Array = []
	for n in w.living():
		if n.busy_with == "" or done.has(n.id) or n.at_home():
			continue
		var m = w.by_id[n.busy_with]
		done[m.id] = true
		facts.append({"kind": "conversation", "subject": [n.id, m.id], "block": w.loc_block(n.loc), "loc": n.loc, "day": w.day, "phase": w.phase,
			"source": "player", "text": "You saw %s and %s talking at %s, day %d %s." % [n.name, m.name, w.loc_name(n.loc), w.day, w.phase_name()]})
	if not facts.is_empty():
		_facts(facts)

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
		out.append("  At home (you can call on them): " + ", ".join(PackedStringArray(at_home)))
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
	var cl = _claim_text(n)
	if cl != "":
		out.append(cl.substr(0, 1).to_upper() + cl.substr(1))
	for x in named_in(n.id):
		out.append("Readings say: " + x)
	if guesses.has(n.id):
		var gg: Dictionary = guesses[n.id]
		out.append("Your guess: %s (confidence %d/3)" % [C.role_name(gg["guess"]) if C.ROLES.has(gg["guess"]) else gg["guess"], gg["confidence"]])
	if notes.get(n.id, "") != "":
		out.append("Your note: " + notes[n.id])
	var cards: Array = filter_cards(n.id)
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
	for c in filter_cards(filter):
		out.append("#%-3d [%s/%s] %s" % [c["n"], c["kind"], c.get("class", "?"), c["text"]])
	if out.is_empty():
		return "No cards match."
	return "\n".join(out)

func _ending() -> void:
	var frozen: Dictionary = prediction_snapshots[-1] if not prediction_snapshots.is_empty() else {}
	case_summary = CaseMetrics.summarize(w, frozen, prediction_spoiled)
	w.dlog.add("case_summary", "world", "", case_summary, "Frozen pre-outcome identification, town survival, and execution attribution.")
	if w.winner == "good":
		_narr("*** VICTORY ***  " + w.end_reason)
	else:
		_narr("*** DEFEAT ***  " + w.end_reason)
	_narr(_outcome_text())
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

# ---------------------------------------------------------------- case work (stage 3)
# Data API used by the UI panel as well as the text commands.

## Filter the board. Accepts card kind, evidence class, person, block, location, day
## ("d2") or night ("n1"), or any text in the card.
func filter_cards(filter: String) -> Array:
	var f = filter.strip_edges().to_lower()
	var base: Array = board.filter(func(c): return not c.get("deleted", false) and (show_hidden or not c.get("hidden", false)))
	if f == "":
		return base
	var blk = find_block(f)
	var lc = find_location(f) if blk == "" else ""
	var person = find_npc(f, true)
	var out: Array = []
	for c in base:
		var ok = false
		if c["kind"] == f or c.get("class", "") == f:
			ok = true
		elif person != null and (person.id in c.get("subject", []) or c.get("source", "") == person.id or c.get("via", "") == person.id):
			ok = true
		elif blk != "" and (c.get("block", "") == blk or w.loc_block(c.get("loc", "")) == blk):
			ok = true
		elif lc != "" and c.get("loc", "") == lc:
			ok = true
		elif f.length() >= 2 and f[0] in ["d", "n"] and f.substr(1).is_valid_int():
			var num = f.substr(1).to_int()
			var is_night = c.get("phase", -1) == C.NIGHT or c["kind"] in ["vigil", "alibi"]
			ok = c.get("day", -99) == num and ((f[0] == "n") == is_night)
		elif f in c["text"].to_lower():
			ok = true
		if ok:
			out.append(c)
	return out

## Link cards: run the contradiction templates. Returns the check result and remembers it.
func link_cards(nums: Array) -> Dictionary:
	var cards: Array = []
	for x in nums:
		if x >= 1 and x <= board.size():
			cards.append(board[x - 1])
	var res: Dictionary = Argue.check(w, cards)
	var options: Array = []
	for m in res["matches"]:
		for e in m["explanations"]:
			options.append({"match": m, "expl": e})
	last_link = {"cards": nums.duplicate(), "result": res, "options": options}
	w.dlog.add("player_link", "player", "", {"cards": nums, "matches": res["matches"].map(func(m): return m["template"]),
		"near": res["near"]}, "matched" if not res["matches"].is_empty() else "no template matched (flag for template work)")
	return last_link

## File a deduction card. conclusion: {type, a, role?, night?, card?}. Returns the card
## number, or -1 if refused (reason in last_error).
func file_deduction(conclusion: Dictionary, supports: Array, match_info: Dictionary = {}, chosen: int = 0) -> int:
	conclusion = Argue.normalize(conclusion.duplicate())
	var cards: Array = board.filter(func(x): return x["n"] in supports)
	# The same conclusion from the same cards gets the same footing however it was built:
	# if a template among the supports offers this conclusion, use it.
	if match_info.is_empty() and not supports.is_empty():
		for m in Argue.check(w, cards)["matches"]:
			for e in m["explanations"]:
				if Argue.conclusion_key(Argue.normalize(e["conclusion"].duplicate())) == Argue.conclusion_key(conclusion):
					match_info = m
					chosen = e["id"]
					break
			if not match_info.is_empty():
				break
	last_error = Argue.filing_problem(w, conclusion, supports, board, not match_info.is_empty())
	if last_error != "":
		w.dlog.add("deduction_refused", "player", conclusion.get("a", ""), {"conclusion": conclusion, "supports": supports}, last_error)
		return -1
	var rank = {"speech": 0, "circumstantial": 1, "concrete": 2}
	var cls = "concrete"
	for x in supports:
		var cc: String = board[x - 1].get("class", "circumstantial")
		if rank.get(cc, 1) < rank[cls]:
			cls = cc
	if match_info.is_empty() and rank[cls] > 1:
		cls = "circumstantial"  # an inference is never stronger than circumstantial on its own
	# Unfounded = the cards don't actually bear on the person (not merely "no template").
	var unfounded = match_info.is_empty() and not Argue.bears_on(w, conclusion, cards)
	var basis = ""
	if not match_info.is_empty():
		basis = " (from #%s: %s)" % [", #".join(PackedStringArray(match_info["cards"].map(func(x): return str(x)))), match_info["text"]]
	else:
		basis = " (because #%s%s)" % [", #".join(PackedStringArray(supports.map(func(x): return str(x)))), "; unfounded" if unfounded else "; your inference"]
	var subj: Array = [conclusion["a"]] if conclusion.has("a") else []
	var near = ""
	if unfounded:
		var nr: Array = Argue.check(w, cards)["near"]
		if not nr.is_empty():
			near = nr[0]
	var card = {"kind": "deduction", "subject": subj, "source": "player", "class": cls, "conclusion": conclusion,
		"supports": supports.duplicate(), "template": match_info.get("template", ""), "explanations": match_info.get("explanations", []),
		"chosen": chosen, "unfounded": unfounded, "near": near,
		"text": "Deduction: %s%s [basis: %s]." % [Argue.conclusion_text(w, conclusion), basis, cls]}
	var n = add_card(card)
	w.dlog.add("deduction", "player", conclusion.get("a", ""), {"card": n, "conclusion": conclusion, "supports": supports,
		"template": card["template"], "unfounded": unfounded, "class": cls}, card["text"])
	return n

## Parse "conclude <name> <is | is not | should be> <status> [night N] [about #N] [because <#> ...]".
## Status: good, evil, the demon, a gift, lying, misled, misled or lying, protected, spared.
func _parse_conclusion(rest: String) -> Dictionary:
	var usage = "Usage: conclude <name> <is | is not | should be> <status> [night N] [because <card#> ...]. Status: good, evil, the demon, a gift (seer...), lying, misled, misled or lying; should be protected / spared."
	var text = " " + rest.to_lower().strip_edges() + " "
	var supports: Array = []
	var bi = text.find(" because ")
	if bi >= 0:
		for q in text.substr(bi + 9).split(" ", false):
			var num = q.trim_prefix("#").to_int()
			if num >= 1 and num <= board.size() and not board[num - 1].get("deleted", false):
				supports.append(num)
		text = text.substr(0, bi + 1)
	var night = -1
	var ni = text.find(" night ")
	if ni >= 0:
		var after = text.substr(ni + 7).split(" ", false)
		if after.size() > 0 and after[0].is_valid_int():
			night = after[0].to_int()
		text = text.substr(0, ni + 1)
		if text.ends_with(" on "):
			text = text.substr(0, text.length() - 3)
	var card = -1
	var ai = text.find(" about #")
	if ai >= 0:
		card = text.substr(ai + 8).split(" ", false)[0].to_int()
		text = text.substr(0, ai + 1)
	var words = text.split(" ", false)
	if words.size() < 3:
		return {"error": usage}
	var who = find_npc(words[0], true)
	if who == null:
		return {"error": "Who is '%s'?" % words[0]}
	var verb = ""
	var rest_i = 1
	if words[1] == "should" and words.size() > 2 and words[2] == "be":
		verb = "should be"
		rest_i = 3
	elif words[1] in ["isnt", "isn't"] or (words[1] == "is" and words.size() > 2 and words[2] == "not"):
		verb = "is not"
		rest_i = 2 if words[1] != "is" else 3
	elif words[1] == "is":
		verb = "is"
		rest_i = 2
	else:
		return {"error": usage}
	var status = " ".join(words.slice(rest_i)).strip_edges().trim_prefix("the ").strip_edges()
	if status == "demon":
		status = "the demon"
	if status in ["spared", "spared from execution"]:
		status = "spared from execution"
	var role = find_role(status)
	if role != "" and role in C.GOOD_ROLES:
		status = role
	var c = Argue.from_builder(who.id, verb, status, night, card)
	if c.is_empty():
		return {"error": "'%s %s' isn't something you can conclude. %s" % [verb, status, usage]}
	if supports.is_empty() and not last_link.is_empty():
		supports = last_link["cards"].duplicate()
	if c["type"] in ["lied", "unreliable", "truthful"] and not c.has("card"):
		for x in supports:
			if board[x - 1].get("source", "") == who.id:
				c["card"] = x
				break
	return {"conclusion": c, "supports": supports}

func _link_command(rest: String) -> void:
	var nums: Array = []
	for q in rest.split(" ", false):
		var num = q.trim_prefix("#").to_int()
		if num >= 1 and num <= board.size() and not (num in nums):
			nums.append(num)
	if nums.size() < 1 or nums.size() > 3:
		_err("Usage: link <card#> <card#> [card#]   (1-3 cards; see 'board')")
		return
	var lk = link_cards(nums)
	var res: Dictionary = lk["result"]
	if res["matches"].is_empty():
		_narr("Nothing links those cards: no conflict, corroboration or inference the town would recognise.")
		for r in res["near"].slice(0, 2):
			_narr("  Close, but " + r)
		_prompt("You can still argue from them: 'conclude <name> is <status> because <cards>'. If the cards bear on that person it's your own inference; if not, it's unfounded.")
		return
	var k = 0
	for m in res["matches"]:
		_narr("%s %s" % [Argue.RELATION_LEAD[m.get("relation", "contradiction")], m["text"]])
		for e in m["explanations"]:
			k += 1
			_narr("  %d. %s" % [k, e["label"]])
	_prompt("'conclude <number>' to file the explanation you believe, or write your own: 'conclude <name> is <status> because <cards>'.")

func _conclude_command(rest: String) -> void:
	var r = rest.strip_edges()
	if r.is_valid_int() and not last_link.is_empty():
		var k = r.to_int()
		var opts: Array = last_link["options"]
		if k < 1 or k > opts.size():
			_err("Pick one of the numbered explanations from your last 'link'.")
			return
		var o: Dictionary = opts[k - 1]
		var n = file_deduction(o["expl"]["conclusion"], o["match"]["cards"], o["match"], o["expl"]["id"])
		if n < 0:
			_err(last_error)
			return
		_narr("Filed.")
		_ev({"k": "card", "n": n})
		return
	var p = _parse_conclusion(r)
	if p.has("error"):
		_err(p["error"])
		return
	var n2 = file_deduction(p["conclusion"], p["supports"])
	if n2 < 0:
		_err(last_error)
		return
	var d2: Dictionary = board[n2 - 1]
	_narr("Filed%s." % (" (unfounded: those cards don't bear on them)" if d2["unfounded"] else
		(" (backed by: %s)" % d2["template"]) if d2["template"] != "" else " (your inference)"))
	_ev({"k": "card", "n": n2})

## "present <card#> [for|against <name>]" in conversation: work out what the player means.
## About the listener -> press them. A deduction about someone else -> argue it. A plain card
## about someone else -> make a case against (or, with "for", for) them.
func _route_present(n, rest: String) -> Dictionary:
	var p = rest.strip_edges().split(" ", false)
	if p.is_empty():
		return {"error": "Present which card? ('present <card#>', optionally 'for <name>' or 'against <name>')"}
	var num = p[0].trim_prefix("#").to_int()
	if num < 1 or num > board.size() or board[num - 1].get("deleted", false):
		return {"error": "No such card on your board."}
	var card: Dictionary = board[num - 1]
	var dir = ""
	var who = null
	if p.size() >= 3 and p[1].to_lower() in ["for", "against", "about"]:
		dir = p[1].to_lower()
		who = find_npc(p[2], true)
		if who == null:
			return {"error": "Who is '%s'?" % p[2]}
	if card["kind"] == "deduction":
		var a: String = card["conclusion"].get("a", "")
		if a == n.id and not (Argue.normalize(card["conclusion"].duplicate())["type"] in ["misled", "unreliable"]):
			return {"verb": "press", "rest": str(num), "note": "You put it to %s directly." % n.name}
		return {"verb": "convince", "rest": str(num), "note": "You argue it to %s." % n.name}
	var subj: Array = card.get("subject", []).duplicate()
	for x in card.get("data", {}).get("pair", []):
		if not (x in subj):
			subj.append(x)
	if who == null and (n.id in subj or card.get("owner", "") == n.id):
		return {"verb": "press", "rest": str(num), "note": "You put it to %s directly." % n.name}
	if who == null:
		var cands: Array = subj.filter(func(x): return x != n.id and x != card.get("source", "") and w.by_id.has(x))
		if cands.size() == 1:
			who = w.by_id[cands[0]]
		elif cands.is_empty():
			return {"error": "That card isn't about anyone in particular. Try 'present %d against <name>' or 'for <name>'." % num}
		else:
			return {"error": "About whom? It mentions %s. ('present %d against <name>' or 'for <name>')" %
				[" and ".join(PackedStringArray(cands.map(func(x): return w.by_id[x].name))), num]}
	if who == n:
		return {"verb": "press", "rest": str(num), "note": "You put it to %s directly." % n.name}
	if dir == "for":
		return {"verb": "defend", "rest": "%s %d" % [who.id, num], "note": "You speak for %s." % who.name}
	return {"verb": "tell", "rest": "%s %d" % [who.id, num], "note": "You make your case against %s." % who.name}

## A deduction resting on someone's confessed secret spreads it, just like citing it.
func _secrets_used(ded: Dictionary, depth: int = 0) -> void:
	for x in ded.get("supports", []):
		var c: Dictionary = board[x - 1]
		if c["kind"] == "secret":
			Mind._secret_used(w, c)
		elif c["kind"] == "deduction" and depth < 3:
			_secrets_used(c, depth + 1)

## Hide a card from views (any card), or delete one of your own deductions.
func hide_card(num: int, on: bool) -> String:
	if num < 1 or num > board.size() or board[num - 1].get("deleted", false):
		return "No such card."
	board[num - 1]["hidden"] = on
	return "Card #%d %s." % [num, "hidden ('showhidden' to see hidden cards)" if on else "shown again"]

func delete_deduction(num: int) -> String:
	if num < 1 or num > board.size() or board[num - 1]["kind"] != "deduction" or board[num - 1].get("deleted", false):
		return "You can only delete your own deductions."
	board[num - 1]["deleted"] = true
	w.dlog.add("deduction_deleted", "player", "", {"card": num})
	return "Deduction #%d deleted." % num

## Present a deduction to the whole meeting (once per meeting).
func _present_deduction(rest: String) -> void:
	if presented_today:
		_err("You've already had the floor today.")
		return
	var num = rest.strip_edges().trim_prefix("#").to_int()
	if num < 1 or num > board.size() or board[num - 1]["kind"] != "deduction" or board[num - 1].get("deleted", false):
		_err("Present which deduction? ('present <card#>'; file one with 'link' and 'conclude')")
		return
	presented_today = true
	var ded: Dictionary = board[num - 1]
	_narr("You take the floor: %s" % ded["text"])
	w.dlog.add("player_present", "player", ded["conclusion"].get("a", ""), {"card": num})
	_secrets_used(ded)
	for n in w.living():
		var r: Dictionary = Argue.evaluate(w, n, ded, board, 0.6)
		_lines(r["lines"])

## Timeline: who was where, by phase, from your board. * = you saw it, ~ = heard.
func timeline_data(filter: String = "") -> Dictionary:
	var cols: Array = [{"label": "N0", "day": 0, "phase": C.NIGHT}]
	for d in range(1, w.day + 1):
		for p in [C.MORNING, C.AFTERNOON, C.EVENING, C.NIGHT]:
			if d == w.day and p > w.phase and state != "night":
				break
			cols.append({"label": ("N%d" % d) if p == C.NIGHT else "D%d%s" % [d, C.PHASES[p].substr(0, 1)], "day": d, "phase": p})
	var cards: Array = filter_cards(filter) if filter != "" else board
	var rows = {}
	for n in w.npcs:
		rows[n.id] = {}
	for c in cards:
		for a in Argue.assertions(c):
			var who: String = a.get("who", "")
			if not rows.has(who):
				continue
			var key = ""
			var val = ""
			match a["t"]:
				"at":
					key = "%d:%d" % [a["day"], a["phase"]]
					val = _abbr(a["block"])
				"out":
					key = "%d:%d" % [a["night"], C.NIGHT]
					val = _abbr(a["block"])
				"home":
					key = "%d:%d" % [a["night"], C.NIGHT]
					val = "hm"
				"killed":
					key = "%d:%d" % [a["night"], C.NIGHT]
					val = "XX"
				_:
					continue
			var confirmed = a.get("src", "") == "player"
			if not rows[who].has(key):
				rows[who][key] = []
			rows[who][key].append({"val": val, "confirmed": confirmed, "card": c["n"]})
	return {"cols": cols, "rows": rows}

func _abbr(b: String) -> String:
	return {"square": "Sq", "market": "Mk", "docks": "Dk", "hill": "Hl"}.get(b, "??")

func _timeline(filter: String) -> String:
	var td = timeline_data(filter)
	var out = PackedStringArray()
	var head = "%-12s" % ""
	for col in td["cols"]:
		head += "%-7s" % col["label"]
	out.append(head)
	for n in w.npcs:
		var line = "%-12s" % (n.name if n.alive else n.name + "†")
		for col in td["cols"]:
			var key = "%d:%d" % [col["day"], col["phase"]]
			var cell = ""
			var vals: Array = td["rows"][n.id].get(key, [])
			var shown = {}
			for v in vals:
				var tag = v["val"] + ("" if v["confirmed"] else "~")
				if not shown.has(tag):
					shown[tag] = true
					cell += ("/" if cell != "" else "") + tag
			line += "%-7s" % (cell if cell != "" else ".")
		out.append(line)
	out.append("Sq Square, Mk Market, Dk Docks, Hl Chapel Hill, hm home, XX killed. No mark = you saw it; ~ = someone told you.")
	return "\n".join(out)

func set_note(id: String, text: String) -> void:
	notes[id] = text

func set_guess(id: String, guess: String, confidence: int) -> bool:
	last_error = ""
	if w.game_over:
		last_error = "The case is closed. Your pre-outcome theory is frozen."
		return false
	if not w.by_id.has(id) or not (guess in C.ROLES or guess in ["?", "good", "evil"]):
		last_error = "Choose a known person and a role, good, evil, or ?."
		return false
	var before = guesses.duplicate(true)
	# These are nominations for two unique identities, not a list of alternate suspects.
	if guess in ["demon", "poisoner"]:
		for old_id in CaseMetrics.named_guesses(guesses, guess):
			if old_id != id:
				guesses[old_id] = {"guess": "?", "confidence": 1}
	guesses[id] = {"guess": guess, "confidence": clampi(confidence, 1, 3)}
	if before == guesses:
		return true
	var revision = {"revision": guess_history.size() + 1, "day": w.day, "phase": w.phase_name(), "state": state,
		"who": id, "guess": guess, "confidence": clampi(confidence, 1, 3), "before": before,
		"guesses": guesses.duplicate(true), "notes": notes.duplicate(true)}
	guess_history.append(revision)
	w.set_log_time()
	w.dlog.add("player_guess", "player", id, revision, "Private theory revised; no truth feedback.")
	return true

func capture_prediction(reason: String, extra: Dictionary = {}) -> Dictionary:
	var snapshot = {"id": prediction_snapshots.size() + 1, "day": w.day, "phase": w.phase_name(), "state": state,
		"reason": reason, "revision": guess_history.size(), "guesses": guesses.duplicate(true), "notes": notes.duplicate(true),
		"spoiled": prediction_spoiled, "context": extra.duplicate(true)}
	prediction_snapshots.append(snapshot)
	w.set_log_time()
	w.dlog.add("prediction_snapshot", "player", "", snapshot, "Private theory frozen before resolving an outcome.")
	return snapshot

func theory_status() -> String:
	var parts: Array = []
	for role in ["demon", "poisoner"]:
		var ids = CaseMetrics.named_guesses(guesses, role)
		parts.append("%s: %s" % ["Demon" if role == "demon" else "Minion", w.by_id[ids[0]].name if ids.size() == 1 else "not recorded"])
	return ("Final theory — " if w.game_over else "Your private theory — ") + "; ".join(PackedStringArray(parts))

func _outcome_text() -> String:
	var lines = PackedStringArray()
	if case_summary["prediction_spoiled"]:
		lines.append("Identification unscored: the hidden grimoire was opened during this case.")
	else:
		for role in ["demon", "minion"]:
			var ids: Array = case_summary[role + "_guesses"]
			var result = "not recorded" if ids.is_empty() else "correct" if case_summary[role + "_identified"] else "incorrect"
			lines.append("%s identified: %s." % [role.capitalize(), result])
		if case_summary["identified_but_lost"]:
			lines.append("You identified the demon, but could not save the town in time.")
		elif case_summary["town_saved"] and not case_summary["demon_identified"]:
			lines.append("The town survived, though your final theory did not identify the demon.")
	lines.append("Innocent townsfolk surviving: %d/%d. Wrongful executions: %d (%d backed, %d opposed, %d mixed)." %
		[case_summary["good_surviving"], case_summary["good_initial"], case_summary["executions_good"],
		case_summary["wrongful_backed"], case_summary["wrongful_opposed"], case_summary["wrongful_mixed"]])
	return "\n".join(lines)

## What readings on your board say this person might be ("possible: the Warden, per
## Dorian's Clerk reading, with Constance").
func named_in(id: String) -> Array:
	var out: Array = []
	for c in board:
		if c["kind"] != "info" or c.get("deleted", false) or not w.by_id.has(c.get("source", "")):
			continue
		var d: Dictionary = c.get("data", {})
		var pair: Array = d.get("pair", [])
		if not (id in pair) or c["source"] == id:
			continue
		var other = ""
		for x in pair:
			if x != id:
				other = w.by_id[x].name if w.by_id.has(x) else x
		var src: String = w.by_id[c["source"]].name
		var what = ""
		match c.get("role", ""):
			"clerk":
				what = "the " + C.role_name(d.get("role", ""))
			"archivist":
				what = "the Poisoner"
			"seer":
				what = "the demon" if d.get("yes", false) else "not the demon (cleared)"
		if what == "":
			continue
		var lead = "" if what.begins_with("not") else "possibly "
		out.append("%s%s (#%d: %s's %s reading, night %d%s)" % [lead, what, c["n"], src, C.role_name(c["role"]), c.get("day", 0),
			(", with " + other) if other != "" else ""])
	return out

func _claim_text(n) -> String:
	if n.claim_public:
		return "claims (public): " + C.role_name(n.claimed_role)
	elif n.max_tier >= 3:
		return "told you: " + C.role_name(n.claimed_role)
	elif n.max_tier == 2:
		return "hinted: " + C.package_of(w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role).replace("_", " ")
	elif n.claimed_role == "none":
		return "told you: no gift"
	return ""

func profile_data(id: String) -> Dictionary:
	var n = w.by_id[id]
	var claim = _claim_text(n)
	var status = "alive" if n.alive else ("killed by the demon, night %d" % n.death_day if n.death_cause == "demon" else "executed, day %d" % n.death_day)
	return {"id": id, "name": n.name, "occupation": n.occupation, "blurb": n.blurb, "work": "%s at %s" % [C.phase_list(n.work_phases), w.loc_name(n.work)],
		"home": C.block_name(n.home_block), "status": status, "traits": n.revealed_traits.duplicate(), "claim": claim,
		"guess": guesses.get(id, {}), "note": notes.get(id, ""), "cards": filter_cards(id).map(func(c): return c["n"]),
		"named": named_in(id)}
