extends CanvasLayer

var _shop: ShackShop

@onready var _balance: Label = %Amount


func bind_shop(shop: ShackShop) -> void:
	_shop = shop
	_shop.purchases_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_balance.text = "%d gold" % _shop.coins
