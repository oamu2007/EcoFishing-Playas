extends Node2D

signal work_started(watch_cue: String)

const SiteScript = preload("res://scripts/gameplay/cleanup_site.gd")

var _sites: Dictionary[StringName, SiteScript] = {}
var _pending: Array[SiteScript] = []
var _active: SiteScript
var _trader_open: bool = false


func _ready() -> void:
	for child: Node in get_children():
		var site: SiteScript = child as SiteScript
		if site == null or site.site_id.is_empty() or _sites.has(site.site_id):
			push_error("Cleanup site must have a unique site ID: %s" % child.name)
			continue
		_sites[site.site_id] = site
	set_process(false)


func bind_shop(shop: ShackShop) -> void:
	shop.cleanup_funded.connect(_on_cleanup_funded)


func site_for_project(project: CleanupProject) -> SiteScript:
	return _sites.get(project.site_id)


func set_trader_open(value: bool) -> void:
	_trader_open = value
	_continue_work()


func _on_cleanup_funded(project: CleanupProject) -> void:
	var site: SiteScript = site_for_project(project)
	if site != null and not site.has_started and not _pending.has(site):
		_pending.append(site)
		_continue_work()


func _continue_work() -> void:
	if _trader_open:
		set_process(false)
		return
	if _active == null and not _pending.is_empty():
		_active = _pending.pop_front()
		_active.start()
		work_started.emit(_active.watch_cue)
	set_process(_active != null)


func _process(delta: float) -> void:
	_active.advance(delta)
	if _active.is_complete:
		_active = null
		_continue_work()
