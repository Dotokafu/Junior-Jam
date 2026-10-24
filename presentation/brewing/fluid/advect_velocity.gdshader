shader_type canvas_item;
render_mode blend_disabled;
// Hız taşıma: hız ve engel aynı geri izlenen noktadan örneklenir; engel hızı söndürür.
uniform sampler2D velocity_tex : filter_linear, repeat_disable;
uniform sampler2D collision_tex : filter_linear, repeat_disable;
uniform float step_scale;
uniform float keep = 1.0;
void fragment() {
	vec2 back = UV - step_scale * texture(velocity_tex, UV).xy;
	COLOR = texture(velocity_tex, back) * texture(collision_tex, back).z * keep;
}
