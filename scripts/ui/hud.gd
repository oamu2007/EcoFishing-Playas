extends CanvasLayer

var _notification_remaining: float = 0.0
var _startup_hint_remaining: float = 6.0
var _hooked_count: int = 0
var _sack: Sack
var _shop: ShackShop

@onready var _progress: Label = $ProgressPanel/Margin/Readouts/Progress
@onready var _notification: Label = $Notification
@onready var _help: PanelContainer = $ControlsPanel
@onready var _hint: Label = $Hint
@onready var _pollution_bar: ProgressBar = $ProgressPanel/Margin/Readouts/PollutionBar
@onready var _inventory: Label = $ProgressPanel/Margin/Readouts/Inventory
@onready var _gear: Label = $ProgressPanel/Margin/Readouts/Gear


func bind_cleanup(pollution: PollutionSystem, trash: TrashManager, rod: FishingRod, sack: Sack, shop: ShackShop) -> void:
	_sack = sack
	_shop = shop
	sack.contents_changed.connect(_update_inventory)
	shop.purchases_changed.connect(_update_inventory)
	_update_inventory()
	pollution.pollution_changed.connect(_on_pollution_changed)
	trash.trash_hooked.connect(_on_trash_hooked)
	trash.trash_returned.connect(_on_trash_returned)
	rod.state_changed.connect(_on_rod_state_changed)
	_on_pollution_changed(pollution.normalized_pollution)


func _process(delta: float) -> void:
	_notification_remaining = maxf(0.0, _notification_remaining - delta)
	_notification.visible = _notification_remaining > 0.0
	_startup_hint_remaining = maxf(0.0, _startup_hint_remaining - delta)
	_hint.text = "WASD / Arrows | Aim + Click | H Help" if _startup_hint_remaining > 0.0 else "H  Help"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help") and not event.is_echo():
		_help.visible = not _help.visible
		get_viewport().set_input_as_handled()


func _update_inventory() -> void:
	_inventory.text = "SACK  %d/%d    GOLD  %d" % [_sack.item_count, _sack.capacity, _shop.coins]
	_gear.text = "Rod %d  •  Sack tier %d" % [_shop.rod_tier + 1, _shop.sack_tier + 1]


func _on_pollution_changed(normalized: float) -> void:
	_progress.text = "POLLUTION  %d%%" % roundi(normalized * 100.0)
	_pollution_bar.value = normalized * 100.0


func _on_rod_state_changed(state: FishingRod.State) -> void:
	if state == FishingRod.State.CASTING:
		_hooked_count = 0
		_notification_remaining = 0.0
		_notification.hide()
		if _sack.free_slots == 0:
			_notify("Sack full. Sell your catch at the shack.")


func _on_trash_hooked(type_name: String) -> void:
	_hooked_count += 1
	_notify("Hooked %s" % type_name if _hooked_count == 1 else "Hooked %d items" % _hooked_count)


func _on_trash_returned(count: int, type_name: String) -> void:
	if _sack.free_slots == 0:
		_notify("Sack full. Sell your catch at the shack.")
		return
	match count:
		0: _notify("Nothing caught. Aim at floating trash.")
		1: _notify("Collected %s" % type_name)
		_: _notify("Collected %d items" % count)


func _notify(message: String) -> void:
	_notification.text = message
	_notification_remaining = 3.0
	_notification.show()
