extends SceneTree

const MAIN: PackedScene = preload("res://scenes/gameplay/main.tscn")
const World = preload("res://scripts/gameplay/playas_vertical_slice.gd")
const AudioScript = preload("res://scripts/gameplay/game_audio.gd")

var _failures: int
var _pointer: Vector2


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	for window: Vector2i in [Vector2i(1280, 720), Vector2i(800, 450)]:
		root.size = window
		var main: Node = MAIN.instantiate()
		root.add_child(main)
		await process_frame
		await _play(main)
		var audio: AudioScript = main.get_node("GameAudio")
		await audio.prepare_shutdown()
		main.free()
		await process_frame
	print("Trader smoke test: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _play(main: Node) -> void:
	var menu: CanvasLayer = main.get_node("SessionMenu")
	_click(menu.get_node("%StartSession"))
	await process_frame
	await process_frame
	var session: Node = main.get_node_or_null("Session")
	if session == null:
		_check(false, "Start did not create a trader session")
		return
	var world: World = session.get_node("World")
	var trader: CanvasLayer = session.get_node("ShackPanel")
	var pause: CanvasLayer = main.get_node("PauseMenu")
	var balance: Label = session.get_node("CoinBalance").get_node("%Amount")
	var player: CharacterBody2D = world.get_node("Player")
	var shack: Node2D = world.get_node("FishingShack")
	player.global_position = shack.global_position
	var sack: Sack = world.sack
	sack.store("Pacific sardine (21 cm)", 26, true, preload("res://assets/fish/pacific_sardine.svg"))
	for index: int in 2:
		sack.store("Can", 3, false, preload("res://assets/trader/can.svg"))
	var opening_entries: Array[Sack.Entry] = sack.entries()
	_key(KEY_E)
	await process_frame
	var sell: Button = trader.get_node("%Sell")
	_check(trader.visible and sell.has_focus() and balance.text == "0 gold" and balance.is_visible_in_tree(), "Trader entry did not focus Sell or show the starting balance")
	_key(KEY_ENTER)
	await process_frame
	var inventory: Control = trader.get_node("%SackItems")
	var tray: Control = trader.get_node("%TrayItems")
	var confirm: Button = trader.get_node("%ConfirmSale")
	if not inventory.is_visible_in_tree() or not inventory.get_child(0) is Button:
		_check(false, "Keyboard did not open Sell")
		return
	var tray_drop: Control = trader.get_node("%TrayScroll")
	var sack_drop: Control = trader.get_node("%SackScroll")
	_drag(inventory.get_child(0), tray_drop)
	await process_frame
	if not tray.get_child(0) is Button:
		_check(false, "Dragging the fish to the empty tray failed")
		return
	_check(confirm.text.contains("26") and sack.item_count == 3, "Tray did not quote the fish or moved it out of the Sack before confirmation")
	_key(KEY_ENTER)
	await process_frame
	_check(tray.get_child_count() == 2 and confirm.text.contains("29"), "Keyboard did not move the focused can to the sale tray")
	if tray.get_child_count() < 2:
		return
	_drag(tray.get_child(1), sack_drop)
	await process_frame
	_check(inventory.get_child_count() == 2 and confirm.text.contains("26"), "Dragging back did not undo the can selection")
	_drag(tray.get_child(0), tray_drop)
	await process_frame
	_check(confirm.text.contains("26"), "Dropping an item on the same side changed the selection")
	_click(inventory.get_child(1))
	await process_frame
	_click(confirm)
	_click(confirm)
	await process_frame
	_check(world.shop.coins == 29 and balance.text == "29 gold" and sack.entries() == [opening_entries[1]], "Selected sale did not keep the correct duplicate or credited twice")
	_check(world.shop.sell_selected([opening_entries[0], opening_entries[1]]) == 0 and world.shop.sell_selected([opening_entries[1], opening_entries[1]]) == 0, "Stale or duplicate entries passed transaction validation")
	_click(inventory.get_child(0))
	await process_frame
	_begin_drag(tray.get_child(0))
	_check(root.gui_is_dragging(), "The Escape test did not start a drag")
	_key(KEY_ESCAPE)
	_mouse(false)
	await process_frame
	_check(not root.gui_is_dragging() and inventory.is_visible_in_tree() and not confirm.disabled, "Escape did not cancel just the active drag")
	_key(KEY_ESCAPE)
	await process_frame
	_check(trader.visible and sell.has_focus() and not pause.visible and sack.item_count == 1 and world.rod.cast_number == 0, "Escape in Sell did not return to the trader home without selling or pausing")
	_key(KEY_F)
	_check(sack.item_count == 1 and world.shop.coins == 29, "F in trader home sold the Sack")
	_click(sell)
	await process_frame
	_check(confirm.disabled and tray.get_child(0) is Label, "A canceled selection survived returning to Sell")
	_click(trader.get_node("%Back"))
	await process_frame
	_click(trader.get_node("%Buy"))
	await process_frame
	_key(KEY_F)
	_check(sack.item_count == 1 and world.shop.coins == 29, "F in Buy sold the Sack")
	var gear: Control = trader.get_node("%Gear")
	var offers: Array[Node] = gear.find_children("*", "Button", true, false)
	var shore_rod: Button = offers[0]
	_check(not shore_rod.disabled and offers[1].disabled and offers[1].text.begins_with("Locked"), "Buy did not show correct rod availability")
	_click(shore_rod)
	await process_frame
	_check(shore_rod.disabled and shore_rod.text == "Owned" and balance.text == "5 gold", "Purchase did not update the visible balance and ownership")
	_click(shore_rod)
	var add_ons: Control = trader.get_node("%RodAddOns")
	var guard: Button = add_ons.find_children("*", "Button", true, false)[0]
	var catalog: ScrollContainer = trader.get_node("%BuyScroll")
	_check(guard.disabled and guard.text == "12 gold", "The equipped rod add-on did not show its price and affordability")
	world.shop.coins += 15
	world.shop.purchases_changed.emit()
	catalog.ensure_control_visible(guard)
	await process_frame
	_click(guard)
	await process_frame
	_check(guard.disabled and guard.text == "Owned · 12 gold" and world.shop.owns_rod_add_on(1, 0) and balance.text == "8 gold", "Trader input did not equip and charge for the add-on once")
	_key(KEY_ESCAPE)
	await process_frame
	_check(trader.visible and sell.has_focus() and not pause.visible, "Escape in Buy did not return to the trader home")
	_key(KEY_ESCAPE)
	await process_frame
	_check(not trader.visible and not pause.visible and world.rod.cast_number == 0, "Escape at the trader home did not return to shore without pausing")
	_key(KEY_F)
	_check(sack.item_count == 1 and world.shop.coins == 8, "F on shore sold the Sack")
	_key(KEY_E)
	await process_frame
	_click(sell)
	await process_frame
	await _test_sell_all(trader, world, balance)
	_key(KEY_E)
	await process_frame
	_check(not trader.visible and not pause.visible, "E did not close the trader directly from Sell")
	_key(KEY_E)
	await process_frame
	_click(trader.get_node("%Close"))
	_key(KEY_ESCAPE)
	await process_frame
	_check(pause.visible and balance.is_visible_in_tree() and balance.text == "23 gold" and world.rod.cast_number == 0, "The balance or input state did not survive return to shore and pause")


func _test_sell_all(trader: CanvasLayer, world: World, balance: Label) -> void:
	var sack: Sack = world.sack
	var inventory: Control = trader.get_node("%SackItems")
	var tray: Control = trader.get_node("%TrayItems")
	var confirm: Button = trader.get_node("%ConfirmSale")
	var sell_all: Button = trader.get_node("%SellAll")
	var coin_updates: Array[int] = []
	world.shop.purchases_changed.connect(func() -> void: coin_updates.append(world.shop.coins))
	for index: int in 2:
		sack.store("Can", 3, false, preload("res://assets/trader/can.svg"))
	await process_frame
	_click(inventory.get_child(0))
	await process_frame
	_check(tray.get_child_count() == 1 and tray.get_child(0) is Button and inventory.get_child_count() == 2, "Sell All fixture did not separate the identical cans between the Sack and tray")
	_check(sell_all.is_visible_in_tree() and not sell_all.disabled and sell_all.text == "Sell All (F)  ·  9 gold" and confirm.text.contains("3 gold"), "Sell All did not quote all items while the selected sale quoted only the tray")
	_send_key(KEY_F, true, true)
	_send_key(KEY_F, false)
	_check(sack.item_count == 3 and coin_updates.is_empty(), "An F key repeat triggered Sell All")
	_begin_drag(inventory.get_child(0))
	_check(root.gui_is_dragging(), "The Sell All test did not start a drag")
	_send_key(KEY_F, true)
	_mouse(false)
	await process_frame
	_check(not root.gui_is_dragging() and sack.item_count == 0 and balance.text == "17 gold" and coin_updates == [17], "F did not sell staged and unstaged items in a single transaction or left an active drag")
	_check(sell_all.disabled and confirm.disabled and tray.get_child(0) is Label, "Sell All did not clear the tray and disable both sale actions")
	_click(sell_all)
	_send_key(KEY_F, true, true)
	_check(coin_updates == [17], "Clicking the empty Sell All button or repeating F emitted another transaction")
	for index: int in 2:
		sack.store("Can", 3, false, preload("res://assets/trader/can.svg"))
	await process_frame
	_send_key(KEY_F, true, true)
	_send_key(KEY_F, false)
	_check(sack.item_count == 2 and coin_updates == [17], "Repeating a held F sold newly stored items")
	_click(inventory.get_child(0))
	await process_frame
	_click(sell_all)
	_click(sell_all)
	_key(KEY_F)
	await process_frame
	_check(sack.item_count == 0 and sell_all.disabled and balance.text == "23 gold" and coin_updates == [17, 23], "Clicking Sell All with staged and unstaged items did not credit the full load once")


func _drag(item: Control, destination: Control) -> void:
	var target: Vector2 = destination.get_global_rect().get_center()
	_begin_drag(item)
	_move(target, true)
	_mouse(false)


func _begin_drag(item: Control) -> void:
	var start: Vector2 = item.get_global_rect().get_center()
	_move(start)
	_mouse(true)
	_move(start + Vector2(21, 0), true)


func _click(control: Control) -> void:
	_move(control.get_global_rect().get_center())
	_mouse(true)
	_mouse(false)


func _move(point: Vector2, held: bool = false) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = point - _pointer
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_pointer = point
	root.push_input(motion, true)


func _mouse(pressed: bool) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = _pointer
	click.global_position = _pointer
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	root.push_input(click, true)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		_send_key(code, pressed)


func _send_key(code: Key, pressed: bool, echo: bool = false) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = pressed
	key.echo = echo
	root.push_input(key, true)
