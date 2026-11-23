extends Node

signal menu_requested
signal drag_cancelled

const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const ShackPanelScript = preload("res://scripts/ui/shack_panel.gd")
const CoinBalanceScript = preload("res://scripts/ui/coin_balance.gd")
const FishRevealScript = preload("res://scripts/ui/fish_reveal.gd")
const AudioScript = preload("res://scripts/gameplay/game_audio.gd")

var _discovered: Dictionary[FishSpecies, bool] = {}
var _audio: AudioScript

@onready var _world: LevelScript = $World
@onready var _hud: HudScript = $HUD
@onready var _shack_panel: ShackPanelScript = $ShackPanel
@onready var _coin_balance: CoinBalanceScript = $CoinBalance
@onready var _fish_reveal: FishRevealScript = $FishReveal


func _ready() -> void:
	_hud.bind_session(_world.pollution, _world.catches, _world.rod, _world.sack, _world.shop, _world.catchable_fish.pollution_threshold)
	_hud.menu_requested.connect(menu_requested.emit)
	_hud.help_visibility_changed.connect(_world.rod.set_help_visible)
	_world.cleanup_work.work_started.connect(_hud.announce_cleanup)
	_world.catches.fish_landed.connect(_on_fish_landed)
	_fish_reveal.dismissed.connect(_close_fish_reveal)
	_shack_panel.bind_shop(_world.shop, _world.sack, _world.rod)
	_coin_balance.bind_shop(_world.shop)
	_shack_panel.close_requested.connect(_close_shop)


func bind_audio(audio: AudioScript) -> void:
	_audio = audio
	_world.bind_audio(audio)
	_hud.sack_full_warned.connect(audio.play_cue.bind(AudioScript.Cue.SACK_FULL))
	_shack_panel.inventory_picked_up.connect(audio.play_cue.bind(AudioScript.Cue.PICKUP))
	_shack_panel.inventory_dropped.connect(audio.play_cue.bind(AudioScript.Cue.DROP))
	_shack_panel.cancelled.connect(audio.play_cue.bind(AudioScript.Cue.CANCEL))
	drag_cancelled.connect(audio.play_cue.bind(AudioScript.Cue.CANCEL))


func _input(event: InputEvent) -> void:
	if _fish_reveal.visible:
		if event is InputEventKey or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
			if not event.is_echo() and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
				_fish_reveal.dismiss()
		return
	if _shack_panel.visible and (_shack_panel.handle_back(event) or _shack_panel.handle_sell_all(event)):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		var viewport: Viewport = get_viewport()
		viewport.set_input_as_handled()
		if viewport.gui_is_dragging():
			viewport.gui_cancel_drag()
			drag_cancelled.emit()
		elif _shack_panel.visible:
			_shack_panel.cancel_page()
		else:
			menu_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _fish_reveal.visible:
		get_viewport().set_input_as_handled()
		return
	if event.is_echo():
		return
	if _shack_panel.visible:
		if event.is_action_pressed("open_shack"):
			get_viewport().set_input_as_handled()
			_close_shop()
	elif event.is_action_pressed("open_shack") and _world.can_open_shack():
		get_viewport().set_input_as_handled()
		_world.set_shop_open(true)
		set_hud_visible(false)
		_shack_panel.open()


func _on_fish_landed(species: FishSpecies, length_cm: int, sale_value: int) -> void:
	if _discovered.has(species):
		return
	_discovered[species] = true
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	set_hud_visible(false)
	if _audio != null:
		_audio.play_cue(AudioScript.Cue.TROPHY_DISCOVERY if species.rarity == FishSpecies.Rarity.TROPHY else AudioScript.Cue.FISH_DISCOVERY)
	_fish_reveal.present(species, length_cm, sale_value)


func _close_fish_reveal() -> void:
	_world.process_mode = Node.PROCESS_MODE_INHERIT
	set_hud_visible(true)


func _close_shop() -> void:
	_shack_panel.close()
	_world.set_shop_open(false)
	set_hud_visible(true)


func set_hud_visible(value: bool) -> void:
	_hud.visible = value
	_world.rod.set_help_visible(value and _hud.is_help_enabled())
