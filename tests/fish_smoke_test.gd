extends SceneTree

const WORLD_SCENE: PackedScene = preload("res://scenes/levels/playas_vertical_slice.tscn")
const AmbientFishScript = preload("res://scripts/gameplay/ambient_fish.gd")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _visible_count(fish: AmbientFishScript) -> int:
	var count: int = 0
	for silhouette: Polygon2D in fish.get_children():
		if silhouette.is_visible_in_tree() and silhouette.color.a > 0.0:
			count += 1
	return count


func _collect_range(model: PollutionSystem, items: Array[OceanTrash], start: int, end: int) -> void:
	for index: int in range(start, end):
		model.collect(items[index].get_instance_id())


func _check_routes(fish: AmbientFishScript, water_bounds: Rect2) -> void:
	var initial_positions: Array[Vector2] = []
	for silhouette: Polygon2D in fish.get_children():
		initial_positions.append(silhouette.position)
	var nearshore: Rect2 = water_bounds
	nearshore.size.x = minf(nearshore.size.x, fish.nearshore_width)
	var bounded: bool = true
	# Cover at least two cycles of every route and check the rotated outline, not just its center.
	for _step: int in range(252):
		fish._process(0.125)
		for silhouette: Polygon2D in fish.get_children():
			for vertex: Vector2 in silhouette.polygon:
				bounded = bounded and nearshore.has_point(silhouette.to_global(vertex))
	_check(bounded, "A silhouette left the nearshore water rectangle")
	for index: int in range(fish.get_child_count()):
		var silhouette: Polygon2D = fish.get_child(index)
		_check(silhouette.position.distance_to(initial_positions[index]) > 1.0, "Fish did not swim")


func _run() -> void:
	var world: Node2D = WORLD_SCENE.instantiate()
	root.add_child(world)
	var water: WaterVisuals = world.get_node("Environment/Water")
	var fish: AmbientFishScript = world.get_node("Environment/AmbientFish")
	var model: PollutionSystem = world.get_node("PollutionSystem")
	var manager: TrashManager = world.get_node("TrashManager")
	var rod: FishingRod = world.get_node("Player/FishingRod")
	_check(water.displayed_pollution == 1.0 and _visible_count(fish) == 0, "Dirty world showed fish")
	_check(fish.z_index == -8 and fish.get_child_count() == 6, "Unexpected fish layer or population")
	var first_fish: Polygon2D = fish.get_child(0)
	var starting_position: Vector2 = first_fish.position

	# The first 12 default items account for exactly half the original pollution.
	_collect_range(model, manager.items, 0, 12)
	_check(model.normalized_pollution == 0.5 and _visible_count(fish) == 0, "Fish jumped to model pollution before water moved")
	water._process(water.transition_duration * 0.75)
	var previous_opacity: float = first_fish.color.a
	_check(_visible_count(fish) == 3 and previous_opacity > 0.0, "Early fish did not fade in during water transition")
	water._process(water.transition_duration * 0.25)
	_check(water.displayed_pollution == 0.5 and _visible_count(fish) == 3, "Half-clean water did not show three fish")
	_check(first_fish.color.a > previous_opacity, "Fish opacity did not follow the displayed water value")

	# A second set of collections retargets an active transition while fish are visible.
	_collect_range(model, manager.items, 12, 16)
	water._process(water.transition_duration * 0.5)
	var displayed: float = water.displayed_pollution
	var before_retarget: Array[Color] = []
	for silhouette: Polygon2D in fish.get_children():
		before_retarget.append(silhouette.color)
	_collect_range(model, manager.items, 16, manager.items.size())
	_check(model.normalized_pollution == 0.0 and water.displayed_pollution == displayed, "Retarget jumped to clean water")
	for index: int in range(fish.get_child_count()):
		var silhouette: Polygon2D = fish.get_child(index)
		_check(silhouette.color == before_retarget[index], "A fish changed tint or opacity on retarget")
	water._process(water.transition_duration * 0.5)
	_check(water.displayed_pollution < displayed and water.displayed_pollution > 0.0, "Retarget did not continue smoothly")
	water._process(water.transition_duration * 0.5)
	_check(water.displayed_pollution == 0.0 and _visible_count(fish) == 6 and fish.get_child_count() == 6, "Clean water did not reveal the original six fish")
	_check(model.trash_collected == 24 and model.remaining_trash == 0, "Fish affected cleanup totals")
	_check_routes(fish, rod.water_bounds)

	var fresh: Node2D = WORLD_SCENE.instantiate()
	fresh.position = Vector2(1700, 30)
	root.add_child(fresh)
	var fresh_fish: AmbientFishScript = fresh.get_node("Environment/AmbientFish")
	_check(_visible_count(fresh_fish) == 0 and _visible_count(fish) == 6, "Fresh world inherited or reset another world's fish")
	_check((fresh_fish.get_child(0) as Polygon2D).position == starting_position, "Routes do not start deterministically")
	_check_routes(fresh_fish, (fresh.get_node("Player/FishingRod") as FishingRod).water_bounds)

	var empty: Node2D = WORLD_SCENE.instantiate()
	(empty.get_node("TrashManager") as TrashManager).initial_item_count = 0
	root.add_child(empty)
	var empty_water: WaterVisuals = empty.get_node("Environment/Water")
	var empty_fish: AmbientFishScript = empty.get_node("Environment/AmbientFish")
	_check(empty_water.displayed_pollution == 0.0 and _visible_count(empty_fish) == 6, "Empty world did not synchronize fish at startup")
	_check(_visible_count(fresh_fish) == 0, "Empty world revealed fish in another instance")
	empty.free()
	fresh.free()
	world.free()
	print("Fish smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)
