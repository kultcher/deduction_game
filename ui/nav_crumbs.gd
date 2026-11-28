## One way around the screens (Michael, Nov 28, item 5): a row of plaque buttons, always in
## the same corner of the stage, naming where you are and where you can step back to.
##   By day:        Town ▸ <block> ▸ <person you're talking with>
##   At a meeting:  Town ▸ Meeting ▸ <speaker on the stage>
## The crumb you're on is red and does nothing; the others take you there. The block crumb is
## the block in close-up, else yours once you've moved, else the conversation's.
## The Speaker crumb shows while someone is on the courtroom stage (Seneschal's option (a):
## it marks the speech; the speech itself keeps its own pacing).
extends HBoxContainer

const C = preload("res://sim/content.gd")

var _sig: String = ""

func _init() -> void:
	name = "NavCrumbs"
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_PASS

## [{label, current, go: Callable}] for what the main screen `m` is showing now.
static func crumbs(m) -> Array:
	var g = m.g
	if g == null:
		return []
	var out: Array = []
	if g.state in ["meeting", "nomination"]:
		var speaking: bool = m.meeting_view != null and m.meeting_view.presenting()
		var on_map: bool = m.meeting_show_map and m.map_stage.visible and not speaking
		out.append({"label": "Town", "current": on_map, "go": func():
			m.meeting_show_map = true
			m.map.zoom_to("")
			m._refresh_all()})
		out.append({"label": "Meeting", "current": not on_map and not speaking, "go": func():
			if speaking and m.meeting_view.stage != null and m.meeting_view.stage.has_method("clear"):
				m.meeting_view.stage.clear()
			m.meeting_show_map = false
			m._refresh_all()})
		if speaking:
			var who: String = _speaker_name(m)
			out.append({"label": who if who != "" else "Speaker", "current": true, "go": Callable()})
		return out
	if not g.state in ["day", "talk", "approach"]:
		return []
	var talking: bool = g.state == "talk" and g.talk_with != null
	var in_conversation: bool = talking and m.conversation_view.visible
	var zb: String = m.map.zoom_block if m.map != null else ""
	var block: String = zb
	if block == "" and g.moved:
		block = g.w.loc_block(g.loc)
	if block == "" and talking:
		block = g.w.loc_block(g.talk_with.loc)
	out.append({"label": "Town", "current": not in_conversation and zb == "", "go": func(): _show_map(m, talking, "")})
	if block != "" and C.BLOCKS.has(block):
		var b: String = block
		out.append({"label": _block_label(b), "current": not in_conversation and zb == b, "go": func(): _show_map(m, talking, b)})
	if talking:
		out.append({"label": g.talk_with.name, "current": in_conversation, "go": func():
			m.conversation_show_map = false
			m._refresh_all()})
	return out

## Show the map at `block` ("" for the whole town). The full refresh puts the map back on
## your block once you've moved, so zoom after it, then refresh the actions as the map's
## own clicks do.
static func _show_map(m, talking: bool, block: String) -> void:
	if talking:
		m.conversation_show_map = true
		m._refresh_all()
	m.map.zoom_to(block)
	m._on_map_clicked("block" if block != "" else "back", block)

static func _block_label(b: String) -> String:
	var n: String = C.block_name(b).trim_prefix("the ")
	return n.substr(0, 1).to_upper() + n.substr(1)

static func _speaker_name(m) -> String:
	var stage = m.meeting_view.stage if m.meeting_view != null else null
	if stage == null:
		return ""
	var cur: Dictionary = stage.get("current") if stage.get("current") is Dictionary else {}
	return str(cur.get("name", ""))

## Rebuild only when what's shown changes.
func refresh(m) -> void:
	var list: Array = crumbs(m)
	var sig: String = "|".join(PackedStringArray(list.map(func(c): return "%s:%s" % [c.label, c.current])))
	visible = list.size() > 1 or (list.size() == 1 and not list[0].current)
	if sig == _sig:
		return
	_sig = sig
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	for i in range(list.size()):
		var c: Dictionary = list[i]
		if i > 0:
			var sep := Label.new()
			sep.text = "▸"
			add_child(sep)
		var b := Button.new()
		b.text = c.label
		b.toggle_mode = true
		b.set_pressed_no_signal(c.current)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.tooltip_text = "You are here" if c.current else "Go to %s" % c.label
		var go: Callable = c.go
		b.pressed.connect(func():
			b.set_pressed_no_signal(c.current)
			if not c.current and go.is_valid():
				go.call())
		add_child(b)
