class_name FishSpecies
extends Resource

@export var title: String = "Fish"
@export_range(1, 100) var minimum_length_cm: int = 10
@export_range(1, 100) var maximum_length_cm: int = 22
@export_range(0.0, 100.0) var spawn_weight: float = 1.0
@export_range(0, 100) var rarity_bonus: int = 0
@export_range(1, 3) var timing_checks: int = 1
## Fraction of the sweep that accepts an input. Zero uses the rod's default.
@export_range(0.0, 0.6, 0.005) var timing_window: float = 0.0
@export_range(0.1, 5.0, 0.05) var gold_per_centimeter: float = 0.75
@export var art: Texture2D
