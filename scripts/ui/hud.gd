extends CanvasLayer

var _notification_remaining: float = 0.0
var _startup_hint_remaining: float = 6.0
var _hooked_count: int = 0
var _returned_count: int = 0
var _previous_remaining: int = -1

@onready var _progress: Label = $ProgressPanel/Margin/Progress
@onready var _notification: Label = $Notification
@onready var _help: PanelContainer = $ControlsPanel
@onready var _hint: Label = $Hint
@onready var _completion: Label = $Completion
@onready var _pollution_bar: ProgressBar = $PollutionBar


func bind_cleanup(pollution: PollutionSystem, trash: TrashManager) -> void:
	pollution.pollution_changed.connect(_on_pollution_changed)
	trash.trash_hooked.connect(_on_trash_hooked)
	trash.trash_collected.connect(_on_trash_collected)
	_on_pollution_changed(pollution.normalized_pollution, pollution.trash_collected, pollution.remaining_trash)


func _process(delta: float) -> void:
	_notification_remaining = maxf(0.0, _notification_remaining - delta)
	_notification.visible = _notification_remaining > 0.0
	_startup_hint_remaining = maxf(0.0, _startup_hint_remaining - delta)
	_hint.text = "WASD / Arrows | Aim + Click | H Help" if _startup_hint_remaining > 0.0 else "H  Help"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help") and not event.is_echo():
		_help.visible = not _help.visible
		get_viewport().set_input_as_handled()


func _on_pollution_changed(normalized: float, collected: int, remaining: int) -> void:
	_progress.text = "TRASH  %d/%d     POLLUTION  %d%%" % [collected, collected + remaining, roundi(normalized * 100.0)]
	_pollution_bar.value = normalized * 100.0
	_completion.visible = remaining == 0
	if remaining != _previous_remaining:
		_hooked_count = 0
	_previous_remaining = remaining


func _on_trash_hooked(type_name: String) -> void:
	if _hooked_count == 0:
		_returned_count = 0
	_hooked_count += 1
	_notify("Hooked %s (%d)" % [type_name, _hooked_count])


func _on_trash_collected(_item_id: int, type_name: String) -> void:
	_returned_count += 1
	_notify("Collected %s" % type_name if _returned_count == 1 else "Collected %d items" % _returned_count)


func _notify(message: String) -> void:
	_notification.text = message
	_notification_remaining = 3.0
	_notification.show()
