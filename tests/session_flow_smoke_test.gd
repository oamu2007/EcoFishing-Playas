extends SceneTree

const MainScene: PackedScene = preload("res://scenes/gameplay/main.tscn")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const PlayerScript = preload("res://scripts/gameplay/player.gd")
const TraderFixture = preload("res://tests/trader_fixture.gd")
const CleanupSite = preload("res://scripts/gameplay/cleanup_site.gd")

var _failures: int = 0
var _main: Node
var _menu: CanvasLayer
var _start: Button
var _resume: Button


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	_main = MainScene.instantiate()
	root.add_child(_main)
	_menu = _main.get_node("SessionMenu")
	_start = _menu.get_node("%StartSession")
	_resume = _menu.get_node("%Resume")
	await process_frame
	_check(_menu.visible and _start.has_focus() and not _main.has_node("Session"), "Launch did not focus Start before creating gameplay")
	_press_button(_start)
	_start.pressed.emit()
	await process_frame
	var session: Node = _main.get_node_or_null("Session")
	if session == null:
		_check(false, "Start click did not open a session")
		_finish()
		return
	var world: LevelScript = session.get_node("World")
	var opening_positions: Array[Vector2] = []
	for item: OceanTrash in world.trash_manager.items:
		opening_positions.append(item.global_position)
	_check_fresh(world)
	await _verify_onboarding(session, world)
	for reset: int in 2:
		var previous_world_id: int = world.get_instance_id()
		_key(KEY_ESCAPE)
		await process_frame
		_check(_menu.visible and _resume.has_focus() and _start.text == "Start fresh", "Pause menu did not show labeled resume and reset actions")
		_press_button(_start)
		_start.pressed.emit()
		await process_frame
		session = _main.get_node_or_null("Session")
		if session == null:
			_check(false, "Start fresh did not create a replacement session")
			break
		world = session.get_node("World")
		_check(not _menu.visible and world.get_instance_id() != previous_world_id and _main.get_child_count() == 2, "Repeated activation replaced the session twice or retained the old tree")
		_check_fresh(world)
		for index: int in world.trash_manager.items.size():
			_check(world.trash_manager.items[index].global_position.distance_to(opening_positions[index]) < 3.0, "Seeded starting position did not reset")
		if reset == 0:
			# Dirty a second session to make the second reset meaningful.
			world.sack.store("Test catch", 4, false)
			world.shop.sell_all()
			world.pollution.remove_permanent(55)
			world.trash_manager._physics_process(world.trash_manager.arrival_interval)
	_finish()


func _verify_onboarding(session: Node, world: LevelScript) -> void:
	var hud: CanvasLayer = session.get_node("HUD")
	var hint: Label = hud.get_node("Hint")
	var rod: FishingRod = world.rod
	var player: PlayerScript = world.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	var shop_panel: CanvasLayer = session.get_node("ShackPanel")
	var shack: FishingShack = world.get_node("FishingShack")
	var sack: Sack = world.sack
	_check(hint.text.begins_with("Move right"), "Opening guidance did not point to the shoreline")
	_press_button(hud.get_node("HelpKey"))
	_check(hud.get_node("ControlsPanel").visible, "Help button did not open detailed controls")
	_key(KEY_H)
	_check(not hud.get_node("ControlsPanel").visible, "H did not close detailed controls")
	rod.set_process(false)
	player.set_physics_process(false)
	world.trash_manager.set_physics_process(false)
	world.trash_manager.starter_slots = world.trash_manager.maximum_active_items
	for item: OceanTrash in world.trash_manager.items:
		item.set_physics_process(false)
	root.size = Vector2i(800, 450)
	await process_frame
	var offset: Vector2 = rod.global_position - player.global_position
	var miss: Vector2 = Vector2(world.shore_start.x + 76.0, 430.0)
	player.global_position = Vector2(world.shore_start.x, miss.y) - offset
	camera.reset_smoothing()
	camera.force_update_scroll()
	await process_frame
	_check(hint.text.begins_with("Aim at floating trash"), "Shoreline prompt did not advance to casting")
	if not _begin_cast(rod, miss):
		return
	await process_frame
	_check(hint.text.contains("reel in"), "Onboarding omitted retrieval cue")
	_press_button(hud.get_node("MenuButton"))
	_check(_menu.visible and rod.state == FishingRod.State.WAITING, "Menu click reeled in the waiting hook")
	await process_frame
	_mouse_click(Vector2(928, 520))
	_check(rod.state == FishingRod.State.WAITING, "Click on the pause backdrop reached fishing")
	_press_button(_resume)
	_check(not _menu.visible and rod.state == FishingRod.State.WAITING, "Resume click reeled in the waiting hook")
	_finish_cast(rod, miss)
	_check(hud.get_node("Notification").text.begins_with("Nothing caught"), "Miss feedback did not explain the empty return")

	for trip: int in 6:
		for slot: int in sack.capacity:
			if world.trash_manager.items.is_empty():
				world.trash_manager._physics_process(world.trash_manager.arrival_interval)
				world.trash_manager.items.front()._physics_process(world.trash_manager.arrival_travel_time)
			var item: OceanTrash = world.trash_manager.items.front()
			item.set_physics_process(false)
			var target: Vector2 = item.global_position
			player.global_position = Vector2(world.shore_start.x, target.y) - offset
			camera.reset_smoothing()
			camera.force_update_scroll()
			if not _begin_cast(rod, target):
				return
			_finish_cast(rod, target)
		await process_frame
		_check(sack.free_slots == 0 and hint.text.contains("fishing shack"), "Full Sack cue did not point to turn-in")
		player.global_position = shack.global_position
		camera.reset_smoothing()
		camera.force_update_scroll()
		_key(KEY_E)
		await process_frame
		var sell: Button = shop_panel.get_node("%Sell")
		_check(shop_panel.visible and sell.has_focus() and rod.state == FishingRod.State.IDLE, "Shop did not open with keyboard focus")
		TraderFixture.select_all(shop_panel)
		await process_frame
		_press_button(shop_panel.get_node("%ConfirmSale"))
		_check(shop_panel.visible and sack.item_count == 0 and rod.state == FishingRod.State.IDLE, "Selling leaked a click through to fishing")
		if trip == 0:
			_key(KEY_ESCAPE)
			await process_frame
			_check(not shop_panel.visible and not _menu.visible and hint.text.contains("first upgrade"), "Shop close or first upgrade guidance failed")
			_key(KEY_E)
			await process_frame
		if trip == 2:
			_press_button(shop_panel.get_node("%Back"))
			await process_frame
			_press_button(shop_panel.get_node("%Buy"))
			await process_frame
			var gear: Control = shop_panel.get_node("%Gear")
			_press_button(gear.find_children("*", "Button", true, false)[0])
			_check(world.shop.rod_tier == 1, "First upgrade did not respond to its shop control")
		elif trip == 5:
			_press_button(shop_panel.get_node("%Back"))
			await process_frame
			_press_button(shop_panel.get_node("%Buy"))
			await process_frame
			var projects: Control = shop_panel.get_node("%Cleanup")
			_press_button(projects.find_children("*", "Button", true, false)[0])
			_check(world.shop.is_cleanup_complete(0), "Cleanup purchase did not persist before restart")
		_press_button(shop_panel.get_node("%Close"))
		_check(not shop_panel.visible and rod.state == FishingRod.State.IDLE, "Shop close button triggered fishing")
	var site: CleanupSite = world.cleanup_work.get_child(0)
	_check(site.has_started and not site.is_complete and hud.get_node("Notification").text.contains("beach crew"), "Closing the trader did not start or announce cleanup work")
	await process_frame
	_key(KEY_ESCAPE)
	var progress: float = site.progress
	for frame: int in 3:
		await process_frame
	_check(_menu.visible and is_equal_approx(progress, site.progress), "The pause menu did not freeze active cleanup work")
	_key(KEY_ESCAPE)
	await process_frame


func _check_fresh(world: LevelScript) -> void:
	var player: CharacterBody2D = world.get_node("Player")
	var water: WaterVisuals = world.get_node("Environment/Water")
	_check(player.global_position.is_equal_approx(Vector2(520, 450)), "Player spawn did not reset")
	_check(world.shop.coins == 0 and world.shop.rod_tier == 0 and world.shop.sack_tier == 0, "Coins or gear survived reset")
	_check(world.sack.item_count == 0 and world.sack.capacity == 3, "Sack survived reset")
	_check(world.pollution.current_pollution == 100 and world.pollution.permanent_points == 70 and water.displayed_pollution == 1.0, "Pollution or water did not reset")
	_check(world.trash_manager.items.size() == 6 and world.trash_manager.arrivals_enabled and world.catchable_fish.fish.is_empty(), "Arrival state did not reset")
	for project: int in world.shop.cleanup_projects.size():
		_check(not world.shop.is_cleanup_complete(project), "Cleanup flag survived reset")


func _begin_cast(rod: FishingRod, target: Vector2) -> bool:
	var view_point: Vector2 = rod.get_canvas_transform() * target
	_mouse_click(view_point)
	_check(rod.state == FishingRod.State.CASTING, "Viewport aim did not cast at a reachable target")
	if rod.state != FishingRod.State.CASTING:
		return false
	rod._process(rod.cast_duration)
	_check(rod.get_hook_water_position().distance_to(target) < 2.0, "Hook missed the aimed world point after resize")
	return true


func _finish_cast(rod: FishingRod, target: Vector2) -> void:
	_mouse_click(rod.get_canvas_transform() * target)
	_check(rod.state == FishingRod.State.RETRIEVING, "Viewport click did not retrieve")
	rod._process(rod.retrieval_duration)
	_check(rod.state == FishingRod.State.IDLE, "Retrieval did not finish")


func _press_button(button: Button) -> void:
	_mouse_click(button.get_global_rect().get_center())


func _mouse_click(point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for is_pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_pressed
		root.push_input(click, true)


func _key(code: Key) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	root.push_input(key, true)


func _finish() -> void:
	_main.free()
	print("Session flow smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)
