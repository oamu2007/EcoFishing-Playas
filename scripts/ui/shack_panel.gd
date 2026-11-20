extends CanvasLayer

signal close_requested

enum Page { HOME, SELL, BUY }

var _shop: ShackShop
var _sack: Sack
var _rod: FishingRod
var _page: Page = Page.HOME
var _selection: Array[Sack.Entry] = []
var _rod_buttons: Array[Button] = []
var _sack_buttons: Array[Button] = []
var _cleanup_buttons: Array[Button] = []

@onready var _home: Control = %Home
@onready var _sell_screen: Control = %SellScreen
@onready var _buy_screen: Control = %BuyScreen
@onready var _title: Label = %Title
@onready var _summary: Label = %Summary
@onready var _sack_heading: Label = %SackHeading
@onready var _feedback: Label = %Feedback
@onready var _confirm: Button = %ConfirmSale
@onready var _sell: Button = %Sell
@onready var _buy: Button = %Buy
@onready var _back: Button = %Back
@onready var _close: Button = %Close
@onready var _sack_items: VBoxContainer = %SackItems
@onready var _tray_items: VBoxContainer = %TrayItems
@onready var _gear: VBoxContainer = %Gear
@onready var _cleanup: VBoxContainer = %Cleanup


func _ready() -> void:
	_sell.pressed.connect(_show_page.bind(Page.SELL))
	_buy.pressed.connect(_show_page.bind(Page.BUY))
	_back.pressed.connect(_show_page.bind(Page.HOME))
	_confirm.pressed.connect(_sell_selected)
	_close.pressed.connect(close_requested.emit)
	for zone: Control in [%SackScroll, %SackZone]:
		_set_drop_destination(zone, false)
	for zone: Control in [%TrayScroll, %TrayZone]:
		_set_drop_destination(zone, true)


func bind_shop(shop: ShackShop, sack: Sack, rod: FishingRod) -> void:
	_shop = shop
	_sack = sack
	_rod = rod
	for index: int in shop.rod_upgrades.size():
		var upgrade: RodUpgrade = shop.rod_upgrades[index]
		var effect: String = "%d px reach · %d trash\n%.2f s cast · %.2f s reel" % [upgrade.cast_range, upgrade.trash_limit, upgrade.cast_time, upgrade.retrieval_time]
		var button: Button = _add_catalog_card(_gear, upgrade.title, effect, upgrade.art)
		button.pressed.connect(_buy_rod.bind(index))
		_rod_buttons.append(button)
	for index: int in shop.sack_upgrades.size():
		var upgrade: SackUpgrade = shop.sack_upgrades[index]
		var button: Button = _add_catalog_card(_gear, upgrade.title, "%d Sack slots" % upgrade.capacity, upgrade.art)
		button.pressed.connect(_buy_sack.bind(index))
		_sack_buttons.append(button)
	for index: int in shop.cleanup_projects.size():
		var project: CleanupProject = shop.cleanup_projects[index]
		var button: Button = _add_catalog_card(_cleanup, project.title, "Removes %d permanent points" % project.pollution_reduction, project.art)
		button.pressed.connect(_buy_cleanup.bind(index))
		_cleanup_buttons.append(button)
	shop.purchases_changed.connect(_refresh_catalog)
	sack.contents_changed.connect(_on_contents_changed)
	_refresh_catalog()
	_on_contents_changed()


func open() -> void:
	show()
	_show_page(Page.HOME)


func close() -> void:
	hide()
	_selection.clear()


func _show_page(page: Page) -> void:
	_page = page
	_title.text = ["Fishing shack", "Sell your catch", "Buy gear and cleanup"][page]
	_home.visible = page == Page.HOME
	_sell_screen.visible = page == Page.SELL
	_buy_screen.visible = page == Page.BUY
	_back.visible = page != Page.HOME
	_feedback.text = ""
	if page != Page.SELL:
		_selection.clear()
	match page:
		Page.HOME:
			_sell.grab_focus()
		Page.SELL:
			_render_sale_items()
			_focus_sale_item(false)
		Page.BUY:
			%BuyScroll.scroll_vertical = 0
			_back.grab_focus()


func _on_contents_changed() -> void:
	_summary.text = "Sack  %d / %d" % [_sack.item_count, _sack.capacity]
	if visible and _page == Page.SELL:
		_selection = _selection.filter(_sack.has_entry)
		_render_sale_items()


func _render_sale_items() -> void:
	for column: VBoxContainer in [_sack_items, _tray_items]:
		for child: Node in column.get_children():
			column.remove_child(child)
			child.queue_free()
	for entry: Sack.Entry in _sack.entries():
		var on_tray: bool = _selection.has(entry)
		var column: VBoxContainer = _tray_items if on_tray else _sack_items
		var card: Button = _sale_card(entry)
		card.pressed.connect(_move_entry.bind(entry, not on_tray))
		card.set_drag_forwarding(_start_drag.bind(entry), _can_drop.bind(on_tray), _drop.bind(on_tray))
		column.add_child(card)
	_sack_heading.text = "Sack  ·  %d / %d" % [_sack.item_count - _selection.size(), _sack.capacity]
	if _sack_items.get_child_count() == 0:
		_add_empty_note(_sack_items, "No items in the Sack.")
	if _tray_items.get_child_count() == 0:
		_add_empty_note(_tray_items, "No items selected for sale.")
	_confirm.disabled = _selection.is_empty()
	_confirm.text = "Sell selected  ·  %d gold" % maxi(0, _sack.sale_quote(_selection))


func _sale_card(entry: Sack.Entry) -> Button:
	var card: Button = Button.new()
	card.text = "%s   ·   %d gold" % [entry.label, entry.value]
	card.icon = entry.art
	card.expand_icon = true
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.custom_minimum_size.y = 53.0
	card.add_theme_constant_override("icon_max_width", 48)
	return card


func _add_empty_note(column: VBoxContainer, message: String) -> void:
	var label: Label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.y = 53.0
	column.add_child(label)


func _set_drop_destination(zone: Control, on_tray: bool) -> void:
	zone.set_drag_forwarding(Callable(), _can_drop.bind(on_tray), _drop.bind(on_tray))


func _start_drag(_position: Vector2, entry: Sack.Entry) -> Variant:
	var preview: Button = _sale_card(entry)
	preview.modulate.a = 0.92
	preview.position = Vector2(10.0, 10.0)
	_sell_screen.set_drag_preview(preview)
	return entry


func _can_drop(_position: Vector2, data: Variant, on_tray: bool) -> bool:
	return visible and _page == Page.SELL and data is Sack.Entry and _sack.has_entry(data) and _selection.has(data) != on_tray


func _drop(position: Vector2, data: Variant, on_tray: bool) -> void:
	if _can_drop(position, data, on_tray):
		_move_entry(data, on_tray)


func _move_entry(entry: Sack.Entry, to_tray: bool) -> void:
	if not _can_drop(Vector2.ZERO, entry, to_tray):
		return
	if to_tray:
		_selection.append(entry)
	else:
		_selection.erase(entry)
	_feedback.text = ""
	_render_sale_items()
	_focus_sale_item(not to_tray)


func _focus_sale_item(from_tray: bool) -> void:
	var column: VBoxContainer = _tray_items if from_tray else _sack_items
	for child: Node in column.get_children():
		if child is Button:
			child.grab_focus()
			return
	if _confirm.disabled:
		_back.grab_focus()
	else:
		_confirm.grab_focus()


func _sell_selected() -> void:
	if not visible or _page != Page.SELL or _selection.is_empty():
		return
	var selected: Array[Sack.Entry] = _selection.duplicate()
	var quoted: int = _sack.sale_quote(selected)
	if quoted < 0:
		_selection.clear()
		_render_sale_items()
		_focus_sale_item(false)
		return
	var earned: int = _shop.sell_selected(selected)
	_feedback.text = "Sold %d items for %d gold." % [selected.size(), earned] if selected.size() != 1 else "Sold 1 item for %d gold." % earned
	_focus_sale_item(false)


func _add_catalog_card(catalog: VBoxContainer, title: String, effect: String, art: Texture2D) -> Button:
	var card: PanelContainer = PanelContainer.new()
	var row: HBoxContainer = HBoxContainer.new()
	var picture: TextureRect = TextureRect.new()
	picture.texture = art
	picture.custom_minimum_size = Vector2(62, 49)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var details: Label = Label.new()
	details.add_theme_font_size_override("font_size", 14)
	details.text = "%s\n%s" % [title, effect]
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var button: Button = Button.new()
	button.custom_minimum_size.x = 110.0
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 14)
	row.add_child(picture)
	row.add_child(details)
	row.add_child(button)
	card.add_child(row)
	catalog.add_child(card)
	return button


func _refresh_catalog() -> void:
	%CurrentGear.text = "Equipped   ·   Rod %d   ·   %d px reach   ·   %d Sack slots" % [_shop.rod_tier + 1, _rod.maximum_cast_range, _sack.capacity]
	for index: int in _rod_buttons.size():
		_set_price(_rod_buttons[index], index, _shop.rod_tier, _shop.rod_upgrades[index].cost)
	for index: int in _sack_buttons.size():
		_set_price(_sack_buttons[index], index, _shop.sack_tier, _shop.sack_upgrades[index].cost)
	for index: int in _cleanup_buttons.size():
		var button: Button = _cleanup_buttons[index]
		var complete: bool = _shop.is_cleanup_complete(index)
		var project: CleanupProject = _shop.cleanup_projects[index]
		_set_availability(button, not _shop.can_buy_cleanup(index), "Complete" if complete else "%d gold" % project.cost, project.cost)


func _set_price(button: Button, index: int, current_tier: int, cost: int) -> void:
	var status: String = "%d gold" % cost
	if index < current_tier:
		status = "Owned"
	elif index > current_tier:
		status = "Locked · %d" % cost
	_set_availability(button, index != current_tier or _shop.coins < cost, status, cost)


func _set_availability(button: Button, disabled: bool, status: String, cost: int) -> void:
	var had_focus: bool = button.has_focus()
	button.text = status
	button.disabled = disabled
	button.tooltip_text = "Need %d more gold" % (cost - _shop.coins) if status == "%d gold" % cost and _shop.coins < cost else status
	if had_focus and disabled:
		_back.grab_focus()


func _buy_rod(index: int) -> void:
	if visible and _page == Page.BUY and _shop.buy_rod(index):
		_feedback.text = "Equipped the %s." % _shop.rod_upgrades[index].title


func _buy_sack(index: int) -> void:
	if visible and _page == Page.BUY and _shop.buy_sack(index):
		_feedback.text = "Equipped the %s." % _shop.sack_upgrades[index].title


func _buy_cleanup(index: int) -> void:
	if visible and _page == Page.BUY and _shop.buy_cleanup(index):
		_feedback.text = "Project funded. Permanent pollution fell by %d points." % _shop.cleanup_projects[index].pollution_reduction
