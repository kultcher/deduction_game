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

## Wording (Michael, Nov 21: approved, except where marked as a draft).
const TITLE = "Your suspicions"
const DEMON_LABEL = "DEMON"            # draft, awaiting Michael
const MINION_LABEL = "MINION"          # draft, awaiting Michael
const EMPTY_CIRCLE = "Choose…"
const PICK_DEMON = "Who is the Demon?"
const PICK_MINION = "Who is a Minion?"
const DEMON_KILLED_TIP = "Killed by the Demon; it cannot be them."
const TYPE_PLACEHOLDER = "What kind?"
const CLEAR_PICK = "No one"            # draft, awaiting Michael
const PROFILE_NOTE = "Greyed: from your notes. Pick someone new, or confirm to lock them in."   # draft
const CONFIRM = "Confirm"
const SKIP = "Skip"
const DONT_ASK = "Don't ask again this case"
const MENU_ENTRY = "Your suspicions"

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
	var store: Dictionary = g.get_meta(META_LOCKED, {}).duplicate(true) if g.has_meta(META_LOCKED) else {}
	store["picks"] = clean
	var history: Array = store.get("history", [])
	history.append({"day": g.w.day, "picks": clean.duplicate(true)})
	store["history"] = history
	g.set_meta(META_LOCKED, store)
	return true


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
	var confirm = Button.new()
	confirm.name = "Confirm"
	confirm.text = CONFIRM
	confirm.pressed.connect(func(): _finish(true))
	buttons.add_child(confirm)
	var skip = Button.new()
	skip.name = "Skip"
	skip.text = SKIP
	skip.pressed.connect(func(): _finish(false))
	buttons.add_child(skip)
	var off = Button.new()
	off.name = "DontAsk"
	off.text = DONT_ASK
	off.flat = true
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
	face.material = _circle_material()
	face.pressed.connect(func(): _open_picker(i, face))
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
	root.add_child(types)
	return {"root": root, "face": face, "name": name_label, "types": types}

func _refresh_circle(i: int) -> void:
	var c: Dictionary = _circles[i]
	var id: String = str(picks[i].get("id", ""))
	c.face.texture_normal = _portrait(id) if id != "" else null
	c.face.tooltip_text = PICK_DEMON if _slots[i].role == "demon" else PICK_MINION
	c.name.text = g.w.by_id[id].name if id != "" else EMPTY_CIRCLE
	c.face.modulate = GREYED if picks[i].get("from_profile", false) else Color(1, 1, 1)
	if _note != null:
		_note.visible = picks.any(func(p): return p.get("from_profile", false))
	var t: String = str(picks[i].get("type", ""))
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
		b.disabled = not ok
		if not ok:
			b.text = "✕ " + n.name
			b.tooltip_text = DEMON_KILLED_TIP
		elif not n.alive:
			b.modulate = Color(1, 1, 1, 0.6)
		var id: String = n.id
		b.pressed.connect(func(): _pick(i, id))
		grid.add_child(b)
	var none = Button.new()
	none.name = "PickNone"
	none.text = CLEAR_PICK
	none.pressed.connect(func(): _pick(i, ""))
	box.add_child(none)
	if is_inside_tree():
		_picker.popup(Rect2i(Vector2i(anchor.get_screen_position() + Vector2(0, anchor.size.y)), Vector2i.ZERO))

func _pick(i: int, id: String) -> void:
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

func _finish(confirmed: bool) -> void:
	if confirmed:
		apply(g, picks)
	var cb: Callable = _on_done
	queue_free()
	if cb.is_valid():
		cb.call(confirmed)

func _portrait(id: String) -> Texture2D:
	return UITheme.tex("art/portraits/" + id, 0.25)

static func _circle_material() -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat d = distance(UV, vec2(0.5));\n\tc.a *= 1.0 - smoothstep(0.48, 0.5, d);\n\tCOLOR = c;\n}\n"
	mat.shader = sh
	return mat
