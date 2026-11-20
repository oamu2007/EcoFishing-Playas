class_name Sack
extends Node

signal contents_changed

@export_range(1, 20) var capacity: int = 3
@export_range(0.0, 0.5) var full_slowdown: float = 0.12

var _sale_values: Array[int] = []

var item_count: int:
	get:
		return _sale_values.size()
var free_slots: int:
	get:
		return capacity - item_count
var movement_multiplier: float:
	get:
		return 1.0 - full_slowdown * float(item_count) / capacity


func store(sale_value: int) -> bool:
	if free_slots <= 0:
		return false
	_sale_values.append(maxi(sale_value, 0))
	contents_changed.emit()
	return true


func sale_total() -> int:
	var total: int = 0
	for value: int in _sale_values:
		total += value
	return total


func empty() -> void:
	if item_count > 0:
		_sale_values.clear()
		contents_changed.emit()


func expand(new_capacity: int) -> void:
	if new_capacity > capacity:
		capacity = new_capacity
		contents_changed.emit()
