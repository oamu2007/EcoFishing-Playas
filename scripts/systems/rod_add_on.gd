class_name RodAddOn
extends Resource

@export var title: String
@export_range(1, 100) var cost: int = 12
@export_range(0, 1) var forgiven_misses: int = 0
@export_range(0.0, 0.5, 0.01) var duration_discount: float = 0.0


func effect_text() -> String:
	if forgiven_misses > 0:
		return "Retries one missed input per fish"
	return "%d%% shorter casts and reels" % roundi(duration_discount * 100.0)
