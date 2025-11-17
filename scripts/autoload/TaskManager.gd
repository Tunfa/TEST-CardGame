# TaskManager.gd
# 任務管理器（Autoload 單例）
extends Node

# ==================== 信號 ====================
signal quest_started(quest_id: String)
signal quest_step_completed(quest_id: String, step_id: String)
signal quest_completed(quest_id: String)
signal quest_progress_updated(quest_id: String, current_step: int, total_steps: int)

# ==================== 數據 ====================
var quests_database: Array = []  # 所有任務的配置
var active_quests: Dictionary = {}  # 當前進行中的任務 {quest_id: quest_runtime_data}
var completed_quests: Array = []  # 已完成的任務ID列表
var selected_starter_card: String = ""  # 玩家選擇的起始卡片

# 對話框和選卡界面引用
var dialog_system_node: Node = null
var card_selection_overlay: Node = null

# JSON 配置文件路徑
const QUESTS_CONFIG_PATH = "res://data/config/quests.json"
const DIALOGS_CONFIG_PATH = "res://data/config/dialogs.json"

# 對話框配置數據
var dialogs_database: Dictionary = {}  # {dialog_id: dialog_data}

# ==================== 初始化 ====================
func _ready():
	print("📋 TaskManager 初始化完成")
	load_quests_config()
	load_dialogs_config()
	load_progress()  # ✅ 載入任務進度

	# 等待 PlayerDataManager 載入完成後再檢查自動啟動任務
	if PlayerDataManager.has_signal("data_loaded"):
		if not PlayerDataManager.data_loaded.is_connected(_on_player_data_loaded):
			PlayerDataManager.data_loaded.connect(_on_player_data_loaded)

	# 如果 PlayerDataManager 已經載入完成，直接檢查
	await get_tree().create_timer(0.5).timeout
	check_auto_start_quests()

func _on_player_data_loaded():
	"""PlayerDataManager 載入完成回調"""
	print("📋 PlayerDataManager 載入完成，檢查自動啟動任務")
	check_auto_start_quests()

# ==================== 配置載入 ====================
func load_quests_config():
	"""從 JSON 載入任務配置"""
	if not FileAccess.file_exists(QUESTS_CONFIG_PATH):
		push_error("❌ 找不到任務配置文件: " + QUESTS_CONFIG_PATH)
		return

	var file = FileAccess.open(QUESTS_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("❌ 無法打開任務配置文件")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("❌ JSON 解析錯誤: " + json.get_error_message())
		return

	var data = json.get_data()
	quests_database = data.get("quests", [])
	print("✅ 成功載入 %d 個任務配置" % quests_database.size())

func load_dialogs_config():
	"""從 JSON 載入對話框配置"""
	if not FileAccess.file_exists(DIALOGS_CONFIG_PATH):
		push_error("❌ 找不到對話框配置文件: " + DIALOGS_CONFIG_PATH)
		return

	var file = FileAccess.open(DIALOGS_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("❌ 無法打開對話框配置文件")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("❌ JSON 解析錯誤: " + json.get_error_message())
		return

	var data = json.get_data()
	var dialogs = data.get("dialogs", [])

	# 建立索引
	for dialog in dialogs:
		var dialog_id = dialog.get("dialog_id", "")
		if dialog_id != "":
			dialogs_database[dialog_id] = dialog

	print("✅ 成功載入 %d 個對話框配置" % dialogs_database.size())

func check_auto_start_quests():
	"""檢查並自動啟動任務"""
	# 延遲一幀，確保場景載入完成
	await get_tree().process_frame

	for quest_config in quests_database:
		if quest_config.get("auto_start", false):
			var quest_id = quest_config.get("quest_id", "")
			if quest_id != "" and quest_id not in active_quests and quest_id not in completed_quests:
				print("🎯 自動啟動任務: %s" % quest_id)
				start_quest(quest_id)

# ==================== 任務控制 ====================
func start_quest(quest_id: String) -> bool:
	"""啟動任務"""
	# 查找任務配置
	var quest_config = get_quest_config(quest_id)
	if quest_config.is_empty():
		push_error("❌ 找不到任務: " + quest_id)
		return false

	# 檢查是否已經在進行中
	if quest_id in active_quests:
		print("⚠️ 任務已在進行中: " + quest_id)
		return false

	# 檢查是否已完成
	if quest_id in completed_quests:
		print("⚠️ 任務已完成: " + quest_id)
		return false

	# 檢查解鎖條件
	if not check_quest_unlock_conditions(quest_config):
		print("⚠️ 任務未解鎖: " + quest_id)
		return false

	# 創建運行時數據
	var runtime_data = {
		"quest_id": quest_id,
		"current_step_index": 0,
		"completed_steps": [],
		"quest_config": quest_config
	}

	active_quests[quest_id] = runtime_data

	print("🎯 任務啟動: %s - %s" % [quest_id, quest_config.get("quest_name", "")])
	quest_started.emit(quest_id)

	# 處理第一步
	process_current_step(quest_id)

	return true

func process_current_step(quest_id: String):
	"""處理當前任務步驟"""
	if quest_id not in active_quests:
		return

	var runtime_data = active_quests[quest_id]
	var quest_config = runtime_data["quest_config"]
	var steps = quest_config.get("steps", [])
	var current_step_index = runtime_data["current_step_index"]

	if current_step_index >= steps.size():
		# 所有步驟完成，完成任務
		complete_quest(quest_id)
		return

	var current_step = steps[current_step_index]
	var step_id = current_step.get("step_id", "")

	print("📍 任務步驟: %s - %s (%d/%d)" % [quest_id, step_id, current_step_index + 1, steps.size()])

	# 執行步驟動作
	execute_step_actions(quest_id, current_step)

	# 顯示對話框（如果有）
	var dialog_id = current_step.get("dialog_id", "")
	if dialog_id != "":
		show_dialog(dialog_id, quest_id, step_id)

func execute_step_actions(quest_id: String, step_data: Dictionary):
	"""執行步驟動作"""
	var actions = step_data.get("actions", [])

	for action in actions:
		var action_type = action.get("type", "")

		match action_type:
			"show_card_selection":
				# 顯示卡片選擇界面
				var cards = action.get("cards", [])
				show_card_selection(cards, quest_id)
			"highlight_ui":
				# 高亮UI元素
				var target = action.get("target", "")
				var highlight_type = action.get("highlight_type", "red_flash")
				highlight_ui_element(target, highlight_type)

func complete_quest_step(quest_id: String):
	"""完成當前任務步驟"""
	if quest_id not in active_quests:
		return

	var runtime_data = active_quests[quest_id]
	var quest_config = runtime_data["quest_config"]
	var steps = quest_config.get("steps", [])
	var current_step_index = runtime_data["current_step_index"]

	if current_step_index >= steps.size():
		return

	var current_step = steps[current_step_index]
	var step_id = current_step.get("step_id", "")

	runtime_data["completed_steps"].append(step_id)
	runtime_data["current_step_index"] += 1

	print("✅ 步驟完成: %s - %s" % [quest_id, step_id])
	quest_step_completed.emit(quest_id, step_id)
	quest_progress_updated.emit(quest_id, runtime_data["current_step_index"], steps.size())

	# ✅ 保存進度
	save_progress()

	# 處理下一步（減少延遲以提升流暢度）
	await get_tree().create_timer(0.1).timeout
	process_current_step(quest_id)

func complete_quest(quest_id: String):
	"""完成任務"""
	if quest_id not in active_quests:
		return

	var runtime_data = active_quests[quest_id]
	var quest_config = runtime_data["quest_config"]

	# 發放獎勵
	var rewards = quest_config.get("rewards", {})
	grant_rewards(rewards)

	# 移除活動任務
	active_quests.erase(quest_id)
	completed_quests.append(quest_id)

	print("🎉 任務完成: %s - %s" % [quest_id, quest_config.get("quest_name", "")])
	quest_completed.emit(quest_id)

	# ✅ 保存進度
	save_progress()

	# 啟動下一個任務
	var next_quest = quest_config.get("next_quest", "")
	if next_quest != "":
		await get_tree().create_timer(1.0).timeout
		start_quest(next_quest)

func grant_rewards(rewards: Dictionary):
	"""發放獎勵"""
	var gold = rewards.get("gold", 0)
	var diamond = rewards.get("diamond", 0)
	var cards = rewards.get("cards", [])

	if gold > 0:
		PlayerDataManager.add_gold(gold)
		print("💰 獲得金幣: %d" % gold)

	if diamond > 0:
		PlayerDataManager.add_diamond(diamond)
		print("💎 獲得鑽石: %d" % diamond)

	for card_id in cards:
		PlayerDataManager.add_card(card_id)
		print("🎴 獲得卡片: %s" % card_id)

	if gold > 0 or diamond > 0 or cards.size() > 0:
		PlayerDataManager.save_data()

# ==================== 條件檢測 ====================
func check_quest_condition(quest_id: String, event_type: String, event_data: Dictionary = {}) -> bool:
	"""檢查任務條件是否滿足"""
	if quest_id not in active_quests:
		return false

	var runtime_data = active_quests[quest_id]
	var quest_config = runtime_data["quest_config"]
	var steps = quest_config.get("steps", [])
	var current_step_index = runtime_data["current_step_index"]

	if current_step_index >= steps.size():
		return false

	var current_step = steps[current_step_index]
	var conditions = current_step.get("conditions", {})

	var result = evaluate_condition(conditions, event_type, event_data)

	if result:
		complete_quest_step(quest_id)

	return result

func evaluate_condition(condition: Dictionary, event_type: String, event_data: Dictionary) -> bool:
	"""評估條件"""
	var condition_type = condition.get("type", "")

	match condition_type:
		"dialog_completed":
			# 對話完成條件
			var required_dialog = condition.get("dialog_id", "")
			return event_type == "dialog_completed" and event_data.get("dialog_id", "") == required_dialog

		"card_selected":
			# 卡片選擇條件
			if event_type != "card_selected":
				return false
			var valid_cards = condition.get("valid_cards", [])
			var selected_card = event_data.get("card_id", "")
			return selected_card in valid_cards

		"scene_entered":
			# 場景進入條件
			var required_scene = condition.get("scene_name", "")
			return event_type == "scene_entered" and event_data.get("scene_name", "") == required_scene

		"training_room_entered":
			# 訓練室進入條件
			var required_room = condition.get("room_id", "")
			return event_type == "training_room_entered" and event_data.get("room_id", "") == required_room

		"card_in_training":
			# 卡片在訓練中條件
			if event_type != "training_started":
				return false
			# 檢查起始卡片是否在訓練中
			return check_starter_card_in_training(event_data)

		"card_level_up":
			# 卡片升級條件
			if event_type != "card_leveled_up":
				return false
			var card_type = condition.get("card_type", "")
			var target_level = condition.get("target_level", 2)
			return check_card_level_condition(event_data, card_type, target_level)

		"and":
			# AND 條件組合
			var sub_conditions = condition.get("sub_conditions", [])
			for sub_cond in sub_conditions:
				if not evaluate_condition(sub_cond, event_type, event_data):
					return false
			return true

		"or":
			# OR 條件組合
			var sub_conditions = condition.get("sub_conditions", [])
			for sub_cond in sub_conditions:
				if evaluate_condition(sub_cond, event_type, event_data):
					return true
			return false

		_:
			return false

func check_starter_card_in_training(event_data: Dictionary) -> bool:
	"""檢查起始卡片是否在訓練中"""
	if selected_starter_card.is_empty():
		return false

	var teams = event_data.get("teams", [])
	for team in teams:
		for card_instance_id in team:
			var card_id = PlayerDataManager.get_card_id_from_instance(card_instance_id)
			if card_id == selected_starter_card:
				return true
	return false

func check_card_level_condition(event_data: Dictionary, card_type: String, target_level: int) -> bool:
	"""檢查卡片等級條件"""
	if card_type == "starter":
		# 檢查起始卡片
		var card_id = event_data.get("card_id", "")
		var new_level = event_data.get("new_level", 1)
		return card_id == selected_starter_card and new_level >= target_level
	return false

# ==================== 對話框系統 ====================
func show_dialog(dialog_id: String, quest_id: String = "", _step_id: String = ""):
	"""顯示對話框"""
	var dialog_data = dialogs_database.get(dialog_id, {})
	if dialog_data.is_empty():
		push_error("❌ 找不到對話框: " + dialog_id)
		return

	# 確保 choices 數組存在且不為空（如果原本為 null 或空，添加默認選項）
	if not dialog_data.has("choices") or dialog_data.get("choices", []).is_empty():
		dialog_data["choices"] = [{"text": "繼續", "action": "next"}]

	# 替換變量
	var content = dialog_data.get("content", "")
	if selected_starter_card != "":
		var card_data = DataManager.get_card(selected_starter_card)
		if card_data:
			content = content.replace("{card_name}", card_data.card_name)

	dialog_data["content"] = content

	# 創建對話框（如果不存在）
	if dialog_system_node == null:
		create_dialog_system()

	# 顯示對話框
	dialog_system_node.show_dialog(dialog_data)

	# 連接信號（如果需要追蹤完成）
	if quest_id != "":
		if not dialog_system_node.choice_selected.is_connected(_on_dialog_choice_selected):
			dialog_system_node.choice_selected.connect(_on_dialog_choice_selected)

func create_dialog_system():
	"""創建對話框系統節點"""
	var StoryDialog = load("res://scripts/ui/StoryDialog.gd")

	# ✅ 使用 CanvasLayer 確保對話框永遠在最上層（一勞永逸的方法）
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "DialogCanvasLayer"
	canvas_layer.layer = 100  # 高層級，確保在所有遊戲 UI 之上
	get_tree().root.add_child(canvas_layer)

	# 創建對話框節點並添加到 CanvasLayer
	dialog_system_node = Control.new()
	dialog_system_node.name = "StoryDialogSystem"
	dialog_system_node.set_script(StoryDialog)
	dialog_system_node.set_anchors_preset(Control.PRESET_FULL_RECT)  # 全屏
	# ✅ 使用 PASS 讓事件傳遞給子節點，而不是 IGNORE（IGNORE 會導致子節點無法接收事件）
	dialog_system_node.mouse_filter = Control.MOUSE_FILTER_PASS

	canvas_layer.add_child(dialog_system_node)
	dialog_system_node._ready()  # 調用 _ready() 創建 UI

	print("✅ 對話框系統已創建（使用 CanvasLayer layer=100）")

func _on_dialog_choice_selected(action: String, _choice_index: int):
	"""對話選擇回調"""
	print("📖 對話選擇動作: %s" % action)

	match action:
		"show_card_selection":
			# 顯示卡片選擇（在對話框中觸發）
			show_card_selection_for_tutorial()
		"highlight_training_area":
			# 高亮訓練區域
			highlight_ui_element("training_area", "red_flash")
			# 完成當前步驟
			for quest_id in active_quests.keys():
				check_quest_condition(quest_id, "dialog_completed", {"dialog_id": "training_guide_001"})
			# ✅ 立即關閉對話框（不播放動畫），避免場景切換時的 Tween 錯誤
			if dialog_system_node:
				dialog_system_node.close_dialog(true)
		"claim_reward":
			# 領取獎勵（在對話框中觸發）
			print("🎁 處理 claim_reward action")
			print("   當前活動任務: %s" % str(active_quests.keys()))
			for quest_id in active_quests.keys():
				print("   檢查任務: %s" % quest_id)
				var result = check_quest_condition(quest_id, "dialog_completed", {"dialog_id": "training_complete"})
				print("   條件檢查結果: %s" % str(result))
			# 關閉對話框
			if dialog_system_node:
				print("   關閉對話框")
				dialog_system_node.close_dialog()
			else:
				print("   ❌ dialog_system_node 為 null！")

	# 檢查是否完成對話
	if action == "next" or action == "close":
		# 通知所有活動任務對話已完成
		var dialog_id = dialog_system_node.current_dialog_data.get("dialog_id", "")
		for quest_id in active_quests.keys():
			check_quest_condition(quest_id, "dialog_completed", {"dialog_id": dialog_id})

# ==================== 卡片選擇系統 ====================
# 卡片選擇器實例
var card_selector_node: Node = null

func show_card_selection(cards: Array, _quest_id: String):
	"""顯示卡片選擇界面"""
	print("🎴 顯示卡片選擇: %s" % str(cards))

	# 創建卡片選擇器（如果不存在）
	if card_selector_node == null:
		create_card_selector()

	# 顯示選擇器
	card_selector_node.show_selector(cards, "選擇你的起始道侶")

func show_card_selection_for_tutorial():
	"""新手教程的卡片選擇"""
	var starter_cards = ["001", "002", "003", "004", "005"]
	show_card_selection(starter_cards, "tutorial_001")

func create_card_selector():
	"""創建卡片選擇器節點"""
	var CardSelector = load("res://scripts/ui/CardSelector.gd")

	# ✅ 使用 CanvasLayer 確保卡片選擇器在對話框之上
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "CardSelectorCanvasLayer"
	canvas_layer.layer = 200  # 高於對話框的 layer (100)
	get_tree().root.add_child(canvas_layer)

	# 創建卡片選擇器節點並添加到 CanvasLayer
	card_selector_node = Control.new()
	card_selector_node.name = "CardSelectorSystem"
	card_selector_node.set_script(CardSelector)
	card_selector_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_selector_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	canvas_layer.add_child(card_selector_node)
	card_selector_node._ready()  # 調用 _ready() 創建 UI

	# 連接信號
	card_selector_node.card_selected.connect(_on_card_selected)
	card_selector_node.selector_closed.connect(_on_card_selector_closed)

	print("✅ 卡片選擇器已創建（使用 CanvasLayer layer=200）")

func _on_card_selected(card_id: String):
	"""卡片被選擇"""
	print("✅ 選擇起始卡片: %s" % card_id)

	# 添加卡片到背包
	PlayerDataManager.add_card(card_id)
	selected_starter_card = card_id

	# ✅ 保存進度
	save_progress()

	# 通知任務系統
	for quest_id in active_quests.keys():
		check_quest_condition(quest_id, "card_selected", {"card_id": card_id})

func _on_card_selector_closed():
	"""卡片選擇器關閉"""
	print("🎴 卡片選擇器已關閉")

# ==================== UI 高亮系統 ====================
func highlight_ui_element(target: String, highlight_type: String):
	"""高亮UI元素"""
	print("✨ 高亮UI: %s (類型: %s)" % [target, highlight_type])

	# 獲取目標節點
	var target_node = get_highlight_target_node(target)
	if target_node == null:
		print("⚠️ 找不到高亮目標: %s" % target)
		return

	# 應用高亮效果
	apply_highlight_effect(target_node, highlight_type)

func get_highlight_target_node(target: String) -> Control:
	"""智能查找高亮目標節點

	支援多種查找方式（優先級從高到低）：
	1. 透過元數據 (metadata) "highlight_id" 查找
	2. 透過組 (group) "highlight_" + target 查找
	3. 透過節點名稱遞歸查找
	4. 舊版硬編碼路徑（向後兼容）
	"""
	var current_scene = get_tree().current_scene
	if current_scene == null:
		print("⚠️ current_scene 為 null")
		return null

	print("🔍 開始查找高亮目標: %s" % target)

	# 策略 1: 透過元數據查找
	var node = find_node_by_metadata(current_scene, "highlight_id", target)
	if node:
		print("✅ 透過元數據找到節點: %s" % node.name)
		return node

	# 策略 2: 透過組查找
	var group_name = "highlight_" + target
	if get_tree().has_group(group_name):
		var nodes = get_tree().get_nodes_in_group(group_name)
		if nodes.size() > 0:
			print("✅ 透過組找到節點: %s (組: %s)" % [nodes[0].name, group_name])
			return nodes[0]

	# 策略 3: 透過節點名稱遞歸查找
	node = find_node_by_name(current_scene, target)
	if node:
		print("✅ 透過名稱遞歸找到節點: %s" % node.name)
		return node

	# 策略 4: 舊版硬編碼路徑（向後兼容）
	match target:
		"training_area":
			if current_scene.has_node("MapContainer/MapArea/TrainingArea"):
				print("✅ 透過硬編碼路徑找到節點: training_area")
				return current_scene.get_node("MapContainer/MapArea/TrainingArea")
		"back_button":
			if current_scene.has_node("MarginContainer/VBoxContainer/TopBar/BackButton"):
				print("✅ 透過硬編碼路徑找到節點: back_button")
				return current_scene.get_node("MarginContainer/VBoxContainer/TopBar/BackButton")

	print("❌ 找不到高亮目標: %s" % target)
	return null

func find_node_by_metadata(root: Node, meta_key: String, meta_value: String) -> Control:
	"""遞歸查找具有指定元數據的節點"""
	if root == null:
		return null

	# 檢查當前節點
	if root is Control and root.has_meta(meta_key):
		if root.get_meta(meta_key) == meta_value:
			return root

	# 遞歸檢查子節點
	for child in root.get_children():
		var result = find_node_by_metadata(child, meta_key, meta_value)
		if result:
			return result

	return null

func find_node_by_name(root: Node, node_name: String) -> Control:
	"""遞歸查找具有指定名稱的節點"""
	if root == null:
		return null

	# 檢查當前節點
	if root is Control and root.name == node_name:
		return root

	# 遞歸檢查子節點
	for child in root.get_children():
		var result = find_node_by_name(child, node_name)
		if result:
			return result

	return null

func apply_highlight_effect(node: Control, effect_type: String):
	"""應用高亮效果"""
	match effect_type:
		"red_flash":
			# 紅色閃爍邊框
			start_red_flash_effect(node)

func start_red_flash_effect(node: Control):
	"""開始紅色閃爍效果"""
	# 檢查節點是否有效
	if node == null or not is_instance_valid(node):
		print("⚠️ 無法應用高亮效果：節點無效")
		return

	# 如果已經有 tween，先停止它
	if node.has_meta("highlight_tween"):
		var old_tween = node.get_meta("highlight_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()
		node.remove_meta("highlight_tween")

	# 創建一個循環動畫
	var tween = create_tween()
	# ✅ 使用 bind_node 綁定到節點，當節點被釋放時自動停止 Tween
	tween.bind_node(node)
	tween.set_loops(-1)  # ✅ 在 Godot 4.4 中使用 -1 表示無限循環
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# 交替改變節點的 modulate 屬性
	tween.tween_property(node, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.5)
	tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)

	# 保存 tween 引用以便停止
	node.set_meta("highlight_tween", tween)

	print("✨ 開始高亮效果：%s" % node.name)

func stop_highlight_effect(node: Control):
	"""停止高亮效果"""
	if node.has_meta("highlight_tween"):
		var tween = node.get_meta("highlight_tween")
		tween.kill()
		node.remove_meta("highlight_tween")
		node.modulate = Color(1.0, 1.0, 1.0, 1.0)

# ==================== 工具方法 ====================
func get_quest_config(quest_id: String) -> Dictionary:
	"""獲取任務配置"""
	for quest in quests_database:
		if quest.get("quest_id", "") == quest_id:
			return quest
	return {}

func notify_event(event_type: String, event_data: Dictionary = {}):
	"""通知事件（用於外部觸發任務進度）"""
	print("📢 事件通知: %s, 數據: %s" % [event_type, str(event_data)])

	# 檢查所有活動任務
	for quest_id in active_quests.keys():
		check_quest_condition(quest_id, event_type, event_data)

# ==================== 強制任務系統 ====================
func has_mandatory_quest() -> bool:
	"""檢查是否有進行中的強制任務"""
	for quest_id in active_quests.keys():
		var runtime_data = active_quests[quest_id]
		var quest_config = runtime_data["quest_config"]
		if quest_config.get("is_mandatory", false):
			return true
	return false

func get_current_mandatory_quest() -> Dictionary:
	"""獲取當前強制任務"""
	for quest_id in active_quests.keys():
		var runtime_data = active_quests[quest_id]
		var quest_config = runtime_data["quest_config"]
		if quest_config.get("is_mandatory", false):
			return runtime_data
	return {}

func get_current_mandatory_step() -> Dictionary:
	"""獲取當前強制任務的步驟"""
	var mandatory_quest = get_current_mandatory_quest()
	if mandatory_quest.is_empty():
		return {}

	var quest_config = mandatory_quest["quest_config"]
	var steps = quest_config.get("steps", [])
	var current_step_index = mandatory_quest["current_step_index"]

	if current_step_index < steps.size():
		return steps[current_step_index]
	return {}

func is_action_allowed(action_type: String, action_data: Dictionary = {}) -> bool:
	"""檢查操作是否被允許（強制任務限制）"""
	# 如果沒有強制任務，允許所有操作
	if not has_mandatory_quest():
		return true

	# 獲取當前步驟的允許操作
	var current_step = get_current_mandatory_step()
	if current_step.is_empty():
		return true

	var allowed_actions = current_step.get("allowed_actions", {})
	var allowed_type = allowed_actions.get("type", "all")

	match allowed_type:
		"all":
			# 允許所有操作
			return true
		"dialog_only":
			# 只允許對話相關操作
			return action_type == "dialog" or action_type == "dialog_choice"
		"specific_ui":
			# 只允許特定 UI 元素
			if action_type == "navigate_ui":
				var allowed_targets = allowed_actions.get("allowed_targets", [])
				var target = action_data.get("target", "")
				return target in allowed_targets
			return false
		"training_only":
			# 只允許訓練相關操作
			return action_type in ["training_start", "training_card_select", "training_claim", "navigate_ui"]
		_:
			return false

func show_mandatory_quest_message():
	"""顯示強制任務提示"""
	var current_step = get_current_mandatory_step()
	if current_step.is_empty():
		return

	var step_desc = current_step.get("step_desc", "請完成當前任務")
	GameManager.show_message("任務提示", "⚠️ 請先完成任務：%s" % step_desc)

# ==================== 任務解鎖條件 ====================
func check_quest_unlock_conditions(quest_config: Dictionary) -> bool:
	"""檢查任務解鎖條件"""
	var unlock_conditions = quest_config.get("unlock_conditions", {})

	# 如果沒有解鎖條件，直接解鎖
	if unlock_conditions.is_empty():
		return true

	var condition_type = unlock_conditions.get("type", "")

	match condition_type:
		"quest_completed":
			# 需要完成特定任務
			var required_quests = unlock_conditions.get("required_quests", [])
			for required_quest_id in required_quests:
				if required_quest_id not in completed_quests:
					return false
			return true
		"player_level":
			# 需要玩家等級
			var required_level = unlock_conditions.get("required_level", 1)
			return PlayerDataManager.player_level >= required_level
		"card_count":
			# 需要卡片數量
			var required_count = unlock_conditions.get("required_count", 1)
			var card_count = PlayerDataManager.get_all_card_instances().size()
			return card_count >= required_count
		_:
			return true

func is_quest_unlocked(quest_id: String) -> bool:
	"""檢查任務是否已解鎖"""
	var quest_config = get_quest_config(quest_id)
	if quest_config.is_empty():
		return false
	return check_quest_unlock_conditions(quest_config)

# ==================== 任務進度保存/載入 ====================
func save_progress():
	"""保存任務進度到文件"""
	var save_data = {
		"active_quests": {},
		"completed_quests": completed_quests,
		"selected_starter_card": selected_starter_card
	}

	# 保存活躍任務的進度
	for quest_id in active_quests.keys():
		var runtime_data = active_quests[quest_id]
		save_data["active_quests"][quest_id] = {
			"current_step_index": runtime_data["current_step_index"],
			"started_at": runtime_data.get("started_at", 0)
		}

	# 轉換為 JSON
	var json_string = JSON.stringify(save_data, "\t")

	# 寫入文件
	var file_path = "user://task_progress.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("✅ 任務進度已保存: %s" % file_path)
	else:
		push_error("❌ 無法保存任務進度到: %s" % file_path)

func load_progress():
	"""從文件載入任務進度"""
	var file_path = "user://task_progress.json"

	if not FileAccess.file_exists(file_path):
		print("📋 沒有找到任務進度文件，使用初始狀態")
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("❌ 無法讀取任務進度文件: %s" % file_path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("❌ 任務進度 JSON 解析錯誤: " + json.get_error_message())
		return

	var save_data = json.get_data()

	# 恢復已完成的任務
	if save_data.has("completed_quests"):
		completed_quests = save_data["completed_quests"]
		print("📋 已載入 %d 個已完成任務" % completed_quests.size())

	# 恢復選擇的起始卡片
	if save_data.has("selected_starter_card"):
		selected_starter_card = save_data["selected_starter_card"]
		if selected_starter_card != "":
			print("📋 已恢復起始卡片選擇: %s" % selected_starter_card)

	# 恢復活躍任務（需要在配置載入後）
	if save_data.has("active_quests"):
		for quest_id in save_data["active_quests"].keys():
			var saved_quest = save_data["active_quests"][quest_id]
			var quest_config = get_quest_config(quest_id)

			if not quest_config.is_empty():
				# 重建運行時數據
				active_quests[quest_id] = {
					"quest_id": quest_id,
					"quest_config": quest_config,
					"current_step_index": saved_quest["current_step_index"],
					"completed_steps": [],  # ✅ 初始化 completed_steps
					"started_at": saved_quest.get("started_at", 0)
				}
				print("📋 已恢復任務: %s (步驟 %d)" % [quest_id, saved_quest["current_step_index"]])
			else:
				push_error("❌ 找不到任務配置: %s，跳過恢復" % quest_id)

	print("✅ 任務進度載入完成")

	# ✅ 重新觸發所有活躍任務的當前步驟（恢復對話和 UI 高亮）
	# 延遲執行，確保場景已經載入
	await get_tree().create_timer(0.5).timeout
	for quest_id in active_quests.keys():
		print("🔄 恢復任務步驟: %s" % quest_id)
		process_current_step(quest_id)
