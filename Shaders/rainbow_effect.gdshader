// Indique que c'est un shader pour les objets 3D et qu'on va modifier les matériaux spatiaux.
shader_type spatial;

// Cette fonction s'exécute pour chaque pixel visible de l'objet.
void fragment() {
  // TIME est une variable intégrée qui contient le temps de jeu en secondes.
  // On le multiplie pour accélérer le changement de couleur.
  float time_fast = TIME * 2.0;

  // On utilise la fonction cosinus pour créer une onde douce qui va de -1 à 1.
  // On décale la phase pour chaque couleur (R, G, B) pour qu'elles ne changent pas en même temps.
  float red   = cos(time_fast + 0.0) * 0.5 + 0.5; // * 0.5 + 0.5 pour passer de [-1, 1] à [0, 1]
  float green = cos(time_fast + 2.0) * 0.5 + 0.5; // 2.0 est le décalage de phase pour le vert
  float blue  = cos(time_fast + 4.0) * 0.5 + 0.5; // 4.0 est le décalage de phase pour le bleu

  // ALBEDO est la couleur de base de l'objet. On lui assigne notre nouvelle couleur arc-en-ciel.
  ALBEDO = vec3(red, green, blue);
}