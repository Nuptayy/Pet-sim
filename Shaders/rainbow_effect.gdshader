// rainbow_effect.gdshader
shader_type spatial;

// On indique que ce shader va se mélanger avec ce qui est en dessous.
render_mode blend_mix;

void fragment() {
	// On génère notre onde de couleur arc-en-ciel.
	float speed = 1.0;
	float red   = sin(TIME * speed + 0.0) * 0.5 + 0.5;
	float green = sin(TIME * speed + 2.0) * 0.5 + 0.5;
	float blue  = sin(TIME * speed + 4.0) * 0.5 + 0.5;
	vec3 rainbow_color = vec3(red, green, blue);

	// ALBEDO est la couleur de notre calque.
	ALBEDO = rainbow_color;

	// ALPHA est l'opacité de notre calque.
	// 0.3 signifie qu'on voit 30% de la teinte dorée et 70% de la texture originale.
	ALPHA = 0.3;
}