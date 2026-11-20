class_name WaterVisuals
extends Node2D

signal displayed_pollution_changed(value: float)

@export var water_size: Vector2 = Vector2(760, 900)
@export_range(0.1, 5.0) var transition_duration: float = 1.6

var displayed_pollution: float = 1.0
var target_pollution: float = 1.0
var surface_material: ShaderMaterial
var _model: PollutionSystem
var _transition_start: float = 1.0
var _elapsed: float = 0.0

const SeabedScript = preload("res://scripts/gameplay/seabed.gd")

@onready var _surface: ColorRect = $Surface
@onready var _seabed: SeabedScript = $Seabed


func _ready() -> void:
	# One private material per water instance; never allocate materials per frame.
	surface_material = _surface.material.duplicate() as ShaderMaterial
	_surface.material = surface_material
	configure_size(water_size)
	set_visual_target(displayed_pollution, true)


func configure_size(size: Vector2) -> void:
	water_size = size
	_surface.size = size
	_seabed.configure_size(size)
	surface_material.set_shader_parameter("water_size", size)


func bind_pollution(model: PollutionSystem) -> void:
	if is_instance_valid(_model) and _model.pollution_changed.is_connected(_on_pollution_changed):
		_model.pollution_changed.disconnect(_on_pollution_changed)
	_model = model
	_model.pollution_changed.connect(_on_pollution_changed)
	# Initial state is synchronous, including empty levels and scene reloads.
	set_visual_target(model.normalized_pollution, true)


func set_visual_target(value: float, immediate: bool = false) -> void:
	target_pollution = clampf(value, 0.0, 1.0)
	_transition_start = displayed_pollution
	_elapsed = 0.0
	if immediate:
		_apply_displayed(target_pollution)
		set_process(false)
	else:
		set_process(not is_equal_approx(displayed_pollution, target_pollution))


func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	var progress: float = clampf(_elapsed / maxf(transition_duration, 0.001), 0.0, 1.0)
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	_apply_displayed(lerpf(_transition_start, target_pollution, eased))
	if progress >= 1.0:
		set_process(false)


func _apply_displayed(value: float) -> void:
	displayed_pollution = value
	surface_material.set_shader_parameter("pollution_level", value)
	displayed_pollution_changed.emit(value)


func _on_pollution_changed(normalized: float, _collected: int, _remaining: int) -> void:
	set_visual_target(normalized)
