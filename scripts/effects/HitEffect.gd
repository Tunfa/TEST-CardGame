# HitEffect.gd
# 打擊特效 - 適用於一般攻擊
extends BaseEffect

func _init():
	effect_lifetime = 0.5
	particle_amount = 30

func setup_material():
	var mat = ParticleProcessMaterial.new()
	process_material = mat

	# 發射形狀 - 球形
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 5.0

	# 方向與速度
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 100.0
	mat.initial_velocity_max = 200.0

	# 重力
	mat.gravity = Vector3(0, 300, 0)

	# 顏色漸變 - 白色到橙色到透明
	var gradient_tex = _create_gradient([
		Color(1, 1, 1, 1),      # 白色
		Color(1, 0.5, 0, 0.8),  # 橙色
		Color(1, 0, 0, 0)       # 紅色透明
	], [0.0, 0.5, 1.0])
	mat.color_ramp = gradient_tex

	# 大小變化
	mat.scale_min = 0.5
	mat.scale_max = 1.5

	# 添加一些隨機性
	mat.angular_velocity_min = -360.0
	mat.angular_velocity_max = 360.0
