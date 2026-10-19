class_name TrashManager
extends Node2D

signal trash_hooked(type_name: String)
signal trash_collected(item_id: int, type_name: String)

const TRASH_SCENE: PackedScene = preload("res://scenes/gameplay/trash.tscn")

@export_range(0, 100) var initial_item_count: int = 24
@export_range(0, 100) var maximum_active_items: int = 24
@export var spawn_seed: int = 2026
@export var minimum_spacing: float = 72.0
@export var shoreline_clearance: float = 70.0
@export_range(8.0, 60.0) var item_catch_radius: float = 24.0

var items: Array[OceanTrash] = []
var _rod: FishingRod
var _caught: Array[OceanTrash] = []
var _initialized: bool = false


func initialize(rod: FishingRod, shore_start: Vector2, shore_end: Vector2) -> void:
	if _initialized:
		return
	_initialized = true
	_rod = rod
	_rod.hook_landed.connect(_on_hook_landed)
	_rod.target_detected.connect(_on_target_detected)
	_rod.retrieval_completed.connect(_on_retrieval_completed)
	_rod.retrieval_advanced.connect(_on_retrieval_advanced)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = spawn_seed
	var margin: float = item_catch_radius + 8.0
	var left: float = _rod.water_bounds.position.x + maxf(shoreline_clearance, margin)
	var right: float = minf(_rod.water_bounds.end.x - margin, shore_start.x + _rod.maximum_cast_range - margin)
	var top: float = maxf(_rod.water_bounds.position.y + margin, shore_start.y)
	var bottom: float = minf(_rod.water_bounds.end.y - margin, shore_end.y)
	if right <= left or bottom <= top:
		push_warning("No reachable trash spawn region; starting an empty cleanup session.")
		return
	var required: int = mini(initial_item_count, maximum_active_items)
	for attempt: int in range(required * 200):
		if items.size() >= required:
			break
		var point: Vector2 = Vector2(rng.randf_range(left, right), rng.randf_range(top, bottom))
		var origin: Vector2 = Vector2(shore_start.x, clampf(point.y, shore_start.y, shore_end.y))
		if not _rod.invalid_target_reason_from(origin, point).is_empty():
			continue
		var separated: bool = true
		for other: OceanTrash in items:
			if point.distance_to(other.global_position) < maxf(minimum_spacing, item_catch_radius + other.catch_radius + 4.0):
				separated = false
				break
		if not separated:
			continue
		var item: OceanTrash = TRASH_SCENE.instantiate()
		item.kind = (items.size() % 3) as OceanTrash.Kind
		item.pollution_value = [10, 15, 20][items.size() % 3]
		item.catch_radius = item_catch_radius
		item.bob_phase = rng.randf_range(0.0, TAU)
		add_child(item)
		item.global_position = point
		item.configure_drift(Vector2(top, bottom), rng.randf_range(4.0, 8.0), rng.randf_range(0.0, TAU))
		items.append(item)
	if items.size() < required:
		push_warning("Spawn region fits %d of %d requested items; pollution uses the actual batch." % [items.size(), required])


func initial_pollution_values() -> Dictionary[int, int]:
	var values: Dictionary[int, int] = {}
	for item: OceanTrash in items:
		values[item.get_instance_id()] = item.pollution_value
	return values


func _on_hook_landed(point: Vector2) -> void:
	if _rod.state != FishingRod.State.WAITING or not _caught.is_empty():
		return
	# Resolve exact landing geometry synchronously; physics overlap caches can lag a frame.
	var nearest: OceanTrash
	var nearest_distance: float = INF
	for item: OceanTrash in items:
		if item.can_hook_at(point):
			var distance: float = item.global_position.distance_squared_to(point)
			if distance < nearest_distance:
				nearest = item
				nearest_distance = distance
	if nearest != null:
		_attach_item(nearest)


func _attach_item(item: OceanTrash) -> void:
	var columns: Array[float] = [0.0, -22.0, 22.0, -44.0, 44.0]
	var index: int = _caught.size()
	var offset: Vector2 = Vector2(columns[index % 5], 14.0 + floorf(index / 5.0) * 24.0)
	if item.attach_to(_rod.get_hook_attachment(), offset):
		_caught.append(item)
		trash_hooked.emit(item.display_name())


func _on_retrieval_advanced(from: Vector2, to: Vector2, hook_radius: float) -> void:
	if _rod.state != FishingRod.State.RETRIEVING:
		return
	for item: OceanTrash in items:
		if item.hooked or item.collected:
			continue
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(item.global_position, from, to)
		# Physical hook disk must intersect the item's catch disk, not just the line.
		var radius: float = item.catch_radius + hook_radius
		if item.global_position.distance_squared_to(nearest) <= radius * radius:
			_attach_item(item)


func _on_target_detected(_target: Area2D) -> void:
	if _rod.state == FishingRod.State.WAITING:
		# Reparenting a caught Area2D must happen outside physics signal flushing.
		_on_hook_landed.call_deferred(_rod.get_hook_water_position())


func _on_retrieval_completed(_water_position: Vector2) -> void:
	if _rod.state != FishingRod.State.IDLE or _caught.is_empty():
		return
	var returned: Array[OceanTrash] = _caught.duplicate()
	_caught.clear()
	for item: OceanTrash in returned:
		if not is_instance_valid(item) or not item.finish_collection():
			continue
		items.erase(item)
		trash_collected.emit(item.get_instance_id(), item.display_name())
