extends SceneTree

const OUTPUT: String = "res://.godot/water_captures/"
const WorldScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")

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
	var session: Node = load("res://scenes/gameplay/session.tscn").instantiate()
	var world: WorldScript = session.get_node("World")
	var manager: TrashManager = world.get_node("TrashManager")
	manager.arrivals_enabled = false
	root.add_child(session)
	session.get_node("HUD").hide()
	var player: CharacterBody2D = world.get_node("Player")
	player.position = Vector2(790, 450)
	player.set_physics_process(false)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	for item: OceanTrash in manager.items:
		item.set_physics_process(false)
		item.set_process(false)
	var rod: FishingRod = player.get_node("FishingRod")
	rod.set_process(false)
	var ambient_fish: Node2D = world.get_node("Environment/AmbientFish")
	ambient_fish.hide()
	ambient_fish.set_process(false)
	var water: WaterVisuals = world.get_node("Environment/Water")
	var model: PollutionSystem = world.get_node("PollutionSystem")
	var pollution_before: int = model.current_pollution
	var collected_before: int = model.trash_collected
	var remaining_before: int = model.remaining_trash
	var items_before: Array[OceanTrash] = manager.items.duplicate()
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
		caption.text = "WATER PREVIEW | %d%% pollution" % roundi(levels[index] * 100.0)
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
	_check(model.current_pollution == pollution_before and model.trash_collected == collected_before, "Preview modified pollution or collected trash")
	_check(model.remaining_trash == remaining_before and manager.items == items_before, "Preview modified active trash")
	# Capture the landed hook separately so the palette samples stay stable.
	water.set_visual_target(model.normalized_pollution, true)
	ambient_fish.show()
	var landing: Vector2 = Vector2(rod.water_bounds.position.x + 90.0, rod.global_position.y)
	_check(rod.invalid_target_reason(landing).is_empty(), "Gameplay capture target is outside starter reach")
	rod.hook_landed.disconnect(world._on_hook_landed)
	rod._start_cast(landing)
	rod._process(rod.cast_duration)
	_check(rod.state == FishingRod.State.WAITING and rod.get_hook_water_position().is_equal_approx(landing), "Gameplay capture did not land the hook")
	water.surface_material.set_shader_parameter("time_override", 5.0)
	caption.text = "LANDED HOOK | %d%% pollution" % model.current_pollution
	var gameplay: Image = await _frame()
	_check(gameplay.save_png(OUTPUT + "gameplay.png") == OK, "Cannot save landed-hook screenshot")
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
	session.free()
	captions.free()
	quit(0 if _failures == 0 else 1)
