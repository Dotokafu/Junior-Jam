extends Control
## Tezgâhtaki karakter. Çizim: res://assets/characters/<id>.png (el çizimi, yumuşak filtre).
## Çizim bu düğümün kutusuna oranı korunarak sığdırılır ve alttan hizalanır; çözünürlük serbesttir.
## Rastgele müşteriler görünüşünü portrait_id karakterinden alır.
## Balon çapası: çizimin genişlik/yükseklik oranı olarak (sağ yan, göğüs hizası).
const ANCHOR_RATIO := Vector2(0.8, 0.66)
const ART_PATH := "res://assets/characters/%s.png"
const SWAP_TIME := 0.22
const ENTER_OFFSET := 48.0
const BREATH_TIME := 1.7
const BREATH_SCALE := 1.012
var reduced_motion: bool = false
var person_key: String = ""
var home: Vector2
var swap_tween: Tween
var idle_tween: Tween
@onready var body: TextureRect = $Body
@onready var anchor: Marker2D = $BalloonAnchor

func _ready() -> void:
	home = position
	modulate.a = 0.0

func show_person(person: Dictionary, key: String) -> void:
	if key == person_key:
		return
	var had_person := person_key != ""
	person_key = key
	var texture := _texture_for(person)
	if swap_tween:
		swap_tween.kill()
	if reduced_motion:
		_apply(texture)
		position = home
		modulate.a = 1.0
		return
	swap_tween = create_tween()
	if had_person and modulate.a > 0.0:
		swap_tween.tween_property(self, "modulate:a", 0.0, SWAP_TIME)
	swap_tween.tween_callback(_apply.bind(texture))
	swap_tween.tween_callback(func() -> void: position = home - Vector2(ENTER_OFFSET, 0))
	swap_tween.set_parallel(true)
	swap_tween.tween_property(self, "modulate:a", 1.0, SWAP_TIME).set_delay(0.05)
	swap_tween.tween_property(self, "position", home, SWAP_TIME * 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func hide_person() -> void:
	if person_key == "":
		return
	person_key = ""
	if swap_tween:
		swap_tween.kill()
	if reduced_motion:
		modulate.a = 0.0
		return
	swap_tween = create_tween()
	swap_tween.tween_property(self, "modulate:a", 0.0, SWAP_TIME)

## Konuşma başlarken küçük bir zıplama.
func bounce() -> void:
	if reduced_motion or person_key == "":
		return
	var hop := create_tween()
	hop.tween_property(body, "position:y", body.position.y - 8.0, 0.08).set_ease(Tween.EASE_OUT)
	hop.tween_property(body, "position:y", body.position.y, 0.14).set_ease(Tween.EASE_IN)

func balloon_point() -> Vector2:
	return anchor.global_position

func _texture_for(person: Dictionary) -> Texture2D:
	for path: String in [str(person.get("portrait_texture", "")), ART_PATH % person.get("portrait_id", ""), ART_PATH % person.get("id", "")]:
		if path.ends_with(".png") and ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

func _apply(texture: Texture2D) -> void:
	body.texture = texture
	var art_size := size
	if texture:
		var fit := minf(size.x / texture.get_width(), size.y / texture.get_height())
		art_size = texture.get_size() * fit
	body.size = art_size
	body.position = Vector2((size.x - art_size.x) / 2.0, size.y - art_size.y)
	body.pivot_offset = Vector2(art_size.x / 2.0, art_size.y)
	anchor.position = body.position + art_size * ANCHOR_RATIO
	_breathe()

func _breathe() -> void:
	if idle_tween:
		idle_tween.kill()
	body.scale = Vector2.ONE
	if reduced_motion:
		return
	idle_tween = create_tween().set_loops()
	idle_tween.tween_property(body, "scale:y", BREATH_SCALE, BREATH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(body, "scale:y", 1.0, BREATH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
