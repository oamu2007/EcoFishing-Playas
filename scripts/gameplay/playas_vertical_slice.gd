extends Node2D

const AmbientFishScript = preload("res://scripts/gameplay/ambient_fish.gd")
const WaterSplashScript = preload("res://scripts/gameplay/water_splash.gd")
var _splash: Node2D
const FootprintsScript = preload("res://scripts/gameplay/footprints.gd")
var _footprints: Node2D
const SandDetailsScript = preload("res://scripts/gameplay/sand_details.gd")
const PlayerScript = preload("res://scripts/gameplay/player.gd")
const CatchResolverScript = preload("res://scripts/systems/catch_resolver.gd")
const SandShader: Shader = preload("res://shaders/sand.gdshader")

var shore_start: Vector2
var shore_end: Vector2

@onready var pollution: PollutionSystem = $PollutionSystem
@onready var trash_manager: TrashManager = $TrashManager
@onready var _ocean: Polygon2D = $Environment/Ocean
@onready var rod: FishingRod = $Player/FishingRod
@onready var shop: ShackShop = $ShackShop
@onready var sack: Sack = $ShackShop/Sack
@onready var catches: CatchResolverScript = $CatchResolver
@onready var catchable_fish: CatchableFishManager = $CatchableFishManager
@onready var _shack: FishingShack = $FishingShack
@onready var _beach: Polygon2D = $Environment/Beach
@onready var _player: PlayerScript = $Player
@onready var _water: WaterVisuals = $Environment/Water
@onready var _fish: AmbientFishScript = $Environment/AmbientFish


func _ready() -> void:
	# Derive world-space fishing bounds from the authored rectangular ocean.
	var bounds: Rect2 = Rect2(_ocean.to_global(_ocean.polygon[0]), Vector2.ZERO)
	for point: Vector2 in _ocean.polygon:
		bounds = bounds.expand(_ocean.to_global(point))
	rod.water_bounds = bounds
	# Account for the capsule, boundary thickness, and rod offset, rather than
	# assuming the fisherman can stand on the visible water edge.
	var body: Rect2 = _shape_bounds($Player/CollisionShape2D)
	var barrier: Rect2 = _shape_bounds($WorldBounds/OceanBarrier)
	var top: Rect2 = _shape_bounds($WorldBounds/Top)
	var bottom: Rect2 = _shape_bounds($WorldBounds/Bottom)
	var rod_offset: Vector2 = rod.global_position - _player.global_position
	var shore_x: float = barrier.position.x - (body.end.x - _player.global_position.x) - 2.0 + rod_offset.x
	shore_start = Vector2(shore_x, top.end.y - (body.position.y - _player.global_position.y) + 2.0 + rod_offset.y)
	shore_end = Vector2(shore_x, bottom.position.y - (body.end.y - _player.global_position.y) - 2.0 + rod_offset.y)
	trash_manager.trash_collected.connect(pollution.collect)
	trash_manager.trash_arrived.connect(pollution.register_trash)
	_player.sack = sack
	shop.initialize(sack, rod, pollution)
	catches.initialize(rod, sack)
	trash_manager.trash_spawned.connect(catches.register_target)
	trash_manager.initialize(rod, shore_start, shore_end)
	catchable_fish.fish_spawned.connect(catches.register_target)
	catchable_fish.fish_departed.connect(catches.unregister_target)
	catchable_fish.initialize(pollution, rod, shore_start, shore_end)
	_water.global_position = bounds.position
	_water.configure_size(bounds.size)
	_water.bind_pollution(pollution)
	_fish.configure(bounds, _water)
	_splash = WaterSplashScript.new()
	_splash.z_index = 3
	add_child(_splash)
	rod.hook_landed.connect(_on_hook_landed)
	_footprints = FootprintsScript.new()
	add_child(_footprints)
	move_child(_footprints, $Environment.get_index() + 1)
	_footprints.configure(_player)
	_add_sand_details()


func _process(_delta: float) -> void:
	var near_shack: bool = can_open_shack()
	_shack.set_prompt_visible(near_shack)
	rod.show_idle_status = not near_shack


func can_open_shack() -> bool:
	return not rod.is_active() and not rod.input_locked and _shack.is_near(_player.global_position)


func set_shop_open(value: bool) -> void:
	_player.input_locked = value
	rod.input_locked = value


func _shape_bounds(collider: CollisionShape2D) -> Rect2:
	return collider.global_transform * collider.shape.get_rect()


func _on_hook_landed(point: Vector2) -> void:
	_splash.play_at(point, pollution.normalized_pollution)


func _add_sand_details() -> void:
	var beach_area: Rect2 = Rect2(_beach.position + _beach.polygon[0], Vector2.ZERO)
	for point: Vector2 in _beach.polygon:
		beach_area = beach_area.expand(_beach.position + point)
	var grain: ColorRect = ColorRect.new()
	grain.position = beach_area.position
	grain.size = beach_area.size
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sand_material: ShaderMaterial = ShaderMaterial.new()
	sand_material.shader = SandShader
	grain.material = sand_material
	$Environment.add_child(grain)
	var sand_details: SandDetailsScript = SandDetailsScript.new()
	sand_details.area = beach_area.grow(-20.0)
	sand_details.area.size.x -= 60.0
	$Environment.add_child(sand_details)