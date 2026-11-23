extends SceneTree

const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")

var _failures: int = 0
var _capture_line: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	_capture_line = OS.get_cmdline_user_args().has("--capture-line") and DisplayServer.get_name() != "headless"
	if _capture_line:
		DirAccess.make_dir_recursive_absolute("res://.godot/line_captures")
	var session: Node = load("res://scenes/gameplay/session.tscn").instantiate()
	root.add_child(session)
	await process_frame
	var world: LevelScript = session.get_node("World")
	var player: CharacterBody2D = session.get_node("World/Player")
	var rod: FishingRod = player.get_node("FishingRod")
	var hook: FishingHook = rod.get_node("FishingHook")
	var line: Line2D = rod.get_node("FishingLine")
	var tip: Marker2D = rod.get_node("Pivot/Tip")
	rod.set_process(false)
	player.set_physics_process(false)
	_check(InputMap.action_has_event("fishing_action", _click()), "Left click input missing")
	_check(not rod.invalid_target_reason(Vector2(1000, 450)).is_empty(), "Inland cast accepted")
	player.position = Vector2(795, 450)
	_check(not rod.invalid_target_reason(Vector2(700, 450)).is_empty(), "Sand target accepted")
	_check(not rod.invalid_target_reason(Vector2(1500, 450)).is_empty(), "Out-of-range target accepted")
	var target: Vector2 = Vector2(1000, 450)
	if _capture_line:
		await process_frame
		var camera: Camera2D = player.get_node("Camera2D")
		camera.reset_smoothing()
		camera.force_update_scroll()
	_check(rod.invalid_target_reason(target).is_empty(), "Valid ocean target rejected")
	rod._start_cast(target)
	_check(rod.state == FishingRod.State.CASTING, "Cast did not start")
	rod._unhandled_input(_click())
	_check(rod.state == FishingRod.State.CASTING, "Click interrupted casting")
	var before: Vector2 = player.position
	Input.action_press("move_right")
	player._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	_check(player.position == before and player.velocity == Vector2.ZERO, "Movement lock failed")
	rod._process(rod.cast_duration * 0.5)
	_check(hook.visual.position.y < -90.0, "Arc has no visible height")
	_check_endpoints(line, tip, hook)
	var flight_slack: float = _line_slack(line)
	_check(flight_slack > 20.0, "Line did not bow in flight")
	await _record_line("flight")
	rod._process(rod.cast_duration * 0.5)
	_check(rod.state == FishingRod.State.WAITING, "Cast did not land")
	_check(hook.global_position.is_equal_approx(target), "Hook missed selected water point")
	_check(hook.visual.position.is_zero_approx(), "Visual height nonzero on landing")
	var landing_slack: float = _line_slack(line)
	await _record_line("splash")
	for frame: int in 60:
		rod._process(1.0 / 60.0)
		_check_endpoints(line, tip, hook)
	_check(rod.state == FishingRod.State.WAITING and hook.global_position.is_equal_approx(target), "Waiting drifted")
	var waiting_slack: float = _line_slack(line)
	_check(waiting_slack < landing_slack and waiting_slack > 0.0, "Line did not settle after landing")
	await _record_line("settled")
	rod._unhandled_input(_click())
	_check(rod.state == FishingRod.State.RETRIEVING, "Click did not retrieve")
	rod._unhandled_input(_click())
	_check(rod.state == FishingRod.State.RETRIEVING, "Repeated click interrupted retrieval")
	rod._process(rod.retrieval_duration * 0.5)
	_check_endpoints(line, tip, hook)
	_check(_line_slack(line) < waiting_slack, "Line did not tighten during retrieval")
	await _record_line("retrieval")
	rod._process(rod.retrieval_duration * 0.5)
	_check(rod.state == FishingRod.State.IDLE and not rod.is_active(), "Retrieval did not unlock player")
	_check(not hook.visible and not line.visible, "Idle tackle remained visible")
	_check(hook.global_position.is_equal_approx(tip.global_position), "Hook did not return to tip")
	var fish: CatchableFish = world.catchable_fish._add_fish(target, world.catchable_fish.species_catalog[0], 22)
	rod._start_cast(target)
	rod._process(rod.cast_duration)
	_check(fish.hooked and rod.state == FishingRod.State.TIMING, "Fish fixture did not hook for the line tension check")
	rod._process(0.30)
	var first_tug: float = _line_slack(line)
	rod._process(0.18)
	_check_endpoints(line, tip, hook)
	var next_tug: float = _line_slack(line)
	_check(first_tug != next_tug and maxf(first_tug, next_tug) < landing_slack, "Hooked fish did not vary line tension")
	await _record_line("fish_tension")
	print("Line sag in world units: flight %.1f, landing %.1f, waiting %.1f, fish %.1f/%.1f" % [flight_slack, landing_slack, waiting_slack, first_tug, next_tug])
	session.free()
	print("Fishing smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _record_line(phase: String) -> void:
	if not _capture_line:
		return
	await RenderingServer.frame_post_draw
	var path: String = "res://.godot/line_captures/%dx%d_%s.png" % [root.size.x, root.size.y, phase]
	_check(root.get_texture().get_image().save_png(path) == OK, "Could not record the %s line sample" % phase)


func _check_endpoints(line: Line2D, tip: Marker2D, hook: FishingHook) -> void:
	_check(line.to_global(line.points[0]).is_equal_approx(tip.global_position), "Line detached from rod")
	_check(line.to_global(line.points[-1]).is_equal_approx(hook.get_line_endpoint()), "Line detached from hook")


func _line_slack(line: Line2D) -> float:
	return line.points[floori(line.points.size() * 0.5)].y - (line.points[0].y + line.points[-1].y) * 0.5


func _click() -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event
