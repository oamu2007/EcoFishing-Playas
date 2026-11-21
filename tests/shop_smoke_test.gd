extends SceneTree

const SESSION_SCENE: PackedScene = preload("res://scenes/gameplay/session.tscn")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const PlayerScript = preload("res://scripts/gameplay/player.gd")
const TraderFixture = preload("res://tests/trader_fixture.gd")

var _failures: int = 0
var _session: Node
var _world: LevelScript
var _player: PlayerScript
var _panel: CanvasLayer
var _rod: FishingRod
var _manager: TrashManager
var _sack: Sack
var _shop: ShackShop


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	_session = SESSION_SCENE.instantiate()
	root.add_child(_session)
	_world = _session.get_node("World")
	_player = _world.get_node("Player")
	_panel = _session.get_node("ShackPanel")
	_rod = _world.rod
	_manager = _world.trash_manager
	_sack = _world.sack
	_shop = _world.shop
	_rod.set_process(false)
	_manager.set_physics_process(false)
	var starter_cast: float = _rod.cast_duration
	var starter_return: float = _rod.retrieval_duration
	var starter_capacity: int = _sack.capacity
	var equipped_art: Sprite2D = _rod.get_node("Pivot/Rod")
	var tip: Marker2D = _rod.get_node("Pivot/Tip")
	var starter_art: Texture2D = equipped_art.texture
	var target: Vector2 = Vector2(_world.shore_start.x + 325.0, 450.0)
	var shack: FishingShack = _world.get_node("FishingShack")
	_check(_sack.capacity == 3 and _shop.coins == 0 and _sack.item_count == 0, "Session did not start with base equipment")
	_check(not _shop.buy_rod(0) and not _shop.buy_sack(0), "Unaffordable gear was purchased")
	_shack_key()
	_check(not _panel.visible, "Shack opened outside interaction range")
	_place_on_shore(target.y)
	_check(not _rod.invalid_target_reason(target).is_empty(), "Starter rod reached the upgrade target")

	for index: int in starter_capacity:
		_catch_one()
	_check(_sack.item_count == starter_capacity, "Normal catches failed to fill the Sack")
	await _test_full_sack_feedback()
	var collected: int = _world.pollution.trash_collected
	var remaining: int = _manager.items.size()
	_catch_one()
	_check(_world.pollution.trash_collected == collected and _manager.items.size() == remaining, "Full Sack removed an extra item")
	_check(_session.get_node("HUD/Notification").text.begins_with("Sack full"), "Missing full Sack feedback")
	_place_on_shore(shack.global_position.y)
	Input.action_press("move_left")
	await physics_frame
	await physics_frame
	_check(is_equal_approx(_player.velocity.length(), _player.movement_speed * (1.0 - _sack.full_slowdown)), "Full Sack slowdown was not applied")
	for frame: int in range(40):
		if _world.can_open_shack():
			break
		await physics_frame
	Input.action_release("move_left")
	_check(_world.can_open_shack(), "Shack is not a short walk from the fishing spot")
	_shack_key()
	_check(_panel.visible and _rod.input_locked and _player.input_locked, "Shack did not block gameplay input")
	_rod._unhandled_input(_click())
	_check(_rod.state == FishingRod.State.IDLE, "Shop click leaked to fishing")
	TraderFixture.select_all(_panel)
	var sell: Button = _panel.get_node("%ConfirmSale")
	var expected: int = starter_capacity * _manager.trash_sale_value
	_check(sell.text.contains(str(expected)) and not sell.disabled, "Sell button did not quote the exact payout")
	sell.pressed.emit()
	sell.pressed.emit()
	_check(_shop.coins == expected and _sack.item_count == 0 and sell.disabled, "Sale paid incorrectly or paid twice")
	_check(is_equal_approx(_sack.movement_multiplier, 1.0), "Unloading did not restore normal speed")
	_check(not _shop.buy_rod(0), "A single starter trip funded the first rod")
	_panel.get_node("%Close").pressed.emit()
	_earn(_shop.rod_upgrades[0].cost)
	var before_rod: int = _shop.coins
	_check(_shop.buy_rod(0) and not _shop.buy_rod(0) and _shop.rod_tier == 1, "First rod upgrade failed or was duplicated")
	_check(equipped_art.texture == _shop.rod_upgrades[0].art and equipped_art.texture != starter_art, "Shore rod did not switch the equipped art")
	_check(_shop.coins == before_rod - _shop.rod_upgrades[0].cost and _rod.cast_duration < starter_cast and _rod.retrieval_duration < starter_return, "Rod upgrade did not apply the advertised effects")
	_check(not _panel.visible and not _rod.input_locked and not _player.input_locked, "Closing the shop did not restore controls")
	_player.set_physics_process(false)
	_place_on_shore(target.y)
	_check(_rod.invalid_target_reason(target).is_empty(), "First rod upgrade failed to extend reach")

	collected = _world.pollution.trash_collected
	_align_targets(target)
	_cast_and_retrieve(target)
	_check(_sack.item_count == 2, "Upgraded rod failed to land two trash items")
	_align_targets(target)
	_cast_and_retrieve(target)
	_check(_sack.item_count == 3 and _world.pollution.trash_collected == collected + 3, "Upgraded rod ignored remaining Sack space")
	_sell_at_shack()
	_earn(_shop.sack_upgrades[0].cost)
	_check(_shop.buy_sack(0) and _sack.capacity > starter_capacity and not _shop.buy_sack(0), "Sack upgrade did not expand capacity exactly once")
	_earn(_shop.rod_upgrades[1].cost)
	var previous_range: float = _rod.maximum_cast_range
	var previous_cast: float = _rod.cast_duration
	var previous_retrieval: float = _rod.retrieval_duration
	_check(_shop.buy_rod(1) and not _shop.buy_rod(1), "Second rod upgrade failed")
	_check(equipped_art.texture == _shop.rod_upgrades[1].art and equipped_art.position + Vector2(52, 12) == tip.position, "Offshore rod art or line attachment is misaligned")
	_check(_rod.maximum_cast_range > previous_range and _rod.cast_duration < previous_cast and _rod.retrieval_duration < previous_retrieval and _rod.trash_per_cast == 3, "Offshore rod tuning failed")
	_earn(_shop.sack_upgrades[1].cost)
	_check(_shop.buy_sack(1) and _sack.capacity == 8 and not _shop.buy_sack(1), "Second Sack upgrade failed")

	_session.free()
	print("Shop smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_full_sack_feedback() -> void:
	var hud: CanvasLayer = _session.get_node("HUD")
	var popup: Label = hud.get_node("SackFull")
	var timer: Timer = hud.get_node("SackFullTimer")
	var help: Button = hud.get_node("HelpKey")
	var spot: Vector2 = Vector2(_world.shore_start.x + 76.0, 450.0)
	_place_on_shore(spot.y)
	for help_enabled: bool in [false, true]:
		_check(hud.is_help_enabled() == help_enabled, "Full Sack fixture used the wrong Help state")
		_check(not popup.visible, "Sack popup appeared before the cast was attempted")
		_cast_for_feedback(spot)
		_check(popup.visible and popup.text == "Sack full" and not timer.is_stopped(), "Full Sack cast did not show immediate feedback")
		_finish_feedback_cast()
		await create_timer(0.4).timeout
		var remaining: float = timer.time_left
		_cast_for_feedback(_rod.global_position - Vector2(100.0, 0.0))
		_check(popup.visible and timer.time_left > remaining and _rod.state == FishingRod.State.IDLE, "An invalid retry did not refresh the same popup while preserving cast validation")
		await create_timer(timer.wait_time + 0.1).timeout
		_check(not popup.visible and timer.is_stopped(), "Full Sack feedback did not clear on its own")
		var entry: Sack.Entry = _sack.entries().back()
		_sack.remove_entries([entry])
		_cast_for_feedback(spot)
		_check(not popup.visible and _sack.free_slots == 1, "The popup showed with space for a catch")
		_finish_feedback_cast()
		_sack.store(entry.label, entry.value, entry.is_fish, entry.art)
		help.pressed.emit()


func _cast_for_feedback(point: Vector2) -> void:
	var click: InputEventMouseButton = _click()
	click.position = _rod.get_canvas_transform() * point
	_rod._unhandled_input(click)


func _finish_feedback_cast() -> void:
	_check(_rod.state == FishingRod.State.CASTING, "Full Sack changed whether a valid cast could start")
	_rod._process(_rod.cast_duration)
	_rod._unhandled_input(_click())
	_rod._process(_rod.retrieval_duration)


func _earn(amount: int) -> void:
	for trip: int in range(5):
		if _shop.coins >= amount:
			return
		for index: int in _sack.free_slots:
			_catch_one()
		_sell_at_shack()
	_check(_shop.coins >= amount, "Trash income did not fund gear")


func _sell_at_shack() -> void:
	var shack: FishingShack = _world.get_node("FishingShack")
	_player.global_position = shack.global_position
	_shack_key()
	_check(_panel.visible, "Shack failed to open with a load")
	TraderFixture.select_all(_panel)
	_panel.get_node("%ConfirmSale").pressed.emit()
	_shack_key()
	_check(not _panel.visible, "E failed to close the shop")


func _align_targets(target: Vector2) -> void:
	_replenish(2)
	for item: OceanTrash in _manager.items:
		item.global_position.y = 100
	_manager.items[0].global_position = target
	_manager.items[1].global_position = target - Vector2(100, 0)
	_place_on_shore(target.y)


func _catch_one() -> void:
	_replenish(1)
	var target: Vector2 = Vector2(_world.shore_start.x + 160.0, 450.0)
	for item: OceanTrash in _manager.items:
		item.global_position.y = 100.0
	_manager.items[0].global_position = target
	_place_on_shore(target.y)
	_cast_and_retrieve(target)


func _replenish(count: int) -> void:
	for attempt: int in range(12):
		if _manager.items.size() >= count:
			break
		_manager._physics_process(_manager.arrival_interval)
	for item: OceanTrash in _manager.items:
		item._physics_process(60.0)
		item.set_physics_process(false)


func _place_on_shore(y: float) -> void:
	var offset: Vector2 = _rod.global_position - _player.global_position
	_player.global_position = Vector2(_world.shore_start.x, y) - offset


func _cast_and_retrieve(point: Vector2) -> void:
	_check(_rod.invalid_target_reason(point).is_empty(), "Invalid cast in shop fixture")
	_rod._start_cast(point)
	_rod._process(_rod.cast_duration)
	_rod._unhandled_input(_click())
	_rod._process(_rod.retrieval_duration)


func _shack_key() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	_session._unhandled_input(key)


func _click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click
