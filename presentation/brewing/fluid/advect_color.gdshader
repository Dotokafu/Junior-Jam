shader_type canvas_item;
render_mode blend_disabled;
// Renk taşıma (yarı-Lagrange): hızın geri götürdüğü noktadan örnek alır. Engelin altında renk
// içecek rengine döner. clear: her yer içecek rengi.
uniform sampler2D color_tex : filter_linear, repeat_disable;
uniform sampler2D velocity_tex : filter_linear, repeat_disable;
uniform sampler2D collision_tex : filter_linear, repeat_disable;
uniform vec4 base_color;
uniform float step_scale;   // timeStep × simStrength
uniform float dissipation;  // her adım taban rengine dönüş
uniform bool clear = false;
void fragment() {
	if (clear) {
		COLOR = base_color;
	} else {
		vec2 back = UV - step_scale * texture(velocity_tex, UV).xy;
		vec4 color = texture(color_tex, back);
		float fade = (1.0 - texture(collision_tex, back).z) * 0.01 + dissipation;
		COLOR = clamp(color + fade * (base_color - color), 0.0, 1.0);
	}
}
