class_name ShackShop
extends Node

signal purchases_changed
signal cleanup_funded(project: CleanupProject)
signal offshore_net_purchased
signal sale_completed
signal purchase_completed

@export var rod_upgrades: Array[RodUpgrade] = []
@export var rod_add_ons: Array[RodAddOn] = []
@export var sack_upgrades: Array[SackUpgrade] = []
@export var cleanup_projects: Array[CleanupProject] = []
@export_range(0, 500) var offshore_net_cost: int = 0

var coins: int = 0
var rod_tier: int = 0
var sack_tier: int = 0
var offshore_net_installed: bool = false
var _sack: Sack
var _rod: FishingRod
var _pollution: PollutionSystem
var _completed_projects: Dictionary[int, bool] = {}
var _owned_rod_add_ons: Dictionary[Vector2i, bool] = {}


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
	sale_completed.emit()
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
	_apply_rod_add_ons()
	purchases_changed.emit()
	purchase_completed.emit()
	return true


func rod_title(tier: int) -> String:
	return "Starter rod" if tier == 0 else rod_upgrades[tier - 1].title


func owns_rod_add_on(tier: int, index: int) -> bool:
	return _owned_rod_add_ons.has(Vector2i(tier, index))


func can_buy_rod_add_on(index: int) -> bool:
	return index >= 0 and index < rod_add_ons.size() and not _rod.is_active() and not owns_rod_add_on(rod_tier, index) and coins >= rod_add_ons[index].cost


func buy_rod_add_on(index: int) -> bool:
	if not can_buy_rod_add_on(index):
		return false
	coins -= rod_add_ons[index].cost
	_owned_rod_add_ons[Vector2i(rod_tier, index)] = true
	_apply_rod_add_ons()
	purchases_changed.emit()
	purchase_completed.emit()
	return true


func _apply_rod_add_ons() -> void:
	var forgiveness: int = 0
	var discount: float = 0.0
	for index: int in rod_add_ons.size():
		if owns_rod_add_on(rod_tier, index):
			forgiveness = maxi(forgiveness, rod_add_ons[index].forgiven_misses)
			discount = maxf(discount, rod_add_ons[index].duration_discount)
	_rod.configure_add_ons(forgiveness, discount)


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
	purchase_completed.emit()
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
	purchase_completed.emit()
	cleanup_funded.emit(project)
	return true


func is_offshore_net_unlocked() -> bool:
	return offshore_net_cost > 0 and _completed_projects.size() == cleanup_projects.size()


func can_buy_offshore_net() -> bool:
	return is_offshore_net_unlocked() and not offshore_net_installed and coins >= offshore_net_cost


func buy_offshore_net() -> bool:
	if not can_buy_offshore_net():
		return false
	coins -= offshore_net_cost
	offshore_net_installed = true
	_pollution.disable_floating_pollution()
	offshore_net_purchased.emit()
	purchases_changed.emit()
	purchase_completed.emit()
	return true


func credit_intercepted_trash(value: int) -> void:
	coins += value
	purchases_changed.emit()
