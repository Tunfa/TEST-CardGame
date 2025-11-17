# Inventory.gd
extends Control

# ==================== 引用 ====================
@onready var back_button = $VBoxContainer/TopBar/MarginContainer/HBoxContainer/BackButton
@onready var capacity_label = $VBoxContainer/TopBar/MarginContainer/HBoxContainer/CapacityContainer/CapacityLabel
@onready var grid_container = $VBoxContainer/ScrollContainer/CenterContainer/GridContainer
@onready var card_detail_panel = $CardDetailPanel
@onready var expand_bag_button = $VBoxContainer/BottomBar/MarginContainer/HBoxContainer/ExpandBagButton
@onready var batch_delete_button = $VBoxContainer/BottomBar/MarginContainer/HBoxContainer/BatchDeleteButton

# ==================== 預製體 ====================
var slot_scene = preload("res://scenes/inventory/InventorySlot.tscn")

# ==================== 資料 ====================
var inventory_items: Array = []  # 背包中的卡片ID列表
var context_menu: PopupMenu = null  # 右鍵菜單
var context_menu_card_id: String = ""  # 當前右鍵選中的卡片
var batch_delete_mode: bool = false  # 批量刪除模式
var selected_for_deletion: Array = []  # 選中要刪除的卡片instance_id列表
var slot_instances: Dictionary = {}  # instance_id -> InventorySlot 映射，用於快速更新

# ==================== 初始化 ====================

func _ready():
	print("🎒 背包載入完成")

	# 連接按鈕
	back_button.pressed.connect(_on_back_pressed)
	expand_bag_button.pressed.connect(_on_expand_bag_pressed)
	batch_delete_button.pressed.connect(_on_batch_delete_pressed)

	# 創建右鍵菜單
	create_context_menu()

	# 載入背包資料
	load_inventory()

	# 創建格子
	create_inventory_slots()

	# 更新容量顯示
	update_capacity_display()

# ==================== 右鍵菜單 ====================

func create_context_menu():
	"""創建右鍵上下文菜單"""
	context_menu = PopupMenu.new()
	context_menu.name = "ContextMenu"
	add_child(context_menu)

	# 添加菜單項
	context_menu.add_item("進化", 0)
	context_menu.add_item("刪除卡片", 1)

	# 連接選擇信號
	context_menu.id_pressed.connect(_on_context_menu_item_selected)

func _on_context_menu_item_selected(id: int):
	"""處理菜單項選擇"""
	match id:
		0:  # 進化
			goto_evolution_with_card(context_menu_card_id)
		1:  # 刪除卡片
			delete_card(context_menu_card_id)

func goto_evolution_with_card(instance_id: String):
	"""跳轉到進化介面並自動放入卡片"""
	if instance_id.is_empty():
		return

	# 檢查卡片是否在組隊中
	if PlayerDataManager.is_card_in_team(instance_id):
		show_warning_dialog("無法進化", "此卡片正在組隊中，無法進化")
		return

	# 將選中的卡片instance_id儲存到GameManager
	GameManager.selected_card_for_evolution = instance_id

	# 跳轉到進化介面
	GameManager.goto_evolution()

func delete_card(instance_id: String):
	"""刪除卡片（使用 instance_id）"""
	print("🔍 [刪除] 嘗試刪除卡片實例: %s" % instance_id)

	if instance_id.is_empty():
		print("❌ [刪除] 實例ID為空")
		return

	# ✅ 獲取該實例對應的 card_id
	var card_id = PlayerDataManager.get_card_id_from_instance(instance_id)
	if card_id.is_empty():
		print("❌ [刪除] 無效的實例ID")
		show_warning_dialog("刪除失敗", "無法找到此卡片")
		return

	print("🔍 [刪除] instance_%s 對應的卡片ID: %s" % [instance_id, card_id])

	# ✅ 檢查這個特定的實例ID是否在任何隊伍中
	var instance_ids_in_teams = PlayerDataManager.get_all_instance_ids_in_teams()
	print("🔍 [刪除] 所有隊伍中的實例: ", instance_ids_in_teams)
	print("🔍 [刪除] 此實例是否在隊伍中: %s" % (instance_id in instance_ids_in_teams))

	if instance_id in instance_ids_in_teams:
		# 顯示提示框
		print("⚠️ [刪除] 卡片在隊伍中，無法刪除")
		show_warning_dialog("無法刪除", "此卡片正在隊伍中使用\n請先從隊伍中移除")
		return

	# ✅ 使用 instance_id 刪除
	print("🔍 [刪除] 調用 PlayerDataManager.remove_card_by_instance()")
	var success = PlayerDataManager.remove_card_by_instance(instance_id)
	print("🔍 [刪除] remove_card_by_instance 返回: %s" % success)

	if success:
		print("✅ 刪除卡片成功：%s (instance_%s)" % [card_id, instance_id])

		# 刷新顯示
		load_inventory()
		create_inventory_slots()
		update_capacity_display()
	else:
		print("❌ [刪除] 刪除失敗")
		show_warning_dialog("刪除失敗", "無法找到此卡片")

func show_warning_dialog(title: String, message: String):
	"""顯示警告對話框"""
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = title
	dialog.ok_button_text = "確定"
	add_child(dialog)
	dialog.popup_centered()

	# 對話框關閉後自動刪除
	dialog.confirmed.connect(func():
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)

# ==================== 載入背包資料 ====================

func load_inventory():
	"""從 PlayerDataManager 載入背包"""
	inventory_items = PlayerDataManager.get_inventory()
	print("  載入了 %d 張卡片" % inventory_items.size())

# ==================== 創建背包格子 ====================

func create_inventory_slots():
	"""創建背包格子（包含臨時格子）"""
	# 清空舊格子和映射
	for child in grid_container.get_children():
		child.queue_free()
	slot_instances.clear()

	var capacity = PlayerDataManager.player_data.bag_capacity
	var actual_items = inventory_items.size()

	# ✅ 如果背包超過上限，顯示所有格子（包括臨時格子）
	var total_slots = max(capacity, actual_items)

	# 創建格子
	for i in range(total_slots):
		var slot = slot_scene.instantiate()
		grid_container.add_child(slot)

		# 如果有卡片，設定卡片資料
		var instance_id = ""
		if i < inventory_items.size():
			instance_id = inventory_items[i]
			slot.setup(instance_id)
			# ✅ 保存映射，用於快速更新
			slot_instances[instance_id] = slot
		else:
			slot.show_empty()

		# ✅ 批量刪除模式：標記選中的卡片
		if batch_delete_mode and not instance_id.is_empty() and is_card_selected(instance_id):
			slot.set_selected(true)

		# ✅ 標記超出上限的格子（臨時格子）
		if i >= capacity:
			slot.is_overflow_slot = true
			slot.update_modulate()

		# 連接點擊信號
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_right_clicked.connect(_on_slot_right_clicked)

		# 連接懸停信號
		slot.mouse_entered.connect(slot._on_mouse_entered)
		slot.mouse_exited.connect(slot._on_mouse_exited)

# ==================== 更新顯示 ====================

func update_capacity_display():
	"""更新容量顯示"""
	var used = inventory_items.size()
	var total = PlayerDataManager.player_data.bag_capacity
	capacity_label.text = "%d/%d" % [used, total]

	# ✅ 如果超過上限，變紅色並顯示警告
	if used > total:
		capacity_label.add_theme_color_override("font_color", Color.RED)
	# 如果接近滿了，變黃色
	elif used >= total * 0.9:
		capacity_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		capacity_label.add_theme_color_override("font_color", Color.WHITE)

# ==================== 輸入處理 ====================

func _input(event: InputEvent):
	"""處理 ESC 鍵返回"""
	if event.is_action_pressed("ui_cancel"):  # ESC 鍵
		if batch_delete_mode:
			# 批量刪除模式下，ESC 取消模式
			cancel_batch_delete_mode()
		else:
			# 正常返回
			_on_back_pressed()

# ==================== 按鈕回調 ====================

func _on_back_pressed():
	"""返回主選單"""
	print("← 返回主選單")
	GameManager.goto_main_menu()

func _on_slot_clicked(instance_id: String, slot_position: Vector2):
	"""格子被點擊（接收 instance_id）"""
	# ✅ 批量刪除模式下，點擊切換選擇狀態
	if batch_delete_mode:
		toggle_card_selection(instance_id)
		# ✅ 立即更新該卡片的選中狀態，無需刷新整個網格
		if instance_id in slot_instances:
			var slot = slot_instances[instance_id]
			slot.set_selected(is_card_selected(instance_id))
		return

	var card_id = PlayerDataManager.get_card_id_from_instance(instance_id)
	print("點擊卡片：instance_%s -> %s，位置：%s" % [instance_id, card_id, slot_position])
	# ✅ 傳遞 instance_id 而非 card_id，以便顯示等級資訊
	card_detail_panel.show_card_details_with_instance(instance_id, slot_position)

func _on_slot_right_clicked(instance_id: String, _slot_position: Vector2):
	"""格子被右鍵點擊（接收 instance_id）"""
	# ✅ 批量刪除模式下不顯示右鍵菜單
	if batch_delete_mode:
		return

	var card_id = PlayerDataManager.get_card_id_from_instance(instance_id)
	print("右鍵點擊卡片：instance_%s -> %s" % [instance_id, card_id])
	# ✅ 存儲 instance_id 而非 card_id
	context_menu_card_id = instance_id

	# 獲取鼠標全局位置
	var viewport = get_viewport()
	if viewport == null:
		print("⚠️ get_viewport() 返回 null，無法顯示菜單")
		return
	var mouse_pos = viewport.get_mouse_position()

	# 顯示菜單
	context_menu.position = Vector2i(mouse_pos)
	context_menu.popup()

# ==================== 擴充背包按鈕 ====================

func _on_expand_bag_pressed():
	"""擴充背包/取消按鈕被按下"""
	# ✅ 批量刪除模式下作為取消按鈕
	if batch_delete_mode:
		cancel_batch_delete_mode()
	else:
		GameManager.show_expand_bag_dialog()

# ==================== 批量刪除功能 ====================

func _on_batch_delete_pressed():
	"""批量刪除按鈕被按下"""
	if not batch_delete_mode:
		# 進入批量刪除模式
		enter_batch_delete_mode()
	else:
		# 退出批量刪除模式並確認刪除
		exit_batch_delete_mode()

func enter_batch_delete_mode():
	"""進入批量刪除模式"""
	batch_delete_mode = true
	selected_for_deletion.clear()

	# 更新按鈕文字
	batch_delete_button.text = "確認刪除"
	batch_delete_button.modulate = Color(1.0, 0.5, 0.5)

	# ✅ 將擴充背包按鈕改為取消按鈕
	expand_bag_button.text = "取消"
	expand_bag_button.modulate = Color(0.8, 0.8, 0.8)

	# 禁用返回按鈕
	back_button.disabled = true

	print("📋 進入批量刪除模式")

func exit_batch_delete_mode():
	"""退出批量刪除模式並執行刪除"""
	if selected_for_deletion.size() == 0:
		# 沒有選中任何卡片，直接退出
		cancel_batch_delete_mode()
		return

	# 顯示確認對話框
	show_batch_delete_confirmation()

func cancel_batch_delete_mode():
	"""取消批量刪除模式"""
	batch_delete_mode = false
	selected_for_deletion.clear()

	# 恢復按鈕文字
	batch_delete_button.text = "批量刪除"
	batch_delete_button.modulate = Color(1.0, 1.0, 1.0)

	# ✅ 恢復擴充背包按鈕
	expand_bag_button.text = "擴充背包"
	expand_bag_button.modulate = Color(1.0, 1.0, 1.0)

	# 啟用返回按鈕
	back_button.disabled = false

	# 刷新顯示
	create_inventory_slots()

	print("❌ 取消批量刪除模式")

func show_batch_delete_confirmation():
	"""顯示批量刪除確認對話框"""
	var CustomDialog = load("res://scripts/ui/CustomDialog.gd")
	var dialog = CustomDialog.new()

	var count = selected_for_deletion.size()
	var message = "確定要刪除選中的 %d 張卡片嗎？\n此操作無法撤銷！" % count

	var buttons = [
		{"text": "取消", "action": "cancel"},
		{"text": "確認刪除", "action": "confirm"}
	]
	dialog.setup_choice_dialog("批量刪除", message, buttons)

	# 連接信號
	dialog.button_pressed.connect(func(action):
		var scene_tree = get_tree()
		if scene_tree != null:
			await scene_tree.create_timer(0.1).timeout
		match action:
			"confirm":
				perform_batch_delete()
			"cancel":
				cancel_batch_delete_mode()
	)

	# 添加到場景樹並顯示
	var tree = get_tree()
	if tree != null and tree.root != null:
		tree.root.add_child(dialog)
		dialog.show_dialog()
	else:
		print("⚠️ 無法顯示對話框：get_tree() 或 root 為 null")

func perform_batch_delete():
	"""執行批量刪除"""
	var deleted_count = 0
	var failed_count = 0

	# 檢查是否有卡片在隊伍中
	var instance_ids_in_teams = PlayerDataManager.get_all_instance_ids_in_teams()

	for instance_id in selected_for_deletion:
		# 檢查是否在隊伍中
		if instance_id in instance_ids_in_teams:
			print("⚠️ [批量刪除] instance_%s 在隊伍中，跳過" % instance_id)
			failed_count += 1
			continue

		# 刪除卡片
		if PlayerDataManager.remove_card_by_instance(instance_id):
			deleted_count += 1
		else:
			failed_count += 1

	# 顯示結果
	var result_message = "成功刪除 %d 張卡片" % deleted_count
	if failed_count > 0:
		result_message += "\n%d 張卡片無法刪除（可能在隊伍中）" % failed_count

	show_warning_dialog("刪除完成", result_message)

	# 退出批量刪除模式
	cancel_batch_delete_mode()

	# 刷新顯示
	load_inventory()
	create_inventory_slots()
	update_capacity_display()

func toggle_card_selection(instance_id: String):
	"""切換卡片選擇狀態（批量刪除模式下）"""
	if instance_id in selected_for_deletion:
		selected_for_deletion.erase(instance_id)
		print("❌ 取消選擇：instance_%s" % instance_id)
	else:
		selected_for_deletion.append(instance_id)
		print("✅ 選中：instance_%s" % instance_id)

func is_card_selected(instance_id: String) -> bool:
	"""檢查卡片是否被選中"""
	return instance_id in selected_for_deletion
