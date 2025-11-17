# scripts/effects/SlashEffect.gd
# "斬擊" 特效 (v3 - 能量弧線版)
extends BaseEffect

func _init():
	# 1. 粒子數 100 (保持平衡)
	particle_amount = 100
	# 2. 生命週期縮短 (0.6s -> 0.45s)，讓爆發更"乾脆"
	effect_lifetime = 0.45

func setup_material():
	var mat = ParticleProcessMaterial.new()
	process_material = mat

	# 3. 【關鍵】發射形狀：更長、更細的 "刀光"
	#    (這能定義斬擊的初始形狀)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(80, 1, 1) # 160px 寬, 2px 高

	# 4. 【關鍵】方向與加速度：使用 "徑向加速度" 創造衝擊波
	#    (這解決了 "噴射感" 的問題)
	mat.direction = Vector3(0, 0, 0) # 讓粒子從中心點開始計算
	mat.spread = 180.0
	
	mat.initial_velocity_min = 100.0 # 給一個很小的初始速度
	mat.initial_velocity_max = 150.0
	
	# "徑向加速度" (Radial Accel) 會讓粒子從中心點向外猛衝
	mat.radial_accel_min = 300.0
	mat.radial_accel_max = 400.0

	# 5. 【關鍵】取消重力，改用 "阻尼" (Damping)
	#    這會讓粒子爆開後 "急煞"，更有打擊感
	mat.gravity = Vector3(0, 0, 0) # 關閉重力
	mat.damping_min = 30.0
	mat.damping_max = 50.0

	# 6. 顏色：保持高亮度的顏色
	var colors = [
		Color(1, 1, 1, 1),      # 白色
		Color(1, 0.5, 0, 0.8),  # 橙色
		Color(1, 0, 0, 0)       # 紅色透明
	]
	var positions = [0.0, 0.35, 1.0] # 亮部持久
	mat.color_ramp = _create_gradient(colors, positions)

	# 7. 【關鍵】粒子變大 (解決 "太小" 的問題)
	mat.scale_min = 1.2 # (原為 0.8)
	mat.scale_max = 2.0 # (原為 1.8)
	
	# 8. 縮放曲線：保持 "刀光->尾跡" 的邏輯
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.2)) # 初始 (小)
	scale_curve.add_point(Vector2(0.15, 1.0))# 快速變大 (刀光)
	scale_curve.add_point(Vector2(1.0, 0.0)) # 線性縮小 (尾跡)
	
	var curve_tex = CurveTexture.new()
	curve_tex.curve = scale_curve
	mat.scale_curve = curve_tex

	# 9. 旋轉：保持不變
	mat.angular_velocity_min = -360.0
	mat.angular_velocity_max = 360.0
