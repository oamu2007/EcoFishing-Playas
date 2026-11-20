class_name FishingTarget
extends Area2D

signal landed(target: FishingTarget)

@export_range(8.0, 60.0) var catch_radius: float = 24.0
@export_range(0, 100) var sale_value: int = 4

var hooked: bool = false
var collected: bool = false

@onready var visual: Node2D = $Visual
@onready var _collider: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = catch_radius
	_collider.shape = circle


func display_name() -> String:
	return name


func sale_price() -> int:
	return sale_value


func inventory_art() -> Texture2D:
	return null


func can_hook() -> bool:
	return not hooked and not collected and not is_queued_for_deletion()


func can_hook_at(water_position: Vector2) -> bool:
	return can_hook() and global_position.distance_squared_to(water_position) <= catch_radius * catch_radius


func attach_to(anchor: Node2D, offset: Vector2) -> bool:
	if not can_hook():
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
	landed.emit(self)
	queue_free()
	return true
