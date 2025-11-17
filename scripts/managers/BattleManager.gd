# BattleManager.gd
# 戰鬥管理器 - 控制整個戰鬥流程
class_name BattleManager
extends Node

# ==================== 信號 ====================
signal turn_changed(is_player_turn: bool)
signal battle_ended(victory: bool)
signal hp_changed(current: int, max: int)
signal enemy_died(enemy: EnemyData)
signal card_sp_changed(card: CardData)
signal skill_activated(skill_name: String, caster_name: String)
signal damage_dealt(target_identifier: String, damage: int)  # Can be enemy instance_id or "玩家"

# ==================== 戰鬥狀態 ====================
var current_phase: Constants.BattlePhase = Constants.BattlePhase.PLAYER_TURN
var slash_ended: bool = false  # ✅ 斬擊結束標記（用於限制 END_TURN_DAMAGE 技能使用時機）
var current_wave: int = 0
var total_waves: int = 1
var leader_bonus_config: Dictionary = {}
var is_wave_complete: bool = false
var current_element_multipliers: Dictionary = {}
var current_orb_rules: Dictionary = {}
signal wave_completed(wave_number: int)
signal next_wave_starting(wave_number: int)
# ==================== 玩家隊伍 ====================
var player_team: Array = []  # 改为普通 Array
var leader_card: CardData = null
var next_orb_sequence_was_locked: bool = false
# ==================== 敵人 ====================
var enemies: Array = []  # 改为普通 Array

# ==================== 玩家數值 ====================
var total_hp: int = 0
var total_recovery: int = 0
var current_hp: int = 0

# ==================== 回合計數 ====================
var turn_count: int = 0

# ==================== 效果管理器 ====================
var effect_manager: EffectManager = null
var skill_effect_handler: SkillEffectHandler = null

# ==================== 戰鬥數據 ====================
var stage_data: StageData = null

# ==================== 初始化 ====================

func _ready():
	effect_manager = EffectManager.new(self)
	add_child(effect_manager)
# ==================== 寶珠規則 (新) ====================

func set_orb_rules_for_turn(rules: Dictionary):
	"""(新) 由技能(TurnStart)呼叫，設定本回合規則 (✅ 序列疊加邏輯)"""
	
	var new_rules = rules.duplicate() # 技能規則 (e.g., {force_element: FIRE, force_count: 5})
	
	# 1. 檢查技能是否有 "強制靈珠" 規則
	if new_rules.has("force_element") and new_rules.has("force_count"):
		
		var force_element = new_rules.get("force_element")
		var force_count = new_rules.get("force_count", 0)
		
		if force_count > 0:
			# 2. 建立一個 "技能靈珠" 序列 (字典陣列)
			var skill_sequence: Array[Dictionary] = []
			for i in range(force_count):
				skill_sequence.push_back({
					"element": force_element,
					"is_player_sequence": false # 標記為非玩家序列 (會觸發25%掉落)
				})
				
			print("  [BattleManager] 技能產生序列 (5顆): ", skill_sequence.size())

			# 3. 檢查是否 *已經有* 玩家排好的序列
			#    (這是 LIFO 堆疊, e.g., [{elm:火, P:true}, {elm:木, P:true}, {elm:火, P:true}])
			var player_sequence = current_orb_rules.get("orb_sequence", [])
			
			# 4. (✅ 核心 + 法 - 修正版)
			#    LIFO 堆疊 (push_back / pop_back)
			#    玩家序列 (3顆) + 技能序列 (5顆)
			#    堆疊底部 -> [ (3顆玩家) , (5顆技能) ] <- 堆疊頂部 (pop_back() 會從這裡拿)
			#    這樣 ElementPanel.pop_back() 會*先*拿到技能的5顆，*再*拿到玩家的3顆
			current_orb_rules["orb_sequence"] = skill_sequence + player_sequence
			
			
			print("  [BattleManager] 序列疊加完成，總長度: ", current_orb_rules["orb_sequence"].size())

		# 5. 移除 'force' 規則，因為它們已被合併到 'orb_sequence' 中
		new_rules.erase("force_element")
		new_rules.erase("force_count")

	# 6. 合併剩餘的規則 (例如 "bonus_rate")
	current_orb_rules.merge(new_rules, true)

func clear_orb_rules_for_turn():
	"""(新) 清除本回合規則"""
	# ✅ 修正：不能清除 orb_sequence，要留給下一回合
	if current_orb_rules.has("bonus_element"):
		current_orb_rules.erase("bonus_element")
	if current_orb_rules.has("bonus_rate"):
		current_orb_rules.erase("bonus_rate")

func get_orb_rules() -> Dictionary:
		"""(新) 供 ElementPanel 讀取"""
		return current_orb_rules

func set_leader_bonus_config(config: Dictionary):
		"""設定隊長技能提供的靈珠/傷害加成資訊"""
		leader_bonus_config = config.duplicate(true)

func get_leader_bonus_config() -> Dictionary:
		"""提供隊長技能額外加成資訊"""
		return leader_bonus_config.duplicate(true)

func get_stored_orb_count(element: Constants.Element) -> int:
		"""查詢戰場儲存中的指定屬性靈珠數量"""
		var battle_scene = get_tree().current_scene
		if battle_scene and battle_scene.has_method("get_stored_orb_count"):
				return battle_scene.get_stored_orb_count(element)
		return 0

func get_max_stored_orbs() -> int:
		"""查詢可儲存靈珠的上限"""
		var battle_scene = get_tree().current_scene
		if battle_scene and battle_scene.has_method("get_max_stored_orbs"):
				return battle_scene.get_max_stored_orbs()
		return 0


# ==================== 戰鬥開始 ====================


func set_element_multipliers(multipliers: Dictionary):
	"""由 BattleScene 呼叫，用來儲存 ElementPanel 計算好的倍率"""
	current_element_multipliers = multipliers
	print("  BattleManager: 收到倍率: %s" % str(current_element_multipliers))

func start_battle(team: Array, enemy_list: Array, stage: StageData = null):

	"""開始戰鬥""" # (把註解移到最上面)
	print("\n" + "=".repeat(50))
	print("⚔️  戰鬥開始！")
	print("=".repeat(50))

	# 保存資料
	player_team.clear()
	for card in team:
		if card is CardData:
			player_team.append(card)

	# ✅ 保存 stage_data（必須在 load_wave_enemies 之前）
	stage_data = stage

	# ✅ 修正後的敵人載入邏輯：
	# 檢查是否使用多波 (waves)
	if stage and not stage.waves.is_empty():
		total_waves = stage.waves.size()
		current_wave = 1
		# 載入第一波 (這個函式會幫我們清空和添加)
		load_wave_enemies(1)
	else:
		# 兼容單波 (使用傳入的 enemy_list)
		enemies.clear() # 1. 先清空 BattleManager 自己的列表
		for enemy in enemy_list: # 2. 再把傳入的敵人一個個加進來
			if enemy is EnemyData:
				enemies.append(enemy)
		total_waves = 1
		current_wave = 1
	
	# 找出隊長
	if not player_team.is_empty():
		leader_card = player_team[0]
	
	# 重置所有卡片
	for card in player_team:
		card.reset_for_battle()
	
	# 重置所有敵人 (現在 `enemies` 列表是正確的了)
	for enemy in enemies:
		enemy.reset_for_battle()
	
	# 清空效果
	effect_manager.clear_effects()
	leader_bonus_config.clear()
	
	# 載入並註冊所有技能
	load_all_skills()

	# ✅ 應用所有永久型技能（隊長技能 + 敵人永久技能）
	apply_all_permanent_skills()

	# 計算最終屬性
	calculate_team_stats()
	
	# 觸發戰鬥開始技能
	trigger_battle_start_skills()
	current_orb_rules.clear()
	next_orb_sequence_was_locked = false
	
	# ✅ --- 新增修正 ---
	# 手動觸發一次「回合開始」技能，確保第一回合的技能 (如 orbs 技能) 生效
	var turn_start_context = SkillContext.new(self, null, null, null)
	effect_manager.trigger_effects(Constants.TriggerTiming.TURN_START, turn_start_context)
	# ✅ --- 修正結束 ---
	
	# 初始化戰鬥狀態
	turn_count = 1
	current_phase = Constants.BattlePhase.PLAYER_TURN
	
	print("\n📊 戰鬥資訊:")
	print("  玩家隊伍: %d 人" % player_team.size())
	print("  總HP: %d" % total_hp)
	print("  總回復力: %d" % total_recovery)
	print("  敵人數量: %d" % enemies.size())
	for enemy in enemies:
		print("    - %s (HP: %d, 攻擊: %d, CD: %d)" % [enemy.enemy_name, enemy.max_hp, enemy.current_atk, enemy.attack_cd])
	
	print("\n--- 第 %d 回合開始（玩家） ---\n" % turn_count)
	turn_changed.emit(true)
	
	
	
func load_wave_enemies(wave_number: int):
	"""載入指定波次的敵人"""
	enemies.clear()

	# ✅ 檢查 stage_data 是否存在
	if not stage_data:
		push_error("❌ BattleManager: stage_data 為空，無法載入波次敵人")
		return

	# ✅ 檢查 waves 是否存在且有效
	if stage_data.waves.is_empty() or wave_number > stage_data.waves.size():
		push_error("❌ BattleManager: 無效的波次編號 %d（總共 %d 波）" % [wave_number, stage_data.waves.size()])
		return

	var wave_config = stage_data.waves[wave_number - 1]
	for enemy_config in wave_config.enemies:
		var enemy_id = enemy_config.enemy_id
		var count = enemy_config.count

		for i in range(count):
			var enemy = DataManager.get_enemy(enemy_id)
			if enemy:
				enemy.reset_for_battle()
				enemies.append(enemy)

	print("\n🌊 第 %d/%d 波開始！" % [wave_number, total_waves])
	next_wave_starting.emit(wave_number)

# ==================== 技能載入 ====================

func load_all_skills():
	"""載入所有卡片和敵人的技能"""
	print("\n🔮 載入技能...")

	# 載入玩家卡片技能
	for card in player_team:
		if not card is CardData:
			continue

		# ✅ 1. 載入【個人】被動技能 (例如：迴避)
		# 這些技能【所有人】都應該有
		for skill_id in card.passive_skill_ids: # <-- 讀取 "passive_skill_ids"
			if skill_id is String and not skill_id.is_empty():
				var skill = SkillRegistry.create_skill_instance(skill_id)
				if skill:
					card.passive_skills.append(skill)
					# 註冊個人技能
					effect_manager.register_effect(skill, card)
					print("  👤 註冊【個人】被動: %s (來自 %s)" % [skill.skill_name, card.card_name])


		# ✅ 2. 【僅限隊長】載入【隊長技能】
		if card == leader_card:
			print("  👑 載入【隊長】 %s 的隊長技能..." % card.card_name)
			print("     隊長技能ID列表: %s" % str(card.leader_skill_ids))
			if card.leader_skill_ids.is_empty():
				print("     ⚠️ 隊長沒有配置隊長技能！")
			for skill_id in card.leader_skill_ids: # <-- 讀取 "leader_skill_ids"
				if skill_id is String and not skill_id.is_empty():
					print("     正在創建技能: %s" % skill_id)
					var skill_or_skills = SkillRegistry.create_skill_instance(skill_id)
					if skill_or_skills:
						# JSON技能可能返回数组（多个触发时机）
						var skills_to_register = []
						if skill_or_skills is Array:
							skills_to_register = skill_or_skills
						else:
							skills_to_register = [skill_or_skills]

						# 注册所有技能实例
						for skill in skills_to_register:
							card.passive_skills.append(skill)
							effect_manager.register_effect(skill, card)
							print("     -> ✅ 成功註冊【隊長】技能: %s (觸發時機: %s)" % [skill.skill_name, Constants.TriggerTiming.keys()[skill.trigger_timing]])
					else:
						print("     -> ❌ 技能創建失敗: %s" % skill_id)
		
		# 載入主動技能 (這部分不變)
		if card.active_skill_id is String and not card.active_skill_id.is_empty():
			var skill = SkillRegistry.create_skill_instance(card.active_skill_id)
			if skill:
				card.active_skill = skill

	# 載入敵人技能
	for enemy in enemies:
		if not enemy is EnemyData:
			continue

		# 載入被動技能
		for skill_id in enemy.passive_skill_ids:
			if skill_id is String and not skill_id.is_empty():
				var skill = SkillRegistry.create_skill_instance(skill_id)
				if skill:
					enemy.passive_skills.append(skill)
					effect_manager.register_effect(skill, enemy)

		# ✅ 載入攻擊技能（也需要註冊到 effect_manager）
		for skill_id in enemy.attack_skill_ids:
			if skill_id is String and not skill_id.is_empty():
				var skill = SkillRegistry.create_skill_instance(skill_id)
				if skill:
					enemy.attack_skills.append(skill)
					# ✅ 註冊到 effect_manager，這樣技能才會被觸發
					effect_manager.register_effect(skill, enemy)
					print("  💀 註冊敵人攻擊技能: %s (來自 %s)" % [skill.skill_name, enemy.enemy_name])
# ⬆️ ========== 替換到這裡結束 ========== ⬆️

func apply_all_permanent_skills():
	"""應用所有永久型技能（隊長技能 + 敵人永久技能）"""
	print("\n🔮 應用所有永久型技能...")

	if leader_card:
		print("  👑 隊長: %s" % leader_card.card_name)
		print("  👑 隊長技能數量: %d" % leader_card.passive_skills.size())

	if not enemies.is_empty():
		print("  💀 敵人數量: %d" % enemies.size())

	# 一次性觸發所有已註冊的 PERMANENT 技能（包括隊長和敵人）
	# EffectManager 會自動處理去重邏輯（相同 skill_id 的敵人負面技能只觸發一次）
	var context = SkillContext.new(self, null, null, null)
	effect_manager.apply_permanent_effects(context)
	print("  ✅ 應用所有永久型技能完成")

func check_enemy_damage_requirements(enemy: EnemyData, context: SkillContext) -> bool:
	"""檢查是否滿足敵人的傷害條件（如 REQUIRE_COMBO）"""
	# ✅ 檢查是否有 IGNORE_ENEMY_SKILL Buff 可以無視這個敵人的技能
	if has_meta("active_skill_buffs"):
		var buffs = get_meta("active_skill_buffs")
		for buff in buffs:
			if buff["effect_type"] == "IGNORE_ENEMY_SKILL":
				var effect_data = buff["effect_data"]
				var target_scope = buff.get("target_scope", "ALL_ALLIES")
				var caster_instance_id = buff.get("caster_instance_id", "")
				# 檢查目標範圍
				var can_ignore = false
				if target_scope == "SELF":
					# 只有發動技能的卡片可以無視
					if context and context.caster and context.caster.instance_id == caster_instance_id:
						can_ignore = true
				else:
					# ALL_ALLIES: 全隊都可以無視
					can_ignore = true
				if not can_ignore:
					continue  # 這個BUFF不適用於當前攻擊者，檢查下一個BUFF

				# 檢查是否指定了特定的敵人技能ID
				if effect_data.has("target_skill_id"):
					# 獲取敵人的技能列表
					var enemy_skill_ids = []
					for skill in enemy.skills:
						if skill and skill.has("skill_id"):
							enemy_skill_ids.append(skill["skill_id"])

					# 如果敵人擁有被無視的技能ID，則無視所有技能條件
					var target_skill_id = effect_data["target_skill_id"]
					if target_skill_id in enemy_skill_ids:
						print("    [IGNORE_ENEMY_SKILL] ✅ 無視敵人技能: %s (範圍: %s)" % [target_skill_id, target_scope])
						return true  # 無視所有條件，直接可以造成傷害
				else:
					# 沒有指定target_skill_id，無視所有敵人技能（向後兼容）
					print("    [IGNORE_ENEMY_SKILL] ✅ 無視所有敵人技能條件 (範圍: %s)" % target_scope)
					return true

	# ✅ 使用與 SkillRegistry 相同的 meta key 格式
	var instance_id = abs(enemy.get_instance_id())
	var meta_key = "enemy_dmg_req_%d" % instance_id
	if not has_meta(meta_key):
		return true  # 沒有條件，可以造成傷害

	var requirements = get_meta(meta_key)
	# ✅ 安全檢查：確保 requirements 不是 null
	if requirements == null or requirements.is_empty():
		return true

	print("    [條件檢查] 檢查 %d 個條件..." % requirements.size())

	for req in requirements:
		var req_type = req.get("type", "")
		var skill_name = req.get("skill_name", "未知技能")

		match req_type:
			"combo":
				var required_combo = req.get("required_combo", 10)
				var current_combo = get_meta("current_combo", 0)
				print("    [條件檢查] 讀取連擊數: %d (需要: %d)" % [current_combo, required_combo])
				if current_combo < required_combo:
					print("    [條件檢查] ❌ %s: 連擊數不足 (%d/%d)" % [skill_name, current_combo, required_combo])
					return false
				else:
					print("    [條件檢查] ✓ %s: 連擊數滿足 (%d/%d)" % [skill_name, current_combo, required_combo])

			"orb_total":
				var required_element = req.get("required_element", Constants.Element.FIRE)
				var required_count = req.get("required_count", 0)
				var orb_totals = get_meta("current_orb_totals", {})
				var current_count = orb_totals.get(required_element, 0)
				var element_name = Constants.Element.keys()[required_element]
				print("    [條件檢查] %s 累積靈珠: %d (需要: %d)" % [element_name, current_count, required_count])
				if current_count < required_count:
					print("    [條件檢查] ❌ %s: %s靈珠累積不足 (%d/%d)" % [skill_name, element_name, current_count, required_count])
					return false
				else:
					print("    [條件檢查] ✓ %s: %s靈珠累積滿足 (%d/%d)" % [skill_name, element_name, current_count, required_count])

			"orb_continuous":
				var required_element = req.get("required_element", Constants.Element.FIRE)
				var required_count = req.get("required_count", 0)
				var continuous_element = get_meta("current_continuous_element", -1)
				var continuous_count = get_meta("current_continuous_count", 0)
				var element_name = Constants.Element.keys()[required_element]

				# 檢查當前連續消除的元素是否是目標元素
				var is_match = (continuous_element == required_element and continuous_count >= required_count)
				print("    [條件檢查] 連續消除: %s x%d (需要: %s x%d)" % [
					Constants.Element.keys()[continuous_element] if continuous_element >= 0 else "無",
					continuous_count,
					element_name,
					required_count
				])
				if not is_match:
					print("    [條件檢查] ❌ %s: 連續%s靈珠不足" % [skill_name, element_name])
					return false
				else:
					print("    [條件檢查] ✓ %s: 連續%s靈珠滿足" % [skill_name, element_name])

			"unique_elements":
				var required_unique = req.get("required_unique_elements", 0)
				var unique_elements = get_meta("current_unique_elements", [])
				var current_unique = unique_elements.size()
				print("    [條件檢查] 消除屬性種類: %d (需要: %d)" % [current_unique, required_unique])
				if current_unique < required_unique:
					print("    [條件檢查] ❌ %s: 屬性種類不足 (%d/%d)" % [skill_name, current_unique, required_unique])
					return false
				else:
					print("    [條件檢查] ✓ %s: 屬性種類滿足 (%d/%d)" % [skill_name, current_unique, required_unique])

			"combo_exact":
				var required_combo = req.get("required_combo", 10)
				var current_combo = get_meta("current_combo", 0)
				print("    [條件檢查] 連擊數: %d (需要完全等於: %d)" % [current_combo, required_combo])
				if current_combo != required_combo:
					print("    [條件檢查] ❌ %s: 連擊數不符合 (%d != %d)" % [skill_name, current_combo, required_combo])
					return false
				else:
					print("    [條件檢查] ✓ %s: 連擊數符合 (%d = %d)" % [skill_name, current_combo, required_combo])

			"combo_max":
				var max_combo = req.get("max_combo", 10)
				var current_combo = get_meta("current_combo", 0)
				print("    [條件檢查] 連擊數: %d (最多: %d)" % [current_combo, max_combo])
				if current_combo > max_combo:
					print("    [條件檢查] ❌ %s: 連擊數過高 (%d > %d)" % [skill_name, current_combo, max_combo])
					return false
				else:
					print("    [條件檢查] ✓ %s: 連擊數符合 (%d <= %d)" % [skill_name, current_combo, max_combo])

			"stored_orb_min":
				var orb_requirements = req.get("orb_requirements", [])
				var battle_scene = get_tree().current_scene
				var all_satisfied = true
				for orb_req in orb_requirements:
					var element = orb_req.get("element", Constants.Element.FIRE)
					var required_count = orb_req.get("count", 0)
					var current_count = 0
					if battle_scene and battle_scene.has_method("get_stored_orb_count"):
						current_count = battle_scene.get_stored_orb_count(element)
					var element_name = Constants.Element.keys()[element]
					print("    [條件檢查] 儲存%s靈珠: %d (需要>=: %d)" % [element_name, current_count, required_count])
					if current_count < required_count:
						print("    [條件檢查] ❌ %s: 儲存%s靈珠不足 (%d < %d)" % [skill_name, element_name, current_count, required_count])
						all_satisfied = false
						break
				if not all_satisfied:
					return false
				print("    [條件檢查] ✓ %s: 所有儲存靈珠條件滿足" % skill_name)

			"stored_orb_exact":
				var orb_requirements = req.get("orb_requirements", [])
				var battle_scene = get_tree().current_scene
				var all_satisfied = true
				for orb_req in orb_requirements:
					var element = orb_req.get("element", Constants.Element.FIRE)
					var required_count = orb_req.get("count", 0)
					var current_count = 0
					if battle_scene and battle_scene.has_method("get_stored_orb_count"):
						current_count = battle_scene.get_stored_orb_count(element)
					var element_name = Constants.Element.keys()[element]
					print("    [條件檢查] 儲存%s靈珠: %d (需要=: %d)" % [element_name, current_count, required_count])
					if current_count != required_count:
						print("    [條件檢查] ❌ %s: 儲存%s靈珠不符合 (%d != %d)" % [skill_name, element_name, current_count, required_count])
						all_satisfied = false
						break
				if not all_satisfied:
					return false
				print("    [條件檢查] ✓ %s: 所有儲存靈珠條件完全符合" % skill_name)

			"enemy_attack":
				var enemy_attack_key = "enemy_has_attacked_%d" % instance_id
				var has_attacked = get_meta(enemy_attack_key, false)
				print("    [條件檢查] 敵人是否已攻擊: %s" % ("是" if has_attacked else "否"))
				if not has_attacked:
					print("    [條件檢查] ❌ %s: 敵人尚未攻擊" % skill_name)
					return false
				else:
					print("    [條件檢查] ✓ %s: 敵人已攻擊" % skill_name)

			"damage_once_only":
				var damage_count_key = "enemy_damage_count_%d" % instance_id
				var damage_count = get_meta(damage_count_key, 0)
				print("    [條件檢查] 敵人已被攻擊次數: %d" % damage_count)
				if damage_count >= 1:
					print("    [條件檢查] ❌ %s: 敵人已被攻擊過，無法再造成傷害" % skill_name)
					return false
				else:
					print("    [條件檢查] ✓ %s: 這是第一次攻擊，可以造成傷害" % skill_name)

	return true  # 所有條件都滿足

func calculate_team_stats():
	"""計算隊伍總屬性"""
	total_hp = 0
	total_recovery = 0
	
	# 先讓所有卡片計算最終屬性
	for card in player_team:
		card.calculate_final_stats()
		total_hp += card.current_hp
		total_recovery += card.current_recovery
	
	current_hp = total_hp
	hp_changed.emit(current_hp, total_hp)

func trigger_battle_start_skills():
	"""觸發戰鬥開始時的技能"""
	var context = SkillContext.new(self, null, null, null)
	effect_manager.trigger_effects(Constants.TriggerTiming.BATTLE_START, context)

# ==================== 玩家行動 ====================

func attack_with_card(card: CardData, target_enemy: EnemyData):
	"""用卡片攻擊敵人"""
	if current_phase != Constants.BattlePhase.PLAYER_TURN:
		print("❌ 不是玩家回合！")
		return false
	
	if not card.use_sp(1):
		print("❌ SP不足！")
		return false
	
	if not target_enemy.is_alive:
		print("❌ 目標已死亡！")
		return false
	
	var context = SkillContext.new(self, null, card, target_enemy)
	#effect_manager.trigger_effects(Constants.TriggerTiming.BEFORE_ATTACK, context)
	
	# 1. 獲取元素倍率
	var element_multiplier = current_element_multipliers.get(card.element, 1.0)
	
	# 2. 設定*基礎*傷害 (卡片攻擊力 * 元素倍率)
	#    注意：因為 passive_fire_dominance_atk 不再是 PERMANENT，
	#    card.current_atk *沒有* 預先乘以 1.25。
	context.damage = int(card.current_atk * element_multiplier)
	
	# 3. 觸發 `BEFORE_ATTACK` 技能 (例如我們剛修改的 fire_dominance)
	#    這些技能現在會修改 context.damage_multiplier
	effect_manager.trigger_effects(Constants.TriggerTiming.BEFORE_ATTACK, context)

	# 3.5. 應用主動技能的傷害倍率 Buff（向後兼容DAMAGE_MULTIPLIER和新的FINAL_DAMAGE_MULTIPLIER）
	var active_damage_multiplier = get_active_buff_multiplier("DAMAGE_MULTIPLIER")
	var final_damage_multiplier = get_active_buff_multiplier("FINAL_DAMAGE_MULTIPLIER")

	# 合併兩種倍率（向後兼容）
	var total_multiplier = active_damage_multiplier * final_damage_multiplier
	if total_multiplier > 1.0:
		context.damage_multiplier *= total_multiplier
		print("    [主動技能] 傷害倍率 Buff: x%.2f" % total_multiplier)

	# 應用特定元素的傷害倍率 Buff
	var element_name = Constants.Element.keys()[card.element]
	var element_buff_key = "ELEMENT_DAMAGE_BOOST_%s" % element_name
	var element_damage_multiplier = get_active_buff_multiplier(element_buff_key)
	if element_damage_multiplier > 1.0:
		context.damage_multiplier *= element_damage_multiplier
		print("    [主動技能] %s 元素傷害倍率 Buff: x%.2f" % [element_name, element_damage_multiplier])

	# 3.6. 應用屬性相克倍率（我方攻擊敵人）
	# ✅ 提前声明 enemy_element_name 避免作用域问题
	var enemy_element_name = Constants.Element.keys()[target_enemy.element]

	# ✅ 檢查是否無視屬性克制
	var should_ignore_resistance = false
	if has_meta("ignore_resistance"):
		var ignored_elements = get_meta("ignore_resistance")
		if card.element in ignored_elements:
			should_ignore_resistance = true
			print("    [IGNORE_RESISTANCE] %s無視屬性克制！" % element_name)

	if not should_ignore_resistance:
		var advantage_multiplier = get_element_advantage_multiplier(card.element, target_enemy.element)
		if advantage_multiplier != 1.0:
			context.damage_multiplier *= advantage_multiplier
			if advantage_multiplier > 1.0:
				print("    [屬性相克] %s克制%s！傷害倍率: x%.2f" % [element_name, enemy_element_name, advantage_multiplier])
			else:
				print("    [屬性相克] %s被%s克制！傷害倍率: x%.2f" % [element_name, enemy_element_name, advantage_multiplier])

	# 4. 獲取*最終*傷害 (基礎傷害 * 所有技能倍率)
	var final_damage = context.get_final_damage()

	# ✅ 4.5. 檢查敵人的傷害條件（如 REQUIRE_COMBO）
	var can_deal_damage = check_enemy_damage_requirements(target_enemy, context)
	if not can_deal_damage:
		final_damage = 0
		print("    ❌ 不滿足傷害條件！傷害被阻擋")

	print("⚔️  %s (%s屬性) 攻擊 %s (%s屬性)" % [card.card_name, Constants.Element.keys()[card.element], target_enemy.enemy_name, enemy_element_name])
	print("    基礎傷害 (ATK * 元素): %d" % context.damage)
	print("    技能倍率 (來自 %s 等): x%.2f" % ["passive_fire_dominance_atk", context.damage_multiplier])
	print("    最終傷害: %d" % final_damage)

	# ✅ 移除攻擊後清空倍率的邏輯，改為只在休息時清空
	# 這樣多個角色都能享受斬擊累積的倍率
	# current_element_multipliers.clear()  # <- 已註解
	# print("  BattleManager: 攻擊後倍率已清空。")

	# 5. 使用 final_damage 造成傷害
	var actual_damage = target_enemy.take_damage(final_damage)

	# ✅ 記錄攻擊次數（用於 DAMAGE_ONCE_ONLY 技能）
	if actual_damage > 0:
		var instance_id = abs(target_enemy.get_instance_id())
		var damage_count_key = "enemy_damage_count_%d" % instance_id
		var current_count = get_meta(damage_count_key, 0)
		set_meta(damage_count_key, current_count + 1)

	# 保持不變 (日誌和信號)
	print("    對 %s 造成 %d 實際傷害！(剩餘 %d/%d HP)" % [
		target_enemy.enemy_name,
		actual_damage,
		target_enemy.current_hp,
		target_enemy.max_hp
	])
	# 使用instance_id來唯一標識敵人，而不是enemy_id（因為多個敵人可能有相同的enemy_id）
	var enemy_instance_id = str(target_enemy.get_instance_id())
	damage_dealt.emit(enemy_instance_id, actual_damage)
	card_sp_changed.emit(card)
	
	effect_manager.trigger_effects(Constants.TriggerTiming.AFTER_ATTACK, context)
	
	if not target_enemy.is_alive:
		on_enemy_died(target_enemy)
	
	return true

func use_card_active_skill(card: CardData, target_enemy: EnemyData = null):
	"""使用卡片主動技能"""
	if current_phase != Constants.BattlePhase.PLAYER_TURN:
		print("❌ 不是玩家回合！")
		return false

	if not card.can_use_active_skill():
		print("❌ 技能CD中！(剩餘 %d 回合)" % card.active_skill_current_cd)
		return false

	if not card.active_skill:
		print("❌ 該卡片沒有主動技能！")
		return false

	# ✅ 檢查 END_TURN_DAMAGE 技能使用限制
	# 只有在「刚斩击结束」AND「已有主动技能 END_TURN_DAMAGE Buff」时才阻止
	# 这样队长技能的 END_TURN_DAMAGE 不会影响主动技能的使用
	if slash_ended and "effects" in card.active_skill:
		for effect in card.active_skill.effects:
			if effect.get("effect_type", "") == "END_TURN_DAMAGE":
				# 检查是否已经有主动技能的 END_TURN_DAMAGE Buff 在生效
				if has_active_buff("END_TURN_DAMAGE"):
					print("❌ 已有 END_TURN_DAMAGE Buff 在生效且刚斩击结束，不能立即使用！")
					return false
				# 如果没有现存的 Buff，允许创建新的
				print("✓ 虽然刚斩击结束，但没有现存 END_TURN_DAMAGE Buff，允许使用")

	# 創建上下文
	var context = SkillContext.new(self, card.active_skill, card, target_enemy)
	
	# 執行技能
	print("\n✨ %s 使用主動技能！" % card.card_name)
	card.active_skill.execute(context)
	
	# 重置CD
	card.use_active_skill()
	
	skill_activated.emit(card.active_skill.skill_name, card.card_name)
	
	# 檢查是否有敵人死亡
	check_all_enemies_alive()
	
	return true

func player_rest():
	"""玩家選擇休息"""
	if current_phase != Constants.BattlePhase.PLAYER_TURN:
		return

	print("\n💤 玩家選擇休息...")
	current_element_multipliers.clear() # ✨ 新增
	# 重置連擊數（玩家選擇休息時，放棄本次斬擊的連擊加成）
	set_meta("current_combo", 0)

	for card in player_team:
		card.recover_sp(1)
		print("   %s 恢復1點SP (%d/%d)" % [card.card_name, card.current_sp, card.max_sp])
		card_sp_changed.emit(card)
		
	lock_in_orb_sequence()
	end_player_turn()
	
func lock_in_orb_sequence():
	"""(新) 從 BattleScene 獲取序列並設定為規則"""
	if next_orb_sequence_was_locked: # 防止重複鎖定
		return
		
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.has_method("get_and_clear_next_orb_sequence"):
		# 獲取玩家排好的序列 e.g., [{elm:火, P:true}, {elm:木, P:true}]
		var sequence = battle_scene.get_and_clear_next_orb_sequence() 
		if not sequence.is_empty():
			# (重要) 清除舊序列，只保留玩家這回合排的
			current_orb_rules["orb_sequence"] = sequence
			next_orb_sequence_was_locked = true
			print("  [BattleManager] 玩家序列已鎖定: ", sequence.size())
		else:
			# 玩家這回合沒排，清空上一回合可能殘留的
			current_orb_rules["orb_sequence"] = []
			next_orb_sequence_was_locked = true

func end_player_turn():
	"""結束玩家回合"""
	print("\n--- 玩家回合結束 ---\n")

	# ✅ 確保序列被鎖定 (例如 SP 用完自動結束回合)
	lock_in_orb_sequence()

	current_element_multipliers.clear()

	# ✅ 執行回合結束技能效果（如掉落靈珠）
	_apply_end_turn_effects()

	# ✅ 只清除 "bonus" 規則，保留 "orb_sequence"
	clear_orb_rules_for_turn()

	current_phase = Constants.BattlePhase.ENEMY_TURN
	turn_changed.emit(false)

	# 更新玩家技能CD
	for card in player_team:
		card.reduce_skill_cd()

	# 觸發回合結束技能
	var context = SkillContext.new(self, null, null, null)
	effect_manager.trigger_effects(Constants.TriggerTiming.TURN_END, context)

	# ✅ 更新主動技能 Buff（減少回合數）
	tick_active_skill_buffs()

func apply_immediate_orb_drops():
	"""應用斬擊結束立刻掉落的靈珠"""
	if has_meta("orb_drop_immediate"):
		var drops = get_meta("orb_drop_immediate")
		var battle_scene = get_tree().current_scene

		if battle_scene and battle_scene.has_method("add_stored_orb"):
			for element in drops:
				var count = drops[element]
				for i in range(count):
					battle_scene.add_stored_orb(element)
				print("  [斬擊結束] 立刻掉落 %s x%d" % [Constants.Element.keys()[element], count])

		# 清除已處理的立即掉落（避免重複觸發）
		remove_meta("orb_drop_immediate")

func _apply_end_turn_effects():
	"""應用回合結束的技能效果（如掉落靈珠）"""
	# 1. 處理隊長技能的回合結束掉落靈珠
	if has_meta("orb_drop_end_turn"):
		var drops = get_meta("orb_drop_end_turn")
		var battle_scene = get_tree().current_scene

		if battle_scene and battle_scene.has_method("add_stored_orb"):
			for element in drops:
				var count = drops[element]
				for i in range(count):
					battle_scene.add_stored_orb(element)
				print("  [隊長技能] 回合結束掉落 %s x%d" % [Constants.Element.keys()[element], count])

	# 2. 處理主動技能 Buff 的回合結束掉落靈珠
	if has_meta("active_skill_buffs"):
		var buffs = get_meta("active_skill_buffs")
		var battle_scene = get_tree().current_scene

		if battle_scene and battle_scene.has_method("add_stored_orb"):
			for buff in buffs:
				if buff["effect_type"] == "ORB_DROP_END_TURN":
					var effect_data = buff["effect_data"]
					var element_str = effect_data.get("element", "HEART")
					var count = effect_data.get("count", 0)

					# 解析元素
					var element = Constants.Element.HEART
					match element_str.to_upper():
						"FIRE": element = Constants.Element.FIRE
						"WATER": element = Constants.Element.WATER
						"WOOD": element = Constants.Element.WOOD
						"METAL": element = Constants.Element.METAL
						"EARTH": element = Constants.Element.EARTH
						"HEART": element = Constants.Element.HEART

					# 掉落靈珠
					for i in range(count):
						battle_scene.add_stored_orb(element)
					print("  [主動技能 Buff] %s 回合結束掉落 %s x%d" % [buff["skill_name"], element_str, count])

	# 3. 處理其他回合結束效果（可以在這裡擴展）
	# ...

# ==================== 敵人回合 ====================

func execute_enemy_turn():
	"""執行敵人回合"""
	print("\n👾 === 敵人回合 ===\n")

	for enemy in enemies:
		if not enemy.is_alive:
			continue

		# 更新CD
		enemy.tick_cd()

		# 檢查是否該攻擊
		if enemy.should_attack():
			await execute_enemy_attack(enemy)
			enemy.reset_cd()
		else:
			print("  %s 待機中... (CD: %d)" % [enemy.enemy_name, enemy.current_cd])

	# 敵人回合結束
	await get_tree().create_timer(0.5).timeout
	end_enemy_turn()

func execute_enemy_attack(enemy: EnemyData):
	"""執行敵人攻擊"""
	print("\n  👾 %s 的回合：" % enemy.enemy_name)

	# 創建上下文
	var context = SkillContext.new(self, null, enemy, null)
	context.is_player_turn = false

	# 觸發敵人的攻擊技能（跳過 PERMANENT 類型，因為已在戰鬥開始時觸發）
	for attack_skill in enemy.attack_skills:
		# 跳過 PERMANENT 類型技能，這些技能應該只在戰鬥開始時觸發一次
		if attack_skill.trigger_timing == Constants.TriggerTiming.PERMANENT:
			print("  [跳過] %s (PERMANENT技能不應在攻擊時觸發)" % attack_skill.skill_name)
			continue
		attack_skill.execute(context)

	# 如果沒有跳過普通攻擊，且沒有設定傷害，則執行普通攻擊
	if not context.skip_normal_attack and context.damage == 0:
		context.damage = enemy.current_atk

	# 對玩家造成傷害
	if context.damage > 0:
		apply_damage_to_player(context)

	# ✅ 記錄敵人已攻擊標記（用於 REQUIRE_ENEMY_ATTACK 技能，這個標記會繼承回合）
	var instance_id = abs(enemy.get_instance_id())
	var enemy_attack_key = "enemy_has_attacked_%d" % instance_id
	set_meta(enemy_attack_key, true)
	print("    [REQUIRE_ENEMY_ATTACK] 設置敵人已攻擊標記: %s" % enemy.enemy_name)

func apply_damage_to_player(context: SkillContext):

	# 觸發受傷前技能（迴避、減傷等）
	effect_manager.trigger_effects(Constants.TriggerTiming.BEFORE_DAMAGED, context)

	# ✅ 應用主動技能的減傷 Buff (DAMAGE_REDUCTION)
	if has_active_buff("DAMAGE_REDUCTION"):
		var reduction_percent = get_active_buff_value("DAMAGE_REDUCTION", "reduction_percent", 0.0)
		if reduction_percent > 0:
			var original_damage = context.damage
			var reduction = original_damage * (reduction_percent / 100.0)
			context.damage = int(original_damage - reduction)
			print("    [DAMAGE_REDUCTION] 減傷%.0f%% (減少%d點傷害)" % [reduction_percent, int(reduction)])

	var final_damage = context.get_final_damage()

	if context.is_dodged:
		print("    ✨ 觸發迴避！未受到傷害")
		return

	# 扣除生命值
	take_damage(final_damage)

	# 觸發受傷後技能
	effect_manager.trigger_effects(Constants.TriggerTiming.AFTER_DAMAGED, context)

func take_damage(damage: int):
	"""玩家受到傷害"""
	current_hp -= damage
	current_hp = max(current_hp, 0)
	
	print("    💔 玩家受到 %d 點傷害！(剩餘 %d/%d HP)" % [damage, current_hp, total_hp])
	
	hp_changed.emit(current_hp, total_hp)
	damage_dealt.emit("玩家", damage)
	
	# 檢查是否失敗
	if current_hp <= 0:
		end_battle(false)

func end_enemy_turn():
	"""結束敵人回合"""
	print("\n--- 敵人回合結束 ---\n")



	# 檢查是否已經戰鬥結束
	if current_phase == Constants.BattlePhase.BATTLE_END:
		return

	next_orb_sequence_was_locked = false

	# 回到玩家回合
	turn_count += 1
	current_phase = Constants.BattlePhase.PLAYER_TURN

	# ✅ 修復 BUG 1：清除上一回合的條件追蹤數據
	# 這些數據應該在每次斬擊開始時重新計算，不應該繼承到新回合
	set_meta("current_combo", 0)
	set_meta("current_orb_totals", {})
	set_meta("current_continuous_element", -1)
	set_meta("current_continuous_count", 0)
	set_meta("current_unique_elements", [])
	print("  [回合開始] 清除條件追蹤數據")

	# 觸發回合開始技能
	var context = SkillContext.new(self, null, null, null)
	effect_manager.trigger_effects(Constants.TriggerTiming.TURN_START, context)

	turn_changed.emit(true) #

	print("--- 第 %d 回合開始（玩家） ---\n" % turn_count)

# ==================== 治療 ====================

func heal(amount: int):
	"""治療玩家"""
	var old_hp = current_hp
	current_hp += amount
	current_hp = min(current_hp, total_hp)
	
	var actual_heal = current_hp - old_hp
	print("  💚 恢復 %d 點生命值 (%d/%d HP)" % [actual_heal, current_hp, total_hp])
	
	hp_changed.emit(current_hp, total_hp)

# ==================== 戰鬥結束 ====================

func on_enemy_died(enemy: EnemyData):
	"""敵人死亡時"""
	print("  ☠️  %s 被擊敗！" % enemy.enemy_name)
	enemy_died.emit(enemy)
	
	# (✅ 移除 enemies.erase(enemy)，改用 check_all_enemies_alive 統一處理)
	
	check_all_enemies_alive()
			
			
func on_wave_completed():
	"""當前波次完成"""
	is_wave_complete = true
	wave_completed.emit(current_wave)

	print("\n✅ 第 %d 波完成！" % current_wave)
	print("準備下一波...")

	# ✅ 顯示 WAVE 轉場動畫（2秒）
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.has_method("show_wave_transition"):
		battle_scene.show_wave_transition(current_wave + 1, total_waves)

	# ✅ 修改：延遲2秒後開始下一波（原本是3秒）
	await get_tree().create_timer(2.0).timeout

	current_wave += 1
	is_wave_complete = false
	load_wave_enemies(current_wave)

	# ✅ 執行 WAVE 轉場專用的休息邏輯
	execute_wave_transition_rest()

	# 重新創建敵人UI
	battle_scene.create_enemy_nodes()

func execute_wave_transition_rest():
	"""
	WAVE 轉場專用的休息邏輯
	與正常休息的差異：
	1. 強制進入玩家回合（不是敵人回合）
	2. 不增加回合數
	3. 重置所有系統（倍率、連擊、SP等）
	"""
	print("\n🌊 WAVE 轉場 - 執行休息...")

	# ✅ 1. 清除元素倍率（與正常休息相同）
	current_element_multipliers.clear()

	# ✅ 2. 重置連擊數（與正常休息相同）
	set_meta("current_combo", 0)

	# ✅ 3. 恢復所有卡片的 SP（與正常休息相同）
	for card in player_team:
		card.recover_sp(1)
		print("   %s 恢復1點SP (%d/%d)" % [card.card_name, card.current_sp, card.max_sp])
		card_sp_changed.emit(card)

	# ✅ 4. 鎖定靈珠序列（與正常休息相同）
	lock_in_orb_sequence()

	# ✅ 5. 清除回合規則（與正常休息相同）
	clear_orb_rules_for_turn()

	# ✅ 6. 應用回合結束效果（與正常休息相同）
	_apply_end_turn_effects()

	# ✅ 7. 觸發回合結束技能（與正常休息相同）
	var context = SkillContext.new(self, null, null, null)
	effect_manager.trigger_effects(Constants.TriggerTiming.TURN_END, context)

	# ✅ 8. 更新主動技能 Buff（與正常休息相同）
	tick_active_skill_buffs()

	# ✅ 9. 更新玩家技能CD（與正常休息相同）
	for card in player_team:
		card.reduce_skill_cd()

	# ❌ 10. 【關鍵差異】強制進入玩家回合，不是敵人回合
	current_phase = Constants.BattlePhase.PLAYER_TURN

	# ❌ 11. 【關鍵差異】不增加回合數（turn_count 保持不變）
	# 正常的 end_enemy_turn() 會執行 turn_count += 1，這裡不執行

	# ✅ 12. 清除條件追蹤數據（與正常回合開始相同）
	set_meta("current_combo", 0)
	set_meta("current_orb_totals", {})
	set_meta("current_continuous_element", -1)
	set_meta("current_continuous_count", 0)
	set_meta("current_unique_elements", [])

	# ✅ 13. 重置靈珠序列鎖定狀態
	next_orb_sequence_was_locked = false

	# ✅ 14. 觸發回合開始技能（與正常回合開始相同）
	effect_manager.trigger_effects(Constants.TriggerTiming.TURN_START, context)

	# ✅ 15. 發送回合變更信號（強制玩家回合）
	turn_changed.emit(true)

	print("🌊 WAVE 轉場 - 強制進入玩家回合（回合數維持 %d）\n" % turn_count)


func check_all_enemies_alive():
	"""檢查所有敵人是否存活"""
	var alive_enemies = []
	for enemy in enemies:
		if enemy.is_alive:
			alive_enemies.append(enemy)
		# else:
			# (✅ 移除，讓 on_enemy_died 統一處理死亡訊息)
			# print("  ☠️  %s 被擊敗！" % enemy.enemy_name)
			# enemy_died.emit(enemy)
	
	enemies = alive_enemies
	
	if enemies.is_empty() and current_phase != Constants.BattlePhase.BATTLE_END:
		# ✅ 檢查是否還有下一波
		if current_wave < total_waves:
			on_wave_completed()
		else:
			# 所有波次完成，勝利
			end_battle(true)

func end_battle(victory: bool):
	"""結束戰鬥"""
	if current_phase == Constants.BattlePhase.BATTLE_END:
		return  # 防止重複結束
	
	current_phase = Constants.BattlePhase.BATTLE_END
	
	print("\n" + "=".repeat(50))
	if victory:
		print("🎉 勝利！")
		print("  回合數: %d" % turn_count)
		print("  剩餘HP: %d/%d" % [current_hp, total_hp])
	else:
		print("💀 失敗...")
	print("=".repeat(50) + "\n")
	
	battle_ended.emit(victory)
	
	# ✅ 修改：處理獎勵並跳轉
	if victory and stage_data:
		var rewards = process_rewards()
		
		# 保存獎勵資料到 GameManager（供 RewardScreen 使用）
		GameManager.battle_rewards = rewards
		GameManager.battle_victory = victory
		
		# ⚠️ 注意：不要在這裡 await，會導致問題
		# 改由 BattleScene 處理跳轉
	else:
		# 失敗也顯示結算畫面
		GameManager.battle_rewards = {
			"gold": 0,
			"exp": 0,
			"cards": []
		}
		GameManager.battle_victory = false

func process_rewards():
	"""處理戰鬥獎勵（使用新版 rewards 系統）"""
	# 計算獎勵（基於表現分數，目前固定100%）
	var performance_score = 100  # TODO: 未來可根據戰鬥表現調整
	var rewards = stage_data.calculate_rewards(performance_score)

	print("\n💰 獲得獎勵：")
	print("  金錢: +%d" % rewards["gold"])
	print("  經驗: +%d" % rewards["exp"])

	# 添加金錢和經驗
	PlayerDataManager.add_gold(rewards["gold"])
	PlayerDataManager.add_exp(rewards["exp"])

	# 掉落卡片
	var dropped_cards = rewards["cards"]
	if not dropped_cards.is_empty():
		for card_id in dropped_cards:
			if not card_id.is_empty():
				print("  🎴 掉落卡片: %s" % card_id)
				PlayerDataManager.add_card(card_id)

	# 標記關卡完成
	PlayerDataManager.complete_stage(stage_data.stage_id)
	PlayerDataManager.save_data()
	
	# ✅ 返回獎勵資料
	return rewards

# ==================== 工具方法 ====================

func get_alive_enemies() -> Array[EnemyData]:
	"""獲取存活的敵人列表"""
	var alive: Array[EnemyData] = []
	for enemy in enemies:
		if enemy.is_alive:
			alive.append(enemy)
	return alive

func can_player_act() -> bool:
	"""檢查玩家是否可以行動"""
	return current_phase == Constants.BattlePhase.PLAYER_TURN

func get_battle_info() -> Dictionary:
	"""獲取戰鬥資訊"""
	return {
		"turn": turn_count,
		"phase": Constants.BattlePhase.keys()[current_phase],
		"player_hp": "%d/%d" % [current_hp, total_hp],
		"enemies_alive": enemies.size()
	}

# ==================== 主動技能 Buff 管理 ====================

func tick_active_skill_buffs():
	"""每回合更新主動技能 Buff（減少持續回合數）"""
	if not has_meta("active_skill_buffs"):
		return

	var buffs = get_meta("active_skill_buffs")
	var buffs_to_remove = []

	for i in range(buffs.size()):
		var buff = buffs[i]
		buff["remaining_turns"] -= 1

		if buff["remaining_turns"] <= 0:
			buffs_to_remove.append(i)
			print("  ⏱️ [Buff] %s 效果結束" % buff["skill_name"])

			# ✅ 如果是 BASE_STAT_BOOST，需要恢復卡片原始屬性
			if buff["effect_type"] == "BASE_STAT_BOOST":
				ActiveSkill.restore_base_stats(buff, self)
		else:
			print("  🔄 [Buff] %s 剩餘 %d 回合" % [buff["skill_name"], buff["remaining_turns"]])

	# 移除過期的 Buff（從後往前刪除避免索引錯誤）
	buffs_to_remove.reverse()
	for index in buffs_to_remove:
		buffs.remove_at(index)

	set_meta("active_skill_buffs", buffs)

func get_active_buff_multiplier(effect_type: String) -> float:
	"""獲取當前生效的主動技能傷害倍率"""
	if not has_meta("active_skill_buffs"):
		return 1.0

	var buffs = get_meta("active_skill_buffs")
	var total_multiplier = 1.0

	for buff in buffs:
		if buff["effect_type"] == effect_type:
			var multiplier = buff["effect_data"].get("multiplier", 1.0)
			total_multiplier *= multiplier

	return total_multiplier

func has_active_buff(effect_type: String) -> bool:
	"""檢查是否有特定類型的主動技能 Buff"""
	if not has_meta("active_skill_buffs"):
		return false

	var buffs = get_meta("active_skill_buffs")
	for buff in buffs:
		if buff["effect_type"] == effect_type:
			return true

	return false

func get_active_buff_value(effect_type: String, key: String, default = null):
	"""獲取主動技能 Buff 的特定值"""
	if not has_meta("active_skill_buffs"):
		return default

	var buffs = get_meta("active_skill_buffs")
	for buff in buffs:
		if buff["effect_type"] == effect_type:
			return buff["effect_data"].get(key, default)

	return default

func clear_active_skill_buffs():
	"""清除所有主動技能 Buff（戰鬥結束時）"""
	if has_meta("active_skill_buffs"):
		remove_meta("active_skill_buffs")

func apply_end_turn_damage():
	"""應用斬擊結束時的傷害（END_TURN_DAMAGE）
	支持兩種來源：1) 隊長技能（永久） 2) 主動技能（Buff）"""

	var all_damage_configs = []

	# 1. 收集隊長技能的 END_TURN_DAMAGE（永久效果）
	if has_meta("end_turn_damage"):
		var leader_configs = get_meta("end_turn_damage")
		for config in leader_configs:
			all_damage_configs.append({
				"element": config.get("element", Constants.Element.FIRE),
				"damage": config.get("damage", 500),
				"source": "隊長技能"
			})

	# 2. 收集主動技能的 END_TURN_DAMAGE（Buff 效果）
	if has_meta("active_skill_buffs"):
		var buffs = get_meta("active_skill_buffs")
		for buff in buffs:
			if buff["effect_type"] == "END_TURN_DAMAGE":
				var effect_data = buff["effect_data"]
				var element_str = effect_data.get("element", "FIRE")
				var damage = effect_data.get("damage", 500)

				# 解析元素
				var element = Constants.Element.FIRE
				match element_str.to_upper():
					"FIRE": element = Constants.Element.FIRE
					"WATER": element = Constants.Element.WATER
					"WOOD": element = Constants.Element.WOOD
					"METAL": element = Constants.Element.METAL
					"EARTH": element = Constants.Element.EARTH
					"HEART": element = Constants.Element.HEART

				all_damage_configs.append({
					"element": element,
					"damage": damage,
					"source": buff["skill_name"]
				})

	# 如果沒有任何 END_TURN_DAMAGE 效果，直接返回
	if all_damage_configs.is_empty():
		return

	print("\n[END_TURN_DAMAGE] 斬擊結束，觸發回合結束傷害（共%d個來源）" % all_damage_configs.size())

	# 對每個配置應用傷害
	for config in all_damage_configs:
		var element = config["element"]
		var damage = config["damage"]
		var source = config["source"]
		var element_name = Constants.Element.keys()[element]

		print("  [來源: %s] %s傷害 %d" % [source, element_name, damage])

		# 對所有存活的敵人造成傷害
		for enemy in enemies:
			if not enemy or not enemy.is_alive:
				continue

			# ✅ 檢查這個傷害是否滿足敵人的技能條件（如 REQUIRE_COMBO）
			var context = SkillContext.new(self, null, enemy, null)
			var can_deal_damage = check_enemy_damage_requirements(enemy, context)

			if can_deal_damage:
				var actual_damage = enemy.take_damage(damage)
				print("    ✓ 對 %s 造成 %d 點傷害 (滿足技能條件)" % [enemy.enemy_name, actual_damage])

				# 檢查敵人是否死亡
				if not enemy.is_alive:
					print("      💀 %s 被擊敗！" % enemy.enemy_name)
			else:
				print("    ✗ 對 %s 造成 0 點傷害 (不滿足技能條件)" % enemy.enemy_name)

# ==================== 屬性相克系統 ====================

func get_element_advantage_multiplier(attacker_element: Constants.Element, defender_element: Constants.Element) -> float:
	"""
	計算屬性相克倍率
	- 克制：+50%傷害（返回 1.5）
	- 被克制：-50%傷害（返回 0.5）
	- 無相克：返回 1.0

	五行相克規則：
	木 → 土 → 水 → 火 → 金 → 木
	"""
	# 如果元素相同，沒有相克
	if attacker_element == defender_element:
		return 1.0

	# 定義相克關係：攻擊者克制防禦者
	var advantage_table = {
		Constants.Element.WOOD: Constants.Element.EARTH,   # 木克土
		Constants.Element.EARTH: Constants.Element.WATER,  # 土克水
		Constants.Element.WATER: Constants.Element.FIRE,   # 水克火
		Constants.Element.FIRE: Constants.Element.METAL,   # 火克金
		Constants.Element.METAL: Constants.Element.WOOD    # 金克木
	}

	# 檢查攻擊者是否克制防禦者
	if advantage_table.get(attacker_element) == defender_element:
		return 1.5  # 克制：+50%傷害

	# 檢查防禦者是否克制攻擊者（被克制）
	if advantage_table.get(defender_element) == attacker_element:
		return 0.5  # 被克制：-50%傷害

	# 無相克關係
	return 1.0
