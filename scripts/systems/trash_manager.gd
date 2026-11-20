class_name TrashManager
extends Node2D

signal trash_arrived(item_id: int, pollution_points: int)
signal trash_spawned(item: OceanTrash)
signal trash_collected(item_id: int)

const TRASH_SCENE: PackedScene = preload("res://scenes/gameplay/trash.tscn")

@export_range(0, 100) var initial_item_count: int = 6
@export_range(0, 100) var maximum_active_items: int = 12
@export_range(1, 100) var starter_slots: int = 8
@export_range(1, 10) var offshore_every: int = 3
@export var spawn_seed: int = 2026
@export var arrivals_enabled: bool = true
@export_range(0.1, 60.0) var arrival_interval: float = 8.0
@export_range(0.1, 20.0) var arrival_travel_time: float = 9.0
@export var offscreen_margin: float = 100.0
@export var starter_band: Vector2 = Vector2(110.0, 205.0)
@export var offshore_band: Vector2 = Vector2(310.0, 545.0)
@export var minimum_spacing: float = 72.0
@export_range(8.0, 60.0) var item_catch_radius: float = 24.0
@export_range(1, 30) var pollution_per_item: int = 5
@export_range(1, 30) var trash_sale_value: int = 3

var items: Array[OceanTrash] = []
var _rod: FishingRod
var _shore_x: float
var _drift_limits: Vector2
var _near_stops: Vector2
var _far_stops: Vector2
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _starter_items: Array[OceanTrash] = []
var _clock: float = 0.0
var _arrival_turn: int = 0
var _spawned_count: int = 0


func initialize(rod: FishingRod, shore_start: Vector2, shore_end: Vector2) -> void:
	if _rod != null:
		return
	_rod = rod
	_rng.seed = spawn_seed
	_shore_x = shore_start.x
	var margin: float = item_catch_radius + 8.0
	var water: Rect2 = _rod.water_bounds.grow(-margin)
	_near_stops = Vector2(
		maxf(water.position.x, _shore_x + maxf(starter_band.x, _rod.minimum_cast_range)),
		minf(water.end.x, _shore_x + minf(starter_band.y, _rod.maximum_cast_range - margin))
	)
	_far_stops = Vector2(
		maxf(water.position.x, _shore_x + maxf(offshore_band.x, _rod.maximum_cast_range + margin)),
		minf(water.end.x, _shore_x + offshore_band.y)
	)
	_drift_limits = Vector2(maxf(water.position.y, shore_start.y), minf(water.end.y, shore_end.y))
	for index: int in range(mini(initial_item_count, _starter_limit())):
		_spawn(true, false)


func _physics_process(delta: float) -> void:
	if not arrivals_enabled or _rod == null:
		return
	_clock += delta
	if _clock < arrival_interval:
		return
	_clock = fmod(_clock, arrival_interval)
	_arrival_turn += 1
	var offshore_turn: bool = _arrival_turn % offshore_every == 0
	if offshore_turn:
		if not _spawn(false, true):
			_spawn(true, true)
	elif not _spawn(true, true):
		_spawn(false, true)


func _starter_limit() -> int:
	return mini(starter_slots, maximum_active_items)


func _spawn(starter: bool, incoming: bool) -> bool:
	var limit: int = _starter_limit() if starter else maximum_active_items - _starter_limit()
	var count: int = _starter_items.size() if starter else items.size() - _starter_items.size()
	var band: Vector2 = _near_stops if starter else _far_stops
	if count >= limit or band.x > band.y or _drift_limits.x >= _drift_limits.y:
		return false
	for attempt: int in range(40):
		var point: Vector2 = Vector2(_rng.randf_range(band.x, band.y), _rng.randf_range(_drift_limits.x, _drift_limits.y))
		if _stop_is_clear(point):
			_add_item(point, starter, incoming)
			return true
	return false


func _stop_is_clear(point: Vector2) -> bool:
	var spacing: float = maxf(minimum_spacing, item_catch_radius * 2.0 + 4.0)
	for item: OceanTrash in items:
		if not item.hooked and point.distance_to(item.drift_stop_position()) < spacing:
			return false
	return true


func _add_item(point: Vector2, starter: bool, incoming: bool) -> void:
	var item: OceanTrash = TRASH_SCENE.instantiate()
	item.kind = (_spawned_count % OceanTrash.Kind.size()) as OceanTrash.Kind
	item.pollution_value = pollution_per_item
	item.sale_value = trash_sale_value
	item.landed.connect(_on_item_landed)
	item.catch_radius = item_catch_radius
	item.bob_phase = _rng.randf_range(0.0, TAU)
	_spawned_count += 1
	add_child(item)
	items.append(item)
	if starter:
		_starter_items.append(item)
	var speed: float = _rng.randf_range(4.0, 8.0)
	if incoming:
		var entry_x: float = _rod.water_bounds.end.x + offscreen_margin
		var phase: float = PI if point.y < (_drift_limits.x + _drift_limits.y) * 0.5 else 0.0
		item.entered_water.connect(_on_item_arrived.bind(item))
		item.configure_arrival(entry_x, point, arrival_travel_time, _rod.water_bounds.end.x, _drift_limits, speed, phase)
	else:
		item.global_position = point
		item.configure_drift(_drift_limits, speed, _rng.randf_range(0.0, TAU))
		_on_item_arrived(item)
	trash_spawned.emit(item)


func _on_item_arrived(item: OceanTrash) -> void:
	trash_arrived.emit(item.get_instance_id(), item.pollution_value)


func _on_item_landed(target: FishingTarget) -> void:
	var item: OceanTrash = target as OceanTrash
	items.erase(item)
	_starter_items.erase(item)
	trash_collected.emit(item.get_instance_id())
