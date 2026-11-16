## Triage 2.8/8.3 (Nov 16): an NPC approach in the VN. An interstitial with no portrait
## covers the phase change ("You part ways with ... As you cross past ..., X waves you
## down."), holds on Continue, then the approacher speaks with your choices beneath.
extends SceneTree

const GameConversation = preload("res://game/game_conversation.gd")

var checks: int = 0
var fails: int = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	scene.show_script_at_start = false
	scene.seed_box.value = 25923
	scene._new_case()
	scene.roles_win.hide()
	await process_frame
	var g = scene.g
	var people: Array = g.w.living_good()
	var prev = people[0]
	var n = people[1]
	n.loc = "mill"
	# The wording, by phase.
	g.w.phase = 0
	var morning: String = GameConversation.approach_intro(g, n, prev.id, "As you cross past the mill, %s waves you down." % n.name)
	_check(morning == "As you cross past the mill, %s waves you down." % n.name, "in the morning there's no parting (%s)" % morning)
	g.w.phase = 1
	var after: String = GameConversation.approach_intro(g, n, prev.id, "As you cross past the mill, %s waves you down." % n.name)
	_check(after.begins_with("You part ways with %s as the afternoon sun reaches its zenith. As you cross past the mill" % prev.name), "after a conversation it opens with parting (%s)" % after)
	var alone: String = GameConversation.approach_intro(g, n, "", "As you cross past the mill, %s waves you down." % n.name)
	_check(alone.begins_with("The afternoon sun reaches its zenith. As you cross"), "with nobody to part from, the time of day (%s)" % alone)
	# The VN: interstitial, Continue, then the approacher and the choices.
	g.state = "approach"
	g.approach = {"npc": n, "agenda": "gossip", "intro": after,
		"events": [{"k": "speech", "speaker": n.id, "name": n.name, "text": "Demonologist, a word?"}]}
	g.approached_id = n.id
	g.approached_loc = n.loc
	scene._refresh_all()
	await process_frame
	var view = scene.conversation_view
	_check(scene.approach_stage == "intro" and view.visible, "a new approach opens on the interstitial")
	_check(view.person_id == "" and view.portrait.texture == null and view.lines == [after], "with no portrait, just the passage")
	var buttons: Array = view.controls.get_children().filter(func(c): return c is Button)
	_check(buttons.size() == 1 and buttons[0].text == "Continue", "and holds on Continue (%s)" % str(buttons.map(func(b): return b.text)))
	scene._approach_continue()
	await process_frame
	buttons = view.controls.get_children().filter(func(c): return c is Button)
	_check(scene.approach_stage == "speaking" and view.person_id == n.id and view.portrait.texture != null, "Continue brings the approacher on")
	_check(view.lines == ["Demonologist, a word?"], "speaking their approach (%s)" % str(view.lines))
	_check(buttons.map(func(b): return b.text).has("Hear them out (uses this phase)") and buttons.map(func(b): return b.text).has("Wave them off"), "with the choices beneath (%s)" % str(buttons.map(func(b): return b.text)))
	scene._refresh_all()
	_check(scene.approach_stage == "speaking", "a refresh doesn't restart it")
	scene._run("decline")
	await process_frame
	_check(g.state == "day" and scene.approach_stage == "" and not view.visible, "declining closes the VN")
	# A new case opening on the same approach starts at its interstitial again (Codex, #162).
	g.state = "approach"
	g.approach = {"npc": n, "agenda": "gossip", "intro": after, "events": []}
	scene._refresh_all()
	scene._approach_continue()
	scene._new_case()
	await process_frame
	var g2 = scene.g
	var n2 = g2.w.by_id[n.id]
	g2.w.phase = g.w.phase
	g2.w.day = g.w.day
	g2.state = "approach"
	g2.approach = {"npc": n2, "agenda": "gossip", "intro": "A new case.", "events": []}
	scene._refresh_all()
	_check(scene.approach_stage == "intro" and view.lines == ["A new case."], "a new case's approach starts at its own interstitial (%s)" % scene.approach_stage)
	print("Approach VN: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
