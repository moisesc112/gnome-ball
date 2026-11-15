shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec3 glass_color : source_color = vec3(0.25, 0.35, 0.8);
uniform vec3 glow_color : source_color = vec3(0.45, 0.3, 1.0);

uniform float center_opacity : hint_range(0.0, 1.0) = 0.015;
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.35;

uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;
uniform float emission_strength : hint_range(0.0, 10.0) = 1.5;

void fragment() {
    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);

    ALBEDO = glass_color;
    ALPHA = center_opacity + fresnel * edge_opacity;
    EMISSION = glow_color * fresnel * emission_strength;
}