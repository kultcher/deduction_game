## UI controls and help: menus and pickers, headlines, help text, the map and visits, grimoire and Roles windows.
## Merged from: test_backlog_batch3, test_backlog_batch4, test_fixes, test_playtest_followups, test_playtest_regressions.
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const Overlay = preload("res://ui/headline_overlay.gd")
const Mind = preload("res://sim/mind.gd")
const CaseMetrics = preload("res://game/case_metrics.gd")
const Columns = preload("res://ui/column_menus.gd")
const UITheme = preload("res://ui/theme.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await _run_backlog_batch3()
	await _run_backlog_batch4()
	_run_fixes()
	await _run_playtest_followups()
	_run_playtest_regressions()
	print("UI: controls and help: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## One shared check helper (the merged suites used both names).
func check(ok: bool, label: String) -> void:
	_count(ok, label)


func _check(ok: bool, label: String) -> void:
	_count(ok, label)


func _count(ok: bool, label: String) -> void:
	checks += 1
	_checks += 1
	if not ok:
		fails += 1
		failures += 1
		_fails += 1
		printerr("FAIL: " + label)


# ---------------------------------------------------------------- from test_backlog_batch3

func _run_backlog_batch3() -> void:
	await headlines()
	await setup_counts()
	await hide_rows()
	await column_menus()


# ---------------------------------------------------------------- from test_backlog_batch4

func _run_backlog_batch4() -> void:
	vote_help()
	await demon_night_wording()
	approach_arrival()
	await inspect_then_talk()
	busy_visit_warning()
	new_actions_help()
	night_home_listing()
	grimoire_modifiers()
	await presentation_options()


# ---------------------------------------------------------------- from test_fixes

func _run_fixes() -> void:
	_summary()


# ---------------------------------------------------------------- from test_playtest_followups

func _run_playtest_followups() -> void:
	await menus()
	checkbox_skin()
	await playtest_followups__headlines()


# ---------------------------------------------------------------- from test_playtest_regressions

func _run_playtest_regressions() -> void:
	_approach_ui_visibility()


# ---- test_backlog_batch3


func fresh(count: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch3_tests"
	g.new_case(4242, count)
	return g


func headlines():
	var g = fresh()
	var rng = g.w.rng.state
	g._headline("dawn", "Day 1 Dawns")
	check(g.w.rng.state == rng, "headline emission does not advance RNG")
	var events = [{"k": "narration", "text": "Original line."}, {"k": "card", "n": 1}, {"k": "headline", "text": "Notice"}, {"k": "card", "n": 2}]
	check(Game.render(events) == "Original line.  [case board: #1, #2]", "headline side-channel preserves exact text/card-tag rendering")
	var victim = g.w.npcs[0]
	victim.alive = false
	g.w.deaths_last_night = [victim.id]
	g.w.day = 2
	for public_claim in [false, true]:
		victim.claimed_role = "seer"
		victim.max_tier = 3
		victim.claim_public = public_claim
		g.events = []
		g._morning_report()
		var notices = g.events.filter(func(e): return e.k == "headline" and e.kind == "death")
		check(notices.size() == 1 and ("claimed to be" if public_claim else "told you they were") in notices[0].text and "Seer" in notices[0].text, "death notice uses only the player's public/private claim knowledge")
		check(notices[0].subtitle == "A Demon hides among 9 remaining townsfolk", "death subtitle reports living count")
	victim.max_tier = 0
	victim.claim_public = false
	g.events = []
	g._morning_report()
	check(g.events.any(func(e): return e.k == "headline" and e.kind == "death" and e.text == victim.name), "unknown gift death reveals only the name")
	root.size = Vector2i(1200, 800)
	root.content_scale_size = root.size
	var button = Button.new()
	button.position = Vector2(10, 10)
	button.size = Vector2(100, 50)
	button.text = "Target"
	root.add_child(button)
	var clicks = [0]
	button.pressed.connect(func(): clicks[0] += 1)
	var overlay = Overlay.new()
	root.add_child(overlay)
	overlay.set_process(false)
	for i in range(5): overlay.enqueue({"kind": "dawn", "text": str(i)})
	check(overlay.current.text == "0" and overlay.pending.size() == 4, "notices play one at a time in order")
	var left = overlay.remaining
	overlay._process(0.25)
	check(is_equal_approx(left - overlay.remaining, 0.25 * minf(2.0, overlay.styles.dawn.duration / 3.0)), "more than two waiting notices shorten display time")
	var motion = InputEventMouseMotion.new()
	motion.position = Vector2(30, 30)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	for i in range(3): await process_frame
	var click = InputEventMouseButton.new()
	click.position = motion.position
	click.global_position = motion.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click.pressed = false
	Input.parse_input_event(click)
	await process_frame
	check(clicks[0] == 1 and overlay.current.text == "1", "a click skips a notice and still activates its ordinary target")
	check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.title.mouse_filter == Control.MOUSE_FILTER_IGNORE, "overlay and text cannot intercept input")
	var cfg = ConfigFile.new()
	cfg.set_value("headline.dawn", "size", 51)
	cfg.set_value("headline.dawn", "duration", 1.7)
	cfg.set_value("headline.dawn", "colour", "#123456")
	var path = "user://headline-test.cfg"  # res://logs/ may not exist on a fresh checkout
	cfg.save(path)
	overlay.load_styles(path)
	check(overlay.styles.dawn.size == 51 and overlay.styles.dawn.duration == 1.7 and overlay.styles.dawn.colour == Color("123456"), "settings override each style field from the shared defaults table")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	overlay.clear()
	check(overlay.current.is_empty() and overlay.pending.is_empty() and not overlay.visible, "case reset clears every notice")
	overlay.free()
	button.free()


func setup_counts():
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var main = load("res://ui/main.tscn").instantiate()
	main.show_script_at_start = false
	root.add_child(main)
	var expected = {7: "Good: 5 gifted townsfolk / 1 secret · Evil: 1 minion / 1 demon", 10: "Good: 7 gifted townsfolk / 1 secret · Evil: 2 minions / 1 demon"}
	for count in [7, 10]:
		main.g = fresh(count)
		var board = JSON.stringify(main.g.board)
		var rng = main.g.w.rng.state
		# Even an inconsistent hidden assignment cannot influence the public count.
		main.g.w.minion_ids = []
		for n in main.g.w.npcs:
			n.secret_mod = "lovers"
		main._open_roles()
		await process_frame
		var summary = main.roles_box.get_node("SetupSummary")
		check(summary.text == expected[count], "script summary uses setup counts and one secret, including Lovers")
		check(JSON.stringify(main.g.board) == board and main.g.w.rng.state == rng, "script summary creates no card and consumes no RNG")
	for i in range(3): await process_frame
	main.free()


func hide_rows():
	var Layout = preload("res://game/board_model.gd")
	var cards = [{"n": 1, "kind": "sighting", "source": "player", "subject": ["a", "b"], "block": "square", "day": 1, "phase": 0}, {"n": 2, "kind": "deduction", "supports": [1], "pins": {"places": Vector2(500, 500)}}]
	var original = JSON.stringify(cards)
	var ctx = {"day": 1, "phase": 0, "blocks": C.BLOCKS.keys(), "people": [{"id": "a", "name": "A"}, {"id": "b", "name": "B"}], "rows_by": "place", "selected_blocks": ["square", "hill"], "hide_unselected": true}
	var hidden = Layout.layout(cards, "places", ctx)
	check(hidden.rows.map(func(row): return row.id) == ["square", "hill"], "several explicit row filters are ORed with existing selected-first order")
	check(hidden.pinned == [2] and JSON.stringify(cards) == original, "hiding rows preserves pins, cards and links")
	ctx.selected_blocks = []
	check(Layout.layout(cards, "places", ctx).rows.size() == 4, "no active row selection leaves every row visible")
	ctx.rows_by = "person"
	ctx.selected_people = ["b"]
	hidden = Layout.layout(cards, "places", ctx)
	check(hidden.rows.size() == 1 and hidden.rows[0].id == "b" and hidden.items.size() == 1, "person rows reuse the existing person selection rule")
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	root.add_child(scene)
	var cv = scene.case_view
	cv._refresh_board()
	check(cv.hide_unselected.disabled and cv.hide_unselected.tooltip_text != "", "hide toggle is disabled and explained without a current row selection")
	scene.case_state.places.square = true
	cv._refresh_board()
	check(not cv.hide_unselected.disabled, "an explicit place filter enables place-row hiding")
	for i in range(3): await process_frame
	scene.free()


func column_menus():
	var Columns = preload("res://ui/column_menus.gd")
	var option = OptionButton.new()
	for i in range(19):
		option.add_item("Choice %d" % i)
		option.set_item_metadata(i, "value:%d" % i)
	option.set_item_disabled(3, true)
	root.add_child(option)
	Columns.bind(option.get_popup())
	var chosen: Array = []
	option.item_selected.connect(func(index): chosen.append(index))
	option.show_popup()
	for i in range(4): await process_frame
	var popup = option.get_popup().get_meta("column_popup", null)
	check(is_instance_valid(popup) and popup.visible and not option.get_popup().visible, "long native dropdown opens a column presentation")
	var groups = Columns.groups(option.get_popup())
	check(groups.map(func(group): return group.indices.size()) == [7, 6, 6], "uncategorized options split evenly with at most eight per column")
	var buttons = popup.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("menu_index"))
	check(buttons.size() == 19 and buttons.filter(func(b): return b.get_meta("menu_index") == 3)[0].disabled, "column menus preserve every option and disabled state")
	var focused = popup.gui_get_focus_owner()
	var key = InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	key.window_id = popup.get_window_id()
	Input.parse_input_event(key)
	await process_frame
	check(popup.gui_get_focus_owner() != null and popup.gui_get_focus_owner() != focused, "arrow keys move focus across columns")
	var bounds = Rect2i(Vector2i.ZERO if root.gui_embed_subwindows else root.position, root.size)
	check(bounds.encloses(Rect2i(popup.position, popup.size)), "the column popup stays within the containing screen area")
	buttons.filter(func(b): return b.get_meta("menu_index") == 12)[0].pressed.emit()
	check(option.selected == 12 and chosen == [12] and option.get_item_metadata(12) == "value:12", "column choice keeps the native index, metadata and callback exactly once")
	await process_frame
	option.free()
	var menu = PopupMenu.new()
	menu.add_separator("Existing category")
	for i in range(11): menu.add_item(str(i), i + 100)
	menu.add_separator("Other category")
	for i in range(5): menu.add_item(str(i), i + 200)
	groups = Columns.groups(menu)
	check(groups.size() == 3 and groups[0].title == "Existing category" and groups[1].title == "Existing category" and groups[2].title == "Other category", "existing menu categories are retained when a category spans columns")
	menu.free()
	var picker = VBoxContainer.new()
	var label = Label.new()
	label.text = "People"
	picker.add_child(label)
	for i in range(17): picker.add_child(Button.new())
	var balanced = Columns.balance(picker)
	check(balanced.get_child(1).get_children().map(func(col): return col.get_children().filter(func(n): return n is Button).size()) == [6, 6, 5], "handcrafted pickers also split evenly into eight-option columns")
	picker.free()
	balanced.free()


# ---- test_backlog_batch4


func backlog_batch4__fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch4_tests"
	g.new_case(4242, 10)
	return g


func vote_help():
	var g = backlog_batch4__fresh()
	var rng = g.w.rng.state
	check("11 voters, including you" in g._help() and g.w.voter_count() == 11, "help explains the existing player-inclusive voter count")
	check(g.w.rng.state == rng, "vote help changes no RNG or voting rules")


func demon_night_wording():
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	root.add_child(scene)
	var g = backlog_batch4__fresh()
	scene.g = g
	var rng = g.w.rng.state
	scene._open_roles()
	var labels = scene.roles_box.find_children("DemonNightRule", "Label", true, false)
	check(labels.size() == 1 and labels[0].text == C.DEMON_NIGHT_RULE and C.DEMON_NIGHT_RULE in g._script(), "both graphical and typed Roles state the night-0 and night-1 rule")
	check(g.w.rng.state == rng, "Roles wording does not advance RNG")
	for day in [1, 2]:
		g.w.day = day
		g.state = "meeting"
		g.w.meeting = {"block": ""}
		g.events = []
		g._close_meeting()
		var text = Game.render(g.events)
		check((C.DEMON_NIGHT_RULE in text) == (day == 1) and g.state == "night", "the explanatory line appears at the first night prompt only")
	for i in range(3): await process_frame
	scene.free()


func approach_arrival():
	var g = backlog_batch4__fresh()
	var control = backlog_batch4__fresh()
	var n = g.w.living_good()[0]
	var companion = g.w.living_good()[1]
	for game in [g, control]:
		for person in game.w.npcs:
			person.loc = "home_" + person.id
			person.busy_with = ""
		game.w.by_id[n.id].loc = "tavern"
		game.w.by_id[companion.id].loc = "tavern"
		game.state = "day"
		game.moved = false
	g.approach = {"npc": n, "agenda": "divulge"}
	g.state = "approach"
	var phase = g.w.phase
	var rng = g.w.rng.state
	var output = g.command("accept")
	control.command("go tavern")
	var arrival = control.last_events.filter(func(e): return e.k == "narration").map(func(e): return e.text)
	check(arrival.all(func(text): return text in output) and ("Present: " in output) and companion.name in output, "acceptance prints the ordinary go arrival block including other people")
	check(g.state == "talk" and g.talk_with == n and g.loc == "tavern" and g.w.player_loc == "tavern" and g.free_move_used and g.questions_left == 3, "approach acceptance retains its conversation and movement rules")
	check(g.w.phase == phase and g.w.rng.state == rng, "arrival narration adds no phase advance or RNG draws")
	var expected = control.board.filter(func(c): return c.get("loc", "") == "tavern" and c.kind == "sighting").map(func(c): return Mind.fact_id(c))
	var actual = g.board.filter(func(c): return c.get("loc", "") == "tavern" and c.kind == "sighting").map(func(c): return Mind.fact_id(c))
	check(expected == actual, "approach and ordinary visit produce the same visible-person sighting identities")
	var due = backlog_batch4__fresh()
	var source = due.w.living_good()[0]
	source.loc = "tavern"
	source.busy_with = ""
	source.silenced = false
	source.role = "clerk"
	due.divulge_due = [source.id]
	due.events = []
	check(due._maybe_divulge() and Game.render(due.events).contains("finds you at " + due.w.loc_name(source.loc)), "a promised approach names the meeting place before acceptance")
	var old_loc = due.loc
	var old_phase = due.w.phase
	due.command("decline")
	check(due.loc == old_loc and due.w.phase == old_phase, "declining an approach still does not move or spend the phase")


func inspect_then_talk():
	root.size = Vector2i(1920, 1080)
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	root.add_child(scene)
	var g = backlog_batch4__fresh()
	scene.g = g
	scene.map.set_game(g)
	scene.cast_list.setup(g)
	scene.profile.setup(g, scene.case_state)
	scene.case_view.set_game(g)
	scene.meeting_view.set_game(g)
	g.state = "day"
	g.moved = false
	var n = g.w.living_good()[0]
	n.loc = n.work
	n.working = true
	n.busy_with = ""
	var phase = g.w.phase
	var loc = g.loc
	var rng = g.w.rng.state
	var cards = g.board.size()
	scene._on_map_clicked("npc", n.id)
	check(g.state == "day" and not g.moved and g.w.phase == phase and g.loc == loc and g.w.rng.state == rng and g.board.size() == cards, "map portrait inspection spends no movement, action, question, card or RNG")
	check(scene.profile.current() == n.id and scene.map.selected_npc == "" and scene.cast_list.selected == "", "map portrait inspection shows the profile while preserving townsfolk-owned highlighting")
	scene._on_town_person_clicked(n.id)
	scene._on_town_person_clicked(n.id)
	check(g.state == "day" and not g.moved and g.w.rng.state == rng, "cast portrait selection also stays informational")
	var buttons = scene.actions.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion() and b.text == "Talk to " + n.name)
	check(buttons.size() == 1, "selected visible person offers an explicit Talk button")
	buttons[0].pressed.emit()
	check(g.state == "talk" and g.talk_with == n and g.questions_left == 3 and g.w.phase == phase, "explicit Talk uses the preserved go/talk command sequence")
	scene._run("bye")
	check(g.w.phase == phase, "leaving an untouched explicit conversation retains the existing free exit")
	g.moved = false
	g.state = "day"
	scene._run_seq(["go nowhere_known", "talk " + n.id])
	check(g.state == "day" and not g.moved and g.talk_with == null, "the existing command sequence still stops on a failed walk")
	for i in range(3): await process_frame
	scene.free()


func busy_visit_warning():
	var g = backlog_batch4__fresh()
	var n = g.w.living()[0]
	var other = g.w.living()[1]
	n.loc = n.work
	n.working = true
	n.busy_with = other.id
	other.loc = n.loc
	other.busy_with = n.id
	g.state = "day"
	g.moved = false
	var row = preload("res://ui/cast_list.gd").new()
	row.setup(g)
	check("busy talking" in row._sub_line(n), "visible cast row warns that someone is busy before choosing to walk")
	check(row._fit_text(row._sub_line(n), 80.0, 13).begins_with("busy"), "busy warning remains visible when role badges leave a narrow cast row")
	var phase = g.w.phase
	var rng = g.w.rng.state
	var output = g.command("go " + n.id)
	check("busy talking with " + other.name in output and "Present:" in output, "go names the busy partner and retains the normal arrival")
	check(g.moved and g.loc == n.loc and g.state == "day" and g.w.phase == phase and g.w.rng.state == rng, "busy warning changes no movement, phase or RNG rules")
	n.loc = "home:" + n.home_block
	n.working = false
	g.moved = false
	g.loc = ""
	check(row._sub_line(n) == "location unknown", "busy status does not disclose a hidden location")
	row.free()


func new_actions_help():
	var g = backlog_batch4__fresh()
	var rng = g.w.rng.state
	var st0: String = g.state  # a seed may open on an approach; help must leave it as it was
	var text = g._help()
	for action in ["offer ward", "offer vigil", "apologise <number>", "yes | no", "ask check <name>", "ask guard <name>", "ask watch <block>", "ask about <gift>", "ward or scorched-sigil card#"]:
		check(action in text, "help documents newer action: " + action)
	check("pending request" in text and "disclosed that gift" in text and "privately or at the meeting" in text, "help explains the action contexts")
	check(g.w.rng.state == rng and g.state == st0, "help is read-only")


func night_home_listing():
	var g = backlog_batch4__fresh()
	g.state = "night"
	var dead = g.w.npcs[0]
	dead.alive = false
	var n = g.w.living()[0]
	n.loc = "night:" + n.home_block
	var rng = g.w.rng.state
	var summary = g._night_homes()
	for block in C.BLOCKS:
		check(C.block_name(block) + ":" in summary, "night list includes block " + block)
	for living in g.w.living():
		check(summary.count(living.name) == 1, "night map's living home resident listed once: " + living.name)
	check(not dead.name in summary and n.name in summary, "night planning list matches map home markers without leaking hidden walks or including the dead")
	check(summary in g.command("look") and g.w.rng.state == rng and g.state == "night", "night look repeats the same home list without changing RNG or night work")


func grimoire_modifiers():
	var g = backlog_batch4__fresh()
	var n = g.w.living_good()[0]
	n.secret = {"kind": "test", "text": "keeps a private diary"}
	var rng = g.w.rng.state
	var st1: String = g.state
	for mod in C.SECRET_MOD_LIST:
		n.secret_mod = mod
		var lines = Array(g._grimoire().split("\n"))
		var row = lines.filter(func(line): return line.strip_edges().begins_with(n.name + " "))[0]
		check("secret modifier: " + C.secret_name(mod) in row and "keeps a private diary" in row, "grimoire shows personal secret and modifier together: " + mod)
	n.secret_mod = ""
	check(not Array(g._grimoire().split("\n")).filter(func(line): return line.strip_edges().begins_with(n.name + " "))[0].contains("secret modifier:"), "no invented modifier is printed for an unmodified NPC")
	check(g.w.rng.state == rng and g.state == st1, "developer summary formatting does not change the game")


## The distinct column counts of the Roles sections' grids.
func _roles_columns(node) -> Array:
	var out: Array = []
	for grid in node.find_children("*", "GridContainer", true, false):
		if grid.columns not in out:
			out.append(grid.columns)
	return out

func _roles_rows(node) -> int:
	var count = 0
	if node is TextureRect and node.custom_minimum_size == Vector2(34, 34): count += 1
	for child in node.get_children(): count += _roles_rows(child)
	return count


func presentation_options():
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.roles_win.hide()
	scene.seed_box.value = 4242
	for index in range(scene.size_opt.item_count):
		if scene.size_opt.get_item_metadata(index) == 10: scene.size_opt.select(index)
	scene._new_case()
	var g = scene.g
	var rng = g.w.rng.state
	var phase = g.w.phase
	var cards = JSON.stringify(g.board)
	var roles_count = g.w.case_script.town.size() + g.w.case_script.demons.size() + g.w.case_script.minions.size() + g.w.case_script.secrets.size()
	scene._open_roles()
	var content = scene.roles_content
	check(not scene.roles_pinned and scene.roles_win.visible and not scene.roles_dock.visible, "Roles starts as the existing movable window")
	scene.roles_pin.button_pressed = true
	check(scene.roles_pinned and scene.roles_dock.visible and not scene.roles_win.visible and content.get_parent() == scene.roles_dock, "pin moves the same Roles content beside the town profile")
	check(_roles_columns(scene.roles_box) == [1] and _roles_rows(scene.roles_box) == roles_count, "pinned Roles has all gifts and secrets in one scrollable column")
	var summary = scene.roles_box.find_child("SetupSummary", true, false)
	check(summary != null and summary.text == scene.setup_summary(g.w.n_npcs), "pinned Roles retains rule-based setup counts")
	var n = g.w.npcs[0]
	n.claimed_role = "seer"
	n.max_tier = 3
	scene._refresh_all()
	check(scene._roles_signature == scene._roles_state_key() and _roles_rows(scene.roles_box) == roles_count, "pinned Roles refreshes the same existing claim content without duplicating rows")
	# Keep the fixture-only disclosure out of the observational comparison.
	n.claimed_role = ""
	n.max_tier = 0
	scene._open_case_view()
	scene._open_roles()
	check(scene.roles_pinned and scene.roles_win.visible and content.get_parent() == scene.roles_window_box, "case-board Roles can still open the shared window while retaining the pin preference")
	scene.case_view.hide()
	check(scene.roles_dock.visible and content.get_parent() == scene.roles_dock and not scene.roles_win.visible, "returning to town restores the pinned Roles panel")
	scene._hide_roles()
	check(not scene.roles_showing and not scene.roles_dock.visible, "Hide closes the pinned reference without changing its session preference")
	scene.case_view.show()
	scene.case_view.hide()
	check(not scene.roles_dock.visible, "screen changes do not reopen a panel the player hid")
	scene._open_roles()
	scene.roles_pin.button_pressed = false
	check(not scene.roles_pinned and scene.roles_win.visible and content.get_parent() == scene.roles_window_box and _roles_columns(scene.roles_box) == [2], "unpin restores the two-column Roles window")
	check(g.w.rng.state == rng and g.w.phase == phase and JSON.stringify(g.board) == cards, "Roles layout, navigation and toggles change no game data or RNG")
	var fresh_scene = load("res://ui/main.tscn").instantiate()
	check(not fresh_scene.roles_pinned, "pin preference is session-only and defaults off in a new UI")
	fresh_scene.free()
	n.revealed_traits.clear()
	scene._select_person(n.id)
	scene.profile.bars.reset_observations()
	scene.profile.refresh()
	n.revealed_traits.insight = C.tier(n.traits.insight)
	scene.profile.refresh()
	check(scene.profile.bars.flashes.has("insight") and scene.profile.bars.revealed.insight == n.traits.insight, "actual profile refresh flashes the newly learned score, not undisclosed traits")
	var bars = preload("res://ui/trait_bars.gd").new()
	bars.show_traits({"privacy": 0.8}, "agnes")
	check(bars.flashes.is_empty(), "first profile display does not flash already known traits")
	bars.show_traits({"privacy": 0.8, "insight": 0.4}, "agnes")
	check(bars.flashes == {"insight": 1.0}, "only the newly learned trait starts its one-second flash")
	bars._process(0.6)
	bars.show_traits({"privacy": 0.8, "insight": 0.4}, "agnes")
	check(is_equal_approx(bars.flashes.insight, 0.4), "refreshing the same known traits does not restart the flash")
	bars._process(0.41)
	check(bars.flashes.is_empty() and not bars.is_processing(), "trait flash expires after one second and stops processing")
	bars.show_traits({"gossip": 0.5}, "isolde")
	check(bars.flashes.is_empty(), "switching people does not present old knowledge as a new discovery")
	bars.reset_observations()
	bars.show_traits({"gossip": 0.5, "privacy": 0.7}, "isolde")
	check(bars.flashes.is_empty(), "new case binding resets trait flash observations")
	bars.free()
	var Map = preload("res://ui/map_view.gd")
	var bounds = Rect2(0, 0, 500, 300)
	var wanted = Rect2(200, 120, 80, 20)
	var obstacles: Array = [wanted.grow(3)]
	var placed = Map.name_label_rect(wanted, obstacles, bounds)
	check(bounds.encloses(placed) and not obstacles[0].intersects(placed) and placed.size == wanted.size, "map name moves clear of a place sign while staying in bounds")
	obstacles.append(placed)
	var next = Map.name_label_rect(wanted, obstacles, bounds)
	check(not obstacles.any(func(r): return r.intersects(next)), "map name placement also avoids preceding names")
	check(next == Map.name_label_rect(wanted, obstacles, bounds), "map label offsets are deterministic")
	check(bounds.encloses(Map.name_label_rect(Rect2(-20, 290, 80, 20), [], bounds)), "map name placement handles view edges")
	# Real rendered map layout with an intentionally crowded public location.
	scene.roles_win.hide()
	g.state = "day"
	g.moved = true
	g.loc = "tavern"
	g.w.player_loc = "tavern"
	for person in g.w.living():
		person.loc = "tavern"
		person.working = true
	scene.map.zoom_block = g.w.loc_block("tavern")
	scene.map.refresh()
	await process_frame
	await process_frame
	check(scene.map._name_labels.size() == g.w.living().size(), "crowded zoomed map retains every visible person's name")
	for name in scene.map._name_labels:
		check(scene.map._r(scene.map._block_rect(scene.map.zoom_block)).encloses(name.rect), "rendered name stays inside the undimmed zoomed block: " + name.id)
		check(not scene.map._label_obstacles.any(func(r): return r != name.rect and r.intersects(name.rect)), "rendered name stays clear of place signs and other names: " + name.id)
	var elsewhere = g.w.living()[-1]
	elsewhere.loc = "wharf"
	scene.map.refresh()
	await process_frame
	await process_frame
	check(not scene.map._name_labels.any(func(label): return label.id == elsewhere.id), "layout never pulls a name from another block into the zoomed street")
	check(scene.map._name_labels.size() == g.w.living().size() - 1, "the viewed block retains all its residents after another person leaves")
	check(g.w.rng.state == rng and g.w.phase == phase, "flash timers and rendered label layout consume no game RNG or time")
	scene._set_roles_pinned(true)
	for index in range(scene.size_opt.item_count):
		if scene.size_opt.get_item_metadata(index) == 7: scene.size_opt.select(index)
	scene._new_case()
	check(scene.roles_pinned and scene.roles_dock.visible and scene.roles_content.get_parent() == scene.roles_dock, "new case retains this session's visible pin preference")
	check(scene.roles_box.find_child("SetupSummary", true, false).text == scene.setup_summary(7), "new case updates pinned setup counts from its new setup rules")
	check(scene.profile.bars.flashes.is_empty(), "new case does not replay previous trait discovery flashes")
	scene.free()


# ---- test_fixes


func _game(sd: int, size: int = 10):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


func _summary() -> void:
	var g = _game(7107)
	var w = g.w
	var mart = w.npcs.filter(func(x): return not x.is_evil())[0]
	var saved = w.npcs.filter(func(x): return not x.is_evil() and x != mart)[0]
	w.executions.append({"day": 2, "id": mart.id, "saved": saved.id, "martyr": true, "nominator": "player", "yes": [], "player_yes": false, "player_nominated": true})
	var first = w.demon_id
	var sc = w.npcs.filter(func(x): return x.is_evil() and x.id != first)[0]
	w.demon_id = sc.id   # as if a Scion had taken over
	var s = CaseMetrics.summarize(w, {"guesses": {first: {"guess": "demon", "confidence": 3}}}, false, g.board)
	var row: Dictionary = s["executions"][0]
	_check(row["id"] == saved.id and row.get("martyr_died", "") == mart.id and row["nominator"] == "player", "a Martyr's death is recorded against the nomination it answered")
	_check(s["executions_good"] == 1, "...and counts as a good death at the gallows")
	_check(s["demon_identified"], "naming the demon the case started with counts, after a Scion takes over")


# ---- test_playtest_followups


func settle():
	for i in range(5): await process_frame


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


func playtest_followups__headlines():
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


# ---- test_playtest_regressions


func playtest_regressions__game():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(25923, 10)
	return g


func _approach_ui_visibility() -> void:
	var g = playtest_regressions__game()
	var w = g.w
	var n = w.living_good()[0]
	n.loc = "chapel"
	n.working = false
	n.busy_with = ""
	g.moved = false
	g.state = "approach"
	g.approach = {"npc": n, "agenda": "gossip"}
	g.approached_id = n.id
	g.approached_loc = n.loc
	_check(not g.can_see(n) and g.can_see_ui(n), "approaching NPC is visible in UI without breaking simulation can_see")
	g.command("decline")
	_check(g.state == "day" and g.can_see_ui(n), "declined approach NPC remains visible at their stated location for that phase")
