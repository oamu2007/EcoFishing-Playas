class_name OceanTrash
extends FishingTarget

signal entered_water

enum Kind { BOTTLE, CAN, BAG }

@export var kind: Kind = Kind.BOTTLE
@export_range(1, 30) var pollution_value: int = 5
@export var bob_amplitude: float = 2.5
@export var bob_phase: float = 0.0
@export_range(0.0, 20.0) var drift_speed: float = 6.0

var in_water: bool = true
var is_arriving: bool = false
var _stop: Vector2
var _arrival_speed: float
var _water_edge: float
var _arrival_drift_limits: Vector2
var _elapsed: float = 0.0
var _drift_center: float = 0.0
var _drift_amplitude: float = 0.0
var _drift_phase: float = 0.0

func _ready() -> void:
	super._ready()
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


func configure_arrival(entry_x: float, stop: Vector2, ingress_speed: float, water_edge: float, drift_limits: Vector2, speed: float, phase: float) -> void:
	_stop = stop
	_arrival_speed = ingress_speed
	_water_edge = water_edge
	_arrival_drift_limits = drift_limits
	drift_speed = speed
	_drift_phase = phase
	in_water = false
	is_arriving = true
	global_position = Vector2(entry_x, stop.y)


func retarget_arrival(stop_x: float) -> void:
	# An upgrade may put this piece inside the new band's reach already.
	_stop.x = minf(stop_x, global_position.x)


func drift_stop_position() -> Vector2:
	return _stop if is_arriving else global_position


func _physics_process(delta: float) -> void:
	if hooked:
		return
	if is_arriving:
		global_position.x = move_toward(global_position.x, _stop.x, _arrival_speed * delta)
		if not in_water and global_position.x <= _water_edge:
			in_water = true
			entered_water.emit()
		if global_position.x == _stop.x:
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


func can_hook() -> bool:
	return in_water and super.can_hook()


func inventory_art() -> Texture2D:
	match kind:
		Kind.CAN:
			return preload("res://assets/trader/can.svg")
		Kind.BAG:
			return preload("res://assets/trader/bag.svg")
	return preload("res://assets/trader/bottle.svg")
