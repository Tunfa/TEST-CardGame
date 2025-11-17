# BattleCard.gd
extends Control

# ==================== 信号 ====================
signal card_clicked(card: Control)
signal card_dragged_to_enemy(card: Control, enemy: Control)
signal skill_button_pressed(card: Control)

# ==================== 引用 ====================
@onready var name_label = $VBoxContainer/NameLabel
@onready var hp_label = $VBoxContainer/StatsContainer/HPLabel
@onready var atk_label = $VBoxContainer/StatsContainer/ATKLabel
@onready var sp_label = $VBoxContainer/StatsContainer/SPLabel
@onready var skill_cd_label = $VBoxContainer/SkillCDLabel
@onready var card_sprite = $CardSprite
@onready var card_texture = $CardSprite/CardTexture # ✅ 1. 新增這一行
@onready var panel = $Panel

# ==================== 資料 ====================
var card_data: CardData = null
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var can_act: bool = true
var original_position: Vector2 = Vector2.ZERO  # 新增：記錄原始位置
var current_multipliers: Dictionary = {}  # ✅ 保存當前倍率

# ==================== 視覺反饋 ====================
var slash_element_count: int = 0  # 當前斬擊回合累積的消除次數（用於發光效果）
var base_border_color: Color = Color.WHITE  # 基礎邊框顏色
var is_bouncing: bool = false  # 是否正在跳躍動畫中

# ==================== 技能標記 ====================
var skill_marker_label: Label = null  # 技能標記（⚔️）

# ==================== 初始化 ====================

func _ready():
	# 設定拖曳
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 設定外觀（臨時，未來替換成圖片）
	if card_sprite:
		card_sprite.color = Color(0.3, 0.3, 0.8, 1.0)  # 藍色

	# ✅ 創建技能標記 Label（⚔️）
	create_skill_marker()

	# 記錄初始位置
	await get_tree().process_frame
	original_position = global_position

func setup(data: CardData):
	"""設定卡片資料"""
	card_data = data
	update_display()

# ✅ 2. 新增圖片/顏色 fallback 邏輯
	if not card_data:
		return

	# 根據元素設置 Panel 背景顏色
	if panel:
		var style_box = panel.get_theme_stylebox("panel").duplicate()
		if style_box is StyleBoxFlat:
			match card_data.element:
				Constants.Element.FIRE:
					style_box.bg_color = Color(0.4, 0.15, 0.15, 1.0)  # 深紅色背景
					style_box.border_color = Color(1.0, 0.3, 0.2, 1.0)  # 火紅色邊框
				Constants.Element.WATER:
					style_box.bg_color = Color(0.1, 0.2, 0.4, 1.0)  # 深藍色背景
					style_box.border_color = Color(0.2, 0.5, 1.0, 1.0)  # 水藍色邊框
				Constants.Element.WOOD:
					style_box.bg_color = Color(0.1, 0.3, 0.15, 1.0)  # 深綠色背景
					style_box.border_color = Color(0.2, 0.8, 0.3, 1.0)  # 木綠色邊框
				Constants.Element.METAL:
					style_box.bg_color = Color(0.35, 0.35, 0.4, 1.0)  # 深銀色背景
					style_box.border_color = Color(0.9, 0.9, 0.9, 1.0)  # 金銀色邊框
				Constants.Element.EARTH:
					style_box.bg_color = Color(0.3, 0.25, 0.15, 1.0)  # 深土色背景
					style_box.border_color = Color(0.8, 0.6, 0.3, 1.0)  # 土黃色邊框
				_:
					style_box.bg_color = Color(0.2, 0.2, 0.3, 1.0)  # 默認深灰藍色
					style_box.border_color = Color(0.5, 0.5, 0.8, 1.0)
			panel.add_theme_stylebox_override("panel", style_box)

	# 檢查是否有圖片
	var texture = DataManager.get_card_texture(card_data.card_id)

	if texture:
		# 1. 顯示圖片
		card_texture.texture = texture
		card_texture.visible = true
		# 2. 隱藏背景顏色 (設為透明)
		card_sprite.color = Color(0, 0, 0, 0)
	else:
		# 1. 隱藏圖片
		card_texture.texture = null
		card_texture.visible = false
		
		# 2. 顯示背景顏色 (根據元素)
		match card_data.element:
			Constants.Element.METAL:
				card_sprite.color = Color(0.9, 0.9, 0.95)
			Constants.Element.WOOD:
				card_sprite.color = Color(0.3, 0.8, 0.3)
			Constants.Element.WATER:
				card_sprite.color = Color(0.3, 0.5, 0.9)
			Constants.Element.FIRE:
				card_sprite.color = Color(0.9, 0.3, 0.2)
			Constants.Element.EARTH:
				card_sprite.color = Color(0.8, 0.6, 0.3)
			_:
				card_sprite.color = Color(0.6, 0.6, 0.6)

func update_display():
	"""更新顯示"""
	if not card_data:
		return

	name_label.text = card_data.card_name
	hp_label.text = "HP:%d" % card_data.current_hp

	# ✅ 使用當前倍率計算攻擊力顯示
	var multiplier = current_multipliers.get(card_data.element, 1.0)
	var display_atk = int(card_data.current_atk * multiplier)
	atk_label.text = "ATK:%d" % display_atk

	sp_label.text = "SP:%d/%d" % [card_data.current_sp, card_data.max_sp]

	if card_data.active_skill_current_cd > 0:
		skill_cd_label.text = "技能CD:%d" % card_data.active_skill_current_cd
	else:
		skill_cd_label.text = "技能就绪"
		skill_cd_label.modulate = Color.GREEN

	# 根据SP更新颜色
	if card_data.current_sp > 0:
		panel.modulate = Color.WHITE
	else:
		panel.modulate = Color(0.5, 0.5, 0.5)  # SP耗尽时变灰

# ==================== 輸入處理 ====================

func update_atk_display(multipliers: Dictionary):
	"""✅ 根據斬擊倍率更新ATK顯示"""
	if not card_data:
		return

	# 保存倍率
	current_multipliers = multipliers

	# 使用 update_display() 來更新，它會自動使用保存的倍率
	var multiplier = multipliers.get(card_data.element, 1.0)
	var dynamic_atk = int(card_data.current_atk * multiplier)
	atk_label.text = "ATK:%d" % dynamic_atk

func _gui_input(event: InputEvent):
	if not can_act or not card_data:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 開始拖曳
				is_dragging = true
				drag_start_pos = global_position
				original_position = global_position  # 更新原始位置
				z_index = 100  # ✨ 設置高 z_index，確保在最上層
				card_clicked.emit(self)
			else:
				# 結束拖曳
				if is_dragging:
					check_drop_target()
				is_dragging = false
				z_index = 0  # ✨ 恢復正常 z_index
				# 確保返回原位
				reset_position()

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 右鍵使用技能
			if card_data.active_skill:
				skill_button_pressed.emit(self)

func _process(_delta):
	if is_dragging:
		# 跟隨滑鼠
		global_position = get_global_mouse_position() - size / 2

func check_drop_target():
	"""檢查拖放目標"""
	var mouse_pos = get_global_mouse_position()

	# 獲取 BattleScene
	var battle_scene = get_tree().current_scene
	if not battle_scene:
		reset_position()
		return

	# 查找 EnemyContainer
	var enemy_container = battle_scene.get_node_or_null("EnemyArea/EnemyContainer")
	if not enemy_container:
		reset_position()
		return

	# 遍歷所有敵人節點，檢查是否拖到敵人上
	for enemy_node in enemy_container.get_children():
		if enemy_node.has_method("get_enemy_data"):
			# 檢查滑鼠是否在敵人節點的範圍內
			var enemy_rect = Rect2(enemy_node.global_position, enemy_node.size)
			if enemy_rect.has_point(mouse_pos):
				# 找到目標敵人
				var enemy_data = enemy_node.get_enemy_data()
				print("🎯 [BattleCard] 選中敵人: %s (ID: %s, 位置: %v)" % [enemy_data.enemy_name, enemy_data.enemy_id, enemy_node.global_position])
				card_dragged_to_enemy.emit(self, enemy_node)
				reset_position()
				return

	# 沒有找到目標，返回原位
	reset_position()

func reset_position():
	"""重置到原始位置"""
	global_position = original_position

func set_interactable(enabled: bool):
	"""設定是否可互動"""
	can_act = enabled
	# ✅ 移除變暗效果，保持原色（避免斬擊時變暗影響視覺）
	# 注意：can_act 仍然會控制是否能點擊
	modulate = Color.WHITE

func play_attack_animation(target_position: Vector2):
	"""播放攻擊動畫"""
	var start_pos = global_position

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	# 快速衝向目標
	tween.tween_property(self, "global_position", target_position, 0.2)
	# 返回原位
	tween.tween_property(self, "global_position", start_pos, 0.2)

	# 動畫結束後確保位置正確
	await tween.finished
	global_position = original_position

# ==================== 視覺反饋動畫 ====================

func on_element_eliminated(element: Constants.Element):
	"""當消除對應屬性的靈珠時調用"""
	if not card_data or card_data.element != element:
		return

	# 累積消除次數
	slash_element_count += 1

	# 播放跳躍動畫
	play_bounce_animation()

	# 更新發光效果
	update_glow_effect()

func play_bounce_animation():
	"""播放跳躍動畫"""
	if is_bouncing:
		return  # 如果正在跳躍，不重複觸發

	is_bouncing = true
	var original_pos = position
	var bounce_height = -20.0  # 跳起的高度（像素）

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	# 跳起（更快速度）
	tween.tween_property(self, "position:y", original_pos.y + bounce_height, 0.08)
	tween.set_ease(Tween.EASE_IN)
	# 落下（更快速度）
	tween.tween_property(self, "position:y", original_pos.y, 0.08)

	await tween.finished
	is_bouncing = false

func update_glow_effect():
	"""更新邊框流光效果（根據累積次數調整亮度，並保持發光狀態）"""
	if not panel or not card_data:
		return

	var style_box = panel.get_theme_stylebox("panel")
	if not (style_box is StyleBoxFlat):
		return

	# 創建副本以避免影響其他實例
	style_box = style_box.duplicate()

	# 根據元素獲取基礎顏色
	var element_color = get_element_color(card_data.element)

	# 計算發光強度（1-5次，5次最亮）
	var intensity = min(slash_element_count, 5) / 5.0

	# 設置邊框寬度（累積越多邊框越粗）
	var border_width = 2 + int(intensity * 3)  # 2-5 像素
	style_box.border_width_left = border_width
	style_box.border_width_top = border_width
	style_box.border_width_right = border_width
	style_box.border_width_bottom = border_width

	# 最終保持的發光顏色（持續發亮）
	var final_glow_color = element_color.lerp(Color.WHITE, intensity * 0.6)
	var final_shadow_size = int(intensity * 12)

	# ✨ 流光效果：三段式閃爍後保持發亮
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# 獲取當前顏色（如果已經在發光，從當前顏色開始）
	var current_color = style_box.border_color if style_box.border_color != Color.TRANSPARENT else element_color

	# 第一次閃爍：快速變亮
	var bright_color_1 = element_color.lerp(Color.WHITE, intensity * 0.8)
	tween.tween_method(func(color):
		style_box.border_color = color
		style_box.shadow_color = Color(color.r, color.g, color.b, intensity * 0.9)
		style_box.shadow_size = int(intensity * 15)
		panel.add_theme_stylebox_override("panel", style_box)
	, current_color, bright_color_1, 0.1)

	# 第二次閃爍：稍微回落（流光效果）
	var mid_color = element_color.lerp(Color.WHITE, intensity * 0.5)
	tween.tween_method(func(color):
		style_box.border_color = color
		style_box.shadow_color = Color(color.r, color.g, color.b, intensity * 0.8)
		style_box.shadow_size = int(intensity * 10)
		panel.add_theme_stylebox_override("panel", style_box)
	, bright_color_1, mid_color, 0.1)

	# 第三次閃爍：再次達到高光
	var bright_color_2 = element_color.lerp(Color.WHITE, intensity * 0.9)
	tween.tween_method(func(color):
		style_box.border_color = color
		style_box.shadow_color = Color(color.r, color.g, color.b, intensity * 0.95)
		style_box.shadow_size = int(intensity * 18)
		panel.add_theme_stylebox_override("panel", style_box)
	, mid_color, bright_color_2, 0.12)

	# ✨ 最後：保持在發光狀態（不回到原色）
	tween.tween_method(func(color):
		style_box.border_color = color
		style_box.shadow_color = Color(color.r, color.g, color.b, intensity * 0.85)
		style_box.shadow_size = final_shadow_size
		panel.add_theme_stylebox_override("panel", style_box)
	, bright_color_2, final_glow_color, 0.15)

func reset_slash_effects():
	"""重置斬擊相關的視覺效果（每次新斬擊開始時調用）"""
	slash_element_count = 0

	# 重置邊框為基礎樣式
	if panel and card_data:
		var style_box = panel.get_theme_stylebox("panel")
		if style_box is StyleBoxFlat:
			style_box = style_box.duplicate()

			# 恢復基礎邊框
			var element_color = get_element_color(card_data.element)
			style_box.border_color = element_color
			style_box.border_width_left = 2
			style_box.border_width_top = 2
			style_box.border_width_right = 2
			style_box.border_width_bottom = 2
			style_box.shadow_size = 0

			panel.add_theme_stylebox_override("panel", style_box)

func get_element_color(element: Constants.Element) -> Color:
	"""獲取元素對應的顏色"""
	match element:
		Constants.Element.FIRE:
			return Color(1.0, 0.3, 0.2, 1.0)  # 火紅色
		Constants.Element.WATER:
			return Color(0.2, 0.5, 1.0, 1.0)  # 水藍色
		Constants.Element.WOOD:
			return Color(0.2, 0.8, 0.3, 1.0)  # 木綠色
		Constants.Element.METAL:
			return Color(0.9, 0.9, 0.9, 1.0)  # 金銀色
		Constants.Element.EARTH:
			return Color(0.8, 0.6, 0.3, 1.0)  # 土黃色
		Constants.Element.HEART:
			return Color(1.0, 0.5, 0.8, 1.0)  # 心粉色
		_:
			return Color(0.5, 0.5, 0.8, 1.0)  # 默認

# ==================== 技能標記相關 ====================

func create_skill_marker():
	"""創建技能標記 Label（⚔️）"""
	skill_marker_label = Label.new()
	skill_marker_label.text = "⚔️"
	skill_marker_label.add_theme_font_size_override("font_size", 32)
	skill_marker_label.modulate = Color(1.0, 0.8, 0.2, 1.0)  # 金色

	# 設置位置（右上角）
	skill_marker_label.position = Vector2(size.x - 40, 0)
	skill_marker_label.z_index = 10

	# 初始隱藏
	skill_marker_label.visible = false

	add_child(skill_marker_label)

func show_skill_marker():
	"""顯示技能標記（技能生效期間）"""
	if skill_marker_label:
		skill_marker_label.visible = true
		# 添加閃爍動畫
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(skill_marker_label, "modulate:a", 0.5, 0.5)
		tween.tween_property(skill_marker_label, "modulate:a", 1.0, 0.5)

func hide_skill_marker():
	"""隱藏技能標記（技能結束）"""
	if skill_marker_label:
		skill_marker_label.visible = false
		# 停止所有動畫
		var tween = skill_marker_label.get_tree().get_processed_tweens()
		for t in tween:
			if t.is_valid():
				t.kill()
