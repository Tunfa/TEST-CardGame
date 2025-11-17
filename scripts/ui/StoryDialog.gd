# StoryDialog.gd
# 劇情對話框 - 完全重寫版本
extends Control

# ==================== 信號 ====================
signal dialog_closed()
signal choice_selected(action: String, choice_index: int)

# ==================== 節點引用 ====================
@onready var background: ColorRect = null  # 半透明背景
@onready var dialog_panel: Panel = null  # 對話框面板
@onready var speaker_label: Label = null  # 說話者
@onready var content_label: Label = null  # 內容
@onready var continue_label: Label = null  # 繼續提示
@onready var choices_container: VBoxContainer = null  # 選項容器

# ==================== 狀態 ====================
var current_dialog_data: Dictionary = {}
var is_showing: bool = false
var can_continue: bool = true

# ==================== Tween ====================
var blink_tween: Tween = null

# ==================== 初始化 ====================
func _ready():
	create_ui()
	hide()
	print("✅ StoryDialog 初始化完成")

func _exit_tree():
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
		blink_tween = null

# ==================== 創建 UI ====================
func create_ui():
	"""創建對話框 UI - 簡化版本"""

	# 1. 半透明背景（覆蓋整個畫面）
	background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0, 0, 0, 0.7)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 2. 對話框面板（底部，全寬）
	dialog_panel = Panel.new()
	dialog_panel.name = "DialogPanel"
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dialog_panel)

	# 設置面板位置和大小（底部，全寬，高度300）
	dialog_panel.set_anchor(SIDE_LEFT, 0.0)
	dialog_panel.set_anchor(SIDE_TOP, 1.0)
	dialog_panel.set_anchor(SIDE_RIGHT, 1.0)
	dialog_panel.set_anchor(SIDE_BOTTOM, 1.0)
	dialog_panel.offset_left = 0
	dialog_panel.offset_top = -300
	dialog_panel.offset_right = 0
	dialog_panel.offset_bottom = 0

	# 設置面板樣式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.border_width_top = 3
	style.border_color = Color(0.8, 0.8, 1, 1)
	dialog_panel.add_theme_stylebox_override("panel", style)

	# 3. 內容容器（確保填滿整個 panel）
	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 20)
	dialog_panel.add_child(margin)

	# 確保 margin 填滿整個 panel
	margin.set_anchor(SIDE_LEFT, 0.0)
	margin.set_anchor(SIDE_TOP, 0.0)
	margin.set_anchor(SIDE_RIGHT, 1.0)
	margin.set_anchor(SIDE_BOTTOM, 1.0)
	margin.offset_left = 0
	margin.offset_top = 0
	margin.offset_right = 0
	margin.offset_bottom = 0

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)

	# 4. 說話者標籤
	speaker_label = Label.new()
	speaker_label.name = "Speaker"
	speaker_label.add_theme_font_size_override("font_size", 28)
	speaker_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vbox.add_child(speaker_label)

	# 5. 內容標籤
	content_label = Label.new()
	content_label.name = "Content"
	content_label.add_theme_font_size_override("font_size", 24)
	content_label.add_theme_color_override("font_color", Color.WHITE)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content_label.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(content_label)

	# 6. 底部容器
	var bottom_box = HBoxContainer.new()
	vbox.add_child(bottom_box)

	# 7. 繼續提示（左側）
	continue_label = Label.new()
	continue_label.name = "Continue"
	continue_label.text = "▼ 點擊繼續"
	continue_label.add_theme_font_size_override("font_size", 20)
	continue_label.add_theme_color_override("font_color", Color.WHITE)
	bottom_box.add_child(continue_label)

	# 空白間隔
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_box.add_child(spacer)

	# 8. 選項容器（右側）
	choices_container = VBoxContainer.new()
	choices_container.name = "Choices"
	choices_container.add_theme_constant_override("separation", 15)
	choices_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	bottom_box.add_child(choices_container)

	# 連接點擊事件
	background.gui_input.connect(_on_clicked)
	dialog_panel.gui_input.connect(_on_clicked)

	print("✅ StoryDialog UI 創建完成")

# ==================== 顯示對話 ====================
func show_dialog(dialog_data: Dictionary):
	"""顯示對話框"""
	print("📖 StoryDialog.show_dialog: %s" % dialog_data.get("dialog_id", "unknown"))

	# 停止舊動畫
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
		blink_tween = null

	# 更新數據
	current_dialog_data = dialog_data
	is_showing = true
	can_continue = true

	# 設置說話者
	speaker_label.text = dialog_data.get("speaker", "???")

	# 設置內容
	content_label.text = dialog_data.get("content", "")

	# 創建選項按鈕
	var choices = dialog_data.get("choices", [])
	_create_choices(choices)

	# 如果有選項，隱藏繼續提示
	if choices.size() > 0:
		continue_label.visible = false
		can_continue = false
	else:
		continue_label.visible = true
		can_continue = true
		_start_blink_animation()

	# 顯示
	show()
	modulate = Color.WHITE

	print("✅ 對話框已顯示")

func _create_choices(choices: Array):
	"""創建選項按鈕"""
	# 清空舊按鈕
	for child in choices_container.get_children():
		child.queue_free()

	# 創建新按鈕
	for i in range(choices.size()):
		var choice = choices[i]
		var button = Button.new()
		button.text = choice.get("text", "選項")
		button.custom_minimum_size = Vector2(350, 55)
		button.add_theme_font_size_override("font_size", 24)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.3, 0.5, 0.9)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.8, 0.8, 1, 1)
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_right = 5
		style.corner_radius_bottom_left = 5
		button.add_theme_stylebox_override("normal", style)

		var action = choice.get("action", "close")
		button.pressed.connect(_on_choice_pressed.bind(action, i))
		choices_container.add_child(button)

func _on_choice_pressed(action: String, choice_index: int):
	"""選項被點擊"""
	print("📖 選擇: %s (索引 %d)" % [action, choice_index])
	choice_selected.emit(action, choice_index)

	if action == "close":
		close_dialog()

# ==================== 關閉對話 ====================
func close_dialog(_immediate: bool = false):

	"""關閉對話框（immediate 參數保留兼容性，但不使用）"""

	print("📖 關閉對話框")

	# 停止動畫
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
		blink_tween = null

	is_showing = false
	hide()
	dialog_closed.emit()

# ==================== 動畫 ====================
func _start_blink_animation():
	"""開始閃爍動畫"""
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()

	blink_tween = create_tween()
	blink_tween.set_loops(-1)
	blink_tween.tween_property(continue_label, "modulate:a", 0.3, 0.8)
	blink_tween.tween_property(continue_label, "modulate:a", 1.0, 0.8)

# ==================== 輸入處理 ====================
func _on_clicked(event: InputEvent):
	"""點擊事件"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if can_continue:
			choice_selected.emit("next", 0)

func _input(event: InputEvent):
	"""鍵盤輸入"""
	if not is_showing:
		return

	# 禁用 ESC
	if event.is_action_pressed("ui_cancel"):
		var vp = get_viewport()
		if vp != null:
			vp.set_input_as_handled()

	# 空格/回車繼續
	if can_continue and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select")):
		choice_selected.emit("next", 0)
		close_dialog()
		var vp = get_viewport()
		if vp != null:
			vp.set_input_as_handled()
