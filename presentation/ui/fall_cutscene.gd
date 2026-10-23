extends Control
## Gündüz → gece ara sahnesi. Her parça ayrı görsel katmanı (assets/cutscene/), çizimle değiştirilebilir:
## city_back (şehir) → uzak pencere ışıkları → yarasa → kafe camı ışığı → silüet → building (opak bina,
## kafe camı şeffaf) → yakın pencere ışıkları → çatıdaki tabela (cafe_sign.png).
## Yarasa soldan gelip duvarın arkasına girer (bina önde olduğu için örtülür); o an silüet duvarın
## arkasından camın içine yürür ve sağa gittikçe solar. Üstte "The Fall", altta rastgele ipucu.
signal next_pressed
const BAT_SHEET := "res://assets/cutscene/bat.png"
const WALKER_SHEET := "res://assets/cutscene/walker.png"
const LIGHT_TEXTURE := "res://assets/cutscene/window_light.png"
## Sprite sayfaları: yan yana 2 kare.
const BAT_FRAME := Vector2(20, 12)
const WALKER_FRAME := Vector2(10, 24)
const BAT_FLAP_FPS := 9.0
const WALK_FPS := 6.0
const LIT_CHANCE := 0.35
const FAR_LIGHT := Color(0.6, 0.55, 0.45)
## Pencere ışıkları placeholder bina çizimiyle hizalı (çizim pikseli ×3). Yeni çizimde pencereler
## farklıysa Inspector'dan window_rects doldurulur; boş bırakılırsa bu varsayılanlar kullanılır.
const ART_SCALE := 3.0
const ART_FAR_BLOCKS := [Rect2(120, 187, 87, 146), Rect2(187, 227, 53, 106), Rect2(400, 173, 80, 160), Rect2(473, 213, 100, 120)]
const ART_BUILDING_X := 252.0
const ART_FIRST_FLOOR_Y := 148.0
const ART_FLOOR_STEP := 39.0
## Zamanlama (saniye)
const DRAW_IN := 0.7
const BAT_START := 0.9
const BAT_TIME := 2.0
const WALL_FADE := 40.0
const WALK_START := BAT_START + BAT_TIME
const WALK_TIME := 2.6
const WALK_FADE_FROM := 0.5
const END_TIME := WALK_START + WALK_TIME
## Yarasanın yolu (kübik eğri): soldan giriş, iki kontrol noktası, son nokta duvarın arkasında.
@export var bat_path: Array[Vector2] = [Vector2(-100, 380), Vector2(300, 300), Vector2(600, 370), Vector2(840, 378)]
## Bina duvarının sol kenarı: yarasa buradan geçerken solar (bina katmanı zaten örter).
@export var wall_x: float = 756.0
## Silüetin yürüyüşü: duvarın arkasından başlar, camın sağına kadar.
@export var walk_from_x: float = 760.0
@export var walk_to_x: float = 1080.0
@export var near_window_rects: Array[Rect2] = []
@export var far_window_rects: Array[Rect2] = []
var time: float = 0.0
var reduced_motion: bool = false
var lit: Dictionary = {}
var bat_frames: Array[AtlasTexture] = []
var walker_frames: Array[AtlasTexture] = []
var light: Texture2D
@onready var bat: TextureRect = $Bat
@onready var walker: TextureRect = $Walker
@onready var far_lights: Control = $FarLights
@onready var near_lights: Control = $NearLights
@onready var title: Label = $Title
@onready var tip: Label = $Tip
@onready var next_button: Button = $NextButton

func _ready() -> void:
	title.text = I18n.t("transition.fall_title")
	next_button.text = I18n.t("button.open_door")
	next_button.pressed.connect(func() -> void: next_pressed.emit())
	bat_frames = _frames(BAT_SHEET, BAT_FRAME)
	walker_frames = _frames(WALKER_SHEET, WALKER_FRAME)
	light = load(LIGHT_TEXTURE) if ResourceLoader.exists(LIGHT_TEXTURE) else null
	if near_window_rects.is_empty():
		near_window_rects = _default_near_windows()
	if far_window_rects.is_empty():
		far_window_rects = _default_far_windows()
	_plan_lights()
	far_lights.draw.connect(_draw_lights.bind(far_lights, far_window_rects, FAR_LIGHT))
	near_lights.draw.connect(_draw_lights.bind(near_lights, near_window_rects, Color.WHITE))
	if reduced_motion:
		time = END_TIME
	_update(0.0)

func set_tip(text: String) -> void:
	tip.text = I18n.t("tip.prefix") + text

func skip() -> void:
	time = maxf(time, END_TIME)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and time < END_TIME:
		skip()
		accept_event()

func _process(delta: float) -> void:
	_update(delta)

func _update(delta: float) -> void:
	time += delta
	modulate.a = maxf(clampf(time / DRAW_IN, 0.0, 1.0), 0.05)
	title.modulate.a = clampf((time - 0.3) / 0.6, 0.0, 1.0)
	tip.modulate.a = clampf((time - 0.8) / 0.6, 0.0, 1.0)
	next_button.modulate.a = clampf((time - 1.2) / 0.5, 0.0, 1.0)
	_update_bat()
	_update_walker()

func _update_bat() -> void:
	var t := (time - BAT_START) / BAT_TIME
	bat.visible = t >= 0.0 and t < 1.0 and not bat_frames.is_empty()
	if not bat.visible:
		return
	var center := _bezier(t * t * (3.0 - 2.0 * t))
	bat.position = center - bat.size / 2.0
	bat.texture = bat_frames[int(time * BAT_FLAP_FPS) % bat_frames.size()]
	bat.modulate.a = clampf((wall_x - center.x) / WALL_FADE, 0.0, 1.0)

func _update_walker() -> void:
	var progress := (time - WALK_START) / WALK_TIME
	walker.visible = progress >= 0.0 and progress <= 1.0 and not walker_frames.is_empty()
	if not walker.visible:
		return
	walker.position.x = lerpf(walk_from_x, walk_to_x, progress)
	walker.texture = walker_frames[int(time * WALK_FPS) % walker_frames.size()]
	walker.modulate.a = 1.0 - smoothstep(WALK_FADE_FROM, 1.0, progress)

## Kübik Bézier: bat_path[0] → bat_path[3], kontrol noktaları [1] ve [2].
func _bezier(t: float) -> Vector2:
	var u := 1.0 - t
	return bat_path[0] * u * u * u + bat_path[1] * 3.0 * u * u * t + bat_path[2] * 3.0 * u * t * t + bat_path[3] * t * t * t

func _frames(path: String, frame_size: Vector2) -> Array[AtlasTexture]:
	var result: Array[AtlasTexture] = []
	if not ResourceLoader.exists(path):
		return result
	var sheet: Texture2D = load(path)
	for i in range(int(sheet.get_width() / frame_size.x)):
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(Vector2(i * frame_size.x, 0), frame_size)
		result.append(frame)
	return result

## Hangi pencerelerin ışığı yanacak: her geçişte rastgele.
func _plan_lights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for window: Rect2 in far_window_rects + near_window_rects:
		lit[window] = rng.randf() < LIT_CHANCE

func _draw_lights(layer: Control, rects: Array[Rect2], tint: Color) -> void:
	if light == null:
		return
	for window: Rect2 in rects:
		if lit.get(window, false):
			layer.draw_texture_rect(light, window, false, tint)

func _default_near_windows() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for floor_index in range(4):
		var y := ART_FIRST_FLOOR_Y + floor_index * ART_FLOOR_STEP
		for column in range(3):
			result.append(Rect2((ART_BUILDING_X + 18 + column * 38) * ART_SCALE, (y + 10) * ART_SCALE, 21 * ART_SCALE, 17 * ART_SCALE))
	return result

func _default_far_windows() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for block: Rect2 in ART_FAR_BLOCKS:
		for y in range(int(block.position.y) + 13, int(block.end.y) - 10, 27):
			for x in range(int(block.position.x) + 10, int(block.end.x) - 13, 23):
				result.append(Rect2((x + 1) * ART_SCALE, (y + 1) * ART_SCALE, 8 * ART_SCALE, 9 * ART_SCALE))
	return result
