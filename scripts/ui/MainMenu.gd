# MainMenu.gd
# 主選單控制器 - 全新大地圖版本
extends Control

# ==================== 節點引用 ====================
# 雲海區域
@onready var cloud_button = $CloudRegion/CloudButton

# 五大區域
@onready var region1_button = $MapContainer/MapArea/Region1
@onready var region2_button = $MapContainer/MapArea/Region2
@onready var region3_button = $MapContainer/MapArea/Region3
@onready var region4_button = $MapContainer/MapArea/Region4
@onready var region5_button = $MapContainer/MapArea/Region5

# 中心漩渦（仙魔界海）
@onready var center_vortex = $MapContainer/MapArea/CenterVortex

# 訓練場（斷界修途）
@onready var training_area = $MapContainer/MapArea/TrainingArea

# 升仙台（卡片進化）
@onready var evolution_area = $MapContainer/MapArea/EvolutionArea

# 底部導航欄
@onready var inventory_button = $BottomBar/HBoxContainer/InventoryButton
@onready var team_button = $BottomBar/HBoxContainer/TeamButton
@onready var shop_button = $BottomBar/HBoxContainer/ShopButton
@onready var settings_button = $BottomBar/HBoxContainer/SettingsButton

# 任務按鈕（動態創建）
var quest_button: Button = null

# 調試面板
@onready var debug_panel = $DebugPanel
@onready var reset_save_button = $DebugPanel/VBoxContainer/ResetSaveButton
@onready var quit_button = $DebugPanel/VBoxContainer/QuitButton

# ==================== 區域進度數據 ====================
var region_progress = {
	"region1": false,  # 北域 - 厚土崑原
	"region2": false,  # 東域 - 離火烈荒
	"region3": false,  # 南域 - 玄水幽淵
	"region4": false,  # 西域 - 蒼木古林
	"region5": false   # 中域 - 金雷天罡
}

# ==================== 初始化 ====================
func _ready():
	print("📱 主選單載入完成 - 大地圖版本")

	# 連接區域按鈕
	cloud_button.pressed.connect(_on_cloud_region_pressed)
	region1_button.pressed.connect(_on_region_pressed.bind(1))
	region2_button.pressed.connect(_on_region_pressed.bind(2))
	region3_button.pressed.connect(_on_region_pressed.bind(3))
	region4_button.pressed.connect(_on_region_pressed.bind(4))
	region5_button.pressed.connect(_on_region_pressed.bind(5))
	center_vortex.pressed.connect(_on_center_vortex_pressed)
	training_area.pressed.connect(_on_training_area_pressed)
	evolution_area.pressed.connect(_on_evolution_area_pressed)

	# 創建並添加任務按鈕
	create_quest_button()

	# 連接底部導航欄
	inventory_button.pressed.connect(_on_inventory_pressed)
	team_button.pressed.connect(_on_team_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	# 連接調試按鈕
	reset_save_button.pressed.connect(_on_reset_save_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# 載入進度並更新 UI
	load_region_progress()
	update_region_buttons()
	update_training_button()

	# 播放入場動畫
	play_entrance_animation()

# ==================== 進度系統 ====================
func load_region_progress():
	"""從 PlayerDataManager 載入區域進度"""
	# TODO: 實際從存檔讀取進度
	# 目前使用測試數據
	region_progress["region1"] = true  # 開放第一個區域供測試
	region_progress["region2"] = false
	region_progress["region3"] = false
	region_progress["region4"] = false
	region_progress["region5"] = false

func update_region_buttons():
	"""根據進度更新按鈕狀態"""
	# 更新區域按鈕（已解鎖的區域不會被禁用）
	# region1_button.disabled = !region_progress["region1"]
	# region2_button.disabled = !region_progress["region2"]
	# region3_button.disabled = !region_progress["region3"]
	# region4_button.disabled = !region_progress["region4"]
	# region5_button.disabled = !region_progress["region5"]

	# 檢查是否所有區域都已完成
	var all_regions_completed = (
		region_progress["region1"] and
		region_progress["region2"] and
		region_progress["region3"] and
		region_progress["region4"] and
		region_progress["region5"]
	)

	# 更新仙魔界海按鈕
	center_vortex.disabled = !all_regions_completed
	if all_regions_completed:
		center_vortex.text = "🌀\n仙魔界海\n✨ 已解鎖"
		center_vortex.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
	else:
		center_vortex.text = "🌀\n仙魔界海\n🔒 未解鎖"
		center_vortex.add_theme_color_override("font_color", Color(0.5, 0, 0.8, 1))

func update_training_button():
	"""更新訓練場按鈕狀態（檢查是否有訓練完成）"""
	var active_training = PlayerDataManager.get_active_training()

	if active_training.has("is_completed") and active_training.is_completed:
		# 訓練已完成，顯示提醒
		training_area.text = "⚔️\n斷界修途\n❗訓練完成"
		training_area.add_theme_color_override("font_color", Color(1, 0.5, 0.2, 1))  # 橙紅色提醒
	else:
		# 正常狀態
		training_area.text = "⚔️\n斷界修途\n✨ 訓練場"
		training_area.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1))

# ==================== 區域選擇回調 ====================
func _on_cloud_region_pressed():
	"""太初天墟（活動/特殊關卡）"""
	# 檢查強制任務
	if not TaskManager.is_action_allowed("navigate_region", {"target": "cloud"}):
		TaskManager.show_mandatory_quest_message()
		return

	print("☁️ 進入太初天墟")
	# TODO: 開啟雲海關卡選擇界面
	show_stage_selection("cloud")

func _on_region_pressed(region_id: int):
	"""區域按鈕被點擊"""
	# 檢查強制任務
	if not TaskManager.is_action_allowed("navigate_region", {"target": "region%d" % region_id}):
		TaskManager.show_mandatory_quest_message()
		return

	var region_names = {
		1: "北域 - 厚土崑原",
		2: "東域 - 離火烈荒",
		3: "南域 - 玄水幽淵",
		4: "西域 - 蒼木古林",
		5: "中域 - 金雷天罡"
	}
	print("🗺️ 進入區域 %d: %s" % [region_id, region_names[region_id]])
	show_stage_selection("region%d" % region_id)

func _on_center_vortex_pressed():
	"""仙魔界海被點擊"""
	# 檢查強制任務
	if not TaskManager.is_action_allowed("navigate_region", {"target": "vortex"}):
		TaskManager.show_mandatory_quest_message()
		return

	print("🌀 進入仙魔界海")
	show_stage_selection("vortex")

func _on_training_area_pressed():
	"""斷界修途被點擊"""
	# 檢查強制任務
	if not TaskManager.is_action_allowed("navigate_ui", {"target": "training_area"}):
		TaskManager.show_mandatory_quest_message()
		return

	print("⚔️ 進入斷界修途 - 訓練場")
	GameManager.goto_training_select()

func _on_evolution_area_pressed():
	"""升仙台被點擊"""
	# 檢查強制任務
	if not TaskManager.is_action_allowed("navigate_ui", {"target": "evolution_area"}):
		TaskManager.show_mandatory_quest_message()
		return

	print("✨ 進入升仙台 - 卡片進化")
	GameManager.goto_evolution()

func show_stage_selection(region_type: String):
	"""顯示關卡選擇界面"""
	print("📋 開啟 %s 的章節列表" % region_type)
	# 跳轉到章節選擇界面
	GameManager.goto_chapter_select(region_type)

# ==================== 創建任務按鈕 ====================
func create_quest_button():
	"""動態創建任務按鈕並添加到底部導航欄"""
	# 獲取底部導航欄的 HBoxContainer
	var bottom_hbox = $BottomBar/HBoxContainer
	if bottom_hbox == null:
		print("❌ 找不到底部導航欄容器")
		return

	# 創建任務按鈕（使用與其他按鈕一致的風格）
	quest_button = Button.new()
	quest_button.text = "📋 任務"
	quest_button.custom_minimum_size = Vector2(200, 80)
	quest_button.add_theme_font_size_override("font_size", 28)

	# 連接信號
	quest_button.pressed.connect(_on_quest_pressed)

	# 添加到底部導航欄（在背包按鈕後面）
	var inventory_index = inventory_button.get_index()
	bottom_hbox.add_child(quest_button)
	bottom_hbox.move_child(quest_button, inventory_index + 1)

	print("✅ 任務按鈕已添加到底部導航欄")

# ==================== 底部導航欄回調 ====================
func _on_inventory_pressed():
	"""背包按鈕"""
	# 檢查強制任務
	if not TaskManager.is_action_allowed("navigate_ui", {"target": "inventory"}):
		TaskManager.show_mandatory_quest_message()
		return

	print("🎒 打開背包")
	GameManager.goto_inventory()

func _on_team_pressed():
	"""隊伍按鈕"""
	# 檢查強制任務
	if not TaskManager.is_action_allowed("navigate_ui", {"target": "team"}):
		TaskManager.show_mandatory_quest_message()
		return

	print("👥 隊伍管理")
	GameManager.goto_team_list()

func _on_shop_pressed():
	"""商城按鈕"""
	# 檢查強制任務
	if not TaskManager.is_action_allowed("navigate_ui", {"target": "shop"}):
		TaskManager.show_mandatory_quest_message()
		return

	print("🏪 進入商城")
	GameManager.goto_shop()

func _on_quest_pressed():
	"""任務按鈕"""
	# 任務界面不受強制任務限制
	print("📋 查看任務")
	GameManager.goto_quest()

func _on_settings_pressed():
	"""設定按鈕（預留）"""
	# 檢查強制任務
	if not TaskManager.is_action_allowed("navigate_ui", {"target": "settings"}):
		TaskManager.show_mandatory_quest_message()
		return

	print("⚙️ 設定（尚未實作）")
	# TODO: 開啟設定選單

# ==================== 調試功能 ====================
func _on_reset_save_pressed():
	"""重置玩家存檔"""
	print("⚠️ 玩家要求重置存檔...")
	PlayerDataManager.reset_save()
	print("✅ 存檔已重置")
	GameManager.goto_main_menu()

func _on_quit_pressed():
	"""退出遊戲"""
	print("👋 退出遊戲")
	GameManager.quit_game()

# ==================== 動畫 ====================
func play_entrance_animation():
	"""播放入場動畫"""
	# 雲海區域從上方滑入
	var cloud_region = $CloudRegion
	var cloud_original_offset = cloud_region.offset_top
	cloud_region.modulate.a = 0
	cloud_region.offset_top = cloud_original_offset - 100

	# 底部導航欄從下方滑入
	var bottom_bar = $BottomBar
	var bottom_original_offset = bottom_bar.offset_top
	bottom_bar.modulate.a = 0
	bottom_bar.offset_top = bottom_original_offset + 100

	# 地圖區域淡入 + 縮放
	var map_container = $MapContainer
	map_container.modulate.a = 0
	map_container.scale = Vector2(0.8, 0.8)

	# 創建動畫
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# 雲海區域動畫
	tween.tween_property(cloud_region, "modulate:a", 1.0, 0.5)
	tween.tween_property(cloud_region, "offset_top", cloud_original_offset, 0.5)

	# 底部導航欄動畫
	tween.tween_property(bottom_bar, "modulate:a", 1.0, 0.5).set_delay(0.2)
	tween.tween_property(bottom_bar, "offset_top", bottom_original_offset, 0.5).set_delay(0.2)

	# 地圖區域動畫
	tween.tween_property(map_container, "modulate:a", 1.0, 0.6).set_delay(0.3)
	tween.tween_property(map_container, "scale", Vector2(1.0, 1.0), 0.6).set_delay(0.3)

# ==================== 輸入處理 ====================
func _input(event: InputEvent):
	"""處理鍵盤快捷鍵"""
	if event.is_action_pressed("ui_cancel"):  # ESC 鍵
		# 切換調試面板顯示
		debug_panel.visible = !debug_panel.visible

	# F5 刷新進度
	if event is InputEventKey and event.keycode == KEY_F5 and event.pressed:
		print("🔄 刷新區域進度")
		load_region_progress()
		update_region_buttons()
