class_name OceanTrash
extends Area2D

enum Kind { BOTTLE, CAN, BAG }

@export var kind: Kind = Kind.BOTTLE
@export_range(1, 100) var pollution_value: int = 10
@export_range(8.0, 60.0) var catch_radius: float = 24.0
@export var bob_amplitude: float = 2.5
@export var bob_phase: float = 0.0

var hooked: bool = false
var collected: bool = false
var _elapsed: float = 0.0

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


func attach_to(anchor: Node2D) -> bool:
	if hooked or collected:
		return false
	hooked = true
	set_deferred("monitorable", false)
	reparent(anchor)
	position = Vector2(0, 14)
	visual.position = Vector2.ZERO
	return true


func finish_collection() -> bool:
	if not hooked or collected:
		return false
	collected = true
	hide()
	queue_free()
	return true
