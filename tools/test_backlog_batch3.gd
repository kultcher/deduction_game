extends SceneTree
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const Overlay = preload("res://ui/headline_overlay.gd")
var checks = 0
var fails = 0
func _init():
	call_deferred("run")
func check(ok: bool, text: String):
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", text)
func fresh(count: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch3_tests"
	g.new_case(4242, count)
	return g
func run():
	await headlines()
	await setup_counts()
	await ward_warnings()
	await hide_rows()
	repeated_role_gift()
	private_gift_terms()
	totem_signpost()
	await column_menus()
	ward_evidence()
	bot_options()
	print("Batch 3: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
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
	check(is_equal_approx(left - overlay.remaining, 0.5), "more than two waiting notices shorten display time")
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
	var path = "res://logs/batch3/headline-test.cfg"
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

func ward_warnings():
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	root.add_child(scene)
	var g = scene.g
	var person = g.w.living_good()[0]
	g.events = []
	g._offer_command(person, "ward")
	check(g.w.tools.ward == 1 and g.offer.ward == person.id and Game.render(g.events).contains("Promising does not spend your ward; keeping the promise does"), "ward promises explain the limit and do not consume the tool")
	g.state = "night"
	scene._ward_target = person.id
	scene._refresh_actions()
	await process_frame
	var buttons: Array = scene.actions.get_children().filter(func(n): return n is Button and "ward" in n.text.to_lower())
	check(buttons.size() >= 3 and buttons.all(func(b): return "1 left, once per case" in b.text), "every direct-night Ward button displays the remaining limit")
	var dialog = scene._confirm_ward(person.id)
	check(dialog.dialog_text == "This spends your only ward. Ward %s?" % person.name and g.w.tools.ward == 1, "direct UI warding asks for confirmation before spending")
	dialog.canceled.emit()
	await process_frame
	check(g.w.tools.ward == 1 and g.state == "night", "canceling a ward confirmation spends nothing")
	var output = g.command("ward " + person.id)
	check(g.w.tools.ward == 0 and g.ward_log.has(1) and "You chalk a warding sigil" in output, "typed ward commands go straight through and consume exactly one use")
	for i in range(3): await process_frame
	scene.free()

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

func repeated_role_gift():
	for evil in [false, true]:
		for public in [false, true]:
			var a = fresh()
			var b = fresh()
			var na = a.w.minion() if evil else a.w.living_good()[0]
			var nb = b.w.by_id[na.id]
			for pair in [[a, na], [b, nb]]:
				var g = pair[0]
				var n = pair[1]
				g.w.day = 3
				n.max_tier = 3
				n.claim_public = public
				n.claimed_role = "seer"
				if evil: g.w.evil_plan.bluffs[n.id] = "seer"
				else: n.role = "seer"
				n.trust = 0.9
				n.traits.privacy = 0.0
				n.pressed_today = 3
				n.role_guesses = 2
				var others: Array = g.w.npcs.filter(func(x): return x != n).map(func(x): return x.id)
				n.info_log = [{"role": "seer", "day": 1, "data": {"pair": others.slice(0, 2), "yes": false}, "text": "neither was the Demon", "shared": false}]
			var direct = Mind.answer_gift(a.w, na)
			var repeated = Social.answer_is_role(b.w, nb, "seer")
			check(JSON.stringify(direct) == JSON.stringify(repeated), "already disclosed matching role question gives exactly the ask-gift response")
			check(na.pressed_today == nb.pressed_today and na.trust == nb.trust and a.w.rng.state == b.w.rng.state and nb.role_guesses == 2, "matching question preserves gift cost/fatigue/RNG and is never a wrong guess")
			check(repeated.facts.any(func(f): return f.kind == "info"), "willing matching-role answers include previously withheld readings")

func private_gift_terms():
	var g = fresh()
	for n in [g.w.living_good()[0], g.w.minion()]:
		for role in [C.START_ROLES[0], "seer", "warden", "martyr"]:
			if n.is_evil(): g.w.evil_plan.bluffs[n.id] = role
			else: n.role = role
			n.traits.privacy = 0.5
			n.traits.composure = 0.5
			n.trust = 0.5
			n.pressure = 0.0
			n.martyr_target = g.w.npcs.back().id
			for day in [1, 2, 3]:
				g.w.day = day
				var probe = RandomNumberGenerator.new()
				probe.state = g.w.rng.state
				var jitter = probe.randf_range(-0.2, 0.2)
				var openness = 0.5 + 0.5 * 1.2 + 0.1 * (day - 1) - 0.72 + jitter
				if C.ROLES[role].kind != "info": openness -= 0.5
				if role in ["seer", "hearthwitch", "nightwatch", "lamplighter", "medium", "psychologist", "dowser"] and day <= 2: openness -= 0.4
				elif role in C.START_ROLES: openness += 0.3
				var expected = 4 if openness > 0.75 else (3 if openness > 0.45 else (2 if openness > 0.15 else 1))
				check(Mind._target_tier(g.w, n) == expected, "private tier applies only the approved gift terms under public-roll conditions")
				check(g.w.rng.state == probe.state, "gift-type tuning retains exactly one jitter draw")

func totem_signpost():
	var g = fresh()
	g.w.totem = {"loc": "well", "material": "market", "day": 1, "owner": g.w.minion().id}
	g.events = []
	var rng = g.w.rng.state
	g.loc = "well"
	g._search()
	check(g.board.any(func(c): return c.kind == "totem" and "will seek a new hiding place" in c.text), "totem-burned receipt warns of a new hiding place")
	check(g.events.any(func(e): return e.k == "headline" and e.kind == "totem" and "will seek a new hiding place" in e.subtitle), "totem warning also appears as a headline")
	check(g.w.totem.is_empty() and g.w.rng.state == rng, "totem signpost preserves burn behavior and RNG")

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
	check(balanced.get_children().map(func(col): return col.get_children().filter(func(n): return n is Button).size()) == [6, 6, 5], "handcrafted pickers also split evenly into eight-option columns")
	picker.free()
	balanced.free()

func ward_evidence():
	var g = fresh()
	var target = g.w.living_good()[0]
	for n in g.w.living_good():
		n.role = "clerk"
		n.secret_mod = ""
		if n != target:
			for i in range(20): g.w.evil_plan.failed.append(n.id)
	g.state = "night"
	g.command("ward " + target.id)
	var spent: Array = g.board.filter(func(c): return c.kind == "ward")
	var sigils: Array = g.board.filter(func(c): return c.kind == "scorched_sigil")
	check(spent.size() == 1 and spent[0].target == target.id and spent[0].loc == "home_" + target.id and spent[0].night == 1, "spending a ward records protectee, door and night")
	check(g.w.ward_saves.any(func(save): return save.target == target.id and save.night == 1) and sigils.size() == 1, "an actual blocked attack leaves one scorched-sigil card next morning")
	if sigils.is_empty(): return
	var sigil: Dictionary = sigils[0]
	check(sigil.private and not sigil.learned.any(func(d): return d.public), "the newly found sigil is player-only")
	var other = g.w.minion()
	for n in g.w.living():
		n.trust_cap = 1.0
		n.trust = 0.3
	g.state = "talk"
	g.talk_with = other
	g.questions_left = 3
	other.silenced = true
	var deliveries = g.workshop_deliveries.size()
	g.command("present %d" % sigil.n)
	check(is_equal_approx(other.trust, 0.35) and g.questions_left == 2, "private showing rewards even an evil/silenced listener and costs one question")
	g.command("present %d" % sigil.n)
	check(is_equal_approx(other.trust, 0.35), "repeated private showing cannot reward the same listener twice")
	g.state = "meeting"
	g.presented_today = false
	g.command("present %d" % sigil.n)
	check(is_equal_approx(target.trust, 0.5) and is_equal_approx(other.trust, 0.35), "meeting showing grants protectee +0.20 total and skips previously rewarded listeners")
	check(g.w.living().all(func(n): return n == target or is_equal_approx(n.trust, 0.35)), "every other living NPC receives +0.05 irrespective of alignment")
	check(g.presented_today and sigil.learned.any(func(d): return d.public) and not sigil.private, "meeting showing consumes the normal floor and makes the receipt public")
	check(g.workshop_deliveries.size() == deliveries, "showing protection context does not invent a shared-model adapter")
	var second = g.add_card({"kind": "scorched_sigil", "subject": [other.id], "source": "evidence", "target": other.id, "text": "Another distinct sigil", "private": true})
	other.trust = 0.49
	other.trust_cap = 0.5
	g._show_ward_context(g.board[second - 1], [other])
	check(is_equal_approx(other.trust, 0.5), "sigil trust honors existing caps")
	g.new_case(4242, 10)
	check(g.sigil_heard.is_empty(), "new cases reset per-sigil reward ownership")

func bot_options():
	var Bot = preload("res://tools/autoplay.gd")
	var g = fresh()
	var n = g.w.living_good()[0]
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 2
	n.max_tier = 3
	n.claimed_role = "seer"
	var used = {}
	check(Bot.new_talk_option(g, used) == "offer ward", "bot offers an available ward to a known info claimant")
	g.offer = {"ward": n.id}
	check(Bot.new_night_option(g) == "ward " + n.id, "bot keeps its ward promise before ordinary night choices")
	check(Bot.new_talk_option(g, used).begins_with("ask check "), "bot requests a disclosed Seer's gift")
	check(Bot.new_talk_option(g, used) == "", "bot does not repeat a free offer or gift request")
	g.questions_left = 1
	check(Bot.new_talk_option(g, used).begins_with("ask about "), "bot asks about another person to learn haunts, traits and relationships")
	g.pending_request = {"kind": "confidence"}
	check(Bot.new_talk_option(g, used) == "yes" and Bot.new_action_kind(g, "yes") == "answer_confidence", "bot answers and counts confidence requests")
	g.pending_request = {"kind": "protect", "what": "ward"}
	check(Bot.new_talk_option(g, used) == "no", "bot answers protection requests without promising a second incompatible action")
	g.offer = {}
	check(Bot.new_talk_option(g, used) == "yes" and Bot.new_action_kind(g, "yes") == "answer_protection", "bot accepts and counts feasible protection requests")
	g.pending_request = {}
	n.grievances = [{"apologised": false}]
	check(Bot.new_talk_option(g, {}) == "apologise 1", "bot apologises for a player-visible grievance")
	n.grievances = []
	n.max_tier = 0
	n.claim_public = false
	check(Bot.new_talk_option(g, {}) == "offer vigil", "hidden role assignments do not influence the bot's protection offer")
	g.offer = {"vigil": {n.id: n.home_block}}
	check(Bot.new_night_option(g) == "vigil " + n.home_block, "bot keeps a vigil promise")
	for role in ["warden", "nightwatch"]:
		n.claimed_role = role
		n.max_tier = 3
		g.questions_left = 2
		var command = Bot.new_talk_option(g, {})
		check(command.begins_with("ask guard " if role == "warden" else "ask watch "), "bot covers each other supported gift request")
		check(Bot.new_action_kind(g, command) == ("request_guard" if role == "warden" else "request_watch"), "run-summary classification counts each gift action")
