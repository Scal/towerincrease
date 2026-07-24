shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float impact_azimuth_deg = 0.0; 
uniform float impact_elevation_deg = 90.0; 

uniform float damage_progress : hint_range(0.0, 1.0) = 0.5;
uniform float progress_wobble : hint_range(0.0, 0.4) = 0.15;

uniform float smoothness_min : hint_range(0.001, 0.2) = 0.01;
uniform float smoothness_max : hint_range(0.05, 0.8) = 0.4;

uniform float cell_density : hint_range(5.0, 40.0) = 16.0;
uniform float center_density_mult : hint_range(1.0, 5.0) = 2.5; 
uniform float density_falloff : hint_range(0.2, 2.0) = 0.6; 

uniform float radial_stretch : hint_range(0.5, 3.0) = 1.3;
uniform float crack_thickness : hint_range(0.001, 0.08) = 0.012;
uniform float wobble_strength : hint_range(0.0, 0.5) = 0.12;

uniform float chromatic_aberration : hint_range(0.0, 0.5) = 0.15;
uniform float glitch_quantization : hint_range(0.0, 100.0) = 40.0;
uniform float scanline_tearing : hint_range(0.0, 0.1) = 0.03;
uniform float digital_grid_glow : hint_range(0.0, 5.0) = 2.0;

uniform vec4 crack_color : source_color = vec4(0.8, 0.9, 1.0, 0.8);
uniform float dead_pixel_density : hint_range(0.0, 0.5) = 0.15;
uniform float static_noise_strength : hint_range(0.0, 0.3) = 0.08;

uniform vec4 pulse_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float pulse_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float pulse_frequency : hint_range(1.0, 50.0) = 20.0;

uniform float facet_tilt : hint_range(0.0, 3.0) = 1.2;
uniform float normal_bump : hint_range(0.0, 10.0) = 5.0;
uniform float impact_seed : hint_range(0.0, 100.0) = 0.0;

varying vec3 v_local_pos;

void vertex() {
    v_local_pos = normalize(VERTEX);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float snoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * snoise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

vec4 cellular_cracks(vec2 polar_uv) {
    vec2 i_st = floor(polar_uv);
    vec2 f_st = fract(polar_uv);

    float m_dist1 = 8.0;
    float m_dist2 = 8.0;
    vec2 cell_center_diff = vec2(0.0);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash22(i_st + neighbor + vec2(impact_seed));
            point = 0.5 + 0.4 * sin(point * TAU);
            
            vec2 diff = neighbor + point - f_st;
            float d = length(diff);

            if (d < m_dist1) {
                m_dist2 = m_dist1;
                m_dist1 = d;
                cell_center_diff = diff;
            } else if (d < m_dist2) {
                m_dist2 = d;
            }
        }
    }

    return vec4(m_dist2 - m_dist1, m_dist1, cell_center_diff);
}

void fragment() {
    float az_rad = radians(impact_azimuth_deg);
    float el_rad = radians(impact_elevation_deg);
    float cos_el = cos(el_rad);
    vec3 impact_dir = vec3(cos_el * sin(az_rad), sin(el_rad), cos_el * cos(az_rad));

    vec3 p = normalize(v_local_pos);
    float dot_imp = clamp(dot(p, impact_dir), -1.0, 1.0);
    float r = acos(dot_imp);

    vec3 up = abs(impact_dir.y) > 0.99 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(up, impact_dir));
    vec3 forward = cross(impact_dir, right);

    vec3 local_p = vec3(dot(p, right), dot(p, forward), dot(p, impact_dir));
    float angle = atan(local_p.y, local_p.x);
    if (angle < 0.0) angle += TAU;

    float dynamic_smoothness = mix(smoothness_min, smoothness_max, damage_progress);
    float front_noise = (fbm(vec2(angle * 3.0, r * 2.0) + impact_seed) - 0.5) * progress_wobble;
    float growth_radius = damage_progress * 2.5; 
    
    float mask_edge = growth_radius + front_noise;
    float radial_mask = smoothstep(mask_edge + dynamic_smoothness, mask_edge - dynamic_smoothness, r);

    float density_factor = pow(r + 0.001, density_falloff) * center_density_mult;
    vec2 warp_uv = vec2(angle * 2.0, r * 4.0) + vec2(impact_seed);
    float n1 = snoise(warp_uv) - 0.5;
    float n2 = snoise(warp_uv + vec2(17.3, 31.7)) - 0.5;

    vec2 polar_uv = vec2(
        ((angle + n1 * wobble_strength) / TAU) * cell_density * radial_stretch,
        (density_factor + n2 * wobble_strength * 0.5) * cell_density
    );

    vec4 cell = cellular_cracks(polar_uv);
    float crack_dist = cell.x;
    vec2 dir_to_center = cell.zw;
    vec2 safe_dir = normalize(dir_to_center + vec2(1e-5));

    float crack_mask = (1.0 - smoothstep(0.0, crack_thickness, crack_dist)) * radial_mask;
    float center_crush = smoothstep(growth_radius * 0.2, 0.0, r) * 
                        (1.0 - smoothstep(0.0, crack_thickness * 2.5, crack_dist)) * radial_mask;
    float final_cracks = clamp(max(crack_mask, center_crush), 0.0, 1.0) * radial_mask;

    vec2 facet_grad = safe_dir * facet_tilt;
    vec2 edge_grad = safe_dir * (1.0 - smoothstep(0.0, crack_thickness * 2.0, crack_dist));
    vec2 combined_grad = mix(facet_grad, edge_grad * normal_bump, final_cracks);
    
    vec3 bump_normal = normalize(vec3(-combined_grad * radial_mask, 1.0));
    NORMAL_MAP = bump_normal * 0.5 + 0.5;

    vec2 screen_edge_dist = min(SCREEN_UV, vec2(1.0) - SCREEN_UV);
    float edge_fade = clamp(min(screen_edge_dist.x, screen_edge_dist.y) * 15.0, 0.0, 1.0);

    float line_noise = hash21(vec2(floor(SCREEN_UV.y * 120.0), floor(TIME * 10.0 + impact_seed)));
    float tear_offset = (line_noise - 0.5) * scanline_tearing * final_cracks;

    vec2 base_disp = bump_normal.xy * radial_mask * edge_fade;
    base_disp.x += tear_offset;

    if (glitch_quantization > 0.0) {
        base_disp = floor(base_disp * glitch_quantization) / glitch_quantization;
    }

    vec2 ca_vec = safe_dir * chromatic_aberration * radial_mask * edge_fade;
    float static_grain = (hash21(SCREEN_UV * 500.0 + TIME) - 0.5) * static_noise_strength * final_cracks;

    vec2 base_uv = SCREEN_UV + base_disp + static_grain;
    vec2 ca_offset = ca_vec * 1.5;

    vec2 uv_r = clamp(base_uv + ca_offset, vec2(0.001), vec2(0.999));
    vec2 uv_g = clamp(base_uv,             vec2(0.001), vec2(0.999));
    vec2 uv_b = clamp(base_uv - ca_offset, vec2(0.001), vec2(0.999));

    float r_chan = texture(screen_texture, uv_r).r;
    float g_chan = texture(screen_texture, uv_g).g;
    float b_chan = texture(screen_texture, uv_b).b;

    float stripe_x = fract(SCREEN_UV.x * 600.0);
    vec3 subpixel_mask = vec3(
        smoothstep(0.0, 0.33, stripe_x) - smoothstep(0.33, 0.66, stripe_x),
        smoothstep(0.33, 0.66, stripe_x) - smoothstep(0.66, 1.0, stripe_x),
        smoothstep(0.66, 1.0, stripe_x)
    ) * 1.5 + 0.5;

    vec2 pixel_grid_uv = floor(SCREEN_UV * 250.0);
    float dead_rand = hash21(pixel_grid_uv + impact_seed);
    vec3 stuck_color = vec3(
        step(0.7, hash21(pixel_grid_uv + 1.0)),
        step(0.7, hash21(pixel_grid_uv + 2.0)),
        step(0.7, hash21(pixel_grid_uv + 3.0))
    );
    float is_dead = step(1.0 - dead_pixel_density, dead_rand) * final_cracks;

    vec3 glitch_screen_color = vec3(r_chan, g_chan, b_chan);
    glitch_screen_color = mix(glitch_screen_color, glitch_screen_color * subpixel_mask, final_cracks * 0.7);
    glitch_screen_color = mix(glitch_screen_color, stuck_color, is_dead);

    float pulse_wave = sin(r * pulse_frequency - TIME * pulse_speed) * 0.5 + 0.5;
    vec3 pulse_glow = pulse_color.rgb * pulse_wave * final_cracks * pulse_intensity;

    vec3 final_crack_tint = mix(crack_color.rgb, glitch_screen_color * digital_grid_glow, 0.5);
    vec3 digital_edges = (final_crack_tint + pulse_glow) * final_cracks;

    ALBEDO = crack_color.rgb;
    
    float refract_mask = smoothstep(0.0001, 0.02, length(base_disp) + length(ca_vec));
    EMISSION = mix(glitch_screen_color, digital_edges, final_cracks * crack_color.a) * refract_mask;

    ROUGHNESS = mix(0.1, 0.8, final_cracks);
    SPECULAR = mix(0.5, 0.1, final_cracks);
    ALPHA = max(radial_mask * 0.9, refract_mask);
}