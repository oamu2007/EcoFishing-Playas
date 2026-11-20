extends SceneTree

const SESSION_SCENE: PackedScene = preload("res://scenes/gameplay/session.tscn")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var session: Node = SESSION_SCENE.instantiate()
	root.add_child(session)
	var world: LevelScript = session.get_node("World")
	var player: CharacterBody2D = world.get_node("Player")
	var rod: FishingRod = world.rod
	var manager: TrashManager = world.trash_manager
	var pollution: PollutionSystem = world.pollution
	var notification: Label = session.get_node("HUD/Notification")
	var meter: ProgressBar = session.get_node("HUD/ProgressPanel/Margin/Readouts/PollutionBar")
	manager.arrivals_enabled = false
	world.sack.expand(manager.maximum_active_items)
	rod.set_process(false)
	player.set_physics_process(false)
	_check(manager.items.size() == 6 and pollution.current_pollution == 100, "Unexpected starting load")
	var replay: Node = SESSION_SCENE.instantiate()
	root.add_child(replay)
	var replay_manager: TrashManager = replay.get_node("World/TrashManager")
	var kinds: Dictionary[int, bool] = {}
	var rod_offset: Vector2 = rod.global_position - player.global_position
	var original_items: Array[OceanTrash] = manager.items.duplicate()
	for index: int in original_items.size():
		var item: OceanTrash = original_items[index]
		var point: Vector2 = item.global_position
		item.set_physics_process(false)
		kinds[item.kind] = true
		_check(point == replay_manager.items[index].global_position, "Opening load is not reproducible")
		_check(rod.water_bounds.grow(-item.catch_radius).has_point(point), "Starting trash outside water")
		_check(rod.invalid_target_reason_from(Vector2(world.shore_start.x, point.y), point).is_empty(), "Starting item unreachable")
		item._process(0.5)
		_check(item.global_position == point, "Bobbing moved catch geometry")
		for other: OceanTrash in original_items:
			if other != item:
				_check(point.distance_to(other.global_position) >= manager.minimum_spacing, "Initial items overlap")
	replay.free()
	_check(kinds.size() == 3, "Starting load lacks trash types")

	var first: OceanTrash = original_items[0]
	var second: OceanTrash = original_items[1]
	var first_id: int = first.get_instance_id()
	var target: Vector2 = Vector2(world.shore_start.x + 190.0, 450.0)
	for index: int in original_items.size():
		original_items[index].global_position = Vector2(world.shore_start.x + 130.0, 200.0 + 80.0 * index)
	first.global_position = target - Vector2(5, 0)
	second.global_position = target - Vector2(20, 0)
	player.global_position = Vector2(world.shore_start.x, target.y) - rod_offset
	_check(not rod.invalid_target_reason(target + Vector2(100, 0)).is_empty(), "Starter reached offshore band")
	_cast(rod, target)
	_check(first.hooked and not second.hooked, "Landing did not select nearest trash")
	rod.target_detected.emit(second)
	rod.hook_landed.emit(target)
	_check(pollution.current_pollution == 100 and notification.text.begins_with("Hooked"), "Landing feedback or accounting incorrect")
	pollution.register_trash(-1, 5)
	_check(notification.text.begins_with("Hooked"), "Arrival reset cast feedback")
	pollution.collect(-1)
	_retrieve(rod)
	_check(first.collected and not second.collected, "Starter sweep exceeded one catch")
	_check(pollution.current_pollution == 95 and meter.value == 95.0, "Pollution and HUD did not update on return")
	_check(not pollution.collect(first_id) and not first.finish_collection(), "Duplicate collection accepted")
	rod.retrieval_completed.emit(target)
	_check(notification.text.begins_with("Collected"), "Duplicate completion replaced catch feedback")
	await process_frame
	_check(not is_instance_valid(first), "Returned item was not freed")
	for item: OceanTrash in manager.items.duplicate():
		player.global_position = Vector2(world.shore_start.x, item.global_position.y) - rod_offset
		_cast(rod, item.global_position)
		_retrieve(rod)
	_check(manager.items.is_empty() and pollution.floating_points == 0, "Floating contribution did not clear")
	_check(pollution.current_pollution == 70 and not session.has_node("HUD/Completion"), "An empty shore counted as completion")
	player.global_position = Vector2(world.shore_start.x, target.y) - rod_offset
	_cast(rod, target)
	_retrieve(rod)
	_check(notification.text.begins_with("Nothing caught") and meter.value == 70.0, "Empty cast changed progress or omitted feedback")
	_check(pollution.remove_permanent(-1) == 0 and pollution.remove_permanent(12) == 12, "Permanent reduction invalid")
	_check(meter.value == 58.0 and pollution.remove_permanent(999) == 58 and meter.value == 0.0, "Permanent contribution did not clamp to zero")
	pollution.register_trash(-2, 100)
	_check(pollution.current_pollution == 30 and not pollution.register_trash(-2, 5), "Floating limit or duplicate registration failed")
	session.free()
	print("Cleanup smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _cast(rod: FishingRod, target: Vector2) -> void:
	_check(rod.invalid_target_reason(target).is_empty(), "Invalid fixture cast")
	rod._start_cast(target)
	rod._process(rod.cast_duration)


func _retrieve(rod: FishingRod) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	rod._unhandled_input(click)
	rod._process(rod.retrieval_duration)
	_check(rod.state == FishingRod.State.IDLE, "Retrieval failed to return to idle")
