shader_type spatial;
// FIXED: Added depth_draw_always
render_mode unshaded, cull_back, depth_draw_always;

uniform vec3 outline_color : source_color = vec3(0.2, 0.8, 0.2);

void fragment() {
    ALBEDO = outline_color;
    ALPHA = clamp(-VERTEX.z / 1000.0, 0.0, 1.0);
}