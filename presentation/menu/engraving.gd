extends Control
## Bardağın gövdesine kazınmış yazı: harfler silindir gövdenin ön yüzüne sarılır (kenarlara doğru
## yukarı kıvrılır ve daralır). Oyuk = koyu dolgu + üst kenarda gölge + alt kenarda ışık.

const FONT := preload("res://assets/fonts/Cinzel.ttf")
const RECESS := Color(0.30, 0.27, 0.25, 0.95)
const INNER_SHADOW := Color(0.16, 0.14, 0.13, 0.55)
const EDGE_LIGHT := Color(0.97, 0.95, 0.90, 0.75)
const SUBTITLE_GAP := 6.0

var title: String = ""
var subtitle: String = ""
## Gövde halkası: merkez x, yazının ortadaki taban çizgisi, yarıçap ve halkanın dikey yarıçapı.
var center_x: float = 0.0
var baseline_y: float = 0.0
var radius: float = 100.0
var curve: float = 20.0
var title_size: int = 34
var subtitle_size: int = 16
var font: FontVariation

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = FontVariation.new()
	font.base_font = FONT
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	material = PaintMaterial.make(0.26, 0.18)

func setup(p_title: String, p_subtitle: String) -> void:
	title = p_title
	subtitle = p_subtitle
	queue_redraw()

func _draw() -> void:
	_draw_ring_text(title.to_upper(), title_size, baseline_y)
	if subtitle != "":
		_draw_ring_text(subtitle.to_upper(), subtitle_size, baseline_y + title_size * 0.55 + SUBTITLE_GAP)
	draw_set_transform(Vector2.ZERO)

## Metni gövde halkası boyunca yerleştirir: yay uzunluğu → açı; x = R·sin, y = curve·(cos − 1).
func _draw_ring_text(text: String, size_px: int, base_y: float) -> void:
	var widths: Array[float] = []
	var total := 0.0
	for c in text:
		var w: float = font.get_char_size(c.unicode_at(0), size_px).x
		widths.append(w)
		total += w
	var s := -total / 2.0
	for i in range(text.length()):
		var mid := s + widths[i] / 2.0
		s += widths[i]
		var angle := mid / radius
		if absf(angle) > PI * 0.42:
			continue
		var pos := Vector2(center_x + radius * sin(angle), base_y + curve * (cos(angle) - 1.0))
		var tilt := atan2(-curve * sin(angle), radius * cos(angle))
		var squeeze := maxf(cos(angle), 0.2)
		var code := text.unicode_at(i)
		var origin := Vector2(-widths[i] / 2.0, 0.0)
		for layer: Array in [[Vector2(0, 1.6), EDGE_LIGHT], [Vector2(0, -1.0), INNER_SHADOW], [Vector2.ZERO, RECESS]]:
			draw_set_transform(pos + layer[0], tilt, Vector2(squeeze, 1.0))
			draw_char(font, origin, char(code), size_px, layer[1])
