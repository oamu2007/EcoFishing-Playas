extends Node2D

# Huellas en la arena: aparecen al caminar y se desvanecen con el tiempo.

const STEP_DISTANCE: float = 26.0
const FOOT_OFFSET: float = 6.0
const LIFETIME: float = 8.0
const MAX_PRINTS: int = 80
const PRINT_COLOR: Color = Color(0.55, 0.45, 0.28)
const FOOT_SHAPE: Array[Vector2] = [
	Vector2(-5, 0), Vector2(-3, -2.5), Vector2(3, -2.5),
	Vector2(5, 0), Vector2(3, 2.5), Vector2(-3, 2.5),
]

var _player: CharacterBody2D
var _last_position: Vector2
var _distance: float = 0.0
var _left_foot: bool = true
var _prints: Array[Dictionary] = []


func configure(player: CharacterBody2D) -> void:
	_player = player
	_last_position = player.global_position


func _process(delta: float) -> void:
	if is_instance_valid(_player):
		var moved: Vector2 = _player.global_position - _last_position
		_last_position = _player.global_position
		_distance += moved.length()
		if _distance >= STEP_DISTANCE:
			_distance = 0.0
			_add_print(moved.normalized())
	# Envejecemos las huellas (al revés para poder borrar las viejas)
	for i: int in range(_prints.size() - 1, -1, -1):
		_prints[i]["age"] += delta
		if _prints[i]["age"] >= LIFETIME:
			_prints.remove_at(i)
	queue_redraw()


func _add_print(direction: Vector2) -> void:
	var side: float = -1.0 if _left_foot else 1.0
	_left_foot = not _left_foot
	# Perpendicular a la dirección: rotamos 90 grados
	var sideways: Vector2 = direction.rotated(PI / 2.0) * FOOT_OFFSET * side
	var feet: Vector2 = to_local(_player.global_position + Vector2(0, 14))
	_prints.append({
		"position": feet + sideways,
		"angle": direction.angle(),
		"age": 0.0,
	})
	if _prints.size() > MAX_PRINTS:
		_prints.remove_at(0)


func _draw() -> void:
	var shape: PackedVector2Array = PackedVector2Array(FOOT_SHAPE)
	for footprint: Dictionary in _prints:
		var age: float = footprint["age"]
		var color: Color = PRINT_COLOR
		color.a = 0.45 * (1.0 - age / LIFETIME)
		var print_position: Vector2 = footprint["position"]
		var print_angle: float = footprint["angle"]
		draw_set_transform(print_position, print_angle, Vector2.ONE)
		draw_colored_polygon(shape, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)