shader_type canvas_item;
// Fundo animado do menu principal: chuva de código verde, skyline com
// janelas acesas e piso em grade com perspectiva (estilo "cidade digital").
// Use em um ColorRect que cobre a tela inteira (Material > Shader Material).

uniform vec4 rain_color : source_color = vec4(0.18, 1.0, 0.42, 1.0);
uniform float horizon : hint_range(0.5, 0.95) = 0.77;
uniform float rain_speed = 0.3;
uniform float grid_speed = 0.6;

float h11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Uma camada de chuva: colunas de "glifos" que caem em velocidades diferentes.
float rain_layer(vec2 uv, float aspect, float cols, float seed, float spd) {
	float rows = cols / aspect * 1.7;
	float x = uv.x * cols;
	float c = floor(x);
	float fx = fract(x);
	float y = uv.y * rows;
	float r = floor(y);
	float fy = fract(y);

	float col_seed = h11(c + seed);
	float speed = (0.35 + 0.9 * col_seed) * spd;
	float head = fract(TIME * speed + h11(c * 1.7 + seed));
	float d = fract(head - uv.y); // 0 = cabeça da coluna; cresce para cima
	float trail_len = 0.15 + 0.5 * h11(c * 3.1 + seed);
	float trail = 0.0;
	if (d < trail_len) {
		trail = pow(1.0 - d / trail_len, 1.6);
	}
	float alive = step(0.35, h11(c * 5.3 + seed)); // some colunas vazias

	// Glifo de 3x5 blocos que muda com o tempo.
	vec2 gp = vec2(fx, fy);
	vec2 g = floor(gp * vec2(3.0, 5.0));
	float t = floor(TIME * 3.0 * (0.5 + col_seed) + r * 0.37);
	float on = step(0.42, h21(g + vec2(c * 7.0 + t, r * 3.0 + seed)));
	vec2 f = fract(gp * vec2(3.0, 5.0));
	float cell = step(0.12, f.x) * step(f.x, 0.88) * step(0.12, f.y) * step(f.y, 0.88);
	float margin = step(0.18, fx) * step(fx, 0.82) * step(0.1, fy) * step(fy, 0.9);
	float glyph = on * cell * margin;

	float head_glow = 1.0 - smoothstep(0.0, 0.03, d);
	return alive * glyph * (trail + head_glow * 1.5);
}

// Chuva completa: 3 camadas (longe, meio, perto), mais forte nas laterais
// para deixar o centro (título e botões) legível.
float rain(vec2 uv, float aspect) {
	float edge = abs(uv.x - 0.5) * 2.0;
	float mask = 0.15 + 0.85 * smoothstep(0.15, 0.85, edge);
	float a = rain_layer(uv, aspect, 110.0, 1.0, rain_speed) * 0.55;
	float b = rain_layer(uv, aspect, 48.0, 9.0, rain_speed * 1.3) * 0.9;
	float c = rain_layer(uv, aspect, 22.0, 21.0, rain_speed * 1.7) * 1.1;
	float fade = 1.0 - smoothstep(horizon - 0.12, horizon, uv.y);
	return (a + b + c) * mask * fade;
}

// Camada de prédios. Retorna (corpo do prédio, janela acesa).
vec2 skyline(vec2 uv, float n, float seed, float maxh, float aspect) {
	float x = uv.x * n;
	float b = floor(x);
	float fx = fract(x);
	float edge = abs(uv.x - 0.5) * 2.0;
	float hh = (0.10 + 0.55 * h11(b + seed)) * (0.35 + 0.65 * smoothstep(0.05, 0.85, edge)) * maxh;
	float top = horizon - hh;
	float inside = step(top, uv.y) * step(uv.y, horizon);
	float gap = step(0.08, fx) * step(fx, 0.92);
	float body = inside * gap;

	float wr = n * 4.0 / aspect;
	vec2 wp = vec2(fx * 4.0, (uv.y - top) * wr);
	vec2 cell = floor(wp);
	vec2 f = fract(wp);
	float lit = step(0.82, h21(cell + vec2(b * 13.0, seed)));
	float shape = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.7);
	return vec2(body, body * lit * shape);
}

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x; // largura / altura

	// Grade do piso (calculada fora do if para os derivativos ficarem corretos).
	float p = max(uv.y - horizon, 0.0) / (1.0 - horizon); // 0 = horizonte, 1 = base
	float z = 1.0 / (p + 0.04);
	vec2 gv = vec2((uv.x - 0.5) * aspect * z * 0.35, z + TIME * grid_speed);
	vec2 dl = 0.5 - abs(fract(gv * 0.5) - 0.5);
	vec2 fw = fwidth(gv * 0.5);
	vec2 gl = 1.0 - smoothstep(vec2(0.0), fw * 1.5, dl);

	vec3 col = vec3(0.0);
	if (uv.y < horizon) {
		float sky = uv.y / horizon;
		col = mix(vec3(0.0, 0.015, 0.008), vec3(0.0, 0.11, 0.05), pow(sky, 2.0));

		vec2 s1 = skyline(uv, 28.0, 11.0, 0.55, aspect);
		col = mix(col, vec3(0.0, 0.07, 0.03), s1.x);
		col += rain_color.rgb * s1.y * 0.25;

		vec2 s2 = skyline(uv, 14.0, 37.0, 0.8, aspect);
		col = mix(col, vec3(0.0, 0.02, 0.01), s2.x);
		col += rain_color.rgb * s2.y * 0.55;

		col += rain_color.rgb * rain(uv, aspect);
		col += rain_color.rgb * 0.45 * exp(-(horizon - uv.y) * 35.0);
	} else {
		float fade = smoothstep(0.0, 0.3, p);
		float grid = max(gl.x, gl.y) * fade;
		float nodes = gl.x * gl.y * fade;
		col = vec3(0.0, 0.012, 0.006);
		col += rain_color.rgb * grid * (0.7 - 0.3 * p);
		col += rain_color.rgb * nodes * 0.9;
		col += rain_color.rgb * 0.4 * exp(-p * 10.0);
		// reflexo da chuva no piso
		vec2 uvr = vec2(uv.x, horizon - (uv.y - horizon) * 0.7);
		col += rain_color.rgb * rain(uvr, aspect) * (1.0 - p) * 0.35;
	}

	// Escurece o centro para o título e os botões ficarem legíveis.
	float center = 1.0 - smoothstep(0.0, 0.55, abs(uv.x - 0.5));
	col *= 1.0 - 0.45 * center;

	COLOR = vec4(col, 1.0);
}
