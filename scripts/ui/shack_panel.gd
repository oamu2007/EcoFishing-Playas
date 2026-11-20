extends CanvasLayer

signal close_requested

var _shop: ShackShop
var _sack: Sack
var _rod_buttons: Array[Button] = []
var _sack_buttons: Array[Button] = []

@onready var _summary: Label = %Summary
@onready var _feedback: Label = %Feedback
@onready var _sell: Button = %Sell
@onready var _close: Button = %Close
@onready var _gear: VBoxContainer = %Gear


func _ready() -> void:
	_sell.pressed.connect(_sell_load)
	_close.pressed.connect(close_requested.emit)


func bind_shop(shop: ShackShop, sack: Sack, rod: FishingRod) -> void:
	_shop = shop
	_sack = sack
	for index: int in shop.rod_upgrades.size():
		var upgrade: RodUpgrade = shop.rod_upgrades[index]
		var effect: String = "%d px, %.2fs cast / %.2fs return, %d trash" % [upgrade.cast_range, upgrade.cast_time, upgrade.retrieval_time, upgrade.trash_limit]
		var button: Button = _add_gear_button(upgrade.title, effect)
		button.pressed.connect(_buy_rod.bind(index))
		_rod_buttons.append(button)
	for index: int in shop.sack_upgrades.size():
		var upgrade: SackUpgrade = shop.sack_upgrades[index]
		var button: Button = _add_gear_button(upgrade.title, "%d slots" % upgrade.capacity)
		button.pressed.connect(_buy_sack.bind(index))
		_sack_buttons.append(button)
	%StarterGear.text = "Starter rod  •  %d px, %d trash    |    Starter Sack  •  %d slots" % [rod.maximum_cast_range, rod.trash_per_cast, sack.capacity]
	shop.purchases_changed.connect(_refresh)
	sack.contents_changed.connect(_refresh)
	_refresh()


func open() -> void:
	_feedback.text = ""
	_refresh()
	show()
	if _sell.disabled:
		_close.grab_focus()
	else:
		_sell.grab_focus()


func _add_gear_button(title: String, effect: String) -> Button:
	var row: HBoxContainer = HBoxContainer.new()
	var details: Label = Label.new()
	details.text = "%s\n%s" % [title, effect]
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(116.0, 34.0)
	row.add_child(details)
	row.add_child(button)
	_gear.add_child(row)
	return button


func _refresh() -> void:
	_summary.text = "%d gold   |   Sack %d/%d   |   Rod %d   |   Sack tier %d" % [_shop.coins, _sack.item_count, _sack.capacity, _shop.rod_tier + 1, _shop.sack_tier + 1]
	_sell.text = "Sell Sack contents   +%d gold" % _sack.sale_total() if _sack.item_count > 0 else "Sack empty"
	_sell.disabled = _sack.item_count == 0
	for index: int in _rod_buttons.size():
		_set_price(_rod_buttons[index], index, _shop.rod_tier, _shop.rod_upgrades[index].cost)
	for index: int in _sack_buttons.size():
		_set_price(_sack_buttons[index], index, _shop.sack_tier, _shop.sack_upgrades[index].cost)


func _set_price(button: Button, index: int, current_tier: int, cost: int) -> void:
	var status: String = "%d gold" % cost
	if index < current_tier:
		status = "Owned"
	elif index > current_tier:
		status = "Locked · %d" % cost
	button.disabled = index != current_tier or _shop.coins < cost
	button.text = status


func _sell_load() -> void:
	var earned: int = _shop.sell_all()
	if earned > 0:
		_feedback.text = "Sold the load for %d gold." % earned


func _buy_rod(index: int) -> void:
	if _shop.buy_rod(index):
		_feedback.text = "Equipped the %s." % _shop.rod_upgrades[index].title


func _buy_sack(index: int) -> void:
	if _shop.buy_sack(index):
		_feedback.text = "Equipped the %s." % _shop.sack_upgrades[index].title
