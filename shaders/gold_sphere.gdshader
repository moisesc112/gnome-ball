
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform sampler2D gold_texture : source_color, filter_linear_mipmap, repeat_enable;

uniform vec3 gold_color : source_color = vec3(1.0, 0.55, 0.15);

uniform float emission_strength : hint_range(0.0, 20.0) = 5.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

uniform float horizontal_scale = 1.0;
uniform float vertical_scale = 4.0;

void fragment() {
    vec2 uv = vec2(
        UV.x * horizontal_scale,
        (UV.y - 0.5) * vertical_scale + 0.5
    );

    if (uv.y < 0.0 || uv.y > 1.0) {
       discard;
    }

    float mask = texture(gold_texture, uv).a;

    ALBEDO = gold_color;
    ALPHA = mask * opacity;
    EMISSION = gold_color * emission_strength;
}