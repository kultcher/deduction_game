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
const CardModel = preload("res://game/card_model.gd")

var w
var state = "day"          # day | approach | talk | meeting | nomination | night | over
var approach = {}          # pending approach: {npc, agenda}
var moved = false          # has the player chosen a location this phase
var free_move_used = false
var loc = ""
var talk_with = null
var questions_left = 0
var free_repeats = 0       # repeats this conversation that cost no question (one allowed)
var board: Array = []
var _card_keys = {}
var _fact_keys = {}      # Mind.fact_id -> card number, for facts that can reach you twice
var case_notes = ""       # the player's free-form notes on the case
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
var fallback_count = 0      # times 'present' couldn't tell what a card was meant to prove
var debug_overlay = false   # show NPCs' hidden credence (spoils identification credit)
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
	_fact_keys = {}
	case_notes = ""
	notes = {}
	guesses = {}
	guess_history = []
	prediction_snapshots = []
	prediction_spoiled = false
	case_summary = {}
	last_link = {}
	log_paths = []
	ward_log = {}
	fallback_count = 0
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
	var disc = _disclosure(fact)
	if _card_keys.has(key):
		_disclose(board[_card_keys[key] - 1], disc)
		return _card_keys[key]
	# The same fact reaching you again (told privately, then publicly; relayed by someone
	# else) is one card with another disclosure, not a second card.
	var fk = Mind.fact_id(fact) if fact.get("kind", "") in CardModel.MERGE_KINDS else ""
	if fk != "" and _fact_keys.has(fk):
		var n0: int = _fact_keys[fk]
		_disclose(board[n0 - 1], disc)
		_card_keys[key] = n0
		return n0
	var card = fact.duplicate()
	card["n"] = board.size() + 1
	if not card.has("day"):
		card["day"] = w.day
	if not card.has("class"):
		card["class"] = Mind.evidence_class(card)
	card["when"] = CardModel.when(card, w.day, _phase_now())
	card["learned"] = [disc]
	card["view"] = CardModel.view_of(card)
	board.append(card)
	_card_keys[key] = card["n"]
	if fk != "":
		_fact_keys[fk] = card["n"]
	return card["n"]

## The current time slot as the board counts it (the meeting and the night belong to the
## evening and night of the day they're in).
func _phase_now() -> int:
	return C.NIGHT if state == "night" else w.phase

## When, how and from whom you heard this fact (public = at a town meeting).
func _disclosure(fact: Dictionary) -> Dictionary:
	var via: String = fact.get("via", fact.get("source", ""))
	return {"day": w.day, "phase": _phase_now(), "via": via, "public": state in ["meeting", "nomination"]}

func _disclose(card: Dictionary, disc: Dictionary) -> void:
	var ls: Array = card.get("learned", [])
	for d in ls:
		if d["day"] == disc["day"] and d["phase"] == disc["phase"] and d["via"] == disc["via"] and d["public"] == disc["public"]:
			return
	ls.append(disc)
	card["learned"] = ls

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
				_prompt("Record privately with 'guess <name> demon [1-3]' and 'guess <name> <minion gift> [1-3]', or use a profile's Your guess. This costs no time and gives no correctness feedback.")
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

## Whether the player can see where someone is right now: anyone at work or deep in
## conversation is plain to see from anywhere; anyone else only once the player is on
## their block this phase (out on the street, or a lit window at home).
func can_see(n) -> bool:
	if not n.alive:
		return false
	if state == "night":
		return true
	if not n.at_home() and (n.working or n.busy_with != ""):
		return true
	return moved and w.loc_block(n.loc) == w.loc_block(loc)

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
		# Go straight to them, if you can see where they are: anyone out on a block can be
		# seen from either location there, so walking to their exact spot reveals nothing
		# you wouldn't see on arrival.
		if not can_see(n):
			return ""
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
				var lost = find_npc(rest)
				if lost != null and lost.alive:
					_err("You can't see where %s is this %s. Try their work (%s) or their home block (%s)." % [lost.name,
						w.phase_name().to_lower(), w.loc_name(lost.work), C.block_name(lost.home_block)])
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
			free_repeats = 0
			state = "talk"
			w.dlog.add("player_talk", "player", n.id, {"trust": snappedf(n.trust, 0.01)})
			var cue = Mind.greeting_cue(w, n)
			if cue != "":
				_narr(cue)
			if not n.remarks.is_empty() and not n.is_evil():
				var said: String = n.remarks.pop_front()
				w.dlog.think(n.id, "reconsider", "Tells the player they've come round to %s." % said)
				_lines([Mind.say(n, "I didn't put much stock in %s. After all that's happened since... perhaps I should have." % said)])
			_narr("You draw %s aside. (3 questions: ask gift | ask night | ask today | ask are <gift> | ask about <name or gift> | present <card#> [for|against <name>] | bye)" % n.name)
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
		# One card per person: being in the same place isn't being together (a conversation
		# you see gets its own card linking the two).
		for n in here:
			_facts([{"kind": "sighting", "subject": [n.id], "block": w.loc_block(l),
				"loc": l, "day": w.day, "phase": w.phase, "source": "player",
				"text": "You saw %s at %s, day %d %s." % [n.name, w.loc_name(l), w.day, w.phase_name()]}])
	for other in w.locations_on(w.loc_block(l)):
		if other == l:
			continue
		var there: Array = w.npcs_at(other)
		if not there.is_empty():
			_narr("Nearby, at %s: %s." % [w.loc_name(other), _who_here(other)])
			for x in there:
				_facts([{"kind": "sighting", "subject": [x.id], "block": w.loc_block(other), "loc": other, "day": w.day,
					"phase": w.phase, "source": "player", "text": "You saw %s nearby at %s, day %d %s." %
					[x.name, w.loc_name(other), w.day, w.phase_name()]}])
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
	var tt: Dictionary = w.find_totem(l)
	if not tt.is_empty():
		var mat: String = C.BLOCKS[tt["material"]]["trace"]
		_narr("Wedged out of sight at %s you find a crude totem of bone and twine, caked with %s. It reeks of the grave. You burn it." % [w.loc_name(l), mat])
		_facts([{"kind": "totem", "subject": [], "block": tt["material"], "loc": l, "source": "evidence", "day": w.day, "phase": w.phase,
			"text": "A Revenant's totem, hidden at %s and found on day %d, caked with %s (from %s)." % [w.loc_name(l), w.day, mat, C.block_name(tt["material"])]}])
		if tt.get("freed", "") != "":
			_narr("As it burns, you feel the curse on the town lift. Whoever it turned is themselves again.")
			_facts([{"kind": "curse_lifted", "subject": [], "source": "player", "day": w.day, "phase": w.phase,
				"text": "Day %d: the totem burned and the Revenant's curse lifted. The turned soul is good again." % w.day}])
	var items: Array = w.dropped.get(l, [])
	if items.is_empty():
		if tt.is_empty():
			w.dlog.add("player_search", "player", "", {"loc": l}, "Nothing dropped here.")
		if tt.is_empty():
			_narr("You search %s carefully. Nothing out of place." % w.loc_name(l))
		return
	w.dropped.erase(l)
	var blk: String = w.loc_block(l)
	for it in items:
		w.dlog.add("player_search", "player", it["who"], {"loc": l, "item": it}, "Found something %s dropped (%s)." % [it["who"], it["why"]])
		if it["owner"] != "":
			var o = w.by_id[it["owner"]]
			_narr("Tucked against the wall of %s you find something of %s's, dropped there on night %d." % [w.loc_name(l), o.name, it["night"]])
			_facts([{"kind": "sighting", "subject": [o.id], "block": blk, "loc": l, "day": it["night"], "phase": C.NIGHT, "source": "evidence", "dropped": true,
				"text": "%s's belongings found at %s: they were on %s on night %d." % [o.name, w.loc_name(l), C.block_name(blk), it["night"]]}])
		else:
			_narr("At %s you find %s, left there on night %d. Someone who lives on %s passed this way in the dark." %
				[w.loc_name(l), C.BLOCKS[it["material"]]["trace"], it["night"], C.block_name(it["material"])])
			_facts([{"kind": "dropped", "subject": [], "block": blk, "loc": l, "day": it["night"], "phase": C.NIGHT, "source": "evidence",
				"material": it["material"], "text": "%s found at %s, left on night %d: someone from %s was out that night." %
				[C.BLOCKS[it["material"]]["trace"].capitalize(), w.loc_name(l), it["night"], C.block_name(it["material"])]}])

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
			free_repeats = 0
			w.dlog.add("player_talk", "player", n.id, {"trust": snappedf(n.trust, 0.01), "approach": approach["agenda"]})
			_narr("You step aside with %s at %s." % [n.name, w.loc_name(loc)])
			var r: Dictionary = Social.approach_open(w, n, approach["agenda"])
			_lines(r["lines"])
			_facts(r["facts"])
			_prompt("(3 questions: ask gift | ask night | ask today | ask are <gift> | ask about <name or gift> | present <card#> [for|against <name>] | bye)")
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
	if n.silenced and verb in ["ask", "a", "tell", "t", "present", "accuse", "show", "press"]:
		_narr("%s opens their mouth, but no sound comes. They can't speak (until tomorrow evening)." % n.name)
		return
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
				"are", "if", "is":
					# "ask are you the seer" / "ask if seer": a guess at their own gift.
					var words: Array = Array(p.slice(1)).filter(func(x): return not (x.to_lower() in ["you", "the", "a", "an", "they", "are"]))
					var grole = find_role(" ".join(PackedStringArray(words)))
					if grole == "":
						_err("Ask if they are which gift? ('ask are seer')")
						return
					r = Social.answer_is_role(w, n, grole)
				_:
					_err("Ask: gift | night | today | are <gift> | about <name or gift>")
					return
		"present", "show", "case":
			var pr = _route_present(n, rest)
			if pr.has("error"):
				_err(pr["error"])
				return
			if pr.has("flat"):
				_narr(pr["flat"])
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
			_conflict_pressure(board[num0 - 1], 0.1, n)
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
			var numd = pd[pd.size() - 1].trim_prefix("#").to_int() if pd.size() >= 2 else 0
			var sds: Array = []
			if pd.size() >= 2:
				for nm in pd[0].split(","):
					var x = find_npc(nm)
					if x != null:
						sds.append(x)
			if sds.is_empty() or numd < 1 or numd > board.size() or board[numd - 1].get("deleted", false):
				_err("Usage: present <card#> for <name>")
				return
			r = Mind.hear_defence(w, n, sds, board[numd - 1])
		"tell", "accuse":
			var p = rest.split(" ", false)
			if p.size() < 2:
				_err("Usage: tell <suspect> <card#>  (see 'board')")
				return
			if "," in p[0]:
				var grp: Array = []
				for nm in p[0].split(","):
					var x = find_npc(nm)
					if x != null and x != n:
						grp.append(x)
				var numg = p[p.size() - 1].trim_prefix("#").to_int()
				if grp.is_empty() or numg < 1 or numg > board.size():
					_err("Usage: present <card#>")
					return
				r = Mind.hear_group_case(w, n, grp, board[numg - 1])
			else:
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
			_err("In conversation: ask gift | ask night | ask today | ask are <gift> | ask about <name or gift> | present <card#> [for|against <name>] | bye")
			return
	# Something they've already heard from you: they say so, and it costs no question.
	var repeat = r["lines"].size() == 1 and r["lines"][0] is Dictionary and r["lines"][0].get("text", "") == "You've told me that already."
	if repeat and free_repeats >= 1:
		repeat = false  # once is a slip; after that it's wasting their time
	if repeat:
		free_repeats += 1
	else:
		questions_left -= 1
	_lines(r["lines"])
	_facts(r["facts"])
	if repeat:
		_prompt("(No question used. %d question%s left)" % [questions_left, "" if questions_left == 1 else "s"])
		return
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
	for sid in w.meeting.get("silenced", []):
		var sn = w.by_id[sid]
		_narr("%s rises to speak, but no sound comes. Their voice has been stolen; they can still vote." % sn.name)
		_facts([{"kind": "silenced", "subject": [sid], "source": "player", "day": w.day, "phase": C.EVENING,
			"text": "Day %d: %s could not speak at the meeting (silenced; can still vote)." % [w.day, sn.name]}])
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
			_facts([{"kind": "vote", "subject": subj, "source": "player", "day": w.day, "phase": C.EVENING,
				"nominee": t.id, "by": res["by"], "yes": res["yes"].duplicate(), "no": res["no"].duplicate(), "player_yes": res["player_yes"],
				"outcome": res["outcome"], "count": res["count"], "threshold": res["threshold"],
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
	if ex != "" and w.meeting.has("martyr"):
		var mt = w.by_id[w.meeting["martyr"]["martyr"]]
		var sv = w.by_id[w.meeting["martyr"]["saved"]]
		_narr("The meeting closes. As the noose tightens on %s, %s cries out and falls dead. %s is cut down alive: the Martyr has died in their place." % [sv.name, mt.name, sv.name])
		_facts([{"kind": "martyr", "subject": [mt.id, sv.id], "source": "player", "day": w.day, "phase": C.EVENING,
			"text": "Day %d: %s died in %s's place at the gallows. Both are proven good." % [w.day, mt.name, sv.name]}])
	elif ex != "":
		var n = w.by_id[ex]
		_narr("The meeting closes. %s is hanged at dusk." % n.name)
		_facts([{"kind": "execution", "subject": [ex], "source": "player", "day": w.day, "phase": C.EVENING, "text": "%s was executed on day %d." % [n.name, w.day]}])
		if w.meeting.get("curse", false):
			_narr("As %s swings, a cold wind moans through Hollowmere. A curse has taken one of those who voted to hang them: someone among you has turned." % n.name)
			_facts([{"kind": "curse", "subject": [ex], "source": "player", "day": w.day, "phase": C.EVENING,
				"text": "Day %d: as %s was hanged, a Revenant's curse turned one of those who voted for it. Find its totem to break the curse." % [w.day, n.name]}])
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
	for e in w.public_log:
		if e["kind"] == "knell" and e["day"] == w.day:
			_narr("At dusk the death knell tolls from the chapel. Doors are barred; nobody walks abroad tonight, or should.")
			_facts([{"kind": "knell", "subject": [], "source": "player", "day": w.day, "phase": C.EVENING,
				"text": "Night %d: the Sexton tolled the death knell (no gift that walks abroad should work)." % w.day}])
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
	_narr("and %s serve%s it. Find the host and see them hanged before the town falls." % ["a minion" if w.minion_ids.size() == 1 else "%d minions" % w.minion_ids.size(), "s" if w.minion_ids.size() == 1 else ""])
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
            conclude one of these is misled or lying because <card#> ...  ("something doesn't add up")
              status: good, evil, the demon, a gift (seer...), lying, misled, misled or lying;
                      should be protected / spared
              misled = not lying, but their information was wrong (poisoned or mistaken)
            hide <#> | unhide <#> | showhidden | delete <#> (your own deductions only)
            note <name> <text> | guess <name> <role|evil|good> [1-3] | theory
  Day     : go <place | block | person>   (then one free move within the same block)
            then one action: talk <name> | search | gossip (tavern) | wait
  Talking : ask gift | ask night | ask today | ask are <gift> | ask about <name or gift> | bye
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

## Current-phase view of the town: workers and conversations from anywhere; anyone else
## only on the player's own block (once they've chosen where to go).
func _map() -> String:
	var out = PackedStringArray()
	out.append("Around town this %s:" % w.phase_name().to_lower())
	var at_home: Array = []
	var unseen = 0
	for b in C.BLOCKS:
		var parts: Array = []
		var done = {}
		for n in w.living():
			if done.has(n.id) or w.loc_block(n.loc) != b or n.at_home():
				continue
			if not can_see(n):
				unseen += 1
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
			if can_see(n):
				at_home.append(n.name)
			else:
				unseen += 1
	if not at_home.is_empty():
		out.append("  At home nearby (you can call on them): " + ", ".join(PackedStringArray(at_home)))
	if unseen > 0:
		out.append("  %d other%s out of sight: go to a block to see who's about there." % [unseen, "" if unseen == 1 else "s"])
	return "\n".join(out)

func _cast() -> String:
	var out = PackedStringArray()
	out.append("The townsfolk:")
	for n in w.npcs:
		var status = "" if n.alive else "  [%s]" % _death_text(n)
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
		"" if n.alive else " %s%s." % [_death_text(n)[0].to_upper(), _death_text(n).substr(1)]])
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
	var fams = PackedStringArray()
	for pk in C.HINT_PACKAGES:
		fams.append("%s (%s)" % [C.HINT_PACKAGES[pk]["name"], ", ".join(PackedStringArray(C.HINT_PACKAGES[pk]["roles"].filter(func(r): return r in C.GOOD_ROLES).map(func(r): return C.role_name(r))))])
	out.append("Hint families: " + "; ".join(fams) + ".")
	out.append("Evil: the Demon, and %d of these minions:" % w.minion_ids.size())
	out.append("  %-12s %s" % ["Demon", C.ROLES["demon"]["desc"]])
	for r in C.MINION_ROLES:
		out.append("  %-12s %s" % [C.role_name(r), C.ROLES[r]["desc"]])
	out.append("Secrets (one in play, laid on a townsfolk on top of their gift):")
	for k in C.SECRET_MOD_LIST:
		out.append("  %-12s %s" % [C.secret_name(k), C.SECRET_MODS[k]["desc"]])
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
	case_summary = CaseMetrics.summarize(w, frozen, prediction_spoiled, board)
	case_summary["present_fallbacks"] = fallback_count
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
		if m.get("relation", "contradiction") == "contradiction":
			var grp: Array = Argue.group_of(w, cards.filter(func(x): return x["n"] in m["cards"]))
			if grp.size() >= 2:
				var cc = {"type": "conflict", "a": "", "group": grp}
				options.append({"match": m, "expl": {"id": 0, "kind": "conflict", "blame": "", "conclusion": cc,
					"label": "Something doesn't add up (no explanation chosen): one of %s is misled or lying" % Argue._names(w, grp)}})
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
	if conclusion.get("type", "") == "conflict":
		if conclusion.get("group", []).is_empty():
			conclusion["group"] = Argue.group_of(w, cards)
		if match_info.is_empty():
			for m in Argue.check(w, cards)["matches"]:
				if m.get("relation", "contradiction") == "contradiction":
					match_info = m
					chosen = 0
					break
	elif match_info.is_empty() and not supports.is_empty():
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
	var subj: Array = conclusion.get("group", []).duplicate() if conclusion.get("type", "") == "conflict" else ([conclusion["a"]] if conclusion.has("a") else [])
	var near = ""
	if unfounded:
		var nr: Array = Argue.check(w, cards)["near"]
		if not nr.is_empty():
			near = nr[0]
	var card = {"kind": "deduction", "subject": subj, "source": "player", "class": cls, "conclusion": conclusion,
		"supports": supports.duplicate(), "template": match_info.get("template", ""), "explanations": match_info.get("explanations", []),
		"chosen": chosen, "unfounded": unfounded, "near": near, "relation": match_info.get("relation", ""),
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
	var group_lead = 0
	if words[0] in ["someone", "somebody"]:
		group_lead = 1
	elif words.size() > 3 and words[0] == "one" and words[1] == "of" and words[2] in ["these", "them", "those"]:
		group_lead = 3
	if group_lead > 0:
		if supports.is_empty() and not last_link.is_empty():
			supports = last_link["cards"].duplicate()
		var tail = " ".join(words.slice(group_lead)).strip_edges()
		if not (tail in ["is misled or lying", "are misled or lying", "is lying or misled", "doesn't add up", "is wrong"]):
			return {"error": "For a group, say: conclude one of these is misled or lying because <cards>."}
		var gcards: Array = board.filter(func(x): return x["n"] in supports)
		return {"conclusion": Argue.conflict_of(w, gcards), "supports": supports}
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
## About the listener -> press them. A deduction -> argue it. A plain card about others ->
## a case for or against them, direction read from the card itself (a Seer "yes" accuses, a
## Seer "no" clears), split across everyone it names. for/against is only an override; if
## the card has no direction of its own, it falls flat (logged as a fallback).
func _route_present(n, rest: String) -> Dictionary:
	var p = rest.strip_edges().split(" ", false)
	if p.is_empty():
		return {"error": "Present which card? ('present <card#>')"}
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
		var cc: Dictionary = Argue.normalize(card["conclusion"].duplicate())
		if cc.get("a", "") == n.id and not (cc["type"] in ["misled", "unreliable"]):
			return {"verb": "press", "rest": str(num), "note": "You put it to %s directly." % n.name}
		return {"verb": "convince", "rest": str(num), "note": "You argue it to %s." % n.name}
	var subj: Array = card.get("subject", []).duplicate()
	for x in card.get("data", {}).get("pair", []):
		if not (x in subj):
			subj.append(x)
	if who == null and (n.id in subj or card.get("owner", "") == n.id):
		return {"verb": "press", "rest": str(num), "note": "You put it to %s directly." % n.name}
	if who == n:
		return {"verb": "press", "rest": str(num), "note": "You put it to %s directly." % n.name}
	var targets: Array = [who.id] if who != null else subj.filter(func(x): return x != n.id and x != card.get("source", "") and w.by_id.has(x) and w.by_id[x].alive)
	if targets.is_empty():
		return _present_fallback(n, num, "the card isn't about anyone living")
	if dir == "":
		var inc = 0.0
		var dfn = 0.0
		for x in targets:
			inc = maxf(inc, Mind.card_strength(w, card, w.by_id[x]))
			if card.get("kind", "") == "sighting" and card.get("phase", -1) == C.NIGHT:
				inc = maxf(inc, 0.45)  # its direction is plain even when it's weak (far from any death)
			dfn = maxf(dfn, Mind.defend_strength(card, x))
		if inc >= 0.4 and inc > dfn:
			dir = "against"
		elif dfn >= 0.4 and dfn > inc:
			dir = "for"
		else:
			return _present_fallback(n, num, "no clear direction (incriminating %.2f, clearing %.2f)" % [inc, dfn])
	var names = Argue._names(w, targets)
	var ids = ",".join(PackedStringArray(targets))
	if dir == "for":
		return {"verb": "defend", "rest": "%s %d" % [ids, num], "note": "You speak up for %s." % names}
	return {"verb": "tell", "rest": "%s %d" % [ids, num], "note": ("You make your case against %s." if targets.size() == 1 else "You point out it implicates one of %s.") % names}

## The card has no direction of its own: it falls flat, costs no question, and is logged
## so we can see which cards keep landing here.
func _present_fallback(n, num: int, why: String) -> Dictionary:
	fallback_count += 1
	w.dlog.add("present_fallback", "player", n.id, {"card": num, "kind": board[num - 1]["kind"], "why": why},
		"present couldn't tell what the card was meant to prove (%s)" % why)
	return {"verb": "", "rest": "", "note": "", "flat": "%s: \"I'm not sure what you're trying to prove.\" (You can say 'present %d for <name>' or 'against <name>'.)" % [n.name, num]}

## "Something doesn't add up" puts the people involved under scrutiny: publicly, all of
## them; privately, only the listener if they're one of them.
func _conflict_pressure(ded: Dictionary, amount: float, listener) -> void:
	var c: Dictionary = ded.get("conclusion", {})
	if c.get("type", "") != "conflict":
		return
	for id in c.get("group", []):
		var m = w.by_id[id]
		if not m.alive or (listener != null and m != listener):
			continue
		m.pressure += amount
		w.dlog.think(m.id, "pressed", "Under scrutiny: the Demonologist says something doesn't add up (pressure +%.2f -> %.2f)." % [amount, m.pressure])

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
	_conflict_pressure(ded, 0.2, null)
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
	if guess == "demon" or C.is_minion(guess):
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
	var dids = CaseMetrics.named_guesses(guesses, "demon")
	parts.append("Demon: %s" % (w.by_id[dids[0]].name if dids.size() == 1 else "not recorded"))
	var mids = CaseMetrics.minion_guesses(guesses)
	parts.append("Minion%s: %s" % ["" if w.minion_ids.size() == 1 else "s", ", ".join(PackedStringArray(mids.map(func(i): return "%s (%s)" % [w.by_id[i].name, C.role_name(guesses[i]["guess"])]))) if not mids.is_empty() else "not recorded"])
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
	# What evidence against the demon existed (descriptive, not a verdict on your play).
	var ob: Array = case_summary.get("demon_evidence_on_board", [])
	var rc: Array = case_summary.get("demon_evidence_reachable", [])
	if not case_summary["town_saved"]:
		if not ob.is_empty():
			lines.append("Evidence pointing at the demon was on your board: #%s." % ", #".join(PackedStringArray(ob.map(func(x): return str(x)))))
		elif not rc.is_empty():
			lines.append("Evidence pointing at the demon existed but never reached your board: %s." % "; ".join(PackedStringArray(rc.slice(0, 4))))
		else:
			lines.append("No true evidence pointed at the demon this case.")
	return "\n".join(lines)

## Debug overlay: reveal what NPCs privately make of cards and people. Turning it on during
## a case marks identification as unscored (like opening the grimoire).
func set_debug_overlay(on: bool) -> void:
	debug_overlay = on
	if on and not w.game_over and not prediction_spoiled:
		prediction_spoiled = true
		w.dlog.add("prediction_spoiled", "player", "", {}, "Turned on the debug overlay during the case; identification credit disabled.")

## Summary of how a value varies across good NPCs: "avg 0.46 · high 0.60 (A) · low 0.30 (H)".
func _spread(vals: Dictionary) -> String:
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
	return "avg %.2f · high %.2f (%s) · low %.2f (%s)" % [tot / vals.size(), vals[hi_id], w.by_id[hi_id].name.substr(0, 1),
		vals[lo_id], w.by_id[lo_id].name.substr(0, 1)]

## A card's current influence on each good NPC who has heard the claim behind it (the share
## of its full weight it carries for them). Readings and your arguments map cleanly; other
## cards only if an NPC holds the same fact. Returns "" when nobody's record matches.
func debug_card_text(card: Dictionary) -> String:
	var eid = ""
	if card.get("kind", "") == "deduction":
		eid = "arg:" + Argue.conclusion_key(Argue.normalize(card["conclusion"].duplicate()))
	else:
		eid = Mind.fact_id(card)
	var vals = {}
	var listeners = w.living_good()
	for n in listeners:
		if n.ledger.has(eid):
			vals[n.id] = n.ledger[eid].get("eff", n.ledger[eid]["weight"])
	if vals.is_empty():
		return ""
	return "influence %s · heard by %d of %d" % [_spread(vals), vals.size(), listeners.size()]

## How the town (good NPCs) credits and suspects this person.
func debug_npc_text(id: String) -> String:
	var hon = {}
	var sus = {}
	for n in w.living_good():
		if n.id == id:
			continue
		hon[n.id] = n.honesty.get(id, 1.0)
		sus[n.id] = n.suspicion.get(id, 0.0)
	var n0 = w.by_id[id]
	var town = {}
	for n in w.living_good():
		if n.id != id and n.consensus_applied.get(id, 0.0) > 0.0:
			town[n.id] = n.consensus_applied[id]
	var trust_line = "Trust in you: %.2f%s" % [n0.trust, (" (capped at %.2f)" % n0.trust_cap) if n0.trust_cap < 1.0 else ""]
	if n0.is_evil():
		trust_line += " (evil: acted, not felt)"
	var out = "%s · Pressure: %.2f\nCredited by others: %s\nSuspected by others: %s" % [trust_line, n0.pressure, _spread(hon), _spread(sus)]
	if not town.is_empty():
		out += "\n  of which public accusations: %s" % _spread(town)
	return out

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
				what = "the " + C.role_name(d.get("role", "poisoner"))
			"rumormonger":
				what = C.secret_name(d.get("secret", "")) + " (a secret)"
			"seer":
				what = "the demon" if d.get("yes", false) else "not the demon (cleared)"
		if what == "":
			continue
		var lead = "" if what.begins_with("not") else "possibly "
		out.append("%s%s (#%d: %s's %s reading, night %d%s)" % [lead, what, c["n"], src, C.role_name(c["role"]), c.get("day", 0),
			(", with " + other) if other != "" else ""])
	return out

func _death_text(n) -> String:
	match n.death_cause:
		"demon":
			return "killed by the demon, night %d" % n.death_day
		"martyr":
			return "died in another's place at the gallows, day %d" % n.death_day
	return "executed, day %d" % n.death_day

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
	var status = "alive" if n.alive else _death_text(n)
	return {"id": id, "name": n.name, "occupation": n.occupation, "blurb": n.blurb, "work": "%s at %s" % [C.phase_list(n.work_phases), w.loc_name(n.work)],
		"home": C.block_name(n.home_block), "status": status, "traits": n.revealed_traits.duplicate(), "claim": claim,
		"guess": guesses.get(id, {}), "note": notes.get(id, ""), "cards": filter_cards(id).map(func(c): return c["n"]),
		"named": named_in(id)}
