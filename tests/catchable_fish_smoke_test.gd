extends SceneTree

const SESSION_SCENE: PackedScene = preload("res://scenes/gameplay/session.tscn")
const FishScene: PackedScene = preload("res://scenes/gameplay/catchable_fish.tscn")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const PlayerScript = preload("res://scripts/gameplay/player.gd")
const TraderFixture = preload("res://tests/trader_fixture.gd")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var dirty: int = _spawn_trials(51)
	var threshold: int = _spawn_trials(50)
	var halfway_to_clean: int = _spawn_trials(25)
	var clean: int = _spawn_trials(0)
	_check(dirty == 0 and threshold > 0 and threshold < halfway_to_clean and halfway_to_clean < clean, "Seeded spawn rates did not rise with actual water quality")
	print("Catchable fish seeded trials per 120 at 51/50/25/0: %s" % str([dirty, threshold, halfway_to_clean, clean]))
	await _test_recovery_and_sales()
	print("Catchable fish smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _spawn_trials(points: int) -> int:
	var session: Node = SESSION_SCENE.instantiate()
	root.add_child(session)
	var world: LevelScript = session.get_node("World")
	var model: PollutionSystem = world.pollution
	var manager: CatchableFishManager = world.catchable_fish
	var empty: Dictionary[int, int] = {}
	model.initialize(empty, points)
	var spawned: int = 0
	var species_seen: Dictionary[String, int] = {}
	for trial: int in 120:
		manager._physics_process(manager.spawn_interval)
		if manager.fish.is_empty():
			continue
		var fish: CatchableFish = manager.fish.front()
		spawned += 1
		species_seen[fish.species.title] = species_seen.get(fish.species.title, 0) + 1
		_check(fish.length_cm >= fish.species.minimum_length_cm and fish.length_cm <= fish.species.maximum_length_cm, "Fish size outside catalog range")
		var start: Vector2 = fish.global_position
		fish._physics_process(0.5)
		var point: Vector2 = fish.global_position
		var shore: Vector2 = Vector2(world.shore_start.x, point.y)
		_check(not point.is_equal_approx(start) and world.rod.invalid_target_reason_from(shore, point).is_empty(), "Fish did not swim within reachable water")
		fish._physics_process(fish.lifetime)
		_check(manager.fish.is_empty() and not fish.can_hook(), "Expired fish was still eligible or counted against cap")
	if points == 0:
		_check(species_seen.size() == 4, "Clean-water sample did not exercise all species")
	session.free()
	return spawned


func _test_recovery_and_sales() -> void:
	var session: Node = SESSION_SCENE.instantiate()
	root.add_child(session)
	var world: LevelScript = session.get_node("World")
	var player: PlayerScript = world.get_node("Player")
	var manager: CatchableFishManager = world.catchable_fish
	var trash: TrashManager = world.trash_manager
	var model: PollutionSystem = world.pollution
	var rod: FishingRod = world.rod
	var sack: Sack = world.sack
	var water: WaterVisuals = world.get_node("Environment/Water")
	trash.arrivals_enabled = false
	manager.set_physics_process(false)
	rod.set_process(false)
	player.set_physics_process(false)
	for item: OceanTrash in trash.items:
		item.set_physics_process(false)
	model.remove_permanent(50)
	_check(model.normalized_pollution == 0.50 and water.displayed_pollution > 0.50, "Threshold fixture did not separate true pollution from visual easing")
	var fish: CatchableFish = _next_fish(manager)
	if fish == null:
		_check(false, "No fish appeared at the threshold while water visuals were easing")
		session.free()
		return
	fish.set_physics_process(false)
	var empty: Dictionary[int, int] = {}
	water._process(water.transition_duration)
	model.initialize(empty, 50)
	model.register_trash(-1, 5)
	_check(model.current_pollution == 55 and water.displayed_pollution == 0.50, "Rebound fixture did not separate actual pollution from displayed pollution")
	var visitors: int = manager.fish.size()
	for trial: int in 24:
		manager._physics_process(manager.spawn_interval)
	_check(manager.fish.size() == visitors and fish.can_hook(), "Rebound spawned new fish or removed a current visit")
	var trash_values: Dictionary[int, int] = {}
	for item: OceanTrash in trash.items:
		trash_values[item.get_instance_id()] = item.pollution_value
	model.initialize(trash_values, 0)
	water._process(water.transition_duration)
	var ambient: Node2D = world.get_node("Environment/AmbientFish")
	_check(ambient.find_children("*", "Area2D", true, false).is_empty(), "Ambient silhouettes have catch geometry")
	var spot: Vector2 = Vector2(world.shore_start.x + 184.0, 450.0)
	var offset: Vector2 = rod.global_position - player.global_position
	player.global_position = Vector2(world.shore_start.x, spot.y) - offset
	for item: OceanTrash in trash.items:
		item.global_position.y = 120.0
	var downstream: OceanTrash = trash.items[0]
	var competitor: OceanTrash = trash.items[1]
	downstream.global_position = spot - Vector2(74.0, 0.0)
	competitor.global_position = spot + Vector2(19.0, 0.0)
	fish.global_position = spot
	var expected: int = fish.sale_price() + trash.trash_sale_value
	_cast(rod, spot)
	_check(fish.hooked and rod.state == FishingRod.State.TIMING and not competitor.hooked and sack.item_count == 0, "Nearest cross-type landing did not start fish timing")
	fish._physics_process(fish.lifetime + 1.0)
	_check(fish.hooked and not fish.is_queued_for_deletion(), "Hooked fish expired during retrieval")
	var zone: Vector2 = rod.fish_timing_zone()
	rod._process(rod.fish_timing_duration * lerpf(zone.x, zone.y, 0.5))
	var timing_key: InputEventKey = InputEventKey.new()
	timing_key.physical_keycode = KEY_SPACE
	timing_key.pressed = true
	timing_key.echo = true
	rod._input(timing_key)
	_check(rod.state == FishingRod.State.TIMING, "Key repeat resolved the timing challenge")
	timing_key.echo = false
	rod._input(timing_key)
	rod._input(timing_key)
	_check(rod.state == FishingRod.State.WAITING and sack.item_count == 0, "Timed input failed to secure a fish before retrieval")
	_retrieve(rod)
	_check(fish.collected and competitor.collected and not downstream.collected, "Mixed return failed to land fish plus the swept trash")
	_check(model.trash_collected == 1 and model.current_pollution == 25, "Fish changed floating pollution or trash did not score")
	_check(sack.item_count == 2 and sack.fish_count == 1 and sack.sale_total() == expected, "Mixed return did not preserve fish and trash values")
	rod.retrieval_completed.emit(spot)
	_check(sack.item_count == 2, "Duplicate completion duplicated a fish")

	_cast(rod, downstream.global_position)
	_retrieve(rod)
	expected += trash.trash_sale_value
	_check(sack.free_slots == 0 and sack.sale_total() == expected, "One more trash piece failed to fill the Sack")
	var excess: CatchableFish = _next_fish(manager)
	if excess != null:
		excess.set_physics_process(false)
		excess.global_position = spot
		_cast(rod, spot)
		_retrieve(rod)
		_check(not excess.hooked and not excess.collected and sack.fish_count == 1, "Full Sack removed an excess fish")
	else:
		_check(false, "No excess fish for capacity check")
	_test_prices(manager.species_catalog, trash.trash_sale_value)
	var shack: FishingShack = world.get_node("FishingShack")
	player.global_position = shack.global_position
	var open: InputEventKey = InputEventKey.new()
	open.physical_keycode = KEY_E
	open.pressed = true
	session._unhandled_input(open)
	var panel: CanvasLayer = session.get_node("ShackPanel")
	TraderFixture.select_all(panel)
	var sell: Button = panel.get_node("%ConfirmSale")
	var tray: Control = panel.get_node("%TrayItems")
	_check(tray.get_child(0).text.contains(" cm)") and tray.get_child(0).icon == fish.species.art and sell.text.contains(str(expected)), "Trader did not display the fish art and mixed sale quote")
	sell.pressed.emit()
	sell.pressed.emit()
	_check(world.shop.coins == expected and sack.item_count == 0 and sack.fish_count == 0, "Mixed sale failed or credited twice")
	session.get_node("ShackPanel").get_node("%Close").pressed.emit()
	if excess != null:
		player.global_position = Vector2(world.shore_start.x, spot.y) - offset
		_cast(rod, spot + Vector2(48, 0))
		_retrieve(rod)
		_check(not excess.hooked and sack.item_count == 0, "Retrieval sweep hooked a fish without a landing")
		_test_misses(manager, rod, sack, spot)
	await process_frame
	_check(not is_instance_valid(fish), "Landed fish did not leave the water")
	session.free()


func _test_misses(manager: CatchableFishManager, rod: FishingRod, sack: Sack, spot: Vector2) -> void:
	for progress: float in [0.05, 0.95, 1.05]:
		var fish: CatchableFish = _next_fish(manager)
		if fish == null:
			_check(false, "No fish for a timing-miss fixture")
			return
		fish.set_physics_process(false)
		fish.global_position = spot
		_cast(rod, spot)
		_check(rod.state == FishingRod.State.TIMING, "Timing-miss fixture did not hook a fish")
		rod._process(rod.fish_timing_duration * progress)
		if progress < 1.0:
			_retrieve(rod)
		_check(rod.state == FishingRod.State.IDLE and fish.is_queued_for_deletion(), "Early, late, or absent input did not release the fish")
		_check(not manager.fish.has(fish) and sack.item_count == 0, "Escaped fish blocked another visit or entered the Sack")
	_cast(rod, spot + Vector2(48, 0))
	_retrieve(rod)
	_check(rod.state == FishingRod.State.IDLE, "A new cast did not recover after timing failures")


func _next_fish(manager: CatchableFishManager) -> CatchableFish:
	for trial: int in 48:
		manager._physics_process(manager.spawn_interval)
		if not manager.fish.is_empty():
			return manager.fish.front()
	return null


func _test_prices(species: Array[FishSpecies], trash_price: int) -> void:
	var sample: CatchableFish = FishScene.instantiate()
	sample.species = species[0]
	sample.length_cm = species[0].minimum_length_cm
	var small: int = sample.sale_price()
	sample.length_cm = species[0].maximum_length_cm
	var large: int = sample.sale_price()
	sample.species = species.back()
	var rare: int = sample.sale_price()
	_check(small > trash_price and large > small and rare > large, "Size and rarity did not increase fish sale value")
	sample.free()


func _cast(rod: FishingRod, point: Vector2) -> void:
	_check(rod.invalid_target_reason(point).is_empty(), "Fish fixture cast was out of range")
	rod._start_cast(point)
	rod._process(rod.cast_duration)


func _retrieve(rod: FishingRod) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	rod._unhandled_input(click)
	rod._process(rod.retrieval_duration)
