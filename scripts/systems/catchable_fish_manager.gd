class_name CatchableFishManager
extends Node2D

signal fish_spawned(fish: CatchableFish)
signal fish_departed(fish: CatchableFish)

const FISH_SCENE: PackedScene = preload("res://scenes/gameplay/catchable_fish.tscn")

@export var species_catalog: Array[FishSpecies] = []
@export var spawn_seed: int = 202610
@export var spawns_enabled: bool = true
@export_range(1, 12) var maximum_active_fish: int = 3
@export_range(0.1, 60.0) var spawn_interval: float = 4.0
@export_range(1.0, 90.0) var fish_lifetime: float = 26.0
@export_range(0.01, 1.0) var pollution_threshold: float = 0.50
@export_range(0.0, 1.0) var threshold_spawn_chance: float = 0.24
@export_range(0.0, 1.0) var clean_spawn_chance: float = 0.85
@export_range(8.0, 60.0) var fish_catch_radius: float = 25.0
@export var starter_band: Vector2 = Vector2(88.0, 136.0)
@export_range(0.0, 0.9) var offshore_band_start: float = 0.5
@export_range(4.0, 100.0) var offshore_reach_clearance: float = 32.0
@export var shore_search_distance: float = 190.0
@export var swim_radius: Vector2 = Vector2(10.0, 22.0)
@export var swim_speed: Vector2 = Vector2(1.15, 1.60)
@export var minimum_spacing: float = 82.0

var fish: Array[CatchableFish] = []
var _pollution: PollutionSystem
var _rod: FishingRod
var _shore_start: Vector2
var _shore_end: Vector2
var _starter_range: float
var _clock: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func initialize(pollution: PollutionSystem, rod: FishingRod, shore_start: Vector2, shore_end: Vector2) -> void:
	if _rod != null:
		return
	_pollution = pollution
	_rod = rod
	_shore_start = shore_start
	_shore_end = shore_end
	_starter_range = rod.maximum_cast_range
	_rng.seed = spawn_seed


func spawn_chance(normalized_pollution: float) -> float:
	if normalized_pollution > pollution_threshold:
		return 0.0
	var recovery: float = 1.0 - clampf(normalized_pollution / pollution_threshold, 0.0, 1.0)
	return lerpf(threshold_spawn_chance, clean_spawn_chance, recovery)


func _physics_process(delta: float) -> void:
	if not spawns_enabled or _pollution == null:
		return
	_clock += delta
	if _clock < spawn_interval:
		return
	_clock = fmod(_clock, spawn_interval)
	if fish.size() >= maximum_active_fish:
		return
	var chance: float = spawn_chance(_pollution.normalized_pollution)
	if chance > 0.0 and _rng.randf() < chance:
		_spawn()


func _spawn() -> void:
	if _rod.maximum_cast_range > _starter_range and _has_nearshore_fish():
		if _spawn_in_band(_spawn_bounds(true)):
			return
	_spawn_in_band(_spawn_bounds())


func _has_nearshore_fish() -> bool:
	for visitor: CatchableFish in fish:
		if not visitor.hooked and visitor.swim_center.x < _shore_start.x + _starter_range:
			return true
	return false


func _spawn_in_band(bounds: Rect2) -> bool:
	if not bounds.has_area():
		return false
	for _attempt: int in range(12):
		var center: Vector2 = Vector2(_rng.randf_range(bounds.position.x, bounds.end.x), _rng.randf_range(bounds.position.y, bounds.end.y))
		if _route_is_clear(center):
			var species: FishSpecies = _roll_species()
			if species != null:
				_add_fish(center, species)
				return true
			return false
	return false


func _spawn_bounds(offshore: bool = false) -> Rect2:
	var water: Rect2 = _rod.water_bounds.grow(-fish_catch_radius - 4.0)
	var cast_reach: float = _starter_range
	var band: Vector2 = starter_band
	if offshore:
		cast_reach = _rod.maximum_cast_range
		band = Vector2(
			maxf(_starter_range + offshore_reach_clearance, lerpf(_starter_range, cast_reach, offshore_band_start)),
			cast_reach - offshore_reach_clearance
		)
	var x_min: float = maxf(water.position.x, _shore_start.x + maxf(band.x, _rod.minimum_cast_range))
	var x_max: float = minf(water.end.x, _shore_start.x + minf(band.y, cast_reach))
	var x_offset: float = x_max - _shore_start.x
	# Fit the entire route inside one cast from the nearest reachable shore point.
	var nearby_y: float = clampf(_rod.global_position.y, _shore_start.y, _shore_end.y)
	var reachable_y: float = sqrt(maxf(0.0, cast_reach * cast_reach - x_offset * x_offset))
	var half_height: float = minf(shore_search_distance, reachable_y)
	var y_min: float = maxf(water.position.y, maxf(_shore_start.y, nearby_y - half_height))
	var y_max: float = minf(water.end.y, minf(_shore_end.y, nearby_y + half_height))
	var minimum: Vector2 = Vector2(x_min, y_min) + swim_radius
	var maximum: Vector2 = Vector2(x_max, y_max) - swim_radius
	return Rect2(minimum, maximum - minimum)


func _route_is_clear(center: Vector2) -> bool:
	for active_fish: CatchableFish in fish:
		if not active_fish.hooked and active_fish.swim_center.distance_to(center) < minimum_spacing:
			return false
	return true


func _add_fish(center: Vector2, species: FishSpecies) -> void:
	var visitor: CatchableFish = FISH_SCENE.instantiate()
	visitor.species = species
	visitor.length_cm = _rng.randi_range(species.minimum_length_cm, species.maximum_length_cm)
	visitor.catch_radius = fish_catch_radius
	visitor.lifetime = fish_lifetime
	visitor.visit_ended.connect(_on_fish_visit_ended)
	visitor.landed.connect(_on_fish_landed)
	add_child(visitor)
	visitor.configure_visit(center, swim_radius, _rng.randf_range(0.0, TAU), _rng.randf_range(swim_speed.x, swim_speed.y))
	fish.append(visitor)
	fish_spawned.emit(visitor)


func _roll_species() -> FishSpecies:
	var choices: Array[FishSpecies] = []
	var weights: PackedFloat32Array = PackedFloat32Array()
	for species: FishSpecies in species_catalog:
		if species != null and species.spawn_weight > 0.0:
			choices.append(species)
			weights.append(species.spawn_weight)
	if choices.is_empty():
		return null
	return choices[_rng.rand_weighted(weights)]


func _on_fish_visit_ended(visitor: CatchableFish) -> void:
	fish.erase(visitor)
	fish_departed.emit(visitor)


func _on_fish_landed(target: FishingTarget) -> void:
	fish.erase(target as CatchableFish)
