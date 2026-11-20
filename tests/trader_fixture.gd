extends RefCounted


static func select_all(panel: CanvasLayer) -> void:
	panel.get_node("%Sell").pressed.emit()
	var items: Control = panel.get_node("%SackItems")
	while items.get_child(0) is Button:
		items.get_child(0).pressed.emit()
