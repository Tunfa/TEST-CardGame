# StageSelect.gd
# 關卡選擇場景
extends Control

# ==================== 引用節點 ====================
@onready var stage_grid: GridContainer = $Background/MarginContainer/VBoxContainer/ScrollContainer/StageGrid
@onready var back_button: Button = $Background/MarginContainer/VBoxContainer/TopBar/BackButton
@onready var title_label: Label = $Background/MarginContainer/VBoxContainer/TopBar/TitleLabel

# ==================== 預載資源 ====================
const STAGE_ITEM_SCENE = preload("res://scenes/stage/StageItem.tscn")

# ==================== 數據 ====================
var current_chapter_name: String = ""

# ==================== 初始化 ====================

func _ready():
	print("🗺️ StageSelect 初始化...")
	back_button.pressed.connect(_on_back_button_pressed)

	# 從 GameManager 讀取章節信息並更新標題
	update_chapter_info()
	load_stages()

func update_chapter_info():
	"""從 GameManager 更新章節信息"""
	if GameManager.current_chapter_id != "":
		print("📖 當前章節: %s" % GameManager.current_chapter_id)
		print("📋 章節關卡: %s" % str(GameManager.current_chapter_stages))

		# 從 regions.json 讀取章節名稱
		var file_path = "res://data/config/regions.json"
		if FileAccess.file_exists(file_path):
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file != null:
				var json_text = file.get_as_text()
				file.close()

				var json = JSON.new()
				var error = json.parse(json_text)
				if error == OK:
					var data = json.get_data()
					for region in data.get("regions", []):
						if region.get("region_id") == GameManager.current_region_id:
							for chapter in region.get("chapters", []):
								if chapter.get("chapter_id") == GameManager.current_chapter_id:
									current_chapter_name = chapter.get("chapter_name", "")
									var region_icon = region.get("region_icon", "📍")
									var region_name = region.get("region_name", "")
									title_label.text = "%s %s - %s" % [region_icon, region_name, current_chapter_name]
									print("✅ 標題設置為: %s" % title_label.text)
									break
							break
	else:
		print("⚠️ 沒有章節信息，使用舊版模式（顯示所有關卡）")
		title_label.text = "關卡選擇"

# ==================== 載入關卡 ====================

func load_stages():
	"""載入並顯示當前章節的關卡"""
	# 清空現有項目
	for child in stage_grid.get_children():
		child.queue_free()

	# 檢查是否有章節關卡列表
	var stage_ids_to_load = []
	if GameManager.current_chapter_stages.size() > 0:
		# 章節模式：只載入當前章節的關卡
		stage_ids_to_load = GameManager.current_chapter_stages
		print("📖 載入章節關卡數量: %d" % stage_ids_to_load.size())
	else:
		# 兼容舊版：載入所有關卡
		stage_ids_to_load = DataManager.get_all_stages()
		print("⚠️ 使用舊版模式，載入所有關卡數量: %d" % stage_ids_to_load.size())

	# 排序關卡（按 stage_id）
	stage_ids_to_load.sort()

	# 創建關卡項目
	for stage_id in stage_ids_to_load:
		var stage_data = DataManager.get_stage(stage_id)
		if stage_data:
			create_stage_item(stage_data)
		else:
			print("⚠️ 找不到關卡: %s" % stage_id)

func create_stage_item(stage_data: StageData):
	"""創建關卡項目"""
	var stage_item = STAGE_ITEM_SCENE.instantiate()
	stage_grid.add_child(stage_item)
	stage_item.setup(stage_data)
	stage_item.stage_selected.connect(_on_stage_selected)

# ==================== 信號處理 ====================

func _on_stage_selected(stage_data: StageData):
	"""關卡被選中"""
	print("選擇關卡: %s - %s" % [stage_data.stage_id, stage_data.stage_name])

	# ✅ 修改：保存選中的關卡到 GameManager
	GameManager.selected_stage = stage_data
	
	# ✅ 修改：進入隊伍選擇畫面（而不是直接戰鬥）
	show_team_selection()

func show_team_selection():
	"""
	顯示隊伍選擇畫面 (新版：直接跳轉到 TeamList)
	"""
	print("📋 進入隊伍列表 (選擇模式)...")
	# GameManager 已經保存了 selected_stage (在 _on_stage_selected 中)
	# TeamList 會在 _ready() 中偵測到這個狀態並自動進入「選擇模式」
	GameManager.goto_team_list()


func _on_create_new_team():
	"""新建隊伍"""
	print("✨ 創建新隊伍")
	# 註：我們不再需要設定 current_editing_team_id
	# GameManager.current_editing_team_id = "team_%d" % Time.get_ticks_msec()
	
# ⬇️ ========== 修改開始 ========== ⬇️
	# 直接導向新的隊伍列表/編輯畫面
	GameManager.goto_team_list()
# ⬆️ ========== 修改結束 ========== ⬆️

func start_battle():
	"""開始戰鬥"""
	var stage_data = GameManager.selected_stage
	var team = GameManager.current_team
	
	if not stage_data or not team:
		show_error_dialog("缺少關卡或隊伍資料！")
		return
	
	print("⚔️ 開始戰鬥: %s" % stage_data.stage_name)
	print("   隊伍: %s" % team.team_name)
	
# ⬇️ ======== 修正開始 ======== ⬇️
	
	# 錯誤的跳轉方式（這會導致 stage_data 丟失）:
	# GameManager.change_scene("battle")

	# 正確的跳轉方式 (使用 GameManager 的專用函式來傳遞資料):
	GameManager.goto_battle(team, stage_data)
	
	# ⬆️ ======== 修正結束 ======== ⬆️

func _input(event: InputEvent):
	"""處理 ESC 鍵返回"""
	if event.is_action_pressed("ui_cancel"):  # ESC 鍵
		_on_back_button_pressed()

func _on_back_button_pressed():
	"""返回章節選擇或主選單"""
	if GameManager.current_chapter_id != "":
		# 章節模式：返回章節選擇
		print("🔙 返回章節選擇: %s" % GameManager.current_region_id)
		GameManager.goto_chapter_select(GameManager.current_region_id)
	else:
		# 舊版模式：返回主選單
		print("🔙 返回主選單...")
		GameManager.goto_main_menu()

# ==================== 錯誤對話框 ====================

func show_error_dialog(message: String):
	"""顯示錯誤訊息"""
	print("❌ 錯誤: " + message)

	# 創建臨時標籤顯示錯誤
	var error_label = Label.new()
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color.RED)
	error_label.add_theme_font_size_override("font_size", 24)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.position = Vector2(760, 490)
	error_label.size = Vector2(400, 100)
	add_child(error_label)

	# 2秒後移除
	await get_tree().create_timer(2.0).timeout
	error_label.queue_free()
