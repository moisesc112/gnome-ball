
shader_type spatial;
render_mode specular_disabled;

group_uniforms Colors;

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 shadow_color : source_color = vec4(0.35, 0.40, 0.60, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.85, 0.65, 1.0);

group_uniforms Toon_Shading;

uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float highlight_threshold : hint_range(0.0, 1.0) = 0.75;
uniform float transition_softness : hint_range(0.001, 0.2) = 0.04;

uniform float shadow_strength : hint_range(0.0, 1.0) = 0.55;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.25;

group_uniforms Rim_Lighting;

uniform vec4 rim_color : source_color = vec4(1.0, 0.65, 0.30, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.25;
uniform float rim_power : hint_range(1.0, 10.0) = 4.0;

group_uniforms;

void fragment() {
    ALBEDO = base_color.rgb;
    ROUGHNESS = 1.0;

    // Camera-facing rim lighting.
    float rim = 1.0 - max(
        dot(normalize(NORMAL), normalize(VIEW)),
        0.0
    );

    rim = pow(rim, rim_power);

    // Add a subtle golden edge highlight.
    EMISSION = rim_color.rgb * rim * rim_strength;
}

void light() {
    // Angle between surface and light.
    float ndotl = max(dot(NORMAL, LIGHT), 0.0);

    // Soft transitions between three lighting bands.
    float mid_band = smoothstep(
        shadow_threshold - transition_softness,
        shadow_threshold + transition_softness,
        ndotl
    );

    float highlight_band = smoothstep(
        highlight_threshold - transition_softness,
        highlight_threshold + transition_softness,
        ndotl
    );

    // Shadow color is a tint relative to the base material.
    vec3 shadow_tint = mix(
        vec3(1.0),
        shadow_color.rgb,
        shadow_strength
    );

    // Highlight color is also a tint.
    vec3 highlight_tint = mix(
        vec3(1.0),
        highlight_color.rgb,
        highlight_strength
    );

    // Three-band color response.
    vec3 toon_tint = mix(
        shadow_tint,
        vec3(1.0),
        mid_band
    );

    toon_tint = mix(
        toon_tint,
        highlight_tint,
        highlight_band
    );

    // Discrete brightness levels.
    float brightness = mix(0.4, 0.75, mid_band);
    brightness = mix(brightness, 1.0, highlight_band);

    DIFFUSE_LIGHT += toon_tint
        * brightness
        * LIGHT_COLOR
        * ATTENUATION;
}
