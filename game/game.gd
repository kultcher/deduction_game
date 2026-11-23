## Player-facing game layer: command interpreter, case board, structured output.
##
## Every command produces a list of structured events in `last_events`
## ({k: kind, ...}); `command()` also returns them rendered as text. A future UI can read
## the events and the board directly instead of parsing text.
## Event kinds: header, narration, speech {speaker, name, text}, card {n}, prompt, error, screen.
##
## The work lives in the game_* modules (game_board, game_conversation, game_day_night,
## game_meeting, game_presentation, game_screens), which take the game as their first
## argument: call them directly (`GameBoard.add_card(g, fact)`), not through a forward here.
## The one-line forwards that remain are kept on purpose, as the game's interface for the UI
## and the command line (Michael, Nov 19; Seneschal, Nov 20): already_public, can_see,
## can_see_ui, debug_card_text, debug_npc_text, delete_deduction, filter_cards, hide_card,
## meeting_streaming, offer_text, on_deck_case, profile_data, protection_label,
## set_debug_overlay, set_guess, set_secret_guess, testimony_step, theory_status,
## unseen_at_ui, vote_requirement_text, workshop_ghost_preview, workshop_preview and
## workshop_retract.
extends RefCounted
## Refusal for a typed "withdraw" away from the meeting (draft wording, with Michael).
const WITHDRAW_OUTSIDE_MEETING = "You can only take back a case before the whole town, at the meeting."

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const World = preload("res://sim/world.gd")
const RoleDef = preload("res://sim/role_def.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const Deduction = preload("res://sim/deduction.gd")
const Evil = preload("res://sim/evil.gd")
const CaseMetrics = preload("res://game/case_metrics.gd")
const CardModel = preload("res://game/card_model.gd")
const RecentSightings = preload("res://game/recent_sightings.gd")
const WorkshopBridge = preload("res://game/workshop_bridge.gd")
const WorkshopOwnership = preload("res://game/workshop_ownership.gd")
const WorkshopPresentation = preload("res://game/workshop_presentation.gd")
const WorkshopGhost = preload("res://workshop/ghost_juror.gd")
const WorkshopAssessment = preload("res://workshop/live_assessment.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const WorkshopProfiler = preload("res://workshop/profiler.gd")
const GameBoard = preload("res://game/game_board.gd")
const GamePresentation = preload("res://game/game_presentation.gd")
const GameConversation = preload("res://game/game_conversation.gd")
const GameMeeting = preload("res://game/game_meeting.gd")
const GameDayNight = preload("res://game/game_day_night.gd")
const GameScreens = preload("res://game/game_screens.gd")

var w
var state = "day"          # day | approach | talk | meeting | nomination | night | over
var approach = {}          # pending approach: {npc, agenda}
var approached_id = ""     # npc who approached at the start of this phase
var approached_loc = ""    # location named in that approach
var moved = false          # has the player chosen a location this phase
var free_move_used = false
var loc = ""
var talk_with = null
var questions_left = 0
var free_repeats = 0       # repeats this conversation that cost no question (one allowed)
var board: Array = []
var profile_receipts: Array = []
var _card_keys = {}
var _fact_keys = {}      # Mind.fact_id -> card number, for facts that can reach you twice
var _profile_card_keys = {}
var _profile_fact_keys = {}
var case_notes = ""       # the player's free-form notes on the case
var town_quiet = false     # the town has had its say since the last nomination (allows 'done')
var talk_approached = false  # this conversation began with them approaching you (it costs the phase)
var statement_used = false # the player has put their one case on the pending nomination
var presented_today = false # player has had the meeting floor today
var public_presentations = {} # card number -> the day you last put that case to the town (floor, nomination, statement)
var public_citations = {}     # card numbers of plain cards you've cited at a meeting
var town_vibe_heard = {}      # the town's opinion of you when you last heard it at the tavern
var notes = {}              # npc id -> player's note
var guesses = {}            # npc id -> {guess, confidence 1..3}
var guess_history: Array = []
var prediction_snapshots: Array = []
var prediction_spoiled = false
var case_summary: Dictionary = {}
var show_hidden = false     # include cards the player has hidden
var sigil_heard = {} # Receipt number -> listener IDs; trust rewards are once per NPC per sigil.
var shown_protection = {} # Receipt number -> true: a ward or sigil already shown to the whole town (it doesn't take the floor)
var ward_log = {}           # night -> who you warded
## Promises for tonight: {"ward": id, "vigil": {id: block}}. Kept or broken when you choose
## your night work.
var offer = {}
var talk_offered = false
## The UI streams the meeting's testimony (testimony_step) instead of computing it all at
## once; headless/text play leaves this off and gets the whole meeting in one command.
var stream_meeting = false
var _testimony = {}   # streamed testimony in progress (Mind.testimony_start state)
## Something the person you're talking to asked of you (free to answer): {kind, npc, ...}
## kind "confidence" (keep it quiet) or "protect" (a ward or vigil tonight).
var pending_request = {}
## Promised their gift once you'd kept a ward/vigil promise: id -> true until tonight settles.
var protect_pending = {}
## Kept that promise: they come to tell you the next day, at no cost. [ids]
var divulge_due: Array = []
## Where people go when they're not working: unknown at the start; you learn it by asking
## others about them. id -> [location ids].
var known_haunts = {}
var regulars_searched = {}   # place -> true: a place's regulars can be asked about once per game
var haunt_sightings = {}     # "npc:place" -> [days]: the player saw them idling there
var watched = []             # [{day, phase, block, at: {loc: [ids]}}]: who the player saw at each public place on the block they spent a day phase on
var known_relationships = {} # Public town bonds actually learned, with their source.
# Every refresh or presentation the shared model couldn't prepare (the mind kept its last
# good beliefs; always recorded, with or without detailed tracing). See the `fallbacks` command.
var unprepared_refreshes: Array = []
var _unprepared_reported = 0
const DecisionFeed = preload("res://sim/decision_feed.gd")
const WorkshopCaches = preload("res://workshop/caches.gd")
const Credibility = preload("res://game/credibility.gd")
var decision_feed = DecisionFeed.new()

var debug_overlay = false   # show NPCs' hidden credence (spoils identification credit)
var last_error = ""         # why the last file_deduction was refused
var log_dir = "user://logs"
var log_paths: Array = []
var debug = false
var detailed_logging = true  # developer tracing, independent of spoiler/debug scoring
var workshop_compare = false # opt-in diagnostics; never applies the proposed effects
## Opt-in diagnostics: after each presented case, record why each listener moved as far as
## they did (game/workshop_why.gd). Read-only; costs several union evaluations per listener.
var workshop_why = false
var workshop_whys: Array = []
var _workshop_repeats: Dictionary = {}
var _workshop_busy = false
var _workshop_plans = {}
var _workshop_evaluations = {}
var _workshop_reason_ctx = {} # deferred reason attribution inputs per mind (purge 2a)
var _workshop_responses = {}
var workshop_comparisons: Array = []
var workshop_draft: Dictionary = {} # case-local canvas layout and filed premise numbers
var workshop_deliveries: Array = [] # each listener who heard a filed case, with any issues
var workshop_presenting = false
var trace_build = ""
var trace_tuning = ""
var _trace_export_pending = false
var events: Array = []
var last_events: Array = []

# ---------------------------------------------------------------- events

func _ev(e: Dictionary) -> void:
	if e.has("text"):
		e["text"] = C.natural_nights(e["text"])
	events.append(e)

func _headline(kind: String, text: String, subtitle: String = "") -> void:
	_ev({"k": "headline", "kind": kind, "text": text, "subtitle": subtitle})

func _hdr(t: String) -> void:
	_ev({"k": "header", "text": t})
	if t.begins_with("Night "):
		_headline("nightfall", "Night %d Falls" % w.day)
	elif t.begins_with("Day "):
		_headline("dawn" if t.ends_with(", Morning") else "phase", "Day %d Dawns" % w.day if t.ends_with(", Morning") else t)

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
		GameConversation._remember_spoken_relationship(self, x)
		# The unvoiced statement rides along for logs and tests; the UI shows the text.
		var event = {"k": "speech", "speaker": x["speaker"], "name": x["name"], "text": x["text"], "statement": x.get("statement", x["text"])}
		if x.has("expression"):
			event["expression"] = x["expression"]
			event["expression_strength"] = x.get("expression_strength", 1)
		# A summarised meeting answer (Michael, Nov 19): the representative carries who agreed;
		# the others' own words go to the log only.
		for key in ["agree", "agree_more", "bundled"]:
			if x.has(key):
				event[key] = x[key]
		_ev(event)
	else:
		_narr(str(x))

func _lines(arr: Array) -> void:
	for x in arr:
		_line(x)

## Cards told to you in confidence: card number -> the NPC who asked you to keep it quiet.
var confidences = {}


static func render(evs: Array) -> String:
	var lines = PackedStringArray()
	var pending: Array = []
	for e in evs:
		if e["k"] == "headline":
			continue # UI side channel; never flush/reorder the existing log or card tags.
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

## `case_script` (sim/script_def.gd): what may be in play; null deals the Default script.
func new_case(seed_in: int, npc_count: int = 7, case_script = null) -> String:
	if workshop_presenting:
		return "A case presentation is still being assessed."
	# Each case starts from empty shared-model memo tables (and picks up tuning changes).
	WorkshopCaches.clear_all()
	workshop_draft = {}
	public_presentations = {}
	public_citations = {}
	town_vibe_heard = {}
	workshop_deliveries = []
	workshop_comparisons = []
	workshop_whys = []
	_workshop_plans = {}
	_workshop_evaluations = {}
	_workshop_reason_ctx = {}
	_workshop_responses = {}
	_workshop_repeats = {}
	board = []
	profile_receipts = []
	confidences = {}
	_card_keys = {}
	_fact_keys = {}
	_profile_card_keys = {}
	_profile_fact_keys = {}
	case_notes = ""
	notes = {}
	guesses = {}
	guess_history = []
	prediction_snapshots = []
	prediction_spoiled = false
	case_summary = {}
	log_paths = []
	ward_log = {}
	sigil_heard = {}
	shown_protection = {}
	_testimony = {}
	offer = {}
	talk_offered = false
	known_haunts = {}
	regulars_searched = {}
	haunt_sightings = {}
	watched = []
	known_relationships = {}
	unprepared_refreshes = []
	_unprepared_reported = 0
	show_hidden = false
	last_error = ""
	_trace_export_pending = false
	var console_rolls: bool = decision_feed.console
	decision_feed = DecisionFeed.new()
	decision_feed.enabled = debug_overlay
	decision_feed.console = console_rolls
	w = World.new()
	w.attach_decision_feed(decision_feed)
	w.detailed_logging = detailed_logging
	w.trace_build = trace_build
	w.trace_tuning = trace_tuning
	w.case_script = case_script
	w.setup(seed_in, npc_count, func(_world): _attach_workshop_world())
	RoleDef.script_secrets = w.case_script.secrets.duplicate() if w.case_script != null else []
	if debug_overlay: set_debug_overlay(true)
	w.dlog.begin_action("new_case_presentation")
	state = "day"
	moved = false
	approached_id = ""
	approached_loc = ""
	events = []
	GameScreens._intro(self)
	GameDayNight._morning_report(self)
	GameConversation._maybe_approach(self)
	return _finish_command("new_case", "")

## Where everyone lives is common knowledge: one card per resident, so arguments about
## where someone could have walked at night can cite it.
func _attach_workshop_world() -> void:
	var weak_game = weakref(self)
	var weak_world = weakref(w)
	w.workshop_refresh = func(n):
		var game = weak_game.get_ref()
		if game != null and game.w == weak_world.get_ref():
			WorkshopOwnership.refresh(game, n)
	w.workshop_reasons = func(n):
		var game = weak_game.get_ref()
		if game != null and game.w == weak_world.get_ref():
			WorkshopOwnership.reasons_for(game, n)
	w.workshop_roots = func(card):
		var game = weak_game.get_ref()
		if game == null or game.w != weak_world.get_ref():
			return {"complete": false, "receipts": {}}
		var proof = WorkshopOwnership.Shared.roots([card], GameBoard.all_receipts(game))
		if card.get("kind") == "deduction" and card.get("n", 0) > 0:
			var captured = GamePresentation.workshop_snapshot(game, [card.n])
			var endorsed: Array = WorkshopOwnership.Shared.endorsed_facts(captured, card.n)
			for id in proof.receipts.keys():
				if id not in endorsed:
					proof.receipts.erase(id) # Quoting a case is not endorsing its accounts.
		return proof
	w.workshop_present = func(n, card, targets, direction, venue, speak):
		var game = weak_game.get_ref()
		if game == null or game.w != weak_world.get_ref():
			return {}
		return WorkshopPresentation.present(game, n, card, targets, direction, venue, speak)
	GameBoard._home_cards(self)


## Canvas capability status for the current command: it already checks the whole
## audience, so computing it once per listener made a presentation O(listeners^2).
var _canvas_status_memo: Dictionary = {}

func command(line: String) -> String:
	if workshop_presenting:
		return "A case presentation is still being assessed."
	if meeting_streaming():
		return "The town is still speaking."
	var text = line.strip_edges()
	if text == "":
		return ""
	_canvas_status_memo = {}
	events = []
	if w != null:
		w.set_log_time()
		w.dlog.begin_action("command", {"cmd": text})
		w.trace_capture("before_command")
	_dispatch(text)
	if w.game_over and state != "over":
		state = "over"
		GameScreens._ending(self)
	return _finish_command("command", text)

## Canvas town presentations yield BETWEEN listeners. Each listener assessment is
## still atomic; action limits, disclosure, speech, voting and trace boundaries
## are the very same handlers as the synchronous command interface.
func workshop_command(line: String, progress: Callable) -> String:
	if workshop_presenting:
		return "A case presentation is still being assessed."
	var parts = line.split(" ", false, 1)
	if parts.size() != 2 or not ((state == "meeting" and parts[0] in ["present", "nominate"]) or (state == "nomination" and parts[0] == "case")):
		return command(line)
	workshop_presenting = true
	events = []
	w.set_log_time()
	w.dlog.begin_action("command", {"cmd": line})
	w.trace_capture("before_command")
	if state == "meeting" and parts[0] == "nominate":
		await GameMeeting._player_nomination(self, parts[1], progress)
	elif state == "meeting":
		await GamePresentation._present_deduction(self, parts[1], progress)
	else:
		await GameMeeting._nomination_command(self, parts[0], parts[1], progress)
	workshop_presenting = false
	if w.game_over and state != "over":
		state = "over"
		GameScreens._ending(self)
	return _finish_command("command", line)

## Write World.state_digest after every command and Workshop filing (the replay compares
## them, tools/log_replay.gd). Developer switch; on by default.
var state_digests: bool = true

func _finish_command(kind: String, cmd: String) -> String:
	last_events = events.duplicate()
	var out = render(events)
	if w != null:
		w.set_log_time()
		w.dlog.add("player_" + kind, "player", "", {"cmd": cmd, "output": out})
		if state_digests:
			w.dlog.add("state_digest", "", "", w.state_digest())
		w.trace_capture("after_" + kind)
		w.dlog.end_action()
		# Endings/manual exports can occur inside dispatch. Flush again only after
		# the final state and action_end have been recorded.
		if _trace_export_pending:
			_trace_export_pending = false
			var error = w.dlog.write_trace_file(log_dir, "case_%d" % w.seed_value)
			if error != OK:
				push_error("Detailed trace export failed: %s" % error_string(error))
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
	if t in ["town hall", "townhall", "hall", "town_hall"]:
		return "town_hall"
	for l in w.player_locations():
		if l == t:
			return l
	for l in w.player_locations():
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


# ---------------------------------------------------------------- corroboration

## What a card says happened, independent of who said it: "who was where, when" for each
## person it places, and "these two talked" for a conversation. Two cards from different
## sources that share a key back each other up.
static func core_keys(card: Dictionary) -> Array:
	return GameBoard.core_keys(card)

func _corroborate(card: Dictionary, src: String) -> void:
	GameBoard._corroborate(card, src)


func _disclose(card: Dictionary, disc: Dictionary) -> void:
	GameBoard._disclose(card, disc)


func workshop_preview(number: int, listener_id: String, venue: String = "private") -> Dictionary:
	return GamePresentation.workshop_preview(self, number, listener_id, venue)

func workshop_ghost_preview(number: int) -> Dictionary:
	return GamePresentation.workshop_ghost_preview(self, number)


## Conclusion types named by issues that are only about the conclusion ("Unsupported
## claim: role"), or [] if any issue is about the evidence itself.
func _unsupported_conclusions(issues: Array) -> Array:
	return GamePresentation._unsupported_conclusions(issues)


func workshop_retract(number: int, listener_id: String) -> void:
	GamePresentation.workshop_retract(self, number, listener_id)


# ---------------------------------------------------------------- dispatch

func _dispatch(text: String) -> void:
	var parts = text.split(" ", false)
	var verb = parts[0].to_lower()
	var rest = " ".join(parts.slice(1))
	match verb:
		"help", "?", "h":
			_screen(GameScreens._help(self))
			return
		"fallbacks":
			_screen(GameDayNight._fallbacks_text(self))
			return
		"look", "l":
			GameScreens._look(self)
			return
		"map", "m", "town":
			_screen(GameScreens._map(self))
			return
		"cast", "people", "who":
			_screen(GameScreens._cast(self))
			return
		"board", "b":
			_screen(GameScreens._board(self, rest))
			return
		"timeline", "tl":
			_screen(GameBoard._timeline(self, rest))
			return
		"hide", "unhide":
			_narr(hide_card(rest.strip_edges().trim_prefix("#").to_int(), verb == "hide"))
			return
		"delete":
			_narr(delete_deduction(rest.strip_edges().trim_prefix("#").to_int()))
			return
		"withdraw", "takeback":
			var wnum: int = rest.strip_edges().trim_prefix("#").to_int()
			# Taking a case back is a public act, so only at the town meeting, as the button
			# is (Steward, Nov 19: typed, it reached every listener at night or in private).
			if state != "meeting":
				_err(WITHDRAW_OUTSIDE_MEETING)
				return
			var werr: String = GamePresentation.workshop_withdraw_public(self, wnum)
			if werr != "":
				_err(werr)
			else:
				_narr("You stand and take back case #%d." % wnum)
			return
		"showhidden":
			show_hidden = not show_hidden
			_narr("Hidden cards are now %s." % ("shown" if show_hidden else "hidden"))
			return
		"link", "conclude", "deduce":
			_err("Cases are built in the Case Workshop now (the old link / conclude commands are retired).")
			return
		"note":
			var p0 = rest.split(" ", false)
			var nn = find_npc(p0[0], true) if p0.size() > 0 else null
			if nn == null:
				_err("Usage: note <name> <text>")
			else:
				GameScreens.set_note(self, nn.id, " ".join(p0.slice(1)))
				_narr("Noted.")
			return
		"guess":
			var p1 = rest.split(" ", false)
			var gn = find_npc(p1[0], true) if p1.size() > 1 else null
			if gn == null:
				_err("Usage: guess <name> <role | evil | good | ?> [1-4: flimsy, maybe, likely, confirmed]")
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
				_prompt("Record privately with 'guess <name> demon [1-4]' and 'guess <name> <minion gift> [1-4]', or use a profile's Your guess. This costs no time and gives no correctness feedback.")
			return
		"profile", "p":
			_screen(GameScreens._profile(self, rest))
			return
		"roles", "script":
			_screen(GameScreens._script(self))
			return
		"tools":
			_screen(GameScreens._tools(self))
			return
		"log":
			_narr(GameScreens._write_logs(self))
			return
		"grimoire":
			if debug or state == "over":
				if not w.game_over:
					prediction_spoiled = true
					w.dlog.add("prediction_spoiled", "player", "", {}, "Opened the hidden grimoire before the case ended; identification credit disabled.")
				var sub: String = rest.strip_edges().to_lower()
				_screen(GameScreens._lies(self) if sub == "lies" else (GameScreens._exchanges(self) if sub in ["talk", "shares", "exchanges"] else GameScreens._grimoire(self)))
			else:
				_err("The grimoire is sealed until the case ends.")
			return
	if state == "over":
		_err("The case is closed. Type 'grimoire' (or 'grimoire lies') for the full reveal, or start a new case.")
		return
	match state:
		"day":
			GameDayNight._day_command(self, verb, rest)
		"approach":
			GameConversation._approach_command(self, verb, rest)
		"talk":
			GameConversation._talk_command(self, verb, rest)
		"meeting":
			GameMeeting._meeting_command(self, verb, rest)
		"nomination":
			GameMeeting._nomination_command(self, verb, rest)
		"night":
			GameDayNight._night_command(self, verb, rest)


# ---------------------------------------------------------------- day & night forwarders


func unseen_at_ui(l: String) -> int:
	return GameDayNight.unseen_at_ui(self, l)

func can_see(n) -> bool:
	return GameDayNight.can_see(self, n)

func can_see_ui(n) -> bool:
	return GameDayNight.can_see_ui(self, n)


# ---------------------------------------------------------------- conversation forwarders

const OBSERVABLE_TRAITS = GameConversation.OBSERVABLE_TRAITS
const TRAIT_WORDS = GameConversation.TRAIT_WORDS
const MAX_BONDS_TOLD = GameConversation.MAX_BONDS_TOLD


func _repeat_refusal(n, response: Dictionary) -> void:
	GameConversation._repeat_refusal(n, response)


func _grievance_menu(n) -> String:
	return GameConversation._grievance_menu(n)

static func grievance_text(g: Dictionary) -> String:
	return GameConversation.grievance_text(g)


func offer_text() -> String:
	return GameConversation.offer_text(self)


# ---------------------------------------------------------------- meeting forwarders


func meeting_streaming() -> bool:
	return GameMeeting.meeting_streaming(self)

func testimony_step() -> String:
	return GameMeeting.testimony_step(self)


func vote_requirement_text() -> String:
	return GameMeeting.vote_requirement_text(self)


# ---------------------------------------------------------------- case work (stage 3)
# Data API used by the UI panel as well as the text commands.

## Filter the board. Accepts card kind, evidence class, person, block, location, day
## ("d2") or night ("n1"), or any text in the card.
## Filter the board by a text query. Terms joined with "+" must all match ("greta+night"):
## a person (by, about or via), a block or place, a kind or class, d2 / n1 (a day or a
## night), "night" / "day", or any text.
func filter_cards(filter: String) -> Array:
	return GameBoard.filter_cards(self, filter)


## A deduction resting on someone's confessed secret spreads it, just like citing it.
## Meeting plan M2a, for the nomination picker: the case on deck against `id`, every live
## case that names them, and whether a card or case is already public.
func on_deck_case(id: String) -> Dictionary:
	return GameMeeting.on_deck_case(self, id)

func cases_naming(id: String) -> Array:
	return board.filter(func(c): return c.get("kind", "") == "deduction" and not c.get("deleted", false) and not c.get("withdrawn", false) and int(c.get("superseded_by", 0)) == 0 and GameMeeting._case_names(c, id))

func already_public(card: Dictionary) -> bool:
	return GameMeeting.already_public(self, card)


## Hide a card from views (any card), or delete one of your own deductions.
func hide_card(num: int, on: bool) -> String:
	return GameBoard.hide_card(self, num, on)

func delete_deduction(num: int) -> String:
	return GameBoard.delete_deduction(self, num)


func protection_label(card: Dictionary) -> String:
	return GamePresentation.protection_label(self, card)


func _abbr(b: String) -> String:
	return GameBoard._abbr(b)


# ---------------------------------------------------------------- screens & theory forwarders


func set_guess(id: String, guess: String, confidence: int) -> bool:
	return GameScreens.set_guess(self, id, guess, confidence)

func set_secret_guess(id: String, secret: String, confidence: int) -> bool:
	return GameScreens.set_secret_guess(self, id, secret, confidence)


func theory_status() -> String:
	return GameScreens.theory_status(self)

func set_debug_overlay(on: bool) -> void:
	GameScreens.set_debug_overlay(self, on)

func debug_card_text(card: Dictionary) -> String:
	return GameScreens.debug_card_text(self, card)

func debug_npc_text(id: String) -> String:
	return GameScreens.debug_npc_text(self, id)

func _death_text(n) -> String:
	return GameScreens._death_text(n)

func profile_data(id: String) -> Dictionary:
	return GameScreens.profile_data(self, id)
