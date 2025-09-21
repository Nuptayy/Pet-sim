// glitch_effect.gdshader
shader_type spatial;
render_mode blend_mix;

// Fonction pour générer un bruit simple.
float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Couleur de base du glitch.
	vec3 glitch_color = vec3(0.0, 1.0, 0.2); // Vert citron
	
	// L'opacité du calque va scintiller très rapidement.
	float intensity = random(UV + vec2(TIME * 10.0));
	
	ALBEDO = glitch_color;
	// L'alpha change constamment, créant un effet de bruit visuel.
	ALPHA = intensity * 0.5; // * 0.5 pour que l'effet ne soit pas trop opaque.
}