class_name OceanTrash
extends Area2D

signal entered_water

enum Kind { BOTTLE, CAN, BAG }

@export var kind: Kind = Kind.BOTTLE
@export_range(1, 30) var pollution_value: int = 5
@export_range(8.0, 60.0) var catch_radius: float = 24.0
@export var bob_amplitude: float = 2.5
@export var bob_phase: float = 0.0
@export_range(0.0, 20.0) var drift_speed: float = 6.0

var hooked: bool = false
var collected: bool = false
var in_water: bool = true
var is_arriving: bool = false
var _entry_x: float
var _stop: Vector2
var _travel_time: float
var _arrival_elapsed: float
var _water_edge: float
var _arrival_drift_limits: Vector2
var _elapsed: float = 0.0
var _drift_center: float = 0.0
var _drift_amplitude: float = 0.0
var _drift_phase: float = 0.0

@onready var visual: Node2D = $Visual


func _ready() -> void:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = catch_radius
	$CollisionShape2D.shape = circle
	$Visual/Bottle.visible = kind == Kind.BOTTLE
	$Visual/Can.visible = kind == Kind.CAN
	$Visual/Bag.visible = kind == Kind.BAG


func _process(delta: float) -> void:
	if not hooked:
		_elapsed += delta
		visual.position.y = sin(_elapsed * 2.0 + bob_phase) * bob_amplitude


func configure_drift(limits: Vector2, speed: float, phase: float) -> void:
	drift_speed = speed
	_drift_phase = phase
	var cosine: float = cos(phase)
	# Preserve the spawn point and fit the entire orbit inside reachable water.
	var room_above: float = maxf(0.0, global_position.y - limits.x)
	var room_below: float = maxf(0.0, limits.y - global_position.y)
	_drift_amplitude = minf(80.0, minf(room_above / maxf(0.001, 1.0 + cosine), room_below / maxf(0.001, 1.0 - cosine)))
	_drift_center = global_position.y - _drift_amplitude * cosine


func configure_arrival(entry_x: float, stop: Vector2, travel_time: float, water_edge: float, drift_limits: Vector2, speed: float, phase: float) -> void:
	_entry_x = entry_x
	_stop = stop
	_travel_time = travel_time
	_water_edge = water_edge
	_arrival_drift_limits = drift_limits
	drift_speed = speed
	_drift_phase = phase
	in_water = false
	is_arriving = true
	global_position = Vector2(entry_x, stop.y)


func drift_stop_position() -> Vector2:
	return _stop if is_arriving else global_position


func _physics_process(delta: float) -> void:
	if hooked:
		return
	if is_arriving:
		_arrival_elapsed += delta
		var progress: float = minf(_arrival_elapsed / _travel_time, 1.0)
		global_position.x = lerpf(_entry_x, _stop.x, smoothstep(0.0, 1.0, progress))
		if not in_water and global_position.x <= _water_edge:
			in_water = true
			entered_water.emit()
		if progress >= 1.0:
			is_arriving = false
			configure_drift(_arrival_drift_limits, drift_speed, _drift_phase)
		return
	if _drift_amplitude < 0.01:
		return
	# Cosine turns with zero velocity at the boundaries; no reflection/teleport.
	_drift_phase = fposmod(_drift_phase + delta * drift_speed / _drift_amplitude, TAU)
	global_position.y = _drift_center + _drift_amplitude * cos(_drift_phase)


func display_name() -> String:
	match kind:
		Kind.BOTTLE:
			return "Plastic bottle"
		Kind.CAN:
			return "Can"
		Kind.BAG:
			return "Plastic bag"
	return "Trash"


func can_hook_at(water_position: Vector2) -> bool:
	return in_water and not hooked and not collected and global_position.distance_to(water_position) <= catch_radius


func attach_to(anchor: Node2D, offset: Vector2 = Vector2(0, 14)) -> bool:
	if not in_water or hooked or collected:
		return false
	hooked = true
	set_deferred("monitorable", false)
	reparent(anchor)
	position = offset
	visual.position = Vector2.ZERO
	return true


func finish_collection() -> bool:
	if not hooked or collected:
		return false
	collected = true
	hide()
	queue_free()
	return true
