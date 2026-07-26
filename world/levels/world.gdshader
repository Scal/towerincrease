// res://shaders/desert_sand_compat.gdshader
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

group_uniforms Base_Colors;
uniform vec4 base_sand_color : source_color = vec4(0.82, 0.61, 0.35, 1.0);
uniform vec4 dune_crest_color : source_color = vec4(0.93, 0.76, 0.48, 1.0);
uniform vec4 shadow_sand_color : source_color = vec4(0.65, 0.44, 0.22, 1.0);

group_uniforms Noise_Settings;
uniform float dune_scale : hint_range(0.001, 0.1) = 0.02;
uniform float ripple_scale : hint_range(0.1, 20.0) = 4.0;
uniform float grain_scale : hint_range(10.0, 500.0) = 150.0;

group_uniforms Surface;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float ripple_bump : hint_range(0.0, 1.0) = 0.25;

// Hash function for Compatibility (lightweight 2D noise)
float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.25));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

// Fast 2D Value Noise
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // Smoothstep interpolation

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 2-Octave FBM for Dunes
float fbm_dunes(vec2 p) {
	float val = 0.0;
	val += value_noise(p) * 0.6;
	val += value_noise(p * 2.03) * 0.4;
	return val;
}

void fragment() {
	// World position to prevent mapping issues on procedural meshes
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 pos_xz = world_pos.xz;

	// 1. Large Dunes Noise
	float dune = fbm_dunes(pos_xz * dune_scale);

	// 2. Fine Ripples (directional sine + noise distortion)
	float ripple_distortion = value_noise(pos_xz * 0.5) * 0.5;
	float ripple_wave = sin((pos_xz.x + pos_xz.y * 0.5 + ripple_distortion) * ripple_scale);
	float ripple_mask = smoothstep(-0.2, 0.8, ripple_wave);

	// 3. Micro Grain / Sand Noise
	float grain = hash21(floor(pos_xz * grain_scale));

	// Color Blending
	vec3 col = mix(base_sand_color.rgb, dune_crest_color.rgb, dune);
	col = mix(col, shadow_sand_color.rgb, (1.0 - ripple_mask) * 0.2);
	col += (grain - 0.5) * 0.05; // Light sand texture variations

	ALBEDO = col;
	ROUGHNESS = clamp(roughness + (grain * 0.1), 0.0, 1.0);
	SPECULAR = 0.1; // Sand is mostly diffuse

	// Procedural Normal perturbation for ripples (without expensive derivates)
	vec2 ripple_grad = vec2(
		cos((pos_xz.x + pos_xz.y * 0.5) * ripple_scale),
		cos((pos_xz.x + pos_xz.y * 0.5) * ripple_scale) * 0.5
	) * ripple_bump;

	NORMAL_MAP = vec3(ripple_grad * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = ripple_bump;
}