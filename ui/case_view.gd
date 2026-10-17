## Full-screen case view: filters, card list with selection, timeline grid, profiles,
## and the Link / Conclude builder. Reads the game's structured data directly.
extends PanelContainer

signal changed

const C = preload("res://sim/content.gd")
const Argue = preload("res://sim/argue.gd")
const CardList = preload("res://ui/card_list.gd")
const Metrics = preload("res://game/case_metrics.gd")

var g
var mono: Font
var filter_edit: LineEdit
var kind_menu: MenuButton
var person_menu: MenuButton
var place_menu: MenuButton
var match_opt: OptionButton
var sel_kinds = {}            # multi-select filters: OR within each, and by default across them
var sel_people = {}
var sel_places = {}
var card_list
var grid: GridContainer
var prof_opt: OptionButton
var prof_text: RichTextLabel
var guess_opt: OptionButton
var theory_label: Label
var conf_spin: SpinBox
var note_edit: TextEdit
var result_text: RichTextLabel
var result_box: VBoxContainer
var cell_filter: Array = []   # card numbers picked from a timeline cell ([] = off)
var hidden_check: CheckBox
var work_list
var staged: Array = []        # the working set: card numbers, kept across filters
var b_who: OptionButton
var b_verb: OptionButton
var b_status: OptionButton
var b_night: OptionButton
var b_because: Label
var b_preview: Label
var b_error: Label
var pending: Dictionary = {}  # explanation picked from a link: {conclusion, match, id}
var _setting = false

const KINDS = ["all", "sighting", "info", "claim", "hint", "refusal", "alibi", "secret", "opinion", "accusation",
	"trace", "vigil", "vote", "death", "execution", "deduction"]

func _init() -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.98)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)

func build(font: Font) -> void:
	mono = font
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	theory_label = Label.new()
	theory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(theory_label)

	var top = HFlowContainer.new()
	root.add_child(top)
	_btn(top, "◀ Back to console (Esc)", func(): visible = false)
	var title = Label.new()
	title.text = "  CASE VIEW  "
	top.add_child(title)
	filter_edit = LineEdit.new()
	filter_edit.placeholder_text = "filter: text, d2, n1 ..."
	filter_edit.custom_minimum_size = Vector2(180, 0)
	filter_edit.text_changed.connect(func(_t): _refresh_cards())
	top.add_child(filter_edit)
	kind_menu = _multi(top, "Kinds", sel_kinds)
	person_menu = _multi(top, "People", sel_people)
	place_menu = _multi(top, "Places", sel_places)
	match_opt = _option(top, ["match any", "match all"], func(_i): _refresh_cards())
	match_opt.tooltip_text = "Any: a card shows if it fits any ticked kind, person or place. All: it must fit each list you've ticked (any item within a list)."
	hidden_check = CheckBox.new()
	hidden_check.text = "Show hidden"
	hidden_check.toggled.connect(func(on):
		g.show_hidden = on
		_refresh_cards()
		changed.emit())
	top.add_child(hidden_check)

	var body = HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	body.add_child(left)
	var ll = Label.new()
	ll.text = "Cards (double-click or >> to add to your working set)"
	left.add_child(ll)
	card_list = CardList.new()
	card_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_list.size_flags_stretch_ratio = 2.5
	card_list.card_activated.connect(func(num): _stage([num]))
	card_list.add_theme_font_override("font", mono)
	card_list.add_theme_font_size_override("font_size", 13)
	left.add_child(card_list)
	var lb = HFlowContainer.new()
	left.add_child(lb)
	_btn(lb, ">> Add to working set", func(): _stage(card_list.selected_metas()))
	_btn(lb, "Hide", func(): _hide_selected(true))
	_btn(lb, "Unhide", func(): _hide_selected(false))
	_btn(lb, "Delete deduction", _delete_selected)
	_btn(lb, "Clear filters", func():
		cell_filter = []
		filter_edit.text = ""
		sel_kinds.clear()
		sel_people.clear()
		sel_places.clear()
		_sync_menus()
		_refresh_cards())
	var wl = Label.new()
	wl.text = "Working set (what you link, and the 'because' of a conclusion)"
	left.add_child(wl)
	work_list = CardList.new()
	work_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work_list.card_activated.connect(func(num): _unstage([num]))
	work_list.add_theme_font_override("font", mono)
	work_list.add_theme_font_size_override("font_size", 13)
	left.add_child(work_list)
	var wb = HFlowContainer.new()
	left.add_child(wb)
	_btn(wb, "Link working set", _on_link)
	_btn(wb, "<< Remove", func(): _unstage(work_list.selected_metas()))
	_btn(wb, "Clear", func(): _unstage(staged.duplicate()))

	var mid_split = HSplitContainer.new()
	mid_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(mid_split)
	var mid = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_split.add_child(mid)
	var tl = Label.new()
	tl.text = "Timeline (bright = you saw it, dim = you were told; click a cell for its cards)"
	mid.add_child(tl)
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(sc)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	sc.add_child(grid)
	var res_title = Label.new()
	res_title.text = "Conclusion builder"
	mid.add_child(res_title)
	var brow = HFlowContainer.new()
	mid.add_child(brow)
	b_who = OptionButton.new()
	b_who.item_selected.connect(func(_i):
		_fill_status()
		_builder_changed())
	brow.add_child(b_who)
	b_verb = _option(brow, ["is", "is not", "should be"], func(_i):
		_fill_status()
		_builder_changed())
	b_status = OptionButton.new()
	b_status.item_selected.connect(func(_i): _builder_changed())
	brow.add_child(b_status)
	b_night = OptionButton.new()
	b_night.item_selected.connect(func(_i): _builder_changed())
	brow.add_child(b_night)
	b_because = Label.new()
	b_because.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(b_because)
	b_preview = Label.new()
	b_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_preview.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	mid.add_child(b_preview)
	var frow = HBoxContainer.new()
	mid.add_child(frow)
	_btn(frow, "File deduction", _on_file)
	b_error = Label.new()
	b_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_error.add_theme_color_override("font_color", Color(1, 0.55, 0.5))
	frow.add_child(b_error)
	var lt = Label.new()
	lt.text = "Link results"
	mid.add_child(lt)
	var rs = ScrollContainer.new()
	rs.custom_minimum_size = Vector2(0, 160)
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(rs)
	result_box = VBoxContainer.new()
	result_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.add_child(result_box)
	result_text = RichTextLabel.new()
	result_text.fit_content = true
	result_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_text.text = "Select cards and press Link to check them for a contradiction. Or pick cards and build a conclusion above."
	result_box.add_child(result_text)

	var right = VBoxContainer.new()
	right.custom_minimum_size = Vector2(280, 0)
	mid_split.add_child(right)
	var pl = Label.new()
	pl.text = "Profile"
	right.add_child(pl)
	prof_opt = OptionButton.new()
	prof_opt.item_selected.connect(func(_i): _refresh_profile())
	right.add_child(prof_opt)
	prof_text = RichTextLabel.new()
	prof_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prof_text.custom_minimum_size = Vector2(0, 260)
	prof_text.add_theme_font_size_override("normal_font_size", 13)
	right.add_child(prof_text)
	var gl = HBoxContainer.new()
	right.add_child(gl)
	var glab = Label.new()
	glab.text = "Your guess"
	gl.add_child(glab)
	guess_opt = OptionButton.new()
	for x in ["?", "good", "evil"] + C.GOOD_ROLES + ["demon", "poisoner"]:
		guess_opt.add_item(x if not C.ROLES.has(x) else C.role_name(x))
		guess_opt.set_item_metadata(guess_opt.item_count - 1, x)
	gl.add_child(guess_opt)
	conf_spin = SpinBox.new()
	conf_spin.min_value = 1
	conf_spin.max_value = 3
	conf_spin.value = 2
	conf_spin.prefix = "conf"
	gl.add_child(conf_spin)
	var nl = Label.new()
	nl.text = "Notes"
	right.add_child(nl)
	note_edit = TextEdit.new()
	note_edit.custom_minimum_size = Vector2(0, 120)
	right.add_child(note_edit)
	_btn(right, "Save guess and notes", _on_save_profile)

func _option(parent: Node, items: Array, cb: Callable) -> OptionButton:
	var o = OptionButton.new()
	for x in items:
		o.add_item(x)
	o.item_selected.connect(cb)
	parent.add_child(o)
	return o

func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func set_game(game) -> void:
	g = game
	var pp: PopupMenu = person_menu.get_popup()
	pp.clear()
	sel_people.clear()
	sel_places.clear()
	sel_kinds.clear()
	prof_opt.clear()
	b_who.clear()
	hidden_check.set_pressed_no_signal(g.show_hidden)
	for n in g.w.npcs:
		b_who.add_item(n.name)
		b_who.set_item_metadata(b_who.item_count - 1, n.id)
		pp.add_check_item(n.name)
		pp.set_item_metadata(pp.item_count - 1, n.id)
		prof_opt.add_item(n.name)
		prof_opt.set_item_metadata(prof_opt.item_count - 1, n.id)
	b_who.add_item("One of these people")
	b_who.set_item_metadata(b_who.item_count - 1, "*group")
	var lp: PopupMenu = place_menu.get_popup()
	lp.clear()
	for b in C.BLOCKS:
		lp.add_check_item(C.block_name(b))
		lp.set_item_metadata(lp.item_count - 1, b)
	for l in C.LOCATIONS:
		lp.add_check_item("    " + C.loc_name(l))
		lp.set_item_metadata(lp.item_count - 1, l)
	var kp: PopupMenu = kind_menu.get_popup()
	kp.clear()
	for k in KINDS:
		if k != "all":
			kp.add_check_item(k)
			kp.set_item_metadata(kp.item_count - 1, k)
	_sync_menus()
	refresh()

func refresh() -> void:
	if g == null:
		return
	theory_label.text = g.theory_status()
	if not g.w.game_over:
		theory_label.text += " — Save Your guess in a profile before voting. No correctness feedback until the case ends."
	_refresh_cards()
	_refresh_timeline()
	_refresh_profile()
	_fill_nights()
	_refresh_work()
	if b_status.item_count == 0:
		_fill_status()
	_update_preview()

func open_theory() -> void:
	# Select the existing candidate or leave the ordinary first profile selected.
	var ids = Metrics.named_guesses(g.guesses, "demon")
	if not ids.is_empty():
		for i in range(prof_opt.item_count):
			if prof_opt.get_item_metadata(i) == ids[0]:
				prof_opt.select(i)
	_refresh_profile()
	guess_opt.grab_focus()

func _input(ev: InputEvent) -> void:
	if visible and ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()

func _meta(o: OptionButton) -> String:
	if o.selected < 0:
		return ""
	var m = o.get_item_metadata(o.selected)
	return m if m != null else ""

## A checkable drop-down list feeding one of the filter sets.
func _multi(parent: Node, title: String, store: Dictionary) -> MenuButton:
	var mb = MenuButton.new()
	mb.text = title + " ▾"
	mb.flat = false
	var pm: PopupMenu = mb.get_popup()
	pm.hide_on_checkable_item_selection = false
	pm.id_pressed.connect(func(id):
		var i = pm.get_item_index(id)
		var key = pm.get_item_metadata(i)
		if store.has(key):
			store.erase(key)
		else:
			store[key] = true
		pm.set_item_checked(i, store.has(key))
		_sync_menus()
		_refresh_cards())
	parent.add_child(mb)
	return mb

func _sync_menus() -> void:
	for pair in [[kind_menu, sel_kinds, "Kinds"], [person_menu, sel_people, "People"], [place_menu, sel_places, "Places"]]:
		var mb: MenuButton = pair[0]
		var store: Dictionary = pair[1]
		var pm: PopupMenu = mb.get_popup()
		for i in range(pm.item_count):
			pm.set_item_checked(i, store.has(pm.get_item_metadata(i)))
		mb.text = "%s%s ▾" % [pair[2], (" (%d)" % store.size()) if not store.is_empty() else ""]

func _visible_cards() -> Array:
	var cards: Array = g.filter_cards(filter_edit.text)
	var lists: Array = []  # each ticked list -> set of matching card numbers
	if not sel_kinds.is_empty():
		var ks = {}
		for c in cards:
			if sel_kinds.has(c["kind"]):
				ks[c["n"]] = true
		lists.append(ks)
	for store in [sel_people, sel_places]:
		if store.is_empty():
			continue
		var ids = {}
		for key in store:
			for c in g.filter_cards(key):
				ids[c["n"]] = true
		lists.append(ids)
	if not lists.is_empty():
		var any = match_opt.selected <= 0
		cards = cards.filter(func(c):
			var hits = 0
			for st in lists:
				if st.has(c["n"]):
					hits += 1
			return hits > 0 if any else hits == lists.size())
	if not cell_filter.is_empty():
		cards = cards.filter(func(c): return c["n"] in cell_filter)
	return cards

func _refresh_cards() -> void:
	var keep: Array = card_list.selected_metas()
	card_list.reset()
	for c in _visible_cards():
		var line = "#%-3d %-10s %s%s" % [c["n"], c["kind"], "[hidden] " if c.get("hidden", false) else "", c["text"]]
		if g.debug_overlay:
			var dbg: String = g.debug_card_text(c)
			if dbg != "":
				line += "\n      ⟨" + dbg + "⟩"
		var col = null
		if c.get("hidden", false):
			col = Color(0.45, 0.45, 0.5)
		elif c["kind"] == "deduction":
			col = Color(0.95, 0.8, 0.45)
		elif c.get("source", "") != "player" and c.get("source", "") != "evidence":
			col = Color(0.72, 0.72, 0.78)
		card_list.add(line, c["n"], "%s\n[%s, %s%s]" % [c["text"], c["kind"], c.get("class", "?"),
			"" if c.get("source", "") == "player" else ", heard"], col)
		if c["n"] in keep:
			card_list.select_meta(c["n"])

## The working set (what Link and the builder use).
func selected_cards() -> Array:
	return staged.duplicate()

func _stage(nums: Array) -> void:
	for x in nums:
		if not (x in staged):
			staged.append(x)
	card_list.deselect_all()
	_refresh_work()

func _unstage(nums: Array) -> void:
	staged = staged.filter(func(x): return not (x in nums))
	_refresh_work()

func _refresh_work() -> void:
	if work_list == null or g == null:
		return
	staged = staged.filter(func(x): return x >= 1 and x <= g.board.size() and not g.board[x - 1].get("deleted", false))
	work_list.reset()
	for x in staged:
		var c: Dictionary = g.board[x - 1]
		work_list.add("#%-3d %-10s %s" % [x, c["kind"], c["text"]], x, c["text"],
			Color(0.95, 0.8, 0.45) if c["kind"] == "deduction" else null)
	_update_preview()

func _refresh_timeline() -> void:
	for ch in grid.get_children():
		ch.queue_free()
	var td: Dictionary = g.timeline_data()
	grid.columns = td["cols"].size() + 1
	grid.add_child(_cell_label(""))
	for col in td["cols"]:
		grid.add_child(_cell_label(col["label"]))
	for n in g.w.npcs:
		var nl = _cell_label(n.name if n.alive else n.name + " †")
		nl.add_theme_color_override("font_color", C.npc_color(n.id))
		grid.add_child(nl)
		for col in td["cols"]:
			var key = "%d:%d" % [col["day"], col["phase"]]
			var vals: Array = td["rows"][n.id].get(key, [])
			var b = Button.new()
			b.flat = true
			b.custom_minimum_size = Vector2(54, 24)
			b.add_theme_font_override("font", mono)
			b.add_theme_font_size_override("font_size", 12)
			var parts: Array = []
			var nums: Array = []
			var any_confirmed = false
			for v in vals:
				var tag = v["val"] + ("" if v["confirmed"] else "~")
				if not (tag in parts):
					parts.append(tag)
				nums.append(v["card"])
				any_confirmed = any_confirmed or v["confirmed"]
			b.text = "/".join(PackedStringArray(parts)) if not parts.is_empty() else "."
			b.add_theme_color_override("font_color", Color(1, 1, 1) if any_confirmed else Color(0.6, 0.6, 0.66))
			if not nums.is_empty():
				b.tooltip_text = "Cards #" + ", #".join(PackedStringArray(nums.map(func(x): return str(x))))
				b.pressed.connect(func():
					cell_filter = nums
					_refresh_cards())
			grid.add_child(b)

func _cell_label(t: String) -> Label:
	var l = Label.new()
	l.text = t
	l.add_theme_font_override("font", mono)
	l.add_theme_font_size_override("font_size", 12)
	return l

func _refresh_profile() -> void:
	var id = _meta(prof_opt)
	if id == "":
		return
	var p: Dictionary = g.profile_data(id)
	var lines = PackedStringArray()
	lines.append("[color=#%s][b]%s[/b][/color] the %s" % [C.npc_color(id).to_html(false), p["name"], p["occupation"]])
	lines.append(p["blurb"])
	lines.append("Works %s; lives on %s; %s." % [p["work"], p["home"], p["status"]])
	if p["claim"] != "":
		lines.append(p["claim"])
	for x in p["named"]:
		lines.append("Readings say: " + x)
	if g.debug_overlay:
		lines.append("[color=#9fd3a8]" + g.debug_npc_text(id) + "[/color]")
	var tl = PackedStringArray()
	for t in C.TRAITS:
		tl.append("%s %s" % [t.capitalize(), p["traits"].get(t, "?")])
	lines.append("Traits: " + ", ".join(tl))
	lines.append("")
	for num in p["cards"]:
		lines.append("#%d %s" % [num, g.board[num - 1]["text"]])
	prof_text.bbcode_enabled = true
	prof_text.text = "\n".join(lines)
	var gs: Dictionary = p["guess"]
	guess_opt.select(0)
	for i in range(guess_opt.item_count):
		if gs.get("guess", "?") == guess_opt.get_item_metadata(i):
			guess_opt.select(i)
	conf_spin.value = gs.get("confidence", 2)
	guess_opt.disabled = g.w.game_over
	conf_spin.editable = not g.w.game_over
	note_edit.text = p["note"]

func show_profile(id: String) -> void:
	for i in range(prof_opt.item_count):
		if prof_opt.get_item_metadata(i) == id:
			prof_opt.select(i)
	_refresh_profile()

func _on_save_profile() -> void:
	var id = _meta(prof_opt)
	if id == "":
		return
	g.set_note(id, note_edit.text)
	if not g.w.game_over:
		g.set_guess(id, guess_opt.get_item_metadata(guess_opt.selected), int(conf_spin.value))
	refresh()
	changed.emit()

func _clear_results() -> void:
	for ch in result_box.get_children():
		if ch != result_text:
			ch.queue_free()

func _on_link() -> void:
	_clear_results()
	var sel: Array = selected_cards()
	if sel.size() < 1 or sel.size() > 3:
		result_text.text = "Put 1 to 3 cards in your working set to link them."
		return
	var lk: Dictionary = g.link_cards(sel)
	var res: Dictionary = lk["result"]
	if res["matches"].is_empty():
		var t = "Nothing links cards %s: no conflict, corroboration or inference." % _nums(sel)
		for r in res["near"].slice(0, 2):
			t += "\nClose, but " + r
		t += "\nYou can still build a conclusion from them above: your own inference if they bear on that person, unfounded if not."
		result_text.text = t
		return
	var t2 = ""
	for m in res["matches"]:
		t2 += "%s %s\n" % [Argue.RELATION_LEAD[m.get("relation", "contradiction")], m["text"]]
	result_text.text = t2 + "Possible conclusions (this doesn't say which is true). Pick one to put it in the builder:"
	var k = 0
	for o in lk["options"]:
		k += 1
		var idx = k
		var b = _btn(result_box, "%d. %s" % [k, o["expl"]["label"]], func():
			_use_option(o)
			g.w.dlog.add("ui_use_option", "player", "", {"option": idx}))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = o["expl"]["label"]

func _nums(a: Array) -> String:
	return " ".join(PackedStringArray(a.map(func(x): return "#%d" % x)))

# ---------------------------------------------------------------- builder

func _fill_status() -> void:
	var verb: String = b_verb.get_item_text(max(0, b_verb.selected))
	b_status.clear()
	if b_who.selected >= 0 and b_who.get_item_metadata(b_who.selected) == "*group":
		# "Something doesn't add up": the people your working set rests on.
		b_verb.select(0)
		b_status.add_item("misled or lying (something doesn't add up)")
		b_status.set_item_metadata(0, "conflict")
		return
	for pair in Argue.BUILDER[verb]:
		b_status.add_item(pair[0])
		b_status.set_item_metadata(b_status.item_count - 1, pair[1])
	if verb != "should be":
		for r in C.GOOD_ROLES:
			b_status.add_item("the " + C.role_name(r))
			b_status.set_item_metadata(b_status.item_count - 1, r)

func _fill_nights() -> void:
	var keep = _meta_int(b_night)
	b_night.clear()
	b_night.add_item("(any night)")
	b_night.set_item_metadata(0, -1)
	for nt in range(0, g.w.day + 1):
		b_night.add_item("on night 0 (the first night)" if nt == 0 else "on night %d" % nt)
		b_night.set_item_metadata(b_night.item_count - 1, nt)
	for i in range(b_night.item_count):
		if b_night.get_item_metadata(i) == keep:
			b_night.select(i)

func _meta_int(o: OptionButton) -> int:
	if o == null or o.selected < 0 or o.item_count == 0:
		return -1
	return int(o.get_item_metadata(o.selected))

func _builder_changed() -> void:
	if not _setting:
		pending = {}
	_update_preview()

## The conclusion the builder currently describes (empty if incomplete).
func _built() -> Dictionary:
	if not pending.is_empty():
		return pending["conclusion"]
	if b_who.selected < 0 or b_status.selected < 0:
		return {}
	var who: String = b_who.get_item_metadata(b_who.selected)
	if who == "*group":
		return Argue.conflict_of(g.w, g.board.filter(func(x): return x["n"] in staged))
	var verb: String = b_verb.get_item_text(b_verb.selected)
	var status: String = b_status.get_item_metadata(b_status.selected)
	var c: Dictionary = Argue.from_builder(who, verb, status, _meta_int(b_night))
	if c.is_empty():
		return c
	if c["type"] in ["lied", "unreliable", "truthful"]:
		for x in selected_cards():
			if g.board[x - 1].get("source", "") == who:
				c["card"] = x
				break
	return c

func _update_preview() -> void:
	if b_preview == null or g == null:
		return
	var st: String = b_status.get_item_metadata(b_status.selected) if b_status.selected >= 0 else ""
	b_night.disabled = not pending.is_empty() or not (st in ["misled", "unreliable"])
	var sel: Array = pending["match"]["cards"] if not pending.is_empty() else selected_cards()
	b_because.text = "because: " + (_nums(sel) if not sel.is_empty() else "(add the supporting cards to your working set)")
	var c = _built()
	if c.is_empty():
		b_preview.text = ""
		return
	var backing = ("  [backed by a contradiction: %s]" % pending["match"]["text"]) if not pending.is_empty() else ""
	b_preview.text = Argue.conclusion_text(g.w, Argue.normalize(c.duplicate())) + backing
	b_error.text = ""

func _use_option(o: Dictionary) -> void:
	var c: Dictionary = Argue.normalize(o["expl"]["conclusion"].duplicate())
	_setting = true
	for i in range(b_who.item_count):
		if b_who.get_item_metadata(i) == (c.get("a", "") if c["type"] != "conflict" else "*group"):
			b_who.select(i)
	if c["type"] == "conflict":
		_fill_status()
		_setting = false
		pending = {"conclusion": c, "match": o["match"], "id": 0}
		_update_preview()
		return
	var verb = "is"
	var status: String = c["type"]
	match c["type"]:
		"role":
			status = c["role"]
		"notrole":
			verb = "is not"
			status = c["role"]
		"notdemon":
			verb = "is not"
		"truthful":
			verb = "is not"
		"protect", "spare":
			verb = "should be"
	for i in range(b_verb.item_count):
		if b_verb.get_item_text(i) == verb:
			b_verb.select(i)
	_fill_status()
	for i in range(b_status.item_count):
		if b_status.get_item_metadata(i) == status:
			b_status.select(i)
	for i in range(b_night.item_count):
		if b_night.get_item_metadata(i) == c.get("night", -1):
			b_night.select(i)
	_setting = false
	pending = {"conclusion": c, "match": o["match"], "id": o["expl"]["id"]}
	_update_preview()

func _on_file() -> void:
	var n = -1
	if not pending.is_empty():
		n = g.file_deduction(pending["conclusion"], pending["match"]["cards"], pending["match"], pending["id"])
	else:
		var c = _built()
		if c.is_empty():
			b_error.text = "That isn't a complete conclusion."
			return
		n = g.file_deduction(c, selected_cards())
	if n < 0:
		b_error.text = g.last_error
		return
	pending = {}
	b_error.text = ""
	_clear_results()
	result_text.text = "Filed card #%d: %s" % [n, g.board[n - 1]["text"]]
	staged = []
	card_list.deselect_all()
	refresh()
	changed.emit()

func _hide_selected(on: bool) -> void:
	var sel = card_list.selected_metas()
	if sel.is_empty():
		result_text.text = "Select cards to %s." % ("hide" if on else "unhide")
		return
	for x in sel:
		g.hide_card(x, on)
	_clear_results()
	result_text.text = "%s %s.%s" % ["Hid" if on else "Unhid", _nums(sel), " Tick 'Show hidden' to see hidden cards." if on and not g.show_hidden else ""]
	card_list.deselect_all()
	refresh()
	changed.emit()

func _delete_selected() -> void:
	var sel = (card_list.selected_metas() + work_list.selected_metas()).filter(func(x): return g.board[x - 1]["kind"] == "deduction")
	_clear_results()
	if sel.is_empty():
		result_text.text = "Select one of your deductions to delete. (Other cards can only be hidden.)"
		return
	for x in sel:
		g.delete_deduction(x)
	result_text.text = "Deleted deduction %s." % _nums(sel)
	card_list.deselect_all()
	refresh()
	changed.emit()
