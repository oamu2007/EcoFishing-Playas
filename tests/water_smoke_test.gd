extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/gameplay/main.tscn")
const WATER_SCENE: PackedScene = preload("res://scenes/gameplay/water.tscn")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _uniform(water: WaterVisuals) -> float:
	return float(water.surface_material.get_shader_parameter("pollution_level"))


func _run() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	root.add_child(main)
	var water: WaterVisuals = main.get_node("World/Environment/Water")
	var model: PollutionSystem = main.get_node("World/PollutionSystem")
	var manager: TrashManager = main.get_node("World/TrashManager")
	_check(_uniform(water) == model.normalized_pollution and _uniform(water) == 1.0, "Initial uniform not synchronized")
	var material_id: int = water.surface_material.get_instance_id()
	var initial: int = model.current_pollution
	var first: OceanTrash = manager.items[0]
	model.collect(first.get_instance_id())
	_check(model.current_pollution == initial - first.pollution_value, "Water integration changed model calculations")
	_check(water.target_pollution == model.normalized_pollution, "Pollution signal did not update visual target")
	_check(_uniform(water) == 1.0, "Visual jumped instead of transitioning")
	var bar: ProgressBar = main.get_node("HUD/PollutionBar")
	_check(absf(bar.value - model.normalized_pollution * 100.0) <= maxf(bar.step, 0.0001), "HUD waited for water smoothing")
	var hud_text: String = main.get_node("HUD/ProgressPanel/Margin/Progress").text
	_check(hud_text.ends_with("%d%%" % roundi(model.normalized_pollution * 100.0)), "Numerical HUD pollution did not update immediately")
	water._process(water.transition_duration * 0.5)
	_check(_uniform(water) < 1.0 and _uniform(water) > water.target_pollution, "Intermediate interpolation outside boundaries")
	water._process(water.transition_duration * 0.5)
	_check(is_equal_approx(_uniform(water), model.normalized_pollution), "Visual did not reach model in transition duration")
	_check(water.surface_material.get_instance_id() == material_id, "Material recreated while interpolating")
	# Mid-transition retarget starts at the displayed value, without a discontinuity.
	water.set_visual_target(0.0)
	water._process(0.4)
	var intermediate: float = water.displayed_pollution
	water.set_visual_target(0.5)
	_check(_uniform(water) == intermediate, "Retarget jumped")
	water._process(10.0)
	_check(_uniform(water) == 0.5 and not water.is_processing(), "Retarget overshot or never stopped updating")
	water.set_visual_target(-2.0)
	water._process(10.0)
	_check(_uniform(water) == 0.0, "Lower pollution bound failed")
	water.set_visual_target(2.0, true)
	_check(_uniform(water) == 1.0, "Upper pollution bound failed")
	var other: WaterVisuals = WATER_SCENE.instantiate()
	root.add_child(other)
	other.set_visual_target(0.0, true)
	_check(other.surface_material != water.surface_material and _uniform(water) == 1.0, "Water instances share mutable materials")
	# Rebinding reads current state and disconnects the old dependency.
	var empty: PollutionSystem = PollutionSystem.new()
	root.add_child(empty)
	var no_items: Dictionary[int, int] = {}
	empty.initialize(no_items)
	water.bind_pollution(empty)
	_check(_uniform(water) == 0.0 and not water.is_processing(), "Empty level/rebind did not synchronize immediately")
	model.collect(manager.items[1].get_instance_id())
	_check(water.target_pollution == 0.0, "Old model still controls rebound water")
	other.free()
	empty.free()
	main.free()
	# Scene reset starts at fresh state, never the previous water material value.
	main = MAIN_SCENE.instantiate()
	root.add_child(main)
	water = main.get_node("World/Environment/Water")
	_check(_uniform(water) == 1.0 and water.displayed_pollution == 1.0, "Reload inherited previous pollution")
	_check(water.get_node("Surface").size == Vector2(760, 900), "Water presentation changed authored bounds")
	_check(water.z_index < 0 and water.get_node("Surface").material != main.get_node("World/Player").material, "Water shader leaked into gameplay draw layer")
	main.free()
	main = MAIN_SCENE.instantiate()
	(main.get_node("World/TrashManager") as TrashManager).initial_item_count = 0
	root.add_child(main)
	water = main.get_node("World/Environment/Water")
	_check(_uniform(water) == 0.0, "Empty scene load did not start clean")
	main.free()
	print("Water smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)
