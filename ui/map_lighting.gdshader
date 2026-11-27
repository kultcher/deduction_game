shader_type canvas_item;

// Painterly time-of-day split-tone grading and curved sweeping wave transitions
// for the town map (ui/map_view.gd).
//
// Phase IDs match sim/content.gd:
//   0 = Morning (golden hour)
//   1 = Afternoon (neutral daylight — original painted map balance)
//   2 = Evening (cool twilight / blue hour)
//   3 = Night (moonlit nocturne with Purkinje shift)

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform int from_phase = 0;
uniform int to_phase = 0;
uniform float progress : hint_range(0.0, 1.0) = 1.0;

// Map rect inside the MapView Control (in local control pixels), so the curved
// sunlight arc stays anchored to the town map even when zoomed into a block.
uniform vec4 map_rect = vec4(0.0, 0.0, 1000.0, 700.0);
uniform vec2 control_size = vec2(1000.0, 700.0);

// Curved arc sweeping right -> left from an off-screen sun origin on the right.
uniform vec2 sun_origin = vec2(1.85, 0.45);
uniform vec2 arc_squash = vec2(1.0, 0.52);
uniform float band_width : hint_range(0.05, 1.0) = 0.44;
uniform float edge_grain : hint_range(0.0, 0.08) = 0.025;

struct Grade {
	vec3 shadow_tint;
	vec3 mid_tint;
	vec3 high_tint;
	float sat;
	float exposure;
	float purkinje;
	float warm_lift;
};

Grade grade_morning() {
	// Golden hour: honey-gold highlights, warm amber-peach midtones, subtle cool
	// slate-plum shadows so dark teal trees and river stay rich instead of muddy.
	return Grade(
		vec3(0.85, 0.83, 0.94),
		vec3(1.07, 0.98, 0.83),
		vec3(1.14, 1.04, 0.80),
		1.06,
		1.03,
		0.0,
		0.03
	);
}

Grade grade_afternoon() {
	// Neutral daylight: preserves the painted map's original colour balance.
	return Grade(
		vec3(1.0, 1.0, 1.0),
		vec3(1.0, 1.0, 1.0),
		vec3(1.0, 1.0, 1.0),
		1.0,
		1.0,
		0.0,
		0.0
	);
}

Grade grade_evening() {
	// Blue hour / cool dusk: periwinkle highlights, cool slate-blue midtones,
	// deeper twilight indigo shadows.
	return Grade(
		vec3(0.54, 0.64, 0.90),
		vec3(0.78, 0.87, 1.05),
		vec3(0.92, 0.96, 1.08),
		0.88,
		0.84,
		0.08,
		0.0
	);
}

Grade grade_night() {
	// Moonlit nocturne: silver-blue moonlight highlights, midnight blue midtones,
	// deep navy-indigo shadows, desaturated with a gentle Purkinje shift.
	return Grade(
		vec3(0.28, 0.36, 0.62),
		vec3(0.50, 0.60, 0.86),
		vec3(0.76, 0.86, 1.04),
		0.68,
		0.56,
		0.36,
		0.0
	);
}

Grade grade_for_phase(int p) {
	if (p == 0) {
		return grade_morning();
	}
	if (p == 1) {
		return grade_afternoon();
	}
	if (p == 2) {
		return grade_evening();
	}
	return grade_night();
}

Grade mix_grade(Grade a, Grade b, float t) {
	return Grade(
		mix(a.shadow_tint, b.shadow_tint, t),
		mix(a.mid_tint, b.mid_tint, t),
		mix(a.high_tint, b.high_tint, t),
		mix(a.sat, b.sat, t),
		mix(a.exposure, b.exposure, t),
		mix(a.purkinje, b.purkinje, t),
		mix(a.warm_lift, b.warm_lift, t)
	);
}

// Multi-stop wave colour ramp for each phase transition so dawn/dusk paint
// across the map in realistic intermediate hues (e.g. night -> violet -> rose -> gold).
Grade transition_grade(int a, int b, float t) {
	// Night -> Morning (Dawn): indigo -> pale violet -> pale rose/peach -> morning gold
	if (a == 3 && b == 0) {
		Grade g_night = grade_night();
		Grade g_violet = Grade(
			vec3(0.38, 0.34, 0.62),
			vec3(0.78, 0.68, 0.96),
			vec3(0.96, 0.86, 1.06),
			0.84, 0.78, 0.14, 0.01
		);
		Grade g_rose = Grade(
			vec3(0.64, 0.54, 0.70),
			vec3(1.10, 0.86, 0.80),
			vec3(1.18, 0.95, 0.84),
			1.04, 0.96, 0.0, 0.035
		);
		Grade g_morn = grade_morning();
		if (t < 0.30) {
			return mix_grade(g_night, g_violet, smoothstep(0.0, 0.30, t));
		}
		if (t < 0.64) {
			return mix_grade(g_violet, g_rose, smoothstep(0.30, 0.64, t));
		}
		return mix_grade(g_rose, g_morn, smoothstep(0.64, 1.0, t));
	}

	// Morning -> Afternoon: warm gold -> soft sunlit cream -> neutral daylight
	if (a == 0 && b == 1) {
		Grade g_morn = grade_morning();
		Grade g_cream = Grade(
			vec3(0.94, 0.93, 0.98),
			vec3(1.04, 1.01, 0.93),
			vec3(1.07, 1.04, 0.93),
			1.03, 1.02, 0.0, 0.015
		);
		Grade g_aft = grade_afternoon();
		if (t < 0.50) {
			return mix_grade(g_morn, g_cream, smoothstep(0.0, 0.50, t));
		}
		return mix_grade(g_cream, g_aft, smoothstep(0.50, 1.0, t));
	}

	// Afternoon -> Evening (Dusk): neutral -> brief amber-rose sunset -> lavender dusk -> cool blue
	if (a == 1 && b == 2) {
		Grade g_aft = grade_afternoon();
		Grade g_sunset = Grade(
			vec3(0.74, 0.62, 0.78),
			vec3(1.10, 0.88, 0.76),
			vec3(1.16, 0.92, 0.74),
			1.05, 0.96, 0.0, 0.025
		);
		Grade g_dusk = Grade(
			vec3(0.56, 0.58, 0.84),
			vec3(0.84, 0.82, 1.02),
			vec3(0.96, 0.90, 1.05),
			0.92, 0.87, 0.05, 0.0
		);
		Grade g_eve = grade_evening();
		if (t < 0.34) {
			return mix_grade(g_aft, g_sunset, smoothstep(0.0, 0.34, t));
		}
		if (t < 0.68) {
			return mix_grade(g_sunset, g_dusk, smoothstep(0.34, 0.68, t));
		}
		return mix_grade(g_dusk, g_eve, smoothstep(0.68, 1.0, t));
	}

	// Evening -> Night: cool twilight -> deep indigo -> moonlit night
	if (a == 2 && b == 3) {
		Grade g_eve = grade_evening();
		Grade g_indigo = Grade(
			vec3(0.38, 0.46, 0.74),
			vec3(0.64, 0.72, 0.95),
			vec3(0.83, 0.90, 1.05),
			0.78, 0.69, 0.22, 0.0
		);
		Grade g_night = grade_night();
		if (t < 0.48) {
			return mix_grade(g_eve, g_indigo, smoothstep(0.0, 0.48, t));
		}
		return mix_grade(g_indigo, g_night, smoothstep(0.48, 1.0, t));
	}

	return mix_grade(grade_for_phase(a), grade_for_phase(b), smoothstep(0.0, 1.0, t));
}

// Lightweight value noise for a soft painterly / stippled wave boundary.
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 apply_grade(vec3 col, Grade g) {
	// Purkinje shift in low light: warm reds/yellows dim slightly faster than blues/greens.
	if (g.purkinje > 0.001) {
		col *= mix(vec3(1.0), vec3(0.84, 0.94, 1.12), g.purkinje);
	}
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, g.sat);

	// Smooth 3-zone split-tone weights across luminance.
	float w_sh = smoothstep(0.55, 0.0, lum);
	float w_hi = smoothstep(0.45, 1.0, lum);
	float w_mid = max(0.0, 1.0 - w_sh - w_hi);
	vec3 tint = g.shadow_tint * w_sh + g.mid_tint * w_mid + g.high_tint * w_hi;

	col = col * tint * g.exposure;
	// Subtle warm sun-kiss lift on bright sandy paths/roofs during dawn & morning.
	if (g.warm_lift > 0.001) {
		col += vec3(1.0, 0.86, 0.56) * (w_hi * g.warm_lift);
	}
	return clamp(col, vec3(0.0), vec3(1.0));
}

void fragment() {
	vec4 src = texture(screen_texture, SCREEN_UV);
	Grade g;
	if (from_phase == to_phase || progress >= 0.999) {
		g = grade_for_phase(to_phase);
	} else if (progress <= 0.001) {
		g = grade_for_phase(from_phase);
	} else {
		vec2 local_px = UV * control_size;
		vec2 map_uv = (local_px - map_rect.xy) / max(map_rect.zw, vec2(1.0));
		// Elliptical arc sweeping from off-screen right across to the left corners.
		float dist = length((map_uv - sun_origin) * arc_squash);
		float d_norm = clamp((dist - 0.83) / 1.06, 0.0, 1.0);
		// Subtle painterly stipple on the advancing edge.
		float n_coarse = value_noise(map_uv * 14.0) - 0.5;
		float n_fine = value_noise(map_uv * 64.0) - 0.5;
		float grain = (n_coarse * 0.65 + n_fine * 0.35) * edge_grain;
		float bw = max(band_width, 0.05);
		float front = mix(-0.05, 1.0 + bw + 0.05, progress);
		float local_t = clamp((front - (d_norm + grain)) / bw, 0.0, 1.0);
		g = transition_grade(from_phase, to_phase, local_t);
	}
	COLOR = vec4(apply_grade(src.rgb, g), src.a);
}
