shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D proxy_color_tex : source_color, filter_linear_mipmap;
uniform sampler2D main_depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform float outline_width : hint_range(0.0, 10.0) = 4.0;
uniform float global_glow : hint_range(0.0, 5.0) = 1.0;
uniform float depth_bias : hint_range(0.0, 1.0) = 0.2; 

const int SAMPLES = 16;

// FIXED: Godot 4 uses Vulkan, where Z is 0.0 to 1.0. 
float get_linear_depth(float depth, mat4 inv_proj) {
    vec4 ndc = vec4(0.0, 0.0, depth, 1.0); // No more depth * 2.0 - 1.0!
    vec4 view = inv_proj * ndc;
    return -view.z / view.w;
}

void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0); 
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 tex_pixel_size = 1.0 / VIEWPORT_SIZE * outline_width;
    
    float main_d_raw = texture(main_depth_tex, uv).r;
    float main_linear_at_uv = get_linear_depth(main_d_raw, INV_PROJECTION_MATRIX);

    vec3 blurred_color = vec3(0.0);
    float total_alpha = 0.0;

    for(int i = 0; i < SAMPLES; i++) {
        float angle = (float(i) / float(SAMPLES)) * 2.0 * PI;
        vec2 offset = vec2(cos(angle), sin(angle)) * tex_pixel_size;
        vec2 sample_uv = uv + offset;
        
        vec4 proxy_sample = texture(proxy_color_tex, sample_uv);
        float proxy_depth = proxy_sample.a * 1000.0; 
        
        if (proxy_depth > 0.0) {
            float proxy_main_d_raw = texture(main_depth_tex, sample_uv).r;
            float proxy_main_linear = get_linear_depth(proxy_main_d_raw, INV_PROJECTION_MATRIX);
            
            bool item_is_visible = proxy_main_linear > proxy_depth - depth_bias;
            bool halo_is_unblocked = main_linear_at_uv > proxy_depth - depth_bias;
            
            if (item_is_visible && halo_is_unblocked) {
                // FIXED: Divide by the alpha to restore the true vibrant color
                vec3 true_color = proxy_sample.rgb / max(proxy_sample.a, 0.00001);
                blurred_color += true_color;
                total_alpha += 1.0; 
            }
        }
    }

    if (total_alpha > 0.0) {
        blurred_color /= total_alpha; 
        float final_alpha = clamp((total_alpha / float(SAMPLES)) * global_glow, 0.0, 1.0);
        
        vec4 center_proxy = texture(proxy_color_tex, uv);
        float center_proxy_depth = center_proxy.a * 1000.0;
        
        if (center_proxy_depth > 0.0 && main_linear_at_uv > center_proxy_depth - depth_bias) {
            final_alpha = 0.0; 
        }
        
        ALBEDO = blurred_color;
        ALPHA = final_alpha;
    } else {
        discard;
    }
}