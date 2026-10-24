shader_type canvas_item;
render_mode blend_disabled;
// Hızdan basınç farkı (tam fark) çıkarılır. Engel komşusunda o eksenin hızı engelin hızı olur;
// sağ/üst komşu sol/alt komşuyu ezer.
uniform sampler2D velocity_tex : filter_linear, repeat_disable;
uniform sampler2D pressure_tex : filter_linear, repeat_disable;
uniform sampler2D collision_tex : filter_linear, repeat_disable;
uniform float texel;
void fragment() {
	vec2 dx = vec2(texel, 0.0);
	vec2 dy = vec2(0.0, texel);
	float center = texture(pressure_tex, UV).x;
	vec4 left = texture(collision_tex, UV - dx);
	vec4 right = texture(collision_tex, UV + dx);
	vec4 down = texture(collision_tex, UV - dy);
	vec4 up = texture(collision_tex, UV + dy);
	float p_left = left.z < 0.5 ? center : texture(pressure_tex, UV - dx).x;
	float p_right = right.z < 0.5 ? center : texture(pressure_tex, UV + dx).x;
	float p_down = down.z < 0.5 ? center : texture(pressure_tex, UV - dy).x;
	float p_up = up.z < 0.5 ? center : texture(pressure_tex, UV + dy).x;
	vec2 mask = vec2(left.z < 0.5 || right.z < 0.5 ? 0.0 : 1.0, down.z < 0.5 || up.z < 0.5 ? 0.0 : 1.0);
	vec2 obstacle = vec2(right.z < 0.5 ? right.x : (left.z < 0.5 ? left.x : 0.0), up.z < 0.5 ? up.y : (down.z < 0.5 ? down.y : 0.0));
	vec2 velocity = texture(velocity_tex, UV).xy - vec2(p_right - p_left, p_up - p_down);
	COLOR = vec4(velocity * mask + obstacle, 0.0, 0.0);
}
