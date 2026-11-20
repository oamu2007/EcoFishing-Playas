class_name RodUpgrade
extends Resource

@export var title: String
@export var art: Texture2D
@export_range(1, 100) var cost: int = 12
@export var cast_range: float = 390.0
@export_range(0.1, 3.0) var cast_time: float = 0.76
@export_range(0.1, 3.0) var retrieval_time: float = 0.57
@export_range(1, 10) var trash_limit: int = 2
