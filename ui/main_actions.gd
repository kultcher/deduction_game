## The action pane (ui/main.gd): what you can do now, as buttons, for each state of the game
## (the day, a conversation, an approach, the meeting, a vote, the night, the case closed).
## Every button becomes the same text command the CLI uses. `m` is the main control.
extends RefCounted

const GameDayNight = preload("res://game/game_day_night.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Declaration = preload("res://game/demon_declaration.gd")
const GameMeeting = preload("res://game/game_meeting.gd")
const LiveWorkshopFields = preload("res://ui/live_workshop_fields.gd")
const Pickers = preload("res://ui/main_pickers.gd")

## The approach's choices: in the VN's controls once the approacher is speaking.
static func approach(m, w) -> void:
	match m.g.approach.get("agenda", ""):
		"protect":
			var pk: String = Mind.protection_kind(w, m.g.approach["npc"])
			m._button(m.actions, "Promise it: %s (free)" % ("your ward on their door (%s; promise does not spend it)" % Pickers.ward_remaining(m) if pk == "ward" else "a vigil tonight"), func(): m._run("yes"))
			m._button(m.actions, "Say no", func(): m._run("no"))
		"divulge":
			m._button(m.actions, "Keep talking (uses this phase)", func(): m._run("accept"))
			m._button(m.actions, "Go on your way", func(): m._run("decline"))
		_:
			m._button(m.actions, "Hear them out (uses this phase)", func(): m._run("accept"))
			m._button(m.actions, "Wave them off", func(): m._run("decline"))

## Keep the approach's VN in step with the game: a new approach starts at its interstitial;
## leaving the approach (accepted, declined) clears it. It waits behind a finished
## conversation or a reading.
static func sync_approach(m, reading: bool) -> void:
	if m.g.state != "approach" or not m.g.approach.has("npc"):
		m.approach_stage = ""
		m._approach_key = ""
		return
	if m.conversation_finished or reading:
		return
	var n = m.g.approach["npc"]
	# The game's identity too: a new case can open on the same approach (Codex, #162).
	var key: String = "%d:%d:%d:%s:%s" % [m.g.get_instance_id(), m.g.w.day, m.g.w.phase, n.id, str(m.g.approach.get("agenda", ""))]
	if key == m._approach_key:
		return
	m._approach_key = key
	m.approach_stage = "intro"
	m.conversation_view.set_location(n.loc)
	m.conversation_view.show_item("", null, str(m.g.approach.get("intro", "%s wants a word." % n.name)))

static func approach_continue(m) -> void:
	if m.g.state != "approach" or not m.g.approach.has("npc"):
		return
	var n = m.g.approach["npc"]
	m.approach_stage = "speaking"
	m.conversation_view.begin(n.id, n.name)
	m.conversation_view.set_location(n.loc)
	m.conversation_view.consume(m.g.approach.get("events", []))
	m._refresh_all()

static func refresh(m) -> void:
	m.conversation_view.set_action_hint("")
	for ch in m.actions.get_children():
		m.actions.remove_child(ch)
		ch.queue_free()
	for ch in m.conversation_view.controls.get_children():
		m.conversation_view.controls.remove_child(ch)
		ch.queue_free()
	if m.g == null:
		return
	var w = m.g.w
	if m.conversation_finished:
		m.action_title.text = "Conversation finished"
		m._button(m.conversation_view.controls, "Leave conversation", m._leave_finished_conversation)
		return
	if not m.inspect_pages.is_empty():
		var more: bool = m.inspect_index < m.inspect_pages.size() - 1
		var page_now: Dictionary = m.inspect_pages[m.inspect_index]
		m._button(m.conversation_view.controls, "Next trace" if more else str(page_now.get("button", "Done")), m._inspect_next)
		m.action_title.text = "Reading the traces" if not page_now.has("loc") else ("Listening to the gossip" if page_now.loc == "tavern" else "Reading the records")
		hint(m, "Finish reading before you move on.")
		return
	if m._presenting():
		m.action_title.text = ("Day %d: the town meeting" % w.day) if m.g.state in ["meeting", "nomination"] or m.g.meeting_streaming() else "The town is speaking"
		if m.meeting_view.stage.busy():
			m._button(m.actions, "Continue", func(): m.meeting_view.stage.advance())
		elif m.meeting_view.animating():
			m._button(m.actions, "Finish the count", func(): m.meeting_view.finish())
		hint(m, "The town is speaking…" if m.g.meeting_streaming() or m.meeting_view.stage.busy() else "The hand goes round…")
		return
	match m.g.state:
		"day":
			day(m, w)
		"approach":
			if m.approach_stage == "intro":
				m.action_title.text = "Someone waves you down"
				m._button(m.conversation_view.controls, "Continue", func(): approach_continue(m))
				return
			m.action_title.text = ("%s wants a word." % m.g.approach["npc"].name) if m.g.approach.has("npc") else "Someone wants a word."
			var lower_actions = m.actions
			if m.approach_stage == "speaking":
				m.actions = m.conversation_view.controls
			approach(m, w)
			m.actions = lower_actions
		"talk":
			m._button(m.actions, "Look at conversation" if m.conversation_show_map else "Look at the map", func():
				m.conversation_show_map = not m.conversation_show_map
				m._refresh_all())
			if m.conversation_show_map:
				# The conversation's options wait while the map is up: go back to it to carry on
				# (Michael, Nov 17).
				m.action_title.text = "Talking with %s" % m.g.talk_with.name
			else:
				var lower_actions = m.actions
				m.actions = m.conversation_view.controls
				talk(m, w)
				m.actions = lower_actions
		"meeting":
			m.action_title.text = "Day %d: the town meeting" % w.day
			# Wards and scorched sigils are shown, not argued: one button each, free of the floor.
			for pc in m.g.board.filter(func(c): return c.kind in ["ward", "scorched_sigil"] and not c.get("deleted", false) and not m.g.shown_protection.has(int(c.n))):
				var pnum: int = int(pc.n)
				m._button(m.actions, "Show the town %s" % m.g.protection_label(pc), func(): m._run("present %d" % pnum))
			map_toggle(m)
			m._button(m.actions, "Let the town speak (wait)", func(): m._run("wait"))
			if not m.g.presented_today:
				m._button(m.actions, "Present a deduction to everyone…", func(): Pickers.card(m, "Present a deduction to the meeting",
					func(c): return c["kind"] == "deduction", func(num, _x): m._run("present %d" % num), false))
			# Call on someone to share what they haven't said (withheld readings, Michael, Nov 22).
			var call = m._button(m.actions, "Call on…", func(): pass)
			call.disabled = GameMeeting.called_on_today(m.g)
			if call.disabled:
				call.tooltip_text = GameMeeting.CALLED_ALREADY
			call.pressed.connect(func(): Pickers.people(m, call, "Call on whom?", func(id): m._run("call " + id), func(n): return GameMeeting.call_on_rejection(m.g, n) == ""))
			# Take back a filed case in public (BACKLOG "Believable public revisions", Nov 18).
			if m.g.board.any(Pickers.withdrawable):
				m._button(m.actions, "Take back a case…", func(): Pickers.card(m, "Take back a case in public",
					Pickers.withdrawable, func(num, _x): Pickers.confirm_withdraw(m, num), false))
			if Declaration.blocked(w) == "":
				# The demon-type declaration: its own action, once a day (game/demon_declaration.gd).
				for kind in Declaration.TYPES:
					if kind == w.declared_demon_type:
						continue
					var verb: String = "Correct yourself" if w.declared_demon_type != "" else "Declare"
					var b = m._button(m.actions, "%s: it's %s" % [verb, Declaration.LABEL[kind]], func(): m._run("declare " + kind))
					b.tooltip_text = "The whole town weighs the evidence as if this were true. Once a day; changing your mind costs credibility with everyone."
			var nom = m._button(m.actions, "Nominate…", func(): pass)
			nom.disabled = "player" in w.meeting.get("nominators", [])
			if nom.disabled:
				nom.tooltip_text = "No nominations remaining"
			nom.pressed.connect(func(): Pickers.people(m, nom, "Nominate whom?", func(id): Pickers.nomination_menu(m, nom, id), func(n): return w.can_nominate("player", n.id) == ""))
			var done = m._button(m.actions, "Close the meeting", func(): m.close_meeting())
			done.disabled = not m.g.town_quiet
			if not m.g.town_quiet:
				done.tooltip_text = "Let the town speak first (wait) until nobody else rises."
		"nomination":
			var nm: Dictionary = w.meeting["pending"]
			m.action_title.text = "Vote on %s" % w.by_id[nm["nominee"]].name
			map_toggle(m)
			m._button(m.actions, "Vote to execute", func(): m._run("vote yes"))
			m._button(m.actions, "Vote to spare", func(): m._run("vote no"))
			if not nm.get("supporters_done", false):
				# Steps 3-4 first (meeting plan M2c/M2d): press them, or let the town speak.
				if nm.get("press", "") == "open":
					var pr = m._button(m.actions, "Press them before the town…", func(): pass)
					pr.tooltip_text = "One public question before the town weighs in. Voting without pressing skips it."
					pr.pressed.connect(func(): Pickers.press_menu(m, pr, nm["nominee"]))
				var hear = m._button(m.actions, "Hear the town", func(): m._run("hear"))
				hear.tooltip_text = "Let bystanders speak for or against them; then it's your turn."
			elif not m.g.statement_used:
				# Option (b), Michael, Nov 19: one filed case about the nominee, judged as at the podium.
				var nominee: String = nm["nominee"]
				var cases: Array = GameMeeting.nomination_cases(m.g, nominee)
				var put = m._button(m.actions, "Present a case about them…", func():
					if cases.is_empty():
						# No filed case yet: open the Workshop with "<nominee> is evil" ready, as the
						# nomination menu does (Michael's playtest, Nov 22: it was greyed out).
						m._open_live_workshop()
						LiveWorkshopFields.prefill_premise(m.case_view.workshop.editor, nominee, "evil")
						return
					Pickers.card(m, "Present a case about %s" % w.by_id[nominee].name,
						func(c): return GameMeeting.nomination_case_rejection(m.g, c, nominee) == "", func(num, _x): m._run("case %d" % num), false))
				put.tooltip_text = "Put one filed case about them to the town before the vote. It doesn't use your Present." if not cases.is_empty() else "You have no filed case about them. Build one in the Workshop."
			if w.tools["clemency"] > 0 and nm["by"] != "player" and nm.get("supporters_done", false):
				m._button(m.actions, "Invoke Clemency (once per case)", func(): m._run("clemency"))
		"night":
			m.action_title.text = "Night %d: your night work" % w.day
			# Tonight's promises first, so keeping your word is one click.
			if m.g.offer.has("ward") and w.tools["ward"] > 0:
				var wid: String = m.g.offer["ward"]
				m._button(m.actions, "Keep your word: ward %s's door (%s)" % [w.by_id[wid].name, Pickers.ward_remaining(m)], func(): Pickers.confirm_ward(m, wid), C.npc_color(wid))
			var vblocks = {}
			for id in m.g.offer.get("vigil", {}):
				vblocks[m.g.offer["vigil"][id]] = true
			for vb in vblocks:
				m._button(m.actions, "Keep your word: vigil on %s" % C.block_name(vb), func(): m._run("vigil " + vb))
			if not m.g.offer.is_empty():
				hint(m, "You promised %s." % m.g.offer_text())
			if m.map.selected_block != "":
				m._button(m.actions, "Keep vigil on %s" % C.block_name(m.map.selected_block), func(): m._run("vigil " + m.map.selected_block))
			if m._ward_target != "" and w.tools["ward"] > 0 and w.by_id[m._ward_target].alive:
				m._button(m.actions, "Ward %s's door (%s)" % [w.by_id[m._ward_target].name, Pickers.ward_remaining(m)], func(): Pickers.confirm_ward(m, m._ward_target), C.npc_color(m._ward_target))
			var vig = m._button(m.actions, "Keep vigil on…", func(): pass)
			vig.pressed.connect(func(): Pickers.list(m, vig, "Watch which block?", C.BLOCKS.keys().map(func(b): return [C.block_name(b), "vigil " + b, null])))
			if w.tools["ward"] > 0:
				var wd = m._button(m.actions, "Ward someone… (%s)" % Pickers.ward_remaining(m), func(): pass)
				wd.pressed.connect(func(): Pickers.people(m, wd, "Ward whom?", func(id): Pickers.confirm_ward(m, id), func(n): return n.alive))
			m._button(m.actions, "Sleep", func(): m._run("sleep"))
			hint(m, "Tip: click a block or a person on the map to pick them.")
		"over":
			m.action_title.text = "The case is closed."
			if m.reveal_seen_for != m.g:
				m.call_deferred("open_reveal")
			m._button(m.actions, "The grim reveal", func(): m.open_reveal())
			m._button(m.actions, "Show the grimoire", func(): m._run("grimoire"))
			m._button(m.actions, "Show every lie", func(): m._run("grimoire lies"))
			m._button(m.actions, "Show who told whom what", func(): m._run("grimoire talk"))
			m._button(m.actions, "New case", m._open_new_case_screen)

## Portraits inspect; this explicit action owns the existing go/talk sequence.
static func talk_to_person(m, id: String) -> void:
	if m.g.state != "day": return
	var n = m.g.w.by_id.get(id)
	if n == null or not m.g.can_see_ui(n): return
	var cmds: Array = []
	if not m.g.moved:
		# An approach discloses a destination even before ordinary block visibility.
		var destination: String = id if m.g.can_see(n) else m.g.approached_loc
		cmds.append("go " + destination)
	cmds.append("talk " + id)
	m._run_seq(cmds)

static func day(m, w) -> void:
	if not m.g.moved:
		m.action_title.text = "Day %d, %s: where will you go?" % [w.day, C.PHASES[w.phase].to_lower()]
		var picked = w.by_id.get(m._day_pick)
		if picked != null and picked.alive and m.g.can_see_ui(picked):
			var talk = m._button(m.actions, "Talk to %s" % picked.name, func(): talk_to_person(m, picked.id), C.npc_color(picked.id))
			talk.disabled = picked.busy_with != ""
		if m.map.zoom_block != "" and C.BLOCKS.has(m.map.zoom_block):
			# Zoomed in on a block: go there (its busiest spot; the other is a free step away),
			# to its crime scene, or back out.
			var zb: String = m.map.zoom_block
			hint(m, "Click a spot on the block to go straight there, or a person to inspect their profile.")
			m._button(m.actions, "Visit %s" % C.block_name(zb), func(): m._run("go " + zb))
			for sid in w.scenes:
				if w.scenes[sid].get("block", "") == zb:
					var scene_id: String = sid
					m._button(m.actions, "Go to %s (crime scene)" % w.scenes[scene_id]["name"], func(): m._run("go " + scene_id))
			m._button(m.actions, "Back to town view", func():
				m.map.zoom_to("")
				refresh(m))
		else:
			hint(m, "Examine a block to look closer, or click a person to inspect their profile.")
			for b in C.BLOCKS.keys():
				var blk: String = b
				m._button(m.actions, "Examine %s" % C.block_name(blk), func():
					m.map.zoom_to(blk)
					refresh(m))
		m._button(m.actions, "Wait (let the %s pass)" % C.PHASES[w.phase].to_lower(), func(): m._run("wait"))
		return
	m.action_title.text = "%s, %s" % [w.loc_name(m.g.loc).capitalize(), C.PHASES[w.phase].to_lower()]
	var here: Array = GameDayNight._present(m.g, m.g.loc)
	for n in here:
		if n.busy_with == "":
			m._button(m.actions, "Talk to %s" % n.name, func(): m._run("talk " + n.id), C.npc_color(n.id))
		else:
			var b = m._button(m.actions, "%s is deep in conversation" % n.name, func(): pass, C.npc_color(n.id))
			b.disabled = true
	if not m.g.free_move_used:
		for l in w.locations_on(w.loc_block(m.g.loc)):
			if l == m.g.loc or l.begins_with("home_"):
				continue
			var who: Array = GameDayNight._present(m.g, l).filter(func(x): return x.busy_with == "")
			if not who.is_empty():
				for n in who:
					m._button(m.actions, "Talk to %s (at %s)" % [n.name, w.loc_name(l)], func(): m._run("talk " + n.id), C.npc_color(n.id))
	if not m.g.loc.begins_with("home_") and not C.is_player_building(m.g.loc):
		m._button(m.actions, "Search here", func(): m._run("search"))
	if m.g.loc == "tavern":
		var gos_btn = m._button(m.actions, "Listen to the gossip" if w.phase == C.EVENING else "Listen to the gossip (evening only)", func(): m._run("gossip"))
		gos_btn.disabled = w.phase != C.EVENING
	if m.g.loc == "town_hall":
		var th_open: bool = w.phase in [C.MORNING, C.AFTERNOON]
		var th_left: int = w.town_hall_uses_left
		var th_lbl: String = ("Check the Town Hall records (%d left)" % th_left) if th_open else "Check the Town Hall records (morning/afternoon only)"
		if th_left <= 0:
			th_lbl = "Check the Town Hall records (0 left)"
		var th_btn = m._button(m.actions, th_lbl, func(): m._run("records"))
		th_btn.disabled = (not th_open) or th_left <= 0
	m._button(m.actions, "Wait", func(): m._run("wait"))
	if not m.g.free_move_used:
		hint(m, "You can still step to the other spot on this block (click it on the map).")

static func talk(m, w) -> void:
	var n = m.g.talk_with
	m.action_title.text = "Talking with %s · %d question%s left" % [n.name, m.g.questions_left, "" if m.g.questions_left == 1 else "s"]
	if not m.g.pending_request.is_empty():
		var rq: Dictionary = m.g.pending_request
		var ask: String = "Promise to keep it quiet" if rq["kind"] == "confidence" else (
			"Promise your ward on their door (%s; promise does not spend it)" % Pickers.ward_remaining(m) if rq.get("what", "") == "ward" else "Promise a vigil on %s tonight" % C.block_name(n.home_block))
		m._button(m.actions, ask + " (free)", func(): m._run("yes"), C.npc_color(n.id))
		m._button(m.actions, "Say no (free)", func(): m._run("no"))
		hint(m, "Anything else you do counts as no.")
	var gb = m._button(m.actions, "Ask about their readings…  ▸" if n.max_tier >= 3 or n.claim_public else "Ask about %s's gift…  ▸" % n.name, func(): pass)
	gb.pressed.connect(func(): Pickers.ask_gift(m, gb))
	var ob = m._button(m.actions, "Offer…  ▸", func(): pass)
	ob.pressed.connect(func(): Pickers.offer(m, ob))
	var wb = m._button(m.actions, "Ask where they were and who they saw…  ▸", func(): pass)
	wb.pressed.connect(func(): Pickers.ask_when(m, wb))
	var ab = m._button(m.actions, "Ask about others…  ▸", func(): pass)
	ab.pressed.connect(func(): Pickers.ask_about(m, ab))
	var asks: Dictionary = {"seer": "check", "registrar": "check", "warden": "guard", "nightwatch": "watch"}
	if (n.max_tier >= 3 or n.claim_public) and asks.has(n.claimed_role) and w.phase != C.NIGHT:
		var rb = m._button(m.actions, "Ask them to use their gift tonight…  ▸", func(): pass)
		rb.pressed.connect(func(): Pickers.gift_request(m, rb, n.claimed_role, asks[n.claimed_role]))
	for k in n.hints:
		if w.by_id[k].alive:
			# They hinted at a private reason at the meeting: ask them for it.
			m._button(m.actions, "Ask why they suspect %s" % w.by_id[k].name, func(): m._run("ask why"), C.npc_color(k))
			break
	m._button(m.actions, "Present a card…", func(): Pickers.card(m, "Present a card to %s" % n.name,
		func(c): return not c.get("tavern_gossip", false) and c.get("pressable", true) and c.get("workshop_usable", true),
		func(num, extra): m._run(("present %d" % num) + extra), false, true))
	m._button(m.actions, "Leave", func(): m._run("bye"))

## During the meeting: switch the top-left view between the meeting circle and the map.
static func map_toggle(m) -> void:
	m._button(m.actions, "Back to the meeting" if m.meeting_show_map else "Look at the map", func():
		m.meeting_show_map = not m.meeting_show_map
		m._refresh_all())

static func hint(m, t: String) -> void:
	if m.actions == m.conversation_view.controls:
		m.conversation_view.set_action_hint(t)
		return
	var l = Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	m.actions.add_child(l)

