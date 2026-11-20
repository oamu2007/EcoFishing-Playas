class_name FishSpecies
extends Resource

@export var title: String = "Fish"
@export_range(1, 100) var minimum_length_cm: int = 10
@export_range(1, 100) var maximum_length_cm: int = 22
@export_range(0.0, 100.0) var spawn_weight: float = 1.0
@export_range(0, 100) var rarity_bonus: int = 0
@export_range(0.1, 5.0, 0.05) var gold_per_centimeter: float = 0.75
@export var art: Texture2D
