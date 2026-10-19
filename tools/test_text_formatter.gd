## Step 2: styled spans and isolated native rich-text rendering (no game-panel changes).
## godot --headless --path . --script res://tools/test_text_formatter.gd
extends SceneTree

const Formatter = preload("res://ui/text_formatter.gd")
const Renderer = preload("res://ui/rich_text_renderer.gd")
const Terms = preload("res://ui/text_terms.gd")
const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
var fails = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var formatter = Formatter.new()
	var text = "I saw Fenwick near the Seer, and Lian’s house.\n\tÉlan."
	var spans = formatter.format_text(text, {"speaker_id": "bart"})
	_check(Formatter.plain_text(spans) == text, "formatting preserves wording, Unicode, punctuation and whitespace exactly")
	_check(spans.all(func(s): return text.substr(s["start"], s["end"] - s["start"]) == s["text"]) and spans[0]["start"] == 0 and spans[-1]["end"] == text.length(), "every span retains its original source range")
	_check(spans[0]["color"] == C.npc_color("bart") and spans[-1]["color"] == C.npc_color("bart"), "speech starts and resumes in the speaker's color")
	var fenwick = _entity(spans, "person:fenwick")
	_check(fenwick["color"] == C.npc_color("fenwick") and _entity(spans, "person:lian")["color"] == C.npc_color("lian"), "each mentioned person overrides only their own name")
	var seer = _entity(spans, "role:seer")
	_check(seer["color"] == C.npc_color("bart") and seer["icon_path"].ends_with("/seer.png") and C.ROLES["seer"]["desc"] in seer["tooltip"], "a role inherits speech color and carries its public icon and tooltip")
	var paper = formatter.format_text(text, {"speaker_id": "bart", "surface": "paper"})
	_check(paper[0]["color"] == UITheme.ink_of(C.npc_color("bart")) and _entity(paper, "person:fenwick")["color"] == UITheme.ink_of(C.npc_color("fenwick")), "speaker and entity colors use readable parchment ink variants")
	_check(formatter.format_text("Plain.", {"surface": "paper"})[0]["color"] == UITheme.color("ink") and formatter.format_text("Plain.")[0]["color"] == UITheme.color("text"), "non-speech text gets the appropriate surface default")
	var base = Color(0.2, 0.3, 0.4, 0.6)
	_check(formatter.format_text("Plain.", {"base_color": base, "speaker_id": "missing"})[0]["color"] == base, "an unknown speaker falls back to the supplied base style")
	var faded = formatter.format_text("I saw Fenwick the Seer.", {"speaker_id": "bart", "opacity": 0.42})
	_check(faded.all(func(s): return is_equal_approx(Renderer.text_color(s).a, 0.42)), "hidden opacity applies once to ordinary, name and role text")
	_check(is_equal_approx(Renderer.icon_color(_entity(faded, "role:seer")).a, 0.42), "inline icons receive the same hidden opacity")
	_check(is_equal_approx(Renderer.text_color(formatter.format_text("Plain.", {"base_color": base, "opacity": 0.5})[0]).a, 0.3), "overall opacity multiplies an existing text alpha")
	_check(Renderer.text_color(formatter.format_text("Plain.", {"opacity": -1})[0]).a == 0.0 and Renderer.icon_color(formatter.format_text("Plain.", {"opacity": 2})[0]).a == 1.0, "overall opacity is clamped to valid bounds")
	var reduced = formatter.format_text("Fenwick the Seer", {"icons": false, "tooltips": false, "font_size": 22})
	_check(reduced.all(func(s): return s["icon_path"] == "" and s["tooltip"] == "" and s["font_size"] == 22) and _entity(reduced, "person:fenwick")["color"] == C.npc_color("fenwick"), "icons and hints can be disabled without disabling name colors")
	_check(formatter.format_text("Seer", {"font_size": 22})[0]["icon_size"] == 22 and formatter.format_text("Seer", {"font_size": 22, "icon_size": 18})[0]["icon_size"] == 18, "icons track font size with an explicit size override")
	_check(formatter.format_text("").is_empty(), "empty text produces no spans")
	var opted_out = formatter.format_text("Fenwick the Seer", {"enabled": false, "speaker_id": "bart"})
	_check(opted_out.size() == 1 and opted_out[0]["entity_id"] == "" and opted_out[0]["color"] == C.npc_color("bart"), "opting out preserves surrounding speech styling and literal text")
	_check(_entity(formatter.format_text("medium", {"role_context": true}), "role:medium")["text"] == "medium" and formatter.format_text("medium confidence").size() == 1, "the formatter respects the registry's role-context matching policy")
	var custom = Terms.new(false)
	custom.register_term({"id": "place:test", "kind": "place", "label": "Test Place", "color": Color(0.8, 0.2, 0.4, 0.5),
		"icon_path": "res://assets/ui/roles/not_an_icon.png", "tooltip": "A [literal] description."})
	var custom_formatter = Formatter.new(custom)
	var custom_spans = custom_formatter.format_text("At Test Place.", {"surface": "paper", "opacity": 0.5})
	_check(_entity(custom_spans, "place:test")["entity_id"] == "place:test" and is_equal_approx(Renderer.text_color(custom_spans[1]).a, 0.25), "custom term kinds work and parchment conversion preserves their own alpha")
	var renderer = Renderer.new()
	var label = RichTextLabel.new()
	root.add_child(label)
	label.size = Vector2(600, 300)
	label.bbcode_enabled = true
	var literal = "[color=red]Fenwick[/color] #12 <Seer>\n[img]fake[/img]"
	renderer.append_to(label, formatter.format_text(literal, {"icons": false}))
	_check(label.get_parsed_text() == literal, "the rich-text adapter displays bracketed source text literally, including fake tags")
	renderer.append_to(label, formatter.format_text("\nSecond entry.", {"icons": false}))
	_check(label.get_parsed_text() == literal + "\nSecond entry.", "appending an entry preserves existing log content")
	label.clear()
	renderer.append_to(label, custom_spans)
	_check(label.get_parsed_text() == "At Test Place.", "a missing icon falls back to the complete readable text without added spacing")
	label.clear()
	renderer.append_to(label, formatter.format_text("Fenwick the Seer."))
	# Godot's parsed-text fallback represents an inline image by one ordinary space.
	_check(label.get_parsed_text().replace(" \u00a0", "") == "Fenwick the Seer.", "native inline images supplement the complete role name")
	label.clear()
	label.push_meta("card:12")
	label.push_bold()
	renderer.append_to(label, formatter.format_text("Fenwick the Seer."))
	label.pop()
	label.pop()
	label.add_text(" Outside the card link.")
	_check(label.get_parsed_text().replace(" \u00a0", "") == "Fenwick the Seer. Outside the card link.", "rendering nests inside caller-owned formatting and permits subsequent unlinked text")
	await process_frame
	_check(label.get_content_height() > 0, "native text and role images produce a measurable layout")
	label.free()
	print("TEXT FORMATTER FAILURES: %d" % fails)
	quit(1 if fails else 0)

func _entity(spans: Array, id: String) -> Dictionary:
	for span in spans:
		if span["entity_id"] == id:
			return span
	return {}

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1
