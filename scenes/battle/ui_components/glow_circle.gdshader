shader_type canvas_item;

uniform float radius = 0.45;     // 光圈大小
uniform float soft_edge = 0.25;  // 外圈柔化
uniform vec4 glow_color = vec4(1.0, 1.0, 0.8, 1.0); // 光圈顏色

void fragment() {
    // UV (0.5,0.5) 為中心
    vec2 uv = UV - vec2(0.5, 0.5);
    float dist = length(uv);

    float edge_inner = radius;
    float edge_outer = radius + soft_edge;

    // 0~1 的光圈強度
    float glow = smoothstep(edge_outer, edge_inner, dist);

    COLOR = glow_color * glow;
}
