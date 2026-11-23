extends SceneTree

const MainScene: PackedScene = preload("res://scenes/gameplay/main.tscn")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const PlayerScript = preload("res://scripts/gameplay/player.gd")
const CleanupSite = preload("res://scripts/gameplay/cleanup_site.gd")
const AudioScript = preload("res://scripts/gameplay/game_audio.gd")

var _failures: int = 0
var _main: Node
var _menu: CanvasLayer
var _pause: CanvasLayer
var _session: Node
var _panel: CanvasLayer
var _world: LevelScript
var _player: PlayerScript
var _rod: FishingRod
var _sack: Sack
var _shop: ShackShop
var _shack: FishingShack
var _water: WaterVisuals
var _coin_amount: Label
var _return_checked: bool
var _fish_sale_value: int
var _intentionally_fishing: bool
var _sale_trips: int
var _first_threshold_time: float
var _start_ticks: int
var _sale_count: int
var _gross_earned: int
var _starter_range: float
var _seen_starter_items: Dictionary[int, bool]
var _new_starter_times: Array[float]
var _cleanup_cues: int
var _trophy_visits: int


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures += 1
		push_error(message)
	return condition


func _run() -> void:
	physics_frame.connect(_sample_starter_supply)
	var baseline_orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_main = MainScene.instantiate()
	root.add_child(_main)
	_menu = _main.get_node("SessionMenu")
	_pause = _main.get_node("PauseMenu")
	root.size = Vector2i(1280, 720)
	await process_frame
	if await _start_session():
		await _play_session("1280 x 720")
		_key(KEY_ESCAPE)
		await process_frame
		root.size = Vector2i(800, 450)
		await process_frame
		if _check(_pause.visible, "Pause menu did not open after the first session") and await _start_session(true):
			await _play_session("800 x 450")
			_key(KEY_ESCAPE)
			await process_frame
			_click_button(_pause.get_node("%QuitToTitle"))
			await process_frame
			_click_button(_pause.get_node("%ConfirmDiscard"))
			await process_frame
			if _check(_menu.visible and not _main.has_node("Session"), "Quit after the second route did not return to title"):
				await _start_session()
	var audio: AudioScript = _main.get_node("GameAudio")
	await audio.prepare_shutdown()
	_main.free()
	for frame: int in 4:
		await process_frame
	_check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= baseline_orphans, "Replaying left orphan nodes behind")
	print("Complete playthrough smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _start_session(restarting: bool = false) -> bool:
	if restarting:
		_click_button(_pause.get_node("%Restart"))
		await process_frame
		_click_button(_pause.get_node("%ConfirmDiscard"))
	else:
		_click_button(_menu.get_node("%StartSession"))
	await process_frame
	await process_frame
	_session = _main.get_node_or_null("Session")
	if not _check(_session != null and not _menu.visible and not _pause.visible, "Start did not enter the playable session"):
		return false
	_world = _session.get_node("World")
	_player = _world.get_node("Player")
	_shack = _world.get_node("FishingShack")
	_panel = _session.get_node("ShackPanel")
	_water = _world.get_node("Environment/Water")
	_rod = _world.rod
	_rod._timing_rng.seed = 26
	_sack = _world.sack
	_shop = _world.shop
	_coin_amount = _session.get_node("CoinBalance").get_node("%Amount")
	_return_checked = false
	_fish_sale_value = 0
	_intentionally_fishing = false
	_sale_trips = 0
	_sale_count = 0
	_gross_earned = 0
	_first_threshold_time = -1.0
	_cleanup_cues = 0
	_trophy_visits = 0
	_starter_range = _rod.maximum_cast_range
	_seen_starter_items.clear()
	_new_starter_times.clear()
	for item: OceanTrash in _world.trash_manager.items:
		_seen_starter_items[item.get_instance_id()] = true
	_world.pollution.pollution_changed.connect(_record_threshold)
	_world.cleanup_work.work_started.connect(_count_cleanup_cue)
	_world.catchable_fish.fish_spawned.connect(_count_trophy_visit)
	_check(_sack.item_count == 0 and _sack.capacity == 3 and _shop.coins == 0 and _coin_amount.text == "0 gold" and _shop.rod_tier == 0 and _shop.sack_tier == 0, "Fresh session retained Sack, gold, or gear progress")
	_check(not _shop.offshore_net_installed and not _world.get_node("OffshoreNet").visible, "Fresh session retained the offshore net")
	for tier: int in range(_shop.rod_upgrades.size() + 1):
		for add_on: int in _shop.rod_add_ons.size():
			_check(not _shop.owns_rod_add_on(tier, add_on), "Fresh session retained a rod add-on")
	for index: int in _shop.cleanup_projects.size():
		var site: CleanupSite = _world.cleanup_work.site_for_project(_shop.cleanup_projects[index])
		_check(not _shop.is_cleanup_complete(index) and not site.has_started, "Fresh session retained completed cleanup or crew work")
	return _check(_world.pollution.current_pollution == 100 and is_equal_approx(_water.displayed_pollution, 1.0), "Fresh session retained pollution or water clarity")


func _play_session(window: String) -> void:
	_start_ticks = Engine.get_physics_frames()
	print("Starting complete input playthrough at ", window)
	await _walk_to_shore()
	var edge: Vector2 = _rod.global_position + Vector2(_rod.maximum_cast_range, 0.0)
	var old_cast: int = _rod.cast_number
	_cast_click(edge + Vector2(10.0, 0.0))
	_check(_rod.cast_number == old_cast and _rod.state == FishingRod.State.IDLE, "Out-of-range click started a cast")
	if not await _cast_and_return(edge - Vector2(3.0, 0.0), true):
		return
	if not await _buy("Gear", 0, _shop.rod_upgrades[0].cost):
		return
	var first_upgrade_time: float = _seconds_since(_start_ticks)
	_check(_sale_trips >= 3, "First upgrade took fewer than three starter trips")
	print("First gear at %.1fs after %d starter trips" % [first_upgrade_time, _sale_trips])
	if not await _buy("Gear", _shop.rod_upgrades.size(), _shop.sack_upgrades[0].cost):
		return
	var project_index: int = 0
	var target_permanent_points: int = roundi(_world.catchable_fish.pollution_threshold * 100.0) - PollutionSystem.MAX_FLOATING_POINTS
	while _world.pollution.permanent_points > target_permanent_points and project_index < _shop.cleanup_projects.size():
		if not await _buy("Cleanup", project_index, _shop.cleanup_projects[project_index].cost):
			return
		project_index += 1
	_check(_world.pollution.current_pollution <= 50 and _shop.rod_tier == 1 and _shop.sack_tier == 1, "Trash-funded gear and projects did not unlock fish")
	print("Stable fish threshold secured at %.1fs after %d projects" % [_seconds_since(_start_ticks), project_index])
	_check(is_equal_approx(_rod.equipped_cast_duration(), _rod.cast_duration) and not _shop.owns_rod_add_on(1, 0) and not _shop.owns_rod_add_on(1, 1), "The first fish attempt used an add-on")
	_intentionally_fishing = true
	if not await _catch_fish():
		return
	if not await _sell():
		return
	var first_fish_sale_time: float = _seconds_since(_start_ticks)
	_check(_fish_sale_value > _world.trash_manager.trash_sale_value, "The first fish sale did not pay more than trash")
	_check(_first_threshold_time >= 0.0, "The playthrough did not record a true 50% crossing")
	print("First 50%% crossing %.1fs, first fish sale %.1fs (+%d gold), pollution %d%%" % [_first_threshold_time, first_fish_sale_time, _fish_sale_value, _world.pollution.current_pollution])

	var spool_index: int = 1
	var spool: RodAddOn = _shop.rod_add_ons[spool_index]
	if not await _buy("RodAddOns", spool_index, spool.cost):
		return
	_check(_shop.owns_rod_add_on(1, spool_index) and is_equal_approx(_rod.equipped_cast_duration(), _rod.cast_duration * (1.0 - spool.duration_discount)), "The Shore rod did not apply its own Quick spool")
	if not await _buy("Gear", 1, _shop.rod_upgrades[1].cost):
		return
	_check(_shop.owns_rod_add_on(1, spool_index) and not _shop.owns_rod_add_on(2, spool_index) and is_equal_approx(_rod.equipped_cast_duration(), _rod.cast_duration), "The Offshore rod inherited its predecessor's Quick spool")
	if not await _buy("RodAddOns", spool_index, spool.cost):
		return
	_check(_shop.owns_rod_add_on(2, spool_index) and is_equal_approx(_rod.equipped_retrieval_duration(), _rod.retrieval_duration * (1.0 - spool.duration_discount)), "The Offshore rod did not apply its own Quick spool")
	for index: int in range(project_index, _shop.cleanup_projects.size()):
		if not await _buy("Cleanup", index, _shop.cleanup_projects[index].cost):
			return
	if not await _reach_clean_water():
		return
	var clean_time: float = _seconds_since(_start_ticks)
	var zero_ambient: int = _visible_ambient_count()
	_check(zero_ambient == 6, "Ambient fish did not return at clean water")
	var rebounds: bool = false
	for frame: int in 1100:
		if _world.pollution.current_pollution > 0:
			rebounds = true
			break
		await physics_frame
	_check(rebounds and _world.pollution.permanent_points == 0 and _world.pollution.floating_points == _world.trash_manager.pollution_per_item, "Live pollution did not rebound from zero by one floating arrival")
	var rebound_target: float = _world.pollution.normalized_pollution
	for frame: int in 150:
		if is_equal_approx(_water.displayed_pollution, rebound_target):
			break
		await physics_frame
	_check(is_equal_approx(_water.displayed_pollution, rebound_target) and _visible_ambient_count() == zero_ambient, "Water and ambient fish did not settle after the rebound")
	print("Clean-water window at %.1fs, live rebound to %d%%, %d ambient fish" % [clean_time, _world.pollution.current_pollution, _visible_ambient_count()])
	await _check_cleanup_sites()
	if not await _purchase_and_watch_net():
		return
	_check(_trophy_visits == 0, "The seeded ordinary progression route encountered a trophy")
	var longest_gap: float = 0.0
	for index: int in range(1, _new_starter_times.size()):
		longest_gap = maxf(longest_gap, _new_starter_times[index] - _new_starter_times[index - 1])
	if _check(_new_starter_times.size() >= 2, "Recurring starter-range supply was not observed"):
		var mean_gap: float = (_new_starter_times.back() - _new_starter_times.front()) / (_new_starter_times.size() - 1)
		print("Ingress %.1f px/s, cadence %.1fs. Starter arrivals %.1fs apart on average, longest %.1fs (%d observed)." % [_world.trash_manager.arrival_speed, _world.trash_manager.arrival_interval, mean_gap, longest_gap, _new_starter_times.size()])


func _purchase_and_watch_net() -> bool:
	var price: int = _shop.offshore_net_cost
	if not await _fund(price):
		return false
	var net: Node2D = _world.get_node("OffshoreNet")
	var old_debris: Array[OceanTrash] = []
	for frame: int in 1400:
		for item: OceanTrash in _world.trash_manager.items:
			if item.in_water and item.global_position.x < net.global_position.x:
				old_debris.append(item)
		if not old_debris.is_empty():
			break
		await physics_frame
	if not _check(not old_debris.is_empty() and _world.pollution.floating_points > 0, "The net purchase had no existing floating pollution to remove"):
		return false
	var before: int = _shop.coins
	var intercepted: Dictionary[int, int] = {}
	_world.trash_manager.trash_intercepted.connect(func(item: OceanTrash, sale_value: int) -> void:
		var id: int = item.get_instance_id()
		_check(not intercepted.has(id) and sale_value == item.sale_price() and item.global_position.x == net.global_position.x, "The net intercepted a piece twice or credited the wrong value")
		intercepted[id] = sale_value
	)
	if not await _buy("OffshoreNetOffer", 0, price):
		return false
	_check(net.visible and _shop.offshore_net_installed and _world.pollution.current_pollution == 0, "Purchase did not deploy the net and clear floating pollution")
	print("Offshore net at %.1fs, %d gold earned before purchase, paid %d gold" % [_seconds_since(_start_ticks), _gross_earned, price])
	for frame: int in 2400:
		if not _check(_world.pollution.current_pollution == 0, "True pollution rebounded after net installation"):
			return false
		if intercepted.size() >= 3 and is_zero_approx(_water.displayed_pollution):
			break
		await physics_frame
	var net_earnings: int = 0
	for sale_value: int in intercepted.values():
		net_earnings += sale_value
	var meter: ProgressBar = _session.get_node("HUD/ProgressPanel/Margin/Readouts/PollutionBar")
	_check(is_instance_valid(old_debris.front()) and _world.trash_manager.items.has(old_debris.front()), "Installation removed earlier shoreward debris")
	_check(_shop.coins == before - price + net_earnings and _coin_amount.text == "%d gold" % _shop.coins, "Visible wallet did not reconcile with intercepted sales")
	_check(is_zero_approx(_water.displayed_pollution) and meter.value == 0.0 and _visible_ambient_count() == 6, "Water, HUD, or fish did not settle at clean conditions")
	print("Stable 0%% after %d net interceptions (+%d gold), with earlier debris still in the water" % [intercepted.size(), net_earnings])
	return _check(intercepted.size() >= 3, "The net did not intercept recurring arrivals")


func _sample_starter_supply() -> void:
	if not is_instance_valid(_world):
		return
	for item: OceanTrash in _world.trash_manager.items:
		var id: int = item.get_instance_id()
		if item.can_hook() and not _seen_starter_items.has(id) and item.global_position.x - _world.shore_start.x <= _starter_range:
			_seen_starter_items[id] = true
			_new_starter_times.append(_seconds_since(_start_ticks))


func _record_threshold(normalized: float) -> void:
	if _first_threshold_time < 0.0 and normalized <= _world.catchable_fish.pollution_threshold:
		_first_threshold_time = _seconds_since(_start_ticks)


func _count_cleanup_cue(_watch_cue: String) -> void:
	_cleanup_cues += 1


func _count_trophy_visit(fish: CatchableFish) -> void:
	if fish.species.timing_checks == 3:
		_trophy_visits += 1


func _check_cleanup_sites() -> void:
	for frame: int in 300:
		if not _world.cleanup_work.is_processing():
			break
		await process_frame
	_check(_cleanup_cues == _shop.cleanup_projects.size(), "A project work cue was missing or repeated")
	for index: int in _shop.cleanup_projects.size():
		var site: CleanupSite = _world.cleanup_work.site_for_project(_shop.cleanup_projects[index])
		_check(_shop.is_cleanup_complete(index) and site.is_complete, "A project failed to leave a completed site")


func _buy(catalog: String, index: int, cost: int) -> bool:
	if not await _fund(cost) or not await _open_shop():
		return false
	_click_button(_panel.get_node("%Buy"))
	await process_frame
	var column: Control = _panel.get_node("%" + catalog)
	var button: Button = column.find_children("*", "Button", true, false)[index]
	var scroll: ScrollContainer = _panel.get_node("%BuyScroll")
	scroll.ensure_control_visible(button)
	await process_frame
	if not _check(not button.disabled, "Funded purchase remained unavailable"):
		return false
	var before: int = _shop.coins
	_click_button(button)
	var purchased: bool = _check(_shop.coins == before - cost and button.disabled and _coin_amount.text == "%d gold" % _shop.coins, "Purchase did not debit once and update the visible balance")
	if catalog == "Gear" and index < _shop.rod_upgrades.size():
		var art: Sprite2D = _rod.get_node("Pivot/Rod")
		_check(art.texture == _shop.rod_upgrades[index].art, "Rod purchase did not change the equipped artwork")
	_click_button(_panel.get_node("%Close"))
	return purchased and _check(not _panel.visible and _rod.state == FishingRod.State.IDLE, "Closing the shop changed fishing state")


func _fund(cost: int) -> bool:
	for trip: int in 15:
		if _shop.coins >= cost:
			return true
		while _sack.free_slots > 0:
			if not await _catch_trash():
				return false
		if not _return_checked:
			var full_count: int = _sack.item_count
			var full_pol: int = _world.pollution.trash_collected
			var next_item: OceanTrash = _nearest_trash()
			if is_instance_valid(next_item):
				await _align(next_item.global_position.y)
				if not await _cast_and_return(next_item.global_position):
					return false
			_check(_sack.item_count == full_count and _world.pollution.trash_collected == full_pol, "Full Sack removed an extra target")
		if not await _sell():
			return false
	return _check(_shop.coins >= cost, "Recurring trash income did not fund a purchase")


func _sell() -> bool:
	var walk_started: int = Engine.get_physics_frames()
	var first_trip: bool = not _return_checked
	if first_trip:
		_check(_sack.item_count == _sack.capacity and _sack.sale_total() == _sack.capacity * _world.trash_manager.trash_sale_value, "First full Sack quote changed unexpectedly")
		Input.action_press("move_left")
		await physics_frame
		await physics_frame
		Input.action_release("move_left")
		_check(is_equal_approx(_player.velocity.length(), _player.movement_speed * (1.0 - _sack.full_slowdown)), "Full load did not slow movement")
	if not await _open_shop():
		return false
	if first_trip:
		_return_checked = true
		var travel: float = _seconds_since(walk_started)
		_check(travel < 4.0, "Walk to the shack exceeded four seconds")
		print("First full Sack walk to the shack: %.2fs" % travel)
	_click_button(_panel.get_node("%Sell"))
	await process_frame
	var sell: Button = _panel.get_node("%SellAll")
	var payout: int = _sack.sale_total()
	var before: int = _shop.coins
	var fish_in_load: bool = _sack.fish_count > 0
	_check(_intentionally_fishing or not fish_in_load, "A pre-threshold upgrade or project used fish income")
	_check(not sell.disabled and sell.text.contains(str(payout)), "Sell All did not show the full Sack payout")
	if _sale_count % 2 == 0:
		_key(KEY_F)
		_key(KEY_F)
	else:
		_click_button(sell)
		_click_button(sell)
	_sale_count += 1
	_gross_earned += payout
	_check(_shop.coins == before + payout and _sack.item_count == 0 and _coin_amount.text == "%d gold" % _shop.coins, "Sale did not update the Sack and visible balance exactly once")
	if fish_in_load:
		_fish_sale_value = payout
	else:
		_sale_trips += 1
	_click_button(_panel.get_node("%Close"))
	return _check(not _panel.visible and _rod.state == FishingRod.State.IDLE, "Sale or close click reached fishing")


func _open_shop() -> bool:
	if not _shack.is_near(_player.global_position):
		await _walk_axis(1, _shack.global_position.y)
		await _walk_axis(0, _shack.global_position.x + 17.0)
	_key(KEY_E)
	await process_frame
	return _check(_panel.visible and _rod.state == FishingRod.State.IDLE, "Approach or E failed to open the fishing shack")


func _catch_trash() -> bool:
	await _walk_to_shore()
	for attempt: int in 90:
		var item: OceanTrash = _nearest_trash()
		if item == null:
			await _wait_ticks(20)
			continue
		await _align(item.global_position.y)
		var point: Vector2 = item.global_position
		if not _rod.invalid_target_reason(point).is_empty():
			continue
		var before: int = _world.pollution.trash_collected
		if not await _cast_and_return(point):
			return false
		if _world.pollution.trash_collected > before:
			return true
	return _check(false, "No reachable live trash could be landed")


func _nearest_trash() -> OceanTrash:
	var chosen: OceanTrash
	var nearest: float = INF
	for item: OceanTrash in _world.trash_manager.items:
		if not item.can_hook():
			continue
		var point: Vector2 = item.global_position
		var origin: Vector2 = Vector2(_rod.global_position.x, point.y)
		if not _rod.invalid_target_reason_from(origin, point).is_empty() or _fish_near(point):
			continue
		var distance: float = _rod.global_position.distance_squared_to(point)
		if distance < nearest:
			chosen = item
			nearest = distance
	return chosen


func _fish_near(point: Vector2) -> bool:
	for fish: CatchableFish in _world.catchable_fish.fish:
		if fish.can_hook() and fish.global_position.distance_to(point) < fish.catch_radius + 18.0:
			return true
	return false


func _catch_fish() -> bool:
	await _walk_to_shore()
	for attempt: int in 160:
		var candidates: Array[CatchableFish] = _world.catchable_fish.fish
		if candidates.is_empty():
			await _wait_ticks(20)
			continue
		var target: CatchableFish = candidates.front()
		await _align(target.global_position.y)
		if not is_instance_valid(target) or not target.can_hook():
			continue
		var point: Vector2 = target.global_position
		if not _rod.invalid_target_reason(point).is_empty():
			continue
		if not await _cast_and_return(point):
			return false
		if _sack.fish_count > 0:
			return true
		if _sack.free_slots == 0 and not await _sell():
			return false
		if _shack.is_near(_player.global_position):
			await _walk_to_shore()
	return _check(false, "No catchable fish could be landed after cleanup")


func _reach_clean_water() -> bool:
	for attempt: int in 45:
		if _world.pollution.current_pollution == 0:
			for frame: int in 150:
				if is_zero_approx(_water.displayed_pollution):
					return true
				if _world.pollution.current_pollution > 0:
					break
				await physics_frame
		if _sack.free_slots == 0 and not await _sell():
			return false
		if not await _catch_trash():
			return false
	return _check(false, "Permanent projects and normal catches never reached fully displayed 0% pollution")


func _cast_and_return(target: Vector2, rapid: bool = false) -> bool:
	await process_frame
	_cast_click(target)
	if not _check(_rod.state == FishingRod.State.CASTING, "Valid target did not cast through viewport input"):
		return false
	if rapid:
		_cast_click(target)
		_cast_click(target)
		_check(_rod.state == FishingRod.State.CASTING, "Repeated clicks interrupted casting")
	if not await _wait_for_rod(FishingRod.State.WAITING, true):
		return false
	_check(_rod.get_hook_water_position().distance_to(target) < 2.0, "Hook landed away from the selected point")
	if _rod.state == FishingRod.State.TIMING:
		var progress: float = _rod.fish_timing_progress()
		_key(KEY_ESCAPE)
		await _wait_ticks(8)
		_check(_pause.visible and is_equal_approx(progress, _rod.fish_timing_progress()), "Pause did not freeze the timing challenge")
		_key(KEY_ESCAPE)
		await process_frame
		if not _check(not _pause.visible and _rod.state == FishingRod.State.TIMING, "Pause did not resume the visible timing challenge"):
			return false
		for stage: int in _rod.fish_timing_checks:
			while _rod.state == FishingRod.State.TIMING and _rod.fish_timing_progress() < _rod.fish_timing_zone().x + 0.04:
				await process_frame
			_key(KEY_SPACE)
		if not _check(_rod.state == FishingRod.State.WAITING, "Timed input did not secure a fish"):
			return false
	_cast_click(target)
	if rapid:
		_cast_click(target)
		_check(_rod.state == FishingRod.State.RETRIEVING, "Repeated clicks interrupted retrieval")
	if not await _wait_for_rod(FishingRod.State.IDLE):
		return false
	if _session.get_node("FishReveal").visible:
		_key(KEY_ENTER)
	return true


func _wait_for_rod(state: FishingRod.State, allow_timing: bool = false) -> bool:
	for frame: int in 230:
		if _rod.state == state or (allow_timing and _rod.state == FishingRod.State.TIMING):
			return true
		await process_frame
	return _check(false, "Fishing loop did not reach state %s" % FishingRod.State.keys()[state])


func _walk_to_shore() -> void:
	if _player.global_position.x < 760.0:
		await _walk_axis(0, _world.shore_start.x - (_rod.global_position.x - _player.global_position.x) - 2.0)


func _align(world_y: float) -> void:
	await _walk_axis(1, world_y - (_rod.global_position.y - _player.global_position.y))


func _walk_axis(axis: int, target: float) -> void:
	var positive: StringName = &"move_right" if axis == 0 else &"move_down"
	var negative: StringName = &"move_left" if axis == 0 else &"move_up"
	var direction: float = signf(target - _player.global_position[axis])
	if absf(target - _player.global_position[axis]) <= 5.0:
		return
	var action: StringName = positive if direction > 0.0 else negative
	Input.action_press(action)
	for frame: int in 360:
		await physics_frame
		if direction * (target - _player.global_position[axis]) <= 5.0:
			break
	Input.action_release(action)
	await physics_frame
	_check(absf(target - _player.global_position[axis]) < 9.0, "Movement could not reach the next shoreline or shack position")


func _wait_ticks(ticks: int) -> void:
	for tick: int in ticks:
		await physics_frame


func _seconds_since(ticks: int) -> float:
	return float(Engine.get_physics_frames() - ticks) / Engine.physics_ticks_per_second


func _visible_ambient_count() -> int:
	var ambient: Node2D = _world.get_node("Environment/AmbientFish")
	var visible_count: int = 0
	for child: Node in ambient.get_children():
		if child is Polygon2D and child.visible:
			visible_count += 1
	return visible_count


func _cast_click(world_position: Vector2) -> void:
	_mouse_click(_rod.get_canvas_transform() * world_position)


func _click_button(button: Button) -> void:
	_mouse_click(button.get_global_rect().get_center())


func _mouse_click(point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for is_pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_pressed
		root.push_input(click, true)


func _key(code: Key) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	root.push_input(key, true)
