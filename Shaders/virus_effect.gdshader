shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    float t = floor(TIME * 8.0);
    float row = floor(UV.y * 20.0);
    float band = rand(vec2(t * 0.1, row));
    float active = step(0.85, band);
    float r = step(0.7, rand(vec2(t, row + 0.1))) * active;
    float g = step(0.75, rand(vec2(t + 0.3, row))) * active * 0.5;
    float b = step(0.6, rand(vec2(t + 0.7, row))) * active;
    ALBEDO = vec3(0.0, 0.6, 0.5) * 0.2 + vec3(r, g, b) * 0.7;
    ALPHA = 1.0;
}