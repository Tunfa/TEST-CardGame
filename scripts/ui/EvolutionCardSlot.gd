# EvolutionCardSlot.gd
# 升仙台卡片槽 - 顯示單張卡片
extends PanelContainer

# ==================== 信號 ====================
signal slot_clicked(instance_id: String)

# ==================== 引用 ====================
@onready var card_sprite = $MarginContainer/VBoxContainer/CardTextureContainer/CardSprite
@onready var card_texture = $MarginContainer/VBoxContainer/CardTextureContainer/CardTexture
@onready var level_label = $MarginContainer/VBoxContainer/CardTextureContainer/LevelLabel
@onready var name_label = $MarginContainer/VBoxContainer/NameLabel
@onready var rank_label = $MarginContainer/VBoxContainer/RankLabel
@onready var status_label = $MarginContainer/VBoxContainer/StatusLabel

# ==================== 資料 ====================
var instance_id: String = ""
var card_data: CardData = null
var is_empty: bool = true
var slot_type: String = "normal"  # normal, target, material

var ELEMENT_COLORS = {
	Constants.Element.METAL: Color("FFD700"),
	Constants.Element.WOOD: Color("33CC33"),
	Constants.Element.WATER: Color("3388FF"),
	Constants.Element.FIRE: Color("FF3333"),
	Constants.Element.EARTH: Color("CC9933"),
	Constants.Element.HEART: Color("FF66CC")
}

# ==================== 初始化 ====================
func _ready():
	if is_empty:
		show_empty()

func setup(p_card: CardData, p_slot_type: String = "normal"):
	"""設定卡片資料"""
	if p_card == null:
		show_empty()
		return

	card_data = p_card
	instance_id = p_card.instance_id
	is_empty = false
	slot_type = p_slot_type

	load_card_display()

func load_card_display():
	"""載入卡片顯示"""
	if card_data == null:
		show_empty()
		return

	# 顯示卡片名稱
	if name_label:
		name_label.text = card_data.card_name

	# 顯示星級
	if rank_label:
		var stars = ""
		for i in range(card_data.rank):
			stars += "⭐"
		rank_label.text = stars

	# 顯示卡圖
	var texture = DataManager.get_card_texture(card_data.card_id)
	if texture and card_texture:
		card_texture.texture = texture
		card_texture.visible = true
		card_sprite.color = Color(0, 0, 0, 0)
	else:
		if card_texture:
			card_texture.texture = null
			card_texture.visible = false
		var element_color = ELEMENT_COLORS.get(card_data.element, Color.GRAY)
		if card_sprite:
			card_sprite.visible = true
			card_sprite.color = element_color

	# 顯示等級
	if level_label:
		level_label.text = "Lv.%d/%d" % [card_data.current_level, card_data.max_level]

	# 顯示狀態標籤（可進化、未滿等等）
	if status_label:
		status_label.visible = false

func set_status_text(text: String, color: Color = Color.WHITE):
	"""設置狀態文字"""
	if status_label:
		status_label.text = text
		status_label.add_theme_color_override("font_color", color)
		status_label.visible = true

func show_empty():
	"""顯示空格子"""
	is_empty = true
	instance_id = ""
	card_data = null

	if name_label:
		name_label.text = "空"
	if rank_label:
		rank_label.text = ""
	if level_label:
		level_label.text = ""
	if status_label:
		status_label.visible = false

	card_sprite.color = Color(0.1, 0.1, 0.1, 0.5)
	card_sprite.visible = true
	if card_texture:
		card_texture.visible = false

func _gui_input(event: InputEvent):
	"""處理點擊事件"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not is_empty:
				slot_clicked.emit(instance_id)
				play_click_animation()
			else:
				# 空槽位也發送信號（instance_id 為空字串）
				slot_clicked.emit("")

func play_click_animation():
	"""播放點擊動畫"""
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

func _on_mouse_entered():
	"""滑鼠懸停"""
	if not is_empty:
		modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited():
	"""滑鼠離開"""
	modulate = Color(1.0, 1.0, 1.0)
