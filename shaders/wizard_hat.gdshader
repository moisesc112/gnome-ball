shader_type spatial;

uniform sampler2D star_texture : source_color, repeat_enable;
uniform vec2 texture_scale = vec2(1.0, 2.0);
uniform vec2 texture_offset = vec2(0.5, 0.5);

varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 uv = world_position.xy * texture_scale + texture_offset;
    ALBEDO = texture(star_texture, uv).rgb;
    ROUGHNESS = 1.0;
}
