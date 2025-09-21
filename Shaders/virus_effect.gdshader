// virus_effect.gdshader
shader_type spatial;
render_mode blend_mix;

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 virus_color = vec3(1.0, 0.1, 0.2); // Rouge
	
	// L'opacité scintille comme le glitch.
	float noise_intensity = random(UV + vec2(TIME * 8.0)) * 0.4;
	
	// On ajoute un effet de "scanline" qui bouge verticalement.
	float scanline = step(0.9, sin(UV.y * 20.0 - TIME * 5.0)) * 0.3;
	
	ALBEDO = virus_color;
	// L'opacité finale est la somme du bruit et des scanlines.
	ALPHA = noise_intensity + scanline;
}