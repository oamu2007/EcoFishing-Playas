class_name Sack
extends Node

signal contents_changed

class Entry extends RefCounted:
	var label: String
	var value: int
	var is_fish: bool
	var art: Texture2D

	func _init(catch_label: String, sale_value: int, caught_fish: bool, catch_art: Texture2D) -> void:
		label = catch_label
		value = sale_value
		is_fish = caught_fish
		art = catch_art

@export_range(1, 20) var capacity: int = 3
@export_range(0.0, 0.5) var full_slowdown: float = 0.12

var _items: Array[Entry] = []

var item_count: int:
	get:
		return _items.size()
var fish_count: int:
	get:
		var count: int = 0
		for item: Entry in _items:
			if item.is_fish:
				count += 1
		return count
var free_slots: int:
	get:
		return capacity - item_count
var movement_multiplier: float:
	get:
		return 1.0 - full_slowdown * float(item_count) / capacity


func store(label: String, sale_value: int, is_fish: bool, art: Texture2D = null) -> bool:
	if free_slots <= 0:
		return false
	_items.append(Entry.new(label, maxi(sale_value, 0), is_fish, art))
	contents_changed.emit()
	return true


func sale_total() -> int:
	var total: int = 0
	for item: Entry in _items:
		total += item.value
	return total


func contents_description() -> String:
	var labels: PackedStringArray = []
	for item: Entry in _items:
		labels.append("%s · %d gold" % [item.label, item.value])
	return "\n".join(labels)


func empty() -> void:
	if item_count > 0:
		_items.clear()
		contents_changed.emit()


func expand(new_capacity: int) -> void:
	if new_capacity > capacity:
		capacity = new_capacity
		contents_changed.emit()
