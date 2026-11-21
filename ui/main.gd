## In-engine UI. The town map (click places and people), a coloured log, a context-sensitive
## action panel (every command as buttons and menus), a profile panel, an optional case-board
## sidebar and the full-screen case view. Every click becomes the same text command the CLI
## uses, so the typed prompt still works as a fallback.
extends Control

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const TermDefs = preload("res://ui/term_defs.gd")
const TextTerms = preload("res://ui/text_terms.gd")
const CardList = preload("res://ui/card_list.gd")
const EvidenceContext = preload("res://ui/evidence_context.gd")
const MapView = preload("res://ui/map_view.gd")
const CaseState = preload("res://ui/case_state.gd")
const UITheme = preload("res://ui/theme.gd")
const TraceArt = preload("res://ui/trace_art.gd")
const NewCaseScreen = preload("res://ui/new_case_screen.gd")
const LogText = preload("res://ui/log_text.gd")
const Layout = preload("res://ui/main_layout.gd")
const Roles = preload("res://ui/main_roles.gd")
const Actions = preload("res://ui/main_actions.gd")
const DailyGuess = preload("res://ui/daily_guess.gd")
const RevealOverlay = preload("res://ui/reveal/reveal_overlay.gd")

var g
var out: RichTextLabel
var input: LineEdit
var seed_box: SpinBox
var size_opt: OptionButton       # hidden: the New Case screen sets it (tests still drive it)
var new_case_screen
## The script for the next case (sim/script_def.gd); null deals the Default script.
var current_script = null
var side: VBoxContainer
var side_filter: LineEdit
var side_list
## Daytime sightings ("X saw Y at Z") crowd the card lists, so they're hidden unless asked
## for (Michael, Nov 19): one setting for the side list and the "Present a card" picker,
## kept for the case.
var show_day_sightings: bool = false
var side_sightings_check: CheckBox
var profile                  # ui/profile_panel.gd: the same profile as on the case board
var side_profile: RichTextLabel:
	get: return profile.body
var case_view
var case_state = CaseState.new()   # view, filters and selection shared by every panel
var map
var map_stage: Control
## Top right of the map during a conversation or meeting: back to it (Michael, Nov 17).
var map_return: Button
var conversation_view
var conversation_show_map = false
var _deferred_log_events: Array = []  # the phase change after a conversation that ran out of questions (see _run)
## A reading (Town Hall records, tavern gossip, a crime scene's traces) that ended the phase:
## the screen holds the old phase until the last page is done (Michael, Nov 19).
var _phase_held: bool = false
var reveal_seen_for = null      # the game whose grim reveal has opened (it opens once, by itself)
var reduced_motion: bool = false  # the reveal without its deal and slides (More menu)
var daily_guess_off_for = null   # the game whose daily guess the player turned off ("Don't ask again this case")
const READING_VERBS = ["gossip", "records", "register", "town_hall", "inspect", "search", "s"]
var _deferred_meeting_events: Array = []  # the same, when it opened the meeting: the stage takes them up on leaving
var conversation_finished = false
## An NPC approach in the VN (triage 2.8/8.3, Nov 16): "intro" shows the interstitial with
## no portrait over the phase change, "speaking" the approacher and your choices. The key
## tells a new approach from the one already on screen.
var approach_stage = ""
var _approach_key = ""
## Crime-scene traces from the last search, shown one at a time in the conversation view.
var inspect_pages: Array = []
var inspect_index = 0
var meeting_view
var actions: Container
var action_title: Label
var popup: PopupPanel
var mono: SystemFont
var history: Array = []
var hist_i = 0
var theory_label: Label
var roll_window
var roll_button: Button
var debug_check: CheckBox
var day_icon: TextureRect
var day_label: Label
var cast_list                # ui/cast_list.gd
var cast_header: Label
var meeting_show_map = false # during a meeting, peek at the map instead of the circle
var _popup_anchor = null
var _case_seed = -1
var show_script_at_start = true   # the script opens when a case begins
var _last_state = ""
var _ward_target = ""       # choosing a night action does not own map highlighting
var notes_win: Window
var notes_edit: TextEdit
var roles_win: Window
var roles_box: VBoxContainer
var roles_pinned = false # Session preference; never saved with game/settings.
var roles_showing = false
var _roles_signature = ""
var roles_dock: PanelContainer
var roles_content: VBoxContainer
var roles_window_box: VBoxContainer
var roles_pin: CheckBox
var log_text = LogText.new()

var headlines

## The screen is built in ui/main_layout.gd; this script keeps the state and the command flow.
func _ready() -> void:
	Layout.build(self)

func _consume_headlines() -> void:
	for event in g.last_events:
		if event.k == "headline":
			headlines.enqueue(event)
func _button(parent: Node, text: String, cb: Callable, color = null) -> Button:
	var b = Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.tooltip_text = TermDefs.control_tip(text)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if color != null:
		# Character colours are tuned for the dark board; on a paper button, use their ink.
		b.add_theme_color_override("font_color", UITheme.ink_of(color))
		b.add_theme_color_override("font_hover_color", UITheme.ink_of(color).darkened(0.2))
	parent.add_child(b)
	return b
func _on_side_activated(num) -> void:
	input.text += " " + str(num)
	input.grab_focus()
	input.caret_column = input.text.length()
## New case from the button: a fresh seed, unless you've typed one in since this case began.
func _open_new_case_screen() -> void:
	if g != null and (g.workshop_presenting or g.meeting_streaming()):
		return
	new_case_screen.count = int(size_opt.get_item_metadata(size_opt.selected))
	new_case_screen.case_seed = _next_case_seed()
	new_case_screen.open(g != null and not g.w.game_over, debug_check.button_pressed)
## The seed the next case starts with: the one typed in, or a fresh one if the box still
## holds this case's. The New Case screen builds a dynamic script from it.
func _next_case_seed() -> int:
	return int(seed_box.value) if int(seed_box.value) != _case_seed else NewCaseScreen.fresh_seed()
func _on_new_case_start(count: int, script_def, case_seed: int) -> void:
	for i in range(size_opt.item_count):
		if int(size_opt.get_item_metadata(i)) == count:
			size_opt.select(i)
	current_script = script_def
	seed_box.value = case_seed
	_new_case()
func _new_case_button() -> void:
	seed_box.value = _next_case_seed()
	_new_case()
func _new_case() -> void:
	if g != null and (g.workshop_presenting or g.meeting_streaming()):
		return
	conversation_finished = false
	_phase_held = false
	_deferred_log_events = []
	_day_pick = ""
	conversation_show_map = false
	inspect_pages.clear()
	_case_seed = int(seed_box.value)
	case_state.select_card(0)
	show_day_sightings = false
	if side_sightings_check != null:
		side_sightings_check.set_pressed_no_signal(false)
	g = Game.new()
	g.debug_overlay = debug_check.button_pressed
	g.decision_feed.console = roll_window.mirror.button_pressed
	headlines.clear()
	g.stream_meeting = true
	out.clear()
	_print(g.new_case(int(seed_box.value), int(size_opt.get_item_metadata(size_opt.selected)),
		current_script.duplicate_script() if current_script != null else null))
	_consume_headlines()
	# The Mistaken term's tooltip names only the causes this case's script allows.
	TextTerms.set_honest_causes(preload("res://workshop/reading_challenges.gd").game_honest_causes(g.w.case_script))
	case_view.set_game(g)
	profile.setup(g, case_state)
	cast_list.setup(g)
	notes_edit.text = g.case_notes
	map.set_game(g)
	_ward_target = ""
	meeting_view.set_game(g)
	if debug_check.button_pressed:
		g.set_debug_overlay(true)
	roll_window.set_feed(g.decision_feed)
	roll_button.visible = debug_check.button_pressed
	_refresh_all()
	if is_inside_tree() and show_script_at_start:
		Roles.open(self)
func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE and not case_view.visible:
		input.grab_focus()
func _open_case_view() -> void:
	case_view.refresh()
	case_view.visible = true

enum MoreItem { CAST, TIMELINE, SIDEBAR, LOG, WORKSHOP, NEW_CASE, SUSPICIONS, REDUCED_MOTION }

func _on_more(i: int) -> void:
	match i:
		MoreItem.CAST:
			_run("cast")
		MoreItem.TIMELINE:
			_run("timeline")
		MoreItem.SIDEBAR:
			side.visible = not side.visible
		MoreItem.LOG:
			_run("log")
		MoreItem.WORKSHOP:
			_open_live_workshop()
		MoreItem.NEW_CASE:
			_open_new_case_screen()
		MoreItem.SUSPICIONS:
			open_daily_guess(Callable())
		MoreItem.REDUCED_MOTION:
			reduced_motion = not reduced_motion

## The daily evil-team guess (ui/daily_guess.gd). `then(confirmed)` runs once it closes.
func open_daily_guess(then: Callable) -> void:
	if g == null or g.w.game_over or has_node("DailyGuess"):
		return
	DailyGuess.open(self, func(confirmed):
		_refresh_all()
		if then.is_valid():
			then.call(confirmed),
		func(): daily_guess_off_for = g)

## The grim reveal, once the case is over. The verdict is the private theory frozen before the
## final hanging when the case ended at a meeting (that day's guess window was the seal); after
## an overnight ending, the seal window opens once more first.
func open_reveal() -> void:
	if g == null or not g.w.game_over or has_node("GrimReveal") or has_node("DailyGuess"):
		return
	reveal_seen_for = g
	var verdict = sealed_verdict(g)
	if verdict == null:
		DailyGuess.open(self, func(_ok): RevealOverlay.open(self, g, sealed_verdict(g, true), Callable(), reduced_motion), Callable(), true)
		return
	RevealOverlay.open(self, g, verdict, Callable(), reduced_motion)

## The sealed verdict (person id -> guess), or null when the seal window must open first.
static func sealed_verdict(game, fallback: bool = false):
	if game.has_meta(DailyGuess.META_VERDICT):
		return game.get_meta(DailyGuess.META_VERDICT)
	if not game.prediction_snapshots.is_empty() and (fallback or ended_at_meeting(game)):
		var out: Dictionary = {}
		var frozen: Dictionary = game.prediction_snapshots[-1].get("guesses", {})
		for id in frozen:
			out[id] = str(frozen[id].get("guess", "?"))
		return out
	if fallback:
		var out2: Dictionary = {}
		for id in game.guesses:
			out2[id] = str(game.guesses[id].get("guess", "?"))
		return out2
	return null

## Whether the case ended at a meeting: no kill after the last frozen theory.
static func ended_at_meeting(game) -> bool:
	var last_snap: int = -1
	var entries: Array = game.w.dlog.entries
	for i in range(entries.size()):
		if entries[i]["type"] == "prediction_snapshot":
			last_snap = i
	if last_snap < 0:
		return false
	for i in range(last_snap + 1, entries.size()):
		if entries[i]["type"] == "kill":
			return false
	return true

## Closing the meeting: the daily guess comes first, unless it's off for this case.
func close_meeting() -> void:
	if daily_guess_off_for == g:
		_run("done")
		return
	open_daily_guess(func(_confirmed): _run("done"))
## The Case Workshop lives on the case board as a pull-out sheet.
func _open_live_workshop(number: int = 0) -> void:
	case_view.refresh()
	case_view.open_workshop(number)
func _run_workshop(cmd: String, progress: Callable) -> void:
	if conversation_finished or _phase_held:
		return
	var previous_state = g.state
	_print("\n> " + cmd)
	_print(await g.workshop_command(cmd, progress))
	_capture_conversation(previous_state, cmd)
	if not conversation_finished:
		_consume_headlines()
		_show_notes()
	if g.state == "talk" and g.talk_with != null:
		_select_person(g.talk_with.id)
	_refresh_all()
func _open_notes() -> void:
	notes_edit.text = g.case_notes
	notes_win.popup_centered()
func _open_theory() -> void:
	_open_case_view()
	case_view.open_theory()
func _on_submit(text: String) -> void:
	var t = text.strip_edges()
	input.clear()
	if t == "" or _presenting():
		return
	history.append(t)
	hist_i = history.size()
	_run(t)
func _run(cmd: String) -> void:
	# While a finished conversation or a reading holds the old phase, nothing runs until the
	# player leaves or presses Done: a command would clear the page and strand the hold (Codex, #369).
	if conversation_finished or _phase_held:
		return
	var previous_state = g.state
	_print("\n> " + cmd)
	if g.meeting_streaming() or g.workshop_presenting:
		_print(g.command(cmd))   # refused; no new events
		return
	var phase_before: Array = [g.w.day, g.w.phase, g.state in ["meeting", "nomination"]]
	var out: String = g.command(cmd)
	# A conversation that ran out of questions ended the phase too: what comes after it (the
	# next phase's header, the meeting's headline, who was silenced) waits in the log until
	# the player leaves the conversation, so the log never runs ahead of the scene.
	var verb0: String = cmd.strip_edges().get_slice(" ", 0).to_lower()
	var talk_ran_out: bool = previous_state == "talk" and g.state != "talk" and not verb0 in ["bye", "leave", "done"]
	var deferred_meeting: bool = false
	if talk_ran_out:
		var evs: Array = g.last_events
		var cut: int = -1
		for i in range(evs.size()):
			if str(evs[i].get("k", "")) in ["header", "headline"]:
				cut = i
				break
		if cut > 0:
			_deferred_log_events = evs.slice(cut)
			if g.state in ["meeting", "nomination"]:
				# The meeting itself waits too: the stage takes it up when they leave.
				deferred_meeting = true
				_deferred_meeting_events = evs.slice(cut)
				_deferred_log_events = []
				_print(Game.render(evs.slice(0, cut)))
			else:
				out = Game.render(evs.slice(0, cut))
	# A reading that ended the phase: what follows the next phase's header waits in the log
	# until the last page is done, like a conversation that ran out of questions.
	var read_ran_out: bool = verb0 in READING_VERBS and previous_state != "talk" and [g.w.day, g.w.phase, g.state in ["meeting", "nomination"]] != phase_before \
		and not g.last_events.any(func(e): return e.get("k", "") == "error")
	if read_ran_out and not g.state in ["meeting", "nomination"]:
		var revs: Array = g.last_events
		for i in range(revs.size()):
			if str(revs[i].get("k", "")) in ["header", "headline"]:
				if i > 0:
					_deferred_log_events = revs.slice(i)
					out = Game.render(revs.slice(0, i))
				break
	# What's said at the meeting reaches the log as the stage shows it (see _log_events).
	if not deferred_meeting and not _meeting_owns_log(previous_state):
		_print(out)
	if not deferred_meeting:
		_capture_meeting(previous_state)
	_capture_conversation(previous_state, cmd)
	_capture_scene_search(cmd)
	var released_now: bool = false
	if read_ran_out:
		if inspect_pages.is_empty():
			_release_phase()   # nothing to read: the new phase shows at once
			released_now = true   # and its headlines and notes have had their pass (Codex, #369)
		else:
			_phase_held = true
	if not conversation_finished and not _phase_held and not released_now:
		_consume_headlines()
		_show_notes()
	if g.meeting_streaming() and not conversation_finished and inspect_pages.is_empty():
		_stream_meeting()
		return
	if g.state == "talk" and g.talk_with != null:
		_select_person(g.talk_with.id)
	_refresh_all()
	if case_view.visible and case_view.workshop != null:
		case_view.workshop.refresh()
## A command's log goes through the stage when the meeting is (or was) on.
func _meeting_owns_log(previous_state: String) -> bool:
	return previous_state in ["meeting", "nomination"] or g.state in ["meeting", "nomination"]
func _log_events(evs: Array) -> void:
	var text: String = Game.render(evs)
	if text != "":
		_print(text)
## Something is still being shown (a speaker, a vote count, a trace, the town still
## speaking): nothing moves on until it's done (Nov 7). The action pane offers Continue.
func _presenting() -> bool:
	if g == null:
		return false
	return meeting_view.presenting() or g.meeting_streaming() or g.workshop_presenting or not inspect_pages.is_empty()
## What's said at the meeting comes forward on the courtroom stage (meeting plan M3a).
func _capture_meeting(previous_state: String) -> void:
	var was: bool = previous_state in ["meeting", "nomination"]
	if g.state in ["meeting", "nomination"] and not was:
		meeting_view.arrive()
	if was or g.state in ["meeting", "nomination"]:
		meeting_view.consume(g.last_events)
func _capture_conversation(previous_state: String, cmd: String) -> void:
	if g.state == "talk" and g.talk_with != null:
		if previous_state != "talk" or conversation_view.person_id != g.talk_with.id:
			conversation_show_map = false
			conversation_view.begin(g.talk_with.id, g.talk_with.name)
			conversation_view.set_location(g.loc)
		conversation_view.consume(g.last_events)
	elif previous_state == "talk":
		# The talk's last answer ends the phase: what follows the next phase's header (an
		# approach, say) belongs to the new phase, not this conversation (playtest triage 1.8).
		var talk_events: Array = []
		for ev in g.last_events:
			if ev.get("k") == "header":
				break
			talk_events.append(ev)
		conversation_view.consume(talk_events)
		var verb = cmd.strip_edges().get_slice(" ", 0).to_lower()
		if not verb in ["bye", "leave", "done"]:
			conversation_finished = true
			conversation_show_map = false
## A search that turns up crime-scene traces shows them in the conversation view, the item
## where the portrait goes; the log keeps the same text. Any other command closes it.
func _capture_scene_search(cmd: String) -> void:
	inspect_pages.clear()
	inspect_index = 0
	var verb: String = cmd.strip_edges().get_slice(" ", 0).to_lower()
	if verb in ["gossip", "records", "register", "town_hall", "inspect"]:
		_capture_place_reading(verb)
		return
	if verb not in ["search", "s"]:
		return
	var prose: Array = []
	var cards: Array = []
	for e in g.last_events:
		if e.get("k", "") == "narration" and cards.is_empty():
			prose.append(str(e.get("text", "")))
		elif e.get("k", "") == "card":
			var c: Dictionary = g.board[int(e["n"]) - 1]
			if c.get("kind", "") == "trace":
				cards.append(c)
	# Each trace's narration comes just before the cards are minted, in the same order.
	prose = prose.slice(maxi(0, prose.size() - cards.size()))
	for i in range(cards.size()):
		var c: Dictionary = cards[i]
		var victim = g.w.by_id.get(str(c.get("victim", "")))
		var place: String = ("%s's cottage" % victim.name) if victim != null else "The crime scene"
		var title: String = place if cards.size() == 1 else "%s · trace %d of %d" % [place, i + 1, cards.size()]
		var text: String = prose[i] if i < prose.size() and prose[i] != "" else str(c.get("text", ""))
		inspect_pages.append({"title": title, "texture": TraceArt.icon(c, "large"), "text": text})
	if not inspect_pages.is_empty():
		_show_inspect_page()
## Tavern gossip and Town Hall records come up in the conversation view over the building's
## interior, like a crime-scene trace: the building where the portrait goes, what you learned
## in the speech bubble. The log keeps the same text. Only the command's own narration, up to
## the next phase's header (gossip ends the evening), goes on the page.
func _capture_place_reading(verb: String) -> void:
	if g.last_events.any(func(e): return e.get("k", "") == "error"):
		return
	var text_parts: Array = []
	for e in g.last_events:
		var k: String = str(e.get("k", ""))
		if k in ["header", "headline"]:
			break
		if k == "narration" and str(e.get("text", "")).strip_edges() != "":
			text_parts.append(str(e.get("text", "")))
	if text_parts.is_empty():
		return
	var gossip: bool = verb == "gossip"
	var loc: String = "tavern" if gossip else "town_hall"
	var title: String = "The Drowned Lamb · evening gossip" if gossip else "The Town Hall · parish records"
	inspect_pages.append({"title": title, "texture": UITheme.tex("art/" + MapView.PAPER_ART.get(loc, ""), 0.5), "text": "\n".join(PackedStringArray(text_parts)),
		"loc": loc, "button": "Done"})
	_show_inspect_page()
func _show_inspect_page() -> void:
	var page: Dictionary = inspect_pages[inspect_index]
	conversation_view.set_location(str(page.get("loc", g.loc)))
	conversation_view.show_item(page.title, page.texture, page.text)
## The held phase shows: its log, headlines and notes.
func _release_phase() -> void:
	_phase_held = false
	if not _deferred_log_events.is_empty():
		_log_events(_deferred_log_events)
		_deferred_log_events = []
	_consume_headlines()
	_show_notes()
func _inspect_next() -> void:
	inspect_index += 1
	if inspect_index >= inspect_pages.size():
		inspect_pages.clear()
		inspect_index = 0
		if _phase_held:
			_release_phase()
		# A search that ended the evening: the meeting waited for you to finish reading.
		if g.meeting_streaming() and not conversation_finished:
			_stream_meeting()
			return
	else:
		_show_inspect_page()
	_refresh_all()
func _leave_finished_conversation() -> void:
	conversation_finished = false
	if not _deferred_log_events.is_empty():
		_log_events(_deferred_log_events)
		_deferred_log_events = []
	if not _deferred_meeting_events.is_empty():
		var evs: Array = _deferred_meeting_events
		_deferred_meeting_events = []
		if g.state in ["meeting", "nomination"]:
			meeting_view.arrive()
			meeting_view.consume(evs)
	_consume_headlines()
	if g.meeting_streaming():
		_stream_meeting()
	else:
		_refresh_all()
## Several commands from one click (e.g. walk to someone, then talk to them).
func _run_seq(cmds: Array) -> void:
	for c in cmds:
		var before = g.state
		_run(c)
		if g.meeting_streaming() or g.state == "approach" or _presenting():
			break
		if g.state == "over" or (before == g.state and g.last_events.any(func(e): return e.get("k", "") == "error")):
			break
## The meeting's testimony, one speaker at a time: the next speaker is worked out while the
## current one is on the stage, never more than one ahead, so the stage (and the log, which
## follows it) moves at the player's pace. Actions wait until the town has spoken.
const STREAM_GAP = 0.15   # seconds between speakers, at least (the work itself takes longer)

func _stream_meeting() -> void:
	_refresh_all()
	var game = g
	while game == g and g.meeting_streaming():
		await get_tree().process_frame
		if meeting_view.stage.waiting() > 0:
			continue
		var started: int = Time.get_ticks_msec()
		g.testimony_step()
		meeting_view.consume(g.last_events)
		_consume_headlines()
		meeting_view.refresh()
		Actions.refresh(self)   # Continue appears as soon as someone's on the stage
		var left: float = STREAM_GAP - (Time.get_ticks_msec() - started) / 1000.0
		if left > 0.0:
			await get_tree().create_timer(left).timeout
	_refresh_all()
	if case_view.visible and case_view.workshop != null:
		case_view.workshop.refresh()
## Finish a streamed meeting at once (tests and scripted clicks that can't wait).
func finish_streaming() -> void:
	while g != null and g.meeting_streaming():
		g.testimony_step()
		meeting_view.consume(g.last_events)
		_consume_headlines()
	_refresh_all()
var _last_phase_key = ""
var _day_pick: String = ""   # the person you clicked this phase (the profile panel's default doesn't count)

func _refresh_all() -> void:
	if conversation_finished or _phase_held:
		# The talk's last answer (or a reading: the records, gossip, a scene's traces) has
		# already ended the phase in the game, but the screen holds the old one (the clock, the
		# map, the townsfolk and the cards) until the player leaves the conversation or finishes
		# reading (Michael, Nov 19). Nothing the player does can come between, so this changes
		# only when they see it.
		Actions.refresh(self)
		cast_list.freeze()
		map_stage.visible = true
		conversation_view.visible = true
		meeting_view.visible = false
		map_return.visible = false
		input.editable = false
		return
	cast_list.thaw()
	Actions.sync_approach(self, not inspect_pages.is_empty())
	if roles_pinned and roles_showing and _roles_signature != Roles.state_key(self):
		Roles.build(self, roles_content.get_parent() == roles_dock)
	# The map follows you: zoom to your block once you've moved; back out for a new phase.
	var key = "%d:%d:%s" % [g.w.day, g.w.phase, g.state if g.state in ["night", "meeting", "nomination", "over"] else "day"]
	if key != _last_phase_key:
		_last_phase_key = key
		map.zoom_block = ""
		map.selected_block = ""
		_day_pick = ""
	if g.state in ["day", "talk", "approach"] and g.moved:
		map.zoom_block = g.w.loc_block(g.loc)
	_refresh_side()
	Actions.refresh(self)
	var meeting = g.state in ["meeting", "nomination"]
	if not meeting or (g.state == "nomination" and _last_state != "nomination") or (g.state == "meeting" and _last_state == "nomination") or meeting_view.presenting():
		meeting_show_map = false  # a vote starting (or being counted), or anyone speaking, brings the circle back
	_last_state = g.state
	var last_words: bool = not meeting and meeting_view.stage_busy()   # the gallows, after the meeting closes
	var reading: bool = not inspect_pages.is_empty()   # traces from the evening's search come before the meeting
	map_stage.visible = conversation_finished or reading or (not meeting and not last_words) or meeting_show_map
	conversation_view.visible = conversation_finished or (g.state == "talk" and not conversation_show_map) or reading or (g.state == "approach" and approach_stage != "")
	meeting_view.visible = (meeting or last_words) and not meeting_show_map and not conversation_finished and not reading
	var in_talk_map: bool = g.state == "talk" and conversation_show_map and not conversation_view.visible
	var in_meeting_map: bool = meeting and meeting_show_map and map_stage.visible
	map_return.visible = in_talk_map or in_meeting_map
	map_return.text = "Return to conversation" if in_talk_map else "Return to meeting"
	input.editable = not conversation_finished and not _presenting()
	if meeting:
		meeting_view.refresh()
	else:
		meeting_view.finish()
	map.refresh()
	cast_list.refresh()
	cast_header.text = "Townsfolk · %d alive" % g.w.living().size()
	var night = g.state == "night"
	day_icon.texture = UITheme.tex("ui/moon" if night else "ui/sun", 0.15)
	day_label.text = ("Night %d" % g.w.day) if night else ("Day %d · %s" % [g.w.day, "Town meeting" if g.state in ["meeting", "nomination"] else C.PHASES[g.w.phase]])
	if case_view.visible:
		case_view.refresh()
## Show this person's profile in the sidebar and the case view.
func _side_person_id() -> String:
	return profile.current()
func _select_person(id: String) -> void:
	case_state.select_person(id)
	profile.show_person(id)
	case_view.show_profile(id)
	_refresh_profile()
func _on_town_person_clicked(id: String) -> void:
	var selected: String = "" if cast_list.selected == id else id
	_day_pick = id   # their profile stays up either way
	cast_list.selected = selected
	map.selected_npc = selected
	if selected != "":
		_select_person(selected)
	cast_list.refresh()
	map.refresh()
	if g.state == "night":
		_ward_target = selected
	if g.state in ["day", "night"]: Actions.refresh(self)
# ---------------------------------------------------------------- coloured log

func _print(s: String) -> void:
	log_text.append_to(out, s)
func _swatch(c: Color) -> ImageTexture:
	var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)
# ---------------------------------------------------------------- map clicks

func _on_map_clicked(kind: String, id: String) -> void:
	if _presenting() and kind != "npc":
		return
	if kind == "npc":
		_day_pick = id
		_select_person(id)
		if g.state == "day": Actions.refresh(self)
		if g.state == "night":
			_ward_target = id
	match g.state:
		"day":
			var w = g.w
			match kind:
				"block", "back":
					Actions.refresh(self)
				"location", "scene":
					if not g.moved:
						_run("go " + id)
					elif id != g.loc and w.loc_block(id) == w.loc_block(g.loc) and not g.free_move_used:
						_run("go " + id)
					elif id != g.loc:
						_print("(You've already chosen where to spend this phase.)")
				"home":
					var hn = w.by_id[id]
					if not (hn.alive and hn.at_home()):
						_print("(Nobody's home at %s's just now. You can only call on someone who's in.)" % hn.name)
					elif not g.moved or (not g.free_move_used and w.loc_block("home_" + id) == w.loc_block(g.loc)):
						_run("go " + id)
					else:
						_print("(%s is in, but you've already chosen where to spend this phase.)" % hn.name)

		"night":
			Actions.refresh(self)
	map.refresh()
## The map's "Return to conversation" / "Return to meeting" button.
func _on_map_return() -> void:
	if g == null:
		return
	if g.state == "talk":
		conversation_show_map = false
	else:
		meeting_show_map = false
	_refresh_all()
## Informational notes (never a confirmation): a short toast that fades on its own.
func _show_notes() -> void:
	for e in g.last_events:
		if e.get("k", "") != "note":
			continue
		var panel = PanelContainer.new()
		var lbl = Label.new()
		lbl.text = e.text
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(420, 0)
		panel.add_child(lbl)
		add_child(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		panel.position.y -= 160
		get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(panel):
				panel.queue_free())
# ---------------------------------------------------------------- side panels

## A daytime location sighting: anyone seen somewhere by day, people's own "I was at the
## mill" accounts included (Michael, Nov 19). Night sightings stay.
static func is_day_sighting(c: Dictionary) -> bool:
	if c.get("kind", "") != "sighting" or c.get("phase") == null:
		return false
	return int(c["phase"]) != C.NIGHT
## The "Show daytime sightings" box; toggling it updates the shared setting, then `refill`.
func _day_sightings_check(refill: Callable) -> CheckBox:
	var box = CheckBox.new()
	box.text = "Show daytime sightings"
	box.tooltip_text = "Sightings of people about town by day are hidden to keep the list short."
	box.button_pressed = show_day_sightings
	box.toggled.connect(func(on):
		show_day_sightings = on
		if side_sightings_check != null and side_sightings_check != box:
			side_sightings_check.set_pressed_no_signal(on)
		refill.call()
		if box != side_sightings_check:
			_refresh_side())
	return box
func _refresh_side() -> void:
	if g == null or side_list == null:
		return
	theory_label.text = g.theory_status()
	if not g.w.game_over:
		theory_label.text += " — Record your demon guess before voting; it costs no time."
	side_list.reset()
	side_list.context_numbers = EvidenceContext.numbers(g)
	var cards: Array = g.filter_cards(side_filter.text)
	cards.reverse()
	if not show_day_sightings:
		cards = cards.filter(func(c): return not is_day_sighting(c))
	for c in cards.slice(0, 60):
		var col = null
		if c.get("hidden", false):
			col = Color(0.45, 0.45, 0.5)
		elif c["kind"] == "deduction":
			col = Color(0.95, 0.8, 0.45)
		else:
			col = CardList.tint_for(c)
		var dbg = g.debug_card_text(c) if g.debug_overlay else ""
		side_list.add("%s%s" % [CardList.line_for(c), ("\n      ⟨" + dbg + "⟩") if dbg != "" else ""], c["n"], c["text"], CardList.color_for(c, col))
	_refresh_profile()
func _refresh_profile() -> void:
	if g != null:
		profile.refresh()
func _on_input_key(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not history.is_empty():
		if ev.keycode == KEY_UP:
			hist_i = max(0, hist_i - 1)
			input.text = history[hist_i]
			input.caret_column = input.text.length()
		elif ev.keycode == KEY_DOWN:
			hist_i = min(history.size(), hist_i + 1)
			input.text = history[hist_i] if hist_i < history.size() else ""
			input.caret_column = input.text.length()
