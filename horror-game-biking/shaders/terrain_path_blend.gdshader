shader_type spatial;

uniform vec4 grass_color : source_color = vec4(0.09, 0.14, 0.08, 1.0);
uniform vec4 path_color : source_color = vec4(0.24, 0.17, 0.11, 1.0);
uniform vec4 edge_color : source_color = vec4(0.15, 0.11, 0.07, 1.0);

uniform float roughness : hint_range(0.0, 1.0) = 0.94;

uniform float path_width : hint_range(0.5, 10.0) = 2.4;
uniform float feather_amount : hint_range(0.1, 3.0) = 1.2;

uniform float noise_scale : hint_range(0.1, 20.0) = 4.0;
uniform float noise_strength : hint_range(0.0, 2.0) = 0.8;

/*
    Jede vec4 beschreibt ein Straßen-Segment:

    x = Start X
    y = Start Z
    z = Ende X
    w = Ende Z
*/
const int MAX_ROAD_SEGMENTS = 1024;

uniform vec4 road_segments[MAX_ROAD_SEGMENTS];
uniform int road_segment_count = 0;

varying vec3 world_pos;


float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}


float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(
            hash(i + vec2(0.0, 0.0)),
            hash(i + vec2(1.0, 0.0)),
            u.x
        ),
        mix(
            hash(i + vec2(0.0, 1.0)),
            hash(i + vec2(1.0, 1.0)),
            u.x
        ),
        u.y
    );
}


float distance_to_segment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;

    float ab_len_sq = dot(ab, ab);

    if (ab_len_sq <= 0.00001) {
        return distance(p, a);
    }

    float t = clamp(
        dot(p - a, ab) / ab_len_sq,
        0.0,
        1.0
    );

    vec2 closest = a + ab * t;

    return distance(p, closest);
}


void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
    vec2 position = world_pos.xz;

    float nearest_distance = 100000.0;

    for (int i = 0; i < MAX_ROAD_SEGMENTS; i++) {
        if (i >= road_segment_count) {
            break;
        }

        vec4 segment = road_segments[i];

        vec2 a = segment.xy;
        vec2 b = segment.zw;

        float d = distance_to_segment(position, a, b);

        nearest_distance = min(nearest_distance, d);
    }


    /*
        Organische Kante.
        Das Rauschen wird nur leicht auf die Distanz angewendet,
        damit die Straße nicht künstlich perfekt aussieht.
    */
    vec2 noise_uv = position * noise_scale * 0.1;

    float n = (value_noise(noise_uv) - 0.5) * noise_strength;

    float dist_with_noise = nearest_distance + n;


    /*
        Hauptweg
    */
    float path_mask = 1.0 - smoothstep(
        path_width - feather_amount,
        path_width + feather_amount,
        dist_with_noise
    );


    /*
        Dunkler Erdsaum an der Kante
    */
    float edge_mask =
        smoothstep(
            path_width + feather_amount * 1.5,
            path_width - feather_amount * 0.5,
            dist_with_noise
        )
        *
        (
            1.0 -
            smoothstep(
                path_width - feather_amount * 0.8,
                path_width - feather_amount * 1.8,
                dist_with_noise
            )
        );


    vec3 final_color = grass_color.rgb;

    final_color = mix(
        final_color,
        path_color.rgb,
        path_mask
    );

    final_color = mix(
        final_color,
        edge_color.rgb,
        edge_mask * 0.6
    );

    ALBEDO = final_color;
    ROUGHNESS = roughness;
}