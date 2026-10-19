extends Node2D

var shore_start: Vector2
var shore_end: Vector2

@onready var pollution: PollutionSystem = $PollutionSystem
@onready var trash_manager: TrashManager = $TrashManager
@onready var _ocean: Polygon2D = $Environment/Ocean
@onready var _rod: FishingRod = $Player/FishingRod
@onready var _player: CharacterBody2D = $Player
@onready var _water: WaterVisuals = $Environment/Water


func _ready() -> void:
	# Derive world-space fishing bounds from the authored rectangular ocean.
	var bounds: Rect2 = Rect2(_ocean.to_global(_ocean.polygon[0]), Vector2.ZERO)
	for point: Vector2 in _ocean.polygon:
		bounds = bounds.expand(_ocean.to_global(point))
	_rod.water_bounds = bounds
	# Account for the capsule, boundary thickness, and rod offset, rather than
	# assuming the fisherman can stand on the visible water edge.
	var body: Rect2 = _shape_bounds($Player/CollisionShape2D)
	var barrier: Rect2 = _shape_bounds($WorldBounds/OceanBarrier)
	var top: Rect2 = _shape_bounds($WorldBounds/Top)
	var bottom: Rect2 = _shape_bounds($WorldBounds/Bottom)
	var rod_offset: Vector2 = _rod.global_position - _player.global_position
	var shore_x: float = barrier.position.x - (body.end.x - _player.global_position.x) - 2.0 + rod_offset.x
	shore_start = Vector2(shore_x, top.end.y - (body.position.y - _player.global_position.y) + 2.0 + rod_offset.y)
	shore_end = Vector2(shore_x, bottom.position.y - (body.end.y - _player.global_position.y) - 2.0 + rod_offset.y)
	trash_manager.trash_collected.connect(_on_trash_collected)
	trash_manager.initialize(_rod, shore_start, shore_end)
	pollution.initialize(trash_manager.initial_pollution_values())
	_water.global_position = bounds.position
	_water.configure_size(bounds.size)
	_water.bind_pollution(pollution)


func _shape_bounds(collider: CollisionShape2D) -> Rect2:
	return collider.global_transform * collider.shape.get_rect()


func _on_trash_collected(item_id: int, _type_name: String) -> void:
	pollution.collect(item_id)
