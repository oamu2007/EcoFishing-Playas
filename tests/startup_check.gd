extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	if change_scene_to_file(main_path) != OK:
		push_error("Could not load the configured main scene")
		quit(1)
		return
	for frame: int in 120:
		await process_frame
	var title: CanvasLayer = current_scene.get_node_or_null("SessionMenu") if current_scene != null else null
	if title == null or not title.visible:
		push_error("The configured main scene did not open the title")
		quit(1)
		return
	print("Main scene started and displayed the title for 120 frames.")
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await create_timer(1.0).timeout
	push_error("The app did not exit after a window close request")
	quit(1)
