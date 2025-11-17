# ExplosionEffect.gd
# 爆炸特效 - 適用於範圍技能或爆炸效果
extends BaseEffect

func _init():
	effect_lifetime = 0.8
	particle_amount = 50

func setup_material():
	var mat = ParticleProcessMaterial.new()
	process_material = mat

	# 發射形狀 - 環形
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.emission_ring_height = 1.0
	mat.emission_ring_radius = 10.0
	mat.emission_ring_inner_radius = 5.0

	# 徑向方向
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 150.0
	mat.initial_velocity_max = 300.0

	# 重力較小
	mat.gravity = Vector3(0, 100, 0)

	# 顏色漸變 - 黃色到紅色到黑色透明
	var gradient_tex = _create_gradient([
		Color(1, 1, 0.5, 1),    # 亮黃色
		Color(1, 0.3, 0, 1),    # 橙紅色
		Color(0.5, 0, 0, 0.5),  # 深紅色半透明
		Color(0.1, 0, 0, 0)     # 黑色透明
	], [0.0, 0.3, 0.7, 1.0])
	mat.color_ramp = gradient_tex

	# 大小變化 - 爆炸粒子較大
	mat.scale_min = 1.0
	mat.scale_max = 2.5

	# 縮放曲線 - 先變大再縮小
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.2, 1.5))
	scale_curve.add_point(Vector2(1.0, 0.0))

	var curve_tex = CurveTexture.new()
	curve_tex.curve = scale_curve
	mat.scale_curve = curve_tex

	# 旋轉
	mat.angular_velocity_min = -720.0
	mat.angular_velocity_max = 720.0
