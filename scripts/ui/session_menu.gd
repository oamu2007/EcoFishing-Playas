extends CanvasLayer

signal start_requested
signal resume_requested

const ShorelineIllustration = preload("res://scripts/ui/shoreline_illustration.gd")

var _feedback_tweens: Dictionary[Button, Tween] = {}

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = %Title
@onready var _intro: Label = %Introduction
@onready var _start: Button = %StartSession
@onready var _resume: Button = %Resume
@onready var _shoreline: ShorelineIllustration = %Shoreline


func _ready() -> void:
	_start.pressed.connect(start_requested.emit)
	_resume.pressed.connect(resume_requested.emit)
	for button: Button in [_start, _resume]:
		button.mouse_entered.connect(_animate_button.bind(button, 1.014))
		button.mouse_exited.connect(_animate_button.bind(button, 1.0))
		button.button_down.connect(_animate_button.bind(button, 0.98))
		button.button_up.connect(_animate_button.bind(button, 1.0))


func open(has_session: bool) -> void:
	_backdrop.color.a = 0.79 if has_session else 1.0
	_title.text = "Session\npaused" if has_session else "EcoFishing\nPlayas"
	_intro.text = "Start fresh to reset your gear, Sack, gold, and cleanup projects." if has_session else "Fish for trash and fund cleanup.\nBring fish back to Playas."
	_start.text = "Start fresh" if has_session else "New Game"
	_start.theme_type_variation = &"Button" if has_session else &"FieldPrimary"
	_resume.visible = has_session
	_resume.disabled = false
	_start.disabled = false
	_apply_pressed_style(_start)
	_apply_pressed_style(_resume)
	show()
	_shoreline.set_motion_active(true)
	if has_session:
		_resume.grab_focus()
	else:
		_start.grab_focus()


func set_transition_pending() -> void:
	_start.disabled = true
	_resume.disabled = true
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
