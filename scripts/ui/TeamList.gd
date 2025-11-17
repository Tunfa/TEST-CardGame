# scripts/ui/TeamList.gd
# 隊伍管理主控制器 (新版)
extends Control

# ==================== 引用 ====================
@onready var back_button = $VBoxContainer/TopBar/HBoxContainer/BackButton
@onready var team_list_container = $VBoxContainer/ScrollContainer/TeamListContainer

# --- 新增：懸浮視窗 (Modal) 的引用 ---
@onready var card_selector_modal = $CardSelectorModal
@onready var modal_header_label = $CardSelectorModal/MarginContainer/VBoxContainer/HeaderLabel
@onready var modal_card_grid = $CardSelectorModal/MarginContainer/VBoxContainer/InventoryScroll/CardGridContainer
@onready var modal_confirm_button = $CardSelectorModal/MarginContainer/VBoxContainer/ButtonHBox/ConfirmButton
@onready var modal_cancel_button = $CardSelectorModal/MarginContainer/VBoxContainer/ButtonHBox/CancelButton

# ==================== 預製體 ====================
# 替換成新的 TeamRow 場景
var team_row_scene = preload("res://scenes/team/TeamRow.tscn")
# 我們還需要背包格子的場景
var inventory_slot_scene = preload("res://scenes/inventory/InventorySlot.tscn")

# ==================== 資料 ====================
const DEFAULT_TEAM_ROWS = 5
var current_editing_team_id: String = ""
var temp_team_card_ids: Array = []  # ✅ 儲存 modal 中臨時選擇的 instance_id
var is_selection_mode: bool = false

# ==================== 初始化 ====================
func _ready():
	print("👥 隊伍管理 (新版) 載入完成")
	
	# 連接按鈕
	back_button.pressed.connect(_on_back_pressed)
	# 檢查是否是從關卡選擇介面來的
	if GameManager.selected_stage != null:
		is_selection_mode = true
		print("📋 TeamList 進入「選擇模式」")
	else:
		is_selection_mode = false
		print("👥 TeamList 進入「管理模式」")
	
	# 連接 Modal 按鈕
	modal_confirm_button.pressed.connect(_on_modal_confirm_pressed)
	modal_cancel_button.pressed.connect(_on_modal_cancel_pressed)

	# 載入所有隊伍
	create_team_rows()
	
	# 隱藏 Modal
	card_selector_modal.hide()

# ==================== 載入隊伍 ====================

func create_team_rows():
	"""創建 5 個預設的隊伍欄位"""
	
	# 1. 清空舊的
	for child in team_list_container.get_children():
		child.queue_free()
	
	# 2. 獲取所有已儲存的隊伍資料
	var all_teams_data = PlayerDataManager.get_all_teams()

	# 3. 創建 5 個欄位
	for i in range(DEFAULT_TEAM_ROWS):
		var team_id = "team_%d" % (i + 1) # team_1, team_2, ...
		
		# 嘗試從已儲存的資料中載入
		var team_data: TeamData = null
		if all_teams_data.has(team_id):
			# PlayerDataManager.load_team() 會返回一個 TeamData 物件
			team_data = PlayerDataManager.load_team(team_id)
			
		var row = team_row_scene.instantiate()
		team_list_container.add_child(row)
		
		# 設定欄位 (即使 team_data 是 null 也沒關係)
		row.setup(team_id, team_data)
		var team_is_empty = (team_data == null or team_data.leader_card_id.is_empty())
		row.set_selection_mode(is_selection_mode, team_is_empty)
		row.battle_requested.connect(_on_battle_requested)
		
		# 連接信號
		row.edit_requested.connect(_on_edit_requested)
		row.clear_requested.connect(_on_clear_requested)
		row.remove_member_requested.connect(_on_remove_member_requested)

# ==================== 隊伍操作 (由 TeamRow 觸發) ====================
func _on_battle_requested(team_id: String):
	"""一個 TeamRow 按下了「戰鬥」按鈕"""
	var team = PlayerDataManager.load_team(team_id)

	if team == null or team.leader_card_id.is_empty():
		push_error("選擇了無效的隊伍！ ID: %s" % team_id)
		return

	if GameManager.selected_stage == null:
		push_error("沒有選擇關卡！無法開始戰鬥")
		return

	print("⚔️ 隊伍 %s 確認！進入戰鬥: %s" % [team_id, GameManager.selected_stage.stage_name])

	# 使用 GameManager 儲存的關卡和剛選擇的隊伍開始戰鬥
	GameManager.goto_battle(team, GameManager.selected_stage)


func _on_edit_requested(team_id: String):
	"""(核心) 當一個欄位的「編輯」按鈕被點擊"""
	print("開始編輯隊伍: %s" % team_id)
	current_editing_team_id = team_id
	
	# 1. 載入當前隊伍資料，存入暫存區
	temp_team_card_ids.clear()
	var team_data = PlayerDataManager.load_team(team_id)
	if team_data:
		if not team_data.leader_card_id.is_empty():
			temp_team_card_ids.append(team_data.leader_card_id)
		temp_team_card_ids.append_array(team_data.member_card_ids)

	# 2. 填充懸浮背包
	_populate_card_selector()
	
	# 3. 顯示懸浮視窗
	card_selector_modal.show()

func _on_clear_requested(team_id: String):
	"""當一個欄位的「清空」按鈕被點擊"""
	# TODO: 可以在這裡加一個確認對話框

	# 1. 呼叫 PlayerDataManager 清除
	PlayerDataManager.clear_team(team_id)

	# 2. 保存變更
	PlayerDataManager.save_data()

	# 3. 刷新列表
	create_team_rows()

func _on_remove_member_requested(team_id: String, slot_index: int):
	"""當點擊某個格子的移除按鈕"""
	print("🗑️ 處理移除請求：隊伍 %s，格子 %d" % [team_id, slot_index])

	# 1. 載入當前隊伍資料
	var team_data = PlayerDataManager.load_team(team_id)
	if not team_data:
		print("❌ 隊伍資料不存在：%s" % team_id)
		return

	# 2. 根據 slot_index 移除對應的卡片
	if slot_index == 0:
		# 移除隊長 (L1)
		print("  移除隊長：%s" % team_data.leader_card_id)

		# 如果有隊員，將第一個隊員升為隊長
		if team_data.member_card_ids.size() > 0:
			team_data.leader_card_id = team_data.member_card_ids[0]
			team_data.member_card_ids.remove_at(0)
			print("  升級隊員為新隊長：%s" % team_data.leader_card_id)
		else:
			# 如果沒有隊員，清空整個隊伍
			print("  隊伍已空，清空整個隊伍")
			PlayerDataManager.clear_team(team_id)
			PlayerDataManager.save_data()
			create_team_rows()
			return
	else:
		# 移除隊員 (A1 ~ A4)
		var member_index = slot_index - 1
		if member_index < team_data.member_card_ids.size():
			var removed_card = team_data.member_card_ids[member_index]
			print("  移除隊員：%s (索引 %d)" % [removed_card, member_index])
			team_data.member_card_ids.remove_at(member_index)
		else:
			print("❌ 無效的隊員索引：%d" % member_index)
			return

	# 3. 保存更新後的隊伍
	PlayerDataManager.save_team(team_id, team_data)
	PlayerDataManager.save_data()

	# 4. 刷新顯示
	create_team_rows()
	print("✅ 移除成功")

# ==================== 懸浮背包 (Modal) 邏輯 ====================

func _populate_card_selector():
	"""填充懸浮背包的卡片列表"""

	# 1. 更新標題
	modal_header_label.text = "編輯隊伍 %s (%d/%d)" % [
		current_editing_team_id.replace("team_", ""),
		temp_team_card_ids.size(),
		Constants.MAX_TEAM_SIZE
	]

	# 2. 清空格子
	for child in modal_card_grid.get_children():
		child.queue_free()

	# 3. ✅ 獲取玩家所有卡片（現在返回 instance_id 列表）
	var all_inventory_instances = PlayerDataManager.get_inventory()

	# 4. 創建格子
	for instance_id in all_inventory_instances:
		var slot = inventory_slot_scene.instantiate()
		modal_card_grid.add_child(slot)
		slot.setup(instance_id)  # ✅ 傳遞 instance_id

		# 5. 連接點擊信號
		# ✅ 使用 lambda 捕獲 instance_id
		slot.slot_clicked.connect(func(_signal_instance_id, _signal_pos):
			_on_modal_card_clicked(instance_id, slot)
		)

		# 6. 標記已選中的卡片（✅ 真正支援重複角色！）
		var count = temp_team_card_ids.count(instance_id)
		if count == 0:
			slot.modulate = Color(1.0, 1.0, 1.0)  # 正常
		elif count == 1:
			slot.modulate = Color(0.7, 0.7, 0.7)  # 稍暗
		else:
			slot.modulate = Color(0.4, 0.4, 0.4)  # 很暗（多張）

func _on_modal_card_clicked(instance_id: String, slot_node: Control):
	"""在懸浮背包中點擊了一張卡片（接收 instance_id）"""

	# ✅ 真正支援重複角色！
	# 計算這張卡片實例在隊伍中出現的次數
	var count_in_team = temp_team_card_ids.count(instance_id)

	var card_id = PlayerDataManager.get_card_id_from_instance(instance_id)

	if count_in_team > 0:
		# 如果已經有這張實例 -> 移除它
		temp_team_card_ids.erase(instance_id)  # 只移除第一個匹配的
		print("從隊伍中移除 %s (instance_%s, 剩餘 %d 張)" % [card_id, instance_id, count_in_team - 1])
	else:
		# 如果沒有這張實例 -> 加入選擇
		if temp_team_card_ids.size() < Constants.MAX_TEAM_SIZE:
			temp_team_card_ids.append(instance_id)
			print("添加 %s (instance_%s) 到隊伍" % [card_id, instance_id])
		else:
			print("❌ 隊伍已滿！")

	# 更新視覺效果：根據數量調整透明度
	var new_count = temp_team_card_ids.count(instance_id)
	if new_count == 0:
		slot_node.modulate = Color(1.0, 1.0, 1.0)  # 正常
	elif new_count == 1:
		slot_node.modulate = Color(0.7, 0.7, 0.7)  # 稍暗
	else:
		slot_node.modulate = Color(0.4, 0.4, 0.4)  # 很暗（多張）

	# 刷新標題
	modal_header_label.text = "編輯隊伍 %s (%d/%d)" % [
		current_editing_team_id.replace("team_", ""),
		temp_team_card_ids.size(),
		Constants.MAX_TEAM_SIZE
	]

func _on_modal_confirm_pressed():
	"""點擊懸浮背包的「確認」按鈕"""
	print("儲存隊伍: %s" % current_editing_team_id)
	
	if temp_team_card_ids.is_empty():
		# 如果是空的，視同清空
		_on_clear_requested(current_editing_team_id)
	else:
		# 1. 建立一個新的 TeamData 物件
		var new_team = TeamData.new()
		new_team.team_id = current_editing_team_id
		# TODO: 之後可以讓玩家自訂隊伍名稱
		new_team.team_name = "我的隊伍 %s" % current_editing_team_id.replace("team_", "")
		
		# 2. 第一張卡片自動設為隊長
		new_team.leader_card_id = temp_team_card_ids[0]
		
		# 3. 剩下的卡片設為隊員
		if temp_team_card_ids.size() > 1:
			new_team.member_card_ids = temp_team_card_ids.slice(1)
			
		# 4. 儲存隊伍
		PlayerDataManager.save_team(current_editing_team_id, new_team)
		PlayerDataManager.save_data()

	# 5. 關閉視窗並刷新
	card_selector_modal.hide()
	create_team_rows()
	
	# 6. 清空暫存
	current_editing_team_id = ""
	temp_team_card_ids.clear()

func _on_modal_cancel_pressed():
	"""點擊懸浮背包的「取消」按鈕"""
	card_selector_modal.hide()
	current_editing_team_id = ""
	temp_team_card_ids.clear()

# ==================== 輸入處理 ====================

func _input(event: InputEvent):
	"""處理 ESC 鍵返回"""
	if event.is_action_pressed("ui_cancel"):  # ESC 鍵
		if card_selector_modal and card_selector_modal.visible:
			# 如果彈窗打開，先關閉彈窗
			_on_modal_cancel_pressed()
		else:
			# 正常返回
			_on_back_pressed()

# ==================== 導航 ====================
func _on_back_pressed():
	if is_selection_mode:
	# 從選擇模式返回關卡選擇
		GameManager.goto_stage_select()
	else:
	# 從管理模式返回主選單
		GameManager.goto_main_menu()
