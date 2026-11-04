## Player-facing game layer: command interpreter, case board, structured output.
##
## Every command produces a list of structured events in `last_events`
## ({k: kind, ...}); `command()` also returns them rendered as text. A future UI can read
## the events and the board directly instead of parsing text.
## Event kinds: header, narration, speech {speaker, name, text}, card {n}, prompt, error, screen.
extends RefCounted

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const World = preload("res://sim/world.gd")
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
var statement_used = false # player's one statement on the pending nomination
var presented_today = false # player has had the meeting floor today
var notes = {}              # npc id -> player's note
var guesses = {}            # npc id -> {guess, confidence 1..3}
var guess_history: Array = []
var prediction_snapshots: Array = []
var prediction_spoiled = false
var case_summary: Dictionary = {}
var show_hidden = false     # include cards the player has hidden
var sigil_heard = {} # Receipt number -> listener IDs; trust rewards are once per NPC per sigil.
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
var known_relationships = {} # Public town bonds actually learned, with their source.
var fallback_count = 0      # times 'present' couldn't tell what a card was meant to prove
# Every time the legacy rules judged something the shared model couldn't read (always
# recorded, with or without detailed tracing). See the `fallbacks` command.
var shared_fallbacks: Array = []
var _fallbacks_reported = 0
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
## Opt-in test assertion: unsupported presentations are rejected before any effects.
var strict_evaluator = C.STRICT_EVALUATOR
var _workshop_native_submission = false
var _workshop_native_social = false  # a bare belief with no evidence: social speech, not a fallback
var _workshop_repeats: Dictionary = {}
var _workshop_busy = false
var _workshop_plans = {}
var _workshop_evaluations = {}
var _workshop_reason_ctx = {} # deferred reason attribution inputs per mind (purge 2a)
var _workshop_responses = {}
var workshop_comparisons: Array = []
var workshop_draft: Dictionary = {} # case-local canvas layout and filed premise numbers
var workshop_deliveries: Array = [] # explicit actual model/fallback feedback
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
		_remember_spoken_relationship(x)
		# The unvoiced statement rides along for logs and tests; the UI shows the text.
		var event = {"k": "speech", "speaker": x["speaker"], "name": x["name"], "text": x["text"], "statement": x.get("statement", x["text"])}
		if x.has("expression"):
			event["expression"] = x["expression"]
			event["expression_strength"] = x.get("expression_strength", 1)
		_ev(event)
	else:
		_narr(str(x))

func _lines(arr: Array) -> void:
	for x in arr:
		_line(x)

## Cards told to you in confidence: card number -> the NPC who asked you to keep it quiet.
var confidences = {}

## Using a confidential card at the meeting breaks your word to whoever told you: a trust
## blow (like a broken offer), unless they've since gone public themselves.
func _break_confidences(nums: Array) -> void:
	GameBoard._break_confidences(self, nums)

func _facts(facts: Array) -> void:
	GameBoard._facts(self, facts)

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
	workshop_deliveries = []
	workshop_comparisons = []
	_workshop_plans = {}
	_workshop_evaluations = {}
	_workshop_reason_ctx = {}
	_workshop_responses = {}
	_workshop_repeats = {}
	_workshop_native_submission = false
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
	_testimony = {}
	offer = {}
	talk_offered = false
	known_haunts = {}
	known_relationships = {}
	fallback_count = 0
	shared_fallbacks = []
	_fallbacks_reported = 0
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
	if debug_overlay: set_debug_overlay(true)
	w.dlog.begin_action("new_case_presentation")
	w.dlog.trace_event("game_config", "world", "", {"strict_evaluator": strict_evaluator})
	state = "day"
	moved = false
	approached_id = ""
	approached_loc = ""
	events = []
	_intro()
	_morning_report()
	_maybe_approach()
	return _finish_command("new_case", "")

## Where everyone lives is common knowledge: one card per resident, so arguments about
## where someone could have walked at night can cite it.
func _attach_workshop_world() -> void:
	var weak_game = weakref(self)
	var weak_world = weakref(w)
	w.workshop_refresh = func(n, phase):
		var game = weak_game.get_ref()
		if game != null and game.w == weak_world.get_ref():
			WorkshopOwnership.refresh(game, n, phase)
	w.workshop_reasons = func(n):
		var game = weak_game.get_ref()
		if game != null and game.w == weak_world.get_ref():
			WorkshopOwnership.reasons_for(game, n)
	w.workshop_roots = func(card):
		var game = weak_game.get_ref()
		if game == null or game.w != weak_world.get_ref():
			return {"complete": false, "receipts": {}}
		var proof = WorkshopOwnership.Shared.roots([card], game.all_receipts())
		if card.get("kind") == "deduction" and card.get("n", 0) > 0:
			var captured = game.workshop_snapshot([card.n])
			var endorsed: Array = WorkshopOwnership.Shared.endorsed_facts(captured, card.n)
			for id in proof.receipts.keys():
				if id not in endorsed:
					proof.receipts.erase(id) # Quoting a conflict is not endorsing its accounts.
		return proof
	w.workshop_present = func(n, card, targets, direction, venue, speak):
		var game = weak_game.get_ref()
		if game == null or game.w != weak_world.get_ref():
			return {}
		if game._workshop_native_submission:
			if not game._workshop_native_social:
				WorkshopOwnership.fallback(game, n, "submission", ["The whole audience is using existing response rules for this submission."], card.get("n", 0))
			return {}
		return WorkshopPresentation.present(game, n, card, targets, direction, venue, speak)
	_home_cards()

func _home_cards() -> void:
	GameBoard._home_cards(self)

## Canvas capability status for the current command: it already checks the whole
## audience, so computing it once per listener made a presentation O(listeners^2).
var _canvas_status_memo: Dictionary = {}

func _canvas_status(value: Dictionary) -> Dictionary:
	return GamePresentation._canvas_status(self, value)

func command(line: String) -> String:
	if workshop_presenting:
		return "A case presentation is still being assessed."
	if meeting_streaming():
		return "The town is still speaking."
	var text = line.strip_edges()
	if text == "":
		return ""
	_canvas_status_memo = {}
	_workshop_native_submission = false
	events = []
	if w != null:
		w.set_log_time()
		w.dlog.begin_action("command", {"cmd": text})
		w.trace_capture("before_command")
	_dispatch(text)
	if w.game_over and state != "over":
		state = "over"
		_ending()
	return _finish_command("command", text)

## Canvas town presentations yield BETWEEN listeners. Each listener assessment is
## still atomic; action limits, disclosure, speech, voting and trace boundaries
## are the very same handlers as the synchronous command interface.
func workshop_command(line: String, progress: Callable) -> String:
	if workshop_presenting:
		return "A case presentation is still being assessed."
	var parts = line.split(" ", false, 1)
	if parts.size() != 2 or not ((state == "meeting" and parts[0] == "present") or (state == "nomination" and parts[0] in ["accuse", "defend"])):
		return command(line)
	workshop_presenting = true
	_workshop_native_submission = false
	events = []
	w.set_log_time()
	w.dlog.begin_action("command", {"cmd": line})
	w.trace_capture("before_command")
	if state == "meeting":
		await _present_deduction(parts[1], progress)
	else:
		await _nomination_command(parts[0], parts[1], progress)
	workshop_presenting = false
	if w.game_over and state != "over":
		state = "over"
		_ending()
	return _finish_command("command", line)

func _finish_command(kind: String, cmd: String) -> String:
	last_events = events.duplicate()
	var out = render(events)
	if w != null:
		w.set_log_time()
		w.dlog.add("player_" + kind, "player", "", {"cmd": cmd, "output": out})
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

func add_card(fact: Dictionary) -> int:
	return GameBoard.add_card(self, fact)

func add_profile_receipt(fact: Dictionary) -> int:
	return GameBoard.add_profile_receipt(self, fact)

func receipt_by_number(num: int) -> Dictionary:
	return GameBoard.receipt_by_number(self, num)

func all_receipts() -> Array:
	return GameBoard.all_receipts(self)

func profile_receipts_for(id: String, facet: String = "") -> Array:
	return GameBoard.profile_receipts_for(self, id, facet)

func _record_trait_receipt(target, key: String, tier: String, source_id: String) -> int:
	return GameConversation._record_trait_receipt(self, target, key, tier, source_id)

func sync_bereaved_traits(target, source_id: String = "player") -> void:
	GameConversation.sync_bereaved_traits(self, target, source_id)

# ---------------------------------------------------------------- corroboration

## What a card says happened, independent of who said it: "who was where, when" for each
## person it places, and "these two talked" for a conversation. Two cards from different
## sources that share a key back each other up.
static func core_keys(card: Dictionary) -> Array:
	return GameBoard.core_keys(card)

func _corroborate(card: Dictionary, src: String) -> void:
	GameBoard._corroborate(card, src)

func _link_corroboration(card: Dictionary) -> void:
	GameBoard._link_corroboration(self, card)

## Cards you've already got for a conversation (for "don't tell me what I saw myself").
func seen_pairs() -> Dictionary:
	return GameBoard.seen_pairs(self)

## A fact an NPC passes over in silence because you saw it yourself: no new card, they're
## just recorded as backing yours.
func _silent_corroboration(f: Dictionary) -> void:
	GameBoard._silent_corroboration(self, f)

## The current time slot as the board counts it (the meeting and the night belong to the
## evening and night of the day they're in).
func _phase_now() -> int:
	return GameBoard._phase_now(self)

## When, how and from whom you heard this fact (public = at a town meeting).
func _disclosure(fact: Dictionary) -> Dictionary:
	return GameBoard._disclosure(self, fact)

func _disclose(card: Dictionary, disc: Dictionary) -> void:
	GameBoard._disclose(card, disc)

## Read-only integration boundary. No NPC effects, time costs or Workshop fixture truth.
func workshop_snapshot(numbers: Array, listener_id: String = "", venue: String = "private") -> Dictionary:
	return GamePresentation.workshop_snapshot(self, numbers, listener_id, venue)

func workshop_preview(number: int, listener_id: String, venue: String = "private") -> Dictionary:
	return GamePresentation.workshop_preview(self, number, listener_id, venue)

func workshop_ghost_preview(number: int) -> Dictionary:
	return GamePresentation.workshop_ghost_preview(self, number)

## Read-only and exhaustive: one unavailable listener blocks the whole test-mode
## submission. A preview may display only capability reasons, never private facts.
func workshop_readiness(card: Dictionary, listeners: Array, targets: Array, direction: String, venue: String) -> Dictionary:
	return GamePresentation.workshop_readiness(self, card, listeners, targets, direction, venue)

func _presentation_gate(card: Dictionary, listeners: Array, targets: Array, direction: String, venue: String) -> bool:
	return GamePresentation._presentation_gate(self, card, listeners, targets, direction, venue)

## Conclusion types named by issues that are only about the conclusion ("Unsupported
## claim: role"), or [] if any issue is about the evidence itself.
func _unsupported_conclusions(issues: Array) -> Array:
	return GamePresentation._unsupported_conclusions(issues)

## Issues that only say "there's no evidence here", as opposed to evidence the shared
## model can't read.
func _bare_speech(issues: Array) -> bool:
	return GamePresentation._bare_speech(issues)

func _presentation_rejection(card: Dictionary) -> String:
	return GamePresentation._presentation_rejection(self, card)

func workshop_retract(number: int, listener_id: String) -> void:
	GamePresentation.workshop_retract(self, number, listener_id)

func _workshop_retract(number: int, listener_id: String) -> void:
	GamePresentation._workshop_retract(self, number, listener_id)

## All three deduction venues share receipt ownership and optional comparison.
func _evaluate_deduction(n, ded: Dictionary, scale: float, speak: bool = true, venue: String = "private") -> Dictionary:
	return GamePresentation._evaluate_deduction(self, n, ded, scale, speak, venue)

func _evaluate_deduction_inner(n, ded: Dictionary, scale: float, speak: bool = true, venue: String = "private") -> Dictionary:
	return GamePresentation._evaluate_deduction_inner(self, n, ded, scale, speak, venue)

## Canvas revisions replace this listener's previous endorsement only when heard.
## Keep a dedicated native ledger entry so other filed arguments are untouched.
func workshop_canvas_retire(real, ded: Dictionary) -> void:
	GamePresentation.workshop_canvas_retire(self, real, ded)

# ---------------------------------------------------------------- dispatch

func _dispatch(text: String) -> void:
	var parts = text.split(" ", false)
	var verb = parts[0].to_lower()
	var rest = " ".join(parts.slice(1))
	match verb:
		"help", "?", "h":
			_screen(_help())
			return
		"fallbacks":
			_screen(_fallbacks_text())
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
		"link", "conclude", "deduce":
			_err("Cases are built in the Case Workshop now (the old link / conclude commands are retired).")
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
				var sub: String = rest.strip_edges().to_lower()
				_screen(_lies() if sub == "lies" else (_exchanges() if sub in ["talk", "shares", "exchanges"] else _grimoire()))
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


# ---------------------------------------------------------------- day & night forwarders

func unseen_at(l: String) -> int:
	return GameDayNight.unseen_at(self, l)

func unseen_at_ui(l: String) -> int:
	return GameDayNight.unseen_at_ui(self, l)

func can_see(n) -> bool:
	return GameDayNight.can_see(self, n)

func can_see_ui(n) -> bool:
	return GameDayNight.can_see_ui(self, n)

func _present(l: String) -> Array:
	return GameDayNight._present(self, l)

func _resolve_go(target: String) -> String:
	return GameDayNight._resolve_go(self, target)

func _best_location_on(b: String) -> String:
	return GameDayNight._best_location_on(self, b)

func _day_command(verb: String, rest: String) -> void:
	GameDayNight._day_command(self, verb, rest)

func _warn_busy_visit(n) -> void:
	GameDayNight._warn_busy_visit(self, n)

func _who_here(l: String) -> String:
	return GameDayNight._who_here(self, l)

func _observe() -> void:
	GameDayNight._observe(self)

func _search() -> void:
	GameDayNight._search(self)

func _end_phase(talked_id: String) -> void:
	GameDayNight._end_phase(self, talked_id)

func _night_homes() -> String:
	return GameDayNight._night_homes(self)

func _night_command(verb: String, rest: String) -> void:
	GameDayNight._night_command(self, verb, rest)

func _resolve_night() -> void:
	GameDayNight._resolve_night(self)

func _fallbacks_text() -> String:
	return GameDayNight._fallbacks_text(self)

func _morning_report() -> void:
	GameDayNight._morning_report(self)

# ---------------------------------------------------------------- conversation forwarders

const OBSERVABLE_TRAITS = GameConversation.OBSERVABLE_TRAITS
const TRAIT_WORDS = GameConversation.TRAIT_WORDS
const MAX_BONDS_TOLD = GameConversation.MAX_BONDS_TOLD

func _maybe_approach() -> void:
	GameConversation._maybe_approach(self)

func _promised_to(n) -> bool:
	return GameConversation._promised_to(self, n)

func _maybe_divulge() -> bool:
	return GameConversation._maybe_divulge(self)

func _approach_command(verb: String, rest: String) -> void:
	GameConversation._approach_command(self, verb, rest)

func _protect_approach_answer(n, verb: String, rest: String) -> void:
	GameConversation._protect_approach_answer(self, n, verb, rest)

func _grant_protection(n, what: String) -> void:
	GameConversation._grant_protection(self, n, what)

func _phase_header() -> void:
	GameConversation._phase_header(self)

func _remember_dialogue_exchange(n, verb: String, rest: String, response: Dictionary) -> void:
	GameConversation._remember_dialogue_exchange(self, n, verb, rest, response)

func _greeting_context(n) -> Dictionary:
	return GameConversation.greeting_context(self, n)

func _talk_options(n) -> String:
	return GameConversation._talk_options(self, n)

func _repeat_refusal(n, response: Dictionary) -> void:
	GameConversation._repeat_refusal(n, response)

func _talk_command(verb: String, rest: String) -> void:
	GameConversation._talk_command(self, verb, rest)

func _record_trace_profile_haunts(speaker, r: Dictionary) -> void:
	GameConversation._record_trace_profile_haunts(self, speaker, r)

func _answer_request(n, verb: String, rest: String) -> bool:
	return GameConversation._answer_request(self, n, verb, rest)

func _answer_request_now(n, rq: Dictionary, verb: String, rest: String) -> bool:
	return GameConversation._answer_request_now(self, n, rq, verb, rest)

func _gift_request(n, topic: String, target: String) -> Dictionary:
	return GameConversation._gift_request(self, n, topic, target)

func _grievance_menu(n) -> String:
	return GameConversation._grievance_menu(n)

static func grievance_text(g: Dictionary) -> String:
	return GameConversation.grievance_text(g)

func _offer_command(n, what: String, requested: bool = false) -> void:
	GameConversation._offer_command(self, n, what, requested)

func offer_text() -> String:
	return GameConversation.offer_text(self)

func _settle_offers() -> void:
	GameConversation._settle_offers(self)

func _maybe_tell_haunts(n, t, r: Dictionary) -> void:
	GameConversation._maybe_tell_haunts(self, n, t, r)

func _maybe_tell_trait(n, t, r: Dictionary) -> void:
	GameConversation._maybe_tell_trait(self, n, t, r)

func _maybe_tell_relationships(n, t, r: Dictionary) -> void:
	GameConversation._maybe_tell_relationships(self, n, t, r)

func _remember_spoken_relationship(line: Dictionary) -> void:
	GameConversation._remember_spoken_relationship(self, line)

func known_relationship_notes(id: String) -> Array:
	return GameConversation.known_relationship_notes(self, id)

func known_haunt_names(id: String) -> String:
	return GameConversation.known_haunt_names(self, id)

func _close_conversation() -> void:
	GameConversation._close_conversation(self)

# ---------------------------------------------------------------- meeting forwarders

func _start_meeting() -> void:
	GameMeeting._start_meeting(self)

func meeting_streaming() -> bool:
	return GameMeeting.meeting_streaming(self)

func testimony_step() -> String:
	return GameMeeting.testimony_step(self)

func _testimony_turn() -> void:
	GameMeeting._testimony_turn(self)

func _meeting_opened() -> void:
	GameMeeting._meeting_opened(self)

func _meeting_command(verb: String, rest: String) -> void:
	GameMeeting._meeting_command(self, verb, rest)

func _next_npc_nomination() -> bool:
	return GameMeeting._next_npc_nomination(self)

func _defend_pending() -> void:
	GameMeeting._defend_pending(self)

func vote_requirement_text() -> String:
	return GameMeeting.vote_requirement_text(self)

func _show_nomination() -> void:
	GameMeeting._show_nomination(self)

func _nomination_command(verb: String, rest: String, progress: Callable = Callable()) -> void:
	await GameMeeting._nomination_command(self, verb, rest, progress)

func _after_vote() -> void:
	GameMeeting._after_vote(self)

func _last_words(n) -> void:
	GameMeeting._last_words(self, n)

func _close_meeting() -> void:
	GameMeeting._close_meeting(self)

# ---------------------------------------------------------------- case work (stage 3)
# Data API used by the UI panel as well as the text commands.

## Filter the board. Accepts card kind, evidence class, person, block, location, day
## ("d2") or night ("n1"), or any text in the card.
## Filter the board by a text query. Terms joined with "+" must all match ("greta+night"):
## a person (by, about or via), a block or place, a kind or class, d2 / n1 (a day or a
## night), "night" / "day", or any text.
func filter_cards(filter: String) -> Array:
	return GameBoard.filter_cards(self, filter)

func _filter_term(cards: Array, f: String) -> Array:
	return GameBoard._filter_term(self, cards, f)

## File a deduction card. conclusion: {type, a, role?, night?, card?}. Returns the card
## number, or -1 if refused (reason in last_error).
func file_deduction(conclusion: Dictionary, supports: Array, workshop_filing: bool = false) -> int:
	return GameBoard.file_deduction(self, conclusion, supports, workshop_filing)

## "present <card#> [for|against <name>]" in conversation: work out what the player means.
## About the listener -> press them. A deduction -> argue it. A plain card about others ->
## a case for or against them, direction read from the card itself (a Seer "yes" accuses, a
## Seer "no" clears), split across everyone it names. for/against is only an override; if
## the card has no direction of its own, it falls flat (logged as a fallback).
func _route_present(n, rest: String) -> Dictionary:
	return GamePresentation._route_present(self, n, rest)

## The card has no direction of its own: it falls flat, costs no question, and is logged
## so we can see which cards keep landing here.
func _present_fallback(n, num: int, why: String) -> Dictionary:
	return GamePresentation._present_fallback(self, n, num, why)

## "Something doesn't add up" puts the people involved under scrutiny: publicly, all of
## them; privately, only the listener if they're one of them.
func _conflict_pressure(ded: Dictionary, amount: float, listener, fallback: bool = false) -> void:
	GamePresentation._conflict_pressure(self, ded, amount, listener, fallback)

## A deduction resting on someone's confessed secret spreads it, just like citing it.
func _secrets_used(ded: Dictionary, depth: int = 0) -> void:
	GamePresentation._secrets_used(self, ded, depth)

## Hide a card from views (any card), or delete one of your own deductions.
func hide_card(num: int, on: bool) -> String:
	return GameBoard.hide_card(self, num, on)

func delete_deduction(num: int) -> String:
	return GameBoard.delete_deduction(self, num)

## Present a deduction to the whole meeting (once per meeting).
## Context receipts are shown directly, without a shared-model adapter or numeric
## evidence effect. Claude owns that adapter; this only delivers the approved trust.
func _ward_context_card(rest: String) -> Dictionary:
	return GamePresentation._ward_context_card(self, rest)

func _show_ward_context(card: Dictionary, listeners: Array) -> Dictionary:
	return GamePresentation._show_ward_context(self, card, listeners)

func _present_deduction(rest: String, progress: Callable = Callable()) -> void:
	await GamePresentation._present_deduction(self, rest, progress)

## Timeline: who was where, by phase, from your board. * = you saw it, ~ = heard.
func timeline_data(filter: String = "") -> Dictionary:
	return GameBoard.timeline_data(self, filter)

func _abbr(b: String) -> String:
	return GameBoard._abbr(b)

func _timeline(filter: String) -> String:
	return GameBoard._timeline(self, filter)


# ---------------------------------------------------------------- screens & theory forwarders

func _intro() -> void:
	GameScreens._intro(self)

func _help() -> String:
	return GameScreens._help(self)

func _look() -> void:
	GameScreens._look(self)

func _card_workers() -> void:
	GameScreens._card_workers(self)

func _card_conversations() -> void:
	GameScreens._card_conversations(self)

func _map() -> String:
	return GameScreens._map(self)

func _cast() -> String:
	return GameScreens._cast(self)

func _profile(token: String) -> String:
	return GameScreens._profile(self, token)

func _script() -> String:
	return GameScreens._script(self)

func _tools() -> String:
	return GameScreens._tools(self)

func _board(filter: String) -> String:
	return GameScreens._board(self, filter)

func _ending() -> void:
	GameScreens._ending(self)

func _grimoire() -> String:
	return GameScreens._grimoire(self)

func _exchanges() -> String:
	return GameScreens._exchanges(self)

func _lies() -> String:
	return GameScreens._lies(self)

func _write_logs() -> String:
	return GameScreens._write_logs(self)

func set_note(id: String, text: String) -> void:
	GameScreens.set_note(self, id, text)

func set_guess(id: String, guess: String, confidence: int) -> bool:
	return GameScreens.set_guess(self, id, guess, confidence)

func set_secret_guess(id: String, secret: String, confidence: int) -> bool:
	return GameScreens.set_secret_guess(self, id, secret, confidence)

func capture_prediction(reason: String, extra: Dictionary = {}) -> Dictionary:
	return GameScreens.capture_prediction(self, reason, extra)

func theory_status() -> String:
	return GameScreens.theory_status(self)

func _outcome_text() -> String:
	return GameScreens._outcome_text(self)

func set_debug_overlay(on: bool) -> void:
	GameScreens.set_debug_overlay(self, on)

func _spread(vals: Dictionary) -> String:
	return GameScreens._spread(self, vals)

func debug_card_text(card: Dictionary) -> String:
	return GameScreens.debug_card_text(self, card)

func debug_npc_text(id: String) -> String:
	return GameScreens.debug_npc_text(self, id)

func named_in(id: String) -> Array:
	return GameScreens.named_in(self, id)

func _death_text(n) -> String:
	return GameScreens._death_text(n)

func _claim_text(n) -> String:
	return GameScreens._claim_text(self, n)

func profile_data(id: String) -> Dictionary:
	return GameScreens.profile_data(self, id)
