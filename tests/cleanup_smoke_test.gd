extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/gameplay/main.tscn")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")

var _failures: int = 0
var _completion_count: int = 0
var _change_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	root.add_child(main)
	# Drift is tested separately; keep this original spawn/catch fixture stationary.
	for item: OceanTrash in (main.get_node("World/TrashManager") as TrashManager).items:
		item.set_physics_process(false)
	await process_frame
	var level: LevelScript = main.get_node("World")
	var player: CharacterBody2D = level.get_node("Player")
	var rod: FishingRod = player.get_node("FishingRod")
	var manager: TrashManager = level.trash_manager
	var pollution: PollutionSystem = level.pollution
	rod.set_process(false)
	player.set_physics_process(false)
	var original_count: int = manager.items.size()
	_check(original_count == 24, "Default batch did not spawn 24 items")
	_check(original_count <= manager.maximum_active_items, "Exceeded active item cap")
	_check(pollution.remaining_trash == original_count, "Pollution registration count mismatch")
	_check(pollution.normalized_pollution == 1.0, "Initial pollution is not 100 percent")
	var kinds: Dictionary[int, bool] = {}
	var total_value: int = 0
	var rod_offset: Vector2 = rod.global_position - player.global_position
	for item: OceanTrash in manager.items:
		kinds[item.kind] = true
		total_value += item.pollution_value
		var point: Vector2 = item.global_position
		_check(rod.water_bounds.grow(-item.catch_radius).has_point(point), "Trash geometry leaves ocean bounds")
		_check(point.x >= rod.water_bounds.position.x + manager.shoreline_clearance, "Trash too close to shoreline")
		var origin: Vector2 = Vector2(level.shore_start.x, point.y)
		player.global_position = origin - rod_offset
		_check(rod.invalid_target_reason(point).is_empty(), "Trash unreachable from shoreline")
		var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
		var body: Rect2 = player_shape.global_transform * player_shape.shape.get_rect()
		_check(body.end.x < 816.0 and body.position.y >= 0.0 and body.end.y <= 900.0, "Reachability origin intersects world collision")
		var ground: Vector2 = item.global_position
		item._process(0.5)
		_check(item.global_position == ground, "Bobbing moved catch geometry")
		for other: OceanTrash in manager.items:
			if other != item:
				_check(point.distance_to(other.global_position) >= manager.minimum_spacing, "Spawned trash overlaps")
	_check(kinds.size() == 3, "Batch lacks all three trash types")
	_check(total_value == pollution.initial_total_pollution, "Initial pollution sum mismatch")
	var replay: Node = MAIN_SCENE.instantiate()
	root.add_child(replay)
	var replay_manager: TrashManager = replay.get_node("World/TrashManager")
	_check(replay_manager.items.size() == original_count, "Seeded batch size differs")
	for index: int in range(mini(original_count, replay_manager.items.size())):
		_check(manager.items[index].global_position == replay_manager.items[index].global_position, "Same seed gives different spawn positions")
	replay.free()
	pollution.cleanup_completed.connect(func() -> void: _completion_count += 1)
	pollution.pollution_changed.connect(func(_normalized: float, _collected: int, _remaining: int) -> void: _change_count += 1)
	# Deliberately overlap two catch radii to exercise nearest selection.
	var first: OceanTrash = manager.items[0]
	var second: OceanTrash = manager.items[1]
	var second_position: Vector2 = second.global_position
	var landing: Vector2 = first.global_position + Vector2(5, 0)
	second.global_position = first.global_position + Vector2(20, 0)
	player.global_position = Vector2(level.shore_start.x, landing.y) - rod_offset
	var first_id: int = first.get_instance_id()
	_cast(rod, landing)
	_check(first.hooked and not second.hooked, "Catch did not select exactly the nearest item")
	_check(not first.collected and pollution.trash_collected == 0, "Landing removed or scored trash")
	rod.target_detected.emit(second)
	rod.hook_landed.emit(landing)
	_check(not second.hooked, "Repeated detection caught another item")
	second.global_position = second_position
	rod._unhandled_input(_click())
	rod._process(rod.retrieval_duration * 0.5)
	_check(first.get_parent() == rod.get_hook_attachment(), "Caught trash does not follow hook")
	_check(first.global_position.distance_to(rod.get_hook_attachment().global_position) < 30.0, "Caught trash detached during retrieval")
	_check(pollution.current_pollution == total_value, "Scored before successful return")
	rod._process(rod.retrieval_duration * 0.5)
	# The return path may now sweep additional trash; all removed values must match.
	var returned_count: int = original_count - manager.items.size()
	var remaining_value: int = 0
	for item: OceanTrash in manager.items:
		remaining_value += item.pollution_value
	_check(first.collected and pollution.trash_collected == returned_count and pollution.current_pollution == remaining_value, "Retrieval did not score correct values")
	_check(not pollution.collect(first_id), "Duplicate item scored twice")
	rod.retrieval_completed.emit(landing)
	_check(pollution.trash_collected == returned_count and _change_count == returned_count, "Repeated completion changed score")
	_check(not first.finish_collection(), "Duplicate trash removal accepted")
	await process_frame
	_check(not is_instance_valid(first), "Retrieved trash was not freed")
	# A reachable gap at the water's edge lies outside every spawned catch radius.
	var miss: Vector2 = Vector2(rod.water_bounds.position.x + 32.0, 450.0)
	player.global_position = Vector2(level.shore_start.x, miss.y) - rod_offset
	_check(rod.invalid_target_reason(miss).is_empty(), "Miss test uses an invalid cast")
	_cast(rod, miss)
	for item: OceanTrash in manager.items:
		_check(not item.hooked, "Miss caught trash outside its radius")
	_retrieve(rod)
	_check(pollution.trash_collected == returned_count and _change_count == returned_count, "Miss changed pollution")
	# Collect the whole finite batch through the existing state machine.
	for remaining_cast: int in range(original_count - 1):
		if manager.items.is_empty():
			break
		var item: OceanTrash = manager.items[0]
		player.global_position = Vector2(level.shore_start.x, item.global_position.y) - rod_offset
		_cast(rod, item.global_position)
		_check(item.hooked, "Remaining item was not caught")
		_retrieve(rod)
		await process_frame
	_check(pollution.current_pollution == 0 and pollution.normalized_pollution == 0.0, "Completed level remains polluted")
	_check(pollution.remaining_trash == 0 and pollution.trash_collected == original_count, "Final counts incorrect")
	_check(_completion_count == 1 and _change_count == original_count, "Pollution signals duplicated or missing")
	_check(main.get_node("HUD/Completion").visible, "HUD lacks completion message")
	await create_timer(0.1).timeout
	_check(manager.items.is_empty(), "Trash respawned after completion")
	main.free()
	_test_empty_and_capped_batches()
	print("Cleanup smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_empty_and_capped_batches() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	var manager: TrashManager = main.get_node("World/TrashManager")
	manager.initial_item_count = 10
	manager.maximum_active_items = 3
	root.add_child(main)
	_check(manager.items.size() == 3, "Configured item cap ignored")
	main.free()
	main = MAIN_SCENE.instantiate()
	manager = main.get_node("World/TrashManager")
	manager.initial_item_count = 0
	root.add_child(main)
	var model: PollutionSystem = main.get_node("World/PollutionSystem")
	_check(model.initial_total_pollution == 0 and model.current_pollution == 0, "Empty batch pollution nonzero")
	_check(model.normalized_pollution == 0.0 and model.remaining_trash == 0, "Empty batch normalization failed")
	_check(not model.collect(123), "Unknown item collected")
	_check(main.get_node("HUD/Completion").visible, "Empty level lacks completion UI")
	main.free()


func _cast(rod: FishingRod, target: Vector2) -> void:
	_check(rod.invalid_target_reason(target).is_empty(), "Test attempted an invalid target")
	rod._start_cast(target)
	rod._process(rod.cast_duration)
	_check(rod.state == FishingRod.State.WAITING, "Cast did not reach waiting state")


func _retrieve(rod: FishingRod) -> void:
	rod._unhandled_input(_click())
	rod._unhandled_input(_click())
	rod._process(rod.retrieval_duration)
	_check(rod.state == FishingRod.State.IDLE, "Retrieval did not return to idle")


func _click() -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event
