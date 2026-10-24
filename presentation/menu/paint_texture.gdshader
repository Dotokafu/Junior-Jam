shader_type canvas_item;
// Menünün boyalı resmine uysun diye düz renkleri fırça/kâğıt dokusuyla bozar.
// strength: renk dalgalanması; erosion: alfa aşınması (kazıma, eski boya).
uniform sampler2D grain : repeat_enable, filter_linear;
uniform float strength = 0.18;
uniform float erosion = 0.0;
uniform float grain_scale = 0.0035;
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	float coarse = texture(grain, world * grain_scale).r;
	float fine = texture(grain, world * grain_scale * 5.3 + vec2(0.37, 0.11)).r;
	color.rgb *= 1.0 + (coarse - 0.5) * strength * 2.0 + (fine - 0.5) * strength;
	color.a *= mix(1.0, smoothstep(0.32, 0.62, fine * 0.6 + coarse * 0.4), erosion);
	COLOR = color;
}
