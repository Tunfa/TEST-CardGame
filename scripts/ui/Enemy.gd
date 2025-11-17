# Enemy.gd
# 敵人顯示節點
extends Control

# ==================== 信號 ====================
signal enemy_clicked(enemy: Control)
signal enemy_right_clicked(enemy: Control)  # 右鍵查看技能

# ==================== 引用 ====================
@onready var name_label = $VBoxContainer/NameLabel
@onready var hp_bar = $VBoxContainer/HPBar
@onready var hp_label = $VBoxContainer/HPLabel
@onready var atk_label = $VBoxContainer/ATKLabel
@onready var cd_label = $VBoxContainer/CDLabel
@onready var enemy_sprite = $EnemySprite
@onready var area_2d = $Area2D
@onready var panel = $Panel  # ✅ 添加 Panel 引用

# ==================== 資料 ====================
var enemy_data: EnemyData = null
# ✅ 修正：用變數來儲存 Tween，而不是用 name
var attack_tween: Tween = null
var sprite_tween: Tween = null

# ==================== 條件型技能盾牌 ====================
var shield_label: Label = null  # 盾牌符號 Label
var shield_blink_tween: Tween = null  # 閃爍動畫 

# ==================== 初始化 ====================
func _ready():
	# 創建盾牌符號 Label
	shield_label = Label.new()
	shield_label.text = "🛡️"
	shield_label.add_theme_font_size_override("font_size", 32)
	shield_label.position = Vector2(-21, -15)  # 左上角
	shield_label.z_index = 10  # 確保在最上層
	shield_label.visible = false  # 初始隱藏
	add_child(shield_label)

	# 如果已經有 enemy_data，立即應用顏色
	if enemy_data:
		apply_element_colors()
	else:
		# 默認白色（保持圖片原色）
		if enemy_sprite:
			enemy_sprite.modulate = Color(1, 1, 1, 1)

func setup(data: EnemyData):
	enemy_data = data
	if hp_bar:
		hp_bar.max_value = enemy_data.max_hp

	# 等待節點就緒後設置顏色
	if is_node_ready():
		apply_element_colors()
		print("🎨 設置敵人顏色：%s -> %s" % [enemy_data.enemy_name, Constants.Element.keys()[enemy_data.element]])
	# 如果節點還沒就緒，_ready() 會處理

	update_display()

	# ✅ 初次檢查盾牌（可能技能還沒加載，所以可能不會顯示）
	update_shield_visibility()

func apply_element_colors():
	"""應用元素顏色到 Sprite 和 Panel"""
	if not enemy_data:
		return

	var _element_color = get_element_color(enemy_data.element)

	# 設置 Sprite 顏色
	if enemy_sprite:
		# 載入敵人圖片
		var enemy_texture = DataManager.get_enemy_texture(enemy_data.enemy_id)
		if enemy_texture:
			enemy_sprite.texture = enemy_texture
		# 保持圖片原色（白色 modulate = 不改變顏色）
		enemy_sprite.modulate = Color(1, 1, 1, 1)

	# 設置 Panel 背景顏色（類似 BattleCard）
	if panel:
		var style_box = panel.get_theme_stylebox("panel")
		if style_box:
			style_box = style_box.duplicate()
			if style_box is StyleBoxFlat:
				# 根據元素設置背景和邊框顏色
				match enemy_data.element:
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
						style_box.bg_color = Color(0.3, 0.3, 0.35, 1.0)  # 深灰色背景
						style_box.border_color = Color(0.9, 0.9, 0.9, 1.0)  # 金銀色邊框
					Constants.Element.EARTH:
						style_box.bg_color = Color(0.3, 0.25, 0.15, 1.0)  # 深土黃色背景
						style_box.border_color = Color(0.8, 0.6, 0.3, 1.0)  # 土黃色邊框
					Constants.Element.HEART:
						style_box.bg_color = Color(0.4, 0.2, 0.3, 1.0)  # 深粉色背景
						style_box.border_color = Color(1.0, 0.5, 0.8, 1.0)  # 心粉色邊框
					_:
						style_box.bg_color = Color(0.3, 0.2, 0.2, 1.0)  # 默認深紅色
						style_box.border_color = Color(0.8, 0.3, 0.3, 1.0)  # 默認紅色邊框

				panel.add_theme_stylebox_override("panel", style_box)

func update_display():
	if not enemy_data:
		return
	name_label.text = enemy_data.enemy_name
	hp_label.text = "%d/%d" % [enemy_data.current_hp, enemy_data.max_hp]
	atk_label.text = "ATK:%d" % enemy_data.current_atk
	cd_label.text = "CD:%d" % [enemy_data.current_cd]
	if hp_bar:
		hp_bar.value = enemy_data.current_hp
	if not enemy_data.is_alive:
		modulate = Color(0.3, 0.3, 0.3, 0.5)

func get_enemy_data() -> EnemyData:
	return enemy_data

func get_element_color(element: Constants.Element) -> Color:
	"""根據元素返回對應顏色"""
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
			return Color(0.8, 0.3, 0.3, 1.0)  # 默認紅色

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			enemy_clicked.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			enemy_right_clicked.emit(self)
			
func play_attack_animation():
	"""播放更有力量感的攻擊動畫"""
	if not enemy_data or not enemy_data.is_alive:
		return

	var original_pos = position
	
	# ✅ 修正：停止舊的 Tween 動畫
	if attack_tween and attack_tween.is_valid():
		attack_tween.kill()
	if sprite_tween and sprite_tween.is_valid():
		sprite_tween.kill()

	# ✅ 修正：將 Tween 實例賦值給類別變數
	attack_tween = create_tween()
	attack_tween.set_trans(Tween.TRANS_ELASTIC) 
	attack_tween.set_ease(Tween.EASE_OUT) 

	# 1. 蓄力 (Anticipation)
	attack_tween.tween_property(self, "position", original_pos - Vector2(0, 25), 0.15)
	# 2. 衝刺 (Attack & Overshoot)
	attack_tween.tween_property(self, "position", original_pos + Vector2(0, 100), 0.1)
	# 3. 歸位 (Return)
	attack_tween.tween_property(self, "position", original_pos, 0.4)

	# ✅ 修正：將 Tween 實例賦值給類別變數
	sprite_tween = create_tween()
	sprite_tween.tween_interval(0.15)
	sprite_tween.tween_property(enemy_sprite, "modulate", Color(1.8, 1.8, 1.8), 0.05)
	sprite_tween.tween_property(enemy_sprite, "modulate", Color(1.0, 1.0, 1.0), 0.05)

func shake():
	"""受擊震動效果"""
	var original_pos = position
	var tween = create_tween() # 這個是短暫的，不用存

	for i in range(3):
		tween.tween_property(self, "position", original_pos + Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.05)

	tween.tween_property(self, "position", original_pos, 0.05)

# ==================== 條件型技能盾牌系統 ====================

func update_shield_visibility():
	"""更新盾牌顯示狀態（在技能加載後調用）"""
	if not shield_label or not enemy_data:
		return

	var has_condition = has_condition_skill()

	if has_condition:
		shield_label.visible = true
		shield_label.modulate = Color(1, 1, 1, 1)  # 初始完全不透明（條件未達成）
		print("  🛡️ [%s] 顯示盾牌符號（有條件技能）" % enemy_data.enemy_name)
	else:
		shield_label.visible = false
		print("  ✓ [%s] 無條件技能，盾牌隱藏" % enemy_data.enemy_name)

func has_condition_skill() -> bool:
	"""檢查敵人是否有條件型技能"""
	if not enemy_data:
		return false

	# 調試：列出所有被動技能
	print("  🔍 [%s] 檢查條件技能，passive_skills 數量: %d" % [enemy_data.enemy_name, enemy_data.passive_skills.size()])

	# 檢查被動技能是否有條件型效果
	for skill in enemy_data.passive_skills:
		if not skill:
			continue

		print("    - 技能: %s (類型: %s)" % [skill.skill_name, skill.get_class()])

		# 檢查是否有 is_condition_skill 方法（EnemySkillWrapper 類有這個方法）
		if skill.has_method("is_condition_skill"):
			if skill.is_condition_skill():
				print("      ✅ 這是條件型技能！")
				return true
		# 如果是其他類型的技能，檢查 json_effects
		elif "json_effects" in skill:
			for effect in skill.json_effects:
				var effect_type = effect.get("effect_type", "")
				print("      - 效果類型: %s" % effect_type)
				if effect_type in ["REQUIRE_COMBO", "REQUIRE_ORB_TOTAL", "REQUIRE_ORB_CONTINUOUS", "REQUIRE_ELEMENTS"]:
					print("      ✅ 找到條件型效果！")
					return true

	return false

func update_shield_status(condition_met: bool):
	"""更新盾牌符號狀態
	condition_met: true = 條件已達成（閃爍），false = 條件未達成（正常顯示）
	"""
	if not shield_label or not shield_label.visible:
		return

	if condition_met:
		# 條件達成：開始半透明閃爍
		start_shield_blink()
	else:
		# 條件未達成：停止閃爍，完全不透明
		stop_shield_blink()
		shield_label.modulate = Color(1, 1, 1, 1)

func start_shield_blink():
	"""開始盾牌閃爍動畫（半透明閃爍）"""
	if not shield_label:
		return

	# 停止舊的閃爍動畫
	if shield_blink_tween and shield_blink_tween.is_valid():
		shield_blink_tween.kill()

	# 創建循環閃爍動畫
	shield_blink_tween = create_tween()
	shield_blink_tween.bind_node(self)
	shield_blink_tween.set_trans(Tween.TRANS_SINE)
	shield_blink_tween.set_ease(Tween.EASE_IN_OUT)

	# 從不透明 → 半透明 → 不透明
	shield_blink_tween.tween_property(shield_label, "modulate:a", 0.3, 0.5)
	shield_blink_tween.tween_property(shield_label, "modulate:a", 1.0, 0.5)

func stop_shield_blink():
	"""停止盾牌閃爍動畫"""
	if shield_blink_tween and shield_blink_tween.is_valid():
		shield_blink_tween.kill()
		shield_blink_tween = null
