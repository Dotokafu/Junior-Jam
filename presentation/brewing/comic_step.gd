extends Control
## Demleme sayfasındaki tek adım karesi: kavanoz eğilir, akış fincana iner, ses efekti patlar.
## res://assets/comic/<malzeme id>.png varsa kare kodla kurulmaz, o çizim gösterilir.
const ART_PATH := "res://assets/comic/%s.png"
const ICON_PATH := "res://assets/ui/ingredients/%s.png"
const POP_TIME := 0.18
const POUR_TIME := 0.3
## Yerleşim kare boyutuna göre hesaplanır (oranlar karenin yüksekliğine göre).
const JAR_TOP := 0.08
const COUNTER_TOP := 0.8
const SFX_TOP := 0.4
const LIQUID_DEPTH := 32.0
## Her demlemede kare biraz farklı çizilir (yalnızca görsel; oyun durumunu etkilemez).
const JAR_TILT := Vector2(-2.45, -1.95)
const SFX_TILT := Vector2(-0.3, 0.25)
const SFX_SCALE := Vector2(0.85, 1.25)
const SFX_DRIFT := 70.0
const CAPTION_MARGIN := 12.0
var stream_length: float = 0.0
@onready var art: TextureRect = $Art
@onready var jar: TextureRect = $Jar
@onready var stream: TextureRect = $Stream
@onready var cup: Control = $Cup
@onready var liquid: TextureRect = $Cup/Liquid
@onready var caption: Label = $Caption/Text
@onready var sfx: Label = $Sfx

var sfx_offset := Vector2.ZERO
var sfx_size := 1.0
var caption_bottom: bool = false

func _ready() -> void:
	resized.connect(_layout)
	_layout()

## Kavanoz eğimi, ses efektinin yeri/açısı/boyutu ve anlatım kutusunun köşesi rastgele.
func randomize_look(rng: RandomNumberGenerator) -> void:
	jar.rotation = rng.randf_range(JAR_TILT.x, JAR_TILT.y)
	sfx.rotation = rng.randf_range(SFX_TILT.x, SFX_TILT.y)
	sfx_size = rng.randf_range(SFX_SCALE.x, SFX_SCALE.y)
	sfx_offset = Vector2(rng.randf_range(-SFX_DRIFT, SFX_DRIFT), rng.randf_range(-SFX_DRIFT, SFX_DRIFT) * 0.6)
	caption_bottom = rng.randf() < 0.35
	_layout()

## Kavanoz üstte eğik, akış ortadan iner, fincan tezgâhın üstünde durur.
func _layout() -> void:
	var center_x := size.x / 2.0
	for node: Control in [$Backdrop, $Dots, art, $Frame]:
		node.position = Vector2.ZERO
		node.size = size
	jar.position = Vector2(center_x - 12.0, size.y * JAR_TOP)
	cup.position = Vector2(center_x - cup.size.x / 2.0, size.y * COUNTER_TOP + 12.0 - cup.size.y)
	stream.position = Vector2(center_x - stream.size.x / 2.0, jar.position.y + 160.0)
	stream_length = cup.position.y + LIQUID_DEPTH - stream.position.y
	stream.size.y = stream_length
	sfx.position = Vector2(center_x - sfx.size.x / 2.0, size.y * SFX_TOP) + sfx_offset
	var caption_box: Control = $Caption
	caption_box.position = Vector2(CAPTION_MARGIN, size.y - caption_box.size.y - CAPTION_MARGIN if caption_bottom else CAPTION_MARGIN)
	pivot_offset = size / 2.0
	sfx.pivot_offset = sfx.size / 2.0

## mixed_color: bu adıma kadar eklenenlerin karışım rengi (fincandaki sıvı).
func setup(item: Dictionary, index: int, mixed_color: Color) -> void:
	caption.text = "%d · %s" % [index + 1, str(item.get("name", "")).to_upper()]
	sfx.text = str(item.get("sfx", ""))
	var art_path := ART_PATH % item.get("id", "")
	var has_art := ResourceLoader.exists(art_path)
	art.visible = has_art
	if has_art:
		art.texture = load(art_path)
	for node: CanvasItem in [jar, stream, cup]:
		node.visible = not has_art
	var icon_path := ICON_PATH % item.get("id", "")
	jar.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	stream.modulate = Color(str(item.get("color", "ffffff")))
	liquid.modulate = mixed_color

func reset() -> void:
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	stream.size.y = 0.0
	sfx.modulate.a = 0.0

func show_instantly() -> void:
	modulate.a = 1.0
	scale = Vector2.ONE
	stream.size.y = stream_length
	sfx.modulate.a = 1.0
	sfx.scale = Vector2.ONE * sfx_size

## Kare belirir → akış dökülür → ses efekti patlar. Bekleyebilmek için tween döner.
func play() -> Tween:
	reset()
	var chain := create_tween()
	chain.set_parallel(true)
	chain.tween_property(self, "modulate:a", 1.0, POP_TIME)
	chain.tween_property(self, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	chain.set_parallel(false)
	chain.tween_property(stream, "size:y", stream_length, POUR_TIME).set_ease(Tween.EASE_IN)
	chain.tween_callback(func() -> void: sfx.scale = Vector2(1.6, 1.6))
	chain.set_parallel(true)
	chain.tween_property(sfx, "modulate:a", 1.0, 0.08)
	chain.tween_property(sfx, "scale", Vector2.ONE * sfx_size, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return chain
