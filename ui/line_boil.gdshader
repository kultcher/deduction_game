// Line boil: rotoscope-style "redrawn every frame" ink over a steady colour portrait.
// Two layers: TEXTURE is the colour base (the portrait with its own lines lifted out) and
// `ink` is the drawn linework, channel-packed by tools/make_line_boil_layers.py:
//   R outlines, G the same outlines redrawn, B hatching and shadow, A a value per hatch stroke.
// On each redraw step the ink is bent by fresh noise, the outline drawing alternates,
// line weight shifts by region and a few hatch strokes are left out. The colour stays put.
// `boil` (0..1) scales all of it: low at rest, flared on an expression change.
// `redraw_step` comes from ui/line_boil.gd (a steady clock); a negative value falls back to
// TIME for previews. Presentation only. Cost: 6 texture reads a pixel, no loops.
shader_type canvas_item;

uniform sampler2D ink : filter_linear, repeat_disable;
// Any smooth tileable greyscale noise (ui/line_boil.gd makes a Simplex NoiseTexture2D).
uniform sampler2D warp_tex : repeat_enable, filter_linear;

uniform float boil : hint_range(0.0, 1.0) = 0.3;
uniform float redraw_step = -1.0;
uniform float fps_fallback = 8.0;            // steps per second when redraw_step < 0

uniform float warp_px = 3.0;                 // how far lines wander at boil 1 (source pixels)
uniform float warp_rest_px = 0.8;            // ...and at boil 0
uniform float warp_size_px = 180.0;          // size of a bend: bigger = lazier ripples
uniform float weight_flicker : hint_range(0.0, 1.0) = 0.6;   // lines thicken and thin per step
uniform float hatch_drop : hint_range(0.0, 1.0) = 0.25;      // share of hatch strokes left out
uniform float hatch_amount : hint_range(0.0, 1.0) = 0.85;
uniform float ink_amount : hint_range(0.0, 1.0) = 1.0;       // 0 shows the colour layer alone
uniform vec4 ink_color : source_color = vec4(0.13, 0.08, 0.06, 1.0);
uniform float base_jitter_px = 0.6;          // the colour layer barely moves, and only at boil 1

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 tex_px = UV / px;
	float b = clamp(boil, 0.0, 1.0);
	float step_n = redraw_step >= 0.0 ? redraw_step : floor(TIME * fps_fallback);
	vec2 h = vec2(hash(step_n), hash(step_n + 17.0));

	// A fresh bend each step: two lookups into the same noise, far apart, give x and y.
	vec2 wuv = tex_px / warp_size_px / 4.0 + h * 7.0;
	vec2 bend = vec2(texture(warp_tex, wuv).r, texture(warp_tex, wuv + vec2(0.43, 0.71)).r) - 0.5;
	vec4 L = texture(ink, UV + bend * 2.0 * mix(warp_rest_px, warp_px, b) * px);

	// Alternate the two outline drawings, then shift where the anti-aliased line is cut,
	// by region and by step, so the pen presses harder in some places on each redraw.
	float line = mod(step_n, 2.0) < 1.0 ? L.r : L.g;
	float region = texture(warp_tex, tex_px / 260.0 + h.yx * 5.0).r - 0.5;
	float cut = 0.5 + (region * 0.8 + (h.x - 0.5) * 0.4) * weight_flicker * (0.25 + b);
	float outline = smoothstep(cut - 0.28, cut + 0.18, line);

	// Hatching: each redraw leaves out a different few strokes, more as boil rises.
	float stroke = fract(L.a * 255.0 * 0.6180339 + h.y);
	float keep = step(hatch_drop * (0.4 + 0.6 * b), stroke);
	float hatch = L.b * keep * hatch_amount;

	float amount = clamp(max(outline, hatch * 0.9), 0.0, 1.0) * ink_color.a * ink_amount;
	vec4 base = texture(TEXTURE, UV + (h - 0.5) * 2.0 * base_jitter_px * b * px);
	vec3 rgb = mix(base.rgb, ink_color.rgb, amount);
	// Ink can stray a hair outside the silhouette, as a redrawn contour would.
	COLOR = vec4(rgb, max(base.a, outline * ink_color.a * ink_amount)) * tint;
}
