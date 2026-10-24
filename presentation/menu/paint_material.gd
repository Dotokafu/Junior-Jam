class_name PaintMaterial
extends RefCounted
## Menü öğeleri için boya dokusu malzemesi (paint_texture.gdshader).

const SHADER := preload("res://presentation/menu/paint_texture.gdshader")
const GRAIN := preload("res://presentation/menu/paint_grain.tres")

static func make(strength: float, erosion: float = 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("grain", GRAIN)
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("erosion", erosion)
	return material
