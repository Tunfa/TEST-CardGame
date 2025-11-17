# CriticalHitEffect.gd
# 暴擊特效 - 適用於暴擊攻擊
extends BaseEffect

func _init():
	effect_lifetime = 0.6
	particle_amount = 60

func setup_material():
	var mat = ParticleProcessMaterial.new()
	process_material = mat

	# 發射形狀 - 點發射
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 3.0

	# 爆發式方向
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 200.0
	mat.initial_velocity_max = 400.0

	# 中等重力
	mat.gravity = Vector3(0, 200, 0)

	# 顏色漸變 - 金色暴擊效果
	var gradient_tex = _create_gradient([
		Color(1, 1, 0.8, 1),    # 亮白金色
		Color(1, 0.8, 0, 1),    # 金色
		Color(1, 0.5, 0, 0.8),  # 橙金色
		Color(1, 0, 0, 0)       # 紅色透明
	], [0.0, 0.2, 0.6, 1.0])
	mat.color_ramp = gradient_tex

	# 大小變化 - 暴擊粒子較大
	mat.scale_min = 1.0
	mat.scale_max = 2.0

	# 快速旋轉
	mat.angular_velocity_min = -1080.0
	mat.angular_velocity_max = 1080.0

	# 添加閃爍效果（通過縮放曲線）
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.5))
	scale_curve.add_point(Vector2(0.1, 0.8))
	scale_curve.add_point(Vector2(0.3, 1.2))
	scale_curve.add_point(Vector2(0.5, 0.6))
	scale_curve.add_point(Vector2(1.0, 0.0))

	var curve_tex = CurveTexture.new()
	curve_tex.curve = scale_curve
	mat.scale_curve = curve_tex
