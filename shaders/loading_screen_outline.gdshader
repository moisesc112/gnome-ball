shader_type canvas_item;

uniform vec4 silhouette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float outline_width : hint_range(0.0, 5.0) = 2.0;
uniform float beard_threshold : hint_range(0.0, 1.0) = 0.7;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    vec2 pixel = TEXTURE_PIXEL_SIZE * outline_width;
    float alpha = tex.a;

    // Find neighboring opaque pixels for the outline
    float neighbors = 0.0;

    neighbors = max(neighbors, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
    neighbors = max(neighbors, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
    neighbors = max(neighbors, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
    neighbors = max(neighbors, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);

    // Detect bright parts of the original texture
    float brightness = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    float beard_mask = step(beard_threshold, brightness);

    // Black body, white bright areas
    vec3 body_color = mix(
        silhouette_color.rgb,
        vec3(1.0),
        beard_mask
    );

    // White outline outside the silhouette
    float outline = max(neighbors - alpha, 0.0);

    vec3 final_color = mix(
        body_color,
        outline_color.rgb,
        outline
    );

    COLOR = vec4(final_color, max(alpha, outline));
}