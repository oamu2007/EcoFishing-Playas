class_name CleanupProject
extends Resource

enum WorkKind { NONE = -1, SHORE_DEBRIS = 0, OFFSHORE_NET = 1, TIDE_POOL = 2 }

@export var title: String
@export var art: Texture2D
@export var work_kind: WorkKind = WorkKind.NONE
@export_range(1, 100) var cost: int = 12
@export_range(1, 70) var pollution_reduction: int = 30
