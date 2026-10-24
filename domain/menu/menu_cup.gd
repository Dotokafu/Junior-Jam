class_name MenuCup
extends RefCounted
## Topdown menüdeki tek bir fincanın/bardağın dolum ve seçim kuralları (Domain).
## Sunum veya görsel düğümlerden tamamen bağımsız, saf iş mantığıdır.

signal filled()
signal progress_changed(amount: float)

var id: String = ""
var label_key: String = ""
var fill_amount: float = 0.0
var fill_target: float = 1.0
var pour_rate: float = 1.15  # Yaklaşık 0.85-0.9 saniyede tam dolar
var drain_rate: float = 0.75  # Doldurma bırakıldığında boşalma hızı
var is_full: bool = false

func _init(p_id: String = "", p_label_key: String = "", p_fill_target: float = 1.0, p_pour_rate: float = 1.15, p_drain_rate: float = 0.75) -> void:
	id = p_id
	label_key = p_label_key
	fill_target = p_fill_target
	pour_rate = p_pour_rate
	drain_rate = p_drain_rate

## Kahve doldurma adımı. Dolduğu anda true döner (seçim tamamlanma olayı).
func pour(delta: float) -> bool:
	if is_full:
		return false
	fill_amount = clampf(fill_amount + pour_rate * delta, 0.0, fill_target)
	progress_changed.emit(get_progress())
	if fill_amount >= fill_target:
		is_full = true
		filled.emit()
		return true
	return false

## Doldurma bırakıldığında yavaşça boşaltır.
func drain(delta: float) -> void:
	if is_full:
		return
	if fill_amount > 0.0:
		fill_amount = clampf(fill_amount - drain_rate * delta, 0.0, fill_target)
		progress_changed.emit(get_progress())

func reset() -> void:
	fill_amount = 0.0
	is_full = false
	progress_changed.emit(0.0)

func get_progress() -> float:
	return fill_amount / fill_target if fill_target > 0.0 else 0.0
