extends Node

const SESSION_SCENE: PackedScene = preload("res://scenes/gameplay/session.tscn")
const SessionScript = preload("res://scripts/gameplay/session.gd")
const MenuScript = preload("res://scripts/ui/session_menu.gd")

var _session: SessionScript
var _starting_session: bool = false

@onready var _menu: MenuScript = $SessionMenu


func _ready() -> void:
	_menu.start_requested.connect(_request_start)
	_menu.resume_requested.connect(_resume)
	_menu.open(false)


func _unhandled_input(event: InputEvent) -> void:
	if _menu.visible and _session != null and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_resume()


func _request_start() -> void:
	if _starting_session or not _menu.visible:
		return
	_starting_session = true
	_menu.set_transition_pending()
	_start_session.call_deferred()


func _start_session() -> void:
	if _session != null:
		remove_child(_session)
		_session.queue_free()
	_session = SESSION_SCENE.instantiate()
	_session.menu_requested.connect(_open_menu)
	add_child(_session)
	_menu.dismiss()
	_starting_session = false


func _open_menu() -> void:
	if _menu.visible or _starting_session:
		return
	_session.process_mode = Node.PROCESS_MODE_DISABLED
	_session.set_hud_visible(false)
	_menu.open(true)


func _resume() -> void:
	if _starting_session or not _menu.visible or _session == null:
		return
	_menu.dismiss()
	_session.process_mode = Node.PROCESS_MODE_INHERIT
	_session.set_hud_visible(true)
