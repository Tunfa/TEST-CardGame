# VFXManager.gd
# 視覺特效管理器 - 統一管理遊戲中的所有粒子特效
# 使用方式類似 AudioManager
extends Node

# ==================== 特效庫 ====================
# 預載所有特效腳本
var vfx_library = {
	"hit": preload("res://scripts/effects/HitEffect.gd"),
	"explosion": preload("res://scripts/effects/ExplosionEffect.gd"),
	"heal": preload("res://scripts/effects/HealEffect.gd"),
	"critical": preload("res://scripts/effects/CriticalHitEffect.gd"),
	"shield": preload("res://scripts/effects/ShieldEffect.gd"),
	"slash": preload("res://scripts/effects/SlashEffect.gd")
}

# ==================== 節點池 ====================
# 存儲當前活躍的特效節點
var active_effects: Array = []
# 節點池大小限制（避免同時播放過多特效）
var max_active_effects: int = 20

# ==================== 主場景引用 ====================
# 用於將特效添加到場景樹
var current_scene: Node = null

func _ready():
	print("[VFXManager] 視覺特效管理器已初始化")
	print("[VFXManager] 可用特效: ", vfx_library.keys())

# ==================== 核心 API ====================

func play_effect(effect_name: String, position: Vector2 = Vector2.ZERO, parent: Node = null) -> GPUParticles2D:
	"""
	播放指定的視覺特效

	參數:
		effect_name: 特效名稱（"hit", "explosion", "heal", "critical", "shield"）
		position: 特效播放位置（世界座標）
		parent: 父節點（如果不指定，將使用當前場景或 VFXManager）

	返回:
		GPUParticles2D: 創建的特效節點（可用於進一步自定義）

	使用範例:
		VFXManager.play_effect("hit", enemy.global_position)
		VFXManager.play_effect("explosion", Vector2(100, 100), battle_scene)
	"""

	# 檢查特效是否存在
	if not vfx_library.has(effect_name):
		push_error("[VFXManager] 找不到特效: " + effect_name)
		return null

	# 清理已經完成的特效（避免節點池過大）
	_cleanup_finished_effects()

	# 如果達到上限，移除最舊的特效
	if active_effects.size() >= max_active_effects:
		var oldest = active_effects.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# 創建新特效實例
	var effect_script = vfx_library[effect_name]
	var effect = GPUParticles2D.new()
	effect.set_script(effect_script)

	# 決定父節點
	var target_parent = parent if parent != null else _get_current_parent()
	target_parent.add_child(effect)

	# 設定位置並觸發
	effect.global_position = position
	effect.trigger(position)

	# 添加到活躍列表
	active_effects.append(effect)

	return effect

func play_effect_at_node(effect_name: String, target_node: Node2D) -> GPUParticles2D:
	"""
	在指定節點的位置播放特效

	參數:
		effect_name: 特效名稱
		target_node: 目標節點（使用其 global_position）

	使用範例:
		VFXManager.play_effect_at_node("heal", player_card)
		VFXManager.play_effect_at_node("critical", enemy)
	"""
	if not is_instance_valid(target_node):
		push_error("[VFXManager] 目標節點無效")
		return null

	return play_effect(effect_name, target_node.global_position, target_node.get_parent())

func play_multiple_effects(effect_name: String, positions: Array) -> Array:
	"""
	在多個位置同時播放相同特效

	參數:
		effect_name: 特效名稱
		positions: 位置陣列 Array[Vector2]

	返回:
		Array[GPUParticles2D]: 創建的所有特效節點

	使用範例:
		var enemy_positions = [enemy1.position, enemy2.position, enemy3.position]
		VFXManager.play_multiple_effects("explosion", enemy_positions)
	"""
	var effects = []
	for pos in positions:
		var effect = play_effect(effect_name, pos)
		if effect:
			effects.append(effect)
	return effects

# ==================== 進階 API ====================

func create_custom_effect(effect_name: String) -> GPUParticles2D:
	"""
	創建自定義特效（不自動播放）
	可用於需要手動控制的特效

	使用範例:
		var my_effect = VFXManager.create_custom_effect("shield")
		my_effect.scale = Vector2(2, 2)  # 自定義縮放
		get_parent().add_child(my_effect)
		my_effect.trigger(position)
	"""
	if not vfx_library.has(effect_name):
		push_error("[VFXManager] 找不到特效: " + effect_name)
		return null

	var effect_script = vfx_library[effect_name]
	var effect = GPUParticles2D.new()
	effect.set_script(effect_script)
	return effect

func clear_all_effects():
	"""清除所有活躍的特效"""
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	active_effects.clear()

func get_active_effect_count() -> int:
	"""獲取當前活躍的特效數量"""
	_cleanup_finished_effects()
	return active_effects.size()

# ==================== 內部方法 ====================

func _cleanup_finished_effects():
	"""清理已經完成的特效"""
	var valid_effects = []
	for effect in active_effects:
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			valid_effects.append(effect)
	active_effects = valid_effects

func _get_current_parent() -> Node:
	"""獲取當前場景作為父節點"""
	if current_scene and is_instance_valid(current_scene):
		return current_scene

	# 嘗試獲取當前場景
	var root = get_tree().root
	if root.get_child_count() > 0:
		current_scene = root.get_child(root.get_child_count() - 1)
		return current_scene

	# 如果都失敗，使用 VFXManager 本身
	return self

func set_current_scene(scene: Node):
	"""手動設定當前場景（可選）"""
	current_scene = scene

# ==================== 便捷方法 ====================

# 快捷方法 - 可以直接調用
func hit(pos: Vector2) -> GPUParticles2D:
	return play_effect("hit", pos)

func explosion(pos: Vector2) -> GPUParticles2D:
	return play_effect("explosion", pos)

func heal(pos: Vector2) -> GPUParticles2D:
	return play_effect("heal", pos)

func critical(pos: Vector2) -> GPUParticles2D:
	return play_effect("critical", pos)

func shield(pos: Vector2) -> GPUParticles2D:
	return play_effect("shield", pos)
