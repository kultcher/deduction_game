## Playtests 78148/77388 and PR #25 follow-ups.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
const Columns = preload("res://ui/column_menus.gd")
const UITheme = preload("res://ui/theme.gd")
var checks = 0
var fails = 0
func _init():
	call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)
func fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://followup_tests"
	g.new_case(4242, 10)
	return g
func settle():
	for i in range(5): await process_frame
func run():
	await menus()
	checkbox_skin()
	await headlines()
	ward_promise()
	approach_fatigue()
	martyr_wording()
	spoken_relationships()
	print("Playtest follow-ups: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
func picker(title: String, count: int):
	var box = VBoxContainer.new()
	var label = Label.new()
	label.text = title
	box.add_child(label)
	for i in range(count):
		var button = Button.new()
		button.text = "Long option %d with a complete name" % i
		box.add_child(button)
	return box
func labels(node: Node) -> Array:
	var out: Array = []
	if node is Label: out.append(node.text)
	for child in node.get_children(): out.append_array(labels(child))
	return out
func menus():
	var host = Control.new()
	host.theme = UITheme.make(UITheme.serif())
	root.add_child(host)
	var popup = PopupPanel.new()
	host.add_child(popup)
	for extent in [Vector2i(1280, 720), Vector2i(640, 480)]:
		root.size = extent
		root.content_scale_size = extent
		await settle()
		for child in popup.get_children():
			popup.remove_child(child)
			child.queue_free()
		var original = picker("Heard of a…", 19)
		var balanced = Columns.balance(original)
		original.free()
		Columns.fit_picker(popup, balanced, extent - Vector2i(25, 30))
		await settle()
		check(labels(balanced) == ["Heard of a…"], "one heading spans all columns")
		check(Rect2i(Vector2i.ZERO, extent).encloses(Rect2i(popup.position, popup.size)), "popup remains inside owner after opening and shrinking")
		var scroll: ScrollContainer = popup.get_child(0)
		var buttons = balanced.find_children("*", "Button", true, false)
		check(buttons.size() == 19, "every long option survives layout")
		var last: Button = buttons.back()
		last.grab_focus()
		await settle()
		check(scroll.get_global_rect().grow(1).encloses(last.get_global_rect()), "keyboard focus scrolls the last option fully into view")
		popup.hide()
	root.gui_embed_subwindows = true
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1600, 1200)
	root.content_scale_size = Vector2i(800, 600)
	await settle()
	for child in popup.get_children():
		popup.remove_child(child)
		child.queue_free()
	var scaled_original = picker("Scaled viewport", 19)
	var scaled = Columns.balance(scaled_original)
	scaled_original.free()
	Columns.fit_picker(popup, scaled, Vector2i(770, 570))
	await settle()
	var logical = Rect2i(Vector2i.ZERO, Vector2i(root.get_visible_rect().size))
	check(logical.encloses(Rect2i(popup.position, popup.size)), "embedded picker bounds use the logical viewport when the physical window is larger")
	popup.hide()
	root.size = Vector2i(640, 480)
	root.content_scale_size = root.size
	await settle()
	var menu = PopupMenu.new()
	host.add_child(menu)
	menu.add_separator("One category")
	for i in range(19): menu.add_item("Option %d" % i)
	Columns.show_columns(menu)
	await settle()
	var native: PopupPanel = menu.get_meta("column_popup")
	check(labels(native).count("One category") == 1, "native menu section title is also displayed once")
	native.hide()
	await settle()
	host.free()

func checkbox_skin():
	var theme = UITheme.make()
	check(theme.get_stylebox("normal", "CheckBox") is StyleBoxEmpty and theme.get_stylebox("disabled", "CheckBox") is StyleBoxEmpty, "disabled Hide Unselected uses the same checkbox layout, not inherited plaque padding")
	check(theme.get_color("font_disabled_color", "CheckBox") == UITheme.color("muted"), "disabled checkbox text stays legible on the board")

func headlines():
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var overlay = preload("res://ui/headline_overlay.gd").new()
	root.add_child(overlay)
	overlay.set_process(false)
	overlay.load_styles("user://no-such-headline-settings.cfg")
	check(overlay.styles.dawn.duration == 5.0 and overlay.styles.phase.duration == 3.0 and overlay.styles.ending.duration == 7.0, "headline defaults use approved longer durations")
	for extent in [Vector2i(1280, 720), Vector2i(640, 480)]:
		root.size = extent
		root.content_scale_size = extent
		overlay.clear()
		overlay.enqueue({"kind": "death", "text": "A longer headline that wraps when the screen becomes narrow", "subtitle": "A second line"})
		await settle()
		var combined = overlay.title.get_global_rect().merge(overlay.subtitle.get_global_rect())
		check(combined.get_center().distance_to(Vector2(extent) / 2.0) <= 1.0, "wrapped title and subtitle are centered together in both dimensions")
	overlay.clear()
	for i in range(5): overlay.enqueue({"kind": "dawn", "text": str(i)})
	overlay._process(2.9)
	check(overlay.current.text == "0", "a crowded queue gives each ordinary notice at least three seconds")
	overlay._process(0.11)
	check(overlay.current.text == "1", "crowded notices still advance faster than five seconds")
	overlay.clear()
	overlay.enqueue({"kind": "phase", "text": "Afternoon"})
	await settle()
	check(not overlay.subtitle.visible and absf(overlay.title.get_global_rect().get_center().y - root.size.y / 2.0) <= 1.0, "a headline without a subtitle centers its visible text")
	overlay.free()

func ward_promise():
	var g = fresh()
	var w = g.w
	var n = w.living_good()[0]
	var neighbour = w.living_good()[1]
	n.home_block = "square"
	neighbour.home_block = "square"
	w.player_vigil = "market"
	w.day = 2
	for person in [n, neighbour]: person.trust = 0.5
	g.offer = {"vigil": {n.id: "square", neighbour.id: "square"}}
	g.protect_pending[n.id] = true
	g.ward_log[w.day] = n.id
	var rng = w.rng.state
	g._settle_offers()
	check(is_equal_approx(n.trust, 0.56) and n.fear_eased and n.id in g.divulge_due, "a ward on the promised person's door keeps their vigil promise and promised disclosure")
	check(is_equal_approx(neighbour.trust, 0.35) and not neighbour.fear_eased, "a ward does not fulfil another resident's vigil promise")
	check(g.offer.is_empty() and g.protect_pending.is_empty() and w.rng.state == rng, "settlement clears obligations without RNG draws")
	g._settle_offers()
	check(is_equal_approx(n.trust, 0.56), "settlement rewards only once")
	n.trust = 0.5
	g.offer = {"ward": n.id, "vigil": {n.id: "square"}}
	g._settle_offers()
	check(is_equal_approx(n.trust, 0.56), "a ward satisfying both offers to one NPC does not pay twice")
	n.trust = 0.5
	g.offer = {"vigil": {n.id: "square"}}
	g.ward_log = {w.day - 1: n.id}
	g._settle_offers()
	check(is_equal_approx(n.trust, 0.35), "yesterday's ward does not keep tonight's promise")
	n.trust = 0.5
	w.player_vigil = "square"
	g.offer = {"vigil": {n.id: "square"}}
	g._settle_offers()
	check(is_equal_approx(n.trust, 0.56), "ordinary promised vigils retain their reward")

func approach_fixture(g, evil: bool):
	var n = g.w.minion() if evil else g.w.living_good()[0]
	g.w.day = 3
	n.loc = n.work
	n.busy_with = ""
	n.silenced = false
	n.trust = 0.5
	n.claim_public = false
	n.claimed_role = ""
	n.max_tier = 0
	n.info_log = []
	n.role_guesses = 2
	if evil: g.w.evil_plan.bluffs[n.id] = "clerk"
	else: n.role = "clerk"
	g.state = "approach"
	return n
func approach_fatigue():
	for agenda in ["news", "gossip", "frame", "protect"]:
		var a = fresh()
		var b = fresh()
		var n = approach_fixture(a, agenda == "frame")
		var control = approach_fixture(b, agenda == "frame")
		n.pressed_today = 8
		control.pressed_today = 0
		a.approach = {"npc": n, "agenda": agenda, "what": "ward"}
		b.approach = {"npc": control, "agenda": agenda, "what": "ward"}
		var rng = a.w.rng.state
		a._approach_command("accept", "")
		b._approach_command("accept", "")
		check(n.pressed_today == 0 and n.trust == control.trust, "accepted %s approach starts with no accumulated question fatigue" % agenda)
		check(a.w.rng.state == b.w.rng.state and n.role_guesses == 2, "approach reset changes neither existing rolls nor wrong guesses")
		var before = n.trust
		for i in range(3): Mind.on_question(a.w, n)
		check(n.trust == before, "three follow-up questions are free of old fatigue")
		Mind.on_question(a.w, n)
		check(n.trust < before, "new fatigue still applies after the fresh allowance")
	var g = fresh()
	var n = approach_fixture(g, false)
	n.pressed_today = 8
	g.approach = {"npc": n, "agenda": "news"}
	g._approach_command("decline", "")
	check(n.pressed_today == 8, "declining a news approach does not reset fatigue")
	g.state = "approach"
	g.approach = {"npc": n, "agenda": "protect", "what": "ward"}
	g._approach_command("decline", "")
	check(n.pressed_today == 8, "declining a protection request does not reset fatigue")
	g.state = "day"
	g.divulge_due = [n.id]
	var before = n.trust
	var divulged = g._maybe_divulge()
	check(divulged and n.pressed_today == 0, "promised free disclosure itself resets fatigue before its opening answer (delivered %s, fatigue %d)" % [divulged, n.pressed_today])
	check(n.trust >= before, "promised disclosure adds no old question-fatigue trust penalty")
	g._approach_command("accept", "")
	check(g.questions_left == 3 and n.pressed_today == 0, "continuing a promised disclosure has a fresh question allowance")

func martyr_wording():
	var g = fresh()
	var w = g.w
	var martyr = w.living_good()[0]
	var target = w.minion()
	for n in w.npcs:
		if not n.is_evil(): n.role = "clerk"
		n.secret_mod = ""
		if n != martyr: n.martyr_target = ""
	martyr.role = "martyr"
	martyr.poisoned = false
	martyr.martyr_target = target.id
	martyr.info_log = []
	w.day = 2
	var rng = w.rng.state
	w.execute(target.id, {"by": "player", "yes": []})
	check(martyr.alive and not target.alive and martyr.info_log.size() == 1, "the original non-substitution outcome and report generation remain intact")
	var report: Dictionary = martyr.info_log[0]
	check(report.text == "As the Martyr, I chose %s. They were hanged and I still stand: they must have been evil or my gift failed" % target.name, "the Martyr explicitly identifies their choice and qualifies their interpretation")
	check(report.data == {"target": target.id, "evil": true} and report["true"] and w.rng.state == rng, "wording changes no report truth, effects or RNG")

func spoken_relationships():
	var g = fresh()
	var w = g.w
	var n = w.living_good()[0]
	var t = w.living_good()[1]
	g.known_relationships = {}
	n.npc_trust[t.id] = 0.9
	n.suspicion[t.id] = 0.0
	var reply = Mind.answer_opinion(w, n, t)
	var rng = w.rng.state
	var cards = JSON.stringify(g.board)
	g._lines(reply.lines)
	check(g.known_relationships.size() == 1 and g.known_relationship_notes(n.id) == g.known_relationship_notes(t.id), "explicit closeness in an opinion populates both profiles")
	var note: Dictionary = g.known_relationships.values()[0]
	check(note.kind == "friend" and note.source == n.id and str(note.text).contains(n.name), "spoken friendship remains an attributed claim")
	g._lines(reply.lines)
	check(g.known_relationships.size() == 1 and w.rng.state == rng and JSON.stringify(g.board) == cards, "repeated disclosure neither duplicates notes nor adds cards, beliefs or RNG")
	g.known_relationships = {}
	t.alive = false
	var line = Mind.say(n, "%s is my friend. You'll need more than that." % t.name)
	line["relationship"] = {"kind": "friend", "people": [n.id, t.id]}
	g._line(line)
	check(not g.known_relationship_notes(t.id).is_empty(), "an explicit bond to a dead NPC can still be learned")
	g.known_relationships = {}
	g._line(Mind.say(n, "I have my doubts about %s." % t.name))
	check(g.known_relationships.is_empty(), "distrust is not silently promoted to a rival relationship")
	for kind in ["friend", "rival"]:
		g.known_relationships = {"existing": {"kind": kind, "people": [t.id, n.id], "source": n.id, "text": "Earlier attributed disclosure"}}
		line.relationship = {"kind": kind, "people": [n.id, t.id]}
		g._line(line)
		check(g.known_relationships.size() == 1 and g.known_relationships.existing.text == "Earlier attributed disclosure", "existing attributed bonds deduplicate independently of pair order")
