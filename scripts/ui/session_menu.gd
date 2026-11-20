extends CanvasLayer

signal start_requested
signal resume_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = %Title
@onready var _intro: Label = %Introduction
@onready var _start: Button = %StartSession
@onready var _resume: Button = %Resume


func _ready() -> void:
	_start.pressed.connect(start_requested.emit)
	_resume.pressed.connect(resume_requested.emit)


func open(has_session: bool) -> void:
	_backdrop.color.a = 0.79 if has_session else 1.0
	_title.text = "Session\npaused" if has_session else "EcoFishing\nPlayas"
	_intro.text = "Start fresh to reset your gear, Sack, gold, and cleanup projects." if has_session else "Fish for trash and fund cleanup.\nBring fish back to Playas."
	_start.text = "Start fresh" if has_session else "Start session"
	_start.theme_type_variation = &"Button" if has_session else &"FieldPrimary"
	_resume.visible = has_session
	_resume.disabled = false
	_start.disabled = false
	show()
	if has_session:
		_resume.grab_focus()
	else:
		_start.grab_focus()


func set_transition_pending() -> void:
	_start.disabled = true
	_resume.disabled = true
