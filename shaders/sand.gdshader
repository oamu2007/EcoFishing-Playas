shader_type canvas_item;

uniform vec2 area_size = vec2(840.0, 900.0);
uniform vec4 dark_sand : source_color = vec4(0.62, 0.48, 0.25, 1.0);
uniform vec4 light_sand : source_color = vec4(1.0, 0.93, 0.70, 1.0);
uniform float overlay_opacity : hint_range(0.0, 1.0) = 0.32;
uniform float dune_strength : hint_range(0.0, 1.0) = 0.6;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.35;

float hash21(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), u.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * area_size;
	// Lomas suaves: ruido de baja frecuencia
	float dunes = 0.6 * value_noise(p / 120.0) + 0.4 * value_noise(p / 45.0 + vec2(7.3, 2.1));
	// Marcas de viento: ondas alargadas deformadas por las lomas
	float wind = 0.5 + 0.5 * sin(dot(p, vec2(0.35, 0.94)) * 0.22 + dunes * 9.0);
	wind = smoothstep(0.7, 1.0, wind);
	// Granos: un valor al azar por cada cuadrito de 2x2 px
	float grain = hash21(floor(p / 2.0));
	float tone = 0.5 + (dunes - 0.5) * dune_strength + (wind - 0.3) * 0.12 + (grain - 0.5) * grain_strength;
	vec3 color = mix(dark_sand.rgb, light_sand.rgb, clamp(tone, 0.0, 1.0));
	COLOR = vec4(color, overlay_opacity);
}