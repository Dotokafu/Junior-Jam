shader_type canvas_item;
render_mode blend_disabled;
// Hız alanına fırça itmesi ekler: hız += yön × güç × ağırlık. clear: hızı sıfırlar (köpük baştan).
uniform sampler2D velocity_tex : filter_linear, repeat_disable;
uniform bool clear = false;
uniform int count = 0;
uniform vec4 shape[4];  // x, y, yarıçap, düşüş × 150
uniform vec2 push[4];
void fragment() {
	vec2 velocity = clear ? vec2(0.0) : texture(velocity_tex, UV).xy;
	for (int i = 0; i < count; i++) {
		velocity += push[i] * clamp((shape[i].z - distance(UV, shape[i].xy)) * shape[i].w, 0.0, 1.0);
	}
	COLOR = vec4(velocity, 0.0, 0.0);
}
