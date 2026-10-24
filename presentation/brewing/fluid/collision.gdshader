shader_type canvas_item;
render_mode blend_disabled;
// Engel alanı: rg = engel hızı, b = 1 sıvı / 0 engel. Duvar: kare kenar + fincan dairesi (yarıçap 0.367).
// Fırçalar engel olur: ağırlık = sat((yarıçap - uzaklık) × düşüş × 150); b *= 1 - ağırlık × güç,
// hız += engel hızı × ağırlık × güç.
uniform float texel;
uniform float wall_radius = 0.367;
uniform int count = 0;
uniform vec4 shape[4];   // x, y, yarıçap, düşüş × 150
uniform vec4 motion[4];  // engel hızı x, y, güç
void fragment() {
	vec2 uv = UV;
	bool edge = uv.x <= texel || uv.y <= texel || uv.x >= 1.0 - texel || uv.y >= 1.0 - texel;
	float fluid = (edge || distance(uv, vec2(0.5)) > wall_radius) ? 0.0 : 1.0;
	vec2 velocity = vec2(0.0);
	for (int i = 0; i < count; i++) {
		float weight = clamp((shape[i].z - distance(uv, shape[i].xy)) * shape[i].w, 0.0, 1.0) * motion[i].z;
		velocity += motion[i].xy * weight;
		fluid *= 1.0 - weight;
	}
	COLOR = vec4(velocity, fluid, 0.0);
}
