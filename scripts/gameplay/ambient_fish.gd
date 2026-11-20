extends Node2D

const SILHOUETTE: Array[Vector2] = [
	Vector2(14, 0), Vector2(8, 4), Vector2(1, 5), Vector2(-8, 2),
	Vector2(-15, 5), Vector2(-13, 0), Vector2(-15, -5), Vector2(-8, -2),
	Vector2(-1, -5), Vector2(7, -4),
]
const SILHOUETTE_RADIUS: float = 17.0
const ROUTE_CENTERS: Array[Vector2] = [
	Vector2(0.29, 0.13), Vector2(0.33, 0.50), Vector2(0.31, 0.86),
	Vector2(0.67, 0.26), Vector2(0.72, 0.63), Vector2(0.65, 0.77),
]
const ROUTE_RADIUS: Vector2 = Vector2(0.16, 0.06)
const EARLY_GROUP_SIZE: int = 3
const REVEAL_STAGGER: float = 0.035

@export_range(0.01, 1.0) var early_reveal_pollution: float = 0.79
@export_range(0.01, 1.0) var late_reveal_pollution: float = 0.43
@export_range(0.01, 1.0) var fade_width: float = 0.24
@export_range(34.0, 500.0) var nearshore_width: float = 280.0
@export var murky_tint: Color = Color(0.12, 0.28, 0.30, 0.56)
@export var clear_tint: Color = Color(0.06, 0.25, 0.32, 0.72)

var _water: WaterVisuals
var _swim_area: Rect2
var _elapsed: float = 0.0
var _fish: Array[Polygon2D] = []


func _ready() -> void:
	set_process(false)
	var polygon: PackedVector2Array = PackedVector2Array(SILHOUETTE)
	for _center: Vector2 in ROUTE_CENTERS:
		var silhouette: Polygon2D = Polygon2D.new()
		silhouette.polygon = polygon
		silhouette.antialiased = true
		silhouette.hide()
		add_child(silhouette)
		_fish.append(silhouette)


func configure(water_bounds: Rect2, water: WaterVisuals) -> void:
	global_position = water_bounds.position
	var area_size: Vector2 = to_local(water_bounds.end)
	area_size.x = minf(area_size.x, nearshore_width)
	# Reserve room for the full rotated silhouette, even in a small water rectangle.
	var fish_scale: float = minf(1.0, minf(area_size.x, area_size.y) / (4.0 * SILHOUETTE_RADIUS))
	var inset: float = SILHOUETTE_RADIUS * fish_scale
	_swim_area = Rect2(Vector2.ZERO, area_size).grow(-inset)
	for fish: Polygon2D in _fish:
		fish.scale = Vector2.ONE * fish_scale
	_process(0.0)
	set_process(water_bounds.has_area())
	if is_instance_valid(_water):
		_water.displayed_pollution_changed.disconnect(_on_displayed_pollution_changed)
	_water = water
	_water.displayed_pollution_changed.connect(_on_displayed_pollution_changed)
	_on_displayed_pollution_changed(_water.displayed_pollution)


func _process(delta: float) -> void:
	_elapsed += delta
	var radius: Vector2 = _swim_area.size * ROUTE_RADIUS
	for index: int in range(_fish.size()):
		var center: Vector2 = _swim_area.position + _swim_area.size * ROUTE_CENTERS[index]
		var phase: float = TAU * _elapsed / (9.0 + index) + index * 2.4
		var offset: Vector2 = Vector2(cos(phase), sin(phase))
		_fish[index].position = center + radius * offset
		_fish[index].rotation = Vector2(-radius.x * offset.y, radius.y * offset.x).angle()


func _on_displayed_pollution_changed(pollution: float) -> void:
	var tint: Color = clear_tint.lerp(murky_tint, pollution)
	for index: int in range(_fish.size()):
		var start: float = early_reveal_pollution if index < EARLY_GROUP_SIZE else late_reveal_pollution
		start = maxf(0.01, start - (index % EARLY_GROUP_SIZE) * REVEAL_STAGGER)
		var full: float = maxf(0.0, start - fade_width)
		var opacity: float = tint.a * (1.0 - smoothstep(full, start, pollution))
		_fish[index].color = Color(tint.r, tint.g, tint.b, opacity)
		_fish[index].visible = opacity > 0.0 and _swim_area.has_area()
