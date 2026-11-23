extends SceneTree

const SESSION: PackedScene = preload("res://scenes/gameplay/session.tscn")
const WorldScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const PlayerScript = preload("res://scripts/gameplay/player.gd")

var _failures: int = 0
var _world: WorldScript
var _player: PlayerScript
var _camera: Camera2D


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(800, 450)]:
		root.size = window_size
		await process_frame
		var session: Node = SESSION.instantiate()
		_world = session.get_node("World")
		_world.get_node("TrashManager").initial_item_count = 0
		root.add_child(session)
		_player = _world.get_node("Player")
		_camera = _player.get_node("Camera2D")
		_player.set_physics_process(false)
		_world.rod.set_process(false)
		_world.trash_manager.set_physics_process(false)
		_world.catchable_fish.set_physics_process(false)
		_world.shop.coins = 100
		print("Offshore reach at %s" % str(window_size))
		var starter_reach: float = _world.rod.maximum_cast_range
		var previous_reach: float = starter_reach
		for tier: int in 3:
			if tier > 0:
				await _upgrade_during_arrival(tier - 1)
			_sample_trash_stops()
			await _test_fish_routes(tier, starter_reach, previous_reach)
			previous_reach = _world.rod.maximum_cast_range
		session.free()
	print("Offshore reach smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _sample_trash_stops() -> void:
	var trash: TrashManager = _world.trash_manager
	var shore_x: float = _world.shore_start.x
	var band: Vector2 = trash._reachable_stop_band()
	var m30_far_edge: float = shore_x + _world.rod.maximum_cast_range - 20.0
	var m30_near_edge: float = shore_x + _world.rod.maximum_cast_range - 95.0
	var counts: Vector3i = Vector3i.ZERO
	var sampled: Vector2 = Vector2(INF, -INF)
	for sample: int in 72:
		trash._physics_process(trash.arrival_interval)
		var item: OceanTrash = trash.items.back()
		var stop: Vector2 = item.drift_stop_position()
		var bucket: int = mini(2, floori(inverse_lerp(band.x, band.y, stop.x) * 3.0))
		counts[bucket] += 1
		sampled = Vector2(minf(sampled.x, stop.x), maxf(sampled.y, stop.x))
		_check(item.global_position.x > _world.rod.water_bounds.end.x and not item.can_hook(), "Arrival did not start offshore")
		item._physics_process(60.0)
		var origin: Vector2 = Vector2(shore_x, stop.y)
		_check(item.global_position.is_equal_approx(stop) and _world.rod.invalid_target_reason_from(origin, stop).is_empty(), "Trash settled outside castable water")
		_aim_from_shore(stop.y)
		_check(_on_screen(stop, item.catch_radius), "A settled piece or its cue was outside the shore-aligned view")
		if sample == 0:
			item._physics_process(1.0)
			_check(item.global_position.x == stop.x and absf(item.global_position.y - stop.y) <= item.drift_speed, "Current snapped away from the stop")
		_remove_trash(item)
	_check(counts.x > 0 and counts.y > 0 and counts.z > 0, "Seeded stops missed a third of the usable band")
	_check(sampled.x < m30_near_edge and sampled.y > m30_far_edge, "Visible stops did not extend shoreward and seaward from M30")
	print("  %.0f reach: visible X %.1f–%.1f, M30 %.0f–%.0f, thirds %s" % [_world.rod.maximum_cast_range, sampled.x, sampled.y, m30_near_edge, m30_far_edge, str(counts)])


func _upgrade_during_arrival(index: int) -> void:
	var trash: TrashManager = _world.trash_manager
	trash._physics_process(trash.arrival_interval)
	var item: OceanTrash = trash.items.back()
	item.set_physics_process(false)
	var old_stop: Vector2 = item.drift_stop_position()
	var crossed_x: float = _world.shore_start.x + _world.rod.maximum_cast_range - 2.0
	item._physics_process((item.global_position.x - crossed_x) / trash.arrival_speed)
	var before: Vector2 = item.global_position
	_check(item.is_arriving and before.x > old_stop.x and item.can_hook(), "Upgrade fixture missed the in-range approach")
	_check(_world.shop.buy_rod(index), "Could not upgrade the rod")
	trash._physics_process(0.0)
	var new_stop: Vector2 = item.drift_stop_position()
	_check(item.global_position == before and new_stop.x > old_stop.x and new_stop.x < before.x, "Retargeting did not preserve inward movement")
	item._physics_process(1.0 / 60.0)
	_check(item.global_position.x < before.x and before.x - item.global_position.x <= trash.arrival_speed / 60.0 + 0.001, "The first step after retargeting exceeded arrival speed")
	item._physics_process(60.0)
	_check(not item.is_arriving and item.global_position.is_equal_approx(new_stop), "Retargeted arrival did not settle")
	_remove_trash(item)
	await process_frame


func _remove_trash(item: OceanTrash) -> void:
	item.attach_to(_world.rod.get_hook_attachment(), Vector2.ZERO)
	item.finish_collection()
	item.free()


func _test_fish_routes(tier: int, starter_reach: float, previous_reach: float) -> void:
	var manager: CatchableFishManager = _world.catchable_fish
	var rod: FishingRod = _world.rod
	_aim_from_shore(450.0)
	for _slot: int in manager.maximum_active_fish:
		manager._spawn()
	_check(manager.fish.size() == manager.maximum_active_fish, "Could not fill the seeded visit cap")
	if manager.fish.size() < 2:
		return
	var near: CatchableFish = manager.fish.front()
	var candidate: CatchableFish = manager.fish[1]
	if tier > 0:
		near.escape()
		manager._spawn()
		near = manager.fish.back()
		_check(manager.fish.size() == manager.maximum_active_fish and near != candidate, "Offshore occupancy prevented nearshore replenishment")
	_check(near.swim_center.x + manager.swim_radius.x < _world.shore_start.x + starter_reach, "Nearshore visit left starter reach")
	for _step: int in 16:
		candidate._physics_process(TAU / (16.0 * candidate._swim_speed))
		var point: Vector2 = candidate.global_position
		_check(rod.invalid_target_reason(point).is_empty() and _on_screen(point, candidate.catch_radius), "Fish route or its cue left the castable view")
		_check(candidate.visual.global_position.is_equal_approx(point) and candidate.can_hook_at(point), "Fish cue or catch circle lost alignment")
		if tier > 0:
			_check(point.x > _world.shore_start.x + previous_reach, "Offshore route remained castable with the previous rod")
	for visitor: CatchableFish in manager.fish:
		visitor.set_physics_process(false)
	await process_frame
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = rod.get_canvas_transform() * candidate.global_position
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	_check(rod.state == FishingRod.State.CASTING, "Viewport click could not cast to the fish")
	rod._process(rod.equipped_cast_duration())
	_check(candidate.hooked and rod.state == FishingRod.State.TIMING, "Viewport cast could not hook the fish")
	rod._process(rod.fish_timing_duration)
	for visitor: CatchableFish in manager.fish.duplicate():
		visitor.escape()
	await process_frame


func _aim_from_shore(y: float) -> void:
	_player.global_position = Vector2(_world.shore_start.x, y) - _world.rod.position
	_player._process(0.0)
	_camera.reset_smoothing()
	_camera.force_update_scroll()


func _on_screen(point: Vector2, margin: float) -> bool:
	var canvas_point: Vector2 = _world.rod.get_canvas_transform() * point
	return _player.get_viewport_rect().grow(-margin).has_point(canvas_point)
