# StageItem.gd
# 關卡項目 UI
extends PanelContainer

# ==================== 引用節點 ====================
@onready var stage_name_label: Label = $MarginContainer/VBoxContainer/StageNameLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var difficulty_label: Label = $MarginContainer/VBoxContainer/InfoContainer/DifficultyLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/InfoContainer/StatusLabel
@onready var locked_overlay: ColorRect = $LockedOverlay
@onready var boss_badge: Label = $BossBadge

# ==================== 信號 ====================
signal stage_selected(stage_data: StageData)

# ==================== 屬性 ====================
var stage_data: StageData = null

# ==================== 初始化 ====================

func _ready():
	gui_input.connect(_on_gui_input)

# ==================== 設置關卡數據 ====================

func setup(data: StageData):
	"""設置關卡數據並更新顯示"""
	stage_data = data

	# 基礎資訊
	stage_name_label.text = data.stage_name
	description_label.text = data.stage_description

	# 難度
	difficulty_label.text = "難度: " + "★".repeat(data.difficulty)

	# BOSS 標記
	boss_badge.visible = data.is_boss_stage

	# 狀態
	update_status()

func update_status():
	"""更新關卡狀態顯示"""
	if not stage_data:
		return

	# 1. 獲取玩家的通關紀錄 (例如 ["1-1"])
	var completed_stages = PlayerDataManager.get_completed_stages()

	# 2. 檢查此關卡是否已解鎖 (例如 1-2 檢查 "1-1" 是否在 completed_stages 中)
	var is_unlocked = stage_data.is_unlocked(completed_stages)

	# 3. 檢查「此關卡本身」是否在通關紀錄中
	var is_completed = (stage_data.stage_id in completed_stages)

	# 4. 根據解鎖和完成狀態更新UI
	if not is_unlocked:
		# 未解鎖
		status_label.text = "🔒 未解鎖"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		locked_overlay.visible = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif is_completed:
		# 已解鎖 且 已完成 (例如 1-1)
		status_label.text = "✅ 已完成"
		status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		locked_overlay.visible = false
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		# 已解鎖 但 未完成 (例如 1-2)
		status_label.text = "▶ 可挑戰"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		locked_overlay.visible = false
		mouse_filter = Control.MOUSE_FILTER_STOP

# ==================== 輸入處理 ====================

func _on_gui_input(event: InputEvent):
	"""處理點擊事件"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if stage_data and locked_overlay.visible == false:
			stage_selected.emit(stage_data)
