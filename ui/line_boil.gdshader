// Line boil: rotoscope-style "redrawn every frame" ink over a steady colour portrait.
// Put it on the TextureRect that shows the colour base (TEXTURE). The ink comes from
// two or three channel-packed line layers (R = outline, G = hatching), each a slightly
// different drawing of the same lines; the shader cycles them on a stepped clock and,
// each step, bends them with fresh noise, shifts their weight and drops hatch patches.
// `boil` (0..1) scales all of it: keep it low at rest and flare it on an expression change.
// Sizes are in source-texture pixels. Presentation only.
shader_type canvas_item;

uniform sampler2D lines_a : filter_linear;
uniform sampler2D lines_b : filter_linear;
uniform sampler2D lines_c : filter_linear;
uniform int variant_count : hint_range(1, 3) = 3;

uniform float boil : hint_range(0.0, 1.0) = 0.2;
uniform float fps_rest = 8.0;               // steps per second at boil 0 ("on threes")
uniform float fps_flare = 14.0;             // ...and at boil 1
uniform float clock = -1.0;                 // seconds; < 0 uses TIME (set it for recordings)
uniform float drawing_step = -1.0;          // optional integrated controller clock

// Any smooth tileable greyscale noise (a Simplex NoiseTexture2D).
uniform sampler2D warp_tex : repeat_enable, filter_linear;
uniform float warp_px = 3.0;                // how far lines wander at boil 1
uniform float warp_rest_px = 0.8;           // ...and at boil 0
uniform float warp_size_px = 180.0;         // size of a bend: bigger = lazier ripples

uniform vec4 ink_color : source_color = vec4(0.13, 0.08, 0.06, 1.0);
uniform float weight_flicker : hint_range(0.0, 1.0) = 0.6; // lines thicken and thin per step
uniform float hatch_flicker : hint_range(0.0, 1.0) = 0.7;  // hatch patches come and go
uniform float hatch_amount : hint_range(0.0, 1.0) = 0.85;
uniform float base_jitter_px = 0.6;         // the colour layer barely moves

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

vec2 hash2(float n) {
	return vec2(hash(n), hash(n + 17.0));
}

vec4 lines_at(int v, vec2 uv) {
	if (v == 1) return texture(lines_b, uv);
	if (v == 2) return texture(lines_c, uv);
	return texture(lines_a, uv);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 tex_px = UV / px;
	float b = clamp(boil, 0.0, 1.0);
	float t = clock >= 0.0 ? clock : TIME;
	// Keep the old look as a comparison, but never multiply elapsed time by a
	// changing rate: settling a flare must not rewind or skip the drawing clock.
	float step_n = drawing_step >= 0.0 ? floor(drawing_step) : floor(t * fps_rest);
	vec2 h = hash2(step_n);

	// A fresh bend each step: two lookups into the same noise, far apart, give x and y.
	vec2 wuv = tex_px / warp_size_px / 4.0 + h * 7.0;
	vec2 bend = vec2(texture(warp_tex, wuv).r, texture(warp_tex, wuv + vec2(0.43, 0.71)).r) - 0.5;
	vec2 luv = UV + bend * 2.0 * mix(warp_rest_px, warp_px, b) * px;

	// Cycle the drawings, skipping the repeat a plain modulo would make with one variant.
	int v = variant_count > 1 ? int(mod(step_n, float(variant_count))) : 0;
	vec4 L = lines_at(v, luv);

	// Pen weight: shift where the anti-aliased line is cut, by region and by step.
	float region = texture(warp_tex, tex_px / 260.0 + h.yx * 5.0).r - 0.5;
	float cut = 0.5 + (region * 0.8 + (h.x - 0.5) * 0.4) * weight_flicker * (0.25 + b);
	float outline = smoothstep(cut - 0.28, cut + 0.18, L.r);

	// Hatching: patches drop out and return, more as boil rises.
	float patch = texture(warp_tex, tex_px / 140.0 + h * 3.0).r;
	float keep = mix(1.0, smoothstep(0.32, 0.55, patch), hatch_flicker * (0.3 + 0.7 * b));
	float hatch = L.g * keep * hatch_amount;

	float ink = clamp(max(outline, hatch * 0.9), 0.0, 1.0) * ink_color.a;
	vec4 base = texture(TEXTURE, UV + (h - 0.5) * 2.0 * base_jitter_px * b * px);
	vec3 rgb = mix(base.rgb, ink_color.rgb, ink);
	// Ink can stray a hair outside the silhouette, as a redrawn contour would.
	COLOR = vec4(rgb, max(base.a, outline * ink_color.a)) * tint;
}
