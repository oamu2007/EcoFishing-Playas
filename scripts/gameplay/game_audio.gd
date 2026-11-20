extends Node

enum Cue {
	FOOTSTEP, CAST, SPLASH, REEL, CATCH, MISS, TIMING_SUCCESS, TIMING_FAILURE,
	NAVIGATE, CONFIRM, CANCEL, PICKUP, DROP, SALE, PURCHASE, CLEANUP,
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
}
const CUE_GAIN: Dictionary[Cue, float] = {
	Cue.FOOTSTEP: -3.0,
	Cue.NAVIGATE: -3.0,
	Cue.REEL: -2.0,
	Cue.CATCH: 1.0,
	Cue.TIMING_SUCCESS: 2.0,
	Cue.TIMING_FAILURE: 2.0,
	Cue.SALE: 2.0,
}
const MINIMUM_GAP_MS: Dictionary[Cue, int] = {Cue.NAVIGATE: 65, Cue.MISS: 110, Cue.FOOTSTEP: 100}

@export var tracks: Array[AudioStreamMP3] = []
@export_range(0, 15) var starting_track: int = 0
@export_range(0.0, 30.0, 0.01) var loop_start_seconds: float = 0.0

var _last_cues: Dictionary[Cue, int] = {}
var _voices: AudioStreamPlaybackPolyphonic

@onready var _music: AudioStreamPlayer = $Music
@onready var _effects: AudioStreamPlayer = $Effects


func _ready() -> void:
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
	_music.stop()
	_effects.stop()
	_voices = null


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
