## Daytime visibility/movement, location observation, multi-trace crime-scene
## search, phase transitions, night actions, and dawn reports for `Game`.
##
## Extracted from `game/game.gd`; `Game` retains thin forwarding methods so all
## UI panels (`ui/`) and test suites can continue calling `g.<fn>(...)` unchanged.
extends RefCounted

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const Credibility = preload("res://game/credibility.gd")


## Whether the player can see where someone is right now: anyone at work or deep in
## conversation is plain to see from anywhere; anyone else only once the player is on
## their block this phase (out on the street, or a lit window at home).
## How many people are at a location whom you can't see from here (not who: just that
## someone's there, so you don't walk into an empty spot).
static func unseen_at(g, l: String) -> int:
	return g.w.npcs_at(l).filter(func(n): return not n.at_home() and not can_see(g, n)).size()


static func unseen_at_ui(g, l: String) -> int:
	return g.w.npcs_at(l).filter(func(n): return not n.at_home() and not can_see_ui(g, n)).size()


static func can_see(g, n) -> bool:
	if not n.alive:
		return false
	if g.state == "night":
		return true
	if not n.at_home() and (n.working or n.busy_with != ""):
		return true
	return g.moved and g.w.loc_block(n.loc) == g.w.loc_block(g.loc)


static func can_see_ui(g, n) -> bool:
	if can_see(g, n):
		return true
	if not n.alive or g.state == "night" or n.at_home():
		return false
	if g.state == "approach" and g.approach.get("npc") == n:
		return true
	return n.id == g.approached_id and n.loc == g.approached_loc


## Who the player can see at a location (a home shows only its owner, if in).
static func _present(g, l: String) -> Array:
	if l.begins_with("home_"):
		var o = g.w.by_id.get(l.substr(5))
		return [o] if o != null and o.alive and o.at_home() else []
	return g.w.npcs_at(l)


static func _resolve_go(g, target: String) -> String:
	var l = g.find_location(target)
	if l != "":
		return l
	var b = g.find_block(target)
	if b != "":
		return _best_location_on(g, b)
	var n = g.find_npc(target)
	if n != null:
		# Go straight to them, if you can see where they are: anyone out on a block can be
		# seen from either location there, so walking to their exact spot reveals nothing
		# you wouldn't see on arrival.
		if not can_see(g, n):
			return ""
		if n.at_home():
			return "home_" + n.id
		return n.loc
	return ""


static func _best_location_on(g, b: String) -> String:
	var locs: Array = g.w.locations_on(b)
	for l in locs:
		for n in g.w.npcs_at(l):
			if n.working:
				return l
	return locs[0]


static func _day_command(g, verb: String, rest: String) -> void:
	match verb:
		"go", "visit", "g":
			var sought = g.find_npc(rest) if g.find_location(rest) == "" and g.find_block(rest) == "" else null
			var l = _resolve_go(g, rest)
			if l == "":
				var lost = g.find_npc(rest)
				if lost != null and lost.alive:
					var hs: String = g.known_haunt_names(lost.id)
					g._err("You can't see where %s is this %s. Try their work (%s), %s, or their home block (%s)." % [lost.name,
						g.w.phase_name().to_lower(), g.w.loc_name(lost.work), ("where they often go (%s)" % hs) if hs != "" else "where they go off work (ask around)", C.block_name(lost.home_block)])
				else:
					g._err("Where? Try 'map' for places (a location, a block, or a person).")
				return
			if g.moved:
				if l == g.loc:
					g._err("You're already here.")
				elif g.free_move_used:
					g._err("You've already moved once this %s. Talk, search, or wait." % g.w.phase_name().to_lower())
				elif g.w.loc_block(l) != g.w.loc_block(g.loc):
					g._err("You can only move within %s now (one free move per phase)." % C.block_name(g.w.loc_block(g.loc)))
				else:
					_warn_busy_visit(g, sought)
					g.free_move_used = true
					g.loc = l
					g.w.player_loc = l
					g.w.dlog.add("player_move", "player", "", {"loc": l, "free_move": true})
					_observe(g)
				return
			_warn_busy_visit(g, sought)
			g.moved = true
			g.free_move_used = false
			g.loc = l
			g.w.player_loc = l
			g.w.dlog.add("player_move", "player", "", {"loc": l})
			_observe(g)
			if sought != null and not sought.at_home() and sought.loc != l and g.w.loc_block(sought.loc) == g.w.loc_block(l):
				g._narr("%s isn't here, but you spot them at %s. ('talk %s' walks you over, using your free move.)" %
					[sought.name, g.w.loc_name(sought.loc), sought.name.to_lower()])
		"talk", "t":
			if not g.moved:
				g._err("First choose where to spend this phase ('go <place>').")
				return
			var n = g.find_npc(rest)
			if n == null:
				g._err("Talk to whom?")
				return
			var at_their_home = g.loc == "home_" + n.id and n.at_home()
			if n.loc != g.loc and not at_their_home:
				if n.at_home():
					g._err("%s is at home (on %s) this %s. 'go %s' to call on them." % [n.name, C.block_name(n.home_block),
						g.w.phase_name().to_lower(), n.name.to_lower()])
					return
				if g.w.loc_block(n.loc) == g.w.loc_block(g.loc) and not g.free_move_used:
					g.free_move_used = true
					g.loc = n.loc
					g.w.player_loc = g.loc
					g.w.dlog.add("player_move", "player", "", {"loc": g.loc, "free_move": true, "via": "talk"})
					g._narr("You walk over to %s." % g.w.loc_name(g.loc))
				elif g.w.loc_block(n.loc) == g.w.loc_block(g.loc):
					g._err("%s is at %s, and you've already used your free move this %s." % [n.name, g.w.loc_name(n.loc), g.w.phase_name().to_lower()])
					return
				else:
					g._err("%s isn't here." % n.name)
					return
			if n.busy_with != "":
				g._err("%s is deep in conversation with %s." % [n.name, g.w.by_id[n.busy_with].name])
				return
			g.talk_with = n
			Mind.Dialogue.begin_conversation(n.dialogue_memory)
			g.questions_left = 3
			g.free_repeats = 0
			g.talk_approached = false
			g.talk_offered = false
			g.state = "talk"
			g.w.dlog.add("player_talk", "player", n.id, {"trust": snappedf(n.trust, 0.01)})
			g._line(Mind.greeting_line(g.w, n, g._greeting_context(n)))
			if not n.remarks.is_empty() and not n.is_evil():
				var said: String = n.remarks.pop_front()
				g.w.dlog.think(n.id, "reconsider", "Tells the player they've come round to %s." % said)
				g._lines([Mind.reconsideration_line(n, said)])
			g._narr("You draw %s aside. %s" % [n.name, g._talk_options(n)])
		"search", "s":
			if not g.moved:
				g._err("First choose where to spend this phase ('go <place>').")
				return
			if g.loc.begins_with("home_"):
				g._err("You can't search someone's home from their doorstep.")
				return
			if C.is_player_building(g.loc):
				g._err("There are no personal drops or crime scenes inside %s; use 'records' to check the town register." % g.w.loc_name(g.loc))
				return
			_search(g)
			_end_phase(g, "")
		"gossip":
			if not g.moved:
				g._err("First choose where to spend this phase ('go <place>').")
				return
			if g.loc != "tavern":
				g._err("You can only listen for gossip at the tavern.")
				return
			if g.w.phase != C.EVENING:
				g._err("The tavern only buzzes with town gossip in the evening.")
				return
			g.w.finish_evening_conversations("")
			var r: Dictionary = Social.tavern_evening_gossip(g)
			g._lines(r["lines"])
			g._facts(r["facts"])
			_apply_tavern_profile_gossip(g, r)
			_end_phase(g, "")
		"records", "register", "town_hall", "inspect":
			if not g.moved:
				g._err("First choose where to spend this phase ('go town_hall').")
				return
			if g.loc != "town_hall":
				g._err("You can only inspect the town registers at the Town Hall.")
				return
			if g.w.phase not in [C.MORNING, C.AFTERNOON]:
				g._err("The Town Hall's records room is only open in the morning and afternoon.")
				return
			if g.w.town_hall_uses_left <= 0:
				g._err("You have already consulted the Town Hall records %d times this case." % Tuning.Setup.TOWN_HALL_USES_PER_CASE)
				return
			var th: Dictionary = g.w.consult_town_hall()
			if th.is_empty():
				g._err("Nothing further can be gleaned from the Town Hall ledgers.")
				return
			var pair: Array = th["roles"]
			var rem: int = int(th["uses_left"])
			g._narr("Combing through the Town Hall's parish ledgers, you narrow the town's gifts: either the %s or the %s is in play here, not both. (%d consultation%s left this case.)" %
				[C.role_name(pair[0]), C.role_name(pair[1]), rem, "" if rem == 1 else "s"])
			g._facts([{
				"kind": "town_hall", "subject": [], "roles": pair.duplicate(), "source": "player",
				"day": g.w.day, "phase": g.w.phase, "class": "concrete",
				"text": "Town Hall records: either the %s or the %s is in town, not both." % [C.role_name(pair[0]), C.role_name(pair[1])],
			}])
			_end_phase(g, "")
		"wait", "rest", "pass":
			g._narr("You let the %s pass." % g.w.phase_name().to_lower())
			_end_phase(g, "")
		_:
			g._err("You can't do that now. Type 'help'.")


static func _warn_busy_visit(g, n) -> void:
	if n != null and n.busy_with != "":
		g._narr("%s is busy talking with %s; you can visit, but they cannot talk to you yet." % [n.name, g.w.by_id[n.busy_with].name])


static func _who_here(g, l: String) -> String:
	var here: Array = g.w.npcs_at(l)
	var parts: Array = []
	var done = {}
	for n in here:
		if done.has(n.id):
			continue
		if n.busy_with != "":
			var m = g.w.by_id[n.busy_with]
			done[m.id] = true
			parts.append("%s and %s (deep in conversation)" % [n.name, m.name])
		elif n.working:
			parts.append("%s the %s (working)" % [n.name, n.occupation])
		else:
			parts.append("%s the %s" % [n.name, n.occupation])
	return ", ".join(PackedStringArray(parts))


static func _observe(g) -> void:
	var l = g.loc
	g._narr("You spend the %s at %s (%s)." % [g.w.phase_name().to_lower(), g.w.loc_name(l), C.block_name(g.w.loc_block(l))])
	var here: Array = _present(g, l)
	if l.begins_with("home_"):
		if here.is_empty():
			g._narr("You knock, but nobody answers.")
		else:
			g._narr("You knock, and %s opens the door." % here[0].name)
			g._facts([{"kind": "sighting", "subject": [here[0].id], "block": g.w.loc_block(l), "loc": l, "day": g.w.day, "phase": g.w.phase,
				"source": "player", "text": "You found %s at home, day %d %s." % [here[0].name, g.w.day, g.w.phase_name()]}])
	elif l == "town_hall":
		g._narr("The clerks' desks stand quiet; the parish registers and gift rolls are kept here.")
	elif here.is_empty():
		g._narr("Nobody is here.")
	elif not l.begins_with("home_"):
		g._narr("Present: " + _who_here(g, l) + ".")
		# One card per person: being in the same place isn't being together (a conversation
		# you see gets its own card linking the two).
		for n in here:
			g._facts([{"kind": "sighting", "subject": [n.id], "block": g.w.loc_block(l),
				"loc": l, "day": g.w.day, "phase": g.w.phase, "source": "player",
				"text": "You saw %s at %s, day %d %s." % [n.name, g.w.loc_name(l), g.w.day, g.w.phase_name()]}])
	for other in g.w.locations_on(g.w.loc_block(l)):
		if other == l:
			continue
		var there: Array = g.w.npcs_at(other)
		if not there.is_empty():
			g._narr("Nearby, at %s: %s." % [g.w.loc_name(other), _who_here(g, other)])
			for x in there:
				g._facts([{"kind": "sighting", "subject": [x.id], "block": g.w.loc_block(other), "loc": other, "day": g.w.day,
					"phase": g.w.phase, "source": "player", "text": "You saw %s nearby at %s, day %d %s." %
					[x.name, g.w.loc_name(other), g.w.day, g.w.phase_name()]}])
	if not l.begins_with("home_"):
		_note_haunt_sightings(g, l)
	if g.w.scenes.has(l):
		g._narr("This is where %s was killed. ('search' to examine it.)" % g.w.by_id[g.w.scenes[l]["victim"]].name)
	var acts = "Actions: talk <name> | search%s | wait" % (" | gossip" if (l == "tavern" and g.w.phase == C.EVENING) else "")
	if l == "town_hall":
		var rec_opt: String = ("records (%d left) | " % g.w.town_hall_uses_left) if (g.w.phase in [C.MORNING, C.AFTERNOON] and g.w.town_hall_uses_left > 0) else ""
		acts = "Actions: %swait" % rec_opt
	elif l.begins_with("home_"):
		acts = "Actions: talk <name> | wait"
	if not g.free_move_used:
		acts += "   (or 'go <place>' once more within %s)" % C.block_name(g.w.loc_block(l))
	g._prompt(acts)


static func _apply_tavern_profile_gossip(g, r: Dictionary) -> void:
	for ph in r.get("haunts", []):
		var pid: String = str(ph.get("id", ""))
		var loc_id: String = str(ph.get("loc", ""))
		if pid == "" or not g.w.by_id.has(pid) or not C.LOCATIONS.has(loc_id):
			continue
		if not (loc_id in g.known_haunts.get(pid, [])):
			g.known_haunts[pid] = g.known_haunts.get(pid, []) + [loc_id]
		g.add_profile_receipt({
			"kind": "haunt", "subject": [pid], "source": "town", "loc": loc_id, "locs": [loc_id],
			"day": g.w.day, "phase": g._phase_now(), "class": "circumstantial",
			"text": "Word about town says %s often goes to %s when off work." % [g.w.by_id[pid].name, g.w.loc_name(loc_id)],
		})
		g.w.dlog.add("player_learns_haunts", "rumour", pid, {"locs": [loc_id], "via": "tavern_gossip"})
	for pb in r.get("bonds", []):
		var bkey: String = str(pb.get("key", ""))
		var bkind: String = str(pb.get("kind", ""))
		var people: Array = pb.get("people", []).duplicate()
		if bkey == "" or bkind not in ["friend", "rival"] or people.size() != 2 or not people.all(func(pid): return g.w.by_id.has(pid)):
			continue
		if g.known_relationships.has(bkey):
			continue
		var na: String = g.w.by_id[people[0]].name
		var nb: String = g.w.by_id[people[1]].name
		var note: String = "Word about town says %s and %s %s." % [na, nb, "are close" if bkind == "friend" else "don't get along"]
		g.known_relationships[bkey] = {"kind": bkind, "people": people.duplicate(), "source": "town", "text": note}
		var sorted_p: Array = people.duplicate()
		sorted_p.sort()
		g.add_profile_receipt({
			"kind": "bond", "subject": sorted_p, "bond_kind": bkind, "source": "town",
			"day": g.w.day, "phase": g._phase_now(), "class": "circumstantial", "text": note,
		})
		g.w.dlog.add("player_learns_relationship", "rumour", people[0], {"kind": bkind, "people": people, "via": "tavern_gossip"})


static func _search(g) -> void:
	var l = g.loc
	if g.w.scenes.has(l):
		var sc: Dictionary = g.w.scenes[l]
		if sc["searched"]:
			g._narr("You go over the scene again. Nothing new.")
			return
		sc["searched"] = true
		var scene_traces: Array = sc.get("traces", [])
		if scene_traces.is_empty():
			var tb: String = sc.get("trace_block", sc["block"])
			g._narr("Near the body you find %s. Whoever did this most likely spent the evening of day %d on %s." % [C.BLOCKS[tb]["trace"], sc["day"], C.block_name(tb)])
			g.w.dlog.add("player_search", "player", sc["victim"], {"trace_block": tb, "trace_true": sc.get("trace_true", true)}, sc.get("why", ""))
			g._facts([{"kind": "trace", "subject": [], "block": tb, "source": "evidence", "day": sc["day"], "phase": C.EVENING,
				"scene": l, "scene_block": sc.block, "victim": sc.victim, "crime_night": sc.day, "material": tb,
				"text": "Trace at %s's death scene: the killer most likely spent the evening of day %d on %s." %
					[g.w.by_id[sc["victim"]].name, sc["day"], C.block_name(tb)]}])
			return
		var new_cards: Array = []
		for tr in scene_traces:
			g._narr(tr.get("scene_prose", ""))
			new_cards.append({
				"kind": "trace",
				"subject": [],
				"block": sc["block"],
				"source": "evidence",
				"day": sc["day"],
				"phase": C.EVENING,
				"scene": l,
				"scene_block": sc["block"],
				"victim": sc["victim"],
				"victim_block": tr.get("victim_block", sc["block"]),
				"crime_night": sc["day"],
				"trace_family": tr.get("trace_family", ""),
				"trace_subtype": tr.get("trace_subtype", ""),
				"trace_slot": int(tr.get("trace_slot", 0)),
				"scene_trace_count": int(tr.get("scene_trace_count", scene_traces.size())),
				"trace_key": tr.get("trace_key", ""),
				"locs": tr.get("locs", []).duplicate(),
				"trace_home_block": tr.get("home_block", ""),
				"trace_evening_block": tr.get("evening_block", ""),
				"item_label": tr.get("item_label", ""),
				"text": tr.get("card_text", ""),
			})
		g.w.dlog.add("player_search", "player", sc["victim"], {"traces": scene_traces.map(func(t): return t.get("trace_key", "")), "trace_true": sc.get("trace_true", true)}, sc.get("why", ""))
		g._facts(new_cards)
		return
	if l.begins_with("home_"):
		g._narr("You can't search someone's home from their doorstep.")
		return
	var tt: Dictionary = g.w.find_totem(l)
	if not tt.is_empty():
		var mat: String = C.BLOCKS[tt["material"]]["trace"]
		g._narr("Wedged out of sight at %s you find a crude totem of bone and twine, caked with %s. It reeks of the grave. You burn it. The Revenant's spirit will seek a new hiding place." % [g.w.loc_name(l), mat])
		g._headline("totem", "A Revenant's totem is burned", "Its spirit will seek a new hiding place.")
		g._facts([{"kind": "totem", "subject": [], "block": tt["material"], "loc": l, "source": "evidence", "day": g.w.day, "phase": g.w.phase,
			"text": "A Revenant's totem, hidden at %s and found on day %d, caked with %s (from %s). The Revenant's spirit will seek a new hiding place." % [g.w.loc_name(l), g.w.day, mat, C.block_name(tt["material"])]}])
		if tt.get("freed", "") != "":
			g._narr("As it burns, you feel the curse on the town lift. Whoever it turned is themselves again.")
			g._facts([{"kind": "curse_lifted", "subject": [], "source": "player", "day": g.w.day, "phase": g.w.phase,
				"text": "Day %d: the totem burned and the Revenant's curse lifted. The turned soul is good again." % g.w.day}])
	var raw_items: Array = g.w.dropped.get(l, [])
	g.w.dropped.erase(l)
	var items: Array = raw_items.filter(func(it): return it.get("owner", "") != "" or Tuning.Setup.LEGACY_MUD_DROPS_ENABLED)
	var regular: bool = _search_regulars(g, l)
	if items.is_empty():
		if tt.is_empty():
			g.w.dlog.add("player_search", "player", "", {"loc": l}, "Nothing dropped here.")
		if tt.is_empty() and not regular:
			g._narr("You search %s carefully. Nothing out of place." % g.w.loc_name(l))
		return
	var blk: String = g.w.loc_block(l)
	for it in items:
		g.w.dlog.add("player_search", "player", it["who"], {"loc": l, "item": it}, "Found something %s dropped (%s)." % [it["who"], it["why"]])
		if it["owner"] != "":
			var o = g.w.by_id[it["owner"]]
			g._narr("Tucked against the wall of %s you find something of %s's, dropped there on night %d." % [g.w.loc_name(l), o.name, it["night"]])
			g._facts([{"kind": "sighting", "subject": [o.id], "block": blk, "loc": l, "day": it["night"], "phase": C.NIGHT, "source": "evidence", "dropped": true,
				"text": "%s's belongings found at %s: they were on %s on night %d." % [o.name, g.w.loc_name(l), C.block_name(blk), it["night"]]}])
		else:
			g._narr("At %s you find %s, left there on night %d. Someone who lives on %s passed this way in the dark." %
				[g.w.loc_name(l), C.BLOCKS[it["material"]]["trace"], it["night"], C.block_name(it["material"])])
			g._facts([{"kind": "dropped", "subject": [], "block": blk, "loc": l, "day": it["night"], "phase": C.NIGHT, "source": "evidence",
				"material": it["material"], "text": "%s found at %s, left on night %d: someone from %s was out that night." %
				[C.BLOCKS[it["material"]]["trace"].capitalize(), g.w.loc_name(l), it["night"], C.block_name(it["material"])]}])


## Searching a social spot also turns up one of its regulars (someone with it as a haunt),
## once per place per game. Whoever works there points them out; with nobody working there,
## you hear it around the place. Returns true if this search was the place's one ask.
static func _search_regulars(g, l: String) -> bool:
	if not C.LOCATIONS.has(l) or g.regulars_searched.has(l):
		return false
	g.regulars_searched[l] = true
	var regulars: Array = g.w.living().filter(func(n): return l in n.haunts)
	var unknown: Array = regulars.filter(func(n): return not (l in g.known_haunts.get(n.id, [])))
	var place: String = g.w.loc_name(l)
	if unknown.is_empty():
		g._narr("You ask after the regulars at %s, but there's nobody you didn't already know of." % place if not regulars.is_empty() else "You ask after the regulars at %s. Nobody makes a habit of it." % place)
		g.w.dlog.add("player_learns_haunts", "player", "", {"loc": l, "via": "search", "found": false})
		return true
	# Its own draw (seeded by the case and the place), so asking about regulars never shifts
	# the world's random rolls.
	var pick_rng := RandomNumberGenerator.new()
	pick_rng.seed = hash([g.w.seed_value, l, "regulars"])
	unknown.sort_custom(func(a, b): return a.id < b.id)
	var r = unknown[pick_rng.randi_range(0, unknown.size() - 1)]
	var workers: Array = g.w.living().filter(func(n): return n.work == l and n != r)
	var told: String
	if not workers.is_empty():
		var wk = workers[0]
		told = "%s, the %s, tells you %s is a regular at %s when not working." % [wk.name, str(wk.occupation), r.name, place]
	else:
		told = "Asking around %s, you learn %s is a regular here when not working." % [place, r.name]
	if unknown.size() > 1:
		told += " They're not the only one."
	g._narr(told)
	_learn_haunt(g, r, l, "player", "%s often goes to %s when off work (you asked after the regulars there, day %d)." % [r.name, place, g.w.day], "search")
	return true


## Seeing someone idle at one of their haunts, from the same block, on enough different days
## (HAUNT_SIGHTING_DAYS; more for the tavern) teaches you it's a haunt of theirs.
static func _note_haunt_sightings(g, l: String) -> void:
	for x in g.w.living():
		if x.working or not (x.loc in x.haunts) or g.w.loc_block(x.loc) != g.w.loc_block(l):
			continue
		if x.loc in g.known_haunts.get(x.id, []):
			continue
		var key: String = "%s:%s" % [x.id, x.loc]
		var days: Array = g.haunt_sightings.get(key, [])
		if g.w.day in days:
			continue
		days.append(g.w.day)
		g.haunt_sightings[key] = days
		var need: int = Tuning.Setup.HAUNT_SIGHTING_DAYS_TAVERN if x.loc == "tavern" else Tuning.Setup.HAUNT_SIGHTING_DAYS
		if days.size() >= need:
			var place: String = g.w.loc_name(x.loc)
			g._narr("That's %d days you've seen %s at %s with time on their hands: it must be one of their haunts." % [days.size(), x.name, place])
			_learn_haunt(g, x, x.loc, "player", "%s often goes to %s when off work (you've seen them there on %d days)." % [x.name, place, days.size()], "sightings")


static func _learn_haunt(g, n, l: String, source: String, text: String, via: String) -> void:
	if not (l in g.known_haunts.get(n.id, [])):
		g.known_haunts[n.id] = g.known_haunts.get(n.id, []) + [l]
	g.add_profile_receipt({"kind": "haunt", "subject": [n.id], "source": source, "loc": l, "locs": [l],
		"block": g.w.loc_block(l), "day": g.w.day, "phase": g._phase_now(), "class": "circumstantial", "text": text})
	g.w.dlog.add("player_learns_haunts", "player", n.id, {"locs": [l], "via": via})


static func _end_phase(g, talked_id: String) -> void:
	g.moved = false
	g.free_move_used = false
	g.loc = ""
	g.w.player_loc = ""
	g.approached_id = ""
	g.approached_loc = ""
	if g.w.end_day_phase(talked_id):
		g._phase_header()
		g._maybe_approach()
	else:
		g._start_meeting()


## Match the night-planning map: living townsfolk are shown at their homes.
## Night excursions have not resolved yet; this reveals no hidden walking result.
static func _night_homes(g) -> String:
	var blocks: Array = []
	for block in C.BLOCKS:
		var names: Array = g.w.living().filter(func(n): return n.home_block == block).map(func(n): return n.name)
		blocks.append("%s: %s" % [C.block_name(block), ", ".join(PackedStringArray(names)) if not names.is_empty() else "nobody"])
	return "At home tonight — " + "; ".join(PackedStringArray(blocks)) + "."


static func _night_command(g, verb: String, rest: String) -> void:
	match verb:
		"ward", "protect":
			if g.w.tools["ward"] <= 0:
				g._err("You've already used your Ward.")
				return
			var n = g.find_npc(rest)
			if n == null:
				g._err("Ward whom?")
				return
			g.w.tools["ward"] -= 1
			g.w.player_ward = n.id
			g.ward_log[g.w.day] = n.id
			g.w.player_vigil = ""
			g._narr("You chalk a warding sigil on %s's door." % n.name)
			g._facts([{"kind": "ward", "source": "player", "subject": [n.id], "target": n.id, "loc": "home_" + n.id, "block": n.home_block, "night": g.w.day, "day": g.w.day, "phase": C.NIGHT, "private": true,
				"text": "Night %d: you spent your ward on %s's door on %s." % [g.w.day, n.name, C.block_name(n.home_block)]}])
			_resolve_night(g)
		"vigil", "watch":
			var b = g.find_block(rest)
			if b == "":
				g._err("Watch which block? (square, market, docks, hill)")
				return
			g.w.player_vigil = b
			g._narr("You keep a cold vigil on %s." % C.block_name(b))
			_resolve_night(g)
		"sleep", "wait", "pass":
			g.w.player_vigil = ""
			g._narr("You sleep uneasily.")
			_resolve_night(g)
		_:
			g._err("At night: %svigil <block> | sleep" % ("ward <name> | " if g.w.tools["ward"] > 0 else ""))


static func _resolve_night(g) -> void:
	g.capture_prediction("before_night")
	# Each NPC's hunches at day's end: tomorrow's Confidence resists moves against them.
	for n in g.w.npcs:
		for mind in [n, n.shadow]:
			# Every mind is shared now (purge 3): commit even for one that hasn't refreshed
			# yet, as before, when the retired enabled key kept its state non-empty.
			if mind != null:
				mind.workshop_state["committed_lean"] = Mind.suspicion_view(mind).duplicate(true)
				mind.workshop_state["committed_requested"] = mind.workshop_state.get("requested", {}).duplicate(true)
	g._settle_offers()
	var vig: String = g.w.player_vigil
	g.w.resolve_night()
	for e in g.w.public_log:
		if e["kind"] == "knell" and e["day"] == g.w.day:
			g._narr("At dusk the death knell tolls from the chapel. Doors are barred; nobody walks abroad tonight, or should.")
			g._facts([{"kind": "knell", "subject": [], "source": "player", "day": g.w.day, "phase": C.EVENING,
				"text": "Night %d: the Sexton tolled the death knell (no gift that walks abroad should work)." % g.w.day}])
	if vig != "":
		if g.w.player_vigil_seen.is_empty():
			g._narr("Nobody comes to %s all night." % C.block_name(vig))
			g._facts([{"kind": "vigil", "subject": [], "block": vig, "source": "player", "day": g.w.day, "phase": C.NIGHT,
				"text": "Night %d vigil on %s: nobody came to %s." % [g.w.day, C.block_name(vig), C.block_name(vig)]}])
		else:
			var names: Array = g.w.player_vigil_seen.map(func(i): return g.w.by_id[i].name)
			g._narr("During your vigil you see %s out on %s." % [", ".join(PackedStringArray(names)), C.block_name(vig)])
			g._facts([{"kind": "sighting", "subject": g.w.player_vigil_seen.duplicate(), "block": vig, "source": "player",
				"day": g.w.day, "phase": C.NIGHT, "vigil": true, "text": "Night %d vigil: you saw %s on %s." % [g.w.day, ", ".join(PackedStringArray(names)), C.block_name(vig)]}])
	g.w.player_vigil = ""
	if g.w.game_over:
		return
	g.w.start_new_day()
	if g.w.game_over:
		return
	g.state = "day"
	g.moved = false
	Credibility.dawn(g)
	_morning_report(g)
	g._maybe_approach()


## Developer report: what the legacy rules judged because the shared model couldn't.
static func _fallbacks_text(g) -> String:
	if g.shared_fallbacks.is_empty():
		return "No legacy fallbacks this game: everything was judged by the shared model."
	var by_point = {}
	for f in g.shared_fallbacks:
		by_point[f.point] = by_point.get(f.point, 0) + 1
	var out = PackedStringArray(["%d legacy fallbacks this game:" % g.shared_fallbacks.size()])
	for point in by_point:
		out.append("  %s: %d" % [point, by_point[point]])
	out.append("Most recent:")
	for f in g.shared_fallbacks.slice(maxi(0, g.shared_fallbacks.size() - 10)):
		out.append("  day %d %s, %s (%s): %s" % [f.day, f.phase, f.listener, f.point, "; ".join(PackedStringArray(f.issues))])
	return "\n".join(out)


static func _morning_report(g) -> void:
	g._hdr("Day %d, Morning" % g.w.day)
	if g.shared_fallbacks.size() > g._fallbacks_reported:
		g._narr("[dev] The legacy rules judged %d thing(s) the shared model couldn't read since the last report. Type 'fallbacks' for details." % (g.shared_fallbacks.size() - g._fallbacks_reported))
		g._fallbacks_reported = g.shared_fallbacks.size()
	if g.w.day > 1 or not g.w.deaths_last_night.is_empty():
		if g.w.deaths_last_night.is_empty():
			g._narr("Dawn breaks. Nobody died in the night.")
			g._headline("quiet", "No one died in the night")
			var nq = g.w.day - 1
			if nq >= 1:
				var wd: String = g.ward_log.get(nq, "")
				g._facts([{"kind": "quiet", "subject": [], "night": nq, "day": nq, "phase": C.NIGHT, "source": "player", "ward": wd,
					"text": "Nobody died on night %d%s." % [nq, (" (you had warded %s)" % g.w.by_id[wd].name) if wd != "" else ""]}])
		for id in g.w.deaths_last_night:
			var v = g.w.by_id[id]
			var death_title: String = v.name
			if v.claimed_role in C.ROLES and (v.claim_public or v.max_tier >= 3):
				death_title = "%s, who %s the %s, died in the night" % [v.name, "claimed to be" if v.claim_public else "told you they were", C.role_name(v.claimed_role)]
			g._headline("death", death_title, "A Demon hides among %d remaining townsfolk" % g.w.living().size())
			g._narr("Dawn breaks over a body: %s the %s was killed in the night. Their cottage on %s is now a crime scene." %
				[v.name, v.occupation, C.block_name(v.home_block)])
			g._facts([{"kind": "death", "subject": [id], "block": v.home_block, "source": "player", "night": g.w.day - 1,
				"text": "%s was killed by the demon on night %d (home on %s)." % [v.name, g.w.day - 1, C.block_name(v.home_block)]}])
	for save in g.w.ward_saves:
		if save.night == g.w.day - 1:
			var held = "Your ward held at %s's door last night." % g.w.by_id[save.target].name
			g._narr(held)
			g._headline("ward", held)
			var saved = g.w.by_id[save.target]
			g._facts([{"kind": "scorched_sigil", "source": "evidence", "subject": [saved.id], "target": saved.id, "loc": "home_" + saved.id, "block": saved.home_block, "night": save.night, "day": save.night, "phase": C.NIGHT, "private": true,
				"text": "You alone found a scorched sigil on %s's door on %s: the Demon came to that door on night %d and your ward held." % [saved.name, C.block_name(saved.home_block), save.night]}])
	g._screen(g._map())
	g._card_workers()
	g._card_conversations()
	g._prompt("%d townsfolk remain. Where will you spend the morning? ('go <place | block | person>', 'help')" % g.w.living().size())
