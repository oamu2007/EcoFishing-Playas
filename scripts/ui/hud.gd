extends CanvasLayer

signal menu_requested

const CatchResolverScript = preload("res://scripts/systems/catch_resolver.gd")

var _notification_remaining: float = 0.0
var _hooked_count: int = 0
var _sack: Sack
var _shop: ShackShop
var _pollution: PollutionSystem
var _rod: FishingRod
var _fish_threshold: float

@onready var _progress: Label = $ProgressPanel/Margin/Readouts/Progress
@onready var _notification: Label = $Notification
@onready var _help: PanelContainer = $ControlsPanel
@onready var _hint: Label = $Hint
@onready var _pollution_bar: ProgressBar = $ProgressPanel/Margin/Readouts/PollutionBar
@onready var _inventory: Label = $ProgressPanel/Margin/Readouts/Inventory
@onready var _gear: Label = $ProgressPanel/Margin/Readouts/Gear
@onready var _menu_button: Button = $MenuButton
@onready var _help_button: Button = $HelpKey


func _ready() -> void:
	_menu_button.pressed.connect(menu_requested.emit)
	_help_button.pressed.connect(_toggle_help)


func bind_session(pollution: PollutionSystem, catches: CatchResolverScript, rod: FishingRod, sack: Sack, shop: ShackShop, fish_threshold: float) -> void:
	_sack = sack
	_shop = shop
	_pollution = pollution
	_rod = rod
	_fish_threshold = fish_threshold
	sack.contents_changed.connect(_update_inventory)
	shop.purchases_changed.connect(_update_inventory)
	_update_inventory()
	pollution.pollution_changed.connect(_on_pollution_changed)
	catches.catch_hooked.connect(_on_catch_hooked)
	catches.catches_returned.connect(_on_catches_returned)
	rod.state_changed.connect(_on_rod_state_changed)
	rod.cast_rejected.connect(_notify)
	_on_pollution_changed(pollution.normalized_pollution)
	_hint.text = _guidance()


func _process(delta: float) -> void:
	_notification_remaining = maxf(0.0, _notification_remaining - delta)
	_notification.visible = _notification_remaining > 0.0
	if _rod != null:
		var message: String = _guidance()
		if _hint.text != message:
			_hint.text = message


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("toggle_help") and not event.is_echo():
		_toggle_help()
		get_viewport().set_input_as_handled()


func _toggle_help() -> void:
	_help.visible = not _help.visible


func close_help() -> void:
	_help.hide()


func _guidance() -> String:
	match _rod.state:
		FishingRod.State.CASTING:
			return "Wait for the hook to land."
		FishingRod.State.WAITING:
			return "Left click again to reel in."
		FishingRod.State.RETRIEVING:
			return "Reeling in your line…"
	if _sack.free_slots == 0:
		return "Head inland to the fishing shack and press E."
	if _sack.fish_count > 0:
		return "Sell your fish at the fishing shack. Press E at the door."
	if _shop.rod_tier == 0 and _shop.sack_tier == 0:
		var price: int = _first_upgrade_cost()
		if price > 0 and _shop.coins >= price:
			return "Buy your first upgrade at the shack. Press E at the door."
		if _sack.item_count > 0:
			return "Catch %d more for a full load, then sell it at the fishing shack." % _sack.free_slots
		if price > _shop.coins and _shop.coins > 0:
			return "Catch and sell more trash. Your first upgrade needs %d more gold." % (price - _shop.coins)
	if not _rod.is_near_shore(_rod.global_position):
		return "Move right to the shoreline with WASD or the arrow keys."
	if _pollution.permanent_points == 0 and _pollution.current_pollution > 0:
		return "Clear floating trash between arrivals to reach 0%."
	if _pollution.normalized_pollution <= _fish_threshold:
		return "Watch for white-ringed fish. Click to cast and reel them in."
	if _pollution.trash_collected == 0:
		return "Aim at floating trash. Left click when the marker is green."
	return "Sell trash at the shack to fund cleanup. Fish return at %d%%." % roundi(_fish_threshold * 100.0)


func _first_upgrade_cost() -> int:
	var rod_cost: int = _shop.rod_upgrades[0].cost if not _shop.rod_upgrades.is_empty() else 0
	var sack_cost: int = _shop.sack_upgrades[0].cost if not _shop.sack_upgrades.is_empty() else 0
	return mini(rod_cost, sack_cost) if rod_cost > 0 and sack_cost > 0 else maxi(rod_cost, sack_cost)


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


func _on_catch_hooked(type_name: String) -> void:
	_hooked_count += 1
	_notify("Hooked %s" % type_name if _hooked_count == 1 else "Hooked %d items" % _hooked_count)


func _on_catches_returned(count: int, type_name: String) -> void:
	if _sack.free_slots == 0:
		var catch_message: String = ""
		if count == 1:
			catch_message = "Collected %s. " % type_name
		elif count > 1:
			catch_message = "Collected %d items. " % count
		_notify(catch_message + "Sack full. Sell your catch at the shack.")
		return
	match count:
		0: _notify("Nothing caught. Aim at trash or a marked fish.")
		1: _notify("Collected %s" % type_name)
		_: _notify("Collected %d items" % count)


func _notify(message: String) -> void:
	_notification.text = message
	_notification_remaining = 3.0
	_notification.show()
