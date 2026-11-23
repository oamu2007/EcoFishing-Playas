extends Node

const SESSION_SCENE: PackedScene = preload("res://scenes/gameplay/session.tscn")
const SessionScript = preload("res://scripts/gameplay/session.gd")
const MenuScript = preload("res://scripts/ui/session_menu.gd")
const PauseScript = preload("res://scripts/ui/pause_menu.gd")
const AudioScript = preload("res://scripts/gameplay/game_audio.gd")

var _session: SessionScript
var _starting_session: bool = false
var _closing_game: bool = false

@onready var _menu: MenuScript = $SessionMenu
@onready var _pause: PauseScript = $PauseMenu
@onready var _audio: AudioScript = $GameAudio


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_menu.start_requested.connect(_request_start)
	_pause.resume_requested.connect(_resume)
	_pause.restart_requested.connect(_request_start)
	_pause.title_requested.connect(_request_title)
	_pause.discard_cancelled.connect(_audio.play_cue.bind(AudioScript.Cue.CANCEL))
	_menu.open()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or _closing_game:
		return
	_closing_game = true
	await _audio.prepare_shutdown()
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if _pause.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_pause.cancel_or_resume()


func _request_start() -> void:
	if _starting_session or not (_menu.visible or _pause.visible):
		return
	_starting_session = true
	_audio.play_cue(AudioScript.Cue.CONFIRM)
	if _menu.visible:
		_menu.set_transition_pending()
	_start_session.call_deferred()


func _start_session() -> void:
	_drop_session()
	_session = SESSION_SCENE.instantiate()
	_session.menu_requested.connect(_open_pause)
	add_child(_session)
	_session.bind_audio(_audio)
	_menu.dismiss()
	_pause.hide()
	_audio.set_music_ducked(false)
	_starting_session = false


func _request_title() -> void:
	if _starting_session or not _pause.visible:
		return
	_starting_session = true
	_audio.play_cue(AudioScript.Cue.CONFIRM)
	_return_to_title.call_deferred()


func _return_to_title() -> void:
	_drop_session()
	_pause.hide()
	_audio.set_music_ducked(false)
	_menu.open()
	_starting_session = false


func _drop_session() -> void:
	if _session != null:
		remove_child(_session)
		_session.queue_free()
		_session = null


func _open_pause() -> void:
	if _pause.visible or _starting_session:
		return
	_session.process_mode = Node.PROCESS_MODE_DISABLED
	_session.set_hud_visible(false)
	_pause.open()
	_audio.set_music_ducked(true)


func _resume() -> void:
	if _starting_session or not _pause.visible or _session == null:
		return
	_audio.play_cue(AudioScript.Cue.CANCEL)
	_pause.hide()
	_audio.set_music_ducked(false)
	_session.process_mode = Node.PROCESS_MODE_INHERIT
	_session.set_hud_visible(true)
