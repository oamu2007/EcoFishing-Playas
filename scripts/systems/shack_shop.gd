class_name ShackShop
extends Node

signal purchases_changed

@export var rod_upgrades: Array[RodUpgrade] = []
@export var sack_upgrades: Array[SackUpgrade] = []
@export var cleanup_projects: Array[CleanupProject] = []

var coins: int = 0
var rod_tier: int = 0
var sack_tier: int = 0
var _sack: Sack
var _rod: FishingRod
var _pollution: PollutionSystem
var _completed_projects: Dictionary[int, bool] = {}


func initialize(sack: Sack, rod: FishingRod, pollution: PollutionSystem) -> void:
	_sack = sack
	_rod = rod
	_pollution = pollution


func sell_all() -> int:
	return sell_selected(_sack.entries())


func sell_selected(selection: Array[Sack.Entry]) -> int:
	if selection.is_empty():
		return 0
	var earned: int = _sack.sale_quote(selection)
	if earned < 0:
		return 0
	coins += earned
	_sack.remove_entries(selection)
	purchases_changed.emit()
	return earned


func buy_rod(index: int) -> bool:
	if index != rod_tier or index < 0 or index >= rod_upgrades.size() or _rod.is_active():
		return false
	var upgrade: RodUpgrade = rod_upgrades[index]
	if coins < upgrade.cost:
		return false
	coins -= upgrade.cost
	rod_tier += 1
	_rod.maximum_cast_range = upgrade.cast_range
	_rod.cast_duration = upgrade.cast_time
	_rod.retrieval_duration = upgrade.retrieval_time
	_rod.trash_per_cast = upgrade.trash_limit
	_rod.set_rod_art(upgrade.art)
	purchases_changed.emit()
	return true


func buy_sack(index: int) -> bool:
	if index != sack_tier or index < 0 or index >= sack_upgrades.size():
		return false
	var upgrade: SackUpgrade = sack_upgrades[index]
	if coins < upgrade.cost or upgrade.capacity <= _sack.capacity:
		return false
	coins -= upgrade.cost
	sack_tier += 1
	_sack.expand(upgrade.capacity)
	purchases_changed.emit()
	return true


func is_cleanup_complete(index: int) -> bool:
	return _completed_projects.has(index)


func can_buy_cleanup(index: int) -> bool:
	if index < 0 or index >= cleanup_projects.size() or is_cleanup_complete(index):
		return false
	var project: CleanupProject = cleanup_projects[index]
	return coins >= project.cost and _pollution.permanent_points >= project.pollution_reduction


func buy_cleanup(index: int) -> bool:
	if not can_buy_cleanup(index):
		return false
	var project: CleanupProject = cleanup_projects[index]
	coins -= project.cost
	_completed_projects[index] = true
	_pollution.remove_permanent(project.pollution_reduction)
	purchases_changed.emit()
	return true
