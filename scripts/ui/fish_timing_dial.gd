extends Control

const START_ANGLE: float = -PI * 0.5
const RADIUS: float = 44.0
const CREAM: Color = Color("#fff2ce")
const INK: Color = Color("#153b3b")
const MISS: Color = Color("#ac4545")
const SUCCESS: Color = Color("#3f9462")
const STAGE_COLORS: Array[Color] = [Color("#f4ce80"), Color("#a4e7f1"), Color("#b2e8b7")]

var _progress: float
var _zone: Vector2
var _showing_result: bool

@onready var _title: Label = $Title
@onready var _cue: Label = $Cue
@onready var _guard: Label = $Guard


func update_timing(rod: FishingRod, guard_used: bool) -> void:
	_showing_result = false
	_progress = rod.fish_timing_progress()
	_zone = rod.fish_timing_zone()
	var multi_check: bool = rod.fish_timing_checks > 1
	_title.text = "%d/%d" % [rod.fish_timing_stage, rod.fish_timing_checks] if multi_check else "Fish on!"
	_title.add_theme_color_override("font_color", STAGE_COLORS[(rod.fish_timing_stage - 1) % STAGE_COLORS.size()] if multi_check else CREAM)
	_cue.text = "Click or press Space in the green arc"
	_guard.visible = guard_used or rod.fish_timing_saves_left > 0
	_guard.text = "Slip guard used · try again" if guard_used else "Slip guard ready"
	queue_redraw()


func show_result(title: String, cue: String) -> void:
	_showing_result = true
	_title.text = title
	_title.add_theme_color_override("font_color", CREAM)
	_cue.text = cue
	_guard.hide()
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
