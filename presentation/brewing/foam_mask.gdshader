shader_type canvas_item;
// Köpük karesinin yalnızca ortasını (sıvının duvar dairesi, latte_art.gd VISIBLE) fincanın iç dairesine
// kırpar. mask: assets/latte/foam_mask.png (beyaz daire), görünen alanın tamamına gerilir.
uniform sampler2D mask : filter_nearest;
uniform float visible = 0.734375;

void fragment() {
	vec2 mask_uv = (UV - vec2(0.5)) / visible + vec2(0.5);
	float inside = step(0.0, mask_uv.x) * step(mask_uv.x, 1.0) * step(0.0, mask_uv.y) * step(mask_uv.y, 1.0);
	// Köpüğün kendi alfası yok sayılır (Coffee Talk düzlemi opak çizer).
	COLOR = vec4(texture(TEXTURE, UV).rgb, texture(mask, clamp(mask_uv, vec2(0.0), vec2(1.0))).a * inside);
}
