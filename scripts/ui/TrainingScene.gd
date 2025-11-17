# TrainingScene.gd
# 訓練界面 - 完全獨立的訓練系统
extends Control

# ==================== 節點引用 ====================
@onready var back_button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var title_label = $MarginContainer/VBoxContainer/TopBar/TitleLabel
@onready var exp_label = $MarginContainer/VBoxContainer/InfoPanel/HBoxContainer/ExpLabel
@onready var time_label = $MarginContainer/VBoxContainer/InfoPanel/HBoxContainer/TimeLabel
@onready var teams_label = $MarginContainer/VBoxContainer/InfoPanel/HBoxContainer/TeamsLabel
@onready var training_teams_list = $MarginContainer/VBoxContainer/ScrollContainer/TrainingTeamsList
@onready var start_button = $MarginContainer/VBoxContainer/BottomBar/StartTrainingButton
@onready var card_selector_modal = $CardSelectorModal
@onready var card_grid = $CardSelectorModal/ModalPanel/MarginContainer/VBoxContainer/InventoryScroll/CardGridContainer
@onready var selector_header = $CardSelectorModal/ModalPanel/MarginContainer/VBoxContainer/HeaderLabel
@onready var confirm_button = $CardSelectorModal/ModalPanel/MarginContainer/VBoxContainer/ButtonHBox/ConfirmButton
@onready var cancel_button = $CardSelectorModal/ModalPanel/MarginContainer/VBoxContainer/ButtonHBox/CancelButton

# ==================== 訓練室數據 ====================
var room_data: Dictionary = {}
var training_time: int = 30
var exp_reward: int = 300
var max_teams: int = 1

# ==================== 訓練隊伍 ====================
# training_teams[team_index] = [card_instance_id, ...]
var training_teams: Array = []
var team_rows: Array = []  # TrainingTeamRow instances

# ==================== 訓練狀態 ====================
enum TrainingState {
	IDLE,
	TRAINING,
	COMPLETED
}

var current_state: TrainingState = TrainingState.IDLE
var remaining_time: float = 0.0
var timer: Timer = null

# ==================== 卡片選擇器 ====================
var current_editing_team_index: int = -1
var selected_cards_for_edit: Array = []

# ==================== 初始化 ====================
func _ready():
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	confirm_button.pressed.connect(_on_selector_confirm_pressed)
	cancel_button.pressed.connect(_on_selector_cancel_pressed)

	# 創建計時器（用於UI更新）
	timer = Timer.new()
	timer.timeout.connect(_on_timer_tick)
	add_child(timer)
	timer.start(1.0)  # 每秒更新一次UI

	# 從 GameManager 獲取訓練室數據
	if GameManager.current_training_room.size() > 0:
		setup(GameManager.current_training_room)
	else:
		setup_with_test_data()

	# ✅ 檢查是否有進行中的訓練
	check_active_training()

func setup(room: Dictionary):
	"""設定訓練室"""
	room_data = room
	training_time = room.get("training_time", 30)
	exp_reward = room.get("exp_reward", 300)
	max_teams = room.get("max_teams", 1)

	# 初始化訓練隊伍（如果沒有進行中的訓練）
	if not PlayerDataManager.is_training_active():
		training_teams.clear()
		for i in range(max_teams):
			training_teams.append([])
	else:
		# 從進行中的訓練恢復隊伍
		var active_training = PlayerDataManager.get_active_training()
		if active_training.room_id == room_data.get("room_id", ""):
			training_teams = active_training.teams.duplicate(true)

	update_ui()

	# 🎯 通知任務系統：進入訓練場景
	TaskManager.notify_event("scene_entered", {"scene_name": "training"})
	# 🎯 通知任務系統：進入訓練室
	TaskManager.notify_event("training_room_entered", {"room_id": room_data.get("room_id", "")})

	print("📍 任務系統通知：scene_entered (training) + training_room_entered (%s)" % room_data.get("room_id", ""))

func setup_with_test_data():
	"""使用测试數據設定"""
	room_data = {
		"room_id": "TR_001",
		"room_name": "基本訓練室",
		"room_icon": "📚",
		"training_time": 30,
		"exp_reward": 300,
		"max_teams": 1
	}
	setup(room_data)

# ==================== UI 更新 ====================
func update_ui():
	"""更新界面"""
	var room_icon = room_data.get("room_icon", "📚")
	var room_name = room_data.get("room_name", "訓練室")
	title_label.text = "%s %s" % [room_icon, room_name]

	exp_label.text = "✨ 經驗值: %d" % exp_reward
	time_label.text = "⏱️ 訓練時間: %d秒" % training_time
	teams_label.text = "👥 訓練隊伍: %d" % max_teams

	update_training_teams()
	update_start_button()

func update_training_teams():
	"""更新訓練隊伍列表"""
	# 清空现有行
	for row in team_rows:
		row.queue_free()
	team_rows.clear()

	# 加载 TrainingTeamRow 场景
	var team_row_scene = load("res://scenes/training/TrainingTeamRow.tscn")

	# 創建訓練隊伍行
	for i in range(max_teams):
		var row = team_row_scene.instantiate()
		training_teams_list.add_child(row)
		team_rows.append(row)

		# 設定數據（安全訪問，如果 training_teams 太短則用空陣列）
		var team_data = training_teams[i] if i < training_teams.size() else []
		row.setup(i, team_data)

		# 連接信号
		row.edit_team_requested.connect(_on_team_row_edit_requested)
		row.slot_clicked.connect(_on_team_row_slot_clicked)
		row.card_removed.connect(_on_team_row_card_removed)
		row.team_cleared.connect(_on_team_row_cleared)

func update_start_button():
	"""更新開始按鈕状态"""
	match current_state:
		TrainingState.IDLE:
			start_button.text = "開始訓練"
			start_button.disabled = false
		TrainingState.TRAINING:
			start_button.text = "訓練中 (%ds)" % int(remaining_time)
			start_button.disabled = true
		TrainingState.COMPLETED:
			start_button.text = "接收獎勵"
			start_button.disabled = false

# ==================== 隊伍行回调 ====================
func _on_team_row_edit_requested(team_index: int):
	"""編輯整个隊伍"""
	print("✏️ 編輯訓練隊伍 %d" % team_index)
	current_editing_team_index = team_index
	selected_cards_for_edit = training_teams[team_index].duplicate()
	open_card_selector()

func _on_team_row_slot_clicked(team_index: int, slot_index: int):
	"""點擊槽位"""
	# ✅ 檢查強制任務限制
	if not TaskManager.is_action_allowed("training_card_select"):
		TaskManager.show_mandatory_quest_message()
		return

	print("👆 點擊槽位 [隊伍%d, 槽位%d]" % [team_index, slot_index])
	current_editing_team_index = team_index
	selected_cards_for_edit = training_teams[team_index].duplicate()
	open_card_selector()

func _on_team_row_card_removed(team_index: int, slot_index: int):
	"""移除卡片"""
	print("🗑️ 移除卡片 [隊伍%d, 槽位%d]" % [team_index, slot_index])
	if slot_index < training_teams[team_index].size():
		training_teams[team_index].remove_at(slot_index)
		update_training_teams()

func _on_team_row_cleared(team_index: int):
	"""清空隊伍"""
	print("🗑️ 清空訓練隊伍 %d" % team_index)
	training_teams[team_index].clear()
	update_training_teams()

# ==================== 按鈕回调 ====================
func _input(event: InputEvent):
	"""處理 ESC 鍵返回"""
	if event.is_action_pressed("ui_cancel"):  # ESC 鍵
		if card_selector_modal and card_selector_modal.visible:
			# 如果卡片選擇器打開，先關閉它
			_on_selector_cancel_pressed()
		else:
			# 正常返回
			_on_back_pressed()

func _on_back_pressed():
	"""返回訓練室選擇"""
	print("🔙 返回訓練室選擇")
	GameManager.goto_training_select()

func _on_start_button_pressed():
	"""開始/接收按鈕被點擊"""
	match current_state:
		TrainingState.IDLE:
			start_training()
		TrainingState.COMPLETED:
			receive_rewards()

# ==================== 卡片選擇器 ====================
func open_card_selector():
	"""打开卡片選擇器"""
	card_selector_modal.visible = true
	update_card_selector()

func update_card_selector():
	"""更新卡片選擇器"""
	selector_header.text = "選擇訓練卡片 (%d/5)" % selected_cards_for_edit.size()

	# 清空现有卡片
	for child in card_grid.get_children():
		child.queue_free()

	# 獲取所有可用卡片
	var all_cards = PlayerDataManager.get_all_card_instances()

	# 創建卡片按鈕
	for card_instance in all_cards:
		var card_data = DataManager.get_card(card_instance.card_id)
		if card_data:
			# ✅ 跳過滿等卡片
			if card_instance.current_level >= card_instance.max_level:
				continue
			var card_button = create_card_button(card_instance, card_data)
			card_grid.add_child(card_button)

func create_card_button(card_instance, card_data) -> PanelContainer:
	"""創建卡片按鈕（帶卡圖）"""
	# 元素顏色定義
	var ELEMENT_COLORS = {
		Constants.Element.METAL: Color("FFD700"),
		Constants.Element.WOOD: Color("33CC33"),
		Constants.Element.WATER: Color("3388FF"),
		Constants.Element.FIRE: Color("FF3333"),
		Constants.Element.EARTH: Color("CC9933"),
		Constants.Element.HEART: Color("FF66CC")
	}

	var ELEMENT_NAMES = {
		Constants.Element.METAL: "金",
		Constants.Element.WOOD: "木",
		Constants.Element.WATER: "水",
		Constants.Element.FIRE: "火",
		Constants.Element.EARTH: "土",
		Constants.Element.HEART: "心"
	}

	# 創建 PanelContainer 並設置元素顏色背景
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 180)

	# ✅ 設置卡面背景為元素顏色
	var style = StyleBoxFlat.new()
	style.bg_color = ELEMENT_COLORS.get(card_instance.element, Color.GRAY)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4, 1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	panel.add_theme_stylebox_override("panel", style)

	# 創建按鈕
	var button = Button.new()
	button.flat = true
	panel.add_child(button)

	# 創建內容容器
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	button.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	# 卡圖容器
	var texture_container = Control.new()
	texture_container.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(texture_container)

	# 卡圖（如果有的話）
	var texture = DataManager.get_card_texture(card_instance.card_id)
	if texture:
		var card_texture = TextureRect.new()
		card_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_texture.texture = texture
		card_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_container.add_child(card_texture)
	else:
		# ✅ 沒有卡圖時，顯示元素顏色背景作為替代
		var card_sprite = ColorRect.new()
		card_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_sprite.color = ELEMENT_COLORS.get(card_instance.element, Color.GRAY)
		card_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_container.add_child(card_sprite)

	# 等級標籤
	var level_label = Label.new()
	level_label.text = "Lv. %d" % card_instance.current_level
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	level_label.add_theme_constant_override("shadow_offset_x", 1)
	level_label.add_theme_constant_override("shadow_offset_y", 1)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 等級背景
	var level_bg = ColorRect.new()
	level_bg.color = Color(0, 0, 0, 0.7)
	level_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	level_bg.offset_top = -16
	level_bg.z_index = -1
	level_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.add_child(level_bg)

	level_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	level_label.offset_top = -16
	texture_container.add_child(level_label)

	# 元素標籤
	var element_name = ELEMENT_NAMES.get(card_instance.element, "??")
	var card_element_color = ELEMENT_COLORS.get(card_instance.element, Color.WHITE)
	var element_label = Label.new()
	element_label.text = "[%s]" % element_name
	element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	element_label.add_theme_font_size_override("font_size", 11)
	element_label.add_theme_color_override("font_color", card_element_color)
	element_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(element_label)

	# 名稱標籤
	var name_label = Label.new()
	name_label.text = card_data.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# 檢查是否已選擇
	var is_selected = card_instance.instance_id in selected_cards_for_edit

	if is_selected:
		panel.modulate = Color(0.5, 1.0, 0.5)
	else:
		panel.modulate = Color(1, 1, 1)

	button.pressed.connect(_on_card_selected_in_selector.bind(card_instance.instance_id))
	return panel

func _on_card_selected_in_selector(card_instance_id: String):
	"""在選擇器中點擊卡片"""
	if card_instance_id in selected_cards_for_edit:
		# 取消選擇
		selected_cards_for_edit.erase(card_instance_id)
	else:
		# 選擇卡片（最多5張）
		if selected_cards_for_edit.size() < 5:
			selected_cards_for_edit.append(card_instance_id)

	update_card_selector()

func _on_selector_confirm_pressed():
	"""確認選擇"""
	if current_editing_team_index >= 0 and current_editing_team_index < training_teams.size():
		training_teams[current_editing_team_index] = selected_cards_for_edit.duplicate()

	card_selector_modal.visible = false
	update_training_teams()

func _on_selector_cancel_pressed():
	"""取消選擇"""
	card_selector_modal.visible = false

# ==================== 檢查進行中的訓練 ====================
func check_active_training():
	"""檢查是否有進行中的訓練"""
	if PlayerDataManager.is_training_active():
		var active_training = PlayerDataManager.get_active_training()

		# 檢查是否是當前訓練室的訓練
		if active_training.room_id == room_data.get("room_id", ""):
			if active_training.is_completed:
				# 訓練已完成，可以領取獎勵
				current_state = TrainingState.COMPLETED
			else:
				# 訓練進行中
				current_state = TrainingState.TRAINING
				remaining_time = active_training.remaining_time

			update_start_button()
			print("📋 恢復訓練狀態：%s，剩餘時間：%.0f 秒" % [
				"已完成" if active_training.is_completed else "進行中",
				active_training.remaining_time
			])

# ==================== 訓練系统 ====================
func start_training():
	"""開始訓練"""
	# ✅ 檢查強制任務限制
	if not TaskManager.is_action_allowed("training_start"):
		TaskManager.show_mandatory_quest_message()
		return

	print("🏋️ 開始訓練！")

	# 檢查是否至少有一張卡片
	var has_cards = false
	for team in training_teams:
		if team.size() > 0:
			has_cards = true
			break

	if not has_cards:
		GameManager.show_message("無法開始", "至少需要一張卡片才能開始訓練！")
		return

	# ✅ 使用背景訓練系統
	PlayerDataManager.start_training(
		room_data.get("room_id", ""),
		training_time,
		training_teams,
		exp_reward
	)

	current_state = TrainingState.TRAINING
	remaining_time = training_time

	update_start_button()

	# 🎯 通知任務系統：訓練開始
	TaskManager.notify_event("training_started", {
		"room_id": room_data.get("room_id", ""),
		"teams": training_teams
	})

func _on_timer_tick():
	"""計時器更新（用於UI更新）"""
	# ✅ 從 PlayerDataManager 獲取當前訓練狀態
	if PlayerDataManager.is_training_active():
		var active_training = PlayerDataManager.get_active_training()

		# 只更新當前訓練室的訓練
		if active_training.room_id == room_data.get("room_id", ""):
			if active_training.is_completed and current_state != TrainingState.COMPLETED:
				# 訓練剛剛完成
				complete_training()
			elif current_state == TrainingState.TRAINING:
				# 更新剩餘時間
				remaining_time = active_training.remaining_time
				update_start_button()

func complete_training():
	"""訓練完成（切換到可領取狀態）"""
	print("✅ 訓練完成！")
	current_state = TrainingState.COMPLETED
	update_start_button()

func receive_rewards():
	"""接收獎勵"""
	print("🎁 接收獎勵")

	# ✅ 使用 PlayerDataManager 完成訓練並領取獎勵
	var result = PlayerDataManager.complete_training()

	if not result.success:
		GameManager.show_message("錯誤", result.get("error", "未知錯誤"))
		return

	# 顯示結果
	var message = "訓練完成！\n共訓練了 %d 張卡片\n每張卡片獲得 %d 經驗值" % [
		result.total_cards,
		result.exp_reward
	]

	if result.level_ups.size() > 0:
		message += "\n\n🎉 升級的卡片："
		for level_up in result.level_ups:
			message += "\n  • %s → Lv.%d" % [level_up.card_name, level_up.new_level]

	GameManager.show_message("訓練完成", message)

	# 🎯 通知任務系統：訓練已完成並領取獎勵
	TaskManager.notify_event("training_completed", {
		"room_id": room_data.get("room_id", ""),
		"total_cards": result.total_cards,
		"exp_reward": result.exp_reward,
		"level_ups": result.level_ups
	})

	# 🎯 通知任務系統：卡片升級事件（用於任務條件檢測）
	for level_up in result.level_ups:
		TaskManager.notify_event("card_leveled_up", {
			"card_id": level_up.card_id,
			"card_name": level_up.card_name,
			"old_level": level_up.old_level,
			"new_level": level_up.new_level
		})
		print("📢 任務系統通知：%s (%s) 升級到 Lv.%d" % [level_up.card_name, level_up.card_id, level_up.new_level])

	# ✅ 清空訓練隊伍（避免持續訓練）
	training_teams.clear()
	print("🧹 訓練隊伍已清空")

	# 重置狀態
	current_state = TrainingState.IDLE
	update_ui()
