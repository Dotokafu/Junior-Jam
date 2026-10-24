shader_type canvas_item;
// Teslim ekranının gölgesi: iki dikdörtgen delik (ekran pikseli: x, y, genişlik, yükseklik) dışında karartır.
uniform vec4 hole_a;
uniform vec4 hole_b;
uniform vec2 screen_size = vec2(1920.0, 1080.0);
uniform float darkness = 0.66;
uniform float feather = 28.0;

float lit(vec2 p, vec4 r) {
	vec2 d = max(r.xy - p, p - (r.xy + r.zw));
	return 1.0 - smoothstep(0.0, feather, length(max(d, vec2(0.0))));
}

void fragment() {
	vec2 p = UV * screen_size;
	COLOR = vec4(0.0, 0.0, 0.0, darkness * (1.0 - max(lit(p, hole_a), lit(p, hole_b))));
}
