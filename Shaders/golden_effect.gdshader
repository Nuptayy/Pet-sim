// golden_effect.gdshader
shader_type spatial;

// On indique que ce shader va se mélanger avec ce qui est en dessous.
render_mode blend_mix;

// On définit la couleur OR directement dans le code.
const vec3 GOLD_COLOR = vec3(1.0, 0.84, 0.0);

void fragment() {
	// ALBEDO est la couleur de notre calque.
	ALBEDO = GOLD_COLOR;

	// ALPHA est l'opacité de notre calque.
	// 0.3 signifie qu'on voit 30% de la teinte dorée et 70% de la texture originale.
	ALPHA = 0.3;
}