extends CharacterBody2D

@export_range(50.0, 500.0, 10.0) var movement_speed: float = 220.0

var sack: Sack
var input_locked: bool = false

@onready var fishing_rod: FishingRod = $FishingRod


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
