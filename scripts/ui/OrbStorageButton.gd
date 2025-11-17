# scripts/ui/OrbStorageButton.gd
extends Button

# 信號：當按鈕被點擊時，發出自己的屬性
signal orb_clicked(element: Constants.Element)

@onready var count_label = $CountLabel

var element: Constants.Element
var current_count: int = 0
var is_locked: bool = false # ✅ 1. 新增一個鎖定狀態

# 我們從 InventorySlot 借用顏色定義
var ELEMENT_COLORS = {
	Constants.Element.METAL: Color("FFD700"), # 金色
	Constants.Element.WOOD: Color("33CC33"),   # 綠色
	Constants.Element.WATER: Color("3388FF"),  # 藍色
	Constants.Element.FIRE: Color("FF3333"),   # 紅色
	Constants.Element.EARTH: Color("CC9933"),  # 土黃色
	Constants.Element.HEART: Color("FF66CC")   # 亮粉紅
}

func _ready():
	# 連接按鈕本身的 pressed 信號
	pressed.connect(_on_pressed)

func setup(p_element: Constants.Element):
	"""初始化按鈕的屬性和顏色"""
	element = p_element
	
	var base_color = ELEMENT_COLORS.get(element, Color.GRAY)
	
	# 創建 StyleBox (圓角)
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.corner_radius_top_left = 35
	style_normal.corner_radius_top_right = 35
	style_normal.corner_radius_bottom_left = 35
	style_normal.corner_radius_bottom_right = 35

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = base_color.lightened(0.2) # 懸停時變亮

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = base_color.darkened(0.2) # 按下時變暗
	
	# --- ✅ 修正：禁用狀態不變暗，保持原色 ---
	var style_disabled = style_normal.duplicate()

	# 禁用時保持原色，不改變透明度（避免斬擊時變暗影響發光效果）
	style_disabled.bg_color = base_color

	# 應用 StyleBox
	add_theme_stylebox_override("normal", style_normal)
	add_theme_stylebox_override("hover", style_hover)
	add_theme_stylebox_override("pressed", style_pressed)
	add_theme_stylebox_override("disabled", style_disabled)

func update_count(count: int):
	"""更新顯示的數字"""
	current_count = count
	count_label.text = str(current_count)
	
	# ⚠️ 2. 關鍵修改：
	# 只有在「未鎖定」時，才根據數量決定是否禁用
	if not is_locked:
		disabled = (current_count == 0)
		
func set_locked(p_is_locked: bool): # ✅ 3. 新增這個函數
	"""(新) 強制鎖定或解鎖按鈕"""
	is_locked = p_is_locked
	if is_locked:
		# 如果要鎖定，則強制禁用
		disabled = true
	else:
		# 如果要解鎖，則根據當前數量重新判斷
		disabled = (current_count == 0)

func _on_pressed():
	"""當按鈕被按下時"""
	# 發送信號，告訴 BattleScene "我這個屬性的按鈕被點了"
	orb_clicked.emit(element)

	# 注意：在 BattleScene 收到信號並處理完邏輯後，
	# BattleScene 會呼叫 update_count() 來更新數字和禁用狀態

# ==================== 視覺反饋 ====================

func on_element_collected(collected_element: Constants.Element):
	"""當收集到對應屬性的靈珠時，播放發光動畫"""
	if collected_element != element:
		return  # 不是這個按鈕的屬性，忽略

	# 播放發光閃爍動畫
	play_glow_animation()

func play_glow_animation():
	"""播放跳起動畫"""
	# ✨ 跳起動畫（類似 BattleCard）
	var original_pos = position
	var bounce_height = -15.0  # 跳起的高度（像素）

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	# 跳起
	tween.tween_property(self, "position:y", original_pos.y + bounce_height, 0.1)
	tween.set_ease(Tween.EASE_IN)
	# 落下
	tween.tween_property(self, "position:y", original_pos.y, 0.1)
