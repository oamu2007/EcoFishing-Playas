extends SceneTree

const REVIEW: PackedScene = preload("res://tests/fish_discovery_review.tscn")
const AudioScript = preload("res://scripts/gameplay/game_audio.gd")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const RevealScript = preload("res://scripts/ui/fish_reveal.gd")
const SessionScript = preload("res://scripts/gameplay/session.gd")

var _failures: int = 0
var _cues: Array[AudioScript.Cue] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for test_size: Vector2i in [Vector2i(1280, 720), Vector2i(800, 450)]:
		root.size = test_size
		await _exercise()
		print("Fish discovery review route at %s: %d cumulative failures" % [test_size, _failures])
	quit(0 if _failures == 0 else 1)


func _exercise() -> void:
	var main: Node = REVIEW.instantiate()
	root.add_child(main)
	await process_frame
	var audio: AudioScript = main.get_node("GameAudio")
	audio.cue_started.connect(_cues.append)
	_cues.clear()
	var session: SessionScript = main.get_node("Session")
	var world: LevelScript = session.get_node("World")
	var rod: FishingRod = world.rod
	var reveal: RevealScript = session.get_node("FishReveal")
	var pause: CanvasLayer = main.get_node("PauseMenu")
	var manager: CatchableFishManager = world.catchable_fish
	_key(KEY_4)
	var small: CatchableFish = manager.fish[0]
	var large: CatchableFish = manager.fish[1]
	var small_scale: float = small.get_node("Visual/Silhouette").scale.x
	var large_scale: float = large.get_node("Visual/Silhouette").scale.x
	_check(small.species == large.species and large_scale >= small_scale * 1.5 and is_equal_approx(small.catch_radius, large.catch_radius), "Same-species comparison did not produce visibly distinct art at identical catch radius")
	_key(KEY_1)
	rod._process(rod.equipped_cast_duration())
	rod._process(rod.fish_timing_duration)
	_check(not reveal.visible and world.sack.fish_count == 0 and _cues.count(AudioScript.Cue.FISH_DISCOVERY) == 0, "A timing escape marked the species discovered")

	for slot: int in world.sack.capacity:
		world.sack.store("Trash", slot, false)
	var spot: Vector2 = manager._spawn_bounds().get_center()
	var blocked: CatchableFish = manager._add_fish(spot, manager.species_catalog[0], 10)
	rod._start_cast(spot)
	rod._process(rod.equipped_cast_duration())
	_check(not blocked.hooked and not reveal.visible and world.sack.fish_count == 0, "Full Sack discovered a fish that could not attach")
	_reel(rod)
	blocked.escape()
	world.sack.remove_entries(world.sack.entries())
	await create_timer(0.65).timeout
	_land_fixture_fish(world, reveal, KEY_1, small_scale)
	_check(reveal.visible and _cues.count(AudioScript.Cue.FISH_DISCOVERY) == 1 and root.gui_get_focus_owner() == reveal.get_node("%Continue"), "First common fish did not reveal once with focused Continue")
	var common_background: Color = reveal.get_node("%Illustration").color
	var small_reveal_scale: float = reveal.get_node("%FishArt").scale.x
	await process_frame
	var initial_cast: int = rod.cast_number
	var player: CharacterBody2D = world.get_node("Player")
	var initial_position: Vector2 = player.global_position
	Input.action_press("move_up")
	_key(KEY_E)
	_key(KEY_F)
	_key(KEY_H)
	_key(KEY_ENTER, true)
	_click(Vector2(20.0, 80.0))
	await physics_frame
	await physics_frame
	Input.action_release("move_up")
	_check(reveal.visible and not session.get_node("ShackPanel").visible and not session.get_node("HUD").is_help_enabled() and rod.cast_number == initial_cast and player.global_position == initial_position and world.sack.fish_count == 1, "Gameplay input escaped the discovery screen")
	_key(KEY_ESCAPE)
	_check(not reveal.visible and not pause.visible and world.can_process(), "Escape did not dismiss discovery cleanly")
	await create_timer(0.65).timeout
	_land_fixture_fish(world, reveal, KEY_2, large_scale)
	_check(not reveal.visible and world.sack.fish_count == 2 and _cues.count(AudioScript.Cue.FISH_DISCOVERY) == 1, "Repeat common catch replayed discovery or lost its catch")
	await create_timer(0.65).timeout
	_land_fixture_fish(world, reveal, KEY_3)
	_check(reveal.visible and reveal.get_node("%Rarity").text == "Trophy catch" and reveal.get_node("%Illustration").color != common_background and _cues.count(AudioScript.Cue.TROPHY_DISCOVERY) == 1, "The trophy did not get its distinct reveal and cue")
	await process_frame
	var button: Button = reveal.get_node("%Continue")
	var viewport_rect: Rect2 = root.get_visible_rect()
	_check(viewport_rect.encloses(button.get_global_rect()) and viewport_rect.encloses(reveal.get_node("%Illustration").get_global_rect()), "The reveal or Continue button overflowed the viewport")
	initial_cast = rod.cast_number
	_click(button.get_global_rect().get_center())
	_check(not reveal.visible and rod.cast_number == initial_cast, "Mouse dismissal did not return cleanly to gameplay")
	world.sack.remove_entries(world.sack.entries())
	await create_timer(1.1).timeout
	_land_fixture_fish(world, reveal, KEY_3)
	_check(not reveal.visible and _cues.count(AudioScript.Cue.TROPHY_DISCOVERY) == 1, "Repeat trophy replayed the discovery")
	_key(KEY_ESCAPE)
	pause.get_node("%Restart").pressed.emit()
	pause.get_node("%ConfirmDiscard").pressed.emit()
	await create_timer(0.65).timeout
	session = main.get_node("Session")
	world = session.get_node("World")
	reveal = session.get_node("FishReveal")
	_land_fixture_fish(world, reveal, KEY_2, large_scale)
	_check(reveal.visible and world.sack.fish_count == 1 and _cues.count(AudioScript.Cue.FISH_DISCOVERY) == 2, "Start fresh did not reset discoveries")
	_check(reveal.get_node("%FishArt").scale.x > small_reveal_scale * 1.2, "Two lengths of the same species looked the same in the reveal")
	_key(KEY_ENTER)
	_check(not reveal.visible and world.can_process(), "Enter did not dismiss discovery")
	await audio.prepare_shutdown()
	main.free()


func _land_fixture_fish(world: LevelScript, reveal: RevealScript, key: Key, expected_scale: float = 0.0) -> void:
	var rod: FishingRod = world.rod
	_key(key)
	var fish: CatchableFish = world.catchable_fish.fish.back()
	var value: int = fish.sale_price()
	var length_cm: int = fish.length_cm
	var count: int = world.sack.fish_count
	rod._process(rod.equipped_cast_duration())
	_check(fish.hooked and not reveal.visible, "Fixture fish was not hooked or showed a premature discovery")
	if expected_scale > 0.0:
		_check(is_equal_approx(fish.get_node("Visual/Silhouette").scale.x, expected_scale), "Hooking changed the rolled artwork size")
	while rod.state == FishingRod.State.TIMING:
		var zone: Vector2 = rod.fish_timing_zone()
		rod._process(rod.fish_timing_duration * (zone.x + zone.y) * 0.5)
		_key(KEY_SPACE)
	_check(not reveal.visible and world.sack.fish_count == count, "Securing the fish revealed it before landing")
	_reel(rod)
	var entry: Sack.Entry = world.sack.entries().back()
	_check(rod.state == FishingRod.State.IDLE and world.sack.fish_count == count + 1 and entry.value == value, "Landing failed to store the fish at its exact value")
	if reveal.visible:
		_check(reveal.get_node("%Length").text == "%d cm" % length_cm and reveal.get_node("%SaleValue").text == "%d gold" % value and reveal.get_node("%Species").text == fish.species.title, "Discovery details diverged from the landed catch")


func _reel(rod: FishingRod) -> void:
	_click(rod.get_canvas_transform() * rod.get_hook_water_position())
	rod._process(rod.equipped_retrieval_duration())


func _key(code: Key, echo: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.echo = echo
	event.pressed = true
	root.push_input(event, true)


func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
