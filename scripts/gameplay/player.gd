extends CharacterBody2D

@export_range(50.0, 500.0, 10.0) var movement_speed: float = 220.0


func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	velocity = input_direction * movement_speed
	move_and_slide()
