class_name PollutionSystem
extends Node

signal pollution_changed(normalized_pollution: float, collected_count: int, remaining_count: int)
signal cleanup_completed

var initial_total_pollution: int = 0
var current_pollution: int = 0
var trash_collected: int = 0
var _remaining: Dictionary[int, int] = {}

var remaining_trash: int:
	get:
		return _remaining.size()

var normalized_pollution: float:
	get:
		if initial_total_pollution == 0:
			return 0.0
		return clampf(float(current_pollution) / initial_total_pollution, 0.0, 1.0)


func initialize(item_values: Dictionary[int, int]) -> void:
	_remaining.assign(item_values)
	initial_total_pollution = 0
	for id: int in _remaining:
		_remaining[id] = maxi(0, _remaining[id])
		initial_total_pollution += _remaining[id]
	current_pollution = initial_total_pollution
	trash_collected = 0
	_emit_state()


func collect(item_id: int) -> bool:
	if not _remaining.has(item_id):
		return false
	current_pollution = maxi(0, current_pollution - _remaining[item_id])
	_remaining.erase(item_id)
	trash_collected += 1
	_emit_state()
	return true


func _emit_state() -> void:
	pollution_changed.emit(normalized_pollution, trash_collected, remaining_trash)
	if remaining_trash == 0:
		cleanup_completed.emit()
