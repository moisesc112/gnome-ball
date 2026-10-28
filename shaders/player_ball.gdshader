
shader_type spatial;

uniform vec4 color_1 : source_color = vec4(0.1, 0.4, 1.0, 1.0);
uniform vec4 color_2 : source_color = vec4(1.0, 0.2, 0.1, 1.0);

uniform float opacity : hint_range(0.0, 1.0) = 0.5;

varying vec3 local_pos;

void vertex() {
    local_pos = VERTEX;
}

void fragment() {
    if (local_pos.x + local_pos.y + local_pos.z > 0.0) {
    ALBEDO = color_1.rgb;
} else {
    ALBEDO = color_2.rgb;
}

    ALPHA = opacity;
}