## Full-screen case view: filters, card list with selection, timeline grid, profiles,
## and the Link / Conclude builder. Reads the game's structured data directly.
extends PanelContainer

signal changed

const C = preload("res://sim/content.gd")
const Argue = preload("res://sim/argue.gd")

var g
var mono: Font
var filter_edit: LineEdit
var kind_opt: OptionButton
var person_opt: OptionButton
var place_opt: OptionButton
var card_list: ItemList
var grid: GridContainer
var prof_opt: OptionButton
var prof_text: RichTextLabel
var guess_opt: OptionButton
var conf_spin: SpinBox
var note_edit: TextEdit
var result_text: RichTextLabel
var result_box: VBoxContainer
var cell_filter: Array = []   # card numbers picked from a timeline cell ([] = off)

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

	var top = HBoxContainer.new()
	root.add_child(top)
	var title = Label.new()
	title.text = "CASE VIEW"
	top.add_child(title)
	filter_edit = LineEdit.new()
	filter_edit.placeholder_text = "filter: text, d2, n1 ..."
	filter_edit.custom_minimum_size = Vector2(220, 0)
	filter_edit.text_changed.connect(func(_t): _refresh_cards())
	top.add_child(filter_edit)
	kind_opt = _option(top, KINDS, func(_i): _refresh_cards())
	person_opt = OptionButton.new()
	person_opt.item_selected.connect(func(_i): _refresh_cards())
	top.add_child(person_opt)
	place_opt = OptionButton.new()
	place_opt.item_selected.connect(func(_i): _refresh_cards())
	top.add_child(place_opt)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_btn(top, "Close", func(): visible = false)

	var body = HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 0)
	body.add_child(left)
	var ll = Label.new()
	ll.text = "Cards (select 1-3 to link, or as support for a conclusion)"
	left.add_child(ll)
	card_list = ItemList.new()
	card_list.select_mode = ItemList.SELECT_MULTI
	card_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_list.add_theme_font_override("font", mono)
	card_list.add_theme_font_size_override("font_size", 13)
	left.add_child(card_list)
	var lb = HBoxContainer.new()
	left.add_child(lb)
	_btn(lb, "Link selected", _on_link)
	_btn(lb, "Conclude...", _on_conclude_form)
	_btn(lb, "Clear", func():
		card_list.deselect_all()
		cell_filter = []
		_refresh_cards())

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
	res_title.text = "Builder"
	mid.add_child(res_title)
	var rs = ScrollContainer.new()
	rs.custom_minimum_size = Vector2(0, 220)
	mid.add_child(rs)
	result_box = VBoxContainer.new()
	result_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.add_child(result_box)
	result_text = RichTextLabel.new()
	result_text.fit_content = true
	result_text.custom_minimum_size = Vector2(400, 0)
	result_text.text = "Select cards and press Link to check them for a contradiction."
	result_box.add_child(result_text)

	var right = VBoxContainer.new()
	right.custom_minimum_size = Vector2(320, 0)
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
	person_opt.clear()
	person_opt.add_item("anyone")
	person_opt.set_item_metadata(0, "")
	prof_opt.clear()
	for n in g.w.npcs:
		person_opt.add_item(n.name)
		person_opt.set_item_metadata(person_opt.item_count - 1, n.id)
		prof_opt.add_item(n.name)
		prof_opt.set_item_metadata(prof_opt.item_count - 1, n.id)
	place_opt.clear()
	place_opt.add_item("anywhere")
	place_opt.set_item_metadata(0, "")
	for b in C.BLOCKS:
		place_opt.add_item(C.block_name(b))
		place_opt.set_item_metadata(place_opt.item_count - 1, b)
	for l in C.LOCATIONS:
		place_opt.add_item("  " + C.loc_name(l))
		place_opt.set_item_metadata(place_opt.item_count - 1, l)
	refresh()

func refresh() -> void:
	if g == null:
		return
	_refresh_cards()
	_refresh_timeline()
	_refresh_profile()

func _meta(o: OptionButton) -> String:
	if o.selected < 0:
		return ""
	var m = o.get_item_metadata(o.selected)
	return m if m != null else ""

func _visible_cards() -> Array:
	var cards: Array = g.filter_cards(filter_edit.text)
	var kind = KINDS[kind_opt.selected] if kind_opt.selected >= 0 else "all"
	if kind != "all":
		cards = cards.filter(func(c): return c["kind"] == kind)
	var who = _meta(person_opt)
	if who != "":
		var ids: Array = g.filter_cards(who).map(func(c): return c["n"])
		cards = cards.filter(func(c): return c["n"] in ids)
	var place = _meta(place_opt)
	if place != "":
		var pids: Array = g.filter_cards(place).map(func(c): return c["n"])
		cards = cards.filter(func(c): return c["n"] in pids)
	if not cell_filter.is_empty():
		cards = cards.filter(func(c): return c["n"] in cell_filter)
	return cards

func _refresh_cards() -> void:
	var keep: Array = selected_cards()
	card_list.clear()
	for c in _visible_cards():
		var line = "#%-3d %-10s %s" % [c["n"], c["kind"], c["text"]]
		card_list.add_item(line)
		var i = card_list.item_count - 1
		card_list.set_item_metadata(i, c["n"])
		card_list.set_item_tooltip(i, "%s\n[%s, %s%s]" % [c["text"], c["kind"], c.get("class", "?"),
			"" if c.get("source", "") == "player" else ", heard"])
		if c["kind"] == "deduction":
			card_list.set_item_custom_fg_color(i, Color(0.95, 0.8, 0.45))
		elif c.get("source", "") != "player" and c.get("source", "") != "evidence":
			card_list.set_item_custom_fg_color(i, Color(0.72, 0.72, 0.78))
		if c["n"] in keep:
			card_list.select(i, false)

func selected_cards() -> Array:
	var out: Array = []
	if card_list == null:
		return out
	for i in card_list.get_selected_items():
		out.append(card_list.get_item_metadata(i))
	return out

func _refresh_timeline() -> void:
	for ch in grid.get_children():
		ch.queue_free()
	var td: Dictionary = g.timeline_data()
	grid.columns = td["cols"].size() + 1
	grid.add_child(_cell_label(""))
	for col in td["cols"]:
		grid.add_child(_cell_label(col["label"]))
	for n in g.w.npcs:
		grid.add_child(_cell_label(n.name if n.alive else n.name + " †"))
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
	lines.append("[b]%s[/b] the %s" % [p["name"], p["occupation"]])
	lines.append(p["blurb"])
	lines.append("Works %s; lives on %s; %s." % [p["work"], p["home"], p["status"]])
	if p["claim"] != "":
		lines.append(p["claim"])
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
	note_edit.text = p["note"]

func _on_save_profile() -> void:
	var id = _meta(prof_opt)
	if id == "":
		return
	g.set_guess(id, guess_opt.get_item_metadata(guess_opt.selected), int(conf_spin.value))
	g.set_note(id, note_edit.text)
	changed.emit()

func _clear_results() -> void:
	for ch in result_box.get_children():
		if ch != result_text:
			ch.queue_free()

func _on_link() -> void:
	_clear_results()
	var sel: Array = selected_cards()
	if sel.size() < 1 or sel.size() > 3:
		result_text.text = "Select 1 to 3 cards to link."
		return
	var lk: Dictionary = g.link_cards(sel)
	var res: Dictionary = lk["result"]
	if res["matches"].is_empty():
		var t = "No contradiction between cards %s." % str(sel)
		for r in res["near"].slice(0, 2):
			t += "\nClose, but " + r
		t += "\nYou can still file a conclusion from them (Conclude...); it will be marked unfounded."
		result_text.text = t
		return
	var t2 = ""
	var k = 0
	for m in res["matches"]:
		t2 += "These conflict: %s\n" % m["text"]
	result_text.text = t2 + "File the explanation you believe:"
	for o in lk["options"]:
		k += 1
		var idx = k
		_btn(result_box, "%d. %s" % [k, o["expl"]["label"]], func():
			var n = g.file_deduction(o["expl"]["conclusion"], o["match"]["cards"], o["match"], o["expl"]["id"])
			result_text.text = "Filed card #%d: %s" % [n, g.board[n - 1]["text"]]
			_clear_results()
			g.w.dlog.add("ui_conclude", "player", "", {"option": idx})
			refresh()
			changed.emit())

func _on_conclude_form() -> void:
	_clear_results()
	var sel: Array = selected_cards()
	result_text.text = "New conclusion (supports: %s)" % (str(sel) if not sel.is_empty() else "none selected")
	var row = HBoxContainer.new()
	result_box.add_child(row)
	var type_opt = OptionButton.new()
	for t in Argue.CONCLUSION_TYPES:
		type_opt.add_item(t)
	row.add_child(type_opt)
	var who_opt = OptionButton.new()
	for n in g.w.npcs:
		who_opt.add_item(n.name)
		who_opt.set_item_metadata(who_opt.item_count - 1, n.id)
	row.add_child(who_opt)
	var role_opt = OptionButton.new()
	for r in C.GOOD_ROLES:
		role_opt.add_item(C.role_name(r))
		role_opt.set_item_metadata(role_opt.item_count - 1, r)
	row.add_child(role_opt)
	var night_spin = SpinBox.new()
	night_spin.prefix = "night"
	night_spin.max_value = 9
	row.add_child(night_spin)
	var card_spin = SpinBox.new()
	card_spin.prefix = "card #"
	card_spin.min_value = 0
	card_spin.max_value = max(1, g.board.size())
	row.add_child(card_spin)
	_btn(result_box, "File conclusion", func():
		var c = {"type": Argue.CONCLUSION_TYPES[type_opt.selected], "a": who_opt.get_item_metadata(who_opt.selected)}
		if c["type"] in ["role", "notrole"]:
			c["role"] = role_opt.get_item_metadata(role_opt.selected)
		if c["type"] == "poisoned":
			c["night"] = int(night_spin.value)
		if c["type"] in ["lied", "mistaken"]:
			c["card"] = int(card_spin.value)
		var n = g.file_deduction(c, sel)
		result_text.text = "Filed card #%d: %s" % [n, g.board[n - 1]["text"]]
		_clear_results()
		refresh()
		changed.emit())
