extends CanvasLayer

signal start_requested

const ShorelineIllustration = preload("res://scripts/ui/shoreline_illustration.gd")

var _feedback_tweens: Dictionary[Button, Tween] = {}

@onready var _start: Button = %StartSession
@onready var _shoreline: ShorelineIllustration = %Shoreline


func _ready() -> void:
	_start.pressed.connect(start_requested.emit)
	_start.mouse_entered.connect(_animate_button.bind(_start, 1.014))
	_start.mouse_exited.connect(_animate_button.bind(_start, 1.0))
	_start.button_down.connect(_animate_button.bind(_start, 0.98))
	_start.button_up.connect(_animate_button.bind(_start, 1.0))
	_apply_pressed_style(_start)


func open() -> void:
	_start.text = "New Game"
	_start.disabled = false
	show()
	_shoreline.set_motion_active(true)
	_start.grab_focus()


func set_transition_pending() -> void:
	_start.disabled = true
	_start.text = "Opening shoreline…"


func dismiss() -> void:
	hide()
	_shoreline.set_motion_active(false)
	for button: Button in _feedback_tweens:
		_feedback_tweens[button].kill()
		button.scale = Vector2.ONE
	_feedback_tweens.clear()


func _animate_button(button: Button, target_scale: float) -> void:
	if not visible or button.disabled:
		return
	if _feedback_tweens.has(button):
		_feedback_tweens[button].kill()
	button.pivot_offset = button.size * 0.5
	var feedback: Tween = create_tween()
	feedback.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	feedback.tween_property(button, "scale", Vector2.ONE * target_scale, 0.1)
	_feedback_tweens[button] = feedback


func _apply_pressed_style(button: Button) -> void:
	var pressed: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
	pressed.bg_color = pressed.bg_color.darkened(0.12)
	button.add_theme_stylebox_override("pressed", pressed)
