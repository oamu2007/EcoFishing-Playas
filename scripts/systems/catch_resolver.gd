extends Node

signal catch_hooked(type_name: String)
signal catches_returned(count: int, type_name: String)

const ATTACHMENT_COLUMNS: Array[float] = [0.0, -22.0, 22.0, -44.0, 44.0]

var _rod: FishingRod
var _sack: Sack
var _targets: Array[FishingTarget] = []
var _caught: Array[FishingTarget] = []
var _trash_held: int = 0
var _last_returned_cast: int = 0


func initialize(rod: FishingRod, sack: Sack) -> void:
	_rod = rod
	_sack = sack
	rod.hook_landed.connect(_on_hook_landed)
	rod.target_detected.connect(_on_target_detected)
	rod.retrieval_advanced.connect(_on_retrieval_advanced)
	rod.retrieval_completed.connect(_on_retrieval_completed)


func register_target(target: FishingTarget) -> void:
	if not _targets.has(target):
		_targets.append(target)
		target.landed.connect(unregister_target, CONNECT_ONE_SHOT)


func unregister_target(target: FishingTarget) -> void:
	_targets.erase(target)


func _on_hook_landed(point: Vector2) -> void:
	if _rod.state != FishingRod.State.WAITING or not _caught.is_empty() or _sack.free_slots <= 0:
		return
	# Resolve all target types against the current geometry before physics overlap caches catch up.
	var nearest: FishingTarget
	var nearest_distance: float = INF
	for target: FishingTarget in _targets:
		if target.can_hook_at(point):
			var distance: float = target.global_position.distance_squared_to(point)
			if distance < nearest_distance:
				nearest = target
				nearest_distance = distance
	if nearest != null:
		_attach(nearest)


func _on_target_detected(area: Area2D) -> void:
	if area is FishingTarget and _rod.state == FishingRod.State.WAITING:
		# Reparent outside physics signal flushing. A deferred event belongs to one cast.
		_check_waiting_target.call_deferred(_rod.cast_number)


func _check_waiting_target(cast_number: int) -> void:
	if _rod.cast_number == cast_number:
		_on_hook_landed(_rod.get_hook_water_position())


func _on_retrieval_advanced(from: Vector2, to: Vector2, hook_radius: float) -> void:
	if _rod.state != FishingRod.State.RETRIEVING:
		return
	var open_slots: int = mini(_sack.free_slots - _caught.size(), _rod.trash_per_cast - _trash_held)
	if open_slots <= 0:
		return
	var swept: Array[OceanTrash] = []
	for target: FishingTarget in _targets:
		if not target is OceanTrash or not target.can_hook():
			continue
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(target.global_position, from, to)
		var radius: float = target.catch_radius + hook_radius
		if target.global_position.distance_squared_to(nearest) <= radius * radius:
			swept.append(target)
	var direction: Vector2 = to - from
	swept.sort_custom(func(a: OceanTrash, b: OceanTrash) -> bool:
		var a_distance: float = (a.global_position - from).dot(direction)
		var b_distance: float = (b.global_position - from).dot(direction)
		if a_distance == b_distance:
			return _targets.find(a) < _targets.find(b)
		return a_distance < b_distance
	)
	for index: int in mini(open_slots, swept.size()):
		_attach(swept[index])


func _attach(target: FishingTarget) -> void:
	var index: int = _caught.size()
	var offset: Vector2 = Vector2(ATTACHMENT_COLUMNS[index % ATTACHMENT_COLUMNS.size()], 14.0 + floorf(float(index) / ATTACHMENT_COLUMNS.size()) * 24.0)
	if target.attach_to(_rod.get_hook_attachment(), offset):
		_caught.append(target)
		if target is OceanTrash:
			_trash_held += 1
		catch_hooked.emit(target.display_name())


func _on_retrieval_completed(_point: Vector2) -> void:
	if _rod.state != FishingRod.State.IDLE or _last_returned_cast == _rod.cast_number:
		return
	_last_returned_cast = _rod.cast_number
	var returned: Array[FishingTarget] = _caught.duplicate()
	_caught.clear()
	_trash_held = 0
	var type_name: String
	var count: int = 0
	for target: FishingTarget in returned:
		if not is_instance_valid(target) or not target.hooked or target.collected:
			continue
		var label: String = target.display_name()
		if not _sack.store(label, target.sale_price(), target is CatchableFish):
			push_error("A reserved catch could not fit in the Sack")
			continue
		target.finish_collection()
		if count == 0:
			type_name = label
		count += 1
	catches_returned.emit(count, type_name)
