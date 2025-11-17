# QuestScreen.gd
# 任務查看界面
extends Control

# ==================== 節點引用 ====================
@onready var back_button = $VBoxContainer/TopBar/HBoxContainer/BackButton
@onready var quest_list_container = $VBoxContainer/ScrollContainer/MarginContainer/QuestListContainer

# ==================== 初始化 ====================
func _ready():
	back_button.pressed.connect(_on_back_pressed)
	# 延迟调用 update_quest_list，确保所有节点都已初始化
	call_deferred("update_quest_list")

# ==================== 更新任務列表 ====================
func update_quest_list():
	"""更新任務列表"""
	# 检查节点是否存在
	if quest_list_container == null:
		push_error("❌ quest_list_container 节点不存在！")
		return

	# 清空現有列表
	for child in quest_list_container.get_children():
		child.queue_free()

	# 獲取活動任務
	var active_quests = TaskManager.active_quests
	var completed_quests = TaskManager.completed_quests

	# 顯示活動任務
	if active_quests.size() > 0:
		var active_label = Label.new()
		active_label.text = "進行中的任務"
		active_label.add_theme_font_size_override("font_size", 24)
		active_label.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
		quest_list_container.add_child(active_label)

		for quest_id in active_quests.keys():
			var quest_runtime = active_quests[quest_id]
			var quest_config = quest_runtime["quest_config"]
			create_quest_item(quest_config, quest_runtime, true)
	else:
		var no_quest_label = Label.new()
		no_quest_label.text = "目前沒有進行中的任務"
		no_quest_label.add_theme_font_size_override("font_size", 20)
		no_quest_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		quest_list_container.add_child(no_quest_label)

	# 添加分隔線
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 20)
	quest_list_container.add_child(separator)

	# 顯示已完成任務
	var completed_label = Label.new()
	completed_label.text = "已完成的任務 (%d)" % completed_quests.size()
	completed_label.add_theme_font_size_override("font_size", 24)
	completed_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 1))
	quest_list_container.add_child(completed_label)

	if completed_quests.size() > 0:
		for quest_id in completed_quests:
			var quest_config = TaskManager.get_quest_config(quest_id)
			if not quest_config.is_empty():
				create_quest_item(quest_config, {}, false)

func create_quest_item(quest_config: Dictionary, quest_runtime: Dictionary, is_active: bool):
	"""創建任務項目"""
	var quest_panel = PanelContainer.new()
	quest_panel.custom_minimum_size = Vector2(0, 120)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	quest_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	# 任務名稱
	var name_label = Label.new()
	var quest_name = quest_config.get("quest_name", "未命名任務")
	name_label.text = "📋 %s" % quest_name
	name_label.add_theme_font_size_override("font_size", 22)
	if is_active:
		name_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	else:
		name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(name_label)

	# 任務描述
	var desc_label = Label.new()
	desc_label.text = quest_config.get("quest_desc", "")
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# 進度條（僅活動任務）
	if is_active:
		var progress_hbox = HBoxContainer.new()
		vbox.add_child(progress_hbox)

		var current_step = quest_runtime.get("current_step_index", 0)
		var total_steps = quest_config.get("steps", []).size()

		var progress_label = Label.new()
		progress_label.text = "進度: %d / %d" % [current_step, total_steps]
		progress_label.add_theme_font_size_override("font_size", 16)
		progress_hbox.add_child(progress_label)

		# 當前步驟提示
		if current_step < total_steps:
			var steps = quest_config.get("steps", [])
			if current_step < steps.size():
				var current_step_data = steps[current_step]
				var step_desc = current_step_data.get("step_desc", "")
				if step_desc != "":
					var step_label = Label.new()
					step_label.text = "→ %s" % step_desc
					step_label.add_theme_font_size_override("font_size", 16)
					step_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1, 1))
					vbox.add_child(step_label)

	quest_list_container.add_child(quest_panel)

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
