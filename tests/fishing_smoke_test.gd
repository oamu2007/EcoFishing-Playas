extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var main: Node = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player: CharacterBody2D = main.get_node("World/Player")
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
	_check(line.to_global(line.points[0]).is_equal_approx(tip.global_position), "Line detached from rod")
	_check(line.to_global(line.points[1]).is_equal_approx(hook.get_line_endpoint()), "Line detached from hook")
	rod._process(rod.cast_duration * 0.5)
	_check(rod.state == FishingRod.State.WAITING, "Cast did not land")
	_check(hook.global_position.is_equal_approx(target), "Hook missed selected water point")
	_check(hook.visual.position.is_zero_approx(), "Visual height nonzero on landing")
	rod._process(5.0)
	_check(rod.state == FishingRod.State.WAITING and hook.global_position.is_equal_approx(target), "Waiting drifted")
	rod._unhandled_input(_click())
	_check(rod.state == FishingRod.State.RETRIEVING, "Click did not retrieve")
	rod._unhandled_input(_click())
	_check(rod.state == FishingRod.State.RETRIEVING, "Repeated click interrupted retrieval")
	rod._process(rod.retrieval_duration)
	_check(rod.state == FishingRod.State.IDLE and not rod.is_active(), "Retrieval did not unlock player")
	_check(not hook.visible and not line.visible, "Idle tackle remained visible")
	_check(hook.global_position.is_equal_approx(tip.global_position), "Hook did not return to tip")
	main.free()
	print("Fishing smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _click() -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event
