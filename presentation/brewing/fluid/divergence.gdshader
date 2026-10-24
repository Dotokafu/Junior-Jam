shader_type canvas_item;
render_mode blend_disabled;
// Diverjans: komşu hızlar (engel ağırlıklı) arasındaki fark, yarım.
uniform sampler2D velocity_tex : filter_linear, repeat_disable;
uniform sampler2D collision_tex : filter_linear, repeat_disable;
uniform float texel;
void fragment() {
	vec2 dx = vec2(texel, 0.0);
	vec2 dy = vec2(0.0, texel);
	float x = texture(velocity_tex, UV + dx).x * texture(collision_tex, UV + dx).z - texture(velocity_tex, UV - dx).x * texture(collision_tex, UV - dx).z;
	float y = texture(velocity_tex, UV + dy).y * texture(collision_tex, UV + dy).z - texture(velocity_tex, UV - dy).y * texture(collision_tex, UV - dy).z;
	COLOR = vec4((x + y) * 0.5);
}
