
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms Parent_Transform;
uniform mat4 parent_inverse_matrix = mat4(1.0);

group_uniforms Base_Metal;
uniform vec4 metal_color : source_color = vec4(0.25, 0.27, 0.3, 1.0);
uniform vec4 rust_color : source_color = vec4(0.35, 0.18, 0.1, 1.0);
uniform float metal_roughness : hint_range(0.0, 1.0) = 0.35;
uniform float metal_metallic : hint_range(0.0, 1.0) = 0.95;

group_uniforms Dirt_System;
uniform vec4 dirt_color : source_color = vec4(0.15, 0.11, 0.07, 1.0);
uniform float dirt_roughness : hint_range(0.0, 1.0) = 0.95;
uniform float dirt_coverage : hint_range(0.0, 2.0) = 0.8;
uniform float dirt_cavity_influence : hint_range(0.0, 1.0) = 0.5;

group_uniforms Triplanar_and_Macro;
uniform vec3 uv_scale = vec3(0.1);
uniform float uv_blend_sharpness : hint_range(1.0, 16.0) = 4.0;

uniform float macro_noise_scale : hint_range(0.001, 0.5) = 0.02;
uniform float macro_noise_influence : hint_range(0.0, 1.0) = 0.6;

group_uniforms Textures;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_macro_noise : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale : hint_range(-4.0, 4.0) = 1.0;

varying vec3 v_triplanar_pos;
varying vec3 v_power_normal;
varying vec3 v_world_normal;

void vertex() {
    vec3 world_normal = MODEL_NORMAL_MATRIX * NORMAL;
    vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);

    v_world_normal = world_normal;

    v_triplanar_pos = (parent_inverse_matrix * world_pos).xyz;
    vec3 parent_normal = (parent_inverse_matrix * vec4(world_normal, 0.0)).xyz;

    v_power_normal = pow(abs(parent_normal), vec3(uv_blend_sharpness));
    v_power_normal /= dot(v_power_normal, vec3(1.0));
}

void fragment() {
    vec3 scaled_pos = v_triplanar_pos * uv_scale;

    vec3 macro_pos = v_triplanar_pos * macro_noise_scale;


    vec4 macro_n_z = texture(texture_macro_noise, macro_pos.xy);
    vec4 macro_n_y = texture(texture_macro_noise, macro_pos.xz);
    vec4 macro_n_x = texture(texture_macro_noise, macro_pos.zy);

    float macro_noise = (macro_n_x * v_power_normal.x + macro_n_y * v_power_normal.y + macro_n_z * v_power_normal.z).r - 0.5;


    vec4 alb_z = texture(texture_albedo, scaled_pos.xy);
    vec4 alb_y = texture(texture_albedo, scaled_pos.xz);
    vec4 alb_x = texture(texture_albedo, scaled_pos.zy);
    vec4 albedo_tex = alb_x * v_power_normal.x + alb_y * v_power_normal.y + alb_z * v_power_normal.z;


    vec3 n_z = texture(texture_normal, scaled_pos.xy).rgb * 2.0 - 1.0;
    vec3 n_y = texture(texture_normal, scaled_pos.xz).rgb * 2.0 - 1.0;
    vec3 n_x = texture(texture_normal, scaled_pos.zy).rgb * 2.0 - 1.0;

    n_z.xy *= normal_scale;
    n_y.xy *= normal_scale;
    n_x.xy *= normal_scale;

    vec3 axis_sign = sign(v_world_normal);

    vec3 world_n_z = vec3(n_z.x * axis_sign.z, n_z.y, n_z.z * axis_sign.z);
    vec3 world_n_y = vec3(n_y.x, n_y.z * axis_sign.y, -n_y.y * axis_sign.y);
    vec3 world_n_x = vec3(n_x.z * axis_sign.x, n_x.y, n_x.x * axis_sign.x);

    vec3 unpacked_normal = normalize(world_n_x * v_power_normal.x + world_n_y * v_power_normal.y + world_n_z * v_power_normal.z);


    float cavity_mask = 1.0 - smoothstep(0.3, 0.8, unpacked_normal.z);


    float rust_val = (1.0 - albedo_tex.a) + (cavity_mask * 0.4) + (macro_noise * macro_noise_influence * 2.0);
    float rust_mask = smoothstep(0.35, 0.65, rust_val);

    vec3 base_metal = mix(metal_color.rgb, rust_color.rgb, rust_mask);
    vec3 final_albedo = base_metal * albedo_tex.rgb;


    float y_up = clamp(v_world_normal.y, 0.0, 1.0);

    float dirt_factor = (y_up * 0.4) + (cavity_mask * dirt_cavity_influence) + (macro_noise * macro_noise_influence);
    float dirt_mask = smoothstep(1.0 - dirt_coverage, 1.3 - dirt_coverage, dirt_factor);


    ALBEDO = mix(final_albedo, dirt_color.rgb * albedo_tex.rgb, dirt_mask);


    float roughness_var = macro_noise * macro_noise_influence * 0.25;
    float current_roughness = clamp(mix(metal_roughness, 0.85, rust_mask) + roughness_var, 0.0, 1.0);
    ROUGHNESS = mix(current_roughness, dirt_roughness, dirt_mask);

    float current_metallic = mix(metal_metallic, 0.05, rust_mask);
    METALLIC = mix(current_metallic, 0.0, dirt_mask);

    AO = mix(1.0, 0.5, rust_mask * 0.5 + dirt_mask * 0.5);

    NORMAL = (VIEW_MATRIX * vec4(unpacked_normal, 0.0)).xyz;
}
