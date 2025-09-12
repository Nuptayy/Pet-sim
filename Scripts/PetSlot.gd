# PetSlot.gd
extends Button

# 🔹 Configure ce slot avec les données d'un pet.
func setup(pet_instance: Dictionary):
	# Pour l'instant, on affiche juste le nom du pet.
	self.text = pet_instance["base_name"]
