class_name ShackShop
extends Node

signal purchases_changed

@export var rod_upgrades: Array[RodUpgrade] = []
@export var sack_upgrades: Array[SackUpgrade] = []

var coins: int = 0
var rod_tier: int = 0
var sack_tier: int = 0
var _sack: Sack
var _rod: FishingRod


func initialize(sack: Sack, rod: FishingRod) -> void:
	_sack = sack
	_rod = rod


func sell_all() -> int:
	if _sack.item_count == 0:
		return 0
	var earned: int = _sack.sale_total()
	coins += earned
	_sack.empty()
	purchases_changed.emit()
	return earned


func buy_rod(index: int) -> bool:
	if index != rod_tier or index >= rod_upgrades.size() or _rod.is_active():
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
	purchases_changed.emit()
	return true


func buy_sack(index: int) -> bool:
	if index != sack_tier or index >= sack_upgrades.size():
		return false
	var upgrade: SackUpgrade = sack_upgrades[index]
	if coins < upgrade.cost or upgrade.capacity <= _sack.capacity:
		return false
	coins -= upgrade.cost
	sack_tier += 1
	_sack.expand(upgrade.capacity)
	purchases_changed.emit()
	return true
