# TrainingTeamRow.gd
# 訓練隊伍行組件 - 完全獨立的實現
extends PanelContainer

# ==================== 信号 ====================
signal edit_team_requested(team_index: int)
signal slot_clicked(team_index: int, slot_index: int)
signal card_removed(team_index: int, slot_index: int)
signal team_cleared(team_index: int)

# ==================== 節點引用 ====================
@onready var team_label = $MarginContainer/HBoxContainer/LeftPanel/TeamLabel
@onready var edit_button = $MarginContainer/HBoxContainer/LeftPanel/EditButton
@onready var clear_button = $MarginContainer/HBoxContainer/LeftPanel/ClearButton
@onready var cards_container = $MarginContainer/HBoxContainer/CardsContainer

# ==================== 數據 ====================
var team_index: int = 0
var team_cards: Array = []  # instance_id 数组

# ==================== 初始化 ====================
func _ready():
	edit_button.pressed.connect(_on_edit_pressed)
	clear_button.pressed.connect(_on_clear_pressed)

	# 連接所有槽位按鈕
	for i in range(5):
		var slot = cards_container.get_child(i)
		var card_button = slot.get_node("CardPanel/CardButton")
		var remove_button = slot.get_node("RemoveButton")

		card_button.pressed.connect(_on_slot_pressed.bind(i))
		remove_button.pressed.connect(_on_remove_pressed.bind(i))

func setup(index: int, cards: Array = []):
	"""設定隊伍數據"""
	team_index = index
	team_cards = cards.duplicate()
	team_label.text = "訓練隊伍 %d" % (team_index + 1)
	update_display()

func update_display():
	"""更新顯示"""
	# 元素顏色定義
	var ELEMENT_COLORS = {
		Constants.Element.METAL: Color("FFD700"),
		Constants.Element.WOOD: Color("33CC33"),
		Constants.Element.WATER: Color("3388FF"),
		Constants.Element.FIRE: Color("FF3333"),
		Constants.Element.EARTH: Color("CC9933"),
		Constants.Element.HEART: Color("FF66CC")
	}

	var ELEMENT_NAMES = {
		Constants.Element.METAL: "金",
		Constants.Element.WOOD: "木",
		Constants.Element.WATER: "水",
		Constants.Element.FIRE: "火",
		Constants.Element.EARTH: "土",
		Constants.Element.HEART: "心"
	}

	for i in range(5):
		var slot = cards_container.get_child(i)
		var card_panel = slot.get_node("CardPanel")
		var card_button = card_panel.get_node("CardButton")
		var vbox = card_button.get_node("MarginContainer/VBoxContainer")
		var texture_container = vbox.get_node("CardTextureContainer")
		var card_texture = texture_container.get_node("CardTexture")
		var card_sprite = texture_container.get_node("CardSprite")
		var level_label = texture_container.get_node("LevelLabel")
		var element_label = vbox.get_node("ElementLabel")
		var name_label = vbox.get_node("NameLabel")
		var remove_button = slot.get_node("RemoveButton")

		if i < team_cards.size() and team_cards[i] != "":
			# 有卡片
			var card_instance_id = team_cards[i]
			var card_instance = PlayerDataManager.get_card_instance(card_instance_id)

			if card_instance:
				# 顯示卡圖
				var texture = DataManager.get_card_texture(card_instance.card_id)
				if texture:
					card_texture.texture = texture
					card_texture.visible = true
					card_sprite.visible = false
				else:
					card_texture.visible = false
					card_sprite.visible = true
					var element_color = ELEMENT_COLORS.get(card_instance.element, Color.GRAY)
					card_sprite.color = element_color

				# 顯示等級
				level_label.text = "Lv. %d" % card_instance.current_level
				level_label.visible = true

				# 顯示元素
				var element_name = ELEMENT_NAMES.get(card_instance.element, "??")
				var text_color = ELEMENT_COLORS.get(card_instance.element, Color.WHITE)
				element_label.text = "[%s]" % element_name
				element_label.add_theme_color_override("font_color", text_color)

				# 顯示名稱
				name_label.text = card_instance.card_name

				remove_button.visible = true
			else:
				# 無效實例ID
				_show_empty_slot(card_texture, card_sprite, level_label, element_label, name_label, remove_button)
		else:
			# 空位
			_show_empty_slot(card_texture, card_sprite, level_label, element_label, name_label, remove_button)

func _show_empty_slot(card_texture, card_sprite, level_label, element_label, name_label, remove_button):
	"""顯示空格子"""
	card_texture.visible = false
	card_sprite.visible = true
	card_sprite.color = Color(0.3, 0.3, 0.3, 0.5)
	level_label.visible = false
	element_label.text = ""
	name_label.text = "空位"
	remove_button.visible = false

func get_team_cards() -> Array:
	"""獲取隊伍卡片"""
	return team_cards.duplicate()

func set_team_cards(cards: Array):
	"""設定隊伍卡片"""
	team_cards = cards.duplicate()
	update_display()

# ==================== 按鈕回调 ====================
func _on_edit_pressed():
	"""編輯按鈕"""
	edit_team_requested.emit(team_index)

func _on_clear_pressed():
	"""清空按鈕"""
	team_cleared.emit(team_index)

func _on_slot_pressed(slot_index: int):
	"""槽位按鈕"""
	slot_clicked.emit(team_index, slot_index)

func _on_remove_pressed(slot_index: int):
	"""移除按鈕"""
	card_removed.emit(team_index, slot_index)
