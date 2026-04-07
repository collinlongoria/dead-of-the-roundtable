shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D proxy_depth_tex : filter_nearest;
uniform sampler2D proxy_color_tex : filter_nearest;
uniform sampler2D main_depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform float outline_width : hint_range(0.0, 10.0) = 4.0;
uniform float global_glow : hint_range(0.0, 5.0) = 1.0;
uniform float depth_bias : hint_range(0.0, 5.0) = 0.1;
uniform float depth_range : hint_range(1.0, 200.0) = 50.0;

const int SAMPLES = 16;

float linearize(float depth, mat4 inv_proj, vec2 uv) {
    vec4 ndc = vec4(uv * 2.0 - 1.0, depth, 1.0);
    vec4 view = inv_proj * ndc;
    return -view.z / view.w;
}

float decode_proxy_depth(vec3 rgb) {
    return ((rgb.r * 255.0) + rgb.g) / 255.0 * depth_range;
}

void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 px = (1.0 / VIEWPORT_SIZE) * outline_width;

    float main_d_raw = texture(main_depth_tex, uv).r;
    float main_linear = linearize(main_d_raw, INV_PROJECTION_MATRIX, uv);

    vec4 center = texture(proxy_depth_tex, uv);
    if (center.b > 0.5) {
        float center_depth = decode_proxy_depth(center.rgb);
        if (main_linear >= center_depth - depth_bias) {
            discard;
        }
    }

    float hits = 0.0;
    vec3 accumulated_color = vec3(0.0);
    
    for (int i = 0; i < SAMPLES; i++) {
        float a = (float(i) / float(SAMPLES)) * 6.2831853;
        vec2 suv = uv + vec2(cos(a), sin(a)) * px;

        vec4 s = texture(proxy_depth_tex, suv);
        if (s.b < 0.5) continue;

        float proxy_depth = decode_proxy_depth(s.rgb);

        float s_main_raw = texture(main_depth_tex, suv).r;
        float s_main_linear = linearize(s_main_raw, INV_PROJECTION_MATRIX, suv);
        bool item_visible = s_main_linear >= proxy_depth - depth_bias;
        bool halo_unblocked = main_linear >= proxy_depth - depth_bias;

        if (item_visible && halo_unblocked) {
            hits += 1.0;
            accumulated_color += texture(proxy_color_tex, suv).rgb;
        }
    }

    if (hits <= 0.0) discard;

    float alpha = clamp((hits / float(SAMPLES)) * global_glow, 0.0, 1.0);
    ALBEDO = accumulated_color / hits;
    ALPHA = alpha;
}