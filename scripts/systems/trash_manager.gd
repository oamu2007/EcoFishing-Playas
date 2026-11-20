class_name TrashManager
extends Node2D

signal trash_arrived(item_id: int, pollution_points: int)
signal trash_spawned(item: OceanTrash)
signal trash_collected(item_id: int)

const TRASH_SCENE: PackedScene = preload("res://scenes/gameplay/trash.tscn")

@export_range(0, 100) var initial_item_count: int = 6
@export_range(0, 100) var maximum_active_items: int = 12
@export var spawn_seed: int = 2026
@export var arrivals_enabled: bool = true
@export_range(0.1, 60.0) var arrival_interval: float = 8.0
@export_range(5.0, 150.0) var arrival_speed: float = 44.0
@export var offscreen_margin: float = 100.0
@export var starter_band: Vector2 = Vector2(110.0, 205.0)
@export var arrival_inset: Vector2 = Vector2(20.0, 95.0)
@export var minimum_spacing: float = 72.0
@export_range(8.0, 60.0) var item_catch_radius: float = 24.0
@export_range(1, 30) var pollution_per_item: int = 5
@export_range(1, 30) var trash_sale_value: int = 3

var items: Array[OceanTrash] = []
var _rod: FishingRod
var _shore_x: float
var _drift_limits: Vector2
var _safe_water: Rect2
var _reach_x: float
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _arrival_offsets: Dictionary[OceanTrash, float] = {}
var _clock: float = 0.0
var _spawned_count: int = 0


func initialize(rod: FishingRod, shore_start: Vector2, shore_end: Vector2) -> void:
	if _rod != null:
		return
	_rod = rod
	_rng.seed = spawn_seed
	_shore_x = shore_start.x
	var margin: float = item_catch_radius + 8.0
	_safe_water = _rod.water_bounds.grow(-margin)
	_reach_x = _shore_x + _rod.maximum_cast_range
	var initial_band: Vector2 = Vector2(
		maxf(_minimum_stop_x(), _shore_x + starter_band.x),
		minf(_reach_x, minf(_safe_water.end.x, _shore_x + starter_band.y))
	)
	_drift_limits = Vector2(maxf(_safe_water.position.y, shore_start.y), minf(_safe_water.end.y, shore_end.y))
	for index: int in range(mini(initial_item_count, maximum_active_items)):
		_spawn(initial_band, false)


func _physics_process(delta: float) -> void:
	if _rod == null:
		return
	_update_arrival_stops()
	if not arrivals_enabled:
		return
	_clock += delta
	if _clock < arrival_interval:
		return
	_clock = fmod(_clock, arrival_interval)
	if _reach_x >= _minimum_stop_x():
		_spawn(Vector2(_arrival_stop_x(arrival_inset.y), _arrival_stop_x(arrival_inset.x)), true)


func _minimum_stop_x() -> float:
	return maxf(_safe_water.position.x, _shore_x + _rod.minimum_cast_range)


func _arrival_stop_x(inset: float) -> float:
	return clampf(_reach_x - maxf(0.0, inset), _minimum_stop_x(), _safe_water.end.x)


func _update_arrival_stops() -> void:
	var next_reach: float = _shore_x + _rod.maximum_cast_range
	var reach_changed: bool = next_reach != _reach_x
	_reach_x = next_reach
	for item: OceanTrash in _arrival_offsets.keys():
		if not item.is_arriving:
			_arrival_offsets.erase(item)
		elif reach_changed:
			item.retarget_arrival(_arrival_stop_x(_arrival_offsets[item]))


func _spawn(band: Vector2, incoming: bool) -> void:
	if items.size() >= maximum_active_items or band.x > band.y or _drift_limits.x >= _drift_limits.y:
		return
	for attempt: int in range(40):
		var point: Vector2 = Vector2(_rng.randf_range(band.x, band.y), _rng.randf_range(_drift_limits.x, _drift_limits.y))
		if _stop_is_clear(point):
			_add_item(point, incoming)
			return


func _stop_is_clear(point: Vector2) -> bool:
	var spacing: float = maxf(minimum_spacing, item_catch_radius * 2.0 + 4.0)
	for item: OceanTrash in items:
		if not item.hooked and point.distance_to(item.drift_stop_position()) < spacing:
			return false
	return true


func _add_item(point: Vector2, incoming: bool) -> void:
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
	var speed: float = _rng.randf_range(4.0, 8.0)
	if incoming:
		var entry_x: float = _rod.water_bounds.end.x + offscreen_margin
		var phase: float = PI if point.y < (_drift_limits.x + _drift_limits.y) * 0.5 else 0.0
		item.entered_water.connect(_on_item_arrived.bind(item))
		_arrival_offsets[item] = _reach_x - point.x
		item.configure_arrival(entry_x, point, arrival_speed, _rod.water_bounds.end.x, _drift_limits, speed, phase)
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
	_arrival_offsets.erase(item)
	trash_collected.emit(item.get_instance_id())
