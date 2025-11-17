# CustomDialog.gd
# 自定義對話框基類 - 統一所有對話框的樣式和行為
extends ConfirmationDialog

# 信號
signal button_pressed(button_name: String)

# 對話框類型
enum DialogType {
	INFO,     # 信息提示（只有確定）
	CONFIRM,  # 確認對話框（確定/取消）
	CHOICE    # 多選對話框（自定義按鈕）
}

var dialog_type: DialogType = DialogType.INFO
var custom_buttons: Array = []

func _ready():
	# ✅ 設置 Window 層級，確保在最上層
	always_on_top = true
	# ✅ 設置為非獨佔模式，避免阻擋其他 UI
	exclusive = false

	# 設置對話框樣式
	setup_style()

	# 連接默認信號
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled) # <-- ESC 鍵會觸發這個信號

# ==================== 樣式設置 ====================
func setup_style():
	"""設置對話框樣式 (美化版 v6 - 最終調整)"""
	
	# --- 1. 基礎設置 ---
	min_size = Vector2(480, 280)
	set("title_alignment", HORIZONTAL_ALIGNMENT_CENTER) # 標題置中
	
	# --- 2. 字體與顏色 ---
	# 標題
	add_theme_color_override("title_color", Color.WHITE)
	add_theme_font_size_override("title_font_size", 24)
	
	# 內文 (Label)
	var label = get_label()
	if label:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER 
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color.hex(0xDDDDDD)) # 淺灰色

	# --- 3. 背景面板 ---
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color.hex(0x2D3748) # 深藍灰色
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	
	# 🔴 需求 1: 更改邊框顏色 (更有質感)
	panel_style.border_color = Color.hex(0xA0AEC0) # (原 0x4A5568) 改為亮灰色
	
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	add_theme_stylebox_override("panel", panel_style)

	# --- 4. 按鈕樣式 ---
	var button_hbox = get_ok_button().get_parent()
	if button_hbox and button_hbox is HBoxContainer:
		# 🔴 需求 2: 讓按鈕靠近一點
		button_hbox.add_theme_constant_override("separation", 10) # (原為 20)
		
	# 統一定義按鈕樣式
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color.hex(0x4A5568) # 正常狀態
	btn_style_normal.border_width_top = 1
	btn_style_normal.border_width_bottom = 1
	btn_style_normal.border_width_left = 1
	btn_style_normal.border_width_right = 1
	btn_style_normal.border_color = Color.hex(0x718096)
	btn_style_normal.corner_radius_top_left = 5
	btn_style_normal.corner_radius_top_right = 5
	btn_style_normal.corner_radius_bottom_left = 5
	btn_style_normal.corner_radius_bottom_right = 5
	btn_style_normal.content_margin_top = 8
	btn_style_normal.content_margin_bottom = 8
	btn_style_normal.content_margin_left = 16
	btn_style_normal.content_margin_right = 16

	var btn_style_hover = btn_style_normal.duplicate()
	btn_style_hover.bg_color = Color.hex(0x718096) # 懸停狀態
	btn_style_hover.border_color = Color.hex(0x4A5568)

	var btn_style_pressed = btn_style_normal.duplicate()
	btn_style_pressed.bg_color = Color.hex(0x2D3748) # 按下狀態
	btn_style_pressed.border_color = Color.hex(0x4A5568)

	# 應用到所有按鈕
	add_theme_stylebox_override("button_normal", btn_style_normal)
	add_theme_stylebox_override("button_hover", btn_style_hover)
	add_theme_stylebox_override("button_pressed", btn_style_pressed)
	add_theme_font_size_override("button_font_size", 16)
	add_theme_color_override("button_font_color", Color.WHITE)
	add_theme_color_override("button_hover_font_color", Color.WHITE)
	add_theme_color_override("button_pressed_font_color", Color.hex(0xAAAAAA))

# ==================== 功能函數 (保持不變) ====================

func setup_info_dialog(title_text: String, message: String):
	"""設置為信息對話框"""
	dialog_type = DialogType.INFO
	title = title_text
	dialog_text = message
	get_ok_button().text = "確定"
	get_cancel_button().hide()
	get_ok_button().show()

func setup_confirm_dialog(title_text: String, message: String):
	"""設置為確認對話框"""
	dialog_type = DialogType.CONFIRM
	title = title_text
	dialog_text = message
	get_ok_button().text = "確定"
	get_cancel_button().text = "取消"
	get_ok_button().show()
	get_cancel_button().show()

func setup_choice_dialog(title_text: String, message: String, buttons: Array):
	"""設置為多選對話框
	   buttons 格式: [{"text": "按鈕文字", "action": "action_name"}, ...]
	"""
	dialog_type = DialogType.CHOICE
	title = title_text
	dialog_text = message
	custom_buttons = buttons

	# 隱藏默認按鈕
	get_ok_button().hide()
	get_cancel_button().hide()

	# 獲取按鈕的父容器 (HBoxContainer)
	var button_hbox = get_ok_button().get_parent()
	if button_hbox:
		# 移除舊的自定義按鈕
		for child in button_hbox.get_children():
			if child != get_ok_button() and child != get_cancel_button():
				child.queue_free()

	# 添加自定義按鈕
	for button_data in buttons:
		var button_text = button_data.get("text", "按鈕")
		var action_name = button_data.get("action", "")
		add_button(button_text, true, action_name)

	# 連接自定義按鈕信號
	if not custom_action.is_connected(_on_custom_action):
		custom_action.connect(_on_custom_action)

# ==================== 信號回調 (保持不變) ====================

func _on_confirmed():
	"""確定按鈕被點擊"""
	button_pressed.emit("confirmed")
	hide_and_free()

func _on_canceled():
	"""取消按鈕被點擊 (ESC 鍵也會觸發這裡)"""
	button_pressed.emit("canceled")
	hide_and_free()

func _on_custom_action(action: String):
	"""自定義按鈕被點擊"""
	button_pressed.emit(action)
	hide_and_free()

func hide_and_free():
	"""隱藏並釋放內存"""
	hide()
	call_deferred("queue_free")

func show_dialog():
	"""顯示對話框"""
	popup_centered()
