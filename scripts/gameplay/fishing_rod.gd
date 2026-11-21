class_name FishingRod
extends Node2D

signal state_changed(new_state: State)
signal cast_rejected(reason: String)
signal hook_landed(water_position: Vector2)
signal retrieval_completed(water_position: Vector2)
signal retrieval_advanced(previous_position: Vector2, current_position: Vector2, hook_radius: float)
signal target_detected(target: Area2D)
signal fish_timing_finished(succeeded: bool)
signal fish_timing_advanced
signal fish_timing_saved

enum State { IDLE, CASTING, WAITING, RETRIEVING, TIMING }

const FishingLineScript = preload("res://scripts/gameplay/fishing_line.gd")

@export var shoreline_distance: float = 140.0
@export var minimum_cast_range: float = 60.0
@export var maximum_cast_range: float = 240.0
@export_range(0.1, 3.0) var cast_duration: float = 1.05
@export_range(0.1, 3.0) var retrieval_duration: float = 0.85
@export_range(1, 10) var trash_per_cast: int = 1
@export var cast_height: float = 100.0
@export_range(0.5, 5.0, 0.05) var fish_timing_duration: float = 1.20
@export_range(0.05, 0.6, 0.01) var fish_timing_window: float = 0.17
@export var fish_timing_centers: Vector2 = Vector2(0.50, 0.83)
@export_range(0.0, 1.0, 0.01) var fish_timing_reaction_time: float = 0.45
@export_range(0.0, 0.5, 0.01) var fish_timing_center_shift: float = 0.10

var state: State = State.IDLE
var cast_number: int = 0
var input_locked: bool = false
var show_idle_status: bool = true
var water_bounds: Rect2 = Rect2()
var fish_timing_stage: int = 1
var fish_timing_checks: int = 1
var fish_timing_saves_left: int = 0
var fish_secured: bool = false
var _timing_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _timing_zone: Vector2
var _timing_window: float
var _forgiven_misses: int = 0
var _duration_discount: float = 0.0
var _elapsed: float = 0.0
var _start: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _invalid_feedback: float = 0.0
var _help_visible: bool = false

@onready var _pivot: Node2D = $Pivot
@onready var _rod_art: Sprite2D = $Pivot/Rod
@onready var _slip_guard_art: Sprite2D = $Pivot/SlipGuard
@onready var _quick_spool_art: Sprite2D = $Pivot/QuickSpool
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


func set_help_visible(value: bool) -> void:
	_help_visible = value
	_refresh_status_visibility()


func set_rod_art(art: Texture2D) -> void:
	if art != null:
		_rod_art.texture = art


func configure_add_ons(forgiven_misses: int, duration_discount: float) -> void:
	_forgiven_misses = forgiven_misses
	_duration_discount = duration_discount
	_slip_guard_art.visible = forgiven_misses > 0
	_quick_spool_art.visible = duration_discount > 0.0


func equipped_cast_duration() -> float:
	return cast_duration * (1.0 - _duration_discount)


func equipped_retrieval_duration() -> float:
	return retrieval_duration * (1.0 - _duration_discount)


func start_fish_timing(checks: int, window: float = 0.0) -> void:
	if state == State.WAITING:
		fish_timing_stage = 1
		fish_timing_checks = checks
		fish_timing_saves_left = _forgiven_misses
		_timing_window = clampf(window, 0.05, 0.6) if window > 0.0 else fish_timing_window
		_place_fish_timing_zone()
		_set_state(State.TIMING)


func fish_timing_progress() -> float:
	return clampf(_elapsed / fish_timing_duration, 0.0, 1.0) if state == State.TIMING else 0.0


func fish_timing_zone() -> Vector2:
	return _timing_zone


func _place_fish_timing_zone() -> void:
	var half_window: float = _timing_window * 0.5
	var latest_center: float = 1.0 - half_window
	var earliest_center: float = minf(latest_center, half_window + fish_timing_reaction_time / fish_timing_duration)
	var first_center: float = clampf(fish_timing_centers.x, earliest_center, latest_center)
	var last_center: float = clampf(fish_timing_centers.y, first_center, latest_center)
	var center: float
	var span: float = last_center - first_center
	if fish_timing_stage > 1 and span > 0.0:
		# Wrap around the allowed center range while avoiding the previous center.
		var shift: float = minf(fish_timing_center_shift, span * 0.5)
		var previous_center: float = (_timing_zone.x + _timing_zone.y) * 0.5 - first_center
		center = first_center + fposmod(previous_center + _timing_rng.randf_range(shift, span - shift), span)
	else:
		center = _timing_rng.randf_range(first_center, last_center)
	_timing_zone = Vector2(center - half_window, center + half_window)


func invalid_target_reason(target: Vector2) -> String:
	return invalid_target_reason_from(global_position, target)


func get_hook_attachment() -> Node2D:
	return _hook.visual


func get_hook_water_position() -> Vector2:
	return _hook.global_position


func is_near_shore(origin: Vector2) -> bool:
	var closest_water: Vector2 = origin.clamp(water_bounds.position, water_bounds.end)
	return water_bounds.has_area() and origin.distance_to(closest_water) <= shoreline_distance


func invalid_target_reason_from(origin: Vector2, target: Vector2) -> String:
	if not water_bounds.has_area():
		return "No fishing water configured"
	if not is_near_shore(origin):
		return "Move closer to the shoreline"
	if not water_bounds.has_point(target):
		return "Aim at the ocean"
	var cast_distance: float = origin.distance_to(target)
	if cast_distance < minimum_cast_range or cast_distance > maximum_cast_range:
		return "Target outside casting range"
	return ""


func _input(event: InputEvent) -> void:
	if not input_locked and state == State.TIMING and event is InputEventKey and event.physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			_press_fish_timing()


func _unhandled_input(event: InputEvent) -> void:
	if input_locked or not event.is_action_pressed("fishing_action"):
		return
	get_viewport().set_input_as_handled()
	match state:
		State.IDLE:
			var aim: Vector2 = get_global_mouse_position()
			if event is InputEventMouseButton:
				aim = get_canvas_transform().affine_inverse() * event.position
			var reason: String = invalid_target_reason(aim)
			if reason.is_empty():
				_start_cast(aim)
			else:
				_invalid_feedback = 0.7
				cast_rejected.emit(reason)
		State.WAITING:
			_start = _hook.global_position
			_set_state(State.RETRIEVING)
		State.TIMING:
			_press_fish_timing()


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
			var progress: float = clampf(_elapsed / equipped_cast_duration(), 0.0, 1.0)
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
			var progress: float = clampf(_elapsed / equipped_retrieval_duration(), 0.0, 1.0)
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
		State.TIMING:
			_elapsed += delta
			if _elapsed >= fish_timing_duration:
				_finish_fish_timing(false)
	if is_active():
		_line.connect_endpoints(_tip.global_position, _hook.get_line_endpoint())
	_refresh_status_visibility()
	_status.modulate = Color(1.0, 0.4, 0.3) if _invalid_feedback > 0.0 else Color.WHITE
	queue_redraw()


func _refresh_status_visibility() -> void:
	_status.visible = _help_visible and not input_locked and state != State.TIMING and (is_active() or (show_idle_status and is_near_shore(global_position)))


func _draw() -> void:
	if input_locked or state != State.IDLE:
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
	cast_number += 1
	_target = target
	_pivot.look_at(target)
	_start = _tip.global_position
	_hook.global_position = _start
	_hook.set_height(0.0)
	_hook.show()
	_line.show()
	_line.connect_endpoints(_start, _start)
	_set_state(State.CASTING)


func _press_fish_timing() -> void:
	var zone: Vector2 = fish_timing_zone()
	var progress: float = fish_timing_progress()
	if progress >= zone.x and progress <= zone.y:
		if fish_timing_stage == fish_timing_checks:
			_finish_fish_timing(true)
		else:
			fish_timing_stage += 1
			_elapsed = 0.0
			_place_fish_timing_zone()
			fish_timing_advanced.emit()
	elif fish_timing_saves_left > 0:
		fish_timing_saves_left -= 1
		_elapsed = 0.0
		fish_timing_saved.emit()
	else:
		_finish_fish_timing(false)


func _finish_fish_timing(succeeded: bool) -> void:
	if succeeded:
		fish_secured = true
		_set_state(State.WAITING)
	else:
		_hook.hide()
		_line.hide()
		_set_state(State.IDLE)
	fish_timing_finished.emit(succeeded)


func _set_state(new_state: State) -> void:
	state = new_state
	_elapsed = 0.0
	if state == State.IDLE and fish_secured:
		fish_secured = false
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
