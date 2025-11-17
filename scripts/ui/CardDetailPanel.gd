# CardDetailPanel.gd
extends Control

# ==================== 信號 ====================
signal panel_closed()

# ==================== 引用 ====================
@onready var background = $Background
@onready var panel = $Panel

@onready var card_name_label = $Panel/MarginContainer/VBoxContainer/HeaderContainer/CardName
@onready var element_label = $Panel/MarginContainer/VBoxContainer/HeaderContainer/ElementLabel
@onready var close_button = $Panel/MarginContainer/VBoxContainer/HeaderContainer/CloseButton

@onready var card_sprite = $Panel/MarginContainer/VBoxContainer/CardSprite
@onready var card_texture = $Panel/MarginContainer/VBoxContainer/CardSprite/CardTexture

# 属性区 - 两行布局
@onready var hp_label = $Panel/MarginContainer/VBoxContainer/StatsContainer/TopRow/HPLabel
@onready var recovery_label = $Panel/MarginContainer/VBoxContainer/StatsContainer/TopRow/RecoveryLabel
@onready var atk_label = $Panel/MarginContainer/VBoxContainer/StatsContainer/BottomRow/ATKLabel
@onready var race_label = $Panel/MarginContainer/VBoxContainer/StatsContainer/BottomRow/RaceLabel

# 主动技能区
@onready var active_skill_container = $Panel/MarginContainer/VBoxContainer/ActiveSkillContainer
@onready var active_skill_header = $Panel/MarginContainer/VBoxContainer/ActiveSkillContainer/HeaderContainer
@onready var active_skill_name = $Panel/MarginContainer/VBoxContainer/ActiveSkillContainer/HeaderContainer/SkillName
@onready var active_skill_cd = $Panel/MarginContainer/VBoxContainer/ActiveSkillContainer/HeaderContainer/CDLabel
@onready var active_skill_desc = $Panel/MarginContainer/VBoxContainer/ActiveSkillContainer/DescScrollContainer/DescContainer/DescLabel

# 队长技能区
@onready var leader_skill_container = $Panel/MarginContainer/VBoxContainer/LeaderSkillContainer
@onready var leader_skill_desc = $Panel/MarginContainer/VBoxContainer/LeaderSkillContainer/DescScrollContainer/DescContainer/DescLabel

# Tween 追蹤
var active_tween: Tween = null

var ELEMENT_NAMES = {
	Constants.Element.METAL: "金",
	Constants.Element.WOOD: "木",
	Constants.Element.WATER: "水",
	Constants.Element.FIRE: "火",
	Constants.Element.EARTH: "土",
	Constants.Element.HEART: "心"
}

var ELEMENT_COLORS = {
	Constants.Element.METAL: Color("FFD700"), # 金色
	Constants.Element.WOOD: Color("33CC33"),   # 綠色
	Constants.Element.WATER: Color("3388FF"),  # 藍色
	Constants.Element.FIRE: Color("FF3333"),   # 紅色
	Constants.Element.EARTH: Color("CC9933"),  # 土黃色
	Constants.Element.HEART: Color("FF66CC")   # 亮粉紅
}

var RACE_NAMES = {
	Constants.CardRace.HUMAN: "人類",
	Constants.CardRace.ELF: "精靈",
	Constants.CardRace.DWARF: "神族",
	Constants.CardRace.ORC: "獸類",
	Constants.CardRace.DEMON: "魔族",
	Constants.CardRace.UNDEAD: "保留",
	Constants.CardRace.DRAGON: "龍族",
	Constants.CardRace.ELEMENTAL: "保留"
}

# ==================== 初始化 ====================

func _ready():
	hide()
	close_button.pressed.connect(_on_close_pressed)

	# ✅ 添加點擊背景關閉功能
	background.gui_input.connect(_on_background_clicked)

	# ✅ 確保背景阻止鼠標事件穿透
	background.mouse_filter = Control.MOUSE_FILTER_STOP

	# ✅ 設置為全局 z_index（不受父節點影響）
	z_as_relative = false

func _exit_tree():
	"""節點離開場景樹時清理 Tween"""
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		active_tween = null

# ==================== 顯示卡片詳情 ====================

func show_card_details_with_instance(instance_id: String, spawn_position: Vector2 = Vector2.ZERO):
	"""顯示卡片詳情（使用實例ID，包含等級資訊）"""
	var card_instance = PlayerDataManager.get_card_instance(instance_id)

	if not card_instance:
		push_error("無法找到卡片實例: " + instance_id)
		return

	# 更新卡片名稱（加上等級）
	card_name_label.text = "Lv. %d %s" % [card_instance.current_level, card_instance.card_name]

	# 顯示剩餘資訊
	_show_card_details_internal(card_instance, spawn_position)

func show_card_details(card_id: String, spawn_position: Vector2 = Vector2.ZERO):
	"""顯示卡片詳情（使用模板ID，默認顯示滿等級狀態）"""
	var card = DataManager.get_card(card_id)

	if not card:
		push_error("無法找到卡牌: " + card_id)
		return

	# ✅ 創建一個副本並設置為滿等級
	var card_copy = card.duplicate()
	card_copy.current_level = card_copy.max_level

	# 更新卡片名稱（顯示滿等級）
	card_name_label.text = "Lv.%d %s" % [card_copy.max_level, card_copy.card_name]

	# 顯示剩餘資訊
	_show_card_details_internal(card_copy, spawn_position)

func _show_card_details_internal(card: CardData, spawn_position: Vector2):
	"""內部函數：顯示卡片詳情的共用邏輯"""

	# 更新元素標籤
	var element_name = ELEMENT_NAMES.get(card.element, "??")
	var text_color = ELEMENT_COLORS.get(card.element, Color.WHITE)
	element_label.text = "[%s]" % element_name
	element_label.add_theme_color_override("font_color", text_color)

	# 更新卡片圖片
	var texture = DataManager.get_card_texture(card.card_id)
	if texture and card_texture:
		card_texture.texture = texture
		card_texture.visible = true
		card_sprite.color = Color(0, 0, 0, 0)
	else:
		if card_texture:
			card_texture.texture = null
			card_texture.visible = false
		var element_color = ELEMENT_COLORS.get(card.element, Color.GRAY)
		card_sprite.color = element_color

	# 更新屬性（根據等級計算）
	var level_stats = card.calculate_level_stats()
	hp_label.text = "HP:%d" % level_stats.hp
	atk_label.text = "ATK:%d" % level_stats.atk
	recovery_label.text = "RCV:%d" % level_stats.recovery

	# 顯示種族
	var race_name = RACE_NAMES.get(card.card_race, "未知")
	race_label.text = "[%s]" % race_name

	# 顯示主動技能
	if card.active_skill_id and not card.active_skill_id.is_empty():
		var skill = SkillRegistry.get_skill_info(card.active_skill_id)
		if skill and not skill.is_empty():
			active_skill_container.visible = true
			active_skill_name.text = "─── %s ───" % skill.skill_name
			active_skill_cd.text = "CD:%d" % card.get_active_skill_max_cd()
			active_skill_desc.text = skill.skill_description
		else:
			active_skill_container.visible = false
	else:
		active_skill_container.visible = false

	# 顯示隊長技能
	if card.leader_skill_ids and card.leader_skill_ids.size() > 0:
		leader_skill_container.visible = true

		# 組合所有隊長技能的描述
		var leader_desc_text = ""
		for skill_id in card.leader_skill_ids:
			var skill = SkillRegistry.get_skill_info(skill_id)
			if skill and not skill.is_empty():
				if not leader_desc_text.is_empty():
					leader_desc_text += "\n\n"
				leader_desc_text += "• " + skill.skill_description

		leader_skill_desc.text = leader_desc_text
	else:
		leader_skill_container.visible = false

	# 設定彈出位置
	position_panel_near_slot(spawn_position)

	# 顯示面板（帶動畫）
	show()
	play_show_animation()

func position_panel_near_slot(_slot_pos: Vector2):
	"""將面板定位在卡片槽附近，並確保不超出螢幕範圍"""
	# ✅ 限制 panel 大小不超過 1920x1080
	var max_width = 1920
	var max_height = 1080

	# 獲取當前視窗大小
	var viewport_size = get_viewport().get_visible_rect().size
	max_width = min(max_width, viewport_size.x - 40)  # 留 20px 邊距
	max_height = min(max_height, viewport_size.y - 40)

	# 設置 panel 的最大尺寸
	if panel.size.x > max_width:
		panel.custom_minimum_size.x = max_width
		panel.size.x = max_width

	if panel.size.y > max_height:
		panel.custom_minimum_size.y = max_height
		panel.size.y = max_height

	# ✅ 確保 panel 居中（只使用 anchor 系統，不手動設置 position）
	panel.set_anchors_preset(Control.PRESET_CENTER)

	# ✅ 確保整個 CardDetailPanel (self) 填滿整個視窗
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = viewport_size

# ==================== 關閉面板 ====================

func _on_background_clicked(event: InputEvent):
	"""點擊背景關閉面板"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 檢查是否點擊到背景（而非 panel）
		var mouse_pos = event.position
		var panel_rect = panel.get_global_rect()
		if not panel_rect.has_point(mouse_pos):
			hide_panel()

func _on_close_pressed():
	"""關閉按鈕"""
	hide_panel()

func hide_panel():
	"""隱藏面板"""
	play_hide_animation()
	await get_tree().create_timer(0.2).timeout
	hide()
	panel_closed.emit()

# ==================== 動畫 ====================

func play_show_animation():
	"""顯示動畫"""
	# 停止之前的動畫
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	panel.modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	background.modulate.a = 0

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.set_trans(Tween.TRANS_BACK)
	active_tween.set_ease(Tween.EASE_OUT)

	active_tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	active_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3)
	active_tween.tween_property(background, "modulate:a", 1.0, 0.3)

	# 動畫完成後清理引用
	active_tween.finished.connect(func(): active_tween = null)

func play_hide_animation():
	"""隱藏動畫"""
	# 停止之前的動畫
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.set_trans(Tween.TRANS_CUBIC)
	active_tween.set_ease(Tween.EASE_IN)

	active_tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	active_tween.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.2)
	active_tween.tween_property(background, "modulate:a", 0.0, 0.2)

	# 動畫完成後清理引用
	active_tween.finished.connect(func(): active_tween = null)

# ==================== 輸入處理 ====================

func _input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):  # ESC 鍵
		_on_close_pressed()
		get_viewport().set_input_as_handled()
