extends SceneTree

const OUTPUT: String = "res://.godot/water_captures/"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _difference(a: Image, b: Image) -> float:
	var total: float = 0.0
	# Sparse sampling is test-only; gameplay never reads pixels on the CPU.
	for y: int in range(100, 500, 13):
		for x: int in range(500, 930, 13):
			var delta: Color = a.get_pixel(x, y) - b.get_pixel(x, y)
			total += absf(delta.r) + absf(delta.g) + absf(delta.b)
	return total / (31.0 * 34.0 * 3.0)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run water_render_check.gd without --headless: shader validation needs a real renderer.")
		quit(2)
		return
	DisplayServer.window_set_size(Vector2i(960, 540))
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT)) == OK, "Cannot create screenshot directory")
	var preview: Node = load("res://scenes/levels/water_preview.tscn").instantiate()
	root.add_child(preview)
	for node_name: String in ["Dirty", "Midway", "Clean"]:
		var water: WaterVisuals = preview.get_node(node_name)
		water.surface_material.set_shader_parameter("use_time_override", true)
		water.surface_material.set_shader_parameter("time_override", 5.0)
	var triptych: Image = await _frame()
	_check(triptych.save_png(OUTPUT + "comparison.png") == OK, "Cannot save comparison screenshot")
	preview.free()
	var main: Node = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	main.get_node("HUD").hide()
	var player: CharacterBody2D = main.get_node("World/Player")
	player.position = Vector2(790, 450)
	player.set_physics_process(false)
	player.get_node("FishingRod").set_process(false)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	var manager: TrashManager = main.get_node("World/TrashManager")
	for item: OceanTrash in manager.items:
		item.set_physics_process(false)
		item.set_process(false)
	# Keep a real landed hook/line in all captures to review gameplay contrast.
	var rod: FishingRod = player.get_node("FishingRod")
	rod._start_cast(Vector2(1110, 450))
	rod._process(rod.cast_duration)
	var water: WaterVisuals = main.get_node("World/Environment/Water")
	var model: PollutionSystem = main.get_node("World/PollutionSystem")
	var pollution_before: int = model.current_pollution
	water.surface_material.set_shader_parameter("use_time_override", true)
	water.surface_material.set_shader_parameter("time_override", 5.0)
	var captions: CanvasLayer = CanvasLayer.new()
	var caption: Label = Label.new()
	caption.position = Vector2(16, 16)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 1)
	captions.add_child(caption)
	root.add_child(captions)
	var images: Array[Image] = []
	var detail_differences: Array[float] = []
	var levels: Array[float] = [1.0, 0.5, 0.0]
	var names: Array[String] = ["dirty", "midway", "clean"]
	for index: int in range(levels.size()):
		water.set_visual_target(levels[index], true)
		caption.text = "WATER PREVIEW | %d%% pollution | gameplay state unchanged" % roundi(levels[index] * 100.0)
		var image: Image = await _frame()
		_check(image.save_png(OUTPUT + names[index] + ".png") == OK, "Cannot save state screenshot")
		images.append(image)
		water.get_node("Seabed").hide()
		var no_bed: Image = await _frame()
		detail_differences.append(_difference(image, no_bed))
		water.get_node("Seabed").show()
	_check(_difference(images[0], images[1]) > 0.025 and _difference(images[1], images[2]) > 0.025, "Pollution palettes are not visibly distinct")
	_check(detail_differences[2] > detail_differences[1] and detail_differences[1] > detail_differences[0] * 2.0, "Clean water does not reveal more actual seabed")
	# Both extremes remain animated at equal state, independent of CPU smoothing.
	for index: int in [0, 2]:
		water.set_visual_target(levels[index], true)
		caption.text = "Animation test"
		water.surface_material.set_shader_parameter("time_override", 5.0)
		var before: Image = await _frame()
		water.surface_material.set_shader_parameter("time_override", 11.0)
		var after: Image = await _frame()
		_check(_difference(before, after) > 0.0005, "Water stops animating at pollution endpoint")
	_check(model.current_pollution == pollution_before and model.trash_collected == 0 and manager.items.size() == 24, "Preview modified gameplay state")
	water.surface_material.set_shader_parameter("use_time_override", false)
	# Let screenshot readback/compilation settle before observing live frame pacing.
	for frame: int in range(60):
		await process_frame
	var started: int = Time.get_ticks_usec()
	for frame: int in range(90):
		await process_frame
	print("Live render observation: average wall-frame %.3f ms (includes display pacing; not isolated GPU time)" % [(Time.get_ticks_usec() - started) / 90000.0])
	print("Seabed image differences dirty/mid/clean: ", detail_differences)
	print("Water render check: %d failures; screenshots: %s" % [_failures, ProjectSettings.globalize_path(OUTPUT)])
	main.free()
	captions.free()
	quit(0 if _failures == 0 else 1)
