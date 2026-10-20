## One person's profile, the same component on the town screen and the case board.
## Header: portrait, name, occupation, status; what they claim (their word) and your guess
## (your theory, styled so it can never pass for a confirmed role). Tabs: About | Their
## claims (what they've told you or the town) | About them (what others say of them). Card
## entries are links: clicking one selects that card (and shows it on the board). Your guess
## saves as you change it. (Case notes live in their own window.)
extends VBoxContainer

signal changed                # guess or notes saved
signal card_clicked(num)
signal card_context_requested(num, at)
signal person_changed(id)

const C = preload("res://sim/content.gd")
const CardModel = preload("res://game/card_model.gd")
const UITheme = preload("res://ui/theme.gd")
const Formatter = preload("res://ui/text_formatter.gd")
const Renderer = preload("res://ui/rich_text_renderer.gd")
const FormattedTextLabel = preload("res://ui/formatted_text_label.gd")

const TABS = ["About", "Their claims", "About them"]
const TraitBars = preload("res://ui/trait_bars.gd")

var g
var state
var person_opt: OptionButton
var portrait: TextureRect
var name_label: Label
var sub_label: Label
var claim_icon: TextureRect
var claim_label: RichTextLabel
var guess_opt: OptionButton
var conf_opt: OptionButton      # confidence in the role guess: Flimsy, Maybe, Likely, Confirmed
var secret_opt: OptionButton
var secret_conf_opt: OptionButton
var tab_buttons: Array = []
var body: RichTextLabel
var bars
var tab = 0
var _setting = false
var compact = false   # the town screen's narrower column: smaller portrait
var _hovered_card = 0
var formatter = Formatter.new()
var renderer = Renderer.new()

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
	var hv = VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	head.add_child(hv)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hv.add_child(hb)
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
	name_label.add_theme_font_override("font", UITheme.font_face(UITheme.serif(), true))
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
	claim_label = FormattedTextLabel.new()
	claim_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	claim_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim_label.fit_content = true
	claim_label.scroll_active = false
	claim_label.hint_underlined = false
	UITheme.rich_text_fonts(claim_label, UITheme.serif())
	crow.add_child(claim_label)
	# Your guesses: pencilled notes, visibly yours, not facts. A role and a secret, each
	# with how sure you are.
	var gl = Label.new()
	gl.text = "Your guesses:"
	gl.add_theme_font_size_override("font_size", 15)
	gl.add_theme_color_override("font_color", UITheme.color("red"))
	hv.add_child(gl)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	var gpad = MarginContainer.new()
	gpad.add_theme_constant_override("margin_left", 14)
	gpad.add_theme_constant_override("margin_bottom", 6)
	gpad.add_child(grid)
	hv.add_child(gpad)
	guess_opt = OptionButton.new()
	for x in ["?", "good", "evil"] + C.GOOD_ROLES + C.EVIL_ROLES:
		guess_opt.add_item((x if not C.ROLES.has(x) else C.role_name(x)) + ("" if x == "?" else " ?"))
		guess_opt.set_item_metadata(guess_opt.item_count - 1, x)
	guess_opt.tooltip_text = "Your private theory about this person's role. Nobody else sees it."
	guess_opt.item_selected.connect(func(_i): _save_guess())
	secret_opt = OptionButton.new()
	for x in ["?", "none"] + C.SECRET_MOD_LIST:
		secret_opt.add_item("?" if x == "?" else ("None" if x == "none" else C.secret_name(x)) + " ?")
		secret_opt.set_item_metadata(secret_opt.item_count - 1, x)
	secret_opt.tooltip_text = "Your guess at whether they carry the secret in play, and which."
	secret_opt.item_selected.connect(func(_i): _save_secret())
	conf_opt = _conf_menu()
	conf_opt.item_selected.connect(func(_i): _save_guess())
	secret_conf_opt = _conf_menu()
	secret_conf_opt.item_selected.connect(func(_i): _save_secret())
	for row in [["Role:", guess_opt, conf_opt], ["Secret:", secret_opt, secret_conf_opt]]:
		var l1 = Label.new()
		l1.text = row[0]
		l1.add_theme_font_size_override("font_size", 15)
		l1.add_theme_color_override("font_color", UITheme.color("ink_soft"))
		grid.add_child(l1)
		row[1].add_theme_font_size_override("font_size", 15)
		row[1].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(row[1])
		var l2 = Label.new()
		l2.text = "Confidence:"
		l2.add_theme_font_size_override("font_size", 15)
		l2.add_theme_color_override("font_color", UITheme.color("ink_soft"))
		grid.add_child(l2)
		grid.add_child(row[2])

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
	var pv = VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	page.add_child(pv)
	bars = TraitBars.new()
	pv.add_child(bars)
	body = FormattedTextLabel.new()
	body.bbcode_enabled = true
	body.hint_underlined = false
	UITheme.rich_text_fonts(body, UITheme.serif())
	body.context_menu_enabled = false
	body.meta_hover_started.connect(func(meta):
		var value = str(meta)
		_hovered_card = value.substr(5).to_int() if value.begins_with("card:") else 0)
	body.meta_hover_ended.connect(func(_meta): _hovered_card = 0)
	body.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and _hovered_card > 0:
			card_context_requested.emit(_hovered_card, Vector2i(body.get_screen_transform() * ev.position))
			body.accept_event())
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
	pv.add_child(body)

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

func _conf_menu() -> OptionButton:
	var o = OptionButton.new()
	for i in range(C.CONFIDENCE.size()):
		o.add_item(C.CONFIDENCE[i])
		o.set_item_metadata(i, i + 1)
	o.select(1)
	o.add_theme_font_size_override("font_size", 15)
	o.tooltip_text = "How sure you are."
	return o

func _conf_of(o: OptionButton) -> int:
	return int(o.get_item_metadata(o.selected)) if o.selected >= 0 else 2

func _save_secret() -> void:
	if _setting or g == null or current() == "" or g.w.game_over:
		return
	g.set_secret_guess(current(), secret_opt.get_item_metadata(secret_opt.selected), _conf_of(secret_conf_opt))
	changed.emit()

## Save the guess (and notes) now; used by the case board's banner shortcut and tests.
func save() -> void:
	var id = current()
	if id == "" or g == null:
		return
	if not g.w.game_over:
		g.set_guess(id, guess_opt.get_item_metadata(guess_opt.selected), _conf_of(conf_opt))
	changed.emit()

func _save_guess() -> void:
	if _setting or g == null or current() == "" or g.w.game_over:
		return
	g.set_guess(current(), guess_opt.get_item_metadata(guess_opt.selected), _conf_of(conf_opt))
	changed.emit()

func refresh() -> void:
	_hovered_card = 0
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
	claim_label.clear()
	renderer.append_to(claim_label, formatter.format_text(claim_txt, {"surface": "paper", "icons": false, "role_context": true}))
	claim_icon.texture = UITheme.tex("ui/roles/" + role, 0.07) if role != "" else null
	var gs: Dictionary = p["guess"]
	guess_opt.select(0)
	for i in range(guess_opt.item_count):
		if gs.get("guess", "?") == guess_opt.get_item_metadata(i):
			guess_opt.select(i)
	conf_opt.select(clampi(int(gs.get("confidence", 2)), 1, 4) - 1)
	secret_opt.select(0)
	for i in range(secret_opt.item_count):
		if gs.get("secret", "?") == secret_opt.get_item_metadata(i):
			secret_opt.select(i)
	secret_conf_opt.select(clampi(int(gs.get("secret_conf", 2)), 1, 4) - 1)
	for o in [guess_opt, conf_opt, secret_opt, secret_conf_opt]:
		o.disabled = g.w.game_over
	for i in range(tab_buttons.size()):
		tab_buttons[i].set_pressed_no_signal(i == tab)
	_setting = false
	_render_page(id, p)
	bars.visible = tab == 0
	bars.show_traits(p["traits"])

func _append_profile(text: String, context: Dictionary = {}) -> void:
	var style = {"surface": "paper", "icon_size": 18}
	style.merge(context, true)
	renderer.append_to(body, formatter.format_text(text, style))

func _render_page(id: String, p: Dictionary) -> void:
	body.clear()
	match tab:
		0:
			var bl: String = p["blurb"]
			body.push_italics()
			_append_profile("%s." % (bl[0].to_upper() + bl.substr(1)), {"kinds": ["person"]})
			body.pop()
			_append_profile("\nWorks %s; lives on %s." % [p["work"], p["home"]], {"kinds": ["person"]})
			if p.get("haunts", "") != "":
				_append_profile("\nOff work, often at %s." % p["haunts"], {"kinds": ["person"]})
			else:
				_append_profile("\nWhere they go off work: nobody's told you yet. Ask around.")
			for x in p["named"]:
				_append_profile("\nReadings say: " + x)
			if g.debug_overlay:
				_append_profile("\n\n" + g.debug_npc_text(id), {"enabled": false, "base_color": Color("2f6b3a")})
		1:
			var said: Array = g.board.filter(func(c): return not c.get("deleted", false) and c.get("kind", "") != "deduction" and \
				(c.get("source", "") == id or c.get("via", "") == id or c.get("learned", []).any(func(d): return d.get("via", "") == id)))
			_append_profile("What %s has said" % p["name"], {"bold": true}) if not said.is_empty() else _append_profile("%s hasn't told you anything yet." % p["name"])
			if not said.is_empty():
				_append_profile(" (to you, or to the town)")
			_render_entries(said, id)
		2:
			var about: Array = g.board.filter(func(c): return not c.get("deleted", false) and c.get("source", "") != id and id in CardModel.about(c))
			_append_profile("What's been said or seen of %s" % p["name"], {"bold": true}) if not about.is_empty() else _append_profile("Nothing on your board about %s yet." % p["name"])
			_render_entries(about, id)

## Card links, oldest first, each with when it happened and how you heard it.
func _render_entries(cards: Array, id: String) -> void:
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
		var cb: Array = c.get("corroborated_by", [])
		if not cb.is_empty():
			heard.append("also seen by " + ", ".join(PackedStringArray(cb.map(func(x): return "you" if x == "player" else (g.w.by_id[x].name if g.w.by_id.has(x) else x)))))
		var opacity = UITheme.HIDDEN_CARD_ALPHA if c.get("hidden", false) else 1.0
		_append_profile("\n%s " % CardModel.time_label(t), {"base_color": Color("8a7a5a"), "opacity": opacity})
		body.push_meta("card:%d" % c["n"])
		_append_profile("#%d %s" % [c["n"], c.get("text", "")], {"base_color": Color("7a1f1a") if c.get("kind", "") == "deduction" else UITheme.color("ink"),
			"opacity": opacity, "role_context": c.get("kind", "") == "claim"})
		body.pop()
		_append_profile(" (%s)" % ", ".join(PackedStringArray(heard)), {"base_color": Color("8a7a5a"), "font_size": 14, "opacity": opacity})
