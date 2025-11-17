# TestScene.gd
extends Node2D

func _ready():
	print("\n========== 測試基礎架構 ==========\n")
	
	# 測試 GameManager
	print("1. 測試 GameManager:")
	print("  當前狀態: ", Constants.GameState.keys()[GameManager.current_state])
	
	# 測試 PlayerDataManager
	print("\n2. 測試 PlayerDataManager:")
	print("  金錢: ", PlayerDataManager.get_gold())
	print("  背包: ", PlayerDataManager.get_inventory())
	
	# 測試 CardData
	print("\n3. 測試 CardData:")
	var test_card = CardData.new()
	test_card.card_name = "測試戰士"
	test_card.base_hp = 15
	test_card.base_atk = 8
	test_card.reset_for_battle()
	print("  ", test_card.get_display_info())
	
	# 測試 EnemyData
	print("\n4. 測試 EnemyData:")
	var test_enemy = EnemyData.new()
	test_enemy.enemy_name = "測試史萊姆"
	test_enemy.max_hp = 20
	test_enemy.base_atk = 5
	test_enemy.reset_for_battle()
	print("  ", test_enemy.get_display_info())
	
	# 測試 SkillRegistry
	print("\n5. 測試 SkillRegistry:")
	print("  已註冊技能數量: ", SkillRegistry.registered_skills.size())
	
	print("\n========== 測試完成 ==========\n")
