class_name OceanTrash
extends Area2D

enum Kind { BOTTLE, CAN, BAG }

@export var kind: Kind = Kind.BOTTLE
@export_range(1, 100) var pollution_value: int = 10
@export_range(8.0, 60.0) var catch_radius: float = 24.0
@export var bob_amplitude: float = 2.5
@export var bob_phase: float = 0.0
@export_range(0.0, 20.0) var drift_speed: float = 6.0

var hooked: bool = false
var collected: bool = false
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


func _physics_process(delta: float) -> void:
	if hooked or _drift_amplitude < 0.01:
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
	return not hooked and not collected and global_position.distance_to(water_position) <= catch_radius


func attach_to(anchor: Node2D, offset: Vector2 = Vector2(0, 14)) -> bool:
	if hooked or collected:
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
