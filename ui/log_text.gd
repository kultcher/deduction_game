## Presentation of the game's plain console output, enriched before any UI markup.
## Keeps speech portraits, headers, emphasis and card actions in the native text stack.
extends RefCounted

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const Formatter = preload("res://ui/text_formatter.gd")
const Renderer = preload("res://ui/rich_text_renderer.gd")

var formatter = Formatter.new()
var renderer = Renderer.new()
var _speech = RegEx.new()
var _cards = RegEx.new()
var _numbers = RegEx.new()
var _lead = RegEx.new()

func _init() -> void:
	var names = PackedStringArray(C.CAST.map(func(n): return n["name"]))
	_speech.compile("^(\\s*)(" + "|".join(names) + "): (\".*)$")
	_cards.compile("\\s*\\[case board: (#[0-9]+(?:, #[0-9]+)*)\\]$")
	_numbers.compile("#([0-9]+)")
	_lead.compile("^(\\s*)(Present:|Nearby[^:]{0,40}:|Actions:|Around town [a-z ]+:|You (?:spend|keep|search|draw|overhear|step|leave|promise|chalk|sleep|stand|take|lay|excuse|break|go over|think|find)\\b|Dawn breaks|During your vigil|Near the body|Votes to execute [^:]*:|The meeting closes)")

func append_to(label: RichTextLabel, text: String) -> void:
	for line in text.split("\n"):
		_append_line(label, line)
		label.add_text("\n")

func _append_line(label: RichTextLabel, line: String) -> void:
	if line.begins_with("> "):
		label.add_text("\n")
		_append(label, line, {"enabled": false, "base_color": Color("8a8f99")})
		return
	var cards = _cards.search(line)
	var body = line.substr(0, cards.get_start()) if cards != null else line
	var speech = _speech.search(body)
	if speech != null:
		var speaker = ""
		for person in C.CAST:
			if person["name"] == speech.get_string(2):
				speaker = person["id"]
		label.add_text(speech.get_string(1))
		_icon(label, "art/portraits/" + speaker, 24)
		_append(label, speech.get_string(2) + ": " + speech.get_string(3), {"speaker_id": speaker})
	elif body.begins_with("=== "):
		_icon(label, "ui/moon" if "Night" in body else "ui/wax_seal" if "meeting" in body else "ui/sun", 20)
		_append(label, body.trim_prefix("=== ").trim_suffix(" ==="), {"base_color": UITheme.color("accent"), "bold": true})
	else:
		if "was killed" in body:
			_icon(label, "ui/raven", 20)
		var lead = _lead.search(body)
		if lead != null:
			_append(label, body.substr(0, lead.get_start(2)))
			_append(label, lead.get_string(2), {"bold": true})
			_append(label, body.substr(lead.get_end(2)))
		else:
			_append(label, body)
	if cards != null:
		label.add_text("  ")
		_icon(label, "ui/cards/card_04", 14)
		var hits = _numbers.search_all(cards.get_string(1))
		for i in range(hits.size()):
			if i > 0:
				label.add_text(", ")
			label.push_meta("card:" + hits[i].get_string(1))
			_append(label, hits[i].get_string(), {"enabled": false, "base_color": Color("8a8f99")})
			label.pop()

func _append(label: RichTextLabel, text: String, context: Dictionary = {}) -> void:
	var style = {"icon_size": 20}
	style.merge(context, true)
	renderer.append_to(label, formatter.format_text(text, style))

func _icon(label: RichTextLabel, path: String, height: int) -> void:
	var texture = UITheme.tex(path)
	if texture != null:
		label.add_image(texture, 0, height)
		label.add_text(" ")
