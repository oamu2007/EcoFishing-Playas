extends Node

enum Cue {
	FOOTSTEP, CAST, SPLASH, REEL, CATCH, MISS, TIMING_SUCCESS, TIMING_FAILURE,
	NAVIGATE, CONFIRM, CANCEL, PICKUP, DROP, SALE, PURCHASE, CLEANUP,
	FISH_DISCOVERY, TROPHY_DISCOVERY, SACK_FULL,
}

signal cue_started(cue: Cue)

const EFFECTS: Dictionary[Cue, AudioStream] = {
	Cue.FOOTSTEP: preload("res://assets/audio/effects/footstep.wav"),
	Cue.CAST: preload("res://assets/audio/effects/cast.wav"),
	Cue.SPLASH: preload("res://assets/audio/effects/splash.wav"),
	Cue.REEL: preload("res://assets/audio/effects/reel.wav"),
	Cue.CATCH: preload("res://assets/audio/effects/catch.wav"),
	Cue.MISS: preload("res://assets/audio/effects/miss.wav"),
	Cue.TIMING_SUCCESS: preload("res://assets/audio/effects/timing_success.wav"),
	Cue.TIMING_FAILURE: preload("res://assets/audio/effects/timing_failure.wav"),
	Cue.NAVIGATE: preload("res://assets/audio/effects/navigate.wav"),
	Cue.CONFIRM: preload("res://assets/audio/effects/confirm.wav"),
	Cue.CANCEL: preload("res://assets/audio/effects/cancel.wav"),
	Cue.PICKUP: preload("res://assets/audio/effects/pickup.wav"),
	Cue.DROP: preload("res://assets/audio/effects/drop.wav"),
	Cue.SALE: preload("res://assets/audio/effects/sale.wav"),
	Cue.PURCHASE: preload("res://assets/audio/effects/purchase.wav"),
	Cue.CLEANUP: preload("res://assets/audio/effects/cleanup.wav"),
	Cue.FISH_DISCOVERY: preload("res://assets/audio/effects/fish_discovery.wav"),
	Cue.TROPHY_DISCOVERY: preload("res://assets/audio/effects/trophy_discovery.wav"),
	Cue.SACK_FULL: preload("res://assets/audio/effects/sack_full.wav"),
}
const CUE_GAIN: Dictionary[Cue, float] = {
	Cue.FOOTSTEP: -8.0,
	Cue.NAVIGATE: -3.0,
	Cue.REEL: -2.0,
	Cue.CATCH: 1.0,
	Cue.TIMING_SUCCESS: 2.0,
	Cue.TIMING_FAILURE: 2.0,
	Cue.SALE: 2.0,
}
const MINIMUM_GAP_MS: Dictionary[Cue, int] = {Cue.NAVIGATE: 65, Cue.MISS: 110, Cue.FOOTSTEP: 100, Cue.SACK_FULL: 330}
const SHUTDOWN_GRACE_MS: int = 150

@export var tracks: Array[AudioStreamMP3] = []
@export_range(0, 15) var starting_track: int = 0
@export_range(0.0, 30.0, 0.01) var loop_start_seconds: float = 0.0
@export_range(0.0, 30.0) var pause_duck_db: float = 14.0
@export_range(0.05, 1.0, 0.01) var pause_fade_seconds: float = 0.24

var _last_cues: Dictionary[Cue, int] = {}
var _voices: AudioStreamPlaybackPolyphonic
var _music_gain_db: float
var _music_ducked: bool = false
var _music_fade: Tween

@onready var _music: AudioStreamPlayer = $Music
@onready var _effects: AudioStreamPlayer = $Effects


func _ready() -> void:
	_music_gain_db = _music.volume_db
	if not tracks.is_empty():
		var track: AudioStreamMP3 = tracks[mini(starting_track, tracks.size() - 1)].duplicate()
		track.loop = true
		track.loop_offset = clampf(loop_start_seconds, 0.0, maxf(0.0, track.get_length() - 0.1))
		_music.stream = track
		_music.play()
	_effects.play()
	_voices = _effects.get_stream_playback()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _exit_tree() -> void:
	_stop_all()


func prepare_shutdown() -> void:
	_stop_all()
	# The mixer releases stopped streams on its own clock, even in fixed-FPS tests.
	var release_at: int = Time.get_ticks_msec() + SHUTDOWN_GRACE_MS
	while Time.get_ticks_msec() < release_at:
		await get_tree().process_frame


func _stop_all() -> void:
	if _music_fade != null:
		_music_fade.kill()
	_music.stop()
	_effects.stop()
	_voices = null


func set_music_ducked(ducked: bool) -> void:
	if _music_ducked == ducked:
		return
	_music_ducked = ducked
	if _music_fade != null:
		_music_fade.kill()
	var target_db: float = _music_gain_db - pause_duck_db if ducked else _music_gain_db
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", target_db, pause_fade_seconds).set_trans(Tween.TRANS_SINE)


func play_cue(cue: Cue, pitch: float = 1.0) -> void:
	if _voices == null:
		return
	var now: int = Time.get_ticks_msec()
	if _last_cues.has(cue) and now - _last_cues[cue] < MINIMUM_GAP_MS.get(cue, 0):
		return
	var voice: int = _voices.play_stream(EFFECTS[cue], 0.0, CUE_GAIN.get(cue, 0.0), pitch)
	if voice != AudioStreamPlaybackPolyphonic.INVALID_ID:
		_last_cues[cue] = now
		cue_started.emit(cue)


func on_footstep(left_foot: bool) -> void:
	play_cue(Cue.FOOTSTEP, 0.96 if left_foot else 1.05)


func on_rod_state_changed(state: FishingRod.State) -> void:
	match state:
		FishingRod.State.CASTING: play_cue(Cue.CAST)
		FishingRod.State.RETRIEVING: play_cue(Cue.REEL)


func on_fish_timing_finished(succeeded: bool) -> void:
	play_cue(Cue.TIMING_SUCCESS if succeeded else Cue.TIMING_FAILURE)


func on_catches_returned(count: int, _type_name: String) -> void:
	play_cue(Cue.CATCH if count > 0 else Cue.MISS)


func _on_focus_changed(control: Control) -> void:
	var button: BaseButton = control as BaseButton
	if button != null and not button.disabled:
		play_cue(Cue.NAVIGATE)
