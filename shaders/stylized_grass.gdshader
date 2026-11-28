shader_type spatial;
render_mode cull_disabled, specular_disabled;

// ========================
// TEXTURES
// ========================

group_uniforms Textures;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap;
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.3;

// ========================
// COLOR PALETTE
// ========================

group_uniforms Color;

uniform vec4 shadow_color : source_color = vec4(0.141, 0.298, 0.196, 1.0);
uniform vec4 midtone_color : source_color = vec4(0.255, 0.435, 0.259, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.514, 0.671, 0.314, 1.0);

uniform float color_variation_strength : hint_range(0.0, 1.0) = 0.15;
uniform float color_variation_scale = 0.08;
uniform float root_darkening : hint_range(0.0, 1.0) = 0.15;

// ========================
// NORMALS
// ========================

group_uniforms Lighting;

uniform float normal_up_strength : hint_range(0.0, 1.0) = 1.0;

// ========================
// WIND
// ========================

group_uniforms Wind;

uniform float grass_height = 1.0;
uniform float wind_strength = 0.15;
uniform float wind_speed = 0.4;
uniform float wind_scale = 0.15;
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_color_strength : hint_range(0.0, 1.0) = 0.12;
uniform float bend_exponent : hint_range(1.0, 4.0) = 2.0;

// ========================
// VARYINGS
// ========================

varying vec3 world_position;
varying float height_factor;
varying float wind_factor;
varying vec3 grass_normal_view;

// ========================
// VERTEX
// ========================

group_uniforms Interaction;

global uniform vec3 ball_position;
uniform float ball_radius = 2.0;

uniform float interaction_radius = 1.8;
uniform float interaction_strength = 0.8;
uniform float interaction_vertical_range = 2.0;
uniform float flatten_strength = 0.3;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Use the instance origin so both crossed planes
    // receive the same wind displacement.
    vec3 instance_position = MODEL_MATRIX[3].xyz;

    // Keep roots stationary and move the tips.
    height_factor = clamp(
        VERTEX.y / max(grass_height, 0.001),
        0.0,
        1.0
    );

    // Override the original horizontal normals.
    NORMAL = normalize(mix(
        NORMAL,
        vec3(0.0, 1.0, 0.0),
        normal_up_strength
    ));

    grass_normal_view = normalize(
        MODELVIEW_NORMAL_MATRIX * NORMAL
    );

    // World-space traveling wind noise.
    vec2 direction = normalize(
        wind_direction + vec2(0.00001)
    );

    vec2 wind_uv = instance_position.xz * wind_scale
        - direction * TIME * wind_speed;

    wind_factor = textureLod(
        noise_texture,
        wind_uv,
        0.0
    ).r;

    // Stronger displacement toward the grass tips.
    float bend = pow(
	    smoothstep(0.1, 1.0, height_factor),
	    bend_exponent
	);

    float displacement = wind_factor
        * wind_strength
        * bend;

    vec3 world_offset = vec3(
        direction.x,
        0.0,
        direction.y
    ) * displacement;

	// ========================
	// BALL INTERACTION
	// ========================

	vec2 away = instance_position.xz - ball_position.xz;

	float distance_to_ball = length(away);

	float influence = 1.0 - smoothstep(
	    interaction_radius * 0.5,
	    interaction_radius,
	    distance_to_ball
	);
	
	// Prevent interaction when the ball is airborne.
	float ball_bottom = ball_position.y - ball_radius;

	float vertical_distance = abs(
	    instance_position.y - ball_bottom
	);

	influence *= 1.0 - smoothstep(
	    interaction_vertical_range * 0.5,
	    interaction_vertical_range,
	    vertical_distance
	);


	// Direction away from the ball.
	vec2 push_direction = away / max(distance_to_ball, 0.001);

	// Bend grass outward and downward.
	vec3 interaction_offset = vec3(
	    push_direction.x * interaction_strength,
	    -flatten_strength,
	    push_direction.y * interaction_strength
	);

	interaction_offset *= influence * bend;

	// Suppress wind near the ball.
	world_offset *= 1.0 - influence;

	// Apply combined displacement.
	VERTEX += inverse(mat3(MODEL_MATRIX))
	    * (world_offset + interaction_offset);
	
}

// ========================
// FRAGMENT
// ========================

void fragment() {
    vec4 tex = texture(grass_texture, UV);

    // Convert the original texture to grayscale.
    float grayscale = dot(
        tex.rgb,
        vec3(0.299, 0.587, 0.114)
    );

    // Permanent patches of lighter and darker grass.
    float color_noise = texture(
        noise_texture,
        world_position.xz * color_variation_scale
    ).r;

    grayscale += (color_noise - 0.5)
        * color_variation_strength;

    // Traveling highlights corresponding to wind.
    grayscale += (wind_factor - 0.5)
        * wind_color_strength
        * height_factor;

    grayscale = clamp(grayscale, 0.0, 1.0);

    // Map grayscale to a three-color palette.
    vec3 grass_color;

    if (grayscale < 0.5) {
        grass_color = mix(
            shadow_color.rgb,
            midtone_color.rgb,
            grayscale * 2.0
        );
    } else {
        grass_color = mix(
            midtone_color.rgb,
            highlight_color.rgb,
            (grayscale - 0.5) * 2.0
        );
    }

    // Slightly darken the grass near the ground.
    grass_color *= mix(
        1.0 - root_darkening,
        1.0,
        height_factor
    );

    ALBEDO = grass_color;

    // Maintain consistent normals on both sides.
    NORMAL = normalize(grass_normal_view);

    ALPHA = tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;

    ROUGHNESS = 1.0;
    METALLIC = 0.0;
    SPECULAR = 0.0;
}