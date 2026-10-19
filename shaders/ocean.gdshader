shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float pollution_level : hint_range(0.0, 1.0) = 1.0;
uniform vec4 clean_shallow : source_color = vec4(0.035, 0.65, 0.73, 1.0);
uniform vec4 clean_deep : source_color = vec4(0.025, 0.32, 0.53, 1.0);
uniform vec4 dirty_shallow : source_color = vec4(0.30, 0.36, 0.255, 1.0);
uniform vec4 dirty_deep : source_color = vec4(0.19, 0.275, 0.25, 1.0);
uniform vec4 sediment_color : source_color = vec4(0.36, 0.32, 0.21, 1.0);
uniform float wave_speed : hint_range(0.0, 2.0) = 0.35;
uniform float wave_strength : hint_range(0.0, 0.12) = 0.035;
uniform float murkiness : hint_range(0.0, 1.0) = 1.0;
uniform float foam_strength : hint_range(0.0, 1.0) = 0.42;
uniform vec2 water_size = vec2(760.0, 900.0);
// Used only by the separate render-check harness for equal-phase comparisons.
uniform bool use_time_override = false;
uniform float time_override = 0.0;

float hash21(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	// Cubic Hermite weights: continuous value and first derivative at cell edges.
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), u.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), u.x), u.y);
}

void fragment() {
	float time = (use_time_override ? time_override : TIME) * wave_speed;
	vec2 p = UV * water_size;
	vec2 flow = p / 135.0 + vec2(0.025, -0.017) * time;
	float cloud = 0.57 * value_noise(flow)
		+ 0.29 * value_noise(flow * 2.03 + vec2(17.4, 9.2))
		+ 0.14 * value_noise(flow * 4.07 + vec2(3.1, 28.7));
	float sediment = value_noise(flow * 2.8 + vec2(-time * 0.018, 11.0));
	float depth = smoothstep(0.0, 0.9, UV.x);
	float dirty = smoothstep(0.0, 1.0, clamp(pollution_level, 0.0, 1.0));
	vec3 clean_palette = mix(clean_shallow.rgb, clean_deep.rgb, depth);
	vec3 dirty_palette = mix(dirty_shallow.rgb, dirty_deep.rgb, depth);
	vec3 color = mix(clean_palette, dirty_palette, dirty);
	color += (cloud - 0.5) * mix(0.035, 0.085, dirty);
	color = mix(color, sediment_color.rgb,
		dirty * murkiness * (0.045 + 0.12 * smoothstep(0.3, 0.8, sediment)));

	// Two nonparallel, incommensurate travelling waves, organically phase-warped.
	float wave_a = sin(dot(p, vec2(0.85, 0.53)) * 0.038 - time * 0.9 + cloud * 0.7);
	float wave_b = sin(dot(p, vec2(-0.35, 0.94)) * 0.061 + time * 0.67 + cloud * 0.5);
	float ripple = 0.5 + 0.5 * (0.6 * wave_a + 0.4 * wave_b);
	float highlight = smoothstep(0.62, 0.98, ripple);
	color += vec3(0.62, 0.88, 0.84) * highlight * wave_strength;
	color += (wave_a + wave_b) * wave_strength * 0.15;

	// Alpha blending reveals the actual seabed, not a screen-color approximation.
	float clean_opacity = mix(0.56, 0.83, depth);
	float opacity = mix(clean_opacity, 0.985, dirty * murkiness);
	// Foam moves only inside the water rectangle; shoreline collision never moves.
	float edge = 10.0 + 3.0 * sin(p.y * 0.022 + time * 0.55)
		+ 2.0 * sin(p.y * 0.051 - time * 0.37);
	float foam_a = 1.0 - smoothstep(1.0, 4.5, abs(p.x - edge));
	float foam_b = 1.0 - smoothstep(0.7, 2.8, abs(p.x - edge - 18.0));
	float foam = (foam_a + 0.28 * foam_b) * foam_strength;
	vec3 foam_color = mix(vec3(0.80, 0.96, 0.92), vec3(0.70, 0.77, 0.62), dirty);
	color = mix(color, foam_color, foam);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), opacity);
}
