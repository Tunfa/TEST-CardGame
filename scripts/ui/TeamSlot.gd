# TeamSlot.gd
# 隊伍格子 - 顯示已選擇的卡片
extends PanelContainer

# ==================== 信號 ====================
signal slot_clicked(slot_index: int)
signal remove_clicked(slot_index: int)
signal set_leader_clicked(slot_index: int)

# ==================== 引用 ====================
@onready var leader_badge = $MarginContainer/VBoxContainer/LeaderBadge
@onready var card_sprite = $MarginContainer/VBoxContainer/CardSprite
@onready var name_label = $MarginContainer/VBoxContainer/NameLabel
@onready var stats_label = $MarginContainer/VBoxContainer/StatsLabel
@onready var remove_button = $MarginContainer/VBoxContainer/RemoveButton
@onready var card_texture = $MarginContainer/VBoxContainer/CardSprite/CardTexture # ✅ 1. 新增
@onready var element_label = $MarginContainer/VBoxContainer/ElementLabel

# ==================== 資料 ====================
var slot_index: int = 0
var card_id: String = ""
var instance_id: String = ""  # ✅ 保存實例ID
var is_empty: bool = true
var is_leader: bool = false
# ✅ 2. 新增元素名稱和顏色的字典
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
# ==================== 初始化 ====================

func _ready():
	show_empty()
	
	# 連接移除按鈕
	if remove_button:
		remove_button.pressed.connect(_on_remove_pressed)

func setup_slot(index: int):
	"""設定格子索引"""
	slot_index = index

func set_card(p_card_id: String):
	"""設定卡片（接收 instance_id）"""
	# ✅ 現在接收的是 instance_id，需要轉換為 card_id
	instance_id = p_card_id
	card_id = PlayerDataManager.get_card_id_from_instance(instance_id)

	if card_id.is_empty():
		print("❌ [TeamSlot] 無效的實例ID: %s" % instance_id)
		show_empty()
		return

	is_empty = false

	# ✅ 載入卡片實例（包含等級資訊）
	var card_instance = PlayerDataManager.get_card_instance(instance_id)
	if card_instance:
		name_label.text = card_instance.card_name
		# ✅ 顯示等級而不是三圍
		stats_label.text = "Lv. %d" % card_instance.current_level

		var card = card_instance  # 用於後續的元素、圖片等資訊

		# ✅ --- 核心修改邏輯 (替換掉舊的) ---
		var texture = DataManager.get_card_texture(card_id)

		if texture:
			# 1. 顯示圖片
			card_texture.texture = texture
			card_texture.visible = true
			# 2. 隱藏背景顏色
			card_sprite.color = Color(0, 0, 0, 0)
		else:
			# 1. 隱藏圖片
			card_texture.texture = null
			card_texture.visible = false
			# 2. 顯示元素背景色
			var element_color = ELEMENT_COLORS.get(card.element, Color.GRAY)
			card_sprite.color = element_color
		# ✅ --- 修改結束 ---
		var element_name = ELEMENT_NAMES.get(card.element, "??")
		var text_color = ELEMENT_COLORS.get(card.element, Color.WHITE)
		element_label.text = "[%s]" % element_name
		element_label.add_theme_color_override("font_color", text_color)

		remove_button.visible = true
		update_border_style()

func show_empty():
	"""顯示空格子"""
	is_empty = true
	is_leader = false
	card_id = ""
	instance_id = ""

	name_label.text = "空位"
	stats_label.text = ""
	card_sprite.color = Color(0.2, 0.2, 0.2, 0.5)
	if card_texture: # 檢查節點是否已就緒
		card_texture.visible = false # ✅ 3. 確保空格子隱藏 Texture
	leader_badge.visible = false
	remove_button.visible = false
	
	# 重置邊框
	update_border_style()

func set_as_leader(is_leader_slot: bool):
	"""設定為隊長"""
	is_leader = is_leader_slot
	leader_badge.visible = is_leader and not is_empty
	update_border_style()

func update_border_style():
	"""更新邊框樣式"""
	var style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	
	if is_leader:
		style.border_color = Color(1.0, 0.9, 0.3, 1.0)  # 金色邊框
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
	elif not is_empty:
		style.border_color = Color(0.4, 0.7, 1.0, 1.0)  # 藍色邊框
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	else:
		style.border_color = Color(0.3, 0.3, 0.4, 1.0)  # 灰色邊框
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	
	add_theme_stylebox_override("panel", style)

func load_card_data(p_card_id: String) -> CardData:
	"""載入卡片資料"""
	return DataManager.get_card(p_card_id)

# ==================== 輸入處理 ====================

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit(slot_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 右鍵設為隊長
			if not is_empty:
				set_leader_clicked.emit(slot_index)

func _on_remove_pressed():
	"""移除按鈕"""
	remove_clicked.emit(slot_index)
