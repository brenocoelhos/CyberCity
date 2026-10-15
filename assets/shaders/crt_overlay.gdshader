shader_type canvas_item;
// Efeito de monitor antigo por cima do terminal: linhas de varredura,
// uma faixa clara que desce devagar, leve cintilação e bordas escuras.
// Fica num ColorRect transparente que não bloqueia o mouse.

uniform float scanline_count = 220.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.16;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float flicker_strength : hint_range(0.0, 0.2) = 0.025;
uniform vec4 glow_color : source_color = vec4(0.2, 1.0, 0.4, 1.0);

void fragment() {
	float scan = 0.5 + 0.5 * sin(UV.y * scanline_count * 3.14159);
	float dark = scan * scanline_strength;

	vec2 centered = UV - vec2(0.5);
	float vignette = smoothstep(0.35, 0.75, length(centered * vec2(1.0, 1.25))) * vignette_strength;

	float flicker = flicker_strength * (0.5 + 0.5 * sin(TIME * 55.0));

	// Faixa clara que percorre a tela de cima para baixo a cada 6 s.
	float band_pos = fract(TIME / 6.0);
	float band = smoothstep(0.06, 0.0, abs(UV.y - band_pos)) * 0.05;

	float alpha = clamp(dark + vignette + flicker, 0.0, 1.0);
	// Preto (escurece) + um pouco de verde (brilho da faixa).
	vec3 rgb = glow_color.rgb * band / max(alpha + band, 0.0001);
	COLOR = vec4(rgb, alpha + band);
}
