shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

vec3 hsv_to_rgb(float h, float s, float v) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(vec3(h) + K.xyz) * 6.0 - K.www);
    return v * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), s);
}

void fragment() {
    float hue = fract(TIME * 0.3 + VERTEX.y * 0.3 + VERTEX.x * 0.1);
    vec3 rainbow = hsv_to_rgb(hue, 1.0, 1.0);
    ALBEDO = rainbow * (0.4 + 0.1 * sin(TIME * 5.0));
    ALPHA = 1.0;
}