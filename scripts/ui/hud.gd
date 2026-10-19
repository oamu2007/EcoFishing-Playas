extends CanvasLayer

var _notification_remaining: float = 0.0

@onready var _progress: Label = $ProgressPanel/Margin/Progress
@onready var _notification: Label = $Notification


func bind_cleanup(pollution: PollutionSystem, trash: TrashManager) -> void:
	pollution.pollution_changed.connect(_on_pollution_changed)
	trash.trash_hooked.connect(_on_trash_hooked)
	trash.trash_collected.connect(_on_trash_collected)
	_on_pollution_changed(pollution.normalized_pollution, pollution.trash_collected, pollution.remaining_trash)


func _process(delta: float) -> void:
	_notification_remaining = maxf(0.0, _notification_remaining - delta)
	_notification.visible = _notification_remaining > 0.0


func _on_pollution_changed(normalized: float, collected: int, remaining: int) -> void:
	_progress.text = "Collected: %d   Remaining: %d   Pollution: %d%%" % [collected, remaining, roundi(normalized * 100.0)]
	if remaining == 0:
		_progress.text += "\nBeach cleanup complete! All trash collected."


func _on_trash_hooked(type_name: String) -> void:
	_notify("Hooked: %s - click to retrieve" % type_name)


func _on_trash_collected(_item_id: int, type_name: String) -> void:
	_notify("Collected: %s" % type_name)


func _notify(message: String) -> void:
	_notification.text = message
	_notification_remaining = 3.0
	_notification.show()
