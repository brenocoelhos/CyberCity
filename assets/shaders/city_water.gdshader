shader_type canvas_item;
// Água em volta da cidade. A "terra" é um retângulo de cantos arredondados
// (um raio por canto) com a borda ondulada; fora dela desenha água escura com
// ondas animadas, espuma e uma linha de neon na margem. Dentro, transparente.
// Usado por scripts/world/CityShape.gd num ColorRect do tamanho do mapa.

uniform vec2 map_size = vec2(1984.0, 864.0);
uniform float inset = 32.0;
// Raios dos cantos: x = sup. esquerdo, y = sup. direito, z = inf. direito, w = inf. esquerdo.
uniform vec4 radii = vec4(176.0, 176.0, 144.0, 144.0);
uniform vec4 water_color : source_color = vec4(0.02, 0.07, 0.16, 1.0);
uniform vec4 neon_color : source_color = vec4(0.3, 0.85, 1.0, 1.0);

float rounded_box(vec2 p, vec2 half_size, vec4 r) {
	float radius = p.x < 0.0 ? (p.y < 0.0 ? r.x : r.w) : (p.y < 0.0 ? r.y : r.z);
	vec2 q = abs(p) - half_size + radius;
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

void fragment() {
	vec2 pos = UV * map_size;
	vec2 center = map_size * 0.5;
	vec2 half_size = center - vec2(inset);
	float d = rounded_box(pos - center, half_size, radii);
	// margem ondulada (não é uma linha reta)
	float wobble = 3.0 * sin(pos.x * 0.045 + pos.y * 0.03) + 2.0 * sin(pos.y * 0.07 - pos.x * 0.02);
	d += wobble;
	if (d < -1.0) {
		COLOR = vec4(0.0);
	} else {
		float t = TIME;
		vec3 col = water_color.rgb;
		// ondas: faixas que andam devagar, mais fortes longe da margem
		float wave = sin(pos.x * 0.08 + pos.y * 0.05 + t * 1.2) * sin(pos.y * 0.11 - t * 0.8);
		col += vec3(0.02, 0.06, 0.1) * smoothstep(0.55, 1.0, wave);
		// reflexo do neon da cidade perto da margem
		col += neon_color.rgb * 0.22 * exp(-d / 14.0);
		// espuma
		float foam = smoothstep(7.0, 2.0, d) * (0.5 + 0.5 * sin(pos.x * 0.3 + pos.y * 0.3 + t * 3.0));
		col = mix(col, vec3(0.7, 0.9, 1.0), foam * 0.35);
		// linha de neon na beira
		float line = 1.0 - smoothstep(0.0, 1.6, abs(d - 1.0));
		col = mix(col, neon_color.rgb, line * 0.9);
		COLOR = vec4(col, smoothstep(-1.0, 0.5, d));
	}
}
