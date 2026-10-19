extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/gameplay/main.tscn")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const HudScript = preload("res://scripts/ui/hud.gd")

var _failures: int = 0
var _hook_events: int = 0
var _score_events: int = 0
var _completion_events: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _fixture(count: int) -> Node:
	var main: Node = MAIN_SCENE.instantiate()
	var manager: TrashManager = main.get_node("World/TrashManager")
	manager.initial_item_count = count
	root.add_child(main)
	for item: OceanTrash in manager.items:
		item.set_physics_process(false)
	main.get_node("World/Player").set_physics_process(false)
	main.get_node("World/Player/FishingRod").set_process(false)
	return main


func _run() -> void:
	_test_drift()
	var main: Node = _fixture(6)
	var level: LevelScript = main.get_node("World")
	var rod: FishingRod = main.get_node("World/Player/FishingRod")
	var player: CharacterBody2D = main.get_node("World/Player")
	var hud: HudScript = main.get_node("HUD")
	var model: PollutionSystem = level.pollution
	var manager: TrashManager = level.trash_manager
	var items: Array[OceanTrash] = manager.items.duplicate()
	var positions: Array[Vector2] = [Vector2(1160, 450), Vector2(1070, 450), Vector2(960, 450), Vector2(1070, 485), Vector2(1220, 450), Vector2(970, 700)]
	for index: int in range(items.size()):
		items[index].global_position = positions[index]
	var rod_offset: Vector2 = rod.global_position - player.global_position
	player.global_position = Vector2(level.shore_start.x, 450) - rod_offset
	var item_ids: Array[int] = []
	for item: OceanTrash in items:
		item_ids.append(item.get_instance_id())
	manager.trash_hooked.connect(func(_type: String) -> void: _hook_events += 1)
	model.pollution_changed.connect(func(_n: float, _c: int, _r: int) -> void: _score_events += 1)
	model.cleanup_completed.connect(func() -> void: _completion_events += 1)
	var states: Array[int] = []
	rod.state_changed.connect(func(state: FishingRod.State) -> void: states.append(state))
	_cast(rod, positions[0])
	_check(items[0].hooked and _hook_events == 1, "Landing did not retain single-item selection")
	_check(model.trash_collected == 0, "Landing scored prematurely")
	rod._unhandled_input(_click())
	var from: Vector2 = rod.get_hook_water_position()
	rod._process(rod.retrieval_duration * 0.5)
	var to: Vector2 = rod.get_hook_water_position()
	var hook: FishingHook = rod.get_node("FishingHook")
	var radius: float = items[1].catch_radius + hook.get_collision_radius()
	_check(positions[1].distance_to(from) > radius and positions[1].distance_to(to) > radius, "Sweep fixture endpoints are too close")
	_check(items[1].hooked and not items[2].hooked, "Swept segment missed the intermediate item")
	_check(not items[3].hooked and not items[4].hooked, "Hook caught trash outside swept disks/segment")
	_check(items[0].position != items[1].position, "Attached items overlap at the same offset")
	_check(items[1].get_parent() == rod.get_hook_attachment(), "Swept item did not attach to hook")
	_check(model.current_pollution == model.initial_total_pollution and _score_events == 0, "Mid-return catch scored prematurely")
	rod.retrieval_advanced.emit(from, to, hook.get_collision_radius())
	rod._unhandled_input(_click())
	_check(_hook_events == 2 and rod.state == FishingRod.State.RETRIEVING, "Duplicate sweep/click changed attachment or state")
	rod._process(rod.retrieval_duration * 0.5)
	_check(model.trash_collected == 3 and model.current_pollution == 45 and model.remaining_trash == 3, "Batch score/value incorrect")
	_check(_score_events == 3 and _hook_events == 3, "Batch signals duplicated or missing")
	_check(states == [FishingRod.State.CASTING, FishingRod.State.WAITING, FishingRod.State.RETRIEVING, FishingRod.State.IDLE], "Fishing states changed")
	_check(hud.get_node("Notification").text == "Collected 3 items", "Batch notification is not aggregated")
	rod.retrieval_completed.emit(positions[0])
	for index: int in range(3):
		_check(not model.collect(item_ids[index]), "Duplicate batch item scored")
		_check(not items[index].finish_collection(), "Duplicate batch item removed")
	_check(_score_events == 3, "Repeated batch completion changed pollution")
	# An empty landing may still pick up an item farther along the return path.
	player.global_position = Vector2(level.shore_start.x, 485) - rod_offset
	_cast(rod, Vector2(1190, 485))
	_check(_hook_events == 3, "Supposedly empty landing caught an item")
	rod._unhandled_input(_click())
	rod._process(10.0)
	_check(items[3].collected and model.trash_collected == 4 and _score_events == 4, "Empty landing failed to sweep trash on return")
	# Entire empty path is near shore and far from every remaining item.
	player.global_position = Vector2(level.shore_start.x, 100) - rod_offset
	_cast(rod, Vector2(900, 100))
	rod._unhandled_input(_click())
	rod._process(10.0)
	_check(_score_events == 4 and model.trash_collected == 4, "Empty return changed pollution")
	# One-frame returns exercise the final swept segment before scoring.
	for attempt: int in range(3):
		if manager.items.is_empty():
			break
		var item: OceanTrash = manager.items[0]
		player.global_position = Vector2(level.shore_start.x, item.global_position.y) - rod_offset
		_cast(rod, item.global_position)
		rod._unhandled_input(_click())
		rod._process(10.0)
	_check(model.current_pollution == 0 and model.trash_collected == 6 and manager.items.is_empty(), "Full batch failed to complete")
	_check(model.normalized_pollution == 0.0 and _completion_events == 1 and _score_events == 6, "Completion accounting/signals incorrect")
	_check(hud.get_node("Completion").visible, "Completion message missing")
	_check(not hud.get_node("ControlsPanel").visible, "Detailed controls shown by default")
	var help_event: InputEventKey = InputEventKey.new()
	help_event.physical_keycode = KEY_H
	help_event.pressed = true
	hud._unhandled_input(help_event)
	_check(hud.get_node("ControlsPanel").visible, "H did not open help")
	help_event.echo = true
	hud._unhandled_input(help_event)
	_check(hud.get_node("ControlsPanel").visible, "Key repeat toggled help")
	help_event.echo = false
	hud._unhandled_input(help_event)
	_check(not hud.get_node("ControlsPanel").visible, "H did not close help")
	await process_frame
	_check(hud.get_node("ProgressPanel").size.x < 320.0 and hud.get_node("ProgressPanel").size.y <= 60.0, "HUD panel is not compact")
	main.free()
	print("Refinement smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_drift() -> void:
	var main: Node = _fixture(24)
	var replay: Node = _fixture(24)
	var level: LevelScript = main.get_node("World")
	var rod: FishingRod = main.get_node("World/Player/FishingRod")
	var manager: TrashManager = level.trash_manager
	var replay_manager: TrashManager = replay.get_node("World/TrashManager")
	var initial_positions: Array[Vector2] = []
	for item: OceanTrash in manager.items:
		initial_positions.append(item.global_position)
	var moved_up: bool = false
	var moved_down: bool = false
	for step: int in range(600):
		for index: int in range(manager.items.size()):
			var item: OceanTrash = manager.items[index]
			var before: Vector2 = item.global_position
			item._physics_process(0.5)
			replay_manager.items[index]._physics_process(0.5)
			var point: Vector2 = item.global_position
			if step == 0:
				moved_up = moved_up or point.y < before.y
				moved_down = moved_down or point.y > before.y
			_check(point == replay_manager.items[index].global_position, "Seeded drift is not reproducible")
			_check(point.x == initial_positions[index].x and absf(point.y - before.y) <= item.drift_speed * 0.5 + 0.001, "Drift jumped or moved horizontally")
			_check(rod.water_bounds.grow(-item.catch_radius).has_point(point), "Drifting item left water bounds")
			_check(point.x >= rod.water_bounds.position.x + manager.shoreline_clearance, "Drift crossed shoreline clearance")
			var origin: Vector2 = Vector2(level.shore_start.x, clampf(point.y, level.shore_start.y, level.shore_end.y))
			_check(rod.invalid_target_reason_from(origin, point).is_empty(), "Drift made trash unreachable")
			var collider: CollisionShape2D = item.get_node("CollisionShape2D")
			_check(collider.global_position == point, "Collision did not move with drift")
	_check(moved_up and moved_down, "Seeded currents lack both directions")
	# Explicit smooth turnaround: velocity must approach zero before reversing.
	var item: OceanTrash = manager.items[0]
	item.global_position.y = 150.0
	item.configure_drift(Vector2(100, 200), 6.0, PI * 0.5)
	var last_velocity: float = -6.0
	var turned: bool = false
	for step: int in range(1700):
		var previous_y: float = item.global_position.y
		item._physics_process(1.0 / 60.0)
		var velocity: float = (item.global_position.y - previous_y) * 60.0
		if last_velocity < 0.0 and velocity > 0.0:
			turned = true
			_check(absf(last_velocity) < 0.05 and absf(velocity) < 0.05, "Boundary reversal was abrupt")
		last_velocity = velocity
	_check(turned, "Drift never reversed direction")
	main.free()
	replay.free()


func _cast(rod: FishingRod, target: Vector2) -> void:
	_check(rod.invalid_target_reason(target).is_empty(), "Invalid test cast")
	rod._start_cast(target)
	rod._process(rod.cast_duration)


func _click() -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event
