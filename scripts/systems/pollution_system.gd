class_name PollutionSystem
extends Node

signal pollution_changed(normalized_pollution: float)

const MAX_FLOATING_POINTS: int = 30
const MAX_PERMANENT_POINTS: int = 70

var permanent_points: int = MAX_PERMANENT_POINTS
var trash_collected: int = 0
var _floating_load: int = 0
var _floating_disabled: bool = false
var _remaining: Dictionary[int, int] = {}

var remaining_trash: int:
	get:
		return _remaining.size()
var floating_points: int:
	get:
		return 0 if _floating_disabled else mini(_floating_load, MAX_FLOATING_POINTS)
var current_pollution: int:
	get:
		return permanent_points + floating_points
var normalized_pollution: float:
	get:
		return current_pollution / 100.0


func initialize(item_values: Dictionary[int, int], permanent: int = MAX_PERMANENT_POINTS) -> void:
	var previous: int = current_pollution
	permanent_points = clampi(permanent, 0, MAX_PERMANENT_POINTS)
	trash_collected = 0
	_floating_disabled = false
	_remaining.clear()
	_floating_load = 0
	for id: int in item_values:
		var points: int = clampi(item_values[id], 0, MAX_FLOATING_POINTS)
		_remaining[id] = points
		_floating_load += points
	_emit_change(previous)


func register_trash(item_id: int, points: int) -> bool:
	if _remaining.has(item_id):
		return false
	var previous: int = current_pollution
	var contribution: int = clampi(points, 0, MAX_FLOATING_POINTS)
	_remaining[item_id] = contribution
	_floating_load += contribution
	_emit_change(previous)
	return true


func collect(item_id: int) -> bool:
	if not _remaining.has(item_id):
		return false
	var previous: int = current_pollution
	_floating_load -= _remaining[item_id]
	_remaining.erase(item_id)
	trash_collected += 1
	_emit_change(previous)
	return true


func remove_permanent(points: int) -> int:
	var previous: int = current_pollution
	var removed: int = clampi(points, 0, permanent_points)
	permanent_points -= removed
	_emit_change(previous)
	return removed


func disable_floating_pollution() -> void:
	var previous: int = current_pollution
	_floating_disabled = true
	_emit_change(previous)


func _emit_change(previous: int) -> void:
	if current_pollution != previous:
		pollution_changed.emit(normalized_pollution)
