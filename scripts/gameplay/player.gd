extends CharacterBody2D

@export_range(50.0, 500.0, 10.0) var movement_speed: float = 220.0
@export var fishing_view_margin: float = 40.0

var sack: Sack
var input_locked: bool = false

@onready var fishing_rod: FishingRod = $FishingRod
@onready var _camera: Camera2D = $Camera2D
@onready var _minimum_camera_lead: float = _camera.position.x


func _process(_delta: float) -> void:
	# Keep the furthest shore-aligned cast and its target cue inside the view.
	var half_width: float = get_viewport_rect().size.x / (2.0 * _camera.zoom.x)
	var cast_lead: float = fishing_rod.position.x + fishing_rod.maximum_cast_range + fishing_view_margin - half_width
	_camera.position.x = maxf(_minimum_camera_lead, cast_lead)


func _physics_process(_delta: float) -> void:
	if input_locked or fishing_rod.is_active():
		velocity = Vector2.ZERO
		return
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	var load_multiplier: float = sack.movement_multiplier if sack != null else 1.0
	velocity = input_direction * movement_speed * load_multiplier
	move_and_slide()
