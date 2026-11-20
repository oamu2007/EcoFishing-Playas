extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/gameplay/main.tscn")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const HudScript = preload("res://scripts/ui/hud.gd")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	var manager: TrashManager = main.get_node("World/TrashManager")
	manager.initial_item_count = 0
	root.add_child(main)
	var world: LevelScript = main.get_node("World")
	var hud: HudScript = main.get_node("HUD")
	var rod: FishingRod = world.rod
	manager.set_physics_process(false)
	var stops: Dictionary[Vector2, bool] = {}
	var far_count: int = 0
	for turn: int in range(18):
		var size_before: int = manager.items.size()
		manager._physics_process(manager.arrival_interval)
		if manager.items.size() == size_before:
			continue
		var item: OceanTrash = manager.items.back()
		item.set_physics_process(false)
		var stop: Vector2 = item.drift_stop_position()
		_check(item.global_position.x > rod.water_bounds.end.x and not item.in_water, "Arrival did not begin offshore")
		_check(world.pollution.remaining_trash == size_before, "Offscreen trash polluted before entering water")
		for step: int in range(240):
			var before: Vector2 = item.global_position
			item._physics_process(item._travel_time / 239.0)
			_check(item.global_position.x <= before.x + 0.001 and absf(item.global_position.x - before.x) < 10.0, "Arrival jumped or moved offshore")
		_check(item.global_position.is_equal_approx(stop) and item.in_water and not item.is_arriving, "Arrival did not settle into drift")
		_check(world.pollution.remaining_trash == size_before + 1, "Arrival failed to register exactly once")
		_check(rod.water_bounds.grow(-item.catch_radius).has_point(stop), "Arrival stop outside water")
		stops[stop] = true
		var origin: Vector2 = Vector2(world.shore_start.x, stop.y)
		if not rod.invalid_target_reason_from(origin, stop).is_empty():
			far_count += 1
	_check(stops.size() == manager.maximum_active_items and far_count == manager.maximum_active_items - manager.starter_slots, "Cap did not preserve distinct starter and offshore supply")

	for step: int in range(600):
		for item: OceanTrash in manager.items:
			var before: Vector2 = item.global_position
			item._physics_process(0.5)
			var point: Vector2 = item.global_position
			_check(point.x == before.x and absf(point.y - before.y) <= item.drift_speed * 0.5 + 0.01, "Settled drift jumped")
			_check(rod.water_bounds.grow(-item.catch_radius).has_point(point), "Settled drift left water")
	var item: OceanTrash = manager.items[0]
	var target: Vector2 = item.global_position
	var player: CharacterBody2D = world.get_node("Player")
	var offset: Vector2 = rod.global_position - player.global_position
	player.global_position = Vector2(world.shore_start.x, target.y) - offset
	rod.set_process(false)
	# Make two more reachable targets on the swept segment, with a clear landing.
	var aligned: OceanTrash = manager.items[1]
	var near: OceanTrash = manager.items[2]
	for other: OceanTrash in manager.items:
		other.global_position.y = 90.0 if target.y > 450.0 else 810.0
	target.x = world.shore_start.x + 230.0
	item.global_position = target - Vector2(67, 0)
	aligned.global_position = target - Vector2(127, 0)
	near.global_position = aligned.global_position + Vector2(0, 55)
	rod._start_cast(target)
	rod._process(rod.cast_duration)
	_check(not item.hooked and not aligned.hooked, "Clear landing caught a target")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	rod._unhandled_input(click)
	rod._process(rod.retrieval_duration)
	_check(world.pollution.trash_collected == 1 and not near.collected, "Fast sweep exceeded starter limit or caught a near miss")
	manager._physics_process(manager.arrival_interval)
	_check(manager.items.size() == manager.maximum_active_items and manager._starter_items.size() == manager.starter_slots, "Offshore buildup blocked starter replenishment")

	var help: PanelContainer = hud.get_node("ControlsPanel")
	var help_event: InputEventKey = InputEventKey.new()
	help_event.physical_keycode = KEY_H
	help_event.pressed = true
	_check(not help.visible, "Help visible by default")
	hud._unhandled_input(help_event)
	_check(help.visible, "H did not open help")
	help_event.echo = true
	hud._unhandled_input(help_event)
	_check(help.visible, "Key repeat closed help")
	help_event.echo = false
	hud._unhandled_input(help_event)
	_check(not help.visible, "H did not close help")
	await process_frame
	_check(hud.get_node("ProgressPanel").size.x < 320.0 and hud.get_node("ProgressPanel").size.y <= 60.0, "HUD is no longer compact")
	main.free()
	print("Refinement smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)
