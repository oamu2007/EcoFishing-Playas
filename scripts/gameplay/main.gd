extends Node

const LevelScript = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const ShackPanelScript = preload("res://scripts/ui/shack_panel.gd")

@onready var _world: LevelScript = $World
@onready var _hud: HudScript = $HUD
@onready var _shack_panel: ShackPanelScript = $ShackPanel


func _ready() -> void:
	_hud.bind_cleanup(_world.pollution, _world.trash_manager, _world.rod, _world.sack, _world.shop)
	_shack_panel.bind_shop(_world.shop, _world.sack, _world.rod)
	_shack_panel.close_requested.connect(_close_shop)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if _shack_panel.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_shack"):
			get_viewport().set_input_as_handled()
			_close_shop()
	elif event.is_action_pressed("open_shack") and _world.can_open_shack():
		get_viewport().set_input_as_handled()
		_world.set_shop_open(true)
		_shack_panel.open()


func _close_shop() -> void:
	_shack_panel.hide()
	_world.set_shop_open(false)
