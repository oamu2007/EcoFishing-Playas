extends SceneTree

const MAIN: PackedScene = preload("res://scenes/gameplay/main.tscn")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")

var _failures: int = 0
var _main: Node
var _session: Node
var _world: LevelScript
var _player: CharacterBody2D
var _manager: TrashManager
var _shop: ShackShop
var _net: Node2D
var _meter: ProgressBar
var _interceptions: Dictionary[int, int] = {}
var _capture: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture-net") and DisplayServer.get_name() != "headless"
	if _capture:
		DirAccess.make_dir_recursive_absolute("res://.godot/offshore_net_captures")
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(800, 450)]:
		root.size = window_size
		_main = MAIN.instantiate()
		root.add_child(_main)
		_main.get_node("SessionMenu").get_node("%StartSession").pressed.emit()
		await process_frame
		_bind_session()
		_interceptions.clear()
		_manager.trash_intercepted.connect(_record_interception)
		var older: OceanTrash = _verify_live_rebound()
		var inbound: OceanTrash = _spawn_arrival()
		if older != null and inbound != null:
			await _verify_purchase()
			if _shop.offshore_net_installed:
				await _verify_interceptions(older, inbound)
				await _verify_reset()
		await _main.get_node("GameAudio").prepare_shutdown()
		_main.free()
		print("Offshore net checked at %s" % str(window_size))
	print("Offshore net smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _bind_session() -> void:
	_session = _main.get_node("Session")
	_world = _session.get_node("World")
	_player = _world.get_node("Player")
	_manager = _world.trash_manager
	_shop = _world.shop
	_net = _world.get_node("OffshoreNet")
	_meter = _session.get_node("HUD/ProgressPanel/Margin/Readouts/PollutionBar")
	_manager.set_physics_process(false)
	_player.set_physics_process(false)
	_world.catchable_fish.set_physics_process(false)
	for item: OceanTrash in _manager.items:
		item.set_physics_process(false)


func _verify_live_rebound() -> OceanTrash:
	_check(_shop.offshore_net_cost > 0 and not _shop.offshore_net_installed and not _net.visible, "New session did not start with a configured, uninstalled net")
	_check(_world.pollution.permanent_points == 70 and _world.pollution.floating_points == 30 and _meter.value == 100.0, "Early pollution did not use the 70/30 split")
	for item: OceanTrash in _manager.items.duplicate():
		item.attach_to(_world, Vector2.ZERO)
		item.finish_collection()
	_check(_world.pollution.floating_points == 0 and _meter.value == 70.0, "Clearing ordinary trash did not remove its floating contribution")
	var arrival: OceanTrash = _spawn_arrival()
	if arrival == null:
		return null
	_check(_world.pollution.floating_points == 0, "A pre-net arrival counted before reaching the ocean")
	arrival._physics_process(60.0)
	_check(arrival.in_water and not arrival.is_arriving and _manager.items.has(arrival), "Trash was intercepted with the net still locked")
	_check(_world.pollution.floating_points == arrival.pollution_value and _meter.value == 70.0 + arrival.pollution_value and _interceptions.is_empty(), "Pre-net arrival failed to restore floating pollution on its normal path")
	return arrival


func _verify_purchase() -> void:
	var trader: CanvasLayer = _session.get_node("ShackPanel")
	_player.global_position = _world.get_node("FishingShack").global_position
	_key(KEY_E)
	trader.get_node("%Buy").pressed.emit()
	await process_frame
	var catalog: ScrollContainer = trader.get_node("%BuyScroll")
	var offer: Control = trader.get_node("%OffshoreNetOffer")
	var buttons: Array[Node] = offer.find_children("*", "Button", true, false)
	if buttons.size() != 1:
		_check(false, "The trader did not create the net offer's purchase button")
		return
	var button: Button = buttons[0]
	var effect: String = ""
	for label: Label in offer.find_children("*", "Label", true, false):
		effect += label.text.to_lower() + " "
	var cost: int = _shop.offshore_net_cost
	_shop.coins = cost * 2
	for project: CleanupProject in _shop.cleanup_projects:
		_shop.coins += project.cost
	_shop.purchases_changed.emit()
	var funded: int = _shop.coins
	_check(offer.is_visible_in_tree() and button.disabled and button.text.contains("Locked") and button.text.contains(str(cost)) and effect.contains("all %d cleanup projects" % _shop.cleanup_projects.size()) and effect.contains("floating pollution"), "Locked net offer did not explain its price, unlock condition, and floating pollution effect")
	catalog.ensure_control_visible(offer)
	await process_frame
	_check(catalog.get_global_rect().encloses(offer.get_global_rect()), "The net offer is clipped at the bottom of the catalog")
	await _record_capture("offer")
	_check(not _shop.is_offshore_net_unlocked() and not _shop.buy_offshore_net() and _shop.coins == funded, "Net was available before cleanup")
	var last: int = _shop.cleanup_projects.size() - 1
	for index: int in last:
		_check(_shop.buy_cleanup(index), "Failed to fund a cleanup project in the test fixture")
	_check(button.disabled and not _shop.is_offshore_net_unlocked() and not _shop.buy_offshore_net(), "Net unlocked with a permanent project still unpurchased")
	_check(_shop.buy_cleanup(last) and _shop.is_offshore_net_unlocked(), "Completing the last permanent project did not unlock the net")
	_check(_world.pollution.permanent_points == 0 and _world.pollution.current_pollution > 0, "Final permanent purchase changed the floating load before the net")
	_shop.coins = cost - 1
	_shop.purchases_changed.emit()
	_check(button.disabled and not _shop.buy_offshore_net() and _shop.coins == cost - 1, "Unaffordable net purchase changed the wallet")
	_shop.coins = cost
	_shop.purchases_changed.emit()
	catalog.ensure_control_visible(button)
	await process_frame
	_check(not button.disabled and button.text.contains(str(cost)) and catalog.get_global_rect().encloses(button.get_global_rect()), "Configured net price was unavailable or clipped")
	for slot: int in _world.sack.free_slots:
		_check(_world.sack.store("Fixture trash", slot + 1, false), "Could not fill the Sack before installing the net")
	button.pressed.emit()
	_check(_shop.offshore_net_installed and _shop.coins == 0 and _net.is_visible_in_tree() and button.disabled, "Net purchase did not install once at its configured price")
	_check(_interceptions.is_empty(), "Installation credited an existing piece before it crossed the net")
	_check_zero_pollution()
	_shop.coins = cost
	_shop.purchases_changed.emit()
	_check(not _shop.buy_offshore_net() and _shop.coins == cost and button.disabled, "Installed net could be purchased twice")
	trader.get_node("%Close").pressed.emit()
	await process_frame
	_check(not trader.visible, "The trader did not return to the shore after purchase")


func _verify_interceptions(older: OceanTrash, inbound: OceanTrash) -> void:
	var shore_mid_y: float = (_world.shore_start.y + _world.shore_end.y) * 0.5
	var rod_offset: Vector2 = _world.rod.global_position - _player.global_position
	_player.global_position = Vector2(_world.shore_start.x, shore_mid_y) - rod_offset
	var camera: Camera2D = _player.get_node("Camera2D")
	camera.reset_smoothing()
	camera.force_update_scroll()
	_ensure_net_in_view(shore_mid_y)
	if _capture:
		_player.global_position.y = inbound.global_position.y - rod_offset.y
		camera.reset_smoothing()
		camera.force_update_scroll()
		var water: WaterVisuals = _world.get_node("Environment/Water")
		await create_timer(water.transition_duration + 0.1).timeout
	inbound.sale_value = 5
	_verify_crossing(inbound)
	await process_frame
	await _record_capture("interception")
	_check(_manager.items.has(older) and older.can_hook(), "Net installation removed or disabled older shoreward trash")
	_check_zero_pollution()

	# A full group of old debris must still leave room for a new transit piece.
	_manager.maximum_active_items = _manager.items.size()
	var newcomer: OceanTrash = _spawn_arrival()
	if newcomer == null:
		return
	newcomer.sale_value = 8
	_check(not newcomer.in_water and newcomer.global_position.x > _world.rod.water_bounds.end.x, "Post-net arrival skipped the offscreen approach")
	var departure: Vector2 = newcomer.global_position
	var expected_coins: int = _shop.coins
	_key(KEY_ESCAPE)
	newcomer.set_physics_process(true)
	for frame: int in 3:
		await physics_frame
	_check(_main.get_node("PauseMenu").visible and newcomer.global_position.is_equal_approx(departure) and _shop.coins == expected_coins, "Pause advanced net collection or changed the balance")
	newcomer.set_physics_process(false)
	_key(KEY_ESCAPE)
	_check(not _main.get_node("PauseMenu").visible and _shop.offshore_net_installed, "Resume lost the installed net")
	var fixed_position: Vector2 = _net.global_position
	_player.global_position = _world.get_node("FishingShack").global_position
	camera.reset_smoothing()
	camera.force_update_scroll()
	_verify_crossing(newcomer)
	_check(_net.global_position == fixed_position and _manager.items.has(older), "Moving the camera changed the net or removed old debris")
	_check_zero_pollution()


func _verify_crossing(item: OceanTrash) -> void:
	var item_id: int = item.get_instance_id()
	var value: int = item.sale_price()
	var coins: int = _shop.coins
	var approach: float = (item.global_position.x - _net.global_position.x - 1.0) / _manager.arrival_speed
	_check(approach > 0.0, "The arriving piece did not start seaward of the net")
	item._physics_process(maxf(0.0, approach))
	_check(_manager.items.has(item) and _shop.coins == coins and not _interceptions.has(item_id), "The net paid for a piece before it reached the net")
	_check_zero_pollution()
	item._physics_process(1.0)
	_check(not _manager.items.has(item) and item.is_queued_for_deletion() and _interceptions.get(item_id, -1) == value and _shop.coins == coins + value, "Crossing did not remove the trash and credit its exact sale value once")
	var sale_cue: Label = _net.get_node("SaleCue")
	_check(sale_cue.is_visible_in_tree() and sale_cue.text.begins_with("+") and sale_cue.text.ends_with("gold"), "Interception did not show the short gold cue")
	item._physics_process(1.0)
	_manager._physics_process(0.0)
	_check(_shop.coins == coins + value and _world.sack.free_slots == 0, "Crossing paid again or used Sack capacity")


func _verify_reset() -> void:
	_key(KEY_ESCAPE)
	var pause: CanvasLayer = _main.get_node("PauseMenu")
	var session_id: int = _session.get_instance_id()
	pause.get_node("%Restart").pressed.emit()
	pause.get_node("%ConfirmDiscard").pressed.emit()
	await process_frame
	_bind_session()
	_check(_session.get_instance_id() != session_id and not _shop.offshore_net_installed and not _shop.is_offshore_net_unlocked() and not _net.visible, "Start fresh retained the offshore investment")
	_check(_shop.coins == 0 and _world.sack.item_count == 0 and _world.pollution.permanent_points == 70 and _world.pollution.floating_points == 30 and _meter.value == 100.0, "Start fresh retained net revenue or pollution settings")


func _spawn_arrival() -> OceanTrash:
	var count: int = _manager.items.size()
	_manager._physics_process(_manager.arrival_interval)
	if _manager.items.size() != count + 1:
		_check(false, "The arrival manager did not spawn one incoming piece")
		return null
	var item: OceanTrash = _manager.items.back()
	item.set_physics_process(false)
	return item


func _record_interception(item: OceanTrash, sale_value: int) -> void:
	var item_id: int = item.get_instance_id()
	_check(not _interceptions.has(item_id), "One item emitted two interception events")
	_interceptions[item_id] = sale_value


func _check_zero_pollution() -> void:
	var pollution: PollutionSystem = _world.pollution
	_check(pollution.floating_points == 0 and pollution.current_pollution == 0 and pollution.normalized_pollution == 0.0 and _meter.value == 0.0, "Installed net did not hold game and HUD pollution at zero")
	var fish: CatchableFishManager = _world.catchable_fish
	_check(is_equal_approx(fish.spawn_chance(pollution.normalized_pollution), fish.clean_spawn_chance), "Clean-water fish spawn conditions did not persist")


func _ensure_net_in_view(shore_mid_y: float) -> void:
	var net_center: Vector2 = Vector2(_net.global_position.x, shore_mid_y)
	var screen_position: Vector2 = _net.get_canvas_transform() * net_center
	_check(root.get_visible_rect().has_point(screen_position), "The installed net center is outside the middle shoreline view")


func _record_capture(phase: String) -> void:
	if not _capture:
		return
	await RenderingServer.frame_post_draw
	var path: String = "res://.godot/offshore_net_captures/%dx%d_%s.png" % [root.size.x, root.size.y, phase]
	_check(root.get_texture().get_image().save_png(path) == OK, "Could not save the %s net capture" % phase)


func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
