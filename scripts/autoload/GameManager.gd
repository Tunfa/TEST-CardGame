# GameManager.gd
# 遊戲總控制器（Autoload 單例）
extends Node

# ==================== 信號 ====================
signal game_state_changed(new_state: Constants.GameState)
signal scene_changed(scene_name: String)

# ==================== 遊戲狀態 ====================
var current_state: Constants.GameState = Constants.GameState.MAIN_MENU

# ==================== 當前數據 ====================
var current_team: TeamData = null  # 當前選擇的隊伍
var current_stage: StageData = null  # 當前選擇的關卡
var selected_stage: StageData = null  # 選中的關卡（用於關卡選擇介面）
var current_editing_team_id: String = ""  # ✅ 新增：正在編輯的隊伍ID
var battle_rewards: Dictionary = {}
var battle_victory: bool = false

# 章節系統數據
var current_region_id: String = ""  # 當前區域ID
var current_chapter_id: String = ""  # 當前章節ID
var current_chapter_stages: Array = []  # 當前章節的關卡列表

# 訓練系統數據
var current_training_room: Dictionary = {}  # 當前訓練室數據

# 進化系統數據
var selected_card_for_evolution: String = ""  # 選中要進化的卡片 instance_id

# ==================== 場景路徑 ====================
const SCENES = {
	"main_menu": "res://scenes/main/MainMenu.tscn",
	"chapter_select": "res://scenes/stage/ChapterSelect.tscn",  # ✅ 新增：章節選擇
	"stage_select": "res://scenes/stage/StageSelect.tscn",
	"inventory": "res://scenes/inventory/Inventory.tscn",
	"team_list": "res://scenes/team/TeamList.tscn",
	"battle": "res://scenes/battle/BattleScene.tscn",
	"reward": "res://scenes/reward/RewardScreen.tscn",
	"gacha": "res://scenes/gacha/GachaScreen.tscn", # ✅ 新增
	"shop": "res://scenes/shop/ShopScreen.tscn",    # ✅ 新增
	"training_select": "res://scenes/training/TrainingRoomSelect.tscn",  # ✅ 新增：訓練室選擇
	"training": "res://scenes/training/TrainingScene.tscn",  # ✅ 新增：訓練界面
	"evolution": "res://scenes/evolution/EvolutionHall.tscn",  # ✅ 新增：升仙台
	"quest": "res://scenes/quest/QuestScreen.tscn"  # ✅ 新增：任務界面
}

# ==================== 初始化 ====================

func _ready():
	print("🎮 GameManager 初始化完成")
	change_state(Constants.GameState.MAIN_MENU)

# ==================== 狀態管理 ====================

func change_state(new_state: Constants.GameState):
	"""改變遊戲狀態"""
	current_state = new_state
	game_state_changed.emit(new_state)
	print("遊戲狀態切換至: ", Constants.GameState.keys()[new_state])

# ==================== 場景切換 ====================

func goto_gacha(): # ✅ 新增
	"""進入抽卡畫面"""
	# (您應該在 Constants.gd (source 139) 的 GameState enum 中新增 GACHA)
	# change_state(Constants.GameState.GACHA) 
	change_scene("gacha")

func goto_shop(): # ✅ 新增
	"""進入商店畫面"""
	# (您應該在 Constants.gd (source 139) 的 GameState enum 中新增 SHOP)
	# change_state(Constants.GameState.SHOP)
	change_scene("shop")

func change_scene(scene_key: String):
	"""切換場景"""
	if scene_key not in SCENES:
		push_error("場景不存在: " + scene_key)
		return

	# ✅ 檢查背包是否超限（除了背包和主選單，其他場景都要檢查）
	if scene_key not in ["inventory", "main_menu"]:
		if PlayerDataManager.is_bag_over_capacity():
			print("⚠️  背包已滿，無法進入 %s" % scene_key)
			show_bag_full_dialog()
			return

	var scene_path = SCENES[scene_key]
	print("切換場景至: " + scene_path)

	get_tree().change_scene_to_file(scene_path)
	scene_changed.emit(scene_key)

	# 🎯 通知任務系統：場景切換
	await get_tree().process_frame
	TaskManager.notify_event("scene_entered", {"scene_name": scene_key})

func goto_main_menu():
	"""返回主選單"""
	change_state(Constants.GameState.MAIN_MENU)
	change_scene("main_menu")

func goto_chapter_select(region_id: String):
	"""進入章節選擇（區域的層級列表）"""
	print("🎮 GameManager.goto_chapter_select(%s)" % region_id)
	current_region_id = region_id
	current_chapter_id = ""
	current_chapter_stages = []

	change_state(Constants.GameState.STAGE_SELECT)
	change_scene("chapter_select")
	# ChapterSelect 會在 _ready() 中自動從 current_region_id 讀取並初始化

func goto_stage_select():
	"""進入關卡選擇（舊版，兼容性保留）"""

	# ⚠️ 修正：
	# 無論是從主選單還是戰鬥中返回，都應清除關卡狀態。
	# 這樣 TeamList 才不會錯誤地進入「選擇模式」。
	current_stage = null
	selected_stage = null

	change_state(Constants.GameState.STAGE_SELECT)
	change_scene("stage_select")

func goto_stage_select_with_chapter(region_id: String, chapter_id: String, stages: Array):
	"""進入關卡選擇（帶章節信息）"""
	current_region_id = region_id
	current_chapter_id = chapter_id
	current_chapter_stages = stages
	current_stage = null
	selected_stage = null

	change_state(Constants.GameState.STAGE_SELECT)
	change_scene("stage_select")

	# 場景載入後設置章節信息
	await get_tree().process_frame
	var scene = get_tree().current_scene
	if scene and scene.has_method("setup_chapter"):
		scene.setup_chapter(region_id, chapter_id, stages)
	
func goto_team_list(): # 原名 goto_team_setup
	"""進入隊伍管理畫面"""
	# 使用我們在 Constants.gd 中重命名的狀態
	change_state(Constants.GameState.TEAM_LIST) 
	change_scene("team_list")

func goto_inventory():
	"""進入背包"""
	change_state(Constants.GameState.INVENTORY)
	change_scene("inventory")

func goto_training_select():
	"""進入訓練室選擇"""
	print("🎮 GameManager.goto_training_select()")
	change_scene("training_select")

func goto_training(room_data: Dictionary):
	"""進入訓練界面"""
	print("🎮 GameManager.goto_training(%s)" % room_data.get("room_name", ""))
	current_training_room = room_data
	change_scene("training")

	# 場景載入後設置訓練室數據
	await get_tree().process_frame
	var scene = get_tree().current_scene
	if scene and scene.has_method("setup"):
		scene.setup(room_data)

func goto_evolution():
	"""進入升仙台"""
	print("🎮 GameManager.goto_evolution()")
	change_scene("evolution")

func goto_quest():
	"""進入任務界面"""
	print("🎮 GameManager.goto_quest()")
	change_scene("quest")

func goto_battle(team: TeamData, stage: StageData):
	"""進入戰鬥"""
	current_team = team
	current_stage = stage
	change_state(Constants.GameState.BATTLE)
	change_scene("battle")

func goto_reward(victory: bool, rewards: Dictionary):
	"""進入獎勵結算"""
	battle_victory = victory
	battle_rewards = rewards
	change_state(Constants.GameState.REWARD)
	change_scene("reward")
	
	

# ==================== 背包管理 ====================

func show_bag_full_dialog():
	"""顯示背包已滿對話框（使用統一UI）"""
	# 載入自定義對話框場景
	var CustomDialog = load("res://scripts/ui/CustomDialog.gd")
	var dialog = CustomDialog.new()

	# 設置為多選對話框
	var buttons = [
		{"text": "前往背包", "action": "goto_inventory"},
		{"text": "擴充背包", "action": "expand_bag"}
	]
	dialog.setup_choice_dialog("背包已滿", "您的背包已經滿了！\n請前往背包整理或擴充背包。", buttons)

	# 連接信號
	dialog.button_pressed.connect(func(action):
		match action:
			"goto_inventory":
				goto_inventory()
			"expand_bag":
				# ✅ 等待對話框完全關閉後再顯示下一個
				await get_tree().create_timer(0.1).timeout
				show_expand_bag_dialog()
	)

	# 添加到場景樹並顯示
	get_tree().root.add_child(dialog)
	dialog.show_dialog()

func show_expand_bag_dialog():
	"""顯示擴充背包確認對話框（使用統一UI）"""
	var current_diamond = PlayerDataManager.get_diamond()

	# 載入自定義對話框場景
	var CustomDialog = load("res://scripts/ui/CustomDialog.gd")
	var dialog = CustomDialog.new()

	# 設置為多選對話框
	var buttons = [
		{"text": "取消", "action": "canceled"},
		{"text": "擴充五格 (5💎)", "action": "expand_5"},
		{"text": "擴充十格 (10💎)", "action": "expand_10"}
	]
	var message = "你確定要擴充背包嗎？\n擴充背包需要消耗鑽石\n\n當前鑽石: %d 💎" % current_diamond
	dialog.setup_choice_dialog("擴充背包", message, buttons)

	# 連接信號
	dialog.button_pressed.connect(func(action):
		# ✅ 等待對話框完全關閉後再顯示訊息框
		await get_tree().create_timer(0.1).timeout

		match action:
			"expand_5":
				if current_diamond >= 5:
					if PlayerDataManager.expand_bag(5, 5):
						show_message("成功", "成功擴充 5 格！")
					else:
						show_message("錯誤", "鑽石不足！")
				else:
					show_message("錯誤", "鑽石不足！需要 5 顆鑽石")

			"expand_10":
				if current_diamond >= 10:
					if PlayerDataManager.expand_bag(10, 10):
						show_message("成功", "成功擴充 10 格！")
					else:
						show_message("錯誤", "鑽石不足！")
				else:
					show_message("錯誤", "鑽石不足！需要 10 顆鑽石")
			"canceled":
				pass  # 取消，不做任何事
	)

	# 添加到場景樹並顯示
	get_tree().root.add_child(dialog)
	dialog.show_dialog()

func show_message(title: String, message: String):
	"""顯示訊息對話框（使用統一UI）"""
	# 載入自定義對話框場景
	var CustomDialog = load("res://scripts/ui/CustomDialog.gd")
	var dialog = CustomDialog.new()

	# 設置為信息對話框
	dialog.setup_info_dialog(title, message)

	# 添加到場景樹並顯示
	get_tree().root.add_child(dialog)
	dialog.show_dialog()

# ==================== 工具方法 ====================

func quit_game():
	"""退出遊戲"""
	print("退出遊戲")
	get_tree().quit()
