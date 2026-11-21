## The daily evil-team guess (Michael, Nov 21; docs/design/grim_reveal.md).
## Each day, once the meeting is settled and before the hanging is announced, the screen fades
## and the player marks who they believe is evil: a Demon circle on top, a Minion circle for
## each Minion in play below it, each with its type. It's bookkeeping only: it writes the
## player's private theory (the profile guesses), which the meeting's close then freezes
## (GameScreens.capture_prediction "before_execution"). No mechanical effect.
## The logic (slots, prefill, apply) is static so tests can drive it without a display.
extends Control

const C = preload("res://sim/content.gd")
const CaseMetrics = preload("res://game/case_metrics.gd")
const UITheme = preload("res://ui/theme.gd")

## Wording: drafts awaiting Michael (Herald, Nov 21).
const FADE_LINE = "Before the verdict is read, mark who you believe serves the dark."
const TITLE = "Your suspicions"
const DEMON_LABEL = "DEMON"
const MINION_LABEL = "MINION"
const EMPTY_CIRCLE = "Choose…"
const PICK_DEMON = "Who is the Demon?"
const PICK_MINION = "Who is a Minion?"
const DEMON_KILLED_TIP = "Killed by the Demon; it cannot be them."
const TYPE_PLACEHOLDER = "What kind?"
const CLEAR_PICK = "No one"
const CONFIRM = "Confirm"
const SKIP = "Skip"
const DONT_ASK = "Don't ask again this case"
const MENU_ENTRY = "Your suspicions"
const SEAL_TITLE = "Seal your verdict"
const SEAL_BUTTON = "Seal my verdict"
const META_VERDICT = "sealed_verdict"   # on the game: the verdict sealed after an overnight ending

const META_LAST = "daily_guess_picks"   # on the game: the circles last confirmed
const PORTRAIT_SIZE = 112
const PICKER_PORTRAIT_SIZE = 64
const FADE_SECONDS = 0.35
const DEFAULT_CONFIDENCE = 3


## The circles this case shows: the Demon first, then one per Minion in play. Each has a role
## ("demon" or "minion") and the types the script allows for it.
static func slots(g) -> Array:
	var sc = g.w.case_script
	var demons: Array = sc.demons.duplicate() if sc != null else C.EVIL_ROLES.filter(func(r): return C.is_demon(r))
	var minions: Array = sc.minions.duplicate() if sc != null else C.EVIL_ROLES.filter(func(r): return C.is_minion(r))
	var out: Array = [{"role": "demon", "types": demons}]
	for i in range(g.w.minion_ids.size()):
		out.append({"role": "minion", "types": minions})
	return out


## Whether this person can be picked for a circle. The Demon picker crosses out those the Demon
## killed; Minion pickers leave them open (the Demon may one day kill its own).
static func pickable(g, role: String, id: String) -> bool:
	var n = g.w.by_id.get(id)
	if n == null:
		return false
	return not (role == "demon" and not n.alive and n.death_cause == "demon")


## The circles filled from the player's current private theory. Circles the window filled last
## time keep their people while those guesses still stand (an untyped Demon is stored as plain
## "evil", so only the window knows it was the Demon circle). The rest: the Demon guess, then
## Minion types, then plain "evil" guesses, in the order the cast is listed.
static func prefill(g) -> Array:
	var ss: Array = slots(g)
	var picks: Array = []
	for s in ss:
		picks.append({"id": "", "type": _default_type(s)})
	var used: Dictionary = {}
	var last: Array = g.get_meta(META_LAST, []) if g.has_meta(META_LAST) else []
	for i in range(mini(last.size(), picks.size())):
		var id: String = str(last[i].get("id", ""))
		if id == "" or not g.guesses.has(id):
			continue
		if str(g.guesses[id].get("guess", "")) == _written(last[i]):
			picks[i] = {"id": id, "type": str(last[i].get("type", ""))}
			used[id] = true
	if picks[0].id == "":
		var demon_ids: Array = CaseMetrics.demon_guesses(g.guesses).filter(func(x): return not used.has(x))
		if not demon_ids.is_empty():
			picks[0] = {"id": demon_ids[0], "type": str(g.guesses[demon_ids[0]].get("guess", ""))}
			used[demon_ids[0]] = true
	var minion_like: Array = []
	for n in g.w.npcs:
		var guess: String = str(g.guesses.get(n.id, {}).get("guess", "?"))
		if C.is_minion(guess):
			minion_like.append([0, n.id, guess])
		elif guess == "evil":
			minion_like.append([1, n.id, ""])
	minion_like.sort_custom(func(a, b): return a[0] < b[0])
	for entry in minion_like:
		if used.has(entry[1]):
			continue
		var k: int = -1
		for j in range(1, picks.size()):
			if picks[j].id == "":
				k = j
				break
		if k < 0:
			break
		picks[k] = {"id": entry[1], "type": entry[2]}
		used[entry[1]] = true
	return picks


## What a circle writes to the private theory: its type, or plain "evil" without one.
static func _written(p: Dictionary) -> String:
	var t: String = str(p.get("type", ""))
	return t if t != "" else "evil"


static func _default_type(s: Dictionary) -> String:
	# On single-Demon scripts the Demon's type is given.
	return s.types[0] if s.role == "demon" and s.types.size() == 1 else ""


## Writes the picks into the private theory. A circle with a type guesses that type; one
## without guesses plain "evil". Two Minion circles can't share a type (each Minion type is one
## identity): a repeated type is written as plain "evil" rather than silently replacing the
## first. Anyone who held an evil guess before and isn't picked now is set back to "?", so the
## window and the profile panel stay one source of truth.
static func apply(g, picks: Array) -> bool:
	var clean: Array = []
	var seen_types: Dictionary = {}
	for p in picks:
		var q: Dictionary = {"id": str(p.get("id", "")), "type": str(p.get("type", ""))}
		if q.id != "" and q.type != "":
			if seen_types.has(q.type):
				q.type = ""
			seen_types[q.type] = true
		clean.append(q)
	var picked: Dictionary = {}
	for p in clean:
		if p.id != "":
			picked[p.id] = true
	var ok: bool = true
	for id in g.guesses.keys():
		var guess: String = str(g.guesses[id].get("guess", "?"))
		if not picked.has(id) and (guess == "evil" or C.is_demon(guess) or C.is_minion(guess)):
			ok = g.set_guess(id, "?", 1) and ok
	for p in clean:
		if p.id == "":
			continue
		var conf: int = int(g.guesses.get(p.id, {}).get("confidence", DEFAULT_CONFIDENCE))
		if str(g.guesses.get(p.id, {}).get("guess", "?")) in ["?", "good"]:
			conf = DEFAULT_CONFIDENCE
		ok = g.set_guess(p.id, _written(p), conf) and ok
	g.set_meta(META_LAST, clean)
	return ok


## The verdict the picks make, without touching the private theory (it froze at the outcome):
## every current guess, with the window's picks written over it as apply() would.
static func verdict_of(g, picks: Array) -> Dictionary:
	var out: Dictionary = {}
	for id in g.guesses:
		out[id] = str(g.guesses[id].get("guess", "?"))
	for id in out.keys():
		if out[id] == "evil" or C.is_demon(out[id]) or C.is_minion(out[id]):
			out[id] = "?"
	var seen_types: Dictionary = {}
	for p in picks:
		var id: String = str(p.get("id", ""))
		if id == "":
			continue
		var t: String = str(p.get("type", ""))
		if t != "" and seen_types.has(t):
			t = ""
		seen_types[t] = true
		out[id] = _written({"type": t})
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
var seal: bool = false      # the end-of-game seal: writes the verdict, not the theory

## Opens over the main screen. `on_done(confirmed: bool)` runs after Confirm or Skip; the caller
## closes the meeting then. `dont_ask` runs when the player turns the window off for the case.
static func open(m, on_done: Callable, dont_ask: Callable, sealing: bool = false) -> Control:
	var v = load("res://ui/daily_guess.gd").new()
	v.g = m.g
	v.seal = sealing
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
	var fade_line = Label.new()
	fade_line.name = "FadeLine"
	fade_line.text = FADE_LINE
	fade_line.visible = not seal
	fade_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_line.add_theme_color_override("font_color", UITheme.color("muted"))
	box.add_child(fade_line)
	var title = Label.new()
	title.text = SEAL_TITLE if seal else TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
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
	confirm.text = SEAL_BUTTON if seal else CONFIRM
	confirm.pressed.connect(func(): _finish(true))
	buttons.add_child(confirm)
	var skip = Button.new()
	skip.name = "Skip"
	skip.text = SKIP
	skip.pressed.connect(func(): _finish(false))
	skip.visible = not seal
	buttons.add_child(skip)
	var off = Button.new()
	off.name = "DontAsk"
	off.text = DONT_ASK
	off.flat = true
	off.pressed.connect(func():
		if dont_ask.is_valid():
			dont_ask.call()
		_finish(false))
	off.visible = not seal
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

func _finish(confirmed: bool) -> void:
	if confirmed and seal:
		g.set_meta(META_VERDICT, verdict_of(g, picks))
	elif confirmed:
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
