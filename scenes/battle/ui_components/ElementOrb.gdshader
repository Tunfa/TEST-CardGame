shader_type canvas_item;

void fragment() {
    // COLOR 是來自 ColorRect 的顏色
    // UV 是節點的標準化座標 (左上角是 0,0，右下角是 1,1)

    // 計算目前像素到中心點 (0.5, 0.5) 的距離
    float dist = distance(UV, vec2(0.5));

    // smoothstep(edge0, edge1, x)
    // 當 x (距離) < 0.49 時，回傳 1.0 (完全不透明)
    // 當 x (距離) > 0.50 時，回傳 0.0 (完全透明)
    // 在 0.49 到 0.5 之間平滑過渡，以產生抗鋸齒的圓邊
    float alpha = smoothstep(0.5, 0.49, dist);

    // 將 ColorRect 的原始顏色 (COLOR.rgb)
    // 乘上我們計算出來的透明度 (alpha)
    COLOR = vec4(COLOR.rgb, COLOR.a * alpha);
}