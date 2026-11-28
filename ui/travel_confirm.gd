## "Travel to <block>" (Michael, Nov 28): from a block's close-up, before you've chosen where
## to spend the phase, a button at the bottom of the map asks first, showing what you could
## know of the block: who you can make out at each spot (by name, "(busy)" if they're talking
## with someone), how many more you can't, the Town Hall's reads left, and who lives there.
## A "Don't ask again" tick skips the question from then on, kept in this viewer's settings.
extends RefCounted

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const Tuning = preload("res://sim/tuning.gd")
const GameDayNight = preload("res://game/game_day_night.gd")

const SETTINGS_PATH = "user://settings.cfg"
const SECTION = "travel"
const KEY = "skip_confirm"

## The question and its lines, from what the player could know.
static func summary(g, block: String) -> Dictionary:
	var w = g.w
	var title: String = "Visit %s this %s?" % [C.block_name(block), w.phase_name().to_lower()]
	var lines: Array = []
	for l in w.player_locations_on(block):
		if C.PLAYER_BUILDINGS.has(l):
			# The player's own buildings (the Town Hall): no townsfolk, just what's left to do.
			if l == "town_hall" and w.phase in [C.MORNING, C.AFTERNOON]:
				lines.append("Town Hall: %d/%d Check Records uses remaining" % [w.town_hall_uses_left, Tuning.Setup.TOWN_HALL_USES_PER_CASE])
			continue
		var place: String = _place_name(w, l)
		var named: Array = []
		for n in w.npcs_at(l):
			if n.at_home() or not GameDayNight.can_see_ui(g, n):
				continue
			named.append(n.name + (" (busy)" if str(n.busy_with) != "" else ""))
		var others: int = GameDayNight.unseen_at_ui(g, l)
		var who: Array = named.duplicate()
		if others > 0:
			who.append("+%d other%s" % [others, "" if others == 1 else "s"])
		var line: String = "%s: %s" % [place, ", ".join(PackedStringArray(who)) if not who.is_empty() else "no one you can see"]
		lines.append(line)
	var residents: Array = []
	for n in w.npcs:
		if str(n.home_block) == block:
			residents.append(n.name + ("" if n.alive else " (dead)"))
	if not residents.is_empty():
		lines.append("Living here: " + ", ".join(PackedStringArray(residents)))
	return {"title": title, "lines": lines}

static func _place_name(w, l: String) -> String:
	var name: String = w.loc_name(l).trim_prefix("the ")
	return name.substr(0, 1).to_upper() + name.substr(1) if name != "" else l

static func skip_confirm() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return false
	return bool(cfg.get_value(SECTION, KEY, false))

static func set_skip_confirm(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SECTION, KEY, on)
	cfg.save(SETTINGS_PATH)

## Travel to the block, asking first unless the player said not to. `go` runs the command.
static func request(host: Control, g, block: String, go: Callable) -> void:
	if skip_confirm():
		go.call()
		return
	var info: Dictionary = summary(g, block)
	var popup := PopupPanel.new()
	popup.name = "TravelConfirm"
	popup.theme = host.theme if host.theme != null else null
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size.x = 420
	popup.add_child(box)
	var head := Label.new()
	head.text = info.title
	head.add_theme_color_override("font_color", UITheme.color("accent"))
	head.add_theme_font_size_override("font_size", 19)
	box.add_child(head)
	var sub := Label.new()
	sub.text = "Locations:"
	box.add_child(sub)
	for line in info.lines:
		var l := Label.new()
		l.text = "  • " + str(line)
		box.add_child(l)
	var skip := CheckBox.new()
	skip.text = "Don't ask again"   # the theme draws its box (Limner, #595)
	box.add_child(skip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var stay := Button.new()
	stay.text = "Stay"
	row.add_child(stay)
	var travel := Button.new()
	travel.text = "Travel"
	row.add_child(travel)
	host.add_child(popup)
	stay.pressed.connect(func(): popup.hide())
	travel.pressed.connect(func():
		if skip.button_pressed:
			set_skip_confirm(true)
		popup.hide()
		go.call())
	popup.popup_hide.connect(popup.queue_free, CONNECT_ONE_SHOT)
	popup.popup_centered()
	travel.grab_focus()
