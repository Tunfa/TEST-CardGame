# CardSelector.gd
# 通用卡片選擇器 - 可用於任何需要選擇卡片的場景
extends Control

# ==================== 信號 ====================
signal card_selected(card_id: String)  # 卡片被選擇
signal selector_closed()  # 選擇器關閉

# ==================== 節點引用 ====================
@onready var modal_overlay: ColorRect = null
@onready var panel_container: PanelContainer = null
@onready var title_label: Label = null
@onready var grid_container: GridContainer = null
@onready var confirm_button: Button = null
@onready var cancel_button: Button = null
@onready var card_detail_panel: Control = null

# ==================== 預製體 ====================
var slot_scene = preload("res://scenes/inventory/InventorySlot.tscn")

# ==================== 數據 ====================
var available_cards: Array = []  # 可選擇的卡片ID列表
var selected_card_id: String = ""  # 當前選中的卡片
var selector_title: String = "選擇卡片"
var slot_instances: Dictionary = {}  # card_id -> InventorySlot 映射
var context_menu: PopupMenu = null
var active_tween: Tween = null  # 當前運行的動畫 Tween
var active_detail_panel: Control = null  # 當前顯示的詳細面板

# ==================== 初始化 ====================
func _ready():
	print("🎴 CardSelector 初始化")
	create_ui()

func _exit_tree():
	"""節點離開場景樹時清理資源"""
	# 清理 Tween
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		active_tween = null

	# 清理詳細面板及其 CanvasLayer
	if active_detail_panel and is_instance_valid(active_detail_panel):
		var detail_parent = active_detail_panel.get_parent()
		if detail_parent and detail_parent.name == "CardDetailPanelCanvasLayer":
			detail_parent.queue_free()  # 清理整個 CanvasLayer
		else:
			active_detail_panel.queue_free()
		active_detail_panel = null

	# ✅ 清理右鍵菜單及其 CanvasLayer
	if context_menu and is_instance_valid(context_menu):
		var menu_parent = context_menu.get_parent()
		if menu_parent and menu_parent.name == "ContextMenuCanvasLayer":
			menu_parent.queue_free()  # 清理整個 CanvasLayer
		else:
			context_menu.queue_free()
		context_menu = null

func create_ui():
	"""動態創建 UI"""
	# 1. 模態遮罩
	modal_overlay = ColorRect.new()
	modal_overlay.name = "ModalOverlay"
	modal_overlay.color = Color(0, 0, 0, 0.8)
	modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal_overlay)

	# 2. 主面板
	panel_container = PanelContainer.new()
	panel_container.name = "PanelContainer"
	panel_container.custom_minimum_size = Vector2(1200, 800)
	panel_container.set_anchors_preset(Control.PRESET_CENTER)
	panel_container.offset_left = -600
	panel_container.offset_top = -400
	panel_container.offset_right = 600
	panel_container.offset_bottom = 400

	# 設置面板樣式
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.8, 0.8, 1, 1)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_container.add_theme_stylebox_override("panel", panel_style)

	add_child(panel_container)

	# 3. 添加邊距容器
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel_container.add_child(margin)

	# 4. 主布局容器
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# 4. 標題
	title_label = Label.new()
	title_label.text = selector_title
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 1))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# 5. 卡片網格（可滾動）
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 600)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	grid_container = GridContainer.new()
	grid_container.columns = 5
	grid_container.add_theme_constant_override("h_separation", 20)
	grid_container.add_theme_constant_override("v_separation", 20)
	scroll.add_child(grid_container)

	# 6. 按鈕容器
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 20)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_hbox)

	# 確認按鈕
	confirm_button = Button.new()
	confirm_button.text = "確認選擇"
	confirm_button.custom_minimum_size = Vector2(200, 60)
	confirm_button.add_theme_font_size_override("font_size", 24)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_pressed)
	button_hbox.add_child(confirm_button)

	# 取消按鈕
	cancel_button = Button.new()
	cancel_button.text = "取消"
	cancel_button.custom_minimum_size = Vector2(200, 60)
	cancel_button.add_theme_font_size_override("font_size", 24)
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(cancel_button)

	# 7. 創建右鍵菜單
	create_context_menu()

	# 初始隱藏
	hide()

func create_context_menu():
	"""創建右鍵菜單"""
	context_menu = PopupMenu.new()
	context_menu.name = "ContextMenu"

	# ✅ 創建高層級的 CanvasLayer 確保菜單顯示在 CardSelector 之上
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ContextMenuCanvasLayer"
	canvas_layer.layer = 300  # 高於 CardSelector 的 layer (200)

	var tree = get_tree()
	if tree and tree.root:
		tree.root.add_child(canvas_layer)
		canvas_layer.add_child(context_menu)
		print("✅ ContextMenu 添加到 CanvasLayer (layer=300)")
	else:
		# 備用方案：添加為子節點並設置為 top_level
		add_child(context_menu)
		context_menu.top_level = true


	context_menu.add_item("查看詳細資料", 0)
	context_menu.id_pressed.connect(_on_context_menu_selected)

func _on_context_menu_selected(id: int):
	"""處理右鍵菜單選擇"""
	match id:
		0:  # 查看詳細資料
			show_card_details(selected_card_id)

# ==================== 公開方法 ====================
func show_selector(cards: Array, title: String = "選擇卡片"):
	"""顯示選擇器
	@param cards: 可選擇的卡片ID數組
	@param title: 選擇器標題
	"""
	print("🎴 CardSelector.show_selector 被調用")
	print("   可選卡片: %s" % str(cards))
	print("   標題: %s" % title)

	available_cards = cards
	selector_title = title
	selected_card_id = ""

	if title_label:
		title_label.text = title

	create_card_slots()
	show()
	play_appear_animation()

func create_card_slots():
	"""創建卡片格子"""
	# 清空舊格子
	for child in grid_container.get_children():
		child.queue_free()
	slot_instances.clear()

	# 創建新格子
	for card_id in available_cards:
		var slot = slot_scene.instantiate()
		grid_container.add_child(slot)

		# 設置卡片顯示（使用卡片模板數據）
		slot.setup_with_card_id(card_id)

		# 連接信號（InventorySlot 的信號已經會發送 card_id，不需要 bind）
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_right_clicked.connect(_on_slot_right_clicked)

		slot_instances[card_id] = slot

	print("✅ 創建了 %d 個卡片格子" % available_cards.size())

# ==================== 事件處理 ====================
func _on_slot_clicked(card_id: String, _slot_position: Vector2):
	"""卡片被點擊"""
	print("🎴 CardSelector._on_slot_clicked 被調用")
	print("   收到的 card_id: %s" % card_id)
	print("   slot_instances 中的卡片: %s" % str(slot_instances.keys()))

	# 取消之前選中的卡片
	if not selected_card_id.is_empty() and selected_card_id in slot_instances:
		print("   取消之前的選中: %s" % selected_card_id)
		slot_instances[selected_card_id].set_selected(false)

	# 選中新卡片
	selected_card_id = card_id
	if card_id in slot_instances:
		print("   ✅ 設置 %s 為選中狀態" % card_id)
		slot_instances[card_id].set_selected(true)
	else:
		print("   ❌ card_id %s 不在 slot_instances 中！" % card_id)

	# 啟用確認按鈕
	confirm_button.disabled = false
	print("   確認按鈕已啟用")

func _on_slot_right_clicked(card_id: String, _slot_position: Vector2):
	"""卡片被右鍵點擊"""
	print("🖱️ CardSelector._on_slot_right_clicked 被調用")
	print("   card_id: %s" % card_id)
	selected_card_id = card_id

	# ✅ 獲取全局鼠標位置
	var mouse_pos = get_global_mouse_position()
	print("   鼠標位置: %s" % str(mouse_pos))

	# ✅ 使用 popup(Rect2) 方法正確設置位置
	if context_menu:
		# 創建一個以鼠標位置為起點的矩形
		var popup_rect = Rect2(mouse_pos, Vector2.ZERO)
		context_menu.popup(popup_rect)
		print("   ✅ 上下文菜單已顯示")
	else:
		print("   ❌ context_menu 為 null")

func _on_confirm_pressed():
	"""確認按鈕被點擊"""
	print("🔘 CardSelector._on_confirm_pressed 被調用")
	print("   當前選中的卡片ID: %s" % selected_card_id)

	if selected_card_id.is_empty():
		print("   ❌ 沒有選中任何卡片，取消操作")
		return

	print("   ✅ 發射 card_selected 信號: %s" % selected_card_id)
	card_selected.emit(selected_card_id)
	print("   關閉選擇器...")
	close_selector()

func _on_cancel_pressed():
	"""取消按鈕被點擊"""
	print("❌ 取消選擇")
	close_selector()

func close_selector():
	"""關閉選擇器"""
	# 停止當前動畫
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		active_tween = null

	# 清理詳細面板及其 CanvasLayer
	if active_detail_panel and is_instance_valid(active_detail_panel):
		var detail_parent = active_detail_panel.get_parent()
		if detail_parent and detail_parent.name == "CardDetailPanelCanvasLayer":
			detail_parent.queue_free()  # 清理整個 CanvasLayer
		else:
			active_detail_panel.queue_free()
		active_detail_panel = null

	# ✅ 隱藏右鍵菜單（如果正在顯示）
	if context_menu and is_instance_valid(context_menu):
		context_menu.hide()

	# 直接隱藏，不播放動畫（避免 Tween 錯誤）
	selector_closed.emit()
	hide()

func show_card_details(card_id: String):
	"""顯示卡片詳細資料（使用 CardDetailPanel.tscn）"""
	print("🔍 顯示卡片詳細資料: %s" % card_id)

	if card_id.is_empty():
		print("   ❌ card_id 為空")
		return

	# ✅ 清理舊的詳細面板及其 CanvasLayer
	if active_detail_panel and is_instance_valid(active_detail_panel):
		print("   清理舊的 CardDetailPanel")
		var detail_parent = active_detail_panel.get_parent()
		if detail_parent and detail_parent.name == "CardDetailPanelCanvasLayer":
			detail_parent.queue_free()  # 清理整個 CanvasLayer
		else:
			active_detail_panel.queue_free()
		active_detail_panel = null

	# ✅ 載入 CardDetailPanel 場景
	var detail_panel_scene = load("res://scenes/inventory/CardDetailPanel.tscn")
	if not detail_panel_scene:
		push_error("❌ 無法載入 CardDetailPanel.tscn")
		return

	var detail_panel = detail_panel_scene.instantiate()
	var tree = get_tree()
	if tree != null and tree.root != null:
		# ✅ 創建高層級的 CanvasLayer 確保面板顯示在 CardSelector 之上
		var canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CardDetailPanelCanvasLayer"
		canvas_layer.layer = 300  # 高於 CardSelector 的 layer (200)
		tree.root.add_child(canvas_layer)
		canvas_layer.add_child(detail_panel)
		print("   ✅ CardDetailPanel 添加到 CanvasLayer (layer=300)")

		# ✅ 等待一幀，確保節點完全加入場景樹
		await tree.process_frame
	else:
		print("⚠️ 無法添加 CardDetailPanel：get_tree() 或 root 為 null")
		detail_panel.queue_free()
		return

	# ✅ 追蹤當前的詳細面板
	active_detail_panel = detail_panel

	# ✅ 設置非常高的 z_index 確保顯示在 CardSelector 之上
	detail_panel.z_index = 300
	print("   設置 CardDetailPanel z_index = 9999")

	# 連接關閉信號以清理引用
	detail_panel.panel_closed.connect(func():
		if active_detail_panel == detail_panel:
			active_detail_panel = null
	)

	# 顯示卡片詳細資料（使用模板 ID）
	detail_panel.show_card_details(card_id, Vector2.ZERO)

	print("   ✅ CardDetailPanel 已顯示")

# ==================== 動畫 ====================
func play_appear_animation():
	"""播放出現動畫"""
	# 停止之前的動畫
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	modal_overlay.modulate.a = 0
	panel_container.modulate.a = 0
	panel_container.scale = Vector2(0.8, 0.8)

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.set_trans(Tween.TRANS_CUBIC)
	active_tween.set_ease(Tween.EASE_OUT)

	active_tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.3)
	active_tween.tween_property(panel_container, "modulate:a", 1.0, 0.3)
	active_tween.tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.3)

	# 動畫完成後清理引用
	active_tween.finished.connect(func(): active_tween = null)

func play_disappear_animation():
	"""播放消失動畫"""
	# 停止之前的動畫
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.set_trans(Tween.TRANS_CUBIC)
	active_tween.set_ease(Tween.EASE_IN)

	active_tween.tween_property(modal_overlay, "modulate:a", 0.0, 0.3)
	active_tween.tween_property(panel_container, "modulate:a", 0.0, 0.3)
	active_tween.tween_property(panel_container, "scale", Vector2(0.8, 0.8), 0.3)

	# 動畫完成後清理引用
	active_tween.finished.connect(func(): active_tween = null)
