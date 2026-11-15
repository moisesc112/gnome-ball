shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform sampler2D gold_texture : source_color, repeat_disable;

uniform vec3 gold_color : source_color = vec3(1.0, 0.65, 0.2);

uniform float metallic : hint_range(0.0, 1.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.25;

uniform float emission_strength : hint_range(0.0, 20.0) = 3.0;
uniform float pulse_speed = 1.5;
uniform float pulse_amount = 0.15;

uniform float opacity = 1.0;
uniform float band_scale = 4.0;

void fragment() {
    vec2 uv = UV;
    uv.y = (uv.y - 0.5) * band_scale + 0.5;

    float mask = texture(gold_texture, uv).a;

    float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);

    float intensity = emission_strength *
        mix(1.0 - pulse_amount, 1.0, pulse);

    ALBEDO = gold_color;
    METALLIC = metallic;
    ROUGHNESS = roughness;

    ALPHA = mask * opacity;
    EMISSION = gold_color * intensity * mask;
}