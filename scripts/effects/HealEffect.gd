# scripts/effects/HealEffect.gd
# 治療特效 (v2 - 神聖爆發版)
extends BaseEffect

func _init():
	# 1. 粒子數加倍 (原 40 -> 80)
	effect_lifetime = 1.0   # 持續 1 秒
	particle_amount = 80

func setup_material():
	var mat = ParticleProcessMaterial.new()
	process_material = mat

	# 2. 發射形狀：使用 "環形" (Ring) 創造一個爆發光環
	# (參考 ShieldEffect.gd)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.emission_ring_height = 1.0
	mat.emission_ring_radius = 20.0
	mat.emission_ring_inner_radius = 15.0

	# 3. 初始速度：向外擴張
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 120.0

	# 4. 動作：負重力 (向上飄) + 軌道旋轉 (Orbit)
	mat.gravity = Vector3(0, -100, 0) # (原 -150)

	# 【關鍵】增加軌道旋轉 (Orbit Velocity)，粒子會一邊上升一邊旋轉
	mat.orbit_velocity_min = -0.5
	mat.orbit_velocity_max = 0.5
	# 增加一些徑向加速度，讓它有 "推" 的感覺
	mat.radial_accel_min = 20.0
	mat.radial_accel_max = 40.0

	# 5. 顏色 (更華麗)：
	#    從 耀眼的白綠色 -> 柔和的綠色 -> 金色殘光 -> 消失
	var colors = [
		Color(0.8, 1.0, 0.8, 1.0),  # 1. 耀眼白綠色
		Color(0.2, 1.0, 0.5, 1.0),  # 2. 柔和綠色
		Color(1.0, 0.9, 0.5, 0.5),  # 3. 金色殘光
		Color(0.5, 1.0, 0.5, 0.0)   # 4. 消失
	]
	var positions = [0.0, 0.2, 0.7, 1.0]
	mat.color_ramp = _create_gradient(colors, positions)

	# 6. 縮放：粒子更大，且有爆發感
	mat.scale_min = 1.0 # (原 0.8)
	mat.scale_max = 2.0 # (原 1.8)
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5)) # 初始
	scale_curve.add_point(Vector2(0.2, 1.2)) # 爆發
	scale_curve.add_point(Vector2(1.0, 0.0)) # 消失
	
	var curve_tex = CurveTexture.new()
	curve_tex.curve = scale_curve
	mat.scale_curve = curve_tex

	# 7. 旋轉：增加粒子自轉
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
