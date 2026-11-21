## The script sheet (ui/main.gd's Roles window): the town's gifts, the secrets, the minions and
## the demons, each with its icon, what it does and who has claimed it. It opens as a window,
## or pinned beside the profile. `m` is the main control.
extends RefCounted

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const ScriptDef = preload("res://sim/script_def.gd")

## Team colours on the script sheet: blue gifts, violet secrets, red for the demon's side.
const ROLE_TEAM_COLOR = {"good": "role_good_ink", "secret": "role_secret_ink", "evil": "role_evil_ink"}

## Recolours a role icon's dark ink to its team colour, keeping the gold and paper fills.
static var _icon_shader: Shader = null

## The roles list (the script, as in Clocktower): the town's gifts on the left; the demon's
## side and the secrets on the right. Each with its icon, what it does, and who has claimed it.
static func setup_summary(count: int) -> String:
	# Setup rules count burdens (code: secrets), not holders.
	var rules: Dictionary = C.SETUPS.get(count, {"town": count - 2, "minions": 1, "secrets": 1})
	return "Good: %d gifted townsfolk / %d burden%s · Evil: %d minion%s / 1 demon" % [rules.town, rules.secrets, "" if rules.secrets == 1 else "s", rules.minions, "" if rules.minions == 1 else "s"]

static func set_pinned(m, on: bool) -> void:
	m.roles_pinned = on
	m.roles_pin.set_pressed_no_signal(on)
	open(m)

static func hide(m) -> void:
	m.roles_showing = false
	m.roles_win.hide()
	if m.roles_pinned and m.roles_content.get_parent() != m.roles_dock:
		m.roles_content.reparent(m.roles_dock)
		build(m, true)
	m.roles_dock.hide()

static func open(m) -> void:
	m.roles_showing = true
	var embedded: bool = m.roles_pinned and not m.case_view.visible
	var host = m.roles_dock if embedded else m.roles_window_box
	if m.roles_content.get_parent() != host: m.roles_content.reparent(host)
	build(m, embedded)
	m.roles_dock.visible = embedded
	if embedded:
		m.roles_win.hide()
	elif not m.roles_win.visible:
		m.roles_win.popup_centered()

static func state_key(m) -> String:
	return JSON.stringify([m.g.w.n_npcs, m.g.w.minion_ids.size(), m.g.w.npcs.map(func(n): return [n.id, n.claimed_role, n.max_tier >= 3, n.claim_public]),
		m.g.w.burden_claims, m.g.w.burden_told.keys()])

static func build(m, embedded: bool) -> void:
	m._roles_signature = state_key(m)
	for ch in m.roles_box.get_children():
		m.roles_box.remove_child(ch)
		ch.queue_free()
	# Four stacked sections, as on a Clocktower script sheet: gifts, secrets, minions, demons.
	# Each lays its roles out in two columns in the window, one when pinned beside the profile.
	var sections = VBoxContainer.new()
	sections.name = "ScriptSections"
	sections.add_theme_constant_override("separation", 14)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.roles_box.add_child(sections)
	var sc = m.g.w.case_script
	var minions: int = m.g.w.minion_ids.size()
	group(m, sections, "Gifts of the town", sc.town, "good", embedded)
	group(m, sections, burden_heading(sc.secrets_in_play), sc.secrets, "secret", embedded)
	group(m, sections, "Minions: %d in play" % minions, sc.minions, "evil", embedded)
	var demon_box = group(m, sections, "Demon" if sc.demons.size() == 1 else "Demons: one in play", sc.demons, "evil", embedded)
	var night_rule = Label.new()
	night_rule.name = "DemonNightRule"
	night_rule.text = C.DEMON_NIGHT_RULE
	night_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	night_rule.add_theme_color_override("font_color", UITheme.color("ink"))
	demon_box.add_child(night_rule)
	var summary = Label.new()
	summary.name = "SetupSummary"
	summary.text = setup_summary(m.g.w.n_npcs)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", UITheme.color("ink"))
	m.roles_box.add_child(summary)
	var bottom_pad = Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 12)
	m.roles_box.add_child(bottom_pad)

## The burdens section's heading (Michael, Nov 21: "secret" becomes "burden" on the sheet).
static func burden_heading(in_play: int) -> String:
	return "Burdens: %s in play, on top of a gift" % ("one" if in_play == 1 else str(in_play))

## Who the player knows has claimed burden `kind`: before the town, or to the player alone
## (as gifts are shown, so a double claim stands out; Michael, Q21).
static func burden_claimers(w, kind: String) -> Array:
	var out: Array = []
	var public: Array = w.burden_claims.get(kind + ":public", [])
	for id in w.burden_claims.get(kind, []):
		if id in public:
			out.append("%s (to the town)" % w.by_id[id].name)
		elif w.burden_told.has("%s|player" % id):
			out.append("%s (told you)" % w.by_id[id].name)
	return out

static func team_icon_material(team_color: Color) -> ShaderMaterial:
	if _icon_shader == null:
		_icon_shader = Shader.new()
		_icon_shader.code = """shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float ink = 1.0 - smoothstep(0.18, 0.42, lum);
	COLOR = vec4(mix(c.rgb, tint.rgb, ink), c.a);
}"""
	var mat = ShaderMaterial.new()
	mat.shader = _icon_shader
	mat.set_shader_parameter("tint", team_color)
	return mat

## One section: its heading, then its roles in a grid. Returns the section box.
static func group(m, parent: Container, title: String, roles: Array, team: String, embedded: bool) -> VBoxContainer:
	var team_color: Color = UITheme.color(ROLE_TEAM_COLOR[team])
	var box = VBoxContainer.new()
	box.name = "Section_" + team
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	var h = Label.new()
	h.text = title
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_theme_font_size_override("font_size", 18)
	h.add_theme_color_override("font_color", team_color)
	box.add_child(h)
	var rule = ColorRect.new()
	rule.color = Color(team_color, 0.45)
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)
	var grid = GridContainer.new()
	grid.columns = 1 if embedded else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var icon_material := team_icon_material(team_color)
	for r in roles:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(row)
		var ic = TextureRect.new()
		var rt = UITheme.tex("ui/roles/" + r, 0.1)
		ic.texture = rt if rt != null else UITheme.tex("ui/roles/unknown", 0.1)  # icons for new gifts still to come
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(34, 34)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ic.material = icon_material
		row.add_child(ic)
		var col = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var nm = Label.new()
		nm.text = C.role_name(r) if C.ROLES.has(r) else C.secret_name(r)
		nm.add_theme_font_size_override("font_size", 16)
		nm.add_theme_color_override("font_color", team_color)
		col.add_child(nm)
		var d = Label.new()
		d.name = "Desc_" + r
		# A hidden burden's rules text leads with its tag (Michael, Nov 21: "Hidden: ...").
		d.text = C.ROLES[r]["desc"] if C.ROLES.has(r) else (("Hidden: " if r in ScriptDef.HIDDEN_SECRETS else "") + C.SECRET_MODS[r]["desc"])
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 14)
		d.add_theme_color_override("font_color", UITheme.color("ink_soft"))
		col.add_child(d)
		var who: Array = []
		if team == "secret":
			who = burden_claimers(m.g.w, r)
		else:
			for n in m.g.w.npcs:
				if n.claimed_role == r and (n.claim_public or n.max_tier >= 3):
					who.append("%s (%s)" % [n.name, "to the town" if n.claim_public else "told you"])
		if not who.is_empty():
			var c2 = Label.new()
			c2.name = "Claims_" + r
			c2.text = "Claimed by: " + ", ".join(PackedStringArray(who))
			c2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c2.add_theme_font_size_override("font_size", 13)
			c2.add_theme_color_override("font_color", UITheme.color("red").darkened(0.2))
			col.add_child(c2)
	return box
