## The daily evil-team guess (Michael, Nov 21; docs/design/grim_reveal.md "Corrections").
## Each day, once the meeting is settled and before the hanging is announced, the screen fades
## to a window where the player locks in who they believe is evil: a Demon circle on top, a
## Minion circle for each Minion in play below it, each with its type. The last guesses locked
## here are the player's verdict, which the grim reveal plays against; there's no end-of-game
## seal. The window keeps its own locked guesses; Demon or Minion picks from the profile
## prefill empty circles, greyed, until confirmed. It never writes back to the profile.
## Bookkeeping only: no mechanical effect. The logic is static so tests can drive it.
extends Control

const C = preload("res://sim/content.gd")
const CaseMetrics = preload("res://game/case_metrics.gd")
const UITheme = preload("res://ui/theme.gd")
const PortraitFx = preload("res://ui/portrait_fx.gd")

## Wording (Michael, Nov 21: all approved; "we can tweak it later if needed").
const TITLE = "Your suspicions"
const DEMON_LABEL = "DEMON"
const MINION_LABEL = "MINION"
const EMPTY_CIRCLE = "Choose…"
const PICK_DEMON = "Who is the Demon?"
const PICK_MINION = "Who is a Minion?"
const DEMON_KILLED_TIP = "Killed by the Demon; it cannot be them."
const TYPE_PLACEHOLDER = "What kind?"
const CLEAR_PICK = "No one"
const PROFILE_NOTE = "Greyed: from your notes. Pick someone new, or confirm to lock them in."
const CONFIRM = "Confirm"
const SKIP = "Skip"
const DONT_ASK = "Don't ask again this case"
const MENU_ENTRY = "Your suspicions"
const CHANGE_DIALOG = "Change your Demon selection? You can only do this two times per case. (%d change(s) remaining)."
const NO_CHANGES_TIP = "No changes left this case"

## The Demon guess (Michael, Nov 21): the first pick is free, then two changes a case. Minion
## picks and every type are free. Clearing a locked Demon counts as a change.
const DEMON_CHANGES = 2

const META_LOCKED = "daily_guess_locked"   # on the game: {"picks": [...], "history": [{"day", "picks"}]}
const PORTRAIT_SIZE = 112
const PICKER_PORTRAIT_SIZE = 64
const FADE_SECONDS = 0.35
const GREYED = Color(1, 1, 1, 0.45)


## The circles this case shows: the Demon first, then one per Minion in play. Each has a role
## ("demon" or "minion") and the types the script allows for it.
static func slots(g) -> Array:
	var sc = g.w.case_script
	var demons: Array = sc.demons.duplicate() if sc != null else C.EVIL_ROLES.filter(func(r): return C.is_demon(r))
	var minions: Array = sc.minions.duplicate() if sc != null else C.EVIL_ROLES.filter(func(r): return C.is_minion(r))
	var out: Array = [{"role": "demon", "types": demons}]
	# Count the Minions dealt at the start: a Scion's hidden promotion takes one off minion_ids,
	# and dropping a circle would give it away (Codex on #496).
	var dealt: Array = g.w.initial_minion_ids if not g.w.initial_minion_ids.is_empty() else g.w.minion_ids
	for i in range(dealt.size()):
		out.append({"role": "minion", "types": minions})
	return out


## Whether this person can be picked for a circle. The Demon picker crosses out those the Demon
## killed; Minion pickers leave them open (the Demon may one day kill its own).
static func pickable(g, role: String, id: String) -> bool:
	var n = g.w.by_id.get(id)
	if n == null:
		return false
	return not (role == "demon" and not n.alive and n.death_cause == "demon")


## The guesses locked so far, one per circle ({"id", "type"}); empty circles have id "".
static func locked(g) -> Array:
	var ss: Array = slots(g)
	var stored: Array = g.get_meta(META_LOCKED, {}).get("picks", []) if g.has_meta(META_LOCKED) else []
	var out: Array = []
	for i in range(ss.size()):
		out.append(stored[i].duplicate() if i < stored.size() else {"id": "", "type": _default_type(ss[i])})
	return out


## The circles as the window opens: the locked guesses, then empty circles prefilled from the
## profile's Demon and Minion picks, marked "from_profile" (greyed) until the player confirms.
static func prefill(g) -> Array:
	var picks: Array = locked(g)
	for p in picks:
		p["from_profile"] = false
	var used: Dictionary = {}
	for p in picks:
		if p.id != "":
			used[p.id] = true
	if picks[0].id == "":
		var demon_ids: Array = CaseMetrics.demon_guesses(g.guesses).filter(func(x): return not used.has(x))
		if not demon_ids.is_empty():
			picks[0] = {"id": demon_ids[0], "type": str(g.guesses[demon_ids[0]].get("guess", "")), "from_profile": true}
			used[demon_ids[0]] = true
	for n in g.w.npcs:
		var guess: String = str(g.guesses.get(n.id, {}).get("guess", "?"))
		if not C.is_minion(guess) or used.has(n.id):
			continue
		for j in range(1, picks.size()):
			if picks[j].id == "":
				picks[j] = {"id": n.id, "type": guess, "from_profile": true}
				used[n.id] = true
				break
	return picks


## What a locked circle claims: its type, or plain "evil" without one.
static func _written(p: Dictionary) -> String:
	var t: String = str(p.get("type", ""))
	return t if t != "" else "evil"


static func _default_type(s: Dictionary) -> String:
	# On single-Demon scripts the Demon's type is given.
	return s.types[0] if s.role == "demon" and s.types.size() == 1 else ""


## Locks the picks in, as today's entry. Two Minion circles can't share a type (each Minion type
## is one identity): a repeated type is kept as plain evil rather than replacing the first.
static func apply(g, picks: Array) -> bool:
	var clean: Array = []
	var seen_types: Dictionary = {}
	for p in picks:
		var q: Dictionary = {"id": str(p.get("id", "")), "type": str(p.get("type", ""))}
		if q.id != "" and q.type != "":
			if seen_types.has(q.type):
				q.type = ""
			else:
				seen_types[q.type] = true
		clean.append(q)
	var costs: bool = changes_demon(g, clean)
	if costs and demon_changes_left(g) <= 0:
		return false   # no changes left: the window disables the Demon picker, so this is a guard
	var store: Dictionary = g.get_meta(META_LOCKED, {}).duplicate(true) if g.has_meta(META_LOCKED) else {}
	if costs:
		store["demon_changes"] = int(store.get("demon_changes", 0)) + 1
	store["picks"] = clean
	var history: Array = store.get("history", [])
	history.append({"day": g.w.day, "picks": clean.duplicate(true)})
	store["history"] = history
	g.set_meta(META_LOCKED, store)
	return true


## Changes of the Demon guess left this case.
static func demon_changes_left(g) -> int:
	var used: int = int(g.get_meta(META_LOCKED, {}).get("demon_changes", 0)) if g.has_meta(META_LOCKED) else 0
	return maxi(0, DEMON_CHANGES - used)


## Whether locking these picks changes a Demon guess already locked (which costs a change). The
## first Demon pick, and confirming the same Demon, cost nothing.
static func changes_demon(g, picks: Array) -> bool:
	var before: String = str(locked(g)[0].get("id", ""))
	return before != "" and str(picks[0].get("id", "")) != before


## The verdict the reveal plays against: person id -> guess ("?" for anyone not locked in).
static func verdict(g) -> Dictionary:
	var out: Dictionary = {}
	for n in g.w.npcs:
		out[n.id] = "?"
	for p in locked(g):
		if p.id != "":
			out[p.id] = _written(p)
	return out


## ---- The view ----

var g
var picks: Array = []
var _slots: Array = []
var _on_done: Callable
var _shade: ColorRect
var _panel: PanelContainer
var _circles: Array = []
var _picker: PopupPanel
var _note: Label
var _change_dialog: ConfirmationDialog

## Opens over the main screen. `on_done(confirmed: bool)` runs after Confirm or Skip; the caller
## closes the meeting then. `dont_ask` runs when the player turns the window off for the case.
static func open(m, on_done: Callable, dont_ask: Callable) -> Control:
	var v = load("res://ui/daily_guess.gd").new()
	v.g = m.g
	v._on_done = on_done
	v.name = "DailyGuess"
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(v)
	v.build(dont_ask)
	return v

func build(dont_ask: Callable) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_slots = slots(g)
	picks = prefill(g)
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.modulate.a = 0.0
	center.add_child(_panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	var title = Label.new()
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_note = Label.new()
	_note.name = "ProfileNote"
	_note.text = PROFILE_NOTE
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", UITheme.color("muted"))
	box.add_child(_note)
	# The triangle: the Demon on top, the Minions in a row beneath.
	var top = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(top)
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 48)
	box.add_child(bottom)
	for i in range(_slots.size()):
		var c: Dictionary = _circle(i)
		(top if i == 0 else bottom).add_child(c.root)
		_circles.append(c)
	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var confirm_button = Button.new()
	confirm_button.name = "Confirm"
	confirm_button.text = CONFIRM
	confirm_button.pressed.connect(confirm)
	buttons.add_child(confirm_button)
	var skip = Button.new()
	skip.name = "Skip"
	skip.text = SKIP
	skip.pressed.connect(func(): _finish(false))
	buttons.add_child(skip)
	var off = Button.new()
	off.name = "DontAsk"
	off.text = DONT_ASK
	off.flat = true
	# A flat button takes the theme's dark paper ink; this one sits on the dark panel (Michael's playtest).
	for k in ["font_color", "font_focus_color"]:
		off.add_theme_color_override(k, UITheme.color("text"))
	for k in ["font_hover_color", "font_pressed_color"]:
		off.add_theme_color_override(k, UITheme.color("accent"))
	off.pressed.connect(func():
		if dont_ask.is_valid():
			dont_ask.call()
		_finish(false))
	buttons.add_child(off)
	for i in range(_circles.size()):
		_refresh_circle(i)
	if is_inside_tree():
		var tw = create_tween()
		tw.tween_property(_shade, "color:a", 0.85, FADE_SECONDS)
		tw.tween_property(_panel, "modulate:a", 1.0, FADE_SECONDS)
	else:
		_shade.color.a = 0.85
		_panel.modulate.a = 1.0

func _circle(i: int) -> Dictionary:
	var root = VBoxContainer.new()
	root.name = "Circle%d" % i
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	var label = Label.new()
	label.text = DEMON_LABEL if _slots[i].role == "demon" else MINION_LABEL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UITheme.color("red"))
	root.add_child(label)
	var face = TextureButton.new()
	face.name = "Face"
	face.ignore_texture_size = true
	face.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # square, not stretched to the column (ovals)
	face.material = PortraitFx.material(true)
	PortraitFx.hover_lift(face)
	face.pressed.connect(func(): _open_picker(i, face))
	# An empty circle has no portrait to draw, so it shows a ring to click (Michael's playtest:
	# a fresh window showed nothing where the circles should be).
	var ring = Panel.new()
	ring.name = "EmptyRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.border_color = UITheme.color("accent")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(PORTRAIT_SIZE / 2)
	sb.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", sb)
	face.add_child(ring)
	root.add_child(face)
	var name_label = Label.new()
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(name_label)
	var types = OptionButton.new()
	types.name = "Type"
	types.add_item(TYPE_PLACEHOLDER)
	types.set_item_metadata(0, "")
	for t in _slots[i].types:
		types.add_item(C.role_name(t))
		types.set_item_metadata(types.item_count - 1, t)
	types.item_selected.connect(func(idx): _pick_type(i, str(types.get_item_metadata(idx))))
	if _default_type(_slots[i]) != "":
		# One Demon type on the script: it's given, so the button shows it and doesn't open.
		types.select(1)
		types.disabled = true
	root.add_child(types)
	return {"root": root, "face": face, "name": name_label, "types": types}

func _refresh_circle(i: int) -> void:
	var c: Dictionary = _circles[i]
	var id: String = str(picks[i].get("id", ""))
	c.face.texture_normal = _round_portrait(id) if id != "" else null
	c.face.get_node("EmptyRing").visible = id == ""
	c.face.tooltip_text = PICK_DEMON if _slots[i].role == "demon" else PICK_MINION
	if i == 0 and _demon_frozen():
		c.face.disabled = true
		c.face.tooltip_text = NO_CHANGES_TIP
	c.name.text = g.w.by_id[id].name if id != "" else EMPTY_CIRCLE
	c.face.modulate = GREYED if picks[i].get("from_profile", false) else Color(1, 1, 1)
	PortraitFx.set_grey(c.face, id != "" and not g.w.by_id[id].alive)
	PortraitFx.set_ring(c.face, id != "" and not picks[i].get("from_profile", false), UITheme.color("red"))
	if _note != null:
		_note.visible = picks.any(func(p): return p.get("from_profile", false))
	var t: String = str(picks[i].get("type", ""))
	if t == "":
		t = _default_type(_slots[i])   # a given Demon type shows even before a pick
	for k in range(c.types.item_count):
		if str(c.types.get_item_metadata(k)) == t:
			c.types.select(k)

func _open_picker(i: int, anchor: Control) -> void:
	if _picker != null:
		_picker.queue_free()
	_picker = PopupPanel.new()
	_picker.name = "Picker"
	add_child(_picker)
	var box = VBoxContainer.new()
	_picker.add_child(box)
	var head = Label.new()
	head.text = PICK_DEMON if _slots[i].role == "demon" else PICK_MINION
	box.add_child(head)
	var grid = GridContainer.new()
	grid.columns = 5
	box.add_child(grid)
	for n in g.w.npcs:
		var b = Button.new()
		b.name = "Pick_" + n.id
		b.icon = _portrait(n.id)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(PICKER_PORTRAIT_SIZE + 24, PICKER_PORTRAIT_SIZE + 28)
		b.text = n.name
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var ok: bool = pickable(g, _slots[i].role, n.id)
		var frozen_demon: bool = i != 0 and n.id == str(picks[0].get("id", "")) and _demon_frozen()
		b.disabled = not ok or frozen_demon
		if not ok:
			b.text = "✕ " + n.name
			b.tooltip_text = DEMON_KILLED_TIP
		elif frozen_demon:
			b.tooltip_text = NO_CHANGES_TIP
		if not n.alive:
			b.material = PortraitFx.material(false)
			PortraitFx.set_grey(b, true)
		if n.id == str(picks[i].get("id", "")):
			PortraitFx.glow(b, UITheme.color("red"))
		PortraitFx.hover_lift(b)
		var id: String = n.id
		b.pressed.connect(func(): _pick(i, id))
		grid.add_child(b)
	var none = Button.new()
	none.name = "PickNone"
	none.text = CLEAR_PICK
	none.pressed.connect(func(): _pick(i, ""))
	box.add_child(none)
	if is_inside_tree():
		_picker.popup(Rect2i(preload("res://ui/column_menus.gd").popup_point(anchor, Vector2(0, anchor.size.y)), Vector2i.ZERO))

func _pick(i: int, id: String) -> void:
	# The Demon can't be moved out of its circle once it's frozen (Codex on #496).
	if _demon_frozen() and ((i == 0 and id != str(picks[0].get("id", ""))) or (i != 0 and id != "" and id == str(picks[0].get("id", "")))):
		return
	# A person sits in one circle at a time.
	for k in range(picks.size()):
		if k != i and id != "" and picks[k].get("id", "") == id:
			picks[k]["id"] = ""
			_refresh_circle(k)
	picks[i]["id"] = id
	picks[i]["from_profile"] = false
	_refresh_circle(i)
	if _picker != null:
		_picker.hide()

## A type sits in one circle at a time, like a person.
func _pick_type(i: int, t: String) -> void:
	for k in range(picks.size()):
		if k != i and t != "" and str(picks[k].get("type", "")) == t:
			picks[k]["type"] = ""
			_refresh_circle(k)
	picks[i]["type"] = t
	picks[i]["from_profile"] = false
	_refresh_circle(i)

## The Demon circle can't change once a Demon is locked and no changes are left.
func _demon_frozen() -> bool:
	return str(locked(g)[0].get("id", "")) != "" and demon_changes_left(g) <= 0

## Confirm: a changed Demon guess asks first (Michael, Nov 21); anything else locks at once.
func confirm() -> void:
	if not changes_demon(g, picks):
		_finish(true)
		return
	var dlg = ConfirmationDialog.new()
	dlg.name = "ChangeDemon"
	dlg.dialog_text = CHANGE_DIALOG % demon_changes_left(g)
	dlg.confirmed.connect(func(): _finish(true))
	add_child(dlg)
	_change_dialog = dlg
	if is_inside_tree():
		dlg.popup_centered()

func _finish(confirmed: bool) -> void:
	# A lock that can't be saved keeps the window open rather than closing unsaved (Codex on #496).
	if confirmed and not apply(g, picks):
		return
	var cb: Callable = _on_done
	queue_free()
	if cb.is_valid():
		cb.call(confirmed)

func _portrait(id: String) -> Texture2D:
	return UITheme.tex("art/portraits/" + id, 0.25)

## The portrait cut to a square from the top, where the face is, so the circle mask draws a
## circle rather than an oval (the art is taller than wide; Michael's playtest). PortraitFx caches it.
func _round_portrait(id: String) -> Texture2D:
	return PortraitFx.square(_portrait(id))
