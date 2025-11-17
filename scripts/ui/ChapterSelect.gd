# ChapterSelect.gd
# 層級選擇界面 - 顯示某個區域的所有章節/層級
extends Control

# ==================== 節點引用 ====================
@onready var back_button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var region_title = $MarginContainer/VBoxContainer/TopBar/RegionTitle
@onready var chapter_list = $MarginContainer/VBoxContainer/ScrollContainer/ChapterList

# ==================== 數據 ====================
var current_region_id: String = ""
var region_data: Dictionary = {}
var chapters: Array = []

# ==================== 初始化 ====================
func _ready():
	back_button.pressed.connect(_on_back_pressed)

	# 從 GameManager 讀取當前區域ID並自動設置
	if GameManager.current_region_id != "":
		print("🎬 _ready() 檢測到 region_id: %s" % GameManager.current_region_id)
		setup(GameManager.current_region_id)
	else:
		print("⚠️ _ready() 沒有找到 region_id")

func setup(region_id: String):
	"""設置區域並載入章節列表"""
	print("📖 ChapterSelect.setup() 被調用，region_id = %s" % region_id)
	current_region_id = region_id
	load_region_data()
	update_ui()

# ==================== 數據載入 ====================
func load_region_data():
	"""從 JSON 載入區域配置"""
	var file_path = "res://data/config/regions.json"
	print("📂 正在載入區域配置: %s" % file_path)

	if not FileAccess.file_exists(file_path):
		push_error("❌ 找不到區域配置文件: " + file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("❌ 無法打開區域配置文件")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("❌ JSON 解析錯誤: " + json.get_error_message())
		return

	var data = json.get_data()
	print("✅ JSON 載入成功，總共 %d 個區域" % data.get("regions", []).size())

	# 找到對應的區域
	for region in data.get("regions", []):
		if region.get("region_id") == current_region_id:
			region_data = region
			chapters = region.get("chapters", [])
			print("✅ 找到區域 %s，共 %d 個章節" % [current_region_id, chapters.size()])
			break

	if region_data.is_empty():
		push_error("❌ 找不到區域: " + current_region_id)
	else:
		print("📋 章節列表: %s" % str(chapters))

# ==================== UI 更新 ====================
func update_ui():
	"""更新界面"""
	print("🎨 開始更新 UI...")

	# 更新標題
	var region_icon = region_data.get("region_icon", "📍")
	var region_name = region_data.get("region_name", "未知區域")
	region_title.text = "%s %s" % [region_icon, region_name]
	print("  標題設置為: %s" % region_title.text)

	# 清空現有的章節按鈕
	for child in chapter_list.get_children():
		child.queue_free()
	print("  清空現有章節按鈕")

	# 創建章節按鈕
	print("  開始創建 %d 個章節按鈕" % chapters.size())
	for chapter in chapters:
		create_chapter_button(chapter)
	print("✅ UI 更新完成")

func create_chapter_button(chapter_data: Dictionary):
	"""創建章節按鈕"""
	var chapter_id = chapter_data.get("chapter_id", "")
	var chapter_name = chapter_data.get("chapter_name", "未命名")
	var chapter_desc = chapter_data.get("chapter_desc", "")
	var require_previous = chapter_data.get("require_previous", false)
	var previous_chapter = chapter_data.get("previous_chapter", "")
	var is_independent = chapter_data.get("is_independent", true)

	# 檢查是否解鎖
	var is_unlocked = check_chapter_unlocked(chapter_id, require_previous, previous_chapter)

	# 檢查是否完成
	var is_completed = check_chapter_completed(chapter_id, chapter_data.get("stages", []))

	# 創建按鈕容器
	var button_container = PanelContainer.new()
	button_container.custom_minimum_size = Vector2(0, 120)

	# 如果未解鎖，隱藏按鈕（除非是獨立章節）
	if not is_unlocked and not is_independent:
		button_container.visible = false

	var button = Button.new()
	button.custom_minimum_size = Vector2(0, 120)
	button.disabled = !is_unlocked

	# 設置按鈕文字
	var status_text = ""
	if is_completed:
		status_text = " ✅ 攻略完成"
	elif not is_unlocked:
		status_text = " 🔒 未解鎖"

	button.text = "%s%s\n%s" % [chapter_name, status_text, chapter_desc]
	button.add_theme_font_size_override("font_size", 24)

	# 綁定信號
	button.pressed.connect(_on_chapter_pressed.bind(chapter_data))

	button_container.add_child(button)
	chapter_list.add_child(button_container)

func check_chapter_unlocked(_chapter_id: String, require_previous: bool, previous_chapter: String) -> bool:
	"""檢查章節是否解鎖"""
	if not require_previous:
		return true

	# TODO: 從 PlayerDataManager 檢查前置章節是否完成
	# 暫時實現：檢查前置章節是否完成（目前都返回 false，需要實際進度系統）
	if previous_chapter != "":
		# 這裡應該從 PlayerDataManager 檢查
		# 暫時返回 false 來測試鎖定功能
		return false

	return true

func check_chapter_completed(_chapter_id: String, stages: Array) -> bool:
	"""檢查章節是否完成（所有關卡都完成）"""
	if stages.is_empty():
		return false

	# TODO: 從 PlayerDataManager 檢查所有關卡是否完成
	# 暫時返回 false
	return false

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

func _on_chapter_pressed(chapter_data: Dictionary):
	"""章節被點擊"""
	var chapter_id = chapter_data.get("chapter_id", "")
	var chapter_name = chapter_data.get("chapter_name", "")
	var stages = chapter_data.get("stages", [])

	print("📖 進入章節: %s (%s)" % [chapter_name, chapter_id])
	print("  關卡列表: %s" % str(stages))

	# 跳轉到關卡選擇（傳遞章節信息）
	GameManager.goto_stage_select_with_chapter(current_region_id, chapter_id, stages)
