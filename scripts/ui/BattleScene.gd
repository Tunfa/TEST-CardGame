# BattleScene.gd
# 戰鬥場景控制器
extends Node2D

# ==================== 引用 ====================
@onready var battle_manager: BattleManager = $BattleManager
@onready var player_stats = $UI/PlayerStats
@onready var rest_button = $PlayerArea/RestButton
@onready var skill_dialog = $UI/SkillDialog
@onready var card_container = $PlayerArea/CardContainer
@onready var enemy_container = $EnemyArea/EnemyContainer
@onready var targeting_label = $UI/TargetingLabel
@onready var camera = $Camera2D
@onready var player_hp_bar = $PlayerArea/HPContainer/HPBar
@onready var player_hp_label = $PlayerArea/HPContainer/HPBar/HPLabel
@onready var leave_battle_button = $PlayerArea/LeaveBattleButton
@onready var element_panel = $UI/ElementPanel  # 元素面板

# ✅ 修正 #1：路徑應指向 UI 節點內部
@onready var orb_storage_container = $OrbStorageContainer
@onready var nexttime_label = $UI/nexttime
# ==================== 預製體 ====================
var battle_card_scene = preload("res://scenes/battle/entities/BattleCard.tscn")
var enemy_scene = preload("res://scenes/battle/entities/Enemy.tscn")
var damage_number_scene = preload("res://scenes/battle/ui_components/DamageNumber.tscn")  # 修正：統一使用這個名稱
const ORB_STORAGE_BUTTON_SCENE = preload("res://scenes/battle/ui_components/OrbStorageButton.tscn")
var ELEMENT_NAMES = {
	Constants.Element.METAL: "金",
	Constants.Element.WOOD: "木",
	Constants.Element.WATER: "水",
	Constants.Element.FIRE: "火",
	Constants.Element.EARTH: "土",
	Constants.Element.HEART: "心"
}
# ==================== 資料 ====================
var orb_storage_buttons: Dictionary = {}
var card_nodes: Array = []  # 卡片節點列表
var enemy_nodes: Array = []  # 敵人節點列表
var selected_enemy: Control = null  # 當前選擇的敵人
var is_selecting_skill_target: bool = false # 是否正在等待玩家選擇技能目標
var card_for_skill_targeting: CardData = null # 正在等待目標的卡片
var targeting_tweens: Array = [] # 用來存放閃爍動畫
var camera_shake_tween: Tween = null # ✅ 修正：用變數儲存
var stored_orbs: Dictionary = {
	Constants.Element.METAL: 0,
	Constants.Element.WOOD: 0,
	Constants.Element.WATER: 0,
	Constants.Element.FIRE: 0,
	Constants.Element.EARTH: 0,
	Constants.Element.HEART: 0
}
var next_orb_sequence: Array[Dictionary] = []
var is_slashing: bool = false # ✅ 新增：追蹤斬擊狀態
const MAX_STORED_ORBS = 5

# ==================== 條件型技能追蹤 ====================
# ✅ 移除本地追蹤變數，改為從 BattleManager meta 讀取
# 數據由 ElementPanel 追蹤並存儲到 BattleManager.meta
# ==================== 初始化 ====================

func _ready():
	# 連接戰鬥管理器信號
	battle_manager.turn_changed.connect(_on_turn_changed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.hp_changed.connect(_on_hp_changed)
	battle_manager.enemy_died.connect(_on_enemy_died)
	battle_manager.card_sp_changed.connect(_on_card_sp_changed)
	battle_manager.next_wave_starting.connect(_on_next_wave_starting)
	battle_manager.damage_dealt.connect(_on_damage_dealt)
	leave_battle_button.leave_battle_pressed.connect(_on_leave_battle_pressed)

	# 連接UI信號
	rest_button.rest_pressed.connect(_on_rest_pressed)
	skill_dialog.skill_confirmed.connect(_on_skill_confirmed)
	skill_dialog.skill_cancelled.connect(_on_skill_cancelled)

	# 初始化元素面板
	if element_panel:
		element_panel.setup(battle_manager)
		# ✅ 連接視覺反饋信號
		element_panel.orb_eliminated.connect(_on_orb_eliminated)
		element_panel.slashing_started.connect(_on_slashing_started)
		element_panel.slashing_ended.connect(_on_slashing_ended)
		# ✨ 改用新的
		element_panel.slashing_phase_finished.connect(_on_slashing_phase_finished)
		element_panel.multipliers_updated.connect(_on_multipliers_updated)
		element_panel.healing_phase_finished.connect(_on_healing_phase_finished)
		element_panel.orb_dropped.connect(_on_orb_dropped)

	# ✅ 5. 在 _ready 的末尾，呼叫新的 setup 函數
	setup_orb_storage()
	update_orb_storage_display()
	
	# ✅ 修正 #2：在遊戲開始時，預設隱藏靈珠倉庫
	orb_storage_container.visible = false

	# 從 GameManager 獲取隊伍和關卡資料
	if GameManager.current_team and GameManager.current_stage:
		start_battle_from_game_manager()
	else:
		# 測試模式：創建測試資料
		start_test_battle()
	if nexttime_label:
		nexttime_label.visible = false

# ==================== 戰鬥開始 ====================
func _on_orb_dropped(element: Constants.Element, _is_special_spawn: bool): # ✅ 修正：接收 2 個參數
	"""(新) 收到 ElementPanel 的掉落信號"""
	# (_is_special_spawn 參數目前保留，供未來使用)
	var max_capacity = get_max_stored_orbs(element)  # ✅ 使用動態容量
	if stored_orbs[element] < max_capacity:
		stored_orbs[element] += 1
		update_orb_storage_display() # 更新UI，數字會+1

		# ✅ 只有在成功掉落（儲存）時，才觸發跳起動畫
		if element in orb_storage_buttons:
			var button = orb_storage_buttons[element]
			if button and is_instance_valid(button):
				button.on_element_collected(element)

		# print("靈珠已儲存: ", Constants.Element.keys()[element])
	else:
		print("靈珠 %s 倉庫已滿 (%d/%d)，掉落溢出！" % [Constants.Element.keys()[element], max_capacity, max_capacity])

func setup_orb_storage():
	"""(新) 以程式碼動態創建 6 顆靈珠按鈕，並放入容器中"""
	
	# (可選) 清空容器，以防您在編輯器中留下任何佔位符
	for child in orb_storage_container.get_children():
		child.queue_free()
	
	# 清空舊的按鈕字典
	orb_storage_buttons.clear()

	# 定義我們要創建的按鈕 (您可以自訂順序)
	var elements_to_create = [
		Constants.Element.FIRE,
		Constants.Element.WATER,
		Constants.Element.WOOD,
		Constants.Element.METAL,
		Constants.Element.EARTH,
		Constants.Element.HEART
	]

	for element in elements_to_create:
		# 1. 創建實例
		var button_instance = ORB_STORAGE_BUTTON_SCENE.instantiate()
		
		# 2. 加入場景樹 (HBoxContainer 會自動排版)
		orb_storage_container.add_child(button_instance)
		
		# 3. 呼叫 setup，設定它的屬性
		button_instance.setup(element)
		
		# 4. 連接它的點擊信號
		button_instance.orb_clicked.connect(_on_storage_orb_clicked)
		
		# 5. 儲存引用，方便我們稍後更新數字
		orb_storage_buttons[element] = button_instance

func _on_storage_orb_clicked(element: Constants.Element):
	"""(新) 當玩家點擊一顆儲存的靈珠按鈕時"""
	if stored_orbs[element] > 0:
		if next_orb_sequence.is_empty():
			_update_next_orb_display(true) # 傳入 true 來清空 Label
		stored_orbs[element] -= 1
		
		# ✅ 核心修改：儲存為字典格式，並標記為「玩家序列」
		next_orb_sequence.push_back({
			"element": element,
			"is_player_sequence": true
		}) 
		
		update_orb_storage_display()
		_update_next_orb_display() # ✅ 4. 新增這一行
	else:
		print("錯誤: 嘗試使用 0 顆的靈珠: ", Constants.Element.keys()[element])


# ✅ 7. 修改 update_orb_storage_display 函數
func update_orb_storage_display():
	"""(新) 更新所有按鈕上的數字 (使用字典)"""
	
	# 遍歷我們儲存的按鈕實例
	for element in orb_storage_buttons:
		var button = orb_storage_buttons[element]
		var count = stored_orbs[element]
		button.update_count(count)
	
	# (除錯用) 顯示當前排好的序列
	# print("排隊序列 LIFO (點擊順序): ", next_orb_sequence)
		
func _on_multipliers_updated(multipliers: Dictionary): # ✅ 2. 新增此回調函式
	"""(新) 收到 ElementPanel 的即時倍率更新"""
	for card_node in card_nodes:
		if is_instance_valid(card_node):
			card_node.update_atk_display(multipliers)

func start_battle_from_game_manager():
# ⬇️ ======== 修正開始 ======== ⬇️

	# 錯誤的讀取 (它讀取了 selected_stage):
	# var team_data = GameManager.current_team
	# var stage_data = GameManager.selected_stage

	# 正確的讀取 (讀取由 goto_battle 傳入的 current_stage):
	var team_data = GameManager.current_team
	var stage_data = GameManager.current_stage # ⬅️ 修正這一行

	# ⬆️ ======== 修正結束 ======== ⬆️
	
	# ✅ 根據 team_data 載入卡片（使用 instance_id）
	var team = []
	for instance_id in team_data.get_all_instance_ids():
		var card = PlayerDataManager.get_card_instance(instance_id) 
		if card:
			team.append(card)
		else:
			print("❌ [戰鬥初始化] 無法載入卡片實例: instance_%s" % instance_id)
	
	# 根據 stage_data 載入敵人
	var enemies = []
	for enemy_id in stage_data.get_enemy_list():
		var enemy = DataManager.get_enemy(enemy_id)
		if enemy:
			enemies.append(enemy)
	
	battle_manager.start_battle(team, enemies, stage_data)

	create_card_nodes()
	create_enemy_nodes()
	player_stats.update_wave(battle_manager.current_wave, battle_manager.total_waves)
	update_player_stats()

	# ✅ 顯示戰鬥開場動畫
	await show_battle_start_animation()

func start_test_battle():
	"""開始測試戰鬥"""
	var team = create_test_team()
	var enemies = create_test_enemies()

	battle_manager.start_battle(team, enemies)

	# 創建UI節點
	create_card_nodes()
	create_enemy_nodes()

	# 初始化UI
	player_stats.update_wave(battle_manager.current_wave, battle_manager.total_waves)
	update_player_stats()

	# ✅ 顯示戰鬥開場動畫
	await show_battle_start_animation()
	
func _on_next_wave_starting(wave_number: int):
	"""當新一波開始時，更新UI"""
	print("BattleScene: 接收到新波次 %d" % wave_number)
	# 1. 更新 PlayerStats 上的波次標籤
	player_stats.update_wave(wave_number, battle_manager.total_waves)
	# 2. 重新創建敵人UI
	create_enemy_nodes()

func create_test_team() -> Array:
	"""創建測試隊伍"""
	var warrior = CardData.new()
	warrior.card_name = "戰士"
	warrior.element = Constants.Element.FIRE
	warrior.base_hp = 15
	warrior.base_atk = 10
	warrior.base_recovery = 3
	warrior.passive_skill_ids = ["passive_atk_boost_150"]
	warrior.leader_skill_ids = ["passive_fire_dominance_atk", "passive_fire_dominance_orbs"]  # ✅ 添加队长技能
	warrior.active_skill_id = "active_heavy_strike"
	warrior.active_skill_cd = 5

	var mage = CardData.new()
	mage.card_name = "法師"
	mage.element = Constants.Element.WATER
	mage.base_hp = 8
	mage.base_atk = 12
	mage.base_recovery = 6
	mage.passive_skill_ids = ["passive_start_full_sp"]
	mage.leader_skill_ids = []  # 没有队长技能
	mage.active_skill_id = "active_aoe_damage"
	mage.active_skill_cd = 6

	var ranger = CardData.new()
	ranger.card_name = "遊俠"
	ranger.element = Constants.Element.WOOD
	ranger.base_hp = 10
	ranger.base_atk = 8
	ranger.base_recovery = 4
	ranger.passive_skill_ids = ["passive_dodge_once"]
	ranger.leader_skill_ids = []  # 没有队长技能

	return [warrior, mage, ranger]

func create_test_enemies() -> Array:
	"""創建測試敵人"""
	var slime = EnemyData.new()
	slime.enemy_name = "史萊姆"
	slime.max_hp = 20
	slime.base_atk = 3
	slime.attack_cd = 1
	slime.attack_skill_ids = ["enemy_normal_attack"]
	
	var goblin = EnemyData.new()
	goblin.enemy_name = "哥布林"
	goblin.max_hp = 30
	goblin.base_atk = 6
	goblin.attack_cd = 2
	goblin.passive_skill_ids = ["enemy_passive_defense_50"]
	goblin.attack_skill_ids = ["enemy_double_hit"]
	
	return [slime, goblin]

# ==================== 創建UI節點 ====================

func create_card_nodes():
	"""創建卡片節點"""
	# 清空舊節點
	for child in card_container.get_children():
		child.queue_free()
	card_nodes.clear()
	
	# 創建新節點
	for card_data in battle_manager.player_team:
		var card_node = battle_card_scene.instantiate()
		card_container.add_child(card_node)
		card_node.setup(card_data)
		
		# 連接信號
		card_node.card_dragged_to_enemy.connect(_on_card_dragged_to_enemy)
		card_node.skill_button_pressed.connect(_on_skill_button_pressed)
		
		card_nodes.append(card_node)

func create_enemy_nodes():
	"""創建敵人節點"""
	# 清空舊節點
	for child in enemy_container.get_children():
		child.queue_free()
	enemy_nodes.clear()

	# 創建新節點
	for enemy_data in battle_manager.enemies:
		var enemy_node = enemy_scene.instantiate()
		enemy_container.add_child(enemy_node)
		enemy_node.setup(enemy_data)

		# 連接信號
		enemy_node.enemy_clicked.connect(_on_enemy_clicked)
		enemy_node.enemy_right_clicked.connect(_on_enemy_right_clicked)

		enemy_nodes.append(enemy_node)

	# ✅ 等一幀後更新盾牌顯示（確保技能已經加載）
	await get_tree().process_frame
	update_all_enemy_shields()

# ==================== UI更新 ====================

func update_player_stats():
	"""更新玩家狀態"""
	player_stats.update_turn(battle_manager.turn_count)
	player_stats.update_phase(battle_manager.current_phase == Constants.BattlePhase.PLAYER_TURN)
	#player_stats.update_hp(battle_manager.current_hp, battle_manager.total_hp)
	player_stats.update_recovery(battle_manager.total_recovery)

func update_all_cards():
	"""更新所有卡片顯示"""
	for i in range(card_nodes.size()):
		if i < battle_manager.player_team.size():
			card_nodes[i].update_display()

func update_all_enemies():
	"""更新所有敵人顯示"""
	for node in enemy_nodes:
		if node and is_instance_valid(node):
			node.update_display()

func update_card_display(card_data: CardData):
	"""更新特定卡片的顯示（用於技能BUFF修改屬性時）"""
	for card_node in card_nodes:
		if card_node.card_data == card_data:
			card_node.update_display()
			break

func update_skill_markers():
	"""更新所有卡片的技能標記顯示
	根據當前生效的主動技能BUFF來顯示/隱藏技能標記"""
	if not battle_manager.has_meta("active_skill_buffs"):
		# 沒有任何BUFF，隱藏所有標記
		for card_node in card_nodes:
			card_node.hide_skill_marker()
		return

	var buffs = battle_manager.get_meta("active_skill_buffs")
	var active_caster_ids = {}  # 記錄哪些卡片有激活的技能

	# 收集所有激活技能的發動者
	for buff in buffs:
		var caster_id = buff.get("caster_instance_id", "")
		if not caster_id.is_empty():
			active_caster_ids[caster_id] = true

	# 更新卡片標記顯示
	for card_node in card_nodes:
		if card_node.card_data and card_node.card_data.instance_id in active_caster_ids:
			card_node.show_skill_marker()
		else:
			card_node.hide_skill_marker()

# ==================== 玩家操作 ====================

func _on_card_dragged_to_enemy(card_node: Control, enemy_node: Control):
	"""卡片拖曳到敵人上"""
	var card_data = card_node.card_data
	var enemy_data = enemy_node.get_enemy_data()
	
	if battle_manager.attack_with_card(card_data, enemy_data):
		# ... (播放動畫等)
		AudioManager.play_sfx("player_attack")
		for node in card_nodes:
			node.update_display()
		update_all_cards()
		update_all_enemies()
		
		# ✨ 攻擊成功後，立即重置元素面板，準備下一輪斬擊
		# (雖然回合還沒結束，但倍率已用掉，可以提前顯示)
		# element_panel.start_element_combat() 
		
	else:
		# 攻擊失敗 (例如SP不足)，面板不重置
		pass

func _on_skill_button_pressed(card_node: Control):
	"""技能按鈕按下 (新流程：一律打開對話框)"""
	var card_data = card_node.card_data

	if not card_data.active_skill:
		print("❌ 該卡片沒有主動技能！")
		return

	# 無論技能類型，一律先打開確認對話框
	cancel_skill_targeting() # 先取消可能存在的上一個目標選擇
	
	# 注意：這裡的 target 參數固定傳入 null
	skill_dialog.show_skill_dialog(card_data, null, battle_manager)

func _on_skill_confirmed(card: CardData, _target: EnemyData):
	"""(新流程) 玩家在對話框點了確定"""
	
	# 因為是從第一層對話框來的，target 參數此時必定是 null
	
	var skill = card.active_skill
	if not skill: return

	# 1. 檢查技能是否需要選擇目標
	if skill.target_type == Constants.TargetType.SINGLE_ENEMY:
		# 是單體技能：進入「等待目標」狀態
		is_selecting_skill_target = true
		card_for_skill_targeting = card
		print("🎯 [技能] %s 準備就緒，請點擊一個敵人作為目標..." % card.active_skill.skill_name)
		
		# 高亮敵人，提示玩家選擇
		highlight_enemies_for_targeting(true) 
		_update_ui_interactivity() # ✅ 新增
	
	else:
		# 2. 不需要目標 (例如AOE或自身)，直接發動
		print("✨ [技能] %s (AOE/自身) 立即發動！" % card.active_skill.skill_name)
		if battle_manager.use_card_active_skill(card, null):
			update_all_cards()
			update_all_enemies()
			# ✅ 更新技能標記顯示
			update_skill_markers()

		# (以防萬一，重置瞄準狀態)
		cancel_skill_targeting()

func _on_rest_pressed():
	"""休息按鈕按下"""
	cancel_skill_targeting()
	battle_manager.player_rest() # 這裡會清空倍率

	# ✅ 重置所有卡片的發光特效
	for card_node in card_nodes:
		if card_node and is_instance_valid(card_node):
			card_node.reset_slash_effects()

	# ✨ 休息後，也重置元素面板
	#element_panel.start_element_combat()
	
func _on_leave_battle_pressed():
	"""玩家點擊離開戰鬥按鈕"""
	print("🏃‍♂️ 玩家放棄戰鬥，返回關卡選擇...")
	
	# 
	GameManager.goto_stage_select()

func _on_turn_changed(is_player_turn: bool):
	"""回合切換"""
	update_player_stats()

	if is_player_turn:
		# ✅ 在新回合開始時，重置所有卡牌倍率為 1.0
		var reset_multipliers = {
			Constants.Element.METAL: 1.0,
			Constants.Element.WOOD: 1.0,
			Constants.Element.WATER: 1.0,
			Constants.Element.FIRE: 1.0,
			Constants.Element.EARTH: 1.0,
			Constants.Element.HEART: 1.0
		}
		for card_node in card_nodes:
			if is_instance_valid(card_node):
				card_node.update_atk_display(reset_multipliers)
				# ✅ 重置所有卡片的發光特效
				card_node.reset_slash_effects()

		update_all_cards()
		element_panel.start_element_combat()
		orb_storage_container.visible = true
		if nexttime_label:
			# 只有在有預排靈珠時才顯示提示
			nexttime_label.visible = not next_orb_sequence.is_empty()
		# ✅ 更新技能標記（回合開始時，BUFF可能已經過期）
		update_skill_markers()

	else:
		# 敵人回合開始時，停止元素面板
		element_panel.stop_element_combat()
		orb_storage_container.visible = false
		if nexttime_label:
			nexttime_label.visible = false

		# ✅ 回合結束時，重置所有敵人的盾牌狀態（停止閃爍）
		# 因為條件追蹤數據會在下一回合開始時清除，盾牌應該回到未達成狀態
		for enemy_node in enemy_nodes:
			if enemy_node and is_instance_valid(enemy_node):
				enemy_node.update_shield_status(false)

		execute_enemy_turn()
		update_all_cards()
		# ✅ 更新技能標記
		update_skill_markers()


	# ❌ 刪除這裡所有 set_interactable 的程式碼...
	# var can_act = is_player_turn
	# for card_node in card_nodes:
	# 	card_node.set_interactable(can_act)
	# rest_button.set_interactable(can_act)
	# leave_battle_button.set_interactable(can_act)
	
	# ✅ ...只留下這一行
	_update_ui_interactivity()

func _on_enemy_clicked(enemy_node: Control):
	"""敵人被點擊"""
	selected_enemy = enemy_node
	var enemy_data = enemy_node.get_enemy_data()
	
	if not enemy_data: return
	
	print("選擇敵人: %s" % enemy_data.enemy_name)

	# (新流程) 檢查是否正在等待技能目標
	if is_selecting_skill_target:
		
		# 確保敵人是活的
		if enemy_data.is_alive:
			print("✅ [技能] 選定目標: %s，立即發動！" % enemy_data.enemy_name)

			# (新流程) 直接發動技能
			if battle_manager.use_card_active_skill(card_for_skill_targeting, enemy_data):
				update_all_cards()
				update_all_enemies()
				# ✅ 更新技能標記顯示
				update_skill_markers()

			# (新流程) 重置狀態，退出瞄準模式
			cancel_skill_targeting()
			
		else:
			print("❌ [技能] 選擇了無效的目標（已死亡），請重新選擇")
			# 注意：這裡故意不呼叫 cancel_skill_targeting()，讓玩家可以選別的敵人

func _on_enemy_right_clicked(enemy_node: Control):
	"""敵人被右鍵點擊 - 顯示技能面板"""
	var enemy_data = enemy_node.get_enemy_data()
	if not enemy_data:
		return

	print("查看敵人技能: %s" % enemy_data.enemy_name)
	show_enemy_skill_panel(enemy_data)

func show_enemy_skill_panel(enemy_data: EnemyData):
	"""顯示敵人技能面板"""
	# 動態載入技能面板場景
	var skill_panel_script = preload("res://scripts/ui/EnemySkillPanel.gd")

	# 創建 CanvasLayer 確保在最上層
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # 設置為最高層
	add_child(canvas_layer)

	# 創建面板容器
	var panel = PanelContainer.new()
	panel.script = skill_panel_script

	# 設置樣式 - 不透明背景 + 白色邊框
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.2, 1.0)  # 深色不透明背景
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color(1.0, 1.0, 1.0, 1.0)  # 白色邊框
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style_box)

	# 設置大小和位置
	panel.custom_minimum_size = Vector2(400, 300)
	panel.position = Vector2(get_viewport().size) / 2 - panel.custom_minimum_size / 2  # 居中

	# 創建內部結構
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	margin.add_child(vbox)

	# 標題
	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "%s - 技能列表" % enemy_data.enemy_name
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# 滾動容器
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)

	var skill_list_container = VBoxContainer.new()
	skill_list_container.name = "SkillList"
	scroll.add_child(skill_list_container)

	# 關閉按鈕
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "關閉 (ESC)"
	vbox.add_child(close_btn)

	# 添加到 CanvasLayer
	canvas_layer.add_child(panel)

	# 調用 setup（必須在添加到場景樹之後）
	panel.setup(enemy_data)

	# 連接關閉信號 - 同時刪除 CanvasLayer
	close_btn.pressed.connect(func():
		canvas_layer.queue_free()
	)

# ==================== 戰鬥管理器回調 ====================

func _on_skill_cancelled():
	"""玩家在對話框點了取消"""
	print("❌ [技能] 玩家取消了技能使用")
	cancel_skill_targeting()

func cancel_skill_targeting():
	"""重置技能瞄準狀態"""
	if not is_selecting_skill_target:
		return
		
	print("...取消技能瞄準狀態...")
	is_selecting_skill_target = false
	card_for_skill_targeting = null
	
	# 取消敵人的高亮
	highlight_enemies_for_targeting(false)
	_update_ui_interactivity() # ✅ 新增

func highlight_enemies_for_targeting(is_highlighted: bool):
	"""高亮/取消高亮 敵人以提示玩家"""
	
	if targeting_label:
		targeting_label.visible = is_highlighted

	# 先停止並清除所有舊的閃爍動畫
	for t in targeting_tweens:
		if t and t.is_valid():
			t.kill() # 停止動畫
	targeting_tweens.clear()

	# 遍歷所有敵人節點
	for enemy_node in enemy_nodes:
		if is_instance_valid(enemy_node):
			
			if is_highlighted and enemy_node.get_enemy_data().is_alive:
				# 創建新的 Tween 動畫
				var tween = create_tween()
				tween.bind_node(self)
				tween.set_loops(-1) # 讓它無限循環
				tween.set_trans(Tween.TRANS_SINE) # 使用SINE曲線比較平滑
				tween.set_ease(Tween.EASE_IN_OUT)
				
				# 從 亮 (1.5) -> 暗 (1.0) -> 亮 (1.5)
				tween.tween_property(enemy_node, "modulate", Color(1.5, 1.5, 1.5), 0.4)
				tween.tween_property(enemy_node, "modulate", Color(1.0, 1.0, 1.0), 0.4)
				
				targeting_tweens.append(tween) # 儲存這個動畫，方便之後停止
				
			else:
				# 如果是取消高亮，恢復正常顏色
				if enemy_node.get_enemy_data().is_alive:
					enemy_node.modulate = Color.WHITE
				else:
					enemy_node.modulate = Color(0.3, 0.3, 0.3, 0.5)

# ==================== 攝影機震動 ====================

func shake_camera(amount: float = 10.0, duration: float = 0.2):
	"""(新函式) 震動攝影機"""
	if not camera:
		print("Error: 找不到 Camera2D 節點")
		return

	# ✅ 修正：停止舊的 Tween
	if camera_shake_tween and camera_shake_tween.is_valid():
		camera_shake_tween.kill()
		
	camera_shake_tween = create_tween() # ✅ 修正：賦值給變數
	camera_shake_tween.set_trans(Tween.TRANS_BOUNCE)
	camera_shake_tween.set_ease(Tween.EASE_IN_OUT)
	
	var original_offset = camera.offset 
	
	var shake_time = duration / 4.0
	camera_shake_tween.tween_property(camera, "offset", original_offset + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), shake_time)
	camera_shake_tween.tween_property(camera, "offset", original_offset + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), shake_time)
	camera_shake_tween.tween_property(camera, "offset", original_offset + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), shake_time)
	
	camera_shake_tween.tween_property(camera, "offset", original_offset, shake_time)

# ==================== WAVE 轉場動畫 ====================

func show_wave_transition(next_wave: int, total_waves: int):
	"""
	顯示 WAVE 轉場動畫
	- 2秒動畫時長
	- 顯示 "WAVE X/Y" 文字淡入淡出
	- 相機移動效果
	"""
	print("🌊 [WAVE 轉場] 顯示轉場動畫：WAVE %d/%d" % [next_wave, total_waves])
	AudioManager.play_sfx("wave_move")  # 或你的音效名稱

	# ✅ 1. 創建轉場文字 Label
	var wave_label = Label.new()
	wave_label.name = "WaveTransitionLabel"
	wave_label.text = "WAVE %d/%d" % [next_wave, total_waves]

	# 設定文字樣式
	wave_label.add_theme_font_size_override("font_size", 80)
	wave_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))  # 金黃色
	wave_label.add_theme_color_override("font_outline_color", Color(0.2, 0.2, 0.2))
	wave_label.add_theme_constant_override("outline_size", 5)

	# 設定位置（居中）
	wave_label.anchor_left = 0.5
	wave_label.anchor_right = 0.5
	wave_label.anchor_top = 0.5
	wave_label.anchor_bottom = 0.5
	wave_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wave_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	wave_label.pivot_offset = wave_label.size / 2
	wave_label.position = -wave_label.size / 2
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 初始透明度為0
	wave_label.modulate.a = 0.0

	# 添加到場景（使用 CanvasLayer 確保在最上層）
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # 確保在最上層
	add_child(canvas_layer)
	canvas_layer.add_child(wave_label)

	# ✅ 2. 創建動畫 Tween
	var transition_tween = create_tween()
	transition_tween.set_parallel(true)  # 允許多個動畫同時進行

	# ✅ 2.1 文字淡入淡出動畫（共2秒）
	# 淡入 (0.5秒)
	transition_tween.tween_property(wave_label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 保持 (1.0秒)
	transition_tween.tween_property(wave_label, "modulate:a", 1.0, 1.0).set_delay(0.5)
	# 淡出 (0.5秒)
	transition_tween.tween_property(wave_label, "modulate:a", 0.0, 0.5).set_delay(1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# ✅ 2.2 文字縮放動畫（從小到大，再回到正常）
	wave_label.scale = Vector2(0.5, 0.5)
	transition_tween.tween_property(wave_label, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	transition_tween.tween_property(wave_label, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# ✅ 3. 相機移動效果（模擬移動感覺）
	if camera:
		var original_offset = camera.offset

		# 相機向右滑動然後回中
		transition_tween.tween_property(camera, "offset", original_offset + Vector2(50, 0), 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		transition_tween.tween_property(camera, "offset", original_offset, 1.0).set_delay(1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# ✅ 4. 動畫結束後清理
	await get_tree().create_timer(2.0).timeout
	canvas_layer.queue_free()

	print("🌊 [WAVE 轉場] 動畫結束")

# ==================== 戰鬥開場動畫 ====================

func show_battle_start_animation():
	"""
	顯示戰鬥開場動畫
	- 畫面淡入效果
	- 顯示 "WAVE 1/X" 文字
	"""
	var current_wave = battle_manager.current_wave
	var total_waves = battle_manager.total_waves

	print("⚔️ [戰鬥開場] 顯示開場動畫：WAVE %d/%d" % [current_wave, total_waves])

	# ✅ 播放進場音效
	AudioManager.play_sfx("battle_start")

	# ✅ 1. 創建全屏黑色遮罩（用於淡入效果）
	var fade_overlay = ColorRect.new()
	fade_overlay.name = "BattleStartFadeOverlay"
	fade_overlay.color = Color(0, 0, 0, 1.0)  # 完全不透明黑色
	fade_overlay.anchor_right = 1.0
	fade_overlay.anchor_bottom = 1.0

	# 使用 CanvasLayer 確保在最上層
	var fade_canvas_layer = CanvasLayer.new()
	fade_canvas_layer.layer = 100  # 最上層
	add_child(fade_canvas_layer)
	fade_canvas_layer.add_child(fade_overlay)

	# ✅ 2. 黑色遮罩淡出（0.8秒）
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 等待淡入完成一半
	await get_tree().create_timer(0.4).timeout

	# ✅ 3. 創建 WAVE X/Y 文字
	var wave_label = Label.new()
	wave_label.name = "BattleStartWaveLabel"
	wave_label.text = "WAVE %d/%d" % [current_wave, total_waves]

	# 設定文字樣式
	wave_label.add_theme_font_size_override("font_size", 80)
	wave_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))  # 金黃色
	wave_label.add_theme_color_override("font_outline_color", Color(0.2, 0.2, 0.2))
	wave_label.add_theme_constant_override("outline_size", 5)

	# 設定位置（居中）
	wave_label.anchor_left = 0.5
	wave_label.anchor_right = 0.5
	wave_label.anchor_top = 0.5
	wave_label.anchor_bottom = 0.5
	wave_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wave_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	wave_label.pivot_offset = wave_label.size / 2
	wave_label.position = -wave_label.size / 2
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 初始透明度和縮放
	wave_label.modulate.a = 0.0
	wave_label.scale = Vector2(0.5, 0.5)

	# 使用新的 CanvasLayer（在淡入遮罩之上）
	var wave_canvas_layer = CanvasLayer.new()
	wave_canvas_layer.layer = 101  # 比淡入遮罩更高
	add_child(wave_canvas_layer)
	wave_canvas_layer.add_child(wave_label)

	# ✅ 4. WAVE 文字動畫
	var text_tween = create_tween()
	text_tween.set_parallel(true)

	# 文字淡入 + 彈性放大
	text_tween.tween_property(wave_label, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	text_tween.tween_property(wave_label, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 等待 1.2 秒（文字顯示時間）
	await get_tree().create_timer(1.2).timeout

	# ✅ 5. WAVE 文字淡出
	var fadeout_tween = create_tween()
	fadeout_tween.tween_property(wave_label, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# 等待淡出完成
	await get_tree().create_timer(0.4).timeout

	# ✅ 6. 清理
	fade_canvas_layer.queue_free()
	wave_canvas_layer.queue_free()

	print("⚔️ [戰鬥開場] 動畫結束")

# ==================== 勝利/失敗動畫 ====================

func show_battle_result_animation(victory: bool):
	"""
	顯示戰鬥結果動畫
	- 背景變灰（遮罩效果）
	- 禁用所有操作
	- 顯示勝利/失敗文字動畫
	"""
	print("🎬 [戰鬥結束] 顯示結果動畫：%s" % ("勝利" if victory else "失敗"))
	# ⬅️ 在這裡插入音效
	if victory:
		AudioManager.play_sfx("victory")
	else:
		AudioManager.play_sfx("defeat")

	# ✅ 1. 禁用所有操作
	disable_all_interactions()

	# ✅ 2. 創建背景遮罩（半透明黑色）
	var overlay = ColorRect.new()
	overlay.name = "BattleResultOverlay"
	overlay.color = Color(0, 0, 0, 0)  # 初始透明
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0

	# 使用 CanvasLayer 確保在最上層
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 999  # 最上層
	add_child(canvas_layer)
	canvas_layer.add_child(overlay)

	# ✅ 3. 背景淡入動畫（變灰）
	var overlay_tween = create_tween()
	overlay_tween.tween_property(overlay, "color", Color(0, 0, 0, 0.7), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 等待背景淡入完成
	await get_tree().create_timer(0.3).timeout

	# ✅ 4. 創建結果文字
	var result_label = Label.new()
	result_label.name = "BattleResultLabel"

	if victory:
		# 勝利樣式
		result_label.text = "勝利！"
		result_label.add_theme_font_size_override("font_size", 120)
		result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))  # 金黃色
		result_label.add_theme_color_override("font_outline_color", Color(0.8, 0.6, 0.0))
		result_label.add_theme_constant_override("outline_size", 8)
	else:
		# 失敗樣式
		result_label.text = "失敗..."
		result_label.add_theme_font_size_override("font_size", 100)
		result_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))  # 紅色
		result_label.add_theme_color_override("font_outline_color", Color(0.5, 0.0, 0.0))
		result_label.add_theme_constant_override("outline_size", 8)

	# 設定位置（居中）
	result_label.anchor_left = 0.5
	result_label.anchor_right = 0.5
	result_label.anchor_top = 0.5
	result_label.anchor_bottom = 0.5
	result_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	result_label.pivot_offset = result_label.size / 2
	result_label.position = -result_label.size / 2
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 初始透明度和縮放
	result_label.modulate.a = 0.0
	result_label.scale = Vector2(0.3, 0.3)

	canvas_layer.add_child(result_label)

	# ✅ 5. 文字動畫
	var text_tween = create_tween()
	text_tween.set_parallel(true)

	if victory:
		# 勝利動畫：彈性放大 + 淡入
		text_tween.tween_property(result_label, "scale", Vector2(1.3, 1.3), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		text_tween.tween_property(result_label, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		# 勝利後的呼吸效果
		await get_tree().create_timer(0.6).timeout
		var breath_tween = create_tween()
		breath_tween.bind_node(self)
		breath_tween.set_loops(-1)
		breath_tween.tween_property(result_label, "scale", Vector2(1.35, 1.35), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		breath_tween.tween_property(result_label, "scale", Vector2(1.25, 1.25), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# 勝利光暈效果（使用旋轉）
		var glow_tween = create_tween()
		glow_tween.bind_node(self)
		glow_tween.tween_property(result_label, "rotation", deg_to_rad(5), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glow_tween.tween_property(result_label, "rotation", deg_to_rad(-5), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	else:
		# 失敗動畫：震動 + 淡入
		text_tween.tween_property(result_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		text_tween.tween_property(result_label, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		# 失敗後的下墜效果
		await get_tree().create_timer(0.5).timeout
		var fall_tween = create_tween()
		fall_tween.set_parallel(true)
		fall_tween.tween_property(result_label, "position:y", result_label.position.y + 20, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		fall_tween.tween_property(result_label, "modulate:a", 0.8, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

		# 相機震動效果（失敗時）
		shake_camera(15, 0.3)

	# ✅ 6. 等待動畫播放（總共約2秒）
	await get_tree().create_timer(2.0).timeout

	print("🎬 [戰鬥結束] 結果動畫結束，準備跳轉")

func disable_all_interactions():
	"""禁用所有戰鬥交互"""
	# 禁用休息按鈕
	if rest_button:
		rest_button.disabled = true

	# 禁用離開戰鬥按鈕
	if leave_battle_button:
		leave_battle_button.disabled = true

	# 禁用所有卡片交互
	for card_node in card_nodes:
		if is_instance_valid(card_node):
			card_node.set_process_input(false)
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 禁用所有敵人交互
	for enemy_node in enemy_nodes:
		if is_instance_valid(enemy_node):
			enemy_node.set_process_input(false)
			enemy_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 禁用元素面板
	if element_panel:
		element_panel.set_process_input(false)
		element_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	print("🔒 [戰鬥結束] 已禁用所有交互")

# ==================== 敵人回合 ====================

func execute_enemy_turn():
	"""執行敵人回合（UI層）"""
	print("\n👾 === 敵人回合 ===\n")

	for i in range(battle_manager.enemies.size()):
		var enemy = battle_manager.enemies[i]

		if not enemy.is_alive:
			continue

		# 更新CD
		enemy.tick_cd()

		# 檢查是否該攻擊
		if enemy.should_attack():
			AudioManager.play_sfx("enemy_attack")
			# 1. 播放敵人攻擊動畫 (衝刺)
			if i < enemy_nodes.size():
				enemy_nodes[i].play_attack_animation()
			# 2. 等待動畫 "命中" 的時間
			await get_tree().create_timer(0.2).timeout 
			# 3. 立即結算傷害 (這會觸發 damage_dealt 信號，產生數字)
			await battle_manager.execute_enemy_attack(enemy) 
			# 4. 立即播放攝影機震動
			shake_camera(10, 0.2)
			# 5. 立即播放玩家受擊動畫 (血條閃爍)
			player_stats.play_damage_effect()
			# 6. 重置CD
			enemy.reset_cd()
			# 7. 等待剩餘的動畫時間 (0.6秒)，讓動畫播放完
			await get_tree().create_timer(0.6).timeout  
			# 檢查是否失敗
			if battle_manager.current_phase == Constants.BattlePhase.BATTLE_END:
				return
			await get_tree().create_timer(0.3).timeout
		else:
			print("  %s 待機中... (CD: %d)" % [enemy.enemy_name, enemy.current_cd])

	# 敵人回合結束
	await get_tree().create_timer(0.5).timeout
	battle_manager.end_enemy_turn()

func _on_battle_ended(victory: bool):
	"""戰鬥結束"""
	print("戰鬥結束！勝利: %s" % victory)

	# ✅ 顯示勝利/失敗動畫（約2秒）
	await show_battle_result_animation(victory)

	# ✅ 動畫結束後再延遲0.5秒，讓玩家有時間看到結果
	await get_tree().create_timer(0.5).timeout

	# 跳轉到獎勵結算畫面
	GameManager.goto_reward(victory, GameManager.battle_rewards)

func _on_hp_changed(current: int, max_hp: int):
	"""HP變化"""
	# 1. 更新 PlayerStats (舊有程式碼)
	#player_stats.update_hp(current, max_hp)
	
	# 2. 更新您在 PlayerArea 新增的血條 (新程式碼)
	if player_hp_bar:
		player_hp_bar.max_value = max_hp
		player_hp_bar.value = current
		player_stats.play_damage_effect()

	# 3. 更新血量標籤 (顯示 當前/最大 格式)
	if player_hp_label:
		player_hp_label.text = "%d/%d" % [current, max_hp]

	# 4. (可選) 讓血條和標籤在低血量時變色
	var color_to_use = Color.DARK_GREEN  # 預設的填充顏色（白色）
	if current < max_hp * 0.3:
		color_to_use = Color.RED   # 低血量時的填充顏色（紅色）
	
	if player_hp_bar:
		# --- 修正開始 ---
		# 錯誤：player_hp_bar.modulate = color_to_use
		
		# 正確：我們只修改 "fill" 樣式的背景色
		
		# 1. 獲取當前的 "fill" 樣式
		var fill_stylebox = player_hp_bar.get_theme_stylebox("fill")
		
		# 2. 複製一份，避免修改到全局預設主題
		var new_fill_stylebox = fill_stylebox.duplicate()
		
		# 3. 設置新樣式的顏色
		if new_fill_stylebox is StyleBoxFlat:
			new_fill_stylebox.bg_color = color_to_use
		
		# 4. 將新樣式應用回 HPBar
		player_hp_bar.add_theme_stylebox_override("fill", new_fill_stylebox)
		
		# 5. 確保節點本身的 modulate 是正常的
		player_hp_bar.modulate = Color.WHITE
		# --- 修正結束 ---

	#if player_hp_label:
		#player_hp_label.modulate = color_to_use

func _on_enemy_died(dead_enemy_data: EnemyData):
	"""敵人死亡 (新版：接收 EnemyData 物件)"""
	var node_to_remove = null

	#
	for node in enemy_nodes:
		#
		if node.get_enemy_data() == dead_enemy_data:
			node_to_remove = node
			break

	if node_to_remove:
		# ✨ 敵人死亡時播放爆炸特效
		var death_pos = node_to_remove.global_position + (node_to_remove.size / 2)
		VFXManager.play_effect("explosion", death_pos)

		enemy_nodes.erase(node_to_remove)
		node_to_remove.queue_free()

	#
	#
	update_all_enemies()

func _on_card_sp_changed(_card: CardData):
	"""卡片SP變化"""
	update_all_cards()

func _on_damage_dealt(target_id_or_name: String, damage: int):
	"""(新函式) 接收 BattleManager 的傷害信號並產生數字"""

	# ✅ 修正：使用你 preload 的 "damage_number_scene"
	var text_instance = damage_number_scene.instantiate()

	var spawn_pos: Vector2
	var node_color: Color

	if target_id_or_name == "玩家":
		if player_hp_bar:
			spawn_pos = player_hp_bar.global_position + (player_hp_bar.size / 2)
		else:
			spawn_pos = player_stats.global_position + (player_stats.size / 2)
		node_color = Color(1.0, 0.4, 0.4)
		$UI.add_child(text_instance) #
		text_instance.position = spawn_pos - Vector2(0, 40) #

		# ✨ 玩家受傷特效
		VFXManager.play_effect("hit", spawn_pos)
	else:
		var target_node: Control = null
		# 嘗試按 instance_id 匹配（新方式）
		for node in enemy_nodes:
			var enemy_data = node.get_enemy_data()
			if str(enemy_data.get_instance_id()) == target_id_or_name:
				target_node = node
				break

		# 如果沒找到，嘗試按 enemy_id 匹配（兼容舊方式）
		if not target_node:
			for node in enemy_nodes:
				if node.get_enemy_data().enemy_id == target_id_or_name:
					target_node = node
					break

		if target_node:
			spawn_pos = target_node.global_position + (target_node.size / 2)
			if is_instance_valid(target_node) and target_node.has_method("shake"):
				target_node.shake()

			# ✨ 敵人受傷特效（根據傷害大小選擇不同效果）
			if damage >= target_node.get_enemy_data().max_hp * 0.3:
				# 大傷害 - 使用暴擊特效
				VFXManager.play_effect("critical", spawn_pos)
			else:
				# 普通傷害 - 使用打擊特效
				VFXManager.play_effect("hit", spawn_pos)
		else:
			spawn_pos = enemy_container.global_position
			# ✨ 找不到目標也播放特效
			VFXManager.play_effect("hit", spawn_pos)

		node_color = Color.WHITE
		add_child(text_instance)
		text_instance.global_position = spawn_pos - Vector2(0, 50)

	text_instance.add_theme_color_override("font_color", node_color)

	# ✅ 關鍵：在設定好位置「之後」，才呼叫 start()
	text_instance.start(damage)

# ==================== 元素戰鬥回調 ====================
# 🔔 3. 新增 _on_slashing_phase_finished 函式
func _on_slashing_phase_finished(multipliers: Dictionary):
	"""(新) 斬擊階段結束時，接收倍率並交給 BattleManager"""
	print("BattleScene: 收到斬擊結束信號，正在儲存倍率...")
	battle_manager.set_element_multipliers(multipliers)

	# ✅ 更新敵人顯示（因為 END_TURN_DAMAGE 可能已經造成傷害）
	update_all_enemies()

func _on_healing_phase_finished(heal_amount: int):
	"""(新) 收到 ElementPanel 的治療結算"""
	if battle_manager and heal_amount > 0:
		# BattleManager 已經有 heal 函數了，直接呼叫
		battle_manager.heal(heal_amount)

		# ✨ 播放治療特效
		if player_hp_bar:
			var heal_pos = player_hp_bar.global_position + (player_hp_bar.size / 2)
			VFXManager.play_effect("heal", heal_pos)
		else:
			var heal_pos = player_stats.global_position + (player_stats.size / 2)
			VFXManager.play_effect("heal", heal_pos)
		
func _on_slashing_started():
	"""(新) 斬擊開始時，鎖定UI"""
	is_slashing = true
	_update_ui_interactivity()

	# ✅ 重置所有卡片的斬擊視覺效果
	for card_node in card_nodes:
		if card_node and is_instance_valid(card_node):
			card_node.reset_slash_effects()

	# ✅ 條件追蹤數據由 ElementPanel 重置，這裡不需要處理

	# ✅ 重置所有敵人的盾牌狀態（條件未達成）
	for enemy_node in enemy_nodes:
		if enemy_node and is_instance_valid(enemy_node):
			enemy_node.update_shield_status(false)

func _on_orb_eliminated(element: Constants.Element, _combo_count: int, _eliminate_count: int):
	"""當消除靈珠時，通知對應屬性的卡片播放動畫"""
	for card_node in card_nodes:
		if card_node and is_instance_valid(card_node):
			card_node.on_element_eliminated(element)

	# ✅ 條件追蹤數據由 ElementPanel 更新，這裡只需檢查盾牌狀態
	check_and_update_enemy_conditions()

func _on_slashing_ended():
	"""(新) 斬擊結束時，解鎖UI"""
	is_slashing = false
	_update_ui_interactivity()

	# ✅ 條件追蹤數據由 ElementPanel 重置（在 ElementPanel 的斬擊結束回調中）

	# ✅ 修復 BUG 2：斬擊結束時，重新檢查條件狀態（而不是直接設為 false）
	# 如果在回合內條件還是達成的，盾牌應該繼續閃爍
	check_and_update_enemy_conditions()

func _update_ui_interactivity():
	"""(新) 統一管理所有UI的互動狀態"""
	
	# 檢查是否可以互動：必須是玩家回合、不在斬擊中、也不在選擇技能目標
	var can_act = (battle_manager.current_phase == Constants.BattlePhase.PLAYER_TURN) and \
				  (not is_slashing) and \
				  (not is_selecting_skill_target)

	# 更新卡片
	for card_node in card_nodes:
		if is_instance_valid(card_node):
			card_node.set_interactable(can_act)

	# 更新按鈕
	rest_button.set_interactable(can_act)
	leave_battle_button.set_interactable(can_act)
	
	for button in orb_storage_buttons.values():
		if can_act:
			# 解鎖按鈕 (它會自動根據數量決定是否禁用)
			button.set_locked(false)
		else:
			# 強制鎖定按鈕
			button.set_locked(true)
			
func _update_next_orb_display(clear_first: bool = false): # ✅ 1. 修改函數簽名
	"""(新) 更新 'nexttime_label' 來顯示玩家點擊的序列"""
	if not nexttime_label: 
		return

	# ✅ 2. 如果被要求，先重置文字
	if clear_first:
		nexttime_label.text = ""
		nexttime_label.visible = true # 重置時就顯示

	if next_orb_sequence.is_empty():
		# 如果序列是空的...
		if not clear_first: # 且不是剛被重置 (例如回合剛開始)
			nexttime_label.visible = false # 則隱藏
			nexttime_label.text = ""
		# (如果是剛被重置，標籤會顯示 "預排：")
	else:
		# 如果序列有內容，建立文字
		var display_text = "" 
		
		for orb_data in next_orb_sequence:
			var element = orb_data["element"]
			display_text += ELEMENT_NAMES.get(element, "?")
		
		nexttime_label.text = display_text
		nexttime_label.visible = true

# ✅ 修正 #3：您缺少這個函數，請將它加到腳本的*最末尾*
func get_and_clear_next_orb_sequence() -> Array:
	"""(新) 供 BattleManager 在回合結束時調用"""
	if next_orb_sequence.is_empty():
		return []
		
	var sequence_to_send = next_orb_sequence.duplicate()
	next_orb_sequence.clear()
	print("BattleScene: 鎖定並傳送序列 (LIFO): ", sequence_to_send)
	return sequence_to_send
	
func get_stored_orb_count(element: Constants.Element) -> int:
		"""(新) 供 BattleManager/技能查詢儲存中的靈珠數量"""
		return stored_orbs.get(element, 0)

func get_max_stored_orbs(element = null) -> int:
		"""(新) 供 BattleManager/技能查詢儲存上限（支援容量加成）"""
		var base_capacity = MAX_STORED_ORBS

		# ✅ 檢查是否有容量加成
		if element != null and battle_manager and battle_manager.has_meta("orb_capacity_boost"):
			var boosts = battle_manager.get_meta("orb_capacity_boost")
			if boosts.has(element):
				var bonus = boosts[element]
				return base_capacity + bonus

		return base_capacity

func add_stored_orb(element: Constants.Element) -> bool:
		"""供技能效果添加靈珠到儲存庫（支援容量加成）"""
		var max_capacity = get_max_stored_orbs(element)

		if stored_orbs[element] < max_capacity:
			stored_orbs[element] += 1
			update_orb_storage_display()
			print("  [靈珠儲存] 添加 %s 靈珠 (%d/%d)" % [Constants.Element.keys()[element], stored_orbs[element], max_capacity])
			return true
		else:
			print("  [靈珠儲存] %s 靈珠已滿 (%d/%d)" % [Constants.Element.keys()[element], max_capacity, max_capacity])
			return false

# ==================== 條件型技能檢查系統 ====================

func update_all_enemy_shields():
	"""更新所有敵人的盾牌顯示（在技能加載後調用）"""
	print("\n🛡️ 更新所有敵人的盾牌顯示...")
	for enemy_node in enemy_nodes:
		if enemy_node and is_instance_valid(enemy_node):
			enemy_node.update_shield_visibility()

func check_and_update_enemy_conditions():
	"""檢查所有敵人的條件並更新盾牌狀態"""
	for enemy_node in enemy_nodes:
		if not enemy_node or not is_instance_valid(enemy_node):
			continue

		var enemy_data = enemy_node.get_enemy_data()
		if not enemy_data:
			continue

		# 檢查這個敵人的條件是否達成
		var condition_met = check_enemy_condition(enemy_data)

		# 更新盾牌狀態
		enemy_node.update_shield_status(condition_met)

func check_enemy_condition(enemy_data: EnemyData) -> bool:
	"""檢查單個敵人的條件是否達成
	返回 true = 條件達成，false = 條件未達成
	"""
	if not enemy_data or not battle_manager:
		return false

	# 從 BattleManager meta 讀取條件追蹤數據
	var current_combo = battle_manager.get_meta("current_combo", 0)
	var orb_totals = battle_manager.get_meta("current_orb_totals", {})
	var continuous_element = battle_manager.get_meta("current_continuous_element", -1)
	var continuous_count = battle_manager.get_meta("current_continuous_count", 0)
	var unique_elements = battle_manager.get_meta("current_unique_elements", [])

	# 檢查被動技能的條件
	for skill in enemy_data.passive_skills:
		if not skill:
			continue

		# 獲取技能的效果列表（支持 EnemySkillWrapper）
		var effects = []
		if "json_effects" in skill:
			effects = skill.json_effects
		elif "effects" in skill:
			effects = skill.effects

		for effect in effects:
			var effect_type = effect.get("effect_type", "")

			match effect_type:
				"REQUIRE_COMBO":
					var required_combo = effect.get("required_combo", 0)
					if current_combo < required_combo:
						return false  # 條件未達成

				"REQUIRE_COMBO_EXACT":
					var required_combo = effect.get("required_combo", 10)
					if current_combo != required_combo:
						return false  # 條件未達成

				"REQUIRE_COMBO_MAX":
					var max_combo = effect.get("max_combo", 10)
					if current_combo > max_combo:
						return false  # 條件未達成

				"REQUIRE_ORB_TOTAL":
					var required_element = Constants.Element.get(effect.get("required_element", "FIRE"))
					var required_count = effect.get("required_count", 0)
					var current_count = orb_totals.get(required_element, 0)
					if current_count < required_count:
						return false  # 條件未達成

				"REQUIRE_ORB_CONTINUOUS":
					var required_element = Constants.Element.get(effect.get("required_element", "FIRE"))
					var required_count = effect.get("required_count", 0)
					# 檢查連續消除的元素是否匹配
					if continuous_element != required_element or continuous_count < required_count:
						return false  # 條件未達成

				"REQUIRE_ELEMENTS":
					var required_unique = effect.get("required_unique_elements", 0)
					if unique_elements.size() < required_unique:
						return false  # 條件未達成

				"REQUIRE_STORED_ORB_MIN":
					var requirements_list = effect.get("requirements", [])
					for req in requirements_list:
						var element_str = req.get("element", "FIRE")
						var required_count = req.get("count", 0)
						var element = Constants.Element.get(element_str)
						var current_count = get_stored_orb_count(element)
						if current_count < required_count:
							return false  # 條件未達成

				"REQUIRE_STORED_ORB_EXACT":
					var requirements_list = effect.get("requirements", [])
					for req in requirements_list:
						var element_str = req.get("element", "FIRE")
						var required_count = req.get("count", 0)
						var element = Constants.Element.get(element_str)
						var current_count = get_stored_orb_count(element)
						if current_count != required_count:
							return false  # 條件未達成

				"REQUIRE_ENEMY_ATTACK":
					var instance_id = abs(enemy_data.get_instance_id())
					var enemy_attack_key = "enemy_has_attacked_%d" % instance_id
					var has_attacked = battle_manager.get_meta(enemy_attack_key, false)
					if not has_attacked:
						return false  # 條件未達成

				"DAMAGE_ONCE_ONLY":
					var instance_id = abs(enemy_data.get_instance_id())
					var damage_count_key = "enemy_damage_count_%d" % instance_id
					var damage_count = battle_manager.get_meta(damage_count_key, 0)
					if damage_count >= 1:
						return false  # 條件未達成

	# 所有條件都達成
	return true
