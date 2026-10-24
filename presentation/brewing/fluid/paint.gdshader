shader_type canvas_item;
render_mode blend_disabled;
// Fırçalar renk bırakır: renk = karıştır(renk, fırça rengi, ağırlık × fırça alfası).
uniform sampler2D color_tex : filter_linear, repeat_disable;
uniform int count = 0;
uniform vec4 shape[4];  // x, y, yarıçap, düşüş × 150
uniform vec4 tint[4];
void fragment() {
	vec4 color = texture(color_tex, UV);
	for (int i = 0; i < count; i++) {
		float amount = clamp((shape[i].z - distance(UV, shape[i].xy)) * shape[i].w, 0.0, 1.0) * tint[i].a;
		color += amount * (tint[i] - color);
	}
	COLOR = color;
}
