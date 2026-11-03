// Paper cutout: draws a transparent-background portrait as if cut from a sheet of
// paper. An irregular off-white margin follows the silhouette (the "scissor" edge),
// a soft shadow sits under it, and a paper grain runs across the art and the margin.
// Works on any texture with alpha; every size is in source-texture pixels, so the look
// scales with the portrait. Purely presentational: nothing reads it back.
shader_type canvas_item;

// Shared paper texture: any tileable greyscale (a NoiseTexture2D works). Mid-grey = no change.
uniform sampler2D grain_tex : repeat_enable, filter_linear;
uniform float grain_scale = 1.5;            // texture pixels per grain texel
uniform float grain_strength : hint_range(0.0, 1.0) = 0.25;
uniform float art_grain : hint_range(0.0, 1.0) = 0.5;   // how much grain shows on the art itself

uniform vec4 paper_color : source_color = vec4(0.95, 0.91, 0.82, 1.0);
uniform float edge_px = 14.0;               // width of the paper margin
// Hand-cut irregularity comes from a smooth, low-detail noise so the cut stays crisp.
uniform sampler2D wobble_tex : repeat_enable, filter_linear;
uniform float edge_wobble : hint_range(0.0, 1.0) = 0.45;
uniform float wobble_scale = 2.0;           // texture pixels per wobble texel
uniform vec4 edge_line_color : source_color = vec4(0.35, 0.27, 0.2, 0.55);
uniform float edge_line_px = 1.6;           // the faint outer line of the cut

uniform vec4 shadow_color : source_color = vec4(0.05, 0.03, 0.02, 0.55);
uniform vec2 shadow_offset_px = vec2(10.0, 14.0);
uniform float shadow_blur_px = 12.0;

// Tonal cross-hatching. Lines are laid where the art is darker than its surroundings
// (folds, cast shadows, the turn of a form), not where its colour is dark, so skin tone
// and dark cloth aren't hatched flat. Up to three layers at different angles.
uniform float hatch_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hatch_ink : source_color = vec4(0.16, 0.1, 0.07, 1.0);
uniform float hatch_spacing_px = 11.0;      // texture pixels between lines
uniform float hatch_width : hint_range(0.05, 0.6) = 0.22; // line thickness, fraction of spacing
uniform float hatch_contrast = 5.0;         // how quickly shading turns into lines
uniform float hatch_floor : hint_range(0.0, 0.2) = 0.04;  // shading below this stays clean
uniform float hatch_wobble : hint_range(0.0, 1.0) = 0.35; // hand-drawn waver
uniform float shade_radius_px = 26.0;       // what "surroundings" means

const int DIRS = 16;

varying vec4 tint;   // the node's modulate (crossfades), kept apart from the texture

void vertex() {
	tint = COLOR;
}

// Largest alpha within `radius` of `uv`: the silhouette grown outward.
float grown(sampler2D tex, vec2 uv, vec2 px, float radius) {
	float a = texture(tex, uv).a;
	for (int i = 0; i < DIRS; i++) {
		float ang = 6.2831853 * float(i) / float(DIRS);
		vec2 dir = vec2(cos(ang), sin(ang));
		a = max(a, texture(tex, uv + dir * radius * px).a);
		a = max(a, texture(tex, uv + dir * radius * 0.5 * px).a);
	}
	return a;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Average luminance in a ring of `radius` (alpha-weighted, so the background doesn't count).
float ring_luma(sampler2D tex, vec2 uv, vec2 px, float radius) {
	float sum = 0.0;
	float w = 0.0;
	for (int i = 0; i < 12; i++) {
		float ang = 6.2831853 * float(i) / 12.0;
		vec4 c = texture(tex, uv + vec2(cos(ang), sin(ang)) * radius * px);
		sum += luma(c.rgb) * c.a;
		w += c.a;
	}
	return w > 0.0 ? sum / w : 0.0;
}

// One layer of parallel lines at `angle`: 1 on a line, 0 between, antialiased.
float hatch_layer(vec2 p, float angle, float spacing, float width, float wobble) {
	vec2 d = vec2(cos(angle), sin(angle));
	float x = dot(p, vec2(-d.y, d.x)) / spacing + wobble;
	float f = abs(fract(x) - 0.5) * 2.0;           // 0 at line centre
	float aa = fwidth(x) * 2.0;
	return 1.0 - smoothstep(width - aa, width + aa, f);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 tex_px = UV / px;
	vec4 art = texture(TEXTURE, UV);

	// Hand-cut margin: the radius wanders with a low-frequency noise.
	float wob = texture(wobble_tex, tex_px / wobble_scale / 512.0 * 4.0).r * 2.0 - 1.0;
	float radius = edge_px * (1.0 + edge_wobble * wob);
	float cut = smoothstep(0.42, 0.58, grown(TEXTURE, UV, px, radius));
	float cut_inner = smoothstep(0.42, 0.58, grown(TEXTURE, UV, px, max(radius - edge_line_px, 0.0)));

	// Shadow of the whole cutout, offset and softened.
	vec2 suv = UV - shadow_offset_px * px;
	float sh = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = 6.2831853 * float(i) / 8.0;
		sh += grown(TEXTURE, suv + vec2(cos(ang), sin(ang)) * shadow_blur_px * 0.5 * px, px, radius);
	}
	sh = smoothstep(0.0, 1.0, sh / 8.0);

	float g = texture(grain_tex, tex_px / grain_scale).r - 0.5;
	vec3 margin = paper_color.rgb * (1.0 + g * grain_strength);
	margin = mix(margin, edge_line_color.rgb, edge_line_color.a * (cut - cut_inner));
	vec3 art_rgb = art.rgb * (1.0 + g * grain_strength * art_grain);
	if (hatch_strength > 0.0 && art.a > 0.0) {
		float here = (luma(art.rgb) + ring_luma(TEXTURE, UV, px, 3.0)) * 0.5;
		float around = (ring_luma(TEXTURE, UV, px, shade_radius_px) + ring_luma(TEXTURE, UV, px, shade_radius_px * 0.5)) * 0.5;
		float shade = clamp((around - here - hatch_floor) * hatch_contrast, 0.0, 1.0);
		float waver = (texture(wobble_tex, tex_px / 400.0).r - 0.5) * hatch_wobble * 3.0;
		float lines = hatch_layer(tex_px, 0.785, hatch_spacing_px, hatch_width, waver) * step(0.15, shade);
		lines = max(lines, hatch_layer(tex_px, -0.785, hatch_spacing_px, hatch_width, -waver) * step(0.45, shade));
		lines = max(lines, hatch_layer(tex_px, 0.2, hatch_spacing_px * 0.8, hatch_width, waver * 0.5) * step(0.75, shade));
		// Ink fades in with the shading so the first lines are faint.
		lines *= smoothstep(0.1, 0.5, shade);
		art_rgb = mix(art_rgb, art_rgb * hatch_ink.rgb * 1.6, lines * hatch_strength);
	}

	// Layering, back to front: shadow, paper margin, art.
	vec4 col = vec4(shadow_color.rgb, shadow_color.a * sh);
	col = mix(col, vec4(margin, 1.0), cut);
	col = mix(col, vec4(art_rgb, 1.0), art.a);
	COLOR = col * tint;
}
