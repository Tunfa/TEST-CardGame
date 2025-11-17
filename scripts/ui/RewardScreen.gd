# RewardScreen.gd
# 獎勵結算畫面
extends Control

# ==================== 引用 ====================
@onready var title_label = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var gold_value = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/RewardsContainer/GoldContainer/GoldValue
@onready var exp_value = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/RewardsContainer/ExpContainer/ExpValue
@onready var card_container = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/CardContainer
@onready var cards_label = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/CardsLabel
@onready var continue_button = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/ButtonContainer/ContinueButton
@onready var return_button = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/ButtonContainer/ReturnButton

# ==================== 預製體 ====================
var reward_card_scene = preload("res://scenes/inventory/InventorySlot.tscn")

# ==================== 資料 ====================
var rewards_data: Dictionary = {}
var victory: bool = true

# ==================== 初始化 ====================

func _ready():
	print("🏆 獎勵結算畫面載入")
	
	# 連接按鈕
	continue_button.pressed.connect(_on_continue_pressed)
	return_button.pressed.connect(_on_return_pressed)
	
	# ✅ 修正：
	# 直接從 GameManager 獲取屬性。
	# 這兩個屬性在 GameManager.gd (Source 351) 中有被定義，所以永遠存在。
	# BattleManager (Source 332) 會在戰鬥結束時 (無論勝敗) 負責填入正確的資料。
	rewards_data = GameManager.battle_rewards
	victory = GameManager.battle_victory
	
	# 顯示獎勵
	display_rewards()
	
	# 播放入場動畫
	play_entrance_animation()

# ==================== 顯示獎勵 ====================

func display_rewards():
	"""顯示獎勵資訊"""
	# 設定標題
	if victory:
		title_label.text = "🎉 戰鬥勝利！"
		title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	else:
		title_label.text = "💀 戰鬥失敗..."
		title_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	
	# 顯示金幣
	var gold = rewards_data.get("gold", 0)
	gold_value.text = "+%d" % gold
	
	# 顯示經驗
	var experience = rewards_data.get("exp", 0)
	exp_value.text = "+%d" % experience
	
	# 顯示卡片
	var cards = rewards_data.get("cards", [])
	if cards.is_empty():
		cards_label.text = "🎴 沒有卡片掉落"
		cards_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		cards_label.text = "🎴 獲得卡片："
		create_reward_cards(cards)

func create_reward_cards(card_ids: Array):
	"""創建獎勵卡片顯示"""
	# 清空舊卡片
	for child in card_container.get_children():
		child.queue_free()
	
	# 創建卡片
	for card_id in card_ids:
		var card_slot = reward_card_scene.instantiate()
		card_container.add_child(card_slot)
		card_slot.setup(card_id)
		
		# 播放卡片彈出動畫
		card_slot.scale = Vector2.ZERO
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(card_slot, "scale", Vector2.ONE, 0.5)
		
		# 延遲播放動畫
		await get_tree().create_timer(0.2).timeout

# ==================== 動畫 ====================

func play_entrance_animation():
	"""播放入場動畫"""
	var panel = $CenterContainer/RewardPanel
	
	# 初始狀態
	panel.modulate.a = 0
	panel.scale = Vector2(0.5, 0.5)
	
	# 淡入 + 放大
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(panel, "modulate:a", 1.0, 0.5)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.5)

# ==================== 按鈕回調 ====================

func _on_continue_pressed():
	"""繼續冒險按鈕"""
	print("▶️ 繼續冒險")
	
	# 返回關卡選擇
	GameManager.goto_stage_select()

func _on_return_pressed():
	"""返回主選單按鈕"""
	print("🏠 返回主選單")
	GameManager.goto_main_menu()
