# NumberFormat.gd
extends RefCounted

# --- Constantes ---
const SUFFIXES = [[1e18, "Qt"], [1e15, "Qd"], [1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"]]


# --- Formatage ---

# 🔹 Formate un grand nombre avec un suffixe (1.2K, 3.4M...) à partir d'un seuil.
static func format_compact(value: float, threshold: float = 1e6) -> String:
	if abs(value) < threshold:
		return str(int(value))
	var sign_text = "-" if value < 0.0 else ""
	return sign_text + _with_suffix(abs(value), 2)

# 🔹 Formate une chance en pourcentage, ou en "1 in X" pour les très petites valeurs.
static func format_chance(chance_percent: float) -> String:
	if chance_percent >= 1.0:
		return "%.1f%%" % chance_percent
	if chance_percent <= 0.0:
		return "1 in ∞"
	return "1 in %s" % _with_suffix(100.0 / chance_percent, 1)

# 🔹 Formate une durée en secondes sous la forme HH:MM:SS.
static func format_duration(seconds: int) -> String:
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60, seconds % 60]


# --- Méthodes Internes ---

# 🔹 Écrit un nombre positif avec le bon suffixe, sans jamais afficher "1000" d'une unité.
static func _with_suffix(value: float, decimals: int) -> String:
	var rounding_step = pow(10.0, -decimals)
	for suffix in SUFFIXES:
		var scaled = snappedf(value / suffix[0], rounding_step)
		if scaled >= 1.0:
			return ("%." + str(decimals) + "f%s") % [scaled, suffix[1]]
	return str(int(round(value)))
