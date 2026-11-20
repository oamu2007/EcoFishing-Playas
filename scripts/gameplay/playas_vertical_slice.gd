extends Node2D

const AmbientFishScript = preload("res://scripts/gameplay/ambient_fish.gd")
const WaterSplashScript = preload("res://scripts/gameplay/water_splash.gd")
var _splash: Node2D
const FootprintsScript = preload("res://scripts/gameplay/footprints.gd")
var _footprints: Node2D
const SandDetailsScript = preload("res://scripts/gameplay/sand_details.gd")
const SandShader: Shader = preload("res://shaders/sand.gdshader")

var shore_start: Vector2
var shore_end: Vector2

@onready var pollution: PollutionSystem = $PollutionSystem
@onready var trash_manager: TrashManager = $TrashManager
@onready var _ocean: Polygon2D = $Environment/Ocean
@onready var rod: FishingRod = $Player/FishingRod
@onready var _player: CharacterBody2D = $Player
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
	trash_manager.trash_collected.connect(_on_trash_collected)
	trash_manager.trash_arrived.connect(pollution.register_trash)
	trash_manager.initialize(rod, shore_start, shore_end)
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


func _shape_bounds(collider: CollisionShape2D) -> Rect2:
	return collider.global_transform * collider.shape.get_rect()


func _on_trash_collected(item_id: int, _type_name: String) -> void:
	pollution.collect(item_id)


func _on_hook_landed(point: Vector2) -> void:
	_splash.play_at(point, pollution.normalized_pollution)


func _add_sand_details() -> void:
	# Capa de grano/lomas sobre la arena (el tamaño es el del polígono Beach)
	var grain: ColorRect = ColorRect.new()
	grain.size = Vector2(840, 900)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sand_material: ShaderMaterial = ShaderMaterial.new()
	sand_material.shader = SandShader
	grain.material = sand_material
	$Environment.add_child(grain)
	# Piedritas, conchas y marcas de viento encima del grano
	$Environment.add_child(SandDetailsScript.new())