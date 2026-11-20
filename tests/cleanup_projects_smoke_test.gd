extends SceneTree

const SESSION_SCENE: PackedScene = preload("res://scenes/gameplay/session.tscn")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")

var _failures: int = 0
var _session: Node
var _world: LevelScript
var _player: CharacterBody2D
var _panel: CanvasLayer
var _project_buttons: Array[Node]
var _meter: ProgressBar
var _rod: FishingRod
var _manager: TrashManager
var _sack: Sack
var _shop: ShackShop
var _pollution: PollutionSystem
var _starter_range: float


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	_start_session()
	_check(_shop.cleanup_projects.size() == 3 and _project_buttons.size() == 3, "Expected three playable cleanup projects")
	if _failures == 0:
		_verify_new_session()
		_verify_cleanup_path()
		_session.free()
		_start_session()
		_verify_new_session()
	_session.free()
	print("Cleanup projects smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _start_session() -> void:
	_session = SESSION_SCENE.instantiate()
	root.add_child(_session)
	_world = _session.get_node("World")
	_player = _world.get_node("Player")
	_panel = _session.get_node("ShackPanel")
	_project_buttons = _panel.get_node("%Cleanup").find_children("*", "Button", true, false)
	_meter = _session.get_node("HUD/ProgressPanel/Margin/Readouts/PollutionBar")
	_rod = _world.rod
	_starter_range = _rod.maximum_cast_range
	_manager = _world.trash_manager
	_sack = _world.sack
	_shop = _world.shop
	_pollution = _world.pollution
	_rod.set_process(false)
	_manager.set_physics_process(false)
	_player.set_physics_process(false)


func _verify_new_session() -> void:
	_check(_shop.coins == 0 and _shop.rod_tier == 0 and _sack.item_count == 0, "Session did not start with base gear and an empty Sack")
	_check(_pollution.permanent_points == PollutionSystem.MAX_PERMANENT_POINTS and _meter.value == 100.0, "Session did not start with full pollution")
	_open_shack()
	var catalog_points: int = 0
	for index: int in _shop.cleanup_projects.size():
		var project: CleanupProject = _shop.cleanup_projects[index]
		var button: Button = _project_buttons[index]
		catalog_points += project.pollution_reduction
		_check(not _shop.is_cleanup_complete(index) and button.disabled and button.text == "%d gold" % project.cost, "Session did not restore the project catalog")
		button.pressed.emit()
		_check(not _shop.buy_cleanup(index) and not _shop.is_cleanup_complete(index), "Unaffordable cleanup was purchased")
	_check(catalog_points == PollutionSystem.MAX_PERMANENT_POINTS, "Cleanup catalog does not cover all permanent pollution")
	_check(_shop.coins == 0 and _meter.value == 100.0, "Unaffordable cleanup changed coins or pollution")
	_close_shack()


func _verify_cleanup_path() -> void:
	var starter_cast: float = _rod.cast_duration
	_earn(_shop.rod_upgrades[0].cost, 1)
	_open_shack()
	_check(_shop.buy_rod(0) and _rod.maximum_cast_range > _starter_range and _rod.cast_duration < starter_cast, "A starter Sack did not fund the first rod upgrade")
	_close_shack()

	for index: int in range(2):
		var project: CleanupProject = _shop.cleanup_projects[index]
		_earn(project.cost, index + 1)
		_restore_floating_cap()
		_purchase_project(index)
		_check(_catch_reachable_trash(), "No reachable trash remained after the cleanup purchase")
		_check(_pollution.floating_points < PollutionSystem.MAX_FLOATING_POINTS, "Catch did not lower the floating load before the rebound")
		var permanent: int = _pollution.permanent_points
		_restore_floating_cap()
		_check(_pollution.permanent_points == permanent, "A live arrival changed permanent pollution")
		_check_completed_projects(index + 1)
	_check(_pollution.current_pollution == 50 and _meter.value == 50.0, "First rod and two projects did not reach the fish threshold after a full floating rebound")

	# Starter-range income funds the final project and the gear to retrieve offshore pieces.
	_earn(_shop.cleanup_projects[2].cost + _shop.rod_upgrades[1].cost, 5)
	_open_shack()
	var coins: int = _shop.coins
	var pollution_before: int = _pollution.current_pollution
	for index: int in range(2):
		var button: Button = _project_buttons[index]
		_check(coins >= _shop.cleanup_projects[index].cost and not _shop.buy_cleanup(index), "An affordable duplicate cleanup was accepted")
		button.pressed.emit()
	_check(_shop.coins == coins and _pollution.current_pollution == pollution_before, "Repeated cleanup charged coins or reduced pollution")
	_check(_shop.buy_rod(1), "Recurring trash sales did not fund the offshore rod")
	_close_shack()
	_restore_floating_cap()
	_purchase_project(2)
	_check(_pollution.permanent_points == 0 and _meter.value == float(PollutionSystem.MAX_FLOATING_POINTS), "All projects should leave only the floating load")

	while not _manager.items.is_empty():
		if _sack.free_slots == 0:
			_sell_at_shack()
		if not _catch_reachable_trash():
			break
	_check(_manager.items.is_empty() and _pollution.current_pollution == 0 and _meter.value == 0.0, "Completed projects and a cleared shore did not reach zero")
	_manager._physics_process(_manager.arrival_interval)
	_check(_manager.items.size() == 1 and _pollution.current_pollution == 0, "Next floating arrival counted before entering the ocean")
	if _manager.items.size() == 1:
		var newcomer: OceanTrash = _manager.items[0]
		_check(not newcomer.in_water, "Next piece did not enter by the live arrival path")
		newcomer._physics_process(_manager.arrival_travel_time)
		_check(newcomer.in_water and _pollution.permanent_points == 0 and _pollution.floating_points == newcomer.pollution_value, "Next arrival did not restore only floating pollution")
		_check(_meter.value == float(newcomer.pollution_value), "The HUD did not rebound from zero")
	_check_completed_projects(_shop.cleanup_projects.size())


func _check_completed_projects(count: int) -> void:
	_open_shack()
	for index: int in count:
		var button: Button = _project_buttons[index]
		_check(_shop.is_cleanup_complete(index) and button.disabled and button.text == "Complete", "Project did not stay complete across arrivals and shop visits")
	_close_shack()


func _purchase_project(index: int) -> void:
	_open_shack()
	var project: CleanupProject = _shop.cleanup_projects[index]
	var button: Button = _project_buttons[index]
	var coins: int = _shop.coins
	var permanent: int = _pollution.permanent_points
	var floating: int = _pollution.floating_points
	var trash_count: int = _manager.items.size()
	_check(not button.disabled and button.text == "%d gold" % project.cost, "Affordable project did not display its configured price")
	button.pressed.emit()
	_check(_shop.coins == coins - project.cost and _pollution.permanent_points == permanent - project.pollution_reduction, "Project charged or removed the wrong amount")
	_check(_pollution.floating_points == floating and _manager.items.size() == trash_count, "Project changed the floating load")
	_check(_meter.value == float(permanent - project.pollution_reduction + floating), "Project did not update the HUD immediately")
	_check(_shop.is_cleanup_complete(index) and button.disabled and button.text == "Complete", "Purchased project did not display completion")
	_close_shack()


func _earn(amount: int, max_trips: int) -> void:
	for trip: int in max_trips:
		if _shop.coins >= amount:
			break
		for attempt: int in range(_sack.capacity + _manager.maximum_active_items):
			if _sack.free_slots == 0:
				break
			if not _catch_reachable_trash(_starter_range):
				_advance_arrival()
		_check(_sack.free_slots == 0, "Recurring arrivals failed to fill a starter Sack")
		_sell_at_shack()
	_check(_shop.coins >= amount, "Trash sales exceeded the expected trip budget")


func _restore_floating_cap() -> void:
	for attempt: int in _manager.maximum_active_items:
		if _pollution.floating_points == PollutionSystem.MAX_FLOATING_POINTS:
			return
		_advance_arrival()
	_check(false, "Real arrivals did not restore the full floating load")


func _advance_arrival() -> void:
	_manager._physics_process(_manager.arrival_interval)
	for item: OceanTrash in _manager.items:
		if item.is_arriving:
			item._physics_process(_manager.arrival_travel_time)


func _catch_reachable_trash(maximum_distance: float = INF) -> bool:
	var rod_offset: Vector2 = _rod.global_position - _player.global_position
	for item: OceanTrash in _manager.items:
		var target: Vector2 = item.global_position
		var origin: Vector2 = Vector2(_world.shore_start.x, target.y)
		if not item.in_water or origin.distance_to(target) > maximum_distance:
			continue
		if not _rod.invalid_target_reason_from(origin, target).is_empty():
			continue
		_player.global_position = origin - rod_offset
		var before: int = _sack.item_count
		_rod._start_cast(target)
		_rod._process(_rod.cast_duration)
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		_rod._unhandled_input(click)
		_rod._process(_rod.retrieval_duration)
		var landed: bool = _sack.item_count > before
		_check(landed and _rod.state == FishingRod.State.IDLE, "Reachable trash did not complete the cast and return to the Sack")
		return landed
	return false


func _sell_at_shack() -> void:
	_open_shack()
	var button: Button = _panel.get_node("%Sell")
	var payout: int = _sack.item_count * _manager.trash_sale_value
	var coins: int = _shop.coins
	_check(payout > 0 and not button.disabled and button.text.contains(str(payout)), "Sale did not display the expected trash payout")
	button.pressed.emit()
	_check(_shop.coins == coins + payout and _sack.item_count == 0, "Sale did not fund projects with the correct trash payout")
	_close_shack()


func _open_shack() -> void:
	var shack: FishingShack = _world.get_node("FishingShack")
	_player.global_position = shack.global_position
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	_session._unhandled_input(key)
	_check(_panel.visible, "Shack did not open at its entrance")


func _close_shack() -> void:
	var button: Button = _panel.get_node("%Close")
	button.pressed.emit()
	_check(not _panel.visible, "Shack did not close")
