extends SceneTree

const MAIN: PackedScene = preload("res://scenes/gameplay/main.tscn")
const FISH: PackedScene = preload("res://scenes/gameplay/catchable_fish.tscn")
const AudioScript = preload("res://scripts/gameplay/game_audio.gd")
const WorldScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")

var _failures: int = 0
var _cues: Dictionary[AudioScript.Cue, int] = {}
var _playback: AudioStreamPlayback


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = MAIN.instantiate()
	root.add_child(main)
	var audio: AudioScript = main.get_node("GameAudio")
	audio.cue_started.connect(_record_cue)
	var music: AudioStreamPlayer = audio.get_node("Music")
	var stream: AudioStreamMP3 = music.stream
	_playback = music.get_stream_playback()
	_check(stream.loop and stream.get_length() > 110.0, "The supplied track was not playing as a loop")
	await create_timer(0.3).timeout
	var last_position: float = music.get_playback_position()
	_check(last_position > 0.05, "The music did not progress on the title screen")

	main.get_node("SessionMenu").get_node("%StartSession").pressed.emit()
	await process_frame
	var session: Node = main.get_node("Session")
	var world: WorldScript = session.get_node("World")
	_check_music(main, music, stream, last_position)
	Input.action_press("move_right")
	await create_timer(0.35).timeout
	Input.action_release("move_right")
	_check(_seen(AudioScript.Cue.FOOTSTEP) >= 1, "Walking did not play footsteps")

	var pause: CanvasLayer = main.get_node("PauseMenu")
	_key(KEY_ESCAPE)
	var paused_at: float = music.get_playback_position()
	await create_timer(0.25).timeout
	_check(pause.visible and music.get_playback_position() > paused_at + 0.1, "Pausing the session stopped the music")
	_key(KEY_ESCAPE)
	_check_music(main, music, stream, paused_at)

	await _exercise_fishing(world)
	var player: CharacterBody2D = world.get_node("Player")
	player.global_position = world.get_node("FishingShack").global_position
	_key(KEY_E)
	var trader: CanvasLayer = session.get_node("ShackPanel")
	trader.get_node("%Sell").pressed.emit()
	var item: Button = trader.get_node("%SackItems").get_child(0)
	item.pressed.emit()
	trader.get_node("%TrayItems").get_child(0).pressed.emit()
	_key(KEY_F)
	_key(KEY_F)
	_check(_seen(AudioScript.Cue.PICKUP) == 1 and _seen(AudioScript.Cue.DROP) == 1, "Inventory staging lost its pickup or drop cue")
	_check(_seen(AudioScript.Cue.SALE) == 1 and world.sack.item_count == 0, "A full or repeated sale played the wrong sound")
	var trader_at: float = music.get_playback_position()
	await create_timer(0.3).timeout
	_check_music(main, music, stream, trader_at)
	_key(KEY_ESCAPE)
	trader.get_node("%Buy").pressed.emit()
	var cleanup: Button = trader.get_node("%Cleanup").find_children("*", "Button", true, false)[0]
	cleanup.pressed.emit()
	cleanup.pressed.emit()
	trader.get_node("%Close").pressed.emit()
	_check(_seen(AudioScript.Cue.PURCHASE) == 1 and _seen(AudioScript.Cue.CLEANUP) == 1, "Purchase or cleanup work did not cue once")

	await create_timer(0.55).timeout
	_key(KEY_ESCAPE)
	pause.get_node("%Restart").pressed.emit()
	pause.get_node("%ConfirmDiscard").pressed.emit()
	await process_frame
	_check_music(main, music, stream, trader_at)
	_key(KEY_ESCAPE)
	pause.get_node("%QuitToTitle").pressed.emit()
	pause.get_node("%ConfirmDiscard").pressed.emit()
	await process_frame
	_check(not main.has_node("Session"), "Quit did not return to title")
	_check_music(main, music, stream, trader_at)
	main.get_node("SessionMenu").get_node("%StartSession").pressed.emit()
	await process_frame
	_check_music(main, music, stream, trader_at)
	_check(_seen(AudioScript.Cue.CONFIRM) >= 3 and _seen(AudioScript.Cue.CANCEL) >= 1 and _seen(AudioScript.Cue.NAVIGATE) >= 1, "Menu controls lost distinct cues")
	_check(audio.get_node("Effects").stream.polyphony == 8, "The effects player lost its voice limit")
	await audio.prepare_shutdown()
	main.free()
	print("Audio smoke test: %d failures. Driver: %s." % [_failures, AudioServer.get_driver_name()])
	quit(0 if _failures == 0 else 1)


func _exercise_fishing(world: WorldScript) -> void:
	var rod: FishingRod = world.rod
	var player: CharacterBody2D = world.get_node("Player")
	var spot: Vector2 = world.shore_start + Vector2(145.0, 320.0)
	player.global_position = Vector2(world.shore_start.x, spot.y) - (rod.global_position - player.global_position)
	world.trash_manager.arrivals_enabled = false
	world.catchable_fish.set_physics_process(false)
	for item: OceanTrash in world.trash_manager.items:
		item.global_position.y = spot.y + 120.0
		item.set_physics_process(false)
	for attempt: int in 2:
		var fish: CatchableFish = FISH.instantiate()
		fish.species = world.catchable_fish.species_catalog.back()
		fish.length_cm = 24
		world.add_child(fish)
		fish.global_position = spot
		fish.set_physics_process(false)
		world.catches.register_target(fish)
		fish.visit_ended.connect(world.catches.unregister_target)
		rod._start_cast(spot)
		await create_timer(rod.equipped_cast_duration() + 0.08).timeout
		_check(rod.state == FishingRod.State.TIMING, "Audio route did not hook the timing target")
		if attempt == 0:
			_key(KEY_SPACE)
			_check(_seen(AudioScript.Cue.TIMING_FAILURE) == 1, "A missed timing input did not play its cue")
		else:
			for step: int in 2:
				var zone: Vector2 = rod.fish_timing_zone()
				while rod.state == FishingRod.State.TIMING and rod.fish_timing_progress() < (zone.x + zone.y) * 0.5:
					await process_frame
				_key(KEY_SPACE)
			_mouse_reel(rod, spot)
			await create_timer(rod.equipped_retrieval_duration() + 0.08).timeout
			_check(world.sack.fish_count == 1 and _seen(AudioScript.Cue.CATCH) == 1 and _seen(AudioScript.Cue.TIMING_SUCCESS) == 2, "Timing or the landed fish lost a success cue")
	rod._start_cast(spot)
	await create_timer(rod.equipped_cast_duration() + 0.08).timeout
	_mouse_reel(rod, spot)
	await create_timer(rod.equipped_retrieval_duration() + 0.08).timeout
	_check(_seen(AudioScript.Cue.CAST) == 3 and _seen(AudioScript.Cue.SPLASH) == 3 and _seen(AudioScript.Cue.REEL) == 2 and _seen(AudioScript.Cue.MISS) == 1, "Cast, splash, reel, or empty return cues did not follow the rod")


func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)


func _mouse_reel(rod: FishingRod, point: Vector2) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = rod.get_canvas_transform() * point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)


func _check_music(main: Node, music: AudioStreamPlayer, stream: AudioStreamMP3, last_position: float) -> void:
	var music_players: int = 0
	for player: Node in main.find_children("*", "AudioStreamPlayer", true, false):
		if player.bus == &"Music" and player.playing:
			music_players += 1
	_check(music_players == 1 and music.stream == stream and music.get_stream_playback() == _playback and music.get_playback_position() >= last_position, "A transition stopped, duplicated, or restarted the track")


func _record_cue(cue: AudioScript.Cue) -> void:
	_cues[cue] = _seen(cue) + 1


func _seen(cue: AudioScript.Cue) -> int:
	return _cues.get(cue, 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
