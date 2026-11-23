extends Node2D

@export_range(20.0, 70.0) var mesh_width: float = 46.0
@export_range(24.0, 120.0) var buoy_spacing: float = 64.0
@export_range(0.15, 3.0) var deploy_seconds: float = 0.65
@export_range(0.3, 3.0) var sale_cue_seconds: float = 1.15

const ROPE: Color = Color("1b5457")
const MESH: Color = Color("7ed6bba6")
const FLOAT: Color = Color("ffc969")

var _span: Vector2
var _cue_tween: Tween
var _cue_gold: int = 0

@onready var _sale_cue: Label = $SaleCue


func deploy(world_span: Vector2) -> void:
	_span = world_span - Vector2.ONE * global_position.y
	modulate.a = 0.0
	show()
	queue_redraw()
	create_tween().tween_property(self, "modulate:a", 1.0, deploy_seconds)


func show_sale(world_point: Vector2, value: int) -> void:
	if _cue_tween != null:
		_cue_tween.kill()
	_cue_gold += value
	_sale_cue.text = "+%d gold" % _cue_gold
	_sale_cue.position = Vector2(-116.0, clampf(to_local(world_point).y - 18.0, _span.x + 26.0, _span.y - 26.0))
	_sale_cue.modulate.a = 1.0
	_sale_cue.show()
	_cue_tween = create_tween().set_parallel()
	_cue_tween.tween_property(_sale_cue, "position:y", _sale_cue.position.y - 20.0, sale_cue_seconds)
	_cue_tween.tween_property(_sale_cue, "modulate:a", 0.0, sale_cue_seconds * 0.4).set_delay(sale_cue_seconds * 0.6)
	_cue_tween.chain().tween_callback(_hide_sale)


func _hide_sale() -> void:
	_cue_gold = 0
	_sale_cue.hide()


func _draw() -> void:
	var half_width: float = mesh_width * 0.5
	var panel: Rect2 = Rect2(-half_width, _span.x, mesh_width, _span.y - _span.x)
	draw_rect(panel.grow(5.0), Color("163b4159"))
	draw_rect(panel, Color("163b4199"))
	for mesh_top: float in range(ceili(_span.x), floori(_span.y), 20):
		var mesh_bottom: float = minf(mesh_top + 20.0, _span.y)
		draw_line(Vector2(-half_width, mesh_top), Vector2(half_width, mesh_bottom), MESH, 1.2, true)
		draw_line(Vector2(half_width, mesh_top), Vector2(-half_width, mesh_bottom), MESH, 1.2, true)
	draw_rect(panel, ROPE, false, 3.0, true)
	draw_line(Vector2(0.0, _span.x), Vector2(0.0, _span.y), ROPE, 2.5, true)
	var buoy_count: int = maxi(1, ceili(panel.size.y / buoy_spacing))
	for index: int in range(buoy_count + 1):
		var y: float = lerpf(_span.x, _span.y, float(index) / buoy_count)
		draw_line(Vector2(-half_width - 5.0, y), Vector2(half_width + 5.0, y), ROPE, 3.0, true)
		for x: float in [-half_width, half_width]:
			var point: Vector2 = Vector2(x, y)
			draw_circle(point, 8.0, ROPE, true, -1.0, true)
			draw_circle(point, 6.0, FLOAT, true, -1.0, true)
			draw_circle(point + Vector2(-1.5, -1.5), 2.0, Color("ffe7aa"), true, -1.0, true)
