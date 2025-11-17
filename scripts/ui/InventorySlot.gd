# InventorySlot.gd
# 背包格子 - 顯示單張卡片
extends PanelContainer

# ==================== 信號 ====================
signal slot_clicked(card_id: String, slot_position: Vector2)  # ✅ 增加位置參數
signal slot_right_clicked(card_id: String, slot_position: Vector2)  # 右鍵點擊信號

# ==================== 引用 ====================
@onready var card_sprite = $MarginContainer/VBoxContainer/CardTextureContainer/CardSprite
@onready var card_texture = $MarginContainer/VBoxContainer/CardTextureContainer/CardTexture
@onready var level_label = $MarginContainer/VBoxContainer/CardTextureContainer/LevelLabel
@onready var exp_bar = $MarginContainer/VBoxContainer/ExpBar

# 基礎信息（通過函數獲取，支持多路徑回退）
var name_label: Label = null
var race_label: Label = null
var element_label: Label = null

# 主動技能相關（可選節點）
var active_skill_separator: PanelContainer = null
var active_skill_name: Label = null
var active_skill_cd: Label = null
var active_skill_desc: Label = null

# 隊長技能相關（可選節點）
var leader_skill_separator: PanelContainer = null
var leader_skill_name: Label = null
var leader_skill_desc: Label = null

# ==================== 資料 ====================
var instance_id: String = ""  # ✅ 卡片實例ID（唯一）
var card_id: String = ""  # 卡片模板ID（用於顯示數據）
var is_empty: bool = true
var is_overflow_slot: bool = false  # ✅ 是否是超出上限的臨時格子
var is_selected_for_deletion: bool = false  # ✅ 是否被選中待刪除
var active_tween: Tween = null  # 當前運行的動畫 Tween
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
	Constants.CardRace.DWARF: "矮人",
	Constants.CardRace.ORC: "獸人",
	Constants.CardRace.DEMON: "惡魔",
	Constants.CardRace.UNDEAD: "不死",
	Constants.CardRace.DRAGON: "龍族",
	Constants.CardRace.ELEMENTAL: "元素"
}
# ==================== 初始化 ====================

func _ready():
	# 初始化節點引用（支持多路徑回退）
	_init_node_references()

	# 設定初始外觀
	if is_empty:
		show_empty()

func _exit_tree():
	"""節點離開場景樹時清理 Tween"""
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		active_tween = null

func _init_node_references():
	"""初始化節點引用，支持舊版和新版布局"""
	# name_label - 嘗試新版路徑，失敗則嘗試舊版路徑
	name_label = get_node_or_null("MarginContainer/VBoxContainer/TopInfo/NameLabel")
	if not name_label:
		name_label = get_node_or_null("MarginContainer/VBoxContainer/NameLabel")

	# element_label - 嘗試新版路徑，失敗則嘗試舊版路徑
	element_label = get_node_or_null("MarginContainer/VBoxContainer/TopInfo/ElementLabel")
	if not element_label:
		element_label = get_node_or_null("MarginContainer/VBoxContainer/ElementLabel")

	# race_label - 僅新版布局有此節點
	race_label = get_node_or_null("MarginContainer/VBoxContainer/TopInfo/RaceLabel")

	# 主動技能相關節點
	active_skill_separator = get_node_or_null("MarginContainer/VBoxContainer/ActiveSkillSeparator")
	active_skill_name = get_node_or_null("MarginContainer/VBoxContainer/ActiveSkillSeparator/ActiveSkillName")
	active_skill_cd = get_node_or_null("MarginContainer/VBoxContainer/ActiveSkillSeparator/ActiveSkillCD")
	active_skill_desc = get_node_or_null("MarginContainer/VBoxContainer/ActiveSkillDesc")

	# 隊長技能相關節點
	leader_skill_separator = get_node_or_null("MarginContainer/VBoxContainer/LeaderSkillSeparator")
	leader_skill_name = get_node_or_null("MarginContainer/VBoxContainer/LeaderSkillSeparator/LeaderSkillName")
	leader_skill_desc = get_node_or_null("MarginContainer/VBoxContainer/LeaderSkillDesc")

func setup(p_instance_id: String):
	"""設定卡片資料（接收 instance_id）"""
	instance_id = p_instance_id
	is_empty = false

	# ✅ 通過 instance_id 獲取 card_id
	card_id = PlayerDataManager.get_card_id_from_instance(instance_id)

	if card_id.is_empty():
		print("❌ 無效的實例ID: " + instance_id)
		show_empty()
		return

	load_card_data()

func setup_with_card_id(p_card_id: String):
	"""直接使用 card_id 設定卡片資料（用於選擇器，不需要實例ID）"""
	card_id = p_card_id
	instance_id = ""  # 沒有實例ID
	is_empty = false

	if card_id.is_empty():
		show_empty()
		return

	load_card_data_from_template()

func load_card_data():
	"""載入卡片資料"""
	# ✅ 獲取卡片實例（包含等級資訊）
	var card_instance = PlayerDataManager.get_card_instance(instance_id)
	if not card_instance:
		show_empty()
		return

	var card = card_instance  # card_instance 已經是 CardData 對象

	# 顯示卡片名稱
	if name_label:
		name_label.text = card.card_name

	# 顯示種族（如果節點存在）
	if race_label:
		var race_name = RACE_NAMES.get(card.card_race, "未知")
		race_label.text = "[%s]" % race_name

	# 顯示元素
	if element_label:
		var element_name = ELEMENT_NAMES.get(card.element, "??")
		var text_color = ELEMENT_COLORS.get(card.element, Color.WHITE)
		element_label.text = "[%s]" % element_name
		element_label.add_theme_color_override("font_color", text_color)

	# 顯示卡圖
	var texture = DataManager.get_card_texture(card_id)
	if texture:
		card_texture.texture = texture
		card_texture.visible = true
		card_sprite.color = Color(0, 0, 0, 0)
	else:
		card_texture.texture = null
		card_texture.visible = false
		var element_color = ELEMENT_COLORS.get(card.element, Color.GRAY)
		card_sprite.visible = true
		card_sprite.color = element_color

	# ✅ 顯示等級（在卡圖下方的黑底布條）
	if level_label:
		level_label.text = "Lv. %d" % card.current_level

	# ✅ 顯示等級進度條（當前等級/滿等級）
	if exp_bar:
		# 計算等級百分比（35級/100滿級 = 35%）
		var level_progress = (float(card.current_level) / card.max_level) * 100.0
		exp_bar.value = level_progress

	# 顯示主動技能
	if card.active_skill_id and not card.active_skill_id.is_empty():
		var skill = SkillRegistry.get_skill_info(card.active_skill_id)
		if skill and not skill.is_empty():
			if active_skill_separator:
				active_skill_separator.visible = true
			if active_skill_name:
				active_skill_name.text = skill.skill_name
			if active_skill_cd:
				active_skill_cd.text = "CD:%d" % card.active_skill_cd
			if active_skill_desc:
				active_skill_desc.visible = true
				active_skill_desc.text = skill.skill_description
		else:
			if active_skill_separator:
				active_skill_separator.visible = false
			if active_skill_desc:
				active_skill_desc.visible = false
	else:
		if active_skill_separator:
			active_skill_separator.visible = false
		if active_skill_desc:
			active_skill_desc.visible = false

	# 顯示隊長技能
	if card.leader_skill_ids and card.leader_skill_ids.size() > 0:
		if leader_skill_separator:
			leader_skill_separator.visible = true
		if leader_skill_desc:
			leader_skill_desc.visible = true

		# 組合所有隊長技能的描述
		var leader_desc_text = ""
		for skill_id in card.leader_skill_ids:
			var skill = SkillRegistry.get_skill_info(skill_id)
			if skill and not skill.is_empty():
				if not leader_desc_text.is_empty():
					leader_desc_text += "\n"
				leader_desc_text += "• " + skill.skill_description

		if leader_skill_desc:
			leader_skill_desc.text = leader_desc_text
	else:
		if leader_skill_separator:
			leader_skill_separator.visible = false
		if leader_skill_desc:
			leader_skill_desc.visible = false

func load_card_data_from_template():
	"""從卡片模板載入資料（用於選擇器，不需要實例）"""
	# 獲取卡片模板數據
	var card = DataManager.get_card(card_id)
	if not card:
		show_empty()
		return

	# 顯示卡片名稱
	if name_label:
		name_label.text = card.card_name

	# 顯示種族（如果節點存在）
	if race_label:
		var race_name = RACE_NAMES.get(card.card_race, "未知")
		race_label.text = "[%s]" % race_name

	# 顯示元素
	if element_label:
		var element_name = ELEMENT_NAMES.get(card.element, "??")
		var text_color = ELEMENT_COLORS.get(card.element, Color.WHITE)
		element_label.text = "[%s]" % element_name
		element_label.add_theme_color_override("font_color", text_color)

	# 顯示卡圖
	var texture = DataManager.get_card_texture(card_id)
	if texture:
		card_texture.texture = texture
		card_texture.visible = true
		card_sprite.color = Color(0, 0, 0, 0)
	else:
		card_texture.texture = null
		card_texture.visible = false
		var element_color = ELEMENT_COLORS.get(card.element, Color.GRAY)
		card_sprite.visible = true
		card_sprite.color = element_color

	# 顯示等級（模板卡片顯示 Lv.1）
	if level_label:
		level_label.text = "Lv. 1"

	# 顯示等級進度條（初始為 1 級）
	if exp_bar:
		var level_progress = (1.0 / card.max_level) * 100.0
		exp_bar.value = level_progress

	# 顯示主動技能
	if card.active_skill_id and not card.active_skill_id.is_empty():
		var skill = SkillRegistry.get_skill_info(card.active_skill_id)
		if skill and not skill.is_empty():
			if active_skill_separator:
				active_skill_separator.visible = true
			if active_skill_name:
				active_skill_name.text = skill.skill_name
			if active_skill_cd:
				active_skill_cd.text = "CD:%d" % card.active_skill_cd
			if active_skill_desc:
				active_skill_desc.visible = true
				active_skill_desc.text = skill.skill_description
		else:
			if active_skill_separator:
				active_skill_separator.visible = false
			if active_skill_desc:
				active_skill_desc.visible = false
	else:
		if active_skill_separator:
			active_skill_separator.visible = false
		if active_skill_desc:
			active_skill_desc.visible = false

	# 顯示隊長技能
	if card.leader_skill_ids and card.leader_skill_ids.size() > 0:
		if leader_skill_separator:
			leader_skill_separator.visible = true
		if leader_skill_desc:
			leader_skill_desc.visible = true

		# 組合所有隊長技能的描述
		var leader_desc_text = ""
		for skill_id in card.leader_skill_ids:
			var skill = SkillRegistry.get_skill_info(skill_id)
			if skill and not skill.is_empty():
				if not leader_desc_text.is_empty():
					leader_desc_text += "\n"
				leader_desc_text += "• " + skill.skill_description

		if leader_skill_desc:
			leader_skill_desc.text = leader_desc_text
	else:
		if leader_skill_separator:
			leader_skill_separator.visible = false
		if leader_skill_desc:
			leader_skill_desc.visible = false

func show_empty():
	"""顯示空格子"""
	is_empty = true
	instance_id = ""
	card_id = ""

	if name_label:
		name_label.text = "空"
	if race_label:
		race_label.text = ""
	if element_label:
		element_label.text = ""
	if level_label:
		level_label.text = ""
	if exp_bar:
		exp_bar.value = 0

	card_sprite.color = Color(0.1, 0.1, 0.1, 0.5)
	card_sprite.visible = true
	if card_texture:
		card_texture.visible = false

	# 隱藏技能相關UI
	if active_skill_separator:
		active_skill_separator.visible = false
	if active_skill_desc:
		active_skill_desc.visible = false
	if leader_skill_separator:
		leader_skill_separator.visible = false
	if leader_skill_desc:
		leader_skill_desc.visible = false

	# 修改邊框樣式
	var style = get_theme_stylebox("panel").duplicate()
	style.border_color = Color(0.2, 0.2, 0.2, 1.0)
	add_theme_stylebox_override("panel", style)

# ==================== 輸入處理 ====================

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not is_empty:
				# ✅ 優先發送 instance_id，若為空則發送 card_id（用於選擇器）
				var id_to_send = instance_id if not instance_id.is_empty() else card_id
				slot_clicked.emit(id_to_send, global_position)
				# 播放點擊動畫
				play_click_animation()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not is_empty:
				# ✅ 右鍵點擊 - 優先發送 instance_id，若為空則發送 card_id
				var id_to_send = instance_id if not instance_id.is_empty() else card_id
				slot_right_clicked.emit(id_to_send, global_position)

func play_click_animation():
	"""播放點擊動畫"""
	# 停止之前的動畫
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_ELASTIC)
	active_tween.set_ease(Tween.EASE_OUT)

	# 縮放效果
	active_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)
	active_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

	# 動畫完成後清理引用
	active_tween.finished.connect(func(): active_tween = null)

# ==================== 視覺效果 ====================

func set_selected(selected: bool):
	"""設置選中狀態（批量刪除模式）"""
	print("🟢 InventorySlot.set_selected 被調用")
	print("   卡片ID: %s" % card_id)
	print("   選中狀態: %s" % str(selected))
	is_selected_for_deletion = selected
	update_modulate()

func update_modulate():
	"""更新調製顏色"""
	# ✅ 優先級：選中 > 臨時格子 > 正常
	if is_selected_for_deletion:
		print("   ✅ 應用綠色調製 (0.6, 1.0, 0.6)")
		modulate = Color(0.6, 1.0, 0.6)  # 綠色
	elif is_overflow_slot:
		print("   應用紅色調製 (1.0, 0.8, 0.8)")
		modulate = Color(1.0, 0.8, 0.8)  # 紅色
	else:
		print("   應用正常調製 (1.0, 1.0, 1.0)")
		modulate = Color(1.0, 1.0, 1.0)  # 正常

func _on_mouse_entered():
	"""滑鼠懸停"""
	if not is_empty:
		# ✅ 根據當前狀態疊加高亮效果
		if is_selected_for_deletion:
			modulate = Color(0.72, 1.2, 0.72)  # 綠色基礎上的高亮
		elif is_overflow_slot:
			modulate = Color(1.2, 0.96, 0.96)  # 紅色基礎上的高亮
		else:
			modulate = Color(1.2, 1.2, 1.2)  # 正常高亮

func _on_mouse_exited():
	"""滑鼠離開"""
	# ✅ 恢復當前狀態的調製
	update_modulate()
