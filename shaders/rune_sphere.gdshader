shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform sampler2D rune_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv_scale : hint_range(1.0, 4.0, 0.1) = 4.0;

uniform vec3 rune_color : source_color = vec3(0.05, 0.8, 1.0);

uniform float emission_strength : hint_range(0.0, 20.0) = 20.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.35;

uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 scaled_uv = (UV - vec2(0.5)) * uv_scale + vec2(0.5);;
	
	if (scaled_uv.y < 0.0 || scaled_uv.y > 1.0) {
        discard;
    }

    float mask = texture(rune_texture, scaled_uv).a;

    // Smooth pulsing between 0 and 1.
    float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);

    // Adjust emission intensity.
    float intensity = emission_strength *
        mix(1.0 - pulse_amount, 1.0, pulse);

    ALBEDO = rune_color;
    ALPHA = mask * opacity;
    EMISSION = rune_color * intensity;
}