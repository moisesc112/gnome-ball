
shader_type spatial;
render_mode depth_prepass_alpha, specular_schlick_ggx;

uniform float tile_count : hint_range(3.0, 30.0) = 10.0;
uniform float grout_width : hint_range(0.01, 0.15) = 0.045;
uniform float glass_opacity : hint_range(0.0, 1.0) = 0.55;
uniform float glow_strength : hint_range(0.0, 3.0) = 0.35;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.12;

uniform vec4 grout_color : source_color = vec4(0.035, 0.025, 0.06, 1.0);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
    return vec2(
        hash(p),
        hash(p + 37.7)
    );
}

void fragment() {
    vec2 uv = UV * tile_count;
    vec2 cell = floor(uv);
    vec2 local_uv = fract(uv);

    float nearest = 100.0;
    float second_nearest = 100.0;
    vec2 nearest_cell = vec2(0.0);
    vec2 nearest_point = vec2(0.0);

    // Find nearest and second-nearest Voronoi seeds.
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 seed_cell = cell + neighbor;
            vec2 seed = neighbor + mix(
                vec2(0.5),
                hash2(seed_cell),
                0.85
            );

            vec2 diff = seed - local_uv;
            float dist = dot(diff, diff);

            if (dist < nearest) {
                second_nearest = nearest;
                nearest = dist;
                nearest_cell = seed_cell;
                nearest_point = seed;
            } else if (dist < second_nearest) {
                second_nearest = dist;
            }
        }
    }

    // Approximate lead borders.
    float edge = sqrt(second_nearest) - sqrt(nearest);
    float glass_mask = smoothstep(
        grout_width,
        grout_width + 0.025,
        edge
    );

    // Jewel-tone palette.
    float h = hash(nearest_cell + 19.0);
    vec3 glass_color;

	if (h < 0.20) {
	    glass_color = vec3(0.42, 0.055, 0.075); // Deep crimson
	} else if (h < 0.40) {
	    glass_color = vec3(0.75, 0.18, 0.055);  // Burnt orange
	} else if (h < 0.60) {
	    glass_color = vec3(1.0, 0.58, 0.12);    // Molten gold
	} else if (h < 0.80) {
	    glass_color = vec3(0.82, 0.36, 0.075);  // Rich amber
	} else {
	    glass_color = vec3(0.30, 0.12, 0.27);   // Dusky plum
	}

    // Slight variation within each glass piece.
    float variation = 0.88 + 0.12 *
        sin(local_uv.x * 11.0 + local_uv.y * 8.0);

    glass_color *= variation;

    ALBEDO = mix(grout_color.rgb, glass_color, glass_mask);

    // Transparent glass, opaque lead.
    ALPHA = mix(1.0, glass_opacity, glass_mask);

    ROUGHNESS = mix(0.65, roughness_value, glass_mask);
    METALLIC = mix(0.55, 0.0, glass_mask);
    SPECULAR = 0.9;

    EMISSION = glass_color * glass_mask * glow_strength;
}
