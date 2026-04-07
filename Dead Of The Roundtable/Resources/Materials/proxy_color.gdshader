shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 outline_color : source_color = vec3(0.2, 0.8, 0.2);

void fragment() {
    vec3 raw = outline_color;
    vec3 srgb_corrected = mix(
        pow((raw + 0.055) * (1.0 / 1.055), vec3(2.4)),
        raw * (1.0 / 12.92),
        lessThan(raw, vec3(0.04045))
    );
    ALBEDO = srgb_corrected;
    ALPHA = 1.0;
}
