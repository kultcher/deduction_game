## The grim reveal overlay and the final screen (stage 1; docs/design/grim_reveal.md).
## A full-screen sheet over the town: a lead line, Limner's RevealCard for one person at a
## time (about 90% x 74% of the screen), their key moments beneath, a row of the town's
## portraits, and Next / Skip. After the last person, or on Skip, the final screen: every
## truth at once, the sealed verdict against it (right or wrong only; scoring comes later),
## the detail views as tabs, and Watch again. Presentation only.
extends Control

const RevealPlan = preload("res://ui/reveal/reveal_plan.gd")
const RevealCard = preload("res://ui/reveal/reveal_card.gd")
const GameScreens = preload("res://game/game_screens.gd")
const UITheme = preload("res://ui/theme.gd")
const C = preload("res://sim/content.gd")

## Wording: drafts awaiting Michael (Herald, Nov 21).
const NEXT = "Next"
const SKIP = "Skip to the end"
const FINAL_TITLE = "The grimoire"
const WATCH_AGAIN = "Watch again"
const CLOSE = "Close"
const TAB_TRUTH = "The town"
const TAB_GRIMOIRE = "Grimoire (full)"
const TAB_LIES = "Every lie"
const TAB_TALK = "Who told whom what"
const HEAD_PERSON = "Person"
const HEAD_TRUTH = "Truly"
const HEAD_GUESS = "Your verdict"
const HEAD_MOMENT = "Key moment"
const RIGHT = "✓"
const WRONG = "✗"
const NO_GUESS = "—"
const SUMMARY = "Your verdict: %d of %d evil named rightly."

const CARD_W = 0.90
const CARD_H = 0.74
const TILE = 56

var g
var plan: Dictionary = {}
var index: int = -1
var reduced_motion: bool = false
var card
var _lead: Label
var _moments: Label
var _row: HBoxContainer
var _next: Button
var _skip: Button
var _stage: Control
var _final: Control
var _tiles: Dictionary = {}
var _on_close: Callable


## Opens over `parent` and starts the reveal. `verdict` maps person ids to the sealed guesses.
static func open(parent: Control, game, verdict: Dictionary, on_close: Callable = Callable(), reduced: bool = false) -> Control:
	var v = load("res://ui/reveal/reveal_overlay.gd").new()
	v.name = "GrimReveal"
	v.g = game
	v.reduced_motion = reduced
	v._on_close = on_close
	v.plan = RevealPlan.build(game, verdict)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(v)
	v._build()
	v.start()
	return v

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade = ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.04, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	_lead = Label.new()
	_lead.name = "Lead"
	_lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lead.add_theme_font_size_override("font_size", 26)
	_lead.anchor_left = 0.05
	_lead.anchor_right = 0.95
	_lead.anchor_top = 0.015
	_lead.anchor_bottom = 0.09
	_lead.text = plan.lead.text
	_stage.add_child(_lead)
	card = RevealCard.new()
	card.name = "Card"
	card.anchor_left = (1.0 - CARD_W) / 2.0
	card.anchor_right = 1.0 - (1.0 - CARD_W) / 2.0
	card.anchor_top = 0.09
	card.anchor_bottom = 0.09 + CARD_H
	card.reduced_motion = reduced_motion
	card.finished.connect(_on_card_finished)
	_stage.add_child(card)
	_moments = Label.new()
	_moments.name = "Moments"
	_moments.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moments.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_moments.add_theme_font_size_override("font_size", 20)
	_moments.anchor_left = 0.1
	_moments.anchor_right = 0.9
	_moments.anchor_top = 0.09 + CARD_H
	_moments.anchor_bottom = 0.9
	_stage.add_child(_moments)
	var bar = HBoxContainer.new()
	bar.anchor_left = 0.03
	bar.anchor_right = 0.97
	bar.anchor_top = 0.9
	bar.anchor_bottom = 0.985
	_stage.add_child(bar)
	_row = HBoxContainer.new()
	_row.name = "TownRow"
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_theme_constant_override("separation", 6)
	bar.add_child(_row)
	for s in plan.steps:
		var t = TextureRect.new()
		t.name = "Tile_" + s.npc
		t.texture = _portrait(s.npc)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(TILE, TILE)
		t.tooltip_text = s.name
		t.modulate = Color(0.45, 0.45, 0.45) if s.dead else Color(0.75, 0.75, 0.75)
		_row.add_child(t)
		_tiles[s.npc] = t
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.text = SKIP
	_skip.flat = true
	_skip.pressed.connect(show_final)
	bar.add_child(_skip)
	_next = Button.new()
	_next.name = "Next"
	_next.text = NEXT
	_next.pressed.connect(next)
	bar.add_child(_next)

func start() -> void:
	index = -1
	if _final != null:
		_final.queue_free()
		_final = null
	_stage.visible = true
	_lead.text = plan.lead.text
	next()

## Next: while a card is still playing, land it at once; otherwise go to the next person.
func next() -> void:
	if index >= 0 and card.playing:
		card.skip_to_end()
		return
	index += 1
	if index >= plan.steps.size():
		show_final()
		return
	var s: Dictionary = plan.steps[index].duplicate()
	s["portrait"] = _portrait(s.npc)
	_moments.text = "\n".join(PackedStringArray(s.get("moments", [])))
	_moments.modulate.a = 0.0
	for id in _tiles:
		var tile: TextureRect = _tiles[id]
		tile.scale = Vector2.ONE
	if _tiles.has(s.npc):
		_tiles[s.npc].modulate = Color(1, 1, 1)
	card.play(s)

func _on_card_finished() -> void:
	_moments.modulate.a = 1.0

## The final screen: every truth at once, the verdict against it, the detail views.
func show_final() -> void:
	if card.playing:
		card.skip_to_end()
	_stage.visible = false
	if _final != null:
		_final.queue_free()
	_final = _final_screen()
	add_child(_final)

func _final_screen() -> Control:
	var root = MarginContainer.new()
	root.name = "Final"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 32)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)
	var title = Label.new()
	title.text = FINAL_TITLE
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var summary = Label.new()
	summary.name = "Summary"
	summary.text = SUMMARY % verdict_score()
	box.add_child(summary)
	var tabs = TabContainer.new()
	tabs.name = "Tabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	var truth = ScrollContainer.new()
	truth.name = TAB_TRUTH
	tabs.add_child(truth)
	var grid = GridContainer.new()
	grid.name = "TruthGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	truth.add_child(grid)
	for h in ["", HEAD_PERSON, HEAD_TRUTH, HEAD_GUESS, HEAD_MOMENT]:
		var l = Label.new()
		l.text = h
		l.add_theme_color_override("font_color", UITheme.color("muted"))
		grid.add_child(l)
	var by_cast: Array = plan.steps.duplicate()
	var cast_order: Array = g.w.npcs.map(func(n): return n.id)
	by_cast.sort_custom(func(a, b): return cast_order.find(a.npc) < cast_order.find(b.npc))
	for s in by_cast:
		var face = TextureRect.new()
		face.texture = _portrait(s.npc)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(40, 40)
		if s.dead:
			face.modulate = Color(0.55, 0.55, 0.55)
		grid.add_child(face)
		var nm = Label.new()
		nm.text = s.name
		grid.add_child(nm)
		var tr = Label.new()
		tr.text = "%s, %s%s" % [s.role_text, s.align_text, (" · " + s.burden) if s.burden != "" else ""]
		tr.add_theme_color_override("font_color", UITheme.color("red") if s.evil else UITheme.color("ink"))
		grid.add_child(tr)
		var gs = Label.new()
		var gtext: String = str(s.get("guess", ""))
		gs.text = NO_GUESS if gtext == "" else "%s %s" % [RIGHT if s.get("guess_correct", false) else WRONG, gtext.trim_prefix(RevealPlan.GUESS_LINE.split("%s")[0])]
		grid.add_child(gs)
		var mo = Label.new()
		var ms: Array = s.get("moments", [])
		mo.text = ms[0] if not ms.is_empty() else ""
		mo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mo.custom_minimum_size = Vector2(360, 0)
		grid.add_child(mo)
	for pair in [[TAB_GRIMOIRE, GameScreens._grimoire(g)], [TAB_LIES, GameScreens._lies(g)], [TAB_TALK, GameScreens._exchanges(g)]]:
		var tx = TextEdit.new()
		tx.name = pair[0]
		tx.text = pair[1]
		tx.editable = false
		tabs.add_child(tx)
	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	var again = Button.new()
	again.name = "WatchAgain"
	again.text = WATCH_AGAIN
	again.pressed.connect(start)
	buttons.add_child(again)
	var close = Button.new()
	close.name = "Close"
	close.text = CLOSE
	close.pressed.connect(func():
		var cb: Callable = _on_close
		queue_free()
		if cb.is_valid():
			cb.call())
	buttons.add_child(close)
	return root

## How many of the evil were named rightly, out of how many evil there were. Right or wrong
## only: points wait for scoring (Michael, Q2).
func verdict_score() -> Array:
	var right: int = 0
	var evil: int = 0
	for s in plan.steps:
		if s.evil:
			evil += 1
			if s.get("guess", "") != "" and s.get("guess_correct", false):
				right += 1
	return [right, evil]

func _unhandled_input(ev: InputEvent) -> void:
	if _stage.visible and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		next()
		accept_event()

func _portrait(id: String) -> Texture2D:
	return UITheme.tex("art/portraits/" + id, 0.5)
