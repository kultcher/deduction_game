## One person's profile, the same component on the town screen and the case board.
## Header: portrait, name, occupation, status; what they claim (their word) and your guess
## (your theory, styled so it can never pass for a confirmed role). Tabs: About | Their
## claims (what they've told you or the town) | About them (what others say of them). Card
## entries are links: clicking one selects that card (and shows it on the board). Your guess
## saves as you change it. (Case notes live in their own window.)
extends VBoxContainer

signal changed                # guess or notes saved
signal card_clicked(num)
signal person_changed(id)

const C = preload("res://sim/content.gd")
const CardModel = preload("res://game/card_model.gd")
const UITheme = preload("res://ui/theme.gd")

const TABS = ["About", "Their claims", "About them"]

var g
var state
var person_opt: OptionButton
var portrait: TextureRect
var name_label: Label
var sub_label: Label
var claim_icon: TextureRect
var claim_label: Label
var guess_opt: OptionButton
var conf_spin: SpinBox
var tab_buttons: Array = []
var body: RichTextLabel
var tab = 0
var _setting = false
var compact = false   # the town screen's narrower column: smaller portrait

func _init(is_compact: bool = false) -> void:
	compact = is_compact
	add_theme_constant_override("separation", 6)

func _ready() -> void:
	if person_opt == null:
		build()

func build() -> void:
	person_opt = OptionButton.new()
	person_opt.clip_text = true
	person_opt.item_selected.connect(func(_i):
		if _setting:
			return
		var id = current()
		if state != null:
			state.select_person(id)
		person_changed.emit(id)
		refresh())
	add_child(person_opt)

	# Header on framed paper: portrait beside name, claim and guess.
	var head = PanelContainer.new()
	head.add_theme_stylebox_override("panel", UITheme.panel("paper"))
	add_child(head)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	head.add_child(hb)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(78, 92) if compact else Vector2(112, 132)
	hb.add_child(portrait)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	hb.add_child(info)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 22 if compact else 26)
	info.add_child(name_label)
	sub_label = Label.new()
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_label.add_theme_font_size_override("font_size", 15)
	sub_label.add_theme_color_override("font_color", UITheme.color("ink_soft"))
	info.add_child(sub_label)
	var crow = HBoxContainer.new()
	info.add_child(crow)
	claim_icon = TextureRect.new()
	claim_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	claim_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	claim_icon.custom_minimum_size = Vector2(22, 22)
	crow.add_child(claim_icon)
	claim_label = Label.new()
	claim_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	claim_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim_label.add_theme_font_size_override("font_size", 16)
	claim_label.add_theme_color_override("font_color", UITheme.color("ink"))
	crow.add_child(claim_label)
	# Your guess: a pencilled note, visibly yours, not a fact.
	var grow = HBoxContainer.new()
	info.add_child(grow)
	var gl = Label.new()
	gl.text = "Your guess:"
	gl.add_theme_font_size_override("font_size", 15)
	gl.add_theme_color_override("font_color", UITheme.color("red"))
	grow.add_child(gl)
	guess_opt = OptionButton.new()
	guess_opt.add_theme_font_size_override("font_size", 15)
	for x in ["?", "good", "evil"] + C.GOOD_ROLES + ["demon", "poisoner"]:
		guess_opt.add_item((x if not C.ROLES.has(x) else C.role_name(x)) + ("" if x == "?" else " ?"))
		guess_opt.set_item_metadata(guess_opt.item_count - 1, x)
	guess_opt.tooltip_text = "Your private theory about this person. Nobody else sees it."
	guess_opt.item_selected.connect(func(_i): _save_guess())
	grow.add_child(guess_opt)
	conf_spin = SpinBox.new()
	conf_spin.min_value = 1
	conf_spin.max_value = 3
	conf_spin.value = 2
	conf_spin.prefix = "sure"
	conf_spin.tooltip_text = "How sure you are (1-3)."
	conf_spin.value_changed.connect(func(_v): _save_guess())
	grow.add_child(conf_spin)

	# Tabs.
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	add_child(tabs)
	for i in range(TABS.size()):
		var k = i
		var b = Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func():
			tab = k
			refresh())
		tabs.add_child(b)
		tab_buttons.append(b)
	var page = PanelContainer.new()
	page.add_theme_stylebox_override("panel", UITheme.flat(UITheme.color("paper"), UITheme.color("border"), 1, 4, 10))
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(0, 140 if compact else 200)
	body.add_theme_font_size_override("normal_font_size", 16)
	body.add_theme_color_override("default_color", UITheme.color("ink"))
	body.meta_clicked.connect(func(meta):
		var s = str(meta)
		if s.begins_with("card:"):
			var n = s.substr(5).to_int()
			if state != null:
				state.select_card(n)
			card_clicked.emit(n))
	page.add_child(body)

func setup(game, st) -> void:
	g = game
	state = st
	if person_opt == null:
		build()
	_setting = true
	person_opt.clear()
	for n in g.w.npcs:
		person_opt.add_item(n.name)
		person_opt.set_item_metadata(person_opt.item_count - 1, n.id)
		person_opt.set_item_icon(person_opt.item_count - 1, _swatch(C.npc_color(n.id)))
	_setting = false
	refresh()

func _swatch(c: Color) -> Texture2D:
	var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func current() -> String:
	if person_opt == null or person_opt.selected < 0:
		return ""
	return person_opt.get_item_metadata(person_opt.selected)

func show_person(id: String) -> void:
	if person_opt == null:
		return
	_setting = true
	for i in range(person_opt.item_count):
		if person_opt.get_item_metadata(i) == id:
			person_opt.select(i)
	_setting = false
	refresh()

## Save the guess (and notes) now; used by the case board's banner shortcut and tests.
func save() -> void:
	var id = current()
	if id == "" or g == null:
		return
	if not g.w.game_over:
		g.set_guess(id, guess_opt.get_item_metadata(guess_opt.selected), int(conf_spin.value))
	changed.emit()

func _save_guess() -> void:
	if _setting or g == null or current() == "" or g.w.game_over:
		return
	g.set_guess(current(), guess_opt.get_item_metadata(guess_opt.selected), int(conf_spin.value))
	changed.emit()

func refresh() -> void:
	if g == null or person_opt == null:
		return
	var id = current()
	if id == "":
		return
	var n = g.w.by_id[id]
	var p: Dictionary = g.profile_data(id)
	_setting = true
	var tex = UITheme.tex("art/portraits/" + id, 0.5)
	portrait.texture = tex
	portrait.modulate = Color(1, 1, 1) if n.alive else Color(0.45, 0.42, 0.42, 0.85)
	name_label.text = p["name"] + ("" if n.alive else "  †")
	name_label.add_theme_color_override("font_color", UITheme.ink_of(C.npc_color(id)))
	var st: String = p["status"]
	sub_label.text = "%s · %s" % [p["occupation"].capitalize(), st[0].to_upper() + st.substr(1)]
	# What they claim, in their words.
	var role = ""
	var claim_txt = "No claim yet."
	if n.claim_public:
		role = n.claimed_role
		claim_txt = "Claims: %s (to the town)" % C.role_name(role)
	elif n.max_tier >= 3 and C.ROLES.has(n.claimed_role):
		role = n.claimed_role
		claim_txt = "Claims: %s (told you privately)" % C.role_name(role)
	elif n.claimed_role == "none":
		role = "none"
		claim_txt = "Says they have no gift."
	elif n.max_tier == 2:
		var pk: String = C.package_of(g.w.evil_plan["bluffs"][id] if n.is_evil() else n.role)
		claim_txt = "Hinted at %s." % C.HINT_PACKAGES[pk]["name"] if C.HINT_PACKAGES.has(pk) else "Hinted at a gift."
		role = "unknown"
	claim_label.text = claim_txt
	claim_icon.texture = UITheme.tex("ui/roles/" + role, 0.07) if role != "" else null
	var gs: Dictionary = p["guess"]
	guess_opt.select(0)
	for i in range(guess_opt.item_count):
		if gs.get("guess", "?") == guess_opt.get_item_metadata(i):
			guess_opt.select(i)
	conf_spin.value = gs.get("confidence", 2)
	guess_opt.disabled = g.w.game_over
	conf_spin.editable = not g.w.game_over
	for i in range(tab_buttons.size()):
		tab_buttons[i].set_pressed_no_signal(i == tab)
	_setting = false
	body.text = _page(id, p)

func _ink(hex_from: Color) -> String:
	return UITheme.ink_of(hex_from).to_html(false)

func _page(id: String, p: Dictionary) -> String:
	var lines = PackedStringArray()
	match tab:
		0:
			var bl: String = p["blurb"]
			lines.append("[i]%s.[/i]" % (bl[0].to_upper() + bl.substr(1)))
			lines.append("Works %s; lives on %s." % [p["work"], p["home"]])
			var tl = PackedStringArray()
			for t in C.TRAITS:
				tl.append("%s [b]%s[/b]" % [t.capitalize(), p["traits"].get(t, "?")])
			lines.append("Traits: " + ", ".join(tl))
			for x in p["named"]:
				lines.append("Readings say: " + x)
			if g.debug_overlay:
				lines.append("")
				lines.append("[color=#2f6b3a]" + g.debug_npc_text(id) + "[/color]")
		1:
			var said: Array = g.board.filter(func(c): return not c.get("deleted", false) and c.get("kind", "") != "deduction" and \
				(c.get("source", "") == id or c.get("via", "") == id or c.get("learned", []).any(func(d): return d.get("via", "") == id)))
			lines.append("[b]What %s has said[/b] (to you, or to the town)" % p["name"] if not said.is_empty() else "%s hasn't told you anything yet." % p["name"])
			lines += _entries(said, id)
		2:
			var about: Array = g.board.filter(func(c): return not c.get("deleted", false) and c.get("source", "") != id and id in CardModel.about(c))
			lines.append("[b]What's been said or seen of %s[/b]" % p["name"] if not about.is_empty() else "Nothing on your board about %s yet." % p["name"])
			lines += _entries(about, id)
	return "\n".join(lines)

## Card links, oldest first, each with when it happened and how you heard it.
func _entries(cards: Array, id: String) -> PackedStringArray:
	var out = PackedStringArray()
	var sorted = cards.duplicate()
	sorted.sort_custom(func(a, b): return CardModel.time_order(a.get("when", {"day": a.get("day", 0), "phase": 0})) < CardModel.time_order(b.get("when", {"day": b.get("day", 0), "phase": 0})))
	for c in sorted:
		var t: Dictionary = c.get("when", {"day": c.get("day", 0), "phase": 0})
		var heard: Array = []
		for d in c.get("learned", []):
			var who: String = d.get("via", "")
			var how = "public" if d.get("public", false) else ("private" if who == id or who == c.get("source", "") else "via " + (g.w.by_id[who].name if g.w.by_id.has(who) else "you"))
			if who in ["player", "evidence", ""]:
				how = "you saw" if not d.get("public", false) else "public"
			# First time heard each way only (asking again doesn't need listing).
			if not heard.any(func(x): return x.ends_with(" " + how)):
				heard.append("%s %s" % [CardModel.time_label({"day": d["day"], "phase": d["phase"]}), how])
		var col = "7a1f1a" if c.get("kind", "") == "deduction" else "2b2116"
		out.append("[color=#8a7a5a]%s[/color] [url=card:%d][color=#%s]#%d %s[/color][/url] [color=#8a7a5a](%s)[/color]" %
			[CardModel.time_label(t), c["n"], col, c["n"], c.get("text", ""), ", ".join(PackedStringArray(heard))])
	return out
