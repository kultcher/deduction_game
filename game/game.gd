## Player-facing game layer: command interpreter, case board, and text output.
## Shared by the terminal CLI, the Godot text UI and the autoplay bot.
extends RefCounted

const C = preload("res://sim/content.gd")
const World = preload("res://sim/world.gd")
const Mind = preload("res://sim/mind.gd")

var w
var state = "day"          # day | talk | meeting | night | over
var moved = false          # has the player chosen a location this phase
var talk_with = null
var questions_left = 0
var board: Array = []       # case board cards
var _card_keys = {}
var meeting_noms: Array = []
var player_nominated = false
var player_vote = ""
var log_dir = "user://logs"
var log_paths: Array = []
var debug = false

# ---------------------------------------------------------------- lifecycle

func new_case(seed_in: int, npc_count: int = 7) -> String:
	w = World.new()
	w.setup(seed_in, npc_count)
	state = "day"
	moved = false
	var out = PackedStringArray()
	out.append(_intro())
	out.append(_morning_report())
	_record("new_case", "", "\n".join(out))
	return "\n".join(out)

func command(line: String) -> String:
	var text = line.strip_edges()
	if text == "":
		return ""
	var out = _dispatch(text)
	_record("command", text, out)
	if w.game_over and state != "over":
		state = "over"
		out += "\n\n" + _ending()
	return out

func _record(kind: String, cmd: String, out: String) -> void:
	if w == null:
		return
	w.set_log_time()
	w.dlog.add("player_" + kind, "player", "", {"cmd": cmd, "output": out})

# ---------------------------------------------------------------- parsing helpers

func find_npc(token: String, include_dead := false):
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
	var t = token.to_lower().strip_edges()
	for l in w.all_locations():
		if l == t:
			return l
	for l in w.all_locations():
		var nm: String = w.loc_name(l).to_lower()
		if l.begins_with(t) or t in nm:
			return l
	var victim = find_npc(t, true)
	if victim and w.scenes.has("scene_" + victim.id):
		return "scene_" + victim.id
	return ""

func find_block(token: String) -> String:
	var t = token.to_lower().strip_edges()
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
	board.append(card)
	_card_keys[key] = card["n"]
	return card["n"]

func _add_facts(facts: Array) -> String:
	var nums: Array = []
	for f in facts:
		nums.append(str(add_card(f)))
	if nums.is_empty():
		return ""
	return "  [case board: #%s]" % ", #".join(PackedStringArray(nums))

# ---------------------------------------------------------------- dispatch

func _dispatch(text: String) -> String:
	var parts = text.split(" ", false)
	var verb = parts[0].to_lower()
	var rest = " ".join(parts.slice(1))
	match verb:
		"help", "?", "h":
			return _help()
		"look", "l":
			return _look()
		"map", "m":
			return _map()
		"cast", "people", "who":
			return _cast()
		"board", "notes", "b":
			return _board(rest)
		"roles", "script":
			return _script()
		"log":
			return _write_logs()
		"grimoire":
			if debug or state == "over":
				if rest.strip_edges().to_lower() == "lies":
					return _lies()
				return _grimoire()
			return "The grimoire is sealed until the case ends."
	if state == "over":
		return "The case is closed. Type 'grimoire' for the full reveal, or start a new case."
	match state:
		"day":
			return _day_command(verb, rest)
		"talk":
			return _talk_command(verb, rest)
		"meeting":
			return _meeting_command(verb, rest)
		"night":
			return _night_command(verb, rest)
	return "Nothing happens."

# ---------------------------------------------------------------- day

func _day_command(verb: String, rest: String) -> String:
	match verb:
		"go", "visit", "g":
			if moved:
				return "You have already chosen where to spend the %s. Talk, search, gossip or wait." % w.phase_name().to_lower()
			var l = find_location(rest)
			if l == "":
				return "Where? Try 'map' for places."
			moved = true
			w.player_loc = l
			w.dlog.add("player_move", "player", "", {"loc": l})
			return _observe()
		"talk", "t":
			if not moved:
				return "First choose where to spend this phase ('go <place>')."
			var n = find_npc(rest)
			if n == null or n.loc != w.player_loc:
				return "%s isn't here." % (rest if n == null else n.name)
			talk_with = n
			questions_left = 3
			state = "talk"
			w.dlog.add("player_talk", "player", n.id, {"trust": snappedf(n.trust, 0.01)})
			return "You draw %s aside. (%d questions: ask gift | ask info | ask night | ask today | ask about <name> | tell <suspect> <card#> | bye)" % [n.name, questions_left]
		"search", "s":
			if not moved:
				return "First choose where to spend this phase ('go <place>')."
			return _search() + _end_phase()
		"gossip":
			if not moved:
				return "First choose where to spend this phase ('go <place>')."
			if w.player_loc != "tavern":
				return "You can only listen for gossip at the tavern."
			var r: Dictionary = Mind.gossip(w)
			return "\n".join(PackedStringArray(r["lines"])) + _add_facts(r["facts"]) + _end_phase()
		"wait", "rest", "pass":
			return "You let the %s pass." % w.phase_name().to_lower() + _end_phase()
	return "You can't do that now. Type 'help'."

func _observe() -> String:
	var l: String = w.player_loc
	var out = PackedStringArray()
	out.append("You spend the %s at %s (%s)." % [w.phase_name().to_lower(), w.loc_name(l), C.block_name(w.loc_block(l))])
	var here: Array = w.npcs_at(l)
	if here.is_empty():
		out.append("Nobody is here.")
	else:
		var names: Array = here.map(func(n): return "%s the %s" % [n.name, n.occupation])
		out.append("Present: " + ", ".join(PackedStringArray(names)) + ".")
		out.append(_add_facts([{"kind": "sighting", "subject": here.map(func(n): return n.id), "block": w.loc_block(l),
			"loc": l, "day": w.day, "phase": w.phase, "source": "player",
			"text": "You saw %s at %s, day %d %s." % [", ".join(PackedStringArray(here.map(func(n): return n.name))), w.loc_name(l), w.day, w.phase_name()]}]).strip_edges())
	for other in w.all_locations():
		if other == l or w.loc_block(other) != w.loc_block(l):
			continue
		var there: Array = w.npcs_at(other)
		if not there.is_empty():
			out.append("Nearby, at %s: %s." % [w.loc_name(other), ", ".join(PackedStringArray(there.map(func(n): return n.name)))])
	if w.scenes.has(l):
		out.append("This is where %s was killed. ('search' to examine it.)" % w.by_id[w.scenes[l]["victim"]].name)
	out.append("Actions: talk <name> | search%s | wait" % (" | gossip" if l == "tavern" else ""))
	return "\n".join(out)

func _search() -> String:
	var l: String = w.player_loc
	if w.scenes.has(l):
		var sc: Dictionary = w.scenes[l]
		if sc["searched"]:
			return "You go over the scene again. Nothing new."
		sc["searched"] = true
		var tb: String = sc["trace_block"]
		var text = "Near the body you find %s. The killer likely came from %s." % [C.BLOCKS[tb]["trace"], C.block_name(tb)]
		w.dlog.add("player_search", "player", sc["victim"], {"trace_block": tb, "trace_true": sc["trace_true"]}, sc["why"])
		var who: Array = w.npcs.filter(func(n): return n.home_block == tb or w.loc_block(n.work) == tb).map(func(n): return n.id)
		return text + _add_facts([{"kind": "trace", "subject": who, "block": tb, "source": "evidence", "day": w.day,
			"text": "Trace at %s's death scene points to %s (lives or works there: %s)." % [w.by_id[sc["victim"]].name, C.block_name(tb),
				", ".join(PackedStringArray(who.map(func(i): return w.by_id[i].name)))]}])
	w.dlog.add("player_search", "player", "", {"loc": l}, "Nothing to find at an ordinary location.")
	return "You search %s carefully. Nothing out of place: nobody has hidden anything here." % w.loc_name(l)

func _end_phase() -> String:
	moved = false
	w.player_loc = ""
	if w.end_day_phase():
		return "\n\n" + _phase_header()
	return "\n\n" + _start_meeting()

func _phase_header() -> String:
	return "=== Day %d, %s ===\nWhere will you spend the %s? ('go <place>', 'map')" % [w.day, w.phase_name(), w.phase_name().to_lower()]

# ---------------------------------------------------------------- conversation

func _talk_command(verb: String, rest: String) -> String:
	var n = talk_with
	if not n.alive:
		state = "day"
		return "They are gone."
	var r = {}
	match verb:
		"ask", "a":
			var p = rest.split(" ", false)
			var topic = p[0].to_lower() if p.size() > 0 else ""
			match topic:
				"gift", "role":
					r = Mind.answer_role(w, n)
				"info", "learned":
					r = Mind.answer_info(w, n)
				"night", "lastnight":
					r = Mind.answer_night(w, n)
				"today", "seen":
					r = Mind.answer_today(w, n)
				"about", "opinion":
					var t = find_npc(" ".join(p.slice(1)), true)
					if t == null:
						return "Ask about whom?"
					if t == n:
						return "%s gives you a flat look." % n.name
					r = Mind.answer_opinion(w, n, t)
				_:
					return "Ask about: gift | info | night | today | about <name>"
		"tell", "accuse":
			var p = rest.split(" ", false)
			if p.size() < 2:
				return "Usage: tell <suspect> <card#>  (see 'board')"
			var s = find_npc(p[0])
			var num = p[p.size() - 1].trim_prefix("#").to_int()
			if s == null:
				return "Who is suspicious?"
			if s == n:
				return "Accusing %s to their own face? Try someone else." % n.name
			if num < 1 or num > board.size():
				return "No such card on your board."
			r = Mind.hear_accusation(w, n, s, board[num - 1])
		"bye", "leave", "done":
			state = "day"
			talk_with = null
			return "You leave %s to their business." % n.name + _end_phase()
		_:
			return "In conversation: ask gift | ask info | ask night | ask today | ask about <name> | tell <suspect> <card#> | bye"
	questions_left -= 1
	var out: String = "\n".join(PackedStringArray(r["lines"])) + _add_facts(r["facts"])
	if questions_left <= 0:
		state = "day"
		talk_with = null
		out += "\n%s has other things to do." % n.name + _end_phase()
	else:
		out += "\n(%d question%s left)" % [questions_left, "" if questions_left == 1 else "s"]
	return out

# ---------------------------------------------------------------- meeting

func _start_meeting() -> String:
	state = "meeting"
	player_nominated = false
	player_vote = ""
	var out = PackedStringArray()
	out.append("=== Day %d: the town meeting ===" % w.day)
	var testimony: Array = w.run_testimony()
	if testimony.is_empty():
		out.append("Nobody has much to say tonight.")
	for t in testimony:
		out.append(t["text"] + _add_facts(t["facts"]))
	meeting_noms = w.npc_nominations()
	if meeting_noms.is_empty():
		out.append("\nNobody stands to nominate.")
	for nm in meeting_noms:
		out.append("\n%s stands and nominates %s for execution." % [w.by_id[nm["by"]].name, w.by_id[nm["nominee"]].name])
	out.append("\nYou may 'nominate <name>' (once), 'vote <name>' to back a nominee, then 'done' to count the votes.")
	return "\n".join(out)

func _meeting_command(verb: String, rest: String) -> String:
	match verb:
		"nominate", "nom":
			if player_nominated:
				return "You have already nominated today."
			var n = find_npc(rest)
			if n == null:
				return "Nominate whom?"
			for nm in meeting_noms:
				if nm["nominee"] == n.id:
					player_vote = n.id
					return "%s is already nominated. You back that nomination." % n.name
			player_nominated = true
			player_vote = n.id
			meeting_noms.append({"nominee": n.id, "by": "player", "reason": "player"})
			w.nominations_today.append({"nominee": n.id, "by": "player"})
			w.dlog.add("player_nominate", "player", n.id)
			return "You nominate %s. You will vote for it." % n.name
		"vote", "v":
			var n = find_npc(rest)
			if n == null:
				return "Vote for whom?"
			for nm in meeting_noms:
				if nm["nominee"] == n.id:
					player_vote = n.id
					return "You will vote to execute %s." % n.name
			return "%s has not been nominated." % n.name
		"done", "pass", "count":
			return _tally()
	return "At the meeting: nominate <name> | vote <name> | done"

func _tally() -> String:
	var out = PackedStringArray()
	if meeting_noms.is_empty():
		out.append("No nominations. The meeting breaks up.")
	else:
		var res: Dictionary = w.run_votes(meeting_noms, player_vote)
		for r in res["results"]:
			var yes_names: Array = r["yes"].map(func(i): return w.by_id[i].name)
			if r["player_yes"]:
				yes_names.append("you")
			out.append("Vote on %s (nominated by %s): %d of %d for execution (%s)." % [w.by_id[r["nominee"]].name,
				"you" if r["by"] == "player" else w.by_id[r["by"]].name, r["count"], res["total_voters"],
				", ".join(PackedStringArray(yes_names)) if not yes_names.is_empty() else "nobody"])
			var subj: Array = r["yes"].duplicate()
			subj.append(r["nominee"])
			out.append(_add_facts([{"kind": "vote", "subject": subj, "source": "player",
				"text": "Day %d vote on %s: for = %s." % [w.day, w.by_id[r["nominee"]].name, ", ".join(PackedStringArray(yes_names))]}]).strip_edges())
		if res["executed"] != "":
			var ex = w.by_id[res["executed"]]
			out.append("\nThe town has decided. %s is hanged at dusk." % ex.name)
			out.append(_add_facts([{"kind": "execution", "subject": [ex.id], "source": "player",
				"text": "%s was executed on day %d." % [ex.name, w.day]}]).strip_edges())
		else:
			out.append("\nNo one receives enough votes. Nobody is executed.")
	if w.game_over:
		return "\n".join(out)
	state = "night"
	out.append("\n=== Night %d ===\nChoose your night work: 'ward <name>' (shield them from the demon) or 'vigil <block>' (watch a block), or 'sleep'." % w.day)
	return "\n".join(out)

# ---------------------------------------------------------------- night

func _night_command(verb: String, rest: String) -> String:
	match verb:
		"ward", "protect":
			var n = find_npc(rest)
			if n == null:
				return "Ward whom?"
			w.player_ward = n.id
			w.player_vigil = ""
			return "You chalk a warding sigil on %s's door." % n.name + _resolve_night()
		"vigil", "watch":
			var b = find_block(rest)
			if b == "":
				return "Watch which block? (square, market, docks, hill)"
			w.player_vigil = b
			w.player_ward = ""
			return "You keep a cold vigil on %s." % C.block_name(b) + _resolve_night()
		"sleep", "wait", "pass":
			w.player_ward = ""
			w.player_vigil = ""
			return "You sleep uneasily." + _resolve_night()
	return "At night: ward <name> | vigil <block> | sleep"

func _resolve_night() -> String:
	var vig: String = w.player_vigil
	w.resolve_night()
	var out = PackedStringArray()
	if vig != "":
		if w.player_vigil_seen.is_empty():
			out.append("\nNobody moves through %s all night." % C.block_name(vig))
			out.append(_add_facts([{"kind": "vigil", "subject": [], "block": vig, "source": "player", "day": w.day, "phase": C.NIGHT,
				"text": "Night %d vigil on %s: nobody moved." % [w.day, C.block_name(vig)]}]).strip_edges())
		else:
			var names: Array = w.player_vigil_seen.map(func(i): return w.by_id[i].name)
			out.append("\nDuring your vigil you see %s moving through %s." % [", ".join(PackedStringArray(names)), C.block_name(vig)])
			out.append(_add_facts([{"kind": "sighting", "subject": w.player_vigil_seen.duplicate(), "block": vig, "source": "player",
				"day": w.day, "phase": C.NIGHT, "text": "Night %d vigil: you saw %s on %s." % [w.day, ", ".join(PackedStringArray(names)), C.block_name(vig)]}]).strip_edges())
	w.player_vigil = ""
	if w.game_over:
		return "\n".join(out)
	w.start_new_day()
	if w.game_over:
		return "\n".join(out)
	state = "day"
	moved = false
	out.append("")
	out.append(_morning_report())
	return "\n".join(out)

func _morning_report() -> String:
	var out = PackedStringArray()
	out.append("=== Day %d, Morning ===" % w.day)
	if w.day > 1 or not w.deaths_last_night.is_empty():
		if w.deaths_last_night.is_empty():
			out.append("Dawn breaks. Nobody died in the night.")
		for id in w.deaths_last_night:
			var v = w.by_id[id]
			out.append("Dawn breaks over a body: %s the %s was killed in the night. Their cottage on %s is now a crime scene." %
				[v.name, v.occupation, C.block_name(v.home_block)])
			out.append(_add_facts([{"kind": "death", "subject": [id], "block": v.home_block, "source": "player",
				"text": "%s was killed by the demon on night %d (home on %s)." % [v.name, w.day - 1, C.block_name(v.home_block)]}]).strip_edges())
	out.append("%d townsfolk remain. Where will you spend the morning? ('go <place>', 'map', 'help')" % w.living().size())
	return "\n".join(out)

# ---------------------------------------------------------------- info screens

func _intro() -> String:
	var out = PackedStringArray()
	out.append("THE DEMONOLOGIST  (case #%d)" % w.seed_value)
	out.append("You arrive in the village of Hollowmere at dawn. A demon wears the skin of one of its people,")
	out.append("and a Poisoner serves it. Find the host and see them hanged before the town falls.")
	out.append("")
	out.append(_cast())
	out.append("")
	out.append("Type 'roles' for the gifts that may be in play, 'help' for commands.")
	return "\n".join(out)

func _help() -> String:
	return """Commands
  Anytime : look | map | cast | board [kind] | roles | help | log
  Day     : go <place>  then one of: talk <name> | search | gossip (tavern) | wait
  Talking : ask gift | ask info | ask night | ask today | ask about <name>
            tell <suspect> <card#>   (make a case using a card from your board)
            bye
  Meeting : nominate <name> | vote <name> | done
  Night   : ward <name> | vigil <block> | sleep
Each day phase (morning, afternoon, evening) allows one action. A conversation allows 3 questions.
You win when the demon's host is executed. You lose if only two townsfolk remain or day %d ends.""" % w.max_days

func _look() -> String:
	match state:
		"day":
			if moved:
				return _observe()
			return _phase_header()
		"talk":
			return "You are talking with %s (%d questions left)." % [talk_with.name, questions_left]
		"meeting":
			var noms: Array = meeting_noms.map(func(nm): return w.by_id[nm["nominee"]].name)
			return "The town meeting. Nominated: %s. Your vote: %s." % [", ".join(PackedStringArray(noms)) if not noms.is_empty() else "nobody",
				w.by_id[player_vote].name if player_vote != "" else "none"]
		"night":
			return "Night falls. ward <name> | vigil <block> | sleep"
	return "The case is over."

func _map() -> String:
	var out = PackedStringArray()
	for b in C.BLOCKS:
		var locs: Array = w.all_locations().filter(func(l): return w.loc_block(l) == b).map(func(l): return w.loc_name(l))
		var homes: Array = w.npcs.filter(func(n): return n.home_block == b).map(func(n): return n.name + ("" if n.alive else " (dead)"))
		out.append("%s: %s.  Homes: %s" % [C.block_name(b), ", ".join(PackedStringArray(locs)), ", ".join(PackedStringArray(homes)) if not homes.is_empty() else "none"])
	var ring: Array = w.npcs.duplicate()
	ring.sort_custom(func(a, b): return a.ring < b.ring)
	out.append("Lane order (neighbours, wraps around): " + " - ".join(PackedStringArray(ring.map(func(n): return n.name + ("" if n.alive else "†")))))
	return "\n".join(out)

func _cast() -> String:
	var out = PackedStringArray()
	out.append("The townsfolk:")
	for n in w.npcs:
		var claim = ""
		if n.claimed_role != "" and (n.claim_public or n.told_player_role or n.claimed_role == "none"):
			claim = "  claims: %s%s" % [C.role_name(n.claimed_role), "" if n.claim_public else " (privately)"]
		var status = "" if n.alive else ("  [killed night %d]" % n.death_day if n.death_cause == "demon" else "  [executed day %d]" % n.death_day)
		out.append("  %-12s the %-13s works at %s, lives on %s. %s.%s%s" % [n.name, n.occupation, w.loc_name(n.work),
			C.block_name(n.home_block), n.blurb[0].to_upper() + n.blurb.substr(1), status, claim])
	return "\n".join(out)

func _script() -> String:
	var out = PackedStringArray()
	out.append("Gifts that may be in play (not all will be):")
	for r in C.GOOD_ROLES:
		out.append("  %-12s %s" % [C.role_name(r), C.ROLES[r]["desc"]])
	out.append("Evil (always in play): ")
	out.append("  %-12s %s" % ["Demon", C.ROLES["demon"]["desc"]])
	out.append("  %-12s %s" % ["Poisoner", C.ROLES["poisoner"]["desc"]])
	return "\n".join(out)

func _board(filter: String) -> String:
	if board.is_empty():
		return "Your case board is empty."
	var out = PackedStringArray()
	var f = filter.strip_edges().to_lower()
	for c in board:
		if f != "" and c["kind"] != f:
			var subj_names: Array = c.get("subject", []).map(func(i): return w.by_id[i].name.to_lower())
			if not (f in subj_names) and not f in c["text"].to_lower():
				continue
		out.append("#%-3d [%s] %s" % [c["n"], c["kind"], c["text"]])
	if out.is_empty():
		return "No cards match."
	return "\n".join(out)

func _ending() -> String:
	var out = PackedStringArray()
	if w.winner == "good":
		out.append("*** VICTORY ***  " + w.end_reason)
	else:
		out.append("*** DEFEAT ***  " + w.end_reason)
	out.append("")
	out.append(_grimoire())
	out.append("")
	out.append(_write_logs())
	return "\n".join(out)

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
		out.append("  %-12s %-11s %-5s %s" % [n.name, C.role_name(n.role), n.alignment.to_upper(), "; ".join(extra)])
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
