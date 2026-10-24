extends HBoxContainer
## Makine göstergesi: 3 ölçü yuvası + 4 tat çubuğu. Demleme ekranında ve çizgi roman sayfasında kullanılır.
const Brewing = preload("res://domain/brewing/brewing_rules.gd")
const ICON_PATH := "res://assets/ui/ingredients/%s.png"
const SLOT_ICON := Vector2(40, 50)
const SEGMENTS := 8
const SEGMENT_SIZE := Vector2(15, 24)
const SEGMENT_ON := Color("6b3f2a")
const SEGMENT_PREVIEW := Color("c99a6b")
const SEGMENT_ON_TEXTURE := preload("res://assets/ui/segment_on.png")
const SEGMENT_OFF_TEXTURE := preload("res://assets/ui/segment_off.png")
const STAT_KEYS := {"warm": "brew.stat_warm", "cool": "brew.stat_cool", "sweet": "brew.stat_sweet", "bitter": "brew.stat_bitter"}
var slot_rows: Array[Dictionary] = []
var stat_rows: Dictionary = {}
@onready var slots: VBoxContainer = $Left/Slots
@onready var stats_box: VBoxContainer = $Mid/Stats

func _ready() -> void:
	$Mid/StatsTitle.text = I18n.t("brew.taste")
	_build_slots()
	_build_stats()

func slot_panels() -> Array:
	return slot_rows.map(func(row: Dictionary) -> Control: return row.panel)

func show_slots(selected: Array, ingredients: Dictionary) -> void:
	for i in range(slot_rows.size()):
		var row: Dictionary = slot_rows[i]
		if i < selected.size():
			var item: Dictionary = ingredients.get(selected[i], {})
			row.label.text = str(item.get("name", "?")).to_upper()
			var icon_path := "res://assets/custom/coffee_pot.png" if item.get("id", "") == "coffee" and ResourceLoader.exists("res://assets/custom/coffee_pot.png") else ICON_PATH % item.get("id", "")
			row.icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
		else:
			row.label.text = I18n.t("brew.slot_base") if i == 0 else I18n.t("brew.slot_empty", {"index": i + 1})
			row.icon.texture = null
		row.panel.modulate = Color.WHITE if i < selected.size() else Color(1, 1, 1, 0.65)

## base: kesin değerler; preview: üzerine gelinen malzemeyle oluşacak değerler (açık renk).
func show_stats(base: Dictionary, preview: Dictionary) -> void:
	for stat: String in Brewing.STATS:
		var row: Dictionary = stat_rows[stat]
		var value := int(base.get(stat, 0))
		var future := int(preview.get(stat, 0))
		for i in range(SEGMENTS):
			var segment: TextureRect = row.segments[i]
			var filled := i < future
			segment.texture = SEGMENT_ON_TEXTURE if filled else SEGMENT_OFF_TEXTURE
			segment.modulate = (SEGMENT_ON if i < value else SEGMENT_PREVIEW) if filled else Color.WHITE
		row.tier.text = I18n.t("brew.tier_%d" % Brewing.tier(future))

static func tier_summary(tiers: Dictionary) -> String:
	var parts: Array[String] = []
	for stat: String in Brewing.STATS:
		if int(tiers.get(stat, 0)) > 0:
			parts.append(I18n.t(STAT_KEYS[stat]) + " " + I18n.t("brew.tier_%d" % int(tiers[stat])))
	return "  ·  ".join(parts)

func _build_slots() -> void:
	for i in range(Brewing.SLOTS):
		var row := PanelContainer.new()
		row.theme_type_variation = &"SlotPanel"
		slots.add_child(row)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		row.add_child(line)
		var label := Label.new()
		label.theme_type_variation = &"MachineLabel"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(label)
		var icon := TextureRect.new()
		icon.custom_minimum_size = SLOT_ICON
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(icon)
		slot_rows.append({"panel": row, "icon": icon, "label": label})

func _build_stats() -> void:
	for stat: String in Brewing.STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		stats_box.add_child(row)
		var name_label := Label.new()
		name_label.theme_type_variation = &"MachineLabel"
		name_label.custom_minimum_size = Vector2(84, 0)
		name_label.text = I18n.t(STAT_KEYS[stat])
		row.add_child(name_label)
		var segments: Array[TextureRect] = []
		for i in range(SEGMENTS):
			var segment := TextureRect.new()
			segment.custom_minimum_size = SEGMENT_SIZE
			segment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			segment.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			segment.texture = SEGMENT_OFF_TEXTURE
			row.add_child(segment)
			segments.append(segment)
		var tier_label := Label.new()
		tier_label.theme_type_variation = &"MachineLabel"
		tier_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(tier_label)
		stat_rows[stat] = {"segments": segments, "tier": tier_label}
