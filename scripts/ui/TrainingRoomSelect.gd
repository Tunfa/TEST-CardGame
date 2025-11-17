# TrainingRoomSelect.gd
# 訓練室選擇界面 - 顯示所有可用的訓練室
extends Control

# ==================== 節點引用 ====================
@onready var back_button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var room_list = $MarginContainer/VBoxContainer/ScrollContainer/RoomList

# ==================== 數據 ====================
var training_rooms: Array = []

# ==================== 初始化 ====================
func _ready():
	back_button.pressed.connect(_on_back_pressed)
	load_training_rooms()
	update_ui()

	# 🎯 通知任務系統：進入訓練選擇界面
	TaskManager.notify_event("scene_entered", {"scene_name": "training_select"})

# ==================== 數據載入 ====================
func load_training_rooms():
	"""從 JSON 載入訓練室配置"""
	var file_path = "res://data/config/training_rooms.json"
	print("📂 正在載入訓練室配置: %s" % file_path)

	if not FileAccess.file_exists(file_path):
		push_error("❌ 找不到訓練室配置文件: " + file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("❌ 無法打開訓練室配置文件")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("❌ JSON 解析錯誤: " + json.get_error_message())
		return

	var data = json.get_data()
	training_rooms = data.get("training_rooms", [])
	print("✅ 成功載入 %d 個訓練室" % training_rooms.size())

# ==================== UI 更新 ====================
func update_ui():
	"""更新界面"""
	print("🎨 開始更新訓練室列表...")

	# 清空現有按鈕
	for child in room_list.get_children():
		child.queue_free()

	# 創建訓練室按鈕
	for room in training_rooms:
		create_room_button(room)
	print("✅ UI 更新完成")

func create_room_button(room_data: Dictionary):
	"""創建訓練室按鈕"""
	var room_id = room_data.get("room_id", "")
	var room_name = room_data.get("room_name", "未命名")
	var room_desc = room_data.get("room_desc", "")
	var room_icon = room_data.get("room_icon", "📚")
	var training_time = room_data.get("training_time", 30)
	var exp_reward = room_data.get("exp_reward", 100)
	var max_teams = room_data.get("max_teams", 1)
	var unlock_conditions = room_data.get("unlock_conditions", {})
	var is_unlocked_by_default = room_data.get("is_unlocked_by_default", false)

	# 檢查是否解鎖
	var is_unlocked = check_room_unlocked(room_id, unlock_conditions, is_unlocked_by_default)

	# 創建按鈕容器
	var button_container = PanelContainer.new()
	button_container.name = "training_room_" + room_id  # 節點名稱（策略3）
	button_container.custom_minimum_size = Vector2(0, 150)

	# ✅ 設置元數據以便任務系統智能查找（策略1 - 最高優先級）
	button_container.set_meta("highlight_id", "training_room_" + room_id)

	var button = Button.new()
	button.name = "RoomButton"
	button.custom_minimum_size = Vector2(0, 150)
	#button.disabled = !is_unlocked

	# 組裝按鈕文字
	var status_text = ""
	if not is_unlocked:
		status_text = " 🔒 未解鎖(點擊解鎖)"
		var unlock_text = get_unlock_text(unlock_conditions)
		if unlock_text != "":
			status_text += "\n" + unlock_text

	var button_text = "%s %s%s\n%s\n" % [room_icon, room_name, status_text, room_desc]
	button_text += "⏱️ 訓練時間: %d秒  |  ✨ 經驗值: %d  |  👥 同時訓練: %d隊" % [training_time, exp_reward, max_teams]

	button.text = button_text
	button.add_theme_font_size_override("font_size", 20)

	# 綁定信號
	if is_unlocked:
		button.pressed.connect(_on_room_pressed.bind(room_data))
	else:
		button.modulate = Color(0.6, 0.6, 0.6)
		button.pressed.connect(_on_locked_room_pressed.bind(room_data))

	button_container.add_child(button)
	room_list.add_child(button_container)

func check_room_unlocked(room_id: String, unlock_conditions: Dictionary, is_unlocked_by_default: bool) -> bool:
	"""檢查訓練室是否解鎖"""
	# 檢查玩家數據中是否已解鎖
	if PlayerDataManager.is_training_room_unlocked(room_id):
		return true

	# 默認解鎖的訓練室
	if is_unlocked_by_default:
		return true

	var unlock_type = unlock_conditions.get("type", "default")

	match unlock_type:
		"default":
			return true
		"stage":
			var required_stage = unlock_conditions.get("required_stage", "")
			if required_stage != "":
				return PlayerDataManager.is_stage_completed(required_stage)
			return false
		_:
			# 金幣和鑽石解鎖需要玩家手動解鎖
			return false

func get_unlock_text(unlock_conditions: Dictionary) -> String:
	"""獲取解鎖條件文字"""
	var unlock_type = unlock_conditions.get("type", "default")

	match unlock_type:
		"gold":
			var cost = unlock_conditions.get("cost_gold", 0)
			return "需要: %d 金幣解鎖" % cost
		"diamond":
			var cost = unlock_conditions.get("cost_diamond", 0)
			return "需要: %d 鑽石解鎖" % cost
		"stage":
			var required_stage = unlock_conditions.get("required_stage", "")
			return "需要完成關卡: %s" % required_stage
		_:
			return ""

# ==================== 輸入處理 ====================

func _input(event: InputEvent):
	"""處理 ESC 鍵返回"""
	if event.is_action_pressed("ui_cancel"):  # ESC 鍵
		_on_back_pressed()

# ==================== 按鈕回調 ====================
func _on_back_pressed():
	"""返回主選單"""
	print("🔙 返回主選單")
	GameManager.goto_main_menu()

func _on_room_pressed(room_data: Dictionary):
	"""訓練室被點擊（已解鎖）"""
	var room_id = room_data.get("room_id", "")
	var room_name = room_data.get("room_name", "")

	print("📖 進入訓練室: %s (%s)" % [room_name, room_id])

	# 跳轉到訓練界面
	GameManager.goto_training(room_data)

func _on_locked_room_pressed(room_data: Dictionary):
	"""點擊了未解鎖的訓練室"""
	var unlock_conditions = room_data.get("unlock_conditions", {})
	var unlock_type = unlock_conditions.get("type", "default")

	match unlock_type:
		"gold":
			var cost = unlock_conditions.get("cost_gold", 0)
			show_unlock_confirm_dialog(room_data, "金幣", cost)
		"diamond":
			var cost = unlock_conditions.get("cost_diamond", 0)
			show_unlock_confirm_dialog(room_data, "鑽石", cost)
		_:
			GameManager.show_message("未解鎖", get_unlock_text(unlock_conditions))

func show_unlock_confirm_dialog(room_data: Dictionary, currency_type: String, cost: int):
	"""顯示解鎖確認對話框"""
	var room_id = room_data.get("room_id", "")
	var room_name = room_data.get("room_name", "")
	var unlock_conditions = room_data.get("unlock_conditions", {})

	# 載入自定義對話框
	var CustomDialog = load("res://scripts/ui/CustomDialog.gd")
	var dialog = CustomDialog.new()

	# 獲取當前貨幣
	var current_currency = PlayerDataManager.get_gold() if currency_type == "金幣" else PlayerDataManager.get_diamond()
	var message = "是否花費 %d %s 解鎖 %s？\n\n當前%s: %d" % [cost, currency_type, room_name, currency_type, current_currency]

	# 設置對話框
	var buttons = [
		{"text": "取消", "action": "cancel"},
		{"text": "確認解鎖", "action": "unlock"}
	]
	dialog.setup_choice_dialog("解鎖訓練室", message, buttons)

	# 連接信號
	dialog.button_pressed.connect(func(action):
		if action == "unlock":
			# 嘗試解鎖
			var cost_gold = unlock_conditions.get("cost_gold", 0) if currency_type == "金幣" else 0
			var cost_diamond = unlock_conditions.get("cost_diamond", 0) if currency_type == "鑽石" else 0

			if PlayerDataManager.unlock_training_room(room_id, cost_gold, cost_diamond):
				# 解鎖成功，刷新UI
				await get_tree().create_timer(0.1).timeout
				GameManager.show_message("解鎖成功", "成功解鎖 %s！" % room_name)
				update_ui()
			else:
				# 解鎖失敗
				await get_tree().create_timer(0.1).timeout
				GameManager.show_message("解鎖失敗", "%s不足！" % currency_type)
	)

	# 顯示對話框
	get_tree().root.add_child(dialog)
	dialog.show_dialog()
