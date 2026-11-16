// golden_effect.gdshader
// Effet dore – unshaded pour etre independant de l'eclairage de la scene.
// Simule un reflet metallique dore par animation UV sans PBR.
shader_type spatial;
render_mode blend_mix, unshaded;

uniform float shimmer_speed  : hint_range(0.5, 8.0)  = 3.0;
uniform float shimmer_scale  : hint_range(1.0, 24.0) = 9.0;
uniform float overlay_opacity: hint_range(0.0, 1.0)  = 0.62;

void fragment() {
	// --- Palette ---
	vec3 gold_dark   = vec3(0.62, 0.40, 0.00);
	vec3 gold_mid    = vec3(1.00, 0.78, 0.00);
	vec3 gold_bright = vec3(1.00, 0.97, 0.55);

	// --- Bande de shimmer principale (axe V) ---
	float s1 = sin(UV.y * shimmer_scale + TIME * shimmer_speed);
	s1 = pow(max(s1, 0.0), 3.0);

	// --- Bande croisee (axe U, plus lente) ---
	float s2 = sin(UV.x * shimmer_scale * 0.6 - TIME * shimmer_speed * 0.5);
	s2 = pow(max(s2, 0.0), 5.0) * 0.45;

	float shimmer = clamp(s1 + s2, 0.0, 1.0);

	// --- Couleur : du dore sombre au reflet blanc-or ---
	vec3 color = mix(gold_dark, gold_mid, 0.75);
	color = mix(color, gold_bright, shimmer);

	ALBEDO = color;

	// Legere pulsation de l'opacite sur les reflets pour les faire "flasher"
	ALPHA = clamp(overlay_opacity + shimmer * 0.22, 0.0, 1.0);
}
