class_name CatchableFish
extends FishingTarget

signal visit_ended(fish: CatchableFish)

var species: FishSpecies
var length_cm: int = 0
var lifetime: float = 26.0
var swim_center: Vector2
var _swim_radius: Vector2
var _swim_phase: float
var _swim_speed: float
var _elapsed: float = 0.0

@onready var _silhouette: Node2D = $Visual/Silhouette
@onready var _sprite: Sprite2D = $Visual/Silhouette/Sprite
@onready var _ripple: Node2D = $Visual/Ripple


func _ready() -> void:
	super._ready()
	swim_center = global_position
	_sprite.texture = inventory_art()
	_silhouette.scale = Vector2.ONE * remap(clampf(length_cm, 10.0, 38.0), 10.0, 38.0, 0.85, 1.14)


func configure_visit(center: Vector2, radius: Vector2, phase: float, speed: float) -> void:
	swim_center = center
	_swim_radius = radius
	_swim_phase = phase
	_swim_speed = speed
	_update_swim()


func _physics_process(delta: float) -> void:
	if hooked or collected:
		_ripple.hide()
		return
	_elapsed += delta
	if _elapsed >= lifetime:
		escape()
		return
	_swim_phase = fposmod(_swim_phase + delta * _swim_speed, TAU)
	_update_swim()


func _update_swim() -> void:
	var offset: Vector2 = Vector2(cos(_swim_phase), sin(_swim_phase))
	global_position = swim_center + _swim_radius * offset
	_silhouette.rotation = Vector2(-_swim_radius.x * offset.y, _swim_radius.y * offset.x).angle()
	_ripple.modulate.a = 0.81 + 0.15 * sin(_elapsed * 4.4 + _swim_phase)


func display_name() -> String:
	return "%s (%d cm)" % [species.title, length_cm] if species != null else "Fish"


func sale_price() -> int:
	if species == null:
		return sale_value + length_cm
	return sale_value + roundi(length_cm * species.gold_per_centimeter) + species.rarity_bonus


func inventory_art() -> Texture2D:
	return species.art if species != null and species.art != null else preload("res://assets/fish/topsmelt.svg")


func escape() -> void:
	hide()
	set_physics_process(false)
	queue_free()
	visit_ended.emit(self)


func can_hook() -> bool:
	return _elapsed < lifetime and super.can_hook()
