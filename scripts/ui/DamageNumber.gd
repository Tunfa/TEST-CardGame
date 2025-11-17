# DamageNumber.gd
extends Label

#（可選）光圈節點，如果沒有 Glow 這個子節點，效果會自動跳過
@onready var glow: TextureRect = $Glow
var glow_material: ShaderMaterial

# ==== 特效開關 ====
var enable_bounce := true        # 彈跳放大
var enable_afterimage := true    # 殘影拖尾
var enable_glow := true          # 光圈閃光
var enable_shake := true        # 震動（已關閉，可自行改 true）
# ===================

var float_offset: Vector2 = Vector2(0, -60)
var lifetime: float = 0.6


func _ready() -> void:
	if glow:
		glow.visible = false
		if glow.material is ShaderMaterial:
			glow_material = glow.material
		else:
			glow_material = null


#-----------------------------------------------------------------
#  由外部呼叫： damage_number_instance.start(數值)
#-----------------------------------------------------------------
func start(damage: int) -> void:
	text = str(damage)

	# ----------------------------------------------------
	# 火焰 Shader（掛在 Label 上）動態調整強度
	# ----------------------------------------------------
	if material is ShaderMaterial:
		var sm := material as ShaderMaterial

		# 依照傷害強度調整火焰速度與亮度
		var power = clamp(float(damage) / 3000.0, 0.2, 1.2)

		sm.set_shader_parameter("fire_speed", lerp(1.0, 2.0, power))
		sm.set_shader_parameter("glow_intensity", lerp(0.7, 1.3, power))

	# 額外顏色 Tint（配合 Shader）
	_apply_damage_tint(damage)

	# 主 Tween：位置 + 淡出
	var tw := create_tween()

	# 彈跳效果
	if enable_bounce:
		_play_bounce(tw)

	# 光圈閃光
	if enable_glow:
		_play_glow_flash(damage)

	# 殘影拖尾
	if enable_afterimage:
		_spawn_afterimages()

	#（可選）震動效果
	if enable_shake:
		_play_shake()

	# 主體往上飄
	tw.tween_property(self, "position", position + float_offset, lifetime)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	# 淡出
	tw.parallel().tween_property(self, "modulate:a", 0.0, lifetime)

	await tw.finished
	queue_free()


# ===================== A. 彈跳放大 =====================
func _play_bounce(parent_tween: Tween) -> void:
	pivot_offset = size / 2.0
	scale = Vector2(0.6, 0.6)

	parent_tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.08)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	parent_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)


# ===================== B. 殘影拖尾 =====================
func _spawn_afterimages() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	for i in range(3):
		var ghost := Label.new()
		ghost.text = text
		ghost.global_position = global_position + Vector2(2 * (i + 1), -2 * (i + 1))
		ghost.scale = scale
		ghost.z_index = z_index - 1
		ghost.theme = theme
		ghost.modulate = Color(modulate.r, modulate.g, modulate.b, 0.4)

		root.add_child(ghost)

		var duration := 0.35 + 0.05 * i
		var tw := create_tween()

		tw.tween_property(ghost, "modulate:a", 0.0, duration)
		tw.parallel().tween_property(
			ghost, "global_position",
			ghost.global_position + Vector2(0, -12),
			duration
		)

		tw.finished.connect(func():
			if is_instance_valid(ghost):
				ghost.queue_free())


# ===================== C. 震動（預設關閉） =====================
func _play_shake() -> void:
	var orig := position.x
	var tw := create_tween().set_loops(3)

	tw.tween_property(self, "position:x", orig + 8.0, 0.03)
	tw.tween_property(self, "position:x", orig - 8.0, 0.03)
	tw.tween_property(self, "position:x", orig, 0.03)


# ===================== D. 光圈閃光 =====================
func _play_glow_flash(damage: int) -> void:
	if glow == null:
		return

	# 根據傷害強度調整光圈亮度
	var power = clamp(float(damage) / 2000.0, 0.2, 1.0)
	var base_color := Color(1.0, 0.8, 0.3, 1.0)  # 金色光

	var col = base_color * (0.6 + power * 0.7)

	if glow_material:
		glow_material.set_shader_parameter(
			"glow_color",
			Vector4(col.r, col.g, col.b, col.a)
		)

	glow.global_position = global_position
	glow.scale = Vector2(0.2, 0.2)
	glow.modulate = Color(1, 1, 1, 0.0)
	glow.visible = true

	var tw := create_tween()
	tw.tween_property(glow, "scale", Vector2(1.4, 1.4), 0.3)
	tw.parallel().tween_property(glow, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(glow, "modulate:a", 0.0, 0.45)

	tw.finished.connect(func():
		if is_instance_valid(glow):
			glow.visible = false)


# ===================== 顏色 Tint =====================
func _apply_damage_tint(dmg: int) -> void:
	var tint: Color

	if dmg >= 5000:
		tint = Color(1.0, 0.55, 0.25)   # 大傷→橘紅
	elif dmg >= 1500:
		tint = Color(1.0, 0.75, 0.35)   # 中傷→暖橙
	else:
		tint = Color(1.0, 1.0, 1.0)     # 小傷→白

	modulate = tint
