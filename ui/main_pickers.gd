## The menus the action pane opens (ui/main.gd): choosing a card, a person, a block or a
## question, the nomination and podium menus, and the confirmations that spend a ward or take
## back a case. `m` is the main control.
extends RefCounted

const LiveWorkshopFields = preload("res://ui/live_workshop_fields.gd")
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const MindPodium = preload("res://sim/mind_podium.gd")
const CardList = preload("res://ui/card_list.gd")
const EvidenceContext = preload("res://ui/evidence_context.gd")

static func show(m, content: Control, anchor: Control) -> void:
	# Clicking the same button again closes its menu.
	if m.popup.visible and anchor != null and anchor == m._popup_anchor:
		m.popup.hide()
		m._popup_anchor = null
		content.queue_free()
		return
	m._popup_anchor = anchor
	var original_content = content
	content = preload("res://ui/column_menus.gd").balance(content)
	if content != original_content:
		original_content.queue_free()
	for ch in m.popup.get_children():
		m.popup.remove_child(ch)
		ch.queue_free()
	# Every menu gets its own close button (Esc works too).
	var wrap = VBoxContainer.new()
	var bar = HBoxContainer.new()
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	var x = Button.new()
	x.text = "✕ Close"
	x.pressed.connect(func():
		m.popup.hide()
		m._popup_anchor = null)
	bar.add_child(x)
	wrap.add_child(bar)
	wrap.add_child(content)
	content = wrap
	var pos = Vector2i(m.get_viewport_rect().size / 2.0)
	if anchor != null:
		# Embedded popup positions are in logical viewport units, not screen pixels.
		var origin = anchor.global_position if anchor.get_window().gui_embed_subwindows else anchor.get_screen_position()
		pos = Vector2i(origin) + Vector2i(0, int(anchor.size.y))
	preload("res://ui/column_menus.gd").fit_picker(m.popup, content, pos)

## Meeting plan M2a: nominate on the case on deck (your latest case naming them), update it
## first, pick another, file one, or nominate on your word alone.
static func nomination_menu(m, anchor: Control, id: String) -> void:
	var who = m.g.w.by_id[id]
	var deck: Dictionary = m.g.on_deck_case(id)
	var v = column("Nominate %s" % who.name)
	var public_tip: String = "This case is already public knowledge: citing it again doesn't sway the town further, but it stands on its own merits."
	if not deck.is_empty():
		var go = m._button(v, "Nominate on case #%d: %s" % [deck.n, deck.text], func():
			m.popup.hide()
			m._run("nominate %s #%d" % [id, deck.n]))
		if m.g.already_public(deck):
			go.tooltip_text = public_tip
		m._button(v, "Update case #%d in the Workshop first" % deck.n, func():
			m.popup.hide()
			m._open_live_workshop(deck.n))
	var others: Array = m.g.cases_naming(id).filter(func(c): return deck.is_empty() or c.n != deck.n).map(func(c): return c.n)
	if not others.is_empty():
		m._button(v, "Nominate on another case…", func():
			m.popup.hide()
			card(m, "Nominate %s on which case?" % who.name, func(c): return c.n in others, func(num, _x): m._run("nominate %s #%d" % [id, num]), false))
	if deck.is_empty():
		m._button(v, "File a case against %s in the Workshop" % who.name, func():
			m.popup.hide()
			m._open_live_workshop()
			LiveWorkshopFields.prefill_premise(m.case_view.workshop.editor, id, "evil"))
	var raw = m._button(v, "Nominate without a case", func():
		m.popup.hide()
		m._run("nominate %s raw" % id))
	raw.tooltip_text = "Rests on your word alone: the town will want more, and a wrong call costs your credibility."
	show(m, v, anchor)

## The podium press (Step 3): their gift, a night's account, or a card about them. Cards
## from the case on the floor come first.
static func press_menu(m, anchor: Control, id: String) -> void:
	var t = m.g.w.by_id[id]
	var opts: Dictionary = MindPodium.options(m.g.w, t)
	var v = column("Press %s before the town" % t.name)
	if opts.gift != "":
		m._button(v, "Ask what their gift has shown them" if opts.gift == "readings" else "Press them on their gift", func():
			m.popup.hide()
			m._run("press role"))
	var nights: Array = opts.nights.duplicate()
	nights.reverse()
	if not nights.is_empty():
		m._button(v, "Press their account of a night…", func():
			m.popup.hide()
			list(m, anchor, "Which night?", nights.map(func(nd): return [C.spoken_night(nd, m.g.w.day).capitalize(), "press night %d" % nd, null])))
	var case_n: int = int(m.g.w.meeting["pending"].get("case_card", 0))
	var case_cards: Array = []
	if case_n > 0:
		case_cards = Array(m.g.board[case_n - 1].get("supports", [])).map(func(x): return int(x))
	var fits = func(c): return MindPodium.card_fits(m.g.w, t, c)
	if case_cards.any(func(n): return n >= 1 and n <= m.g.board.size() and fits.call(m.g.board[n - 1])):
		m._button(v, "Press a card from case #%d…" % case_n, func():
			m.popup.hide()
			card(m, "Press %s with which card from the case?" % t.name, func(c): return int(c.n) in case_cards and fits.call(c), func(num, _x): m._run("press card %d" % num), false))
	m._button(v, "Press them with a card…", func():
		m.popup.hide()
		card(m, "Press %s with which card?" % t.name, fits, func(num, _x): m._run("press card %d" % num), false))
	show(m, v, anchor)

static func column(title: String) -> VBoxContainer:
	var v = VBoxContainer.new()
	var l = Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	v.add_child(l)
	return v

## "Ask about <them>'s gift…": what their gift is, or whether they hold a particular one.
static func ask_gift(m, anchor: Control) -> void:
	var n = m.g.talk_with
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var qs = column("Ask %s…" % n.name)
	m._button(qs, "about their readings" if n.max_tier >= 3 or n.claim_public else "about their gift", func():
		m.popup.hide()
		m._run("ask gift"))
	h.add_child(qs)
	var gifts = column("…if they are the")
	for r in m.g.w.case_script.town:
		m._button(gifts, C.role_name(r), func():
			m.popup.hide()
			m._run("ask are " + C.role_name(r).to_lower()))
	h.add_child(gifts)
	show(m, h, anchor)

## A filed case that can still be taken back: live, not replaced, not already withdrawn.
static func withdrawable(c: Dictionary) -> bool:
	return c.get("kind", "") == "deduction" and not c.get("deleted", false) and not c.get("withdrawn", false) and int(c.get("superseded_by", 0)) == 0

static func confirm_withdraw(m, num: int) -> ConfirmationDialog:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Take back case #%d in public? If the town still thinks it was wrong at dawn, it may cost you some of their trust." % num
	m.add_child(dialog)
	dialog.confirmed.connect(func():
		m._run("withdraw %d" % num)
		dialog.queue_free(), CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.popup_centered()
	return dialog

static func confirm_ward(m, id: String) -> ConfirmationDialog:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "This spends your only ward. Ward %s?" % m.g.w.by_id[id].name
	m.add_child(dialog)
	dialog.confirmed.connect(func():
		m._run("ward " + id)
		dialog.queue_free(), CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.popup_centered()
	return dialog

static func offer(m, anchor: Control) -> void:
	var n = m.g.talk_with
	var v = column("Offer %s…" % n.name)
	var wb = m._button(v, "my ward on your door tonight (%s; promise only)" % ward_remaining(m), func():
		m.popup.hide()
		m._run("offer ward"))
	wb.tooltip_text = "Promising does not spend your ward; keeping the promise does."
	wb.disabled = m.g.w.tools["ward"] <= 0 or m.g.offer.has("ward")
	if m.g.w.tools["ward"] <= 0:
		wb.tooltip_text = "Your ward is spent (once per case)."
	var vb = m._button(v, "a vigil on %s tonight" % C.block_name(n.home_block), func():
		m.popup.hide()
		m._run("offer vigil"))
	vb.disabled = m.g.offer.has("vigil")
	if not m.g.offer.is_empty():
		hint_into(v, "You've promised tonight: %s." % m.g.offer_text())
	var open: Array = Mind.open_grievances(n)
	if not open.is_empty():
		var col = column("Apologise for… (uses a question)")
		for i in range(open.size()):
			var idx: int = i + 1
			m._button(col, Game.grievance_text(open[i]), func():
				m.popup.hide()
				m._run("apologise %d" % idx))
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		h.add_child(v)
		h.add_child(col)
		show(m, h, anchor)
		return
	show(m, v, anchor)

## "Ask them to use their gift tonight…": whom a Seer looks at (one or two), whom a Warden
## guards, which block a Night Watch watches. Costs a question.
static func gift_request(m, anchor: Control, role: String, verb: String) -> void:
	var n = m.g.talk_with
	var items: Array = []
	if role == "nightwatch":
		for b in C.BLOCKS.keys():
			items.append([C.block_name(b), "ask watch " + b, null])
	else:
		for other in m.g.w.living():
			if other != n:
				items.append([other.name, "ask %s %s" % [verb, other.id], C.npc_color(other.id)])
	var title = {"seer": "Ask %s to look at… (a question; for a pair, type 'ask check A, B')", "registrar": "Ask %s to check against their register…", "warden": "Ask %s to guard…", "nightwatch": "Ask %s to watch…"}[role] % n.name
	list(m, anchor, title, items)

## "Ask where they were and who they saw…": a time to ask about.
static func ask_when(m, anchor: Control) -> void:
	# Not this phase: you can see who's around for yourself.
	var items: Array = [["…last night", "ask night", null]]
	if m.g.w.phase > 0:
		items.push_front(["…earlier today", "ask seen today", null])
	if m.g.w.day > 1:
		for ph in [2, 1, 0]:
			items.append(["…yesterday %s" % C.PHASES[ph].to_lower(), "ask seen yesterday " + C.PHASES[ph].to_lower(), null])
	list(m, anchor, "Ask where they were and who they saw…", items)

static func hint_into(box: Control, t: String) -> void:
	var l = Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	box.add_child(l)

## "Ask about others…": opinion on a person, or whether they've heard of anyone holding a gift.
static func ask_about(m, anchor: Control) -> void:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var people = column("Opinion on…")
	for n in m.g.w.npcs:
		if n == m.g.talk_with:
			continue
		m._button(people, n.name + ("" if n.alive else " †"), func():
			m.popup.hide()
			m._run("ask about " + n.id), C.npc_color(n.id))
	h.add_child(people)
	var gifts = column("Heard of a…")
	for r in m.g.w.case_script.town:
		m._button(gifts, C.role_name(r), func():
			m.popup.hide()
			m._run("ask about " + C.role_name(r).to_lower()))
	h.add_child(gifts)
	show(m, h, anchor)

static func people(m, anchor: Control, title: String, cb: Callable, allowed: Callable) -> void:
	var v = column(title)
	for n in m.g.w.living():
		var b = m._button(v, n.name, func():
			m.popup.hide()
			cb.call(n.id), C.npc_color(n.id))
		b.disabled = not allowed.call(n)
	show(m, v, anchor)

static func list(m, anchor: Control, title: String, items: Array) -> void:
	var v = column(title)
	for it in items:
		m._button(v, it[0], func():
			m.popup.hide()
			m._run(it[1]), it[2])
	show(m, v, anchor)

## Pick a card from the board. allow_none: offer "without a card". with_target: offer the
## optional for/against override for 'present'.
static func card(m, title: String, keep: Callable, cb: Callable, allow_none: bool, with_target: bool = false) -> void:
	var v = VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 420)
	var t = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	v.add_child(t)
	var f = LineEdit.new()
	f.placeholder_text = "filter: person, place, kind, d2, n1, text; join with + (greta+night)"
	v.add_child(f)
	var lst = CardList.new()
	lst.card_context_requested.connect(func(n, at):
		m.popup.hide()
		m.case_view.show_card_menu(n, at))
	lst.select_mode = Tree.SELECT_ROW
	lst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lst.readable(14)
	v.add_child(lst)
	var fill = func():
		lst.reset()
		lst.context_numbers = EvidenceContext.numbers(m.g)
		var cs: Array = m.g.filter_cards(f.text)
		cs.reverse()  # newest first
		for c in cs:
			if with_target and not m.show_day_sightings and m.is_day_sighting(c):
				continue
			if keep.call(c):
				lst.add(CardList.line_for(c), c["n"], c["text"], CardList.color_for(c, Color(0.95, 0.8, 0.45) if c["kind"] == "deduction" else CardList.tint_for(c)))
	fill.call()
	f.text_changed.connect(func(_x): fill.call())
	if with_target:
		var sight_check: CheckBox = m._day_sightings_check(func(): fill.call())
		v.add_child(sight_check)
		v.move_child(sight_check, f.get_index() + 1)
	var mode: OptionButton = null
	var who: OptionButton = null
	if with_target:
		var row = HBoxContainer.new()
		v.add_child(row)
		mode = OptionButton.new()
		for choice in ["Let them read it", "Speak for…", "Speak against…"]:
			mode.add_item(choice)
		row.add_child(mode)
		who = OptionButton.new()
		for n in m.g.w.living():
			who.add_item(n.name)
			who.set_item_metadata(who.item_count - 1, n.id)
		row.add_child(who)
		# Whom to speak for or against only matters once you pick one of those.
		who.visible = false
		mode.item_selected.connect(func(i): who.visible = i > 0)
	var extra = func() -> String:
		if mode == null or mode.selected == 0 or who.selected < 0:
			return ""
		return (" for " if mode.selected == 1 else " against ") + str(who.get_item_metadata(who.selected))
	var go = func():
		var sel: Array = lst.selected_metas()
		if sel.is_empty():
			return
		m.popup.hide()
		cb.call(sel[0], extra.call())
	lst.card_activated.connect(func(_n): go.call())
	var row2 = HBoxContainer.new()
	v.add_child(row2)
	m._button(row2, "Use this card", func(): go.call())
	if allow_none:
		m._button(row2, "Without a card", func():
			m.popup.hide()
			cb.call(0, ""))
	m._button(row2, "Cancel", func(): m.popup.hide())
	show(m, v, null)

## How much of the ward is left, for the buttons that promise or spend it.
static func ward_remaining(m) -> String:
	return "%d left, once per case" % m.g.w.tools["ward"]
