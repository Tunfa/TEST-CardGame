# BaseEffect.gd
# 基礎特效類 - 所有粒子特效的父類
class_name BaseEffect
extends GPUParticles2D

# 基本設定
@export var effect_lifetime: float = 1.0
@export var particle_amount: int = 30
@export var auto_free: bool = true

func _ready():
	# 基本粒子設定
	amount = particle_amount
	lifetime = effect_lifetime
	one_shot = true
	explosiveness = 1.0

	# 創建基礎材質
	setup_material()

func setup_material():
	"""由子類覆寫以設定粒子材質"""
	pass

func trigger(pos: Vector2 = Vector2.ZERO):
	"""觸發特效"""
	if pos != Vector2.ZERO:
		global_position = pos

	emitting = true

	if auto_free:
		await get_tree().create_timer(lifetime).timeout
		queue_free()

func _create_gradient(colors: Array, positions: Array = []) -> GradientTexture1D:
	"""創建顏色漸變
	colors: Color 陣列
	positions: 位置陣列 (0.0-1.0)，如果為空則平均分配
	"""
	var gradient = Gradient.new()
	# 1. 在函數的開頭只宣告一次
	var gradient_tex = GradientTexture1D.new()

	# 2. 檢查無效的 colors 陣列
	if colors.is_empty():
		push_warning("Tried to create a gradient with no colors.")
		# 賦予預設的(黑到白)漸變並返回
		gradient_tex.gradient = gradient
		return gradient_tex

	# 3. 準備 positions (offsets) 陣列
	var final_positions = []
	if positions.size() == colors.size():
		final_positions = positions
	else:
		if colors.size() == 1:
			final_positions = [0.0]
		else:
			for i in range(colors.size()):
				var pos = float(i) / (colors.size() - 1)
				final_positions.append(pos)

	# 4. 設定漸變屬性
	gradient.colors = colors
	gradient.offsets = final_positions

	# 5. 賦予最終的漸變並返回
	gradient_tex.gradient = gradient
	return gradient_tex
