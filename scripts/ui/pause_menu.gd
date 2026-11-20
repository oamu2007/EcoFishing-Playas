extends CanvasLayer

signal resume_requested
signal restart_requested
signal title_requested

enum Confirmation { NONE, RESTART, TITLE }

var _confirmation: Confirmation = Confirmation.NONE
var _transition_pending: bool = false

@onready var _heading: Label = %PauseHeading
@onready var _actions: Control = %PauseActions
@onready var _confirmation_panel: Control = %Confirmation
@onready var _message: Label = %DiscardMessage
@onready var _resume: Button = %Resume
@onready var _restart: Button = %Restart
@onready var _quit: Button = %QuitToTitle
@onready var _cancel: Button = %CancelDiscard
@onready var _confirm: Button = %ConfirmDiscard


func _ready() -> void:
	_resume.pressed.connect(resume_requested.emit)
	_restart.pressed.connect(_ask_to_discard.bind(Confirmation.RESTART))
	_quit.pressed.connect(_ask_to_discard.bind(Confirmation.TITLE))
	_cancel.pressed.connect(_cancel_discard)
	_confirm.pressed.connect(_confirm_discard)


func open() -> void:
	_transition_pending = false
	_cancel.disabled = false
	_confirm.disabled = false
	show()
	_show_actions(_resume)


func cancel_or_resume() -> void:
	if _transition_pending:
		return
	if _confirmation == Confirmation.NONE:
		resume_requested.emit()
	else:
		_cancel_discard()


func _show_actions(focus: Button) -> void:
	_confirmation = Confirmation.NONE
	_heading.text = "Paused"
	_confirmation_panel.hide()
	_actions.show()
	focus.grab_focus()


func _ask_to_discard(choice: Confirmation) -> void:
	_confirmation = choice
	var restarting: bool = choice == Confirmation.RESTART
	_heading.text = "Start fresh?" if restarting else "Quit to title?"
	_message.text = "Your gear, Sack, gold, and cleanup progress will reset." if restarting else "Your current session progress will be lost."
	_confirm.text = "Start fresh" if restarting else "Quit to title"
	_actions.hide()
	_confirmation_panel.show()
	_cancel.grab_focus()


func _cancel_discard() -> void:
	_show_actions(_restart if _confirmation == Confirmation.RESTART else _quit)


func _confirm_discard() -> void:
	if _transition_pending or _confirmation == Confirmation.NONE:
		return
	_transition_pending = true
	_cancel.disabled = true
	_confirm.disabled = true
	if _confirmation == Confirmation.RESTART:
		restart_requested.emit()
	else:
		title_requested.emit()
