# TestBattle.gd
extends Node2D

var battle_manager: BattleManager

func _ready():
	print("\n========== 完整戰鬥測試 ==========\n")
	
	# 創建戰鬥管理器
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	
	# 連接信號
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.turn_changed.connect(_on_turn_changed)
	battle_manager.hp_changed.connect(_on_hp_changed)
	battle_manager.enemy_died.connect(_on_enemy_died)
	
	# 創建測試隊伍
	var team = create_test_team()
	
	# 創建測試敵人
	var enemies = create_test_enemies()
	
	# 開始戰鬥
	battle_manager.start_battle(team, enemies)
	
	# 模擬戰鬥
	await simulate_battle()

func create_test_team() -> Array[CardData]:
	"""創建測試隊伍"""
	# 使用新的新手冒險者卡牌（001）
	var starter = DataManager.get_card("001")
	if starter == null:
		push_error("無法載入新手冒險者卡牌")
		return []

	var team: Array[CardData] = [starter]
	return team

func create_test_enemies() -> Array[EnemyData]:
	"""創建測試敵人"""
	var slime = EnemyData.new()
	slime.enemy_id = "slime_001"
	slime.enemy_name = "史萊姆"
	slime.max_hp = 20
	slime.base_atk = 3
	slime.attack_cd = 1
	slime.attack_skill_ids = ["enemy_normal_attack"]
	
	var goblin = EnemyData.new()
	goblin.enemy_id = "goblin_001"
	goblin.enemy_name = "哥布林"
	goblin.max_hp = 30
	goblin.base_atk = 6
	goblin.attack_cd = 2
	goblin.passive_skill_ids = ["enemy_passive_defense_50"]  # 防禦50%
	goblin.attack_skill_ids = ["enemy_double_hit"]  # 攻擊兩下
	
	var enemies: Array[EnemyData] = [slime, goblin]
	return enemies

func simulate_battle():
	"""模擬戰鬥流程"""
	await get_tree().create_timer(1.0).timeout

	if battle_manager.player_team.is_empty():
		push_error("沒有可用的卡牌")
		return

	var starter = battle_manager.player_team[0]

	# 自動戰鬥循環
	while battle_manager.current_phase != Constants.BattlePhase.BATTLE_END:
		await get_tree().create_timer(1.0).timeout

		if battle_manager.current_phase == Constants.BattlePhase.PLAYER_TURN:
			if not battle_manager.enemies.is_empty():
				# 如果有SP就攻擊，否則休息
				if starter.current_sp > 0:
					battle_manager.attack_with_card(starter, battle_manager.enemies[0])
				else:
					battle_manager.player_rest()

				await get_tree().create_timer(0.5).timeout
				battle_manager.end_player_turn()
			else:
				break

		await battle_manager.turn_changed

# ==================== 信號回調 ====================

func _on_battle_ended(victory: bool):
	"""戰鬥結束"""
	if victory:
		print("\n✅ 戰鬥測試通過！")
	else:
		print("\n❌ 戰鬥失敗")

func _on_turn_changed(is_player_turn: bool):
	"""回合切換"""
	pass

func _on_hp_changed(current: int, max_hp: int):
	"""HP變化"""
	pass

func _on_enemy_died(enemy: EnemyData):
	"""敵人死亡"""
	pass
