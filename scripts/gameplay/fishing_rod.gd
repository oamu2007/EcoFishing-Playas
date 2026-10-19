class_name FishingRod
extends Node2D

signal state_changed(new_state: State)
signal hook_landed(water_position: Vector2)
signal retrieval_completed(water_position: Vector2)
signal retrieval_advanced(previous_position: Vector2, current_position: Vector2, hook_radius: float)
signal target_detected(target: Area2D)

enum State { IDLE, CASTING, WAITING, RETRIEVING }

const FishingLineScript = preload("res://scripts/gameplay/fishing_line.gd")

@export var shoreline_distance: float = 140.0
@export var minimum_cast_range: float = 60.0
@export var maximum_cast_range: float = 420.0
@export_range(0.1, 3.0) var cast_duration: float = 0.8
@export_range(0.1, 3.0) var retrieval_duration: float = 0.65
@export var cast_height: float = 100.0

var state: State = State.IDLE
var water_bounds: Rect2 = Rect2()
var _elapsed: float = 0.0
var _start: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _invalid_feedback: float = 0.0

@onready var _pivot: Node2D = $Pivot
@onready var _tip: Marker2D = $Pivot/Tip
@onready var _hook: FishingHook = $FishingHook
@onready var _line: FishingLineScript = $FishingLine
@onready var _status: Label = $Status


func _ready() -> void:
	_hook.hide()
	_line.hide()
	_hook.area_entered.connect(_on_hook_area_entered)


func is_active() -> bool:
	return state != State.IDLE


func invalid_target_reason(target: Vector2) -> String:
	return invalid_target_reason_from(global_position, target)


func get_hook_attachment() -> Node2D:
	return _hook.visual


func get_hook_water_position() -> Vector2:
	return _hook.global_position


func invalid_target_reason_from(origin: Vector2, target: Vector2) -> String:
	if not water_bounds.has_area():
		return "No fishing water configured"
	var closest_water: Vector2 = origin.clamp(water_bounds.position, water_bounds.end)
	if origin.distance_to(closest_water) > shoreline_distance:
		return "Move closer to the shoreline"
	if not water_bounds.has_point(target):
		return "Aim at the ocean"
	var cast_distance: float = origin.distance_to(target)
	if cast_distance < minimum_cast_range or cast_distance > maximum_cast_range:
		return "Target outside casting range"
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("fishing_action"):
		return
	get_viewport().set_input_as_handled()
	match state:
		State.IDLE:
			var aim: Vector2 = get_global_mouse_position()
			if invalid_target_reason(aim).is_empty():
				_start_cast(aim)
			else:
				_invalid_feedback = 0.7
		State.WAITING:
			_start = _hook.global_position
			_set_state(State.RETRIEVING)


func _process(delta: float) -> void:
	_invalid_feedback = maxf(0.0, _invalid_feedback - delta)
	match state:
		State.IDLE:
			var aim: Vector2 = get_global_mouse_position()
			_pivot.look_at(aim)
			var reason: String = invalid_target_reason(aim)
			_status.text = "Ready - click to cast" if reason.is_empty() else reason
		State.CASTING:
			_elapsed += delta
			var progress: float = clampf(_elapsed / cast_duration, 0.0, 1.0)
			_hook.global_position = _start.lerp(_target, progress)
			# Height is presentation only: the Area2D follows the water-plane path.
			_hook.set_height(4.0 * cast_height * progress * (1.0 - progress))
			if progress >= 1.0:
				_set_state(State.WAITING)
				hook_landed.emit(_target)
				for area: Area2D in _hook.get_overlapping_areas():
					target_detected.emit(area)
		State.RETRIEVING:
			_elapsed += delta
			var progress: float = clampf(_elapsed / retrieval_duration, 0.0, 1.0)
			var previous_position: Vector2 = _hook.global_position
			_hook.global_position = _start.lerp(_tip.global_position, progress)
			_hook.set_height(0.0)
			# Include the final segment before IDLE/completion so fast returns cannot tunnel.
			retrieval_advanced.emit(previous_position, _hook.global_position, _hook.get_collision_radius())
			if progress >= 1.0:
				_hook.hide()
				_line.hide()
				_set_state(State.IDLE)
				retrieval_completed.emit(_target)
	if is_active():
		_line.connect_endpoints(_tip.global_position, _hook.get_line_endpoint())
	_status.modulate = Color(1.0, 0.4, 0.3) if _invalid_feedback > 0.0 else Color.WHITE
	queue_redraw()


func _draw() -> void:
	if state != State.IDLE:
		return
	var aim: Vector2 = get_global_mouse_position()
	var valid: bool = invalid_target_reason(aim).is_empty()
	var tint: Color = Color(0.4, 1.0, 0.6) if valid else Color(1.0, 0.3, 0.25)
	var center: Vector2 = to_local(aim)
	var radius: float = 12.0 if _invalid_feedback <= 0.0 else 18.0
	draw_arc(center, radius, 0.0, TAU, 32, tint, 2.0, true)
	draw_line(center - Vector2(5, 0), center + Vector2(5, 0), tint, 2.0)
	draw_line(center - Vector2(0, 5), center + Vector2(0, 5), tint, 2.0)


func _start_cast(target: Vector2) -> void:
	_target = target
	_pivot.look_at(target)
	_start = _tip.global_position
	_hook.global_position = _start
	_hook.set_height(0.0)
	_hook.show()
	_line.show()
	_line.connect_endpoints(_start, _start)
	_set_state(State.CASTING)


func _set_state(new_state: State) -> void:
	state = new_state
	_elapsed = 0.0
	match state:
		State.CASTING:
			_status.text = "Casting..."
		State.WAITING:
			_status.text = "Waiting - click to retrieve"
		State.RETRIEVING:
			_status.text = "Retrieving..."
	state_changed.emit(state)


func _on_hook_area_entered(area: Area2D) -> void:
	if state == State.WAITING:
		target_detected.emit(area)
