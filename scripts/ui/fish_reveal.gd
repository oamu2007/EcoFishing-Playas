extends CanvasLayer

signal dismissed

const RARITY_COLORS: Dictionary[FishSpecies.Rarity, Color] = {
	FishSpecies.Rarity.COMMON: Color("8cde9e"),
	FishSpecies.Rarity.RARE: Color("82bdff"),
	FishSpecies.Rarity.TROPHY: Color("ffd28a"),
}
const CARD_DARK: Color = Color("101611")

var _trophy: bool = false
var _accent: Color
var _burst_progress: float = 0.0
var _entrance: Tween
var _card_style: StyleBoxFlat

@onready var _card: PanelContainer = %Card
@onready var _art: TextureRect = %FishArt
@onready var _plate: ColorRect = %Illustration
@onready var _rarity: Label = %Rarity
@onready var _species: Label = %Species
@onready var _length: Label = %Length
@onready var _value: Label = %SaleValue
@onready var _continue: Button = %Continue


func _ready() -> void:
	_continue.pressed.connect(dismiss)
	_plate.draw.connect(_draw_plate)
	_card_style = _card.get_theme_stylebox("panel").duplicate()
	_card.add_theme_stylebox_override("panel", _card_style)


func present(species: FishSpecies, length_cm: int, sale_value: int) -> void:
	_trophy = species.rarity == FishSpecies.Rarity.TROPHY
	_accent = RARITY_COLORS[species.rarity]
	_card_style.bg_color = CARD_DARK.lerp(_accent, 0.09)
	_card_style.border_color = CARD_DARK.lerp(_accent, 0.85 if _trophy else 0.48)
	_card_style.set_border_width_all(2 if _trophy else 1)
	_plate.color = CARD_DARK.lerp(_accent, 0.19)
	_plate.custom_minimum_size.y = 196.0 if _trophy else 153.0
	_rarity.text = ["Common", "Rare", "Trophy catch"][species.rarity]
	_rarity.add_theme_color_override("font_color", _accent)
	_species.text = species.title
	_length.text = "%d cm" % length_cm
	_value.text = "%d gold" % sale_value
	_art.texture = species.art
	_update_burst(0.0)
	show()
	_continue.grab_focus()
	if _entrance != null:
		_entrance.kill()
	var display_scale: float = remap(clampf(length_cm, 10.0, 38.0), 10.0, 38.0, 0.70, 1.07)
	display_scale += remap(clampf(length_cm, 38.0, 85.0), 38.0, 85.0, 0.0, 0.13)
	if _trophy:
		display_scale *= 1.10
	_art.pivot_offset = _art.size * 0.5
	_art.scale = Vector2.ONE * display_scale * (0.34 if _trophy else 0.78)
	_art.modulate.a = 0.0
	_entrance = create_tween().set_parallel(true)
	_entrance.tween_property(_art, "modulate:a", 1.0, 0.31 if _trophy else 0.23)
	_entrance.tween_property(_art, "scale", Vector2.ONE * display_scale, 0.68 if _trophy else 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _trophy:
		_entrance.tween_method(_update_burst, 0.0, 1.0, 0.90).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func dismiss() -> void:
	if visible:
		if _entrance != null:
			_entrance.kill()
		hide()
		dismissed.emit()


func _update_burst(progress: float) -> void:
	_burst_progress = progress
	_plate.queue_redraw()


func _draw_plate() -> void:
	var center: Vector2 = _plate.size * 0.5
	for radius: float in [47.0, 70.0]:
		_plate.draw_arc(center, radius, 0.0, TAU, 64, Color(_accent, 0.31), 1.0, true)
	_plate.draw_line(Vector2(16.0, center.y), Vector2(center.x - 92.0, center.y), Color(_accent, 0.32), 1.0, true)
	_plate.draw_line(Vector2(center.x + 92.0, center.y), Vector2(_plate.size.x - 16.0, center.y), Color(_accent, 0.32), 1.0, true)
	if _trophy:
		var halo: float = lerpf(32.0, 86.0, _burst_progress)
		_plate.draw_arc(center, halo, 0.0, TAU, 64, Color(_accent, lerpf(0.82, 0.18, _burst_progress)), 2.0, true)
		_plate.draw_circle(center, halo, Color(_accent, lerpf(0.18, 0.05, _burst_progress)), true, -1.0, true)
		for index: int in range(16):
			var direction: Vector2 = Vector2.from_angle(TAU * index / 16.0)
			var offset: Vector2 = direction * Vector2(154.0, 70.0)
			var leading_edge: Vector2 = center + offset * lerpf(0.42, 1.15, _burst_progress)
			var trailing_edge: Vector2 = center + offset * lerpf(0.23, 0.99, _burst_progress)
			_plate.draw_line(trailing_edge, leading_edge, Color(_accent, 0.69), 2.0, true)
			if index % 2 == 0:
				_plate.draw_circle(leading_edge, 2.2, _accent, true, -1.0, true)
