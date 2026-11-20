extends SceneTree

const MAIN: PackedScene = preload("res://scenes/gameplay/main.tscn")
const World = preload("res://scripts/gameplay/playas_vertical_slice.gd")

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
	_key(KEY_ESCAPE)
	await process_frame
	_check(not trader.visible and not menu.visible and sack.item_count == 1 and world.rod.cast_number == 0, "Trader cancel changed the load or leaked a fishing or pause input")
	_key(KEY_E)
	await process_frame
	_click(sell)
	await process_frame
	_check(confirm.disabled and tray.get_child(0) is Label, "A canceled selection survived returning to Sell")
	_click(trader.get_node("%Back"))
	await process_frame
	_click(trader.get_node("%Buy"))
	await process_frame
	var gear: Control = trader.get_node("%Gear")
	var offers: Array[Node] = gear.find_children("*", "Button", true, false)
	var shore_rod: Button = offers[0]
	_check(not shore_rod.disabled and offers[1].disabled and offers[1].text.begins_with("Locked"), "Buy did not show correct rod availability")
	_click(shore_rod)
	await process_frame
	_check(shore_rod.disabled and shore_rod.text == "Owned" and balance.text == "5 gold", "Purchase did not update the visible balance and ownership")
	_click(shore_rod)
	_click(trader.get_node("%Close"))
	_key(KEY_ESCAPE)
	await process_frame
	_check(menu.visible and balance.is_visible_in_tree() and balance.text == "5 gold" and world.rod.cast_number == 0, "The balance or input state did not survive return to shore and pause")


func _drag(item: Control, destination: Control) -> void:
	var start: Vector2 = item.get_global_rect().get_center()
	var target: Vector2 = destination.get_global_rect().get_center()
	_move(start)
	_mouse(true)
	_move(start + Vector2(21, 0), true)
	_move(target, true)
	_mouse(false)


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
		var key: InputEventKey = InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = pressed
		root.push_input(key, true)
