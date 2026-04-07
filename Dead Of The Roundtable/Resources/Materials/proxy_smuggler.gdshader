shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 outline_color : source_color = vec3(0.2, 0.8, 0.2);
uniform float depth_range : hint_range(1.0, 200.0) = 50.0;

varying float view_depth;

void vertex() {
    view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
    float d = clamp(view_depth / depth_range, 0.0, 1.0);
    float scaled = d * 255.0;
    float r = floor(scaled) / 255.0;
    float g = fract(scaled);
    
    // Pre-cancel Godot's sRGB encoding on write
    vec3 raw = vec3(r, g, 1.0);
    vec3 srgb_corrected = mix(
        pow((raw + 0.055) * (1.0 / 1.055), vec3(2.4)),
        raw * (1.0 / 12.92),
        lessThan(raw, vec3(0.04045))
    );
    
    ALBEDO = srgb_corrected;
    ALPHA = 1.0;
}