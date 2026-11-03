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

	// Layering, back to front: shadow, paper margin, art.
	vec4 col = vec4(shadow_color.rgb, shadow_color.a * sh);
	col = mix(col, vec4(margin, 1.0), cut);
	col = mix(col, vec4(art_rgb, 1.0), art.a);
	COLOR = col * tint;
}
