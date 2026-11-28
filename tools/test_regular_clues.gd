## Searching a place for its regulars (Michael, Nov 28, item 7): the search finds a thing of
## the regular's left behind, not a worker's word (the worker needn't even be there), and it
## comes up as its own page over the place, like the other searches.
##   godot --headless --path . --script res://tools/test_regular_clues.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Clues = preload("res://game/regular_clues.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _frames(n: int = 4) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	# Every character has a clue or two, each naming them or theirs.
	var missing: Array = C.CAST.filter(func(ch): return Clues.CLUES.get(ch.id, []).is_empty()).map(func(ch): return ch.id)
	check(missing.is_empty(), "every character has a clue (%s missing)" % ", ".join(PackedStringArray(missing)))
	check(Clues.CLUES.values().all(func(list): return list.size() >= 1 and list.size() <= 2), "one or two each")

	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	scene.pacing_enabled = false
	root.add_child(scene)
	await _frames()
	var g = scene.g
	if g.state == "approach":
		scene._run("decline")
	# A social spot with a regular the player doesn't know of yet.
	var spot: String = ""
	for l in C.LOCATIONS:
		if g.w.living().any(func(n): return l in n.haunts) and not C.is_player_building(l):
			spot = l
			break
	check(spot != "", "found a place with a regular (%s)" % spot)
	if spot == "":
		quit(1)
		return
	scene._run("go " + spot)
	await _frames()
	var before: Dictionary = g.known_haunts.duplicate(true)
	scene._run("search")
	await _frames()
	var found: Dictionary = g.last_search_clue
	check(not found.is_empty() and str(found.get("loc", "")) == spot, "the search found something of a regular's (%s)" % str(found))
	var who = g.w.by_id.get(str(found.get("who", "")))
	check(who != null and spot in who.haunts and spot in g.known_haunts.get(who.id, []) and not (spot in before.get(who.id, [])), "it teaches you whose haunt it is")
	check(who != null and str(found.clue) in Clues.CLUES.get(who.id, []), "with one of their own clues (%s)" % str(found.get("clue", "")))
	var said: String = str(found.get("text", ""))
	check(who != null and said == "You found %s's %s at %s: a sign they come here when off work." % [who.name, found.clue, g.w.loc_name(spot)] and not "tells you" in said, "the narration is a find, in Michael's words (%s)" % said)
	var receipts: Array = g.profile_receipts.filter(func(c): return c.get("kind", "") == "haunt" and who != null and who.id in c.get("subject", []))
	check(receipts.any(func(c): return str(c.get("text", "")) == said and not ("day %d" % g.w.day) in str(c.get("text", ""))), "the card says what you found, with no day")
	check(not scene.inspect_pages.is_empty() and str(scene.inspect_pages[0].get("text", "")) == said and str(scene.inspect_pages[0].get("loc", "")) == spot, "it comes up as a page over the place")
	check(scene.inspect_pages.size() > 0 and scene.inspect_pages[0].get("texture") == null, "with no picture of the thing yet")
	check(scene.action_title.text == "Searching the place", "and the panel says you're searching, even at the tavern (%s)" % scene.action_title.text)
	scene.queue_free()
	print("Regular clues: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
