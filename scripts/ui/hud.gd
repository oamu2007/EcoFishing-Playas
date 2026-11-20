extends CanvasLayer

var _notification_remaining: float = 0.0
var _startup_hint_remaining: float = 6.0
var _hooked_count: int = 0

@onready var _progress: Label = $ProgressPanel/Margin/Progress
@onready var _notification: Label = $Notification
@onready var _help: PanelContainer = $ControlsPanel
@onready var _hint: Label = $Hint
@onready var _pollution_bar: ProgressBar = $PollutionBar


func bind_cleanup(pollution: PollutionSystem, trash: TrashManager, rod: FishingRod) -> void:
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


func _on_pollution_changed(normalized: float) -> void:
	_progress.text = "POLLUTION  %d%%" % roundi(normalized * 100.0)
	_pollution_bar.value = normalized * 100.0


func _on_rod_state_changed(state: FishingRod.State) -> void:
	if state == FishingRod.State.CASTING:
		_hooked_count = 0
		_notification_remaining = 0.0
		_notification.hide()


func _on_trash_hooked(type_name: String) -> void:
	_hooked_count += 1
	_notify("Hooked %s" % type_name if _hooked_count == 1 else "Hooked %d items" % _hooked_count)


func _on_trash_returned(count: int, type_name: String) -> void:
	match count:
		0: _notify("Nothing caught. Aim at floating trash.")
		1: _notify("Collected %s" % type_name)
		_: _notify("Collected %d items" % count)


func _notify(message: String) -> void:
	_notification.text = message
	_notification_remaining = 3.0
	_notification.show()
