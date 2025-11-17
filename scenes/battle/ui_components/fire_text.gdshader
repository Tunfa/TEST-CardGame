shader_type canvas_item;

// ================= 火焰外觀參數 =================
uniform float fire_speed     = 3.8;  // 火焰往上流動速度
uniform float distortion_amp = 1.5;  // 🔥 增加扭曲幅度(原1.07)
uniform float flame_height   = 3.4;  // 火焰高度
uniform float glow_intensity = 1.2;  // 🔥 提高整體亮度

// 顏色漸層：底部 → 中段 → 頂端
uniform vec3 base_color = vec3(0.85, 0.30, 0.05); // 深紅橘
uniform vec3 mid_color  = vec3(1.00, 0.60, 0.10); // 橘色
uniform vec3 tip_color  = vec3(1.00, 0.95, 0.60); // 火舌偏白

// ================= 邊緣燃燒設定 =================
uniform float outline_size        = 3.0;  // 🔥 增加外圈厚度(原2.0)
uniform float edge_burn_intensity = 2.5;  // 🔥 增強邊緣燃燒(原1.8)

// ================= 🔥 新增：纏繞控制 =================
uniform float wrap_frequency = 3.0;  // 纏繞頻率(螺旋圈數)
uniform float wrap_amplitude = 0.15; // 纏繞幅度(左右擺動距離)
uniform float turbulence     = 1.5;  // 亂流強度

// ================= 簡易 2D 噪聲 / fBm =================
float hash(vec2 p) {
	p = vec2(
		dot(p, vec2(127.1, 311.7)),
		dot(p, vec2(269.5, 183.3))
	);
	return fract(sin(p.x + p.y) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {  // 🔥 增加迭代次數(原4)
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

// ================= Fragment =================
void fragment() {
	// 原始文字 alpha
	vec4 tex = texture(TEXTURE, UV);
	float base_alpha = tex.a;
	
	// ------------ (1) 擴張 alpha ------------
	vec2 px = TEXTURE_PIXEL_SIZE * outline_size;
	float max_a = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y)) * px;
			max_a = max(max_a, texture(TEXTURE, UV + offset).a);
		}
	}
	float expanded_alpha = max_a;
	
	if (expanded_alpha < 0.01) {
		discard;
	}
	
	float edge = clamp(expanded_alpha - base_alpha, 0.0, 1.0);
	
	// ------------ (2) 🔥 加強火焰纏繞效果 ------------
	float v = 1.0 - UV.y;
	float t = TIME * fire_speed;
	
	// 螺旋纏繞：隨著高度旋轉
	float wrap_angle = v * wrap_frequency * 6.2831 + t;
	float wrap_offset = sin(wrap_angle) * wrap_amplitude;
	
	// 多層噪聲疊加，製造複雜亂流
	vec2 p1 = vec2(UV.x * 4.0 + wrap_offset, v * 6.0 + t);
	vec2 p2 = vec2(UV.x * 6.0 - wrap_offset * 0.5, v * 8.0 + t * 1.3);
	vec2 p3 = vec2(UV.x * 3.0 + wrap_offset * 1.5, v * 5.0 + t * 0.7);
	
	float n1 = fbm(p1);
	float n2 = fbm(p2) * 0.5;
	float n3 = fbm(p3) * 0.3;
	float n = (n1 + n2 + n3) / 1.8;
	
	// 增強扭曲效果
	float distort = (n - 0.5) * 2.0 * distortion_amp * (1.0 + v * turbulence);
	
	// 火焰高度遮罩
	float flame_mask = smoothstep(0.0, 1.0, v * flame_height + distort);
	
	// 🔥 新增：動態脈動效果
	float pulse = 0.9 + 0.1 * sin(TIME * 4.0 + UV.x * 10.0);
	flame_mask *= pulse;
	
	// ------------ (3) 顏色漸層 ------------
	vec3 col = base_color;
	col = mix(col, mid_color, clamp(v * 1.3, 0.0, 1.0));
	col = mix(col, tip_color, clamp(v * 1.8, 0.0, 1.0)); // 🔥 更快變白(原1.6)
	
	// 噪聲控制亮度
	float brightness = 0.5 + 0.5 * n;  // 🔥 更強對比(原0.6+0.4)
	col *= brightness;
	
	// 🔥 增強閃爍效果
	float flicker = 0.8 + 0.2 * sin(TIME * 8.0 + n * 15.0);
	col *= flicker;
	
	// ------------ (4) 邊緣燃燒加強 ------------
	vec3 edge_color = vec3(1.0, 0.97, 0.85);
	float edge_factor = clamp(edge * edge_burn_intensity, 0.0, 1.0);
	
	// 🔥 邊緣加入噪聲，讓燃燒更不規則
	edge_factor *= (0.8 + 0.4 * n);
	col = mix(col, edge_color, edge_factor);
	
	// ------------ (5) 最終輸出 ------------
	float final_alpha = expanded_alpha * flame_mask;
	col *= glow_intensity;
	
	// 🔥 新增：外圈半透明火焰層
	float outer_glow = edge * 0.3 * (1.0 - v);
	final_alpha = clamp(final_alpha + outer_glow, 0.0, 1.0);
	
	COLOR = vec4(col, final_alpha);
}