extends "res://scripts/gameplay/main.gd"

const REVIEW_THEME: Theme = preload("res://ui/themes/coastal_field_guide.tres")
const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")


func _ready() -> void:
	super._ready()
	_request_start()


func _start_session() -> void:
	super._start_session()
	var world: LevelScript = _session.get_node("World")
	world.trash_manager.arrivals_enabled = false
	for item: OceanTrash in world.trash_manager.items:
		world.catches.unregister_target(item)
		item.queue_free()
	world.trash_manager.items.clear()
	var empty: Dictionary[int, int] = {}
	world.pollution.initialize(empty, 0)
	world.catchable_fish.spawns_enabled = false

	var instructions: Label = Label.new()
	instructions.theme = REVIEW_THEME
	instructions.theme_type_variation = &"FieldNote"
	instructions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.text = "1  Common fish    ·    2  Rare fish    ·    3  Trophy fish\nClick or press Space in green, then click to reel in."
	_session.get_node("HUD").add_child(instructions)
	instructions.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode not in [KEY_1, KEY_2, KEY_3] or _session == null or not _session.can_process():
		return
	var world: LevelScript = _session.get_node("World")
	var rod: FishingRod = world.rod
	if rod.is_active() or rod.input_locked:
		return
	get_viewport().set_input_as_handled()
	if world.sack.free_slots == 0:
		world.sack.remove_entries(world.sack.entries())
	var checks: int = event.physical_keycode - KEY_1 + 1
	var manager: CatchableFishManager = world.catchable_fish
	var choices: Array[FishSpecies] = manager.species_catalog.filter(func(species: FishSpecies) -> bool: return species.timing_checks == checks)
	var species: FishSpecies = choices[manager._rng.randi_range(0, choices.size() - 1)]
	var player: CharacterBody2D = world.get_node("Player")
	var rod_offset: Vector2 = rod.global_position - player.global_position
	var shore_y: float = (world.shore_start.y + world.shore_end.y) * 0.5
	player.global_position = Vector2(world.shore_start.x, shore_y) - rod_offset
	var center: Vector2 = manager._spawn_bounds().get_center()
	manager._add_fish(center, species)
	# The entire swim loop fits inside the hook's catch radius at this aim point.
	rod._start_cast(center)
