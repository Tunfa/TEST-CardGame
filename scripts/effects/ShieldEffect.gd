# ShieldEffect.gd
# 護盾特效 - 適用於防禦技能
extends BaseEffect

func _init():
	effect_lifetime = 1.2
	particle_amount = 45

func setup_material():
	var mat = ParticleProcessMaterial.new()
	process_material = mat

	# 發射形狀 - 環形（形成護盾形狀）
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.emission_ring_height = 1.0
	mat.emission_ring_radius = 25.0
	mat.emission_ring_inner_radius = 20.0

	# 環繞方向
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0

	# 輕微向上
	mat.gravity = Vector3(0, -50, 0)

	# 顏色漸變 - 藍色護盾效果
	var gradient_tex = _create_gradient([
		Color(0.5, 0.8, 1, 1),  # 淺藍色
		Color(0.2, 0.5, 1, 1),  # 藍色
		Color(0, 0.3, 0.8, 0.6),# 深藍色半透明
		Color(0, 0.2, 0.5, 0)   # 深藍透明
	], [0.0, 0.3, 0.7, 1.0])
	mat.color_ramp = gradient_tex

	# 大小變化
	mat.scale_min = 0.6
	mat.scale_max = 1.4

	# 緩慢旋轉
	mat.angular_velocity_min = -90.0
	mat.angular_velocity_max = 90.0

	# 阻尼 - 讓粒子形成緩慢環繞
	mat.damping_min = 20.0
	mat.damping_max = 40.0

	# 縮放曲線 - 逐漸擴散
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(0.7, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))

	var curve_tex = CurveTexture.new()
	curve_tex.curve = scale_curve
	mat.scale_curve = curve_tex
