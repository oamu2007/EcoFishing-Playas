extends Control

const START_ANGLE: float = -PI * 0.5
const RADIUS: float = 44.0
const CREAM: Color = Color("#fff2ce")
const INK: Color = Color("#153b3b")
const MISS: Color = Color("#ac4545")
const SUCCESS: Color = Color("#3f9462")

var _progress: float
var _zone: Vector2
var _showing_result: bool


func update_timing(rod: FishingRod, guard_used: bool) -> void:
	_showing_result = false
	_progress = rod.fish_timing_progress()
	_zone = rod.fish_timing_zone()
	$Title.text = "Fish on!" if rod.fish_timing_checks == 1 else "Check %d of %d" % [rod.fish_timing_stage, rod.fish_timing_checks]
	$Cue.text = "Click or press Space in the green arc"
	$Guard.visible = guard_used or rod.fish_timing_saves_left > 0
	$Guard.text = "Slip guard used · try again" if guard_used else "Slip guard ready"
	queue_redraw()


func show_result(title: String, cue: String) -> void:
	_showing_result = true
	$Title.text = title
	$Cue.text = cue
	$Guard.hide()
	show()
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = Vector2(size.x * 0.5, 57.0)
	if _showing_result:
		draw_rect(Rect2(center - Vector2(88.0, 16.0), Vector2(176.0, 32.0)), INK)
		return
	draw_circle(center, 57.0, INK, true, -1.0, true)
	draw_arc(center, RADIUS, 0.0, TAU, 80, MISS, 9.0, true)
	var from: float = START_ANGLE + _zone.x * TAU
	var to: float = START_ANGLE + _zone.y * TAU
	draw_arc(center, RADIUS, from, to, 24, SUCCESS, 13.0, true)
	for angle: float in [from, to]:
		var direction: Vector2 = Vector2.from_angle(angle)
		draw_line(center + direction * 35.0, center + direction * 53.0, CREAM, 2.0, true)
	var marker: Vector2 = center + Vector2.from_angle(START_ANGLE + _progress * TAU) * RADIUS
	draw_circle(marker, 8.0, INK, true, -1.0, true)
	draw_circle(marker, 5.0, CREAM, true, -1.0, true)
