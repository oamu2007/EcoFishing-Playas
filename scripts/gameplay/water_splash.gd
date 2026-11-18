extends Node2D

# Salpicadura (partículas) + ondas (aros que crecen) cuando el anzuelo cae al agua.

const RIPPLE_DURATION: float = 0.9
const RIPPLE_MAX_RADIUS: float = 42.0
const RIPPLE_COUNT: int = 2
const RIPPLE_DELAY: float = 0.18
const CLEAN_COLOR: Color = Color(0.85, 0.97, 1.0)
const DIRTY_COLOR: Color = Color(0.55, 0.5, 0.33)

# Cada onda guarda su posición, su edad y su color
var _ripples: Array[Dictionary] = []


func play_at(world_position: Vector2, pollution: float) -> void:
	var color: Color = CLEAN_COLOR.lerp(DIRTY_COLOR, pollution)
	_spawn_droplets(world_position, color)
	for i: int in range(RIPPLE_COUNT):
		_ripples.append({
			"position": to_local(world_position),
			"age": -i * RIPPLE_DELAY,
			"color": color,
		})


func _spawn_droplets(world_position: Vector2, color: Color) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	add_child(particles)
	particles.global_position = world_position
	particles.one_shot = true
	particles.amount = 18
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.damping_min = 60.0
	particles.damping_max = 90.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	# Las gotas se van haciendo transparentes
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(color, 0.9))
	fade.set_color(1, Color(color, 0.0))
	particles.color_ramp = fade
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func _process(delta: float) -> void:
	# Recorremos al revés para poder borrar las ondas que ya terminaron
	for i: int in range(_ripples.size() - 1, -1, -1):
		_ripples[i]["age"] += delta
		if _ripples[i]["age"] >= RIPPLE_DURATION:
			_ripples.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for ripple: Dictionary in _ripples:
		var age: float = ripple["age"]
		if age < 0.0:
			continue
		var t: float = age / RIPPLE_DURATION
		var radius: float = lerpf(4.0, RIPPLE_MAX_RADIUS, t)  # el aro crece con LERP
		var color: Color = ripple["color"]
		color.a = 0.7 * (1.0 - t)  # y se desvanece
		draw_arc(ripple["position"], radius, 0.0, TAU, 32, color, 2.0, true)