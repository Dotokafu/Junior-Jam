shader_type canvas_item;
render_mode blend_disabled;
// Basınç (Jacobi): engel komşusunun basıncı yerine merkezinki. first: önceki basınç 0.
uniform sampler2D pressure_tex : filter_linear, repeat_disable;
uniform sampler2D divergence_tex : filter_linear, repeat_disable;
uniform sampler2D collision_tex : filter_linear, repeat_disable;
uniform float texel;
uniform bool first = false;
float neighbor(vec2 at, float center) {
	float p = first ? 0.0 : texture(pressure_tex, at).x;
	return center + texture(collision_tex, at).z * (p - center);
}
void fragment() {
	float center = first ? 0.0 : texture(pressure_tex, UV).x;
	vec2 dx = vec2(texel, 0.0);
	vec2 dy = vec2(0.0, texel);
	float sum = neighbor(UV - dx, center) + neighbor(UV + dx, center) + neighbor(UV - dy, center) + neighbor(UV + dy, center);
	COLOR = vec4((sum - texture(divergence_tex, UV).x) * 0.25);
}
