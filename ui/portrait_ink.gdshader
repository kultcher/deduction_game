// Interior ink over the ORIGINAL colour portrait. The original silhouette, paper,
// structural lines and face are stable. R is structural ink (unused); G is hatching.
// The controller supplies a monotonic step, so intensity never changes the clock.
shader_type canvas_item;

uniform sampler2D lines_a : filter_linear, repeat_disable;
uniform sampler2D lines_b : filter_linear, repeat_disable;
uniform sampler2D lines_c : filter_linear, repeat_disable;
uniform float redraw_step = 0.0;
uniform float seed = 27.0;
uniform int variant_count : hint_range(1, 3) = 1;
uniform float displacement_px : hint_range(0.0, 4.0) = 1.2;
uniform float patch_size_px = 90.0;
uniform float ink_amount : hint_range(0.0, 1.0) = 0.6;
uniform vec4 ink_color : source_color = vec4(0.13, 0.08, 0.06, 1.0);
uniform vec4 protected_face = vec4(0.465, 0.245, 0.225, 0.175);
uniform bool protect_face = true;
uniform bool protect_edge = true;
uniform bool show_protection = false;
uniform bool warp_enabled = true;
// Optional experiments, off in the recommended preset. Never remove hatch patches.
uniform float pressure_variation : hint_range(0.0, 0.2) = 0.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

vec2 field(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(cell), hash2(cell + vec2(1.0, 0.0)), u.x),
		mix(hash2(cell + vec2(0.0, 1.0)), hash2(cell + vec2(1.0)), u.x), u.y) * 2.0 - 1.0;
}

float hatching(vec2 uv) {
	int drawing = int(mod(redraw_step, float(max(variant_count, 1))));
	if (drawing == 1) return texture(lines_b, uv).g;
	if (drawing == 2) return texture(lines_c, uv).g;
	return texture(lines_a, uv).g;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 p = UV / px;
	float editable = 1.0;
	if (protect_face) {
		float d = length((UV - protected_face.xy) / max(protected_face.zw, vec2(0.001)));
		editable *= smoothstep(1.0, 1.16, d);
	}
	if (protect_edge) {
		// Erode the permission mask, not the artwork. Hatch ink cannot escape the
		// original cutout or make its contour wobble against the stationary fill.
		vec2 guard_px = px * (4.0 + displacement_px);
		float inside = min(min(texture(TEXTURE, UV + vec2(guard_px.x, 0.0)).a,
			texture(TEXTURE, UV - vec2(guard_px.x, 0.0)).a),
			min(texture(TEXTURE, UV + vec2(0.0, guard_px.y)).a,
			texture(TEXTURE, UV - vec2(0.0, guard_px.y)).a));
		editable *= smoothstep(0.95, 1.0, inside);
	}
	vec2 offset = field(p / max(patch_size_px, 1.0) + hash2(vec2(redraw_step, seed)) * 100.0);
	vec2 uv = UV + offset * displacement_px * px * editable * float(warp_enabled);
	float hatch = hatching(uv) * editable;
	float pressure = 1.0 + field(p / 180.0 + vec2(redraw_step, seed)).x * pressure_variation;
	float amount = clamp(hatch * ink_amount * pressure * ink_color.a, 0.0, 1.0);
	// Darkening only: added ink never lightens an existing dark stroke or garment.
	vec3 rgb = mix(base.rgb, min(base.rgb, ink_color.rgb), amount);
	if (show_protection) rgb = mix(rgb, vec3(0.2, 0.8, 0.65), (1.0 - editable) * 0.35);
	COLOR = vec4(rgb, base.a) * tint;
}
