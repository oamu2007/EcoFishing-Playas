extends Node

const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const HudScript = preload("res://scripts/ui/hud.gd")

@onready var _world: LevelScript = $World
@onready var _hud: HudScript = $HUD


func _ready() -> void:
	_hud.bind_cleanup(_world.pollution, _world.trash_manager)
