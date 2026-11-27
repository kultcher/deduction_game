## One NPC's reveal at the end of the game (Limner, Nov 21; the grim reveal, stage 1).
## The script's roles are dealt from a face-down deck: each card slides off the top, flips
## face up, arcs out to one side (alternating right and left) and slides back in under the
## deck. The last card, the true role, flips in place and pushes out towards the player.
## Then the alignment seal stamps down and the burden tag, if any, drops in on a thread.
## A fakeout flips a false role first: it starts to push out, then tears in half and the
## halves fall away, showing the true card already face up beneath it.
## About 3 s a person, about 3.8 s with a fakeout. Reduced motion skips the deal: the card
## fades in, and a fakeout shows the false role struck through before the true one.
##
## Herald's overlay places this Control (it fills its rect, laid out for 16:9) and calls
## play(step). Everything here is a pure function of one clock, `t`, so skip_to_end() and
## the tests can jump to any moment. Presentation only: no game state, no simulation RNG.
extends Control

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const MainRoles = preload("res://ui/main_roles.gd")

signal landed      ## the true card has settled: its name and alignment are showing
signal finished    ## the seal and burden tag are done
signal card_dealt  ## each dealt card as it leaves the deck (a hook for a sound)

const REF = Vector2(1730, 800)       ## the reference footprint; everything scales with it
const CARD = Vector2(270, 380)       ## card size at the reference footprint
const PUSH = 1.35                    ## how much the final card grows as it comes forward
const DEAL = 8                       ## cards dealt before the final one
## The gap between the burden tag and the card's edge, at the reference size.
const TAG_GAP = 22.0
const MAX_STACK = 6                  ## face-down cards drawn in the deck at most

var reduced_motion := false
var t := 0.0
var playing := false
var step: Dictionary = {}

var _k := 1.0
var _deck_c := Vector2.ZERO          ## the deck's centre, in this Control's space
var _plan: Dictionary = {}           ## the timeline for the current step
var _emitted_landed := false
var _emitted_finished := false
var _dealt_emitted := 0
var _deal_roles: Array = []
var _seed := 0

# Nodes, built once.
var portrait: TextureRect
var name_label: Label
var guess_label: Label
var mark: Control
var role_label: Label
var align_label: Label
var strike: ColorRect
var table: Control
var stack: Array = []                ## face-down cards in the deck
var dealt: Array = []                ## the dealt cards, one per deal slot
var final_card                       ## the true role
var fake_card                        ## the false role, for a fakeout
var halves: Array = []               ## the torn halves of the fake card: [{clip, shadow}]
var seal: Control
var tag: Control
var tag_label: Label
var _built := false

func _ready() -> void:
	_build()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_layout()
		_apply()

# --- Public ------------------------------------------------------------------------------

## step: {"portrait": Texture2D, "name": String, "roles": Array (script order), "role": String,
##   "evil": bool, "burden": String or "" (the tag's full text), "fakeout_role": String or "",
##   "guess": String or "",
##   optional "guess_correct": bool, "dead": bool, "role_text": String, "align_text": String}
func play(s: Dictionary) -> void:
	_build()
	step = s
	t = 0.0
	playing = true
	_emitted_landed = false
	_emitted_finished = false
	_dealt_emitted = 0
	_seed = hash(str(s.get("name", "")) + str(s.get("role", "")))
	_choose_deal()
	_dress()
	_plan = _make_plan()
	_layout()
	_apply()

## A click mid-play: jump to the end, emitting whatever hasn't been emitted.
func skip_to_end() -> void:
	if step.is_empty():
		return
	t = _plan.end
	_apply()
	_emit_due()
	playing = false

## Advance the clock (the overlay's _process does this; tests and the capture tool call it).
func advance(delta: float) -> void:
	if not playing:
		return
	t = minf(t + delta, _plan.end)
	_apply()
	_emit_due()
	if t >= _plan.end:
		playing = false

func landed_at() -> float:
	return _plan.get("landed", 0.0)

func ends_at() -> float:
	return _plan.get("end", 0.0)

func _process(delta: float) -> void:
	if playing:
		advance(delta)

# --- Building ----------------------------------------------------------------------------

func _build() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm = ShaderMaterial.new()
	pm.shader = _portrait_shader()
	portrait.material = pm
	add_child(portrait)
	name_label = _label(UITheme.color("ink"))
	guess_label = _label(UITheme.color("ink_soft"))
	mark = Mark.new()
	add_child(mark)
	table = Control.new()
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(table)
	for i in range(MAX_STACK):
		var c = Card.new()
		table.add_child(c)
		stack.append(c)
	for i in range(DEAL):
		var c = Card.new()
		table.add_child(c)
		dealt.append(c)
	fake_card = Card.new()
	table.add_child(fake_card)
	final_card = Card.new()
	table.add_child(final_card)
	for side in [0, 1]:
		var sh = Polygon2D.new()
		sh.color = Color(0.1, 0.06, 0.03, 0.35)
		table.add_child(sh)
		var clip = Polygon2D.new()
		clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		table.add_child(clip)
		var copy = Card.new()
		clip.add_child(copy)
		halves.append({"clip": clip, "shadow": sh, "card": copy, "side": side})
	role_label = _label(UITheme.color("ink"))
	align_label = _label(UITheme.color("ink"))
	strike = ColorRect.new()
	strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strike)
	seal = Seal.new()
	add_child(seal)
	tag = Control.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tag)
	var thread = ColorRect.new()
	thread.name = "Thread"
	thread.color = UITheme.color("ink")
	tag.add_child(thread)
	var slip = PanelContainer.new()
	slip.name = "Slip"
	tag.add_child(slip)
	tag_label = Label.new()
	tag_label.add_theme_color_override("font_color", UITheme.color("role_secret_ink"))
	slip.add_child(tag_label)
	# Above the cards, whose z_index rises as they come forward.
	for n in [role_label, align_label, strike, seal, tag, mark]:
		n.z_index = 60

func _label(col: Color) -> Label:
	var l = Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l

func _portrait_shader() -> Shader:
	var s = Shader.new()
	# Grey for the dead until their turn; a soft coloured rim on landing (8 reads a pixel).
	s.code = """shader_type canvas_item;
uniform float grey = 0.0;
uniform vec4 glow : source_color = vec4(0.66, 0.12, 0.12, 1.0);
uniform float glow_amount = 0.0;
uniform float glow_px = 10.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(l) * 0.8, grey);
	vec2 r = TEXTURE_PIXEL_SIZE * glow_px;
	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2(r.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV - vec2(r.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, r.y)).a);
	n = max(n, texture(TEXTURE, UV - vec2(0.0, r.y)).a);
	n = max(n, texture(TEXTURE, UV + r * 0.7).a);
	n = max(n, texture(TEXTURE, UV - r * 0.7).a);
	float rim = n * (1.0 - c.a) * glow_amount;
	COLOR = vec4(mix(glow.rgb, c.rgb, c.a), max(c.a, rim * 0.8));
}"""
	return s

func _choose_deal() -> void:
	var truth: String = step.get("role", "")
	var fake: String = step.get("fakeout_role", "")
	var pool: Array = []
	for r in step.get("roles", []):
		if r != truth and r != fake:
			pool.append(r)
	if pool.is_empty():
		pool = [truth]
	var rng = RandomNumberGenerator.new()
	rng.seed = _seed
	_deal_roles = []
	var bag: Array = []
	for i in range(DEAL):
		if bag.is_empty():
			bag = pool.duplicate()
			# A presentation-only shuffle with its own seed.
			for j in range(bag.size() - 1, 0, -1):
				var o = rng.randi_range(0, j)
				var tmp = bag[j]
				bag[j] = bag[o]
				bag[o] = tmp
		_deal_roles.append(bag.pop_back())

func _dress() -> void:
	portrait.texture = step.get("portrait", null)
	name_label.text = step.get("name", "")
	guess_label.text = step.get("guess", "")
	var truth: String = step.get("role", "")
	role_label.text = step.get("role_text", C.role_name(truth))
	var evil = bool(step.get("evil", _is_evil(truth)))
	align_label.text = step.get("align_text", "Evil" if evil else "Good")
	var ink = _team_color(truth, evil)
	role_label.add_theme_color_override("font_color", ink)
	align_label.add_theme_color_override("font_color", ink)
	seal.evil = evil
	var burden: String = step.get("burden", "")
	tag_label.text = burden   # Herald's full string, e.g. "…and Delusional"
	for i in range(DEAL):
		dealt[i].dress(_deal_roles[i], _team_color(_deal_roles[i], _is_evil(_deal_roles[i])))
	final_card.dress(truth, ink)
	var fake: String = step.get("fakeout_role", "")
	if fake != "":
		fake_card.dress(fake, _team_color(fake, _is_evil(fake)))
		for h in halves:
			h.card.dress(fake, _team_color(fake, _is_evil(fake)))
	var pm: ShaderMaterial = portrait.material
	pm.set_shader_parameter("glow", UITheme.color("role_evil_ink") if evil else Color(0.85, 0.66, 0.3))

func _is_evil(r: String) -> bool:
	return C.ROLES.has(r) and C.ROLES[r].get("align", "") == "evil"

func _team_color(r: String, evil: bool) -> Color:
	if evil:
		return UITheme.color("role_evil_ink")
	if C.SECRET_MODS.has(r):
		return UITheme.color("role_secret_ink")
	return UITheme.color("role_good_ink")

# --- Timeline ----------------------------------------------------------------------------

func _make_plan() -> Dictionary:
	var fake = step.get("fakeout_role", "") != ""
	var burden = step.get("burden", "") != ""
	var p = {"fake": fake}
	if reduced_motion:
		p.deal = []
		if fake:
			p.fake_in = 0.0
			p.strike = 0.45
			p.fake_out = 0.8
			p.final_in = 0.8
		else:
			p.final_in = 0.0
		p.landed = p.final_in + 0.35
		p.seal = p.landed + 0.2
		p.tag = p.seal + 0.3
	else:
		var deal = []
		var s = 0.2
		for i in range(DEAL):
			var d = maxf(0.26, 0.46 - 0.025 * i)
			deal.append([s, d])
			s += d * 0.5
		p.deal = deal
		var last = deal[DEAL - 1]
		p.final_at = last[0] + last[1] * 0.6
		if fake:
			p.fake_flip = p.final_at
			p.fake_push = p.fake_flip + 0.25
			p.tear = p.fake_push + 0.4
			p.real_push = p.tear + 0.45
			p.landed = p.real_push + 0.35
		else:
			p.flip = p.final_at
			p.push = p.flip + 0.25
			p.landed = p.push + 0.35
		p.seal = p.landed
		p.tag = p.seal + 0.4
	# A moment to take the card in before Next.
	p.end = (p.tag + 0.45) if burden else (p.seal + 0.6)
	return p

func _emit_due() -> void:
	var deal: Array = _plan.get("deal", [])
	while _dealt_emitted < deal.size() and t >= deal[_dealt_emitted][0]:
		_dealt_emitted += 1
		card_dealt.emit()
	if not _emitted_landed and t >= _plan.landed:
		_emitted_landed = true
		landed.emit()
	if not _emitted_finished and t >= _plan.end:
		_emitted_finished = true
		finished.emit()

# --- Layout and pose ---------------------------------------------------------------------

func _layout() -> void:
	var sz = size if size.x > 0 else REF
	_k = minf(sz.x / REF.x, sz.y / REF.y)
	var k = _k
	portrait.position = Vector2.ZERO
	portrait.size = Vector2(sz.x * 0.45, sz.y)
	var col_x = sz.x * 0.49
	name_label.position = Vector2(col_x, sz.y * 0.01)
	name_label.add_theme_font_size_override("font_size", int(56 * k))
	guess_label.position = Vector2(col_x, sz.y * 0.01 + 74 * k)
	guess_label.add_theme_font_size_override("font_size", int(30 * k))
	_deck_c = Vector2(sz.x * 0.72, sz.y * 0.55)
	for c in stack + dealt + [final_card, fake_card]:
		c.set_card_size(CARD * k, k)
	for h in halves:
		h.card.set_card_size(CARD * k, k)
		var poly = _half_polygon(h.side, CARD * k)
		h.clip.polygon = poly
		h.shadow.polygon = poly
		h.card.position = -CARD * k / 2.0
		h.card.set_flip(1.0, 1.0)
		h.card.set_lift(0.0)
	var below = _deck_c.y + CARD.y * k * PUSH / 2.0 + 8 * k
	role_label.add_theme_font_size_override("font_size", int(52 * k))
	align_label.add_theme_font_size_override("font_size", int(28 * k))
	role_label.position.y = below
	align_label.position.y = below + 62 * k
	seal.size = Vector2(130, 130) * k
	seal.pivot_offset = seal.size / 2.0
	seal.position = _deck_c + Vector2(CARD.x * PUSH / 2.0 - 70, CARD.y * PUSH / 2.0 - 110) * k
	var slip: PanelContainer = tag.get_node("Slip")
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.89, 0.8)
	sb.border_color = UITheme.color("role_secret_ink")
	sb.set_border_width_all(int(maxf(1, 2 * k)))
	sb.set_corner_radius_all(int(4 * k))
	sb.content_margin_left = 18 * k
	sb.content_margin_right = 18 * k
	sb.content_margin_top = 8 * k
	sb.content_margin_bottom = 8 * k
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = int(6 * k)
	sb.shadow_offset = Vector2(3, 5) * k
	slip.add_theme_stylebox_override("panel", sb)
	tag_label.add_theme_font_size_override("font_size", int(32 * k))
	slip.reset_size()
	var thread: ColorRect = tag.get_node("Thread")
	thread.size = Vector2(maxf(1, 2 * k), 70 * k)
	thread.position = Vector2(26 * k, -70 * k)
	slip.position = Vector2.ZERO
	tag.pivot_offset = Vector2(27 * k, -70 * k)
	# The slip hangs just clear of the pushed-out card's left edge (it overlapped it before; Nov 27).
	tag.position = _deck_c + Vector2(-CARD.x * PUSH / 2.0 - TAG_GAP, CARD.y * 0.12) * k - Vector2(slip.size.x, 0)
	tag.set_meta("base", tag.position)

## A ragged tear down the middle of a card: side 0 is the left half, 1 the right.
func _half_polygon(side: int, sz: Vector2) -> PackedVector2Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = 41
	var tear: Array = []
	var x = sz.x * 0.5
	var y = 0.0
	while y <= sz.y:
		x = clampf(x + rng.randf_range(-sz.x * 0.04, sz.x * 0.04), sz.x * 0.38, sz.x * 0.62)
		tear.append(Vector2(x, y))
		y += sz.y / 26.0
	tear[tear.size() - 1].y = sz.y
	var pts: Array = []
	if side == 0:
		pts = [Vector2(0, 0)] + tear + [Vector2(0, sz.y)]
	else:
		var back = tear.duplicate()
		back.reverse()
		pts = [Vector2(sz.x, 0), Vector2(sz.x, sz.y)] + back
	var out = PackedVector2Array()
	for p in pts:
		out.append(p - sz / 2.0)
	return out

static func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

func _place(card, centre: Vector2, scale_by: float, rot_deg: float = 0.0, flip: float = 1.0, lift: float = 0.0, z: int = 0, alpha: float = 1.0) -> void:
	card.visible = alpha > 0.0
	card.position = centre - card.size / 2.0
	card.rotation_degrees = rot_deg
	card.set_flip(flip, scale_by)
	card.set_lift(lift)
	card.z_index = z
	card.modulate.a = alpha

func _apply() -> void:
	if step.is_empty() or _plan.is_empty():
		return
	var p = _plan
	var k = _k
	var D = _deck_c
	for c in stack + dealt + [final_card, fake_card]:
		c.visible = false
	for h in halves:
		h.clip.visible = false
		h.shadow.visible = false
	strike.visible = false
	var true_shown = false
	var fake_label = false
	if reduced_motion:
		if p.fake and t < p.fake_out + 0.15:
			var a = _smooth(t / 0.25) * (1.0 - _smooth((t - p.fake_out) / 0.15))
			_place(fake_card, D, 1.15, 0, 1.0, 0.5, 5, a)
			fake_label = true
		if t >= p.final_in:
			var a = _smooth((t - p.final_in) / 0.3)
			_place(final_card, D, PUSH, 0, 1.0, 0.8, 6, a)
			true_shown = t >= p.landed
	else:
		_pose_deal(p, D, k)
		var final_t = p.final_at
		if not p.fake:
			if t >= final_t:
				var f = _smooth((t - p.flip) / 0.25)
				var u = _ease_out((t - p.push) / 0.35)
				_place(final_card, D + Vector2(0, -6 * k * u), 1.0 + (PUSH - 1.0) * u, 0, f, 0.1 + 0.9 * u, 30)
				true_shown = t >= p.landed
		else:
			if t >= final_t:
				if t < p.tear:
					# The true card waits face down beneath; it turns face up once the false
					# card has grown enough to hide it.
					var hidden_under = t >= p.fake_push + 0.05
					_place(final_card, D, 1.0, 0, 1.0 if hidden_under else 0.0, 0.05, 20)
					var f = _smooth((t - p.fake_flip) / 0.25)
					var u = _ease_out((t - p.fake_push) / 0.4) * 0.45
					_place(fake_card, D + Vector2(0, -6 * k * u), 1.0 + (PUSH - 1.0) * u, 0, f, 0.1 + 0.9 * u, 30)
					fake_label = t >= p.fake_flip + 0.25
				elif t < p.real_push + 0.35:
					var u = _ease_out((t - p.real_push) / 0.35)
					_place(final_card, D + Vector2(0, -6 * k * u), 1.0 + (PUSH - 1.0) * u, 0, 1.0, 0.1 + 0.9 * u, 30)
					_pose_tear(p, D, k)
					fake_label = t < p.tear + 0.2
					strike.visible = fake_label
				else:
					_place(final_card, D + Vector2(0, -6 * k), PUSH, 0, 1.0, 1.0, 30)
					true_shown = t >= p.landed
	# The labels under the card.
	var show_role = true_shown or (t >= p.landed)
	var label_fake = fake_label and not show_role
	role_label.visible = show_role or label_fake
	align_label.visible = show_role
	if label_fake:
		role_label.text = step.get("fakeout_role_text", C.role_name(step.get("fakeout_role", "")))
		role_label.add_theme_color_override("font_color", _team_color(step.fakeout_role, _is_evil(step.fakeout_role)))
	else:
		role_label.text = step.get("role_text", C.role_name(step.get("role", "")))
		role_label.add_theme_color_override("font_color", _team_color(step.role, bool(step.get("evil", _is_evil(step.role)))))
	role_label.reset_size()
	role_label.position.x = D.x - role_label.size.x / 2.0
	align_label.reset_size()
	align_label.position.x = D.x - align_label.size.x / 2.0
	if reduced_motion and p.fake and t >= p.strike and t < p.fake_out + 0.15:
		strike.visible = true
	if strike.visible:
		strike.color = UITheme.color("ink")
		strike.size = Vector2(role_label.size.x + 12 * k, maxf(2, 4 * k))
		strike.position = role_label.position + Vector2(-6 * k, role_label.size.y * 0.55)
	# The seal and the tag.
	var su = (t - p.seal) / 0.25
	seal.visible = t >= p.seal
	seal.modulate.a = _smooth(su * 2.0)
	var stamp = 1.0 if reduced_motion else lerpf(1.5, 1.0, _ease_out(su))
	seal.scale = Vector2.ONE * stamp
	var has_tag = step.get("burden", "") != ""
	tag.visible = has_tag and t >= p.tag
	if tag.visible:
		var du = (t - p.tag) / 0.3
		var drop = 1.0 if reduced_motion else _ease_out(du)
		tag.modulate.a = _smooth(du * 3.0) if reduced_motion else 1.0
		var base: Vector2 = tag.get_meta("base", tag.position)
		tag.position.y = base.y - 60 * k * (1.0 - drop)
		var swing = 0.0 if reduced_motion else 7.0 * exp(-3.0 * maxf(0.0, t - p.tag - 0.2)) * sin((t - p.tag) * 14.0)
		tag.rotation_degrees = swing
	# The guess mark and the portrait.
	mark.visible = step.has("guess_correct") and t >= p.landed
	if mark.visible:
		mark.correct = bool(step.guess_correct)
		guess_label.reset_size()
		mark.size = Vector2(34, 34) * _k
		mark.position = guess_label.position + Vector2(guess_label.size.x + 14 * _k, (guess_label.size.y - mark.size.y) / 2.0)
		mark.queue_redraw()
	var pm: ShaderMaterial = portrait.material
	pm.set_shader_parameter("grey", (1.0 - _smooth(t / 0.4)) if step.get("dead", false) else 0.0)
	pm.set_shader_parameter("glow_amount", _smooth((t - p.landed) / 0.35) if t >= p.landed else 0.0)
	pm.set_shader_parameter("glow_px", 10.0)

func _pose_deal(p: Dictionary, D: Vector2, k: float) -> void:
	var started = 0
	for i in range(DEAL):
		var s = p.deal[i][0]
		var d = p.deal[i][1]
		if t < s:
			continue
		started += 1
		var u = (t - s) / d
		if u >= 1.0:
			continue
		var side = 1.0 if i % 2 == 0 else -1.0
		var c = dealt[i]
		if u < 0.22:          # slide off the top and flip
			var v = u / 0.22
			_place(c, D + Vector2(side * 30 * v, -30 * v) * k, 1.0 + 0.05 * v, 0, v, 0.3 * v, 40 + i)
		elif u < 0.78:        # arc up and out to the side, and down beside the deck
			# From where the flip left it, (30, -30), to where the slide back starts,
			# (250, 30), bulging up on the way; size and shadow meet both ends too.
			var v = _smooth((u - 0.22) / 0.56)
			var a = PI * v
			var off = Vector2(side * (30 + 220 * v + 40 * sin(a)), -30 + 60 * v - 80 * sin(a))
			_place(c, D + off * k, 1.05 - 0.05 * v + 0.1 * sin(a), side * -12 * sin(a), 1.0, 0.3 - 0.2 * v + 0.4 * sin(a), 40 + i)
		else:                 # slide back in under the deck
			var v = _smooth((u - 0.78) / 0.22)
			_place(c, D + Vector2(side * 250 * (1.0 - v), 30 * (1.0 - v)) * k, 1.0, 0, 1.0, 0.1, -10)
	# The deck itself: what's left, face down, slightly stacked.
	var finals = 2 if p.fake else 1
	var left = DEAL - started + finals
	if t >= p.final_at:
		left = 0
	var n = mini(left, MAX_STACK)
	for j in range(n):
		_place(stack[j], D - Vector2(1.5, 1.5) * k * j, 1.0, 0, 0.0, 0.1 if j == n - 1 else 0.0, j)

func _pose_tear(p: Dictionary, D: Vector2, k: float) -> void:
	var v = clampf((t - p.tear) / 0.45, 0.0, 1.0)
	var s = 1.0 + (PUSH - 1.0) * 0.45
	for h in halves:
		var sgn = -1.0 if h.side == 0 else 1.0
		var pos = D + Vector2(sgn * (6 + 460 * v), -6 - 130 * v + 1000 * v * v) * k
		var rot = sgn * -70.0 * v
		for n in [h.clip, h.shadow]:
			n.visible = v < 1.0
			n.position = pos
			n.rotation_degrees = rot
			n.scale = Vector2.ONE * s
			n.z_index = 35
		h.shadow.position += Vector2(10, 16) * k
		h.shadow.z_index = 34

# --- Pieces ------------------------------------------------------------------------------

## A card: a paper face (role icon and name, in its team's ink) and a back, with a soft
## shadow that lifts as the card comes forward.
class Card extends Control:
	var face: Panel
	var back: Panel
	var icon: TextureRect
	var name_label: Label
	var emblem: Control
	var _face_sb: StyleBoxFlat
	var _back_sb: StyleBoxFlat
	var _k := 1.0
	var _flip := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		face = Panel.new()
		back = Panel.new()
		for p in [face, back]:
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(p)
		_face_sb = StyleBoxFlat.new()
		_face_sb.bg_color = Color(0.94, 0.9, 0.8)
		_back_sb = StyleBoxFlat.new()
		_back_sb.bg_color = Color(0.43, 0.13, 0.12)
		_back_sb.border_color = Color(0.8, 0.63, 0.32)
		for sb in [_face_sb, _back_sb]:
			sb.shadow_color = Color(0.1, 0.06, 0.03, 0.4)
		face.add_theme_stylebox_override("panel", _face_sb)
		back.add_theme_stylebox_override("panel", _back_sb)
		icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(icon)
		name_label = Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(name_label)
		emblem = Emblem.new()
		back.add_child(emblem)

	func dress(role: String, ink: Color) -> void:
		var tex = UITheme.tex("ui/roles/" + role, 0.4)
		icon.texture = tex if tex != null else UITheme.tex("ui/roles/unknown", 0.4)
		icon.material = MainRoles.team_icon_material(ink)
		name_label.text = C.role_name(role)
		name_label.add_theme_color_override("font_color", ink)
		_face_sb.border_color = ink

	func set_card_size(sz: Vector2, k: float) -> void:
		_k = k
		size = sz
		pivot_offset = sz / 2.0
		for p in [face, back]:
			p.position = Vector2.ZERO
			p.size = sz
		_face_sb.set_border_width_all(int(maxf(1, 4 * k)))
		_back_sb.set_border_width_all(int(maxf(1, 5 * k)))
		for sb in [_face_sb, _back_sb]:
			sb.set_corner_radius_all(int(10 * k))
		icon.position = Vector2(sz.x * 0.14, sz.y * 0.1)
		icon.size = Vector2(sz.x * 0.72, sz.y * 0.58)
		name_label.add_theme_font_size_override("font_size", int(30 * k))
		name_label.position = Vector2(0, sz.y * 0.74)
		name_label.size = Vector2(sz.x, sz.y * 0.2)
		emblem.position = sz * 0.15
		emblem.size = sz * 0.7
		set_lift(0.0)

	## flip: 0 shows the back, 1 the face; the card narrows to an edge between them.
	func set_flip(f: float, s: float) -> void:
		_flip = f
		face.visible = f >= 0.5
		back.visible = f < 0.5
		scale = Vector2(maxf(0.02, absf(cos(PI * f))) * s, s)

	func set_lift(l: float) -> void:
		for sb in [_face_sb, _back_sb]:
			sb.shadow_size = int((3 + 14 * l) * _k)
			sb.shadow_offset = Vector2(3 + 10 * l, 5 + 16 * l) * _k

## The card back's emblem: a five-pointed star in a ring, in gold.
class Emblem extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var gold = Color(0.8, 0.63, 0.32)
		var c = size / 2.0
		var r = minf(size.x, size.y) * 0.32
		draw_arc(c, r * 1.2, 0, TAU, 48, gold, maxf(1.0, r * 0.05), true)
		var pts = PackedVector2Array()
		for i in range(6):
			var a = -PI / 2.0 + (i * 2 % 5) * TAU / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, gold, maxf(1.0, r * 0.07), true)

## The alignment seal: a wax disc, gold for good and red for evil.
class Seal extends Control:
	var evil := false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var col = Color(0.62, 0.14, 0.12) if evil else Color(0.72, 0.55, 0.22)
		var c = size / 2.0
		var r = minf(size.x, size.y) / 2.0
		draw_circle(c + Vector2(r * 0.05, r * 0.08), r, Color(0, 0, 0, 0.3))
		draw_circle(c, r, col)
		draw_arc(c, r * 0.74, 0, TAU, 48, col.darkened(0.3), maxf(1.0, r * 0.08), true)
		var pts = PackedVector2Array()
		for i in range(6):
			var a = -PI / 2.0 + (i * 2 % 5) * TAU / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * r * 0.45)
		draw_polyline(pts, col.lightened(0.35), maxf(1.0, r * 0.07), true)

## The tick or cross beside the player's guess.
class Mark extends Control:
	var correct := true
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
	func _draw() -> void:
		var w = maxf(2.0, size.x * 0.14)
		if correct:
			var col = Color(0.25, 0.48, 0.2)
			draw_polyline(PackedVector2Array([Vector2(size.x * 0.1, size.y * 0.55), Vector2(size.x * 0.4, size.y * 0.85), Vector2(size.x * 0.92, size.y * 0.15)]), col, w, true)
		else:
			var col = Color(0.62, 0.14, 0.12)
			draw_line(Vector2(size.x * 0.15, size.y * 0.15), Vector2(size.x * 0.85, size.y * 0.85), col, w, true)
			draw_line(Vector2(size.x * 0.85, size.y * 0.15), Vector2(size.x * 0.15, size.y * 0.85), col, w, true)
